import 'package:file_picker/file_picker.dart';

import '../models/selected_file_info.dart';

class FilePickerService {
  Future<SelectedFileInfo?> pickImageFile() {
    return pickSingleFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'],
    );
  }

  Future<List<SelectedFileInfo>> pickImageFiles() {
    return pickMultipleFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'],
    );
  }

  Future<SelectedFileInfo?> pickVideoFile() {
    return pickSingleFile(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'mkv', 'avi', 'webm', '3gp'],
    );
  }

  Future<SelectedFileInfo?> pickSingleFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return _fromPlatformFile(result.files.first);
  }

  Future<List<SelectedFileInfo>> pickMultipleFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: true,
      withData: false,
    );

    return result?.files.map(_fromPlatformFile).toList() ?? [];
  }

  SelectedFileInfo _fromPlatformFile(PlatformFile file) {
    return SelectedFileInfo(
      name: file.name,
      path: file.path,
      sizeBytes: file.size,
    );
  }
}
