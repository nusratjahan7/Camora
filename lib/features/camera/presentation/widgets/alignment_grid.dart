import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../settings/presentation/providers/settings_controller.dart';

/// Rule-of-thirds guide drawn over the preview while composing.
///
/// Purely a visual aid: it sits above the feed (and the reference overlay, so
/// features can be lined up against it) but ignores pointers, and is never
/// part of a capture. Visibility follows the "Alignment grid" preference, so
/// the quick toggle on the camera bar and the switch in Settings stay in step.
class AlignmentGridLayer extends ConsumerWidget {
  const AlignmentGridLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.value?.showAlignmentGrid ?? false,
      ),
    );
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _ThirdsPainter(context.cameraTheme.guide)),
      ),
    );
  }
}

/// Toggle for the alignment grid, kept on the camera bar so it can be turned
/// on and off while the shot is being framed.
class GridToggleButton extends ConsumerWidget {
  const GridToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.value?.showAlignmentGrid ?? false,
      ),
    );

    return GlassIconButton(
      key: const ValueKey<String>('camera-grid'),
      icon: visible ? Icons.grid_on_rounded : Icons.grid_off_rounded,
      tooltip: visible ? 'Hide alignment grid' : 'Show alignment grid',
      active: visible,
      onPressed: () => ref
          .read(settingsControllerProvider.notifier)
          .setShowAlignmentGrid(!visible),
    );
  }
}

class _ThirdsPainter extends CustomPainter {
  const _ThirdsPainter(this.color);

  final Color color;

  /// A soft dark line under the bright one keeps the guide readable on a
  /// bright scene without turning it into a heavy box.
  static const Color _underlay = Color(0x59000000);
  static const double _underlayWidth = 2.4;
  static const double _lineWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final underlay = Paint()
      ..color = _underlay
      ..strokeWidth = _underlayWidth;
    final line = Paint()
      ..color = color
      ..strokeWidth = _lineWidth;

    final verticals = <double>[size.width / 3, size.width * 2 / 3];
    final horizontals = <double>[size.height / 3, size.height * 2 / 3];

    for (final x in verticals) {
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), underlay)
        ..drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (final y in horizontals) {
      canvas
        ..drawLine(Offset(0, y), Offset(size.width, y), underlay)
        ..drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter oldDelegate) => oldDelegate.color != color;
}
