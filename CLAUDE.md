# ATC Frequencies — Project Context

## What this app does
Flutter Android app (v1.0.1) listing worldwide airport ATC frequencies. **Live on Google Play** (production, £0.99): https://play.google.com/store/apps/details?id=com.atcfreq.atc_freq Users can search ~70,000 airports by name/ICAO/IATA/city, star favourites, pin a home airport, view nearby airports via GPS, see a map, calculate VHF signal reception, and link out to LiveATC.net for live audio. A toggleable foreground service shows a persistent notification listing the nearest airports.

## Project location
`/Users/mark/Projects/atc_freq`

## Build / run
```bash
cd /Users/mark/Projects/atc_freq
/Users/mark/Documents/projects/flutter/bin/flutter build apk --release
/Users/mark/Documents/projects/flutter/bin/flutter build appbundle   # Play Store
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am force-stop com.atcfreq.atc_freq
adb shell am start -n com.atcfreq.atc_freq/com.atcfreq.atc_freq.MainActivity
```
Android SDK: `~/Library/Android/sdk`. Java: temurin@17 (`/opt/homebrew/opt/temurin@17`).
Flutter: `/Users/mark/Documents/projects/flutter/bin/flutter`

---

## Tech stack

| Layer | Package | Version | Notes |
|-------|---------|---------|-------|
| Framework | Flutter/Dart | sdk ≥3.3.0 | Android only in practice |
| Local DB | sqflite | **^2.2.8+4** | **PINNED** — 2.3.x requires Android NDK |
| State | provider | ^6.1.2 | ChangeNotifier pattern |
| GPS | geolocator | ^13.0.1 | Permission + altitude |
| Background service | flutter_foreground_task | ^8.14.0 | Nearby airport notification |
| Persistent notifications | flutter_local_notifications | ^17.2.3 | Frequency display notification |
| Maps | flutter_map | ^7.0.2 | OpenStreetMap, no API key |
| CSV parsing | csv | ^6.0.0 | Parsed in `compute()` isolate |
| Preferences | shared_preferences | ^2.3.2 | Settings + favourites |
| HTTP | http | ^1.2.1 | CSV download + metrics POST |
| Accelerometer | sensors_plus | ^6.1.0 | Shake-to-report |
| URL launching | url_launcher | ^6.3.0 | LiveATC.net links |
| Package info | package_info_plus | ^8.0.0 | Version display + metrics |

---

## Data source
OurAirports.com (CC0). Four CSVs downloaded on first launch, refreshed weekly:
- `airports.csv` (~6 MB, ~70,000 rows)
- `airport-frequencies.csv` (~3 MB, ~90,000 rows)
- `runways.csv` (~2 MB)
- `navaids.csv` (~2 MB)

URLs in `lib/constants.dart`. No API key. No rate limiting.

---

## File structure

