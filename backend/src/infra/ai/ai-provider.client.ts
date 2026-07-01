/**
 * Sellio Metrics — Multi-Provider AI Client
 *
 * Implements a TIERED fallback chain for AI completions:
 *
 *   Tier 1 — Premium (Code generation, Planning, Self-correction):
 *     Gemini 2.5 Flash → OpenAI GPT-4o
 *
 *   Tier 2 — Fast/Free (Classification, File selection, Validation):
 *     Workers AI (qwen2.5-coder-32b) → Groq (llama-3.3-70b) → Grok
 *
 * All external calls are routed through Cloudflare AI Gateway for:
 *   - Response caching (identical prompts → free cached result)
 *   - Logging & analytics (token usage, cost, error rates)
 *   - Rate limiting (no manual cooldown logic needed)
 *
 * Workers AI runs FREE on Cloudflare's GPUs (10K neurons/day free tier).
 * No cold starts, no external API call, no cost for simple tasks.
 */

import type { Logger } from "../../core/logger";
import type { CacheService } from "../cache/cache.service";
import { RateLimitError, AppError } from "../../core/errors";

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

export interface AICompletionParams {
    systemPrompt?: string;
    userPrompt: string;
    jsonMode?: boolean;
    images?: { mimeType: string; data: string }[];
}

export type AITier = "premium" | "fast";

// ─── Provider health-check result shapes ────────────────────
export interface AiProviderProbeResult {
    provider: string;
    model: string;
    ok: boolean;
    latencyMs: number;
    sample?: string;
    error?: string;
}

export interface AiProviderHealth {
    checkedAt: string;
    aiGateway: "enabled" | "direct";
    totalProbed: number;
    totalHealthy: number;
    anyHealthy: boolean;
    healthyProviders: string[];
    skipped: string[];
    results: AiProviderProbeResult[];
    configuredProviders: string[];
}

// Cloudflare Workers AI binding interface
export interface CloudflareAI {
    run(model: string, inputs: {
        messages?: { role: string; content: string }[];
        prompt?: string;
        max_tokens?: number;
        temperature?: number;
        response_format?: { type: string };
    }): Promise<{ response?: string; result?: { response: string } }>;
}

export class AiProviderClient {
    private readonly geminiApiKey: string;
    private readonly openaiApiKey: string;
    private readonly deepseekApiKey: string;
    private readonly grokApiKey: string;
    private readonly groqApiKey: string;
    private readonly cfAccountId: string;
    private readonly aiGatewaySlug: string;
    private readonly workersAI: CloudflareAI | null;
    private readonly logger: Logger;
    private readonly cache: CacheService;

    // Gemini models for premium tier — ordered by quality/cost
    private readonly geminiModels = [
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
    ];

    // DeepSeek models for premium tier fallback
    private readonly deepseekModels = [
        "deepseek-chat",
        "deepseek-reasoner",
    ];

    // Workers AI models for fast/free tier
    // @cf/qwen/qwen2.5-coder-32b-instruct: specialized for code tasks
    // deepseek-r1-distill-qwen-32b: strong reasoning
    // Note: @cf/qwen/qwen3-30b-a3b-fp8 was removed — it consistently returns an empty
    // response and hangs ~40s before doing so, stalling the fast-tier fallback chain.
    // deepseek-r1-distill is kept last: it works but emits <think> reasoning preamble.
    private readonly workersAIModels = [
        "@cf/qwen/qwen2.5-coder-32b-instruct",
        "@cf/deepseek-ai/deepseek-r1-distill-qwen-32b",
    ];

    constructor({
        geminiApiKey,
        openaiApiKey,
        deepseekApiKey,
        grokApiKey,
        groqApiKey,
        cfAccountId,
        aiGatewaySlug,
        workersAI,
        logger,
        cacheService,
    }: {
        geminiApiKey: string;
        openaiApiKey: string;
        deepseekApiKey: string;
        grokApiKey: string;
        groqApiKey: string;
        cfAccountId?: string;
        aiGatewaySlug?: string;
        workersAI?: CloudflareAI | null;
        logger: Logger;
        cacheService: CacheService;
    }) {
        this.geminiApiKey = geminiApiKey;
        this.openaiApiKey = openaiApiKey;
        this.deepseekApiKey = deepseekApiKey;
        this.grokApiKey = grokApiKey;
        this.groqApiKey = groqApiKey;
        this.cfAccountId = cfAccountId || "";
        this.aiGatewaySlug = aiGatewaySlug || "";
        this.workersAI = workersAI || null;
        this.logger = logger.child({ module: "ai-provider" });
        this.cache = cacheService;
    }

