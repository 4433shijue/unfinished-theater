import 'dart:math' as math;

// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

@immutable
class AppTextScaler extends TextScaler {
  const AppTextScaler({
    required this.systemScaler,
    required this.uiScale,
  });

  final TextScaler systemScaler;
  final double uiScale;

  double get _effectiveUiScale => math.max(1, uiScale.clamp(0.82, 1.25));

  @override
  double scale(double fontSize) {
    return systemScaler.scale(fontSize) * _effectiveUiScale;
  }

  @override
  double get textScaleFactor =>
      systemScaler.textScaleFactor * _effectiveUiScale;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppTextScaler &&
            other.systemScaler == systemScaler &&
            other.uiScale == uiScale;
  }

  @override
  int get hashCode => Object.hash(systemScaler, uiScale);
}
