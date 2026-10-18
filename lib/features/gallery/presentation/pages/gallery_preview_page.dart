import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

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
/// it: share and delete for a photo or a clip, plus "use again" for a
/// reference.
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
          switch (entry.kind) {
            GalleryEntryKind.photo =>
              'This removes the app\'s copy. Photos already saved to your '
                  'device library are not affected.',
            GalleryEntryKind.video =>
              'This removes the app\'s copy. Clips already saved to your '
                  'device library are not affected.',
            GalleryEntryKind.reference =>
              'This removes the reference image from this device.',
          },
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
      return const _Message(
        icon: Icons.broken_image_outlined,
        text: 'This file is no longer on the device.',
      );
    }

    if (entry.kind == GalleryEntryKind.video) {
      return _VideoPreview(path: entry.path);
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

/// Plays a clip with a minimal transport: tap the frame to play or pause.
///
/// Playback is the platform player's job, so a clip keeps the orientation and
/// synchronised audio it was recorded with. A clip the device cannot play
/// explains itself instead of failing silently.
class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.path});

  final String path;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.file(File(widget.path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
    } catch (_) {
      // Playback is the platform player's job. When it cannot start, say so
      // rather than spinning forever. Disposal is not awaited: a controller
      // that never finished initialising never finishes disposing either.
      controller.dispose().catchError((Object _) {});
      if (mounted) setState(() => _failed = true);
      return;
    }

    if (!mounted) {
      controller.dispose().catchError((Object _) {});
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle(VideoPlayerValue value) async {
    final controller = _controller;
    if (controller == null) return;
    if (value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const _Message(
        icon: Icons.videocam_off_outlined,
        text: 'This clip could not be played on this device.',
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: GestureDetector(
        key: const ValueKey<String>('gallery-preview-video'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggle(controller.value),
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, child) => AspectRatio(
            aspectRatio: value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                VideoPlayer(controller),
                if (!value.isPlaying)
                  const Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: Colors.white70,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final onScrim = context.cameraTheme.onScrim;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: onScrim),
            const SizedBox(height: AppSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.copyWith(color: onScrim),
            ),
          ],
        ),
      ),
    );
  }
}
