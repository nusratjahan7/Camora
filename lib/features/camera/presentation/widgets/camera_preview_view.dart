import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../providers/camera_providers.dart';

class CameraPreviewView extends ConsumerWidget {
  const CameraPreviewView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerAsync = ref.watch(cameraControllerProvider);

    return controllerAsync.when(
      loading: () => const LoadingView(message: 'Starting the camera…'),
      error: (error, stackTrace) => Center(
        child: ErrorView(
          exception: ref.read(appErrorHandlerProvider).map(error, stackTrace),
          onRetry: () => ref.invalidate(cameraControllerProvider),
        ),
      ),
      data: (controller) => _Preview(controller: controller),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _TopBar()),
          const Positioned(bottom: 0, left: 0, right: 0, child: _BottomBar()),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final cameraTheme = context.cameraTheme;

    return Container(
      color: cameraTheme.scrim,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              AppIconButton(
                icon: Icons.close,
                tooltip: 'Close camera',
                color: cameraTheme.onScrim,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.home);
                  }
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Live preview',
                style: context.textStyles.titleMedium?.copyWith(
                  color: cameraTheme.onScrim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraTheme = context.cameraTheme;
    final cameras =
        ref.watch(camerasProvider).value ?? const <CameraDescription>[];
    final canSwitch = cameras.length > 1;

    return Container(
      color: cameraTheme.scrim,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'The preview is live. Choosing a reference image, tuning the '
                'overlay and capturing arrive in the next module.',
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: cameraTheme.onScrim.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.photo_library_outlined,
                    tooltip: 'Choose reference image (next module)',
                    color: cameraTheme.onScrim,
                  ),
                  const _ShutterButton(),
                  AppIconButton(
                    icon: Icons.cameraswitch_outlined,
                    tooltip: 'Switch camera',
                    color: cameraTheme.onScrim,
                    onPressed: canSwitch
                        ? () => ref
                              .read(cameraControllerProvider.notifier)
                              .switchCamera()
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton();

  @override
  Widget build(BuildContext context) {
    final cameraTheme = context.cameraTheme;
    final ring = cameraTheme.shutterRing.withValues(alpha: 0.4);
    final inner = cameraTheme.shutterInner.withValues(alpha: 0.35);

    return Semantics(
      button: true,
      enabled: false,
      label: 'Capture photo, available in the next module',
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 4),
        ),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, color: inner),
          ),
        ),
      ),
    );
  }
}
