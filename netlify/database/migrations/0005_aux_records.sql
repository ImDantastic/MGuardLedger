-- Dedicated, standalone store for the Auxilia section.
--
-- The Auxilia roster, duties, and watch log used to share the single `records`
-- table (and its `record_version_seq`) with the guard section, syncing through
-- the same /api/sync endpoint. This migration gives the Auxilia section its own
-- table and its own version sequence so it persists through a completely
-- independent path: nothing the Auxilia section stores touches the guard
-- records, and nothing in the guard records touches it.
--
-- The layout mirrors `records` so the same record-by-record, version-polled
-- sync mechanism works unchanged. Every Auxilia record (the `auxGuards`,
-- `auxTasks`, and `auxActivities` collections) is one row keyed by
-- (collection, record_id). A monotonic `version` column, fed by this table's
-- own sequence, lets connected clients poll for "everything newer than the last
-- version I saw" to receive near-real-time updates.

CREATE SEQUENCE IF NOT EXISTS aux_record_version_seq;

CREATE TABLE IF NOT EXISTS aux_records (
  collection  TEXT        NOT NULL,
  record_id   TEXT        NOT NULL,
  data        JSONB       NOT NULL DEFAULT '{}'::jsonb,
  deleted     BOOLEAN     NOT NULL DEFAULT FALSE,
  version     BIGINT      NOT NULL DEFAULT nextval('aux_record_version_seq'),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (collection, record_id)
);

-- Polling reads filter and order by version, so index it.
CREATE INDEX IF NOT EXISTS aux_records_version_idx ON aux_records (version);

-- The live Auxilia sync function (/api/aux/sync) connects at runtime as the
-- `netlifydb_readonly` role. Grant it exactly the privileges that function
-- uses: SELECT to read the snapshot and poll for changes, INSERT/UPDATE to
-- apply edits (deletes are soft-deletes performed via UPDATE, so no DELETE is
-- needed), and USAGE on the version sequence so each write can draw a fresh
-- version number. Without these the function would read but silently fail every
-- write — the exact failure mode that previously made newly enlisted Auxilia
-- members vanish on refresh.
GRANT SELECT, INSERT, UPDATE ON TABLE aux_records TO netlifydb_readonly;
GRANT USAGE ON SEQUENCE aux_record_version_seq TO netlifydb_readonly;
