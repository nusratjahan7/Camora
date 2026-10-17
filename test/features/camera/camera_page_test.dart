import 'dart:io';

import 'package:camera_overlay/core/files/file_service.dart';
import 'package:camera_overlay/core/permissions/app_permission.dart';
import 'package:camera_overlay/core/permissions/permission_service.dart';
import 'package:camera_overlay/features/gallery/data/gallery_saver_service.dart';
import 'package:camera_overlay/features/settings/presentation/providers/settings_controller.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';

import '../overlay/overlay_fakes.dart' show FakeSettingsController;
import '../../helpers/camera_test_app.dart';
import '../../helpers/fake_gallery.dart';
import 'fakes/fake_camera_platform.dart';

class FakePermissionService implements PermissionService {
  FakePermissionService(this.current, {AppPermissionStatus? onRequest})
    : onRequest = onRequest ?? current;

  AppPermissionStatus current;
  AppPermissionStatus onRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async => current;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requests++;
    return current = onRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  late Directory temp;
  late FakeCameraPlatform platform;
  late FakeGallerySaver gallery;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('camera_page_test');
    platform = FakeCameraPlatform(captureDirectory: temp);
    CameraPlatform.instance = platform;
    gallery = FakeGallerySaver();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Future<void> pumpPage(
    WidgetTester tester,
    FakePermissionService permissions,
  ) {
    return pumpCameraApp(
      tester,
      overrides: [
        permissionServiceProvider.overrideWithValue(permissions),
        fileServiceProvider.overrideWithValue(TempFileService(temp)),
        gallerySaverServiceProvider.overrideWithValue(gallery),
        // The camera screen reads overlay defaults from Settings.
        settingsControllerProvider.overrideWith(FakeSettingsController.new),
      ],
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  final shutter = find.byKey(const ValueKey<String>('camera-shutter'));

  group('permission', () {
    testWidgets('asks with a rationale first, then shows the preview', (
      tester,
    ) async {
      final permissions = FakePermissionService(
        AppPermissionStatus.denied,
        onRequest: AppPermissionStatus.granted,
      );
      await pumpPage(tester, permissions);
      await settle(tester);

      expect(find.text('Allow camera access'), findsWidgets);
      expect(permissions.requests, 0);

      await tester.tap(find.text('Continue'));
      await settle(tester);

      expect(permissions.requests, 1);
      expect(shutter, findsOneWidget);
    });

    testWidgets('permanent denial points to system settings', (tester) async {
      final permissions = FakePermissionService(
        AppPermissionStatus.permanentlyDenied,
      );
      await pumpPage(tester, permissions);
      await settle(tester);

      expect(find.text('Camera access is blocked'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      await tester.tap(find.text('Open settings'));
      expect(permissions.settingsOpened, 1);
    });

    testWidgets('re-checks permission when returning from settings', (
      tester,
    ) async {
      final permissions = FakePermissionService(
        AppPermissionStatus.permanentlyDenied,
      );
      await pumpPage(tester, permissions);
      await settle(tester);

      permissions.current = AppPermissionStatus.granted;
      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);

      expect(shutter, findsOneWidget);
    });

    testWidgets('restricted access offers no prompt', (tester) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.restricted),
      );
      await settle(tester);

      expect(find.text('Camera access is restricted'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });
  });

  group('camera', () {
    testWidgets('shows controls for the rear camera', (tester) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      expect(shutter, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('camera-flash')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('camera-zoom')), findsOneWidget);
      expect(find.byTooltip('Switch to front camera'), findsOneWidget);
    });

    testWidgets('zoom stops jump to a lens and dragging zooms smoothly', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      // The fake reports 1x–8x, so the stops are 1×, 2 and 5.
      expect(find.text('1×'), findsOneWidget);
      await tester.tap(find.text('2'));
      await settle(tester);
      expect(platform.zoomCalls.last.$2, 2);
      expect(find.text('2×'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey<String>('camera-zoom')),
        const Offset(120, 0),
      );
      await settle(tester);
      expect(platform.zoomCalls.last.$2, greaterThan(3));
    });

    testWidgets('switching to the front camera hides the flash control', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey<String>('camera-switch')));
      await settle(tester);

