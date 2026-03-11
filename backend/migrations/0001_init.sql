-- ═══════════════════════════════════════════════════════════
-- Sellio Metrics — D1 Database Schema (Migration 0001)
-- ═══════════════════════════════════════════════════════════
--
-- Source of truth for scoring events.
-- Points are NOT stored in events — they are derived at query
-- time via JOIN with point_rules, so changing rules auto-reflects.

-- ─── Events (Immutable Log) ────────────────────────────────

CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,              -- unique event ID (idempotency key)
  developer_id TEXT NOT NULL,       -- GitHub login or attendance identifier
  event_type TEXT NOT NULL,         -- PR_CREATED, PR_MERGED, PR_REVIEW, COMMENT,
                                    -- CHECK_IN, CHECK_OUT, ATTENDANCE_DURATION
  source TEXT NOT NULL,             -- 'github' | 'attendance' | 'manual'
  source_id TEXT,                   -- e.g. PR URL, meeting ID
  event_timestamp TEXT NOT NULL,    -- ISO 8601 UTC — when the event actually occurred
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  metadata TEXT                     -- JSON blob (standard keys enforced at ingestion)
);

-- Composite index for fast leaderboard aggregation
CREATE INDEX IF NOT EXISTS idx_events_agg ON events(event_type, event_timestamp, developer_id);
CREATE INDEX IF NOT EXISTS idx_events_developer ON events(developer_id);

-- ─── Point Rules ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS point_rules (
  event_type TEXT PRIMARY KEY,
  points INTEGER NOT NULL,
  description TEXT,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seed default point rules
INSERT OR IGNORE INTO point_rules (event_type, points, description) VALUES
  ('PR_CREATED',          3, 'Developer created a pull request'),
  ('PR_MERGED',           2, 'Pull request was merged'),
  ('PR_REVIEW',           0, 'Developer reviewed a pull request'),
  ('COMMENT',             1, 'Developer left a comment on a PR'),
  ('CHECK_IN',            2, 'Developer checked in to a meeting/session'),
  ('CHECK_OUT',           0, 'Developer checked out of a meeting/session'),
  ('ATTENDANCE_DURATION', 1, 'Per 15-minute block of attendance duration');

-- ─── Events Archive (for old events) ──────────────────────

CREATE TABLE IF NOT EXISTS events_archive (
  id TEXT PRIMARY KEY,
  developer_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  source TEXT NOT NULL,
  source_id TEXT,
  event_timestamp TEXT NOT NULL,
  created_at TEXT NOT NULL,
  metadata TEXT,
  archived_at TEXT NOT NULL DEFAULT (datetime('now'))
);
