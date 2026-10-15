import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../domain/overlay_fit_mode.dart';
import '../../domain/overlay_geometry.dart';
import '../../domain/overlay_settings.dart';

class OverlaySettingsController extends Notifier<OverlaySettings> {
  static const List<double> opacityPresets = <double>[0.25, 0.5, 0.75, 1.0];

  /// Transform captured when a pinch/drag began; null between gestures.
  OverlaySettings? _gestureStart;

  @override
  OverlaySettings build() =>
      OverlaySettings.defaults.copyWith(opacity: _defaultOpacity);

  /// The user's preferred starting opacity from Settings.
  double get _defaultOpacity =>
      ref.read(settingsControllerProvider).value?.defaultOverlayOpacity ??
      AppConstants.defaultOverlayOpacity;

  bool get isGestureActive => _gestureStart != null;

  void setOpacity(double value) {
    state = state.copyWith(
      opacity: value
          .clamp(AppConstants.minOverlayOpacity, AppConstants.maxOverlayOpacity)
          .toDouble(),
    );
  }

  void resetOpacity() => setOpacity(_defaultOpacity);

  void setScale(double value) =>
      state = state.copyWith(scale: OverlayGeometry.clampScale(value));

  void setOffset(Offset value) =>
      state = state.copyWith(offset: OverlayGeometry.clampOffset(value));

  void setRotation(double value) => state = state.copyWith(rotation: value);

  /// Switches the sizing mode and starts again from that mode's framing.
  void setFitMode(OverlayFitMode mode) =>
      state = state.withoutTransform().copyWith(fitMode: mode);

  /// Undoes drag, pinch and rotation within the current fit mode.
  void resetPosition() => state = state.withoutTransform();

  void setLocked(bool locked) {
    if (locked) _gestureStart = null;
    state = state.copyWith(isLocked: locked);
  }

  void toggleLocked() => setLocked(!state.isLocked);

  void setVisible(bool visible) {
    if (!visible) _gestureStart = null;
    state = state.copyWith(isVisible: visible);
  }

  void toggleVisible() => setVisible(!state.isVisible);

  void beginGesture() {
    if (state.isLocked || !state.isVisible) return;
    _gestureStart = state;
  }

  /// [translation], [scale] and [rotation] are cumulative since [beginGesture].
  void updateGesture({
    required Size viewport,
    required Offset translation,
    required double scale,
    required double rotation,
  }) {
    final start = _gestureStart;
    if (start == null) return;
    final next = OverlayGeometry.applyGesture(
      start: start,
      viewport: viewport,
      translation: translation,
      scale: scale,
      rotation: rotation,
    );
    // Opacity may have changed mid-gesture; never roll it back.
    state = next.copyWith(opacity: state.opacity);
  }

  void endGesture() {
    if (_gestureStart == null) return;
    _gestureStart = null;
    state = state.copyWith(
      rotation: OverlayGeometry.settleRotation(state.rotation),
    );
  }

  /// A new image starts framed by [OverlayFitMode.fit], shown and unlocked;
  /// the user's opacity carries over.
  void resetForNewImage() {
    _gestureStart = null;
    state = OverlaySettings.defaults.copyWith(opacity: state.opacity);
  }

  void reset() {
    _gestureStart = null;
    state = OverlaySettings.defaults.copyWith(opacity: _defaultOpacity);
  }
}

final overlaySettingsProvider =
    NotifierProvider<OverlaySettingsController, OverlaySettings>(
      OverlaySettingsController.new,
    );
