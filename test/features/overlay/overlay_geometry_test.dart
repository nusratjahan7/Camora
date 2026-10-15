import 'dart:math' as math;
import 'dart:ui';

import 'package:camera_overlay/features/overlay/domain/overlay_fit_mode.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_geometry.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(400, 800);
  const landscapeImage = Size(4000, 3000);

  Size base(OverlayFitMode mode, {Size image = landscapeImage}) =>
      OverlayGeometry.baseSize(
        image: image,
        viewport: viewport,
        mode: mode,
        devicePixelRatio: 2,
      );

  group('base size', () {
    test('fit shows the whole image inside the viewport', () {
      final size = base(OverlayFitMode.fit);
      expect(size.width, 400);
      expect(size.height, 300);
    });

    test('fill covers the viewport and crops the overflow', () {
      final size = base(OverlayFitMode.fill);
      expect(size.height, 800);
      expect(size.width, closeTo(1066.67, 0.01));
    });

    test('center uses original pixels mapped to logical pixels', () {
      expect(base(OverlayFitMode.center), const Size(2000, 1500));
    });

    test('every mode preserves the aspect ratio', () {
      for (final mode in OverlayFitMode.values) {
        final size = base(mode, image: const Size(1080, 1920));
        expect(size.width / size.height, closeTo(1080 / 1920, 1e-9));
      }
    });

    test('degenerate sizes produce an empty box', () {
      expect(base(OverlayFitMode.fit, image: Size.zero), Size.zero);
    });
  });

  group('gestures', () {
    const start = OverlaySettings(opacity: 0.4);

    test('translation is stored as a fraction of the viewport', () {
      final next = OverlayGeometry.applyGesture(
        start: start,
        viewport: viewport,
        translation: const Offset(100, -200),
        scale: 1,
        rotation: 0,
      );
      expect(next.offset, const Offset(0.25, -0.25));
      expect(next.opacity, 0.4);
    });

    test('keeps the image center on screen', () {
      final next = OverlayGeometry.applyGesture(
        start: start,
        viewport: viewport,
        translation: const Offset(5000, 5000),
        scale: 1,
        rotation: 0,
      );
      expect(next.offset, const Offset(0.5, 0.5));
    });

    test('scale multiplies the starting scale within limits', () {
      OverlaySettings pinch(double factor) => OverlayGeometry.applyGesture(
        start: start.copyWith(scale: 2),
        viewport: viewport,
        translation: Offset.zero,
        scale: factor,
        rotation: 0,
      );
      expect(pinch(1.5).scale, 3);
      expect(pinch(100).scale, OverlayGeometry.maxScale);
      expect(pinch(0.001).scale, OverlayGeometry.minScale);
    });

    test('rotation accumulates', () {
      final next = OverlayGeometry.applyGesture(
        start: start.copyWith(rotation: 0.5),
        viewport: viewport,
        translation: Offset.zero,
        scale: 1,
        rotation: 0.25,
      );
      expect(next.rotation, 0.75);
    });
  });

  group('rotation settling', () {
    test('snaps near quarter turns', () {
      expect(OverlayGeometry.settleRotation(0.03), 0);
      expect(
        OverlayGeometry.settleRotation(math.pi / 2 + 0.03),
        closeTo(math.pi / 2, 1e-12),
      );
    });

    test('leaves deliberate angles alone and normalizes full turns', () {
      expect(OverlayGeometry.settleRotation(0.5), closeTo(0.5, 1e-12));
      expect(
        OverlayGeometry.settleRotation(2 * math.pi + 0.5),
        closeTo(0.5, 1e-12),
      );
      expect(OverlayGeometry.settleRotation(-math.pi), closeTo(math.pi, 1e-12));
    });
  });
}
