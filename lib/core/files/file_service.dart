import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

base class FileService {
  const FileService();

  Future<Directory> capturesDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, 'captures'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// A new file in the captures directory. The name becomes the photo's name
  /// in the system gallery, e.g. `Veylora_1760512345678.jpg`.
  Future<File> createCaptureFile({
    String prefix = 'Veylora',
    String extension = 'jpg',
  }) async {
    final directory = await capturesDirectory();
    final name =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return File(p.join(directory.path, name));
  }

  Future<void> deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

final fileServiceProvider = Provider<FileService>((ref) => const FileService());
