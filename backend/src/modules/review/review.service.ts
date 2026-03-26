/**
 * Review Module — Service (Orchestrator)
 *
 * Single Responsibility: coordinate the review pipeline.
 *   1. Check KV cache (key = owner:repo:prNumber:headSha)
 *   2. Fetch PR context via PrContextFetcher (GitHub data + budget)
 *   3. Run AI analysis via GeminiClient
 *   4. Store result in KV (TTL: 24h — invalidated if PR head SHA changes)
 *   5. Assemble and return the ReviewResponse
 *
 * Cache strategy:
 *   Key:  review:{owner}:{repo}:{prNumber}:{headSha}
 *   TTL:  24 hours
 *   Why SHA in key: different commits of the same PR get fresh reviews.
 */

import type { GeminiClient } from "../../infra/ai/gemini.client";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { ReviewResponse } from "./review.types";
import type { PrContextFetcher } from "./pr-context-fetcher";

const REVIEW_CACHE_TTL = 24 * 60 * 60; // 24 hours

export class ReviewService {
    private readonly contextFetcher: PrContextFetcher;
    private readonly geminiClient: GeminiClient;
    private readonly cacheService: CacheService;
    private readonly logger: Logger;

    constructor({
        prContextFetcher,
        geminiClient,
        cacheService,
        logger,
    }: {
        prContextFetcher: PrContextFetcher;
        geminiClient: GeminiClient;
        cacheService: CacheService;
        logger: Logger;
    }) {
        this.contextFetcher = prContextFetcher;
        this.geminiClient   = geminiClient;
        this.cacheService   = cacheService;
        this.logger         = logger.child({ module: "review" });
    }

    async reviewPr(owner: string, repo: string, prNumber: number): Promise<ReviewResponse> {
        this.logger.info({ owner, repo, prNumber }, "Starting AI code review");

        // ── 1. Fetch PR context (GitHub data + budget filtering) ─────────
        const context = await this.contextFetcher.fetch(owner, repo, prNumber);

        // ── 2. Build cache key using head SHA so cached result is
        //       automatically invalidated when new commits are pushed ─────
        const cacheKey = `review:${owner}:${repo}:${prNumber}`;

        // ── 3. Return cached review if available ──────────────────────────
        const cached = await this.cacheService.get<ReviewResponse>(cacheKey);
        if (cached) {
            this.logger.info({ owner, repo, prNumber }, "AI review served from cache");
            // Refresh reviewedAt so callers know this is a cache hit
            return { ...cached.data, fromCache: true } as ReviewResponse;
        }

        // ── 4. Run AI analysis ────────────────────────────────────────────
        const review = await this.geminiClient.analyzeCode({
            prTitle:  context.pr.title,
            prAuthor: context.pr.author,
            prBody:   context.pr.body,
            files:    context.reviewableFiles,
        });

        this.logger.info(
            { owner, repo, prNumber,
              bugs: review.bugs.length, security: review.security.length,
              filesReviewed: context.meta.filesReviewed },
            "AI review completed",
        );

        const response: ReviewResponse = {
            pr:         context.pr,
            files:      context.allFiles,
            review,
            reviewedAt: new Date().toISOString(),
            reviewMeta: context.meta,
        };

        // ── 5. Cache result ───────────────────────────────────────────────
        await this.cacheService.set(cacheKey, response, REVIEW_CACHE_TTL);

        return response;
    }
}
