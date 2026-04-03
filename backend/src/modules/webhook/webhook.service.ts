/**
 * Webhook Service — Decoupled Business Logic
 *
 * Pure business logic handlers for each GitHub event type.
 * The route layer dispatches to these methods after validation,
 * signature verification, and deduplication.
 *
 * Design:
 *  - No HTTP concerns (no c.json, no c.req)
 *  - Independent DB operations run in parallel via Promise.all
 *  - No unsafe `as string` casts — uses Zod-parsed types
 *  - Returns structured results for the route to serialize
 */

import type { Logger } from "../../core/logger";
import type { ReposRepository } from "../repos/repos.repository";
import type { DeveloperRepository } from "../developers/developer.repository";
import type { PrsRepository } from "../prs/prs.repository";
import type { CommentsRepository } from "../prs/comments.repository";
import type { CommitsRepository } from "../commits/commits.repository";
import type { OpenPrsService } from "../prs/open-prs.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { CacheRegistry } from "../../infra/cache/cache-registry";
import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import { GitHubGraphQLClient } from "../../infra/github/github-graphql.client";
import { isBot } from "../../lib/bot-filter";
import type {
    PullRequestPayload,
    IssueCommentPayload,
    ReviewCommentPayload,
    OrgMembershipPayload,
    PushPayload,
} from "./webhook.schemas";

export interface WebhookHandlerResult {
    affectedDevelopers: string[];
}

interface WebhookServiceDeps {
    logger: Logger;
    reposRepo: ReposRepository;
    developerRepo: DeveloperRepository;
    prsRepo: PrsRepository;
    commentsRepo: CommentsRepository;
    commitsRepo: CommitsRepository;
    openPrsService: OpenPrsService;
    cache: CacheRegistry;
    cachedGithubClient?: CachedGitHubClient;
    env: { org: string };
}

export class WebhookService {
    private readonly logger: Logger;
    private readonly reposRepo: ReposRepository;
    private readonly developerRepo: DeveloperRepository;
    private readonly prsRepo: PrsRepository;
    private readonly commentsRepo: CommentsRepository;
    private readonly commitsRepo: CommitsRepository;
    private readonly openPrsService: OpenPrsService;
    private readonly cache: CacheRegistry;
    private readonly cachedGithubClient?: CachedGitHubClient;
    private readonly org: string;

    constructor(deps: WebhookServiceDeps) {
        this.logger        = deps.logger.child({ module: "webhook-service" });
        this.reposRepo     = deps.reposRepo;
        this.developerRepo = deps.developerRepo;
        this.prsRepo       = deps.prsRepo;
        this.commentsRepo  = deps.commentsRepo;
        this.commitsRepo   = deps.commitsRepo;
        this.openPrsService = deps.openPrsService;
        this.cache         = deps.cache;
        this.cachedGithubClient = deps.cachedGithubClient;
        this.org           = deps.env.org;
    }

    // ─── Pull Request (merged) ──────────────────────────────

