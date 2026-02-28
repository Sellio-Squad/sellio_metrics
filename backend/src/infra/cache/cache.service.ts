/**
 * Sellio Metrics Backend — Cache Service (Workers KV)
 *
 * Typed caching layer using Cloudflare Workers KV.
 * Falls back to no-op (cache-miss) when no KV binding is available
 * (e.g. local development without wrangler).
 *
 * Features:
 * - JSON serialize/deserialize
 * - Key-prefix namespace (sellio:)
 * - TTL-based expiration via KV's built-in expirationTtl
 */

import type { Logger } from "../../core/logger";

// ─── Types ──────────────────────────────────────────────────

/**
 * Workers KV namespace interface.
 * Matches Cloudflare's KVNamespace API.
 */
export interface KVNamespace {
    get(key: string, options?: { type?: "text" | "json" }): Promise<string | null>;
    put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
    delete(key: string): Promise<void>;
}

export interface CachedValue<T> {
    data: T;
    etag?: string;
    cachedAt: string;
}

// ─── Service ────────────────────────────────────────────────

export class CacheService {
    private readonly kv: KVNamespace | null;
    private readonly logger: Logger;
    private readonly prefix = "sellio:";

    constructor({ kvNamespace, logger }: { kvNamespace: KVNamespace | null; logger: Logger }) {
        this.kv = kvNamespace;
        this.logger = logger.child({ module: "cache" });

        if (!this.kv) {
            this.logger.warn("⚠️  No KV namespace bound — caching disabled (pass-through mode)");
        }
    }

    /**
     * Get a cached value by key.
     * Returns null on miss or if KV is unavailable.
     */
    async get<T>(key: string): Promise<CachedValue<T> | null> {
        if (!this.kv) return null;

        try {
            const raw = await this.kv.get(this.prefix + key);
            if (!raw) return null;
            return JSON.parse(raw) as CachedValue<T>;
        } catch (err: any) {
            this.logger.warn({ err: err.message, key }, "Cache get failed");
            return null;
        }
    }

    /**
     * Store a value in the cache with a TTL in seconds.
     */
    async set<T>(key: string, data: T, ttlSeconds: number, etag?: string): Promise<void> {
        if (!this.kv) return;

        try {
            const value: CachedValue<T> = {
                data,
                ...(etag && { etag }),
                cachedAt: new Date().toISOString(),
            };

            await this.kv.put(this.prefix + key, JSON.stringify(value), {
                expirationTtl: ttlSeconds,
            });
        } catch (err: any) {
            this.logger.warn({ err: err.message, key }, "Cache set failed");
        }
    }

    /**
     * Delete a specific cache key. Returns true if successful.
     */
    async del(key: string): Promise<boolean> {
        if (!this.kv) return false;

        try {
            await this.kv.delete(this.prefix + key);
            return true;
        } catch (err: any) {
            this.logger.warn({ err: err.message, key }, "Cache del failed");
            return false;
        }
    }
}
