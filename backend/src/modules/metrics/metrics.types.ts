/**
 * Metrics Module — Types
 *
 * Request/response shapes specific to the metrics module.
 */

import type { PrMetric, LeaderboardEntry } from "../../core/types";

/** Query parameters for GET /api/metrics/:owner/:repo */
export interface MetricsQueryParams {
    state?: "all" | "open" | "closed";
    per_page?: number;
}

/** Route parameters for GET /api/metrics/:owner/:repo */
export interface MetricsRouteParams {
    owner: string;
    repo: string;
}

/** API response for the metrics endpoint */
export interface MetricsResponse {
    owner: string;
    repo: string;
    count: number;
    metrics: PrMetric[];
}
