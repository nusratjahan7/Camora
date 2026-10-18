import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// The frame a shot is cropped to.
///
/// [frame] is measured against the stream image as the preview drew it (the
/// same normalized space [FrameGeometry.cropRectForFrame] expects), and
/// [aspectRatio] is the exact shape the saved photo must end up with.
@immutable
class CaptureCrop {
  const CaptureCrop({required this.frame, required this.aspectRatio});

  final Rect frame;
  final double aspectRatio;
}
