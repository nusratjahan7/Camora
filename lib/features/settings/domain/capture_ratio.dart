import 'dart:ui' show Rect;

/// Output framing for a shot, independent of which lens is open.
///
/// The ratio is a presentation and output choice only: the camera stream keeps
/// running at its own resolution, and the still is cropped to match what the
/// preview showed.
enum CaptureRatio {
  classic43('4:3', 4 / 3),
  widescreen169('16:9', 16 / 9),
  square11('1:1', 1),
  fullScreen('Full', null);

  const CaptureRatio(this.label, this.value);

  /// Short form for the quick control on the camera bar.
  final String label;

  /// Width ÷ height, or null for [fullScreen]: its shape is the available
  /// preview area's, which is only known once the area has been measured.
  final double? value;

  /// Long form for tooltips and screen readers.
  String get spokenLabel => this == fullScreen ? 'Full screen' : label;

  /// The ratio to crop to for [available], resolving [fullScreen] to that
  /// area's own shape rather than a hard-coded one.
  double resolve(Rect available) =>
      value ?? (available.isEmpty ? 1 : available.width / available.height);

  /// The next mode in the cycle, for the quick control on the camera bar.
  CaptureRatio get next => values[(index + 1) % values.length];
}
