import 'package:camera/camera.dart';

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

int nextCameraIndex(int current, int length) {
  if (length <= 0) return 0;
  return (current + 1) % length;
}
