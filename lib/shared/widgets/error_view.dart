import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../extensions/build_context_extensions.dart';
import 'app_button.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.exception,
    this.onRetry,
    this.onOpenSettings,
  });

  final AppException exception;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = context.textStyles;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              exception.message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (onRetry != null || onOpenSettings != null)
              const SizedBox(height: AppSpacing.xl),
            if (onRetry != null)
              AppButton(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: onRetry,
                expand: false,
              ),
            if (onRetry != null && onOpenSettings != null)
              const SizedBox(height: AppSpacing.sm),
            if (onOpenSettings != null)
              AppButton(
                label: 'Open settings',
                variant: AppButtonVariant.outline,
                onPressed: onOpenSettings,
                expand: false,
              ),
          ],
        ),
      ),
    );
  }
}
