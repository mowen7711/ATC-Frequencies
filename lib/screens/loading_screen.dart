import 'dart:math';
import 'package:flutter/material.dart';
import '../constants.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    required this.status,
    required this.progress,
    this.runwayLabels = const [],
    this.eta,
  });

  final String status;
  final double progress;
  final List<String> runwayLabels;
  final String? eta;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _displayProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = AlwaysStoppedAnimation(0.0);
    _animateTo(widget.progress);
  }

  @override
  void didUpdateWidget(LoadingScreen old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) _animateTo(widget.progress);
  }

  void _animateTo(double target) {
    final to = max(_displayProgress, target.clamp(0.0, 1.0));
    if (to <= _displayProgress && _displayProgress > 0) return;
    final from = _displayProgress;
    _displayProgress = to;
    _anim = Tween<double>(begin: from, end: to)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.stop();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    const hPad = 40.0;
    final trackW = screenW - hPad * 2;
    final pct = (widget.progress * 100).clamp(0, 100).toStringAsFixed(0);
    final accentColor = context.col.accent;
    final textMutedColor = context.col.textMuted;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ATC',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              Text(
                'FREQUENCIES',
                style: TextStyle(
                  color: textMutedColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 56),

              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => _LandingWidget(
                  progress: _anim.value,
                  trackWidth: trackW,
                  runwayLabels: widget.runwayLabels,
                  accentColor: accentColor,
                ),
              ),

              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '${widget.status}  $pct%',
                  key: ValueKey(widget.status),
                  style: TextStyle(
                    color: textMutedColor,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  widget.eta ?? 'First run downloads ~9 MB of worldwide data — usually 1 to 2 minutes.',
                  key: ValueKey(widget.eta),
                  style: TextStyle(color: textMutedColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Landing widget ─────────────────────────────────────────────────────────────

class _LandingWidget extends StatelessWidget {
  const _LandingWidget({
    required this.progress,
    required this.trackWidth,
    required this.runwayLabels,
    required this.accentColor,
  });
  final double progress;
  final double trackWidth;
  final List<String> runwayLabels;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    const planeW = 110.0;
    const planeH = planeW / 2.86;
    const runwayH = 32.0;
    const skyH = 120.0;
    const totalH = skyH + runwayH;

    final maxX = trackWidth - planeW;
    final x = progress * maxX;
    final y = progress * (skyH - planeH);

    final levelFactor =
        Curves.easeIn.transform((progress / 0.85).clamp(0.0, 1.0));
    final pitchRad = (1.0 - levelFactor) * -7.0 * pi / 180.0;

    return SizedBox(
      width: trackWidth,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glide slope guide line
          Positioned.fill(
            child: CustomPaint(
              painter: _GlideSlopePainter(
                planeW: planeW,
                planeH: planeH,
                skyH: skyH,
                trackWidth: trackWidth,
                accentColor: accentColor,
              ),
            ),
          ),

          // Runway
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(trackWidth, runwayH),
              painter: _RunwayPainter(
                progress: progress,
                runwayLabels: runwayLabels,
                accentColor: accentColor,
              ),
            ),
          ),

          // Plane — solid accent silhouette
          Positioned(
            left: x,
            top: y,
            child: Transform.rotate(
              angle: pitchRad,
              alignment: Alignment.center,
              child: ColorFiltered(
                colorFilter:
                    ColorFilter.mode(accentColor, BlendMode.srcIn),
                child: Image.asset(
                  'assets/icon/plane_side.png',
                  width: planeW,
                  height: planeH,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painters ───────────────────────────────────────────────────────────────────

class _GlideSlopePainter extends CustomPainter {
  const _GlideSlopePainter(
      {required this.planeW,
      required this.planeH,
      required this.skyH,
      required this.trackWidth,
      required this.accentColor});
  final double planeW, planeH, skyH, trackWidth;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(planeW / 2, planeH / 2),
      Offset(trackWidth - planeW / 2, skyH - planeH / 2),
      Paint()
        ..color = accentColor.withAlpha(20)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GlideSlopePainter old) =>
      old.accentColor != accentColor;
}

class _RunwayPainter extends CustomPainter {
  const _RunwayPainter({
    required this.progress,
    required this.runwayLabels,
    required this.accentColor,
  });
  final double progress;
  final List<String> runwayLabels;
  final Color accentColor;

  static const _white = Color(0xFFFFFFFF);
  static const _stripe = Color(0xFF4a6080);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = Radius.circular(3);

    // ── Runway surface ──────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()..color = const Color(0xFF1a2d4a),
    );

    // ── Progress fill ────────────────────────────────────────────────────────
    if (progress > 0.01) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, w * progress, h), r),
        Paint()..color = accentColor.withAlpha(28),
      );
    }

    // ── Border ───────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()
        ..color = const Color(0xFF2a4068)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Threshold markings — bars at each end ────────────────────────────────
    _drawThreshold(canvas, h, fromRight: false);
    _drawThreshold(canvas, h, fromRight: true, runwayW: w);

    // ── Touchdown zone markers (pairs of bars, ~15% in from each end) ────────
    _drawTDZ(canvas, w, h, fromRight: false);
    _drawTDZ(canvas, w, h, fromRight: true);

    // ── Aiming point markers (~30% in from each end) ─────────────────────────
    _drawAimingPoint(canvas, w, h, fromRight: false);
    _drawAimingPoint(canvas, w, h, fromRight: true);

    // ── Centre-line dashes ───────────────────────────────────────────────────
    final dash = Paint()
      ..color = _stripe
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    double x = w * 0.18;
    final cy = h / 2;
    while (x < w * 0.82) {
      canvas.drawLine(Offset(x, cy), Offset((x + 12).clamp(0, w * 0.82), cy), dash);
      x += 22;
    }

    // ── Leading edge glow ────────────────────────────────────────────────────
    if (progress > 0.01) {
      final ex = w * progress;
      canvas.drawLine(
        Offset(ex, 2),
        Offset(ex, h - 2),
        Paint()
          ..color = accentColor.withAlpha(160)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Runway designator labels ─────────────────────────────────────────────
    if (runwayLabels.isNotEmpty) {
      _drawDesignator(canvas, h, runwayLabels[0], fromRight: false);
    }
    if (runwayLabels.length >= 2) {
      _drawDesignator(canvas, h, runwayLabels[1], fromRight: true, runwayW: w);
    }
  }

  void _drawThreshold(Canvas canvas, double h,
      {required bool fromRight, double runwayW = 0}) {
    final barW = 3.0;
    final barH = h * 0.65;
    final topY = (h - barH) / 2;
    const gap = 3.0;
    const count = 4;
    final totalW = count * barW + (count - 1) * gap;
    final startX = fromRight ? (runwayW - 8 - totalW) : 8.0;
    final paint = Paint()
      ..color = _white.withAlpha(60)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(startX + i * (barW + gap), topY, barW, barH),
        paint,
      );
    }
  }

  void _drawTDZ(Canvas canvas, double w, double h, {required bool fromRight}) {
    const barW = 5.0;
    final barH = h * 0.5;
    final topY = (h - barH) / 2;
    final offset = w * 0.15;
    final baseX = fromRight ? w - offset - barW * 2 - 4 : offset;
    final paint = Paint()
      ..color = _white.withAlpha(45)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(baseX, topY, barW, barH), paint);
    canvas.drawRect(
        Rect.fromLTWH(baseX + barW + 3, topY, barW, barH), paint);
  }

  void _drawAimingPoint(Canvas canvas, double w, double h,
      {required bool fromRight}) {
    const barW = 8.0;
    final barH = h * 0.55;
    final topY = (h - barH) / 2;
    final offset = w * 0.30;
    final baseX = fromRight ? w - offset - barW * 2 - 4 : offset;
    final paint = Paint()
      ..color = _white.withAlpha(55)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(baseX, topY, barW, barH), paint);
    canvas.drawRect(
        Rect.fromLTWH(baseX + barW + 3, topY, barW, barH), paint);
  }

  void _drawDesignator(Canvas canvas, double h, String label,
      {required bool fromRight, double runwayW = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: _white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final cx = fromRight ? runwayW - 5.0 : 5.0;
    final cy = h / 2;

    canvas.save();
    canvas.translate(cx, cy);
    // Rotate so text reads bottom-to-top on left, top-to-bottom on right
    canvas.rotate(fromRight ? pi / 2 : -pi / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RunwayPainter old) =>
      old.progress != progress ||
      old.runwayLabels != runwayLabels ||
      old.accentColor != accentColor;
}
