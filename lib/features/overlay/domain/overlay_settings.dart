import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';

@immutable
class OverlaySettings {
  const OverlaySettings({
    this.opacity = AppConstants.defaultOverlayOpacity,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.rotation = 0.0,
  });

  final double opacity;
  final double scale;
  final Offset offset;
  final double rotation;

  static const OverlaySettings defaults = OverlaySettings();

  OverlaySettings copyWith({
    double? opacity,
    double? scale,
    Offset? offset,
    double? rotation,
  }) {
    return OverlaySettings(
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OverlaySettings &&
            other.opacity == opacity &&
            other.scale == scale &&
            other.offset == offset &&
            other.rotation == rotation;
  }

  @override
  int get hashCode => Object.hash(opacity, scale, offset, rotation);
}
