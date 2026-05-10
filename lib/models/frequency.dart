import 'package:flutter/material.dart';
import '../constants.dart';

class Frequency {
  final int id;
  final int airportRef;
  final String airportIdent;
  final String type;
  final String description;
  final double frequencyMhz;

  const Frequency({
    required this.id,
    required this.airportRef,
    required this.airportIdent,
    required this.type,
    required this.description,
    required this.frequencyMhz,
  });

  // CSV column order from OurAirports airport-frequencies.csv:
  // id,airport_ref,airport_ident,type,description,frequency_mhz
  factory Frequency.fromCsvRow(List<dynamic> row) {
    String s(dynamic v) => v?.toString().trim() ?? '';
    return Frequency(
      id: int.tryParse(s(row[0])) ?? 0,
      airportRef: int.tryParse(s(row[1])) ?? 0,
      airportIdent: s(row[2]),
      type: s(row[3]),
      description: s(row[4]),
      frequencyMhz: double.tryParse(s(row[5])) ?? 0.0,
    );
  }

  factory Frequency.fromMap(Map<String, dynamic> m) {
    return Frequency(
      id: m['id'] as int,
      airportRef: m['airport_ref'] as int,
      airportIdent: m['airport_ident'] as String,
      type: m['type'] as String? ?? '',
      description: m['description'] as String? ?? '',
      frequencyMhz: (m['frequency_mhz'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'airport_ref': airportRef,
        'airport_ident': airportIdent,
        'type': type,
        'description': description,
        'frequency_mhz': frequencyMhz,
      };

  String get formatted => '${frequencyMhz.toStringAsFixed(3)} MHz';

  Color get color => freqTypeColor(type);

  // Canonical sort order for grouping frequencies on the detail screen
  int get sortWeight {
    final t = type.toUpperCase();
    if (t.startsWith('ATIS') || t.startsWith('AWOS') || t.startsWith('ASOS')) return 0;
    if (t.startsWith('DEL')) return 1;
    if (t.startsWith('GND')) return 2;
    if (t.startsWith('TWR')) return 3;
    if (t.startsWith('DEP')) return 4;
    if (t.startsWith('APP')) return 5;
    if (t.startsWith('CTR')) return 6;
    if (t.startsWith('UNIC')) return 7;
    return 8;
  }
}
