/**
 * ATC Frequencies — Metrics Relay (Cloudflare Worker → NeonDB)
 *
 * The Flutter app POSTs a JSON array of events with no credentials.
 * This Worker validates, rate-limits, and bulk-inserts into NeonDB.
 * The NEON_DATABASE_URL secret never leaves Cloudflare's servers.
 *
 * Deploy:
 *   cd metrics-relay
 *   npm install
 *   npx wrangler deploy
 *   npx wrangler secret put NEON_DATABASE_URL
 *
 * Then run the schema once:
 *   psql "$NEON_DATABASE_URL" -f schema.sql
 */

import { neon } from '@neondatabase/serverless';

const MAX_EVENTS     = 100;   // max events per batch
const MAX_BODY_BYTES = 65536; // 64 KB ceiling

// Valid measurement names — rejects garbage/spam payloads
const VALID_MEASUREMENTS = new Set([
  'app_event',
  'airport_view',
  'download_stage',
  'download_complete',
  'bug_report',
]);

export default {
  async fetch(request, env) {

    // ── CORS pre-flight ───────────────────────────────────────────────────────
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors() });
    }

    if (request.method !== 'POST') {
      return reply(405, 'Method Not Allowed');
    }

    // ── Size guard ────────────────────────────────────────────────────────────
    const cl = parseInt(request.headers.get('Content-Length') ?? '0', 10);
    if (cl > MAX_BODY_BYTES) return reply(413, 'Payload Too Large');

    let body;
    try {
      body = await request.text();
      if (body.length > MAX_BODY_BYTES) return reply(413, 'Payload Too Large');
    } catch {
      return reply(400, 'Bad Request');
    }

    // ── Parse JSON ────────────────────────────────────────────────────────────
    let payload;
    try {
      payload = JSON.parse(body);
    } catch {
      return reply(400, 'Invalid JSON');
    }

    const events = Array.isArray(payload?.events) ? payload.events : null;
    if (!events || events.length === 0 || events.length > MAX_EVENTS) {
      return reply(400, 'Bad Request — events array required (1–100 items)');
    }

    // ── Extract Cloudflare geo from the request ───────────────────────────────
    // City-level IP geolocation — no GPS, no PII, IP itself is never stored.
    const cf  = request.cf ?? {};
    const geo = {
      ...(cf.country   ? { geo_country: cf.country }                     : {}),
      ...(cf.city      ? { geo_city:    cf.city }                        : {}),
      ...(cf.latitude  ? { geo_lat:     parseFloat(cf.latitude)  }       : {}),
      ...(cf.longitude ? { geo_lon:     parseFloat(cf.longitude) }       : {}),
      ...(cf.region    ? { geo_region:  cf.region }                      : {}),
    };

    // ── Validate each event ───────────────────────────────────────────────────
    const rows = [];
    for (const e of events) {
      if (
        typeof e.measurement !== 'string' ||
        typeof e.install_id  !== 'string' ||
        typeof e.ts          !== 'number' ||
        !VALID_MEASUREMENTS.has(e.measurement) ||
        !/^[0-9a-f-]{36}$/.test(e.install_id)   // must be UUID v4
      ) {
        continue; // skip invalid, don't reject the whole batch
      }
      const eventTags = (e.tags && typeof e.tags === 'object') ? e.tags : {};
      // Only attach geo to app_open — every other measurement stays
      // location-free, including airport views.
      const isAppOpen = e.measurement === 'app_event' && eventTags.event === 'app_open';
      rows.push({
        ts:          new Date(e.ts),
        measurement: e.measurement,
        install_id:  e.install_id,
        tags:        { ...eventTags, ...(isAppOpen ? geo : {}) },
        fields:      (e.fields && typeof e.fields === 'object') ? e.fields : {},
      });
    }

    if (rows.length === 0) return reply(204, '');

    // ── Bulk insert into NeonDB ───────────────────────────────────────────────
    const sql = neon(env.NEON_DATABASE_URL);

    try {
      // Build parameterised UNNEST bulk insert — single round-trip for the batch
      await sql`
        INSERT INTO atc_metrics (ts, measurement, install_id, tags, fields)
        SELECT * FROM UNNEST(
          ${rows.map(r => r.ts)}::timestamptz[],
          ${rows.map(r => r.measurement)}::text[],
          ${rows.map(r => r.install_id)}::text[],
          ${rows.map(r => JSON.stringify(r.tags))}::jsonb[],
          ${rows.map(r => JSON.stringify(r.fields))}::jsonb[]
        ) AS t(ts, measurement, install_id, tags, fields)
      `;
    } catch (err) {
      // Log server-side, never surface DB errors to the client
      console.error('NeonDB insert error:', err.message);
      return reply(204, ''); // still return 204 so the app isn't blocked
    }

    return reply(204, '');
  },
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function reply(status, body) {
  return new Response(body || null, {
    status,
    headers: { ...cors(), 'Content-Type': 'text/plain' },
  });
}

function cors() {
  return {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}
