/**
 * Sellio Metrics Backend — Redis Client Factory
 *
 * Creates an ioredis instance from REDIS_URL.
 * Gracefully degrades: if no URL is provided or connection fails,
 * the CacheService will operate in pass-through mode (all misses).
 */

import Redis from "ioredis";
import type { Logger } from "../../core/logger";

export type RedisClient = Redis | null;

export function createRedisClient({
    redisUrl,
    logger,
}: {
    redisUrl: string;
    logger: Logger;
}): RedisClient {
    if (!redisUrl) {
        logger.warn("⚠️  REDIS_URL not set — caching disabled (pass-through mode)");
        return null;
    }

    try {
        const client = new Redis(redisUrl, {
            maxRetriesPerRequest: 3,
            retryStrategy(times) {
                if (times > 5) {
                    logger.warn({ attempt: times }, "Redis retry limit reached, giving up");
                    return null; // stop retrying
                }
                return Math.min(times * 200, 2000);
            },
            lazyConnect: false,
            enableReadyCheck: true,
            connectTimeout: 5000,
        });

        client.on("connect", () => {
            logger.info("🟢 Redis connected");
        });

        client.on("error", (err) => {
            logger.warn({ err: err.message }, "🔴 Redis error (caching degraded)");
        });

        client.on("close", () => {
            logger.info("🟡 Redis connection closed");
        });

        return client;
    } catch (err: any) {
        logger.warn({ err: err.message }, "Failed to create Redis client — caching disabled");
        return null;
    }
}
