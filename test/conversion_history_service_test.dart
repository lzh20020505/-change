import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_file_converter/core/models/conversion_record.dart';
import 'package:phone_file_converter/core/services/conversion_history_service.dart';

void main() {
  late Directory tempDirectory;
  late File historyFile;
  late ConversionHistoryService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('history_test_');
    historyFile = File('${tempDirectory.path}/history.json');
    service = ConversionHistoryService(
      historyFileProvider: () async => historyFile,
    );
  });

  tearDown(() => tempDirectory.delete(recursive: true));

  test('adds, loads and deletes JSON records', () async {
    final older = _record('older', DateTime.utc(2026, 1, 1));
    final newer = _record('newer', DateTime.utc(2026, 2, 1));

    await service.addRecords([older]);
    await service.addRecords([newer]);

    final loaded = await service.loadRecords();
    expect(loaded.map((record) => record.id), ['newer', 'older']);

    await service.deleteRecord('newer');
    expect(
      (await service.loadRecords()).map((record) => record.id),
      ['older'],
    );
  });

  test('backs up corrupted JSON and returns an empty list', () async {
    await historyFile.writeAsString('{broken');

    expect(await service.loadRecords(), isEmpty);
    expect(await File('${historyFile.path}.corrupt').exists(), isTrue);
  });
}

ConversionRecord _record(String id, DateTime createdAt) {
  return ConversionRecord(
    id: id,
    type: ConversionRecordType.image,
    operation: '图片转换',
    inputPaths: const ['/input.jpg'],
    outputPath: '/output/$id.jpg',
    inputSizeBytes: 20,
    outputSizeBytes: 10,
    createdAt: createdAt,
  );
}
