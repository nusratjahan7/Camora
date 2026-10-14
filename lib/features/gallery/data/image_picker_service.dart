import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_error_handler.dart';

class ImagePickerService {
  ImagePickerService({required this.errorHandler, ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final AppErrorHandler errorHandler;
  final ImagePicker _picker;

  Future<XFile?> pickFromGallery() => errorHandler.guard(
    () => _picker.pickImage(source: ImageSource.gallery),
    operation: 'pick reference image',
  );
}

final imagePickerServiceProvider = Provider<ImagePickerService>(
  (ref) => ImagePickerService(errorHandler: ref.watch(appErrorHandlerProvider)),
);
