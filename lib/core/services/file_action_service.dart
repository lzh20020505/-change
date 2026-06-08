import 'dart:io';

import 'package:flutter/services.dart';

class FileActionService {
  FileActionService({
    MethodChannel channel = const MethodChannel(_channelName),
    bool Function()? isAndroid,
  })  : _channel = channel,
        _isAndroid = isAndroid ?? _defaultIsAndroid;

  static const _channelName = 'phone_file_converter/file_actions';

  final MethodChannel _channel;
  final bool Function() _isAndroid;

  Future<void> openFile(String path) => _invoke('openFile', path);

  Future<void> shareFile(String path) => _invoke('shareFile', path);

  Future<bool> deleteFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return false;
    }
    return file.delete().then((_) => true);
  }

  Future<void> _invoke(String method, String path) async {
    if (!_isAndroid()) {
      throw const FileActionException('当前文件操作仅支持 Android');
    }
    if (!await File(path).exists()) {
      throw const FileActionException('结果文件已不存在');
    }

    try {
      await _channel.invokeMethod<void>(method, {'path': path});
    } on PlatformException catch (error) {
      throw FileActionException(error.message ?? '文件操作失败');
    }
  }

  static bool _defaultIsAndroid() => Platform.isAndroid;
}

class FileActionException implements Exception {
  const FileActionException(this.message);

  final String message;

  @override
  String toString() => message;
}
