import 'selected_file_info.dart';

class ProcessedFileResult {
  const ProcessedFileResult({
    required this.inputPath,
    required this.outputPath,
    required this.inputSizeBytes,
    required this.outputSizeBytes,
  });

  factory ProcessedFileResult.fromMap(Map<Object?, Object?> map) {
    return ProcessedFileResult(
      inputPath: map['inputPath'] as String,
      outputPath: map['outputPath'] as String,
      inputSizeBytes: (map['inputSize'] as num).toInt(),
      outputSizeBytes: (map['outputSize'] as num).toInt(),
    );
  }

  final String inputPath;
  final String outputPath;
  final int inputSizeBytes;
  final int outputSizeBytes;

  String get outputName {
    final normalizedPath = outputPath.replaceAll(r'\', '/');
    return normalizedPath.substring(normalizedPath.lastIndexOf('/') + 1);
  }

  String get inputDisplaySize => formatFileSize(inputSizeBytes);

  String get outputDisplaySize => formatFileSize(outputSizeBytes);

  String get sizeChangeDescription {
    if (inputSizeBytes <= 0) {
      return '输出大小 $outputDisplaySize';
    }

    final change = (outputSizeBytes - inputSizeBytes) / inputSizeBytes * 100;
    if (change.abs() < 0.05) {
      return '大小基本不变';
    }
    if (change < 0) {
      return '减少 ${change.abs().toStringAsFixed(1)}%';
    }
    return '增加 ${change.toStringAsFixed(1)}%';
  }
}
