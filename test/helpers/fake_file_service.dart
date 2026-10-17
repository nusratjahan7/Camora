import 'dart:io';

import 'package:camera_overlay/core/files/file_service.dart';

/// A [FileService] that touches no disk.
///
/// Widget tests run in a fake-async zone where real file I/O never completes,
/// so they use this and say which paths "exist".
final class FakeFileService extends FileService {
  FakeFileService();

  /// Paths the fake treats as present on disk.
  final Set<String> present = <String>{};

  @override
  Future<Directory> capturesDirectory() async => Directory.systemTemp;

  @override
  Future<Directory> referencesDirectory() async => Directory.systemTemp;

  @override
  Future<File> createReferenceFile({required String extension}) async =>
      File('reference.$extension');

  @override
  Future<bool> exists(String path) async => present.contains(path);

  @override
  Future<void> deleteIfPresent(String path) async {
    present.remove(path);
  }

  @override
  Future<void> deleteIfExists(File file) async {
    present.remove(file.path);
  }
}
