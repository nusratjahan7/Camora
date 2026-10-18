import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_slider.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/capture_ratio.dart';
import '../../domain/preferred_camera.dart';
import '../providers/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return AppScaffold(
      title: 'Settings',
      padded: false,
      body: settingsAsync.when(
        loading: () => const LoadingView(message: 'Loading your preferences…'),
        error: (error, stackTrace) => ErrorView(
          exception: ref.read(appErrorHandlerProvider).map(error, stackTrace),
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const _SectionTitle('Appearance'),
            SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text('System'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('Light'),
                ),
              ],
              selected: <ThemeMode>{settings.themeMode},
              onSelectionChanged: (selection) => ref
                  .read(settingsControllerProvider.notifier)
                  .setThemeMode(selection.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle('Camera'),
            SegmentedButton<PreferredCamera>(
              showSelectedIcon: false,
              segments: <ButtonSegment<PreferredCamera>>[
                for (final camera in PreferredCamera.values)
                  ButtonSegment<PreferredCamera>(
                    value: camera,
                    label: Text(camera.label),
                  ),
              ],
              selected: <PreferredCamera>{settings.preferredCamera},
              onSelectionChanged: (selection) => ref
                  .read(settingsControllerProvider.notifier)
                  .setPreferredCamera(selection.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The lens the camera opens with. You can still switch lenses '
              'while shooting.',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Capture ratio', style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<CaptureRatio>(
              showSelectedIcon: false,
              segments: <ButtonSegment<CaptureRatio>>[
                for (final ratio in CaptureRatio.values)
                  ButtonSegment<CaptureRatio>(
                    value: ratio,
                    label: Text(ratio.label),
                  ),
              ],
              selected: <CaptureRatio>{settings.captureRatio},
              onSelectionChanged: (selection) => ref
                  .read(settingsControllerProvider.notifier)
                  .setCaptureRatio(selection.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'What the preview is framed to, and what a photo is cropped to. '
              'Switching it never restarts the camera.',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              value: settings.showSensorSpill,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .setShowSensorSpill(value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Show sensor spill'),
              subtitle: const Text(
                'Dim, rather than hide, the parts of the camera stream that '
                'fall outside the capture frame.',
              ),
            ),
            SwitchListTile(
              value: settings.showAlignmentGrid,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .setShowAlignmentGrid(value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Alignment grid'),
              subtitle: const Text(
                'Draw a rule-of-thirds guide over the preview while '
                'composing. It is never part of the photo.',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle('Overlay defaults'),
            AppSlider(
              label: 'Reference image opacity',
              value: settings.defaultOverlayOpacity,
              divisions: 20,
              valueLabel: '${(settings.defaultOverlayOpacity * 100).round()}%',
              semanticFormatterCallback: (value) =>
                  '${(value * 100).round()} percent',
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .setDefaultOverlayOpacity(value),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle('Feedback'),
            SwitchListTile(
              value: settings.hapticsEnabled,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .setHapticsEnabled(value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Haptic feedback'),
              subtitle: const Text(
                'A short vibration when you tap a control or take a photo.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title.toUpperCase(),
        style: context.textStyles.labelMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
