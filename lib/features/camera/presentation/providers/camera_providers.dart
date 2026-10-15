import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/files/file_service.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../data/camera_service.dart';
import '../../domain/camera_capabilities.dart';
import '../../domain/camera_errors.dart';
import '../../domain/camera_flash_mode.dart';
import '../../domain/camera_selection.dart';
import '../../domain/camera_session.dart';

/// Riverpod 3 retries failing providers automatically. Camera failures need
/// the user (a permission, another app holding the camera), so they surface
/// once and the screen offers an explicit retry instead of re-opening the
/// hardware in a loop.
Duration? _noRetry(int retryCount, Object error) => null;

final camerasProvider = FutureProvider.autoDispose<List<CameraDescription>>((
  ref,
) async {
  final errorHandler = ref.watch(appErrorHandlerProvider);
  try {
    return await ref.watch(cameraServiceProvider).listCameras();
  } catch (error, stackTrace) {
    errorHandler.report(error, stackTrace, operation: 'list cameras');
    final failure = errorHandler.map(error, stackTrace);
    // CameraX reports a missing or busy camera service as a raw platform
    // error; keep its details in the log, not on screen.
    if (failure is CameraFailure) throw failure;
    throw CameraFailure(
      'No camera could be found. Check that no other app is using it, '
      'then try again.',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}, retry: _noRetry);

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
      if (ref.mounted) state = AsyncData<AppPermissionStatus>(result);
      return result;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        final failure = ref
            .read(appErrorHandlerProvider)
            .map(error, stackTrace);
        state = AsyncError<AppPermissionStatus>(failure, stackTrace);
      }
      return AppPermissionStatus.denied;
    }
  }
}

final cameraPermissionProvider =
    AsyncNotifierProvider.autoDispose<
      CameraPermissionController,
      AppPermissionStatus
    >(CameraPermissionController.new, retry: _noRetry);

/// Owns the [CameraController] for the camera screen.
///
/// Riverpod keeps the previous value around while a new state is loading, so
/// `state.value` can point at a controller that was already released. Every
/// camera operation therefore goes through [_session], which is cleared the
/// moment its controller is released, and never through `state.value`.
class CameraSessionController extends AsyncNotifier<CameraSession> {
  CameraController? _controller;
  CameraSession? _session;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _index = 0;
  CameraFlashMode _preferredFlash = CameraFlashMode.off;

  /// Bumped whenever an in-flight open must be abandoned (pause, dispose, a
  /// newer open). An open only publishes if its generation is still current.
  int _generation = 0;
  bool _active = false;
  bool _building = false;
  bool _paused = false;
  bool _capturing = false;
  bool _switching = false;
  bool _changingFlash = false;
  Future<void> _releasing = Future<void>.value();
  Completer<void>? _resumed;

  double? _pendingZoom;
  bool _zoomInFlight = false;

  // Captured in build: releasing the camera continues after dispose, when
  // `ref` may no longer be used.
  late CameraService _service;
  late AppErrorHandler _errors;
  late FileService _files;

  bool get _isActive => _active && ref.mounted;

  @override
  Future<CameraSession> build() async {
    // The notifier instance survives rebuilds (e.g. a retry), so per-build
    // flags are reset here rather than relying on field initializers.
    _active = true;
    _paused = false;
    _service = ref.read(cameraServiceProvider);
    _errors = ref.read(appErrorHandlerProvider);
    _files = ref.read(fileServiceProvider);
    ref.onDispose(_deactivate);

    final cameras = await ref.watch(camerasProvider.future);
    if (cameras.isEmpty) {
      throw const CameraFailure('No camera is available on this device.');
    }
    _index = _indexToKeep(cameras);
    _cameras = cameras;

    _building = true;
    try {
      while (true) {
        // Never open the camera while backgrounded; a pause during an open
        // also lands here, and the open is retried once the app returns.
        if (_paused) await (_resumed ??= Completer<void>()).future;
        if (!_isActive) {
          throw const CameraFailure('The camera was closed before it started.');
        }
        final session = await _open(_index);
        if (session != null) return session;
      }
    } finally {
      _building = false;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2 || _capturing || _switching || _paused) return;
    if (_session == null) return;

    final previous = _index;
    _index = nextCameraIndex(_index, _cameras.length);
    _switching = true;
    state = const AsyncLoading<CameraSession>();
    try {
      final session = await _open(_index);
      if (session != null) _emit(session);
    } catch (error, stackTrace) {
      // Retry should reopen the camera that last worked.
      _index = previous;
      _fail(error, stackTrace);
    } finally {
      _switching = false;
    }
  }