    /**
     * AI Gateway base URL for a given provider.
     * Returns the proxied URL if AI Gateway is configured, otherwise the direct provider URL.
     *
     * AI Gateway provides: response caching, logging, rate limiting — all FREE.
     */
    private directUrl(provider: "google-ai-studio" | "openai" | "groq" | "x-ai" | "deepseek", path: string): string {
        const directUrls: Record<string, string> = {
            "google-ai-studio": `https://generativelanguage.googleapis.com/${path}`,
            "openai": `https://api.openai.com/${path}`,
            "groq": `https://api.groq.com/openai/${path}`,
            "x-ai": `https://api.x.ai/${path}`,
            "deepseek": `https://api.deepseek.com/${path}`,
        };
        return directUrls[provider];
    }

    private gatewayUrl(provider: "google-ai-studio" | "openai" | "groq" | "x-ai" | "deepseek", path: string): string {
        if (this.cfAccountId && this.aiGatewaySlug) {
            // Route through AI Gateway: https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_slug}/{provider}/{path}
            return `https://gateway.ai.cloudflare.com/v1/${this.cfAccountId}/${this.aiGatewaySlug}/${provider}/${path}`;
        }
        return this.directUrl(provider, path);
    }

    /**
     * Execute a completion with tiered model routing.
     *
     * @param params - The completion parameters
     * @param tier - "fast" uses Workers AI/Groq (free), "premium" uses Gemini/GPT-4o
     */
    async generateCompletion(params: AICompletionParams, tier: AITier = "premium"): Promise<string> {
        const failureLogs: string[] = [];

        // ─── FAST TIER: Workers AI (free) + Groq ────────────────
        // Used for: file selection, CI classification, code validation, review replies
        if (tier === "fast") {
            // 1. Try Workers AI (completely free, runs on Cloudflare GPUs)
            if (this.workersAI) {
                for (const model of this.workersAIModels) {
                    try {
                        this.logger.info({ model, tier: "fast" }, "Trying Workers AI model");
                        return await this.executeWorkersAI(model, params);
                    } catch (error: any) {
                        failureLogs.push(`WorkersAI (${model}): ${error.message}`);
                        this.logger.warn({ model, error: error.message }, "Workers AI model failed");
                        continue;
                    }
                }
            } else {
                failureLogs.push("Workers AI: skipped (binding not available)");
            }

            // 2. Try Groq (has generous free tier: 14,400 req/day on llama-3.3-70b)
            if (this.groqApiKey) {
                try {
                    const cooldownKey = "ai:cooldown:groq";
                    const cooldown = await this.cache.get<number>(cooldownKey);
                    if (!cooldown?.data || Date.now() >= cooldown.data) {
                        this.logger.info({ tier: "fast" }, "Trying Groq for fast tier");
                        return await this.executeGroq(params);
                    }
                    failureLogs.push("Groq: skipped (cooldown active)");
                } catch (error: any) {
                    failureLogs.push(`Groq: ${error.message}`);
                    this.logger.warn({ error: error.message }, "Groq fast-tier call failed");
                }
            }

            // 3. Fall through to premium if all fast options fail
            this.logger.warn("Fast tier exhausted, falling through to premium");
        }

        // ─── PREMIUM TIER: Gemini → OpenAI → DeepSeek ──────────────────────
        // Used for: code generation, planning, self-correction

        // 1. Try Gemini Models (via AI Gateway for caching)
        if (this.geminiApiKey) {
            for (const model of this.geminiModels) {
                try {
                    const cooldownKey = `ai:cooldown:gemini:${model}`;
                    const cooldown = await this.cache.get<number>(cooldownKey);
                    if (cooldown?.data && Date.now() < cooldown.data) {
                        failureLogs.push(`Gemini (${model}): skipped (cooldown active)`);
                        this.logger.info({ model }, "Gemini model in cooldown, skipping");
                        continue;
                    }

                    this.logger.info({ model, tier: "premium" }, "Trying Gemini model");
                    return await this.executeGemini(model, params);
                } catch (error: any) {
                    failureLogs.push(`Gemini (${model}): ${error.message}`);
                    this.logger.warn({ model, error: error.message }, "Gemini model call failed");
                    continue;
                }
            }
        } else {
            failureLogs.push("Gemini: skipped (key not set)");
        }

        // OpenAI (gpt-4o) and DeepSeek were removed from the chain — both accounts are
        // out of quota/balance and only added latency + noise to the fallback. Re-add
        // them here (with a funded key) if they come back online.

        // 4. Try Groq (if not already used in fast tier)
        if (this.groqApiKey && tier !== "fast") {
            try {
                const cooldownKey = "ai:cooldown:groq";
                const cooldown = await this.cache.get<number>(cooldownKey);
                if (!cooldown?.data || Date.now() >= cooldown.data) {
                    this.logger.info({ tier: "premium" }, "Trying Groq as premium fallback");
                    return await this.executeGroq(params);
                }
                failureLogs.push("Groq: skipped (cooldown active)");
            } catch (error: any) {
                failureLogs.push(`Groq: ${error.message}`);
                this.logger.warn({ error: error.message }, "Groq call failed");
            }
        }

        // 5. Try Grok (xAI) — use "grok-latest" only; "grok-beta" is a retired model id
        //    that always 400s ("Model not found").
        if (this.grokApiKey) {
            try {
                const cooldownKey = "ai:cooldown:grok:grok-latest";
                const cooldown = await this.cache.get<number>(cooldownKey);
                if (!cooldown?.data || Date.now() >= cooldown.data) {
                    this.logger.info({ tier: "premium" }, "Trying Grok grok-latest");
                    return await this.executeGrok("grok-latest", params);
                }
                failureLogs.push("Grok: skipped (cooldown active)");
            } catch (error: any) {
                failureLogs.push(`Grok (grok-latest): ${error.message}`);
                this.logger.warn({ error: error.message }, "Grok call failed");
            }
        } else {
            failureLogs.push("Grok: skipped (key not set)");
        }

        const combinedErrorMsg =
            `All AI providers failed.\nDiagnostics:\n` +
            failureLogs.map(log => ` - ${log}`).join("\n");
        throw new AppError(combinedErrorMsg, 500, "AI_ALL_PROVIDERS_FAILED");
    }

