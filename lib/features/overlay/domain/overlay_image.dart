import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// A decoded reference image, ready to paint.
///
/// [image] is GPU-backed memory owned by whoever holds this object; it must be
/// disposed once nothing paints it any more.
@immutable
class OverlayImage {
  const OverlayImage({
    required this.image,
    required this.originalSize,
    required this.name,
  });

  /// Decoded pixels, downsampled to a bounded size.
  final ui.Image image;

  /// Pixel size of the file before downsampling, used for "actual size".
  final ui.Size originalSize;

  final String name;

  ui.Size get decodedSize =>
      ui.Size(image.width.toDouble(), image.height.toDouble());

  double get aspectRatio => originalSize.width / originalSize.height;
}
