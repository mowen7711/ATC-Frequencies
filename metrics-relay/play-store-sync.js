/**
 * ATC Frequencies — Play Store GCS Sync
 *
 * Pulls Play Console CSV exports from Google Cloud Storage into NeonDB.
 * Run daily via cron, GitHub Actions, or manually.
 *
 * Required env vars:
 *   GOOGLE_APPLICATION_CREDENTIALS  path to your service account JSON file
 *   GCS_BUCKET                      e.g. pubsite_prod_XXXXXXXX
 *   NEON_DATABASE_URL               postgres connection string
 *
 * Install deps:
 *   npm install @google-cloud/storage @neondatabase/serverless csv-parse
 *
 * Run:
 *   node play-store-sync.js
 */

import { Storage }    from '@google-cloud/storage';
import { neon }       from '@neondatabase/serverless';
import { parse }      from 'csv-parse/sync';

// ── Configuration ─────────────────────────────────────────────────────────────

const BUCKET_NAME   = process.env.GCS_BUCKET;
const PACKAGE_NAME  = 'com.atcfreq.atc_freq';

if (!BUCKET_NAME)            throw new Error('GCS_BUCKET env var is required');
if (!process.env.NEON_DATABASE_URL) throw new Error('NEON_DATABASE_URL env var is required');

const sql     = neon(process.env.NEON_DATABASE_URL);
const storage = new Storage();   // uses GOOGLE_APPLICATION_CREDENTIALS automatically
const bucket  = storage.bucket(BUCKET_NAME);

// ── Report type definitions ───────────────────────────────────────────────────

const REPORT_TYPES = {
  installs: {
    prefix:  `stats/installs/${PACKAGE_NAME}`,
    handler: insertInstalls,
  },
  ratings: {
    prefix:  `stats/ratings/${PACKAGE_NAME}`,
    handler: insertRatings,
  },
  store_performance: {
    prefix:  `stats/store_performance/${PACKAGE_NAME}`,
    handler: insertStorePerformance,
  },
};

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`[play-store-sync] Starting sync from bucket: ${BUCKET_NAME}`);

  // Load already-synced filenames from NeonDB
  const synced = new Set(
    (await sql`SELECT filename FROM ps_sync_log`).map(r => r.filename)
  );
  console.log(`[play-store-sync] ${synced.size} files already synced`);

  let totalNew = 0;

  for (const [reportType, { prefix, handler }] of Object.entries(REPORT_TYPES)) {
    const [files] = await bucket.getFiles({ prefix });

    for (const file of files) {
      const filename = file.name;

      // Skip already processed files
      if (synced.has(filename)) continue;

      // Only process CSVs for our package
      if (!filename.endsWith('.csv')) continue;

      console.log(`[play-store-sync] Processing: ${filename}`);

      try {
        const [contents] = await file.download();
        const csv = contents.toString('utf8')
          // Play Console CSVs sometimes have a BOM
          .replace(/^﻿/, '');

        const rows = parse(csv, {
          columns:          true,
          skip_empty_lines: true,
          trim:             true,
        });

        if (rows.length === 0) {
          console.log(`  → Empty file, skipping`);
          await logSync(filename, reportType, 0);
          continue;
        }

        const count = await handler(rows);
        await logSync(filename, reportType, count);
        console.log(`  → Inserted/updated ${count} rows`);
        totalNew++;

      } catch (err) {
        console.error(`  → ERROR processing ${filename}:`, err.message);
        // Continue with other files — don't let one bad file stop the sync
      }
    }
  }

  console.log(`[play-store-sync] Done. ${totalNew} new files processed.`);
}

// ── Handlers ──────────────────────────────────────────────────────────────────

