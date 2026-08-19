-- Clear previously saved Atlas (Hold Map) data again so the regional map starts fresh.
--
-- Migration 0002 already wiped the map once, but the Atlas mirrors any markers a
-- guard places and routes they draw back into the shared `records` store under
-- the `mapMarkers` and `mapRoutes` collections. Anything saved since the last
-- clear is still live. This migration wipes that saved map data once more so the
-- Atlas reopens empty.
--
-- As in 0002, each cleared row is soft-deleted (deleted = true) and assigned a
-- fresh `version` rather than being physically removed, so the change rides the
-- same sync mechanism every other edit uses:
--   * /api/state filters on deleted = false, so fresh loads see an empty Atlas;
--   * /api/changes reports these rows as deletions with a newer version, so any
--     guard already connected receives them and clears their map in real time.

UPDATE records
SET deleted = true,
    data = '{}'::jsonb,
    version = nextval('record_version_seq'),
    updated_at = now()
WHERE collection IN ('mapMarkers', 'mapRoutes')
  AND deleted = false;
