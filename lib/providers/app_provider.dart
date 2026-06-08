import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../models/frequency.dart';
import '../services/database_service.dart';
import '../services/data_service.dart';
import '../services/location_service.dart';

const String _kHomeAirportKey    = 'home_airport_ident';
const String _kDistanceUnitKey   = 'distance_unit';

enum AppState { loading, ready, error }

class AppProvider extends ChangeNotifier {
  // ── Initialisation state ─────────────────────────────────────────────────
  AppState _state = AppState.loading;
  String _loadingStatus = 'Starting…';
  double _loadingProgress = 0.0;
  String? _globalError;

  AppState get state => _state;
  String get loadingStatus => _loadingStatus;
  double get loadingProgress => _loadingProgress;
  String? get globalError => _globalError;

  // ── Background update banner ──────────────────────────────────────────────
  bool _backgroundUpdating = false;
  bool get backgroundUpdating => _backgroundUpdating;

  // ── Loading screen extras ─────────────────────────────────────────────────
  List<String> _runwayLabels = [];
  List<String> get runwayLabels => _runwayLabels;

  DateTime? _downloadStart;
  String? get estimatedTimeRemaining {
    if (_downloadStart == null || _loadingProgress <= 0.05) return null;
    final elapsed =
        DateTime.now().difference(_downloadStart!).inSeconds.toDouble();
    if (elapsed < 3) return null;
    final totalEst = elapsed / _loadingProgress;
    final remaining = (totalEst - elapsed).ceil();
    if (remaining <= 0) return null;
    return remaining < 60 ? '~${remaining}s remaining' : '~${(remaining / 60).ceil()}m remaining';
  }

