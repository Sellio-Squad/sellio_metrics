/**
 * Sellio Metrics Backend — Cache Service
 *
 * Typed caching layer wrapping Redis.
 * Gracefully degrades to cache-miss on every call if Redis is unavailable.
 *
 * Features:
 * - JSON serialize/deserialize
 * - Key-prefix namespace (sellio:)
 * - ETag storage alongside cached values
 * - Cache stats tracking for observability
 */

import type { RedisClient } from "./cache.client";
import type { Logger } from "../../core/logger";

// ─── Types ──────────────────────────────────────────────────

export interface CachedValue<T> {
    data: T;
    etag?: string;
    cachedAt: string;
}

export interface CacheStats {
    connected: boolean;
    hits: number;
    misses: number;
    sets: number;
    errors: number;
    hitRate: number;
    keyCount: number;
}

// ─── Service ────────────────────────────────────────────────

export class CacheService {
    private readonly redis: RedisClient;
    private readonly logger: Logger;
    private readonly prefix = "sellio:";

    // Stats counters
    private hits = 0;
    private misses = 0;
    private sets = 0;
    private errors = 0;

    constructor({ redisClient, logger }: { redisClient: RedisClient; logger: Logger }) {
        this.redis = redisClient;
        this.logger = logger.child({ module: "cache" });
    }

    /** Whether Redis is connected and available. */
    get isConnected(): boolean {
        return this.redis !== null && this.redis.status === "ready";
    }

    /**
     * Get a cached value by key.
     * Returns null on miss or if Redis is unavailable.
     */
    async get<T>(key: string): Promise<CachedValue<T> | null> {
        if (!this.redis) {
            this.misses++;
            return null;
        }

        try {
            const raw = await this.redis.get(this.prefix + key);
            if (!raw) {
                this.misses++;
                return null;
            }

            this.hits++;
            return JSON.parse(raw) as CachedValue<T>;
        } catch (err: any) {
            this.errors++;
            this.logger.warn({ err: err.message, key }, "Cache get failed");
            return null;
        }
    }

    /**
     * Store a value in the cache with a TTL in seconds.
     */
    async set<T>(key: string, data: T, ttlSeconds: number, etag?: string): Promise<void> {
        if (!this.redis) return;

        try {
            const value: CachedValue<T> = {
                data,
                ...(etag && { etag }),
                cachedAt: new Date().toISOString(),
            };

            await this.redis.setex(this.prefix + key, ttlSeconds, JSON.stringify(value));
            this.sets++;
        } catch (err: any) {
            this.errors++;
            this.logger.warn({ err: err.message, key }, "Cache set failed");
        }
    }

    /**
     * Delete a specific cache key. Returns true if the key existed.
     */
    async del(key: string): Promise<boolean> {
        if (!this.redis) return false;

        try {
            const result = await this.redis.del(this.prefix + key);
            return result > 0;
        } catch (err: any) {
            this.errors++;
            this.logger.warn({ err: err.message, key }, "Cache del failed");
            return false;
        }
    }

    /**
     * Delete keys matching a pattern (e.g. "github:repos:*").
     */
    async invalidate(pattern: string): Promise<number> {
        if (!this.redis) return 0;

        try {
            const keys = await this.redis.keys(this.prefix + pattern);
            if (keys.length === 0) return 0;

            const deleted = await this.redis.del(...keys);
            this.logger.info({ pattern, deleted }, "Cache invalidated");
            return deleted;
        } catch (err: any) {
            this.errors++;
            this.logger.warn({ err: err.message, pattern }, "Cache invalidate failed");
            return 0;
        }
    }

    /**
     * Get cache stats for the observability dashboard.
     */
    async getStats(): Promise<CacheStats> {
        const total = this.hits + this.misses;
        let keyCount = 0;

        if (this.redis) {
            try {
                const keys = await this.redis.keys(this.prefix + "*");
                keyCount = keys.length;
            } catch {
                // ignore
            }
        }

        return {
            connected: this.isConnected,
            hits: this.hits,
            misses: this.misses,
            sets: this.sets,
            errors: this.errors,
            hitRate: total > 0 ? Math.round((this.hits / total) * 10000) / 10000 : 0,
            keyCount,
        };
    }

    /** Reset stats (useful for testing). */
    resetStats(): void {
        this.hits = 0;
        this.misses = 0;
        this.sets = 0;
        this.errors = 0;
    }
}
