import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_error_handler.dart';

class ImagePickerService {
  ImagePickerService({required this.errorHandler, ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final AppErrorHandler errorHandler;
  final ImagePicker _picker;

  Future<XFile?> pickFromGallery() => errorHandler.guard(
    // Without full metadata iOS uses PHPicker with no photo-library permission
    // prompt; Android uses the system Photo Picker, which needs none either.
    () => _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    ),
    operation: 'pick reference image',
  );
}

final imagePickerServiceProvider = Provider<ImagePickerService>(
  (ref) => ImagePickerService(errorHandler: ref.watch(appErrorHandlerProvider)),
);
