import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/gallery_entry.dart';
import '../providers/gallery_history_provider.dart';
import '../widgets/gallery_tile.dart';

/// Local history: the photos this app captured, and the reference images it
/// has used. Everything lives on the device.
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(galleryHistoryProvider);
    final errorHandler = ref.read(appErrorHandlerProvider);

    return AppScaffold(
      padded: false,
      title: 'Gallery',
      leading: AppIconButton(
        icon: Icons.arrow_back,
        tooltip: 'Back',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.home),
      ),
      body: Column(
        children: <Widget>[
          TabBar(
            controller: _tabs,
            tabs: const <Widget>[
              Tab(text: 'Photos'),
              Tab(text: 'Videos'),
              Tab(text: 'References'),
            ],
          ),
          Expanded(
            child: switch (history) {
              AsyncValue(hasError: true, :final error?, :final stackTrace) =>
                ErrorView(
                  exception: errorHandler.map(
                    error,
                    stackTrace ?? StackTrace.empty,
                  ),
                  onRetry: () => ref.invalidate(galleryHistoryProvider),
                ),
              AsyncValue(value: final value?) => TabBarView(
                controller: _tabs,
                children: <Widget>[
                  _EntryGrid(kind: GalleryEntryKind.photo, history: value),
                  _EntryGrid(kind: GalleryEntryKind.video, history: value),
                  _EntryGrid(kind: GalleryEntryKind.reference, history: value),
                ],
              ),
              _ => const LoadingView(message: 'Loading your gallery…'),
            },
          ),
        ],
      ),
    );
  }
}

class _EntryGrid extends ConsumerWidget {
  const _EntryGrid({required this.kind, required this.history});

  final GalleryEntryKind kind;
  final GalleryHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = history.of(kind);
    if (entries.isEmpty) return _EmptyState(kind: kind);

    return RefreshIndicator(
      onRefresh: () => ref.read(galleryHistoryProvider.notifier).refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
        itemCount: entries.length,
        itemBuilder: (context, index) => GalleryTile(
          entry: entries[index],
          missing: history.isMissing(entries[index]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.kind});

  final GalleryEntryKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final (icon, title, body) = switch (kind) {
      GalleryEntryKind.photo => (
        Icons.photo_camera_outlined,
        'No photos yet',
        'Photos you capture are kept here, on this device.',
      ),
      GalleryEntryKind.video => (
        Icons.videocam_outlined,
        'No videos yet',
        'Clips you film are kept here, on this device.',
      ),
      GalleryEntryKind.reference => (
        Icons.collections_outlined,
        'No reference images yet',
        'Images you float over the preview are kept here so you '
            'can pick them again.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: context.textStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
