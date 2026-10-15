import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'overlay_fit_mode.dart';
import 'overlay_settings.dart';

abstract final class OverlayGeometry {
  static const double minScale = 0.1;
  static const double maxScale = 8.0;

  /// The image center may move at most this far from the viewport center (as
  /// a fraction of the viewport), so it can never be lost off-screen.
  static const double maxOffset = 0.5;

  /// Rotations within this many radians of a quarter turn snap to it.
  static const double rotationSnap = 4 * math.pi / 180;

  /// Size of the image before the user's scale, in logical pixels, keeping its
  /// aspect ratio. [devicePixelRatio] maps original pixels for [OverlayFitMode.center].
  static Size baseSize({
    required Size image,
    required Size viewport,
    required OverlayFitMode mode,
    required double devicePixelRatio,
  }) {
    if (image.isEmpty || viewport.isEmpty) return Size.zero;

    final widthRatio = viewport.width / image.width;
    final heightRatio = viewport.height / image.height;
    final factor = switch (mode) {
      OverlayFitMode.fit => math.min(widthRatio, heightRatio),
      OverlayFitMode.fill => math.max(widthRatio, heightRatio),
      OverlayFitMode.center => 1 / devicePixelRatio,
    };
    return Size(image.width * factor, image.height * factor);
  }

  /// Applies an in-progress pinch/drag to the transform captured when the
  /// gesture started. [translation] is in logical pixels.
  static OverlaySettings applyGesture({
    required OverlaySettings start,
    required Size viewport,
    required Offset translation,
    required double scale,
    required double rotation,
  }) {
    if (viewport.isEmpty) return start;
    final offset =
        start.offset +
        Offset(
          translation.dx / viewport.width,
          translation.dy / viewport.height,
        );
    return start.copyWith(
      offset: clampOffset(offset),
      scale: clampScale(start.scale * scale),
      rotation: start.rotation + rotation,
    );
  }

  static double clampScale(double scale) =>
      scale.isFinite ? scale.clamp(minScale, maxScale).toDouble() : 1.0;

  static Offset clampOffset(Offset offset) => Offset(
    offset.dx.clamp(-maxOffset, maxOffset).toDouble(),
    offset.dy.clamp(-maxOffset, maxOffset).toDouble(),
  );

  /// Normalizes to (-π, π] and snaps to the nearest quarter turn when close.
  static double settleRotation(double radians) {
    var normalized = radians % (2 * math.pi);
    if (normalized > math.pi) normalized -= 2 * math.pi;

    const quarter = math.pi / 2;
    final nearest = (normalized / quarter).round() * quarter;
    final snapped = (normalized - nearest).abs() <= rotationSnap
        ? nearest
        : normalized;
    // Avoid -0.0 and keep π rather than -π.
    if (snapped == 0) return 0;
    return snapped <= -math.pi ? math.pi : snapped;
  }
}
