import 'package:camera/camera.dart';

import '../../../core/errors/app_exception.dart';

/// Platform codes the camera plugins use when the OS refuses camera access.
const Set<String> cameraAccessDeniedCodes = <String>{
  'CameraAccessDenied',
  'CameraAccessDeniedWithoutPrompt',
  'CameraAccessRestricted',
  'cameraPermission',
};

/// True when [error] means the user (or device policy) blocked the camera, so
/// the fix is in system settings rather than a retry.
bool isCameraAccessDenied(Object error) {
  final cause = error is AppException ? error.cause : error;
  return cause is CameraException &&
      cameraAccessDeniedCodes.contains(cause.code);
}

/// Phrases CameraX (Android) uses for camera states it cannot recover from.
const List<String> _cameraXFatalMarkers = <String>[
  'fatal error',
  'device policy',
  'Do Not Disturb',
];

/// Whether a runtime error reported by the camera plugin ends the session.
///
/// CameraX reuses its error channel for recoverable states (camera briefly in
/// use while another closes, transient errors it retries itself) and for failed
/// control calls such as zoom, so only its known-fatal states count there. On
/// iOS, AVFoundation reports only session-level failures on that channel.
bool isFatalRuntimeCameraError(String? description, {required bool android}) {
  if (!android) return true;
  if (description == null) return false;
  return _cameraXFatalMarkers.any(description.contains);
}

/// CameraX's runtime error when flash or torch is used on a lens without one.
bool isMissingFlashError(String? description) =>
    description != null && description.contains('No flash unit');
