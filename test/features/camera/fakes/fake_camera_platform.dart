import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_overlay/core/files/file_service.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

const CameraDescription rearCamera = CameraDescription(
  name: 'rear',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

const CameraDescription frontCamera = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);

/// In-memory stand-in for the native camera plugins, driven through the real
/// `CameraController` so lifecycle bugs surface in unit tests.
class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({
    List<CameraDescription>? cameras,
    required this.captureDirectory,
  }) : cameras = cameras ?? <CameraDescription>[frontCamera, rearCamera];

  List<CameraDescription> cameras;
  final Directory captureDirectory;

  double minZoom = 1.0;
  double maxZoom = 8.0;
  bool focusPointSupported = true;
  bool exposurePointSupported = true;

  /// Thrown once by the next `initializeCamera` call, then cleared.
  Object? nextInitializeError;

  /// When set, `takePicture` waits for it, so tests can overlap captures.
  Completer<void>? captureGate;

  final Set<String> flashFailsFor = <String>{};

  /// Thrown by `setFocusPoint` when set, like a camera rejecting metering.
  Object? focusError;

  /// Called before a camera is disposed, to observe app state at that moment.
  void Function(int cameraId)? onDispose;

  int _nextId = 0;
  final Map<int, CameraDescription> created = <int, CameraDescription>{};
  final Set<int> disposed = <int>{};
  final List<int> initialized = <int>[];
  final List<(int, FlashMode)> flashCalls = <(int, FlashMode)>[];
  final List<(int, double)> zoomCalls = <(int, double)>[];
  final List<(int, Point<double>?)> focusPoints = <(int, Point<double>?)>[];
  final List<(int, Point<double>?)> exposurePoints = <(int, Point<double>?)>[];
  int captureCount = 0;

  /// What every capture writes: a real 9:16 portrait JPEG, matching the
  /// 1920x1080 preview stream, so composites can be rendered from it.
  final List<int> pictureBytes = img.encodeJpg(
    img.fill(
      img.Image(width: 54, height: 96),
      color: img.ColorRgb8(40, 90, 140),
    ),
    quality: 90,
  );

  final Map<int, StreamController<CameraInitializedEvent>> _initEvents =
      <int, StreamController<CameraInitializedEvent>>{};
  final Map<int, StreamController<CameraErrorEvent>> _errorEvents =
      <int, StreamController<CameraErrorEvent>>{};

  Iterable<int> get liveCameras =>
      initialized.where((id) => !disposed.contains(id));

  void emitError(int cameraId, String description) {
    _errorEvents[cameraId]?.add(CameraErrorEvent(cameraId, description));
  }

  /// Thrown by `availableCameras` when set, like CameraX without a camera.
  Object? listError;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    if (listError case final error?) throw error;
    return cameras;
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    final id = _nextId++;
    created[id] = cameraDescription;
    return id;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    final error = nextInitializeError;
    if (error != null) {
      nextInitializeError = null;
      throw error;
    }
    initialized.add(cameraId);
    scheduleMicrotask(
      () => _initEventsFor(cameraId).add(
        CameraInitializedEvent(
          cameraId,
          1920,
          1080,
          ExposureMode.auto,
          exposurePointSupported,
          FocusMode.auto,
          focusPointSupported,
        ),
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initEventsFor(cameraId).stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      (_errorEvents[cameraId] ??=
              StreamController<CameraErrorEvent>.broadcast())
          .stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream<DeviceOrientationChangedEvent>.empty();

  @override
  Future<XFile> takePicture(int cameraId) async {
    captureCount++;
    await captureGate?.future;
    final file = File(
      '${captureDirectory.path}${Platform.pathSeparator}raw_$captureCount.jpg',
    );
    await file.writeAsBytes(pictureBytes);
    return XFile(file.path);
  }

  @override
  Future<double> getMinZoomLevel(int cameraId) async => minZoom;

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => maxZoom;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {
    zoomCalls.add((cameraId, zoom));
  }

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    if (flashFailsFor.contains(created[cameraId]?.name)) {
      throw CameraException('flashUnsupported', 'No flash unit.');
    }
    flashCalls.add((cameraId, mode));
  }

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {}

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {
    if (focusError case final error?) throw error;
    focusPoints.add((cameraId, point));
  }

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {
    exposurePoints.add((cameraId, point));
  }

  @override
  Widget buildPreview(int cameraId) =>
      ColoredBox(key: ValueKey<int>(cameraId), color: const Color(0xFF203040));

  @override
  Future<void> dispose(int cameraId) async {
    onDispose?.call(cameraId);
    disposed.add(cameraId);
  }

  StreamController<CameraInitializedEvent> _initEventsFor(int cameraId) =>
      _initEvents[cameraId] ??=
          StreamController<CameraInitializedEvent>.broadcast();
}

/// Keeps captures inside a temp directory instead of the real documents dir.
final class TempFileService extends FileService {
  const TempFileService(this.directory);

  final Directory directory;

  @override
  Future<Directory> capturesDirectory() async => directory;
}
