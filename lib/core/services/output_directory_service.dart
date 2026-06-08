import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum OutputDirectoryType {
  images('Images'),
  pdfs('Pdfs'),
  audio('Audio'),
  temp('Temp');

  const OutputDirectoryType(this.folderName);

  final String folderName;
}

class OutputDirectoryService {
  Future<Directory> getRootDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return _ensureDirectory(_join(documentsDirectory.path, 'LiteConverter'));
  }

  Future<Directory> getOutputDirectory(OutputDirectoryType type) async {
    final root = await getRootDirectory();
    return _ensureDirectory(_join(root.path, type.folderName));
  }

  Future<Map<OutputDirectoryType, Directory>> createOutputDirectories() async {
    final directories = <OutputDirectoryType, Directory>{};
    for (final type in OutputDirectoryType.values) {
      directories[type] = await getOutputDirectory(type);
    }
    return directories;
  }

  Future<void> clearCache() async {
    final tempDirectory = await getOutputDirectory(OutputDirectoryType.temp);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
    await tempDirectory.create(recursive: true);
  }

  Future<Directory> _ensureDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _join(String parent, String child) {
    return '$parent${Platform.pathSeparator}$child';
  }
}
