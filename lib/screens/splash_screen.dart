import 'dart:math';
import 'package:flutter/material.dart';
import '../constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final AnimationController _flyCtrl;
  late final AnimationController _outroCtrl;

  late final Animation<double> _contentFade;
  late final Animation<double> _arcFade;
  late final Animation<double> _planeY;
  late final Animation<double> _planeScale;
  late final Animation<double> _outroFade;

  @override
  void initState() {
    super.initState();

    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _outroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _contentFade =
        CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _arcFade = CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut));

    _planeY = Tween<double>(begin: 0.0, end: -1.6).animate(
        CurvedAnimation(parent: _flyCtrl, curve: Curves.easeIn));
    _planeScale = Tween<double>(begin: 1.0, end: 0.7).animate(
        CurvedAnimation(parent: _flyCtrl, curve: Curves.easeIn));

    _outroFade =
        CurvedAnimation(parent: _outroCtrl, curve: Curves.easeIn);

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _introCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _flyCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _outroCtrl.forward();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _flyCtrl.dispose();
    _outroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accentColor = context.col.accent;
    final textPrimaryColor = context.col.textPrimary;
    final bgColor = context.col.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([_introCtrl, _flyCtrl, _outroCtrl]),
        builder: (context, _) {
          final visible = (1.0 - _outroFade.value).clamp(0.0, 1.0);
          return Opacity(
            opacity: visible,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radio arcs behind the plane
                Opacity(
                  opacity: _arcFade.value,
                  child: CustomPaint(
                    size: Size(size.width, size.height),
                    painter: _ArcsPainter(accentColor: accentColor),
                  ),
                ),

                // Plane
                Transform.translate(
                  offset: Offset(0, _planeY.value * size.height),
                  child: Transform.scale(
                    scale: _planeScale.value,
                    child: Opacity(
                      opacity: _contentFade.value,
                      child: Image.asset(
                        'assets/icon/plane_only.png',
                        width: 220,
                        height: 220,
                      ),
                    ),
                  ),
                ),

                // App name
                Positioned(
                  bottom: size.height * 0.22,
                  child: Opacity(
                    opacity: _contentFade.value,
                    child: Column(
                      children: [
                        Text(
                          'ATC',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'FREQUENCIES',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Worldwide ATC frequencies, updated weekly',
                          style: TextStyle(
                            color: textPrimaryColor.withAlpha(140),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArcsPainter extends CustomPainter {
  const _ArcsPainter({required this.accentColor});
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 30;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arcs = [
      (90.0, 0.10),
      (140.0, 0.16),
      (195.0, 0.22),
    ];

    for (final (r, opacity) in arcs) {
      paint
        ..color = accentColor.withAlpha((opacity * 255).round())
        ..strokeWidth = r < 120 ? 2.0 : 2.5;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        pi,
        pi,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcsPainter old) => old.accentColor != accentColor;
}
