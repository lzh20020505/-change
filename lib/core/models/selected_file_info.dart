class SelectedFileInfo {
  const SelectedFileInfo({
    required this.name,
    required this.path,
    required this.sizeBytes,
  });

  final String name;
  final String? path;
  final int sizeBytes;

  String get displayPath => path ?? '无可用路径';

  String get displaySize => formatFileSize(sizeBytes);
}

String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }

  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }

  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}
