import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exception.dart';
import '../../features/camera/presentation/pages/camera_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../shared/widgets/error_view.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final errorHandler = ref.watch(appErrorHandlerProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: kDebugMode,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.camera,
        name: AppRoutes.cameraName,
        builder: (context, state) => const CameraPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    // go_router accepts only one of onException / errorBuilder, so the
    // failure is reported from the builder.
    errorBuilder: (context, state) {
      final failure = RouteFailure('No screen matches "${state.uri}".');
      errorHandler.report(failure, StackTrace.current, operation: 'navigate');
      return Scaffold(
        body: SafeArea(child: ErrorView(exception: failure)),
      );
    },
  );
});
