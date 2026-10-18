import 'package:flutter/services.dart';

/// Single gate in front of the platform's haptic feedback.
///
/// The user's "Haptic feedback" preference is applied here by
/// `SettingsController`, so every control can call [selectionClick],
/// [lightImpact] and [mediumImpact] unconditionally and stay quiet when the
/// preference is off. Deep widgets (glass buttons, chips) fire haptics without
/// holding a `ref`, which is why the flag lives on the class rather than in a
/// provider.
abstract final class Haptics {
  /// Mirrors the user's "Haptic feedback" preference. `SettingsController`
  /// keeps it in step; everything else only reads it.
  static bool enabled = true;

  static Future<void> selectionClick() =>
      enabled ? HapticFeedback.selectionClick() : Future<void>.value();

  static Future<void> lightImpact() =>
      enabled ? HapticFeedback.lightImpact() : Future<void>.value();

  static Future<void> mediumImpact() =>
      enabled ? HapticFeedback.mediumImpact() : Future<void>.value();
}
