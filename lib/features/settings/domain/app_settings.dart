import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import 'preferred_camera.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.defaultOverlayOpacity = AppConstants.defaultOverlayOpacity,
    this.showAlignmentGrid = true,
    this.preferredCamera = PreferredCamera.rear,
    this.hapticsEnabled = true,
  });

  final ThemeMode themeMode;
  final double defaultOverlayOpacity;
  final bool showAlignmentGrid;

  /// Which lens the camera screen opens with.
  final PreferredCamera preferredCamera;

  /// Haptic feedback on taps, captures and confirmations.
  final bool hapticsEnabled;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? defaultOverlayOpacity,
    bool? showAlignmentGrid,
    PreferredCamera? preferredCamera,
    bool? hapticsEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultOverlayOpacity:
          defaultOverlayOpacity ?? this.defaultOverlayOpacity,
      showAlignmentGrid: showAlignmentGrid ?? this.showAlignmentGrid,
      preferredCamera: preferredCamera ?? this.preferredCamera,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
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
            other.hapticsEnabled == hapticsEnabled;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    defaultOverlayOpacity,
    showAlignmentGrid,
    preferredCamera,
    hapticsEnabled,
  );
}
