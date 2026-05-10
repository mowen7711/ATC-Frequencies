import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/app_provider.dart';
import '../services/background_service.dart';
import 'bluetooth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _bgEnabled = false;
  bool _bgLoading = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final running = await BackgroundService.isRunning;
    if (mounted) setState(() => _bgEnabled = running);
  }

  Future<void> _toggleBackground(bool value) async {
    setState(() => _bgLoading = true);
    if (value) {
      await BackgroundService.start();
    } else {
      await BackgroundService.stop();
    }
    final running = await BackgroundService.isRunning;
    if (mounted) {
      setState(() {
        _bgEnabled = running;
        _bgLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Background monitoring ──────────────────────────────────────
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
                            ? kAccent.withAlpha(25)
                            : kTextMuted.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.radar_rounded,
                        color: _bgEnabled ? kAccent : kTextMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nearby Airport Monitor',
                              style: TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 3),
                          Text(
                            'Persistent notification showing the nearest airports. Updates every 5 minutes.',
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _bgLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kAccent),
                          )
                        : Switch(
                            value: _bgEnabled,
                            onChanged: _toggleBackground,
                            activeThumbColor: kAccent,
                          ),
                  ],
                ),
                if (_bgEnabled) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kAccent.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kAccent.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: kAccent, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Active — pull down your notification shade to see nearby airports.',
                            style: TextStyle(color: kAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          _InfoTile(
            icon: Icons.info_outline_rounded,
            text:
                'Android requires a visible notification to access GPS in the background. '
                'This is by design — it keeps you in control.',
          ),

          // ── Location ──────────────────────────────────────────────────
          _SectionHeader('Location'),
          _Card(
            child: _SettingRow(
              icon: Icons.my_location_rounded,
              label: 'Default search radius',
              value: '${kDefaultNearbyRadiusKm.toInt()} km',
            ),
          ),

          // ── Data ──────────────────────────────────────────────────────
          _SectionHeader('Airport Data'),
          _Card(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.public_rounded,
                  label: 'Data source',
                  value: 'OurAirports (CC0)',
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.update_rounded,
                  label: 'Update frequency',
                  value: 'Weekly (background)',
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: () {
                    context.read<AppProvider>().forceRefresh();
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.refresh_rounded,
                            color: kAccent, size: 20),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text('Refresh data now',
                              style: TextStyle(
                                  color: kAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: kTextMuted, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scanner control ───────────────────────────────────────────
          _SectionHeader('Scanner Control'),
          _Card(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BluetoothScreen()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_rounded, color: kTextMuted, size: 18),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Icom BLE Radio Control',
                          style: TextStyle(color: kTextPrimary, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7043).withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFF7043).withAlpha(120)),
                      ),
                      child: const Text('BETA',
                          style: TextStyle(
                              color: Color(0xFFFF7043),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: kTextMuted, size: 18),
                  ],
                ),
              ),
            ),
          ),
          _InfoTile(
            icon: Icons.info_outline_rounded,
            text: 'Tune your Icom radio directly from the app via Bluetooth Low Energy. '
                'Compatible with IC-R15, IC-R30, IC-705, IC-9700 and other BLE-capable Icom radios.',
          ),

          // ── About ─────────────────────────────────────────────────────
          _SectionHeader('About'),
          _Card(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.radio_rounded,
                  label: 'ATC Frequencies',
                  value: 'v1.0.0',
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.language_rounded,
                  label: 'Coverage',
                  value: '~70,000 airports worldwide',
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Frequencies',
                  value: '~90,000 ATC entries',
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: kAccent,
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
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder, width: 0.5),
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
          Icon(icon, color: kTextMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: kTextPrimary, fontSize: 14))),
          Text(value,
              style:
                  const TextStyle(color: kTextSecondary, fontSize: 13)),
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
          Icon(icon, size: 14, color: kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: kTextMuted, fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
