import 'dart:math';

class Airport {
  final int id;
  final String ident; // ICAO code e.g. EGLL
  final String type;
  final String name;
  final double? latitude;
  final double? longitude;
  final int? elevationFt;
  final String continent;
  final String isoCountry;
  final String isoRegion;
  final String municipality;
  final String gpsCode;
  final String iataCode;

  const Airport({
    required this.id,
    required this.ident,
    required this.type,
    required this.name,
    this.latitude,
    this.longitude,
    this.elevationFt,
    this.continent = '',
    this.isoCountry = '',
    this.isoRegion = '',
    this.municipality = '',
    this.gpsCode = '',
    this.iataCode = '',
  });

  // CSV column order from OurAirports airports.csv:
  // id,ident,type,name,latitude_deg,longitude_deg,elevation_ft,
  // continent,iso_country,iso_region,municipality,scheduled_service,
  // gps_code,iata_code,local_code,home_link,wikipedia_link,keywords
  factory Airport.fromCsvRow(List<dynamic> row) {
    double? parseLat(dynamic v) => v == null || v.toString().isEmpty ? null : double.tryParse(v.toString());
    int? parseElev(dynamic v) => v == null || v.toString().isEmpty ? null : int.tryParse(v.toString());
    String s(dynamic v) => v?.toString().trim() ?? '';

    return Airport(
      id: int.tryParse(s(row[0])) ?? 0,
      ident: s(row[1]),
      type: s(row[2]),
      name: s(row[3]),
      latitude: parseLat(row[4]),
      longitude: parseLat(row[5]),
      elevationFt: parseElev(row[6]),
      continent: s(row[7]),
      isoCountry: s(row[8]),
      isoRegion: s(row[9]),
      municipality: s(row[10]),
      gpsCode: s(row[12]),
      iataCode: s(row[13]),
    );
  }

  factory Airport.fromMap(Map<String, dynamic> m) {
    return Airport(
      id: m['id'] as int,
      ident: m['ident'] as String,
      type: m['type'] as String? ?? '',
      name: m['name'] as String,
      latitude: m['latitude_deg'] as double?,
      longitude: m['longitude_deg'] as double?,
      elevationFt: m['elevation_ft'] as int?,
      continent: m['continent'] as String? ?? '',
      isoCountry: m['iso_country'] as String? ?? '',
      isoRegion: m['iso_region'] as String? ?? '',
      municipality: m['municipality'] as String? ?? '',
      gpsCode: m['gps_code'] as String? ?? '',
      iataCode: m['iata_code'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ident': ident,
        'type': type,
        'name': name,
        'latitude_deg': latitude,
        'longitude_deg': longitude,
        'elevation_ft': elevationFt,
        'continent': continent,
        'iso_country': isoCountry,
        'iso_region': isoRegion,
        'municipality': municipality,
        'gps_code': gpsCode,
        'iata_code': iataCode,
      };

  // Haversine distance in km to a given lat/lon
  double? distanceTo(double lat, double lon) {
    if (latitude == null || longitude == null) return null;
    const R = 6371.0;
    final dLat = _rad(lat - latitude!);
    final dLon = _rad(lon - longitude!);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(latitude!)) * cos(_rad(lat)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;

  String get displayCode =>
      iataCode.isNotEmpty ? iataCode : (gpsCode.isNotEmpty ? gpsCode : ident);

  String get locationString {
    final parts = <String>[];
    if (municipality.isNotEmpty) parts.add(municipality);
    if (isoCountry.isNotEmpty) parts.add(isoCountry);
    return parts.join(', ');
  }

  bool get hasCoordinates => latitude != null && longitude != null;
}