### `lib/`
```
constants.dart          — colours, URLs, DistanceUnit enum, formatDistance(), formatRadius()
main.dart               — MultiProvider setup, dark/light/system ThemeData, _Root with shake + splash overlay

models/
  airport.dart          — Airport.fromCsvRow(), distanceTo() Haversine, displayCode getter
  frequency.dart        — Frequency.fromCsvRow(), sortWeight, color getter
  navaid.dart           — Navaid.fromCsvRow(), frequencyDisplay, isIls
  runway.dart           — Runway.fromCsvRow()

providers/
  app_provider.dart     — AppState, favourites, search, nearby, homeAirport, distanceUnit, hideNoFreq, needsDisclaimer
  theme_provider.dart   — ThemeMode persisted in SharedPreferences (key: theme_mode)

screens/
  splash_screen.dart    — Intro animation (plane + radio arcs + tagline), calls onDone() callback
  loading_screen.dart   — Landing animation (plane on runway), progress bar, humorous messages
  home_screen.dart      — IndexedStack bottom nav: Favourites(0), Nearby(1), Search(2), Settings(3)
  airport_detail_screen.dart — SliverAppBar, map, frequencies + disclaimer banner, signal reception, airport info
  nearby_screen.dart    — GPS nearby with radius chips + freq filter chip (km or miles), map toggle
  search_screen.dart    — Real-time search with debounce + freq filter chip
  settings_screen.dart  — Appearance, monitoring, data, distance unit, data transparency, feedback, disclaimer

services/
  data_service.dart     — ensureData() / forceRefresh(), humorous progress messages
  database_service.dart — SQLite CRUD, batch inserts, Haversine nearby, requireFrequencies filter
  background_service.dart — flutter_foreground_task, nearby airport notification
  frequency_notification_service.dart — Pinned frequency list notification
  location_service.dart — Geolocator wrapper → LocationResult
  terrain_service.dart  — VHF signal model, SignalResult, SignalQuality enum
  metrics_service.dart  — Anonymous analytics → Cloudflare Worker → NeonDB
  sdr_service.dart      — iqsrc:// intent for RTL-SDR / SDR Touch integration
  shake_service.dart    — Accelerometer shake detection (threshold 28 m/s², 2.5s cooldown)

theme/
  app_colors.dart       — AppColors ThemeExtension (dark + light), context.col extension

widgets/
  airport_tile.dart     — Airport list item with distance, type strip, favourite button
  frequency_card.dart   — Frequency row with type badge, copy + SDR listen button
  bug_report_sheet.dart — Bottom sheet bug report (shake or button triggered)
  disclaimer_banner.dart — Persistent amber banner on every ATC frequencies section
  disclaimer_dialog.dart — First-launch modal with checkbox + I Agree button; exports kDisclaimerText
  home_airport_card.dart — Home airport banner in Favourites tab
  runway_card.dart      — Runway info with ILS chip
  signal_reception_card.dart — VHF reception estimate + LiveATC suggestion
  update_banner.dart    — Background update in progress banner
```

### Outside `lib/`
```
metrics-relay/
  index.js              — Cloudflare Worker: validates + bulk-inserts metrics to NeonDB
  wrangler.toml         — Worker config (secret: NEON_DATABASE_URL)
  schema.sql            — NeonDB atc_metrics table + indexes
  package.json          — @neondatabase/serverless dependency

grafana/
  overview.json         — App opens, installs, feature usage, locale, version split
  content.json          — Top airports, freq types copied, SDR/LiveATC metrics
  performance.json      — Download stage timings p50/p95/p99
  bugs.json             — Bug report dashboard with full report text table
  map.json              — World map of app launches (Cloudflare IP geolocation)

assets/
  icon/                 — App icon SVG/PNG, plane_only.png (splash), plane_side.png (loading)
  data/                 — (empty — data downloaded at runtime)

docs/
  index.html            — Marketing website (atc-frequencies.app), deployed to root@100.103.65.20:/var/www/atcfrequencies/ via rsync
  privacy-policy.html   — Privacy policy (linked from Play Store)
  feature-graphic.svg   — Play Store feature graphic 1024×500px

marketing/
  outreach-log.md       — Tracks every drafted/posted piece of content (dedup for agent)
  *-draft.md            — Individual channel drafts (frontmatter: channel, type, status, date)

marketing-ui/
  server.js             — Express API server for the marketing dashboard
  public/index.html     — Dashboard UI (view/manage drafts, mark posted, delete)
  nginx.conf            — nginx site config (Tailscale-only, port 8090)
  deploy.sh             — Full deploy script (Mac → server via rsync+ssh)
  — Deployed at http://100.103.65.20:8090 (Tailscale peers only)
  — App: /opt/atc-marketing-ui/ on 4t-tech-ubnt-01, systemd service: atc-marketing-ui
  — To redeploy: bash marketing-ui/deploy.sh
  — Code-only update: rsync marketing-ui/ then systemctl restart atc-marketing-ui
```

---

## Providers

### AppProvider (`lib/providers/app_provider.dart`)
Single ChangeNotifier for all app state.

**SharedPreferences keys:**
- `home_airport_ident` — ICAO string
- `distance_unit` — `"km"` or `"miles"`
- `hide_no_freq` — bool, filter out airports with no frequency data
- `disclaimer_agreed` — bool, set true once user accepts the first-launch disclaimer

