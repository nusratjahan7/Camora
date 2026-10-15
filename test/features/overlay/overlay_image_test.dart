import 'dart:typed_data';

import 'package:camera_overlay/core/errors/app_exception.dart';
import 'package:camera_overlay/features/gallery/data/image_picker_service.dart';
import 'package:camera_overlay/features/overlay/data/overlay_image_decoder.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_fit_mode.dart';
import 'package:camera_overlay/features/overlay/presentation/providers/overlay_image_provider.dart';
import 'package:camera_overlay/features/overlay/presentation/providers/overlay_settings_provider.dart';
import 'package:camera_overlay/features/settings/presentation/providers/settings_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overlay_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decoder', () {
    const decoder = OverlayImageDecoder(maxDimension: 64);

    test('decodes a PNG and records its original size', () async {
      final image = await decoder.decode(await pngBytes(40, 20), name: 'a');

      expect(image.originalSize, const Size(40, 20));
      expect(image.decodedSize, const Size(40, 20));
      image.image.dispose();
    });

    test('downsamples large images, keeping the aspect ratio', () async {
      final image = await decoder.decode(await pngBytes(256, 128), name: 'a');

      expect(image.originalSize, const Size(256, 128));
      expect(image.decodedSize, const Size(64, 32));
      image.image.dispose();
    });

    test('rejects corrupted data', () async {
      final png = await pngBytes(16, 16);
      final corrupted = Uint8List.fromList(png.sublist(0, 24))
        ..fillRange(12, 24, 0);

      await expectLater(
        decoder.decode(corrupted, name: 'broken.png'),
        throwsA(isA<ImageSelectionFailure>()),
      );
      await expectLater(
        decoder.decode(Uint8List.fromList(List<int>.filled(512, 7)), name: 'x'),
        throwsA(isA<ImageSelectionFailure>()),
      );
    });

    test('rejects empty and oversized files', () async {
      await expectLater(
        decoder.decode(Uint8List(0), name: 'empty'),
        throwsA(isA<ImageSelectionFailure>()),
      );
      await expectLater(
        const OverlayImageDecoder(
          maxFileBytes: 10,
        ).decode(await pngBytes(16, 16), name: 'big'),
        throwsA(isA<ImageSelectionFailure>()),
      );
    });
  });

  group('image controller', () {
    late FakeImagePickerService picker;
    late ProviderContainer container;

    setUp(() {
      picker = FakeImagePickerService();
      container = ProviderContainer.test(
        overrides: [
          imagePickerServiceProvider.overrideWithValue(picker),
          settingsControllerProvider.overrideWith(FakeSettingsController.new),
        ],
      );
    });

    OverlayImageController controller() =>
        container.read(overlayImageProvider.notifier);

    test('loads the picked image and resets framing', () async {
      container
          .read(overlaySettingsProvider.notifier)
          .setFitMode(OverlayFitMode.fill);
      picker.queueImage(await pngBytes(30, 10));

      expect(await controller().pickFromGallery(), isTrue);

      final image = container.read(overlayImageProvider).value;
      expect(image?.originalSize, const Size(30, 10));
      expect(image?.name, 'reference.png');
      expect(
        container.read(overlaySettingsProvider).fitMode,
        OverlayFitMode.fit,
      );
    });

    test('cancelling keeps the current image', () async {
      picker.queueImage(await pngBytes(30, 10));
      await controller().pickFromGallery();
      final current = container.read(overlayImageProvider).value;

      picker.queueCancel();
      expect(await controller().pickFromGallery(), isFalse);

      expect(container.read(overlayImageProvider).value, same(current));
      expect(container.read(overlayImageProvider).isLoading, isFalse);
    });

    test('a corrupted pick keeps the current image and explains', () async {
      picker.queueImage(await pngBytes(30, 10));
      await controller().pickFromGallery();
      final current = container.read(overlayImageProvider).value;

      picker.queueImage(Uint8List.fromList(List<int>.filled(64, 1)));
      await expectLater(
        controller().pickFromGallery(),
        throwsA(isA<ImageSelectionFailure>()),
      );

      expect(container.read(overlayImageProvider).value, same(current));
      expect(current!.image.debugDisposed, isFalse);
    });

    test('picker failures surface as a selection failure', () async {
      picker.results.add(pickerUnavailable);

      await expectLater(
        controller().pickFromGallery(),
        throwsA(isA<ImageSelectionFailure>()),
      );
      expect(container.read(overlayImageProvider).value, isNull);
    });
  });

  testWidgets('replacing and removing free the previous image after a frame', (
    tester,
  ) async {
    final picker = FakeImagePickerService();
    final container = ProviderContainer.test(
      overrides: [
        imagePickerServiceProvider.overrideWithValue(picker),
        settingsControllerProvider.overrideWith(FakeSettingsController.new),
      ],
    );
    final controller = container.read(overlayImageProvider.notifier);

    await tester.runAsync(() async {
      picker
        ..queueImage(await pngBytes(30, 10))
        ..queueImage(await pngBytes(12, 12));
      await controller.pickFromGallery();
    });
    final first = container.read(overlayImageProvider).value!;

    await tester.runAsync(controller.pickFromGallery);
    final second = container.read(overlayImageProvider).value!;
    expect(first.image.debugDisposed, isFalse);
    await tester.pump();
    expect(first.image.debugDisposed, isTrue);

    controller.remove();
    expect(container.read(overlayImageProvider).value, isNull);
    await tester.pump();
    expect(second.image.debugDisposed, isTrue);
  });
}
