import 'dart:ui';

import 'package:camera_overlay/features/overlay/domain/overlay_fit_mode.dart';
import 'package:camera_overlay/features/overlay/presentation/providers/overlay_settings_provider.dart';
import 'package:camera_overlay/features/settings/domain/app_settings.dart';
import 'package:camera_overlay/features/settings/presentation/providers/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overlay_fakes.dart';

void main() {
  const viewport = Size(400, 800);
  late ProviderContainer container;

  OverlaySettingsController controller() =>
      container.read(overlaySettingsProvider.notifier);

  setUp(() async {
    container = ProviderContainer.test(
      overrides: [
        settingsControllerProvider.overrideWith(
          () => FakeSettingsController(
            const AppSettings(defaultOverlayOpacity: 0.6),
          ),
        ),
      ],
    );
    await container.read(settingsControllerProvider.future);
  });

  void drag(Offset translation, {double scale = 1, double rotation = 0}) {
    controller()
      ..beginGesture()
      ..updateGesture(
        viewport: viewport,
        translation: translation,
        scale: scale,
        rotation: rotation,
      )
      ..endGesture();
  }

  test('starts at the opacity chosen in Settings', () {
    expect(container.read(overlaySettingsProvider).opacity, 0.6);
  });

  group('opacity', () {
    test('clamps to 0–100% and reports the exact percentage', () {
      controller().setOpacity(1.7);
      expect(container.read(overlaySettingsProvider).opacityPercent, 100);

      controller().setOpacity(-1);
      expect(container.read(overlaySettingsProvider).opacityPercent, 0);

      controller().setOpacity(0.374);
      expect(container.read(overlaySettingsProvider).opacityPercent, 37);
    });

    test('presets and reset', () {
      expect(OverlaySettingsController.opacityPresets, <double>[
        0.25,
        0.5,
        0.75,
        1.0,
      ]);
      controller().setOpacity(0.25);
      controller().resetOpacity();
      expect(container.read(overlaySettingsProvider).opacity, 0.6);
    });

    test('changing opacity preserves the transform', () {
      drag(const Offset(40, 80), scale: 1.5, rotation: 0.4);
      final moved = container.read(overlaySettingsProvider);

      for (final value in <double>[0.1, 0.33, 0.9, 1.0]) {
        controller().setOpacity(value);
      }
      final after = container.read(overlaySettingsProvider);

      expect(after.offset, moved.offset);
      expect(after.scale, moved.scale);
      expect(after.rotation, moved.rotation);
      expect(after.fitMode, moved.fitMode);
    });

    test('an opacity change mid-gesture is not rolled back', () {
      controller()
        ..beginGesture()
        ..setOpacity(0.9)
        ..updateGesture(
          viewport: viewport,
          translation: const Offset(10, 0),
          scale: 1,
          rotation: 0,
        )
        ..endGesture();

      expect(container.read(overlaySettingsProvider).opacity, 0.9);
    });
  });

  group('transform', () {
    test('drag, pinch and rotate update the overlay', () {
      drag(const Offset(100, 200), scale: 2, rotation: 0.5);
      final settings = container.read(overlaySettingsProvider);

      expect(settings.offset, const Offset(0.25, 0.25));
      expect(settings.scale, 2);
      expect(settings.rotation, closeTo(0.5, 1e-12));
    });

    test('locking ignores gestures', () {
      controller().setLocked(true);
      drag(const Offset(100, 200), scale: 2);

      final settings = container.read(overlaySettingsProvider);
      expect(settings.offset, Offset.zero);
      expect(settings.scale, 1);
    });

    test('locking mid-gesture stops it', () {
      controller()
        ..beginGesture()
        ..setLocked(true)
        ..updateGesture(
          viewport: viewport,
          translation: const Offset(100, 0),
          scale: 1,
          rotation: 0,
        );
      expect(container.read(overlaySettingsProvider).offset, Offset.zero);
    });

    test('hidden overlays ignore gestures', () {
      controller().setVisible(false);
      drag(const Offset(100, 200));
      expect(container.read(overlaySettingsProvider).offset, Offset.zero);
    });

    test('fit modes and reset position clear the transform', () {
      drag(const Offset(100, 200), scale: 2, rotation: 0.5);
      controller().setFitMode(OverlayFitMode.fill);

      var settings = container.read(overlaySettingsProvider);
      expect(settings.fitMode, OverlayFitMode.fill);
      expect(settings.hasCustomTransform, isFalse);

      drag(const Offset(40, 0));
      controller().resetPosition();
      settings = container.read(overlaySettingsProvider);
      expect(settings.fitMode, OverlayFitMode.fill);
      expect(settings.hasCustomTransform, isFalse);
    });

    test('a new image resets framing but keeps the opacity', () {
      controller()
        ..setOpacity(0.3)
        ..setFitMode(OverlayFitMode.center)
        ..setLocked(true)
        ..setVisible(false)
        ..resetForNewImage();

      final settings = container.read(overlaySettingsProvider);
      expect(settings.opacity, 0.3);
      expect(settings.fitMode, OverlayFitMode.fit);
      expect(settings.isLocked, isFalse);
      expect(settings.isVisible, isTrue);
    });
  });
}
