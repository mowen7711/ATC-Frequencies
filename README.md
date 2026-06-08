# ATC Frequencies

A Flutter Android app listing worldwide airport ATC frequencies. Search ~70,000 airports by name, ICAO, IATA code, or city — then tap through to see every frequency, runway, navaid, and a VHF signal reception estimate for your current location.

[<img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="60" alt="Get it on Google Play">](https://play.google.com/store/apps/details?id=com.atcfreq.atc_freq)

---

## Features

- **Airport search** — real-time search across ~70,000 airports worldwide (name, ICAO, IATA, city)
- **ATC frequencies** — approach, tower, ground, ATIS, clearance, and more with colour-coded type badges
- **Nearby airports** — GPS-based list with configurable radius (5–200 km or 5–100 miles)
- **Interactive map** — OpenStreetMap, no API key required
- **Runways** — length, surface, lighting, ILS chip for instrument approaches
- **Navaids** — VOR, NDB, ILS frequencies associated with each airport
- **VHF signal reception** — physics-based estimate (4/3 Earth radius model) based on distance and elevation
- **Favourites & home airport** — star airports and pin a home airport to the Favourites tab
- **Persistent notification** — foreground service showing nearest 3 airports, updated every 5 minutes
- **Frequency notification** — pin a full frequency list to the notification shade for quick reference in the cockpit
- **LiveATC.net** — one-tap link to live ATC audio streams
- **SDR Touch integration** — launch RTL-SDR receiver directly on any frequency via `iqsrc://`
- **Dark / Light / System theme** — respects system preference or override in Settings
- **Distance units** — km or miles

---

## Screenshots

_Coming soon_

---

## Data

Airport, frequency, runway, and navaid data from [OurAirports.com](https://ourairports.com) (CC0 public domain). Four CSV files (~13 MB total) are downloaded on first launch and refreshed weekly:

| File | Size | Rows |
|------|------|------|
| airports.csv | ~6 MB | ~70,000 |
| airport-frequencies.csv | ~3 MB | ~90,000 |
| runways.csv | ~2 MB | ~28,000 |
| navaids.csv | ~2 MB | ~11,000 |

No API key required.

---

## Tech stack

| Layer | Package |
|-------|---------|
| Framework | Flutter / Dart (SDK ≥ 3.3.0) |
| Local DB | sqflite 2.2.x (SQLite) |
| State | provider (ChangeNotifier) |
| GPS | geolocator |
| Background service | flutter_foreground_task |
| Notifications | flutter_local_notifications |
| Maps | flutter_map (OpenStreetMap) |
| HTTP | http |
| Shake detection | sensors_plus |
| URL launching | url_launcher |

---

## Building

Prerequisites: Flutter SDK ≥ 3.3.0, Android SDK, Java 17.

```bash
flutter pub get
flutter build apk --release
# or for Play Store:
flutter build appbundle
```

Signing: requires `android/key.properties` (not committed). See [Flutter docs on signing](https://docs.flutter.dev/deployment/android#signing-the-app).

---

## Privacy

This app collects anonymous, non-personal usage analytics (airport views, feature use, download timing). No personal data, no account required. Full details: [Privacy Policy](https://mowen7711.github.io/ATC-Frequencies/privacy-policy.html)

---

## License

Data: [OurAirports.com](https://ourairports.com) — CC0 (public domain)  
App code: All rights reserved © 2024 Mark Owen / 4T Technologies
