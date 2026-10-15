import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../domain/camera_flash_mode.dart';
import '../../domain/camera_session.dart';

class CameraCloseButton extends StatelessWidget {
  const CameraCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: Icons.close,
      tooltip: 'Close camera',
      color: context.cameraTheme.onScrim,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
      },
    );
  }
}

class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.session,
    required this.onCycleFlash,
  });

  final CameraSession session;
  final VoidCallback onCycleFlash;

  @override
  Widget build(BuildContext context) {
    final cameraTheme = context.cameraTheme;
    final flash = session.flashMode;
    final canFlash = session.capabilities.supportsFlash && !session.isCapturing;

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
              const CameraCloseButton(),
              const Spacer(),
              if (session.capabilities.supportsFlash)
                AppIconButton(
                  key: const ValueKey<String>('camera-flash'),
                  icon: _flashIcon(flash),
                  tooltip: 'Flash: ${_flashLabel(flash)}. Tap to change.',
                  color: flash == CameraFlashMode.off
                      ? cameraTheme.onScrim
                      : Colors.amberAccent,
                  onPressed: canFlash ? onCycleFlash : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _flashIcon(CameraFlashMode mode) => switch (mode) {
    CameraFlashMode.off => Icons.flash_off,
    CameraFlashMode.auto => Icons.flash_auto,
    CameraFlashMode.on => Icons.flash_on,
    CameraFlashMode.torch => Icons.flashlight_on,
  };

  static String _flashLabel(CameraFlashMode mode) => switch (mode) {
    CameraFlashMode.off => 'off',
    CameraFlashMode.auto => 'auto',
    CameraFlashMode.on => 'on',
    CameraFlashMode.torch => 'torch',
  };
}

class CameraBottomBar extends StatelessWidget {
  const CameraBottomBar({
    super.key,
    required this.session,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onZoomChanged,
  });

  final CameraSession session;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    final cameraTheme = context.cameraTheme;
    final busy = session.isCapturing;

    return Container(
      color: cameraTheme.scrim,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (session.capabilities.supportsZoom)
                _ZoomControl(session: session, onChanged: onZoomChanged),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Reserved for the reference-image picker (overlay module).
                  const SizedBox.square(dimension: AppConstants.minTapTarget),
                  ShutterButton(busy: busy, onPressed: busy ? null : onCapture),
                  AppIconButton(
                    key: const ValueKey<String>('camera-switch'),
                    icon: Icons.cameraswitch_outlined,
                    tooltip: session.isFrontFacing
                        ? 'Switch to rear camera'
                        : 'Switch to front camera',
                    color: cameraTheme.onScrim,
                    onPressed: session.canSwitchCamera && !busy
                        ? onSwitchCamera
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

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({required this.session, required this.onChanged});

  final CameraSession session;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cameraTheme = context.cameraTheme;
    final capabilities = session.capabilities;

    return Row(
      children: <Widget>[
        SizedBox(
          width: 52,
          child: Text(
            '${session.zoom.toStringAsFixed(1)}x',
            textAlign: TextAlign.center,
            style: context.textStyles.labelLarge?.copyWith(
              color: cameraTheme.onScrim,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: cameraTheme.onScrim,
              inactiveTrackColor: cameraTheme.trackInactive,
              thumbColor: cameraTheme.onScrim,
              overlayColor: cameraTheme.onScrim.withValues(alpha: 0.12),
            ),
            child: Slider(
              key: const ValueKey<String>('camera-zoom'),
              value: session.zoom,
              min: capabilities.minZoom,
              max: capabilities.maxZoom,
              onChanged: onChanged,
              semanticFormatterCallback: (value) =>
                  'Zoom ${value.toStringAsFixed(1)} times',
            ),
          ),
        ),
      ],
    );
  }
}

class ShutterButton extends StatelessWidget {
  const ShutterButton({super.key, required this.busy, this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cameraTheme = context.cameraTheme;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? 'Capturing photo' : 'Capture photo',
      child: GestureDetector(
        key: const ValueKey<String>('camera-shutter'),
        onTap: onPressed,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cameraTheme.shutterRing, width: 4),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: AppConstants.fastAnimation,
              width: busy ? 44 : 58,
              height: busy ? 44 : 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cameraTheme.shutterInner.withValues(
                  alpha: enabled ? 1 : 0.5,
                ),
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black54,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
