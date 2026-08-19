-- Restore write access for the live sync function.
--
-- The Morthal Guard Command app persists every hold record by POSTing to the
-- `/api/sync` function, which writes into the shared `records` table and bumps
-- `record_version_seq`. At runtime that function connects to the database as the
-- `netlifydb_readonly` role. That role had only been granted SELECT, so every
-- write (INSERT/UPDATE) and every `nextval('record_version_seq')` was rejected
-- with a permission error.
--
-- The visible effect: reads worked, so the app loaded and looked "live synced",
-- but nothing newly entered ever reached the database. Records that already
-- existed on the server still re-appeared after a refresh (so the guard roster
-- looked like it persisted), while anything freshly created — most noticeably a
-- newly enlisted Auxilia member, since the Auxilia collections had no prior
-- server data to fall back on — silently vanished on the next load.
--
-- Migrations run as the table/sequence owner (`netlifydb_owner`), so this rolls
-- the fix forward by granting the runtime role exactly the privileges the sync
-- function uses: INSERT and UPDATE on `records` (it soft-deletes via UPDATE, so
-- no DELETE is needed) and USAGE on the version sequence.

GRANT INSERT, UPDATE ON TABLE records TO netlifydb_readonly;
GRANT USAGE ON SEQUENCE record_version_seq TO netlifydb_readonly;