    async handlePullRequest(payload: PullRequestPayload): Promise<WebhookHandlerResult> {
        const affectedDevelopers: string[] = [];
        const action = payload.action;
        const pr     = payload.pull_request;
        const repo   = payload.repository;
        const org    = repo.owner?.login ?? this.org;

        // Invalidate open-PRs cache (non-blocking, logged on error)
        this.invalidatePrCache(org);

        // Only process merged PRs
        if (action !== "closed" || !pr.merged) {
            return { affectedDevelopers };
        }

        const author = pr.user?.login;
        if (!author || isBot(author, pr.user?.type)) {
            return { affectedDevelopers };
        }

        const repoOwner = repo.owner?.login ?? org;

        // Parallel: upsert repo + upsert developer (independent operations)
        const [repoId] = await Promise.all([
            this.reposRepo.upsertRepo(repo.id, repoOwner, repo.name, { htmlUrl: repo.html_url }),
            this.developerRepo.upsertDeveloper(author, pr.user?.avatar_url, pr.user?.name ?? undefined),
        ]);

        await this.prsRepo.upsertMergedPr({
            id:          pr.id,
            repoId,
            prNumber:    pr.number,
            author,
            title:       pr.title,
            htmlUrl:     pr.html_url,
            mergedAt:    pr.merged_at || pr.closed_at || new Date().toISOString(),
            prCreatedAt: pr.created_at,
            additions:   pr.additions ?? 0,
            deletions:   pr.deletions ?? 0,
        });

        // The PR is now merged! Let's fetch all historical comments it accumulated
        // while it was open efficiently via GraphQL.
        if (this.cachedGithubClient) {
            try {
                const gqlClient = new GitHubGraphQLClient(this.cachedGithubClient.raw as any, this.logger);
                const gqlPr = await gqlClient.fetchSinglePR(repoOwner, repo.name, pr.number);
                
                if (gqlPr) {
                    const commentsToInsert: any[] = [];
                    
                    const addComment = (c: any, type: "issue" | "review") => {
                        const cAuthor = c.author?.login;
                        if (!cAuthor || isBot(cAuthor, c.author?.__typename)) return;
                        commentsToInsert.push({
                            id:          parseInt(c.databaseId.toString(), 10) || parseInt(c.id.toString(), 10),
                            prId:        pr.id,
                            repoId,
                            prNumber:    pr.number,
                            author:      cAuthor,
                            body:        c.body,
                            commentType: type,
                            htmlUrl:     c.url,
                            commentedAt: c.createdAt,
                        });
                    };

                    // Add standard PR comments
                    gqlPr.comments?.nodes?.forEach(c => addComment(c, "issue"));
                    
                    // Add review thread comments
                    gqlPr.reviewThreads?.nodes?.forEach(thread => {
                        thread.comments?.nodes?.forEach(c => addComment(c, "review"));
                    });

                    // Add review summary bodies as comments
                    gqlPr.reviews?.nodes?.forEach(r => {
                        if (r.body?.trim()) {
                            addComment({
                                ...r,
                                databaseId: Math.floor(Math.random() * -1000000), // mock ID for synthetic review bodies
                                url: pr.html_url,
                                createdAt: r.submittedAt,
                            }, "review");
                        }
                    });

                    if (commentsToInsert.length > 0) {
                        await this.commentsRepo.insertCommentBatch(commentsToInsert);
                    }
                }
            } catch (err) {
                this.logger.error({ err }, "Failed to backfill historical comments for newly merged PR via GraphQL");
            }
        }

        affectedDevelopers.push(author);
        return { affectedDevelopers };
    }

    // ─── Comment (issue_comment or review_comment) ──────────

    async handleIssueComment(payload: IssueCommentPayload): Promise<WebhookHandlerResult> {
        return this.processComment(
            "issue",
            payload.comment,
            payload.issue.number,
            payload.pull_request?.id,
            payload.repository,
            payload.organization?.login,
        );
    }

    async handleReviewComment(payload: ReviewCommentPayload): Promise<WebhookHandlerResult> {
        return this.processComment(
            "review",
            payload.comment,
            payload.pull_request.number,
            payload.pull_request.id,
            payload.repository,
            payload.organization?.login,
        );
    }

