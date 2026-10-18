import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin seam over `package:camera` so controllers never talk to the plugin
/// directly and the lifecycle stays testable.
class CameraService {
  const CameraService({this.resolutionPreset = ResolutionPreset.veryHigh});

  /// ~1080p: detailed enough for an overlay composite, while the preview (which
  /// shares the preset) stays at full frame rate on mid-range devices. `max`
  /// would push 12MP+ frames through the preview pipeline for no visible gain.
  final ResolutionPreset resolutionPreset;

  Future<List<CameraDescription>> listCameras() => availableCameras();

  CameraController createController(
    CameraDescription description, {
    bool enableAudio = false,
  }) {
    return CameraController(
      description,
      resolutionPreset,
      enableAudio: enableAudio,
    );
  }

  Future<void> initialize(CameraController controller) =>
      controller.initialize();

  Future<void> dispose(CameraController controller) => controller.dispose();

  Future<XFile> capture(CameraController controller) =>
      controller.takePicture();

  /// Starts muxing a clip. The platform recorder writes a finished file with
  /// the right orientation and synchronised audio, so nothing here re-encodes.
  Future<void> startVideoRecording(CameraController controller) =>
      controller.startVideoRecording();

  Future<XFile> stopVideoRecording(CameraController controller) =>
      controller.stopVideoRecording();

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

  Future<void> setExposurePoint(CameraController controller, Offset point) =>
      controller.setExposurePoint(point);

  Future<void> resetFocusPoint(CameraController controller) =>
      controller.setFocusPoint(null);
}

final cameraServiceProvider = Provider<CameraService>(
  (ref) => const CameraService(),
);
