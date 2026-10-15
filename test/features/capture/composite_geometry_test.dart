import 'dart:math' as math;

import 'package:camera_overlay/features/capture/domain/composite_geometry.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_fit_mode.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher offsetCloseTo(Offset expected, [double tolerance = 1e-6]) =>
    predicate<Offset>(
      (o) =>
          (o.dx - expected.dx).abs() < tolerance &&
          (o.dy - expected.dy).abs() < tolerance,
      'close to $expected',
    );

void main() {
  group('place', () {
    test('identity: preview exactly covers the viewport and matches the '
        'photo', () {
      final placement = CompositeGeometry.place(
        frame: const PreviewFrame(
          viewport: Size(400, 800),
          previewAspectRatio: 0.5,
          devicePixelRatio: 2,
        ),
        photoSize: const Size(1000, 2000),
        imageSize: const Size(100, 200),
        settings: const OverlaySettings(),
      );

      // A fitted 1:2 reference fills a 1:2 viewport, so it fills the photo.
      expect(placement.center, offsetCloseTo(const Offset(500, 1000)));
      expect(placement.size.width, closeTo(1000, 1e-6));
      expect(placement.size.height, closeTo(2000, 1e-6));
      expect(placement.rotation, 0);
      expect(placement.flipHorizontally, isFalse);
    });

    test('cover crop: the cropped preview edges map back into the photo', () {
      // A 9:16 preview covering a 360x800 viewport is shown 450x800, cropping
      // 45pt on each side; the 1080x1920 photo is 2.4x the displayed preview.
      const frame = PreviewFrame(
        viewport: Size(360, 800),
        previewAspectRatio: 9 / 16,
        devicePixelRatio: 3,
      );

      final centred = CompositeGeometry.place(
        frame: frame,
        photoSize: const Size(1080, 1920),
        imageSize: const Size(90, 160),
        settings: const OverlaySettings(),
      );
      expect(centred.center, offsetCloseTo(const Offset(540, 960)));

      final shifted = CompositeGeometry.place(
        frame: frame,
        photoSize: const Size(1080, 1920),
        imageSize: const Size(90, 160),
        settings: const OverlaySettings(offset: Offset(0.25, -0.1)),
      );
      // Viewport centre x = 180 + 0.25 * 360 = 270 -> (270 + 45) * 2.4.
      // Viewport centre y = 400 - 0.1 * 800 = 320 -> 320 * 2.4.
      expect(shifted.center, offsetCloseTo(const Offset(756, 768)));
    });

    test('scale and rotation carry over, scaled to photo pixels', () {
      final placement = CompositeGeometry.place(
        frame: const PreviewFrame(
          viewport: Size(400, 800),
          previewAspectRatio: 0.5,
          devicePixelRatio: 2,
        ),
        photoSize: const Size(2000, 4000),
        imageSize: const Size(100, 100),
        settings: const OverlaySettings(scale: 1.5, rotation: 0.3),
      );

      // Fit: 400x400 in the viewport, x1.5, then x5 into the photo.
      expect(placement.size.width, closeTo(3000, 1e-6));
      expect(placement.rotation, closeTo(0.3, 1e-12));
    });

    test('aspect mismatch: a 4:3 photo behind a 9:16 preview shares the long '
        'side', () {
      final frame = const PreviewFrame(
        viewport: Size(360, 640),
        previewAspectRatio: 9 / 16,
        devicePixelRatio: 3,
      );
      OverlayPlacement at(Offset offset) => CompositeGeometry.place(
        frame: frame,
        photoSize: const Size(3024, 4032),
        imageSize: const Size(10, 10),
        settings: OverlaySettings(
          offset: offset,
          fitMode: OverlayFitMode.center,
        ),
      );

      // The preview is the centred 2268x4032 strip of the photo.
      expect(at(Offset.zero).center, offsetCloseTo(const Offset(1512, 2016)));
      expect(
        at(const Offset(-0.5, -0.5)).center,
        offsetCloseTo(const Offset(378, 0)),
      );
    });

    test('front camera: placement and rotation are mirrored', () {
      final placement = CompositeGeometry.place(
        frame: const PreviewFrame(
          viewport: Size(400, 800),
          previewAspectRatio: 0.5,
          devicePixelRatio: 2,
          mirrored: true,
        ),
        photoSize: const Size(1000, 2000),
        imageSize: const Size(10, 10),
        settings: const OverlaySettings(offset: Offset(0.25, 0), rotation: 0.4),
      );

      // On screen the overlay sat at 75% across; in the unmirrored photo it
      // belongs at 25%.
      expect(placement.center, offsetCloseTo(const Offset(250, 1000)));
      expect(placement.rotation, closeTo(-0.4, 1e-12));
      expect(placement.flipHorizontally, isTrue);
    });

    test('quarter turn: screen-portrait frame rotates into a landscape '
        'photo', () {
      OverlayPlacement at(Offset offset) => CompositeGeometry.place(
        frame: const PreviewFrame(
          viewport: Size(400, 800),
          previewAspectRatio: 0.5,
          devicePixelRatio: 2,
          quarterTurns: 1,
        ),
        photoSize: const Size(2000, 1000),
        imageSize: const Size(10, 10),
        settings: OverlaySettings(
          offset: offset,
          fitMode: OverlayFitMode.center,
        ),
      );

      // The screen's top-left corner ends up top-right after a clockwise turn.
      expect(
        at(const Offset(-0.5, -0.5)).center,
        offsetCloseTo(const Offset(2000, 0)),
      );
      expect(at(Offset.zero).center, offsetCloseTo(const Offset(1000, 500)));
      expect(at(Offset.zero).rotation, closeTo(math.pi / 2, 1e-12));
    });
  });

  group('quarterTurnsBetween', () {
    test('no turn when the screen follows the device', () {
      expect(
        CompositeGeometry.quarterTurnsBetween(
          device: DeviceOrientation.portraitUp,
          screenIsLandscape: false,
        ),
        0,
      );
      expect(
        CompositeGeometry.quarterTurnsBetween(
          device: DeviceOrientation.landscapeRight,
          screenIsLandscape: true,
        ),
        0,
      );
    });

    test('rotation-locked portrait screen, device turned sideways', () {
      // landscapeLeft is the device turned counterclockwise; the upright photo
      // is the screen image turned back, i.e. three clockwise quarter turns.
      expect(
        CompositeGeometry.quarterTurnsBetween(
          device: DeviceOrientation.landscapeLeft,
          screenIsLandscape: false,
        ),
        3,
      );
      expect(
        CompositeGeometry.quarterTurnsBetween(
          device: DeviceOrientation.landscapeRight,
          screenIsLandscape: false,
        ),
        1,
      );
    });
  });
}
