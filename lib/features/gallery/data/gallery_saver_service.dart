import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/errors/app_exception.dart';

/// Saves files to the system photo library (MediaStore on Android, Photos on
/// iOS) without re-encoding them.
class GallerySaverService {
  GallerySaverService({required this.errorHandler});

  final AppErrorHandler errorHandler;

  /// Android files photos under Pictures/Veylora. iOS saves to the library
  /// without an album: albums need full read-write access there, while plain
  /// saving only needs add-only permission.
  static String? get album => defaultTargetPlatform == TargetPlatform.android
      ? AppConstants.appName
      : null;

  /// Where saved photos appear, for user-facing messages.
  static String get libraryName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'Photos' : 'Gallery';

  Future<bool> hasAccess() =>
      errorHandler.guard(Gal.hasAccess, operation: 'check gallery access');

  Future<bool> requestAccess() => errorHandler.guard(
    Gal.requestAccess,
    operation: 'request gallery access',
  );

  Future<void> saveImage(String path) => errorHandler.guard(
    () => Gal.putImage(path, album: album),
    operation: 'save image to gallery',
  );

  /// Saves a clip to the library. The platform muxer already wrote a finished
  /// file, so it is handed over as-is.
  Future<void> saveVideo(String path) => errorHandler.guard(
    () => Gal.putVideo(path, album: album),
    operation: 'save video to gallery',
  );

  Future<void> openGallery() =>
      errorHandler.guard(Gal.open, operation: 'open gallery');
}

final gallerySaverServiceProvider = Provider<GallerySaverService>(
  (ref) =>
      GallerySaverService(errorHandler: ref.watch(appErrorHandlerProvider)),
);

/// True when a save failed because the photo library permission is missing,
/// so the fix is in system settings.
bool isGalleryAccessDenied(Object error) {
  final cause = error is AppException ? error.cause : error;
  return cause is GalException && cause.type == GalExceptionType.accessDenied;
}
