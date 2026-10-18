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
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/permission_rationale_sheet.dart';
import '../../../gallery/data/gallery_saver_service.dart';
import '../../../gallery/domain/gallery_entry.dart';
import '../../../gallery/presentation/providers/gallery_history_provider.dart';
import '../../../overlay/presentation/widgets/overlay_controls.dart';
import '../../../overlay/presentation/widgets/reference_overlay_layer.dart';
import '../../../settings/domain/capture_ratio.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../domain/camera_errors.dart';
import '../../domain/camera_session.dart';
import '../../domain/capture_crop.dart';
import '../../domain/frame_geometry.dart';
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

    // Changing either of these re-lays-out the preview and nothing else: the
    // controller, the stream and the session are untouched.
    final ratio = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.value?.captureRatio ?? CaptureRatio.classic43,
      ),
    );
    final spilled = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.value?.showSensorSpill ?? true,
      ),
    );

    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The builder can run once more after release (a constraint change)
          // without this widget rebuilding, and its controller then throws.
          if (!_notifier.isLive(controller)) return const SizedBox.shrink();
          final viewport = constraints.biggest;
          final displayed = FrameGeometry.coverRect(
            viewport: viewport,
            sensor: _displayAspectRatio(controller.value),
          );
          // The frame may use what is left after the safe areas, so a notch or
          // the home indicator never eats into the shot.
          final available = FrameGeometry.availableArea(
            viewport: viewport,
            safeInsets: MediaQuery.paddingOf(context),
          );
          final frame = FrameGeometry.frameRect(
            available: available,
            aspect: ratio.value,
          );
          final outputRatio = ratio.resolve(available);

          void focusAt(Offset point) =>
              _focus(point, frame: frame, displayed: displayed);

          // One backdrop read of the preview shared by every glass control.
          return BackdropGroup(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // The stream, drawn once and scaled to cover the viewport
                // exactly as before: the frame below is a window onto it, not a
                // second preview, so the capture pipeline is unaffected.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => focusAt(details.localPosition),
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
                // Everything outside the frame: dimmed while the sensor spill is
                // on, solid black when it is off.
                IgnorePointer(
                  child: CustomPaint(
                    painter: _FrameMaskPainter(frame: frame, spilled: spilled),
                  ),
                ),
                // The shot itself. The reference overlay, the grid and the
                // focus reticle are scoped to the frame, so they stay aligned
                // with the visible framing when the ratio changes.
                Positioned.fromRect(
                  rect: frame,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ReferenceOverlayLayer(
                        onTap: (position) =>
                            focusAt(position + frame.topLeft),
                      ),
                      const AlignmentGridLayer(),
                      if (_focusPoint case final point?)
                        _FocusReticle(
                          key: ValueKey<int>(_focusTick),
                          center: point,
                        ),
                    ],
                  ),
                ),
                Positioned.fromRect(
                  rect: frame,
                  child: IgnorePointer(
                    child: _FrameCaption(
                      ratio: ratio,
                      displayed: displayed,
                      frame: frame,
                      outputRatio: outputRatio,
                      stream: _streamSize(controller.value),
                    ),
                  ),
                ),
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
                    onCapture: () => _capture(
                      frame: frame,
                      displayed: displayed,
                      outputRatio: outputRatio,
                    ),
                    onStartRecording: _startRecording,
                    onStopRecording: _stopRecording,
                    onSwitchCamera: _notifier.switchCamera,
                    onToggleMode: _toggleMode,
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

  /// Meters on a tap, but only where the shot is: a tap on the dimmed spill
  /// outside the frame is not part of the photo, so it is ignored.
  Future<void> _focus(
    Offset position, {
    required Rect frame,
    required Rect displayed,
  }) async {
    final session = widget.session;
    if (!session.capabilities.supportsTapToFocus) return;
    if (!frame.contains(position)) return;

    final value = session.controller.value;
    if (!value.isInitialized || value.previewSize == null) return;

    final point = FrameGeometry.focusPoint(
      point: position,
      displayedImage: displayed,
    );
    if (point == null) return;

    setState(() {
      // Frame-local, because the reticle is drawn inside the frame.
      _focusPoint = position - frame.topLeft;
      _focusTick++;
    });
    _reticleTimer?.cancel();
    _reticleTimer = Timer(_reticleDuration, () {
      if (mounted) setState(() => _focusPoint = null);
    });

    await _notifier.focusAt(point);
  }

  Future<void> _capture({
    required Rect frame,
    required Rect displayed,
    required double outputRatio,
  }) async {
    unawaited(Haptics.lightImpact());
    setState(() => _blink = true);
    Future<void>.delayed(_blinkDuration * 2, () {
      if (mounted) setState(() => _blink = false);
    });

    try {
      final file = await _notifier.capture(
        crop: _cropFor(
          frame: frame,
          displayed: displayed,
          outputRatio: outputRatio,
        ),
      );
      if (file == null || !mounted) return;
      await _saveToGallery(file.path);
    } on AppException catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message);
    }
  }

  Future<void> _toggleMode() async {
    await _notifier.setCaptureMode(widget.session.captureMode.other);
  }

  Future<void> _startRecording() async {
    // A clip is filmed with sound, so the microphone is asked for first.
    if (!await _ensureMicrophone() || !mounted) return;

    unawaited(Haptics.mediumImpact());
    try {
      await _notifier.startRecording();
    } on AppException catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message);
    }
  }

  Future<void> _stopRecording() async {
    unawaited(Haptics.lightImpact());
    try {
      final clip = await _notifier.stopRecording();
      if (clip == null || !mounted) return;
      await _saveToGallery(clip.path, video: true);
    } on AppException catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message);
    }
  }

  /// Asks for the microphone, with a rationale, before the first clip.
  Future<bool> _ensureMicrophone() async {
    final permissions = ref.read(permissionServiceProvider);
    if ((await permissions.status(AppPermission.microphone)).isGranted) {
      return true;
    }
    if (!mounted) return false;

    final accepted = await PermissionRationaleSheet.show(
      context,
      permission: AppPermission.microphone,
    );
    if (!accepted || !mounted) return false;

    final status = await permissions.request(AppPermission.microphone);
    if (status.isGranted) return true;
    if (mounted) {
      _notify(
        '${AppConstants.appName} needs the microphone to film with sound.',
        action: status.isBlocked ? _settingsAction : null,
      );
    }
    return false;
  }

  /// The frame the preview showed, expressed against the stream image so the
  /// session can crop the still to match it.
  ///
  /// Returns null when the frame already matches the stream, which is the
  /// cheap way to keep the camera's own bytes: no crop is requested, so not
  /// even a decode happens.
  static CaptureCrop? _cropFor({
    required Rect frame,
    required Rect displayed,
    required double outputRatio,
  }) {
    if (frame.isEmpty || displayed.isEmpty) return null;
    if (FrameGeometry.sameRatio(
      displayed.width / displayed.height,
      outputRatio,
    )) {
      return null;
    }
    return CaptureCrop(
      frame: Rect.fromLTWH(
        (frame.left - displayed.left) / displayed.width,
        (frame.top - displayed.top) / displayed.height,
        frame.width / displayed.width,
        frame.height / displayed.height,
      ),
      aspectRatio: outputRatio,
    );
  }

  /// Writes a capture to the system library and files it in the local gallery,
  /// which keeps the app's own copy of the file.
  ///
  /// The file is the camera's own image or clip — the preview, the controls and
  /// the reference overlay are never part of it — so it is stored untouched.
  Future<void> _saveToGallery(String path, {bool video = false}) async {
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

      if (video) {
        await gallery.saveVideo(path);
      } else {
        await gallery.saveImage(path);
      }
      keep = await _rememberCapture(path, video: video);
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
  Future<bool> _rememberCapture(String path, {bool video = false}) async {
    try {
      await ref
          .read(galleryHistoryProvider.notifier)
          .record(
            path: path,
            kind: video ? GalleryEntryKind.video : GalleryEntryKind.photo,
          );
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
    final size = _streamSize(value);
    if (size == null) return 1;
    return size.width / size.height;
  }

  /// The stream's size in the orientation it is displayed in, which is what the
  /// frame and the caption reason about. Null until the stream reports one.
  static Size? _streamSize(CameraValue value) {
    final preview = value.previewSize;
    if (preview == null || preview.isEmpty) return null;
    return _isLandscape(value)
        ? Size(preview.width, preview.height)
        : Size(preview.height, preview.width);
  }

  static bool _isLandscape(CameraValue value) {
    final orientation = value.isRecordingVideo
        ? value.recordingOrientation
        : value.previewPauseOrientation ??
              value.lockedCaptureOrientation ??
              value.deviceOrientation;
    return orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
  }
}

/// Dims everything outside the capture frame, so the part of the sensor the
/// shot leaves out stays visible (and visibly excluded).
class _FrameMaskPainter extends CustomPainter {
  const _FrameMaskPainter({required this.frame, required this.spilled});

  final Rect frame;

  /// False paints the outside solid black, hiding the spill entirely.
  final bool spilled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(frame),
    );
    canvas.drawPath(
      outside,
      Paint()..color = spilled ? const Color(0x99000000) : Colors.black,
    );
  }

  @override
  bool shouldRepaint(_FrameMaskPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.spilled != spilled;
}

/// Small chip inside the frame that separates what the camera produces from
/// what the shot will keep: the stream's size, then the cropped output's.
class _FrameCaption extends StatelessWidget {
  const _FrameCaption({
    required this.ratio,
    required this.displayed,
    required this.frame,
    required this.outputRatio,
    required this.stream,
  });

  final CaptureRatio ratio;
  final Rect displayed;
  final Rect frame;
  final double outputRatio;
  final Size? stream;

  @override
  Widget build(BuildContext context) {
    final source = stream;
    if (source == null || source.isEmpty) return const SizedBox.shrink();

    final cropped = FrameGeometry.cropRectForFrame(
      displayedImage: displayed,
      frame: frame,
      source: source,
      targetRatio: outputRatio,
    );
    final output = cropped?.size ?? source;
    final text =
        '${source.width.round()}×${source.height.round()} → '
        '${output.width.round()}×${output.height.round()}';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Semantics(
          label:
              '${ratio.spokenLabel} framing. Camera stream $text '
              'after cropping. The reference image is not part of the photo.',
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              child: Text(
                text,
                key: const ValueKey<String>('camera-frame-caption'),
                style: context.textStyles.labelSmall?.copyWith(
                  color: context.cameraTheme.onScrim.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
