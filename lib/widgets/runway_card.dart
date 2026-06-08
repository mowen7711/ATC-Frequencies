import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/navaid.dart';
import '../models/runway.dart';

class RunwayCard extends StatelessWidget {
  const RunwayCard({super.key, required this.runway, this.navaids = const []});
  final Runway runway;
  final List<Navaid> navaids;

  @override
  Widget build(BuildContext context) {
    // ILS/LOC navaids whose name hints at either runway end
    final ils = navaids.where((n) => n.isIls).toList();
    final leIls = _navaidForEnd(ils, runway.leIdent);
    final heIls = _navaidForEnd(ils, runway.heIdent);

    return Container(
      decoration: BoxDecoration(
        color: context.col.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.airplanemode_active_rounded,
                    color: context.col.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  runway.designator,
                  style: TextStyle(
                    color: context.col.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                if (runway.lighted)
                  _Badge(
                    icon: Icons.lightbulb_rounded,
                    label: 'Lit',
                    color: const Color(0xFFFFD54F),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Stats row ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (runway.lengthDisplay != null)
                  _Stat(
                      icon: Icons.straighten_rounded,
                      label: runway.lengthDisplay!),
                if (runway.widthDisplay != null)
                  _Stat(icon: Icons.width_normal_rounded, label: runway.widthDisplay!),
                _Stat(
                    icon: Icons.layers_rounded, label: runway.surfaceDisplay),
              ],
            ),
          ),

          // ── Runway ends ───────────────────────────────────────────────────
          if (runway.leIdent.isNotEmpty || runway.heIdent.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _RunwayEnd(
                      ident: runway.leIdent,
                      heading: runway.leHeadingDegT,
                      displacedFt: runway.leDisplacedThresholdFt,
                      ils: leIls,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: context.col.border,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _RunwayEnd(
                      ident: runway.heIdent,
                      heading: runway.heHeadingDegT,
                      displacedFt: runway.heDisplacedThresholdFt,
                      ils: heIls,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Navaid? _navaidForEnd(List<Navaid> ils, String endIdent) {
    if (endIdent.isEmpty || ils.isEmpty) return null;
    // Match by runway end number in the navaid name (e.g. "ILS Y RWY 27L")
    final digits = endIdent.replaceAll(RegExp(r'[LRC]'), '');
    final suffix = endIdent.replaceAll(RegExp(r'[0-9]'), '');
    for (final n in ils) {
      final upper = n.name.toUpperCase();
      if (upper.contains(endIdent.toUpperCase())) return n;
      if (digits.isNotEmpty && upper.contains('RWY $digits') &&
          (suffix.isEmpty || upper.contains(suffix))) return n;
    }
    return null;
  }
}

// ── Runway end column ─────────────────────────────────────────────────────────

class _RunwayEnd extends StatelessWidget {
  const _RunwayEnd({
    required this.ident,
    required this.heading,
    required this.displacedFt,
    required this.ils,
  });
  final String ident;
  final double? heading;
  final int? displacedFt;
  final Navaid? ils;

  @override
  Widget build(BuildContext context) {
    if (ident.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ident,
          style: TextStyle(
            color: context.col.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        if (heading != null) ...[
          const SizedBox(height: 2),
          Text(
            '${heading!.toStringAsFixed(0)}° true',
            style: TextStyle(color: context.col.textSecondary, fontSize: 12),
          ),
        ],
        if (displacedFt != null && displacedFt! > 0) ...[
          const SizedBox(height: 2),
          Text(
            'Disp. ${displacedFt} ft',
            style: TextStyle(color: context.col.textMuted, fontSize: 11),
          ),
        ],
        if (ils != null) ...[
          const SizedBox(height: 6),
          _IlsChip(navaid: ils!),
        ],
      ],
    );
  }
}

// ── ILS chip ──────────────────────────────────────────────────────────────────

class _IlsChip extends StatelessWidget {
  const _IlsChip({required this.navaid});
  final Navaid navaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withAlpha(25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF2196F3).withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            navaid.typeDisplay,
            style: const TextStyle(
              color: Color(0xFF64B5F6),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            navaid.frequencyDisplay,
            style: const TextStyle(
              color: Color(0xFF90CAF9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.col.textMuted),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: context.col.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
