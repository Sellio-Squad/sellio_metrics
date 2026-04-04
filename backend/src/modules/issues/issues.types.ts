/**
 * Issues Module — Domain Types
 */

export interface IssueLabel {
    name:  string;
    color: string; // hex without #, e.g. "e4e669"
}

export interface IssueMilestone {
    title:  string;
    due_on: string | null; // ISO-8601 or null
}

export interface IssueUser {
    login:      string;
    avatar_url: string;
}

export interface IssueMetric {
    number:         number;
    title:          string;
    url:            string;       // API URL
    html_url:       string;       // Browser URL
    repo_name:      string;       // e.g. "sellio_mobile"
    author:         IssueUser;
    assignees:      IssueUser[];
    labels:         IssueLabel[];
    created_at:     string;       // ISO-8601
    milestone:      IssueMilestone | null;
    priority:       string | null; // extracted from label ("critical","high","medium","low")
    body:           string;
    // ── Project v2 enrichment (optional) ──
    source:         'issue' | 'project_item'; // where this ticket came from
    project_name:   string | null;      // e.g. "Sprint 12"
    project_number: number | null;
    project_status: string | null;      // single-select status field value
    due_date:       string | null;      // date field from project (ISO-8601)
}
