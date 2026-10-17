import 'dart:convert';
import 'dart:io';

import 'package:camera_overlay/core/constants/storage_keys.dart';
import 'package:camera_overlay/core/files/file_service.dart';
import 'package:camera_overlay/core/storage/shared_preferences_store.dart';
import 'package:camera_overlay/features/gallery/domain/gallery_entry.dart';
import 'package:camera_overlay/features/gallery/presentation/providers/gallery_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fake_key_value_store.dart';
import '../camera/fakes/fake_camera_platform.dart' show TempFileService;

void main() {
  late Directory temp;
  late FakeKeyValueStore store;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      fileServiceProvider.overrideWithValue(TempFileService(temp)),
    ],
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('gallery_test');
    store = FakeKeyValueStore();
    container = makeContainer();
  });

  tearDown(() async {
    container.dispose();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<File> aFile(String name) async {
    final file = File(p.join(temp.path, name));
    await file.writeAsBytes(const <int>[1, 2, 3]);
    return file;
  }

  GalleryHistory history() => container.read(galleryHistoryProvider).value!;

  GalleryHistoryController controller() =>
      container.read(galleryHistoryProvider.notifier);

  group('metadata storage', () {
    test('records a photo with its kind and time', () async {
      final file = await aFile('Veylora_1.jpg');
      await container.read(galleryHistoryProvider.future);
      final at = DateTime(2026, 1, 2, 3, 4, 5);

      await controller().record(
        path: file.path,
        kind: GalleryEntryKind.photo,
        createdAt: at,
      );

      expect(history().entries, hasLength(1));
      final entry = history().entries.single;
      expect(entry.kind, GalleryEntryKind.photo);
      expect(entry.export, PhotoExport.original);
      expect(entry.path, file.path);
      expect(entry.createdAt, at);
      expect(history().isMissing(entry), isFalse);
    });

    test('a composite export is stored apart from an original', () async {
      final original = await aFile('Veylora_2.jpg');
      final composite = await aFile('Veylora_2_composite.jpg');
      await container.read(galleryHistoryProvider.future);

      await controller().record(
        path: original.path,
        kind: GalleryEntryKind.photo,
      );
      await controller().record(
        path: composite.path,
        kind: GalleryEntryKind.photo,
        export: PhotoExport.composite,
      );

      final entries = history().entries;
      expect(entries.singleWhere((e) => e.export == PhotoExport.original)
          .isComposite, isFalse);
      expect(entries.singleWhere((e) => e.export == PhotoExport.composite)
          .isComposite, isTrue);
    });

    test('history survives a restart of the app', () async {
      final file = await aFile('Veylora_3.jpg');
      await container.read(galleryHistoryProvider.future);
      await controller().record(
        path: file.path,
        kind: GalleryEntryKind.reference,
        name: 'Holiday.jpg',
      );

      // A fresh container over the same store is a cold start.
      final restarted = makeContainer();
      addTearDown(restarted.dispose);
      final loaded = await restarted.read(galleryHistoryProvider.future);

      expect(loaded.entries, hasLength(1));
      expect(loaded.entries.single.path, file.path);
      expect(loaded.entries.single.name, 'Holiday.jpg');
      expect(loaded.entries.single.kind, GalleryEntryKind.reference);
    });

    test('newest first, and the two tabs stay apart', () async {
      final older = await aFile('old.jpg');
      final newer = await aFile('new.jpg');
      await container.read(galleryHistoryProvider.future);

      await controller().record(
        path: older.path,
        kind: GalleryEntryKind.photo,
        createdAt: DateTime(2026, 1, 1),
      );
      await controller().record(
        path: newer.path,
        kind: GalleryEntryKind.reference,
        createdAt: DateTime(2026, 2, 1),
      );

      expect(
        history().entries.map((entry) => entry.path).toList(),
        <String>[newer.path, older.path],
      );
      expect(history().of(GalleryEntryKind.photo).single.path, older.path);
      expect(history().of(GalleryEntryKind.reference).single.path, newer.path);
    });

    test('only paths and light metadata reach storage', () async {
      final file = await aFile('Veylora_4.jpg');
      await container.read(galleryHistoryProvider.future);
      await controller().record(
        path: file.path,
        kind: GalleryEntryKind.photo,
      );

      final raw = await store.getString(StorageKeys.galleryHistory);

      expect(raw, isNotNull);
      expect(raw, contains('Veylora_4.jpg'));
      // A path and a timestamp, not image data.
      expect(raw!.length, lessThan(400));
    });

    test('unreadable stored data is treated as an empty history', () async {
      await store.setString(StorageKeys.galleryHistory, 'not json');

      final loaded = await container.read(galleryHistoryProvider.future);

      expect(loaded.entries, isEmpty);
    });

    test('a corrupt row is skipped without losing the others', () async {
      final file = await aFile('Veylora_5.jpg');
      await store.setString(
        StorageKeys.galleryHistory,
        jsonEncode(<Object?>[
          <String, Object?>{
            'id': 'good',
            'path': file.path,
            'kind': 'photo',
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
          <String, Object?>{'id': null, 'path': 42},
          'nonsense',
        ]),
      );

      final loaded = await container.read(galleryHistoryProvider.future);

      expect(loaded.entries, hasLength(1));
      expect(loaded.entries.single.id, 'good');
    });
  });

  group('deleted files', () {
    test('an entry whose file was removed outside the app is flagged', () async {
      final file = await aFile('Veylora_6.jpg');
      await container.read(galleryHistoryProvider.future);
      await controller().record(
        path: file.path,
        kind: GalleryEntryKind.photo,
      );

      await file.delete();
      await controller().refresh();

      final entry = history().entries.single;
      expect(history().isMissing(entry), isTrue);
    });

    test('deleting an entry forgets it and removes the app copy', () async {
      final file = await aFile('Veylora_7.jpg');
      await container.read(galleryHistoryProvider.future);
      await controller().record(
        path: file.path,
        kind: GalleryEntryKind.photo,
      );

      await controller().remove(history().entries.single);

      expect(file.existsSync(), isFalse);
      expect(history().entries, isEmpty);
      expect(history().missingIds, isEmpty);
    });

    test('deleting an entry whose file is already gone still works', () async {
      final file = await aFile('Veylora_8.jpg');
      await container.read(galleryHistoryProvider.future);
      await controller().record(
        path: file.path,
        kind: GalleryEntryKind.photo,
      );
      await file.delete();

      await expectLater(
        controller().remove(history().entries.single),
        completes,
      );

      expect(history().entries, isEmpty);
    });

    test('an empty history is empty rather than an error', () async {
      final loaded = await container.read(galleryHistoryProvider.future);

      expect(loaded.entries, isEmpty);
      expect(loaded.missingIds, isEmpty);
      expect(loaded.of(GalleryEntryKind.photo), isEmpty);
      expect(loaded.of(GalleryEntryKind.reference), isEmpty);
    });
  });
}
