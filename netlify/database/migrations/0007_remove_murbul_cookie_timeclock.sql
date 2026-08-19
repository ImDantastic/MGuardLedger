-- Remove the guard "Rotskull, Murbul Cookie" (badge MG-26) from the guard Time Clock.
--
-- This guard was left clocked in and kept appearing under "Currently On Duty" on
-- the guard Time Clock for everyone. An earlier fix soft-deleted the row directly
-- against the preview database branch, but ad-hoc branch data edits are not
-- promoted to the production database on publish -- only migrations are. So the
-- live site (which reads production) still showed him on duty. Applying the
-- removal as a migration is the durable path: this exact statement runs against
-- production when the deploy is published.
--
-- The removal mirrors what the app's own /api/tc/sync delete does (and matches the
-- map-clearing migrations 0002/0003): mark the record deleted and draw a fresh
-- `version` from timeclock_record_version_seq rather than physically removing the
-- row, so the change rides the same sync mechanism every other Time Clock edit
-- uses:
--   * /api/tc/state filters on deleted = false, so fresh loads no longer list him;
--   * /api/tc/changes reports the row as a deletion with a newer version, so any
--     Time Clock screen already open receives the tombstone and drops him from
--     "Currently On Duty" in near-real-time.
--
-- Matched by the stable record_id, with the guard's name as a defensive fallback,
-- scoped to the `timeclock` collection so no other section is touched.

UPDATE timeclock_records
SET deleted = true,
    version = nextval('timeclock_record_version_seq'),
    updated_at = now()
WHERE collection = 'timeclock'
  AND (record_id = 'mr8jm6a5frdk8' OR data->>'name' = 'Rotskull, Murbul Cookie');
