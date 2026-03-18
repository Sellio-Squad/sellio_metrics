-- ═══════════════════════════════════════════════════════════
-- Sellio Metrics — D1 Migration 0002
-- ═══════════════════════════════════════════════════════════
--
-- Adds CODE_ADDITION and CODE_DELETION point rules.
-- Scoring: points_per_event × lines_changed (stored as `lines` in metadata)

INSERT OR IGNORE INTO point_rules (event_type, points, description) VALUES
  ('CODE_ADDITION', 1, 'Points per line added in a PR (multiplied by line count)'),
  ('CODE_DELETION', 1, 'Points per line deleted in a PR (multiplied by line count)');
