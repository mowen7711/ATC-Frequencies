import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches SDR Touch pre-connected to the RTL-SDR Driver.
///
/// SDR Touch has no frequency-tuning intent API — it cannot be told which
/// frequency to tune to from outside. What we CAN do is:
///   1. Fire the iqsrc:// intent at the driver to start its TCP server
///      pre-configured at the requested frequency.
///   2. Bring SDR Touch to the foreground so the user is ready to listen.
///
/// SDR Touch will then connect to the driver server automatically.
class SdrService {
  SdrService._();

  static const _sdrTouchPackage  = 'marto.androsdr2';
  static const _sdrDriverPackage = 'marto.rtl_tcp_andro';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_sdrDriverPackage';

  static String _iqsrcData(double frequencyMhz) {
    final freqHz = (frequencyMhz * 1000000).round();
    return 'iqsrc://-a 127.0.0.1 -p 1234 -s 1024000 -f $freqHz';
  }

  /// Launches SDR Touch + driver tuned to [frequencyMhz].
  /// Returns true if at least the driver was started.
  static Future<bool> launchAtFrequency(double frequencyMhz) async {
    final data = _iqsrcData(frequencyMhz);
    bool driverStarted = false;

    // Step 1: start RTL-SDR Driver server at the requested frequency
    try {
      await AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: data,
        package: _sdrDriverPackage,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
      driverStarted = true;
    } catch (_) {}

    // Step 2: bring SDR Touch to the foreground via its LAUNCHER activity
    try {
      await AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: _sdrTouchPackage,
        componentName: 'marto.androsdr2.SDRTouchMain',
        flags: <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
        ],
      ).launch();
      return true;
    } catch (_) {}

    return driverStarted;
  }

  /// Opens the RTL-SDR Driver on the Play Store.
  static Future<void> openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
