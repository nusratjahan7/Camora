import 'package:camera_overlay/core/theme/app_theme.dart';
import 'package:camera_overlay/core/theme/camera_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('dark theme is dark, Material 3 and carries the camera extension', () {
      final theme = AppTheme.dark;

      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.extension<CameraTheme>(), isA<CameraTheme>());
      expect(theme.appBarTheme.elevation, 0);
    });

    test('light theme is available for the theme mode setting', () {
      expect(AppTheme.light.brightness, Brightness.light);
    });
  });
}
