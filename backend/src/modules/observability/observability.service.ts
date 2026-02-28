/**
 * Observability Module — Service (v4 — In-Memory)
 *
 * Business logic only. No HTTP concerns.
 *
 * Features:
 * - In-memory ring buffer (lightweight, no disk I/O)
 * - Latency percentiles (p50, p75, p90, p95, p99)
 * - Rate limit tracking per source (GitHub headers)
 * - Abuse / spike detection (calls-per-minute windows)
 * - Service dependency graph
 * - Source-level breakdown with error rates
 */

import type { Logger } from "../../core/logger";
import type {
    ApiCallRecord,
    ApiSource,
    ObservabilityStats,
    LatencyPercentiles,
    LatencyBySource,
    RateLimitInfo,
    AbuseMetrics,
    HotEndpoint,
    SourceBreakdown,
    SlowEndpoint,
    RecentError,
    DependencyGraph,
    DependencyNode,
    DependencyEdge,
} from "./observability.types";

// ─── Input DTO ──────────────────────────────────────────────

export interface RecordCallInput {
    source: ApiSource;
    method: string;
    path: string;
    statusCode: number;
    durationMs: number;
    error?: string;
    metadata?: Record<string, unknown>;
}

// ─── Service ────────────────────────────────────────────────

export class ObservabilityService {
    private readonly logger: Logger;
    private buffer: ApiCallRecord[] = [];
    private nextId = 1;
    private readonly maxBufferSize: number;
    private readonly startedAt = Date.now();

    // Rate limit state per source
    private readonly rateLimits = new Map<
        ApiSource,
        { limit: number; remaining: number; used: number; resetAt: string }
    >();

    // Abuse detection: per-minute call buckets
    private readonly minuteBuckets: Array<{ timestamp: number; count: number }> = [];

    // Dependency tracking
    private readonly edges = new Map<
        string,
        { from: string; to: string; count: number; totalMs: number; errors: number; lastAt: string }
    >();

    private static readonly MAX_RECENT_ERRORS = 20;
    private static readonly MAX_SLOW_ENDPOINTS = 10;
    private static readonly ABUSE_WINDOW_MINUTES = 5;

    constructor({
        logger,
        maxBufferSize = 500,
    }: {
        logger: Logger;
        maxBufferSize?: number;
    }) {
        this.logger = logger.child({ module: "observability" });
        this.maxBufferSize = maxBufferSize;

        this.logger.info(
            { maxBufferSize: this.maxBufferSize },
            "ObservabilityService v4 (in-memory) initialized",
        );
    }

    // ─── Record ─────────────────────────────────────────────

    record(input: RecordCallInput): void {
        try {
            const record: ApiCallRecord = {
                id: this.nextId++,
                source: input.source,
                method: input.method.toUpperCase(),
                path: input.path,
                statusCode: input.statusCode,
                durationMs: Math.round(input.durationMs * 100) / 100,
                timestamp: new Date().toISOString(),
                ...(input.error && { error: input.error }),
                ...(input.metadata && { metadata: input.metadata }),
            };

            // Ring buffer eviction
            if (this.buffer.length >= this.maxBufferSize) {
                this.buffer.shift();
            }
            this.buffer.push(record);

            // Update rate limits from metadata (GitHub headers)
            if (input.metadata) {
                const rl = input.metadata;
                if (rl.rateLimitRemaining !== undefined) {
                    this.rateLimits.set(input.source, {
                        limit: Number(rl.rateLimitLimit ?? rl.rateLimitRemaining) || 5000,
                        remaining: Number(rl.rateLimitRemaining) || 0,
                        used: Number(rl.rateLimitUsed ?? 0) || 0,
                        resetAt: rl.rateLimitReset
                            ? new Date(Number(rl.rateLimitReset) * 1000).toISOString()
                            : new Date(Date.now() + 3600000).toISOString(),
                    });
                }
            }

            // Update dependency graph edges
            const toNode = this.resolveTargetNode(input.source);
            if (input.source !== "internal") {
                const edgeKey = `sellio-backend→${toNode}`;
                const edge = this.edges.get(edgeKey) ?? {
                    from: "sellio-backend",
                    to: toNode,
                    count: 0,
                    totalMs: 0,
                    errors: 0,
                    lastAt: "",
                };
                edge.count++;
                edge.totalMs += input.durationMs;
                if (input.statusCode >= 400) edge.errors++;
                edge.lastAt = record.timestamp;
                this.edges.set(edgeKey, edge);
            }

            // Update abuse tracking
            this.recordMinuteBucket();
        } catch (err) {
            this.logger.warn({ err }, "Failed to record observability call");
        }
    }