**Key getters:**
- `state` — AppState.loading / ready / error
- `distanceUnit` — DistanceUnit enum (km/miles)
- `nearbyRadius` — double (always km internally)
- `hideNoFreq` — bool, whether "With frequencies only" filter is active
- `needsDisclaimer` — bool, true if disclaimer has not yet been accepted
- `runwayLabels` — List<String> shown on loading screen during refresh
- `estimatedTimeRemaining` — String? ETA during download

**Key methods:**
- `toggleHideNoFreq()` — flips the filter, persists, re-runs active search/nearby query
- `acceptDisclaimer()` — sets `disclaimer_agreed`, clears `needsDisclaimer`

**Distance unit:** All internal calculations are km. `setDistanceUnit()` snaps `nearbyRadius` to nearest value in the appropriate radius array (`kRadiiKm` or `kRadiiMiles`).

### ThemeProvider (`lib/providers/theme_provider.dart`)
Stores `ThemeMode` (system/light/dark) in SharedPreferences key `theme_mode`.

---

## Theme system

`AppColors` ThemeExtension defined in `lib/theme/app_colors.dart`. All widgets use `context.col.*` rather than hardcoded constants.

| Token | Dark | Light |
|-------|------|-------|
| background | #0B1120 | #F0F4F8 |
| surface | #131E30 | #FFFFFF |
| card | #1C2B40 | #FFFFFF |
| border | #2A3F5A | #D0DCE8 |
| accent | #FFB300 | #E6A000 |
| textPrimary | #E8EDF5 | #0B1120 |
| textSecondary | #8EA4C0 | #4A6280 |
| textMuted | #4A6280 | #8EA4C0 |

Theme selector in Settings → Appearance (System / Light / Dark).

**AppBar gotcha:** Must have `scrolledUnderElevation: 0` and `surfaceTintColor: Colors.transparent` in the AppBarTheme — otherwise Material 3 darkens the whole scaffold when content scrolls under the AppBar.

---

## SQLite schema (v2)

```sql
airports       (id, ident, type, name, latitude_deg, longitude_deg,
                elevation_ft, continent, iso_country, iso_region,
                municipality, gps_code, iata_code)

frequencies    (id, airport_ref, airport_ident, type, description, frequency_mhz)

runways        (id, airport_ref, airport_ident, length_ft, width_ft, surface,
                lighted, closed, le_ident, le_heading_degT,
                le_displaced_threshold_ft, he_ident, he_heading_degT,
                he_displaced_threshold_ft)

navaids        (id, ident, name, type, frequency_khz, dme_frequency_khz,
                dme_channel, associated_airport)

favourites     (ident TEXT PRIMARY KEY, added_at INTEGER)
```

Upgrade from v1→v2: creates runways + navaids tables, clears airports + frequencies so they are re-downloaded.

---

## VHF signal reception model (`lib/services/terrain_service.dart`)

Physics: 4/3 Earth radius refraction model, VHF line-of-sight (~120 MHz airband).

```
theoreticalRangeKm = 4.12 × (√h_tx_m + √h_rx_m)
practicalRangeKm   = theoreticalRangeKm × 0.50   // stock rubber-duck penalty
ratio              = distanceKm / practicalRangeKm
```

Constants: `_towerHeightM=15`, `_handsetHeightM=1.5`, `_realWorldFactor=0.50`.

| ratio | pct | label | quality |
|-------|-----|-------|---------|
| ≤0.25 | 72% | Good | good |
| ≤0.55 | 50% | Fair | fair |
| ≤0.85 | 28% | Marginal | marginal |
| ≤1.15 | 12% | Poor | poor |
| ≤4.0  | 4%  | Very Poor | poor |
| ≤physicalMax | 0% | Beyond Range | beyondRange |
| >physicalMax | 0% | Out of Range | outOfRange |

`physicalMax = max(theoreticalRangeKm × 8, 300 km)`

Height modifiers: +14% if >250m above airport; +7% if >80m; −12% if <−25m; additional −12% if <−100m.
Proximity floors: min 74% if <2km; min 58% if <5km.

