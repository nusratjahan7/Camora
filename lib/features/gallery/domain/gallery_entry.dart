import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// What a history entry points at.
enum GalleryEntryKind {
  /// A photo the camera captured.
  photo,

  /// A reference image that was floated over the preview.
  reference,
}

/// Which image a captured photo is.
///
/// Both are kept in the model so the gallery can label them apart: an original
/// is exactly what the camera produced, while a composite has the reference
/// image drawn over it.
enum PhotoExport { original, composite }

/// One row of local history: a file the app owns, plus lightweight metadata.
///
/// Only the path is stored, never the image. The file lives in the app's
/// documents directory and may have been removed outside the app, so anything
/// showing an entry has to handle a missing file.
@immutable
class GalleryEntry {
  const GalleryEntry({
    required this.id,
    required this.path,
    required this.kind,
    required this.createdAt,
    this.name,
    this.export = PhotoExport.original,
  });

  final String id;

  /// Absolute path to the app's own copy.
  final String path;

  final GalleryEntryKind kind;

  final DateTime createdAt;

  /// The file name the entry was created from, for display.
  final String? name;

  /// Only meaningful for [GalleryEntryKind.photo].
  final PhotoExport export;

  /// What to show under the thumbnail.
  String get label => name ?? p.basename(path);

  bool get isComposite =>
      kind == GalleryEntryKind.photo && export == PhotoExport.composite;

  GalleryEntry copyWith({String? path, String? name, PhotoExport? export}) {
    return GalleryEntry(
      id: id,
      path: path ?? this.path,
      kind: kind,
      createdAt: createdAt,
      name: name ?? this.name,
      export: export ?? this.export,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'path': path,
    'kind': kind.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'export': export.name,
    if (name != null) 'name': name,
  };

  /// Returns null for a row that cannot be understood, so one corrupt entry
  /// cannot take the whole history with it.
  static GalleryEntry? fromJson(Object? json) {
    if (json is! Map) return null;

    final Object? id = json['id'];
    final Object? path = json['path'];
    final DateTime? createdAt = DateTime.tryParse(
      json['createdAt'] as String? ?? '',
    );
    if (id is! String || path is! String || createdAt == null) return null;

    return GalleryEntry(
      id: id,
      path: path,
      kind: _kindFromName(json['kind']),
      createdAt: createdAt.toLocal(),
      name: json['name'] as String?,
      export: _exportFromName(json['export']),
    );
  }

  static GalleryEntryKind _kindFromName(Object? name) =>
      GalleryEntryKind.values.firstWhere(
        (kind) => kind.name == name,
        orElse: () => GalleryEntryKind.photo,
      );

  static PhotoExport _exportFromName(Object? name) => PhotoExport.values
      .firstWhere((export) => export.name == name, orElse: () => PhotoExport.original);

  @override
  String toString() => 'GalleryEntry(${kind.name}, $label, $path)';
}
