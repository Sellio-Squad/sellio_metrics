/**
 * Sellio Metrics Backend — Rate Limit Guard
 *
 * Pre-flight checker for GitHub API rate limits.
 * Before issuing batch requests, checks remaining quota
 * and auto-delays if quota is running low.
 */

import type { Logger } from "../../core/logger";

export class RateLimitGuard {
    private readonly logger: Logger;
    private readonly threshold: number;

    // In-memory tracking of last known rate-limit state
    private remaining = 5000;
    private limit = 5000;
    private resetAt = 0; // unix timestamp in seconds

    constructor({
        logger,
        githubRateLimitThreshold = 100,
    }: {
        logger: Logger;
        githubRateLimitThreshold?: number;
    }) {
        this.logger = logger.child({ module: "rate-limit-guard" });
        this.threshold = githubRateLimitThreshold;
    }

    /**
     * Update internal state from response headers.
     * Called by the cached client after each GitHub API response.
     */
    updateFromHeaders(headers: Record<string, string | undefined>): void {
        const remaining = headers["x-ratelimit-remaining"];
        const limit = headers["x-ratelimit-limit"];
        const reset = headers["x-ratelimit-reset"];

        if (remaining !== undefined) this.remaining = parseInt(remaining, 10) || 0;
        if (limit !== undefined) this.limit = parseInt(limit, 10) || 5000;
        if (reset !== undefined) this.resetAt = parseInt(reset, 10) || 0;
    }

    /**
     * Check if we're safe to proceed with API calls.
     * If quota is low, waits until reset time.
     * Returns true if safe to proceed, false if we had to abort.
     */
    async checkAndWait(): Promise<boolean> {
        if (this.remaining > this.threshold) {
            return true;
        }

        const nowSeconds = Math.floor(Date.now() / 1000);
        const waitSeconds = Math.max(0, this.resetAt - nowSeconds) + 1;

        this.logger.warn(
            {
                remaining: this.remaining,
                limit: this.limit,
                threshold: this.threshold,
                resetAt: new Date(this.resetAt * 1000).toISOString(),
                waitSeconds,
            },
            "⚠️  GitHub rate limit approaching — delaying requests",
        );

        // If wait is too long (> 60 seconds), don't block the request
        if (waitSeconds > 60) {
            this.logger.error(
                { waitSeconds },
                "Rate limit reset too far in the future — proceeding without delay",
            );
            return true;
        }

        // Wait until reset
        await new Promise((resolve) => setTimeout(resolve, waitSeconds * 1000));

        this.logger.info("Rate limit reset — resuming requests");
        return true;
    }

    /**
     * Get a quick status snapshot.
     */
    getStatus(): { remaining: number; limit: number; resetAt: string; isLow: boolean } {
        return {
            remaining: this.remaining,
            limit: this.limit,
            resetAt: this.resetAt > 0 ? new Date(this.resetAt * 1000).toISOString() : "",
            isLow: this.remaining <= this.threshold,
        };
    }
}
