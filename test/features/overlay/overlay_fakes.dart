import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera_overlay/core/errors/app_error_handler.dart';
import 'package:camera_overlay/core/logging/app_logger.dart';
import 'package:camera_overlay/features/gallery/data/image_picker_service.dart';
import 'package:camera_overlay/features/settings/domain/app_settings.dart';
import 'package:camera_overlay/features/settings/presentation/providers/settings_controller.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Encodes a solid-color PNG of the given size.
Future<Uint8List> pngBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366FF),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Returns queued results in order: an [XFile], null (cancelled) or an
/// [Exception] to throw.
class FakeImagePickerService extends ImagePickerService {
  FakeImagePickerService()
    : super(errorHandler: const AppErrorHandler(logger: AppLogger()));

  final List<Object?> results = <Object?>[];
  int calls = 0;

  /// When set, a pick waits for it, like the user browsing the gallery.
  Completer<void>? gate;

  void queueImage(Uint8List bytes, {String name = 'reference.png'}) => results
      .add(XFile.fromData(bytes, name: name, path: p.join('picked', name)));

  void queueCancel() => results.add(null);

  @override
  Future<XFile?> pickFromGallery() async {
    calls++;
    await gate?.future;
    final next = results.isEmpty ? null : results.removeAt(0);
    if (next is Exception) throw next;
    return next as XFile?;
  }
}

class FakeSettingsController extends SettingsController {
  FakeSettingsController([this.settings = AppSettings.defaults]);

  final AppSettings settings;

  @override
  Future<AppSettings> build() async => settings;
}

final PlatformException pickerUnavailable = PlatformException(
  code: 'no_activity',
  message: 'No gallery app.',
);
