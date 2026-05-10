import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../models/frequency.dart';
import 'database_service.dart';

typedef ProgressCallback = void Function(String status, double progress);

class DataService {
  DataService._();
  static final DataService instance = DataService._();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Ensures local data exists; triggers a background refresh if stale.
  Future<void> ensureData({required ProgressCallback onProgress}) async {
    final hasData = await DatabaseService.instance.hasData();
    if (!hasData) {
      await _downloadAll(onProgress: onProgress);
    } else {
      onProgress('Ready', 1.0);
      _maybeRefreshInBackground();
    }
  }

  /// Forces a full refresh — call from a manual "Refresh data" button.
  Future<void> forceRefresh({required ProgressCallback onProgress}) async {
    await DatabaseService.instance.clearAll();
    await _downloadAll(onProgress: onProgress);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _maybeRefreshInBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('last_update') ?? 0;
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
        .inDays;
    if (daysSince >= kUpdateIntervalDays) {
      // Silent background refresh — user keeps using stale data until done
      _downloadAll(onProgress: (_, __) {}).ignore();
    }
  }

  Future<void> _downloadAll({required ProgressCallback onProgress}) async {
    // Step 1: airports (0–45%)
    onProgress('Downloading airport data…', 0.0);
    final airportsCsv = await _download(
      kAirportsUrl,
      onBytes: (received, total) =>
          onProgress('Downloading airports…', 0.0 + 0.2 * received / total),
    );

    onProgress('Parsing airports…', 0.2);
    final airports = await compute(_parseAirports, airportsCsv);

    onProgress('Storing airports…', 0.25);
    await DatabaseService.instance.insertAirportsBatch(airports,
        onProgress: (p) => onProgress('Storing airports…', 0.25 + 0.2 * p));

    // Step 2: frequencies (45–90%)
    onProgress('Downloading frequency data…', 0.45);
    final freqCsv = await _download(
      kFrequenciesUrl,
      onBytes: (received, total) =>
          onProgress('Downloading frequencies…', 0.45 + 0.2 * received / total),
    );

    onProgress('Parsing frequencies…', 0.65);
    final freqs = await compute(_parseFrequencies, freqCsv);

    onProgress('Storing frequencies…', 0.7);
    await DatabaseService.instance.insertFrequenciesBatch(freqs,
        onProgress: (p) => onProgress('Storing frequencies…', 0.7 + 0.25 * p));

    // Step 3: save timestamp
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_update', DateTime.now().millisecondsSinceEpoch);

    onProgress('Ready', 1.0);
  }

  Future<String> _download(
    String url, {
    void Function(int received, int total)? onBytes,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    final total = response.contentLength ?? 1;
    int received = 0;
    final chunks = <int>[];
    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
      received += chunk.length;
      onBytes?.call(received, total);
    }
    return utf8.decode(chunks);
  }
}

// ── Isolate-safe parsers ──────────────────────────────────────────────────

List<Airport> _parseAirports(String csv) {
  final rows = const CsvToListConverter(eol: '\n').convert(csv);
  if (rows.isEmpty) return [];
  // Skip header row
  return rows
      .skip(1)
      .where((r) => r.length >= 14 && r[0].toString().isNotEmpty)
      .map(Airport.fromCsvRow)
      .where((a) => a.ident.isNotEmpty && a.name.isNotEmpty)
      .toList();
}

List<Frequency> _parseFrequencies(String csv) {
  final rows = const CsvToListConverter(eol: '\n').convert(csv);
  if (rows.isEmpty) return [];
  return rows
      .skip(1)
      .where((r) => r.length >= 6 && r[0].toString().isNotEmpty)
      .map(Frequency.fromCsvRow)
      .where((f) => f.frequencyMhz > 0)
      .toList();
}