    // ─── Provider health check ──────────────────────────────────
    // Sends a tiny throw-away prompt to every configured provider/model and
    // reports which ones actually work right now. Bypasses cooldown caches so
    // it reflects live reachability, not cached rate-limit state.
    // Intended for the /api/debug/ai-providers diagnostics endpoint.

    async pingProviders(timeoutMs: number = 12_000): Promise<AiProviderHealth> {
        const probeParams: AICompletionParams = { userPrompt: "Reply with the single word: ok" };

        // Bound each probe so one hanging/slow model can't stall the whole check.
        // (Probes run concurrently, so total time ≈ slowest probe — cap it.)
        const withTimeout = <T>(p: Promise<T>): Promise<T> =>
            Promise.race([
                p,
                new Promise<T>((_, reject) =>
                    setTimeout(() => reject(new Error(`probe timed out after ${timeoutMs}ms`)), timeoutMs)
                ),
            ]);

        // Build the probe list: one entry per configured provider/model.
        const probes: { provider: string; model: string; run: () => Promise<string> }[] = [];

        if (this.workersAI) {
            for (const model of this.workersAIModels) {
                probes.push({ provider: "workers-ai", model, run: () => this.executeWorkersAI(model, probeParams) });
            }
        }
        if (this.geminiApiKey) {
            for (const model of this.geminiModels) {
                probes.push({ provider: "gemini", model, run: () => this.executeGemini(model, probeParams) });
            }
        }
        // OpenAI and DeepSeek are intentionally not probed — removed from the live chain.
        if (this.groqApiKey) {
            probes.push({ provider: "groq", model: "llama-3.3-70b-versatile", run: () => this.executeGroq(probeParams) });
        }
        if (this.grokApiKey) {
            probes.push({ provider: "grok", model: "grok-latest", run: () => this.executeGrok("grok-latest", probeParams) });
        }

        // Run all probes concurrently — this is a diagnostics call, not the hot path.
        const results: AiProviderProbeResult[] = await Promise.all(
            probes.map(async (p) => {
                const start = Date.now();
                try {
                    const text = await withTimeout(p.run());
                    return {
                        provider: p.provider,
                        model: p.model,
                        ok: true,
                        latencyMs: Date.now() - start,
                        sample: text.slice(0, 80),
                    } as AiProviderProbeResult;
                } catch (err: any) {
                    return {
                        provider: p.provider,
                        model: p.model,
                        ok: false,
                        latencyMs: Date.now() - start,
                        error: err?.message ?? String(err),
                    } as AiProviderProbeResult;
                }
            })
        );

        // Note which providers were skipped entirely (no key / no binding)
        const configured = new Set(results.map(r => r.provider));
        const skipped: string[] = [];
        if (!this.workersAI) skipped.push("workers-ai (binding not available)");
        if (!this.geminiApiKey) skipped.push("gemini (GEMINI_API_KEY not set)");
        if (!this.groqApiKey) skipped.push("groq (GROQ_API_KEY not set)");
        if (!this.grokApiKey) skipped.push("grok (GROK_API_KEY not set)");

        const healthy = results.filter(r => r.ok);
        return {
            checkedAt: new Date().toISOString(),
            aiGateway: this.cfAccountId && this.aiGatewaySlug ? "enabled" : "direct",
            totalProbed: results.length,
            totalHealthy: healthy.length,
            anyHealthy: healthy.length > 0,
            healthyProviders: [...new Set(healthy.map(r => r.provider))],
            skipped,
            results,
            configuredProviders: [...configured],
        };
    }

