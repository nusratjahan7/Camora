import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../errors/app_exception.dart';
import 'app_permission.dart';

abstract interface class PermissionService {
  Future<AppPermissionStatus> status(AppPermission permission);

  Future<AppPermissionStatus> request(AppPermission permission);

  Future<bool> openSettings();
}

final class PermissionHandlerService implements PermissionService {
  const PermissionHandlerService();

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async {
    try {
      return mapPermissionStatus(await permission.platform.status);
    } catch (error, stackTrace) {
      throw PermissionFailure(
        'Could not check the ${permission.label} permission.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    try {
      final result = await permission.platform.request();
      if (result.isPermanentlyDenied) {
        return AppPermissionStatus.permanentlyDenied;
      }
      return mapPermissionStatus(result);
    } catch (error, stackTrace) {
      throw PermissionFailure(
        'Could not request the ${permission.label} permission.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionHandlerService(),
);
