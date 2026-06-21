/**
 * Sellio Metrics — Multi-Provider AI Client
 *
 * Implements the fallback chain for code generation:
 *   Gemini 2.5 Pro/Flash → OpenAI GPT-4o → Grok
 *
 * Direct REST integration with no heavy SDKs to remain compatible with Cloudflare Workers.
 */

import type { Logger } from "../../core/logger";
import type { CacheService } from "../cache/cache.service";
import { RateLimitError, AppError } from "../../core/errors";

export interface AICompletionParams {
    systemPrompt?: string;
    userPrompt: string;
    jsonMode?: boolean;
    images?: { mimeType: string; data: string }[];
}

export class AiProviderClient {
    private readonly geminiApiKey: string;
    private readonly openaiApiKey: string;
    private readonly grokApiKey: string;
    private readonly groqApiKey: string;
    private readonly logger: Logger;
    private readonly cache: CacheService;

    private readonly geminiModels = [
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite"
    ];

    constructor({
        geminiApiKey,
        openaiApiKey,
        grokApiKey,
        groqApiKey,
        logger,
        cacheService,
    }: {
        geminiApiKey: string;
        openaiApiKey: string;
        grokApiKey: string;
        groqApiKey: string;
        logger: Logger;
        cacheService: CacheService;
    }) {
        this.geminiApiKey = geminiApiKey;
        this.openaiApiKey = openaiApiKey;
        this.grokApiKey = grokApiKey;
        this.groqApiKey = groqApiKey;
        this.logger = logger.child({ module: "ai-provider" });
        this.cache = cacheService;
    }

    /**
     * Executes the completion call with the configured fallback chain.
     */
    async generateCompletion(params: AICompletionParams): Promise<string> {
        const failureLogs: string[] = [];

        // 1. Try Gemini Models
        if (this.geminiApiKey) {
            for (const model of this.geminiModels) {
                try {
                    const cooldownKey = `ai:cooldown:gemini:${model}`;
                    const cooldown = await this.cache.get<number>(cooldownKey);
                    if (cooldown?.data && Date.now() < cooldown.data) {
                        failureLogs.push(`Gemini (${model}): skipped (cooldown active)`);
                        this.logger.info({ model }, "Gemini model is in rate limit cooldown, skipping");
                        continue;
                    }

                    return await this.executeGemini(model, params);
                } catch (error: any) {
                    failureLogs.push(`Gemini (${model}): ${error.message}`);
                    this.logger.warn({ model, error: error.message }, "Gemini model call failed");
                    continue;
                }
            }
        } else {
            failureLogs.push("Gemini: skipped (key not set)");
            this.logger.info("Gemini API key is not set, skipping Gemini");
        }

        // 2. Try OpenAI GPT-4o
        if (this.openaiApiKey) {
            try {
                const cooldownKey = "ai:cooldown:openai:gpt-4o";
                const cooldown = await this.cache.get<number>(cooldownKey);
                if (!cooldown?.data || Date.now() >= cooldown.data) {
                    return await this.executeOpenAI("gpt-4o", params);
                }
                failureLogs.push("OpenAI (gpt-4o): skipped (cooldown active)");
                this.logger.info("OpenAI gpt-4o is in cooldown, skipping");
            } catch (error: any) {
                failureLogs.push(`OpenAI (gpt-4o): ${error.message}`);
                this.logger.warn({ error: error.message }, "OpenAI call failed");
            }
        } else {
            failureLogs.push("OpenAI: skipped (key not set)");
            this.logger.info("OpenAI API key is not set, skipping OpenAI");
        }

        // 3. Try Groq
        if (this.groqApiKey) {
            try {
                const cooldownKey = "ai:cooldown:groq";
                const cooldown = await this.cache.get<number>(cooldownKey);
                if (!cooldown?.data || Date.now() >= cooldown.data) {
                    return await this.executeGroq(params);
                }
                failureLogs.push("Groq: skipped (cooldown active)");
                this.logger.info("Groq is in cooldown, skipping");
            } catch (error: any) {
                failureLogs.push(`Groq: ${error.message}`);
                this.logger.warn({ error: error.message }, "Groq call failed");
            }
        } else {
            failureLogs.push("Groq: skipped (key not set)");
            this.logger.info("Groq API key is not set, skipping Groq");
        }

        // 4. Try Grok (xAI)
        if (this.grokApiKey) {
            try {
                const cooldownKey = "ai:cooldown:grok:grok-2";
                const cooldown = await this.cache.get<number>(cooldownKey);
                if (!cooldown?.data || Date.now() >= cooldown.data) {
                    try {
                        return await this.executeGrok("grok-2", params);
                    } catch (grok2Err: any) {
                        failureLogs.push(`Grok (grok-2): ${grok2Err.message}`);
                        this.logger.warn({ error: grok2Err.message }, "Grok-2 failed, trying grok-2-1212");
                        return await this.executeGrok("grok-2-1212", params);
                    }
                }
                failureLogs.push("Grok: skipped (cooldown active)");
                this.logger.info("Grok is in cooldown, skipping");
            } catch (error: any) {
                failureLogs.push(`Grok (grok-2-1212): ${error.message}`);
                this.logger.warn({ error: error.message }, "Grok call failed");
            }
        } else {
            failureLogs.push("Grok: skipped (key not set)");
            this.logger.info("Grok API key is not set, skipping Grok");
        }

        const combinedErrorMsg = `All AI providers failed. Diagnostics:\n` + failureLogs.map(log => ` - ${log}`).join("\n");
        throw new AppError(combinedErrorMsg, 500, "AI_ALL_PROVIDERS_FAILED");
    }

