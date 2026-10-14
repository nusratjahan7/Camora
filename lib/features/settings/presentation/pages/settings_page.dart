import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_slider.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
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
            SwitchListTile(
              value: settings.showAlignmentGrid,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .setShowAlignmentGrid(value),
              contentPadding: EdgeInsets.zero,
              title: const Text('Show alignment grid'),
              subtitle: const Text(
                'Display a rule-of-thirds guide while composing a shot.',
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
