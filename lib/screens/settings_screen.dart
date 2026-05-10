import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../providers/app_provider.dart';
import '../services/background_service.dart';
import '../services/frequency_notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadState();
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
      backgroundColor: kSurface,
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
                            ? kAccent.withAlpha(25)
                            : kTextMuted.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.radar_rounded,
                          color: _bgEnabled ? kAccent : kTextMuted, size: 22),
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
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kAccent))
                        : Switch(
                            value: _bgEnabled,
                            onChanged: _toggleBackground,
                            activeThumbColor: kAccent,
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
                            ? kAccent.withAlpha(25)
                            : kTextMuted.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.speaker_notes_rounded,
                          color: _freqEnabled ? kAccent : kTextMuted, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Frequencies Notification',
                              style: TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 3),
                          Text(
                            'Pin all ATC frequencies for an airport in your notification shade. '
                            'Expand the notification to see the full list.',
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _freqLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kAccent))
                        : Switch(
                            value: _freqEnabled,
                            onChanged: _toggleFreqNotif,
                            activeThumbColor: kAccent,
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
                          color: kBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kAccent.withAlpha(100)),
                        ),
                        child: Text(_freqAirport!.displayCode,
                            style: const TextStyle(
                                color: kAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_freqAirport!.name,
                            style: const TextStyle(
                                color: kTextPrimary, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      TextButton(
                        onPressed: _pickFreqAirport,
                        style: TextButton.styleFrom(
                          foregroundColor: kAccent,
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
                        color: kBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: kAccent.withAlpha(60), style: BorderStyle.solid),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: kAccent, size: 16),
                          SizedBox(width: 8),
                          Text('Select an airport',
                              style: TextStyle(color: kAccent, fontSize: 13)),
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
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: kAccent, size: 20),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text('Refresh data now',
                              style: TextStyle(
                                  color: kAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: kTextMuted, size: 18),
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
                const _SettingRow(
                  icon: Icons.radio_rounded,
                  label: 'ATC Frequencies',
                  value: 'v1.0.0',
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
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
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
        color: kAccent.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccent.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: kAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: kAccent, fontSize: 12)),
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
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose Airport for Frequencies',
                style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'The full frequency list will be pinned in your notification shade.',
              style: TextStyle(color: kTextSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: kTextPrimary),
              decoration: const InputDecoration(
                hintText: 'Search by name, ICAO or IATA…',
                prefixIcon: Icon(Icons.search_rounded, color: kTextMuted),
              ),
              onChanged: (q) => context.read<AppProvider>().search(q),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<AppProvider>(
                builder: (context, provider, _) {
                  if (provider.searching) {
                    return const Center(
                        child: CircularProgressIndicator(color: kAccent));
                  }
                  if (provider.searchResults.isEmpty &&
                      _controller.text.isNotEmpty) {
                    return const Center(
                        child: Text('No airports found',
                            style: TextStyle(color: kTextSecondary)));
                  }
                  return ListView.separated(
                    itemCount: provider.searchResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final airport = provider.searchResults[i];
                      return ListTile(
                        tileColor: kBackground,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kCard,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(airport.displayCode,
                              style: const TextStyle(
                                  color: kAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  fontFamily: 'monospace')),
                        ),
                        title: Text(airport.name,
                            style: const TextStyle(
                                color: kTextPrimary, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(airport.locationString,
                            style: const TextStyle(
                                color: kTextSecondary, fontSize: 12)),
                        trailing: const Icon(Icons.speaker_notes_rounded,
                            color: kAccent, size: 18),
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
                  style: const TextStyle(color: kTextPrimary, fontSize: 14))),
          Text(value,
              style: const TextStyle(color: kTextSecondary, fontSize: 13)),
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
