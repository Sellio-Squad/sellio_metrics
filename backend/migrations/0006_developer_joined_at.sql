-- Migration 0006: Developer enrichment columns
--
-- Adds joined_at (GitHub account creation date) to developers.
-- is_bot column is kept for backward compatibility but we no longer
-- store bots in this table — all bot filtering happens before insert.

ALTER TABLE developers ADD COLUMN joined_at TEXT;  -- GitHub account creation date (user.created_at)
