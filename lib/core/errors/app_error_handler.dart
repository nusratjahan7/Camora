import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../logging/app_logger.dart';
import 'app_exception.dart';

final class AppErrorHandler {
  const AppErrorHandler({required this.logger});

  final AppLogger logger;

  AppException map(Object error, StackTrace stackTrace) {
    if (error is AppException) return error;

    if (error is CameraException) {
      return CameraFailure(
        _cameraMessage(error),
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is GalException) {
      return GallerySaveFailure(
        _galleryMessage(error),
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FileSystemException) {
      return FileFailure(
        'A file could not be read or written on this device.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is MissingPluginException) {
      return UnexpectedFailure(
        'This feature is not available on the current platform.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is PlatformException) {
      return UnexpectedFailure(
        error.message ?? 'The system rejected the request.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return UnexpectedFailure(
      'Something went wrong. Please try again.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  void report(Object error, StackTrace stackTrace, {String? operation}) {
    final failure = map(error, stackTrace);
    final label = operation == null
        ? failure.message
        : '[$operation] ${failure.message}';
    logger.error(label, failure.cause ?? error, stackTrace);
  }

  Future<T> guard<T>(
    Future<T> Function() action, {
    required String operation,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      report(error, stackTrace, operation: operation);
      throw map(error, stackTrace);
    }
  }

  String _galleryMessage(GalException error) => switch (error.type) {
    GalExceptionType.accessDenied =>
      'Permission to save photos was denied. Allow it in system settings.',
    GalExceptionType.notEnoughSpace =>
      'There is not enough storage space to save the photo.',
    GalExceptionType.notSupportedFormat =>
      'This photo format cannot be saved to your gallery.',
    GalExceptionType.unexpected =>
      'The photo could not be saved to your gallery.',
  };

  String _cameraMessage(CameraException error) => switch (error.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' =>
      'Camera access was denied. Enable it in system settings to use the live preview.',
    'cameraPermission' => 'The camera needs permission before it can start.',
    'AudioAccessDenied' => 'Microphone access was denied.',
    _ => 'The camera could not be started on this device.',
  };
}

final appErrorHandlerProvider = Provider<AppErrorHandler>(
  (ref) => AppErrorHandler(logger: ref.watch(appLoggerProvider)),
);
