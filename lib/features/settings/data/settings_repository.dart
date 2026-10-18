import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/shared_preferences_store.dart';
import '../domain/app_settings.dart';
import '../domain/preferred_camera.dart';

class SettingsRepository {
  SettingsRepository({required this.store, required this.errorHandler});

  final KeyValueStore store;
  final AppErrorHandler errorHandler;

  Future<AppSettings> load() => errorHandler.guard(() async {
    final themeModeName = await store.getString(StorageKeys.themeMode);
    final opacity = await store.getDouble(StorageKeys.defaultOverlayOpacity);
    final grid = await store.getBool(StorageKeys.showAlignmentGrid);
    final camera = await store.getString(StorageKeys.preferredCamera);
    final haptics = await store.getBool(StorageKeys.hapticsEnabled);

    return AppSettings(
      themeMode: _themeModeFromName(themeModeName),
      defaultOverlayOpacity:
          opacity ?? AppSettings.defaults.defaultOverlayOpacity,
      showAlignmentGrid: grid ?? AppSettings.defaults.showAlignmentGrid,
      preferredCamera: _cameraFromName(camera),
      hapticsEnabled: haptics ?? AppSettings.defaults.hapticsEnabled,
    );
  }, operation: 'load settings');

  Future<void> save(AppSettings settings) => errorHandler.guard(() async {
    await store.setString(StorageKeys.themeMode, settings.themeMode.name);
    await store.setDouble(
      StorageKeys.defaultOverlayOpacity,
      settings.defaultOverlayOpacity,
    );
    await store.setBool(
      StorageKeys.showAlignmentGrid,
      settings.showAlignmentGrid,
    );
    await store.setString(
      StorageKeys.preferredCamera,
      settings.preferredCamera.name,
    );
    await store.setBool(StorageKeys.hapticsEnabled, settings.hapticsEnabled);
  }, operation: 'save settings');

  ThemeMode _themeModeFromName(String? name) => ThemeMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => AppSettings.defaults.themeMode,
  );

  PreferredCamera _cameraFromName(String? name) =>
      PreferredCamera.values.firstWhere(
        (camera) => camera.name == name,
        orElse: () => AppSettings.defaults.preferredCamera,
      );
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    store: ref.watch(keyValueStoreProvider),
    errorHandler: ref.watch(appErrorHandlerProvider),
  ),
);
