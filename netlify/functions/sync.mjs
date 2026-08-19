// Shared real-time sync API for the Morthal Guard Command System.
//
// The browser app keeps an in-memory copy of every hold record and talks to
// this function to stay in step with every other connected guard:
//
//   GET  /api/state          → full snapshot { version, records: { collection: [...] } }
//   GET  /api/changes?since= → rows written after a given version { version, rows: [...] }
//   POST /api/sync           → apply { upserts:[{collection,id,data}], deletes:[{collection,id}] }
//
// All records live in a single `records` table keyed by (collection, record_id).
// Every write bumps a monotonic `version` (record_version_seq) so clients can
// cheaply poll for "everything that changed since version N".

import { getDatabase } from "@netlify/database";

const db = getDatabase();

// Collections surfaced to the client. `settings` is a single "singleton" row.
// The Auxilia section (auxGuards / auxTasks / auxActivities) is intentionally
// NOT here — it persists through its own table and function (auxsync.mjs,
// /api/aux/*) so the two stores stay fully decoupled.
const COLLECTIONS = [
  "guards",
  "tasks",
  "activities",
  "reports",
  "wanted",
  "auditLog",
  "mapMarkers",
  "mapRoutes",
  "timeclock",
  "settings",
];

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

async function maxVersion() {
  const [row] = await db.sql`SELECT COALESCE(MAX(version), 0)::bigint AS v FROM records`;
  return Number(row.v);
}

// Full snapshot of every live (non-deleted) record, grouped by collection.
async function handleState() {
  const rows = await db.sql`
    SELECT collection, data FROM records WHERE deleted = false`;
  const records = {};
  for (const c of COLLECTIONS) records[c] = [];
  for (const r of rows) {
    if (!records[r.collection]) records[r.collection] = [];
    records[r.collection].push(r.data);
  }
  return json({ version: await maxVersion(), records });
}

// Everything written after `since`, including tombstones (deleted = true) so
// clients can drop locally-held records that other guards removed.
async function handleChanges(url) {
  const since = Number(url.searchParams.get("since") || 0) || 0;
  const rows = await db.sql`
    SELECT collection, record_id, data, deleted, version
    FROM records
    WHERE version > ${since}
    ORDER BY version ASC`;
  return json({
    version: await maxVersion(),
    rows: rows.map((r) => ({
      collection: r.collection,
      record_id: r.record_id,
      data: r.data,
      deleted: r.deleted,
    })),
  });
}

// Apply a batch of per-record upserts and deletes.
//
// Writes run over the same `db.sql` (HTTP) transport that handleState and
// handleChanges read from. The earlier implementation used `db.pool.connect()`
// for an interactive transaction, but that pool is a separate (WebSocket-based)
// transport that is not always reachable from the function runtime — when it
// failed, reads kept working while every write silently errored, so newly
// added records were never persisted even though the app still looked "live
// synced". Each record is keyed and versioned independently, so applying the
// statements one-by-one (rather than in a single transaction) is sufficient:
// any record that doesn't land is simply re-sent on the client's next push.
async function handleSync(req) {
  let body;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const upserts = Array.isArray(body?.upserts) ? body.upserts : [];
  const deletes = Array.isArray(body?.deletes) ? body.deletes : [];

  try {
    for (const u of upserts) {
      if (!u || u.collection == null || u.id == null) continue;
      await db.sql`
        INSERT INTO records (collection, record_id, data, deleted, version, updated_at)
        VALUES (${String(u.collection)}, ${String(u.id)}, ${JSON.stringify(u.data ?? {})}::jsonb, false, nextval('record_version_seq'), now())
        ON CONFLICT (collection, record_id) DO UPDATE SET
          data = EXCLUDED.data,
          deleted = false,
          version = nextval('record_version_seq'),
          updated_at = now()`;
    }
    for (const d of deletes) {
      if (!d || d.collection == null || d.id == null) continue;
      await db.sql`
        UPDATE records SET
          deleted = true,
          version = nextval('record_version_seq'),
          updated_at = now()
        WHERE collection = ${String(d.collection)} AND record_id = ${String(d.id)}`;
    }
  } catch (e) {
    return json({ error: String(e?.message || e) }, 500);
  }
  return json({ ok: true, version: await maxVersion() });
}

export default async (req) => {
  const url = new URL(req.url);
  const path = url.pathname;
  try {
    if (path.endsWith("/state") && req.method === "GET") return await handleState();
    if (path.endsWith("/changes") && req.method === "GET") return await handleChanges(url);
    if (path.endsWith("/sync") && req.method === "POST") return await handleSync(req);
    return json({ error: "Not found" }, 404);
  } catch (e) {
    return json({ error: String(e?.message || e) }, 500);
  }
};

export const config = {
  path: ["/api/state", "/api/changes", "/api/sync"],
};
