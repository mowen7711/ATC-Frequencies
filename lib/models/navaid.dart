class Navaid {
  final int id;
  final String ident;
  final String name;
  final String type;
  final double? frequencyKhz;
  final double? dmeFrequencyKhz;
  final String? dmeChannel;
  final String associatedAirport;

  const Navaid({
    required this.id,
    required this.ident,
    required this.name,
    required this.type,
    this.frequencyKhz,
    this.dmeFrequencyKhz,
    this.dmeChannel,
    required this.associatedAirport,
  });

  // OurAirports navaids.csv columns (0-indexed):
  // 0:id 1:filename 2:ident 3:name 4:type 5:frequency_khz
  // 6:latitude_deg 7:longitude_deg 8:elevation_ft 9:iso_country
  // 10:dme_frequency_khz 11:dme_channel 12:dme_lat 13:dme_lon
  // 14:dme_elev 15:slaved_variation_deg 16:magnetic_variation_deg
  // 17:usageType 18:power 19:associated_airport
  static Navaid fromCsvRow(List<dynamic> r) {
    double? parseKhz(dynamic v) {
      if (v == null || v.toString().isEmpty) return null;
      return double.tryParse(v.toString());
    }

    return Navaid(
      id: int.tryParse(r[0].toString()) ?? 0,
      ident: r[2].toString(),
      name: r[3].toString(),
      type: r[4].toString().trim(),
      frequencyKhz: parseKhz(r[5]),
      dmeFrequencyKhz: parseKhz(r[10]),
      dmeChannel: r[11].toString().isEmpty ? null : r[11].toString(),
      associatedAirport: r[19].toString().trim(),
    );
  }

  static Navaid fromMap(Map<String, dynamic> m) => Navaid(
        id: m['id'] as int,
        ident: m['ident'] as String,
        name: m['name'] as String,
        type: m['type'] as String,
        frequencyKhz: m['frequency_khz'] as double?,
        dmeFrequencyKhz: m['dme_frequency_khz'] as double?,
        dmeChannel: m['dme_channel'] as String?,
        associatedAirport: m['associated_airport'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ident': ident,
        'name': name,
        'type': type,
        'frequency_khz': frequencyKhz,
        'dme_frequency_khz': dmeFrequencyKhz,
        'dme_channel': dmeChannel,
        'associated_airport': associatedAirport,
      };

  // ── Display helpers ───────────────────────────────────────────────────────

  bool get isIls => type.toUpperCase().contains('ILS');
  bool get isVor => type.toUpperCase().contains('VOR');
  bool get isNdb => type.toUpperCase() == 'NDB' || type.toUpperCase() == 'NDB-DME';

  /// Frequency in MHz for VHF navaids (VOR, ILS localiser), kHz label for NDB.
  String get frequencyDisplay {
    if (frequencyKhz == null) return '—';
    if (isNdb) return '${frequencyKhz!.toStringAsFixed(0)} kHz';
    // VOR/ILS: kHz → MHz
    return '${(frequencyKhz! / 1000).toStringAsFixed(2)} MHz';
  }

  String get dmeFrequencyDisplay {
    if (dmeFrequencyKhz == null) return '';
    return 'DME ${(dmeFrequencyKhz! / 1000).toStringAsFixed(2)} MHz';
  }

  String get typeDisplay {
    switch (type.toUpperCase()) {
      case 'ILS-ILS':
      case 'ILS':
        return 'ILS';
      case 'ILS-LOC-ONLY':
        return 'LOC';
      case 'ILS-GS':
        return 'GS';
      case 'ILS-DME':
        return 'ILS/DME';
      case 'VOR':
        return 'VOR';
      case 'VOR-DME':
        return 'VOR/DME';
      case 'VORTAC':
        return 'VORTAC';
      case 'NDB':
        return 'NDB';
      case 'NDB-DME':
        return 'NDB/DME';
      case 'DME':
        return 'DME';
      case 'TACAN':
        return 'TACAN';
      default:
        return type;
    }
  }

  int get sortWeight {
    if (isIls) return 0;
    if (isVor) return 1;
    if (isNdb) return 2;
    return 3;
  }
}
