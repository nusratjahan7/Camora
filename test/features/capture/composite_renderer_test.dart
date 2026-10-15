import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera_overlay/features/capture/data/composite_renderer.dart';
import 'package:camera_overlay/features/capture/domain/captured_photo.dart';
import 'package:camera_overlay/features/capture/domain/composite_geometry.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_fit_mode.dart';
import 'package:camera_overlay/features/overlay/domain/overlay_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Future<ui.Image> solid(int width, int height, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

/// Overlay whose left half is red and right half blue, to detect flips.
Future<ui.Image> split(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    )
    ..drawRect(
      ui.Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF0000FF),
    );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Future<List<int>> pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * image.width + x) * 4;
  return <int>[
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
    data.getUint8(i + 3),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const renderer = CompositeRenderer();

  // A 40x20 viewport showing a 2:1 preview of a 40x20 photo: 1:1 mapping.
  const frame = PreviewFrame(
    viewport: ui.Size(40, 20),
    previewAspectRatio: 2,
    devicePixelRatio: 1,
  );

  CompositeSource source(
    ui.Image overlay, {
    OverlaySettings settings = const OverlaySettings(
      opacity: 1,
      fitMode: OverlayFitMode.center,
    ),
    PreviewFrame previewFrame = frame,
  }) => CompositeSource(
    frame: previewFrame,
    settings: settings,
    image: overlay,
    imageSize: ui.Size(overlay.width.toDouble(), overlay.height.toDouble()),
  );

  test(
    'draws the overlay where it was on screen, at full photo size',
    () async {
      final photo = await solid(40, 20, const ui.Color(0xFF000000));
      final overlay = await solid(10, 10, const ui.Color(0xFFFFFFFF));

      final out = await renderer.compose(photo, source(overlay));

      expect(out.width, 40);
      expect(out.height, 20);
      // 10x10 centred at (20, 10): covers x 15..24, y 5..14.
      expect(await pixel(out, 20, 10), <int>[255, 255, 255, 255]);
      expect(await pixel(out, 15, 5), <int>[255, 255, 255, 255]);
      expect(await pixel(out, 13, 10), <int>[0, 0, 0, 255]);
      expect(await pixel(out, 20, 3), <int>[0, 0, 0, 255]);
    },
  );

  test('blends with the overlay opacity', () async {
    final photo = await solid(40, 20, const ui.Color(0xFF000000));
    final overlay = await solid(10, 10, const ui.Color(0xFFFFFFFF));

    final out = await renderer.compose(
      photo,
      source(
        overlay,
        settings: const OverlaySettings(
          opacity: 0.5,
          fitMode: OverlayFitMode.center,
        ),
      ),
    );

    final centre = await pixel(out, 20, 10);
    expect(centre[0], inInclusiveRange(124, 131));
    expect(centre[3], 255);
  });

  test('zero opacity leaves the photo unchanged', () async {
    final photo = await solid(40, 20, const ui.Color(0xFF204060));
    final overlay = await solid(10, 10, const ui.Color(0xFFFFFFFF));

    final out = await renderer.compose(
      photo,
      source(
        overlay,
        settings: const OverlaySettings(
          opacity: 0,
          fitMode: OverlayFitMode.center,
        ),
      ),
    );

    expect(await pixel(out, 20, 10), <int>[0x20, 0x40, 0x60, 255]);
  });

  test(
    'front camera: the overlay is mirrored in place and in content',
    () async {
      final photo = await solid(40, 20, const ui.Color(0xFF000000));
      final overlay = await split(10, 10);

      final out = await renderer.compose(
        photo,
        source(
          overlay,
          // On screen: right of centre (x = 30).
          settings: const OverlaySettings(
            opacity: 1,
            offset: ui.Offset(0.25, 0),
            fitMode: OverlayFitMode.center,
          ),
          previewFrame: const PreviewFrame(
            viewport: ui.Size(40, 20),
            previewAspectRatio: 2,
            devicePixelRatio: 1,
            mirrored: true,
          ),
        ),
      );

      // In the unmirrored photo it sits at x = 10, with blue now on the left.
      expect(await pixel(out, 7, 10), <int>[0, 0, 255, 255]);
      expect(await pixel(out, 12, 10), <int>[255, 0, 0, 255]);
      expect(await pixel(out, 30, 10), <int>[0, 0, 0, 255]);
    },
  );

  test('encodes a JPEG at the composite resolution', () async {
    final photo = await solid(64, 48, const ui.Color(0xFF336699));
    final overlay = await solid(8, 8, const ui.Color(0xFFFFFFFF));
    final out = await renderer.compose(photo, source(overlay));

    final jpeg = await renderer.encodeJpeg(out);
    final decoded = img.decodeJpg(jpeg)!;

    expect(decoded.width, 64);
    expect(decoded.height, 48);
    // No EXIF orientation: the composite is already upright.
    expect(decoded.exif.imageIfd.orientation ?? 1, 1);
  });

  test('decodes photos upright, honouring EXIF orientation', () async {
    // A 40x20 JPEG tagged "rotate 90° clockwise" is upright as 20x40.
    final stored = img.Image(width: 40, height: 20)
      ..exif.imageIfd.orientation = 6;
    img.fill(stored, color: img.ColorRgb8(10, 20, 30));
    final bytes = Uint8List.fromList(img.encodeJpg(stored));

    final photo = await renderer.decodePhoto(bytes);

    expect(photo.width, 20);
    expect(photo.height, 40);
  });
}
