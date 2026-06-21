/**
 * Sellio Metrics — AI Pipeline Types
 */

export interface AiImplementJob {
    type: "ai_implement";
    owner: string;
    repo: string;
    issueNumber: number;
    issueTitle: string;
    issueBody: string | null;
    projectId: string;       // ProjectV2 Node ID
    itemId: string;          // ProjectV2Item Node ID (GraphQL node ID)
    fieldId: string;         // Status ProjectV2Field Node ID
    phase: 1 | 2 | 3;
    taskId: string;          // Unique task identifier (e.g. repo-issue-timestamp)
}

export interface RepoContext {
    owner: string;
    repo: string;
    fileTree: string[];      // Flat list of file paths
    architectureDocs: {      // Readme, architecture, etc.
        path: string;
        content: string;
    }[];
    dependencies: Record<string, string>; // Dependency names and versions
    recentPrs: {
        title: string;
        number: number;
        body: string | null;
        patchSample?: string;
    }[];
    relevantFiles: {
        path: string;
        content: string;
    }[];
}

export interface ImplementationPlan {
    summary: string;
    approach: string;
    filesToModify: string[];
    newFiles: string[];
}

export interface CodeChange {
    path: string;
    content: string;
    action: "create" | "modify" | "delete";
}

export interface AiRunRecord {
    taskId: string;
    owner: string;
    repo: string;
    issueNumber: number;
    issueTitle: string;
    issueUrl: string;
    status: "in_progress" | "completed" | "failed" | "ci_polling";
    prNumber?: number;
    prUrl?: string;
    branchName?: string;
    startedAt: string;        // ISO-8601
    updatedAt: string;
    events: AiRunEvent[];
}

export interface AiRunEvent {
    phase: "phase1" | "phase2" | "phase3" | "ci_poll" | "failed";
    label: string;
    detail?: string;
    timestamp: string;
    status: "running" | "done" | "failed";
}

