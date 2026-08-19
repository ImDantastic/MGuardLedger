// Standalone real-time sync API for the guard Time Clock.
//
// This is a deliberate twin of the guard `sync.mjs` and the Auxilia
// `auxsync.mjs`, but it is wired to its own `timeclock_records` table and
// `timeclock_record_version_seq` so the guard Time Clock persists through a
// completely independent path. Nothing here reads or writes the shared
// `records` table, and the guard sync never touches `timeclock_records` — the
// two stores are fully decoupled, exactly like the Auxilia Time Clock is.
//
//   GET  /api/tc/state          → full snapshot { version, records: { collection: [...] } }
//   GET  /api/tc/changes?since= → rows written after a given version { version, rows: [...] }
//   POST /api/tc/sync           → apply { upserts:[{collection,id,data}], deletes:[{collection,id}] }
//
// All Time Clock records live in `timeclock_records`, keyed by
// (collection, record_id). Every write bumps a monotonic `version`
// (timeclock_record_version_seq) so clients can cheaply poll for "everything
// that changed since version N".

import { getDatabase } from "@netlify/database";

const db = getDatabase();

// The only collection the guard Time Clock owns.
const COLLECTIONS = ["timeclock"];

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

async function maxVersion() {
  const [row] = await db.sql`SELECT COALESCE(MAX(version), 0)::bigint AS v FROM timeclock_records`;
  return Number(row.v);
}

// Full snapshot of every live (non-deleted) Time Clock record, grouped by collection.
async function handleState() {
  const rows = await db.sql`
    SELECT collection, data FROM timeclock_records WHERE deleted = false`;
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
    FROM timeclock_records
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

// Apply a batch of per-record upserts and deletes. Each record is keyed and
// versioned independently, so the statements are applied one-by-one over the
// HTTP `db.sql` transport — any record that doesn't land is simply re-sent on
// the client's next push.
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
        INSERT INTO timeclock_records (collection, record_id, data, deleted, version, updated_at)
        VALUES (${String(u.collection)}, ${String(u.id)}, ${JSON.stringify(u.data ?? {})}::jsonb, false, nextval('timeclock_record_version_seq'), now())
        ON CONFLICT (collection, record_id) DO UPDATE SET
          data = EXCLUDED.data,
          deleted = false,
          version = nextval('timeclock_record_version_seq'),
          updated_at = now()`;
    }
    for (const d of deletes) {
      if (!d || d.collection == null || d.id == null) continue;
      await db.sql`
        UPDATE timeclock_records SET
          deleted = true,
          version = nextval('timeclock_record_version_seq'),
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
    if (path.endsWith("/tc/state") && req.method === "GET") return await handleState();
    if (path.endsWith("/tc/changes") && req.method === "GET") return await handleChanges(url);
    if (path.endsWith("/tc/sync") && req.method === "POST") return await handleSync(req);
    return json({ error: "Not found" }, 404);
  } catch (e) {
    return json({ error: String(e?.message || e) }, 500);
  }
};

export const config = {
  path: ["/api/tc/state", "/api/tc/changes", "/api/tc/sync"],
};
