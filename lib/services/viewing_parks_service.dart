import 'dart:convert';
import 'package:flutter/services.dart';

class ViewingParkSpot {
  final String name;
  final double lat;
  final double lon;

  const ViewingParkSpot({required this.name, required this.lat, required this.lon});
}

class ViewingParkInfo {
  final List<ViewingParkSpot> spots;
  final String url;

  const ViewingParkInfo({required this.spots, required this.url});

  bool get hasSpots => spots.isNotEmpty;
}

class ViewingParksService {
  static final ViewingParksService instance = ViewingParksService._();
  ViewingParksService._();

  Map<String, ViewingParkInfo>? _data;
  bool _loading = false;

  Future<void> _ensureLoaded() async {
    if (_data != null || _loading) return;
    _loading = true;
    try {
      final raw = await rootBundle.loadString('assets/data/viewing_parks.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _data = map.map((icao, v) {
        final entry = v as Map<String, dynamic>;
        final spotsList = (entry['spots'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .where((s) => s['lat'] != null && s['lon'] != null)
            .map((s) => ViewingParkSpot(
                  name: (s['name'] as String?) ?? '',
                  lat: (s['lat'] as num).toDouble(),
                  lon: (s['lon'] as num).toDouble(),
                ))
            .toList();
        return MapEntry(
          icao,
          ViewingParkInfo(
            spots: spotsList,
            url: entry['url'] as String,
          ),
        );
      });
    } catch (_) {
      _data = {};
    } finally {
      _loading = false;
    }
  }

  Future<ViewingParkInfo?> lookup(String icao) async {
    await _ensureLoaded();
    return _data?[icao.toUpperCase()];
  }
}
