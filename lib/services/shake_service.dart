import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects phone shakes and fires [onShake].
/// Call [init] once, [dispose] when done.
class ShakeService {
  ShakeService._();
  static final ShakeService instance = ShakeService._();

  static const double _kThreshold  = 18.0; // m/s² above which = shake
  static const int    _kCooldownMs = 1500; // ms between shake events

  StreamSubscription<AccelerometerEvent>? _sub;
  VoidCallback? _onShake;
  DateTime? _lastShake;

  void init({required VoidCallback onShake}) {
    _onShake = onShake;
    _sub = accelerometerEventStream().listen(_onEvent);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _onShake = null;
  }

  void _onEvent(AccelerometerEvent e) {
    // Net acceleration magnitude minus gravity (9.8 m/s²)
    final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (magnitude < _kThreshold) return;

    final now = DateTime.now();
    if (_lastShake != null &&
        now.difference(_lastShake!).inMilliseconds < _kCooldownMs) return;

    _lastShake = now;
    _onShake?.call();
  }
}
