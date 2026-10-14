import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../data/settings_repository.dart';
import '../../domain/app_settings.dart';

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> setThemeMode(ThemeMode mode) =>
      _apply((settings) => settings.copyWith(themeMode: mode));

  Future<void> setDefaultOverlayOpacity(double value) =>
      _apply((settings) => settings.copyWith(defaultOverlayOpacity: value));

  Future<void> setShowAlignmentGrid(bool value) =>
      _apply((settings) => settings.copyWith(showAlignmentGrid: value));

  Future<void> _apply(AppSettings Function(AppSettings) transform) async {
    final current = state.value ?? AppSettings.defaults;
    final next = transform(current);
    state = AsyncData<AppSettings>(next);

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
