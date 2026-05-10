import 'package:flutter/material.dart';

// Data source — OurAirports publishes daily CSVs under CC0
const String kAirportsUrl =
    'https://davidmegginson.github.io/ourairports-data/airports.csv';
const String kFrequenciesUrl =
    'https://davidmegginson.github.io/ourairports-data/airport-frequencies.csv';

const int kUpdateIntervalDays = 7;

// Only surface airports that are operationally relevant by default
const List<String> kDefaultAirportTypes = [
  'large_airport',
  'medium_airport',
  'small_airport',
];

const double kDefaultNearbyRadiusKm = 50.0;

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
