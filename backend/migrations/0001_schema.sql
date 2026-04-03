-- ═══════════════════════════════════════════════════════════════════
-- Consolidated Schema — Sellio Metrics
--
-- Single migration containing all tables.
-- After a full DB wipe, apply this one file to recreate everything.
--
-- Tables:
--   repos                     — canonical repo registry
--   members                   — canonical member registry (no bots)
--   merged_prs                — one row per merged PR (FK → repos, members)
--   pr_comments               — one row per comment with body
--   commits                   — one row per direct commit (FK → repos, members)
--   meeting_sessions          — one row per Google Meet session
--   participant_sessions      — one join/leave pair per participant × session
--   regular_meeting_schedules — recurring meeting configurations
--   point_rules               — dynamic scoring rules
-- ═══════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS participant_sessions;
DROP TABLE IF EXISTS meeting_sessions;
DROP TABLE IF EXISTS pr_comments;
DROP TABLE IF EXISTS merged_prs;
DROP TABLE IF EXISTS commits;
DROP TABLE IF EXISTS repos;
DROP TABLE IF EXISTS members;
DROP TABLE IF EXISTS regular_meeting_schedules;
DROP TABLE IF EXISTS point_rules;

-- ─── 1. Repos ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS repos (
    id                INTEGER PRIMARY KEY,        -- GitHub Repo integer id (raw from API)
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

-- ─── 2. Members ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS members (
    login        TEXT PRIMARY KEY,
    avatar_url   TEXT,
    display_name TEXT,
    joined_at    TEXT,                            -- GitHub account creation date
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_members_login ON members(login);

-- ─── 3. Merged PRs ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS merged_prs (
    id           INTEGER PRIMARY KEY,              -- GitHub PR integer id (raw from API)
    repo_id      INTEGER NOT NULL REFERENCES repos(id),
    pr_number    INTEGER NOT NULL,                 -- GitHub PR number (for display / links)
    author       TEXT NOT NULL REFERENCES members(login),
    title        TEXT,
    body         TEXT,                             -- PR description / body text
    html_url     TEXT,
    merged_at    TEXT NOT NULL,
    pr_created_at TEXT,                            -- GitHub PR opened date
    additions    INTEGER,
    deletions    INTEGER,
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(repo_id, pr_number)
);

CREATE INDEX IF NOT EXISTS idx_merged_prs_author    ON merged_prs(author);
CREATE INDEX IF NOT EXISTS idx_merged_prs_merged_at ON merged_prs(merged_at);
CREATE INDEX IF NOT EXISTS idx_merged_prs_repo_id   ON merged_prs(repo_id);

-- ─── 4. PR Comments ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pr_comments (
    id           INTEGER PRIMARY KEY,               -- GitHub comment integer id
    pr_id        INTEGER NOT NULL REFERENCES merged_prs(id),
    repo_id      INTEGER NOT NULL REFERENCES repos(id),
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

-- ─── 5. Commits ─────────────────────────────────────────────────
-- Tracks direct commits (pushes). SHA is the natural primary key
-- for idempotent inserts. additions/deletions stored for display
-- but NOT used in scoring (to avoid double-counting with PRs).
CREATE TABLE IF NOT EXISTS commits (
    sha          TEXT PRIMARY KEY,                  -- Git commit SHA (unique globally)
    repo_id      INTEGER NOT NULL REFERENCES repos(id),
    author       TEXT NOT NULL REFERENCES members(login),
    message      TEXT,                             -- First line of commit message
    branch       TEXT,                             -- Branch name (e.g. 'development')
    committed_at TEXT NOT NULL,                    -- Timestamp of the commit
    html_url     TEXT,                             -- Link to commit on GitHub
    additions    INTEGER DEFAULT 0,                -- Lines added (display only, not scored)
    deletions    INTEGER DEFAULT 0,                -- Lines deleted (display only, not scored)
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_commits_author       ON commits(author);
CREATE INDEX IF NOT EXISTS idx_commits_committed_at ON commits(committed_at);
CREATE INDEX IF NOT EXISTS idx_commits_repo_id      ON commits(repo_id);

-- ─── 6. Meeting Sessions ────────────────────────────────────────
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

-- ─── 7. Participant Sessions ────────────────────────────────────
CREATE TABLE IF NOT EXISTS participant_sessions (
    id               TEXT PRIMARY KEY,             -- "{sessionId}:{participantKey}:{epochMs}"
    session_id       TEXT NOT NULL REFERENCES meeting_sessions(id),
    participant_key  TEXT NOT NULL,                -- "users/{userId}" or displayName
    display_name     TEXT NOT NULL,
    start_time       TEXT,                         -- ISO timestamp, set on JOIN event
    end_time         TEXT,                         -- set on LEAVE event; NULL = still in meeting
    created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ps_session     ON participant_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_ps_participant ON participant_sessions(participant_key);
CREATE INDEX IF NOT EXISTS idx_ps_active      ON participant_sessions(session_id, end_time);

-- ─── 8. Regular Meeting Schedules ───────────────────────────────
CREATE TABLE IF NOT EXISTS regular_meeting_schedules (
    id                TEXT PRIMARY KEY,
    title             TEXT NOT NULL,
    description       TEXT NOT NULL DEFAULT '',
    day_time          TEXT NOT NULL,                -- e.g. "Mon–Fri, 10:00 AM"
    duration_label    TEXT NOT NULL,                -- e.g. "15 min"
    recurrence_label  TEXT NOT NULL,                -- e.g. "Daily"
    icon_code         INTEGER NOT NULL,             -- Flutter IconData codePoint (int)
    accent_color      INTEGER NOT NULL,             -- ARGB int e.g. 0xFF6366F1
    start_time        TEXT NOT NULL,                -- ISO 8601 datetime
    duration_minutes  INTEGER NOT NULL,             -- duration in minutes
    recurrence_rule   TEXT NOT NULL,                -- RFC 5545 RRULE string
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ─── 9. Point Rules ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS point_rules (
    event_type  TEXT PRIMARY KEY,
    points      REAL NOT NULL DEFAULT 0,
    description TEXT,
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO point_rules (event_type, points, description) VALUES
    ('PR_MERGED',           3,    'Points per merged pull request'),
    ('CODE_ADDITION',       0.001, 'Points per added line'),
    ('CODE_DELETION',       0.001, 'Points per deleted line'),
    ('PR_COMMENT',          2,    'Points per pull request comment'),
    ('COMMIT',              1,    'Points per direct commit (push)'),
    ('ATTENDANCE_DURATION', 0.1,  'Points per minute of meeting attendance');
