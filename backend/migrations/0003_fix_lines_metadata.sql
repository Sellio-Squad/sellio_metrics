-- ═══════════════════════════════════════════════════════════
-- Sellio Metrics — D1 Migration 0003
-- ═══════════════════════════════════════════════════════════
--
-- Existing CODE_ADDITION / CODE_DELETION events were stored with
-- `score_multiplier` as the line-count key in their metadata JSON.
-- The scoring query now looks for `lines`, so we update all
-- pre-existing rows to rename the key in-place.
--
-- json_patch replaces / merges the metadata object:
--   BEFORE: {"pr_number": 1, "repo": "…", "score_multiplier": 42}
--   AFTER : {"pr_number": 1, "repo": "…", "score_multiplier": 42, "lines": 42}
--
-- Note: json_patch ADDS the `lines` key with the value from
-- score_multiplier. This is safe because:
--   1. New events already have `lines` and no `score_multiplier`.
--   2. Old events get both keys — the query uses `lines` (which wins).
--   3. COALESCE(lines, score_multiplier, 1) fallback is in the query.

UPDATE events
SET metadata = json_patch(
    metadata,
    json_object('lines', CAST(json_extract(metadata, '$.score_multiplier') AS REAL))
)
WHERE event_type IN ('CODE_ADDITION', 'CODE_DELETION')
  AND json_extract(metadata, '$.score_multiplier') IS NOT NULL
  AND json_extract(metadata, '$.lines') IS NULL;
