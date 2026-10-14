import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../extensions/build_context_extensions.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.filled = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final foreground = onPressed == null
        ? scheme.onSurface.withValues(alpha: 0.38)
        : color ?? scheme.onSurface;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? scheme.surfaceContainerHigh : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppConstants.minTapTarget,
            height: AppConstants.minTapTarget,
            child: Icon(icon, size: 22, color: foreground),
          ),
        ),
      ),
    );
  }
}
