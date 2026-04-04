import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { LogEntry, LogCategory, LogSeverity } from "./logs.types";
import { getKvWriteCountForToday } from "../../infra/cache/cache-metrics";

const LOGS_CACHE_KEY  = "system_events_log";
const QUOTA_CACHE_KEY = "kv_write_counter";
const MAX_LOGS        = 200;
const LOGS_TTL        = 7 * 24 * 60 * 60; // 7 days

/**
 * Module-level state — persists across requests in the SAME isolate.
 *
 * Cloudflare Workers reuse V8 isolates, so these values survive between
 * requests on the same instance. This allows us to:
 *  (a) Buffer log entries in memory and flush to KV at most every 60s
 *      instead of on every single log() call.
 *
 * Result: ~80 KV writes per sync → 1-2 KV writes per sync.
 */
let _memBuffer:       LogEntry[]  = [];
let _lastFlushMs:     number      = 0;

/** Flush to KV at most once per this many ms (60 seconds). */
const FLUSH_INTERVAL_MS = 60_000;

function todayKey(): string {
    return new Date().toISOString().slice(0, 10); // "YYYY-MM-DD"
}

export class LogsService {
    private readonly cacheService: CacheService;
    private readonly logger: Logger;

    constructor({ cacheService, logger }: { cacheService: CacheService; logger: Logger }) {
        this.cacheService = cacheService;
        this.logger = logger.child({ module: "logs" });
    }

    /**
     * Add a new log entry to the in-memory buffer.
     * Only flushes to KV when the buffer hasn't been flushed in 60 seconds,
     * preventing quota exhaustion caused by per-entry KV writes.
     */
    async log(
        message:   string,
        severity:  LogSeverity,
        category:  LogCategory,
        metadata?: Record<string, any>,
    ): Promise<LogEntry> {
        const entry: LogEntry = {
            id:        `log_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
            timestamp: new Date().toISOString(),
            message,
            severity,
            category,
            ...(metadata && { metadata }),
        };

        // Always add to in-memory buffer
        _memBuffer.unshift(entry);
        if (_memBuffer.length > MAX_LOGS) _memBuffer.length = MAX_LOGS;

        // Only flush to KV if the cooldown has elapsed
        const now = Date.now();
        if (now - _lastFlushMs >= FLUSH_INTERVAL_MS) {
            await this._flush();
        }

        return entry;
    }

    /**
     * Force-flush the in-memory buffer to KV immediately.
     * Called by getLogs() to ensure fresh data is returned even if
     * the cooldown hasn't elapsed since the last flush.
     */
    private async _flush(): Promise<void> {
        try {
            // Merge in-memory buffer with any entries already in KV
            const cached = await this.cacheService.get<LogEntry[]>(LOGS_CACHE_KEY);
            const kvLogs = cached?.data ?? [];

            // Merge: in-memory entries are newest, then append older KV entries
            const existingIds = new Set(_memBuffer.map((e) => e.id));
            const merged = [..._memBuffer, ...kvLogs.filter((e) => !existingIds.has(e.id))];
            if (merged.length > MAX_LOGS) merged.length = MAX_LOGS;

            await this.cacheService.set(LOGS_CACHE_KEY, merged, LOGS_TTL);

            // Also persist write count for quota display
            await this._persistWriteCount();

            _lastFlushMs = Date.now();
        } catch (err: any) {
            // Non-fatal — logs are still in _memBuffer for this isolate's lifetime
            this.logger.warn({ err: err.message }, "Log flush to KV failed (non-critical)");
        }
    }

    private async _persistWriteCount(): Promise<void> {
        try {
            await this.cacheService.set(QUOTA_CACHE_KEY, {
                day:    todayKey(),
                writes: getKvWriteCountForToday(), // Always fetches global isolate count
            }, 25 * 60 * 60); // TTL slightly > 24h
        } catch { /* non-critical */ }
    }

    /**
     * Retrieve recent logs — flushes in-memory buffer first to merge with KV state.
     */
    async getLogs(limit = 50): Promise<LogEntry[]> {
        // Flush first so the response always reflects the latest in-memory entries
        await this._flush();
        const cached = await this.cacheService.get<LogEntry[]>(LOGS_CACHE_KEY);
        return (cached?.data ?? []).slice(0, limit);
    }

    /**
     * Return KV write quota usage for today (estimated from this isolate's counter).
     */
    async getQuotaStats(): Promise<{ day: string; writesThisIsolate: number; writesTotal: number }> {
        const cached = await this.cacheService.get<{ day: string; writes: number }>(QUOTA_CACHE_KEY);
        const today  = todayKey();
        return {
            day:                today,
            writesThisIsolate:  getKvWriteCountForToday(),
            writesTotal:        cached?.data?.day === today ? cached.data.writes : 0,
        };
    }

    async clearLogs(): Promise<void> {
        _memBuffer   = [];
        _lastFlushMs = 0;
        await this.cacheService.del(LOGS_CACHE_KEY);
        this.logger.info("Logs feed cleared explicitly");
    }
}