    // ─── Workers AI ─────────────────────────────────────────────
    // Free: 10,000 neurons/day on Cloudflare's GPU infrastructure.
    // Uses the AI binding directly — no network call, no API key needed.

    private async executeWorkersAI(model: string, params: AICompletionParams): Promise<string> {
        if (!this.workersAI) {
            throw new AppError("Workers AI binding not available", 500, "WORKERS_AI_UNAVAILABLE");
        }

        const messages: { role: string; content: string }[] = [];
        if (params.systemPrompt) {
            messages.push({ role: "system", content: params.systemPrompt });
        }
        messages.push({ role: "user", content: params.userPrompt });

        const inputs: any = { messages, max_tokens: 4096, temperature: 0.2 };

        // Note: Workers AI json_mode support varies by model
        if (params.jsonMode) {
            inputs.response_format = { type: "json_object" };
        }

        const result = await this.workersAI.run(model, inputs);

        const rawText = (result as any)?.response ?? (result as any)?.result?.response;
        if (!rawText && rawText !== 0) {
            throw new AppError(`Workers AI model ${model} returned empty response`, 500, "WORKERS_AI_EMPTY");
        }
        // Some thinking-mode models return objects instead of strings — coerce to string defensively
        const text = typeof rawText === "string" ? rawText : JSON.stringify(rawText);
        return text;
    }

    // ─── Gemini (via AI Gateway) ─────────────────────────────────

