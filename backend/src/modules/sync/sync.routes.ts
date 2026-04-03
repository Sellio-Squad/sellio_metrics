/**
 * GitHub Sync Routes
 * POST   /api/sync/github            — Enqueue sync jobs for one or more repos (returns 202 + jobIds)
 * GET    /api/sync/status/:jobId     — Poll job status stored in KV
 * POST   /api/sync/github/members    — Sync org member profiles (display names, joined_at)
 * DELETE /api/sync/github/reset      — Wipe all sync data and caches for a clean re-sync
 * DELETE /api/sync/github/cache      — Clear all KV caches without wiping database
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { syncOneRepo, syncOrgMembers, syncCommitsForRepo } from "./sync.service";
import type { SyncRepoJob, CommitSyncJob, SyncJobState } from "./sync-job.types";

import { z } from "zod";
import { zValidator } from "@hono/zod-validator";

const syncSchema = z.object({
    owner:     z.string().optional(),
    repo:      z.string().optional(),
    repos:     z.array(z.string()).optional(),
    prNumbers: z.array(z.number()).optional(),
    /**
     * force=true fetches all pages (20) regardless of what's in DB.
     * Use when you want a full historical re-sync.
     */
    force:     z.boolean().optional().default(false),
}).refine(data => data.repo || (data.repos && data.repos.length > 0), {
    message: "Body must contain 'repo' (string) or 'repos' (string[]). Example: { \"repos\": [\"sellio_mobile\"] }",
    path: ["repo", "repos"],
});

type SyncBody = z.infer<typeof syncSchema>;

const sync = new Hono<HonoEnv>();

// ─── Helpers ──────────────────────────────────────────────────

