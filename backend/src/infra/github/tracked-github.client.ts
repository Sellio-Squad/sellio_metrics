/**
 * Tracked GitHub Client — Observability Decorator
 *
 * Wraps Octokit with hooks that record every GitHub API call
 * into the ObservabilityService — including rate limit headers.
 */

import type { GitHubClient } from "./github.client";
import type { ObservabilityService } from "../../modules/observability/observability.service";

export function attachTrackingHooks(
    client: GitHubClient,
    observabilityService: ObservabilityService,
): GitHubClient {
    client.hook.wrap("request", async (request, options) => {
        const url = String(options.url ?? "unknown");
        const method = String(options.method ?? "GET").toUpperCase();
        const startTime = performance.now();

        try {
            const response = await request(options);
            const durationMs = performance.now() - startTime;

            observabilityService.record({
                source: "github",
                method,
                path: url,
                statusCode: response.status,
                durationMs,
                metadata: {
                    rateLimitLimit: response.headers["x-ratelimit-limit"],
                    rateLimitRemaining: response.headers["x-ratelimit-remaining"],
                    rateLimitUsed: response.headers["x-ratelimit-used"],
                    rateLimitReset: response.headers["x-ratelimit-reset"],
                },
            });

            return response;
        } catch (error: any) {
            const durationMs = performance.now() - startTime;

            observabilityService.record({
                source: "github",
                method,
                path: url,
                statusCode: error.status ?? 500,
                durationMs,
                error: error.message ?? "Unknown GitHub API error",
                metadata: {
                    rateLimitLimit: error.response?.headers?.["x-ratelimit-limit"],
                    rateLimitRemaining: error.response?.headers?.["x-ratelimit-remaining"],
                    rateLimitUsed: error.response?.headers?.["x-ratelimit-used"],
                    rateLimitReset: error.response?.headers?.["x-ratelimit-reset"],
                },
            });

            throw error;
        }
    });

    return client;
}
