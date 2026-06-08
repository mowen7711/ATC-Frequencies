# ATC Frequencies — Full Technical Documentation

**Version:** 1.0.0  
**Platform:** Android (Flutter)  
**Package:** `com.atcfreq.atc_freq`  
**Developer:** Mark Owen / 4T Technologies  
**Privacy Policy:** https://mowen7711.github.io/ATC-Frequencies/privacy-policy.html

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [Data Pipeline](#3-data-pipeline)
4. [Database Schema](#4-database-schema)
5. [Screen Reference](#5-screen-reference)
6. [Services Reference](#6-services-reference)
7. [Widgets Reference](#7-widgets-reference)
8. [Theme System](#8-theme-system)
9. [VHF Signal Reception Model](#9-vhf-signal-reception-model)
10. [Metrics & Analytics](#10-metrics--analytics)
11. [Grafana Dashboards](#11-grafana-dashboards)
12. [SDR Integration](#12-sdr-integration)
13. [LiveATC.net Integration](#13-liveatcnet-integration)
14. [Bug Reporting](#14-bug-reporting)
15. [Background Services](#15-background-services)
16. [Distance Units](#17-distance-units)
17. [Animations](#18-animations)
18. [Android Configuration](#19-android-configuration)
19. [Build & Deployment](#20-build--deployment)
20. [Known Issues & Gotchas](#20-known-issues--gotchas)
21. [Disclaimer & Frequency Filter](#21-disclaimer--frequency-filter)
22. [Future Considerations](#22-future-considerations)

---

## 1. Product Overview

ATC Frequencies is an Android application that provides pilots, aviation enthusiasts, and scanner hobbyists with quick access to Air Traffic Control radio frequencies for airports worldwide.

### Core Features

| Feature | Description |
|---------|-------------|
| Airport search | Search ~70,000 airports by name, ICAO code, IATA code, or city |
| Frequency filter | "With frequencies only" chip on Search and Nearby — hides airports with no data |
| Favourites | Star airports for quick access |
| Home airport | Pin one airport as home — shown prominently on the Favourites tab |
| Nearby airports | GPS-based discovery with adjustable radius (km or miles) |
| Frequency list | ATC frequencies grouped by type (ATIS, TWR, GND, APP, DEP, CTR, UNICOM) |
| Tap to copy | Tap any frequency to copy it to clipboard |
| Signal reception | VHF line-of-sight model estimating whether you can hear the airport |
| Map | OpenStreetMap showing airport location |
| Runway info | All open runways with designators, surface, length, lighting |
| Navigation aids | VORs, NDBs, ILS localisers linked to each airport |
| LiveATC.net | Link-out to live audio streams (where legally permitted) |
| SDR integration | Launch RTL-SDR driver app tuned to a specific frequency |
| Dark / light / system theme | Full theme support with colour-accurate light mode |
| Background monitor | Persistent notification showing nearest 3 airports, updates every 5 minutes |
| Frequency notification | Pin all frequencies for a chosen airport in the notification shade |
| Disclaimer | First-launch agreement dialog + persistent banner on all frequency pages |
| Contribute link | "Missing a frequency?" link to OurAirports below every frequency list |
| Bug reporting | Shake phone or use button in Settings to submit anonymous report |
| Analytics | Anonymous usage metrics → Cloudflare Worker → NeonDB → Grafana |

### What It Is Not

- Not a live ATC audio player (audio comes via LiveATC.net in-browser)
- Not a flight tracker
- Not a weather source
- Not a navigation tool

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter App                                                     │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ Splash   │  │ Loading  │  │   Home   │  │    Detail    │   │
│  │ Screen   │  │ Screen   │  │  Screen  │  │    Screen    │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  AppProvider (ChangeNotifier)                           │   │
│  │  ThemeProvider (ChangeNotifier)                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ DataService  │  │ DatabaseSvc  │  │  BackgroundService   │ │
│  │ (CSV fetch)  │  │  (SQLite)    │  │  (foreground task)   │ │
│  └──────────────┘  └──────────────┘  └──────────────────────┘ │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │MetricsService│  │TerrainService│  │    SdrService        │ │
│  │  (analytics) │  │ (VHF model)  │  │  (iqsrc:// intent)   │ │
│  └──────────────┘  └──────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
         │ HTTP POST                           │ iqsrc://
         ▼                                     ▼
┌─────────────────┐                  ┌─────────────────────┐
│ Cloudflare      │                  │  RTL-SDR Driver App │
│ Worker          │                  │  (marto.rtl_tcp_    │
│ (metrics relay) │                  │   andro)            │
└────────┬────────┘                  └─────────────────────┘
         │ UNNEST INSERT
         ▼
┌─────────────────┐
│    NeonDB       │◄──── Grafana Dashboards
│  (PostgreSQL)   │
└─────────────────┘
```

### State Management

The app uses the `provider` package with two ChangeNotifiers:

**AppProvider** — Single source of truth for:
- App initialisation state (loading / ready / error)
- Favourites list
- Search results
- Nearby airports list + filter state
- Home airport
- Distance unit preference (km / miles)
- Frequency filter (`hideNoFreq`) — hides airports with no frequency data
- Disclaimer state (`needsDisclaimer`) — whether first-launch dialog needs showing
- Loading progress, status messages, ETA, runway labels

**ThemeProvider** — Stores `ThemeMode` (system / light / dark) only.

Both are provided at the root via `MultiProvider` in `main.dart`.

---

## 3. Data Pipeline

### First Launch

```
App start
  → AppProvider.init()
  → DataService.ensureData()
  → DatabaseService.hasData() → false
  → _downloadAll()
      → Download airports.csv   (0–20%)
      → Parse airports in isolate
      → Batch insert to SQLite (500 rows/batch)
      → Download frequencies.csv (20–40%)
      → Parse + insert
      → Download runways.csv    (40–65%)
      → Parse + insert
      → Download navaids.csv    (65–95%)
      → Parse + insert
      → Save timestamp to SharedPreferences
  → AppProvider state = ready
```

### Subsequent Launches

```
App start
  → AppProvider.init()
  → DataService.ensureData()
  → DatabaseService.hasData() → true
  → onProgress('Ready', 1.0)
  → _maybeRefreshInBackground()
      → If lastUpdate > 7 days ago:
          → _downloadAll() silently in background
```

### Manual Refresh (Settings)

```
User taps "Refresh data now"
  → AppProvider.forceRefresh()
  → Fetch home airport runway labels BEFORE clearing DB
  → AppState = loading
  → DatabaseService.clearAll()
  → DataService.forceRefresh()
  → Same pipeline as first launch
  → AppState = ready
```

### Data Sources

| File | URL | Size | Records |
|------|-----|------|---------|
| airports.csv | davidmegginson.github.io/ourairports-data/airports.csv | ~6 MB | ~70,000 |
| airport-frequencies.csv | .../airport-frequencies.csv | ~3 MB | ~90,000 |
| runways.csv | .../runways.csv | ~2 MB | ~40,000 |
| navaids.csv | .../navaids.csv | ~2 MB | ~30,000 |

Source: OurAirports.com (CC0 public domain). Updated daily by maintainer. No API key, no rate limiting.

### Progress Messages (during download)

The loading screen shows aviation-humour messages during each stage:

| Stage | Messages |
|-------|---------|
| Airports DL | "Filing flight plan (airports)" |
| Airports parse | "Checking NOTAMs (airports)" |
| Airports insert | "Confirming route (airports)" |
| Frequencies DL | "Requesting ATC clearance (frequencies)" |
| Frequencies parse | "Tuning radios (frequencies)" |
| Frequencies insert | "Setting squelch (frequencies)" |
| Runways DL | "Getting ATIS (runways)" |
| Runways parse | "Checking runway conditions (runways)" |
| Runways insert | "Confirming departure runway (runways)" |
| Navaids DL | "Programming the FMS (nav aids)" |
| Navaids parse | "Setting ILS frequency (nav aids)" |
| Navaids insert | "Confirming nav aids (nav aids)" |
| Complete | "Cleared for departure" |

---

## 4. Database Schema

**Engine:** SQLite via sqflite ^2.2.8+4 (pinned — do not upgrade to 2.3.x)  
**Database file:** `{getDatabasesPath()}/atc_freq.db`  
**Schema version:** 2

### Tables

#### airports
```sql
CREATE TABLE airports (
  id INTEGER PRIMARY KEY,
  ident TEXT NOT NULL,          -- ICAO code e.g. EGLL
  type TEXT NOT NULL DEFAULT '',-- large_airport, medium_airport, small_airport, heliport, etc.
  name TEXT NOT NULL,
  latitude_deg REAL,
  longitude_deg REAL,
  elevation_ft INTEGER,
  continent TEXT DEFAULT '',
  iso_country TEXT DEFAULT '',  -- ISO 3166-1 alpha-2 e.g. GB, US
  iso_region TEXT DEFAULT '',
  municipality TEXT DEFAULT '',
  gps_code TEXT DEFAULT '',
  iata_code TEXT DEFAULT ''     -- e.g. LHR
);
-- Indexes: ident, name, iata_code, (latitude_deg, longitude_deg)
```

#### frequencies
```sql
CREATE TABLE frequencies (
  id INTEGER PRIMARY KEY,
  airport_ref INTEGER NOT NULL, -- FK to airports.id
  airport_ident TEXT NOT NULL,
  type TEXT NOT NULL,           -- ATIS, TWR, GND, APP, DEP, CTR, UNIC, etc.
  description TEXT DEFAULT '',
  frequency_mhz REAL NOT NULL
);
-- Index: airport_ref
```

#### runways
```sql
CREATE TABLE runways (
  id INTEGER PRIMARY KEY,
  airport_ref INTEGER NOT NULL,
  airport_ident TEXT NOT NULL,
  length_ft INTEGER,
  width_ft INTEGER,
  surface TEXT DEFAULT '',
  lighted INTEGER NOT NULL DEFAULT 0,   -- 0/1
  closed INTEGER NOT NULL DEFAULT 0,    -- 0/1
  le_ident TEXT DEFAULT '',             -- Low-end designator e.g. "09"
  le_heading_degT REAL,
  le_displaced_threshold_ft INTEGER,
  he_ident TEXT DEFAULT '',             -- High-end designator e.g. "27"
  he_heading_degT REAL,
  he_displaced_threshold_ft INTEGER
);
-- Indexes: airport_ref, airport_ident
```

#### navaids
```sql
CREATE TABLE navaids (
  id INTEGER PRIMARY KEY,
  ident TEXT NOT NULL,
  name TEXT DEFAULT '',
  type TEXT NOT NULL,                   -- VOR, NDB, ILS, LOC, DME, etc.
  frequency_khz REAL,
  dme_frequency_khz REAL,
  dme_channel TEXT DEFAULT '',
  associated_airport TEXT NOT NULL      -- ICAO code
);
-- Index: associated_airport
```

#### favourites
```sql
CREATE TABLE favourites (
  ident TEXT PRIMARY KEY,       -- ICAO code
  added_at INTEGER NOT NULL     -- Unix timestamp ms
);
```

### Key Queries

**Nearby airports (bounding box + Haversine):**
```dart
// Pre-filter with bounding box in SQL (SQLite has no trig)
// Then apply Haversine in Dart to get exact distances
final latDelta = radiusKm / 111.0;
final lonDelta = radiusKm / (111.0 * cos(lat * pi / 180));
// SELECT * WHERE lat BETWEEN and lon BETWEEN
// Then: airport.distanceTo(lat, lon) <= radiusKm
```

**Search (ICAO, IATA, name, city):**
```sql
SELECT * FROM airports
WHERE (name LIKE ? OR ident LIKE ? OR iata_code LIKE ? OR municipality LIKE ?)
AND type IN (...)
ORDER BY
  CASE WHEN iata_code LIKE ? THEN 0
       WHEN ident LIKE ? THEN 1
       ELSE 2 END, name ASC
LIMIT 60
```

---

## 5. Screen Reference

### Splash Screen (`screens/splash_screen.dart`)

Shown on every app launch while the main content loads. Three animation controllers run in sequence:

| Controller | Duration | What it does |
|------------|----------|-------------|
| `_introCtrl` | 500ms | Fades in the plane image, "ATC FREQUENCIES" text, and tagline |
| `_flyCtrl` | 600ms | Translates plane upward (0 → −1.6× screen height), scales down (1.0 → 0.7) |
| `_outroCtrl` | 300ms | Fades out everything |

Sequence timing: intro (500ms) → hold (900ms) → fly starts → 200ms into fly, outro begins.

Tagline "Worldwide ATC frequencies, updated weekly" is shown below "FREQUENCIES" in muted text (same fade-in as the rest of the content, flies up with the plane).

When complete, calls `widget.onDone()` — the `_Root` StatefulWidget removes the splash overlay from its Stack.

Three concentric semicircular radio arcs are drawn by `_ArcsPainter` at radii 90, 140, 195 px with opacity 10%, 16%, 22%.

### Loading Screen (`screens/loading_screen.dart`)

Shown during first launch or manual data refresh. Features a plane landing on a runway that fills as a progress bar.

**`_LandingWidget`**: Plane (`plane_side.png`, amber tint) follows a glide slope from top-left to bottom-right as progress goes 0→1. Pitch angle lerps from −7° to 0° via `Curves.easeIn`.

**Progress bar**: One-directional only — `_animateTo()` uses `max(_displayProgress, target)` to prevent backward movement.

**`_RunwayPainter`**: Draws a realistic runway with threshold markings, TDZ pairs at 15%, aiming point pairs at 30%, centreline dashes, amber leading-edge glow. Runway designators from home airport displayed as rotated text.

**ETA**: Shown once progress >5% and elapsed time >3 seconds. Formula: `(elapsed / progress) - elapsed`.

### Home Screen (`screens/home_screen.dart`)

Bottom navigation with `IndexedStack` preserving scroll state across tabs:

| Index | Tab | Screen |
|-------|-----|--------|
| 0 | Favourites ★ | `_FavouritesTab` |
| 1 | Nearby ▲ | `NearbyScreen` |
| 2 | Search 🔍 | `SearchScreen` |
| 3 | Settings ⚙ | `SettingsScreen` |

The `HomeScreen` accepts `initialTab` parameter for deep-linking from notification taps.

### Airport Detail Screen (`screens/airport_detail_screen.dart`)

`CustomScrollView` with a pinned `SliverAppBar` showing airport name + ICAO/IATA codes.

**AppBar actions:** Pin frequencies to notification shade | Set as home airport | Add to favourites

**Content sections (in order):**
1. Map (OpenStreetMap, 200px height, zoom 12)
2. ATC Frequencies heading + `DisclaimerBanner` + frequency cards + contribute link
3. Signal Reception Card
4. Airport Information (type, location, elevation, coordinates, runways, navaids)

**LiveATC restricted countries:** `kRestrictedCountries = {GB, DE, BE, FR, IS, IN, IT, NZ, ES}` — defined at top of file and exported for use by signal reception card.

### Nearby Screen (`screens/nearby_screen.dart`)

Shows GPS-located airports within a configurable radius. The filter bar has two rows:
1. Radius chips — `kRadiiKm` or `kRadiiMiles` based on distance unit preference
2. "With frequencies only" chip — filters out airports with no frequency data (`AppProvider.hideNoFreq`)

Filter bar `preferredSize` height is 108px to accommodate both rows.

Map view toggles a full `FlutterMap` with markers for each nearby airport, zoom level calculated from radius.

Empty states: "Location not available", "No airports found", "GPS permission denied" each have distinct UI.

### Settings Screen (`screens/settings_screen.dart`)

Sections:
1. **Appearance** — System / Light / Dark theme selector
2. **Background Monitoring** — Toggle foreground service, shows active badge
3. **Airport Frequency Display** — Toggle pinned notification, airport picker
4. **Location** — km/miles selector, default radius display
5. **Airport Data** — Data source info, "Refresh data now" button
6. **About** — Version (read from PackageInfo), coverage stats
7. **How We Use Your Data** — Full data transparency breakdown with 6 rows
8. **Feedback** — "Found a problem?" button, shake gesture tip
9. **Disclaimer** — Full `kDisclaimerText` always visible; imported from `disclaimer_dialog.dart`

---

## 6. Services Reference

### DataService (`services/data_service.dart`)

Singleton. Manages CSV download and parsing.

**Key methods:**
- `ensureData({onProgress})` — downloads if no data, otherwise checks for weekly refresh
- `forceRefresh({onProgress})` — clears DB then re-downloads everything

CSV parsing runs in a `compute()` isolate to keep the UI thread free. Each CSV is streamed (not buffered fully) during download for accurate progress reporting.

**Update interval:** 7 days (`kUpdateIntervalDays` in constants.dart). Timestamp stored in SharedPreferences key `last_update`.

### DatabaseService (`services/database_service.dart`)

Singleton wrapping sqflite. All operations are async.

**Batch insert strategy:** Chunks of 500 rows, each chunk in a single batch transaction. Progress callback fires after each chunk.

**`getRunwayDesignatorsForAirport(String ident)`** — Returns `[leIdent, heIdent]` from a randomly selected runway. Used by `AppProvider.forceRefresh()` to show home airport runway numbers on the loading screen during updates.

**`getNearbyAirports(lat, lon, radiusKm, types, limit, requireFrequencies)`** — SQL bounding box pre-filter, then Haversine in Dart. Returns `List<(Airport, double)>` sorted by distance. When `requireFrequencies: true`, adds `AND EXISTS (SELECT 1 FROM frequencies WHERE airport_ref = airports.id)`.

**`searchAirports(query, limit, types, requireFrequencies)`** — Same `EXISTS` subquery applied when `requireFrequencies: true`.

### TerrainService (`services/terrain_service.dart`)

VHF line-of-sight signal reception calculator. See [Section 9](#9-vhf-signal-reception-model) for full model documentation.

**`getAltitude()`** — Requests GPS position with `LocationAccuracy.best` (needs altitude). 20-second timeout.

**`calculate({airportElevationFt, userAltitudeM, distanceKm})`** — Returns `SignalResult` with percent, label, detail, quality.

### MetricsService (`services/metrics_service.dart`)

Anonymous analytics. Inactive in debug mode or if `_kRelayUrl` is empty.

**Install ID:** Random UUID v4 generated once on first launch, stored in SharedPreferences key `metrics_install_id`. Cannot identify a real person.

**Flush strategy:** Timer every 30 seconds + immediate flush on `trackAppClose()`.

**Payload format:**
```json
{
  "events": [
    {
      "measurement": "airport_view",
      "install_id": "uuid-v4",
      "tags": { "icao": "EGCC", "type": "large_airport" },
      "fields": {},
      "ts": 1718000000000
    }
  ]
}
```

HTTP POST to Cloudflare Worker with `Content-Type: application/json`. Worker returns 204. Any network error is silently swallowed — never impacts the user.

### SdrService (`services/sdr_service.dart`)

Launches RTL-SDR compatible driver app via Android Intent.

```
iqsrc://-a 127.0.0.1 -p 1234 -s 1024000 -f {frequencyHz}
```

The driver (marto.rtl_tcp_andro) starts a TCP server on localhost:1234. SDR Touch or RF Analyzer connect to it as clients.

`openPlayStore()` — opens the driver on Play Store if not installed.

### ShakeService (`services/shake_service.dart`)

Listens to `accelerometerEventStream()` from `sensors_plus`. Fires `onShake` callback when:
- Magnitude `√(x²+y²+z²) > 18.0 m/s²`
- At least 1500ms since last shake

Gravity ≈ 9.8 m/s², so threshold is roughly 1.8× gravitational acceleration.

Disposed when `_Root` disposes (app termination). Not running during splash.

### LocationService (`services/location_service.dart`)

Thin wrapper around Geolocator returning a `LocationResult` (success/error + lat/lon).

### BackgroundService (`services/background_service.dart`)

Configures `flutter_foreground_task`. `init()` called from `main()`. `start()` requests both POST_NOTIFICATIONS and location permissions before starting the service.

`NearbyAirportsTaskHandler` runs in a separate Dart isolate:
- Calls `DatabaseService.getNearbyAirports()` for 3 airports within 50 km
- Updates notification text every 5 minutes
- Notification tap sends `/nearby` intent to app

### FrequencyNotificationService (`services/frequency_notification_service.dart`)

Manages a persistent notification showing all ATC frequencies for a chosen airport. Uses `flutter_local_notifications`. Notification is expanded to show the full list (BigTextStyle). Restored on app restart via `init()`.

---

## 7. Widgets Reference

### AirportTile (`widgets/airport_tile.dart`)

Used in Favourites, Nearby, and Search lists.

- Left strip: colour-coded by airport type (amber=large, blue=medium, green=small, purple=heliport)
- ICAO/IATA badge
- Airport name + location string
- Distance (formatted per user's unit preference via `formatDistance()`)
- Favourite star button (animated icon swap)

### FrequencyCard (`widgets/frequency_card.dart`)

Tap or long-press to copy frequency to clipboard. Contains:
- Type badge (coloured by frequency type — ATIS=blue, TWR=red, GND=yellow, APP=green, DEP=orange, CTR=purple)
- Description text
- Frequency value in MHz
- Copy icon indicator
- SDR listen button (`Icons.sensors_rounded`) — fires `iqsrc://` intent; shows Play Store dialog if driver missing

### SignalReceptionCard (`widgets/signal_reception_card.dart`)

Calculates and displays VHF signal reception estimate.

States: loading (spinner) → error (GPS unavailable) → result.

For **Good/Fair/Marginal/Poor/Very Poor:**
- Percentage + colour-coded label
- Linear progress bar
- Detail text
- Stats grid (distance, range, altitude, elevation, height diff)
- Subtle "Listen live on LiveATC.net →" footer link (hidden for restricted countries)

For **Beyond Range / Out of Range:**
- Grey label only (no percentage or progress bar)
- Explanatory text
- Humorous amber LiveATC suggestion banner (tappable, 5 rotating messages)

### DisclaimerBanner (`widgets/disclaimer_banner.dart`)

Persistent amber-tinted strip shown above every airport's ATC frequency list. Always visible — not dismissable. Contains a warning icon and the text "For recreational use only — always verify frequencies with official sources before flight."

Styling: `context.col.accent.withAlpha(15)` background, `context.col.accent.withAlpha(60)` border, 8px border radius.

### DisclaimerDialog (`widgets/disclaimer_dialog.dart`)

First-launch modal dialog. Key behaviours:
- `PopScope(canPop: false)` — back button disabled until agreed
- `barrierDismissible: false` — cannot be tapped away
- Checkbox must be ticked before "I Agree" `FilledButton` is enabled
- On agree: calls `provider.acceptDisclaimer()` then `Navigator.pop()`
- Triggered from `_RootState` via `addPostFrameCallback` once `provider.state == ready`, `!_splashVisible`, `provider.needsDisclaimer`, and `!_disclaimerTriggered`

Exports `kDisclaimerText` — a `const String` with the full legal disclaimer used by both the dialog and Settings → Disclaimer section.

### BugReportSheet (`widgets/bug_report_sheet.dart`)

Modal bottom sheet with:
- Description field (required, 4 lines)
- Context field (optional, 2 lines)
- Privacy note
- Cancel / Send Report buttons
- Success confirmation state (auto-dismisses after 1.2s)

Report sent via `MetricsService.trackBugReport()` with immediate flush.

### HomeAirportCard (`widgets/home_airport_card.dart`)

Banner at the top of the Favourites tab. Shows home airport name, ICAO, and a change button. Opens `_HomeAirportPicker` bottom sheet which reuses the search functionality.

### RunwayCard (`widgets/runway_card.dart`)

Shows runway designators, heading, length/width, surface type. ILS navaids shown as chips if available.

---

## 8. Theme System

### AppColors (`theme/app_colors.dart`)

`ThemeExtension<AppColors>` with 9 semantic colour tokens.

Accessed in widgets via `context.col.*` (BuildContext extension `AppColorsX`):

```dart
// Instead of:
color: kBackground
// Use:
color: context.col.background
```

### Colour Values

| Token | Dark (#) | Light (#) | Usage |
|-------|----------|-----------|-------|
| background | 0B1120 | F0F4F8 | Scaffold, app bar, screen backgrounds |
| surface | 131E30 | FFFFFF | Bottom sheets, dialogs |
| card | 1C2B40 | FFFFFF | Airport tiles, frequency cards |
| border | 2A3F5A | D0DCE8 | Card borders, dividers |
| accent | FFB300 | E6A000 | Interactive elements, highlights |
| accentDim | CC8E00 | B87D00 | Secondary accent |
| textPrimary | E8EDF5 | 0B1120 | Primary text |
| textSecondary | 8EA4C0 | 4A6280 | Secondary text, subtitles |
| textMuted | 4A6280 | 8EA4C0 | Hints, captions, disabled |

### ThemeData Configuration

Both themes include:
- `scrolledUnderElevation: 0` — prevents Material 3 tinting scaffold on scroll
- `surfaceTintColor: Colors.transparent` — prevents primary colour tinting surfaces
- `AppColors` extension attached via `theme.copyWith(extensions: [AppColors.dark/light])`

### Theme Persistence

`ThemeProvider` stores selection in SharedPreferences key `theme_mode` as string (`"system"`, `"light"`, `"dark"`). Loaded before `runApp()` to prevent flash.

---

## 9. VHF Signal Reception Model

### Physics Background

VHF airband (118–137 MHz) propagates by line-of-sight only. The radio horizon formula uses a 4/3 Earth radius effective radius to account for atmospheric refraction:

```
d_km = 4.12 × (√h₁ + √h₂)
```

where h₁ and h₂ are antenna heights in metres above the local terrain.

### Model Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| ATC tower height | 15 m | Typical rooftop or mast installation |
| Handheld height | 1.5 m | Scanner held in hand |
| Real-world factor | 0.50 | Stock rubber-duck antenna, urban clutter, multipath |

The 50% practical factor is deliberately pessimistic. Experienced scanner operators report 10–20 km ground-level in practice vs the 20–30 km theoretical horizon. This prevents the app from giving falsely optimistic estimates.

### Scoring

```
effectiveRxH = max(userAltitudeM - airportElevationM + 1.5, 1.5)
theoreticalRangeKm = 4.12 × (√15 + √effectiveRxH)
practicalRangeKm = theoreticalRangeKm × 0.50
ratio = distanceKm / practicalRangeKm
physicalMaxKm = max(theoreticalRangeKm × 8, 300)
```

| ratio | Score | Label | Quality enum |
|-------|-------|-------|-------------|
| ≤ 0.25 | 72% | Good | good |
| ≤ 0.55 | 50% | Fair | fair |
| ≤ 0.85 | 28% | Marginal | marginal |
| ≤ 1.15 | 12% | Poor | poor |
| ≤ 4.0 | 4% | Very Poor | poor |
| > 4.0 (< physicalMax) | 0% | Beyond Range | beyondRange |
| > physicalMax | 0% | Out of Range | outOfRange |

### Height Modifiers

| Condition | Effect |
|-----------|--------|
| User ≥250 m above airport | +14%, capped at 88% |
| User ≥80 m above airport | +7%, capped at 80% |
| User <−25 m below airport | −12%, floored at 3% |
| User <−100 m below airport | Additional −12%, floored at 2% |

Height modifiers are not applied for `beyondRange` quality.

### Proximity Floors

| Distance | Minimum % |
|----------|-----------|
| < 2 km | 74% |
| < 5 km | 58% |

### Out-of-Range Handling

For `beyondRange` and `outOfRange`:
- The percentage value and progress bar are hidden
- A humorous amber LiveATC banner is shown instead
- A `liveatc_suggested` metric event is fired
- 5 rotating messages are used, stable per airport (based on ICAO hashCode)

---

## 10. Metrics & Analytics

### Design Principles

- **Anonymous** — random UUID install ID, never linked to a real person
- **No PII** — no name, email, phone, GPS coordinates, or device fingerprint
- **No IP storage** — Cloudflare Worker uses IP for geolocation only, discards the IP
- **Non-blocking** — any failure is silently swallowed; the app never errors due to metrics
- **Opt-out implicit** — metrics are disabled in debug mode; no explicit opt-out needed as nothing identifies the user

### Architecture

```
Flutter App
  └─ MetricsService
       └─ HTTP POST (JSON)
            └─ Cloudflare Worker (atc-freq-metrics.mark-78f.workers.dev)
                 ├─ Validates payload
                 ├─ Injects Cloudflare IP geolocation
                 └─ UNNEST INSERT → NeonDB atc_metrics table
```

### NeonDB Schema

```sql
CREATE TABLE atc_metrics (
  id          BIGSERIAL    PRIMARY KEY,
  ts          TIMESTAMPTZ  NOT NULL,
  measurement TEXT         NOT NULL,
  install_id  TEXT         NOT NULL,  -- anonymous UUID v4
  tags        JSONB        NOT NULL DEFAULT '{}',
  fields      JSONB        NOT NULL DEFAULT '{}'
);
-- Indexes: ts DESC, measurement+ts, install_id+ts, GIN(tags), GIN(fields)
```

**Connection:** `ep-sweet-band-abiz6722-pooler.eu-west-2.aws.neon.tech` / database `neondb`

### Events Catalogue

#### app_event
| tag | field | description |
|-----|-------|-------------|
| event="app_open" | version, locale | App launched or resumed |
| event="session_end" | duration_ms | App backgrounded |

#### airport_view
| tag | description |
|-----|-------------|
| icao | ICAO code of airport opened |
| type | large_airport / medium_airport / small_airport |

#### feature_use
| tag: feature | description |
|-------------|-------------|
| freq_copy | Frequency copied to clipboard |
| sdr_launch | SDR listen button tapped |
| add_favourite | Airport starred |
| set_home | Airport set as home |
| liveatc_suggested | Out-of-range LiveATC banner shown |
| liveatc_tapped_signal | LiveATC tapped from signal card |
| liveatc_launched | LiveATC tapped from frequencies header |

#### download_stage
| tag | field | description |
|-----|-------|-------------|
| stage (airports/frequencies/runways/navaids) | duration_ms, success, bytes | One stage of data download |

#### download_complete
| field | description |
|-------|-------------|
| total_ms | Total time for full download |

#### bug_report
| field | description |
|-------|-------------|
| description | User's description of the issue |
| context | What they were doing (optional) |
| app_version | Version string e.g. "1.0.0" |

### Cloudflare Worker

**File:** `metrics-relay/index.js`  
**URL:** `https://atc-freq-metrics.mark-78f.workers.dev`  
**Secret:** `NEON_DATABASE_URL` (set via `npx wrangler secret put NEON_DATABASE_URL`)

**Geolocation:** `request.cf.country`, `request.cf.city`, `request.cf.latitude`, `request.cf.longitude`, `request.cf.region` are injected as tags on every event. This is city-level from Cloudflare's IP database — not GPS, not precise.

**Validation:**
- POST only
- Content-Type: text/plain (line protocol) or application/json
- Body ≤ 64 KB
- 1–100 events per batch
- Measurement must be in `VALID_MEASUREMENTS` set
- install_id must match UUID v4 regex

**Deployment:**
```bash
cd metrics-relay
npm install
npx wrangler deploy
npx wrangler secret put NEON_DATABASE_URL
```

---

## 11. Grafana Dashboards

All dashboards use NeonDB PostgreSQL data source UID `cfofy105jfxtsf`. Import JSON files from `grafana/` directory via Dashboards → New → Import → Upload JSON.

### overview.json — App Overview
Panels: App Opens (stat), Unique Installs (stat), Airports Viewed (stat), Frequencies Copied (stat), SDR Launches (stat), Avg Session (stat), App Opens Over Time (timeseries), Daily Unique Installs (timeseries), Feature Usage Over Time (timeseries), App Version Split (piechart), Top Locales (barchart).

### content.json — Content & Features
Panels: Top 25 Airports Viewed (barchart), Top 50 Airports table, Airport Type Breakdown (donut), Frequency Types Copied (piechart), Feature Usage Totals (barchart), SDR Driver Installed % (gauge), Most Viewed Airport (stat), Most Copied Freq Type (stat), Airports Viewed Unique ICAOs (stat), LiveATC Suggestions Shown (stat), LiveATC Taps Signal Card (stat), LiveATC Taps Freq Header (stat), LiveATC Tap-Through Rate % (stat), LiveATC Engagement Over Time (timeseries).

### performance.json — Download Performance
Panels: Median Total Download (stat), p95 Total Download (stat), Downloads Completed (stat), Download Failures (stat), Slowest Stage (stat), Download Stage Duration Over Time (timeseries), Stage Statistics p50/p95/p99 (table), Total Download Time Distribution (barchart), Total Download Time Trend median+p95 (timeseries).

### bugs.json — Bug Reports
Panels: Total Reports (stat), Reports Today (stat, red if ≥3), Unique Reporters (stat), Most Affected Version (stat), Avg Reports/Day (stat), Bug Reports Over Time (bar chart), Reports by App Version (donut), All Bug Reports (table with full description, context, version, country, city), Repeat Reporters (table), Reports With App Opens Same Day (table).

### map.json — World Map
Panels: Launches 24h (stat), Countries 24h (stat), Unique Installs 24h (stat), Most Active Country (stat), World Geomap (dots sized by launch count), Launches by Country table, Launches by City table.

---

## 12. SDR Integration

### Overview

When a user taps the antenna icon (⊕) on any frequency card, the app fires an Android Intent that launches an RTL-SDR driver app, pre-tuned to that exact frequency.

### Intent Protocol

The RTL-SDR ecosystem uses the open-source `iqsrc://` URI scheme defined in `rtl_tcp_andro` (GPL-2):

```
iqsrc://-a 127.0.0.1 -p 1234 -s 1024000 -f {frequencyHz}
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| -a | 127.0.0.1 | TCP bind address |
| -p | 1234 | TCP port |
| -s | 1024000 | Sample rate Hz (1.024 MHz, sufficient for airband AM) |
| -f | frequency in Hz | Initial centre frequency |

### Compatible Apps

| App | Package | Notes |
|-----|---------|-------|
| RTL-SDR Driver | marto.rtl_tcp_andro | Free; the driver app itself |
| SDR Touch | marto.androsdr2 | Consumer app, uses the driver |
| RF Analyzer | com.mantz_it.rfanalyzer | Open-source alternative |

### Android Manifest

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="iqsrc" />
  </intent>
  <package android:name="marto.rtl_tcp_andro" />
  <package android:name="marto.androsdr2" />
</queries>
```

Required for Android 11+ (API 30+) to allow `canLaunchUrl()` to resolve `iqsrc://`.

### What the User Needs

1. An RTL-SDR USB dongle (RTL2832U chipset, VID 0x0BDA)
2. A USB OTG adapter (USB-A to their phone's connector)
3. RTL-SDR Driver app installed from Play Store
4. Optionally SDR Touch (or RF Analyzer) for the receiver UI

The frequency card shows a greyed-out version if no driver is installed and opens a dialog with Play Store link.

### Limitations

- Android only (iOS does not support USB Host mode)
- RTL-SDR receives but doesn't transmit
- AM demodulation is handled by SDR Touch / RF Analyzer, not this app
- The app does not process audio — it only launches the driver at the right frequency

---

## 13. LiveATC.net Integration

### Overview

LiveATC.net provides live ATC audio streams from airports worldwide. This app links out to their search page for a specific ICAO code.

**Important:** This app only links out (opens browser/app). It does **not** embed or proxy LiveATC audio streams — doing so would violate their Terms of Service.

### URL Format

```
https://www.liveatc.net/search/?icao={ICAO}
```

e.g. `https://www.liveatc.net/search/?icao=KJFK`

This is a publicly-indexed URL, stable, and consistent across all airports.

### Legal Restrictions

In the following countries, public reception of ATC communications is legally restricted. LiveATC has no feeds for these countries. The app shows a legal notice instead of a link:

| Country | Code | Relevant Law |
|---------|------|-------------|
| United Kingdom | GB | Wireless Telegraphy Act |
| Germany | DE | TKG communications law |
| Belgium | BE | Communications law |
| France | FR | ARCEP regulations |
| Iceland | IS | Communications law |
| India | IN | Indian Wireless Telegraphy Act |
| Italy | IT | Communications code |
| New Zealand | NZ | Radiocommunications Act |
| Spain | ES | Ley General de Telecomunicaciones |

The `kRestrictedCountries` constant in `airport_detail_screen.dart` defines this set. It is exported and used by `signal_reception_card.dart`.

### Entry Points

1. **Signal Reception Card** — Always shown at the bottom of the card. For in-range airports: subtle grey underlined link. For out-of-range/beyond-range: humorous amber banner. Both hidden for restricted countries.

2. **Frequencies Header** — Removed (was previously a button next to "ATC Frequencies" heading).

### Humorous Messages (out-of-range)

Five messages, stable per airport (selected by `airport.ident.hashCode.abs() % 5`):
1. "Bit of a stretch. But you might catch it on LiveATC.net →"
2. "Your antenna would need to be very, very tall. Try LiveATC.net →"
3. "Even a rooftop Yagi won't cut it here. LiveATC.net might though →"
4. "The Earth had other plans. Check for a live feed on LiveATC.net →"
5. "Physics says no. LiveATC.net might say yes →"

### Metrics

- `liveatc_suggested` — Fired when out-of-range banner is displayed
- `liveatc_tapped_signal` — Fired when tapped from signal card
- `liveatc_launched` — Fired when tapped from frequencies header

---

## 14. Bug Reporting

### Trigger Methods

1. **Shake gesture** — Anywhere in the app (not during splash). `ShakeService` detects acceleration >18 m/s², 1.5-second cooldown between triggers.

2. **Settings → Feedback → "Found a problem?"** — Button at bottom of settings.

### The Report Sheet

Bottom sheet (`BugReportSheet`):
- Description field (required, multiline)
- Context field (optional — "what were you doing?")
- Privacy note: reports are anonymous, no email/location collected
- Cancel / Send Report buttons
- Success state with auto-dismiss

### Data Sent

```json
{
  "measurement": "bug_report",
  "fields": {
    "description": "user text",
    "context": "optional text",
    "app_version": "1.0.0"
  },
  "tags": {
    "geo_country": "GB",
    "geo_city": "Ellesmere Port"
  }
}
```

Geo tags are added by the Cloudflare Worker from request IP — not from the user's GPS.

### Querying Reports

```sql
-- All recent reports
SELECT ts,
       fields->>'description' AS description,
       fields->>'context' AS context,
       fields->>'app_version' AS version,
       tags->>'geo_country' AS country,
       tags->>'geo_city' AS city
FROM atc_metrics
WHERE measurement = 'bug_report'
ORDER BY ts DESC
LIMIT 50;
```

---

## 15. Background Services

### Nearby Airport Monitor

**Technology:** `flutter_foreground_task` — runs a Dart isolate as an Android foreground service.

**Behaviour:**
- Updates every 5 minutes
- Queries nearest 3 airports within 50 km
- Updates notification text: "LPL (9.2km), CEG (10.8km), GB-1002 (19.6km)"
- Tapping notification launches app to Nearby tab

**Notification channel:** `atc_nearby_airports`, LOW importance/priority.

**Permissions required:**
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`
- `ACCESS_FINE_LOCATION` + `ACCESS_BACKGROUND_LOCATION`
- `POST_NOTIFICATIONS` (Android 13+ runtime request)
- `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`

**Important:** Do NOT manually declare `BootReceiver` in AndroidManifest — the plugin declares `RebootReceiver` internally. Adding your own causes a conflict.

### Frequency Display Notification

**Technology:** `flutter_local_notifications`.

Pins all ATC frequencies for a user-chosen airport in the notification shade. Expandable notification shows the full list. Restored automatically on app restart by `FrequencyNotificationService.instance.init()`.

---

## 16. Distance Units

### Overview

All internal calculations use kilometres. The display layer converts as needed.

### Preference Storage

`AppProvider._distanceUnit` — enum `DistanceUnit.km` or `DistanceUnit.miles`. Persisted in SharedPreferences key `distance_unit`.

### Radius Arrays

When the user switches units, `nearbyRadius` is snapped to the nearest value:

| km | miles equivalent | Display (km) | Display (miles) |
|----|-----------------|-------------|----------------|
| 10 | 8.047 | 10km | 5mi |
| 25 | 16.093 | 25km | 10mi |
| 50 | 40.234 | 50km | 25mi |
| 100 | 80.467 | 100km | 50mi |
| 200 | 160.934 | 200km | 100mi |

### Helper Functions

```dart
// In constants.dart:
String formatDistance(double km, DistanceUnit unit)
// km: "1.2 km" or "50 m" | miles: "0.8 mi" or "2640 ft"

String formatRadius(double km, DistanceUnit unit)
// km: "50km" | miles: "31mi" (rounds to whole number)
```

---

## 17. Animations

### Splash Screen

3 `AnimationController`s:

```
0ms    500ms    1400ms   1600ms   1900ms
├──────┤        │        │        │
│intro │        │        │        │
(fade in plane + text + tagline)  │
         900ms hold      │        │
                ├────────┤        │
                │  fly   │        │
                (plane moves up)  │
                         ├────────┤
                         │ outro  │
                         (fade out)
```

### Loading Screen

`AnimationController` (600ms, Curves.easeOut) animates `_displayProgress`. Progress is clamped to never go backward. The `_ctrl.stop()` call in `dispose()` prevents the "disposed mid-animation" crash.

---

## 18. Android Configuration

### Package Name
`com.atcfreq.atc_freq`

### Minimum SDK
API 21 (Android 5.0)

### Target SDK
API 34 (Android 14)

### Permissions
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### Signing

`android/key.properties` (gitignored):
```
storeFile=...
storePassword=...
keyAlias=atc_frequencies
keyPassword=...
```

`build.gradle.kts` reads this file for `signingConfigs.release`. R8 minification enabled. Proguard rules in `android/app/proguard-rules.pro` include Flutter plugin keep rules and Play Core dontwarn entries.

### App Icon

`assets/icon/icon.png` — 1024×1024 master. Adaptive icon: dark navy background (`#0B1120`), amber plane foreground. Generated via `flutter_launcher_icons` package.

---

## 19. Build & Deployment

### Prerequisites

- Flutter SDK at `/Users/mark/Documents/projects/flutter/bin/flutter`
- Android SDK at `~/Library/Android/sdk`
- Java: temurin@17 at `/opt/homebrew/opt/temurin@17`
- `android/key.properties` file present

### Build Commands

```bash
cd /Users/mark/Projects/atc_freq

# Debug (connected device)
/Users/mark/Documents/projects/flutter/bin/flutter run

# Release APK (sideload / testing)
/Users/mark/Documents/projects/flutter/bin/flutter build apk --release

# Play Store Bundle
/Users/mark/Documents/projects/flutter/bin/flutter build appbundle --release
```

### Deploy to Phone via USB

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am force-stop com.atcfreq.atc_freq
adb shell am start -n com.atcfreq.atc_freq/com.atcfreq.atc_freq.MainActivity
```

### Deploy Cloudflare Worker

```bash
cd metrics-relay
npm install
npx wrangler login
npx wrangler deploy
npx wrangler secret put NEON_DATABASE_URL
# Paste: postgres://neondb_owner:...@ep-sweet-band-abiz6722-pooler.eu-west-2.aws.neon.tech/neondb?sslmode=require
```

### NeonDB Schema Setup (one-time)

Run `metrics-relay/schema.sql` in the NeonDB SQL Editor at console.neon.tech.

### Play Store

- Privacy policy: https://mowen7711.github.io/ATC-Frequencies/privacy-policy.html
- Feature graphic: `docs/feature-graphic.svg` (1024×500px)
- App bundle: `build/app/outputs/bundle/release/app-release.aab`

---

## 20. Known Issues & Gotchas

### Critical

| Issue | Cause | Fix |
|-------|-------|-----|
| sqflite 2.3.x breaks build | 2.3.x pulls jni requiring NDK | Pin to `^2.2.8+4` |
| Scroll darkens background | Material 3 scaffold tinting | `scrolledUnderElevation: 0` + `surfaceTintColor: Colors.transparent` in AppBarTheme |
| Nested Scaffold backgrounds differ | `colorScheme.surface` ≠ `scaffoldBackgroundColor` | Set `colorScheme.surface = kBackground` in ThemeData |
| Navigator assertion on splash | SplashScreen calling `pushReplacementNamed` on empty stack | Use `onDone` callback with Stack overlay in `_Root` |

### Non-Critical

| Issue | Notes |
|-------|-------|
| `CardTheme` vs `CardThemeData` | Use `CardThemeData` in recent Flutter versions |
| `Switch.activeColor` deprecated | Use `activeThumbColor` |
| No `const` with `context.col.*` | Context is runtime; remove `const` from affected widgets |
| `CustomPainter` can't use context | Pass colours as constructor parameters |
| `BootReceiver` conflict | Don't declare it — plugin uses `RebootReceiver` |
| iOS USB | Apple doesn't support USB Host mode; SDR integration is Android-only |

---

## 21. Disclaimer & Frequency Filter

### Disclaimer System

The app includes a two-layer disclaimer covering recreational-use liability:

**Layer 1 — First-launch dialog** (`widgets/disclaimer_dialog.dart`):
- Shown once after splash clears and app is in `AppState.ready`
- `PopScope(canPop: false)` — cannot be dismissed with back button
- User must tick a checkbox before the "I Agree" button becomes active
- On acceptance: `AppProvider.acceptDisclaimer()` sets SharedPreferences key `disclaimer_agreed = true`
- `_RootState._disclaimerTriggered` prevents re-triggering within a session

**Layer 2 — Persistent banner** (`widgets/disclaimer_banner.dart`):
- Amber-tinted strip above the frequency list on every airport detail page
- Always visible, not dismissable
- Short form: "For recreational use only — always verify frequencies with official sources before flight."

**Layer 3 — Settings** (`settings_screen.dart`):
- Full `kDisclaimerText` always visible in Settings → Disclaimer section
- Imported via `show kDisclaimerText` from `disclaimer_dialog.dart`

### Frequency Filter

"With frequencies only" filter chip on both Search and Nearby screens.

**Implementation:**
- `AppProvider.hideNoFreq` (bool) — toggled by `toggleHideNoFreq()`
- Persisted as SharedPreferences key `hide_no_freq`
- On toggle: re-runs the active search query or nearby query immediately
- `DatabaseService.searchAirports()` and `getNearbyAirports()` accept `requireFrequencies: bool`
- When true, appends: `AND EXISTS (SELECT 1 FROM frequencies WHERE airport_ref = airports.id)`

**UI:**
- Chip matches existing radius chip style (amber when active, card colour when inactive)
- Nearby: second row below radius chips, `preferredSize` height 108px
- Search: below the search text field, `preferredSize` height 108px

### Contribute Link

Below every airport's frequency list (both when frequencies exist and when the list is empty):
- Text: "Missing a frequency? Add it at ourairports.com"
- Taps open `https://ourairports.com/airports/{ICAO}/` in the external browser
- Links directly to the correct airport's page on OurAirports where users can submit edits

---

## 22. Future Considerations

### RTL-SDR Native Integration (13–19 weeks)

Full native integration without requiring SDR Touch:
- Cross-compile `librtlsdr` + `libusb` for Android NDK (arm64-v8a)
- Write JNI wrapper layer
- Implement AM demodulation using `liquid-dsp` (MIT licence)
- Audio playback via OpenSL ES
- Flutter UI via EventChannel audio stream
- **Blocker:** `librtlsdr` is GPL — app layer would need to be open-source

### iOS Support

- Cannot do native USB (Apple restriction)
- Could support `rtl_tcp` network connection over WiFi
- LiveATC linking already works on iOS

### Play Store Submission Checklist

- [ ] Screenshots (minimum 2 phone screenshots)
- [ ] Play Console account created and verified
- [ ] App bundle signed with release keystore
- [ ] Privacy policy URL verified live
- [ ] Content rating questionnaire completed
- [ ] Target audience declaration
- [ ] Data safety form completed (references analytics section of this doc)