  /// Takes a still and stores it in the app's captures directory.
  ///
  /// Returns null without doing anything when the camera is not ready or a
  /// capture is already running, so repeated shutter taps are harmless.
  Future<XFile?> capture() async {
    final session = _session;
    if (session == null || _capturing || _switching) return null;
    if (session.controller.value.isTakingPicture) return null;

    _capturing = true;
    _emit(session.copyWith(isCapturing: true));
    try {
      final shot = await _service.capture(session.controller);
      final stored = await _storeCapture(shot);
      _updateIfCurrent(
        session.controller,
        (current) => current.copyWith(isCapturing: false, lastCapture: stored),
      );
      return stored;
    } catch (error, stackTrace) {
      _updateIfCurrent(
        session.controller,
        (current) => current.copyWith(isCapturing: false),
      );
      _errors.report(error, stackTrace, operation: 'capture photo');
      throw _errors.map(error, stackTrace);
    } finally {
      _capturing = false;
    }
  }

  Future<void> setFlashMode(CameraFlashMode mode) async {
    final session = _session;
    if (session == null || !session.capabilities.supportsFlash) return;
    if (mode.isTorch && !session.capabilities.supportsTorch) return;

    if (_changingFlash) return;

    final controller = session.controller;
    _changingFlash = true;
    try {
      await _service.setFlashMode(controller, mode.platform);
      _preferredFlash = mode;
      _updateIfCurrent(
        controller,
        (current) => current.copyWith(flashMode: mode),
      );
    } catch (error, stackTrace) {
      _errors.report(error, stackTrace, operation: 'set flash mode');
      // Hide whatever the hardware just refused instead of failing again.
      _updateIfCurrent(
        controller,
        (current) => current.copyWith(
          capabilities: mode.isTorch
              ? current.capabilities.copyWith(supportsTorch: false)
              : current.capabilities.copyWith(
                  supportsFlash: false,
                  supportsTorch: false,
                ),
        ),
      );
    } finally {
      _changingFlash = false;
    }
  }

  Future<void> cycleFlashMode() async {
    final session = _session;
    if (session == null) return;
    await setFlashMode(
      nextFlashMode(
        session.flashMode,
        includeTorch: session.capabilities.supportsTorch,
      ),
    );
  }

  /// Updates the zoom immediately in state and coalesces platform calls, so a
  /// slider drag or pinch sends only the latest value once the previous call
  /// has finished.
  Future<void> setZoom(double zoom) async {
    final session = _session;
    if (session == null || !session.capabilities.supportsZoom) return;

    final target = session.capabilities.clampZoom(zoom);
    if (target == session.zoom) return;

    _emit(session.copyWith(zoom: target));
    _pendingZoom = target;
    if (_zoomInFlight) return;

    _zoomInFlight = true;
    try {
      while (_pendingZoom != null) {
        final next = _pendingZoom!;
        _pendingZoom = null;
        final controller = _session?.controller;
        if (controller == null) break;
        await _service.setZoomLevel(controller, next);
      }
    } catch (error, stackTrace) {
      _errors.report(error, stackTrace, operation: 'set zoom');
    } finally {
      _pendingZoom = null;
      _zoomInFlight = false;
    }
  }

