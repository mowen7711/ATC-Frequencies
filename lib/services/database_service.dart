import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/airport.dart';
import '../models/frequency.dart';
import '../models/navaid.dart';
import '../models/runway.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'atc_freq.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createAirportTables(db);
    await _createRunwayTable(db);
    await _createNavaidTable(db);
    await _createFavouritesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createRunwayTable(db);
      await _createNavaidTable(db);
      // Clear existing data so runways + navaids are fetched on next launch
      await db.delete('airports');
      await db.delete('frequencies');
    }
  }

  Future<void> _createAirportTables(Database db) async {
    await db.execute('''
      CREATE TABLE airports (
        id INTEGER PRIMARY KEY,
        ident TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        latitude_deg REAL,
        longitude_deg REAL,
        elevation_ft INTEGER,
        continent TEXT DEFAULT '',
        iso_country TEXT DEFAULT '',
        iso_region TEXT DEFAULT '',
        municipality TEXT DEFAULT '',
        gps_code TEXT DEFAULT '',
        iata_code TEXT DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX idx_ap_ident ON airports(ident)');
    await db.execute('CREATE INDEX idx_ap_name ON airports(name)');
    await db.execute('CREATE INDEX idx_ap_iata ON airports(iata_code)');
    await db.execute(
        'CREATE INDEX idx_ap_coords ON airports(latitude_deg, longitude_deg)');

    await db.execute('''
      CREATE TABLE frequencies (
        id INTEGER PRIMARY KEY,
        airport_ref INTEGER NOT NULL,
        airport_ident TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT DEFAULT '',
        frequency_mhz REAL NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_freq_ref ON frequencies(airport_ref)');
  }

  Future<void> _createRunwayTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS runways (
        id INTEGER PRIMARY KEY,
        airport_ref INTEGER NOT NULL,
        airport_ident TEXT NOT NULL,
        length_ft INTEGER,
        width_ft INTEGER,
        surface TEXT DEFAULT '',
        lighted INTEGER NOT NULL DEFAULT 0,
        closed INTEGER NOT NULL DEFAULT 0,
        le_ident TEXT DEFAULT '',
        le_heading_degT REAL,
        le_displaced_threshold_ft INTEGER,
        he_ident TEXT DEFAULT '',
        he_heading_degT REAL,
        he_displaced_threshold_ft INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rwy_ref ON runways(airport_ref)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rwy_ident ON runways(airport_ident)');
  }

  Future<void> _createNavaidTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS navaids (
        id INTEGER PRIMARY KEY,
        ident TEXT NOT NULL,
        name TEXT DEFAULT '',
        type TEXT NOT NULL,
        frequency_khz REAL,
        dme_frequency_khz REAL,
        dme_channel TEXT DEFAULT '',
        associated_airport TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_nav_airport ON navaids(associated_airport)');
  }

  Future<void> _createFavouritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE favourites (
        ident TEXT PRIMARY KEY,
        added_at INTEGER NOT NULL
      )
    ''');
  }

  // ── Data load ─────────────────────────────────────────────────────────────

  Future<bool> hasData() async {
    final d = await db;
    final apCount =
        (await d.rawQuery('SELECT COUNT(*) AS c FROM airports')).first['c']
            as int;
    final rwyCount =
        (await d.rawQuery('SELECT COUNT(*) AS c FROM runways')).first['c']
            as int;
    return apCount > 0 && rwyCount > 0;
  }

  Future<void> insertAirportsBatch(
    List<Airport> airports, {
    void Function(double progress)? onProgress,
  }) async {
    final d = await db;
    const chunkSize = 500;
    for (int i = 0; i < airports.length; i += chunkSize) {
      final chunk = airports.sublist(i, min(i + chunkSize, airports.length));
      final batch = d.batch();
      for (final a in chunk) {
        batch.insert('airports', a.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      onProgress?.call((i + chunk.length) / airports.length);
    }
  }

  Future<void> insertFrequenciesBatch(
    List<Frequency> freqs, {
    void Function(double progress)? onProgress,
  }) async {
    final d = await db;
    const chunkSize = 500;
    for (int i = 0; i < freqs.length; i += chunkSize) {
      final chunk = freqs.sublist(i, min(i + chunkSize, freqs.length));
      final batch = d.batch();
      for (final f in chunk) {
        batch.insert('frequencies', f.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      onProgress?.call((i + chunk.length) / freqs.length);
    }
  }

  Future<void> insertRunwaysBatch(
    List<Runway> runways, {
    void Function(double progress)? onProgress,
  }) async {
    final d = await db;
    const chunkSize = 500;
    for (int i = 0; i < runways.length; i += chunkSize) {
      final chunk = runways.sublist(i, min(i + chunkSize, runways.length));
      final batch = d.batch();
      for (final r in chunk) {
        batch.insert('runways', r.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      onProgress?.call((i + chunk.length) / runways.length);
    }
  }

  Future<void> insertNavaidsBatch(
    List<Navaid> navaids, {
    void Function(double progress)? onProgress,
  }) async {
    final d = await db;
    const chunkSize = 500;
    for (int i = 0; i < navaids.length; i += chunkSize) {
      final chunk = navaids.sublist(i, min(i + chunkSize, navaids.length));
      final batch = d.batch();
      for (final n in chunk) {
        batch.insert('navaids', n.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      onProgress?.call((i + chunk.length) / navaids.length);
    }
  }

  Future<void> clearAll() async {
    final d = await db;
    await d.delete('airports');
    await d.delete('frequencies');
    await d.delete('runways');
    await d.delete('navaids');
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<Airport>> searchAirports(String query,
      {int limit = 50, List<String>? types, bool requireFrequencies = false}) async {
    if (query.trim().isEmpty) return [];
    final d = await db;
    final q = '%${query.trim()}%';
    final typeFilter = types != null && types.isNotEmpty
        ? 'AND type IN (${types.map((_) => '?').join(',')})'
        : '';
    final freqFilter = requireFrequencies
        ? 'AND EXISTS (SELECT 1 FROM frequencies WHERE airport_ref = airports.id)'
        : '';
    final args = [q, q, q, q, if (types != null) ...types, limit];
    final rows = await d.rawQuery('''
      SELECT * FROM airports
      WHERE (name LIKE ? OR ident LIKE ? OR iata_code LIKE ? OR municipality LIKE ?)
      $typeFilter
      $freqFilter
      ORDER BY
        CASE WHEN iata_code LIKE ? THEN 0
             WHEN ident LIKE ? THEN 1
             ELSE 2 END,
        name ASC
      LIMIT ?
    ''', [...args.sublist(0, args.length - 1), q, q, limit]);
    return rows.map(Airport.fromMap).toList();
  }

  // ── Frequency search ─────────────────────────────────────────────────────

  /// Returns airports that have a frequency matching [freqQuery].
  /// e.g. "121.5" → all airports with a 121.500 MHz entry (GUARD).
  Future<List<Airport>> searchAirportsByFrequency(String freqQuery,
      {int limit = 50}) async {
    final d = await db;
    final pattern = '${freqQuery.trim()}%';
    final rows = await d.rawQuery('''
      SELECT DISTINCT airports.*
      FROM airports
      JOIN frequencies ON frequencies.airport_ref = airports.id
      WHERE CAST(frequencies.frequency_mhz AS TEXT) LIKE ?
      ORDER BY airports.name ASC
      LIMIT ?
    ''', [pattern, limit]);
    return rows.map(Airport.fromMap).toList();
  }

  // ── Nearby ────────────────────────────────────────────────────────────────

  Future<List<(Airport, double)>> getNearbyAirports(
    double lat,
    double lon, {
    double radiusKm = 50,
    List<String>? types,
    int limit = 100,
    bool requireFrequencies = false,
  }) async {
    final d = await db;
    final latDelta = radiusKm / 111.0;
    final lonDelta = radiusKm / (111.0 * max(cos(lat * pi / 180), 0.01));

    final typeFilter = types != null && types.isNotEmpty
        ? 'AND type IN (${types.map((_) => '?').join(',')})'
        : '';
    final freqFilter = requireFrequencies
        ? 'AND EXISTS (SELECT 1 FROM frequencies WHERE airport_ref = airports.id)'
        : '';
    final args = [
      lat - latDelta,
      lat + latDelta,
      lon - lonDelta,
      lon + lonDelta,
      if (types != null) ...types,
    ];

    final rows = await d.rawQuery('''
      SELECT * FROM airports
      WHERE latitude_deg BETWEEN ? AND ?
        AND longitude_deg BETWEEN ? AND ?
        $typeFilter
        $freqFilter
    ''', args);

    final airports = rows.map(Airport.fromMap).toList();
    final withDist = airports
        .map((a) => (a, a.distanceTo(lat, lon) ?? double.infinity))
        .where((t) => t.$2 <= radiusKm)
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));

    return withDist.take(limit).toList();
  }

  // ── Frequencies ───────────────────────────────────────────────────────────

  Future<List<Frequency>> getFrequencies(int airportId) async {
    final d = await db;
    final rows = await d.query('frequencies',
        where: 'airport_ref = ?', whereArgs: [airportId]);
    final freqs = rows.map(Frequency.fromMap).toList()
      ..sort((a, b) => a.sortWeight.compareTo(b.sortWeight));
    return freqs;
  }

  // ── Runways ───────────────────────────────────────────────────────────────

  Future<List<Runway>> getRunways(String airportIdent) async {
    final d = await db;
    final rows = await d.query('runways',
        where: 'airport_ident = ? AND closed = 0',
        whereArgs: [airportIdent],
        orderBy: 'le_ident ASC');
    return rows.map(Runway.fromMap).toList();
  }

  // ── Navaids ───────────────────────────────────────────────────────────────

  Future<List<Navaid>> getNavaids(String airportIdent) async {
    final d = await db;
    final rows = await d.query('navaids',
        where: 'associated_airport = ?', whereArgs: [airportIdent]);
    final navaids = rows.map(Navaid.fromMap).toList()
      ..sort((a, b) => a.sortWeight.compareTo(b.sortWeight));
    return navaids;
  }

  // ── Single lookup ─────────────────────────────────────────────────────────

  Future<Airport?> getAirportByIdent(String ident) async {
    final d = await db;
    final rows = await d.query('airports',
        where: 'ident = ?', whereArgs: [ident], limit: 1);
    return rows.isEmpty ? null : Airport.fromMap(rows.first);
  }

  // ── Favourites ────────────────────────────────────────────────────────────

  Future<List<Airport>> getFavourites() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT a.* FROM airports a
      INNER JOIN favourites f ON a.ident = f.ident
      ORDER BY f.added_at DESC
    ''');
    return rows.map(Airport.fromMap).toList();
  }

  Future<bool> isFavourite(String ident) async {
    final d = await db;
    final rows = await d.query('favourites',
        where: 'ident = ?', whereArgs: [ident], limit: 1);
    return rows.isNotEmpty;
  }

  Future<List<String>> getRunwayDesignatorsForAirport(String ident) async {
    final runways = await getRunways(ident);
    if (runways.isEmpty) return [];
    final r = runways[Random().nextInt(runways.length)];
    return [r.leIdent, r.heIdent].where((s) => s.isNotEmpty).toList();
  }

  Future<bool> toggleFavourite(String ident) async {
    final d = await db;
    final existing = await d.query('favourites',
        where: 'ident = ?', whereArgs: [ident], limit: 1);
    if (existing.isEmpty) {
      await d.insert('favourites', {
        'ident': ident,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } else {
      await d.delete('favourites', where: 'ident = ?', whereArgs: [ident]);
      return false;
    }
  }
}
