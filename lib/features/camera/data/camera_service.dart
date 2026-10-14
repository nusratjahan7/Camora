import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin seam over `package:camera` so controllers never talk to the plugin
/// directly and the lifecycle stays testable.
class CameraService {
  const CameraService({this.resolutionPreset = ResolutionPreset.high});

  /// Stills are captured at ~720p: sharp enough for an overlay composite while
  /// keeping the preview at a responsive frame rate on mid-range devices.
  final ResolutionPreset resolutionPreset;

  Future<List<CameraDescription>> listCameras() => availableCameras();

  CameraController createController(CameraDescription description) {
    return CameraController(
      description,
      resolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
  }

  Future<void> initialize(CameraController controller) => controller.initialize();

  Future<void> dispose(CameraController controller) => controller.dispose();

  Future<XFile> capture(CameraController controller) => controller.takePicture();

  Future<void> setFlashMode(CameraController controller, FlashMode mode) =>
      controller.setFlashMode(mode);

  Future<void> setZoomLevel(CameraController controller, double zoom) =>
      controller.setZoomLevel(zoom);

  Future<double> minZoom(CameraController controller) =>
      controller.getMinZoomLevel();

  Future<double> maxZoom(CameraController controller) =>
      controller.getMaxZoomLevel();

  Future<void> setFocusMode(CameraController controller, FocusMode mode) =>
      controller.setFocusMode(mode);

  Future<void> setFocusPoint(CameraController controller, Offset point) =>
      controller.setFocusPoint(point);

  Future<void> resetFocusPoint(CameraController controller) =>
      controller.setFocusPoint(null);
}

final cameraServiceProvider = Provider<CameraService>(
  (ref) => const CameraService(),
);
