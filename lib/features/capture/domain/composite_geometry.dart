import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import '../../overlay/domain/overlay_geometry.dart';
import '../../overlay/domain/overlay_settings.dart';

/// What the camera screen looked like when the photo was taken: everything
/// needed to put the reference image where the user saw it.
@immutable
class PreviewFrame {
  const PreviewFrame({
    required this.viewport,
    required this.previewAspectRatio,
    required this.devicePixelRatio,
    this.mirrored = false,
    this.quarterTurns = 0,
  });

  /// Logical size of the area the preview covered (and the overlay used).
  final Size viewport;

  /// Width / height of the camera preview as displayed, before cover-cropping.
  final double previewAspectRatio;

  final double devicePixelRatio;

  /// Whether the preview was a mirror image of the photo (front cameras
  /// preview mirrored but save unmirrored photos on Android and iOS).
  final bool mirrored;

  /// Clockwise quarter turns from the screen's orientation to the photo's
  /// upright orientation. Zero whenever the screen follows the device.
  final int quarterTurns;
}

/// Where to draw the reference image on the upright photo, in photo pixels.
@immutable
class OverlayPlacement {
  const OverlayPlacement({
    required this.center,
    required this.size,
    required this.rotation,
    required this.flipHorizontally,
  });

  final Offset center;

  /// Size of the reference image before [rotation] is applied.
  final Size size;

  /// Clockwise rotation in radians.
  final double rotation;

  /// Mirror the reference image itself (front camera).
  final bool flipHorizontally;

  @override
  String toString() =>
      'OverlayPlacement(center: $center, size: $size, rotation: $rotation, '
      'flip: $flipHorizontally)';
}

abstract final class CompositeGeometry {
  /// Maps the overlay as the user saw it onto the captured photo.
  ///
  /// 1. The overlay is laid out in the viewport exactly as the live layer does.
  /// 2. The preview covered the viewport (cropping overflow), so viewport
  ///    points are first mapped into the full preview frame.
  /// 3. Preview and photo streams are centred crops of the same sensor that
  ///    share its long side, so the preview frame sits centred in the photo
  ///    with its long side equal to the photo's long side. When their aspect
  ///    ratios match (the usual case) the frames coincide.
  /// 4. Front-camera mirroring and any screen/device rotation mismatch are
  ///    applied last.
  ///
  /// [photoSize] is the photo's upright size (after EXIF orientation).
  static OverlayPlacement place({
    required PreviewFrame frame,
    required Size photoSize,
    required Size imageSize,
    required OverlaySettings settings,
  }) {
    final viewport = frame.viewport;

    // 1. Overlay in viewport space.
    final base = OverlayGeometry.baseSize(
      image: imageSize,
      viewport: viewport,
      mode: settings.fitMode,
      devicePixelRatio: frame.devicePixelRatio,
    );
    final viewCenter = Offset(
      viewport.width / 2 + settings.offset.dx * viewport.width,
      viewport.height / 2 + settings.offset.dy * viewport.height,
    );
    final viewSize = base * settings.scale;

    // 2. The preview's displayed rect (BoxFit.cover, centred).
    final aspect = frame.previewAspectRatio;
    final cover = math.max(viewport.width / aspect, viewport.height);
    final displayed = Size(aspect * cover, cover);
    final displayedOrigin = Offset(
      (viewport.width - displayed.width) / 2,
      (viewport.height - displayed.height) / 2,
    );

    // 3. The preview frame inside the photo, both in screen orientation.
    final turns = frame.quarterTurns % 4;
    final screenPhoto = turns.isOdd ? photoSize.flipped : photoSize;
    final long = math.max(screenPhoto.width, screenPhoto.height);
    final previewInPhoto = aspect >= 1
        ? Size(long, long / aspect)
        : Size(long * aspect, long);
    final previewOrigin = Offset(
      (screenPhoto.width - previewInPhoto.width) / 2,
      (screenPhoto.height - previewInPhoto.height) / 2,
    );
    final scale = previewInPhoto.width / displayed.width;

    var center = previewOrigin + (viewCenter - displayedOrigin) * scale;
    final size = viewSize * scale;
    var rotation = settings.rotation;

    // 4a. Mirroring, in screen orientation.
    if (frame.mirrored) {
      center = Offset(screenPhoto.width - center.dx, center.dy);
      rotation = -rotation;
    }

    // 4b. Rotate the screen-oriented frame clockwise into the upright photo.
    var space = screenPhoto;
    for (var i = 0; i < turns; i++) {
      center = Offset(space.height - center.dy, center.dx);
      space = space.flipped;
    }
    rotation += turns * math.pi / 2;

    return OverlayPlacement(
      center: center,
      size: size,
      rotation: rotation,
      flipHorizontally: frame.mirrored,
    );
  }

  /// Quarter turns between the screen and the photo, given the device
  /// orientation when the photo was taken. The camera plugins keep the
  /// preview upright for the screen and the photo upright for the device, so
  /// they only differ when the screen does not follow the device (rotation
  /// lock).
  static int quarterTurnsBetween({
    required DeviceOrientation device,
    required bool screenIsLandscape,
  }) {
    final deviceTurns = _counterclockwiseTurns(device);
    final deviceIsLandscape = deviceTurns.isOdd;
    final int screenTurns;
    if (screenIsLandscape == deviceIsLandscape) {
      // Flutter only exposes portrait/landscape; assume the screen follows
      // the device within that.
      screenTurns = deviceTurns;
    } else {
      screenTurns = screenIsLandscape ? 1 : 0;
    }
    // The device turned counterclockwise relative to the screen, so the
    // upright photo is the screen image turned back the other way.
    return (4 - (deviceTurns - screenTurns) % 4) % 4;
  }

  static int _counterclockwiseTurns(DeviceOrientation orientation) =>
      switch (orientation) {
        DeviceOrientation.portraitUp => 0,
        DeviceOrientation.landscapeLeft => 1,
        DeviceOrientation.portraitDown => 2,
        DeviceOrientation.landscapeRight => 3,
      };
}
