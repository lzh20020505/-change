import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/conversion_record.dart';
import '../../../core/models/processed_file_result.dart';
import '../../../core/models/selected_file_info.dart';
import '../../../core/services/active_task_service.dart';
import '../../../core/services/audio_processing_service.dart';
import '../../../core/services/conversion_history_service.dart';
import '../../../core/services/file_action_service.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/services/output_directory_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../shared/widgets/tool_page.dart';

class VideoExtractAudioPage extends StatefulWidget {
  const VideoExtractAudioPage({super.key});

  @override
  State<VideoExtractAudioPage> createState() => _VideoExtractAudioPageState();
}

class _VideoExtractAudioPageState extends State<VideoExtractAudioPage> {
  final _filePickerService = FilePickerService();
  final _outputDirectoryService = OutputDirectoryService();
  final _permissionService = PermissionService();
  final _audioProcessingService = AudioProcessingService();
  final _historyService = ConversionHistoryService();
  final _fileActionService = FileActionService();
  final _activeTaskService = ActiveTaskService.instance;

  SelectedFileInfo? _selectedFile;
  AudioOutputFormat _format = AudioOutputFormat.mp3;
  int _bitrateKbps = 192;
  int _sampleRate = 44100;
  bool _isProcessing = false;
  bool _isCancelling = false;
  double _progress = 0;
  ProcessedFileResult? _result;
  StreamSubscription<AudioProgress>? _progressSubscription;

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickFile() async {
    await _permissionService.ensureFilePickerAccess();
    final file = await _filePickerService.pickVideoFile();
    if (!mounted || file == null) {
      return;
    }

    if (file.path == null || file.path!.trim().isEmpty) {
      showPendingSnackBar(context, message: '无法读取所选视频的本地路径');
      return;
    }
    if (file.sizeBytes <= 0) {
      showPendingSnackBar(context, message: '所选视频是空文件');
      return;
    }
    if (file.sizeBytes > AudioProcessingService.maxInputSizeBytes) {
      showPendingSnackBar(context, message: '暂不处理超过 4 GB 的视频');
      return;
    }

    if (file.sizeBytes > AudioProcessingService.largeFileWarningBytes) {
      final confirmed = await _confirmLargeFile(file);
      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() {
      _selectedFile = file;
      _result = null;
      _progress = 0;
    });
  }

