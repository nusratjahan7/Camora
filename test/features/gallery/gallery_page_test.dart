import 'package:camera_overlay/app/router/app_routes.dart';
import 'package:camera_overlay/core/files/file_service.dart';
import 'package:camera_overlay/core/storage/shared_preferences_store.dart';
import 'package:camera_overlay/core/theme/app_theme.dart';
import 'package:camera_overlay/features/gallery/domain/gallery_entry.dart';
import 'package:camera_overlay/features/gallery/presentation/pages/gallery_page.dart';
import 'package:camera_overlay/features/gallery/presentation/pages/gallery_preview_page.dart';
import 'package:camera_overlay/features/gallery/presentation/providers/gallery_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_file_service.dart';
import '../../helpers/fake_key_value_store.dart';

void main() {
  late FakeKeyValueStore store;
  late FakeFileService files;
  late ProviderContainer container;

  setUp(() {
    store = FakeKeyValueStore();
    files = FakeFileService();
    container = ProviderContainer.test(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        fileServiceProvider.overrideWithValue(files),
      ],
    );
  });

  /// Records a photo whose file the fake reports as present or not.
  Future<GalleryEntry> recordPhoto(String path, {bool onDisk = true}) async {
    if (onDisk) files.present.add(path);

    await container.read(galleryHistoryProvider.future);
    await container
        .read(galleryHistoryProvider.notifier)
        .record(path: path, kind: GalleryEntryKind.photo);

    return container.read(galleryHistoryProvider).value!.entries.single;
  }

  /// Bounded pumps: these screens animate, so `pumpAndSettle` never returns.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpGallery(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.gallery,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.gallery,
          builder: (context, state) => const GalleryPage(),
        ),
        GoRoute(
          path: AppRoutes.galleryPreview,
          redirect: (context, state) =>
              state.extra is GalleryEntry ? null : AppRoutes.gallery,
          builder: (context, state) =>
              GalleryPreviewPage(entry: state.extra! as GalleryEntry),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await settle(tester);
  }

  testWidgets('empty tabs explain themselves', (tester) async {
    await pumpGallery(tester);

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('No photos yet'), findsOneWidget);

    await tester.tap(find.text('References'));
    await settle(tester);

    expect(find.text('No reference images yet'), findsOneWidget);
  });

  testWidgets('a reference tab shows its own entries', (tester) async {
    await container.read(galleryHistoryProvider.future);
    await container
        .read(galleryHistoryProvider.notifier)
        .record(path: 'reference_1.png', kind: GalleryEntryKind.reference);

    await pumpGallery(tester);
    expect(find.text('No photos yet'), findsOneWidget);

    await tester.tap(find.text('References'));
    await settle(tester);

    expect(find.text('No reference images yet'), findsNothing);
  });

  testWidgets('a clip lists under the Videos tab with a play glyph', (
    tester,
  ) async {
    files.present.add('Veylora_1.mp4');
    await container.read(galleryHistoryProvider.future);
    await container
        .read(galleryHistoryProvider.notifier)
        .record(path: 'Veylora_1.mp4', kind: GalleryEntryKind.video);

    await pumpGallery(tester);
    // The clip is not among the photos.
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);

    await tester.tap(find.text('Videos'));
    await settle(tester);

    expect(find.text('No videos yet'), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
  });

  testWidgets('opening a clip explains it when it cannot be played', (
    tester,
  ) async {
    files.present.add('Veylora_2.mp4');
    await container.read(galleryHistoryProvider.future);
    await container
        .read(galleryHistoryProvider.notifier)
        .record(path: 'Veylora_2.mp4', kind: GalleryEntryKind.video);

    await pumpGallery(tester);
    await tester.tap(find.text('Videos'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await settle(tester);

    // Playback is the platform player's job and there is none in a widget
    // test, so the screen says so instead of failing silently. The actions a
    // clip does support are still there.
    expect(find.textContaining('could not be played'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('gallery-share')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('gallery-delete')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('gallery-use-reference')),
      findsNothing,
    );
  });

  testWidgets('an entry whose file is gone is flagged and can be removed', (
    tester,
  ) async {
    final entry = await recordPhoto('Veylora_1.jpg');
    // Removed outside the app: the row stays, the file is gone.
    files.present.remove(entry.path);
    await container.read(galleryHistoryProvider.notifier).refresh();

    await pumpGallery(tester);
    expect(find.text('Missing'), findsOneWidget);

    // The preview explains the missing file instead of trying to draw it.
    await tester.tap(find.byKey(ValueKey<String>('gallery-tile-${entry.id}')));
    await settle(tester);
    expect(find.text('This file is no longer on the device.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('gallery-delete')));
    await settle(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('gallery-confirm-delete')),
    );
    await settle(tester);

    expect(find.text('No photos yet'), findsOneWidget);
    expect(container.read(galleryHistoryProvider).value!.entries, isEmpty);
  });
}
