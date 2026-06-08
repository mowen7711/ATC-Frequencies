import 'dart:math';
import 'package:geolocator/geolocator.dart';

// ── Scanner assumptions ───────────────────────────────────────────────────────
// Transmitter : 25 W EIRP, 15 m antenna (typical ATC VHF ground station)
// Receiver    : average handheld scanner (Uniden/AOR class), rated ~-117 dBm
// Frequency   : 120 MHz (mid airband)
// Antenna     : stock rubber-duck, ~-6 dBi vs a proper VHF antenna
// Real-world factor: 0.50 — stock antennas, clutter, multipath and atmospheric
//   absorption mean a handheld typically achieves ~50 % of theoretical horizon.
//   Experienced scanner users report 10–20 km ground-level in practice vs the
//   20–30 km that ideal free-space geometry would suggest.

const double _towerHeightM = 15.0;   // ATC antenna above ground
const double _handsetHeightM = 1.5;  // scanner held in hand
const double _ftToM = 0.3048;
const double _realWorldFactor = 0.50; // theoretical → practical range

class SignalResult {
  final double distanceKm;
  final double estimatedRangeKm;
  final double userAltitudeM;
  final double airportElevationM;
  final double heightDifferenceM; // positive = user is higher
  final int percent; // 0–100
  final String label;
  final String detail;
  final SignalQuality quality;

  const SignalResult({
    required this.distanceKm,
    required this.estimatedRangeKm,
    required this.userAltitudeM,
    required this.airportElevationM,
    required this.heightDifferenceM,
    required this.percent,
    required this.label,
    required this.detail,
    required this.quality,
  });
}

enum SignalQuality { good, fair, marginal, poor, beyondRange, outOfRange }

class TerrainService {
  TerrainService._();
  static final TerrainService instance = TerrainService._();

  // ── Public ────────────────────────────────────────────────────────────────

  Future<Position?> getAltitude() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, // need best for altitude
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculate VHF line-of-sight reception probability.
  ///
  /// [airportElevationFt] — from OurAirports database (feet ASL).
  /// [userAltitudeM]      — GPS altitude (metres ASL).
  /// [distanceKm]         — great-circle distance to the airport.
  SignalResult calculate({
    required int? airportElevationFt,
    required double userAltitudeM,
    required double distanceKm,
  }) {
    final airportElev =
        airportElevationFt != null ? airportElevationFt * _ftToM : 0.0;
    final heightDiff = userAltitudeM - airportElev;

    // Effective receiver height above local terrain.
    // If below airport elevation the terrain between the two points is likely
    // higher — we use a floor of handset height to avoid negative sqrt.
    final effectiveRxH = max(heightDiff + _handsetHeightM, _handsetHeightM);

    // Radio horizon (4/3 Earth radius refraction model):
    // D_km = 4.12 * (√h_tx + √h_rx)  [heights in metres]
    final theoreticalRangeKm =
        4.12 * (sqrt(_towerHeightM) + sqrt(effectiveRxH));

    // Practical range after applying real-world losses (stock antenna,
    // terrain clutter, multipath). This is what a handheld actually achieves.
    final rangeKm = theoreticalRangeKm * _realWorldFactor;

    // Ratio of your distance to the practical range ceiling
    final ratio = rangeKm > 0 ? distanceKm / rangeKm : 99.0;

    int pct;
    String label;
    SignalQuality quality;
    final List<String> notes = [];

    // Hard physical limits — VHF is strictly line-of-sight.
    // The theoretical range already accounts for altitude; anything beyond
    // 8× theoretical is physically unreachable regardless of equipment.
    // Beyond 3× theoretical is firmly outside any practical scenario.
    final physicalMax = theoreticalRangeKm * 8.0;
    final absoluteMax = max(physicalMax, 300.0); // floor at 300 km

    if (distanceKm > absoluteMax) {
      // Physically impossible — Earth's curvature blocks VHF entirely
      return SignalResult(
        distanceKm: distanceKm,
        estimatedRangeKm: rangeKm,
        userAltitudeM: userAltitudeM,
        airportElevationM: airportElev,
        heightDifferenceM: heightDiff,
        percent: 0,
        label: 'Out of Range',
        detail: 'VHF signals cannot travel this distance — the Earth\'s curvature '
            'blocks line-of-sight at ${distanceKm.toStringAsFixed(0)} km. '
            'No antenna can overcome this.',
        quality: SignalQuality.outOfRange,
      );
    }

    // Base score — deliberately pessimistic to reflect stock antenna reality
    if (ratio <= 0.25) {
      pct = 72; label = 'Good'; quality = SignalQuality.good;
      notes.add('Well within practical range — reception likely with a clear sky view.');
    } else if (ratio <= 0.55) {
      pct = 50; label = 'Fair'; quality = SignalQuality.fair;
      notes.add('Within range but signal will be weak on a stock antenna. Expect occasional drop-outs.');
    } else if (ratio <= 0.85) {
      pct = 28; label = 'Marginal'; quality = SignalQuality.marginal;
      notes.add('Approaching the practical limit for a handheld — intermittent at best.');
    } else if (ratio <= 1.15) {
      pct = 12; label = 'Poor'; quality = SignalQuality.poor;
      notes.add('Beyond practical handheld range — unlikely without an elevated external antenna.');
    } else if (ratio <= 4.0) {
      pct = 4; label = 'Very Poor'; quality = SignalQuality.poor;
      notes.add('Too far for a handheld scanner. An elevated, high-gain antenna would be required.');
    } else {
      // Far beyond any practical scenario but not yet hitting physicalMax
      pct = 0; label = 'Beyond Range'; quality = SignalQuality.beyondRange;
      notes.add('At ${distanceKm.toStringAsFixed(0)} km this airport is too far for any ground-level '
          'VHF reception. Reception would only be possible from an aircraft.');
    }

    // Height modifiers — smaller bonuses, larger penalties
    if (quality != SignalQuality.beyondRange) {
      if (heightDiff >= 250) {
        pct = min(88, pct + 14);
        notes.add('Good height advantage (+${heightDiff.toInt()} m) — extends your effective horizon.');
      } else if (heightDiff >= 80) {
        pct = min(80, pct + 7);
        notes.add('Modest height advantage (+${heightDiff.toInt()} m) helps line-of-sight.');
      } else if (heightDiff < -25) {
        pct = max(3, pct - 12);
        notes.add('You are ${(-heightDiff).toInt()} m below airport elevation — terrain obstruction likely.');
      }
      if (heightDiff < -100) {
        pct = max(2, pct - 12);
        notes.add('Significant depression below airport — ground clutter will severely limit reception.');
      }
    }

    // Close proximity floor — honest ceiling even nearby (clutter, buildings)
    if (distanceKm < 2) {
      pct = max(pct, 74);
      notes.add('Very close range — reception likely despite clutter.');
    } else if (distanceKm < 5) {
      pct = max(pct, 58);
      notes.add('Close range — usable signal expected on flat, open ground.');
    }

    final detail = notes.join(' ');
    return SignalResult(
      distanceKm: distanceKm,
      estimatedRangeKm: rangeKm, // practical range (theoretical * real-world factor)
      userAltitudeM: userAltitudeM,
      airportElevationM: airportElev,
      heightDifferenceM: heightDiff,
      percent: pct.clamp(1, 99),
      label: label,
      detail: detail,
      quality: quality,
    );
  }
}
