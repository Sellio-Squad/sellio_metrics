-- ═══════════════════════════════════════════════════════════════════
-- Migration 0004: Full Normalized Relational Schema
--
-- Drops the old flat `events` and `events_archive` tables (replaced by
-- normalized domain tables below). `point_rules` is preserved.
--
-- New Tables:
--   repos               — canonical repo registry
--   developers          — canonical developer registry
--   merged_prs          — one row per merged PR (FK → repos, developers)
--   pr_comments         — one row per comment with full content
--   meeting_sessions    — one row per Google Meet session
--   meeting_attendance  — one row per developer × session
-- ═══════════════════════════════════════════════════════════════════

-- ─── Drop old flat tables ────────────────────────────────────────────
DROP TABLE IF EXISTS events_archive;
DROP TABLE IF EXISTS events;

-- ─── 1. Repos ────────────────────────────────────────────────────────
-- Canonical repo registry — eliminates repeating "owner/repo" text in PRs.
CREATE TABLE IF NOT EXISTS repos (
    id          TEXT PRIMARY KEY,                  -- "{owner}/{name}"
    owner       TEXT NOT NULL,
    name        TEXT NOT NULL,
    html_url    TEXT,
    description TEXT,
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(owner, name)
);

CREATE INDEX IF NOT EXISTS idx_repos_owner ON repos(owner);

-- ─── 2. Developers ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS developers (
    login        TEXT PRIMARY KEY,
    avatar_url   TEXT,
    display_name TEXT,
    is_bot       INTEGER NOT NULL DEFAULT 0,       -- 1 if login ends with [bot]
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ─── 3. Merged PRs ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS merged_prs (
    id          TEXT PRIMARY KEY,                  -- "github:pr:{repo_id}:{pr_number}"
    repo_id     TEXT NOT NULL REFERENCES repos(id),
    pr_number   INTEGER NOT NULL,
    author      TEXT NOT NULL REFERENCES developers(login),
    title       TEXT,
    html_url    TEXT,
    merged_at   TEXT NOT NULL,
    additions   INTEGER NOT NULL DEFAULT 0,
    deletions   INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(repo_id, pr_number)
);

CREATE INDEX IF NOT EXISTS idx_merged_prs_author    ON merged_prs(author);
CREATE INDEX IF NOT EXISTS idx_merged_prs_merged_at ON merged_prs(merged_at);
CREATE INDEX IF NOT EXISTS idx_merged_prs_repo_id   ON merged_prs(repo_id);

-- ─── 4. PR Comments ──────────────────────────────────────────────────
-- Full comment rows — body, type, link all preserved.
-- comment_type is enforced by CHECK to prevent duplicates / typos.
CREATE TABLE IF NOT EXISTS pr_comments (
    id           TEXT PRIMARY KEY,                 -- "github:comment:{repo_id}:{comment_id}"
    pr_id        TEXT NOT NULL REFERENCES merged_prs(id),
    repo_id      TEXT NOT NULL REFERENCES repos(id),
    pr_number    INTEGER NOT NULL,
    author       TEXT NOT NULL REFERENCES developers(login),
    body         TEXT,
    comment_type TEXT NOT NULL DEFAULT 'issue'
                 CHECK(comment_type IN ('issue', 'review')),
    html_url     TEXT,
    commented_at TEXT NOT NULL,
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_pr_comments_author       ON pr_comments(author);
CREATE INDEX IF NOT EXISTS idx_pr_comments_pr_id        ON pr_comments(pr_id);
CREATE INDEX IF NOT EXISTS idx_pr_comments_commented_at ON pr_comments(commented_at);

-- ─── 5. Meeting Sessions ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meeting_sessions (
    id           TEXT PRIMARY KEY,
    space_name   TEXT NOT NULL UNIQUE,
    meeting_uri  TEXT,
    meeting_code TEXT,
    title        TEXT,
    started_at   TEXT,
    ended_at     TEXT,
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ─── 6. Meeting Attendance ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meeting_attendance (
    id               TEXT PRIMARY KEY,
    session_id       TEXT NOT NULL REFERENCES meeting_sessions(id),
    developer_login  TEXT NOT NULL REFERENCES developers(login),
    display_name     TEXT,
    email            TEXT,
    joined_at        TEXT NOT NULL,
    left_at          TEXT,
    duration_minutes INTEGER NOT NULL DEFAULT 0,
    created_at       TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(session_id, developer_login)
);

CREATE INDEX IF NOT EXISTS idx_meeting_attend_developer ON meeting_attendance(developer_login);
CREATE INDEX IF NOT EXISTS idx_meeting_attend_session   ON meeting_attendance(session_id);
CREATE INDEX IF NOT EXISTS idx_meeting_attend_joined_at ON meeting_attendance(joined_at);

-- ─── point_rules: preserved, no changes ──────────────────────────────
-- Event types used in the UNION ALL leaderboard query:
--   PR_MERGED           → points per merged PR
--   CODE_ADDITION       → points × additions (stored in merged_prs)
--   CODE_DELETION       → points × deletions (stored in merged_prs)
--   PR_COMMENT          → points per comment row (COUNT of pr_comments)
--   ATTENDANCE_DURATION → points per minute (meeting_attendance)
