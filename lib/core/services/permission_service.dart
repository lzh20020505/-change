import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> ensureFilePickerAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }

    // Android's system file picker grants URI access to selected files.
    // Keep this service as the single extension point for future direct
    // media-library access without blocking the picker today.
    final status = await Permission.storage.status;
    return status.isGranted || status.isLimited || status.isDenied;
  }
}
