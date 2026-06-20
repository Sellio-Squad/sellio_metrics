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
}

export class AiProviderClient {
    private readonly geminiApiKey: string;
    private readonly openaiApiKey: string;
    private readonly grokApiKey: string;
    private readonly logger: Logger;
    private readonly cache: CacheService;

    private readonly geminiModels = [
        "gemini-2.5-pro",
        "gemini-2.5-flash",
        "gemini-2.0-flash"
    ];

    constructor({
        geminiApiKey,
        openaiApiKey,
        grokApiKey,
        logger,
        cacheService,
    }: {
        geminiApiKey: string;
        openaiApiKey: string;
        grokApiKey: string;
        logger: Logger;
        cacheService: CacheService;
    }) {
        this.geminiApiKey = geminiApiKey;
        this.openaiApiKey = openaiApiKey;
        this.grokApiKey = grokApiKey;
        this.logger = logger.child({ module: "ai-provider" });
        this.cache = cacheService;
    }

    /**
     * Executes the completion call with the configured fallback chain.
     */
    async generateCompletion(params: AICompletionParams): Promise<string> {
        let lastError: Error | null = null;

        // 1. Try Gemini Models
        if (this.geminiApiKey) {
            for (const model of this.geminiModels) {
                try {
                    const cooldownKey = `ai:cooldown:gemini:${model}`;
                    const cooldown = await this.cache.get<number>(cooldownKey);
                    if (cooldown?.data && Date.now() < cooldown.data) {
                        this.logger.info({ model }, "Gemini model is in rate limit cooldown, skipping");
                        continue;
                    }

                    return await this.executeGemini(model, params);
                } catch (error: any) {
                    lastError = error;
                    this.logger.warn({ model, error: error.message }, "Gemini model call failed");
                    if (error instanceof RateLimitError) {
                        continue; // try next Gemini model
                    }
                    // For other API errors, try next Gemini model
                    continue;
                }
            }
        } else {
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
                this.logger.info("OpenAI gpt-4o is in cooldown, skipping");
            } catch (error: any) {
                lastError = error;
                this.logger.warn({ error: error.message }, "OpenAI call failed");
            }
        } else {
            this.logger.info("OpenAI API key is not set, skipping OpenAI");
        }

        // 3. Try Grok (xAI)
        if (this.grokApiKey) {
            try {
                const cooldownKey = "ai:cooldown:grok:grok-2";
                const cooldown = await this.cache.get<number>(cooldownKey);
                if (!cooldown?.data || Date.now() >= cooldown.data) {
                    // Try grok-2 first, fallback to grok-beta
                    try {
                        return await this.executeGrok("grok-2", params);
                    } catch (grok2Err) {
                        this.logger.warn({ error: (grok2Err as Error).message }, "Grok-2 failed, trying grok-beta");
                        return await this.executeGrok("grok-beta", params);
                    }
                }
                this.logger.info("Grok is in cooldown, skipping");
            } catch (error: any) {
                lastError = error;
                this.logger.warn({ error: error.message }, "Grok call failed");
            }
        } else {
            this.logger.info("Grok API key is not set, skipping Grok");
        }

        throw lastError ?? new AppError("All AI providers failed or were not configured", 500, "AI_ALL_PROVIDERS_FAILED");
    }

    private async executeGemini(model: string, params: AICompletionParams): Promise<string> {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
        
        const contents = [];
        if (params.systemPrompt) {
            // Note: System instruction in Gemini is passed in systemInstruction field
        }

        const body: any = {
            contents: [{ parts: [{ text: params.userPrompt }] }],
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
