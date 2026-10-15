import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/errors/app_exception.dart';
import '../domain/captured_photo.dart';
import '../domain/composite_geometry.dart';

/// Renders "Save composite" exports: the captured photo at full resolution
/// with the reference image drawn where the user saw it.
///
/// Only ever produces a new image; the original photo file is untouched.
class CompositeRenderer {
  const CompositeRenderer({this.jpegQuality = 95});

  final int jpegQuality;

  /// Decodes [bytes] at full size. The engine applies EXIF orientation, so
  /// the result is the upright photo.
  Future<ui.Image> decodePhoto(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      codec = await descriptor.instantiateCodec();
      return (await codec.getNextFrame()).image;
    } catch (error, stackTrace) {
      throw FileFailure(
        'The captured photo could not be read.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Draws [source]'s overlay over [photo]. The caller owns the result.
  Future<ui.Image> compose(ui.Image photo, CompositeSource source) async {
    final photoSize = ui.Size(photo.width.toDouble(), photo.height.toDouble());
    final placement = CompositeGeometry.place(
      frame: source.frame,
      photoSize: photoSize,
      imageSize: source.imageSize,
      settings: source.settings,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Offset.zero & photoSize);
    canvas.drawImage(photo, ui.Offset.zero, ui.Paint());
    if (source.settings.opacity > 0) {
      drawOverlay(canvas, source.image, placement, source.settings.opacity);
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(photo.width, photo.height);
    } finally {
      picture.dispose();
    }
  }

  /// Paints [overlay] at [placement]; shared with tests.
  static void drawOverlay(
    ui.Canvas canvas,
    ui.Image overlay,
    OverlayPlacement placement,
    double opacity,
  ) {
    final src = ui.Rect.fromLTWH(
      0,
      0,
      overlay.width.toDouble(),
      overlay.height.toDouble(),
    );
    final dst = ui.Rect.fromCenter(
      center: ui.Offset.zero,
      width: placement.size.width,
      height: placement.size.height,
    );
    canvas
      ..save()
      ..translate(placement.center.dx, placement.center.dy)
      ..rotate(placement.rotation);
    if (placement.flipHorizontally) canvas.scale(-1, 1);
    canvas
      ..drawImageRect(
        overlay,
        src,
        dst,
        ui.Paint()
          ..filterQuality = ui.FilterQuality.high
          ..color = ui.Color.fromRGBO(255, 255, 255, opacity),
      )
      ..restore();
  }

  /// Encodes [image] as a baseline JPEG off the UI isolate. The composite is
  /// already upright, so it carries no EXIF orientation.
  Future<Uint8List> encodeJpeg(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw const FileFailure('The composite could not be prepared.');
    }
    final width = image.width;
    final height = image.height;
    final quality = jpegQuality;
    final pixels = TransferableTypedData.fromList(<TypedData>[data]);
    return Isolate.run(() {
      final bytes = pixels.materialize();
      final frame = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: bytes,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      return img.encodeJpg(frame, quality: quality);
    });
  }
}

final compositeRendererProvider = Provider<CompositeRenderer>(
  (ref) => const CompositeRenderer(),
);
