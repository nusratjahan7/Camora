import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../gallery/data/image_picker_service.dart';
import '../../data/overlay_image_decoder.dart';
import '../../domain/overlay_image.dart';
import 'overlay_settings_provider.dart';
import 'overlay_tray_provider.dart';

/// Holds the single reference image and owns its decoded pixels.
///
/// While a pick is in progress the state is loading but still carries the
/// previous image, so the current guide stays on screen until the new one is
/// ready, and stays put if the pick is cancelled or fails.
class OverlayImageController extends AsyncNotifier<OverlayImage?> {
  bool _picking = false;

  /// Mirrors the image in state: `ref` (and so `state`) cannot be read while
  /// disposing.
  OverlayImage? _current;

  @override
  Future<OverlayImage?> build() async {
    ref.onDispose(() {
      _current?.image.dispose();
      _current = null;
    });
    return null;
  }

  /// Opens the gallery and replaces the reference image.
  ///
  /// Returns true when a new image was loaded, false when the user cancelled.
  /// Throws an [ImageSelectionFailure] when the image cannot be used.
  Future<bool> pickFromGallery() async {
    if (_picking) return false;
    _picking = true;

    final errors = ref.read(appErrorHandlerProvider);
    final previous = _current;
    state = const AsyncLoading<OverlayImage?>();
    try {
      final file = await ref.read(imagePickerServiceProvider).pickFromGallery();
      if (file == null) {
        _restore(previous);
        return false;
      }

      final bytes = await file.readAsBytes();
      final decoded = await ref
          .read(overlayImageDecoderProvider)
          .decode(bytes, name: file.name);
      if (!ref.mounted) {
        decoded.image.dispose();
        return false;
      }

      _current = decoded;
      state = AsyncData<OverlayImage?>(decoded);
      ref.read(overlaySettingsProvider.notifier).resetForNewImage();
      ref.read(overlayTrayProvider.notifier).showForNewImage();
      _releaseAfterFrame(previous);
      return true;
    } catch (error, stackTrace) {
      _restore(previous);
      errors.report(error, stackTrace, operation: 'load reference image');
      final failure = errors.map(error, stackTrace);
      if (failure is ImageSelectionFailure) throw failure;
      throw ImageSelectionFailure(
        'The gallery could not be opened. Please try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _picking = false;
    }
  }

  void remove() {
    final previous = _current;
    if (previous == null) return;
    _current = null;
    state = const AsyncData<OverlayImage?>(null);
    ref.read(overlaySettingsProvider.notifier).resetForNewImage();
    _releaseAfterFrame(previous);
  }

  void _restore(OverlayImage? previous) {
    if (ref.mounted) state = AsyncData<OverlayImage?>(previous);
  }

  /// The old image may still be painted in the current frame; free its GPU
  /// memory once a frame without it has been drawn.
  void _releaseAfterFrame(OverlayImage? image) {
    if (image == null) return;
    final scheduler = SchedulerBinding.instance;
    scheduler.addPostFrameCallback((_) => image.image.dispose());
    scheduler.scheduleFrame();
  }
}

final overlayImageProvider =
    AsyncNotifierProvider<OverlayImageController, OverlayImage?>(
      OverlayImageController.new,
    );
