import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { LogEntry, LogCategory, LogSeverity } from "./logs.types";

const LOGS_CACHE_KEY = "system_events_log";
const MAX_LOGS = 100;
const LOGS_TTL = 7 * 24 * 60 * 60; // 7 days

export class LogsService {
    private readonly cacheService: CacheService;
    private readonly logger: Logger;

    constructor({ cacheService, logger }: { cacheService: CacheService; logger: Logger }) {
        this.cacheService = cacheService;
        this.logger = logger.child({ module: "logs" });
    }

    /**
     * Add a new log entry to the feed.
     * Silently handles cache failures to prevent interrupting core paths.
     */
    async log(
        message: string,
        severity: LogSeverity,
        category: LogCategory,
        metadata?: Record<string, any>
    ): Promise<LogEntry> {
        const entry: LogEntry = {
            id: `log_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
            timestamp: new Date().toISOString(),
            message,
            severity,
            category,
            ...(metadata && { metadata }),
        };

        try {
            const cached = await this.cacheService.get<LogEntry[]>(LOGS_CACHE_KEY);
            const logs = cached?.data || [];
            
            logs.unshift(entry);
            
            if (logs.length > MAX_LOGS) {
                logs.length = MAX_LOGS;
            }

            // Await to ensure Cloudflare does not drop the background promise!
            await this.cacheService.set(LOGS_CACHE_KEY, logs, LOGS_TTL).catch(err => {
                this.logger.warn({ err: err.message }, "Failed to persist log to KV");
            });
        } catch (err: any) {
            this.logger.warn({ err: err.message }, "Failed to read logs from KV for append");
        }

        return entry;
    }

    /**
     * Retrieve the recent logs feed
     */
    async getLogs(limit: number = 50): Promise<LogEntry[]> {
        const cached = await this.cacheService.get<LogEntry[]>(LOGS_CACHE_KEY);
        const logs = cached?.data || [];
        return logs.slice(0, limit);
    }
}