      expect(find.byTooltip('Switch to rear camera'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('camera-flash')), findsNothing);
    });

    testWidgets('shows an error with retry when the camera fails to start', (
      tester,
    ) async {
      platform.nextInitializeError = CameraException('CameraAccessDenied', '');
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await settle(tester);

      expect(shutter, findsOneWidget);
    });

    testWidgets('shows an error when the device has no camera', (tester) async {
      platform.cameras = <CameraDescription>[];
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      expect(
        find.text('No camera is available on this device.'),
        findsOneWidget,
      );
    });

    /// Captures once, waiting for the shutter's save to reach the gallery.
    Future<void> captureOnce(WidgetTester tester) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);
      // Capture and save touch real files, which need the real event loop.
      await tester.runAsync(() async {
        await tester.tap(shutter);
        for (var i = 0; i < 100 && gallery.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await settle(tester);
    }

    /// Working copies left behind in the captures directory.
    List<String> storedPhotos() => temp
        .listSync()
        .map((f) => f.path)
        .where((path) => path.contains('Veylora_'))
        .toList();

    testWidgets('the shutter saves the camera image byte for byte and stays '
        'on the camera', (tester) async {
      await captureOnce(tester);

      expect(platform.captureCount, 1);
      // The camera's own image, never the preview or the reference overlay.
      expect(gallery.saved.single, platform.pictureBytes);
      expect(find.text('Saved to Gallery'), findsOneWidget);
      // No review screen: still on the live camera, working copy cleaned up.
      expect(shutter, findsOneWidget);
      expect(platform.liveCameras, hasLength(1));
      expect(storedPhotos(), isEmpty);
    });

    testWidgets('a capture that cannot be saved explains itself and leaves the '
        'camera usable', (tester) async {
      gallery.nextError = GalException(
        type: GalExceptionType.notEnoughSpace,
        platformException: PlatformException(code: 'TEST'),
        stackTrace: StackTrace.current,
      );
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      await tester.runAsync(() async {
        await tester.tap(shutter);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await settle(tester);

      expect(gallery.saved, isEmpty);
      expect(find.textContaining('storage'), findsOneWidget);
      expect(shutter, findsOneWidget);
      expect(storedPhotos(), isEmpty);
    });

    testWidgets('saving without library access asks first and stops when '
        'declined', (tester) async {
      gallery.access = false;
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      await tester.runAsync(() async {
        await tester.tap(shutter);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await settle(tester);

      // Nothing reaches the gallery before the user sees the rationale.
      expect(find.text('Continue'), findsOneWidget);
      expect(gallery.saved, isEmpty);

      await tester.tap(find.text('Not now'));
      await settle(tester);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);

      expect(gallery.accessRequests, 0);
      expect(gallery.saved, isEmpty);
      expect(storedPhotos(), isEmpty);
    });

    testWidgets('granting access after the rationale saves the capture', (
      tester,
    ) async {
      gallery.access = false;
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      await tester.runAsync(() async {
        await tester.tap(shutter);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await settle(tester);

      await tester.tap(find.text('Continue'));
      await settle(tester);

      await tester.runAsync(() async {
        for (var i = 0; i < 50 && gallery.saved.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await settle(tester);

      expect(gallery.accessRequests, 1);
      expect(gallery.saved.single, platform.pictureBytes);
      expect(shutter, findsOneWidget);
    });

    testWidgets('releases the camera in the background and reopens it', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);
      expect(platform.liveCameras, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      expect(platform.liveCameras, isEmpty);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(platform.liveCameras, hasLength(1));
      expect(shutter, findsOneWidget);
    });
  });
}
