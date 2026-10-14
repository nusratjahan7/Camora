import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/overlay_settings.dart';

class OverlaySettingsController extends Notifier<OverlaySettings> {
  @override
  OverlaySettings build() => OverlaySettings.defaults;

  void setOpacity(double value) {
    state = state.copyWith(
      opacity: value.clamp(
        AppConstants.minOverlayOpacity,
        AppConstants.maxOverlayOpacity,
      ),
    );
  }

  void setScale(double value) =>
      state = state.copyWith(scale: value.clamp(0.2, 3.0));

  void setOffset(Offset value) => state = state.copyWith(offset: value);

  void setRotation(double value) => state = state.copyWith(rotation: value);

  void reset() => state = OverlaySettings.defaults;
}

final overlaySettingsProvider =
    NotifierProvider<OverlaySettingsController, OverlaySettings>(
      OverlaySettingsController.new,
    );
