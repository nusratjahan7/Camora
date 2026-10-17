import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../domain/gallery_entry.dart';

/// One history entry drawn as a thumbnail.
///
/// The image is decoded at thumbnail size, so a 12 MP file never lands in
/// memory just to draw a small square.
class GalleryTile extends StatelessWidget {
  const GalleryTile({super.key, required this.entry, required this.missing});

  final GalleryEntry entry;

  /// True when the file behind this entry has been removed.
  final bool missing;

  /// Thumbnail edge in logical pixels.
  static const double _edge = 120;

  String get _semanticLabel {
    final what = switch (entry.kind) {
      GalleryEntryKind.photo => entry.isComposite
          ? 'Composite photo'
          : 'Photo',
      GalleryEntryKind.reference => 'Reference image',
    };
    return missing ? '$what, ${entry.label}, file missing' : '$what, ${entry.label}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey<String>('gallery-tile-${entry.id}'),
        onTap: () => context.push<void>(AppRoutes.galleryPreview, extra: entry),
        borderRadius: AppRadius.smAll,
        child: ClipRRect(
          borderRadius: AppRadius.smAll,
          child: ColoredBox(
            color: context.colors.surfaceContainerHigh,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _Thumbnail(entry: entry, missing: missing),
                if (entry.isComposite)
                  const Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: _Badge(label: 'Composite'),
                  ),
                if (missing)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _MissingStrip(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.entry, required this.missing});

  final GalleryEntry entry;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    if (missing) return const _BrokenImage();

    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.file(
      File(entry.path),
      key: ValueKey<String>('gallery-thumb-${entry.id}'),
      fit: BoxFit.cover,
      cacheWidth: (GalleryTile._edge * dpr).round(),
      errorBuilder: (context, error, stackTrace) => const _BrokenImage(),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.image_not_supported_outlined,
      size: 28,
      color: context.colors.onSurface.withValues(alpha: 0.45),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.inverseSurface.withValues(alpha: 0.82),
        borderRadius: AppRadius.smAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          label,
          style: context.textStyles.labelSmall?.copyWith(
            color: context.colors.onInverseSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MissingStrip extends StatelessWidget {
  const _MissingStrip();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.errorContainer.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          'Missing',
          textAlign: TextAlign.center,
          style: context.textStyles.labelSmall?.copyWith(
            color: context.colors.onErrorContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
