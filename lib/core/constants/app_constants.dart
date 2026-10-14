abstract final class AppConstants {
  static const String appName = 'Camera Overlay';
  static const String appTagline = 'Line up any shot with a reference image.';

  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration standardAnimation = Duration(milliseconds: 260);

  static const double minOverlayOpacity = 0.0;
  static const double maxOverlayOpacity = 1.0;
  static const double defaultOverlayOpacity = 0.5;

  static const double minTapTarget = 48.0;
  static const double controlBarHeight = 120.0;
}
