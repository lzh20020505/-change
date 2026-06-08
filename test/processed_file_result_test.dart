import 'package:flutter_test/flutter_test.dart';
import 'package:phone_file_converter/core/models/processed_file_result.dart';

void main() {
  test('processed result exposes output name and reduced size', () {
    const result = ProcessedFileResult(
      inputPath: '/input/photo.png',
      outputPath: r'C:\output\photo_compressed.jpg',
      inputSizeBytes: 2048,
      outputSizeBytes: 1024,
    );

    expect(result.outputName, 'photo_compressed.jpg');
    expect(result.inputDisplaySize, '2.0 KB');
    expect(result.outputDisplaySize, '1.0 KB');
    expect(result.sizeChangeDescription, '减少 50.0%');
  });

  test('processed result reports size increase', () {
    const result = ProcessedFileResult(
      inputPath: '/input/photo.jpg',
      outputPath: '/output/photo.png',
      inputSizeBytes: 100,
      outputSizeBytes: 125,
    );

    expect(result.sizeChangeDescription, '增加 25.0%');
  });
}
