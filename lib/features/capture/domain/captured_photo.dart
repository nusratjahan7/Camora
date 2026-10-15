import 'dart:ui' as ui;

import '../../overlay/domain/overlay_settings.dart';
import 'composite_geometry.dart';

/// The reference overlay exactly as it was on screen at the moment of
/// capture, kept so "Save composite" reproduces it later.
///
/// Owns [image] (a clone of the live overlay's handle, so removing or
/// replacing the overlay afterwards cannot free it); call [dispose] when done.
class CompositeSource {
  CompositeSource({
    required this.frame,
    required this.settings,
    required this.image,
    required this.imageSize,
  });

  final PreviewFrame frame;
  final OverlaySettings settings;
  final ui.Image image;

  /// The reference image's original pixel size (the overlay layout uses it).
  final ui.Size imageSize;

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    image.dispose();
  }
}

/// A photo straight from the camera, awaiting review.
class CapturedPhoto {
  CapturedPhoto({required this.path, this.composite});

  /// The camera's original file: never modified.
  final String path;

  /// Present when a reference overlay was loaded at capture time.
  final CompositeSource? composite;

  bool get canComposite => composite != null;
}
