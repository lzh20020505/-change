import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_file_converter/core/services/image_processing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test_image_processing');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('createPdf forwards page settings and parses result', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return <Object?, Object?>{
        'inputPath': '/input/first.jpg',
        'outputPath': '/output/image_export.pdf',
        'inputSize': 4096,
        'outputSize': 2048,
      };
    });

    final service = ImageProcessingService(
      channel: channel,
      isAndroid: () => true,
    );
    final result = await service.createPdf(
      inputPaths: const ['/input/first.jpg', '/input/second.jpg'],
      outputDirectory: '/output',
      pageSize: PdfPageSize.letter,
      orientation: PdfPageOrientation.landscape,
      fitPage: false,
    );

    expect(receivedCall?.method, 'createPdf');
    expect(
      receivedCall?.arguments,
      <String, Object>{
        'inputPaths': const ['/input/first.jpg', '/input/second.jpg'],
        'outputDirectory': '/output',
        'pageSize': 'letter',
        'orientation': 'landscape',
        'fitPage': false,
      },
    );
    expect(result.outputName, 'image_export.pdf');
    expect(result.outputSizeBytes, 2048);
  });

  test('image processing rejects unsupported platforms before channel call',
      () {
    final service = ImageProcessingService(
      channel: channel,
      isAndroid: () => false,
    );

    expect(
      () => service.createPdf(
        inputPaths: const ['/input/first.jpg'],
        outputDirectory: '/output',
        pageSize: PdfPageSize.a4,
        orientation: PdfPageOrientation.portrait,
        fitPage: true,
      ),
      throwsA(isA<ImageProcessingException>()),
    );
  });
}
