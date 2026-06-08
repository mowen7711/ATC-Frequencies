import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../providers/app_provider.dart';
import '../screens/airport_detail_screen.dart' show kRestrictedCountries;
import '../services/metrics_service.dart';
import '../services/terrain_service.dart';

class SignalReceptionCard extends StatefulWidget {
  const SignalReceptionCard({super.key, required this.airport, this.distanceKm});
  final Airport airport;
  final double? distanceKm; // pre-computed if coming from Nearby screen

  @override
  State<SignalReceptionCard> createState() => _SignalReceptionCardState();
}

class _SignalReceptionCardState extends State<SignalReceptionCard> {
  SignalResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    setState(() { _loading = true; _error = null; });

    final pos = await TerrainService.instance.getAltitude();
    if (!mounted) return;

    if (pos == null) {
      setState(() { _loading = false; _error = 'Could not get GPS altitude.'; });
      return;
    }

    // Distance: use provided value or calculate from GPS
    double distKm = widget.distanceKm ?? 0;
    if (distKm == 0 && widget.airport.hasCoordinates) {
      distKm = widget.airport.distanceTo(pos.latitude, pos.longitude) ?? 0;
    }

    final result = TerrainService.instance.calculate(
      airportElevationFt: widget.airport.elevationFt,
      userAltitudeM: pos.altitude,
      distanceKm: distKm,
    );

