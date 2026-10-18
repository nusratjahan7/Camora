import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/haptics/haptics.dart';
import '../../data/settings_repository.dart';
import '../../domain/app_settings.dart';
import '../../domain/capture_ratio.dart';
import '../../domain/preferred_camera.dart';

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final settings = await ref.watch(settingsRepositoryProvider).load();
    // The preference is a cross-cutting side effect every control relies on,
    // so it is applied as soon as the settings are known.
    Haptics.enabled = settings.hapticsEnabled;
    return settings;
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _apply((settings) => settings.copyWith(themeMode: mode));

  Future<void> setDefaultOverlayOpacity(double value) =>
      _apply((settings) => settings.copyWith(defaultOverlayOpacity: value));

  Future<void> setShowAlignmentGrid(bool value) =>
      _apply((settings) => settings.copyWith(showAlignmentGrid: value));

  Future<void> setPreferredCamera(PreferredCamera camera) =>
      _apply((settings) => settings.copyWith(preferredCamera: camera));

  Future<void> setHapticsEnabled(bool value) =>
      _apply((settings) => settings.copyWith(hapticsEnabled: value));

  Future<void> setCaptureRatio(CaptureRatio ratio) =>
      _apply((settings) => settings.copyWith(captureRatio: ratio));

  Future<void> setShowSensorSpill(bool value) =>
      _apply((settings) => settings.copyWith(showSensorSpill: value));

  Future<void> _apply(AppSettings Function(AppSettings) transform) async {
    final current = state.value ?? AppSettings.defaults;
    final next = transform(current);
    state = AsyncData<AppSettings>(next);
    Haptics.enabled = next.hapticsEnabled;

    try {
      await ref.read(settingsRepositoryProvider).save(next);
    } catch (error, stackTrace) {
      ref
          .read(appErrorHandlerProvider)
          .report(error, stackTrace, operation: 'persist settings');
    }
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );
