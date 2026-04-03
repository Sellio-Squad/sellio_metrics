/**
 * Sync Job Types
 *
 * A sync job is placed in SYNC_QUEUE when the user hits POST /api/sync/github.
 * The queue consumer processes one repo at a time so no 30s wall-time limit applies.
 * Status is written to KV so the frontend can poll GET /api/sync/status/:jobId.
 *
 * Split into TWO job types so each gets its own CPU budget:
 *   1. SyncRepoJob   — PR + comment GraphQL sync
 *   2. CommitSyncJob — commit history GraphQL sync (separate invocation)
 */

export type SyncJobStatus = "queued" | "running" | "done" | "error";

export interface SyncRepoJob {
    jobId:      string;   // uuid — used as KV key for status polling
    owner:      string;
    repoName:   string;
    repoId:     number;
    force:      boolean;
    enqueuedAt: string;
}

/** Separate job for commit sync — gets its own Worker CPU budget */
export interface CommitSyncJob {
    type:       "commit_sync";
    jobId:      string;   // same jobId as parent SyncRepoJob (status key: sync:commits:<jobId>)
    owner:      string;
    repoName:   string;
    repoId:     number;
    since?:     string;   // ISO date of latest stored commit — enables incremental sync
    force:      boolean;
}

export interface SyncJobState {
    jobId:      string;
    owner:      string;
    repoName:   string;
    status:     SyncJobStatus;
    startedAt?: string;
    finishedAt?: string;
    result?:    Record<string, unknown>;
    error?:     string;
}
