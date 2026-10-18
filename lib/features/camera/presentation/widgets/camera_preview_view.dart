import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/haptics/haptics.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/permission_rationale_sheet.dart';
import '../../../gallery/data/gallery_saver_service.dart';
import '../../../gallery/domain/gallery_entry.dart';
import '../../../gallery/presentation/providers/gallery_history_provider.dart';
import '../../../overlay/presentation/widgets/overlay_controls.dart';
import '../../../overlay/presentation/widgets/reference_overlay_layer.dart';
import '../../domain/camera_errors.dart';
import '../../domain/camera_session.dart';
import '../../domain/preview_geometry.dart';
import '../providers/camera_providers.dart';
import 'alignment_grid.dart';
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

    // A released controller cannot render a preview, and `CameraPreview`
    // throws if it is built with one. Rebuild when the session changes so the
    // released viewport renders nothing while it waits to be replaced.
    ref.watch(cameraSessionProvider);
    if (!_notifier.isLive(controller)) {
      return const ColoredBox(color: Colors.black);
    }

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The builder can run once more after release (a constraint change)
          // without this widget rebuilding, and its controller then throws.
          if (!_notifier.isLive(controller)) return const SizedBox.shrink();
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
                // The grid sits above the reference image so features can be
                // lined up against the thirds.
                const AlignmentGridLayer(),
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
                    leading: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        GalleryShortcutButton(),
                        SizedBox(width: AppSpacing.sm),
                        OverlayPickerButton(),
                      ],
                    ),
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
    unawaited(Haptics.lightImpact());
    setState(() => _blink = true);
    Future<void>.delayed(_blinkDuration * 2, () {
      if (mounted) setState(() => _blink = false);
    });

    try {
      final file = await _notifier.capture();
      if (file == null || !mounted) return;
      await _saveToGallery(file.path);
    } on AppException catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message);
    }
  }

  /// Writes the capture to the system photo library and files it in the local
  /// gallery, which keeps the app's own copy of the file.
  ///
  /// The file is the camera's own image — the preview, the controls and the
  /// reference overlay are never part of it — so it is stored untouched.
  Future<void> _saveToGallery(String path) async {
    final gallery = ref.read(gallerySaverServiceProvider);
    var keep = false;
    try {
      if (!await gallery.hasAccess()) {
        if (!mounted) return;
        final accepted = await PermissionRationaleSheet.show(
          context,
          permission: AppPermission.photosAddOnly,
        );
        if (!accepted || !await gallery.requestAccess()) {
          if (mounted) {
            _notify(
              '${AppConstants.appName} needs permission to save to your '
              '${GallerySaverService.libraryName.toLowerCase()}.',
              action: _settingsAction,
            );
          }
          return;
        }
      }

      await gallery.saveImage(path);
      keep = await _rememberCapture(path);
      // No confirmation message: the flash and the haptic already say the
      // photo was taken, and the noise over the preview is not wanted.
      if (mounted) unawaited(Haptics.mediumImpact());
    } on AppException catch (failure) {
      if (mounted) {
        _notify(
          failure.message,
          action: isGalleryAccessDenied(failure) ? _settingsAction : null,
        );
      }
    } finally {
      if (!keep) _deleteWorkingCopy(path);
    }
  }

  /// Files the capture in the local gallery history, which keeps the working
  /// copy. Returns false when it could not be recorded, so the caller cleans
  /// the copy up rather than leaking a file nothing points at.
  Future<bool> _rememberCapture(String path) async {
    try {
      await ref
          .read(galleryHistoryProvider.notifier)
          .record(path: path, kind: GalleryEntryKind.photo);
      return true;
    } catch (error, stackTrace) {
      // The photo is already in the system library; a history failure is not
      // worth reporting as a failed capture.
      ref
          .read(appErrorHandlerProvider)
          .logger
          .warning('The capture was not added to the gallery.', error, stackTrace);
      return false;
    }
  }

  SnackBarAction get _settingsAction => SnackBarAction(
    label: 'Settings',
    onPressed: () => ref.read(permissionServiceProvider).openSettings(),
  );

  void _notify(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  void _deleteWorkingCopy(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (error, stackTrace) {
      // The photo is already in the library; failing to free the copy is not
      // worth interrupting the user for.
      ref
          .read(appErrorHandlerProvider)
          .logger
          .warning('Could not delete $path.', error, stackTrace);
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