    private async executeGemini(model: string, params: AICompletionParams): Promise<string> {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
        
        const parts: any[] = [{ text: params.userPrompt }];
        if (params.images && params.images.length > 0) {
            for (const img of params.images) {
                parts.push({
                    inlineData: {
                        mimeType: img.mimeType,
                        data: img.data
                    }
                });
            }
        }

        const body: any = {
            contents: [{ parts }],
            generationConfig: {
                temperature: 0.2,
                maxOutputTokens: 8192,
            },
        };

        if (params.systemPrompt) {
            body.systemInstruction = {
                parts: [{ text: params.systemPrompt }]
            };
        }

        if (params.jsonMode) {
            body.generationConfig.responseMimeType = "application/json";
        }

        const response = await fetch(url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "x-goog-api-key": this.geminiApiKey,
            },
            body: JSON.stringify(body),
        });

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 60; // 60s cooldown
                await this.cache.set(`ai:cooldown:gemini:${model}`, Date.now() + cooldownDuration * 1000, cooldownDuration + 10);
                throw new RateLimitError(`Gemini model ${model} rate limited: ${errText}`);
            }
            throw new AppError(`Gemini model ${model} failed with HTTP ${response.status}: ${errText}`, response.status, "GEMINI_API_ERROR");
        }

        const result: any = await response.json();
        const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!text) {
            throw new AppError(`Gemini model ${model} returned empty response`, 500, "GEMINI_EMPTY_RESPONSE");
        }
        return text;
    }

    private async executeOpenAI(model: string, params: AICompletionParams): Promise<string> {
        const url = "https://api.openai.com/v1/chat/completions";
        
        const messages: any[] = [];
        if (params.systemPrompt) {
            messages.push({ role: "system", content: params.systemPrompt });
        }

        let userContent: any;
        if (params.images && params.images.length > 0) {
            userContent = [{ type: "text", text: params.userPrompt }];
            for (const img of params.images) {
                userContent.push({
                    type: "image_url",
                    image_url: {
                        url: `data:${img.mimeType};base64,${img.data}`
                    }
                });
            }
        } else {
            userContent = params.userPrompt;
        }

        messages.push({ role: "user", content: userContent });

        const body: any = {
            model,
            messages,
            temperature: 0.2,
        };

        if (params.jsonMode) {
            body.response_format = { type: "json_object" };
        }

        const response = await fetch(url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${this.openaiApiKey}`,
            },
            body: JSON.stringify(body),
        });

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 60;
                await this.cache.set("ai:cooldown:openai:gpt-4o", Date.now() + cooldownDuration * 1000, cooldownDuration + 10);
                throw new RateLimitError(`OpenAI gpt-4o rate limited: ${errText}`);
            }
            throw new AppError(`OpenAI failed with HTTP ${response.status}: ${errText}`, response.status, "OPENAI_API_ERROR");
        }

        const result: any = await response.json();
        const text = result?.choices?.[0]?.message?.content;
        if (!text) {
            throw new AppError("OpenAI returned empty response", 500, "OPENAI_EMPTY_RESPONSE");
        }
        return text;
    }

    private async executeGroq(params: AICompletionParams): Promise<string> {
        const url = "https://api.groq.com/openai/v1/chat/completions";
        const hasImages = params.images && params.images.length > 0;
        const model = hasImages ? "llama-3.2-90b-vision-preview" : "llama-3.3-70b-versatile";

        const messages: any[] = [];
        if (params.systemPrompt) {
            messages.push({ role: "system", content: params.systemPrompt });
        }

        let userContent: any;
        if (hasImages) {
            userContent = [{ type: "text", text: params.userPrompt }];
            for (const img of params.images!) {
                userContent.push({
                    type: "image_url",
                    image_url: {
                        url: `data:${img.mimeType};base64,${img.data}`
                    }
                });
            }
        } else {
            userContent = params.userPrompt;
        }

        messages.push({ role: "user", content: userContent });

        const body: any = {
            model,
            messages,
            temperature: 0.2,
        };

        if (params.jsonMode) {
            body.response_format = { type: "json_object" };
        }

        const response = await fetch(url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${this.groqApiKey}`,
            },
            body: JSON.stringify(body),
        });

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 60;
                await this.cache.set("ai:cooldown:groq", Date.now() + cooldownDuration * 1000, cooldownDuration + 10);
                throw new RateLimitError(`Groq rate limited: ${errText}`);
            }
            throw new AppError(`Groq failed with HTTP ${response.status}: ${errText}`, response.status, "GROQ_API_ERROR");
        }

        const result: any = await response.json();
        const text = result?.choices?.[0]?.message?.content;
        if (!text) {
            throw new AppError("Groq returned empty response", 500, "GROQ_EMPTY_RESPONSE");
        }
        return text;
    }

    private async executeGrok(model: string, params: AICompletionParams): Promise<string> {
        const url = "https://api.x.ai/v1/chat/completions";
        
        const messages: any[] = [];
        if (params.systemPrompt) {
            messages.push({ role: "system", content: params.systemPrompt });
        }
        messages.push({ role: "user", content: params.userPrompt });

        const body: any = {
            model,
            messages,
            temperature: 0.2,
        };

        if (params.jsonMode) {
            body.response_format = { type: "json_object" };
        }

        const response = await fetch(url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${this.grokApiKey}`,
            },
            body: JSON.stringify(body),
        });

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 60;
                await this.cache.set(`ai:cooldown:grok:${model}`, Date.now() + cooldownDuration * 1000, cooldownDuration + 10);
                throw new RateLimitError(`Grok model ${model} rate limited: ${errText}`);
            }
            throw new AppError(`Grok model ${model} failed with HTTP ${response.status}: ${errText}`, response.status, "GROK_API_ERROR");
        }

        const result: any = await response.json();
        const text = result?.choices?.[0]?.message?.content;
        if (!text) {
            throw new AppError(`Grok model ${model} returned empty response`, 500, "GROK_EMPTY_RESPONSE");
        }
        return text;
    }
}
