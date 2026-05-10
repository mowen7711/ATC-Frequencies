import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'database_service.dart';
import 'location_service.dart';

const String kBgServiceEnabledKey = 'bg_service_enabled';
const String kBgUpdateIntervalKey = 'bg_update_interval_ms';
const int kBgDefaultIntervalMs = 5 * 60 * 1000; // 5 minutes

// ── Top-level entry point (required — runs in background isolate) ─────────────
@pragma('vm:entry-point')
void backgroundServiceEntryPoint() {
  FlutterForegroundTask.setTaskHandler(NearbyAirportsTaskHandler());
}

// ── Task handler — runs in background isolate ────────────────────────────────

class NearbyAirportsTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // DB initialises itself on first access — works in any isolate
    await DatabaseService.instance.db;
    // Run an immediate update so the notification shows real data straight away
    // rather than sitting on "Starting…" for the full 5-minute interval.
    await _update();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) => _update();

  Future<void> _update() async {
    final location = await LocationService.instance.getCurrentLocation();
    if (!location.isSuccess) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Nearby Airports',
        notificationText: 'Waiting for location…',
      );
      return;
    }

    final nearby = await DatabaseService.instance.getNearbyAirports(
      location.latitude!,
      location.longitude!,
      radiusKm: kDefaultNearbyRadiusKm,
      types: kDefaultAirportTypes,
      limit: 5,
    );

    if (nearby.isEmpty) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Nearby Airports',
        notificationText: 'No airports within ${kDefaultNearbyRadiusKm.toInt()} km',
      );
    } else {
      final summary = nearby
          .take(3)
          .map((t) => '${t.$1.displayCode} ${t.$2.toStringAsFixed(0)}km')
          .join('  ·  ');
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Nearby Airports',
        notificationText: summary,
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationPressed() {
    // Bring app to foreground and open the Nearby tab
    FlutterForegroundTask.launchApp('/nearby');
  }
}

// ── Public API (call from main isolate) ───────────────────────────────────────

class BackgroundService {
  BackgroundService._();

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'atc_nearby_airports',
        channelName: 'Nearby Airports',
        channelDescription:
            'Persistent notification showing airports near your current location.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(kBgDefaultIntervalMs),
        autoRunOnBoot: false,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> get isRunning =>
      Future.value(FlutterForegroundTask.isRunningService);

  static Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBgServiceEnabledKey) ?? false;
  }

  static Future<void> start() async {
    // Android 13+ (API 33) requires POST_NOTIFICATIONS at runtime
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      final result = await FlutterForegroundTask.requestNotificationPermission();
      if (result != NotificationPermission.granted) return;
    }

    // Request location permission before starting service
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: 'Nearby Airports',
      notificationText: 'Starting…',
      callback: backgroundServiceEntryPoint,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBgServiceEnabledKey, true);
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBgServiceEnabledKey, false);
  }

  static Future<void> toggle() async {
    if (await isRunning) {
      await stop();
    } else {
      await start();
    }
  }

  /// Call once from main() to resume service if user had it on before.
  static Future<void> restoreIfEnabled() async {
    if (await isEnabled && !(await isRunning)) {
      await start();
    }
  }
}