async function insertInstalls(rows) {
  // Play Console CSV columns (exact names vary slightly by region/date):
  // Date, Package Name, Country, Daily Device Installs, Daily Device Uninstalls,
  // Daily Device Upgrades, Total User Installs, Daily User Installs,
  // Daily User Uninstalls, Active Device Installs

  const parsed = rows.map(r => ({
    date:                    parseDate(r['Date'] ?? r['date']),
    country:                 (r['Country'] ?? r['country'] ?? 'ZZ').trim(),
    daily_device_installs:   int(r['Daily Device Installs']),
    daily_device_uninstalls: int(r['Daily Device Uninstalls']),
    daily_device_upgrades:   int(r['Daily Device Upgrades']),
    total_user_installs:     int(r['Total User Installs']),
    daily_user_installs:     int(r['Daily User Installs']),
    daily_user_uninstalls:   int(r['Daily User Uninstalls']),
    active_device_installs:  int(r['Active Device Installs']),
  })).filter(r => r.date !== null);

  if (parsed.length === 0) return 0;

  await sql`
    INSERT INTO ps_installs
      (date, country,
       daily_device_installs, daily_device_uninstalls, daily_device_upgrades,
       total_user_installs, daily_user_installs, daily_user_uninstalls,
       active_device_installs)
    SELECT * FROM UNNEST(
      ${parsed.map(r => r.date)}::date[],
      ${parsed.map(r => r.country)}::text[],
      ${parsed.map(r => r.daily_device_installs)}::int[],
      ${parsed.map(r => r.daily_device_uninstalls)}::int[],
      ${parsed.map(r => r.daily_device_upgrades)}::int[],
      ${parsed.map(r => r.total_user_installs)}::bigint[],
      ${parsed.map(r => r.daily_user_installs)}::int[],
      ${parsed.map(r => r.daily_user_uninstalls)}::int[],
      ${parsed.map(r => r.active_device_installs)}::bigint[]
    ) AS t(date, country,
           daily_device_installs, daily_device_uninstalls, daily_device_upgrades,
           total_user_installs, daily_user_installs, daily_user_uninstalls,
           active_device_installs)
    ON CONFLICT (date, country) DO UPDATE SET
      daily_device_installs   = EXCLUDED.daily_device_installs,
      daily_device_uninstalls = EXCLUDED.daily_device_uninstalls,
      daily_device_upgrades   = EXCLUDED.daily_device_upgrades,
      total_user_installs     = EXCLUDED.total_user_installs,
      daily_user_installs     = EXCLUDED.daily_user_installs,
      daily_user_uninstalls   = EXCLUDED.daily_user_uninstalls,
      active_device_installs  = EXCLUDED.active_device_installs
  `;

  return parsed.length;
}

async function insertRatings(rows) {
  // Date, Package Name, Country, Daily Average Rating, Total Average Rating

  const parsed = rows.map(r => ({
    date:                 parseDate(r['Date'] ?? r['date']),
    country:              (r['Country'] ?? r['country'] ?? 'ZZ').trim(),
    daily_average_rating: float(r['Daily Average Rating']),
    total_average_rating: float(r['Total Average Rating']),
  })).filter(r => r.date !== null);

  if (parsed.length === 0) return 0;

  await sql`
    INSERT INTO ps_ratings (date, country, daily_average_rating, total_average_rating)
    SELECT * FROM UNNEST(
      ${parsed.map(r => r.date)}::date[],
      ${parsed.map(r => r.country)}::text[],
      ${parsed.map(r => r.daily_average_rating)}::numeric[],
      ${parsed.map(r => r.total_average_rating)}::numeric[]
    ) AS t(date, country, daily_average_rating, total_average_rating)
    ON CONFLICT (date, country) DO UPDATE SET
      daily_average_rating = EXCLUDED.daily_average_rating,
      total_average_rating = EXCLUDED.total_average_rating
  `;

  return parsed.length;
}

async function insertStorePerformance(rows) {
  // Date, Package Name, Country, Store Listing Visitors, Store Listing Acquisitions

  const parsed = rows.map(r => ({
    date:                       parseDate(r['Date'] ?? r['date']),
    country:                    (r['Country'] ?? r['country'] ?? 'ZZ').trim(),
    store_listing_visitors:     int(r['Store Listing Visitors']),
    store_listing_acquisitions: int(r['Store Listing Acquisitions']),
  })).filter(r => r.date !== null);

  if (parsed.length === 0) return 0;

  await sql`
    INSERT INTO ps_store_performance
      (date, country, store_listing_visitors, store_listing_acquisitions)
    SELECT * FROM UNNEST(
      ${parsed.map(r => r.date)}::date[],
      ${parsed.map(r => r.country)}::text[],
      ${parsed.map(r => r.store_listing_visitors)}::int[],
      ${parsed.map(r => r.store_listing_acquisitions)}::int[]
    ) AS t(date, country, store_listing_visitors, store_listing_acquisitions)
    ON CONFLICT (date, country) DO UPDATE SET
      store_listing_visitors     = EXCLUDED.store_listing_visitors,
      store_listing_acquisitions = EXCLUDED.store_listing_acquisitions
  `;

  return parsed.length;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

async function logSync(filename, reportType, rowCount) {
  await sql`
    INSERT INTO ps_sync_log (filename, report_type, row_count)
    VALUES (${filename}, ${reportType}, ${rowCount})
    ON CONFLICT (filename) DO NOTHING
  `;
}

function parseDate(val) {
  if (!val) return null;
  // Play Console uses YYYY-MM-DD or YYYYMMDD
  const s = String(val).trim().replace(/(\d{4})(\d{2})(\d{2})/, '$1-$2-$3');
  const d = new Date(s);
  return isNaN(d.getTime()) ? null : s.slice(0, 10);
}

function int(val) {
  const n = parseInt(String(val ?? '0').replace(/,/g, ''), 10);
  return isNaN(n) ? 0 : n;
}

function float(val) {
  const n = parseFloat(String(val ?? '0').replace(/,/g, ''));
  return isNaN(n) ? 0 : n;
}

// ── Run ───────────────────────────────────────────────────────────────────────

main().catch(err => {
  console.error('[play-store-sync] Fatal error:', err);
  process.exit(1);
});
