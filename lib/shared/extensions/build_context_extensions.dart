import 'package:flutter/material.dart';

import '../../core/theme/camera_theme.dart';

extension BuildContextX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get textStyles => Theme.of(this).textTheme;

  CameraTheme get cameraTheme =>
      Theme.of(this).extension<CameraTheme>() ?? CameraTheme.dark;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  void showAppSnackBar(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
