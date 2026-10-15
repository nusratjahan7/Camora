import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/files/file_service.dart';
import '../../../gallery/data/gallery_saver_service.dart';
import '../../data/composite_renderer.dart';
import '../../domain/captured_photo.dart';

enum ReviewVariant { original, composite }

enum SaveOutcome { saved, alreadySaved, busy, permissionDenied }

@immutable
class CaptureReviewState {
  const CaptureReviewState({
    this.variant = ReviewVariant.original,
    this.saving,
    this.originalSaved = false,
    this.compositeSaved = false,
    this.renderingComposite = false,
    this.compositePreview,
    this.compositeError,
  });

  final ReviewVariant variant;

  /// The variant being saved right now, if any.
  final ReviewVariant? saving;
  final bool originalSaved;
  final bool compositeSaved;
  final bool renderingComposite;

  /// The rendered composite, shown on screen and saved as-is.
  final ui.Image? compositePreview;
  final AppException? compositeError;

  bool get isSaving => saving != null;
  bool get anySaved => originalSaved || compositeSaved;

  bool isSaved(ReviewVariant variant) => switch (variant) {
    ReviewVariant.original => originalSaved,
    ReviewVariant.composite => compositeSaved,
  };

  CaptureReviewState copyWith({
    ReviewVariant? variant,
    ValueGetter<ReviewVariant?>? saving,
    bool? originalSaved,
    bool? compositeSaved,
    bool? renderingComposite,
    ValueGetter<ui.Image?>? compositePreview,
    ValueGetter<AppException?>? compositeError,
  }) {
    return CaptureReviewState(
      variant: variant ?? this.variant,
      saving: saving != null ? saving() : this.saving,
      originalSaved: originalSaved ?? this.originalSaved,
      compositeSaved: compositeSaved ?? this.compositeSaved,
      renderingComposite: renderingComposite ?? this.renderingComposite,
      compositePreview: compositePreview != null
          ? compositePreview()
          : this.compositePreview,
      compositeError: compositeError != null
          ? compositeError()
          : this.compositeError,
    );
  }
}

/// Drives the review of one captured photo.
///
/// "Save" writes the camera's original file to the photo library byte for
/// byte. "Save composite" is a separate export rendered from the snapshot
/// taken at capture time. When the review closes, the app's working copies
/// are deleted: a saved photo lives on in the library.
class CaptureReviewController extends Notifier<CaptureReviewState> {
  CaptureReviewController(this.photo);

  final CapturedPhoto photo;

  late CompositeRenderer _renderer;
  late GallerySaverService _gallery;
  late AppErrorHandler _errors;
  late FileService _files;
  Future<ui.Image>? _rendering;
  bool _closed = false;

  /// Mirrors `state.compositePreview`: `state` cannot be read while disposing.
  ui.Image? _composite;

  @override
  CaptureReviewState build() {
    _renderer = ref.read(compositeRendererProvider);
    _gallery = ref.read(gallerySaverServiceProvider);
    _errors = ref.read(appErrorHandlerProvider);
    _files = ref.read(fileServiceProvider);
    ref.onDispose(_cleanUp);
    return const CaptureReviewState();
  }

  void selectVariant(ReviewVariant variant) {
    if (variant == ReviewVariant.composite && !photo.canComposite) return;
    state = state.copyWith(variant: variant);
    if (variant == ReviewVariant.composite) unawaited(_ensureComposite());
  }

