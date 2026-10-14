import 'dart:io';
import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/files/file_service.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../data/camera_service.dart';
import '../../domain/camera_capabilities.dart';
import '../../domain/camera_flash_mode.dart';
import '../../domain/camera_selection.dart';
import '../../domain/camera_session.dart';

final camerasProvider = FutureProvider.autoDispose<List<CameraDescription>>((
  ref,
) {
  final errorHandler = ref.watch(appErrorHandlerProvider);
  return errorHandler.guard(
    () => ref.watch(cameraServiceProvider).listCameras(),
    operation: 'list cameras',
  );
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

class CameraSessionController extends AsyncNotifier<CameraSession> {
  static const Duration _focusHold = Duration(seconds: 2);

  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _index = 0;
  int _generation = 0;
  bool _paused = false;
  bool _capturing = false;
  bool _disposed = false;

  CameraService get _service => ref.read(cameraServiceProvider);
  AppErrorHandler get _errors => ref.read(appErrorHandlerProvider);
  FileService get _files => ref.read(fileServiceProvider);

  @override
  Future<CameraSession> build() async {
    final cameras = await ref.watch(camerasProvider.future);
    if (cameras.isEmpty) {
      throw const CameraFailure('No camera is available on this device.');
    }

    _cameras = cameras;
    _index = indexOfDefaultCamera(cameras);
    ref.onDispose(() {
      _disposed = true;
      _release();
    });

    final session = await _open(_index);
    if (session == null) {
      throw const CameraFailure('The camera could not be started on this '
          'device.');
    }
    return session;
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2 || _capturing) return;

    state = const AsyncLoading<CameraSession>();
    try {
      final session = await _open(nextCameraIndex(_index, _cameras.length));
      if (session != null) _emit(session);
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  Future<XFile?> capture() async {
    final session = state.value;
    if (session == null || _capturing) return null;

    _capturing = true;
    _emit(session.copyWith(isCapturing: true));

    try {
      final shot = await _service.capture(session.controller);
      final stored = await _storeCapture(shot);
      _emit(
        (state.value ?? session).copyWith(
          isCapturing: false,
          lastCapture: stored,
        ),
      );
      return stored;
    } catch (error, stackTrace) {
      _emit((state.value ?? session).copyWith(isCapturing: false));
      throw _errors.map(error, stackTrace);
    } finally {
      _capturing = false;
    }
  }

  Future<void> setFlashMode(CameraFlashMode mode) async {
    final session = state.value;
    if (session == null || !session.capabilities.supportsFlash) return;

    final controller = session.controller;
    try {
      await _service.setFlashMode(controller, mode.platform);
      final current = state.value;
      if (current != null && identical(current.controller, controller)) {
        _emit(current.copyWith(flashMode: mode));
      }
    } catch (error, stackTrace) {
      _errors.report(error, stackTrace, operation: 'set flash mode');
      final current = state.value;
      if (current != null && identical(current.controller, controller)) {
        _emit(
          current.copyWith(
            capabilities: current.capabilities.copyWith(
              supportsFlash: false,
              supportsTorch: false,
            ),
          ),
        );
      }
    }
  }

  Future<void> cycleFlashMode() async {
    final session = state.value;
    if (session == null) return;
    await setFlashMode(
      nextFlashMode(
        session.flashMode,
        includeTorch: session.capabilities.supportsTorch,
      ),
    );
  }

  Future<void> setZoom(double zoom) async {
    final session = state.value;
    if (session == null || !session.capabilities.supportsZoom) return;

    final clamped = zoom.clamp(
      session.capabilities.minZoom,
      session.capabilities.maxZoom,
    );
    if (clamped == session.zoom) return;

    _emit(session.copyWith(zoom: clamped));
    try {
      await _service.setZoomLevel(session.controller, clamped);
    } catch (error, stackTrace) {
      _errors.report(error, stackTrace, operation: 'set zoom');
    }
  }

  Future<void> focusAt(Offset point) async {
    final session = state.value;
    if (session == null || !session.capabilities.supportsFocusPoint) return;

    final controller = session.controller;
    try {
      await _service.setFocusMode(controller, FocusMode.locked);
      await _service.setFocusPoint(controller, point);
      await Future<void>.delayed(_focusHold);
      if (!identical(state.value?.controller, controller)) return;
      await _service.setFocusMode(controller, FocusMode.auto);
      await _service.resetFocusPoint(controller);
    } catch (error, stackTrace) {
      _errors.report(error, stackTrace, operation: 'focus at point');
    }
  }

  Future<void> handleAppLifecycle(AppLifecycleState lifecycle) async {
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        await _resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        await _pause();
      case AppLifecycleState.detached:
        await _suspend();
    }
  }

  Future<CameraSession?> _open(int index) async {
    await _release();

    final generation = ++_generation;
    final description = _cameras[index];
    final controller = _service.createController(description);

    try {
      await _service.initialize(controller);
    } catch (error, stackTrace) {
      await controller.dispose();
      throw _errors.map(error, stackTrace);
    }

    if (generation != _generation || _disposed) {
      await controller.dispose();
      return null;
    }

    _controller = controller;
    _index = index;

    final capabilities = await _capabilities(controller, description);
    return CameraSession(
      controller: controller,
      description: description,
      cameras: _cameras,
      capabilities: capabilities,
      zoom: capabilities.minZoom,
    );
  }

  Future<CameraCapabilities> _capabilities(
    CameraController controller,
    CameraDescription description,
  ) async {
    final base = CameraCapabilities.fromLensDirection(
      description.lensDirection,
    ).copyWith(supportsFocusPoint: controller.value.focusPointSupported);

    try {
      final minZoom = await _service.minZoom(controller);
      final maxZoom = await _service.maxZoom(controller);
      return base.copyWith(minZoom: minZoom, maxZoom: maxZoom);
    } catch (error, stackTrace) {
      _errors.logger.warning(
        'Zoom range unavailable for ${description.name}.',
        error,
        stackTrace,
      );
      return base;
    }
  }

  Future<XFile> _storeCapture(XFile shot) async {
    final target = await _files.createCaptureFile();
    final saved = await File(shot.path).copy(target.path);
    return XFile(saved.path);
  }

  Future<void> _pause() async {
    if (_paused || _disposed) return;
    _paused = true;
    _generation++;
    await _release();
    if (state.hasValue) {
      state = const AsyncLoading<CameraSession>();
    }
  }

  Future<void> _resume() async {
    if (!_paused || _disposed) return;
    _paused = false;
    if (_cameras.isEmpty) return;

    state = const AsyncLoading<CameraSession>();
    try {
      final session = await _open(_index);
      if (session != null) _emit(session);
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  Future<void> _suspend() async {
    _paused = true;
    _generation++;
    await _release();
  }

  Future<void> _release() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;

    try {
      await _service.dispose(controller);
    } catch (error, stackTrace) {
      _errors.logger.warning(
        'The camera could not be released cleanly.',
        error,
        stackTrace,
      );
    }
  }

  void _emit(CameraSession session) {
    if (_disposed) return;
    state = AsyncData<CameraSession>(session);
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    state = AsyncError<CameraSession>(_errors.map(error, stackTrace), stackTrace);
  }
}

final cameraSessionProvider =
    AsyncNotifierProvider.autoDispose<CameraSessionController, CameraSession>(
      CameraSessionController.new,
    );
