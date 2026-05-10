class Runway {
  final int id;
  final int airportRef;
  final String airportIdent;
  final int? lengthFt;
  final int? widthFt;
  final String surface;
  final bool lighted;
  final bool closed;
  final String leIdent;
  final double? leHeadingDegT;
  final int? leDisplacedThresholdFt;
  final String heIdent;
  final double? heHeadingDegT;
  final int? heDisplacedThresholdFt;

  const Runway({
    required this.id,
    required this.airportRef,
    required this.airportIdent,
    this.lengthFt,
    this.widthFt,
    required this.surface,
    required this.lighted,
    required this.closed,
    required this.leIdent,
    this.leHeadingDegT,
    this.leDisplacedThresholdFt,
    required this.heIdent,
    this.heHeadingDegT,
    this.heDisplacedThresholdFt,
  });

  // OurAirports runways.csv columns (0-indexed):
  // 0:id 1:airport_ref 2:airport_ident 3:length_ft 4:width_ft 5:surface
  // 6:lighted 7:closed 8:le_ident 9:le_lat 10:le_lon 11:le_elev
  // 12:le_heading_degT 13:le_displaced_threshold_ft
  // 14:he_ident 15:he_lat 16:he_lon 17:he_elev
  // 18:he_heading_degT 19:he_displaced_threshold_ft
  static Runway fromCsvRow(List<dynamic> r) {
    int? parseInt(dynamic v) {
      if (v == null || v.toString().isEmpty) return null;
      return int.tryParse(v.toString());
    }
    double? parseDouble(dynamic v) {
      if (v == null || v.toString().isEmpty) return null;
      return double.tryParse(v.toString());
    }
    bool parseBool(dynamic v) =>
        v.toString() == '1' || v.toString().toLowerCase() == 'true';

    return Runway(
      id: parseInt(r[0]) ?? 0,
      airportRef: parseInt(r[1]) ?? 0,
      airportIdent: r[2].toString(),
      lengthFt: parseInt(r[3]),
      widthFt: parseInt(r[4]),
      surface: r[5].toString().trim(),
      lighted: parseBool(r[6]),
      closed: parseBool(r[7]),
      leIdent: r[8].toString(),
      leHeadingDegT: parseDouble(r[12]),
      leDisplacedThresholdFt: parseInt(r[13]),
      heIdent: r[14].toString(),
      heHeadingDegT: parseDouble(r[18]),
      heDisplacedThresholdFt: parseInt(r[19]),
    );
  }

  static Runway fromMap(Map<String, dynamic> m) => Runway(
        id: m['id'] as int,
        airportRef: m['airport_ref'] as int,
        airportIdent: m['airport_ident'] as String,
        lengthFt: m['length_ft'] as int?,
        widthFt: m['width_ft'] as int?,
        surface: m['surface'] as String,
        lighted: (m['lighted'] as int) == 1,
        closed: (m['closed'] as int) == 1,
        leIdent: m['le_ident'] as String,
        leHeadingDegT: m['le_heading_degT'] as double?,
        leDisplacedThresholdFt: m['le_displaced_threshold_ft'] as int?,
        heIdent: m['he_ident'] as String,
        heHeadingDegT: m['he_heading_degT'] as double?,
        heDisplacedThresholdFt: m['he_displaced_threshold_ft'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'airport_ref': airportRef,
        'airport_ident': airportIdent,
        'length_ft': lengthFt,
        'width_ft': widthFt,
        'surface': surface,
        'lighted': lighted ? 1 : 0,
        'closed': closed ? 1 : 0,
        'le_ident': leIdent,
        'le_heading_degT': leHeadingDegT,
        'le_displaced_threshold_ft': leDisplacedThresholdFt,
        'he_ident': heIdent,
        'he_heading_degT': heHeadingDegT,
        'he_displaced_threshold_ft': heDisplacedThresholdFt,
      };

  // ── Display helpers ───────────────────────────────────────────────────────

  String get designator {
    if (leIdent.isEmpty && heIdent.isEmpty) return 'RWY —';
    if (leIdent.isEmpty) return 'RWY $heIdent';
    if (heIdent.isEmpty) return 'RWY $leIdent';
    return 'RWY $leIdent / $heIdent';
  }

  String get surfaceDisplay {
    final s = surface.toUpperCase();
    if (s.isEmpty || s == 'UNK') return 'Unknown';
    if (s.contains('ASP')) return 'Asphalt';
    if (s.contains('CON')) return 'Concrete';
    if (s.contains('GRASS') || s == 'GRS') return 'Grass';
    if (s.contains('GRVL') || s.contains('GRAVEL')) return 'Gravel';
    if (s.contains('TURF')) return 'Turf';
    if (s.contains('DIRT')) return 'Dirt';
    if (s.contains('WATER')) return 'Water';
    if (s.contains('SAND')) return 'Sand';
    if (s.contains('SNOW') || s.contains('ICE')) return 'Snow/Ice';
    if (s.contains('METAL') || s.contains('MAT')) return 'Pierced Steel';
    return surface;
  }

  String? get lengthDisplay {
    if (lengthFt == null) return null;
    final m = (lengthFt! * 0.3048).round();
    return '$m m  (${_commas(lengthFt!)} ft)';
  }

  String? get widthDisplay {
    if (widthFt == null) return null;
    final m = (widthFt! * 0.3048).round();
    return '$m m wide';
  }

  String _commas(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
