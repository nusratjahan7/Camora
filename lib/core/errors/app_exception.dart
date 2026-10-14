sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  /// Human readable, safe to show to the user.
  final String message;

  /// The original error, kept for diagnostics only.
  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() {
    final origin = cause == null ? '' : ' (cause: $cause)';
    return '$runtimeType: $message$origin';
  }
}

final class PermissionFailure extends AppException {
  const PermissionFailure(super.message, {super.cause, super.stackTrace});
}

final class CameraFailure extends AppException {
  const CameraFailure(super.message, {super.cause, super.stackTrace});
}

final class ImageSelectionFailure extends AppException {
  const ImageSelectionFailure(super.message, {super.cause, super.stackTrace});
}

final class GallerySaveFailure extends AppException {
  const GallerySaveFailure(super.message, {super.cause, super.stackTrace});
}

final class StorageFailure extends AppException {
  const StorageFailure(super.message, {super.cause, super.stackTrace});
}

final class FileFailure extends AppException {
  const FileFailure(super.message, {super.cause, super.stackTrace});
}

final class RouteFailure extends AppException {
  const RouteFailure(super.message, {super.cause, super.stackTrace});
}

final class UnexpectedFailure extends AppException {
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}
