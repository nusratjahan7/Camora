import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/overlay_geometry.dart';
import '../../domain/overlay_image.dart';
import '../../domain/overlay_settings.dart';
import '../providers/overlay_image_provider.dart';
import '../providers/overlay_settings_provider.dart';

/// Draws the reference image over the camera preview and, while unlocked,
/// turns drag / pinch / two-finger rotate anywhere on the preview into overlay
/// transforms.
///
/// Place it above the preview and below the camera controls: controls stay on
/// top in hit-testing order, so overlay gestures can never block them. When
/// there is no image, or it is hidden or locked, the layer ignores pointers
/// and the preview's own gestures (tap-to-focus, pinch-zoom) work as usual.
class ReferenceOverlayLayer extends ConsumerStatefulWidget {
  const ReferenceOverlayLayer({super.key, this.onTap});

  /// Receives taps (in local coordinates) so tap-to-focus keeps working while
  /// the overlay is editable.
  final ValueChanged<Offset>? onTap;

  @override
  ConsumerState<ReferenceOverlayLayer> createState() =>
      _ReferenceOverlayLayerState();
}

class _ReferenceOverlayLayerState extends ConsumerState<ReferenceOverlayLayer> {
  Offset _translation = Offset.zero;
  int _pointers = 0;

  OverlaySettingsController get _controller =>
      ref.read(overlaySettingsProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final image = ref.watch(
      overlayImageProvider.select((state) => state.value),
    );
    final settings = ref.watch(overlaySettingsProvider);
    if (image == null || !settings.isVisible) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final picture = OverlayPicture(
          image: image,
          settings: settings,
          viewport: viewport,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        );

        if (settings.isLocked) return IgnorePointer(child: picture);

        return GestureDetector(
          key: const ValueKey<String>('overlay-gestures'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => widget.onTap?.call(details.localPosition),
          onScaleStart: (details) => _restart(details.pointerCount),
          onScaleUpdate: (details) {
            // Adding or lifting a finger resets the recognizer's scale and
            // rotation baseline, so restart from the current transform.
            if (details.pointerCount != _pointers) {
              _restart(details.pointerCount);
              return;
            }
            _translation += details.focalPointDelta;
            _controller.updateGesture(
              viewport: viewport,
              translation: _translation,
              scale: details.scale,
              rotation: details.rotation,
            );
          },
          onScaleEnd: (_) {
            _pointers = 0;
            _controller.endGesture();
          },
          child: picture,
        );
      },
    );
  }

  void _restart(int pointerCount) {
    _pointers = pointerCount;
    _translation = Offset.zero;
    _controller.beginGesture();
  }
}

/// Paints [image] framed by [settings] within [viewport]. Pure presentation:
/// all geometry comes from [OverlayGeometry].
class OverlayPicture extends StatelessWidget {
  const OverlayPicture({
    super.key,
    required this.image,
    required this.settings,
    required this.viewport,
    required this.devicePixelRatio,
  });

  final OverlayImage image;
  final OverlaySettings settings;
  final Size viewport;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    final base = OverlayGeometry.baseSize(
      image: image.originalSize,
      viewport: viewport,
      mode: settings.fitMode,
      devicePixelRatio: devicePixelRatio,
    );
    final transform = Matrix4.identity()
      ..translateByDouble(
        settings.offset.dx * viewport.width,
        settings.offset.dy * viewport.height,
        0,
        1,
      )
      ..rotateZ(settings.rotation)
      ..scaleByDouble(settings.scale, settings.scale, 1, 1);

    return Semantics(
      image: true,
      label:
          'Reference image overlay, ${settings.opacityPercent} percent opacity',
      child: ClipRect(
        child: OverflowBox(
          // Zero minimums: the parent's tight constraints would otherwise
          // stretch the image to the viewport and break its aspect ratio.
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: SizedBox.fromSize(
              size: base,
              // Painting with alpha directly avoids the offscreen layer an
              // Opacity widget would allocate on every slider frame.
              child: RawImage(
                image: image.image,
                fit: BoxFit.fill,
                opacity: AlwaysStoppedAnimation<double>(settings.opacity),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
