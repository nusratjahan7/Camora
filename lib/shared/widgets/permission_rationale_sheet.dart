import 'package:flutter/material.dart';

import '../../core/permissions/app_permission.dart';
import '../../core/theme/app_spacing.dart';
import '../extensions/build_context_extensions.dart';
import 'app_button.dart';

class PermissionRationaleSheet extends StatelessWidget {
  const PermissionRationaleSheet({super.key, required this.permission});

  final AppPermission permission;

  static Future<bool> show(
    BuildContext context, {
    required AppPermission permission,
  }) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PermissionRationaleSheet(permission: permission),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = context.textStyles;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.shield_outlined, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    permission.rationaleTitle,
                    style: text.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              permission.rationaleBody,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Continue',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Not now',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
