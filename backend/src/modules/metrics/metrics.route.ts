/**
 * Metrics Module — Route (Controller)
 *
 * HTTP layer only: validates params, calls service, shapes response.
 * No business logic, no data transformation.
 */

import { FastifyPluginAsync } from "fastify";
import type { Cradle } from "../../core/container";
import type { MetricsRouteParams, MetricsQueryParams, MetricsResponse } from "./metrics.types";
import type { PrMetric, LeaderboardEntry } from "../../core/types";

const metricsRoute: FastifyPluginAsync = async (fastify) => {
    /**
     * GET /api/metrics/:owner/:repo
     * Returns enriched PR metrics for the given repository.
     */
    fastify.get<{
        Params: MetricsRouteParams;
        Querystring: MetricsQueryParams;
    }>(
        "/:owner/:repo",
        {
            schema: {
                params: {
                    type: "object",
                    required: ["owner", "repo"],
                    properties: {
                        owner: { type: "string", minLength: 1 },
                        repo: { type: "string", minLength: 1 },
                    },
                },
                querystring: {
                    type: "object",
                    properties: {
                        state: { type: "string", enum: ["all", "open", "closed"], default: "all" },
                        per_page: { type: "integer", minimum: 1, maximum: 100, default: 100 },
                    },
                },
            },
        },
        async (request): Promise<MetricsResponse> => {
            const { metricsService } = request.diScope.cradle as Cradle;
            const { owner, repo } = request.params;
            const { state = "all", per_page = 100 } = request.query;

            const metrics = await metricsService.fetchPrMetrics(owner, repo, {
                state,
                perPage: per_page,
            });

            return {
                owner,
                repo,
                count: metrics.length,
                metrics,
            };
        },
    );

    /**
     * POST /api/metrics/leaderboard
     * Receives a filtered array of PRs and returns the calculated leaderboard.
     */
    fastify.post<{ Body: { prs: PrMetric[] } }>(
        "/leaderboard",
        async (request): Promise<LeaderboardEntry[]> => {
            const { leaderboardService } = request.diScope.cradle as Cradle;
            return leaderboardService.calculateLeaderboard(request.body.prs);
        },
    );
};

export default metricsRoute;
