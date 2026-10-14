import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.defaultOverlayOpacity = AppConstants.defaultOverlayOpacity,
    this.showAlignmentGrid = true,
  });

  final ThemeMode themeMode;
  final double defaultOverlayOpacity;
  final bool showAlignmentGrid;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? defaultOverlayOpacity,
    bool? showAlignmentGrid,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultOverlayOpacity:
          defaultOverlayOpacity ?? this.defaultOverlayOpacity,
      showAlignmentGrid: showAlignmentGrid ?? this.showAlignmentGrid,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppSettings &&
            other.themeMode == themeMode &&
            other.defaultOverlayOpacity == defaultOverlayOpacity &&
            other.showAlignmentGrid == showAlignmentGrid;
  }

  @override
  int get hashCode =>
      Object.hash(themeMode, defaultOverlayOpacity, showAlignmentGrid);
}
