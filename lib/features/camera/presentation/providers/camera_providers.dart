import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';

final camerasProvider = FutureProvider.autoDispose<List<CameraDescription>>((
  ref,
) {
  final errorHandler = ref.watch(appErrorHandlerProvider);
  return errorHandler.guard(availableCameras, operation: 'list cameras');
});

class CameraPermissionController extends AsyncNotifier<AppPermissionStatus> {
  @override
  Future<AppPermissionStatus> build() =>
      ref.watch(permissionServiceProvider).status(AppPermission.camera);

  Future<AppPermissionStatus> request() async {
    state = const AsyncLoading<AppPermissionStatus>();
    try {
      final result = await ref
          .read(permissionServiceProvider)
          .request(AppPermission.camera);
      state = AsyncData<AppPermissionStatus>(result);
      return result;
    } catch (error, stackTrace) {
      final failure = ref.read(appErrorHandlerProvider).map(error, stackTrace);
      state = AsyncError<AppPermissionStatus>(failure, stackTrace);
      return AppPermissionStatus.denied;
    }
  }
}

final cameraPermissionProvider =
    AsyncNotifierProvider.autoDispose<
      CameraPermissionController,
      AppPermissionStatus
    >(CameraPermissionController.new);

class CameraControllerNotifier extends AsyncNotifier<CameraController> {
  CameraController? _controller;
  int _index = 0;

  @override
  Future<CameraController> build() async {
    final cameras = await ref.watch(camerasProvider.future);
    if (cameras.isEmpty) {
      throw const CameraFailure('No camera is available on this device.');
    }
    ref.onDispose(_release);
    return _start(cameras[_index]);
  }

  Future<void> switchCamera() async {
    final cameras =
        ref.read(camerasProvider).value ?? const <CameraDescription>[];
    if (cameras.length < 2) return;

    final errorHandler = ref.read(appErrorHandlerProvider);
    _index = (_index + 1) % cameras.length;
    state = const AsyncLoading<CameraController>();
    await _release();

    try {
      state = AsyncData<CameraController>(await _start(cameras[_index]));
    } catch (error, stackTrace) {
      state = AsyncError<CameraController>(
        errorHandler.map(error, stackTrace),
        stackTrace,
      );
    }
  }

  Future<CameraController> _start(CameraDescription description) async {
    final errorHandler = ref.read(appErrorHandlerProvider);
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
    } catch (error, stackTrace) {
      await controller.dispose();
      throw errorHandler.map(error, stackTrace);
    }

    _controller = controller;
    return controller;
  }

  Future<void> _release() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

final cameraControllerProvider =
    AsyncNotifierProvider.autoDispose<
      CameraControllerNotifier,
      CameraController
    >(CameraControllerNotifier.new);
