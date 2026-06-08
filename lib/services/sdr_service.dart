import 'package:url_launcher/url_launcher.dart';

/// Launches an RTL-SDR compatible driver app (e.g. marto.rtl_tcp_andro)
/// tuned to the given frequency using the iqsrc:// intent protocol.
///
/// Compatible with SDR Touch, RF Analyzer, and any app that implements the
/// open rtl_tcp_andro driver API (GPL-2, no commercial licence required).
class SdrService {
  SdrService._();

  static const _sdrDriverPackage = 'marto.rtl_tcp_andro';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_sdrDriverPackage';

  static Uri _buildUri(double frequencyMhz) {
    final freqHz = (frequencyMhz * 1000000).round();
    // -a  bind address
    // -p  TCP port the driver listens on
    // -s  IQ sample rate (1.024 MHz is enough for airband AM)
    // -f  initial centre frequency in Hz
    return Uri.parse(
        'iqsrc://-a 127.0.0.1 -p 1234 -s 1024000 -f $freqHz');
  }

  /// Returns true if an SDR driver app is installed and can handle iqsrc://.
  static Future<bool> isAvailable() async {
    try {
      return await canLaunchUrl(_buildUri(121.5));
    } catch (_) {
      return false;
    }
  }

  /// Launches the SDR driver tuned to [frequencyMhz] MHz.
  /// Returns false if no compatible driver is installed.
  static Future<bool> launchAtFrequency(double frequencyMhz) async {
    final uri = _buildUri(frequencyMhz);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens the RTL-SDR driver on the Play Store.
  static Future<void> openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
