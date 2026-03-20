/**
 * GitHub Webhook Routes
 * POST /api/webhooks/github
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle } from "../../lib/route-helpers";
import { isBot } from "../../lib/bot-filter";

const RELEVANT_EVENTS = new Set([
    "pull_request", "pull_request_review",
    "issue_comment", "pull_request_review_comment",
    "organization", "member", "membership",
]);

const webhook = new Hono<HonoEnv>();

webhook.post("/github", async (c) => {
    const cradle = useCradle(c);
    const event  = c.req.header("x-github-event");

    if (!event || !RELEVANT_EVENTS.has(event)) return c.json({ ignored: true, event });

    const payload = await c.req.json<{
        action?: string;
        organization?: { login: string };
        repository?: {
            id: number;
            full_name: string;
            name: string;
            html_url: string;
            owner?: { login: string };
        };
        pull_request?: {
            id: number;
            number: number;
            title: string;
            html_url: string;
            merged: boolean;
            user?: { login: string; type: string; avatar_url: string; name?: string };
            merged_at?: string;
            closed_at?: string;
            created_at?: string;
            additions?: number;
            deletions?: number;
        };
        issue?: { number: number };
        comment?: {
            id: number;
            body: string;
            html_url: string;
            created_at: string;
            user?: { login: string; type: string; avatar_url: string };
        };
    }>();

    // Org membership events — just flush member cache
    if (["organization", "member", "membership"].includes(event)) {
        const org = payload.organization?.login || cradle.env.org;
        await cradle.membersKvCache.del(`github:org-members:${org}`);
        return c.json({ ok: true, event, cache_invalidated: true });
    }

    const repo = payload?.repository;
    if (!repo?.full_name) return c.json({ ignored: true, reason: "no repo" });

    const org       = repo.owner?.login || cradle.env.org;
    const repoOwner = repo.owner?.login || org;
    const repoName  = repo.name;
    const action    = payload?.action;

    // Invalidate open-PRs cache on any PR/review event (fire-and-forget)
    if (event === "pull_request" || event === "pull_request_review") {
        const p = cradle.openPrsService.invalidateCache(org).catch(() => {});
        if (c.executionCtx?.waitUntil) c.executionCtx.waitUntil(p);
        else await p;
    }

    const affectedDevelopers = new Set<string>();

    // Merged PR
    if (event === "pull_request" && action === "closed" && payload.pull_request?.merged) {
        const pr     = payload.pull_request;
        const author = pr.user?.login as string;
        if (author && !isBot(author, pr.user?.type)) {
            const repoId = await cradle.reposRepo.upsertRepo(
                repo.id as number, repoOwner, repoName, { htmlUrl: repo.html_url },
            );
            await cradle.developerRepo.upsertDeveloper(author, pr.user?.avatar_url, pr.user?.name);
            await cradle.prsRepo.upsertMergedPr({
                id: pr.id as number, repoId, prNumber: pr.number,
                author, title: pr.title, htmlUrl: pr.html_url,
                mergedAt:    pr.merged_at || pr.closed_at || new Date().toISOString(),
                prCreatedAt: pr.created_at,
                additions:   pr.additions ?? 0,
                deletions:   pr.deletions ?? 0,
            });
            affectedDevelopers.add(author);
        }
    }

    // New comment
    if (
        (event === "issue_comment" || event === "pull_request_review_comment") &&
        action === "created" && payload.comment
    ) {
        const comment = payload.comment;
        const author  = comment.user?.login as string;
        if (author && !isBot(author, comment.user?.type)) {
            const prNumber = payload.issue?.number || payload.pull_request?.number;
            const repoId = await cradle.reposRepo.upsertRepo(
                repo.id as number, repoOwner, repoName, { htmlUrl: repo.html_url },
            );
            await cradle.developerRepo.upsertDeveloper(author, comment.user?.avatar_url);
            await cradle.commentsRepo.insertComment({
                id: comment.id as number, prId: payload.pull_request?.id as number,
                repoId, prNumber: prNumber as number, author, body: comment.body,
                commentType: event === "pull_request_review_comment" ? "review" : "issue",
                htmlUrl: comment.html_url, commentedAt: comment.created_at,
            });
            affectedDevelopers.add(author);
        }
    }

    if (affectedDevelopers.size > 0) {
        const p = cradle.scoreAggregationService
            .precomputeSnapshots([...affectedDevelopers])
            .catch(() => {});
        if (c.executionCtx?.waitUntil) c.executionCtx.waitUntil(p);
        else await p;
    }

    return c.json({ ok: true, event, repo: repo.full_name, affectedDevelopers: [...affectedDevelopers] });
});

export default webhook;
