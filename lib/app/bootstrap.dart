import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import 'app.dart';

void bootstrap() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      const logger = AppLogger();

      FlutterError.onError = (details) {
        logger.error(
          'Flutter framework error',
          details.exception,
          details.stack,
        );
        if (kDebugMode) {
          FlutterError.presentError(details);
        }
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        logger.error('Uncaught platform error', error, stackTrace);
        return true;
      };

      runApp(const ProviderScope(child: CameraOverlayApp()));
    },
    (error, stackTrace) =>
        const AppLogger().error('Uncaught zone error', error, stackTrace),
  );
}
