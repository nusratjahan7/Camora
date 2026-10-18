import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import 'capture_ratio.dart';
import 'preferred_camera.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.defaultOverlayOpacity = AppConstants.defaultOverlayOpacity,
    this.showAlignmentGrid = true,
    this.preferredCamera = PreferredCamera.rear,
    this.hapticsEnabled = true,
    this.captureRatio = CaptureRatio.classic43,
    this.showSensorSpill = true,
  });

  final ThemeMode themeMode;
  final double defaultOverlayOpacity;
  final bool showAlignmentGrid;

  /// Which lens the camera screen opens with.
  final PreferredCamera preferredCamera;

  /// Haptic feedback on taps, captures and confirmations.
  final bool hapticsEnabled;

  /// Framing of the shot: the ratio the preview is masked to and the still is
  /// cropped to. 4:3 by default.
  final CaptureRatio captureRatio;

  /// Whether the parts of the camera stream outside the capture frame are
  /// shown, dimmed, so the sensor's extra coverage stays visible.
  final bool showSensorSpill;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? defaultOverlayOpacity,
    bool? showAlignmentGrid,
    PreferredCamera? preferredCamera,
    bool? hapticsEnabled,
    CaptureRatio? captureRatio,
    bool? showSensorSpill,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultOverlayOpacity:
          defaultOverlayOpacity ?? this.defaultOverlayOpacity,
      showAlignmentGrid: showAlignmentGrid ?? this.showAlignmentGrid,
      preferredCamera: preferredCamera ?? this.preferredCamera,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      captureRatio: captureRatio ?? this.captureRatio,
      showSensorSpill: showSensorSpill ?? this.showSensorSpill,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppSettings &&
            other.themeMode == themeMode &&
            other.defaultOverlayOpacity == defaultOverlayOpacity &&
            other.showAlignmentGrid == showAlignmentGrid &&
            other.preferredCamera == preferredCamera &&
            other.hapticsEnabled == hapticsEnabled &&
            other.captureRatio == captureRatio &&
            other.showSensorSpill == showSensorSpill;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    defaultOverlayOpacity,
    showAlignmentGrid,
    preferredCamera,
    hapticsEnabled,
    captureRatio,
    showSensorSpill,
  );
}
