import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Geometry shared by the preview, the capture crop and the tests.
///
/// The preview draws the camera stream scaled to *cover* the viewport, the
/// selected ratio is a rect inside the safe-area-aware available area, and a
/// captured still is cropped to exactly that same rect. Keeping all three
/// expressed here is what keeps the live framing and the saved photo in step —
/// the one invariant the whole feature rests on.
abstract final class FrameGeometry {
  /// How close two aspect ratios must be to count as the same framing. Below
  /// this the still is saved untouched, so the common case never re-encodes.
  static const double ratioEpsilon = 0.005;

  static bool sameRatio(double a, double b, {double epsilon = ratioEpsilon}) {
    if (!a.isFinite || !b.isFinite) return false;
    return (a - b).abs() <= epsilon;
  }

  /// The area the frame may occupy: [viewport] less the safe-area insets, so a
  /// notch, a status bar or the home indicator never eats into the shot.
  ///
  /// A window too small for its own insets falls back to the whole viewport
  /// rather than an empty frame.
  static Rect availableArea({
    required Size viewport,
    required EdgeInsets safeInsets,
  }) {
    if (viewport.isEmpty) return Rect.zero;
    final width = viewport.width - safeInsets.horizontal;
    final height = viewport.height - safeInsets.vertical;
    if (width <= 0 || height <= 0) return Offset.zero & viewport;
    return Rect.fromLTWH(safeInsets.left, safeInsets.top, width, height);
  }

  /// Where the stream image lands on screen when drawn to cover [viewport],
  /// centred. Its origin is negative on whichever axis overflows.
  ///
  /// [sensor] is the stream's display aspect ratio (width ÷ height).
  static Rect coverRect({required Size viewport, required double sensor}) {
    if (viewport.isEmpty || !sensor.isFinite || sensor <= 0) {
      return Offset.zero & viewport;
    }
    final scale = math.max(viewport.width / sensor, viewport.height);
    return Rect.fromCenter(
      center: viewport.center(Offset.zero),
      width: sensor * scale,
      height: scale,
    );
  }

  /// The largest rect of aspect [aspect] that fits inside [available],
  /// centred.
  ///
  /// A null [aspect] is "full screen": the frame follows the available area
  /// itself, so it tracks the device's real preview area rather than a
  /// hard-coded shape.
  static Rect frameRect({
    required Rect available,
    required double? aspect,
  }) {
    if (available.isEmpty || aspect == null) return available;
    if (!aspect.isFinite || aspect <= 0) return available;

    final heightIfFullWidth = available.width / aspect;
    final frame = heightIfFullWidth <= available.height
        ? Size(available.width, heightIfFullWidth)
        : Size(available.height * aspect, available.height);
    return Rect.fromCenter(
      center: available.center,
      width: frame.width,
      height: frame.height,
    );
  }

  /// The part of a still that the frame showed, in source pixels.
  ///
  /// [displayedImage] is [coverRect] for the viewport, [frame] is the visible
  /// capture rect and [source] is the captured image's pixel size. The result
  /// is snapped to exactly [targetRatio] so the saved photo matches the
  /// preview rather than the one-pixel error of a rounded rect, and is always
  /// kept inside [source].
  ///
  /// Returns null when there is nothing meaningful to crop — a degenerate
  /// frame, image or ratio — and the caller keeps the original bytes.
  static Rect? cropRectForFrame({
    required Rect displayedImage,
    required Rect frame,
    required Size source,
    required double targetRatio,
  }) {
    if (displayedImage.isEmpty || frame.isEmpty || source.isEmpty) return null;
    if (!targetRatio.isFinite || targetRatio <= 0) return null;

    final visible = displayedImage.intersect(frame);
    if (visible.isEmpty) return null;

    final maxWidth = visible.width / displayedImage.width * source.width;
    final maxHeight = visible.height / displayedImage.height * source.height;
    var width = maxWidth;
    var height = width / targetRatio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * targetRatio;
    }
    width = width.roundToDouble().clamp(1.0, source.width);
    height = height.roundToDouble().clamp(1.0, source.height);

    final center = Offset(
      (visible.center.dx - displayedImage.left) /
          displayedImage.width *
          source.width,
      (visible.center.dy - displayedImage.top) /
          displayedImage.height *
          source.height,
    );
    final left = (center.dx - width / 2).clamp(0.0, source.width - width);
    final top = (center.dy - height / 2).clamp(0.0, source.height - height);
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Normalized (0..1) stream coordinates for a point on screen, or null when
  /// it falls outside the image. Mirrors how the preview is drawn, so metering
  /// lands where the user tapped.
  static Offset? focusPoint({
    required Offset point,
    required Rect displayedImage,
  }) {
    if (displayedImage.isEmpty || !displayedImage.contains(point)) return null;
    return Offset(
      ((point.dx - displayedImage.left) / displayedImage.width).clamp(0.0, 1.0),
      ((point.dy - displayedImage.top) / displayedImage.height).clamp(
        0.0,
        1.0,
      ),
    );
  }
}
