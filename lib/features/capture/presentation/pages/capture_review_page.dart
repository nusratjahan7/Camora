import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/glass.dart';
import '../../../../shared/widgets/permission_rationale_sheet.dart';
import '../../../gallery/data/gallery_saver_service.dart';
import '../../domain/captured_photo.dart';
import '../providers/capture_review_controller.dart';

/// Review a just-captured photo: Retake, Save (the untouched original), an
/// optional Save composite, or Discard.
class CaptureReviewPage extends ConsumerWidget {
  const CaptureReviewPage({super.key, required this.photo});

  final CapturedPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = captureReviewProvider(photo);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Theme(
        data: AppTheme.dark,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _close(context, ref);
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _PhotoView(photo: photo, state: state),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopBar(
                    photo: photo,
                    state: state,
                    onClose: () => _close(context, ref),
                    onDiscard: () => _discard(context, ref),
                    onVariant: controller.selectVariant,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _BottomBar(
                    state: state,
                    onRetake: () => _retake(context, ref),
                    onSave: () => _save(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  CaptureReviewController _controller(WidgetRef ref) =>
      ref.read(captureReviewProvider(photo).notifier);

  CaptureReviewState _state(WidgetRef ref) =>
      ref.read(captureReviewProvider(photo));

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final variant = _state(ref).variant;
    try {
      final outcome = await _controller(ref).save(
        explainPermission: () => PermissionRationaleSheet.show(
          context,
          permission: AppPermission.photosAddOnly,
        ),
      );
      if (outcome == SaveOutcome.saved) {
        HapticFeedback.mediumImpact();
        _show(
          messenger,
          variant == ReviewVariant.composite
              ? 'Composite saved to ${GallerySaverService.libraryName}'
              : 'Saved to ${GallerySaverService.libraryName}',
          action: SnackBarAction(
            label: 'View',
            onPressed: () =>
                ref.read(gallerySaverServiceProvider).openGallery(),
          ),
        );
      } else if (outcome == SaveOutcome.permissionDenied) {
        _show(
          messenger,
          '${AppConstants.appName} needs permission to save to your '
          '${GallerySaverService.libraryName.toLowerCase()}.',
          action: _settingsAction(ref),
        );
      }
    } on AppException catch (failure) {
      _show(
        messenger,
        failure.message,
        action: isGalleryAccessDenied(failure) ? _settingsAction(ref) : null,
      );
    }
  }

  SnackBarAction _settingsAction(WidgetRef ref) => SnackBarAction(
    label: 'Settings',
    onPressed: () => ref.read(permissionServiceProvider).openSettings(),
  );

  void _show(
    ScaffoldMessengerState messenger,
    String message, {
    SnackBarAction? action,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _retake(BuildContext context, WidgetRef ref) async {
    if (_state(ref).isSaving) return;
    await _controller(ref).discard();
    if (context.mounted) _leave(context);
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    if (_state(ref).isSaving) return;
    if (!await _confirmDiscard(context)) return;
    await _controller(ref).discard();
    if (context.mounted) _leave(context);
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final state = _state(ref);
    if (state.isSaving) return;
    if (!state.anySaved && !await _confirmDiscard(context)) return;
    if (context.mounted) _leave(context);
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.camera);
    }
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: AppTheme.dark,
        child: AlertDialog(
          title: const Text('Discard this photo?'),
          content: const Text('It has not been saved and will be deleted.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              key: const ValueKey<String>('review-confirm-discard'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }
}

class _PhotoView extends StatelessWidget {
  const _PhotoView({required this.photo, required this.state});

  final CapturedPhoto photo;
  final CaptureReviewState state;

  @override
  Widget build(BuildContext context) {
    final showComposite = state.variant == ReviewVariant.composite;
    final media = MediaQuery.of(context);
    // Decode the on-screen preview near screen resolution; the saved file is
    // never touched.
    final cacheWidth = (media.size.longestSide * media.devicePixelRatio)
        .round();

    final Widget content;
    if (!showComposite) {
      content = Image.file(
        File(photo.path),
        key: const ValueKey<String>('review-original'),
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const _Message(
          icon: Icons.broken_image_outlined,
          text: 'This photo is no longer available.',
        ),
      );
    } else if (state.compositePreview case final composite?) {
      content = RawImage(
        key: const ValueKey<String>('review-composite'),
        image: composite,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    } else if (state.compositeError case final error?) {
      content = _Message(icon: Icons.error_outline, text: error.message);
    } else {
      content = const _Message(text: 'Preparing composite…', busy: true);
    }

    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: AnimatedSwitcher(
          duration: AppConstants.standardAnimation,
          child: content,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.icon, this.busy = false});

  final String text;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final onScrim = context.cameraTheme.onScrim;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (busy)
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: onScrim),
          )
        else if (icon != null)
          Icon(icon, size: 36, color: onScrim),
        const SizedBox(height: AppSpacing.md),
        Text(
          text,
          textAlign: TextAlign.center,
          style: context.textStyles.bodyMedium?.copyWith(color: onScrim),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.photo,
    required this.state,
    required this.onClose,
    required this.onDiscard,
    required this.onVariant,
  });

  final CapturedPhoto photo;
  final CaptureReviewState state;
  final VoidCallback onClose;
  final VoidCallback onDiscard;
  final ValueChanged<ReviewVariant> onVariant;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
      ),
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
              GlassIconButton(
                key: const ValueKey<String>('review-close'),
                icon: Icons.close_rounded,
                tooltip: state.anySaved ? 'Done' : 'Close review',
                onPressed: state.isSaving ? null : onClose,
              ),
              Expanded(
                child: Center(
                  child: photo.canComposite
                      ? GlassSurface(
                          padding: const EdgeInsets.all(3),
                          borderRadius: BorderRadius.circular(22),
                          child: GlassSegmentedControl<ReviewVariant>(
                            selected: state.variant,
                            onSelected: state.isSaving ? (_) {} : onVariant,
                            segments: const <GlassSegment<ReviewVariant>>[
                              GlassSegment<ReviewVariant>(
                                key: ValueKey<String>('review-original-tab'),
                                value: ReviewVariant.original,
                                label: 'Original',
                              ),
                              GlassSegment<ReviewVariant>(
                                key: ValueKey<String>('review-composite-tab'),
                                value: ReviewVariant.composite,
                                label: 'Composite',
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              if (!state.anySaved)
                GlassIconButton(
                  key: const ValueKey<String>('review-discard'),
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Discard photo',
                  onPressed: state.isSaving ? null : onDiscard,
                )
              else
                const SizedBox.square(dimension: AppConstants.minTapTarget),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onRetake,
    required this.onSave,
  });

  final CaptureReviewState state;
  final VoidCallback onRetake;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              _PillButton(
                key: const ValueKey<String>('review-retake'),
                icon: Icons.replay_rounded,
                label: 'Retake',
                onPressed: state.isSaving ? null : onRetake,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SaveButton(state: state, onSave: onSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.state, required this.onSave});

  final CaptureReviewState state;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final variant = state.variant;
    final composite = variant == ReviewVariant.composite;
    final saving = state.saving == variant;
    final saved = state.isSaved(variant);
    final preparing =
        composite &&
        state.compositePreview == null &&
        state.compositeError == null;

    final (IconData icon, String label) = saving
        ? (Icons.hourglass_top_rounded, 'Saving…')
        : saved
        ? (Icons.check_rounded, 'Saved')
        : preparing
        ? (Icons.hourglass_top_rounded, 'Preparing…')
        : composite
        ? (Icons.layers_rounded, 'Save composite')
        : (Icons.download_rounded, 'Save photo');

    final enabled = !state.isSaving && !saved && !preparing;
    return _PillButton(
      key: const ValueKey<String>('review-save'),
      icon: icon,
      label: label,
      primary: true,
      busy: saving,
      onPressed: enabled ? onSave : null,
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.primary = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = context.cameraTheme;
    final enabled = onPressed != null;
    final foreground = primary ? Colors.black : theme.onScrim;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else
          Icon(icon, size: 20, color: foreground),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: context.textStyles.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    final face = SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Center(child: content),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        child: AnimatedOpacity(
          duration: AppConstants.fastAnimation,
          opacity: enabled || busy ? 1 : 0.55,
          child: primary
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(27),
                  ),
                  child: face,
                )
              : GlassSurface(
                  borderRadius: BorderRadius.circular(27),
                  child: face,
                ),
        ),
      ),
    );
  }
}