For `beyondRange` and `outOfRange`: percentage and progress bar are hidden; LiveATC.net suggestion shown.

---

## Loading screen messages

Aviation-themed humorous messages during data download, format: `"phrase (what's downloading)"`:

- Airports: "Filing flight plan (airports)" → "Checking NOTAMs (airports)" → "Confirming route (airports)"
- Frequencies: "Requesting ATC clearance (frequencies)" → "Tuning radios (frequencies)" → "Setting squelch (frequencies)"
- Runways: "Getting ATIS (runways)" → "Checking runway conditions (runways)" → "Confirming departure runway (runways)"
- Nav aids: "Programming the FMS (nav aids)" → "Setting ILS frequency (nav aids)" → "Confirming nav aids (nav aids)"
- Complete: "Cleared for departure"

ETA shown once >5% complete and >3 seconds elapsed. First-launch hint: "First run downloads ~9 MB of worldwide data — usually 1 to 2 minutes."

---

## Distance units

`DistanceUnit` enum in `constants.dart` with `km` and `miles` values.

`formatDistance(double km, DistanceUnit unit) → String` — converts for display.
`formatRadius(double km, DistanceUnit unit) → String` — chip labels (rounds to whole miles).

Radius arrays:
- `kRadiiKm = [10, 25, 50, 100, 200]`
- `kRadiiMiles = [8.047, 16.093, 40.234, 80.467, 160.934]` (≈5, 10, 25, 50, 100 miles)

Switching unit snaps `nearbyRadius` to nearest value in new array.

---

## Metrics pipeline

**Architecture:** App → Cloudflare Worker → NeonDB → Grafana

**Worker URL:** `https://atc-freq-metrics.mark-78f.workers.dev`
**NeonDB:** `ep-sweet-band-abiz6722-pooler.eu-west-2.aws.neon.tech` / `neondb`

`MetricsService` (`lib/services/metrics_service.dart`):
- Only active when `_kRelayUrl` is non-empty and NOT in debug mode
- Buffers events in memory, flushes every 30 seconds or on app background
- Anonymous UUID install ID (stored in SharedPreferences key `metrics_install_id`)
- Sends JSON: `{ "events": [{ measurement, install_id, tags, fields, ts }] }`