  Future<void> _extractAudio() async {
    final selectedFile = _selectedFile;
    final inputPath = selectedFile?.path;
    if (selectedFile == null) {
      showPendingSnackBar(context, message: '请先选择视频');
      return;
    }
    if (inputPath == null || inputPath.isEmpty) {
      showPendingSnackBar(context, message: '无法读取所选视频的本地路径');
      return;
    }

    setState(() {
      _isProcessing = true;
      _isCancelling = false;
      _progress = 0;
      _result = null;
    });
    _activeTaskService.start('正在从 ${selectedFile.name} 提取音频');
    await _progressSubscription?.cancel();
    _progressSubscription = _audioProcessingService.progressStream.listen(
      (progress) {
        if (!mounted) {
          return;
        }
        setState(() => _progress = progress.progress);
        _activeTaskService.updateProgress(progress.progress);
      },
    );

    try {
      final outputDirectory = await _outputDirectoryService.getOutputDirectory(
        OutputDirectoryType.audio,
      );
      final result = await _audioProcessingService.extractAudio(
        inputPath: inputPath,
        outputDirectory: outputDirectory.path,
        format: _format,
        bitrateKbps: _bitrateKbps,
        sampleRate: _sampleRate,
      );
      final historySaved = await _saveHistory(result, inputPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _progress = 1;
      });
      showPendingSnackBar(
        context,
        message: historySaved ? '音频提取完成' : '音频提取完成，但记录保存失败',
      );
    } on AudioProcessingException catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: error.message);
      }
    } catch (error) {
      if (mounted) {
        showPendingSnackBar(context, message: '音频提取失败：$error');
      }
    } finally {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      _activeTaskService.finish();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _cancelExtraction() async {
    if (!_isProcessing || _isCancelling) {
      return;
    }
    setState(() => _isCancelling = true);
    _activeTaskService.markCancelling();
    try {
      await _audioProcessingService.cancel();
    } on AudioProcessingException catch (error) {
      if (mounted) {
        setState(() => _isCancelling = false);
        showPendingSnackBar(context, message: error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return PopScope(
      canPop: !_isProcessing,
      child: ToolPage(
        title: '视频提取音频',
        description: '使用本地 FFmpeg 单线程提取音频，不上传文件。',
        icon: Icons.audiotrack_outlined,
        color: const Color(0xFF7C3AED),
        bottomBar: _isProcessing
            ? OutlinedButton.icon(
                onPressed: _isCancelling ? null : _cancelExtraction,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(_isCancelling ? '正在取消' : '取消任务'),
              )
            : FilledButton.icon(
                onPressed: _extractAudio,
                icon: const Icon(Icons.music_note_rounded),
                label: const Text('提取音频'),
              ),
        children: [
          ToolSection(
            title: '输入视频',
            icon: Icons.video_file_outlined,
            child: FileInputBox(
              title: _selectedFile?.name ?? '未选择视频',
              subtitle: '支持 MP4、MOV、MKV、AVI、WebM、3GP',
              icon: Icons.movie_outlined,
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
            title: '音频设置',
            icon: Icons.tune_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('格式', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                OptionChips(
                  options: AudioOutputFormat.values
                      .map((item) => item.label)
                      .toList(),
                  selected: _format.label,
                  onChanged: _isProcessing
                      ? null
                      : (value) => setState(() {
                            _format = AudioOutputFormat.values
                                .firstWhere((item) => item.label == value);
                            _result = null;
                          }),
                ),
                const SizedBox(height: 14),
                if (_format == AudioOutputFormat.wav) ...[
                  Text('采样率', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  OptionChips(
                    options: const ['44100 Hz', '48000 Hz'],
                    selected: '$_sampleRate Hz',
                    onChanged: _isProcessing
                        ? null
                        : (value) => setState(() {
                              _sampleRate = int.parse(value.split(' ').first);
                              _result = null;
                            }),
                  ),
                ] else ...[
                  Text('码率', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  OptionChips(
                    options: const ['128 kbps', '192 kbps', '320 kbps'],
                    selected: '$_bitrateKbps kbps',
                    onChanged: _isProcessing
                        ? null
                        : (value) => setState(() {
                              _bitrateKbps = int.parse(value.split(' ').first);
                              _result = null;
                            }),
                  ),
                ],
                const SizedBox(height: 12),
                const Text('为控制内存和发热，处理固定使用 1 个 FFmpeg 线程。'),
              ],
            ),
          ),
          if (_isProcessing)
            ToolSection(
              title: '任务进度',
              icon: Icons.hourglass_top_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 10),
                  Text(
                    _isCancelling
                        ? '正在停止任务并清理临时输出…'
                        : '已处理 ${(_progress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
          const ToolSection(
            title: '输出文件',
            icon: Icons.output_rounded,
            child: PendingOutputBox(label: '保存到 LiteConverter/Audio'),
          ),
          ToolSection(
            title: '处理结果',
            icon: Icons.task_alt_rounded,
            child: result == null
                ? const SimulationResultBox(result: null)
                : ProcessedResultList(
                    results: [result],
                    onOpen: _openResult,
                    onShare: _shareResult,
                    onDelete: _deleteResult,
                  ),
          ),
        ],
      ),
    );
  }

  Future<bool> _saveHistory(
    ProcessedFileResult result,
    String inputPath,
  ) async {
    try {
      await _historyService.addRecords([
        ConversionRecord.fromProcessedResult(
          result: result,
          type: ConversionRecordType.audio,
          operation: '视频提取 ${_format.label}',
          inputPaths: [inputPath],
          createdAt: DateTime.now(),
        ),
      ]);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _openResult(ProcessedFileResult result) async {
    await _runFileAction(() => _fileActionService.openFile(result.outputPath));
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
      await _historyService.deleteRecordsForOutput(result.outputPath);
      if (!mounted) {
        return;
      }
      setState(() => _result = null);
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

  Future<bool> _confirmLargeFile(SelectedFileInfo file) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('处理大文件'),
              content: Text(
                '${file.name} 大小为 ${file.displaySize}。处理可能耗时较长并明显发热，建议保持充足电量。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('继续'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
