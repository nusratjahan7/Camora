import 'dart:async';
import 'dart:io';

import 'package:camera_overlay/core/errors/app_error_handler.dart';
import 'package:camera_overlay/core/logging/app_logger.dart';
import 'package:camera_overlay/features/gallery/data/gallery_saver_service.dart';

/// Records what would have gone to the photo library.
class FakeGallerySaver extends GallerySaverService {
  FakeGallerySaver({this.access = true, this.grantOnRequest = true})
    : super(errorHandler: const AppErrorHandler(logger: AppLogger()));

  bool access;
  bool grantOnRequest;
  int accessRequests = 0;

  /// Thrown by the next save, then cleared.
  Object? nextError;

  /// When set, saves wait for it (to overlap saves).
  Completer<void>? gate;

  /// Bytes of every saved file, captured at save time.
  final List<List<int>> saved = <List<int>>[];
  final List<String> savedPaths = <String>[];

  /// Paths saved through [saveVideo].
  final List<String> savedVideos = <String>[];

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<bool> requestAccess() async {
    accessRequests++;
    return access = grantOnRequest;
  }

  @override
  Future<void> saveImage(String path) async {
    await gate?.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw errorHandler.map(error, StackTrace.current);
    }
    savedPaths.add(path);
    saved.add(await File(path).readAsBytes());
  }

  @override
  Future<void> saveVideo(String path) async {
    await gate?.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw errorHandler.map(error, StackTrace.current);
    }
    savedPaths.add(path);
    savedVideos.add(path);
    saved.add(await File(path).readAsBytes());
  }

  @override
  Future<void> openGallery() async {}
}
