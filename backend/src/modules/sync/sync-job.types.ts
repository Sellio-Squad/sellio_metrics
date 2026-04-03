/**
 * Sync Job Types
 *
 * A sync job is placed in SYNC_QUEUE when the user hits POST /api/sync/github.
 * The queue consumer processes one repo at a time so no 30s wall-time limit applies.
 * Status is written to KV so the frontend can poll GET /api/sync/status/:jobId.
 */

export type SyncJobStatus = "queued" | "running" | "done" | "error";

export interface SyncRepoJob {
    jobId:     string;   // uuid — used as KV key for status polling
    owner:     string;
    repoName:  string;
    repoId:    number;
    force:     boolean;
    enqueuedAt: string;
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
