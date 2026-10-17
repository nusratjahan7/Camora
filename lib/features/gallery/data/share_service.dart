import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_error_handler.dart';

/// Opens the system share sheet for a file the app owns.
class ShareService {
  const ShareService({required this.errorHandler});

  final AppErrorHandler errorHandler;

  /// [origin] is the rectangle the sheet points at, in global coordinates.
  /// iPad and macOS need it; other platforms ignore it.
  Future<void> shareFile(String path, {Rect? origin}) =>
      errorHandler.guard(() async {
        await SharePlus.instance.share(
          ShareParams(
            files: <XFile>[XFile(path)],
            sharePositionOrigin: origin,
          ),
        );
      }, operation: 'share file');
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => ShareService(errorHandler: ref.watch(appErrorHandlerProvider)),
);
