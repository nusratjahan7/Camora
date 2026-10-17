import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../overlay/presentation/providers/overlay_image_provider.dart';
import '../../data/share_service.dart';
import '../../domain/gallery_entry.dart';
import '../providers/gallery_history_provider.dart';

/// Full-screen look at one history entry, with the actions that make sense for
/// it: share and delete for a photo, plus "use again" for a reference.
class GalleryPreviewPage extends ConsumerWidget {
  const GalleryPreviewPage({super.key, required this.entry});

  final GalleryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing =
        ref.watch(galleryHistoryProvider).value?.isMissing(entry) ?? false;
    final isReference = entry.kind == GalleryEntryKind.reference;

    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(entry.label, overflow: TextOverflow.ellipsis),
          leading: AppIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          actions: <Widget>[
            if (!missing)
              AppIconButton(
                key: const ValueKey<String>('gallery-share'),
                icon: Icons.ios_share,
                tooltip: 'Share',
                onPressed: () => _share(context, ref),
              ),
            AppIconButton(
              key: const ValueKey<String>('gallery-delete'),
              icon: Icons.delete_outline,
              tooltip: 'Delete from gallery',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
        body: _Preview(entry: entry, missing: missing),
        bottomNavigationBar: isReference && !missing
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AppButton(
                    key: const ValueKey<String>('gallery-use-reference'),
                    label: 'Use as reference',
                    icon: Icons.layers_outlined,
                    onPressed: () => _useAsReference(context, ref),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    // iPad anchors the sheet to the button that opened it.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await ref
          .read(shareServiceProvider)
          .shareFile(entry.path, origin: origin);
    } on AppException catch (failure) {
      if (context.mounted) _notify(context, failure.message);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from gallery?'),
        content: Text(
          entry.kind == GalleryEntryKind.photo
              ? 'This removes the app\'s copy. Photos already saved to your '
                    'device library are not affected.'
              : 'This removes the reference image from this device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const ValueKey<String>('gallery-confirm-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(galleryHistoryProvider.notifier).remove(entry);
    } on AppException catch (failure) {
      if (context.mounted) _notify(context, failure.message);
      return;
    }
    if (context.mounted) context.pop();
  }

  Future<void> _useAsReference(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(overlayImageProvider.notifier)
          .useStoredReference(entry.path, name: entry.label);
    } on AppException catch (failure) {
      if (context.mounted) _notify(context, failure.message);
      return;
    }
    if (context.mounted) context.go(AppRoutes.camera);
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.entry, required this.missing});

  final GalleryEntry entry;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    if (missing) {
      final onScrim = context.cameraTheme.onScrim;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.broken_image_outlined, size: 40, color: onScrim),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This file is no longer on the device.',
                textAlign: TextAlign.center,
                style: context.textStyles.bodyMedium?.copyWith(color: onScrim),
              ),
            ],
          ),
        ),
      );
    }

    final media = MediaQuery.of(context);
    // Decode for the screen, never the full sensor size.
    final cacheWidth = (media.size.longestSide * media.devicePixelRatio)
        .round();

    return InteractiveViewer(
      maxScale: 6,
      child: Center(
        child: Image.file(
          File(entry.path),
          key: const ValueKey<String>('gallery-preview-image'),
          fit: BoxFit.contain,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
