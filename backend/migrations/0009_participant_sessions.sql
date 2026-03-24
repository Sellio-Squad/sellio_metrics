-- Migration: Replace meeting_attendance with participant_sessions
-- Each row = one join-leave pair (handles rejoin gracefully)

DROP TABLE IF EXISTS meeting_attendance;

CREATE TABLE IF NOT EXISTS participant_sessions (
    id               TEXT PRIMARY KEY,           -- "{sessionId}:{participantKey}:{epochMs}"
    session_id       TEXT NOT NULL REFERENCES meeting_sessions(id),
    participant_key  TEXT NOT NULL,              -- "users/{userId}" or displayName for anonymous
    display_name     TEXT NOT NULL,
    start_time       TEXT,                       -- ISO timestamp, set on JOIN event
    end_time         TEXT,                       -- set on LEAVE event; NULL = still in meeting
    created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ps_session     ON participant_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_ps_participant ON participant_sessions(participant_key);
CREATE INDEX IF NOT EXISTS idx_ps_active      ON participant_sessions(session_id, end_time);
