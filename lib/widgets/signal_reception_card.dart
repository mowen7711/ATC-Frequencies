import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/airport.dart';
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

    if (mounted) setState(() { _result = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.signal_cellular_alt_rounded,
                    color: kAccent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Signal Reception',
                      style: TextStyle(
                          color: kTextPrimary,
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
                      foregroundColor: kAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Average handheld scanner · VHF airband · Line-of-sight model',
              style: TextStyle(color: kTextMuted, fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kAccent),
                  ),
                  SizedBox(width: 10),
                  Text('Getting GPS altitude…',
                      style: TextStyle(color: kTextSecondary, fontSize: 13)),
                ],
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(_error!,
                  style: const TextStyle(color: kTextMuted, fontSize: 13)),
            )
          else if (_result != null)
            _ResultBody(result: _result!),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.result});
  final SignalResult result;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(result.quality);
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
                        Text('${result.percent}%',
                            style: TextStyle(
                                color: color,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace')),
                        const SizedBox(width: 10),
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
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: result.percent / 100,
                        backgroundColor: kBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
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
              style: const TextStyle(
                  color: kTextSecondary, fontSize: 12, height: 1.5)),
        ),
        const SizedBox(height: 12),

        // Stats grid
        const Divider(height: 1),
        _StatRow(
          label: 'Distance to airport',
          value: '${result.distanceKm.toStringAsFixed(1)} km',
        ),
        const Divider(height: 1),
        _StatRow(
          label: 'Practical handheld range',
          value: '~${result.estimatedRangeKm.toStringAsFixed(1)} km',
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            'GPS altitude accuracy is ±10–30 m. Actual reception may vary with '
            'terrain, buildings, and antenna type.',
            style: TextStyle(color: kTextMuted, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  String _heightStr(double m) {
    if (m >= 0) return '+${m.toStringAsFixed(0)} m (you are higher)';
    return '${m.toStringAsFixed(0)} m (airport is higher)';
  }

  Color _qualityColor(SignalQuality q) {
    switch (q) {
      case SignalQuality.good:     return const Color(0xFF9CCC65);
      case SignalQuality.fair:     return kAccent;
      case SignalQuality.marginal: return const Color(0xFFFF7043);
      case SignalQuality.poor:     return const Color(0xFFEF5350);
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
              style: const TextStyle(color: kTextSecondary, fontSize: 13))),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? kTextPrimary,
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
      SignalQuality.good     => 3,
      SignalQuality.fair     => 2,
      SignalQuality.marginal => 1,
      SignalQuality.poor     => 0,
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
            color: filled ? color : kBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