    private async processComment(
        commentType: "issue" | "review",
        comment: { id: number; body: string; html_url: string; created_at: string; user?: { login: string; type: string; avatar_url: string } },
        prNumber: number,
        prId: number | undefined,
        repo: { id: number; full_name: string; name: string; html_url: string; owner?: { login: string } },
        orgLogin?: string,
    ): Promise<WebhookHandlerResult> {
        const affectedDevelopers: string[] = [];
        const org = orgLogin ?? repo.owner?.login ?? this.org;

        // Invalidate open-PRs cache (non-blocking, logged on error)
        this.invalidatePrCache(org);

        const author = comment.user?.login;
        if (!author || isBot(author, comment.user?.type)) {
            return { affectedDevelopers };
        }

        const repoOwner = repo.owner?.login ?? org;

        // Parallel: upsert repo + upsert developer (independent operations)
        const [repoId] = await Promise.all([
            this.reposRepo.upsertRepo(repo.id, repoOwner, repo.name, { htmlUrl: repo.html_url }),
            this.developerRepo.upsertDeveloper(author, comment.user?.avatar_url),
        ]);

        await this.commentsRepo.insertComment({
            id:          comment.id,
            prId:        prId ?? null as any,
            repoId,
            prNumber,
            author,
            body:        comment.body,
            commentType,
            htmlUrl:     comment.html_url,
            commentedAt: comment.created_at,
        });

        affectedDevelopers.push(author);
        return { affectedDevelopers };
    }

    // ─── Org Membership ─────────────────────────────────────

    async handleOrgMembership(payload: OrgMembershipPayload): Promise<WebhookHandlerResult> {
        const org = payload.organization?.login ?? this.org;
        await this.cache.members.del(`github:org-members:${org}`);
        return { affectedDevelopers: [] };
    }

    // ─── Push (direct commits) ──────────────────────────────

    async handlePush(payload: PushPayload): Promise<WebhookHandlerResult> {
        const affectedDevelopers: string[] = [];
        const repo   = payload.repository;
        const org    = payload.organization?.login ?? repo.owner?.login ?? this.org;
        const sender = payload.sender;

        // Extract branch name from ref (e.g. "refs/heads/development" → "development")
        const branch = payload.ref.replace(/^refs\/heads\//, "");

        // Skip tag pushes
        if (payload.ref.startsWith("refs/tags/")) {
            return { affectedDevelopers };
        }

        // Skip empty pushes (e.g. branch creation with no commits)
        if (!payload.commits || payload.commits.length === 0) {
            return { affectedDevelopers };
        }

        const repoOwner = repo.owner?.login ?? org;

        // Upsert the repo
        const repoId = await this.reposRepo.upsertRepo(repo.id, repoOwner, repo.name, { htmlUrl: repo.html_url });

        // Process each commit
        const commitRows: Array<{
            sha: string; repoId: number; author: string;
            message: string; branch: string; committedAt: string;
            htmlUrl: string; additions: number; deletions: number;
        }> = [];

        for (const commit of payload.commits) {
            // Resolve author: prefer commit.author.username (GitHub login), fall back to sender
            const author = commit.author?.username ?? sender?.login;
            if (!author || isBot(author, sender?.type)) continue;

            // Ensure developer exists
            await this.developerRepo.upsertDeveloper(author, sender?.avatar_url);

            // Count file changes (rough line proxy for display; not scored)
            const filesAdded    = commit.added?.length ?? 0;
            const filesRemoved  = commit.removed?.length ?? 0;
            const filesModified = commit.modified?.length ?? 0;

            commitRows.push({
                sha:         commit.id,
                repoId,
                author,
                message:     commit.message.split("\n")[0].slice(0, 255),
                branch,
                committedAt: commit.timestamp,
                htmlUrl:     commit.url,
                additions:   filesAdded + filesModified,  // approximate
                deletions:   filesRemoved,                // approximate
            });

            if (!affectedDevelopers.includes(author)) {
                affectedDevelopers.push(author);
            }
        }

        if (commitRows.length > 0) {
            const inserted = await this.commitsRepo.insertCommitBatch(commitRows);
            this.logger.info(
                { repo: `${repoOwner}/${repo.name}`, branch, total: commitRows.length, inserted },
                "Push webhook: commits processed",
            );
        }

        return { affectedDevelopers };
    }

    // ─── Helpers ─────────────────────────────────────────────

    private invalidatePrCache(org: string): void {
        this.openPrsService.invalidateCache(org).catch((err: any) => {
            this.logger.error({ err: (err as Error).message }, "Failed to invalidate open-PRs cache");
        });
    }
}
