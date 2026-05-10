import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../models/frequency.dart';
import '../models/navaid.dart';
import '../models/runway.dart';
import 'database_service.dart';

typedef ProgressCallback = void Function(String status, double progress);

class DataService {
  DataService._();
  static final DataService instance = DataService._();

  Future<void> ensureData({required ProgressCallback onProgress}) async {
    final hasData = await DatabaseService.instance.hasData();
    if (!hasData) {
      await _downloadAll(onProgress: onProgress);
    } else {
      onProgress('Ready', 1.0);
      _maybeRefreshInBackground();
    }
  }

  Future<void> forceRefresh({required ProgressCallback onProgress}) async {
    await DatabaseService.instance.clearAll();
    await _downloadAll(onProgress: onProgress);
  }

  void _maybeRefreshInBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('last_update') ?? 0;
    final daysSince = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
        .inDays;
    if (daysSince >= kUpdateIntervalDays) {
      _downloadAll(onProgress: (_, __) {}).ignore();
    }
  }

  Future<void> _downloadAll({required ProgressCallback onProgress}) async {
    // ── Step 1: airports (0–20%) ────────────────────────────────────────────
    onProgress('Downloading airport data…', 0.0);
    final airportsCsv = await _download(
      kAirportsUrl,
      onBytes: (r, t) => onProgress('Downloading airports…', 0.10 * r / t),
    );
    onProgress('Parsing airports…', 0.10);
    final airports = await compute(_parseAirports, airportsCsv);
    onProgress('Storing airports…', 0.12);
    await DatabaseService.instance.insertAirportsBatch(airports,
        onProgress: (p) => onProgress('Storing airports…', 0.12 + 0.08 * p));

    // ── Step 2: frequencies (20–40%) ────────────────────────────────────────
    onProgress('Downloading frequency data…', 0.20);
    final freqCsv = await _download(
      kFrequenciesUrl,
      onBytes: (r, t) =>
          onProgress('Downloading frequencies…', 0.20 + 0.10 * r / t),
    );
    onProgress('Parsing frequencies…', 0.30);
    final freqs = await compute(_parseFrequencies, freqCsv);
    onProgress('Storing frequencies…', 0.32);
    await DatabaseService.instance.insertFrequenciesBatch(freqs,
        onProgress: (p) => onProgress('Storing frequencies…', 0.32 + 0.08 * p));

    // ── Step 3: runways (40–65%) ────────────────────────────────────────────
    onProgress('Downloading runway data…', 0.40);
    final runwayCsv = await _download(
      kRunwaysUrl,
      onBytes: (r, t) =>
          onProgress('Downloading runways…', 0.40 + 0.12 * r / t),
    );
    onProgress('Parsing runways…', 0.52);
    final runways = await compute(_parseRunways, runwayCsv);
    onProgress('Storing runways…', 0.54);
    await DatabaseService.instance.insertRunwaysBatch(runways,
        onProgress: (p) => onProgress('Storing runways…', 0.54 + 0.11 * p));

    // ── Step 4: navaids (65–95%) ────────────────────────────────────────────
    onProgress('Downloading navaid data…', 0.65);
    final navaidCsv = await _download(
      kNavaidsUrl,
      onBytes: (r, t) =>
          onProgress('Downloading navaids…', 0.65 + 0.15 * r / t),
    );
    onProgress('Parsing navaids…', 0.80);
    final navaids = await compute(_parseNavaids, navaidCsv);
    onProgress('Storing navaids…', 0.82);
    await DatabaseService.instance.insertNavaidsBatch(navaids,
        onProgress: (p) => onProgress('Storing navaids…', 0.82 + 0.13 * p));

    // ── Step 5: save timestamp ──────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_update', DateTime.now().millisecondsSinceEpoch);
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

// ── Isolate-safe parsers ──────────────────────────────────────────────────────

List<Airport> _parseAirports(String csv) {
  final rows = const CsvToListConverter(eol: '\n').convert(csv);
  if (rows.isEmpty) return [];
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

List<Runway> _parseRunways(String csv) {
  final rows = const CsvToListConverter(eol: '\n').convert(csv);
  if (rows.isEmpty) return [];
  return rows
      .skip(1)
      .where((r) => r.length >= 20 && r[0].toString().isNotEmpty)
      .map(Runway.fromCsvRow)
      .where((r) => r.airportIdent.isNotEmpty)
      .toList();
}

List<Navaid> _parseNavaids(String csv) {
  final rows = const CsvToListConverter(eol: '\n').convert(csv);
  if (rows.isEmpty) return [];
  return rows
      .skip(1)
      .where((r) => r.length >= 20 && r[0].toString().isNotEmpty)
      .map(Navaid.fromCsvRow)
      // Only keep navaids linked to an airport — everything else is useless here
      .where((n) => n.associatedAirport.isNotEmpty)
      .toList();
}
