import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera_overlay/core/errors/app_exception.dart';
import 'package:camera_overlay/core/files/file_service.dart';
import 'package:camera_overlay/features/camera/domain/camera_flash_mode.dart';
import 'package:camera_overlay/features/camera/domain/camera_session.dart';
import 'package:camera_overlay/features/camera/presentation/providers/camera_providers.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_camera_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late FakeCameraPlatform platform;
  late ProviderContainer container;
  ProviderSubscription<AsyncValue<CameraSession>>? keepAlive;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('camera_session_test');
    platform = FakeCameraPlatform(captureDirectory: temp);
    CameraPlatform.instance = platform;
    container = ProviderContainer(
      overrides: [fileServiceProvider.overrideWithValue(TempFileService(temp))],
    );
    keepAlive = null;
  });

  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    await temp.delete(recursive: true);
  });

  /// Starts the session on first use, after the test configured the fake,
  /// and keeps the auto-dispose provider alive for the rest of the test.
  Future<CameraSession> session() {
    keepAlive ??= container.listen(cameraSessionProvider, (_, _) {});
    return container.read(cameraSessionProvider.future);
  }

  CameraSessionController notifier() =>
      container.read(cameraSessionProvider.notifier);

  Future<CameraSession> settled() async {
    for (var i = 0; i < 50; i++) {
      final state = container.read(cameraSessionProvider);
      if (!state.isLoading && state.hasValue && !state.hasError) {
        return state.requireValue;
      }
      await Future<void>.delayed(Duration.zero);
    }
    fail(
      'Camera session never settled: ${container.read(cameraSessionProvider)}',
    );
  }

  group('opening', () {
    test('selects the rear camera by default', () async {
      final current = await session();

      expect(current.description, rearCamera);
      expect(current.isFrontFacing, isFalse);
      expect(current.canSwitchCamera, isTrue);
      expect(current.controller.value.isInitialized, isTrue);
    });

    test('fails with a CameraFailure when the device has no camera', () async {
      platform.cameras = <CameraDescription>[];

      await expectLater(session(), throwsA(isA<CameraFailure>()));
    });

    test('turns raw camera-listing errors into a readable failure', () async {
      platform.listError = PlatformException(
        code: 'error',
        message: 'androidx.camera.core.CameraUnavailableException: ...',
      );

      await expectLater(
        session(),
        throwsA(
          isA<CameraFailure>().having(
            (failure) => failure.message,
            'message',
            isNot(contains('androidx')),
          ),
        ),
      );
    });

    test('reports initialization failures and recovers on retry', () async {
      platform.nextInitializeError = CameraException('CameraAccessDenied', '');

      await expectLater(session(), throwsA(isA<CameraFailure>()));
      expect(platform.liveCameras, isEmpty);

      container.invalidate(cameraSessionProvider);
      final recovered = await session();

      expect(recovered.controller.value.isInitialized, isTrue);
      expect(platform.liveCameras, hasLength(1));
    });

    test('starts at 1x and caps absurd zoom ranges', () async {
      platform
        ..minZoom = 0.5
        ..maxZoom = 100;

      final current = await session();

      expect(current.zoom, 1.0);
      expect(current.capabilities.minZoom, 0.5);
      expect(current.capabilities.maxZoom, 10.0);
    });

    test(
      'applies the flash mode explicitly so the UI matches hardware',
      () async {
        final current = await session();

        expect(current.flashMode, CameraFlashMode.off);
        expect(platform.flashCalls.last.$2, FlashMode.off);
      },
    );
  });

  group('switching', () {
    test('switches to the front camera and releases the rear one', () async {
      final rear = await session();
      final rearId = rear.controller.cameraId;

      await notifier().switchCamera();
      final front = await settled();

      expect(front.description, frontCamera);
      expect(platform.disposed, contains(rearId));
      expect(platform.liveCameras, hasLength(1));
      expect(front.capabilities.supportsFlash, isFalse);
    });

    test('keeps the preferred flash mode across cameras', () async {
      await session();
      await notifier().setFlashMode(CameraFlashMode.on);

      await notifier().switchCamera();
      expect((await settled()).flashMode, CameraFlashMode.off);

      await notifier().switchCamera();
      expect((await settled()).flashMode, CameraFlashMode.on);
    });
  });

  group('capture', () {
    test('stores the photo in the captures directory', () async {
      await session();

      final file = await notifier().capture();

      expect(file, isNotNull);
      expect(File(file!.path).existsSync(), isTrue);
      expect(file.path, startsWith(temp.path));
      expect((await settled()).lastCapture?.path, file.path);
      expect((await settled()).isCapturing, isFalse);
    });

    test('ignores a second capture while one is running', () async {
      await session();
      platform.captureGate = Completer<void>();

      final first = notifier().capture();
      final second = await notifier().capture();
      expect(second, isNull);
      expect(
        container.read(cameraSessionProvider).requireValue.isCapturing,
        isTrue,
      );

      platform.captureGate!.complete();
      expect(await first, isNotNull);
      expect(platform.captureCount, 1);
    });
  });

  group('controls', () {
    test('cycles flash through torch on the rear camera', () async {
      await session();
      final seen = <CameraFlashMode>[];
      for (var i = 0; i < 4; i++) {
        await notifier().cycleFlashMode();
        seen.add((await settled()).flashMode);
      }

      expect(seen, <CameraFlashMode>[
        CameraFlashMode.auto,
        CameraFlashMode.on,
        CameraFlashMode.torch,
        CameraFlashMode.off,
      ]);
    });

    test('hides flash when the hardware rejects it', () async {
      platform.flashFailsFor.add('rear');

      final current = await session();

      expect(current.capabilities.supportsFlash, isFalse);
      expect(current.flashMode, CameraFlashMode.off);
    });

    test('clamps zoom to the supported range', () async {
      await session();

      await notifier().setZoom(50);

      expect((await settled()).zoom, 8.0);
      expect(platform.zoomCalls.last.$2, 8.0);
    });

    test('focuses and meters at the tapped point', () async {
      final current = await session();

      final focused = await notifier().focusAt(const Offset(0.25, 0.75));

      expect(focused, isTrue);
      final id = current.controller.cameraId;
      expect(platform.focusPoints.last, (id, const Point<double>(0.25, 0.75)));
      expect(platform.exposurePoints.last.$2, const Point<double>(0.25, 0.75));
    });

    test('stops offering tap-to-focus after the camera rejects it', () async {
      platform.focusError = CameraException('IllegalArgumentException', '');
      await session();

      expect(await notifier().focusAt(const Offset(0.5, 0.5)), isFalse);
      expect((await settled()).capabilities.supportsTapToFocus, isFalse);
    });

    test(
      'reports tap-to-focus as unsupported when the camera lacks it',
      () async {
        platform
          ..focusPointSupported = false
          ..exposurePointSupported = false;
        await session();

        expect(await notifier().focusAt(const Offset(0.5, 0.5)), isFalse);
        expect(platform.focusPoints, isEmpty);
      },
    );
  });

  group('lifecycle', () {
    test(
      'releases the camera when backgrounded and reopens on resume',
      () async {
        final before = await session();
        await notifier().setZoom(3);

        await notifier().handleAppLifecycle(AppLifecycleState.inactive);
        expect(platform.liveCameras, isEmpty);
        expect(container.read(cameraSessionProvider).isLoading, isTrue);

        await notifier().handleAppLifecycle(AppLifecycleState.resumed);
        final after = await settled();

        expect(after.controller, isNot(same(before.controller)));
        expect(after.description, before.description);
        expect(after.zoom, 3);
        expect(platform.liveCameras, hasLength(1));
      },
    );

    test('ignores capture while paused', () async {
      await session();
      await notifier().handleAppLifecycle(AppLifecycleState.paused);

      expect(await notifier().capture(), isNull);
      expect(platform.captureCount, 0);
    });

    test('a pause during startup defers opening until resume', () async {
      final pending = session();
      await notifier().handleAppLifecycle(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(platform.liveCameras, isEmpty);

      await notifier().handleAppLifecycle(AppLifecycleState.resumed);
      final opened = await pending;

      expect(opened.controller.value.isInitialized, isTrue);
      expect(platform.liveCameras, hasLength(1));
    });

    test('disposing the provider releases the camera', () async {
      await session();

      keepAlive!.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(platform.liveCameras, isEmpty);
    });
  });

  group('runtime errors', () {
    // flutter_test reports Android as the target platform.
    test('fatal CameraX errors end the session', () async {
      final current = await session();

      platform.emitError(
        current.controller.cameraId,
        'The camera was closed due to a fatal error.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(cameraSessionProvider);
      expect(state.error, isA<CameraFailure>());
      expect(platform.liveCameras, isEmpty);
    });

    test('a missing flash unit hides the flash control', () async {
      final current = await session();
      await notifier().setFlashMode(CameraFlashMode.torch);

      platform.emitError(
        current.controller.cameraId,
        'java.lang.IllegalStateException: No flash unit',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final updated = await settled();
      expect(updated.capabilities.supportsFlash, isFalse);
      expect(updated.flashMode, CameraFlashMode.off);
      expect(updated.controller, same(current.controller));
    });

    test('recoverable CameraX errors keep the session', () async {
      final current = await session();

      platform.emitError(
        current.controller.cameraId,
        'The camera device has encountered a recoverable error.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(cameraSessionProvider);
      expect(state.hasError, isFalse);
      expect(state.requireValue.controller, same(current.controller));
      expect(platform.liveCameras, hasLength(1));
    });
  });

  test('state leaves the session before its controller is disposed', () async {
    await session();
    final statesAtDispose = <AsyncValue<CameraSession>>[];
    platform.onDispose = (_) =>
        statesAtDispose.add(container.read(cameraSessionProvider));

    await notifier().handleAppLifecycle(AppLifecycleState.paused);

    expect(statesAtDispose, hasLength(1));
    expect(statesAtDispose.single.isLoading, isTrue);
  });
}