    // ─── Queries ────────────────────────────────────────────

    getRecentCalls(limit = 50, offset = 0, source?: ApiSource): { total: number; calls: ApiCallRecord[] } {
        try {
            let calls = this.buffer;

            if (source) {
                calls = calls.filter((c) => c.source === source);
            }

            const total = calls.length;
            const paginated = calls.slice().reverse().slice(offset, offset + limit);

            return { total, calls: paginated };
        } catch (err) {
            this.logger.warn({ err }, "Failed to get recent calls");
            return { total: 0, calls: [] };
        }
    }

    getStats(): ObservabilityStats {
        try {
            const total = this.buffer.length;

            if (total === 0) {
                return this.emptyStats();
            }

            const durations = this.buffer.map((c) => c.durationMs).sort((a, b) => a - b);
            const errorCount = this.buffer.filter((c) => c.statusCode >= 400).length;

            return {
                totalCalls: total,
                errorRate: total > 0 ? Math.round((errorCount / total) * 10000) / 10000 : 0,
                uptimeMs: Date.now() - this.startedAt,
                generatedAt: new Date().toISOString(),
                latency: this.computePercentiles(durations),
                latencyBySource: this.computeLatencyBySource(),
                rateLimits: this.computeRateLimits(),
                abuse: this.computeAbuseMetrics(),
                callsBySource: this.computeSourceBreakdown(),
                slowestEndpoints: this.computeSlowestEndpoints(),
                recentErrors: this.computeRecentErrors(),
                dependencyGraph: this.computeDependencyGraph(),
                cacheStats: { connected: false, hits: 0, misses: 0, sets: 0, errors: 0, hitRate: 0, keyCount: 0 },
            };
        } catch (err) {
            this.logger.error({ err }, "Failed to compute stats");
            return this.emptyStats();
        }
    }

    clear(): void {
        this.buffer = [];
        this.rateLimits.clear();
        this.edges.clear();
        this.minuteBuckets.length = 0;
        this.nextId = 1;
        this.logger.info("Observability buffer cleared");
    }

    dispose(): void {
        // No-op — nothing to clean up for in-memory service
    }

    // ─── Latency Percentiles ────────────────────────────────

    private computePercentiles(sortedValues: number[]): LatencyPercentiles {
        if (sortedValues.length === 0) {
            return { p50: 0, p75: 0, p90: 0, p95: 0, p99: 0, min: 0, max: 0, avg: 0 };
        }
        return {
            p50: this.percentile(sortedValues, 50),
            p75: this.percentile(sortedValues, 75),
            p90: this.percentile(sortedValues, 90),
            p95: this.percentile(sortedValues, 95),
            p99: this.percentile(sortedValues, 99),
            min: sortedValues[0]!,
            max: sortedValues[sortedValues.length - 1]!,
            avg: Math.round(this.avg(sortedValues) * 100) / 100,
        };
    }

    private computeLatencyBySource(): LatencyBySource[] {
        const groups = new Map<ApiSource, number[]>();
        for (const call of this.buffer) {
            const list = groups.get(call.source) ?? [];
            list.push(call.durationMs);
            groups.set(call.source, list);
        }

        return Array.from(groups.entries()).map(([source, durations]) => ({
            source,
            percentiles: this.computePercentiles(durations.sort((a, b) => a - b)),
            callCount: durations.length,
        }));
    }

    // ─── Rate Limits ────────────────────────────────────────

    private computeRateLimits(): RateLimitInfo[] {
        return Array.from(this.rateLimits.entries()).map(([source, rl]) => ({
            source,
            limit: rl.limit,
            remaining: rl.remaining,
            used: rl.used,
            resetAt: rl.resetAt,
            percentUsed: rl.limit > 0 ? Math.round(((rl.limit - rl.remaining) / rl.limit) * 10000) / 10000 : 0,
        }));
    }

    // ─── Abuse / Spike Detection ────────────────────────────

