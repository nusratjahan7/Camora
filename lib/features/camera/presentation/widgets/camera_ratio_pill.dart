import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/haptics/haptics.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../settings/domain/capture_ratio.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../providers/camera_providers.dart';

/// Quick control for the capture ratio.
///
/// Cycles 4:3 → 16:9 → 1:1 → Full the same way the flash button cycles modes,
/// and stores the choice so it survives the next launch. Changing it is pure
/// layout: the camera session is never restarted.
class CaptureRatioButton extends ConsumerWidget {
  const CaptureRatioButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.value?.captureRatio ?? CaptureRatio.classic43,
      ),
    );
    // A clip is muxed by the platform at the camera's own ratio, so there is
    // nothing for the selector to change while filming. Say so rather than
    // offering a control that would not apply.
    final filming = ref.watch(
      cameraSessionProvider.select(
        (session) => session.value?.captureMode.isVideo ?? false,
      ),
    );
    final theme = context.cameraTheme;

    return Tooltip(
      message: filming
          ? 'Clips record at the camera\'s native ratio'
          : 'Aspect ratio: ${ratio.spokenLabel}. Tap to change.',
      child: Semantics(
        button: !filming,
        enabled: !filming,
        label: 'Aspect ratio',
        value: filming ? '${ratio.spokenLabel}, not applied to video' : ratio.spokenLabel,
        hint: filming ? 'Not available while filming' : 'Tap to change',
        child: GestureDetector(
          key: const ValueKey<String>('camera-ratio'),
          behavior: HitTestBehavior.opaque,
          onTap: filming
              ? null
              : () {
                  Haptics.selectionClick();
                  ref
                      .read(settingsControllerProvider.notifier)
                      .setCaptureRatio(ratio.next);
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppConstants.minTapTarget,
              minHeight: AppConstants.minTapTarget,
            ),
            child: Center(
              child: GlassSurface(
                borderRadius: AppRadius.pillAll,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 30,
                  child: Center(
                    child: Text(
                      ratio.label,
                      style: context.textStyles.labelMedium?.copyWith(
                        color: theme.onScrim.withValues(
                          alpha: filming ? 0.4 : 1,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
