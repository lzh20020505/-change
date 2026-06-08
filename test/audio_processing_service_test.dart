import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_file_converter/core/services/audio_processing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test_audio_processing');
  late Directory tempDirectory;
  late File inputFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('audio_test_');
    inputFile = File('${tempDirectory.path}/video.mp4');
    await inputFile.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await tempDirectory.delete(recursive: true);
  });

  test('extractAudio forwards format parameters and parses result', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return <Object?, Object?>{
        'inputPath': inputFile.path,
        'outputPath': '${tempDirectory.path}/video_audio.mp3',
        'inputSize': 3,
        'outputSize': 2,
      };
    });

    final service = AudioProcessingService(
      methodChannel: channel,
      isAndroid: () => true,
    );
    final result = await service.extractAudio(
      inputPath: inputFile.path,
      outputDirectory: tempDirectory.path,
      format: AudioOutputFormat.mp3,
      bitrateKbps: 192,
      sampleRate: 44100,
    );

    expect(receivedCall?.method, 'extractAudio');
    expect(
      receivedCall?.arguments,
      <String, Object>{
        'inputPath': inputFile.path,
        'outputDirectory': tempDirectory.path,
        'format': 'mp3',
        'bitrateKbps': 192,
        'sampleRate': 44100,
      },
    );
    expect(result.outputName, 'video_audio.mp3');
  });

  test('cancel forwards cancellation request', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return null;
    });

    final service = AudioProcessingService(
      methodChannel: channel,
      isAndroid: () => true,
    );
    await service.cancel();

    expect(receivedCall?.method, 'cancelAudioExtraction');
  });

  test('empty input is rejected before native processing', () async {
    await inputFile.writeAsBytes([]);
    final service = AudioProcessingService(
      methodChannel: channel,
      isAndroid: () => true,
    );

    expect(
      () => service.extractAudio(
        inputPath: inputFile.path,
        outputDirectory: tempDirectory.path,
        format: AudioOutputFormat.wav,
        bitrateKbps: 192,
        sampleRate: 48000,
      ),
      throwsA(isA<AudioProcessingException>()),
    );
  });
}
