import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../../core/errors/app_error_handler.dart';

class GallerySaverService {
  GallerySaverService({required this.errorHandler});

  final AppErrorHandler errorHandler;

  Future<bool> hasAccess() => Gal.hasAccess();

  Future<bool> requestAccess() => errorHandler.guard(
    Gal.requestAccess,
    operation: 'request gallery access',
  );

  Future<void> saveImage(String path, {String? album}) => errorHandler.guard(
    () => Gal.putImage(path, album: album),
    operation: 'save image to gallery',
  );

  Future<void> openGallery() =>
      errorHandler.guard(Gal.open, operation: 'open gallery');
}

final gallerySaverServiceProvider = Provider<GallerySaverService>(
  (ref) =>
      GallerySaverService(errorHandler: ref.watch(appErrorHandlerProvider)),
);
