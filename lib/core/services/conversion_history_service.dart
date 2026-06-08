import 'dart:convert';
import 'dart:io';

import '../models/conversion_record.dart';
import 'output_directory_service.dart';

class ConversionHistoryService {
  ConversionHistoryService({
    OutputDirectoryService? outputDirectoryService,
    Future<File> Function()? historyFileProvider,
  })  : _outputDirectoryService =
            outputDirectoryService ?? OutputDirectoryService(),
        _historyFileProvider = historyFileProvider;

  static const maxRecords = 200;

  final OutputDirectoryService _outputDirectoryService;
  final Future<File> Function()? _historyFileProvider;

  Future<List<ConversionRecord>> loadRecords() async {
    final file = await _getHistoryFile();
    if (!await file.exists()) {
      return [];
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List<Object?>) {
        throw const FormatException('转换记录不是 JSON 列表');
      }

      final records = <ConversionRecord>[];
      for (final item in decoded) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        try {
          records.add(ConversionRecord.fromJson(item));
        } on Object {
          // Skip one malformed item without losing the remaining history.
        }
      }
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records.take(maxRecords).toList();
    } on Object {
      await _backupCorruptedFile(file);
      return [];
    }
  }

  Future<void> addRecords(Iterable<ConversionRecord> newRecords) async {
    final records = await loadRecords();
    records.insertAll(0, newRecords);
    await _writeRecords(records.take(maxRecords).toList());
  }

  Future<void> deleteRecord(String id) async {
    final records = await loadRecords();
    records.removeWhere((record) => record.id == id);
    await _writeRecords(records);
  }

  Future<void> deleteRecordsForOutput(String outputPath) async {
    final records = await loadRecords();
    records.removeWhere((record) => record.outputPath == outputPath);
    await _writeRecords(records);
  }

  Future<File> _getHistoryFile() async {
    final provider = _historyFileProvider;
    if (provider != null) {
      return provider();
    }
    final root = await _outputDirectoryService.getRootDirectory();
    return File(
      '${root.path}${Platform.pathSeparator}conversion_history.json',
    );
  }

  Future<void> _writeRecords(List<ConversionRecord> records) async {
    final file = await _getHistoryFile();
    await file.parent.create(recursive: true);
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(
      jsonEncode(records.map((record) => record.toJson()).toList()),
      flush: true,
    );
    if (await file.exists()) {
      await file.delete();
    }
    await temporaryFile.rename(file.path);
  }

  Future<void> _backupCorruptedFile(File file) async {
    if (!await file.exists()) {
      return;
    }
    final backup = File('${file.path}.corrupt');
    if (await backup.exists()) {
      await backup.delete();
    }
    await file.rename(backup.path);
  }
}
