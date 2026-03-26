/**
 * Review Module — Service
 *
 * Orchestrates fetching the PR from GitHub and sending it
 * to Gemini for structured AI code review.
 *
 * ─── Budget enforcement (prevents OOM / timeout / token overflow) ──────────
 *
 *  MAX_FILES_TO_REVIEW  = 15   files sent to Gemini (after filtering)
 *  MAX_PATCH_CHARS      = 2500 chars per file patch (hard truncation)
 *  MAX_TOTAL_CHARS      = 30000 total diff chars across all files
 *
 *  Files are filtered (skip binaries/lock files/assets) then sorted by
 *  change magnitude so the most impactful files are always reviewed first.
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { GeminiClient } from "../../infra/ai/gemini.client";
import type { Logger } from "../../core/logger";
import type { ReviewResponse, PrFileChange } from "./review.types";

// ─── Budget constants ────────────────────────────────────────────────────────

/** Maximum number of files passed to Gemini */
const MAX_FILES_TO_REVIEW = 15;

/** Max characters of patch per file before truncation */
const MAX_PATCH_CHARS = 2500;

/** Max total characters of all patches combined */
const MAX_TOTAL_CHARS = 30_000;

/** File patterns that are never worth reviewing */
const SKIP_PATTERNS = [
    // Lock / generated files
    /package-lock\.json$/i,
    /yarn\.lock$/i,
    /pnpm-lock\.yaml$/i,
    /Podfile\.lock$/i,
    /Gemfile\.lock$/i,
    /pubspec\.lock$/i,
    /\.lock$/i,
    /\.g\.dart$/i,      // Dart generated (build_runner)
    /\.freezed\.dart$/i,
    /\.gr\.dart$/i,     // auto_route generated
    /injection\.config\.dart$/i,
    // Assets / binary-ish
    /\.(png|jpg|jpeg|gif|svg|ico|webp|mp4|mp3|otf|ttf|woff2?)$/i,
    // Changelogs / docs only
    /CHANGELOG\.md$/i,
    /LICENCE(\.md)?$/i,
    /LICENSE(\.md)?$/i,
    // Large data files
    /\.json$/i,  // will allow if small, filtered below
    /\.csv$/i,
    /\.sql$/i,
];

const ALWAYS_ALLOW_PATTERNS = [
    // Re-allow small JSON that might be config
    /tsconfig.*\.json$/i,
    /\.eslintrc.*\.json$/i,
    /pubspec\.yaml$/i,
];

// ─── Service ─────────────────────────────────────────────────────────────────

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

        const allFiles: PrFileChange[] = rawFiles.map((f: any) => ({
            filename: f.filename,
            status: f.status,
            additions: f.additions ?? 0,
            deletions: f.deletions ?? 0,
            changes: f.changes ?? 0,
            patch: f.patch,
            previousFilename: f.previous_filename,
        }));

        // 3. Apply budget: filter → sort → cap → truncate
        const { reviewableFiles, skippedFiles, totalCharsUsed } = this._applyBudget(allFiles);

        this.logger.info(
            {
                owner, repo, prNumber,
                totalFiles: allFiles.length,
                reviewableFiles: reviewableFiles.length,
                skippedFiles,
                totalCharsUsed,
            },
            "Budget applied — sending to Gemini",
        );

        // 4. Send to Gemini for AI analysis
        const review = await this.geminiClient.analyzeCode({
            prTitle: pr.title,
            prAuthor: pr.user?.login ?? "unknown",
            prBody: pr.body ? pr.body.slice(0, 500) : null, // cap body too
            files: reviewableFiles.map((f) => ({
                filename: f.filename,
                status: f.status,
                additions: f.additions,
                deletions: f.deletions,
                patch: f.patch,
            })),
        });

        this.logger.info(
            { owner, repo, prNumber, bugs: review.bugs.length, security: review.security.length },
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
                changedFiles: pr.changed_files ?? allFiles.length,
                createdAt: pr.created_at,
                body: pr.body ?? null,
            },
            files: allFiles,          // Return ALL files for display, not just reviewed
            review,
            reviewedAt: new Date().toISOString(),
            reviewMeta: {
                totalFiles: allFiles.length,
                filesReviewed: reviewableFiles.length,
                filesSkipped: skippedFiles,
                totalCharsReviewed: totalCharsUsed,
                charBudget: MAX_TOTAL_CHARS,
            },
        };
    }

    // ─── Budget logic ───────────────────────────────────────────────────────

    private _applyBudget(files: PrFileChange[]): {
        reviewableFiles: PrFileChange[];
        skippedFiles: number;
        totalCharsUsed: number;
    } {
        // Step 1: Filter out non-reviewable files
        const filtered = files.filter((f) => {
            // Always skip deleted-only files (no patch = nothing to review)
            if (f.status === "removed" && !f.patch) return false;
            // Allow if it matches an always-allow pattern
            if (ALWAYS_ALLOW_PATTERNS.some((p) => p.test(f.filename))) return true;
            // Skip if it matches a skip pattern
            if (SKIP_PATTERNS.some((p) => p.test(f.filename))) return false;
            // Skip if no patch (binary file)
            if (!f.patch) return false;
            return true;
        });

        // Step 2: Sort by impact — most-changed files first (modified > added)
        const sorted = filtered.sort((a, b) => {
            // Prioritise files with actual patch content
            const aHasPatch = a.patch ? 1 : 0;
            const bHasPatch = b.patch ? 1 : 0;
            if (aHasPatch !== bHasPatch) return bHasPatch - aHasPatch;
            // Then by magnitude (total lines changed)
            return (b.additions + b.deletions) - (a.additions + a.deletions);
        });

        // Step 3: Apply file cap + total char budget
        const reviewable: PrFileChange[] = [];
        let totalChars = 0;

        for (const file of sorted) {
            if (reviewable.length >= MAX_FILES_TO_REVIEW) break;
            if (totalChars >= MAX_TOTAL_CHARS) break;

            // Truncate patch if it would blow the per-file budget
            const patchFull = file.patch ?? "";
            const patchTruncated = patchFull.length > MAX_PATCH_CHARS
                ? patchFull.slice(0, MAX_PATCH_CHARS) + "\n... [truncated — file too large]"
                : patchFull;

            const charsForThisFile = patchTruncated.length;
            // Skip if adding this file alone would exceed budget
            if (totalChars + charsForThisFile > MAX_TOTAL_CHARS && reviewable.length > 0) break;

            reviewable.push({ ...file, patch: patchTruncated });
            totalChars += charsForThisFile;
        }

        return {
            reviewableFiles: reviewable,
            skippedFiles: files.length - reviewable.length,
            totalCharsUsed: totalChars,
        };
    }
}