**Privacy note (2026-06):** feature-level tracking (frequency copies, SDR
launches, LiveATC taps) was removed after beta tester feedback about
over-monitoring, then **reinstated** shortly after at the owner's request —
this kind of feature-interaction analytics is standard industry practice
(most apps track it), and the in-app/privacy-policy wording was rewritten to
describe it honestly using general categories ("app usage & interaction
data") rather than itemising every tracked button. The geo restriction
introduced during the removal was kept: geo (country/city/lat/lon from
Cloudflare IP lookup) is attached **only** to `app_open` (and `web_event`
`page_view`) events — `feature_use` and `airport_view` remain location-free.
`screen_view` stays removed (it was dead code, never wired to any screen).
See Settings → How We Use Your Data and `docs/privacy-policy.html` for the
user-facing explanation — keep both in sync if `feature_use` values change.

**IMPORTANT:** if you add new `feature_use` values or new measurements,
Play Console's **Data Safety** form (a separate questionnaire in the Play
Console web UI, not a file in this repo) must also be kept accurate — it
asks about data *categories* collected (e.g. "App interactions", "App info
and performance") and purposes. Selecting "no analytics collected" or
omitting a category that's actually collected is a Play policy violation
independent of what the in-app text says.

**Measurements tracked:**
| measurement | tags | fields | geo attached? |
|-------------|------|--------|----------------|
| app_event | event (app_open/session_end) | version, locale / duration_ms | yes, app_open only |
| airport_view | icao, type | — | no |
| feature_use | feature (freq_copy, sdr_launch, liveatc_suggested, liveatc_tapped_signal), freq_type, driver_installed | freq_mhz | no |
| download_stage | stage | duration_ms, success, bytes | no |
| download_complete | — | total_ms | no |
| bug_report | — | description, context, app_version | no |
| web_event | event (page_view/cta_click/scroll_depth), target, depth, path, referrer_source, referrer_medium, referrer_campaign | — | yes, page_view only |

`web_event` is sent by `docs/index.html` (the marketing site, not the app) — same Worker, same `atc_metrics` table, distinguished by measurement name. install_id there is a per-browser UUID stored in `localStorage`, not the app's install ID.

**Traffic source attribution (2026-06):** `page_view` tags `referrer_source` (e.g. `google.com`, `reddit.com`, `direct`) and optionally `referrer_medium`/`referrer_campaign` if the URL has `?utm_source=...`. UTM params take priority over `document.referrer` when both are present. Same-origin referrers (e.g. internal navigation) are normalised to `direct`. No backend change was needed — the Worker passes through arbitrary tag keys already.

**Cloudflare Worker** (`metrics-relay/index.js`):
- Accepts POST with JSON payload
- Validates measurement names, UUID format, body size ≤64 KB
- Injects Cloudflare IP geolocation (`geo_country`, `geo_city`, `geo_lat`, `geo_lon`, `geo_region`) only into `app_event`/`app_open` and `web_event`/`page_view` events — `feature_use` (and everything else) stays location-free
- Bulk-inserts via `UNNEST` into `atc_metrics` table
- Returns HTTP 204 always (never blocks the app)
- Secret `NEON_DATABASE_URL` set via `npx wrangler secret put`

**Grafana dashboards** (import JSON from `grafana/`):
- `overview.json` — daily actives, installs, feature usage over time, locale/version split
- `content.json` — top airports, airport type breakdown, frequency types copied, SDR/LiveATC engagement, tap-through rates
- `performance.json` — download stage p50/p95/p99, total time distribution
- `bugs.json` — bug report table, version split, repeat reporters
- `website.json` — marketing site page views, unique visitors, CTA clicks by button, scroll depth funnel, visitors by country
- `map.json` — world map of app launches (24h), country/city tables — draws only from app_open geo

All dashboards use data source UID `cfofy105jfxtsf` (NeonDB PostgreSQL).

---

## SDR integration (`lib/services/sdr_service.dart`)

Launches RTL-SDR driver via `iqsrc://` intent:
```
iqsrc://-a 127.0.0.1 -p 1234 -s 1024000 -f {freqHz}
```

Compatible with SDR Touch (`marto.androsdr2`) and RF Analyzer. Driver package: `marto.rtl_tcp_andro`.

`AndroidManifest.xml` queries block declares `iqsrc` scheme and both packages.

If driver not installed: dialog with Play Store deep-link.

---

## LiveATC.net integration

URL format: `https://www.liveatc.net/search/?icao={ICAO}`

Opened via `url_launcher` in `LaunchMode.externalApplication`.

**Restricted countries** (`kRestrictedCountries` in `airport_detail_screen.dart`):
`GB, DE, BE, FR, IS, IN, IT, NZ, ES` — LiveATC has no feeds for these due to local communications law.

Two entry points:
1. **Signal reception card** — tappable link at bottom for all airports; humorous amber banner for `beyondRange`/`outOfRange` (5 rotating messages based on ICAO hash)
2. ~~Frequencies header~~ — removed

---

## Bug reporting

Triggered by:
1. Shaking the phone (`ShakeService` — threshold 28 m/s², 2.5s cooldown)
2. Settings → Feedback → "Found a problem?" button

Shows `BugReportSheet` bottom sheet. Fields: description (required), context (optional). Sends via `MetricsService.trackBugReport()` → NeonDB measurement `bug_report`.

Query in NeonDB:
```sql
SELECT ts, fields->>'description', fields->>'context', fields->>'app_version'
FROM atc_metrics WHERE measurement = 'bug_report' ORDER BY ts DESC;
```

---

## Background monitoring

Android-only. `flutter_foreground_task` runs `NearbyAirportsTaskHandler` in a Dart isolate.
- Repeats every 5 minutes
- Queries nearest 3 airports, updates notification text
- Notification channel: `atc_nearby_airports`, LOW importance
- Tap deep-links to Nearby tab via `/nearby` route
- Requires POST_NOTIFICATIONS runtime permission (Android 13+)

Frequency display notification: pins full frequency list for a selected airport in notification shade. Restored on app restart.

---

## Splash / loading screens

**Splash** (`SplashScreen`): 3 AnimationControllers. Sequence: fade in (500ms) → hold (900ms) → plane flies up + scales down (600ms) → outro fade (300ms). Calls `onDone()` callback; `_Root` removes it from the Stack overlay.

Tagline "Worldwide ATC frequencies, updated weekly" displayed below "FREQUENCIES" in muted text, fades in with the rest of the content.

**Loading** (`LoadingScreen`): Plane landing on runway. Progress bar is one-directional (`max(_displayProgress, target)`). `_ArcsPainter`, `_RunwayPainter`, `_GlideSlopePainter` all accept accent colour as constructor parameter (not from context — they're CustomPainters).

---

## Disclaimer system

First-launch modal dialog (`widgets/disclaimer_dialog.dart`):
- Shown once after splash clears and app is ready, triggered via `WidgetsBinding.addPostFrameCallback` in `_Root`
- `PopScope(canPop: false)` — cannot be dismissed with back button
- Requires checkbox tick before "I Agree" button is enabled
- Acceptance stored in SharedPreferences key `disclaimer_agreed`
- `_disclaimerTriggered` flag in `_RootState` prevents re-triggering within a session

Persistent banner (`widgets/disclaimer_banner.dart`):
- Amber-tinted strip shown above the frequency list on every airport detail screen
- Text: "For recreational use only — always verify frequencies with official sources before flight."
- `kDisclaimerText` constant in `disclaimer_dialog.dart` is the full legal text, imported by settings_screen.dart via `show kDisclaimerText`

Settings → Disclaimer section shows the full `kDisclaimerText` permanently.

---

## Frequency filter ("With frequencies only")

Filter chip on both Search and Nearby screens. When active:
- `AppProvider.hideNoFreq = true`
- `DatabaseService.searchAirports()` and `getNearbyAirports()` add:
  `AND EXISTS (SELECT 1 FROM frequencies WHERE airport_ref = airports.id)`
- Re-queries immediately on toggle; re-queries when returning to a screen with an active search/nearby result
- Persisted in SharedPreferences key `hide_no_freq`

Contribute link below every frequency list:
- "Missing a frequency? Add it at ourairports.com"
- Links to `https://ourairports.com/airports/{ICAO}/` in external browser
- Shown both when frequencies exist (subtle, below list) and when empty (below empty state card)

---

## Known gotchas

- `sqflite` **must** stay at `^2.2.8+4` — 2.3.x introduces jni requiring Android NDK (1.5 GB download)
- `scrolledUnderElevation: 0` + `surfaceTintColor: Colors.transparent` **required** in AppBarTheme — Material 3 darkens the scaffold on scroll otherwise
- `ThemeData.colorScheme.surface` must be `kBackground` — if set to `kSurface`, ListView body renders a different colour than the scaffold
- `_Root` uses `ColoredBox` not `Scaffold` — avoids nested Scaffold background conflicts
- `CustomPainter` subclasses cannot use `context.col.*` — pass colour as constructor parameter from the parent `build()` method
- No `const` on widgets that use `context.col.*` — context is runtime, not compile-time
- `Navigator.pop()` from Settings was left over from when Settings was a pushed route — removed (Settings is now an IndexedStack tab)
- `SplashScreen` must call `widget.onDone()` not `Navigator.pushReplacementNamed()` — navigator history is empty at splash time

---

## Android signing

Keystore: `android/key.properties` (gitignored).
- Alias: `atc_frequencies`
- CN: Mark Owen / 4T Technologies / Ellesmere Port, Cheshire, GB

`build.gradle.kts` reads `key.properties` for `signingConfigs.release`.
R8 minification enabled. Proguard rules in `android/app/proguard-rules.pro`.

## Package name
`com.atcfreq.atc_freq`

## Privacy policy
`https://mowen7711.github.io/ATC-Frequencies/privacy-policy.html`
