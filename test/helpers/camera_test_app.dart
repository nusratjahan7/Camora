import 'package:camera_overlay/app/router/app_routes.dart';
import 'package:camera_overlay/core/theme/app_theme.dart';
import 'package:camera_overlay/features/camera/presentation/pages/camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Pumps the camera screen with the real app shell (router + theme).
Future<void> pumpCameraApp(
  WidgetTester tester, {
  required List<Override> overrides,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.camera,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.camera,
        builder: (context, state) => const CameraPage(),
      ),
      // The camera bar links to the gallery; a stub keeps navigation testable
      // without standing up the whole gallery feature.
      GoRoute(
        path: AppRoutes.gallery,
        builder: (context, state) => const Scaffold(
          body: SizedBox(key: ValueKey<String>('test-gallery-route')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    ),
  );
}
