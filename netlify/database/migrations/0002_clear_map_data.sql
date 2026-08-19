-- Clear previously saved Atlas (Hold Map) data so the regional map starts fresh.
--
-- The Atlas tab mirrors its placed markers and drawn routes into the shared
-- `records` store under the `mapMarkers` and `mapRoutes` collections. This
-- migration wipes that saved map data.
--
-- Each cleared row is soft-deleted (deleted = true) and assigned a fresh
-- `version` rather than being physically removed. That way the change rides the
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
