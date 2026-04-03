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
import type { SyncRepoJob, SyncJobState } from "./sync-job.types";

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
            await runSyncJob(cradle, job, orgRepos);
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

export async function runSyncJob(
    cradle: any,
    job:     SyncRepoJob,
    orgRepos?: any[],
): Promise<void> {
    const { cacheService, logger } = cradle;
    const log = logger.child({ module: "sync-queue", jobId: job.jobId, repo: job.repoName });

    const updateState = (patch: Partial<SyncJobState>) =>
        writeJobState(cacheService, {
            jobId:    job.jobId,
            owner:    job.owner,
            repoName: job.repoName,
            status:   "running",
            ...patch,
        } as SyncJobState);

    try {
        await updateState({ status: "running", startedAt: new Date().toISOString() });
        log.info("Starting sync job from queue");

        if (!orgRepos) {
            orgRepos = await cradle.cachedGithubClient.listOrgRepos(job.owner) as any[];
        }

        const resolvedRepos = orgRepos!;

        const prResult = await syncOneRepo(
            cradle, job.owner, job.repoName, resolvedRepos, undefined, job.force,
        );

        // Sync commits
        const repoMeta = resolvedRepos.find((r: any) => r.name === job.repoName);
        const repoId   = repoMeta?.id ?? job.repoId;
        let commitResult = { commitsFound: 0, commitsInserted: 0 };
        if (repoId) {
            try {
                commitResult = await syncCommitsForRepo(cradle, job.owner, job.repoName, repoId);
            } catch (ce: any) {
                log.warn({ err: ce.message }, "Commit sync failed (non-fatal)");
            }
        }

        await cradle.scoreAggregationService.precomputeSnapshots();

        await writeJobState(cacheService, {
            jobId:      job.jobId,
            owner:      job.owner,
            repoName:   job.repoName,
            status:     "done",
            startedAt:  new Date().toISOString(),
            finishedAt: new Date().toISOString(),
            result:     { ...prResult as object, ...commitResult },
        });

        log.info("Sync job completed successfully");
    } catch (e: any) {
        log.error({ err: e.message }, "Sync job failed");
        await writeJobState(cacheService, {
            jobId:      job.jobId,
            owner:      job.owner,
            repoName:   job.repoName,
            status:     "error",
            finishedAt: new Date().toISOString(),
            error:      e.message,
        });
        throw e; // rethrow so queue retries
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
