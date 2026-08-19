-- Shared state store for the Morthal Guard Command System.
-- Every domain record (guards, duties, watch log entries, reports, bounties,
-- audit entries, and the settings singleton) is stored as one row here, keyed
-- by its collection and the record's own id. A monotonic `version` column,
-- fed by a sequence, lets connected clients poll for "everything newer than
-- the last version I saw" to receive near-real-time updates.

CREATE SEQUENCE IF NOT EXISTS record_version_seq;

CREATE TABLE IF NOT EXISTS records (
  collection  TEXT        NOT NULL,
  record_id   TEXT        NOT NULL,
  data        JSONB       NOT NULL DEFAULT '{}'::jsonb,
  deleted     BOOLEAN     NOT NULL DEFAULT FALSE,
  version     BIGINT      NOT NULL DEFAULT nextval('record_version_seq'),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (collection, record_id)
);

-- Polling reads filter and order by version, so index it.
CREATE INDEX IF NOT EXISTS records_version_idx ON records (version);
