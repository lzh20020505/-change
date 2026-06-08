import 'dart:io';

import 'package:flutter/services.dart';

import '../models/processed_file_result.dart';

enum ImageResizeMode {
  original('original'),
  half('half'),
  longEdge1080('longEdge1080');

  const ImageResizeMode(this.platformValue);

  final String platformValue;
}

enum PdfPageSize {
  a4('a4'),
  original('original'),
  letter('letter');

  const PdfPageSize(this.platformValue);

  final String platformValue;
}

enum PdfPageOrientation {
  portrait('portrait'),
  landscape('landscape');

  const PdfPageOrientation(this.platformValue);

  final String platformValue;
}

class ImageProcessingService {
  ImageProcessingService({
    MethodChannel channel = const MethodChannel(_channelName),
    bool Function()? isAndroid,
  })  : _channel = channel,
        _isAndroid = isAndroid ?? _defaultIsAndroid;

  static const _channelName = 'phone_file_converter/image_processing';

  final MethodChannel _channel;
  final bool Function() _isAndroid;

  Future<ProcessedFileResult> convertImage({
    required String inputPath,
    required String outputDirectory,
    required String outputFormat,
  }) async {
    _ensureAndroid();

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'convertImage',
        {
          'inputPath': inputPath,
          'outputDirectory': outputDirectory,
          'outputFormat': outputFormat,
        },
      );
      if (result == null) {
        throw const ImageProcessingException('原生图片转换未返回结果');
      }
      return ProcessedFileResult.fromMap(result);
    } on PlatformException catch (error) {
      throw ImageProcessingException(error.message ?? '图片转换失败');
    }
  }

  Future<List<ProcessedFileResult>> compressImages({
    required List<String> inputPaths,
    required String outputDirectory,
    required int quality,
    required ImageResizeMode resizeMode,
  }) async {
    _ensureAndroid();

    try {
      final results = await _channel.invokeListMethod<Object?>(
        'compressImages',
        {
          'inputPaths': inputPaths,
          'outputDirectory': outputDirectory,
          'quality': quality,
          'resizeMode': resizeMode.platformValue,
        },
      );
      if (results == null) {
        throw const ImageProcessingException('原生图片压缩未返回结果');
      }

      return results.map((result) {
        if (result is! Map<Object?, Object?>) {
          throw const ImageProcessingException('原生图片压缩返回了无效结果');
        }
        return ProcessedFileResult.fromMap(result);
      }).toList();
    } on PlatformException catch (error) {
      throw ImageProcessingException(error.message ?? '图片压缩失败');
    }
  }

  Future<ProcessedFileResult> createPdf({
    required List<String> inputPaths,
    required String outputDirectory,
    required PdfPageSize pageSize,
    required PdfPageOrientation orientation,
    required bool fitPage,
  }) async {
    _ensureAndroid();

    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'createPdf',
        {
          'inputPaths': inputPaths,
          'outputDirectory': outputDirectory,
          'pageSize': pageSize.platformValue,
          'orientation': orientation.platformValue,
          'fitPage': fitPage,
        },
      );
      if (result == null) {
        throw const ImageProcessingException('原生 PDF 生成未返回结果');
      }
      return ProcessedFileResult.fromMap(result);
    } on PlatformException catch (error) {
      throw ImageProcessingException(error.message ?? 'PDF 生成失败');
    }
  }

  void _ensureAndroid() {
    if (!_isAndroid()) {
      throw const ImageProcessingException('当前图片处理功能仅支持 Android');
    }
  }

  static bool _defaultIsAndroid() => Platform.isAndroid;
}

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}
