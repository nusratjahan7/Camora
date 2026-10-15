import 'dart:io';

import 'package:camera_overlay/core/files/file_service.dart';
import 'package:camera_overlay/core/permissions/app_permission.dart';
import 'package:camera_overlay/core/permissions/permission_service.dart';
import 'package:camera_overlay/core/theme/app_theme.dart';
import 'package:camera_overlay/features/camera/presentation/pages/camera_page.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  setUp(() {
    temp = Directory.systemTemp.createTempSync('camera_page_test');
    platform = FakeCameraPlatform(captureDirectory: temp);
    CameraPlatform.instance = platform;
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Future<void> pumpPage(
    WidgetTester tester,
    FakePermissionService permissions,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionServiceProvider.overrideWithValue(permissions),
          fileServiceProvider.overrideWithValue(TempFileService(temp)),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const CameraPage()),
      ),
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

    testWidgets('capturing confirms with a snackbar', (tester) async {
      await pumpPage(
        tester,
        FakePermissionService(AppPermissionStatus.granted),
      );
      await settle(tester);

      // Capture copies a real file, which needs the real event loop.
      await tester.runAsync(() async {
        await tester.tap(shutter);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await settle(tester);

      expect(platform.captureCount, 1);
      expect(find.text('Photo captured'), findsOneWidget);
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
