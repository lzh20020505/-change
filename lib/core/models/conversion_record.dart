import 'selected_file_info.dart';
import 'processed_file_result.dart';

enum ConversionRecordType {
  image('图片'),
  pdf('PDF'),
  audio('音频');

  const ConversionRecordType(this.label);

  final String label;
}

class ConversionRecord {
  const ConversionRecord({
    required this.id,
    required this.type,
    required this.operation,
    required this.inputPaths,
    required this.outputPath,
    required this.inputSizeBytes,
    required this.outputSizeBytes,
    required this.createdAt,
  });

  factory ConversionRecord.fromJson(Map<String, Object?> json) {
    return ConversionRecord(
      id: json['id'] as String,
      type: ConversionRecordType.values.byName(json['type'] as String),
      operation: json['operation'] as String,
      inputPaths: (json['inputPaths'] as List<Object?>).cast<String>(),
      outputPath: json['outputPath'] as String,
      inputSizeBytes: (json['inputSizeBytes'] as num).toInt(),
      outputSizeBytes: (json['outputSizeBytes'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  factory ConversionRecord.fromProcessedResult({
    required ProcessedFileResult result,
    required ConversionRecordType type,
    required String operation,
    required List<String> inputPaths,
    required DateTime createdAt,
    String? id,
  }) {
    return ConversionRecord(
      id: id ?? '${createdAt.microsecondsSinceEpoch}-${result.outputName}',
      type: type,
      operation: operation,
      inputPaths: inputPaths,
      outputPath: result.outputPath,
      inputSizeBytes: result.inputSizeBytes,
      outputSizeBytes: result.outputSizeBytes,
      createdAt: createdAt,
    );
  }

  final String id;
  final ConversionRecordType type;
  final String operation;
  final List<String> inputPaths;
  final String outputPath;
  final int inputSizeBytes;
  final int outputSizeBytes;
  final DateTime createdAt;

  String get outputName {
    final normalizedPath = outputPath.replaceAll(r'\', '/');
    return normalizedPath.substring(normalizedPath.lastIndexOf('/') + 1);
  }

  String get inputDisplaySize => formatFileSize(inputSizeBytes);

  String get outputDisplaySize => formatFileSize(outputSizeBytes);

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.name,
      'operation': operation,
      'inputPaths': inputPaths,
      'outputPath': outputPath,
      'inputSizeBytes': inputSizeBytes,
      'outputSizeBytes': outputSizeBytes,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}
