import 'package:flutter/material.dart';

// Convenience — use context.col.* in widgets instead
export 'theme/app_colors.dart';

// Data source — OurAirports publishes daily CSVs under CC0
const String kAirportsUrl =
    'https://davidmegginson.github.io/ourairports-data/airports.csv';
const String kFrequenciesUrl =
    'https://davidmegginson.github.io/ourairports-data/airport-frequencies.csv';
const String kRunwaysUrl =
    'https://davidmegginson.github.io/ourairports-data/runways.csv';
const String kNavaidsUrl =
    'https://davidmegginson.github.io/ourairports-data/navaids.csv';

const int kUpdateIntervalDays = 7;

// Only surface airports that are operationally relevant by default
const List<String> kDefaultAirportTypes = [
  'large_airport',
  'medium_airport',
  'small_airport',
];

const double kDefaultNearbyRadiusKm = 50.0;

/// Radius chip values in km for each distance unit.
/// Miles values are exact km equivalents of 5, 10, 25, 50, 100 miles
/// so formatRadius() rounds them to clean whole numbers.
const List<double> kRadiiKm    = [10.0, 25.0, 50.0, 100.0, 200.0];
const List<double> kRadiiMiles = [8.047, 16.093, 40.234, 80.467, 160.934];

// ── Distance unit preference ──────────────────────────────────────────────────

enum DistanceUnit { km, miles }

const double _kMilesPerKm = 0.621371;

/// Format a distance (internally always km) for display in the user's chosen unit.
String formatDistance(double km, DistanceUnit unit) {
  if (unit == DistanceUnit.miles) {
    final mi = km * _kMilesPerKm;
    return mi < 1 ? '${(mi * 5280).toInt()} ft' : '${mi.toStringAsFixed(1)} mi';
  }
  return km < 1 ? '${(km * 1000).toInt()} m' : '${km.toStringAsFixed(1)} km';
}

/// Format a radius value for the nearby chip labels.
String formatRadius(double km, DistanceUnit unit) {
  if (unit == DistanceUnit.miles) {
    final mi = (km * _kMilesPerKm).round();
    return '${mi}mi';
  }
  return '${km.toInt()}km';
}

// Aviation dark theme colours
const Color kBackground = Color(0xFF0B1120);
const Color kSurface = Color(0xFF131E30);
const Color kCard = Color(0xFF1C2B40);
const Color kBorder = Color(0xFF2A3F5A);
const Color kAccent = Color(0xFFFFB300); // amber
const Color kAccentDim = Color(0xFFCC8E00);
const Color kTextPrimary = Color(0xFFE8EDF5);
const Color kTextSecondary = Color(0xFF8EA4C0);
const Color kTextMuted = Color(0xFF4A6280);

// Frequency type colours
const Map<String, Color> kFreqTypeColors = {
  'ATIS': Color(0xFF2196F3),
  'AWOS': Color(0xFF03A9F4),
  'ASOS': Color(0xFF00BCD4),
  'TWR': Color(0xFFF44336),
  'GND': Color(0xFFFFC107),
  'DEL': Color(0xFF009688),
  'APP': Color(0xFF4CAF50),
  'DEP': Color(0xFFFF9800),
  'CTR': Color(0xFF9C27B0),
  'UNIC': Color(0xFF78909C), // UNICOM
  'MULT': Color(0xFF607D8B),
};

Color freqTypeColor(String type) {
  final upper = type.toUpperCase();
  for (final entry in kFreqTypeColors.entries) {
    if (upper.startsWith(entry.key)) return entry.value;
  }
  return const Color(0xFF546E7A);
}

// Airport type labels
const Map<String, String> kAirportTypeLabels = {
  'large_airport': 'Large Airport',
  'medium_airport': 'Medium Airport',
  'small_airport': 'Small Airport',
  'heliport': 'Heliport',
  'seaplane_base': 'Seaplane Base',
  'balloonport': 'Balloon Port',
  'closed': 'Closed',
};
