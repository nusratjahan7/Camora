import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/permission_rationale_sheet.dart';
import '../providers/camera_providers.dart';
import '../widgets/camera_preview_view.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  late final AppLifecycleListener _lifecycle;
  bool _autoPrompted = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleChanged);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(cameraPermissionProvider);
    _maybeAutoPrompt(permission);

    // The camera UI is always dark, whatever the app theme.
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: switch (permission) {
          AsyncValue(isLoading: true) => const CameraStatusFrame(
            child: LoadingView(message: 'Checking camera permission…'),
          ),
          AsyncValue(:final error?, :final stackTrace) => CameraStatusFrame(
            child: ErrorView(
              exception: ref
                  .read(appErrorHandlerProvider)
                  .map(error, stackTrace ?? StackTrace.empty),
              onRetry: () => ref.invalidate(cameraPermissionProvider),
            ),
          ),
          AsyncValue(value: AppPermissionStatus(isGranted: true)) =>
            const CameraPreviewView(),
          AsyncValue(:final value) => CameraStatusFrame(
            child: _PermissionPrompt(
              status: value ?? AppPermissionStatus.denied,
              onRequest: _promptForPermission,
            ),
          ),
        },
      ),
    );
  }

  void _onLifecycleChanged(AppLifecycleState lifecycle) {
    final granted = ref.read(cameraPermissionProvider).value?.isGranted;

    if (granted == true) {
      // Only forward to a live session; reading it here would open the camera.
      if (ref.exists(cameraSessionProvider)) {
        ref.read(cameraSessionProvider.notifier).handleAppLifecycle(lifecycle);
      }
      return;
    }

    // The user may have changed the permission in system settings.
    if (lifecycle == AppLifecycleState.resumed && !_prompting) {
      ref.invalidate(cameraPermissionProvider);
    }
  }

  void _maybeAutoPrompt(AsyncValue<AppPermissionStatus> permission) {
    if (_autoPrompted) return;

    final status = permission.value;
    if (status == null ||
        status.isGranted ||
        status.isBlocked ||
        status == AppPermissionStatus.restricted) {
      return;
    }

    _autoPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptForPermission());
  }

  Future<void> _promptForPermission() async {
    if (_prompting) return;
    _prompting = true;

    final accepted = await PermissionRationaleSheet.show(
      context,
      permission: AppPermission.camera,
    );

    if (!mounted) {
      _prompting = false;
      return;
    }

    if (accepted) {
      await ref.read(cameraPermissionProvider.notifier).request();
    }

    _prompting = false;
  }
}

class _PermissionPrompt extends ConsumerWidget {
  const _PermissionPrompt({required this.status, required this.onRequest});

  final AppPermissionStatus status;
  final Future<void> Function() onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = status.isBlocked;
    final restricted = status == AppPermissionStatus.restricted;
    final scheme = context.colors;
    final text = context.textStyles;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              blocked ? Icons.lock_outline : Icons.no_photography_outlined,
              size: 40,
              color: scheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              restricted
                  ? 'Camera access is restricted'
                  : blocked
                  ? 'Camera access is blocked'
                  : 'Camera access needed',
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              restricted
                  ? 'Camera use is limited on this device, for example by '
                        'Screen Time or a device management policy.'
                  : blocked
                  ? 'Enable camera access for ${AppConstants.appName} in '
                        'system settings to see the live preview.'
                  : AppPermission.camera.rationaleBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (restricted)
              AppButton(
                label: 'Check again',
                icon: Icons.refresh,
                expand: false,
                onPressed: () => ref.invalidate(cameraPermissionProvider),
              )
            else if (blocked)
              AppButton(
                label: 'Open settings',
                icon: Icons.settings_outlined,
                expand: false,
                onPressed: () =>
                    ref.read(permissionServiceProvider).openSettings(),
              )
            else
              AppButton(
                label: 'Allow camera access',
                icon: Icons.photo_camera_outlined,
                expand: false,
                onPressed: onRequest,
              ),
          ],
        ),
      ),
    );
  }
}
