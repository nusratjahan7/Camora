import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../extensions/build_context_extensions.dart';

/// Frosted surface for controls that float over the camera preview: the
/// preview shows through blurred, with a hairline edge to separate the two.
///
/// Uses a grouped backdrop so that every glass control under one
/// [BackdropGroup] shares a single backdrop read of the live preview.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.circle = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool circle;
  final EdgeInsetsGeometry padding;

  static final ImageFilter _blur = ImageFilter.blur(sigmaX: 20, sigmaY: 20);

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final decoration = BoxDecoration(
      color: theme.glassFill,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : borderRadius,
      border: Border.all(color: theme.glassBorder, width: 0.8),
    );
    final content = BackdropFilter.grouped(
      filter: _blur,
      child: DecoratedBox(
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      ),
    );
    return circle
        ? ClipOval(child: content)
        : ClipRRect(borderRadius: borderRadius, child: content);
  }
}

/// Round glass button with a 48dp hit target around a [diameter] visual.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
    this.diameter = 44,
    this.iconSize = 21,
    this.glass = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Tints the icon with the accent, e.g. flash on or lock engaged.
  final bool active;
  final double diameter;
  final double iconSize;

  /// False draws only the icon, for buttons that already sit on glass.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final enabled = onPressed != null;
    final color = !enabled
        ? theme.onScrim.withValues(alpha: 0.35)
        : active
        ? theme.accent
        : theme.onScrim;

    final iconWidget = AnimatedSwitcher(
      duration: AppConstants.fastAnimation,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Icon(
        icon,
        key: ValueKey<IconData>(icon),
        size: iconSize,
        color: color,
      ),
    );
    final face = SizedBox.square(
      dimension: diameter,
      child: Center(child: iconWidget),
    );

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox.square(
            dimension: diameter < AppConstants.minTapTarget
                ? AppConstants.minTapTarget
                : diameter,
            child: Center(
              child: glass ? GlassSurface(circle: true, child: face) : face,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact segmented control; the selected segment is a solid light pill.
class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.expand = false,
  });

  final List<GlassSegment<T>> segments;

  /// Null when nothing is selected (e.g. a fit mode after a manual drag).
  final T? selected;
  final ValueChanged<T> onSelected;

  /// Stretch segments to fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final style = context.textStyles.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );

    Widget segment(GlassSegment<T> item) {
      final isSelected = item.value == selected;
      final child = Semantics(
        button: true,
        selected: isSelected,
        child: GestureDetector(
          key: item.key,
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(item.value);
          },
          child: AnimatedContainer(
            duration: AppConstants.standardAnimation,
            curve: Curves.easeOutCubic,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? theme.onScrim : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
            ),
            child: AnimatedDefaultTextStyle(
              duration: AppConstants.standardAnimation,
              style: (style ?? const TextStyle()).copyWith(
                color: isSelected
                    ? Colors.black
                    : theme.onScrim.withValues(alpha: 0.72),
              ),
              child: Text(item.label, maxLines: 1, softWrap: false),
            ),
          ),
        ),
      );
      // 34dp pill inside a 48dp hit area.
      return SizedBox(
        height: AppConstants.minTapTarget,
        child: Center(child: child),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          for (final item in segments)
            if (expand) Expanded(child: segment(item)) else segment(item),
        ],
      ),
    );
  }
}

class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label, this.key});

  final T value;
  final String label;
  final Key? key;
}

/// Figures that don't jitter as values change (percentages, zoom).
const List<FontFeature> tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];