  /// Saves the variant on screen.
  ///
  /// [explainPermission] is called before the system permission prompt and
  /// returns whether the user wants to continue. Throws an [AppException]
  /// when saving fails; the state is restored so the user can retry.
  Future<SaveOutcome> save({
    required Future<bool> Function() explainPermission,
  }) async {
    final variant = state.variant;
    if (state.isSaving) return SaveOutcome.busy;
    if (state.isSaved(variant)) return SaveOutcome.alreadySaved;

    state = state.copyWith(saving: () => variant);
    File? temporary;
    try {
      if (!await _ensureAccess(explainPermission)) {
        return SaveOutcome.permissionDenied;
      }

      final String path;
      if (variant == ReviewVariant.original) {
        if (!await File(photo.path).exists()) {
          throw const FileFailure(
            'This photo is no longer available. Please retake it.',
          );
        }
        path = photo.path;
      } else {
        final composite = await _ensureComposite();
        if (composite == null) throw state.compositeError!;
        final bytes = await _renderer.encodeJpeg(composite);
        temporary = await _files.createCaptureFile(prefix: 'Veylora_composite');
        await temporary.writeAsBytes(bytes, flush: true);
        path = temporary.path;
      }

      await _gallery.saveImage(path);
      if (!_closed) {
        state = state.copyWith(
          originalSaved: variant == ReviewVariant.original
              ? true
              : state.originalSaved,
          compositeSaved: variant == ReviewVariant.composite
              ? true
              : state.compositeSaved,
        );
      }
      return SaveOutcome.saved;
    } catch (error, stackTrace) {
      _errors.report(error, stackTrace, operation: 'save ${variant.name}');
      throw _errors.map(error, stackTrace);
    } finally {
      if (!_closed) state = state.copyWith(saving: () => null);
      if (temporary != null) unawaited(_deleteQuietly(temporary.path));
    }
  }

  /// Retake/discard: drop the working copy now rather than at dispose.
  Future<void> discard() => _deleteQuietly(photo.path);

  Future<bool> _ensureAccess(Future<bool> Function() explain) async {
    if (await _gallery.hasAccess()) return true;
    if (!await explain()) return false;
    return _gallery.requestAccess();
  }

  /// Renders the composite once and caches it; concurrent callers share the
  /// same render.
  Future<ui.Image?> _ensureComposite() async {
    final source = photo.composite;
    if (source == null) return null;
    if (state.compositePreview != null) return state.compositePreview;

    final rendering = _rendering ??= _render(source);
    if (!state.renderingComposite) {
      state = state.copyWith(
        renderingComposite: true,
        compositeError: () => null,
      );
    }
    try {
      final image = await rendering;
      if (_closed) return null;
      if (state.compositePreview == null) {
        _composite = image;
        state = state.copyWith(
          compositePreview: () => image,
          renderingComposite: false,
        );
      }
      return state.compositePreview;
    } catch (error, stackTrace) {
      _rendering = null;
      final failure = _errors.map(error, stackTrace);
      _errors.report(error, stackTrace, operation: 'render composite');
      if (!_closed) {
        state = state.copyWith(
          renderingComposite: false,
          compositeError: () => failure,
        );
      }
      return null;
    }
  }

  Future<ui.Image> _render(CompositeSource source) async {
    final bytes = await File(photo.path).readAsBytes();
    final decoded = await _renderer.decodePhoto(bytes);
    try {
      final composed = await _renderer.compose(decoded, source);
      if (_closed) {
        composed.dispose();
        throw StateError('Review closed while rendering.');
      }
      return composed;
    } finally {
      decoded.dispose();
    }
  }

  void _cleanUp() {
    _closed = true;
    _composite?.dispose();
    _composite = null;
    photo.composite?.dispose();
    unawaited(_deleteQuietly(photo.path));
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error, stackTrace) {
      _errors.logger.warning('Could not delete $path.', error, stackTrace);
    }
  }
}

final captureReviewProvider = NotifierProvider.autoDispose
    .family<CaptureReviewController, CaptureReviewState, CapturedPhoto>(
      CaptureReviewController.new,
    );

/// True when a save failed because the photo library permission is missing,
/// so the fix is in system settings.
bool isGalleryAccessDenied(Object error) {
  final cause = error is AppException ? error.cause : error;
  return cause is GalException && cause.type == GalExceptionType.accessDenied;
}
