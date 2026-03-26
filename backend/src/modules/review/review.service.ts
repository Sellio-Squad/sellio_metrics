/**
 * Review Module — Service
 *
 * Orchestrates fetching the PR from GitHub and sending it
 * to Gemini for structured AI code review.
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { GeminiClient } from "../../infra/ai/gemini.client";
import type { Logger } from "../../core/logger";
import type { ReviewResponse, PrFileChange } from "./review.types";

export class ReviewService {
    private readonly cachedGithubClient: CachedGitHubClient;
    private readonly geminiClient: GeminiClient;
    private readonly logger: Logger;

    constructor({
        cachedGithubClient,
        geminiClient,
        logger,
    }: {
        cachedGithubClient: CachedGitHubClient;
        geminiClient: GeminiClient;
        logger: Logger;
    }) {
        this.cachedGithubClient = cachedGithubClient;
        this.geminiClient = geminiClient;
        this.logger = logger.child({ module: "review" });
    }

    async reviewPr(owner: string, repo: string, prNumber: number): Promise<ReviewResponse> {
        this.logger.info({ owner, repo, prNumber }, "Starting AI code review");

        // 1. Fetch PR metadata
        const pr = await this.cachedGithubClient.getPull(owner, repo, prNumber, false);

        // 2. Fetch changed files with diffs
        const rawFiles = await this.cachedGithubClient.listPrFiles(owner, repo, prNumber);

        const files: PrFileChange[] = rawFiles.map((f: any) => ({
            filename: f.filename,
            status: f.status,
            additions: f.additions ?? 0,
            deletions: f.deletions ?? 0,
            changes: f.changes ?? 0,
            patch: f.patch,
            previousFilename: f.previous_filename,
        }));

        // 3. Send to Gemini for AI analysis
        const review = await this.geminiClient.analyzeCode({
            prTitle: pr.title,
            prAuthor: pr.user?.login ?? "unknown",
            prBody: pr.body ?? null,
            files: files.map((f) => ({
                filename: f.filename,
                status: f.status,
                additions: f.additions,
                deletions: f.deletions,
                patch: f.patch,
            })),
        });

        this.logger.info(
            {
                owner, repo, prNumber,
                bugs: review.bugs.length,
                security: review.security.length,
                performance: review.performance.length,
            },
            "AI review completed",
        );

        return {
            pr: {
                number: pr.number,
                title: pr.title,
                author: pr.user?.login ?? "unknown",
                url: pr.html_url,
                state: pr.state,
                additions: pr.additions ?? 0,
                deletions: pr.deletions ?? 0,
                changedFiles: pr.changed_files ?? files.length,
                createdAt: pr.created_at,
                body: pr.body ?? null,
            },
            files,
            review,
            reviewedAt: new Date().toISOString(),
        };
    }
}