    private recordMinuteBucket(): void {
        const now = Date.now();
        const currentMinute = Math.floor(now / 60000);

        const last = this.minuteBuckets[this.minuteBuckets.length - 1];
        if (last && Math.floor(last.timestamp / 60000) === currentMinute) {
            last.count++;
        } else {
            this.minuteBuckets.push({ timestamp: now, count: 1 });
        }

        // Prune buckets older than 10 minutes
        const cutoff = now - 10 * 60000;
        while (this.minuteBuckets.length > 0 && this.minuteBuckets[0]!.timestamp < cutoff) {
            this.minuteBuckets.shift();
        }
    }

    private computeAbuseMetrics(): AbuseMetrics {
        const now = Date.now();
        const currentMinute = Math.floor(now / 60000);

        const currentBucket = this.minuteBuckets.find(
            (b) => Math.floor(b.timestamp / 60000) === currentMinute,
        );
        const callsPerMinute = currentBucket?.count ?? 0;

        const prevBucket = this.minuteBuckets.find(
            (b) => Math.floor(b.timestamp / 60000) === currentMinute - 1,
        );
        const prevCallsPerMinute = prevBucket?.count ?? 0;

        const fiveMinAgo = now - ObservabilityService.ABUSE_WINDOW_MINUTES * 60000;
        const recentBuckets = this.minuteBuckets.filter((b) => b.timestamp >= fiveMinAgo);
        const totalInWindow = recentBuckets.reduce((sum, b) => sum + b.count, 0);
        const trailingAvg5Min =
            recentBuckets.length > 0
                ? Math.round(totalInWindow / Math.min(recentBuckets.length, ObservabilityService.ABUSE_WINDOW_MINUTES))
                : 0;

        const peakCallsPerMinute = this.minuteBuckets.reduce(
            (max, b) => Math.max(max, b.count),
            0,
        );

        const trend =
            prevCallsPerMinute > 0
                ? Math.round(((callsPerMinute - prevCallsPerMinute) / prevCallsPerMinute) * 100)
                : callsPerMinute > 0
                    ? 100
                    : 0;

        const isSpiking = trailingAvg5Min > 0 && callsPerMinute >= trailingAvg5Min * 2;

        return {
            callsPerMinute,
            prevCallsPerMinute,
            trend,
            isSpiking,
            trailingAvg5Min,
            peakCallsPerMinute,
            hotEndpoints: this.computeHotEndpoints(),
        };
    }

    private computeHotEndpoints(): HotEndpoint[] {
        const now = Date.now();
        const oneMinAgo = now - 60000;
        const recentCalls = this.buffer.filter(
            (c) => new Date(c.timestamp).getTime() >= oneMinAgo,
        );

        const groups = new Map<string, number>();
        for (const call of recentCalls) {
            const key = `${call.method} ${call.path}`;
            groups.set(key, (groups.get(key) ?? 0) + 1);
        }

        return Array.from(groups.entries())
            .map(([key, count]) => {
                const [method, ...pathParts] = key.split(" ");
                return { method: method!, path: pathParts.join(" "), callsPerMinute: count };
            })
            .sort((a, b) => b.callsPerMinute - a.callsPerMinute)
            .slice(0, 5);
    }

    // ─── Source Breakdown ───────────────────────────────────

    private computeSourceBreakdown(): SourceBreakdown[] {
        const groups = new Map<ApiSource, ApiCallRecord[]>();
        for (const call of this.buffer) {
            const list = groups.get(call.source) ?? [];
            list.push(call);
            groups.set(call.source, list);
        }

        return Array.from(groups.entries()).map(([source, calls]) => {
            const errors = calls.filter((c) => c.statusCode >= 400).length;
            return {
                source,
                count: calls.length,
                avgDurationMs: Math.round(this.avg(calls.map((c) => c.durationMs)) * 100) / 100,
                errorCount: errors,
                errorRate: calls.length > 0 ? Math.round((errors / calls.length) * 10000) / 10000 : 0,
            };
        });
    }

    private computeSlowestEndpoints(): SlowEndpoint[] {
        const groups = new Map<string, number[]>();
        for (const call of this.buffer) {
            const key = `${call.method} ${call.path}`;
            const durations = groups.get(key) ?? [];
            durations.push(call.durationMs);
            groups.set(key, durations);
        }

        return Array.from(groups.entries())
            .map(([key, durations]) => {
                const sorted = durations.sort((a, b) => a - b);
                const [method, ...pathParts] = key.split(" ");
                return {
                    method: method!,
                    path: pathParts.join(" "),
                    avgDurationMs: Math.round(this.avg(sorted) * 100) / 100,
                    maxDurationMs: sorted[sorted.length - 1]!,
                    p95DurationMs: this.percentile(sorted, 95),
                    callCount: sorted.length,
                };
            })
            .sort((a, b) => b.avgDurationMs - a.avgDurationMs)
            .slice(0, ObservabilityService.MAX_SLOW_ENDPOINTS);
    }

