import 'dart:io';

import 'package:camera_overlay/core/constants/storage_keys.dart';
import 'package:camera_overlay/core/files/file_service.dart';
import 'package:camera_overlay/core/permissions/app_permission.dart';
import 'package:camera_overlay/core/permissions/permission_service.dart';
import 'package:camera_overlay/core/storage/shared_preferences_store.dart';
import 'package:camera_overlay/features/camera/presentation/pages/camera_page.dart';
import 'package:camera_overlay/features/camera/presentation/providers/camera_providers.dart';
import 'package:camera_overlay/features/camera/presentation/widgets/alignment_grid.dart';
import 'package:camera_overlay/features/gallery/data/gallery_saver_service.dart';
import 'package:camera_overlay/features/settings/domain/app_settings.dart';
import 'package:camera_overlay/features/settings/domain/capture_ratio.dart';
import 'package:camera_overlay/features/settings/presentation/providers/settings_controller.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../overlay/overlay_fakes.dart' show FakeSettingsController;
import '../../helpers/camera_test_app.dart';
import '../../helpers/fake_gallery.dart';
import '../../helpers/fake_key_value_store.dart';
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
  late FakeKeyValueStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('camera_page_test');
    platform = FakeCameraPlatform(captureDirectory: temp);
    CameraPlatform.instance = platform;
    gallery = FakeGallerySaver();
    store = FakeKeyValueStore();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Future<void> pumpPage(
    WidgetTester tester,
    FakePermissionService permissions, {
    AppSettings settings = AppSettings.defaults,
  }) {
    return pumpCameraApp(
      tester,
      overrides: [
        permissionServiceProvider.overrideWithValue(permissions),
        fileServiceProvider.overrideWithValue(TempFileService(temp)),
        gallerySaverServiceProvider.overrideWithValue(gallery),
        keyValueStoreProvider.overrideWithValue(store),
        // The camera screen reads the capture ratio and overlay defaults from
        // Settings.
        settingsControllerProvider.overrideWith(
          () => FakeSettingsController(settings),
        ),
      ],
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  final shutter = find.byKey(const ValueKey<String>('camera-shutter'));
  // The rule-of-thirds guide paints exactly one CustomPaint when visible.
  final gridPainter = find.descendant(
    of: find.byType(AlignmentGridLayer),
    matching: find.byType(CustomPaint),
  );

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

    testWidgets('the grid toggle drives and stores the alignment grid', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      // The default is on, and the guide is painted over the preview.
      expect(find.byIcon(Icons.grid_on_rounded), findsOneWidget);
      expect(gridPainter, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('camera-grid')));
      await settle(tester);

      expect(find.byIcon(Icons.grid_off_rounded), findsOneWidget);
      expect(gridPainter, findsNothing);
      expect(await store.getBool(StorageKeys.showAlignmentGrid), isFalse);

      await tester.tap(find.byKey(const ValueKey<String>('camera-grid')));
      await settle(tester);

      expect(find.byIcon(Icons.grid_on_rounded), findsOneWidget);
      expect(gridPainter, findsOneWidget);
      expect(await store.getBool(StorageKeys.showAlignmentGrid), isTrue);
    });

    testWidgets('the gallery shortcut opens the app gallery', (tester) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey<String>('camera-gallery')));
      await settle(tester);

      expect(
        find.byKey(const ValueKey<String>('test-gallery-route')),
        findsOneWidget,
      );
      expect(find.byType(CameraPage), findsNothing);
    });

    testWidgets('the ratio control cycles the framing and stores the choice', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      // 4:3 by default, and the caption shows the stream cropped to it.
      expect(find.text('4:3'), findsOneWidget);
      expect(find.text('1080×1920 → 1080×810'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('camera-ratio')));
      await settle(tester);

      expect(find.text('16:9'), findsOneWidget);
      expect(await store.getString(StorageKeys.captureRatio), 'widescreen169');
      // The caption tracks the new frame rather than the old one.
      expect(find.text('1080×1920 → 1080×810'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('camera-ratio')));
      await settle(tester);
      expect(find.text('1:1'), findsOneWidget);
    });

    testWidgets('filming records a clip into the gallery', (tester) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      // Video mode reopens the camera with audio and takes the ratio control
      // out of play, since a clip records at the camera's native ratio.
      await tester.tap(find.byKey(const ValueKey<String>('camera-mode')));
      await settle(tester);
      expect(platform.audioRequested.values, contains(isTrue));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // The shutter turns into a record button, then into a stop button with a
      // running clock once filming starts.
      expect(find.bySemanticsLabel('Start recording'), findsOneWidget);
      await tester.tap(shutter);
      await settle(tester);
      expect(find.bySemanticsLabel('Stop recording'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('camera-recording-timer')),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        await tester.tap(shutter);
        // Stopping writes and files the clip, which needs the real loop.
        for (var i = 0; i < 200 && gallery.savedVideos.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await settle(tester);

      expect(platform.startRecordingCount, 1);
      expect(platform.stopRecordingCount, 1);
      expect(gallery.savedVideos.single, endsWith('.mp4'));
      expect(
        await store.getString(StorageKeys.galleryHistory),
        contains('"kind":"video"'),
      );
      // Back to a record button, and the clock is gone.
      expect(find.bySemanticsLabel('Start recording'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('camera-recording-timer')),
        findsNothing,
      );
    });

    testWidgets('changing the ratio never restarts the camera', (tester) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CameraPage)),
      );
      final before = container
          .read(cameraSessionProvider)
          .requireValue
          .controller;

      for (var i = 0; i < CaptureRatio.values.length; i++) {
        await tester.tap(find.byKey(const ValueKey<String>('camera-ratio')));
        await settle(tester);
      }

      // Same controller, same live camera: the ratio is pure layout.
      final after = container
          .read(cameraSessionProvider)
          .requireValue
          .controller;
      expect(identical(before, after), isTrue);
      expect(platform.created, hasLength(1));
      expect(platform.liveCameras, hasLength(1));
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
    Future<void> captureOnce(
      WidgetTester tester, {
      AppSettings settings = AppSettings.defaults,
      Size? surface,
    }) async {
      if (surface != null) {
        tester.view
          ..physicalSize = surface * 3
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
      }
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
        settings: settings,
      );
      await settle(tester);
      // Capture, crop and save touch real files and a worker isolate, which
      // need the real event loop.
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

    /// Pumps the camera in its no-crop configuration: Full Screen on a 9:16
    /// window matches the stream, so a capture is a plain file copy. Tests
    /// about permissions and saving stay about those, not about the crop.
    Future<void> pumpNoCrop(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1080, 1920)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
        settings: const AppSettings(captureRatio: CaptureRatio.fullScreen),
      );
      await settle(tester);
    }

    testWidgets('the shutter crops the still to the selected ratio and stays '
        'on the camera', (tester) async {
      // The 4:3 default on the default 800x600 window.
      await captureOnce(tester);

      expect(platform.captureCount, 1);
      // The camera's own image, cropped to the frame the preview showed: a
      // 4:3 cut of the 540x960 still. The preview, the controls and the
      // reference overlay are never part of it.
      final saved = img.decodeJpg(Uint8List.fromList(gallery.saved.single))!;
      expect(saved.width, 540);
      expect(saved.height, 405);
      expect(saved.width / saved.height, closeTo(4 / 3, 0.005));
      // Capturing says nothing: the flash and the haptic are the feedback.
      expect(find.byType(SnackBar), findsNothing);
      // No review screen: still on the live camera.
      expect(shutter, findsOneWidget);
      expect(platform.liveCameras, hasLength(1));

      // The capture is filed in the local gallery, which keeps the app's copy.
      final stored = storedPhotos();
      expect(stored, hasLength(1));
      expect(
        await store.getString(StorageKeys.galleryHistory),
        contains(p.basename(stored.single)),
      );
    });

    testWidgets('a ratio that matches the camera output is saved byte for '
        'byte', (tester) async {
      // Full Screen on a 9:16 window matches the stream exactly, so nothing is
      // re-encoded: the camera's own bytes reach the library untouched.
      await captureOnce(
        tester,
        settings: const AppSettings(captureRatio: CaptureRatio.fullScreen),
        surface: const Size(360, 640),
      );

      expect(platform.captureCount, 1);
      expect(gallery.saved.single, platform.pictureBytes);
      expect(shutter, findsOneWidget);
    });

    testWidgets('a capture that cannot be saved explains itself and leaves the '
        'camera usable', (tester) async {
      gallery.nextError = GalException(
        type: GalExceptionType.notEnoughSpace,
        platformException: PlatformException(code: 'TEST'),
        stackTrace: StackTrace.current,
      );
      await pumpNoCrop(tester);

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
      await pumpNoCrop(tester);

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
      await pumpNoCrop(tester);

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
      // No crop is needed in this configuration, so the camera's own bytes
      // reach the library untouched.
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
