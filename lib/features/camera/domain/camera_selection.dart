import 'package:camera/camera.dart';

import '../../settings/domain/preferred_camera.dart';

int indexOfDefaultCamera(List<CameraDescription> cameras) {
  if (cameras.isEmpty) return 0;
  final back = cameras.indexWhere(
    (camera) => camera.lensDirection == CameraLensDirection.back,
  );
  return back == -1 ? 0 : back;
}

CameraDescription? selectDefaultCamera(List<CameraDescription> cameras) {
  if (cameras.isEmpty) return null;
  return cameras[indexOfDefaultCamera(cameras)];
}

/// Index of the camera the user asked the screen to open with, falling back to
/// the default (rear) lens when that direction is not available.
int indexOfPreferredCamera(
  List<CameraDescription> cameras,
  PreferredCamera preference,
) {
  if (cameras.isEmpty) return 0;
  final wanted = preference == PreferredCamera.front
      ? CameraLensDirection.front
      : CameraLensDirection.back;
  final index = cameras.indexWhere((camera) => camera.lensDirection == wanted);
  return index == -1 ? indexOfDefaultCamera(cameras) : index;
}

int nextCameraIndex(int current, int length) {
  if (length <= 0) return 0;
  return (current + 1) % length;
}
