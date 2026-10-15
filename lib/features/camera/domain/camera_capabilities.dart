import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

@immutable
class CameraCapabilities {
  const CameraCapabilities({
    this.supportsFlash = false,
    this.supportsTorch = false,
    this.supportsFocusPoint = false,
    this.supportsExposurePoint = false,
    this.minZoom = 1.0,
    this.maxZoom = 1.0,
  });

  factory CameraCapabilities.fromLensDirection(CameraLensDirection direction) {
    return CameraCapabilities(
      supportsFlash: direction != CameraLensDirection.front,
      supportsTorch: direction == CameraLensDirection.back,
    );
  }

  /// Beyond this, digital zoom is mostly noise; it also keeps the slider
  /// precise on devices that report 50x+ ranges.
  static const double maxUsefulZoom = 10.0;

  final bool supportsFlash;
  final bool supportsTorch;
  final bool supportsFocusPoint;
  final bool supportsExposurePoint;
  final double minZoom;
  final double maxZoom;

  bool get supportsZoom => maxZoom > minZoom;

  bool get supportsTapToFocus => supportsFocusPoint || supportsExposurePoint;

  /// Cameras open at 1x even when an ultra-wide lens reports a lower minimum.
  double get initialZoom => clampZoom(1.0);

  double clampZoom(double zoom) => zoom.clamp(minZoom, maxZoom).toDouble();

  /// Builds the zoom range from what the platform reports, discarding values
  /// that would make the slider unusable.
  CameraCapabilities withZoomRange(double reportedMin, double reportedMax) {
    final min = reportedMin.isFinite && reportedMin > 0 ? reportedMin : 1.0;
    final max = reportedMax.isFinite
        ? math.min(reportedMax, math.max(min, maxUsefulZoom))
        : min;
    return copyWith(minZoom: min, maxZoom: math.max(min, max));
  }

  CameraCapabilities copyWith({
    bool? supportsFlash,
    bool? supportsTorch,
    bool? supportsFocusPoint,
    bool? supportsExposurePoint,
    double? minZoom,
    double? maxZoom,
  }) {
    return CameraCapabilities(
      supportsFlash: supportsFlash ?? this.supportsFlash,
      supportsTorch: supportsTorch ?? this.supportsTorch,
      supportsFocusPoint: supportsFocusPoint ?? this.supportsFocusPoint,
      supportsExposurePoint:
          supportsExposurePoint ?? this.supportsExposurePoint,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CameraCapabilities &&
            other.supportsFlash == supportsFlash &&
            other.supportsTorch == supportsTorch &&
            other.supportsFocusPoint == supportsFocusPoint &&
            other.supportsExposurePoint == supportsExposurePoint &&
            other.minZoom == minZoom &&
            other.maxZoom == maxZoom;
  }

  @override
  int get hashCode => Object.hash(
    supportsFlash,
    supportsTorch,
    supportsFocusPoint,
    supportsExposurePoint,
    minZoom,
    maxZoom,
  );
}
