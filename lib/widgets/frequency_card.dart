import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../models/frequency.dart';
import '../services/metrics_service.dart';
import '../services/sdr_service.dart';

class FrequencyCard extends StatelessWidget {
  const FrequencyCard({super.key, required this.frequency});
  final Frequency frequency;

  @override
  Widget build(BuildContext context) {
    final color = frequency.color;
    return Material(
      color: context.col.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _copyToClipboard(context),
        onLongPress: () => _copyToClipboard(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.col.border, width: 0.5),
          ),
          padding: const EdgeInsets.only(left: 14, top: 10, bottom: 10, right: 4),
          child: Row(
            children: [
              // Type badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withAlpha(100)),
                ),
                child: Text(
                  frequency.type,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Description
              Expanded(
                child: Text(
                  frequency.description.isNotEmpty
                      ? frequency.description
                      : frequency.type,
                  style: TextStyle(
                    color: context.col.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Frequency value
              Text(
                frequency.formatted,
                style: TextStyle(
                  color: context.col.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 4),
              // Copy indicator
              Icon(Icons.copy_rounded, size: 13, color: context.col.textMuted),
              // SDR listen button — has its own tap, doesn't trigger copy
              _SdrButton(frequencyMhz: frequency.frequencyMhz),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    MetricsService.instance.trackFreqCopy(frequency.type);
    Clipboard.setData(ClipboardData(text: frequency.formatted));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${frequency.type}: ${frequency.formatted} copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.col.card,
      ),
    );
  }
}

// ── SDR listen button ─────────────────────────────────────────────────────────

class _SdrButton extends StatelessWidget {
  const _SdrButton({required this.frequencyMhz});
  final double frequencyMhz;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Absorbs the tap so the parent InkWell (copy) does not fire
      onTap: () => _onTap(context),
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: 'Listen with SDR',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(
            Icons.sensors_rounded,
            size: 18,
            color: context.col.textMuted.withAlpha(180),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final launched = await SdrService.launchAtFrequency(frequencyMhz);
    MetricsService.instance.trackSdrLaunch(
        frequencyMhz, driverInstalled: launched);
    if (!launched && context.mounted) {
      _showInstallDialog(context);
    }
  }

  void _showInstallDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.col.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.sensors_rounded, color: ctx.col.accent, size: 22),
            const SizedBox(width: 10),
            Text('SDR Driver Required',
                style: TextStyle(color: ctx.col.textPrimary, fontSize: 17)),
          ],
        ),
        content: Text(
          'To listen live you need an RTL-SDR dongle connected via USB OTG '
          'and the free RTL-SDR Driver app installed.\n\n'
          'Compatible with SDR Touch and RF Analyzer.',
          style: TextStyle(color: ctx.col.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ctx.col.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.col.accent),
            onPressed: () {
              Navigator.pop(ctx);
              SdrService.openPlayStore();
            },
            child: const Text('Install Driver',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
