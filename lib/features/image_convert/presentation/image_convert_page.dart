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

class ImageConvertPage extends StatefulWidget {
  const ImageConvertPage({super.key});

  @override
  State<ImageConvertPage> createState() => _ImageConvertPageState();
}

class _ImageConvertPageState extends State<ImageConvertPage> {
  final _filePickerService = FilePickerService();
  final _conversionHistoryService = ConversionHistoryService();
  final _fileActionService = FileActionService();
  final _imageProcessingService = ImageProcessingService();
  final _outputDirectoryService = OutputDirectoryService();
  final _permissionService = PermissionService();

  SelectedFileInfo? _selectedFile;
  String _format = 'JPG';
  bool _isProcessing = false;
  String? _processingResult;
  List<ProcessedFileResult> _results = [];

  Future<void> _pickFile() async {
    await _permissionService.ensureFilePickerAccess();
    final file = await _filePickerService.pickImageFile();
    if (!mounted || file == null) {
      return;
    }

    setState(() {
      _selectedFile = file;
      _processingResult = null;
      _results = [];
    });
  }

  Future<void> _convertImage() async {
    final selectedFile = _selectedFile;
    if (selectedFile == null) {
      showPendingSnackBar(context, message: '请先选择图片');
      return;
    }
    final inputPath = selectedFile.path;
    if (inputPath == null) {
      showPendingSnackBar(context, message: '无法读取所选图片的本地路径');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final outputDirectory = await _outputDirectoryService.getOutputDirectory(
        OutputDirectoryType.images,
      );
      final result = await _imageProcessingService.convertImage(
        inputPath: inputPath,
        outputDirectory: outputDirectory.path,
        outputFormat: _format,
      );
      final historySaved = await _saveHistory(result, inputPath);
      if (!mounted) {
        return;
      }

      setState(() {
        _processingResult = _describeResult(result);
        _results = [result];
      });
      showPendingSnackBar(
        context,
        message: historySaved ? '图片转换完成' : '图片转换完成，但记录保存失败',
      );
    } on ImageProcessingException catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: error.message);
      }
    } catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: '图片转换失败：$error');
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
      title: '图片转换',
      description: '使用 Android 原生能力在本地转换图片格式。',
      icon: Icons.image_outlined,
      color: const Color(0xFF2563EB),
      bottomBar: FilledButton.icon(
        onPressed: _isProcessing ? null : _convertImage,
        icon: const Icon(Icons.sync_rounded),
        label: Text(_isProcessing ? '处理中' : '开始转换'),
      ),
      children: [
        ToolSection(
          title: '输入文件',
          icon: Icons.add_photo_alternate_outlined,
          child: FileInputBox(
            title: _selectedFile?.name ?? '未选择图片',
            subtitle: '支持 JPG、PNG、WebP 等常见格式',
            icon: Icons.image_outlined,
            actionLabel: '选择',
            onPressed: _isProcessing ? null : _pickFile,
          ),
        ),
        if (_selectedFile != null)
          ToolSection(
            title: '文件信息',
            icon: Icons.description_outlined,
            child: SelectedFileCard(file: _selectedFile!),
          ),
        ToolSection(
          title: '转换设置',
          icon: Icons.tune_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('目标格式', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              OptionChips(
                options: const ['JPG', 'PNG', 'WebP'],
                selected: _format,
                onChanged: _isProcessing
                    ? null
                    : (value) => setState(() {
                          _format = value;
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
                    child: Text(
                      '转换时会修正图片方向，但暂不复制 EXIF 等元数据。',
                    ),
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
    ProcessedFileResult result,
    String inputPath,
  ) async {
    try {
      await _conversionHistoryService.addRecords([
        ConversionRecord.fromProcessedResult(
          result: result,
          type: ConversionRecordType.image,
          operation: '图片转换',
          inputPaths: [inputPath],
          createdAt: DateTime.now(),
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
        _processingResult = _results.isEmpty ? null : _processingResult;
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

  String _describeResult(ProcessedFileResult result) {
    return '已生成：${result.outputName}\n'
        '大小：${result.inputDisplaySize} → ${result.outputDisplaySize}'
        '（${result.sizeChangeDescription}）\n'
        '路径：${result.outputPath}';
  }
}
