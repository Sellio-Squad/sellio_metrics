/**
 * Sellio Metrics Backend — Shared Domain Types
 *
 * Types used across modules. These represent the domain model,
 * independent of any specific data source (GitHub, DB, etc.).
 */

// ─── User ───────────────────────────────────────────────────

export interface UserInfo {
    login: string;
    id: number;
    url: string;
    avatar_url: string;
}

// ─── Pull Request ───────────────────────────────────────────

export interface CommentGroup {
    author: UserInfo;
    first_comment_at: string | null;
    last_comment_at: string | null;
    count: number;
}

export interface Approval {
    reviewer: UserInfo;
    submitted_at: string;
    commit_id: string;
    note?: string;
}

export interface DiffStats {
    additions: number;
    deletions: number;
    changed_files: number;
}

export interface PrMetric {
    pr_number: number;
    url: string;
    title: string;
    opened_at: string;
    head_ref: string;
    base_ref: string;
    creator: UserInfo;
    assignees: UserInfo[];
    comments: CommentGroup[];
    approvals: Approval[];
    required_approvals: number;
    first_approved_at: string | null;
    time_to_first_approval_minutes: number | null;
    required_approvals_met_at: string | null;
    time_to_required_approvals_minutes: number | null;
    closed_at: string | null;
    merged_at: string | null;
    merged_by: UserInfo | null;
    week: string;
    status: "pending" | "approved" | "merged" | "closed";
    labels: string[];
    milestone: { title: string; number: number } | null;
    draft: boolean;
    review_requests: string[];
    files_changed: string[];
    diff_stats: DiffStats;
}

// ─── Repository ─────────────────────────────────────────────

export interface RepoInfo {
    name: string;
    full_name: string;
    description: string | null;
    html_url: string;
    private: boolean;
    default_branch: string;
}
