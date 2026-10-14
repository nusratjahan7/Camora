import 'package:permission_handler/permission_handler.dart';

enum AppPermission { camera, photos, photosAddOnly }

enum AppPermissionStatus {
  granted,
  limited,
  denied,
  permanentlyDenied,
  restricted;

  bool get isGranted =>
      this == AppPermissionStatus.granted ||
      this == AppPermissionStatus.limited;

  bool get isBlocked => this == AppPermissionStatus.permanentlyDenied;
}

extension AppPermissionDetails on AppPermission {
  Permission get platform => switch (this) {
    AppPermission.camera => Permission.camera,
    AppPermission.photos => Permission.photos,
    AppPermission.photosAddOnly => Permission.photosAddOnly,
  };

  String get label => switch (this) {
    AppPermission.camera => 'camera',
    AppPermission.photos => 'photo library',
    AppPermission.photosAddOnly => 'photo library',
  };

  String get rationaleTitle => switch (this) {
    AppPermission.camera => 'Allow camera access',
    AppPermission.photos => 'Allow photo library access',
    AppPermission.photosAddOnly => 'Allow saving to your photos',
  };

  String get rationaleBody => switch (this) {
    AppPermission.camera =>
      'Camera Overlay draws your reference image on top of the live camera preview. '
          'The camera is only used while the shooting screen is open, and nothing is '
          'uploaded anywhere.',
    AppPermission.photos =>
      'Camera Overlay needs your photo library so you can choose a reference image to '
          'overlay and save your finished captures back to it. Photos stay on your device.',
    AppPermission.photosAddOnly =>
      'Camera Overlay saves your finished captures to your photo library. '
          'Existing photos are never read or modified.',
  };
}

AppPermissionStatus mapPermissionStatus(PermissionStatus status) =>
    switch (status) {
      PermissionStatus.granted => AppPermissionStatus.granted,
      PermissionStatus.limited => AppPermissionStatus.limited,
      PermissionStatus.provisional => AppPermissionStatus.granted,
      PermissionStatus.restricted => AppPermissionStatus.restricted,
      PermissionStatus.permanentlyDenied =>
        AppPermissionStatus.permanentlyDenied,
      PermissionStatus.denied => AppPermissionStatus.denied,
    };
