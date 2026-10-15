import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera_overlay/core/errors/app_exception.dart';
import 'package:camera_overlay/core/files/file_service.dart';
import 'package:camera_overlay/features/capture/domain/captured_photo.dart';
import 'package:camera_overlay/features/capture/domain/composite_geometry.dart';
import 'package:camera_overlay/features/capture/presentation/providers/capture_review_controller.dart';
import 'package:camera_overlay/features/gallery/data/gallery_saver_service.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;

import '../../helpers/fake_gallery.dart';
import '../camera/fakes/fake_camera_platform.dart' show TempFileService;
import 'composite_renderer_test.dart' show solid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late FakeGallerySaver gallery;
  late ProviderContainer container;
  late List<int> originalBytes;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('review_test');
    gallery = FakeGallerySaver();
    container = ProviderContainer.test(
      overrides: [
        gallerySaverServiceProvider.overrideWithValue(gallery),
        fileServiceProvider.overrideWithValue(TempFileService(temp)),
      ],
    );
    final jpeg = img.Image(width: 64, height: 48);
    img.fill(jpeg, color: img.ColorRgb8(30, 60, 90));
    originalBytes = img.encodeJpg(jpeg, quality: 80);
  });

  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<CapturedPhoto> photo({bool withOverlay = false}) async {
    final file = File('${temp.path}${Platform.pathSeparator}Veylora_1.jpg');
    await file.writeAsBytes(originalBytes);
    CompositeSource? source;
    if (withOverlay) {
      source = CompositeSource(
        frame: const PreviewFrame(
          viewport: ui.Size(64, 48),
          previewAspectRatio: 64 / 48,
          devicePixelRatio: 1,
        ),
        settings: const OverlaySettings(opacity: 1),
        image: await solid(8, 8, const ui.Color(0xFFFFFFFF)),
        imageSize: const ui.Size(8, 8),
      );
    }
    return CapturedPhoto(path: file.path, composite: source);
  }

  Future<bool> noExplain() async => fail('should not explain');

  ({CaptureReviewController controller, CapturedPhoto photo}) review(
    CapturedPhoto photo,
  ) {
    final provider = captureReviewProvider(photo);
    container.listen(provider, (_, _) {});
    return (controller: container.read(provider.notifier), photo: photo);
  }

  CaptureReviewState stateOf(CapturedPhoto photo) =>
      container.read(captureReviewProvider(photo));

  test('saves the original byte for byte', () async {
    final r = review(await photo());

    final outcome = await r.controller.save(explainPermission: noExplain);

    expect(outcome, SaveOutcome.saved);
    expect(gallery.savedPaths.single, r.photo.path);
    expect(gallery.saved.single, originalBytes);
    expect(stateOf(r.photo).originalSaved, isTrue);
  });

  test('a saved photo is not saved twice', () async {
    final r = review(await photo());
    await r.controller.save(explainPermission: noExplain);

    final again = await r.controller.save(explainPermission: noExplain);

    expect(again, SaveOutcome.alreadySaved);
    expect(gallery.saved, hasLength(1));
  });

  test('a second tap while saving is ignored', () async {
    final r = review(await photo());
    gallery.gate = Completer<void>();

    final first = r.controller.save(explainPermission: noExplain);
    await Future<void>.delayed(Duration.zero);
    expect(stateOf(r.photo).saving, ReviewVariant.original);
    expect(
      await r.controller.save(explainPermission: noExplain),
      SaveOutcome.busy,
    );

    gallery.gate!.complete();
    expect(await first, SaveOutcome.saved);
    expect(gallery.saved, hasLength(1));
    expect(stateOf(r.photo).isSaving, isFalse);
  });

  group('permission', () {
    test('explains before asking, then saves when granted', () async {
      gallery.access = false;
      final r = review(await photo());
      var explained = 0;

      final outcome = await r.controller.save(
        explainPermission: () async {
          explained++;
          return true;
        },
      );

      expect(explained, 1);
      expect(gallery.accessRequests, 1);
      expect(outcome, SaveOutcome.saved);
    });

    test('declining the explanation never shows the system prompt', () async {
      gallery.access = false;
      final r = review(await photo());

      final outcome = await r.controller.save(
        explainPermission: () async => false,
      );

      expect(outcome, SaveOutcome.permissionDenied);
      expect(gallery.accessRequests, 0);
      expect(gallery.saved, isEmpty);
      expect(stateOf(r.photo).isSaving, isFalse);
    });

    test('a denied system prompt reports permissionDenied', () async {
      gallery
        ..access = false
        ..grantOnRequest = false;
      final r = review(await photo());

      expect(
        await r.controller.save(explainPermission: () async => true),
        SaveOutcome.permissionDenied,
      );
    });
  });

  group('errors', () {
    test(
      'library errors surface as readable failures and allow retry',
      () async {
        final r = review(await photo());
        gallery.nextError = GalException(
          type: GalExceptionType.notEnoughSpace,
          platformException: PlatformException(code: 'TEST'),
          stackTrace: StackTrace.current,
        );

        await expectLater(
          r.controller.save(explainPermission: noExplain),
          throwsA(
            isA<GallerySaveFailure>().having(
              (f) => f.message,
              'message',
              contains('storage'),
            ),
          ),
        );
        expect(stateOf(r.photo).isSaving, isFalse);
        expect(stateOf(r.photo).originalSaved, isFalse);

        // Retry succeeds once space is available.
        expect(
          await r.controller.save(explainPermission: noExplain),
          SaveOutcome.saved,
        );
      },
    );

    test('access revoked mid-save points to settings', () async {
      final r = review(await photo());
      gallery.nextError = GalException(
        type: GalExceptionType.accessDenied,
        platformException: PlatformException(code: 'TEST'),
        stackTrace: StackTrace.current,
      );

      try {
        await r.controller.save(explainPermission: noExplain);
        fail('expected a failure');
      } on AppException catch (failure) {
        expect(isGalleryAccessDenied(failure), isTrue);
      }
    });

    test('a photo deleted from storage cannot be saved', () async {
      final r = review(await photo());
      await File(r.photo.path).delete();

      await expectLater(
        r.controller.save(explainPermission: noExplain),
        throwsA(isA<FileFailure>()),
      );
      expect(gallery.saved, isEmpty);
    });
  });

  group('composite', () {
    test(
      'renders and saves a separate JPEG; the original is untouched',
      () async {
        final r = review(await photo(withOverlay: true));

        r.controller.selectVariant(ReviewVariant.composite);
        final outcome = await r.controller.save(explainPermission: noExplain);

        expect(outcome, SaveOutcome.saved);
        expect(stateOf(r.photo).compositeSaved, isTrue);
        expect(stateOf(r.photo).originalSaved, isFalse);
        final composite = img.decodeJpg(
          Uint8List.fromList(gallery.saved.single),
        )!;
        expect(composite.width, 64);
        expect(composite.height, 48);
        // The overlay is white at full opacity in the middle of the photo.
        final centre = composite.getPixel(32, 24);
        expect(centre.r, greaterThan(240));
        expect(gallery.savedPaths.single, isNot(r.photo.path));
        expect(File(r.photo.path).readAsBytesSync(), originalBytes);
        // The temporary composite file is cleaned up after saving.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(File(gallery.savedPaths.single).existsSync(), isFalse);
      },
    );

    test('original and composite can both be saved, once each', () async {
      final r = review(await photo(withOverlay: true));

      await r.controller.save(explainPermission: noExplain);
      r.controller.selectVariant(ReviewVariant.composite);
      await r.controller.save(explainPermission: noExplain);

      expect(gallery.saved, hasLength(2));
      expect(gallery.saved.first, originalBytes);
    });

    test('is unavailable without a reference overlay', () async {
      final r = review(await photo());

      r.controller.selectVariant(ReviewVariant.composite);

      expect(stateOf(r.photo).variant, ReviewVariant.original);
    });
  });

  test(
    'closing the review deletes the working copy and frees the overlay',
    () async {
      final r = review(await photo(withOverlay: true));
      final overlay = r.photo.composite!.image;

      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(File(r.photo.path).existsSync(), isFalse);
      expect(overlay.debugDisposed, isTrue);
      container = ProviderContainer.test();
    },
  );
}
