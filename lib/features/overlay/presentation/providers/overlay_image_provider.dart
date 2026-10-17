import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/files/file_service.dart';
import '../../../gallery/data/image_picker_service.dart';
import '../../../gallery/domain/gallery_entry.dart';
import '../../../gallery/presentation/providers/gallery_history_provider.dart';
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

      _apply(decoded, previous);
      // File the guide away before reporting success, so the history and the
      // file on disk are in step by the time the caller continues.
      await _rememberReference(file);
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

  /// Reuses a reference image from the local gallery history.
  ///
  /// Throws an [ImageSelectionFailure] when the file can no longer be read.
  Future<bool> useStoredReference(String path, {required String name}) async {
    if (_picking) return false;
    _picking = true;

    final errors = ref.read(appErrorHandlerProvider);
    final previous = _current;
    state = const AsyncLoading<OverlayImage?>();
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = await ref
          .read(overlayImageDecoderProvider)
          .decode(bytes, name: name);
      if (!ref.mounted) {
        decoded.image.dispose();
        return false;
      }

      _apply(decoded, previous);
      return true;
    } catch (error, stackTrace) {
      _restore(previous);
      errors.report(error, stackTrace, operation: 'load saved reference');
      final failure = errors.map(error, stackTrace);
      if (failure is ImageSelectionFailure) throw failure;
      throw ImageSelectionFailure(
        'That reference image could not be opened. It may have been removed.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _picking = false;
    }
  }

  void _apply(OverlayImage decoded, OverlayImage? previous) {
    _current = decoded;
    state = AsyncData<OverlayImage?>(decoded);
    ref.read(overlaySettingsProvider.notifier).resetForNewImage();
    ref.read(overlayTrayProvider.notifier).showForNewImage();
    _releaseAfterFrame(previous);
  }

  /// Keeps the app's own copy of a picked file, so the guide can be picked
  /// again from the gallery without reopening the system photo picker.
  ///
  /// Fire and forget: the guide is already on screen, and this outlives the
  /// call, so everything it needs is read up front.
  Future<void> _rememberReference(XFile file) async {
    final files = ref.read(fileServiceProvider);
    final history = ref.read(galleryHistoryProvider.notifier);
    final logger = ref.read(appErrorHandlerProvider).logger;

    try {
      final target = await files.createReferenceFile(
        extension: _extensionOf(file.name),
      );
      // `saveTo` handles both a real file and an XFile held in memory.
      await file.saveTo(target.path);
      await history.record(
        path: target.path,
        kind: GalleryEntryKind.reference,
        name: file.name,
      );
    } catch (error, stackTrace) {
      // Failing to file the guide away is not worth interrupting the user for.
      logger.warning('Could not keep the reference image.', error, stackTrace);
    }
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return 'jpg';
    return name.substring(dot + 1).toLowerCase();
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
