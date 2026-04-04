// ─── Shared sub-types ────────────────────────────────────────────────────────

export interface TicketUser {
    login:      string;
    avatar_url: string;
}

export interface TicketLabel {
    name:  string;
    color: string; // hex without #
}

export interface TicketMilestone {
    title:  string;
    due_on: string | null; // ISO-8601 or null
}

// ─── Main metric shape ───────────────────────────────────────────────────────

export type TicketSource = 'issue' | 'project_item' | 'draft';

export interface TicketMetric {
    number:         number;
    title:          string;
    url:            string;          // API or web URL
    html_url:       string;          // GitHub browser URL
    repo_name:      string;          // e.g. "sellio_mobile"
    author:         TicketUser;
    assignees:      TicketUser[];
    labels:         TicketLabel[];
    created_at:     string;          // ISO-8601
    milestone:      TicketMilestone | null;
    priority:       string | null;   // "critical" | "high" | "medium" | "low"
    body:           string;
    // ── Source / Project v2 enrichment ──────────────────────────────────────
    source:         TicketSource;    // where this ticket originated
    project_name:   string | null;   // e.g. "Sprint 12"
    project_number: number | null;
    project_status: string | null;   // single-select status field
    due_date:       string | null;   // date field from project (ISO-8601)
}
