/**
 * Sellio Metrics Backend — Cache Service (Workers KV)
 *
 * Typed caching layer using Cloudflare Workers KV.
 * Falls back to no-op (cache-miss) when no KV binding is available
 * (e.g. local development without wrangler).
 *
 * Features:
 * - JSON serialize/deserialize with key-prefix namespace (sellio:)
 * - TTL-based expiration via KV's built-in expirationTtl
 * - In-memory write-through layer within a single Worker invocation
 *   to eliminate redundant KV writes (the #1 cause of quota exhaustion)
 * - Critical keys (e.g. OAuth tokens) throw on write failure instead
 *   of silently returning, preventing false-positive isReady() checks
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

// Keys that must never fail silently — a write error throws rather than warns
const CRITICAL_KEYS = new Set(["google_oauth_tokens"]);

// ─── Service ────────────────────────────────────────────────

export class CacheService {
    private readonly kv: KVNamespace | null;
    private readonly logger: Logger;
    private readonly prefix = "sellio:";

    /**
     * In-memory write-through store.
     * Lives only for the duration of this Worker instance (single request).
     * Prevents redundant KV writes when the same key is written multiple times
     * in one request, and avoids KV reads that would always miss for just-set values.
     */
    private readonly memCache = new Map<string, { value: CachedValue<unknown>; expiresAt: number }>();

    constructor({ kvNamespace, logger }: { kvNamespace: KVNamespace | null; logger: Logger }) {
        this.kv = kvNamespace;
        this.logger = logger.child({ module: "cache" });

        if (!this.kv) {
            this.logger.warn("⚠️  No KV namespace bound — caching disabled (pass-through mode)");
        }
    }

    /**
     * Get a cached value by key.
     * Checks in-memory store first (zero latency), then falls back to KV.
     * Returns null on miss or if KV is unavailable.
     */
    async get<T>(key: string): Promise<CachedValue<T> | null> {
        // Check in-memory cache first
        const memEntry = this.memCache.get(this.prefix + key);
        if (memEntry && Date.now() < memEntry.expiresAt) {
            return memEntry.value as CachedValue<T>;
        }

        if (!this.kv) return null;

        try {
            const raw = await this.kv.get(this.prefix + key);
            if (!raw) return null;
            const parsed = JSON.parse(raw) as CachedValue<T>;
            // Populate memory cache so subsequent reads in same request are free
            this.memCache.set(this.prefix + key, {
                value: parsed as CachedValue<unknown>,
                expiresAt: Date.now() + 60_000, // mem TTL capped at 60s for freshness
            });
            return parsed;
        } catch (err: any) {
            this.logger.warn({ err: err.message, key }, "Cache get failed");
            return null;
        }
    }

    /**
     * Store a value in the cache with a TTL in seconds.
     *
     * For critical keys (like OAuth tokens), a KV write failure throws.
     * For all other keys, failures are logged and silently skipped.
     */
    async set<T>(key: string, data: T, ttlSeconds: number, etag?: string): Promise<void> {
        const value: CachedValue<T> = {
            data,
            ...(etag && { etag }),
            cachedAt: new Date().toISOString(),
        };

        // Always write to in-memory cache first (fast, always works)
        this.memCache.set(this.prefix + key, {
            value: value as CachedValue<unknown>,
            expiresAt: Date.now() + Math.min(ttlSeconds, 60) * 1000,
        });

        if (!this.kv) return;

        try {
            await this.kv.put(this.prefix + key, JSON.stringify(value), {
                expirationTtl: Math.max(ttlSeconds, 60), // KV minimum TTL is 60s
            });
        } catch (err: any) {
            if (CRITICAL_KEYS.has(key)) {
                // For critical keys, surface the error so callers know the write failed
                this.logger.error({ err: err.message, key }, "🚨 Critical KV write failed — rethrowing");
                throw new Error(`KV write failed for critical key "${key}": ${err.message}`);
            }
            this.logger.warn({ err: err.message, key }, "Cache set failed (non-critical, skipping)");
        }
    }

    /**
     * Delete a specific cache key. Returns true if successful.
     */
    async del(key: string): Promise<boolean> {
        // Remove from memory cache
        this.memCache.delete(this.prefix + key);

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