    private computeRecentErrors(): RecentError[] {
        return this.buffer
            .filter((c) => c.statusCode >= 400)
            .slice(-ObservabilityService.MAX_RECENT_ERRORS)
            .reverse()
            .map((c) => ({
                id: c.id,
                source: c.source,
                method: c.method,
                path: c.path,
                statusCode: c.statusCode,
                error: c.error ?? `HTTP ${c.statusCode}`,
                timestamp: c.timestamp,
            }));
    }

    // ─── Dependency Graph ───────────────────────────────────

    private resolveTargetNode(source: ApiSource): string {
        switch (source) {
            case "internal":
                return "sellio-backend";
            case "github":
                return "github-api";
            case "google":
                return "google-api";
            default:
                return `external-${source}`;
        }
    }

    private computeDependencyGraph(): DependencyGraph {
        const nodeSet = new Set<string>(["sellio-backend", "flutter-app"]);
        for (const edge of this.edges.values()) {
            nodeSet.add(edge.from);
            nodeSet.add(edge.to);
        }

        const nodes: DependencyNode[] = Array.from(nodeSet).map((id) => ({
            id,
            label: this.labelForNode(id),
            type: this.typeForNode(id),
        }));

        const internalCalls = this.buffer.filter((c) => c.source === "internal");
        const edges: DependencyEdge[] = [
            // Flutter → Backend
            ...(internalCalls.length > 0
                ? [
                    {
                        from: "flutter-app",
                        to: "sellio-backend",
                        callCount: internalCalls.length,
                        avgDurationMs:
                            Math.round(this.avg(internalCalls.map((c) => c.durationMs)) * 100) / 100,
                        errorCount: internalCalls.filter((c) => c.statusCode >= 400).length,
                        lastCallAt: internalCalls[internalCalls.length - 1]?.timestamp ?? "",
                    },
                ]
                : []),
            // Backend → external services
            ...Array.from(this.edges.values()).map((e) => ({
                from: e.from,
                to: e.to,
                callCount: e.count,
                avgDurationMs: e.count > 0 ? Math.round((e.totalMs / e.count) * 100) / 100 : 0,
                errorCount: e.errors,
                lastCallAt: e.lastAt,
            })),
        ];

        return { nodes, edges: edges.filter((e) => e.callCount > 0) };
    }

    private labelForNode(id: string): string {
        const labels: Record<string, string> = {
            "sellio-backend": "Sellio Backend",
            "flutter-app": "Flutter App",
            "github-api": "GitHub API",
            "google-api": "Google API",
        };
        return labels[id] ?? id;
    }

    private typeForNode(id: string): "service" | "api" | "database" {
        if (id.includes("api")) return "api";
        return "service";
    }

    // ─── Private: Empty Stats ───────────────────────────────

    private emptyStats(): ObservabilityStats {
        return {
            totalCalls: 0,
            errorRate: 0,
            uptimeMs: Date.now() - this.startedAt,
            generatedAt: new Date().toISOString(),
            latency: { p50: 0, p75: 0, p90: 0, p95: 0, p99: 0, min: 0, max: 0, avg: 0 },
            latencyBySource: [],
            rateLimits: [],
            abuse: {
                callsPerMinute: 0,
                prevCallsPerMinute: 0,
                trend: 0,
                isSpiking: false,
                trailingAvg5Min: 0,
                peakCallsPerMinute: 0,
                hotEndpoints: [],
            },
            callsBySource: [],
            slowestEndpoints: [],
            recentErrors: [],
            dependencyGraph: { nodes: [], edges: [] },
            cacheStats: { connected: false, hits: 0, misses: 0, sets: 0, errors: 0, hitRate: 0, keyCount: 0 },
        };
    }

    // ─── Private: Math Utilities ────────────────────────────

    private avg(values: number[]): number {
        if (values.length === 0) return 0;
        return values.reduce((sum, v) => sum + v, 0) / values.length;
    }

    private percentile(sortedValues: number[], pct: number): number {
        if (sortedValues.length === 0) return 0;
        const index = Math.ceil((pct / 100) * sortedValues.length) - 1;
        return Math.round(sortedValues[Math.max(0, index)]! * 100) / 100;
    }
}
