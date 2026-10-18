import 'package:camera_overlay/core/constants/storage_keys.dart';
import 'package:camera_overlay/core/errors/app_error_handler.dart';
import 'package:camera_overlay/core/haptics/haptics.dart';
import 'package:camera_overlay/core/logging/app_logger.dart';
import 'package:camera_overlay/core/storage/shared_preferences_store.dart';
import 'package:camera_overlay/features/settings/data/settings_repository.dart';
import 'package:camera_overlay/features/settings/domain/app_settings.dart';
import 'package:camera_overlay/features/settings/domain/capture_ratio.dart';
import 'package:camera_overlay/features/settings/domain/preferred_camera.dart';
import 'package:camera_overlay/features/settings/presentation/providers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_key_value_store.dart';

void main() {
  late FakeKeyValueStore store;
  late SettingsRepository repository;

  setUp(() {
    store = FakeKeyValueStore();
    repository = SettingsRepository(
      store: store,
      errorHandler: const AppErrorHandler(logger: AppLogger()),
    );
  });

  test('round-trips every preference through storage', () async {
    const settings = AppSettings(
      themeMode: ThemeMode.light,
      defaultOverlayOpacity: 0.25,
      showAlignmentGrid: false,
      preferredCamera: PreferredCamera.front,
      hapticsEnabled: false,
      captureRatio: CaptureRatio.square11,
      showSensorSpill: false,
    );

    await repository.save(settings);

    expect(await repository.load(), settings);
  });

  test('4:3 is the default capture ratio', () {
    expect(AppSettings.defaults.captureRatio, CaptureRatio.classic43);
    expect(AppSettings.defaults.showSensorSpill, isTrue);
  });

  test('unknown or missing values fall back to the defaults', () async {
    await store.setString(StorageKeys.themeMode, 'dusk');
    await store.setString(StorageKeys.preferredCamera, 'sideways');
    await store.setString(StorageKeys.captureRatio, 'panorama');

    final settings = await repository.load();

    expect(settings.themeMode, AppSettings.defaults.themeMode);
    expect(settings.preferredCamera, AppSettings.defaults.preferredCamera);
    expect(settings.captureRatio, AppSettings.defaults.captureRatio);
    expect(settings.showAlignmentGrid, AppSettings.defaults.showAlignmentGrid);
    expect(settings.hapticsEnabled, AppSettings.defaults.hapticsEnabled);
    expect(settings.showSensorSpill, AppSettings.defaults.showSensorSpill);
    expect(
      settings.defaultOverlayOpacity,
      AppSettings.defaults.defaultOverlayOpacity,
    );
  });

  group('SettingsController', () {
    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('mirrors the haptics preference onto the shared gate', () async {
      Haptics.enabled = true;
      final container = createContainer();

      await container.read(settingsControllerProvider.future);
      expect(Haptics.enabled, isTrue);

      await container
          .read(settingsControllerProvider.notifier)
          .setHapticsEnabled(false);
      expect(Haptics.enabled, isFalse);

      await container
          .read(settingsControllerProvider.notifier)
          .setHapticsEnabled(true);
      expect(Haptics.enabled, isTrue);
    });

    test('persists a change so it survives the next launch', () async {
      final container = createContainer();
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .setPreferredCamera(PreferredCamera.front);

      expect(
        await store.getString(StorageKeys.preferredCamera),
        PreferredCamera.front.name,
      );
    });
  });
}
