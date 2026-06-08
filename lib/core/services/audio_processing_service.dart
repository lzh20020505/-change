import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/processed_file_result.dart';

enum AudioOutputFormat {
  mp3('MP3', 'mp3'),
  m4a('M4A', 'm4a'),
  wav('WAV', 'wav');

  const AudioOutputFormat(this.label, this.platformValue);

  final String label;
  final String platformValue;
}

class AudioProgress {
  const AudioProgress({
    required this.progress,
    required this.processedMilliseconds,
  });

  factory AudioProgress.fromMap(Map<Object?, Object?> map) {
    return AudioProgress(
      progress: ((map['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      processedMilliseconds:
          (map['processedMilliseconds'] as num?)?.toInt() ?? 0,
    );
  }

  final double progress;
  final int processedMilliseconds;
}

class AudioProcessingService {
  AudioProcessingService({
    MethodChannel methodChannel = const MethodChannel(_methodChannelName),
    EventChannel eventChannel = const EventChannel(_eventChannelName),
    bool Function()? isAndroid,
  })  : _methodChannel = methodChannel,
        _eventChannel = eventChannel,
        _isAndroid = isAndroid ?? _defaultIsAndroid;

  static const maxInputSizeBytes = 4 * 1024 * 1024 * 1024;
  static const largeFileWarningBytes = 1024 * 1024 * 1024;
  static const _methodChannelName = 'phone_file_converter/audio_processing';
  static const _eventChannelName =
      'phone_file_converter/audio_processing_progress';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final bool Function() _isAndroid;

  Stream<AudioProgress> get progressStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is! Map<Object?, Object?>) {
        throw const AudioProcessingException('收到无效的音频处理进度');
      }
      return AudioProgress.fromMap(event);
    });
  }

  Future<ProcessedFileResult> extractAudio({
    required String inputPath,
    required String outputDirectory,
    required AudioOutputFormat format,
    required int bitrateKbps,
    required int sampleRate,
  }) async {
    _ensureAndroid();

    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw const AudioProcessingException('所选视频文件已不存在');
    }
    final inputSize = await inputFile.length();
    if (inputSize <= 0) {
      throw const AudioProcessingException('所选视频是空文件');
    }
    if (inputSize > maxInputSizeBytes) {
      throw const AudioProcessingException('暂不处理超过 4 GB 的视频');
    }

    try {
      final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
        'extractAudio',
        {
          'inputPath': inputPath,
          'outputDirectory': outputDirectory,
          'format': format.platformValue,
          'bitrateKbps': bitrateKbps,
          'sampleRate': sampleRate,
        },
      );
      if (result == null) {
        throw const AudioProcessingException('音频处理未返回结果');
      }
      return ProcessedFileResult.fromMap(result);
    } on PlatformException catch (error) {
      throw AudioProcessingException(error.message ?? '音频提取失败');
    }
  }

  Future<void> cancel() async {
    _ensureAndroid();
    try {
      await _methodChannel.invokeMethod<void>('cancelAudioExtraction');
    } on PlatformException catch (error) {
      throw AudioProcessingException(error.message ?? '取消任务失败');
    }
  }

  void _ensureAndroid() {
    if (!_isAndroid()) {
      throw const AudioProcessingException('当前音频处理功能仅支持 Android');
    }
  }

  static bool _defaultIsAndroid() => Platform.isAndroid;
}

class AudioProcessingException implements Exception {
  const AudioProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}
