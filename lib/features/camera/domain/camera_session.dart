import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'camera_capabilities.dart';
import 'camera_flash_mode.dart';

@immutable
class CameraSession {
  const CameraSession({
    required this.controller,
    required this.description,
    required this.cameras,
    required this.capabilities,
    this.flashMode = CameraFlashMode.off,
    this.zoom = 1.0,
    this.isCapturing = false,
    this.lastCapture,
  });

  final CameraController controller;
  final CameraDescription description;
  final List<CameraDescription> cameras;
  final CameraCapabilities capabilities;
  final CameraFlashMode flashMode;
  final double zoom;
  final bool isCapturing;
  final XFile? lastCapture;

  bool get canSwitchCamera => cameras.length > 1;

  bool get isFrontFacing =>
      description.lensDirection == CameraLensDirection.front;

  CameraSession copyWith({
    CameraController? controller,
    CameraDescription? description,
    List<CameraDescription>? cameras,
    CameraCapabilities? capabilities,
    CameraFlashMode? flashMode,
    double? zoom,
    bool? isCapturing,
    XFile? lastCapture,
  }) {
    return CameraSession(
      controller: controller ?? this.controller,
      description: description ?? this.description,
      cameras: cameras ?? this.cameras,
      capabilities: capabilities ?? this.capabilities,
      flashMode: flashMode ?? this.flashMode,
      zoom: zoom ?? this.zoom,
      isCapturing: isCapturing ?? this.isCapturing,
      lastCapture: lastCapture ?? this.lastCapture,
    );
  }
}
