-- ═══════════════════════════════════════════════════════════════════
-- Migration 0004: Full Normalized Relational Schema (Consolidated)
--
-- Final schema — created fresh after full DB wipe.
-- All tables designed with final column set; no follow-up ALTER needed.
--
-- Tables:
--   repos               — canonical repo registry
--   members             — canonical member registry (no bots, no is_bot column)
--   merged_prs          — one row per merged PR (FK → repos, members)
--   pr_comments         — one row per comment with full content + body
--   meeting_sessions    — one row per Google Meet session
--   meeting_attendance  — one row per member × session
--   point_rules         — dynamic scoring rules
-- ═══════════════════════════════════════════════════════════════════

-- ─── Drop old flat tables (legacy) ───────────────────────────────────
DROP TABLE IF EXISTS events_archive;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS developers;

-- ─── 1. Repos ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS repos (
    id                TEXT PRIMARY KEY,           -- "{owner}/{name}"
    owner             TEXT NOT NULL,
    name              TEXT NOT NULL,
    html_url          TEXT,
    description       TEXT,
    github_created_at TEXT,                       -- GitHub repo creation date
    pushed_at         TEXT,                       -- Last push date
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(owner, name)
);

CREATE INDEX IF NOT EXISTS idx_repos_owner ON repos(owner);

-- ─── 2. Members ──────────────────────────────────────────────────────
-- No is_bot column — bots are filtered before any insert.
CREATE TABLE IF NOT EXISTS members (
    login        TEXT PRIMARY KEY,
    avatar_url   TEXT,
    display_name TEXT,
    joined_at    TEXT,                            -- GitHub account creation date
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_members_login ON members(login);

-- ─── 3. Merged PRs ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS merged_prs (
    id           INTEGER PRIMARY KEY,              -- GitHub PR integer id (raw from API)
    repo_id      TEXT NOT NULL REFERENCES repos(id),
    pr_number    INTEGER NOT NULL,                 -- GitHub PR number (for display / links)
    author       TEXT NOT NULL REFERENCES members(login),
    title        TEXT,
    body         TEXT,                             -- PR description / body text
    html_url     TEXT,
    merged_at    TEXT NOT NULL,
    pr_created_at TEXT,                            -- GitHub PR opened date
    additions    INTEGER NOT NULL DEFAULT 0,
    deletions    INTEGER NOT NULL DEFAULT 0,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(repo_id, pr_number)
);

CREATE INDEX IF NOT EXISTS idx_merged_prs_author    ON merged_prs(author);
CREATE INDEX IF NOT EXISTS idx_merged_prs_merged_at ON merged_prs(merged_at);
CREATE INDEX IF NOT EXISTS idx_merged_prs_repo_id   ON merged_prs(repo_id);

-- ─── 4. PR Comments ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pr_comments (
    id           INTEGER PRIMARY KEY,               -- GitHub comment integer id
    pr_id        INTEGER NOT NULL REFERENCES merged_prs(id),
    repo_id      TEXT NOT NULL REFERENCES repos(id),
    pr_number    INTEGER NOT NULL,
    author       TEXT NOT NULL REFERENCES members(login),
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
    developer_login  TEXT NOT NULL REFERENCES members(login),
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

-- ─── 7. Point Rules ──────────────────────────────────────────────────
-- Seeded with sensible defaults. All values adjustable via API.
CREATE TABLE IF NOT EXISTS point_rules (
    event_type  TEXT PRIMARY KEY,
    points      REAL NOT NULL DEFAULT 0,
    description TEXT,
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO point_rules (event_type, points, description) VALUES
    ('PR_MERGED',           10,   'Points per merged pull request'),
    ('CODE_ADDITION',       0.01, 'Points per added line'),
    ('CODE_DELETION',       0.01, 'Points per deleted line'),
    ('PR_COMMENT',          2,    'Points per pull request comment'),
    ('ATTENDANCE_DURATION', 0.1,  'Points per minute of meeting attendance');
