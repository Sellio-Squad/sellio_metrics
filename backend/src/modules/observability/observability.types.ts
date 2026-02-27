/**
 * Observability Module — Domain Types (v2 — Advanced)
 *
 * Pure type definitions. No logic, no dependencies.
 * Extensible `ApiSource` union + rich aggregation types for
 * rate limits, latency percentiles, abuse detection, and dependency graph.
 */

// ─── Source Discriminator ───────────────────────────────────

export type ApiSource = "internal" | "github" | "google" | "external";

// ─── Single Call Record ─────────────────────────────────────

export interface ApiCallRecord {
    id: number;
    source: ApiSource;
    method: string;
    path: string;
    statusCode: number;
    durationMs: number;
    timestamp: string;
    error?: string;
    metadata?: Record<string, unknown>;
}

// ─── Rate Limit Info ────────────────────────────────────────

export interface RateLimitInfo {
    source: ApiSource;
    limit: number;
    remaining: number;
    used: number;
    resetAt: string;
    percentUsed: number;
}

// ─── Latency Distribution ───────────────────────────────────

export interface LatencyPercentiles {
    p50: number;
    p75: number;
    p90: number;
    p95: number;
    p99: number;
    min: number;
    max: number;
    avg: number;
}

export interface LatencyBySource {
    source: ApiSource;
    percentiles: LatencyPercentiles;
    callCount: number;
}

// ─── Abuse / Spike Detection ────────────────────────────────

export interface AbuseMetrics {
    /** Calls in the current 1-min window. */
    callsPerMinute: number;
    /** Calls in the previous 1-min window. */
    prevCallsPerMinute: number;
    /** Percentage change from previous window. */
    trend: number;
    /** True if current rate is ≥ 2x the trailing 5-min avg. */
    isSpiking: boolean;
    /** Calls per minute averaged over last 5 minutes. */
    trailingAvg5Min: number;
    /** Highest calls-per-minute seen since startup. */
    peakCallsPerMinute: number;
    /** Top offending endpoints during spikes. */
    hotEndpoints: HotEndpoint[];
}

export interface HotEndpoint {
    method: string;
    path: string;
    callsPerMinute: number;
}

// ─── Service Dependency Graph ───────────────────────────────

export interface DependencyNode {
    id: string;
    label: string;
    type: "service" | "api" | "database";
}

export interface DependencyEdge {
    from: string;
    to: string;
    callCount: number;
    avgDurationMs: number;
    errorCount: number;
    lastCallAt: string;
}

export interface DependencyGraph {
    nodes: DependencyNode[];
    edges: DependencyEdge[];
}

// ─── Source Breakdown ───────────────────────────────────────

export interface SourceBreakdown {
    source: ApiSource;
    count: number;
    avgDurationMs: number;
    errorCount: number;
    errorRate: number;
}

// ─── Slow Endpoint ──────────────────────────────────────────

export interface SlowEndpoint {
    method: string;
    path: string;
    avgDurationMs: number;
    maxDurationMs: number;
    p95DurationMs: number;
    callCount: number;
}

// ─── Recent Error ───────────────────────────────────────────

export interface RecentError {
    id: number;
    source: ApiSource;
    method: string;
    path: string;
    statusCode: number;
    error: string;
    timestamp: string;
}

// ─── Aggregated Statistics (v2) ─────────────────────────────

export interface ObservabilityStats {
    totalCalls: number;
    errorRate: number;
    uptimeMs: number;
    generatedAt: string;

    /** Latency percentiles across ALL calls. */
    latency: LatencyPercentiles;

    /** Latency broken down per source. */
    latencyBySource: LatencyBySource[];

    /** Rate limit status for tracked sources. */
    rateLimits: RateLimitInfo[];

    /** Abuse / spike metrics. */
    abuse: AbuseMetrics;

    /** Breakdown per API source. */
    callsBySource: SourceBreakdown[];

    /** Top N slowest endpoint groups. */
    slowestEndpoints: SlowEndpoint[];

    /** Most recent errors. */
    recentErrors: RecentError[];

    /** Service dependency graph. */
    dependencyGraph: DependencyGraph;
}

// ─── Query Filters ──────────────────────────────────────────

export interface CallsQueryParams {
    source?: ApiSource;
    limit?: number;
    offset?: number;
}

export interface CallsResponse {
    total: number;
    count: number;
    calls: ApiCallRecord[];
}
