/**
 * Webhook Module — Route
 *
 * Receives GitHub webhook payloads and invalidates the result cache
 * for the affected repository.
 *
 * Supported events:
 *   - pull_request (opened, closed, merged, synchronize, reopened)
 *   - pull_request_review
 *   - issue_comment (on PRs)
 *   - pull_request_review_comment
 *
 * Setup: In GitHub → Settings → Webhooks → point at:
 *   POST https://your-domain/api/webhooks/github
 *   Content type: application/json
 *   Secret: matches GITHUB_WEBHOOK_SECRET env var
 */

import crypto from "crypto";
import { FastifyPluginAsync } from "fastify";
import type { Cradle } from "../../core/container";

const RELEVANT_EVENTS = new Set([
    "pull_request",
    "pull_request_review",
    "issue_comment",
    "pull_request_review_comment",
]);

const webhookRoute: FastifyPluginAsync = async (fastify) => {
    fastify.post("/github", async (request, reply) => {
        const { cacheService, logger, env } = request.diScope.cradle as Cradle;
        const log = logger.child({ module: "webhook" });

        // Verify webhook signature if secret is configured
        const secret = env.githubWebhookSecret;
        if (secret) {
            const signature = request.headers["x-hub-signature-256"] as string;
            if (!signature) {
                log.warn("Missing webhook signature — rejecting");
                return reply.status(401).send({ error: "Missing signature" });
            }

            const body = JSON.stringify(request.body);
            const expected = "sha256=" + crypto
                .createHmac("sha256", secret)
                .update(body)
                .digest("hex");

            if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
                log.warn("Invalid webhook signature — rejecting");
                return reply.status(401).send({ error: "Invalid signature" });
            }
        }

        // Parse the event
        const event = request.headers["x-github-event"] as string;
        if (!event || !RELEVANT_EVENTS.has(event)) {
            log.debug({ event }, "Ignoring irrelevant webhook event");
            return reply.status(200).send({ ignored: true, event });
        }

        // Extract repo info from the payload
        const payload = request.body as any;
        const repo = payload?.repository;
        if (!repo?.full_name) {
            log.warn("Webhook payload missing repository info");
            return reply.status(200).send({ ignored: true, reason: "no repo" });
        }

        const [owner, repoName] = repo.full_name.split("/");
        log.info(
            { event, repo: repo.full_name, action: payload.action },
            "Processing webhook — invalidating result cache",
        );

        // Invalidate all result cache keys for this repo (all states)
        const keysToInvalidate = [
            `result:metrics:${owner}/${repoName}:all`,
            `result:metrics:${owner}/${repoName}:open`,
            `result:metrics:${owner}/${repoName}:closed`,
        ];

        let deleted = 0;
        for (const key of keysToInvalidate) {
            const result = await cacheService.del(key);
            if (result) deleted++;
        }

        log.info({ deleted, keys: keysToInvalidate.length }, "Result cache invalidated");

        return reply.status(200).send({
            ok: true,
            event,
            repo: repo.full_name,
            cacheKeysInvalidated: deleted,
        });
    });
};

export default webhookRoute;
