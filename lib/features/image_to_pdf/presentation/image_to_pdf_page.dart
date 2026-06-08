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

class ImageToPdfPage extends StatefulWidget {
  const ImageToPdfPage({super.key});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  final _filePickerService = FilePickerService();
  final _conversionHistoryService = ConversionHistoryService();
  final _fileActionService = FileActionService();
  final _imageProcessingService = ImageProcessingService();
  final _outputDirectoryService = OutputDirectoryService();
  final _permissionService = PermissionService();

  List<SelectedFileInfo> _selectedFiles = [];
  String _pageSize = 'A4';
  String _orientation = '竖向';
  bool _fitPage = true;
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
      _selectedFiles = [..._selectedFiles, ...files];
      _processingResult = null;
      _results = [];
    });
  }

  Future<void> _createPdf() async {
    if (_selectedFiles.isEmpty) {
      showPendingSnackBar(context, message: '请先添加图片');
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
        OutputDirectoryType.pdfs,
      );
      final result = await _imageProcessingService.createPdf(
        inputPaths: inputPaths,
        outputDirectory: outputDirectory.path,
        pageSize: _pdfPageSize,
        orientation: _pdfOrientation,
        fitPage: _fitPage,
      );
      final historySaved = await _saveHistory(result, inputPaths);
      if (!mounted) {
        return;
      }

      setState(() {
        _processingResult = _describeResult(result);
        _results = [result];
      });
      showPendingSnackBar(
        context,
        message: historySaved ? 'PDF 生成完成' : 'PDF 生成完成，但记录保存失败',
      );
    } on ImageProcessingException catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: error.message);
      }
    } catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: 'PDF 生成失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _moveFile(int index, int offset) {
    final targetIndex = index + offset;
    if (targetIndex < 0 || targetIndex >= _selectedFiles.length) {
      return;
    }

    setState(() {
      final files = [..._selectedFiles];
      final file = files.removeAt(index);
      files.insert(targetIndex, file);
      _selectedFiles = files;
      _processingResult = null;
      _results = [];
    });
  }

  void _removeFile(int index) {
    setState(() {
      final files = [..._selectedFiles]..removeAt(index);
      _selectedFiles = files;
      _processingResult = null;
      _results = [];
    });
  }

  void _clearFiles() {
    setState(() {
      _selectedFiles = [];
      _processingResult = null;
      _results = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: '图片转 PDF',
      description: '按顺序整理图片，在本地生成多页 PDF。',
      icon: Icons.picture_as_pdf_outlined,
      color: const Color(0xFFDC2626),
      bottomBar: FilledButton.icon(
        onPressed: _isProcessing ? null : _createPdf,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(_isProcessing ? '处理中' : '生成 PDF'),
      ),
      children: [
        ToolSection(
          title: '图片列表',
          icon: Icons.photo_library_outlined,
          child: FileInputBox(
            title: _selectedFiles.isEmpty
                ? '未添加图片'
                : '已添加 ${_selectedFiles.length} 张图片',
            subtitle: '支持分批添加，并可调整页面顺序',
            icon: Icons.collections_bookmark_outlined,
            actionLabel: '添加',
            onPressed: _isProcessing ? null : _pickFiles,
          ),
        ),
        if (_selectedFiles.isNotEmpty)
          ToolSection(
            title: '页面顺序',
            icon: Icons.description_outlined,
            child: Column(
              children: [
                for (var index = 0; index < _selectedFiles.length; index++)
                  _PdfImageItem(
                    index: index,
                    file: _selectedFiles[index],
                    canMoveUp: index > 0,
                    canMoveDown: index < _selectedFiles.length - 1,
                    enabled: !_isProcessing,
                    onMoveUp: () => _moveFile(index, -1),
                    onMoveDown: () => _moveFile(index, 1),
                    onRemove: () => _removeFile(index),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isProcessing ? null : _clearFiles,
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('清空列表'),
                  ),
                ),
              ],
            ),
          ),
        ToolSection(
          title: '页面设置',
          icon: Icons.tune_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('纸张', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              OptionChips(
                options: const ['A4', '原图比例', 'Letter'],
                selected: _pageSize,
                onChanged: _isProcessing
                    ? null
                    : (value) => setState(() {
                          _pageSize = value;
                          _processingResult = null;
                          _results = [];
                        }),
              ),
              if (_pageSize != '原图比例') ...[
                const SizedBox(height: 14),
                Text('方向', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                OptionChips(
                  options: const ['竖向', '横向'],
                  selected: _orientation,
                  onChanged: _isProcessing
                      ? null
                      : (value) => setState(() {
                            _orientation = value;
                            _processingResult = null;
                            _results = [];
                          }),
                ),
              ] else ...[
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('每一页自动使用对应图片的原始比例和方向。')),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('完整适配页面'),
                        SizedBox(height: 4),
                        Text('关闭后图片会填满页面，边缘可能被裁剪'),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _fitPage,
                    onChanged: _isProcessing
                        ? null
                        : (value) => setState(() {
                              _fitPage = value;
                              _processingResult = null;
                              _results = [];
                            }),
                  ),
                ],
              ),
            ],
          ),
        ),
        const ToolSection(
          title: '输出文件',
          icon: Icons.output_rounded,
          child: PendingOutputBox(label: '默认文件名：image_export.pdf'),
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
    List<String> inputPaths,
  ) async {
    try {
      await _conversionHistoryService.addRecords([
        ConversionRecord.fromProcessedResult(
          result: result,
          type: ConversionRecordType.pdf,
          operation: '图片转 PDF',
          inputPaths: inputPaths,
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
        _results = [];
        _processingResult = null;
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

  PdfPageSize get _pdfPageSize {
    return switch (_pageSize) {
      '原图比例' => PdfPageSize.original,
      'Letter' => PdfPageSize.letter,
      _ => PdfPageSize.a4,
    };
  }

  PdfPageOrientation get _pdfOrientation {
    return _orientation == '横向'
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait;
  }

  String _describeResult(ProcessedFileResult result) {
    return '已生成：${result.outputName}\n'
        '页面数量：${_selectedFiles.length}\n'
        '图片总大小：${result.inputDisplaySize}\n'
        'PDF 大小：${result.outputDisplaySize}\n'
        '路径：${result.outputPath}';
  }
}

class _PdfImageItem extends StatelessWidget {
  const _PdfImageItem({
    required this.index,
    required this.file,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.enabled,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final SelectedFileInfo file;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool enabled;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第 ${index + 1} 页',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectedFileCard(file: file),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: '上移',
                onPressed: enabled && canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: '下移',
                onPressed: enabled && canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: '移除',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
