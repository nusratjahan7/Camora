import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Maps a point in a viewport onto the normalized (0..1) coordinates of a
/// preview that is scaled to cover that viewport (cropping the overflow).
///
/// Returns null when the preview size is degenerate.
Offset? coverPointToPreview({
  required Offset point,
  required Size viewport,
  required Size preview,
}) {
  if (preview.isEmpty || viewport.isEmpty) return null;

  final scale = math.max(
    viewport.width / preview.width,
    viewport.height / preview.height,
  );
  final displayed = Size(preview.width * scale, preview.height * scale);
  final origin = Offset(
    (viewport.width - displayed.width) / 2,
    (viewport.height - displayed.height) / 2,
  );
  final local = point - origin;

  return Offset(
    (local.dx / displayed.width).clamp(0.0, 1.0),
    (local.dy / displayed.height).clamp(0.0, 1.0),
  );
}
