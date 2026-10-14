import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colors;
    final text = context.textStyles;

    return AppScaffold(
      padded: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.16),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Icon(Icons.layers_outlined, color: scheme.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(AppConstants.appName, style: text.titleLarge),
                ],
              ),
              const Spacer(),
              Text('Shoot through your reference.', style: text.displaySmall),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Pick an image from your gallery, float it over the live camera '
                'preview, dial in the opacity, then line up the perfect shot.',
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Open camera',
                icon: Icons.photo_camera_outlined,
                onPressed: () => context.go(AppRoutes.camera),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Settings',
                icon: Icons.tune,
                variant: AppButtonVariant.outline,
                onPressed: () => context.go(AppRoutes.settings),
              ),
              const Spacer(),
              Text(
                'Foundation build — overlay alignment and capture arrive in '
                'the next module.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
