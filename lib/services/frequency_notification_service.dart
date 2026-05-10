import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/airport.dart';
import '../models/frequency.dart';
import 'database_service.dart';

const String _prefEnabled = 'freq_notif_enabled';
const String _prefIdent   = 'freq_notif_airport_ident';
const int    _notifId     = 2001;

class FrequencyNotificationService {
  FrequencyNotificationService._();
  static final FrequencyNotificationService instance =
      FrequencyNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // ── Init — call once from main() ──────────────────────────────────────────

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create the dedicated Android notification channel
    const channel = AndroidNotificationChannel(
      'atc_freq_display',
      'Airport Frequencies',
      description: 'Persistent notification showing ATC frequencies for a selected airport.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Restore if user had it on
    if (await isEnabled) {
      final ident = await selectedIdent;
      if (ident != null) await _post(ident);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  Future<String?> get selectedIdent async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefIdent);
  }

  Future<Airport?> get selectedAirport async {
    final ident = await selectedIdent;
    if (ident == null) return null;
    return DatabaseService.instance.getAirportByIdent(ident);
  }

  Future<void> enable(String airportIdent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, true);
    await prefs.setString(_prefIdent, airportIdent);
    await _post(airportIdent);
  }

  Future<void> changeAirport(String airportIdent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefIdent, airportIdent);
    if (await isEnabled) await _post(airportIdent);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
    await _plugin.cancel(_notifId);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _post(String ident) async {
    final airport = await DatabaseService.instance.getAirportByIdent(ident);
    if (airport == null) return;

    final freqs = await DatabaseService.instance.getFrequencies(airport.id);
    if (freqs.isEmpty) return;

    // Sort by type priority (ATIS, DEL, GND, TWR, DEP, APP, CTR, UNICOM, other)
    final sorted = List<Frequency>.from(freqs)
      ..sort((a, b) => a.sortWeight.compareTo(b.sortWeight));

    final title = '${airport.displayCode}  ·  ${airport.name}';

    // Collapsed single-line summary (most important types)
    final summary = sorted
        .take(3)
        .map((f) => '${f.type}  ${f.frequencyMhz.toStringAsFixed(3)}')
        .join('   ');

    // Expanded inbox-style lines — one per frequency
    final lines = sorted
        .map((f) =>
            '${f.type.padRight(8)}${f.frequencyMhz.toStringAsFixed(3)} MHz'
            '${f.description.isNotEmpty ? "  · ${f.description}" : ""}')
        .toList();

    final androidDetails = AndroidNotificationDetails(
      'atc_freq_display',
      'Airport Frequencies',
      channelDescription:
          'Persistent notification showing ATC frequencies for a selected airport.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,          // cannot be dismissed by swipe
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      styleInformation: InboxStyleInformation(
        lines,
        contentTitle: title,
        summaryText: '${sorted.length} frequencies',
      ),
    );

    await _plugin.show(
      _notifId,
      title,
      summary,
      NotificationDetails(android: androidDetails),
    );
  }
}
