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

  /// Where the app keeps its own copy of every reference image it has used,
  /// so a guide can be picked again without reopening the system gallery.
  Future<Directory> referencesDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, 'references'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// A new file in the references directory, for the app's own copy of a
  /// reference image.
  Future<File> createReferenceFile({required String extension}) async {
    final directory = await referencesDirectory();
    final name =
        'reference_${DateTime.now().millisecondsSinceEpoch}.$extension';
    return File(p.join(directory.path, name));
  }

  Future<bool> exists(String path) => File(path).exists();

  /// Deletes [path] if it is there. A file that is already gone is not an
  /// error: history outlives the files it points at.
  Future<void> deleteIfPresent(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

final fileServiceProvider = Provider<FileService>((ref) => const FileService());
