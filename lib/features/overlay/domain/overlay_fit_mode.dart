/// How the reference image is sized against the camera viewport before the
/// user's own drag, pinch and rotate are applied. Every mode keeps the image's
/// aspect ratio; only [fill] crops.
enum OverlayFitMode {
  /// The whole image is visible, letterboxed inside the viewport.
  fit,

  /// The image covers the whole viewport; overflowing edges are cropped.
  fill,

  /// The image is shown at its original pixel size, centered.
  center;

  String get label => switch (this) {
    OverlayFitMode.fit => 'Fit',
    OverlayFitMode.fill => 'Fill',
    OverlayFitMode.center => 'Center',
  };
}
