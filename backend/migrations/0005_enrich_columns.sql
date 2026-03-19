-- Migration 0005: Enrich relational tables with GitHub metadata
--
-- Adds columns that were missing from the initial schema:
--   repos.description, repos.github_created_at, repos.pushed_at
--   merged_prs.pr_created_at
--
-- D1/SQLite supports ADD COLUMN for nullable columns with no non-constant defaults.

ALTER TABLE repos ADD COLUMN github_created_at TEXT;   -- GitHub repo creation date
ALTER TABLE repos ADD COLUMN pushed_at         TEXT;   -- Last push date

ALTER TABLE merged_prs ADD COLUMN pr_created_at TEXT;  -- GitHub PR opened date
