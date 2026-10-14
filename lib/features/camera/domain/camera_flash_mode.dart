import 'package:camera/camera.dart';

enum CameraFlashMode {
  off(FlashMode.off),
  auto(FlashMode.auto),
  on(FlashMode.always),
  torch(FlashMode.torch);

  const CameraFlashMode(this.platform);

  final FlashMode platform;

  bool get isTorch => this == CameraFlashMode.torch;

  static const List<CameraFlashMode> withTorch = <CameraFlashMode>[
    off,
    auto,
    on,
    torch,
  ];

  static const List<CameraFlashMode> withoutTorch = <CameraFlashMode>[
    off,
    auto,
    on,
  ];
}

const List<CameraFlashMode> _flashCycleWithoutTorch = CameraFlashMode
    .withoutTorch;
const List<CameraFlashMode> _flashCycleWithTorch = CameraFlashMode.withTorch;

CameraFlashMode nextFlashMode(
  CameraFlashMode current, {
  required bool includeTorch,
}) {
  final cycle = includeTorch ? _flashCycleWithTorch : _flashCycleWithoutTorch;
  final index = cycle.indexOf(current);
  return cycle[(index + 1) % cycle.length];
}
