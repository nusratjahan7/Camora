import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color accent = Color(0xFFFFC857);
  static const Color accentDeep = Color(0xFF8A6100);
  static const Color info = Color(0xFF8AB4F8);
  static const Color danger = Color(0xFFFF6B6B);

  static const Color ink = Color(0xFF0A0A0C);
  static const Color inkSurface = Color(0xFF15151A);
  static const Color inkSurfaceHigh = Color(0xFF1F1F27);
  static const Color inkText = Color(0xFFF4F4F6);
  static const Color inkTextMuted = Color(0xFFB9B9C4);

  static const Color paper = Color(0xFFF6F6F8);
  static const Color paperSurface = Color(0xFFFFFFFF);
  static const Color paperText = Color(0xFF16161A);
  static const Color paperTextMuted = Color(0xFF5A5A66);

  static const Color scrim = Color(0xCC000000);
  static const Color guide = Color(0x66FFFFFF);
  static const Color trackInactive = Color(0x33FFFFFF);

  static ColorScheme get dark =>
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: accent,
        onPrimary: Color(0xFF241A00),
        secondary: info,
        onSecondary: Color(0xFF0A1A33),
        error: danger,
        onError: Color(0xFF2A0A0A),
        surface: ink,
        onSurface: inkText,
        onSurfaceVariant: inkTextMuted,
        surfaceContainer: inkSurface,
        surfaceContainerHigh: inkSurfaceHigh,
        outline: Color(0x33FFFFFF),
        outlineVariant: Color(0x1FFFFFFF),
      );

  static ColorScheme get light =>
      ColorScheme.fromSeed(
        seedColor: accentDeep,
        brightness: Brightness.light,
      ).copyWith(
        primary: accentDeep,
        error: danger,
        surface: paper,
        onSurface: paperText,
        onSurfaceVariant: paperTextMuted,
        surfaceContainer: paperSurface,
        surfaceContainerHigh: paperSurface,
      );
}