    private async executeGemini(model: string, params: AICompletionParams): Promise<string> {
        // AI Gateway URL: routes through Cloudflare for caching + logging
        let url = this.gatewayUrl(
            "google-ai-studio",
            `v1beta/models/${model}:generateContent`
        );

        const parts: any[] = [{ text: params.userPrompt }];
        if (params.images && params.images.length > 0) {
            for (const img of params.images) {
                parts.push({ inlineData: { mimeType: img.mimeType, data: img.data } });
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
            body.systemInstruction = { parts: [{ text: params.systemPrompt }] };
        }
        if (params.jsonMode) {
            body.generationConfig.responseMimeType = "application/json";
        }

        const fetchOptions = {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "x-goog-api-key": this.geminiApiKey,
            },
            body: JSON.stringify(body),
        };

        let response = await fetch(url, fetchOptions);

        if (!response.ok && (response.status === 401 || response.status === 404) && url.includes("gateway.ai.cloudflare.com")) {
            this.logger.warn({ model, status: response.status }, "AI Gateway request failed, falling back to direct URL");
            url = this.directUrl("google-ai-studio", `v1beta/models/${model}:generateContent`);
            response = await fetch(url, fetchOptions);
        }

        if (response.status === 429) {
            this.logger.warn({ model }, "Gemini model returned HTTP 429. Retrying in 2 seconds...");
            await sleep(2000);
            response = await fetch(url, fetchOptions);
        }

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 10;
                await this.cache.set(
                    `ai:cooldown:gemini:${model}`,
                    Date.now() + cooldownDuration * 1000,
                    cooldownDuration + 10
                );
                throw new RateLimitError(`Gemini model ${model} rate limited: ${errText}`);
            }
            throw new AppError(
                `Gemini model ${model} failed with HTTP ${response.status}: ${errText}`,
                response.status,
                "GEMINI_API_ERROR"
            );
        }

        const result: any = await response.json();
        const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!text) {
            throw new AppError(`Gemini model ${model} returned empty response`, 500, "GEMINI_EMPTY_RESPONSE");
        }
        return text;
    }

    // ─── OpenAI (via AI Gateway) ─────────────────────────────────

    private async executeOpenAI(model: string, params: AICompletionParams): Promise<string> {
        let url = this.gatewayUrl("openai", "v1/chat/completions");

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
                    image_url: { url: `data:${img.mimeType};base64,${img.data}` },
                });
            }
        } else {
            userContent = params.userPrompt;
        }
        messages.push({ role: "user", content: userContent });

        const body: any = { model, messages, temperature: 0.2 };
        if (params.jsonMode) {
            body.response_format = { type: "json_object" };
        }

        const fetchOptions = {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${this.openaiApiKey}`,
            },
            body: JSON.stringify(body),
        };

        let response = await fetch(url, fetchOptions);

        if (!response.ok && (response.status === 401 || response.status === 404) && url.includes("gateway.ai.cloudflare.com")) {
            this.logger.warn({ model, status: response.status }, "AI Gateway request failed, falling back to direct URL");
            url = this.directUrl("openai", "v1/chat/completions");
            response = await fetch(url, fetchOptions);
        }

        if (response.status === 429) {
            this.logger.warn({ model }, "OpenAI model returned HTTP 429. Retrying in 2 seconds...");
            await sleep(2000);
            response = await fetch(url, fetchOptions);
        }

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 10;
                await this.cache.set(
                    "ai:cooldown:openai:gpt-4o",
                    Date.now() + cooldownDuration * 1000,
                    cooldownDuration + 10
                );
                throw new RateLimitError(`OpenAI gpt-4o rate limited: ${errText}`);
            }
            throw new AppError(
                `OpenAI failed with HTTP ${response.status}: ${errText}`,
                response.status,
                "OPENAI_API_ERROR"
            );
        }

        const result: any = await response.json();
        const text = result?.choices?.[0]?.message?.content;
        if (!text) throw new AppError("OpenAI returned empty response", 500, "OPENAI_EMPTY_RESPONSE");
        return text;
    }

    // ─── DeepSeek (via AI Gateway) ─────────────────────────────────

    private async executeDeepSeek(model: string, params: AICompletionParams): Promise<string> {
        let url = this.gatewayUrl("deepseek", "chat/completions");

        const messages: any[] = [];
        if (params.systemPrompt) {
            messages.push({ role: "system", content: params.systemPrompt });
        }
        messages.push({ role: "user", content: params.userPrompt });

        const body: any = { model, messages, temperature: 0.2 };
        if (params.jsonMode) {
            body.response_format = { type: "json_object" };
        }

        const fetchOptions = {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${this.deepseekApiKey}`,
            },
            body: JSON.stringify(body),
        };

        let response = await fetch(url, fetchOptions);

        if (!response.ok && (response.status === 401 || response.status === 404) && url.includes("gateway.ai.cloudflare.com")) {
            this.logger.warn({ model, status: response.status }, "AI Gateway request failed, falling back to direct URL");
            url = this.directUrl("deepseek", "chat/completions");
            response = await fetch(url, fetchOptions);
        }

        if (response.status === 429) {
            this.logger.warn({ model }, "DeepSeek model returned HTTP 429. Retrying in 2 seconds...");
            await sleep(2000);
            response = await fetch(url, fetchOptions);
        }

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 10;
                await this.cache.set(
                    `ai:cooldown:deepseek:${model}`,
                    Date.now() + cooldownDuration * 1000,
                    cooldownDuration + 10
                );
                throw new RateLimitError(`DeepSeek model ${model} rate limited: ${errText}`);
            }
            throw new AppError(
                `DeepSeek model ${model} failed with HTTP ${response.status}: ${errText}`,
                response.status,
                "DEEPSEEK_API_ERROR"
            );
        }

        const result: any = await response.json();
        const text = result?.choices?.[0]?.message?.content;
        if (!text) throw new AppError(`DeepSeek model ${model} returned empty response`, 500, "DEEPSEEK_EMPTY_RESPONSE");
        return text;
    }

    // ─── Groq (via AI Gateway) ───────────────────────────────────
    // Free tier: 14,400 req/day for llama-3.3-70b-versatile

    private async executeGroq(params: AICompletionParams): Promise<string> {
        let url = this.gatewayUrl("groq", "v1/chat/completions");
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
                    image_url: { url: `data:${img.mimeType};base64,${img.data}` },
                });
            }
        } else {
            userContent = params.userPrompt;
        }
        messages.push({ role: "user", content: userContent });

        const body: any = { model, messages, temperature: 0.2 };
        if (params.jsonMode) {
            body.response_format = { type: "json_object" };
        }

        const fetchOptions = {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${this.groqApiKey}`,
            },
            body: JSON.stringify(body),
        };

        let response = await fetch(url, fetchOptions);

        if (!response.ok && (response.status === 401 || response.status === 404) && url.includes("gateway.ai.cloudflare.com")) {
            this.logger.warn({ model, status: response.status }, "AI Gateway request failed, falling back to direct URL");
            url = this.directUrl("groq", "v1/chat/completions");
            response = await fetch(url, fetchOptions);
        }

        if (response.status === 429) {
            this.logger.warn({ model }, "Groq model returned HTTP 429. Retrying in 2 seconds...");
            await sleep(2000);
            response = await fetch(url, fetchOptions);
        }

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 10;
                await this.cache.set(
                    "ai:cooldown:groq",
                    Date.now() + cooldownDuration * 1000,
                    cooldownDuration + 10
                );
                throw new RateLimitError(`Groq rate limited: ${errText}`);
            }
            throw new AppError(
                `Groq failed with HTTP ${response.status}: ${errText}`,
                response.status,
                "GROQ_API_ERROR"
            );
        }

        const result: any = await response.json();
        const text = result?.choices?.[0]?.message?.content;
        if (!text) throw new AppError("Groq returned empty response", 500, "GROQ_EMPTY_RESPONSE");
        return text;
    }

    // ─── Grok / xAI (via AI Gateway) ────────────────────────────

    private async executeGrok(model: string, params: AICompletionParams): Promise<string> {
        let url = this.gatewayUrl("x-ai", "v1/chat/completions");

        const messages: any[] = [];
        if (params.systemPrompt) {
            messages.push({ role: "system", content: params.systemPrompt });
        }
        messages.push({ role: "user", content: params.userPrompt });

        const body: any = { model, messages, temperature: 0.2 };
        if (params.jsonMode) {
            body.response_format = { type: "json_object" };
        }

        const fetchOptions = {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${this.grokApiKey}`,
            },
            body: JSON.stringify(body),
        };

        let response = await fetch(url, fetchOptions);

        if (!response.ok && (response.status === 401 || response.status === 404) && url.includes("gateway.ai.cloudflare.com")) {
            this.logger.warn({ model, status: response.status }, "AI Gateway request failed, falling back to direct URL");
            url = this.directUrl("x-ai", "v1/chat/completions");
            response = await fetch(url, fetchOptions);
        }

        if (response.status === 429) {
            this.logger.warn({ model }, "Grok model returned HTTP 429. Retrying in 2 seconds...");
            await sleep(2000);
            response = await fetch(url, fetchOptions);
        }

        if (!response.ok) {
            const errText = await response.text();
            if (response.status === 429) {
                const cooldownDuration = 10;
                await this.cache.set(
                    `ai:cooldown:grok:${model}`,
                    Date.now() + cooldownDuration * 1000,
                    cooldownDuration + 10
                );
                throw new RateLimitError(`Grok model ${model} rate limited: ${errText}`);
            }
            throw new AppError(
                `Grok model ${model} failed with HTTP ${response.status}: ${errText}`,
                response.status,
                "GROK_API_ERROR"
            );
        }

        const result: any = await response.json();
        const text = result?.choices?.[0]?.message?.content;
        if (!text) throw new AppError(`Grok model ${model} returned empty response`, 500, "GROK_EMPTY_RESPONSE");
        return text;
    }
}
