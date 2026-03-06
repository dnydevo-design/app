import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/app_constants.dart';

/// Widget that detects device shaking for Shake-to-Connect feature.
///
/// Uses accelerometer data with threshold-based detection
/// and debouncing to prevent false positives.
class ShakeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onShake;
  final double threshold;
  final int minimumIntervalMs;

  const ShakeDetector({
    super.key,
    required this.child,
    required this.onShake,
    this.threshold = AppConstants.shakeThreshold,
    this.minimumIntervalMs = AppConstants.shakeMinIntervalMs,
  });

  @override
  State<ShakeDetector> createState() => _ShakeDetectorState();
}

class _ShakeDetectorState extends State<ShakeDetector> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastShakeTime;

  @override
  void initState() {
    super.initState();
    _subscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude > widget.threshold) {
      final now = DateTime.now();
      if (_lastShakeTime == null ||
          now.difference(_lastShakeTime!).inMilliseconds >
              widget.minimumIntervalMs) {
        _lastShakeTime = now;
        widget.onShake();
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