  // ── Distance unit ─────────────────────────────────────────────────────────
  DistanceUnit _distanceUnit = DistanceUnit.km;
  DistanceUnit get distanceUnit => _distanceUnit;

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    _distanceUnit = unit;
    // Snap the current radius to the nearest value in the new unit's array
    final radii = unit == DistanceUnit.miles ? kRadiiMiles : kRadiiKm;
    _nearbyRadius = radii.reduce((a, b) =>
        (a - _nearbyRadius).abs() < (b - _nearbyRadius).abs() ? a : b);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDistanceUnitKey, unit.name);
  }

  // ── Home airport ─────────────────────────────────────────────────────────
  Airport? _homeAirport;
  Airport? get homeAirport => _homeAirport;

  // ── Favourites ───────────────────────────────────────────────────────────
  List<Airport> _favourites = [];
  List<Airport> get favourites => _favourites;

  // ── Search ────────────────────────────────────────────────────────────────
  List<Airport> _searchResults = [];
  bool _searching = false;
  String _lastQuery = '';
  List<Airport> get searchResults => _searchResults;
  bool get searching => _searching;

  // ── Nearby ────────────────────────────────────────────────────────────────
  List<(Airport, double)> _nearbyAirports = [];
  bool _loadingNearby = false;
  String? _nearbyError;
  double _nearbyLat = 0;
  double _nearbyLon = 0;
  double _nearbyRadius = kDefaultNearbyRadiusKm;
  List<String> _nearbyTypes = kDefaultAirportTypes;

  List<(Airport, double)> get nearbyAirports => _nearbyAirports;
  bool get loadingNearby => _loadingNearby;
  String? get nearbyError => _nearbyError;
  double get nearbyLat => _nearbyLat;
  double get nearbyLon => _nearbyLon;
  double get nearbyRadius => _nearbyRadius;
  List<String> get nearbyTypes => _nearbyTypes;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _downloadStart = DateTime.now();
    // Load distance unit preference early so UI is correct immediately
    final prefs = await SharedPreferences.getInstance();
    final unitName = prefs.getString(_kDistanceUnitKey);
    if (unitName != null) {
      _distanceUnit = DistanceUnit.values.firstWhere(
          (u) => u.name == unitName, orElse: () => DistanceUnit.km);
    }
    try {
      await DataService.instance.ensureData(
        onProgress: (status, progress) {
          _loadingStatus = status;
          _loadingProgress = progress;
          notifyListeners();
        },
      );
      await loadFavourites();
      await loadHomeAirport();
      // Small delay so the loading animation settles before swapping widgets
      await Future.delayed(const Duration(milliseconds: 400));
      _state = AppState.ready;
    } catch (e) {
      _state = AppState.error;
      _globalError = e.toString();
    }
    notifyListeners();
  }

  Future<void> forceRefresh() async {
    // Capture home airport runway labels before DB is cleared
    final prefs = await SharedPreferences.getInstance();
    final homeIdent = prefs.getString(_kHomeAirportKey);
    _runwayLabels = homeIdent != null
        ? await DatabaseService.instance
            .getRunwayDesignatorsForAirport(homeIdent)
        : [];
    _downloadStart = DateTime.now();
    _state = AppState.loading;
    _loadingProgress = 0;
    _loadingStatus = 'Refreshing data…';
    notifyListeners();
    try {
      await DataService.instance.forceRefresh(
        onProgress: (status, progress) {
          _loadingStatus = status;
          _loadingProgress = progress;
          notifyListeners();
        },
      );
      await loadFavourites();
      await Future.delayed(const Duration(milliseconds: 400));
      _state = AppState.ready;
    } catch (e) {
      _state = AppState.error;
      _globalError = e.toString();
    }
    notifyListeners();
  }

  // ── Home airport ──────────────────────────────────────────────────────────

  Future<void> loadHomeAirport() async {
    final prefs = await SharedPreferences.getInstance();
    final ident = prefs.getString(_kHomeAirportKey);
    if (ident != null) {
      _homeAirport = await DatabaseService.instance.getAirportByIdent(ident);
    }
    notifyListeners();
  }

  Future<void> setHomeAirport(String ident) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHomeAirportKey, ident);
    _homeAirport = await DatabaseService.instance.getAirportByIdent(ident);
    notifyListeners();
  }

  Future<void> clearHomeAirport() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHomeAirportKey);
    _homeAirport = null;
    notifyListeners();
  }

  bool get isHomeAirport =>
      _homeAirport != null;

  bool isHome(String ident) => _homeAirport?.ident == ident;

  // ── Favourites ────────────────────────────────────────────────────────────

  Future<void> loadFavourites() async {
    _favourites = await DatabaseService.instance.getFavourites();
    notifyListeners();
  }

  Future<bool> toggleFavourite(String ident) async {
    final isFav = await DatabaseService.instance.toggleFavourite(ident);
    await loadFavourites();
    return isFav;
  }

  Future<bool> isFavourite(String ident) =>
      DatabaseService.instance.isFavourite(ident);

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> search(String query) async {
    _lastQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      _searching = false;
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    final results = await DatabaseService.instance
        .searchAirports(query, limit: 60, types: kDefaultAirportTypes);
    if (_lastQuery == query) {
      _searchResults = results;
      _searching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _searching = false;
    _lastQuery = '';
    notifyListeners();
  }

  // ── Nearby ────────────────────────────────────────────────────────────────

  Future<void> findNearby() async {
    _nearbyError = null;
    _loadingNearby = true;
    _nearbyAirports = [];
    notifyListeners();

    final result = await LocationService.instance.getCurrentLocation();
    if (!result.isSuccess) {
      _nearbyError = result.error;
      _loadingNearby = false;
      notifyListeners();
      return;
    }

    _nearbyLat = result.latitude!;
    _nearbyLon = result.longitude!;
    await _loadNearbyWithCurrentLocation();
  }

  Future<void> updateNearbyRadius(double km) async {
    _nearbyRadius = km;
    notifyListeners();
    if (_nearbyLat != 0 || _nearbyLon != 0) {
      await _loadNearbyWithCurrentLocation();
    }
  }

  Future<void> updateNearbyTypes(List<String> types) async {
    _nearbyTypes = types;
    notifyListeners();
    if (_nearbyLat != 0 || _nearbyLon != 0) {
      await _loadNearbyWithCurrentLocation();
    }
  }

  Future<void> _loadNearbyWithCurrentLocation() async {
    _loadingNearby = true;
    notifyListeners();
    _nearbyAirports = await DatabaseService.instance.getNearbyAirports(
      _nearbyLat,
      _nearbyLon,
      radiusKm: _nearbyRadius,
      types: _nearbyTypes,
    );
    _loadingNearby = false;
    notifyListeners();
  }

  // ── Frequencies ───────────────────────────────────────────────────────────

  Future<List<Frequency>> getFrequencies(int airportId) =>
      DatabaseService.instance.getFrequencies(airportId);
}
