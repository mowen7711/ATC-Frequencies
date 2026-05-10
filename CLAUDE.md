# ATC Frequencies — Project Context

## What this app does
Cross-platform Flutter app (iOS + Android) listing worldwide airport ATC frequencies. Users can search airports by name/ICAO/IATA/city, star favourites, pin a home airport, view nearby airports via GPS, and see a map. A toggleable background service shows a persistent notification listing the nearest airports.

## Data source
OurAirports.com (CC0/public domain). Two CSVs downloaded on first launch, refreshed weekly:
- `airports.csv` (~6 MB, ~70,000 rows) — `https://davidmegginson.github.io/ourairports-data/airports.csv`
- `airport-frequencies.csv` (~3 MB, ~90,000 rows) — `https://davidmegginson.github.io/ourairports-data/airport-frequencies.csv`

No API key. No rate limiting. Free forever. Hosting by the maintainer; act as your own mirror if traffic becomes a concern.

## Tech stack
| Layer | Choice | Notes |
|-------|--------|-------|
| Framework | Flutter/Dart | Single codebase, iOS + Android |
| Local DB | sqflite **^2.2.8+4** | **pinned** — 2.3.x pulls jni which requires NDK |
| State | provider (ChangeNotifier) | AppProvider is the main store |
| GPS | geolocator ^13.0.1 | Also used for permission checks |
| Background service | flutter_foreground_task ^8.14.0 (resolved 8.17.0) | Android foreground service, persistent notification |
| Maps | flutter_map ^7.0.2 + OpenStreetMap tiles | No API key required |
| CSV parsing | csv ^6.0.0 in compute() isolate | Keeps UI thread free |
| Preferences | shared_preferences ^2.3.2 | Favourites, home airport, settings flags |

## Key files

### Services
- `lib/services/database_service.dart` — SQLite: airports, frequencies, favourites tables. Batch inserts chunked at 500 rows. `getNearbyAirports()` uses bounding-box SQL pre-filter then Haversine in Dart (SQLite lacks trig).
- `lib/services/data_service.dart` — Downloads + parses CSVs. `ensureData()` on launch; `forceRefresh()` clears DB and re-downloads.
- `lib/services/background_service.dart` — Flutter foreground task. `BackgroundService.init()` called from main(). `start()` requests POST_NOTIFICATIONS then location permission before starting service.
- `lib/services/terrain_service.dart` — VHF signal reception model (see Signal Reception section below).
- `lib/services/location_service.dart` — Geolocator wrapper returning `LocationResult`.

### Models
- `lib/models/airport.dart` — `Airport.fromCsvRow()`, `distanceTo()` (Haversine, returns km), `displayCode` getter.
- `lib/models/frequency.dart` — `Frequency.fromCsvRow()`, `sortWeight` for type ordering.

### Providers
- `lib/providers/app_provider.dart` — AppState enum, favourites, searchResults, nearbyAirports, homeAirport. SharedPreferences key: `home_airport_ident`.

### Screens
- `lib/screens/home_screen.dart` — Bottom nav: Favourites (0), Nearby (1), Search (2). `HomeScreen({initialTab})` for notification deep-link to Nearby.
- `lib/screens/airport_detail_screen.dart` — Shows frequencies grouped by type, SignalReceptionCard, tap-to-copy on frequencies and coordinates.
- `lib/screens/settings_screen.dart` — Toggle background monitoring, "Refresh data now" button.

### Widgets
- `lib/widgets/home_airport_card.dart` — Home airport banner at top of Favourites tab. Opens `_HomeAirportPicker` bottom sheet using `AppProvider.search()`.
- `lib/widgets/signal_reception_card.dart` — Fetches GPS altitude, calls `TerrainService.calculate()`, shows result with signal bars, percentage, detail text and stats grid.

## Signal reception model
Physics: VHF line-of-sight (airband ~120 MHz).

```
theoreticalRangeKm = 4.12 × (√h_tx + √h_rx)   // radio horizon
practicalRangeKm   = theoreticalRangeKm × 0.50  // 50% real-world factor
ratio              = distanceKm / practicalRangeKm
```

Constants: `_towerHeightM=15` (ATC antenna), `_handsetHeightM=1.5`, `_realWorldFactor=0.50` (stock rubber-duck antenna, urban clutter, multipath).

Scoring is deliberately pessimistic:
| ratio | score | label |
|-------|-------|-------|
| ≤ 0.25 | 72% | Good |
| ≤ 0.55 | 50% | Fair |
| ≤ 0.85 | 28% | Marginal |
| ≤ 1.15 | 12% | Poor |
| > 1.15 | 4% | Very Poor |

Height modifiers: ≥250 m advantage → +14%; ≥80 m → +7%; < −25 m → −12%; additionally < −100 m → another −12%.
Proximity floors: < 2 km → min 74%; < 5 km → min 58%.

## Background persistent notification
**Android only** (iOS background location is different).

- flutter_foreground_task runs `NearbyAirportsTaskHandler` in a separate Dart isolate.
- Repeats every 5 minutes, queries nearby airports, updates notification text with nearest 3.
- Notification channel: `atc_nearby_airports`, LOW importance/priority.
- Tapping notification deep-links to Nearby tab via `FlutterForegroundTask.launchApp('/nearby')`.
- **Critical**: Android 13+ (API 33+) requires POST_NOTIFICATIONS runtime permission. `BackgroundService.start()` calls `FlutterForegroundTask.requestNotificationPermission()` first.

## Android manifest permissions
`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `INTERNET`.

Service: `com.pravera.flutter_foreground_task.service.ForegroundService` with `foregroundServiceType="location"`.

Do **not** manually declare `BootReceiver` — the plugin uses `RebootReceiver` internally.

## Colours / theme
Dark aviation theme. Key constants in `lib/constants.dart`:
- `kBackground` = `#0B1120`
- `kAccent` = `#FFB300` (amber)
- `kCard`, `kSurface`, `kBorder`, `kTextPrimary`, `kTextSecondary`, `kTextMuted`

Frequency type colours: ATIS=blue, TWR=red, GND=yellow, DEP/APP=orange, CTR=purple, UNICOM=green.

## Known gotchas
- sqflite **must** stay at ^2.2.8+4. 2.3.x introduces a jni dependency that requires Android NDK (1.5 GB download).
- `CardTheme` was renamed to `CardThemeData` in recent Flutter; use `CardThemeData` in `ThemeData`.
- `Switch.activeColor` is deprecated; use `activeThumbColor`.
- Do not use `const` with non-const children in `SliverToBoxAdapter`.
- The plugin's own AndroidManifest already merges POST_NOTIFICATIONS; you still need to call `requestNotificationPermission()` at runtime on Android 13+.

## Build / run
```bash
cd /Users/mark/atc_freq
flutter run          # connects to attached device/emulator
flutter build apk    # release APK
flutter build appbundle  # Play Store bundle
```
Android SDK lives at `~/Library/Android/sdk`. Java: temurin@17 (`/opt/homebrew/opt/temurin@17`).
