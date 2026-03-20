/**
 * GitHub Webhook Routes
 * POST /api/webhooks/github
 *
 * Thin dispatcher:
 *   1. Verify HMAC signature (middleware)
 *   2. Deduplicate via X-GitHub-Delivery header (KV)
 *   3. Parse with per-event Zod schema
 *   4. Dispatch to WebhookService handler
 *   5. Queue background work (score recomputation)
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle } from "../../lib/route-helpers";
import { verifyGitHubSignature } from "./webhook.middleware";
import { parseWebhookPayload } from "./webhook.schemas";
import type {
    PullRequestPayload,
    IssueCommentPayload,
    ReviewCommentPayload,
    OrgMembershipPayload,
} from "./webhook.schemas";
import type { WebhookHandlerResult } from "./webhook.service";

const RELEVANT_EVENTS = new Set([
    "pull_request", "pull_request_review",
    "issue_comment", "pull_request_review_comment",
    "organization", "member", "membership",
]);

const DEDUP_TTL_SECONDS = 86400; // 24 hours

const webhook = new Hono<HonoEnv>();

// ─── Signature verification middleware ────────────────────────
webhook.use("/github", verifyGitHubSignature);

webhook.post("/github", async (c) => {
    const cradle = useCradle(c);
    const event  = c.req.header("x-github-event");

    if (!event || !RELEVANT_EVENTS.has(event)) {
        return c.json({ ignored: true, event });
    }

    // ─── Idempotency: deduplicate webhook retries ──────────
    const deliveryId = c.req.header("x-github-delivery");
    if (deliveryId) {
        const existing = await cradle.cache.general.get(`webhook:delivery:${deliveryId}`);
        if (existing) {
            return c.json({ ok: true, duplicate: true, deliveryId });
        }
    }

    // ─── Parse raw JSON ────────────────────────────────────
    let rawJson: unknown;
    const rawBody = (c.get as any)("rawBody");
    if (rawBody) {
        try { rawJson = JSON.parse(rawBody); } catch { rawJson = {}; }
    } else {
        rawJson = await c.req.json().catch(() => ({}));
    }

    // ─── Validate with per-event schema ────────────────────
    const parseResult = parseWebhookPayload(event, rawJson);
    if (!parseResult.success) {
        cradle.logger.error({ event, err: parseResult.error }, "Webhook payload validation failed");
        return c.json({ ignored: true, reason: "invalid payload schema" });
    }
    const payload = parseResult.data;

    // ─── Handler dispatch map ──────────────────────────────
    type HandlerFn = (payload: any) => Promise<WebhookHandlerResult>;

    const handlers: Record<string, HandlerFn> = {
        pull_request:               (p) => cradle.webhookService.handlePullRequest(p as PullRequestPayload),
        pull_request_review:        (p) => cradle.webhookService.handlePullRequest(p as PullRequestPayload),
        issue_comment:              (p) => cradle.webhookService.handleIssueComment(p as IssueCommentPayload),
        pull_request_review_comment: (p) => cradle.webhookService.handleReviewComment(p as ReviewCommentPayload),
        organization:               (p) => cradle.webhookService.handleOrgMembership(p as OrgMembershipPayload),
        member:                     (p) => cradle.webhookService.handleOrgMembership(p as OrgMembershipPayload),
        membership:                 (p) => cradle.webhookService.handleOrgMembership(p as OrgMembershipPayload),
    };

    const handler = handlers[event];
    if (!handler) {
        return c.json({ ignored: true, event });
    }

    const result = await handler(payload);

    // ─── Mark delivery as processed (deduplication) ────────
    if (deliveryId) {
        const dedupPromise = cradle.cache.general
            .set(`webhook:delivery:${deliveryId}`, "1", DEDUP_TTL_SECONDS)
            .catch((err) => cradle.logger.error({ err: (err as Error).message }, "Failed to store delivery dedup key"));

        if (c.executionCtx?.waitUntil) c.executionCtx.waitUntil(dedupPromise);
        else await dedupPromise;
    }

    // ─── Queue background work (score recomputation) ───────
    if (result.affectedDevelopers.length > 0) {
        const queueMessage = {
            type: "recompute_scores",
            developers: result.affectedDevelopers,
        };

        // Try Cloudflare Queue first, fall back to waitUntil
        if (cradle.webhookQueue) {
            const queuePromise = cradle.webhookQueue
                .send(queueMessage)
                .catch((err: Error) => {
                    cradle.logger.error({ err: err.message }, "Failed to enqueue score recomputation, falling back to waitUntil");
                    // Fallback: run inline
                    return cradle.scoreAggregationService
                        .precomputeSnapshots(result.affectedDevelopers)
                        .catch((e: Error) => cradle.logger.error({ err: e.message }, "Score precompute failed"));
                });

            if (c.executionCtx?.waitUntil) c.executionCtx.waitUntil(queuePromise);
            else await queuePromise;
        } else {
            // No queue binding — use waitUntil with logging
            const p = cradle.scoreAggregationService
                .precomputeSnapshots(result.affectedDevelopers)
                .catch((err: Error) => cradle.logger.error({ err: err.message }, "Score precompute failed"));

            if (c.executionCtx?.waitUntil) c.executionCtx.waitUntil(p);
            else await p;
        }
    }

    return c.json({
        ok: true,
        event,
        repo: (payload as any)?.repository?.full_name,
        affectedDevelopers: result.affectedDevelopers,
    });
});

export default webhook;
