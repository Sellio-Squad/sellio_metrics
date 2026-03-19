-- Migration 0007: Drop is_bot column from developers
-- Bots are filtered before insert so this column is always 0 and serves no purpose.
-- D1 (SQLite 3.37+) supports ALTER TABLE DROP COLUMN for columns without indexes or FKs.

ALTER TABLE developers DROP COLUMN is_bot;
