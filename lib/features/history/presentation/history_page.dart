import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/models/conversion_record.dart';
import '../../../core/services/conversion_history_service.dart';
import '../../../core/services/file_action_service.dart';
import '../../../core/services/output_directory_service.dart';
import '../../../shared/widgets/tool_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _outputDirectoryService = OutputDirectoryService();
  final _historyService = ConversionHistoryService();
  final _fileActionService = FileActionService();

  String _filter = '全部';
  String? _directoryResult;
  List<ConversionRecord> _records = [];
  Set<String> _existingPaths = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await _historyService.loadRecords();
    final existingPaths = <String>{};
    for (final record in records) {
      if (await File(record.outputPath).exists()) {
        existingPaths.add(record.outputPath);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _records = records;
      _existingPaths = existingPaths;
      _isLoading = false;
    });
  }

  Future<void> _createDirectories() async {
    final root = await _outputDirectoryService.getRootDirectory();
    await _outputDirectoryService.createOutputDirectories();
    if (!mounted) {
      return;
    }

    setState(() {
      _directoryResult = '输出目录已就绪：${root.path}';
    });
    showPendingSnackBar(context, message: '输出目录已创建');
  }

  Future<void> _clearCache() async {
    await _outputDirectoryService.clearCache();
    final temp = await _outputDirectoryService.getOutputDirectory(
      OutputDirectoryType.temp,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _directoryResult = 'Temp 缓存已清理：${temp.path}';
    });
    showPendingSnackBar(context, message: '缓存已清理');
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _filteredRecords;
    return ToolPage(
      title: '转换记录',
      description: '记录保存在本地 JSON 文件中，最多保留最近 200 条。',
      icon: Icons.history_rounded,
      color: const Color(0xFFEA580C),
      children: [
        ToolSection(
          title: '筛选',
          icon: Icons.filter_list_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in const ['全部', '图片', 'PDF', '音频'])
                ChoiceChip(
                  label: Text('$label (${_filterCount(label)})'),
                  selected: _filter == label,
                  onSelected: (_) => setState(() => _filter = label),
                ),
            ],
          ),
        ),
        ToolSection(
          title: '目录管理',
          icon: Icons.folder_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _createDirectories,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('创建输出目录'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('清理缓存'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loadRecords,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('刷新记录'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SimulationResultBox(result: _directoryResult),
            ],
          ),
        ),
        ToolSection(
          title: '记录列表',
          icon: Icons.list_alt_rounded,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredRecords.isEmpty
                  ? const _EmptyHistory()
                  : Column(
                      children: [
                        for (final record in filteredRecords)
                          _HistoryRecordCard(
                            record: record,
                            fileExists:
                                _existingPaths.contains(record.outputPath),
                            onOpen: () => _openRecord(record),
                            onShare: () => _shareRecord(record),
                            onDelete: () => _deleteRecord(record),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  List<ConversionRecord> get _filteredRecords {
    if (_filter == '全部') {
      return _records;
    }
    return _records.where((record) => record.type.label == _filter).toList();
  }

  int _filterCount(String label) {
    if (label == '全部') {
      return _records.length;
    }
    return _records.where((record) => record.type.label == label).length;
  }

  Future<void> _openRecord(ConversionRecord record) async {
    await _runFileAction(
      () => _fileActionService.openFile(record.outputPath),
    );
  }

  Future<void> _shareRecord(ConversionRecord record) async {
    await _runFileAction(
      () => _fileActionService.shareFile(record.outputPath),
    );
  }

  Future<void> _deleteRecord(ConversionRecord record) async {
    final fileExists = _existingPaths.contains(record.outputPath);
    final confirmed = await confirmResultDeletion(
      context,
      fileName: record.outputName,
    );
    if (!confirmed) {
      return;
    }

    try {
      if (fileExists) {
        await _fileActionService.deleteFile(record.outputPath);
      }
      await _historyService.deleteRecord(record.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _records.removeWhere((item) => item.id == record.id);
        _existingPaths.remove(record.outputPath);
      });
      showPendingSnackBar(
        context,
        message: fileExists ? '文件和记录已删除' : '失效记录已删除',
      );
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
}

class _HistoryRecordCard extends StatelessWidget {
  const _HistoryRecordCard({
    required this.record,
    required this.fileExists,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final ConversionRecord record;
  final bool fileExists;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.outputName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(record.type.label),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${record.operation} · ${record.outputDisplaySize} · '
            '${_formatDate(record.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            fileExists ? record.outputPath : '文件已不存在：${record.outputPath}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: fileExists ? null : const Color(0xFFB91C1C),
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: fileExists ? onOpen : null,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开'),
              ),
              OutlinedButton.icon(
                onPressed: fileExists ? onShare : null,
                icon: const Icon(Icons.share_outlined),
                label: const Text('发送原文件'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(fileExists ? '删除文件' : '删除记录'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: Color(0xFF6B7280),
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            '暂无转换记录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '完成转换后会显示在这里',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
