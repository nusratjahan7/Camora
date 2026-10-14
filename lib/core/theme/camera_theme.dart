import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class CameraTheme extends ThemeExtension<CameraTheme> {
  const CameraTheme({
    required this.scrim,
    required this.onScrim,
    required this.controlSurface,
    required this.shutterRing,
    required this.shutterInner,
    required this.guide,
    required this.trackInactive,
  });

  final Color scrim;
  final Color onScrim;
  final Color controlSurface;
  final Color shutterRing;
  final Color shutterInner;
  final Color guide;
  final Color trackInactive;

  static const CameraTheme dark = CameraTheme(
    scrim: AppColors.scrim,
    onScrim: Color(0xFFFFFFFF),
    controlSurface: Color(0xFF1C1C22),
    shutterRing: Color(0xFFFFFFFF),
    shutterInner: Color(0xFFFFFFFF),
    guide: AppColors.guide,
    trackInactive: AppColors.trackInactive,
  );

  static const CameraTheme light = CameraTheme(
    scrim: Color(0xE61A1A1F),
    onScrim: Color(0xFFFFFFFF),
    controlSurface: Color(0xFF23232A),
    shutterRing: Color(0xFFFFFFFF),
    shutterInner: Color(0xFFFFFFFF),
    guide: Color(0x66000000),
    trackInactive: Color(0x33000000),
  );

  @override
  CameraTheme copyWith({
    Color? scrim,
    Color? onScrim,
    Color? controlSurface,
    Color? shutterRing,
    Color? shutterInner,
    Color? guide,
    Color? trackInactive,
  }) {
    return CameraTheme(
      scrim: scrim ?? this.scrim,
      onScrim: onScrim ?? this.onScrim,
      controlSurface: controlSurface ?? this.controlSurface,
      shutterRing: shutterRing ?? this.shutterRing,
      shutterInner: shutterInner ?? this.shutterInner,
      guide: guide ?? this.guide,
      trackInactive: trackInactive ?? this.trackInactive,
    );
  }

  @override
  CameraTheme lerp(ThemeExtension<CameraTheme>? other, double t) {
    if (other is! CameraTheme) return this;
    return CameraTheme(
      scrim: Color.lerp(scrim, other.scrim, t) ?? scrim,
      onScrim: Color.lerp(onScrim, other.onScrim, t) ?? onScrim,
      controlSurface:
          Color.lerp(controlSurface, other.controlSurface, t) ?? controlSurface,
      shutterRing: Color.lerp(shutterRing, other.shutterRing, t) ?? shutterRing,
      shutterInner:
          Color.lerp(shutterInner, other.shutterInner, t) ?? shutterInner,
      guide: Color.lerp(guide, other.guide, t) ?? guide,
      trackInactive:
          Color.lerp(trackInactive, other.trackInactive, t) ?? trackInactive,
    );
  }
}
