import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../overlay/presentation/widgets/overlay_controls.dart';
import '../../../overlay/presentation/widgets/reference_overlay_layer.dart';
import '../../domain/camera_errors.dart';
import '../../domain/camera_session.dart';
import '../../domain/preview_geometry.dart';
import '../providers/camera_providers.dart';
import 'camera_controls.dart';

class CameraPreviewView extends ConsumerWidget {
  const CameraPreviewView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cameraSessionProvider);

    // Loading is checked first on purpose: while reloading, Riverpod still
    // carries the previous session, whose controller is already released.
    if (session.isLoading) {
      return const CameraStatusFrame(
        child: LoadingView(message: 'Starting the camera…'),
      );
    }

    if (session.hasError) {
      final failure = ref
          .read(appErrorHandlerProvider)
          .map(session.error!, session.stackTrace ?? StackTrace.empty);
      return CameraStatusFrame(
        child: ErrorView(
          exception: failure,
          onRetry: () {
            ref.invalidate(camerasProvider);
            ref.invalidate(cameraSessionProvider);
          },
          onOpenSettings: isCameraAccessDenied(failure)
              ? () => ref.read(permissionServiceProvider).openSettings()
              : null,
        ),
      );
    }

    final value = session.value;
    if (value == null) {
      return const CameraStatusFrame(
        child: LoadingView(message: 'Starting the camera…'),
      );
    }

    return _CameraViewport(key: ObjectKey(value.controller), session: value);
  }
}

/// Black backdrop with a close button, so non-preview states never trap the
/// user on the camera screen.
class CameraStatusFrame extends StatelessWidget {
  const CameraStatusFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          child,
          const Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: CameraCloseButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraViewport extends ConsumerStatefulWidget {
  const _CameraViewport({super.key, required this.session});

  final CameraSession session;

  @override
  ConsumerState<_CameraViewport> createState() => _CameraViewportState();
}

class _CameraViewportState extends ConsumerState<_CameraViewport> {
  static const Duration _reticleDuration = Duration(milliseconds: 900);
  static const Duration _blinkDuration = Duration(milliseconds: 90);

  Offset? _focusPoint;
  int _focusTick = 0;
  Timer? _reticleTimer;
  bool _blink = false;
  double _zoomAtScaleStart = 1.0;

  CameraSessionController get _notifier =>
      ref.read(cameraSessionProvider.notifier);

  @override
  void dispose() {
    _reticleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final controller = session.controller;

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          // One backdrop read of the preview shared by every glass control.
          return BackdropGroup(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _focus(details.localPosition, viewport),
                  onScaleStart: (_) => _zoomAtScaleStart = widget.session.zoom,
                  onScaleUpdate: (details) {
                    if (details.pointerCount < 2) return;
                    _notifier.setZoom(_zoomAtScaleStart * details.scale);
                  },
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        // Any width works: FittedBox rescales, and CameraPreview
                        // derives its height from the stream's aspect ratio.
                        width:
                            controller.value.previewSize?.shortestSide ?? 720,
                        child: CameraPreview(controller),
                      ),
                    ),
                  ),
                ),
                // Above the preview, below the controls: a visual guide only, never
                // part of the captured photo.
                ReferenceOverlayLayer(
                  onTap: (position) => _focus(position, viewport),
                ),
                if (_focusPoint case final point?)
                  _FocusReticle(key: ValueKey<int>(_focusTick), center: point),
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _blink ? 1 : 0,
                    duration: _blinkDuration,
                    child: const ColoredBox(color: Colors.black),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: CameraTopBar(
                    session: session,
                    onCycleFlash: _notifier.cycleFlashMode,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CameraBottomBar(
                    session: session,
                    onCapture: _capture,
                    onSwitchCamera: _notifier.switchCamera,
                    onZoomChanged: _notifier.setZoom,
                    leading: const OverlayPickerButton(),
                    accessory: const OverlayControlPanel(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _focus(Offset position, Size viewport) async {
    final session = widget.session;
    if (!session.capabilities.supportsTapToFocus) return;

    final value = session.controller.value;
    if (!value.isInitialized || value.previewSize == null) return;

    final point = coverPointToPreview(
      point: position,
      viewport: viewport,
      preview: Size(_displayAspectRatio(value), 1),
    );
    if (point == null) return;

    setState(() {
      _focusPoint = position;
      _focusTick++;
    });
    _reticleTimer?.cancel();
    _reticleTimer = Timer(_reticleDuration, () {
      if (mounted) setState(() => _focusPoint = null);
    });

    await _notifier.focusAt(point);
  }

  Future<void> _capture() async {
    unawaited(HapticFeedback.lightImpact());
    setState(() => _blink = true);
    Future<void>.delayed(_blinkDuration * 2, () {
      if (mounted) setState(() => _blink = false);
    });

    try {
      final file = await _notifier.capture();
      if (file != null && mounted) context.showAppSnackBar('Photo captured');
    } on AppException catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message);
    }
  }

  /// Mirrors how [CameraPreview] orients the stream, so tap coordinates match
  /// what is on screen.
  static double _displayAspectRatio(CameraValue value) {
    final orientation = value.isRecordingVideo
        ? value.recordingOrientation
        : value.previewPauseOrientation ??
              value.lockedCaptureOrientation ??
              value.deviceOrientation;
    final landscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    return landscape ? value.aspectRatio : 1 / value.aspectRatio;
  }
}

class _FocusReticle extends StatelessWidget {
  const _FocusReticle({super.key, required this.center});

  static const double _size = 76;

  final Offset center;

  @override
  Widget build(BuildContext context) {
    final accent = context.cameraTheme.accent;
    return Positioned(
      left: center.dx - _size / 2,
      top: center.dy - _size / 2,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 1.35 - 0.35 * t, child: child),
          ),
          child: CustomPaint(
            size: const Size.square(_size),
            painter: _ReticlePainter(accent),
          ),
        ),
      ),
    );
  }
}

/// Four corner brackets with a small centre tick, like a camera AF box.
class _ReticlePainter extends CustomPainter {
  const _ReticlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const arm = 14.0;
    final w = size.width;
    final h = size.height;
    final corners = <(Offset, Offset, Offset)>[
      (const Offset(0, arm), Offset.zero, const Offset(arm, 0)),
      (Offset(w - arm, 0), Offset(w, 0), Offset(w, arm)),
      (Offset(w, h - arm), Offset(w, h), Offset(w - arm, h)),
      (Offset(arm, h), Offset(0, h), Offset(0, h - arm)),
    ];
    for (final (a, corner, b) in corners) {
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(b.dx, b.dy),
        paint,
      );
    }
    final c = size.center(Offset.zero);
    canvas
      ..drawLine(c.translate(-4, 0), c.translate(4, 0), paint)
      ..drawLine(c.translate(0, -4), c.translate(0, 4), paint);
  }

  @override
  bool shouldRepaint(_ReticlePainter oldDelegate) => oldDelegate.color != color;
}
