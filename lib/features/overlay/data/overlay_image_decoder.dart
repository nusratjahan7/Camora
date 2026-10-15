import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/overlay_image.dart';

/// Turns picked image bytes into a paintable [OverlayImage].
///
/// The image is decoded once, straight to a bounded size: a 48MP photo would
/// otherwise take ~190MB of GPU memory to draw a translucent guide.
class OverlayImageDecoder {
  const OverlayImageDecoder({
    this.maxDimension = 2048,
    this.maxFileBytes = 64 * 1024 * 1024,
  });

  /// Longest side, in pixels, of the decoded image.
  final int maxDimension;

  /// Files larger than this are rejected before decoding.
  final int maxFileBytes;

  static const String _unreadable =
      'This image could not be opened. It may be damaged or in a format this '
      'device does not support. Try a JPEG or PNG.';

  Future<OverlayImage> decode(Uint8List bytes, {required String name}) async {
    if (bytes.isEmpty) {
      throw const ImageSelectionFailure('The selected file is empty.');
    }
    if (bytes.length > maxFileBytes) {
      throw const ImageSelectionFailure(
        'This image is too large to use as a reference.',
      );
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      if (width <= 0 || height <= 0) {
        throw const ImageSelectionFailure(_unreadable);
      }

      final factor = math.min(1.0, maxDimension / math.max(width, height));
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (width * factor).round()),
        targetHeight: math.max(1, (height * factor).round()),
      );
      // Animated images (GIF, WebP) use their first frame as the guide.
      final frame = await codec.getNextFrame();
      return OverlayImage(
        image: frame.image,
        originalSize: ui.Size(width.toDouble(), height.toDouble()),
        name: name,
      );
    } on ImageSelectionFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw ImageSelectionFailure(
        _unreadable,
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

final overlayImageDecoderProvider = Provider<OverlayImageDecoder>(
  (ref) => const OverlayImageDecoder(),
);
