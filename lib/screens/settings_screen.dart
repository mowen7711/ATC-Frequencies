import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../providers/app_provider.dart';
import '../providers/theme_provider.dart';
import '../services/background_service.dart';
import '../services/frequency_notification_service.dart';
import '../widgets/bug_report_sheet.dart';
import '../widgets/disclaimer_dialog.dart' show kDisclaimerText;
import '../widgets/whats_new_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Nearby monitor state ───────────────────────────────────────────────────
  bool _bgEnabled = false;
  bool _bgLoading = false;

  // ── Frequency display notification state ──────────────────────────────────
  bool _freqEnabled    = false;
  bool _freqLoading    = false;
  Airport? _freqAirport;

  // ── App version ───────────────────────────────────────────────────────────
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = 'v${info.version}');
  }

  Future<void> _loadState() async {
    final running = await BackgroundService.isRunning;
    final freqEnabled = await FrequencyNotificationService.instance.isEnabled;
    final freqAirport = await FrequencyNotificationService.instance.selectedAirport;
    if (mounted) {
      setState(() {
        _bgEnabled   = running;
        _freqEnabled = freqEnabled;
        _freqAirport = freqAirport;
      });
    }
  }

  // ── Nearby toggle ──────────────────────────────────────────────────────────

  Future<void> _toggleBackground(bool value) async {
    if (value) {
      // Google Play policy: show prominent disclosure before requesting
      // location permission for the background monitor.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.col.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Background Location',
              style: TextStyle(
                  color: context.col.textPrimary,
                  fontWeight: FontWeight.w700)),
          content: Text(
            'The nearby airport monitor runs as a foreground service and '
            'accesses your location in the background to keep the notification '
            'up to date.\n\n'
            'Your location is used only on this device — it is never sent '
            'to any server.',
            style:
                TextStyle(color: context.col.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: context.col.textMuted)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: context.col.accent,
                  foregroundColor: Colors.black),
              child: const Text('Continue',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _bgLoading = true);
    if (value) {
      await BackgroundService.start();
    } else {
      await BackgroundService.stop();
    }
    final running = await BackgroundService.isRunning;
    if (mounted) setState(() { _bgEnabled = running; _bgLoading = false; });
  }

  // ── Frequency notification toggle ─────────────────────────────────────────

  Future<void> _toggleFreqNotif(bool value) async {
    if (value) {
      // Need an airport selected before enabling
      final airport = _freqAirport ??
          await FrequencyNotificationService.instance.selectedAirport;
      if (airport == null) {
        // Prompt to pick one
        if (mounted) await _pickFreqAirport();
        return;
      }
      setState(() => _freqLoading = true);
      await FrequencyNotificationService.instance.enable(airport.ident);
    } else {
      setState(() => _freqLoading = true);
      await FrequencyNotificationService.instance.disable();
    }
    final enabled = await FrequencyNotificationService.instance.isEnabled;
    if (mounted) setState(() { _freqEnabled = enabled; _freqLoading = false; });
  }

  Future<void> _pickFreqAirport() async {
    final airport = await showModalBottomSheet<Airport>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AirportPicker(),
    );
    if (airport == null) return;

    setState(() { _freqAirport = airport; _freqLoading = true; });
    await FrequencyNotificationService.instance.enable(airport.ident);
    final enabled = await FrequencyNotificationService.instance.isEnabled;
    if (mounted) setState(() { _freqEnabled = enabled; _freqLoading = false; });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.col.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.palette_outlined,
                          color: context.col.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Theme',
                          style: TextStyle(
                              color: context.col.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return Row(
                      children: [
                        Expanded(
                          child: _ThemeButton(
                            label: 'System',
                            icon: Icons.brightness_auto_rounded,
                            selected: themeProvider.themeMode == ThemeMode.system,
                            onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ThemeButton(
                            label: 'Light',
                            icon: Icons.light_mode_rounded,
                            selected: themeProvider.themeMode == ThemeMode.light,
                            onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ThemeButton(
                            label: 'Dark',
                            icon: Icons.dark_mode_rounded,
                            selected: themeProvider.themeMode == ThemeMode.dark,
                            onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Nearby airport monitor ─────────────────────────────────────
          _SectionHeader('Background Monitoring'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _bgEnabled
                            ? context.col.accent.withAlpha(25)
                            : context.col.textMuted.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.radar_rounded,
                          color: _bgEnabled ? context.col.accent : context.col.textMuted, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nearby Airport Monitor',
                              style: TextStyle(
                                  color: context.col.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                            'Persistent notification showing the nearest airports. Updates every 5 minutes.',
                            style: TextStyle(
                                color: context.col.textSecondary, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _bgLoading
                        ? SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: context.col.accent))
                        : Switch(
                            value: _bgEnabled,
                            onChanged: _toggleBackground,
                            activeThumbColor: context.col.accent,
                          ),
                  ],
                ),
                if (_bgEnabled) ...[
                  const SizedBox(height: 12),
                  _ActiveBadge('Active — pull down your notification shade to see nearby airports.'),
                ],
              ],
            ),
          ),
          const _InfoTile(
            icon: Icons.info_outline_rounded,
            text: 'Android requires a visible notification to access GPS in the background. '
                'This is by design — it keeps you in control.',
          ),

          // ── Airport frequency display ──────────────────────────────────
          _SectionHeader('Airport Frequency Display'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _freqEnabled
                            ? context.col.accent.withAlpha(25)
                            : context.col.textMuted.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.speaker_notes_rounded,
                          color: _freqEnabled ? context.col.accent : context.col.textMuted, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Frequencies Notification',
                              style: TextStyle(
                                  color: context.col.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                            'Pin all ATC frequencies for an airport in your notification shade. '
                            'Expand the notification to see the full list.',
                            style: TextStyle(
                                color: context.col.textSecondary, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _freqLoading
                        ? SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: context.col.accent))
                        : Switch(
                            value: _freqEnabled,
                            onChanged: _toggleFreqNotif,
                            activeThumbColor: context.col.accent,
                          ),
                  ],
                ),

                // Selected airport row
                if (_freqAirport != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.col.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.col.accent.withAlpha(100)),
                        ),
                        child: Text(_freqAirport!.displayCode,
                            style: TextStyle(
                                color: context.col.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_freqAirport!.name,
                            style: TextStyle(
                                color: context.col.textPrimary, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      TextButton(
                        onPressed: _pickFreqAirport,
                        style: TextButton.styleFrom(
                          foregroundColor: context.col.accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Change', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ] else if (!_freqEnabled) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickFreqAirport,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.col.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: context.col.accent.withAlpha(60), style: BorderStyle.solid),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: context.col.accent, size: 16),
                          const SizedBox(width: 8),
                          Text('Select an airport',
                              style: TextStyle(color: context.col.accent, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],

                if (_freqEnabled) ...[
                  const SizedBox(height: 12),
                  _ActiveBadge(
                      'Active — pull down your notification shade and expand to see all frequencies.'),
                ],
              ],
            ),
          ),
          const _InfoTile(
            icon: Icons.info_outline_rounded,
            text: 'Expand the notification by long-pressing or swiping down on it to '
                'reveal the full frequency list. The notification is restored automatically '
                'when you reopen the app.',
          ),

          // ── Location ──────────────────────────────────────────────────
          _SectionHeader('Location'),
          _Card(
            child: Column(
              children: [
                Consumer<AppProvider>(
                  builder: (context, provider, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.straighten_rounded,
                                color: context.col.accent, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Distance units',
                                  style: TextStyle(
                                      color: context.col.textPrimary,
                                      fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeButton(
                              label: 'Kilometres',
                              icon: Icons.straighten_rounded,
                              selected: provider.distanceUnit ==
                                  DistanceUnit.km,
                              onTap: () => provider
                                  .setDistanceUnit(DistanceUnit.km),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeButton(
                              label: 'Miles',
                              icon: Icons.straighten_rounded,
                              selected: provider.distanceUnit ==
                                  DistanceUnit.miles,
                              onTap: () => provider
                                  .setDistanceUnit(DistanceUnit.miles),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Consumer<AppProvider>(
                  builder: (context, provider, _) => _SettingRow(
                    icon: Icons.my_location_rounded,
                    label: 'Default search radius',
                    value: formatRadius(
                        kDefaultNearbyRadiusKm, provider.distanceUnit),
                  ),
                ),
              ],
            ),
          ),

          // ── Data ──────────────────────────────────────────────────────
          _SectionHeader('Airport Data'),
          _Card(
            child: Column(
              children: [
                const _SettingRow(
                  icon: Icons.public_rounded,
                  label: 'Data source',
                  value: 'OurAirports (CC0)',
                ),
                const Divider(height: 1),
                const _SettingRow(
                  icon: Icons.update_rounded,
                  label: 'Update frequency',
                  value: 'Weekly (background)',
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: () {
                    context.read<AppProvider>().forceRefresh();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: context.col.accent, size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text('Refresh data now',
                              style: TextStyle(
                                  color: context.col.accent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: context.col.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── About ─────────────────────────────────────────────────────
          _SectionHeader('About'),
          _Card(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.radio_rounded,
                  label: 'ATC Frequencies',
                  value: _version.isEmpty ? '—' : _version,
                ),
                const Divider(height: 1),
                const _SettingRow(
                  icon: Icons.language_rounded,
                  label: 'Coverage',
                  value: '~70,000 airports worldwide',
                ),
                const Divider(height: 1),
                const _SettingRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Frequencies',
                  value: '~90,000 ATC entries',
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: () async {
                    if (_version.isEmpty) return;
                    await maybeShowWhatsNew(
                      context,
                      _version.replaceFirst('v', ''),
                      forceShow: true,
                    );
                  },
                  child: const _SettingRow(
                    icon: Icons.new_releases_rounded,
                    label: "What's New",
                    value: 'View release notes',
                  ),
                ),
              ],
            ),
          ),

          // ── How we use your data ───────────────────────────────────────
          _SectionHeader('How We Use Your Data'),
          const _InfoTile(
            icon: Icons.shield_outlined,
            text: 'We deliberately keep this to the minimum useful for keeping the app running well. Nothing below is tied to your name, account, or device — only to a random anonymous ID that resets if you reinstall.',
          ),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DataRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Anonymous install ID',
                  detail: 'A random UUID generated on first launch. Cannot identify you — it has no link to your name, account, or device, and isn\'t shared between installs.',
                ),
                const Divider(height: 1),
                const _DataRow(
                  icon: Icons.flight_rounded,
                  label: 'Which airports are viewed',
                  detail: 'We log "EGLL was viewed" — never who viewed it. This is purely so we can see which airports are most popular and prioritise building features for them (e.g. better local data, viewing spots) — not to track your activity or movements.',
                ),
                const Divider(height: 1),
                const _DataRow(
                  icon: Icons.timer_outlined,
                  label: 'Session length & app opens, with app version and language',
                  detail: 'How long each session lasts and how often the app is opened, plus your app version and device language. Used to measure engagement and catch issues on older versions — not tied to anything else you do in the app.',
                ),
                const Divider(height: 1),
                const _DataRow(
                  icon: Icons.location_city_rounded,
                  label: 'Approximate country/city (from IP), on app open only',
                  detail: 'Cloudflare detects the rough location your internet connection is in, attached only to the app-open event above — never to which airports you view, frequencies you use, or anything else you do. Your IP address itself is never stored.',
                ),
                const Divider(height: 1),
                const _DataRow(
                  icon: Icons.bug_report_outlined,
                  label: 'Bug reports & crash details',
                  detail: 'Only when you choose to submit one — the description you type, plus your app version. Nothing is sent automatically.',
                ),
                const Divider(height: 1),
                const _DataRow(
                  icon: Icons.speed_rounded,
                  label: 'Data download performance',
                  detail: 'How long the worldwide airport data takes to download, and whether it succeeded. Used to spot slow connections or failures — no personal data involved.',
                ),
                const Divider(height: 1),
                const _DataRow(
                  icon: Icons.verified_user_outlined,
                  label: 'What we never collect',
                  detail: 'Your name, email, phone number, precise GPS location, contacts, photos, which individual frequencies you copy, which features you tap, or any identifiable information.',
                ),
              ],
            ),
          ),
          const _InfoTile(
            icon: Icons.storage_rounded,
            text: 'Data is stored securely in the EU (NeonDB) and processed via Cloudflare. It is never sold or shared with third parties.',
          ),

          // ── Found a problem ────────────────────────────────────────────
          _SectionHeader('Feedback'),
          _Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showBugReportSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.bug_report_rounded, color: context.col.accent, size: 20),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Found a problem?',
                              style: TextStyle(
                                  color: context.col.accent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('Report a bug anonymously',
                              style: TextStyle(color: context.col.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.col.textMuted, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const _InfoTile(
            icon: Icons.vibration_rounded,
            text: 'Tip: shake your phone at any time to report a problem instantly.',
          ),

          // ── Disclaimer ────────────────────────────────────────────────
          _SectionHeader('Disclaimer'),
          _Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: context.col.accent, size: 18),
                      const SizedBox(width: 8),
                      Text('For Recreational Use Only',
                          style: TextStyle(
                              color: context.col.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    kDisclaimerText,
                    style: TextStyle(
                        color: context.col.textSecondary,
                        fontSize: 12,
                        height: 1.55),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Theme toggle button ───────────────────────────────────────────────────────

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? col.accent.withAlpha(25) : col.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? col.accent : col.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? col.accent : col.textMuted),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? col.accent : col.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ── Active state badge ────────────────────────────────────────────────────────

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.col.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.col.accent.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: context.col.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: context.col.accent, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Airport picker bottom sheet ───────────────────────────────────────────────

class _AirportPicker extends StatefulWidget {
  @override
  State<_AirportPicker> createState() => _AirportPickerState();
}

class _AirportPickerState extends State<_AirportPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: context.col.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Choose Airport for Frequencies',
                style: TextStyle(
                    color: context.col.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'The full frequency list will be pinned in your notification shade.',
              style: TextStyle(color: context.col.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: context.col.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name, ICAO or IATA…',
                prefixIcon: Icon(Icons.search_rounded, color: context.col.textMuted),
              ),
              onChanged: (q) => context.read<AppProvider>().search(q),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<AppProvider>(
                builder: (context, provider, _) {
                  if (provider.searching) {
                    return Center(
                        child: CircularProgressIndicator(color: context.col.accent));
                  }
                  if (provider.searchResults.isEmpty &&
                      _controller.text.isNotEmpty) {
                    return Center(
                        child: Text('No airports found',
                            style: TextStyle(color: context.col.textSecondary)));
                  }
                  return ListView.separated(
                    itemCount: provider.searchResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final airport = provider.searchResults[i];
                      return ListTile(
                        tileColor: context.col.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.col.card,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(airport.displayCode,
                              style: TextStyle(
                                  color: context.col.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  fontFamily: 'monospace')),
                        ),
                        title: Text(airport.name,
                            style: TextStyle(
                                color: context.col.textPrimary, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(airport.locationString,
                            style: TextStyle(
                                color: context.col.textSecondary, fontSize: 12)),
                        trailing: Icon(Icons.speaker_notes_rounded,
                            color: context.col.accent, size: 18),
                        onTap: () {
                          provider.clearSearch();
                          Navigator.pop(context, airport);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Shared reusable widgets ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: context.col.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.col.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.border, width: 0.5),
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: context.col.textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: context.col.textPrimary, fontSize: 14))),
          Text(value,
              style: TextStyle(color: context.col.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    required this.detail,
    this.isNegative = false,
  });
  final IconData icon;
  final String label;
  final String detail;
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    final color = isNegative ? Colors.redAccent : context.col.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: isNegative ? Colors.redAccent : context.col.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(detail,
                    style: TextStyle(
                        color: context.col.textSecondary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: context.col.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: context.col.textMuted, fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
