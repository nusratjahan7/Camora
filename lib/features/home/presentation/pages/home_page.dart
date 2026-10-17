import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/brand_mark.dart';

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
                  const BrandMark(size: 44),
                  const SizedBox(width: AppSpacing.md),
                  Text(AppConstants.appName, style: text.titleLarge),
                ],
              ),
              const Spacer(),
              Text(AppConstants.appTagline, style: text.displaySmall),
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
                label: 'Gallery',
                icon: Icons.photo_library_outlined,
                variant: AppButtonVariant.outline,
                onPressed: () => context.go(AppRoutes.gallery),
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
                'The reference image is only a guide: it is never saved into '
                'your photos.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