  /// Focuses and meters on [point], given in normalized preview coordinates.
  ///
  /// Returns false when the active camera supports neither.
  Future<bool> focusAt(Offset point) async {
    final session = _session;
    if (session == null || !session.capabilities.supportsTapToFocus) {
      return false;
    }

    final controller = session.controller;
    final target = Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0));
    try {
      if (session.capabilities.supportsExposurePoint) {
        await _service.setExposurePoint(controller, target);
      }
      if (session.capabilities.supportsFocusPoint) {
        await _service.setFocusMode(controller, FocusMode.auto);
        await _service.setFocusPoint(controller, target);
      }
      return true;
    } catch (error, stackTrace) {
      // Some cameras advertise focus points but reject every metering region;
      // stop offering tap-to-focus rather than failing on each tap.
      _errors.logger.warning(
        'Tap-to-focus rejected by ${session.description.name}.',
        error,
        stackTrace,
      );
      _updateIfCurrent(
        controller,
        (current) => current.copyWith(
          capabilities: current.capabilities.copyWith(
            supportsFocusPoint: false,
            supportsExposurePoint: false,
          ),
        ),
      );
      return false;
    }
  }

  /// The camera is an exclusive resource: release it whenever the app is not
  /// in the foreground and reopen the same lens when it returns.
  Future<void> handleAppLifecycle(AppLifecycleState lifecycle) async {
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        await _resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        await _pause();
    }
  }

  Future<CameraSession?> _open(int index, {double? zoom}) async {
    await _release();
    if (!_isActive) return null;

    final generation = ++_generation;
    final description = _cameras[index];
    final controller = _service.createController(description);

    try {
      await _service.initialize(controller);
    } catch (error, stackTrace) {
      await _disposeQuietly(controller);
      if (!_isCurrent(generation)) return null;
      _errors.report(error, stackTrace, operation: 'initialize camera');
      throw _errors.map(error, stackTrace);
    }

    if (!_isCurrent(generation)) {
      await _disposeQuietly(controller);
      return null;
    }

    var capabilities = await _capabilities(controller, description);
    var flashMode = CameraFlashMode.off;
    if (capabilities.supportsFlash) {
      // A fresh controller starts in FlashMode.auto, so always apply a mode
      // explicitly to keep the UI and the hardware in agreement.
      flashMode = _preferredFlash.isTorch && !capabilities.supportsTorch
          ? CameraFlashMode.off
          : _preferredFlash;
      try {
        await _service.setFlashMode(controller, flashMode.platform);
      } catch (error, stackTrace) {
        _errors.logger.warning(
          'Flash unavailable for ${description.name}.',
          error,
          stackTrace,
        );
        capabilities = capabilities.copyWith(
          supportsFlash: false,
          supportsTorch: false,
        );
        flashMode = CameraFlashMode.off;
      }
    }

    var initialZoom = capabilities.initialZoom;
    if (zoom != null && capabilities.supportsZoom) {
      final restored = capabilities.clampZoom(zoom);
      try {
        await _service.setZoomLevel(controller, restored);
        initialZoom = restored;
      } catch (error, stackTrace) {
        _errors.logger.warning(
          'Zoom could not be restored.',
          error,
          stackTrace,
        );
      }
    }

    if (!_isCurrent(generation)) {
      await _disposeQuietly(controller);
      return null;
    }

    _controller = controller;
    _index = index;
    controller.addListener(_onControllerValue);

    return _session = CameraSession(
      controller: controller,
      description: description,
      cameras: _cameras,
      capabilities: capabilities,
      flashMode: flashMode,
      zoom: initialZoom,
    );
  }

  Future<CameraCapabilities> _capabilities(
    CameraController controller,
    CameraDescription description,
  ) async {
    final base = CameraCapabilities.fromLensDirection(description.lensDirection)
        .copyWith(
          supportsFocusPoint: controller.value.focusPointSupported,
          supportsExposurePoint: controller.value.exposurePointSupported,
        );

    try {
      final minZoom = await _service.minZoom(controller);
      final maxZoom = await _service.maxZoom(controller);
      return base.withZoomRange(minZoom, maxZoom);
    } catch (error, stackTrace) {
      _errors.logger.warning(
        'Zoom range unavailable for ${description.name}.',
        error,
        stackTrace,
      );
      return base;
    }
  }

  /// Surfaces errors the platform reports after initialization, e.g. another
  /// app taking the camera or the device disconnecting it.
  void _onControllerValue() {
    final controller = _controller;
    if (controller == null || !controller.value.hasError) return;

    final description = controller.value.errorDescription;
    // The controller only ever reports its first error, so stop listening.
    controller.removeListener(_onControllerValue);

    final android = defaultTargetPlatform == TargetPlatform.android;
    if (!isFatalRuntimeCameraError(description, android: android)) {
      _errors.logger.warning('Recoverable camera error: $description');
      // CameraX reports a missing flash here instead of failing the call.
      if (isMissingFlashError(description)) {
        _updateIfCurrent(
          controller,
          (current) => current.copyWith(
            flashMode: CameraFlashMode.off,
            capabilities: current.capabilities.copyWith(
              supportsFlash: false,
              supportsTorch: false,
            ),
          ),
        );
      }
      return;
    }

    // Defer: this runs inside the controller's own notification.
    scheduleMicrotask(() {
      if (!identical(_controller, controller)) return;
      _generation++;
      // Leave the session state before disposing, so no frame renders a
      // released controller.
      _fail(
        CameraFailure(
          'The camera stopped unexpectedly. It may be in use by another app.',
          cause: description,
        ),
        StackTrace.current,
      );
      unawaited(_release());
    });
  }

  Future<XFile> _storeCapture(XFile shot) async {
    final target = await _files.createCaptureFile();
    final source = File(shot.path);
    final saved = await source.copy(target.path);
    try {
      await source.delete();
    } on FileSystemException catch (error, stackTrace) {
      _errors.logger.warning(
        'Temporary capture was not cleaned up.',
        error,
        stackTrace,
      );
    }
    return XFile(saved.path, mimeType: 'image/jpeg');
  }

  Future<void> _pause() async {
    if (_paused || !_isActive) return;
    _paused = true;
    _generation++;

    // Leave the session state before disposing, so no frame renders a
    // released controller.
    if (_session != null) state = const AsyncLoading<CameraSession>();
    await _release();
  }

  Future<void> _resume() async {
    if (!_paused || !_isActive) return;
    _paused = false;

    final waiter = _resumed;
    _resumed = null;
    if (waiter != null) {
      waiter.complete();
      return;
    }
    // An in-flight build notices the resume itself and retries.
    if (_building || _session != null || _cameras.isEmpty) return;

    final zoom = state.value?.zoom;
    state = const AsyncLoading<CameraSession>();
    try {
      final session = await _open(_index, zoom: zoom);
      if (session != null) _emit(session);
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  void _deactivate() {
    _active = false;
    _generation++;
    _pendingZoom = null;
    final waiter = _resumed;
    _resumed = null;
    waiter?.complete();
    unawaited(_release());
  }

  /// Detaches the current controller synchronously and disposes it in the
  /// background. Callers that open a new controller await the returned future
  /// so two controllers never hold the camera at the same time.
  Future<void> _release() {
    final controller = _controller;
    _controller = null;
    _session = null;
    if (controller != null) {
      controller.removeListener(_onControllerValue);
      final previous = _releasing;
      _releasing = previous.then((_) => _disposeQuietly(controller));
    }
    return _releasing;
  }

  Future<void> _disposeQuietly(CameraController controller) async {
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

  bool _isCurrent(int generation) => generation == _generation && _isActive;

  int _indexToKeep(List<CameraDescription> cameras) {
    if (_cameras.isNotEmpty && _index < _cameras.length) {
      final previous = _cameras[_index].name;
      final kept = cameras.indexWhere((camera) => camera.name == previous);
      if (kept != -1) return kept;
    }
    return indexOfDefaultCamera(cameras);
  }

  void _updateIfCurrent(
    CameraController controller,
    CameraSession Function(CameraSession current) update,
  ) {
    final current = _session;
    if (current == null || !identical(current.controller, controller)) return;
    _emit(update(current));
  }

  void _emit(CameraSession session) {
    if (!_isActive || !identical(session.controller, _controller)) return;
    _session = session;
    state = AsyncData<CameraSession>(session);
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (!_isActive) return;
    state = AsyncError<CameraSession>(
      _errors.map(error, stackTrace),
      stackTrace,
    );
  }
}

final cameraSessionProvider =
    AsyncNotifierProvider.autoDispose<CameraSessionController, CameraSession>(
      CameraSessionController.new,
      retry: _noRetry,
    );
