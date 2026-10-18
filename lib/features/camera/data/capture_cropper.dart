import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/capture_crop.dart';
import '../domain/frame_geometry.dart';

/// Quality of the single re-encode a crop costs. High enough that a cropped
/// capture is visually indistinguishable from the original.
const int _jpegQuality = 95;

/// Crops a captured JPEG to the frame the preview showed.
///
/// Runs on a worker isolate: decoding and encoding a multi-megapixel photo is
/// far too slow for the frame budget.
///
/// Returns `null` when there is nothing to do — the still already matches the
/// requested ratio, or the bytes cannot be decoded — so the caller keeps the
/// camera's own bytes byte for byte. A capture is never lost to a failed crop.
Future<Uint8List?> cropToFrame(Uint8List bytes, CaptureCrop crop) {
  return compute(
    _cropToFrame,
    _CropJob(
      bytes: bytes,
      left: crop.frame.left,
      top: crop.frame.top,
      width: crop.frame.width,
      height: crop.frame.height,
      aspectRatio: crop.aspectRatio,
    ),
  );
}

/// Primitives only, so the job copies to the isolate cheaply.
class _CropJob {
  const _CropJob({
    required this.bytes,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.aspectRatio,
  });

  final Uint8List bytes;
  final double left;
  final double top;
  final double width;
  final double height;
  final double aspectRatio;
}

Uint8List? _cropToFrame(_CropJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return null;

  // Upright pixels, so the crop lines up with what the preview showed. This
  // also bakes the orientation into the pixels, since re-encoding drops EXIF.
  final upright = img.bakeOrientation(decoded);
  final source = Size(upright.width.toDouble(), upright.height.toDouble());
  if (source.isEmpty) return null;

  if (FrameGeometry.sameRatio(
    source.width / source.height,
    job.aspectRatio,
  )) {
    return null;
  }

  final rect = FrameGeometry.cropRectForFrame(
    displayedImage: const Rect.fromLTWH(0, 0, 1, 1),
    frame: Rect.fromLTWH(job.left, job.top, job.width, job.height),
    source: source,
    targetRatio: job.aspectRatio,
  );
  if (rect == null) return null;

  final cropped = img.copyCrop(
    upright,
    x: rect.left.toInt(),
    y: rect.top.toInt(),
    width: rect.width.toInt(),
    height: rect.height.toInt(),
  );
  return img.encodeJpg(cropped, quality: _jpegQuality);
}
