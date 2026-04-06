/**
 * Review — PrContextFetcher
 *
 * Single Responsibility: fetch PR metadata + files from GitHub,
 * apply the analysis budget (filter → sort → cap → truncate),
 * and return a clean PrContext ready for Gemini.
 *
 * ReviewService should NOT know about GitHub or budget logic.
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { Logger } from "../../core/logger";
import type { PrFileChange } from "./review.types";

// ─── Output shape ────────────────────────────────────────────

export interface PrContext {
    pr: {
        number: number;
        title: string;
        author: string;
        url: string;
        state: string;
        additions: number;
        deletions: number;
        changedFiles: number;
        createdAt: string;
        body: string | null;
    };
    /** All files (for display in UI, not for Gemini) */
    allFiles: PrFileChange[];
    /** Budget-filtered files sent to Gemini */
    reviewableFiles: Array<{
        filename: string;
        status: string;
        additions: number;
        deletions: number;
        patch?: string;
    }>;
    meta: {
        totalFiles: number;
        filesReviewed: number;
        filesSkipped: number;
        totalCharsReviewed: number;
        charBudget: number;
    };
}

// ─── Budget constants ────────────────────────────────────────

const MAX_FILES   = 15;
const MAX_PATCH   = 2_500;
const MAX_TOTAL   = 30_000;
const MAX_PR_BODY = 500;

/** Patterns that are never worth reviewing */
const SKIP = [
    /package-lock\.json$/i, /yarn\.lock$/i, /pnpm-lock\.yaml$/i,
    /Podfile\.lock$/i, /Gemfile\.lock$/i, /pubspec\.lock$/i, /\.lock$/i,
    /\.g\.dart$/i, /\.freezed\.dart$/i, /\.gr\.dart$/i,
    /injection\.config\.dart$/i,
    /\.(png|jpg|jpeg|gif|svg|ico|webp|mp4|mp3|otf|ttf|woff2?)$/i,
    /CHANGELOG\.md$/i, /LICEN[CS]E(\.md)?$/i,
    /\.csv$/i, /\.sql$/i,
];

/** Exceptions to SKIP (small config files worth reviewing) */
const ALLOW = [
    /tsconfig.*\.json$/i,
    /\.eslintrc.*\.json$/i,
    /pubspec\.yaml$/i,
];

// ─── Fetcher ─────────────────────────────────────────────────

export class PrContextFetcher {
    private readonly github: CachedGitHubClient;
    private readonly logger: Logger;

    constructor({ cachedGithubClient, logger }: {
        cachedGithubClient: CachedGitHubClient;
        logger: Logger;
    }) {
        this.github = cachedGithubClient;
        this.logger = logger.child({ module: "pr-context" });
    }

    async fetch(owner: string, repo: string, prNumber: number, prMeta?: any): Promise<PrContext> {
        // Fetch in parallel — PR metadata (if not provided) and file list are independent
        const [pr, rawFiles] = await Promise.all([
            prMeta ? Promise.resolve(prMeta) : this.github.getPull(owner, repo, prNumber),
            this.github.listPrFiles(owner, repo, prNumber),
        ]);

        const allFiles: PrFileChange[] = rawFiles.map((f: any) => ({
            filename:         f.filename,
            status:           f.status,
            additions:        f.additions  ?? 0,
            deletions:        f.deletions  ?? 0,
            changes:          f.changes    ?? 0,
            patch:            f.patch,
            previousFilename: f.previous_filename,
        }));

        const { reviewable, skipped, totalChars } = this._applyBudget(allFiles);

        this.logger.info(
            { owner, repo, prNumber,
              total: allFiles.length, reviewable: reviewable.length,
              skipped, chars: totalChars },
            "PR context built",
        );

        return {
            pr: {
                number:       pr.number,
                title:        pr.title,
                author:       pr.user?.login ?? "unknown",
                url:          pr.html_url,
                state:        pr.state,
                additions:    pr.additions     ?? 0,
                deletions:    pr.deletions     ?? 0,
                changedFiles: pr.changed_files ?? allFiles.length,
                createdAt:    pr.created_at,
                body:         pr.body ? (pr.body as string).slice(0, MAX_PR_BODY) : null,
            },
            allFiles,
            reviewableFiles: reviewable,
            meta: {
                totalFiles:         allFiles.length,
                filesReviewed:      reviewable.length,
                filesSkipped:       skipped,
                totalCharsReviewed: totalChars,
                charBudget:         MAX_TOTAL,
            },
        };
    }

    // ─── Budget logic ───────────────────────────────────────

    private _applyBudget(files: PrFileChange[]) {
        // 1. Filter
        const filtered = files.filter((f) => {
            if (f.status === "removed" && !f.patch) return false;
            if (ALLOW.some((p) => p.test(f.filename)))  return true;
            if (SKIP.some((p)  => p.test(f.filename)))  return false;
            if (!f.patch) return false;  // binary
            return true;
        });

        // 2. Sort by impact descending
        filtered.sort((a, b) =>
            (b.additions + b.deletions) - (a.additions + a.deletions),
        );

        // 3. Cap by file count + total char budget
        const reviewable: Array<{ filename: string; status: string; additions: number; deletions: number; patch?: string }> = [];
        let totalChars = 0;

        for (const f of filtered) {
            if (reviewable.length >= MAX_FILES) break;
            if (totalChars >= MAX_TOTAL)        break;

            const raw       = f.patch ?? "";
            const truncated = raw.length > MAX_PATCH
                ? raw.slice(0, MAX_PATCH) + "\n... [truncated]"
                : raw;

            if (totalChars + truncated.length > MAX_TOTAL) break;

            reviewable.push({ filename: f.filename, status: f.status, additions: f.additions, deletions: f.deletions, patch: truncated });
            totalChars += truncated.length;
        }

        return { reviewable, skipped: files.length - reviewable.length, totalChars };
    }
}
