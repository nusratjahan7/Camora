import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/shared_preferences_store.dart';
import '../domain/gallery_entry.dart';

/// Persists the local gallery history as a JSON list of [GalleryEntry]s.
///
/// Only paths and lightweight metadata are stored; the images themselves stay
/// on disk in the app's documents directory.
class GalleryHistoryRepository {
  GalleryHistoryRepository({required this.store, required this.errorHandler});

  final KeyValueStore store;
  final AppErrorHandler errorHandler;

  Future<List<GalleryEntry>> load() => errorHandler.guard(() async {
    final raw = await store.getString(StorageKeys.galleryHistory);
    if (raw == null || raw.isEmpty) return const <GalleryEntry>[];

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error, stackTrace) {
      // Stored data we cannot read is treated as an empty history rather than
      // failing the screen; the next save overwrites it.
      errorHandler.logger.warning(
        'The gallery history could not be read.',
        error,
        stackTrace,
      );
      return const <GalleryEntry>[];
    }

    if (decoded is! List) return const <GalleryEntry>[];

    return decoded
        .map(GalleryEntry.fromJson)
        .whereType<GalleryEntry>()
        .toList(growable: false);
  }, operation: 'load gallery history');

  Future<void> save(List<GalleryEntry> entries) => errorHandler.guard(
    () => store.setString(
      StorageKeys.galleryHistory,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    ),
    operation: 'save gallery history',
  );
}

final galleryHistoryRepositoryProvider = Provider<GalleryHistoryRepository>(
  (ref) => GalleryHistoryRepository(
    store: ref.watch(keyValueStoreProvider),
    errorHandler: ref.watch(appErrorHandlerProvider),
  ),
);
