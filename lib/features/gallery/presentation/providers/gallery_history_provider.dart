import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/files/file_service.dart';
import '../../data/gallery_history_repository.dart';
import '../../domain/gallery_entry.dart';

/// The local history, plus which of its files are no longer on disk.
@immutable
class GalleryHistory {
  const GalleryHistory({required this.entries, required this.missingIds});

  static const GalleryHistory empty = GalleryHistory(
    entries: <GalleryEntry>[],
    missingIds: <String>{},
  );

  /// Newest first.
  final List<GalleryEntry> entries;

  /// Ids of entries whose file has been removed outside the app.
  final Set<String> missingIds;

  List<GalleryEntry> of(GalleryEntryKind kind) =>
      entries.where((entry) => entry.kind == kind).toList(growable: false);

  bool isMissing(GalleryEntry entry) => missingIds.contains(entry.id);
}

/// Owns the local gallery history: the photos the app captured and the
/// reference images it has used.
///
/// Nothing here talks to a network — the entries are paths to files in the
/// app's own documents directory.
class GalleryHistoryController extends AsyncNotifier<GalleryHistory> {
  late GalleryHistoryRepository _repository;
  late FileService _files;
  late AppErrorHandler _errors;

  @override
  Future<GalleryHistory> build() async {
    _repository = ref.read(galleryHistoryRepositoryProvider);
    _files = ref.read(fileServiceProvider);
    _errors = ref.read(appErrorHandlerProvider);
    return _load();
  }

  /// Adds an entry for a file the app already owns and keeps.
  ///
  /// Callers may fire this and forget it, so it does nothing once the screen
  /// that asked for it has gone.
  Future<void> record({
    required String path,
    required GalleryEntryKind kind,
    DateTime? createdAt,
    String? name,
    PhotoExport export = PhotoExport.original,
  }) async {
    if (!ref.mounted) return;

    final history = await _current();
    final entry = GalleryEntry(
      id: '${kind.name}_${DateTime.now().microsecondsSinceEpoch}',
      path: path,
      kind: kind,
      createdAt: createdAt ?? DateTime.now(),
      name: name,
      export: export,
    );

    final entries = <GalleryEntry>[entry, ...history.entries];
    await _repository.save(entries);
    if (!ref.mounted) return;

    state = AsyncData<GalleryHistory>(
      GalleryHistory(entries: entries, missingIds: history.missingIds),
    );
  }

  /// Forgets an entry and deletes the app's copy of the file.
  Future<void> remove(GalleryEntry entry) async {
    final history = await _current();
    final entries = history.entries
        .where((candidate) => candidate.id != entry.id)
        .toList(growable: false);

    await _repository.save(entries);

    try {
      await _files.deleteIfPresent(entry.path);
    } catch (error, stackTrace) {
      // The row is already gone; a file we cannot delete is worth logging but
      // not worth failing the delete for.
      _errors.report(error, stackTrace, operation: 'delete history file');
    }

    state = AsyncData<GalleryHistory>(
      GalleryHistory(
        entries: entries,
        missingIds: <String>{...history.missingIds}..remove(entry.id),
      ),
    );
  }

  /// Re-checks which files are still on disk.
  Future<void> refresh() async {
    state = AsyncData<GalleryHistory>(await _load());
  }

  Future<GalleryHistory> _load() async {
    final entries = List<GalleryEntry>.of(await _repository.load())
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final missing = <String>{};
    for (final entry in entries) {
      if (!await _files.exists(entry.path)) missing.add(entry.id);
    }

    return GalleryHistory(entries: entries, missingIds: missing);
  }

  Future<GalleryHistory> _current() async => state.value ?? await future;
}

final galleryHistoryProvider =
    AsyncNotifierProvider<GalleryHistoryController, GalleryHistory>(
      GalleryHistoryController.new,
    );
