import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/haptics/haptics.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/glass.dart';
import '../../domain/overlay_fit_mode.dart';
import '../../domain/overlay_settings.dart';
import '../providers/overlay_image_provider.dart';
import '../providers/overlay_settings_provider.dart';
import '../providers/overlay_tray_provider.dart';

/// Gallery tile for the camera bar: adds a reference image, or shows the
/// current one and replaces it on tap.
class OverlayPickerButton extends ConsumerWidget {
  const OverlayPickerButton({super.key});

  static const double _size = 52;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(15));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overlayImageProvider);
    final image = state.value;
    final theme = context.cameraTheme;

    if (state.isLoading) {
      return SizedBox.square(
        dimension: _size,
        child: GlassSurface(
          borderRadius: _radius,
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                strokeCap: StrokeCap.round,
                color: theme.onScrim,
              ),
            ),
          ),
        ),
      );
    }

    final tooltip = image == null
        ? 'Choose reference image'
        : 'Replace reference image';
    final face = image == null
        ? GlassSurface(
            borderRadius: _radius,
            child: Center(
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 24,
                color: theme.onScrim,
              ),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _radius,
              border: Border.all(color: theme.onScrim, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(13)),
              child: RawImage(image: image.image, fit: BoxFit.cover),
            ),
          );

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          key: const ValueKey<String>('overlay-pick'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.selectionClick();
            pickReferenceImage(context, ref);
          },
          child: SizedBox.square(dimension: _size, child: face),
        ),
      ),
    );
  }
}

Future<void> pickReferenceImage(BuildContext context, WidgetRef ref) async {
  // Resolve these before awaiting: the gallery backgrounds the app, the camera
  // pauses and its controls (this button included) are unmounted, so this
  // context is gone by the time the pick fails.
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(overlayImageProvider.notifier);
  try {
    await notifier.pickFromGallery();
  } on AppException catch (failure) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

/// Overlay settings, shown as a glass tray that can be minimized to a small
/// chip when the user wants an unobstructed preview.
class OverlayControlPanel extends ConsumerWidget {
  const OverlayControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = ref.watch(
      overlayImageProvider.select((state) => state.value != null),
    );
    if (!hasImage) return const SizedBox.shrink();

    final minimized = ref.watch(
      overlayTrayProvider.select((state) => state.minimized),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AnimatedSwitcher(
        duration: AppConstants.standardAnimation,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[...previous, ?current],
        ),
        child: minimized
            ? const _MinimizedChip(key: ValueKey<String>('tray-chip'))
            : const _Tray(key: ValueKey<String>('tray-full')),
      ),
    );
  }
}

/// The full tray: a tab switcher for opacity or framing, with visibility,
/// lock and remove always at hand. Tap the handle or swipe down to minimize.
class _Tray extends ConsumerWidget {
  const _Tray({super.key});

  /// Below this height (typically landscape phones) the tray starts folded
  /// to its header so the preview stays usable.
  static const double _compactHeight = 560;
  static const double _maxWidth = 520;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(overlaySettingsProvider);
    final controller = ref.read(overlaySettingsProvider.notifier);
    final tray = ref.watch(overlayTrayProvider);
    final trayController = ref.read(overlayTrayProvider.notifier);
    final expanded =
        tray.expanded ?? MediaQuery.sizeOf(context).height >= _compactHeight;
    final tab = tray.tab;