function makeJobId(): string {
    // Simple UUID v4-like id using crypto
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
        const r = Math.random() * 16 | 0;
        const v = c === "x" ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

function syncStatusKey(jobId: string): string {
    return `sync:job:${jobId}`;
}

async function writeJobState(cacheService: any, state: SyncJobState): Promise<void> {
    // Store for 24h — long enough for user to poll result
    await cacheService.set(syncStatusKey(state.jobId), state, 24 * 60 * 60);
}

// ─── Enqueue Sync Jobs ────────────────────────────────────────
/**
 * Places one sync job per repo into SYNC_QUEUE.
 * Returns immediately with 202 + the list of jobIds so the
 * frontend can start polling GET /api/sync/status/:jobId.
 */
sync.post("/github", zValidator("json", syncSchema), safe(async (c) => {
    const cradle = useCradle(c);
    const body   = c.req.valid("json") as SyncBody;
    const owner  = body.owner || cradle.env.org;
    const force  = body.force ?? false;

    const repoNames: string[] =
        Array.isArray(body.repos) && body.repos.length > 0 ? body.repos :
        typeof body.repo === "string" && body.repo        ? [body.repo] :
        [];

    // Resolve repo IDs from the org list (needed by queue consumer)
    const orgRepos = await cradle.cachedGithubClient.listOrgRepos(owner);

    const jobs: { jobId: string; repo: string }[] = [];

    for (const repoName of repoNames) {
        const repoMeta = orgRepos.find((r: any) => r.name === repoName);
        const repoId   = repoMeta?.id as number | undefined;

        const jobId = makeJobId();
        const job: SyncRepoJob = {
            jobId,
            owner,
            repoName,
            repoId:    repoId ?? 0,
            force,
            enqueuedAt: new Date().toISOString(),
        };

        // Write initial "queued" state so frontend can poll immediately
        const initialState: SyncJobState = {
            jobId,
            owner,
            repoName,
            status: "queued",
        };
        await writeJobState(cradle.cacheService, initialState);

        // Push to queue — consumer will run up to 15 min per job
        const syncQueue = (c.env as any).SYNC_QUEUE;
        if (syncQueue) {
            await syncQueue.send(job);
        } else {
            // Fallback: if queue not bound (local dev), run inline
            cradle.logger.warn({ repoName }, "SYNC_QUEUE not bound — running sync inline (may timeout)");
            await runSyncJob(cradle, job, {}, orgRepos);
        }

        jobs.push({ jobId, repo: `${owner}/${repoName}` });
    }

    return c.json({ ok: true, message: "Sync jobs enqueued", jobs }, 202);
}));

// ─── Poll Job Status ──────────────────────────────────────────
sync.get("/status/:jobId", safe(async (c) => {
    const { cacheService } = useCradle(c);
    const jobId = c.req.param("jobId") as string;
    const cached = await cacheService.get<SyncJobState>(syncStatusKey(jobId));
    if (!cached) {
        return c.json({ error: "Job not found or expired" }, 404);
    }
    return c.json(cached.data);
}));

// ─── Queue Consumer Logic (called from worker.ts) ─────────────

/**
 * Phase 1: PR Sync
 * Syncs PRs + comments for one repo via GraphQL.
 * On success enqueues a CommitSyncJob for the same repo.
 * precomputeSnapshots() is NOT called here — it runs after commit sync.
 */
export async function runSyncJob(
    cradle:   any,
    job:      SyncRepoJob,
    env:      { SYNC_QUEUE?: any; WEBHOOK_QUEUE?: any } = {},
    orgRepos?: any[],
): Promise<void> {
    const { cacheService, logger } = cradle;
    const log = logger.child({ module: "sync-queue:pr", jobId: job.jobId, repo: job.repoName });

    const setStatus = (patch: Partial<SyncJobState>) =>
        writeJobState(cacheService, {
            jobId:    job.jobId,
            owner:    job.owner,
            repoName: job.repoName,
            status:   "running",
            ...patch,
        } as SyncJobState);

    try {
        await setStatus({ status: "running", startedAt: new Date().toISOString() });
        log.info("Starting PR sync job from queue");

        if (!orgRepos) {
            orgRepos = await cradle.cachedGithubClient.listOrgRepos(job.owner) as any[];
        }
        const resolvedRepos = orgRepos!;

        // ── Phase 1: Sync PRs + comments ──────────────────────
        const prResult = await syncOneRepo(
            cradle, job.owner, job.repoName, resolvedRepos, undefined, job.force,
        );

        // Mark PR phase done — commits still pending
        await setStatus({
            status: "running",
            result: { phase: "prs_done", ...(prResult as object) },
        });
        log.info({ prResult }, "PR sync complete — enqueuing commit sync");

        // ── Phase 2: Enqueue separate commit sync job ──────────
        // This gives commit sync its own 30s CPU budget
        const repoMeta = resolvedRepos.find((r: any) => r.name === job.repoName);
        const repoId   = repoMeta?.id ?? job.repoId;

        const commitJob: CommitSyncJob = {
            type:      "commit_sync",
            jobId:     job.jobId,
            owner:     job.owner,
            repoName:  job.repoName,
            repoId,
            force:     job.force,
            // No `since` here — syncCommitsForRepo reads it from DB automatically
        };

        if (env.SYNC_QUEUE) {
            await env.SYNC_QUEUE.send(commitJob);
            log.info("Commit sync job enqueued");
        } else {
            // Local dev fallback — run inline
            log.warn("SYNC_QUEUE not bound — running commit sync inline");
            await runCommitSyncJob(cradle, commitJob, env);
        }

    } catch (e: any) {
        log.error({ err: e.message }, "PR sync job failed");
        await writeJobState(cacheService, {
            jobId:      job.jobId,
            owner:      job.owner,
            repoName:   job.repoName,
            status:     "error",
            finishedAt: new Date().toISOString(),
            error:      e.message,
        });
        throw e; // rethrow so queue can retry
    }
}

/**
 * Phase 2: Commit Sync
 * Runs as a separate queue invocation → gets its own 30s CPU budget.
 * Uses incremental `since` from DB so only new commits are fetched.
 * After inserting commits, fires precomputeSnapshots() once.
 */
export async function runCommitSyncJob(
    cradle: any,
    job:    CommitSyncJob,
    env:    { WEBHOOK_QUEUE?: any } = {},
): Promise<void> {
    const { cacheService, logger } = cradle;
    const log = logger.child({ module: "sync-queue:commits", jobId: job.jobId, repo: job.repoName });

    try {
        log.info({ force: job.force }, "Starting commit sync job from queue");

        const commitResult = await syncCommitsForRepo(
            cradle, job.owner, job.repoName, job.repoId,
            { since: job.since, force: job.force },
        );

        log.info({ commitResult }, "Commit sync complete");

        // ── Recompute leaderboard once after commits are stored ──
        // Offload to WEBHOOK_QUEUE so it runs async (doesn't count against this invocation)
        if (env.WEBHOOK_QUEUE) {
            await env.WEBHOOK_QUEUE.send({ type: "recompute_scores" });
            log.info("Score recompute enqueued via webhook queue");
        } else {
            // Fallback: run inline (local dev or unbound)
            try {
                await cradle.scoreAggregationService.precomputeSnapshots();
            } catch (se: any) {
                log.warn({ err: se.message }, "Score recompute failed (non-fatal)");
            }
        }

        // Mark the overall job as done
        await writeJobState(cacheService, {
            jobId:      job.jobId,
            owner:      job.owner,
            repoName:   job.repoName,
            status:     "done",
            finishedAt: new Date().toISOString(),
            result:     { ...commitResult },
        });

        log.info("Sync job fully complete (PR + commits)");
    } catch (e: any) {
        log.error({ err: e.message }, "Commit sync job failed");
        await writeJobState(cacheService, {
            jobId:      job.jobId,
            owner:      job.owner,
            repoName:   job.repoName,
            status:     "error",
            finishedAt: new Date().toISOString(),
            error:      `Commit sync failed: ${e.message}`,
        });
        throw e;
    }
}


// ─── Sync Org Members ─────────────────────────────────────────
sync.post("/github/members", safe(async (c) => {
    const cradle = useCradle(c);
    const org    = cradle.env.org;
    const result = await syncOrgMembers(cradle, org);
    return c.json({ ok: true, org, ...result });
}));

// ─── Reset All Sync Data ──────────────────────────────────────
/**
 * Wipes merged_prs, pr_comments, developers, and repositories tables, 
 * then busts all relevant KV caches for a completely fresh start.
 * After calling this, run a fresh sync to repopulate everything.
 */
sync.delete("/github/reset", safe(async (c) => {
    const cradle = useCradle(c);
    const { d1Service, cacheService, scoresKvCache, logger, env } = cradle;

    logger.info("Starting full database reset");

    const { prsDeleted, commentsDeleted, commitsDeleted, devsDeleted, reposDeleted } = await d1Service.truncateSyncData();

    logger.info({ prsDeleted, commentsDeleted, commitsDeleted, devsDeleted, reposDeleted }, "Sync tables cleared");

    // Bust all relevant caches
    await Promise.allSettled([
        cacheService.clearAll(),
        scoresKvCache.clearAll(),
        cradle.membersKvCache.clearAll(),
        cradle.attendanceKvCache.clearAll(),
    ]);

    logger.info("All KV caches cleared");

    return c.json({
        ok: true,
        message: "All sync data wiped. Run a fresh sync to repopulate.",
        cleared: { prsDeleted, commentsDeleted, commitsDeleted, devsDeleted, reposDeleted },
    });
}));

// ─── Invalidate Cache Only ────────────────────────────────────
sync.delete("/github/cache", safe(async (c) => {
    const cradle = useCradle(c);
    const { cacheService, scoresKvCache, membersKvCache, attendanceKvCache, logger } = cradle;
    
    // Wipe every namespace cleanly
    await Promise.allSettled([
        cacheService.clearAll(),
        scoresKvCache.clearAll(),
        membersKvCache.clearAll(),
        attendanceKvCache.clearAll(),
    ]);

    logger.info("KV caches manually invalidated completely via /cache endpoint");

    return c.json({
        ok: true,
        message: "All caches invalidated. Repos list will be freshly fetched.",
    });
}));

export default sync;
