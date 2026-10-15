import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:camera_overlay/core/errors/app_exception.dart';
import 'package:camera_overlay/features/camera/domain/camera_capabilities.dart';
import 'package:camera_overlay/features/camera/domain/camera_errors.dart';
import 'package:camera_overlay/features/camera/domain/camera_flash_mode.dart';
import 'package:camera_overlay/features/camera/domain/camera_selection.dart';
import 'package:camera_overlay/features/camera/domain/preview_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);
const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);
const _external = CameraDescription(
  name: 'usb',
  lensDirection: CameraLensDirection.external,
  sensorOrientation: 0,
);

void main() {
  group('camera selection', () {
    test('prefers the rear camera wherever it is listed', () {
      expect(selectDefaultCamera(<CameraDescription>[_front, _back]), _back);
      expect(indexOfDefaultCamera(<CameraDescription>[_front, _back]), 1);
    });

    test('falls back to the first camera without a rear one', () {
      expect(
        selectDefaultCamera(<CameraDescription>[_front, _external]),
        _front,
      );
      expect(selectDefaultCamera(<CameraDescription>[]), isNull);
    });

    test('cycles through cameras', () {
      expect(nextCameraIndex(0, 2), 1);
      expect(nextCameraIndex(1, 2), 0);
      expect(nextCameraIndex(0, 0), 0);
    });
  });

  group('flash modes', () {
    test('includes torch only when supported', () {
      expect(
        nextFlashMode(CameraFlashMode.on, includeTorch: true),
        CameraFlashMode.torch,
      );
      expect(
        nextFlashMode(CameraFlashMode.on, includeTorch: false),
        CameraFlashMode.off,
      );
    });

    test('maps to platform modes', () {
      expect(CameraFlashMode.on.platform, FlashMode.always);
      expect(CameraFlashMode.torch.platform, FlashMode.torch);
    });
  });

  group('capabilities', () {
    test('front cameras have no flash or torch', () {
      final front = CameraCapabilities.fromLensDirection(
        CameraLensDirection.front,
      );
      expect(front.supportsFlash, isFalse);
      expect(front.supportsTorch, isFalse);
    });

    test('zoom range is sanitized and capped', () {
      const base = CameraCapabilities();

      final wide = base.withZoomRange(0.6, 30);
      expect(wide.minZoom, 0.6);
      expect(wide.maxZoom, CameraCapabilities.maxUsefulZoom);
      expect(wide.initialZoom, 1.0);

      final fixed = base.withZoomRange(1, 1);
      expect(fixed.supportsZoom, isFalse);

      final broken = base.withZoomRange(double.nan, double.infinity);
      expect(broken.minZoom, 1.0);
      expect(broken.maxZoom, 1.0);
    });

    test('clamps zoom into range', () {
      final caps = const CameraCapabilities().withZoomRange(1, 4);
      expect(caps.clampZoom(0.2), 1);
      expect(caps.clampZoom(9), 4);
    });
  });

  group('cover mapping', () {
    test('maps the viewport center to the preview center', () {
      final point = coverPointToPreview(
        point: const Offset(200, 400),
        viewport: const Size(400, 800),
        preview: const Size(3, 4),
      );
      expect(point, const Offset(0.5, 0.5));
    });

    test('accounts for the cropped overflow', () {
      // A 3:4 preview covering 400x800 is scaled to 600x800, cropping 100px
      // on each side, so the viewport's left edge is 1/6 into the preview.
      final point = coverPointToPreview(
        point: const Offset(0, 0),
        viewport: const Size(400, 800),
        preview: const Size(3, 4),
      )!;
      expect(point.dx, closeTo(1 / 6, 1e-9));
      expect(point.dy, 0);
    });

    test('rejects degenerate sizes', () {
      expect(
        coverPointToPreview(
          point: Offset.zero,
          viewport: const Size(400, 800),
          preview: Size.zero,
        ),
        isNull,
      );
    });
  });

  test('recognizes access-denied camera errors', () {
    expect(
      isCameraAccessDenied(
        CameraFailure(
          'denied',
          cause: CameraException('CameraAccessDenied', ''),
        ),
      ),
      isTrue,
    );
    expect(
      isCameraAccessDenied(CameraException('cameraNotFound', '')),
      isFalse,
    );
    expect(isCameraAccessDenied(const CameraFailure('none')), isFalse);
  });

  test('classifies runtime camera errors per platform', () {
    expect(
      isFatalRuntimeCameraError(
        'The camera was closed due to a fatal error.',
        android: true,
      ),
      isTrue,
    );
    expect(
      isFatalRuntimeCameraError(
        'The camera was already in use, possibly by a higher-priority client.',
        android: true,
      ),
      isFalse,
    );
    expect(isFatalRuntimeCameraError(null, android: true), isFalse);
    expect(isFatalRuntimeCameraError('Session error', android: false), isTrue);
  });
}
