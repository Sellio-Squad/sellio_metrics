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
import type { OpenPrsService } from "../prs/open-prs.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { CacheRegistry } from "../../infra/cache/cache-registry";
import { isBot } from "../../lib/bot-filter";
import type {
    PullRequestPayload,
    IssueCommentPayload,
    ReviewCommentPayload,
    OrgMembershipPayload,
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
    openPrsService: OpenPrsService;
    cache: CacheRegistry;
    env: { org: string };
}

export class WebhookService {
    private readonly logger: Logger;
    private readonly reposRepo: ReposRepository;
    private readonly developerRepo: DeveloperRepository;
    private readonly prsRepo: PrsRepository;
    private readonly commentsRepo: CommentsRepository;
    private readonly openPrsService: OpenPrsService;
    private readonly cache: CacheRegistry;
    private readonly org: string;

    constructor(deps: WebhookServiceDeps) {
        this.logger        = deps.logger.child({ module: "webhook-service" });
        this.reposRepo     = deps.reposRepo;
        this.developerRepo = deps.developerRepo;
        this.prsRepo       = deps.prsRepo;
        this.commentsRepo  = deps.commentsRepo;
        this.openPrsService = deps.openPrsService;
        this.cache         = deps.cache;
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

    // ─── Helpers ─────────────────────────────────────────────

    private invalidatePrCache(org: string): void {
        this.openPrsService.invalidateCache(org).catch((err) => {
            this.logger.error({ err: (err as Error).message }, "Failed to invalidate open-PRs cache");
        });
    }
}
