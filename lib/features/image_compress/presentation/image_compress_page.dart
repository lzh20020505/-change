import 'package:flutter/material.dart';

import '../../../core/models/processed_file_result.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/models/selected_file_info.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/services/conversion_history_service.dart';
import '../../../core/services/file_action_service.dart';
import '../../../core/services/image_processing_service.dart';
import '../../../core/services/output_directory_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../shared/widgets/tool_page.dart';

class ImageCompressPage extends StatefulWidget {
  const ImageCompressPage({super.key});

  @override
  State<ImageCompressPage> createState() => _ImageCompressPageState();
}

class _ImageCompressPageState extends State<ImageCompressPage> {
  final _filePickerService = FilePickerService();
  final _conversionHistoryService = ConversionHistoryService();
  final _fileActionService = FileActionService();
  final _imageProcessingService = ImageProcessingService();
  final _outputDirectoryService = OutputDirectoryService();
  final _permissionService = PermissionService();

  List<SelectedFileInfo> _selectedFiles = [];
  double _quality = 75;
  String _sizeMode = '原尺寸';
  bool _isProcessing = false;
  String? _processingResult;
  List<ProcessedFileResult> _results = [];

  Future<void> _pickFiles() async {
    await _permissionService.ensureFilePickerAccess();
    final files = await _filePickerService.pickImageFiles();
    if (!mounted || files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFiles = files;
      _processingResult = null;
      _results = [];
    });
  }

  Future<void> _compressImages() async {
    if (_selectedFiles.isEmpty) {
      showPendingSnackBar(context, message: '请先选择图片');
      return;
    }
    final inputPaths =
        _selectedFiles.map((file) => file.path).whereType<String>().toList();
    if (inputPaths.length != _selectedFiles.length) {
      showPendingSnackBar(context, message: '部分图片没有可读取的本地路径');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final outputDirectory = await _outputDirectoryService.getOutputDirectory(
        OutputDirectoryType.images,
      );
      final results = await _imageProcessingService.compressImages(
        inputPaths: inputPaths,
        outputDirectory: outputDirectory.path,
        quality: _quality.round(),
        resizeMode: _resizeMode,
      );
      final historySaved = await _saveHistory(results, inputPaths);
      if (!mounted) {
        return;
      }

      setState(() {
        _processingResult = _describeResults(results);
        _results = results;
      });
      showPendingSnackBar(
        context,
        message: historySaved ? '图片压缩完成' : '图片压缩完成，但记录保存失败',
      );
    } on ImageProcessingException catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: error.message);
      }
    } catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: '图片压缩失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: '图片压缩',
      description: '调整质量和尺寸参数，在本地批量压缩图片。',
      icon: Icons.photo_size_select_small_outlined,
      color: const Color(0xFF059669),
      bottomBar: FilledButton.icon(
        onPressed: _isProcessing ? null : _compressImages,
        icon: const Icon(Icons.compress_rounded),
        label: Text(_isProcessing ? '处理中' : '开始压缩'),
      ),
      children: [
        ToolSection(
          title: '输入文件',
          icon: Icons.add_photo_alternate_outlined,
          child: FileInputBox(
            title: _selectedFiles.isEmpty
                ? '未选择图片'
                : '已选择 ${_selectedFiles.length} 张图片',
            subtitle: '可选择单张或多张图片',
            icon: Icons.collections_outlined,
            actionLabel: '选择',
            onPressed: _isProcessing ? null : _pickFiles,
          ),
        ),
        if (_selectedFiles.isNotEmpty)
          ToolSection(
            title: '文件信息',
            icon: Icons.description_outlined,
            child: SelectedFileList(files: _selectedFiles),
          ),
        ToolSection(
          title: '压缩设置',
          icon: Icons.tune_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('质量', style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text('${_quality.round()}%'),
                ],
              ),
              Slider(
                value: _quality,
                min: 20,
                max: 100,
                divisions: 16,
                label: '${_quality.round()}%',
                onChanged: _isProcessing
                    ? null
                    : (value) => setState(() {
                          _quality = value;
                          _processingResult = null;
                          _results = [];
                        }),
              ),
              const SizedBox(height: 8),
              Text('尺寸', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              OptionChips(
                options: const ['原尺寸', '缩小 50%', '最长边 1080'],
                selected: _sizeMode,
                onChanged: _isProcessing
                    ? null
                    : (value) => setState(() {
                          _sizeMode = value;
                          _processingResult = null;
                          _results = [];
                        }),
              ),
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('压缩结果统一输出 JPG，透明区域会使用白色背景。'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const ToolSection(
          title: '输出位置',
          icon: Icons.output_rounded,
          child: PendingOutputBox(label: '保存到应用目录 LiteConverter/Images'),
        ),
        ToolSection(
          title: '处理结果',
          icon: Icons.task_alt_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SimulationResultBox(result: _processingResult),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 10),
                ProcessedResultList(
                  results: _results,
                  onOpen: _openResult,
                  onShare: _shareResult,
                  onDelete: _deleteResult,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openResult(ProcessedFileResult result) async {
    await _runFileAction(() => _fileActionService.openFile(result.outputPath));
  }

  Future<bool> _saveHistory(
    List<ProcessedFileResult> results,
    List<String> inputPaths,
  ) async {
    try {
      final createdAt = DateTime.now();
      await _conversionHistoryService.addRecords([
        for (var index = 0; index < results.length; index++)
          ConversionRecord.fromProcessedResult(
            result: results[index],
            type: ConversionRecordType.image,
            operation: '图片压缩',
            inputPaths: [inputPaths[index]],
            createdAt: createdAt.add(Duration(microseconds: index)),
          ),
      ]);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _shareResult(ProcessedFileResult result) async {
    await _runFileAction(() => _fileActionService.shareFile(result.outputPath));
  }

  Future<void> _deleteResult(ProcessedFileResult result) async {
    if (!await confirmResultDeletion(context, fileName: result.outputName)) {
      return;
    }
    try {
      await _fileActionService.deleteFile(result.outputPath);
      await _conversionHistoryService.deleteRecordsForOutput(result.outputPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _results.removeWhere((item) => item.outputPath == result.outputPath);
        if (_results.isEmpty) {
          _processingResult = null;
        }
      });
      showPendingSnackBar(context, message: '结果文件已删除');
    } catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: '删除失败：$error');
      }
    }
  }

  Future<void> _runFileAction(Future<void> Function() action) async {
    try {
      await action();
    } on FileActionException catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: error.message);
      }
    }
  }

  ImageResizeMode get _resizeMode {
    return switch (_sizeMode) {
      '缩小 50%' => ImageResizeMode.half,
      '最长边 1080' => ImageResizeMode.longEdge1080,
      _ => ImageResizeMode.original,
    };
  }

  String _describeResults(List<ProcessedFileResult> results) {
    final inputBytes = results.fold<int>(
      0,
      (total, result) => total + result.inputSizeBytes,
    );
    final outputBytes = results.fold<int>(
      0,
      (total, result) => total + result.outputSizeBytes,
    );
    final summary = ProcessedFileResult(
      inputPath: '',
      outputPath: '',
      inputSizeBytes: inputBytes,
      outputSizeBytes: outputBytes,
    );

    return '已压缩 ${results.length} 张图片\n'
        '总大小：${summary.inputDisplaySize} → ${summary.outputDisplaySize}'
        '（${summary.sizeChangeDescription}）\n'
        '输出目录：${results.first.outputPath.replaceAll(RegExp(r'[/\\][^/\\]+$'), '')}';
  }
}