    if (mounted) {
      setState(() { _result = result; _loading = false; });
      // Track when we show out-of-range results to measure LiveATC suggestion visibility
      if (result.quality == SignalQuality.outOfRange ||
          result.quality == SignalQuality.beyondRange) {
        MetricsService.instance.trackFeature('liveatc_suggested');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.col.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.signal_cellular_alt_rounded,
                    color: context.col.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Signal Reception',
                      style: TextStyle(
                          color: context.col.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                if (!_loading)
                  TextButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Recalculate',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: context.col.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Average handheld scanner · VHF airband · Line-of-sight model',
              style: TextStyle(color: context.col.textMuted, fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.col.accent),
                  ),
                  const SizedBox(width: 10),
                  Text('Getting GPS altitude…',
                      style: TextStyle(color: context.col.textSecondary, fontSize: 13)),
                ],
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(_error!,
                  style: TextStyle(color: context.col.textMuted, fontSize: 13)),
            )
          else if (_result != null)
            _ResultBody(result: _result!, airport: widget.airport),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.result, required this.airport});
  final SignalResult result;
  final Airport airport;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(result.quality, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Signal bar + label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (result.quality != SignalQuality.outOfRange &&
                            result.quality != SignalQuality.beyondRange) ...[
                          Text('${result.percent}%',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace')),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          child: Text(result.label,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    if (result.quality != SignalQuality.outOfRange &&
                        result.quality != SignalQuality.beyondRange) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: result.percent / 100,
                          backgroundColor: context.col.border,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Signal bars icon
              _SignalBars(quality: result.quality, color: color),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Explanation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(result.detail,
              style: TextStyle(
                  color: context.col.textSecondary, fontSize: 12, height: 1.5)),
        ),

        const SizedBox(height: 12),

        // Stats grid
        const Divider(height: 1),
        _StatRow(
          label: 'Distance to airport',
          value: formatDistance(result.distanceKm,
              context.read<AppProvider>().distanceUnit),
        ),
        const Divider(height: 1),
        _StatRow(
          label: 'Practical handheld range',
          value: '~${formatDistance(result.estimatedRangeKm, context.read<AppProvider>().distanceUnit)}',
        ),
        const Divider(height: 1),
        _StatRow(
          label: 'Your altitude (GPS)',
          value: '${result.userAltitudeM.toStringAsFixed(0)} m ASL',
        ),
        const Divider(height: 1),
        _StatRow(
          label: 'Airport elevation',
          value: '${result.airportElevationM.toStringAsFixed(0)} m ASL',
        ),
        const Divider(height: 1),
        _StatRow(
          label: 'Height difference',
          value: _heightStr(result.heightDifferenceM),
          valueColor: result.heightDifferenceM >= 0
              ? const Color(0xFF81C784)
              : const Color(0xFFEF9A9A),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'GPS altitude accuracy is ±10–30 m. Actual reception may vary with '
            'terrain, buildings, and antenna type.',
            style: TextStyle(color: context.col.textMuted, fontSize: 11, height: 1.4),
          ),
        ),

        // LiveATC link — humorous banner for out-of-range, subtle footer otherwise
        if (result.quality == SignalQuality.outOfRange ||
            result.quality == SignalQuality.beyondRange)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: _LiveAtcSuggestion(airport: airport),
          )
        else
          _LiveAtcFooter(airport: airport),

        const SizedBox(height: 4),
      ],
    );
  }

  String _heightStr(double m) {
    if (m >= 0) return '+${m.toStringAsFixed(0)} m (you are higher)';
    return '${m.toStringAsFixed(0)} m (airport is higher)';
  }

  Color _qualityColor(SignalQuality q, BuildContext context) {
    switch (q) {
      case SignalQuality.good:        return const Color(0xFF9CCC65);
      case SignalQuality.fair:        return context.col.accent;
      case SignalQuality.marginal:    return const Color(0xFFFF7043);
      case SignalQuality.poor:        return const Color(0xFFEF5350);
      case SignalQuality.beyondRange: return context.col.textMuted;
      case SignalQuality.outOfRange:  return context.col.textMuted;
    }
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(label,
              style: TextStyle(color: context.col.textSecondary, fontSize: 13))),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? context.col.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.quality, required this.color});
  final SignalQuality quality;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filledBars = switch (quality) {
      SignalQuality.good        => 3,
      SignalQuality.fair        => 2,
      SignalQuality.marginal    => 1,
      SignalQuality.poor        => 0,
      SignalQuality.beyondRange => 0,
      SignalQuality.outOfRange  => 0,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        final filled = i < filledBars;
        return Container(
          width: 6,
          height: 10.0 + i * 5,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: filled ? color : context.col.border,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ── LiveATC suggestion for out-of-range airports ──────────────────────────────

class _LiveAtcSuggestion extends StatelessWidget {
  const _LiveAtcSuggestion({required this.airport});
  final Airport airport;

  static const _messages = [
    'Bit of a stretch. But you might catch it on LiveATC.net →',
    'Your antenna would need to be very, very tall. Try LiveATC.net →',
    'Even a rooftop Yagi won\'t cut it here. LiveATC.net might though →',
    'The Earth had other plans. Check for a live feed on LiveATC.net →',
    'Physics says no. LiveATC.net might say yes →',
  ];

  @override
  Widget build(BuildContext context) {
    final restricted = kRestrictedCountries.contains(
        airport.isoCountry.toUpperCase());
    // Pick a message based on ICAO hash so it's stable per airport
    final msg = _messages[airport.ident.hashCode.abs() % _messages.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: restricted ? null : _launch,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: restricted
                ? context.col.textMuted.withAlpha(15)
                : context.col.accent.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: restricted
                  ? context.col.border
                  : context.col.accent.withAlpha(80),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.headphones_rounded,
                size: 18,
                color: restricted
                    ? context.col.textMuted
                    : context.col.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  restricted
                      ? 'Live ATC streaming is legally restricted in this country.'
                      : msg,
                  style: TextStyle(
                    color: restricted
                        ? context.col.textMuted
                        : context.col.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launch() async {
    MetricsService.instance.trackFeature('liveatc_tapped_signal');
    final uri = Uri.parse(
        'https://www.liveatc.net/search/?icao=${airport.ident.toUpperCase()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Subtle LiveATC footer for in-range airports ───────────────────────────────

class _LiveAtcFooter extends StatelessWidget {
  const _LiveAtcFooter({required this.airport});
  final Airport airport;

  @override
  Widget build(BuildContext context) {
    final restricted = kRestrictedCountries
        .contains(airport.isoCountry.toUpperCase());
    if (restricted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: _launch,
        child: Row(
          children: [
            Icon(Icons.headphones_rounded,
                size: 13, color: context.col.textMuted),
            const SizedBox(width: 6),
            Text(
              'Listen live on LiveATC.net →',
              style: TextStyle(
                  color: context.col.textMuted,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                  decorationColor: context.col.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launch() async {
    MetricsService.instance.trackFeature('liveatc_tapped_signal');
    final uri = Uri.parse(
        'https://www.liveatc.net/search/?icao=${airport.ident.toUpperCase()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
