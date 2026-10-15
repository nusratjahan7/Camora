import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/glass.dart';
import '../../domain/camera_flash_mode.dart';
import '../../domain/camera_session.dart';

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
              const Spacer(),
              if (session.capabilities.supportsFlash)
                GlassIconButton(
                  key: const ValueKey<String>('camera-flash'),
                  icon: _flashIcon(flash),
                  tooltip: 'Flash: ${_flashLabel(flash)}. Tap to change.',
                  active: flash != CameraFlashMode.off,
                  onPressed: canFlash ? onCycleFlash : null,
                ),
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

class CameraBottomBar extends StatelessWidget {
  const CameraBottomBar({
    super.key,
    required this.session,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onZoomChanged,
    this.leading,
    this.accessory,
  });

  final CameraSession session;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final ValueChanged<double> onZoomChanged;

  /// Shown left of the shutter, e.g. the reference-image picker.
  final Widget? leading;

  /// Extra controls above the zoom selector, e.g. overlay adjustments.
  final Widget? accessory;

  @override
  Widget build(BuildContext context) {
    final busy = session.isCapturing;

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
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child:
                            leading ??
                            const SizedBox.square(dimension: _sideSlot),
                      ),
                    ),
                    ShutterButton(
                      busy: busy,
                      onPressed: busy ? null : onCapture,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GlassIconButton(
                          key: const ValueKey<String>('camera-switch'),
                          icon: Icons.cameraswitch_rounded,
                          diameter: _sideSlot,
                          iconSize: 24,
                          tooltip: session.isFrontFacing
                              ? 'Switch to rear camera'
                              : 'Switch to front camera',
                          onPressed: session.canSwitchCamera && !busy
                              ? onSwitchCamera
                              : null,
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

  static const double _sideSlot = 52;
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
                    HapticFeedback.selectionClick();
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
  const ShutterButton({super.key, required this.busy, this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

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
    final discScale = widget.busy
        ? 0.72
        : _pressed
        ? 0.88
        : 1.0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy ? 'Capturing photo' : 'Capture photo',
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
                    color: theme.shutterRing.withValues(
                      alpha: enabled || widget.busy ? 1 : 0.5,
                    ),
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
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.shutterInner.withValues(
                      alpha: enabled || widget.busy ? 1 : 0.5,
                    ),
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
