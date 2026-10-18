import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'camera_capabilities.dart';
import 'camera_flash_mode.dart';
import 'capture_mode.dart';

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
    this.captureMode = CaptureMode.photo,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
  });

  final CameraController controller;
  final CameraDescription description;
  final List<CameraDescription> cameras;
  final CameraCapabilities capabilities;
  final CameraFlashMode flashMode;
  final double zoom;
  final bool isCapturing;
  final XFile? lastCapture;

  /// Photo or video: decides what the shutter does, and whether the camera was
  /// opened with audio.
  final CaptureMode captureMode;

  final bool isRecording;
  final Duration recordingDuration;

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
    CaptureMode? captureMode,
    bool? isRecording,
    Duration? recordingDuration,
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
      captureMode: captureMode ?? this.captureMode,
      isRecording: isRecording ?? this.isRecording,
      recordingDuration: recordingDuration ?? this.recordingDuration,
    );
  }
}
