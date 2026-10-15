import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import 'overlay_fit_mode.dart';

/// Everything about how the reference image is drawn, independent of which
/// image it is and of any widget.
@immutable
class OverlaySettings {
  const OverlaySettings({
    this.opacity = AppConstants.defaultOverlayOpacity,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.rotation = 0.0,
    this.fitMode = OverlayFitMode.fit,
    this.isVisible = true,
    this.isLocked = false,
  });

  final double opacity;

  /// Multiplier on the size given by [fitMode].
  final double scale;

  /// Displacement of the image center from the viewport center, as a fraction
  /// of the viewport's width and height, so a position survives rotation and
  /// other viewport size changes.
  final Offset offset;

  /// Clockwise rotation in radians.
  final double rotation;

  final OverlayFitMode fitMode;
  final bool isVisible;

  /// When locked, gestures leave the overlay alone (camera controls still work).
  final bool isLocked;

  static const OverlaySettings defaults = OverlaySettings();

  bool get hasCustomTransform =>
      scale != 1.0 || offset != Offset.zero || rotation != 0.0;

  int get opacityPercent => (opacity * 100).round();

  OverlaySettings copyWith({
    double? opacity,
    double? scale,
    Offset? offset,
    double? rotation,
    OverlayFitMode? fitMode,
    bool? isVisible,
    bool? isLocked,
  }) {
    return OverlaySettings(
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
      rotation: rotation ?? this.rotation,
      fitMode: fitMode ?? this.fitMode,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  /// Clears drag, pinch and rotation, keeping fit mode, opacity and toggles.
  OverlaySettings withoutTransform() =>
      copyWith(scale: 1.0, offset: Offset.zero, rotation: 0.0);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OverlaySettings &&
            other.opacity == opacity &&
            other.scale == scale &&
            other.offset == offset &&
            other.rotation == rotation &&
            other.fitMode == fitMode &&
            other.isVisible == isVisible &&
            other.isLocked == isLocked;
  }

  @override
  int get hashCode => Object.hash(
    opacity,
    scale,
    offset,
    rotation,
    fitMode,
    isVisible,
    isLocked,
  );
}
