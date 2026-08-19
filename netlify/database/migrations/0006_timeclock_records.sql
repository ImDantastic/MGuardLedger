-- Dedicated, standalone store for the guard Time Clock.
--
-- The guard Time Clock (the `timeclock` collection: one clock-in/out record per
-- guard) used to share the single `records` table (and its `record_version_seq`)
-- with the rest of the guard section, syncing through the same /api/sync
-- endpoint. In practice the clock never stayed in step across guards — clock-ins
-- one guard made never showed up on anyone else's screen — while the Auxilia
-- Time Clock, which already lived on its own decoupled table and function
-- (aux_records / /api/aux/*), worked perfectly.
--
-- This migration gives the guard Time Clock the exact same treatment as the
-- Auxilia clock: its own table and its own version sequence, so it persists
-- through a completely independent path. Nothing the Time Clock stores touches
-- the shared guard `records` table, and nothing in the guard records touches it.
--
-- The layout mirrors `records` (and `aux_records`) so the same record-by-record,
-- version-polled sync mechanism works unchanged. Every Time Clock record (the
-- `timeclock` collection) is one row keyed by (collection, record_id). A
-- monotonic `version` column, fed by this table's own sequence, lets connected
-- clients poll for "everything newer than the last version I saw" to receive
-- near-real-time updates.

CREATE SEQUENCE IF NOT EXISTS timeclock_record_version_seq;

CREATE TABLE IF NOT EXISTS timeclock_records (
  collection  TEXT        NOT NULL,
  record_id   TEXT        NOT NULL,
  data        JSONB       NOT NULL DEFAULT '{}'::jsonb,
  deleted     BOOLEAN     NOT NULL DEFAULT FALSE,
  version     BIGINT      NOT NULL DEFAULT nextval('timeclock_record_version_seq'),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (collection, record_id)
);

-- Polling reads filter and order by version, so index it.
CREATE INDEX IF NOT EXISTS timeclock_records_version_idx ON timeclock_records (version);

-- The live Time Clock sync function (/api/tc/sync) connects at runtime as the
-- `netlifydb_readonly` role. Grant it exactly the privileges that function
-- uses: SELECT to read the snapshot and poll for changes, INSERT/UPDATE to
-- apply edits (deletes are soft-deletes performed via UPDATE, so no DELETE is
-- needed), and USAGE on the version sequence so each write can draw a fresh
-- version number. Without these the function would read but silently fail every
-- write — the exact failure mode that previously kept the clock from ever
-- persisting across guards.
GRANT SELECT, INSERT, UPDATE ON TABLE timeclock_records TO netlifydb_readonly;
GRANT USAGE ON SEQUENCE timeclock_record_version_seq TO netlifydb_readonly;
