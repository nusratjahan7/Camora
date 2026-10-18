import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/haptics/haptics.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/glass.dart';
import '../../domain/camera_flash_mode.dart';
import '../../domain/camera_session.dart';
import '../../domain/capture_mode.dart';
import 'alignment_grid.dart';
import 'camera_ratio_pill.dart';

class CameraCloseButton extends StatelessWidget {
  const CameraCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icons.close_rounded,
      tooltip: 'Close camera',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
      },
    );
  }
}

/// Opens the app's own gallery: the photos this app captured and the reference
/// images it has used.
class GalleryShortcutButton extends StatelessWidget {
  const GalleryShortcutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      key: const ValueKey<String>('camera-gallery'),
      icon: Icons.photo_library_outlined,
      diameter: CameraBottomBar.sideSlot,
      iconSize: 24,
      tooltip: 'Open gallery',
      onPressed: () => context.go(AppRoutes.gallery),
    );
  }
}

/// Soft vertical fade that keeps floating controls legible on any scene
/// without boxing the preview in.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child, required this.fromTop});

  final Widget child;
  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      Colors.black.withValues(alpha: 0.55),
      Colors.black.withValues(alpha: 0.18),
      Colors.transparent,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: colors,
          stops: const <double>[0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.session,
    required this.onCycleFlash,
  });

  final CameraSession session;
  final VoidCallback onCycleFlash;

  @override
  Widget build(BuildContext context) {
    final flash = session.flashMode;
    final canFlash = session.capabilities.supportsFlash && !session.isCapturing;

    return _Scrim(
      fromTop: true,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Row(
            children: <Widget>[
              const CameraCloseButton(),
              if (session.isRecording) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                _RecordingChip(duration: session.recordingDuration),
              ],
              const Spacer(),
              const CaptureRatioButton(),
              const SizedBox(width: AppSpacing.sm),
              const GridToggleButton(),
              if (session.capabilities.supportsFlash) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                GlassIconButton(
                  key: const ValueKey<String>('camera-flash'),
                  icon: _flashIcon(flash),
                  tooltip: 'Flash: ${_flashLabel(flash)}. Tap to change.',
                  active: flash != CameraFlashMode.off,
                  onPressed: canFlash ? onCycleFlash : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData _flashIcon(CameraFlashMode mode) => switch (mode) {
    CameraFlashMode.off => Icons.flash_off_rounded,
    CameraFlashMode.auto => Icons.flash_auto_rounded,
    CameraFlashMode.on => Icons.flash_on_rounded,
    CameraFlashMode.torch => Icons.flashlight_on_rounded,
  };

  static String _flashLabel(CameraFlashMode mode) => switch (mode) {
    CameraFlashMode.off => 'off',
    CameraFlashMode.auto => 'auto',
    CameraFlashMode.on => 'on',
    CameraFlashMode.torch => 'torch',
  };
}

/// Elapsed-time chip shown beside the close button while a clip is filming.
class _RecordingChip extends StatelessWidget {
  const _RecordingChip({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final danger = context.colors.error;

    return Semantics(
      label: 'Recording, $minutes minutes $seconds seconds elapsed',
      excludeSemantics: true,
      child: GlassSurface(
        borderRadius: AppRadius.pillAll,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: 30,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: danger),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$minutes:$seconds',
                key: const ValueKey<String>('camera-recording-timer'),
                style: context.textStyles.labelMedium?.copyWith(
                  color: context.cameraTheme.onScrim,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switches between taking stills and filming clips.
///
/// Shows the mode you would move *to*, like a toggle: a video icon while
/// taking photos, a camera icon while filming.
class CameraModeButton extends StatelessWidget {
  const CameraModeButton({
    super.key,
    required this.mode,
    required this.onPressed,
  });

  final CaptureMode mode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      key: const ValueKey<String>('camera-mode'),
      icon: mode.isVideo
          ? Icons.photo_camera_outlined
          : Icons.videocam_outlined,
      diameter: CameraBottomBar.sideSlot,
      iconSize: 24,
      tooltip: mode.isVideo ? 'Switch to photo' : 'Switch to video',
      active: mode.isVideo,
      onPressed: onPressed,
    );
  }
}

class CameraBottomBar extends StatelessWidget {
  const CameraBottomBar({
    super.key,
    required this.session,
    required this.onCapture,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onSwitchCamera,
    required this.onToggleMode,
    required this.onZoomChanged,
    this.leading,
    this.accessory,
  });

  final CameraSession session;
  final VoidCallback onCapture;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleMode;
  final ValueChanged<double> onZoomChanged;

  /// Shown left of the shutter, e.g. the gallery and reference-image buttons.
  final Widget? leading;

  /// Extra controls above the zoom selector, e.g. overlay adjustments.
  final Widget? accessory;

  /// Diameter of the buttons flanking the shutter.
  static const double sideSlot = 52;

  @override
  Widget build(BuildContext context) {
    final capturing = session.isCapturing;
    final recording = session.isRecording;
    final video = session.captureMode.isVideo;
    // The shutter stays live while filming, so the same button stops the clip.
    final onShutter = capturing
        ? null
        : video
        ? (recording ? onStopRecording : onStartRecording)
        : onCapture;

    return _Scrim(
      fromTop: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xxl,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ?accessory,
              if (session.capabilities.supportsZoom)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ZoomSelector(
                    session: session,
                    onChanged: onZoomChanged,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      // Scales down rather than overflowing on very narrow
                      // screens; the shutter stays centred either way.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child:
                            leading ??
                            const SizedBox.square(dimension: sideSlot),
                      ),
                    ),
                    ShutterButton(
                      busy: capturing,
                      video: video,
                      recording: recording,
                      onPressed: onShutter,
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            GlassIconButton(
                              key: const ValueKey<String>('camera-switch'),
                              icon: Icons.cameraswitch_rounded,
                              diameter: sideSlot,
                              iconSize: 24,
                              tooltip: session.isFrontFacing
                                  ? 'Switch to rear camera'
                                  : 'Switch to front camera',
                              onPressed: session.canSwitchCamera &&
                                      !capturing &&
                                      !recording
                                  ? onSwitchCamera
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            CameraModeButton(
                              mode: session.captureMode,
                              onPressed: capturing || recording
                                  ? null
                                  : onToggleMode,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lens-style zoom stops (0.5×, 1×, 2×…) in a glass pill. Tap a stop to jump
/// to it; drag across the pill for continuous zoom.
class _ZoomSelector extends StatefulWidget {
  const _ZoomSelector({required this.session, required this.onChanged});

  final CameraSession session;
  final ValueChanged<double> onChanged;

  @override
  State<_ZoomSelector> createState() => _ZoomSelectorState();
}

class _ZoomSelectorState extends State<_ZoomSelector> {
  /// Logical pixels of drag that double (or halve) the zoom.
  static const double _dragPerDoubling = 120;

  double _dragStartZoom = 1;
  double _dragDistance = 0;

  List<double> get _stops {
    final caps = widget.session.capabilities;
    final stops = <double>[
      if (caps.minZoom < 0.95) double.parse(caps.minZoom.toStringAsFixed(1)),
      for (final stop in const <double>[1, 2, 5, 10])
        if (stop >= caps.minZoom - 0.01 && stop <= caps.maxZoom + 0.01) stop,
    ];
    return stops.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final zoom = widget.session.zoom;
    final stops = _stops;
    // The active stop is the lens band the current zoom falls in.
    final active = stops.lastWhere(
      (stop) => zoom >= stop - 0.05,
      orElse: () => stops.first,
    );
    final caps = widget.session.capabilities;

    return Semantics(
      slider: true,
      label: 'Zoom',
      value: '${zoom.toStringAsFixed(1)} times',
      increasedValue: '${caps.clampZoom(zoom * 1.25).toStringAsFixed(1)} times',
      decreasedValue: '${caps.clampZoom(zoom / 1.25).toStringAsFixed(1)} times',
      onIncrease: () => widget.onChanged(zoom * 1.25),
      onDecrease: () => widget.onChanged(zoom / 1.25),
      child: GestureDetector(
        key: const ValueKey<String>('camera-zoom'),
        onHorizontalDragStart: (_) {
          _dragStartZoom = widget.session.zoom;
          _dragDistance = 0;
        },
        onHorizontalDragUpdate: (details) {
          _dragDistance += details.delta.dx;
          widget.onChanged(
            _dragStartZoom * math.pow(2, _dragDistance / _dragPerDoubling),
          );
        },
        child: GlassSurface(
          padding: const EdgeInsets.all(3),
          borderRadius: BorderRadius.circular(22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final stop in stops)
                _ZoomStop(
                  label: stop == active ? '${_format(zoom)}×' : _format(stop),
                  selected: stop == active,
                  accent: theme.accent,
                  onTap: () {
                    Haptics.selectionClick();
                    widget.onChanged(stop);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }
}

class _ZoomStop extends StatelessWidget {
  const _ZoomStop({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: AppConstants.minTapTarget,
        height: 38,
        child: Center(
          child: AnimatedContainer(
            duration: AppConstants.standardAnimation,
            curve: Curves.easeOutCubic,
            width: selected ? 44 : 30,
            height: selected ? 34 : 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: selected ? 0.45 : 0.25),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: context.textStyles.labelSmall?.copyWith(
                color: selected ? accent : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: selected ? 12 : 11,
                fontFeatures: tabularFigures,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShutterButton extends StatefulWidget {
  const ShutterButton({
    super.key,
    required this.busy,
    this.onPressed,
    this.video = false,
    this.recording = false,
  });

  final bool busy;
  final VoidCallback? onPressed;

  /// Video mode: the disc turns red, and becomes a stop square while filming.
  final bool video;
  final bool recording;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final enabled = widget.onPressed != null;
    final active = enabled || widget.busy || widget.recording;
    final danger = context.colors.error;
    final disc = widget.video ? danger : theme.shutterInner;
    final ring = widget.recording ? danger : theme.shutterRing;
    final discScale = widget.recording
        ? 0.46
        : widget.busy
        ? 0.72
        : _pressed
        ? 0.88
        : 1.0;
    final label = widget.recording
        ? 'Stop recording'
        : widget.video
        ? 'Start recording'
        : widget.busy
        ? 'Capturing photo'
        : 'Capture photo';

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        key: const ValueKey<String>('camera-shutter'),
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: SizedBox.square(
          dimension: 80,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Outer ring.
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ring.withValues(alpha: active ? 1 : 0.5),
                    width: 4,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              if (widget.busy)
                SizedBox.square(
                  dimension: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    color: theme.accent,
                  ),
                ),
              AnimatedScale(
                scale: discScale,
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    // A 64px box with a 32px radius is a circle, so the disc
                    // can morph into the stop square without ever changing
                    // shape (which a BoxDecoration cannot tween).
                    borderRadius: BorderRadius.circular(
                      widget.recording ? 9 : 32,
                    ),
                    color: disc.withValues(alpha: active ? 1 : 0.5),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
