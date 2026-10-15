import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera_overlay/core/files/file_service.dart';
import 'package:camera_overlay/core/permissions/app_permission.dart';
import 'package:camera_overlay/core/permissions/permission_service.dart';
import 'package:camera_overlay/features/camera/presentation/pages/camera_page.dart';
import 'package:camera_overlay/features/gallery/data/gallery_saver_service.dart';
import 'package:camera_overlay/features/gallery/data/image_picker_service.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_fit_mode.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_settings.dart';
import 'package:camera_overlay/features/overlay/presentation/providers/overlay_image_provider.dart';
import 'package:camera_overlay/features/overlay/presentation/providers/overlay_settings_provider.dart';
import 'package:camera_overlay/features/overlay/presentation/widgets/reference_overlay_layer.dart';
import 'package:camera_overlay/features/settings/presentation/providers/settings_controller.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../camera/camera_page_test.dart' show FakePermissionService;
import '../../helpers/camera_test_app.dart';
import '../../helpers/fake_gallery.dart';
import '../camera/fakes/fake_camera_platform.dart';
import 'overlay_fakes.dart';

void main() {
  late Directory temp;
  late FakeCameraPlatform platform;
  late FakeImagePickerService picker;
  late Uint8List referencePng;
  late FakeGallerySaver gallery;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('overlay_camera_test');
    platform = FakeCameraPlatform(captureDirectory: temp);
    CameraPlatform.instance = platform;
    picker = FakeImagePickerService();
    gallery = FakeGallerySaver();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CameraPage)));

  OverlaySettings settings(WidgetTester tester) =>
      container(tester).read(overlaySettingsProvider);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Opens the camera on a 360x800 phone and loads a 3:4 reference image.
  Future<void> openWithOverlay(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async => referencePng = await pngBytes(30, 40));
    picker.queueImage(referencePng);

    await pumpCameraApp(
      tester,
      overrides: [
        permissionServiceProvider.overrideWithValue(
          FakePermissionService(AppPermissionStatus.granted),
        ),
        fileServiceProvider.overrideWithValue(TempFileService(temp)),
        imagePickerServiceProvider.overrideWithValue(picker),
        gallerySaverServiceProvider.overrideWithValue(gallery),
        settingsControllerProvider.overrideWith(FakeSettingsController.new),
      ],
    );
    await settle(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey<String>('overlay-pick')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    expect(find.byType(OverlayPicture), findsOneWidget);
  }

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> openFrameTab(WidgetTester tester) async {
    await tester.tap(byKey('overlay-tab-frame'));
    await settle(tester);
  }

  const previewPoint = Offset(180, 300);

  testWidgets('shows the picked image with the opacity controls', (
    tester,
  ) async {
    await openWithOverlay(tester);

    expect(picker.calls, 1);
    expect(find.text('50%'), findsWidgets);
    expect(byKey('overlay-opacity'), findsOneWidget);
    for (final percent in <int>[25, 50, 75, 100]) {
      expect(byKey('overlay-preset-$percent'), findsOneWidget);
    }
  });

  testWidgets('every fit mode draws the image at its own aspect ratio', (
    tester,
  ) async {
    await openWithOverlay(tester);
    final image = find.descendant(
      of: find.byType(OverlayPicture),
      matching: find.byType(RawImage),
    );
    // The reference is 30x40 on a 360x800 viewport at 3x density.
    final expected = <OverlayFitMode, Size>{
      OverlayFitMode.fit: const Size(360, 480),
      OverlayFitMode.fill: const Size(600, 800),
      OverlayFitMode.center: const Size(10, 40 / 3),
    };

    await openFrameTab(tester);
    for (final entry in expected.entries) {
      await tester.tap(byKey('overlay-fit-${entry.key.name}'));
      await tester.pump();
      final size = tester.getSize(image);
      expect(size.width, closeTo(entry.value.width, 0.01), reason: '$entry');
      expect(size.height, closeTo(entry.value.height, 0.01), reason: '$entry');
    }
  });

  testWidgets('the tray switches tabs and folds when the open tab is tapped', (
    tester,
  ) async {
    await openWithOverlay(tester);
    expect(byKey('overlay-opacity'), findsOneWidget);
    expect(byKey('overlay-fit-fit'), findsNothing);

    await openFrameTab(tester);
    expect(byKey('overlay-fit-fit'), findsOneWidget);
    expect(byKey('overlay-opacity'), findsNothing);

    await tester.tap(byKey('overlay-tab-frame'));
    await settle(tester);
    expect(byKey('overlay-fit-fit'), findsNothing);
    expect(find.text('Opacity 50%'), findsOneWidget);
    // Header toggles stay reachable while folded.
    expect(byKey('overlay-visibility'), findsOneWidget);
    expect(byKey('overlay-remove'), findsOneWidget);
  });

  testWidgets('the tray minimizes to a chip and restores where it was', (
    tester,
  ) async {
    await openWithOverlay(tester);
    await openFrameTab(tester);

    await tester.tap(byKey('overlay-minimize'));
    await settle(tester);
    expect(byKey('overlay-restore'), findsOneWidget);
    expect(byKey('overlay-lock'), findsNothing);
    expect(byKey('overlay-fit-fit'), findsNothing);
    expect(find.text('50%'), findsOneWidget);
    // The overlay stays on screen and editable while the tray is minimized.
    expect(find.byType(OverlayPicture), findsOneWidget);
    await tester.dragFrom(previewPoint, const Offset(60, 0));
    await tester.pump();
    expect(settings(tester).offset.dx, greaterThan(0));

    await tester.tap(byKey('overlay-restore'));
    await settle(tester);
    expect(byKey('overlay-restore'), findsNothing);
    // Back on the tab that was open.
    expect(byKey('overlay-fit-fit'), findsOneWidget);
  });

  testWidgets('flicking the tray down minimizes it; up restores it', (
    tester,
  ) async {
    await openWithOverlay(tester);

    await tester.fling(byKey('overlay-tab-frame'), const Offset(0, 80), 900);
    await settle(tester);
    expect(byKey('overlay-restore'), findsOneWidget);

    await tester.fling(byKey('overlay-restore'), const Offset(0, -80), 900);
    await settle(tester);
    expect(byKey('overlay-restore'), findsNothing);
    expect(byKey('overlay-opacity'), findsOneWidget);
  });

  testWidgets('the minimized chip shows lock and hidden states', (
    tester,
  ) async {
    await openWithOverlay(tester);
    await tester.tap(byKey('overlay-lock'));
    await tester.tap(byKey('overlay-visibility'));
    await tester.pump();
    await tester.tap(byKey('overlay-minimize'));
    await settle(tester);

    final chip = tester.getSemantics(byKey('overlay-restore'));
    expect(chip.label, contains('locked'));
    expect(chip.label, contains('hidden'));
  });

  testWidgets('minimized stays minimized across a camera switch; a new image '
      'shows the tray', (tester) async {
    await openWithOverlay(tester);
    await tester.tap(byKey('overlay-minimize'));
    await settle(tester);

    await tester.tap(byKey('camera-switch'));
    await settle(tester);
    expect(byKey('overlay-restore'), findsOneWidget);

    picker.queueImage(referencePng);
    await tester.runAsync(() async {
      await tester.tap(byKey('overlay-pick'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    expect(byKey('overlay-restore'), findsNothing);
    expect(byKey('overlay-opacity'), findsOneWidget);
  });

  testWidgets('presets, slider and reset set the exact percentage', (
    tester,
  ) async {
    await openWithOverlay(tester);

    await tester.tap(byKey('overlay-preset-75'));
    await tester.pump();
    expect(tester.widget<Text>(byKey('overlay-opacity-label')).data, '75%');

    await tester.drag(byKey('overlay-opacity'), const Offset(-400, 0));
    await tester.pump();
    expect(tester.widget<Text>(byKey('overlay-opacity-label')).data, '0%');

    await tester.tap(byKey('overlay-opacity-reset'));
    await tester.pump();
    expect(tester.widget<Text>(byKey('overlay-opacity-label')).data, '50%');
  });

  testWidgets('dragging the preview moves the overlay; opacity keeps it', (
    tester,
  ) async {
    await openWithOverlay(tester);

    await tester.dragFrom(previewPoint, const Offset(72, 40));
    await tester.pump();
    final moved = settings(tester);
    expect(moved.offset.dx, greaterThan(0));
    expect(moved.offset.dy, greaterThan(0));

    await tester.drag(byKey('overlay-opacity'), const Offset(60, 0));
    await tester.tap(byKey('overlay-preset-25'));
    await tester.pump();

    expect(settings(tester).offset, moved.offset);
    expect(settings(tester).opacity, 0.25);
  });

  testWidgets('two fingers resize and rotate the overlay', (tester) async {
    await openWithOverlay(tester);

    final first = await tester.startGesture(
      const Offset(140, 300),
      pointer: 101,
    );
    final second = await tester.startGesture(
      const Offset(220, 300),
      pointer: 102,
    );
    await tester.pump();
    // Spread and twist in small steps, like real fingers. The first step only
    // crosses the gesture slop, which Flutter uses as the baseline.
    for (var step = 1; step <= 8; step++) {
      await first.moveTo(Offset(140 - step * 6.0, 300 - step * 6.0));
      await second.moveTo(Offset(220 + step * 6.0, 300 + step * 6.0));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await tester.pump();

    expect(settings(tester).scale, greaterThan(1.5));
    // A symmetric pinch leaves the overlay where it was.
    expect(settings(tester).offset.distance, lessThan(0.01));
    expect(settings(tester).rotation, isNot(0));
  });

  testWidgets('locking stops gestures but taps still focus the camera', (
    tester,
  ) async {
    await openWithOverlay(tester);

    await tester.tap(byKey('overlay-lock'));
    await tester.pump();
    await tester.dragFrom(previewPoint, const Offset(72, 40));
    await tester.pump();
    expect(settings(tester).offset, Offset.zero);

    await tester.tapAt(previewPoint);
    await settle(tester);
    expect(platform.focusPoints, isNotEmpty);
  });

  testWidgets('taps on an editable overlay also focus the camera', (
    tester,
  ) async {
    await openWithOverlay(tester);

    await tester.tapAt(previewPoint);
    await settle(tester);

    expect(platform.focusPoints, isNotEmpty);
    expect(settings(tester).offset, Offset.zero);
  });

  testWidgets('the shutter works over an editable overlay; the saved photo '
      'is the camera image only, and Save composite is a separate export', (
    tester,
  ) async {
    await openWithOverlay(tester);
    expect(settings(tester).isLocked, isFalse);

    await tester.runAsync(() async {
      await tester.tap(byKey('camera-shutter'));
      final dir = await TempFileService(temp).capturesDirectory();
      for (var i = 0; i < 100; i++) {
        if (_captureStored(dir)) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await settle(tester);
    expect(platform.captureCount, 1);
    expect(byKey('review-composite-tab'), findsOneWidget);

    // Save: exactly the bytes the camera produced, no overlay composited in.
    await tester.runAsync(() async {
      await tester.tap(byKey('review-save'));
      for (var i = 0; i < 50 && gallery.saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await settle(tester);
    expect(gallery.saved.single, platform.pictureBytes);

    // Save composite: rendered at the photo's own resolution.
    await tester.tap(byKey('review-composite-tab'));
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (byKey('review-composite').evaluate().isNotEmpty) break;
      }
      await tester.tap(byKey('review-save'));
      for (var i = 0; i < 100 && gallery.saved.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await settle(tester);

    expect(gallery.saved, hasLength(2));
    final composite = img.decodeJpg(Uint8List.fromList(gallery.saved[1]))!;
    expect(composite.width, 54);
    expect(composite.height, 96);
    expect(gallery.saved[1], isNot(platform.pictureBytes));
    expect(find.text('Composite saved to Gallery'), findsOneWidget);
  });

  testWidgets('hide, show and remove', (tester) async {
    await openWithOverlay(tester);

    await tester.tap(byKey('overlay-visibility'));
    await tester.pump();
    expect(find.byType(OverlayPicture), findsNothing);
    // Hidden overlays must not swallow camera gestures.
    expect(byKey('overlay-gestures'), findsNothing);

    await tester.tap(byKey('overlay-visibility'));
    await tester.pump();
    expect(find.byType(OverlayPicture), findsOneWidget);

    await tester.tap(byKey('overlay-remove'));
    await settle(tester);
    expect(find.byType(OverlayPicture), findsNothing);
    expect(container(tester).read(overlayImageProvider).value, isNull);
    expect(find.byTooltip('Choose reference image'), findsOneWidget);
  });

  testWidgets('fit modes and reset position', (tester) async {
    await openWithOverlay(tester);
    await openFrameTab(tester);

    await tester.tap(byKey('overlay-fit-fill'));
    await tester.pump();
    expect(settings(tester).fitMode, OverlayFitMode.fill);

    await tester.dragFrom(previewPoint, const Offset(50, 0));
    await tester.pump();
    expect(settings(tester).hasCustomTransform, isTrue);

    await tester.tap(byKey('overlay-reset-position'));
    await tester.pump();
    expect(settings(tester).hasCustomTransform, isFalse);
    expect(settings(tester).fitMode, OverlayFitMode.fill);
  });

  testWidgets('a corrupted image explains itself and keeps the current one', (
    tester,
  ) async {
    await openWithOverlay(tester);
    picker
      ..queueImage(Uint8List.fromList(List<int>.filled(64, 3)))
      ..gate = Completer<void>();

    await tester.tap(byKey('overlay-pick'));
    // The loading spinner replaces the button, as it does on a device.
    await tester.pump();
    expect(byKey('overlay-pick'), findsNothing);

    await tester.runAsync(() async {
      picker.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);

    expect(find.textContaining('could not be opened'), findsOneWidget);
    expect(find.byType(OverlayPicture), findsOneWidget);
  });

  testWidgets('a pick that fails while the camera is backgrounded still '
      'explains itself', (tester) async {
    await openWithOverlay(tester);
    picker
      ..queueImage(Uint8List.fromList(List<int>.filled(64, 3)))
      ..gate = Completer<void>();

    await tester.tap(byKey('overlay-pick'));
    await tester.pump();
    // The gallery covers the app: the camera pauses and its controls unmount.
    for (final state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);
    expect(find.byKey(const ValueKey<String>('camera-shutter')), findsNothing);

    await tester.runAsync(() async {
      picker.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (final state in <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);

    expect(find.textContaining('could not be opened'), findsOneWidget);
    expect(find.byType(OverlayPicture), findsOneWidget);
  });

  testWidgets('rotating the device keeps the overlay position relative', (
    tester,
  ) async {
    await openWithOverlay(tester);
    await tester.dragFrom(previewPoint, const Offset(72, 0));
    await tester.pump();
    final before = settings(tester);

    tester.view.physicalSize = const Size(2400, 1080);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(settings(tester), before);

    // Landscape starts with the tray folded to its header, keeping the
    // preview usable; the header still shows the opacity and the toggles.
    expect(byKey('overlay-opacity'), findsNothing);
    expect(find.text('Opacity 50%'), findsOneWidget);
    expect(byKey('overlay-lock'), findsOneWidget);
    await tester.tap(byKey('overlay-tab-opacity'));
    await settle(tester);
    expect(byKey('overlay-opacity'), findsOneWidget);
    expect(byKey('overlay-preset-50'), findsOneWidget);
    final picture = tester.getCenter(
      find.descendant(
        of: find.byType(OverlayPicture),
        matching: find.byType(RawImage),
      ),
    );
    final viewport = tester.getSize(find.byType(ReferenceOverlayLayer));
    expect(
      picture.dx,
      closeTo(viewport.width / 2 + before.offset.dx * viewport.width, 1),
    );
  });
}

/// The controller copies the camera's raw file into place and then deletes
/// it, so the copy is complete once only the stored photo remains.
bool _captureStored(Directory dir) {
  final names = dir.listSync().map((f) => f.path).toList();
  return names.any((name) => name.contains('overlay_')) &&
      !names.any((name) => name.contains('raw_'));
}
