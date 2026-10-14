import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

@immutable
class CameraCapabilities {
  const CameraCapabilities({
    this.supportsFlash = false,
    this.supportsTorch = false,
    this.supportsFocusPoint = false,
    this.minZoom = 1.0,
    this.maxZoom = 1.0,
  });

  factory CameraCapabilities.fromLensDirection(
    CameraLensDirection direction,
  ) {
    return CameraCapabilities(
      supportsFlash: direction != CameraLensDirection.front,
      supportsTorch: direction == CameraLensDirection.back,
    );
  }

  final bool supportsFlash;
  final bool supportsTorch;
  final bool supportsFocusPoint;
  final double minZoom;
  final double maxZoom;

  bool get supportsZoom => maxZoom > minZoom;

  CameraCapabilities copyWith({
    bool? supportsFlash,
    bool? supportsTorch,
    bool? supportsFocusPoint,
    double? minZoom,
    double? maxZoom,
  }) {
    return CameraCapabilities(
      supportsFlash: supportsFlash ?? this.supportsFlash,
      supportsTorch: supportsTorch ?? this.supportsTorch,
      supportsFocusPoint: supportsFocusPoint ?? this.supportsFocusPoint,
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
            other.minZoom == minZoom &&
            other.maxZoom == maxZoom;
  }

  @override
  int get hashCode => Object.hash(
    supportsFlash,
    supportsTorch,
    supportsFocusPoint,
    minZoom,
    maxZoom,
  );
}
