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
import type { Logger } from "pino";
import type { ReviewResponse } from "./review.types";
import type { PrContextFetcher } from "./pr-context-fetcher";
import type { CachedGitHubClient } from "../../infra/github/cached-github.client";

const REVIEW_CACHE_TTL = 24 * 60 * 60; // 24 hours

export class ReviewService {
    private readonly contextFetcher: PrContextFetcher;
    private readonly geminiClient: GeminiClient;
    private readonly cacheService: CacheService;
    private readonly github: CachedGitHubClient;
    private readonly gitOps: any;
    private readonly logger: Logger;

    constructor({
        prContextFetcher,
        geminiClient,
        cacheService,
        cachedGithubClient,
        gitOpsService,
        logger,
    }: {
        prContextFetcher: PrContextFetcher;
        geminiClient: GeminiClient;
        cacheService: CacheService;
        cachedGithubClient: CachedGitHubClient;
        gitOpsService: any;
        logger: Logger;
    }) {
        this.contextFetcher = prContextFetcher;
        this.geminiClient   = geminiClient;
        this.cacheService   = cacheService;
        this.github         = cachedGithubClient;
        this.gitOps         = gitOpsService;
        this.logger         = logger.child({ module: "review" });
    }

    async reviewPr(owner: string, repo: string, prNumber: number): Promise<ReviewResponse> {
        this.logger.info({ owner, repo, prNumber }, "Starting AI code review");

        // ── 1. Fetch cheap PR metadata to get head branch SHA ─────────
        const prMeta = await this.github.getPull(owner, repo, prNumber);
        const headSha = prMeta?.head?.sha ?? "no-sha";

        if (headSha === "no-sha") {
            this.logger.warn({ owner, repo, prNumber }, "PR metadata missing head.sha structure; using 'no-sha' fallback");
        }

        // ── 2. Build cache key using head SHA so cached result is
        //       automatically invalidated when new commits are pushed ─────
        const cacheKey = `review:${owner}:${repo}:${prNumber}:${headSha}`;

        // ── 3. Return cached review if available ──────────────────────────
        const cached = await this.cacheService.get<ReviewResponse>(cacheKey);
        if (cached) {
            this.logger.info({ owner, repo, prNumber, headSha }, "AI review served from cache");
            // Refresh reviewedAt so callers know this is a cache hit
            return { ...cached.data, fromCache: true } as ReviewResponse;
        }

        // ── 4. Cache miss — fetch full PR context (files, diffs, etc) ─────────
        const context = await this.contextFetcher.fetch(owner, repo, prNumber, prMeta);

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
            fromCache:  false,
        };

        // ── 5. Cache result ───────────────────────────────────────────────
        await this.cacheService.set(cacheKey, response, REVIEW_CACHE_TTL);

        return response;
    }

    /**
     * Run (or reuse the cached) review for a PR and post it as a comment on the PR.
     * Returns the review plus a flag indicating the comment was posted.
     */
    async postReviewToPr(owner: string, repo: string, prNumber: number): Promise<ReviewResponse & { posted: boolean }> {
        const review = await this.reviewPr(owner, repo, prNumber);
        const markdown = this.formatReviewComment(review);
        await this.gitOps.commentOnIssue(owner, repo, prNumber, markdown);
        this.logger.info({ owner, repo, prNumber }, "Posted AI review comment to PR");
        return { ...review, posted: true };
    }

    /** Render a ReviewResponse as a GitHub-flavored markdown comment. */
    private formatReviewComment(review: ReviewResponse): string {
        const r = review.review;
        const totalIssues = r.bugs.length + r.bestPractices.length + r.security.length + r.performance.length;

        const sevEmoji = (s: string) => (s === "critical" ? "🔴" : s === "warning" ? "🟠" : "🔵");

        const section = (title: string, emoji: string, findings: typeof r.bugs): string => {
            if (!findings.length) return "";
            const rows = findings.map((f) => {
                const loc = f.line ? `\`${f.file}:${f.line}\`` : `\`${f.file}\``;
                const suggestion = f.suggestion ? `\n  - 💡 ${f.suggestion}` : "";
                return `- ${sevEmoji(f.severity)} **${f.title}** — ${loc}\n  - ${f.description}${suggestion}`;
            }).join("\n");
            return `\n### ${emoji} ${title} (${findings.length})\n${rows}\n`;
        };

        const header = totalIssues === 0
            ? "✅ **No issues found** — this PR looks good!"
            : `Found **${totalIssues}** item(s) across ${review.reviewMeta.filesReviewed}/${review.reviewMeta.totalFiles} files reviewed.`;

        const body = [
            `## 🤖 Sellio AI Code Review`,
            ``,
            `> ${r.prSummary}`,
            ``,
            header,
            section("Bugs", "🐛", r.bugs),
            section("Security", "🛡️", r.security),
            section("Performance", "⚡", r.performance),
            section("Best Practices", "✨", r.bestPractices),
            ``,
            `---`,
            `<sub>Automated review${review.fromCache ? " (from cache)" : ""} · reviewed ${review.reviewMeta.filesReviewed}/${review.reviewMeta.totalFiles} files. Not a substitute for human review.</sub>`,
        ].join("\n");

        // Collapse any run of 3+ newlines (from empty sections) down to a clean paragraph break.
        return body.replace(/\n{3,}/g, "\n\n");
    }
}