    final body = !expanded
        ? const SizedBox(width: double.infinity)
        : switch (tab) {
            OverlayTrayTab.opacity => _OpacityControls(
              settings: settings,
              controller: controller,
            ),
            OverlayTrayTab.frame => _FrameControls(
              settings: settings,
              controller: controller,
            ),
          };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: GestureDetector(
          // A downward flick anywhere on the tray minimizes it.
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 150) {
              trayController.minimize();
            }
          },
          child: GlassSurface(
            borderRadius: BorderRadius.circular(26),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _GrabHandle(onTap: trayController.minimize),
                Row(
                  children: <Widget>[
                    // Scales down rather than overflowing on narrow screens
                    // or with large system text.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: GlassSegmentedControl<OverlayTrayTab>(
                          selected: expanded ? tab : null,
                          onSelected: (selected) => trayController.selectTab(
                            selected,
                            currentlyExpanded: expanded,
                          ),
                          segments: <GlassSegment<OverlayTrayTab>>[
                            GlassSegment<OverlayTrayTab>(
                              key: const ValueKey<String>(
                                'overlay-tab-opacity',
                              ),
                              value: OverlayTrayTab.opacity,
                              label: expanded && tab == OverlayTrayTab.opacity
                                  ? 'Opacity'
                                  : 'Opacity ${settings.opacityPercent}%',
                            ),
                            const GlassSegment<OverlayTrayTab>(
                              key: ValueKey<String>('overlay-tab-frame'),
                              value: OverlayTrayTab.frame,
                              label: 'Frame',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GlassIconButton(
                      key: const ValueKey<String>('overlay-visibility'),
                      glass: false,
                      diameter: 40,
                      icon: settings.isVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      tooltip: settings.isVisible
                          ? 'Hide reference image'
                          : 'Show reference image',
                      active: !settings.isVisible,
                      onPressed: controller.toggleVisible,
                    ),
                    GlassIconButton(
                      key: const ValueKey<String>('overlay-lock'),
                      glass: false,
                      diameter: 40,
                      icon: settings.isLocked
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      tooltip: settings.isLocked
                          ? 'Unlock overlay to move it'
                          : 'Lock overlay position',
                      active: settings.isLocked,
                      onPressed: controller.toggleLocked,
                    ),
                    GlassIconButton(
                      key: const ValueKey<String>('overlay-remove'),
                      glass: false,
                      diameter: 40,
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Remove reference image',
                      onPressed: () =>
                          ref.read(overlayImageProvider.notifier).remove(),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: AppConstants.standardAnimation,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: AppConstants.fastAnimation,
                    child: KeyedSubtree(
                      key: ValueKey<Object>(expanded ? tab : 'collapsed'),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet style handle across the top of the tray; tapping it
/// minimizes the tray. The whole width is the hit area.
class _GrabHandle extends StatelessWidget {
  const _GrabHandle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Minimize overlay controls',
      child: Semantics(
        button: true,
        label: 'Minimize overlay controls',
        child: GestureDetector(
          key: const ValueKey<String>('overlay-minimize'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: double.infinity,
            height: 24,
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cameraTheme.onScrim.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The minimized tray: a small glass chip with the opacity and any active
/// lock/hidden state. Tap it or swipe up to bring the tray back.
class _MinimizedChip extends ConsumerWidget {
  const _MinimizedChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(overlaySettingsProvider);
    final restore = ref.read(overlayTrayProvider.notifier).restore;
    final theme = context.cameraTheme;
    final states = <String>[
      if (settings.isLocked) 'locked',
      if (!settings.isVisible) 'hidden',
    ];
    final stateLabel = states.isEmpty ? '' : ', ${states.join(', ')}';

    return Tooltip(
      message: 'Show overlay controls',
      child: Semantics(
        button: true,
        label:
            'Show overlay controls. Opacity ${settings.opacityPercent} '
            'percent$stateLabel',
        child: GestureDetector(
          key: const ValueKey<String>('overlay-restore'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.selectionClick();
            restore();
          },
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -150) restore();
          },
          child: SizedBox(
            height: AppConstants.minTapTarget,
            child: Center(
              child: GlassSurface(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.tune_rounded, size: 17, color: theme.onScrim),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${settings.opacityPercent}%',
                        style: context.textStyles.labelLarge?.copyWith(
                          color: theme.onScrim,
                          fontWeight: FontWeight.w600,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                      if (settings.isLocked) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(Icons.lock_rounded, size: 15, color: theme.accent),
                      ],
                      if (!settings.isVisible) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 15,
                          color: theme.accent,
                        ),
                      ],
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: theme.onScrim.withValues(alpha: 0.8),
                      ),
                    ],
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

class _OpacityControls extends StatelessWidget {
  const _OpacityControls({required this.settings, required this.controller});

  final OverlaySettings settings;
  final OverlaySettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final enabled = settings.isVisible;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: theme.onScrim,
                  inactiveTrackColor: theme.onScrim.withValues(alpha: 0.2),
                  thumbColor: theme.onScrim,
                  overlayColor: theme.onScrim.withValues(alpha: 0.1),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 9,
                    elevation: 3,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  key: const ValueKey<String>('overlay-opacity'),
                  value: settings.opacity,
                  onChanged: enabled ? controller.setOpacity : null,
                  semanticFormatterCallback: (value) =>
                      'Overlay opacity ${(value * 100).round()} percent',
                ),
              ),
            ),
            SizedBox(
              width: 58,
              child: Text(
                '${settings.opacityPercent}%',
                key: const ValueKey<String>('overlay-opacity-label'),
                textAlign: TextAlign.end,
                style: context.textStyles.titleMedium?.copyWith(
                  color: theme.onScrim,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        Row(
          children: <Widget>[
            for (final preset in OverlaySettingsController.opacityPresets)
              Expanded(
                child: _PresetChip(
                  key: ValueKey<String>(
                    'overlay-preset-${(preset * 100).round()}',
                  ),
                  label: '${(preset * 100).round()}%',
                  selected: settings.opacityPercent == (preset * 100).round(),
                  onPressed: enabled
                      ? () => controller.setOpacity(preset)
                      : null,
                ),
              ),
            GlassIconButton(
              key: const ValueKey<String>('overlay-opacity-reset'),
              glass: false,
              diameter: 40,
              iconSize: 19,
              icon: Icons.restart_alt_rounded,
              tooltip: 'Reset opacity',
              onPressed: enabled ? controller.resetOpacity : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _FrameControls extends StatelessWidget {
  const _FrameControls({required this.settings, required this.controller});

  final OverlaySettings settings;
  final OverlaySettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final canReset = settings.hasCustomTransform;
    final resetColor = theme.onScrim.withValues(alpha: canReset ? 1 : 0.35);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, right: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GlassSegmentedControl<OverlayFitMode>(
              expand: true,
              // A manual drag/pinch means no preset framing is current.
              selected: canReset ? null : settings.fitMode,
              onSelected: controller.setFitMode,
              segments: <GlassSegment<OverlayFitMode>>[
                for (final mode in OverlayFitMode.values)
                  GlassSegment<OverlayFitMode>(
                    key: ValueKey<String>('overlay-fit-${mode.name}'),
                    value: mode,
                    label: mode.label,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Tooltip(
            message: 'Reset position',
            child: Semantics(
              button: true,
              enabled: canReset,
              child: GestureDetector(
                key: const ValueKey<String>('overlay-reset-position'),
                behavior: HitTestBehavior.opaque,
                onTap: canReset
                    ? () {
                        Haptics.selectionClick();
                        controller.resetPosition();
                      }
                    : null,
                child: SizedBox(
                  height: AppConstants.minTapTarget,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.center_focus_strong_outlined,
                          size: 18,
                          color: resetColor,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Reset',
                          style: context.textStyles.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: resetColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal text preset: the current value is bright with an accent dot.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    super.key,
    required this.label,
    required this.selected,
    this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final enabled = onPressed != null;
    final color = !enabled
        ? theme.onScrim.withValues(alpha: 0.3)
        : selected
        ? theme.onScrim
        : theme.onScrim.withValues(alpha: 0.6);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed == null
            ? null
            : () {
                Haptics.selectionClick();
                onPressed!();
              },
        child: SizedBox(
          height: AppConstants.minTapTarget,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: context.textStyles.labelLarge?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: tabularFigures,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: AppConstants.fastAnimation,
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? theme.accent : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
