import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Configuration ─────────────────────────────────────────────────────────────
// Set this to your deployed Cloudflare Worker URL once it is live.
// Leave empty to disable metrics silently — safe for dev/debug builds.
// No credentials are stored here; the Worker holds the NeonDB secret.
const String _kRelayUrl = 'https://atc-freq-metrics.mark-78f.workers.dev';

const String _kInstallIdKey = 'metrics_install_id';

/// Anonymous, privacy-respecting metrics service.
///
/// Events are buffered in memory and flushed every 30 seconds or when the
/// app backgrounds. POSTs JSON to a Cloudflare Worker relay which writes to
/// NeonDB — no credentials are ever stored in the app or APK.
///
/// Nothing PII is collected: only a random anonymous install UUID that cannot
/// be linked to a real person, plus the device locale tag. Covers app opens
/// (country-level location only, never per-feature), airport views and
/// feature usage (aggregate, anonymous — never tied to who used what), and
/// crash/bug reports + download performance. See Settings → How We Use Your
/// Data and docs/privacy-policy.html for the user-facing disclosure.
class MetricsService {
  MetricsService._();
  static final MetricsService instance = MetricsService._();

  String? _installId;
  String _appVersion = '0.0.0';
  String _locale = 'unknown';
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;
  DateTime? _sessionStart;

  bool get _enabled => _kRelayUrl.isNotEmpty && !kDebugMode;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    if (!_enabled) return;

    final prefs = await SharedPreferences.getInstance();

    // Persist a random UUID as the install ID. Not a device ID — purely random,
    // no link to any identifiable information.
    _installId = prefs.getString(_kInstallIdKey);
    if (_installId == null) {
      _installId = _uuid();
      await prefs.setString(_kInstallIdKey, _installId!);
    }

    final info = await PackageInfo.fromPlatform();
    _appVersion = info.version;

    // Locale from the platform gives approximate region with no GPS or PII
    _locale = PlatformDispatcher.instance.locale.toLanguageTag();

    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
  }

  // ── Public event API ──────────────────────────────────────────────────────

  /// App launched or returned to foreground.
  void trackAppOpen() {
    _sessionStart = DateTime.now();
    _record('app_event',
        tags: {'event': 'app_open'},
        fields: {'version': _appVersion, 'locale': _locale});
  }

  /// App sent to background — records session duration.
  void trackAppClose() {
    if (_sessionStart != null) {
      final ms = DateTime.now().difference(_sessionStart!).inMilliseconds;
      _record('app_event',
          tags: {'event': 'session_end'},
          fields: {'duration_ms': ms});
      _sessionStart = null;
    }
    _flush(); // send immediately so data isn't lost on process kill
  }

  /// User opened an airport detail page. Anonymous and aggregate-only — used
  /// to see which airports are most viewed so we can prioritise airport-
  /// specific features, not to track individual users' behaviour.
  void trackAirportView(String icao, String type) {
    _record('airport_view', tags: {'icao': icao, 'type': type});
  }

  /// A frequency was copied to clipboard.
  void trackFreqCopy(String freqType) {
    _record('feature_use',
        tags: {'feature': 'freq_copy', 'freq_type': freqType});
  }

  /// The SDR listen button was tapped.
  void trackSdrLaunch(double frequencyMhz, {required bool driverInstalled}) {
    _record('feature_use', tags: {
      'feature': 'sdr_launch',
      'driver_installed': driverInstalled.toString(),
    }, fields: {
      'freq_mhz': frequencyMhz,
    });
  }

  /// Generic named feature (add_favourite, set_home, etc.).
  void trackFeature(String featureName) {
    _record('feature_use', tags: {'feature': featureName});
  }

  /// A download stage completed.
  void trackDownloadStage(
    String stage, {
    required int durationMs,
    required bool success,
    int? bytes,
  }) {
    _record('download_stage',
        tags: {'stage': stage},
        fields: {
          'duration_ms': durationMs,
          'success': success,
          if (bytes != null) 'bytes': bytes,
        });
  }

  /// Full data download completed.
  void trackDownloadComplete({required int totalMs}) {
    _record('download_complete', fields: {'total_ms': totalMs});
  }

  /// User-submitted bug report.
  void trackBugReport({required String description, String? context}) {
    _record('bug_report', fields: {
      'description': description,
      if (context != null && context.isNotEmpty) 'context': context,
      'app_version': _appVersion,
    });
    _flush(); // send immediately
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _record(
    String measurement, {
    Map<String, dynamic> tags = const {},
    Map<String, dynamic> fields = const {},
  }) {
    if (!_enabled || _installId == null) return;
    _buffer.add({
      'measurement': measurement,
      'install_id': _installId,
      'tags': tags,
      'fields': fields,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    final events = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      await http.post(
        Uri.parse(_kRelayUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'events': events}),
      );
    } catch (_) {
      // Never crash the app over metrics — silently drop on failure
    }
  }

  /// Random UUID v4.
  String _uuid() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${b.sublist(0, 4).map(h).join()}-'
        '${b.sublist(4, 6).map(h).join()}-'
        '${b.sublist(6, 8).map(h).join()}-'
        '${b.sublist(8, 10).map(h).join()}-'
        '${b.sublist(10).map(h).join()}';
  }
}
