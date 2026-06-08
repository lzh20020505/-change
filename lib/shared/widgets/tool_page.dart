import 'package:flutter/material.dart';

import '../../core/models/selected_file_info.dart';
import '../../core/models/processed_file_result.dart';

class ToolPage extends StatelessWidget {
  const ToolPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.children,
    this.bottomBar,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: bottomBar,
              ),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ToolHeader(
              title: title,
              description: description,
              icon: icon,
              color: color,
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ToolHeader extends StatelessWidget {
  const ToolHeader({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ToolSection extends StatelessWidget {
  const ToolSection({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF374151)),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class FileInputBox extends StatelessWidget {
  const FileInputBox({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF4B5563)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class PendingOutputBox extends StatelessWidget {
  const PendingOutputBox({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open_outlined, color: Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class SelectedFileCard extends StatelessWidget {
  const SelectedFileCard({
    required this.file,
    super.key,
  });

  final SelectedFileInfo file;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FileInfoRow(label: '文件名', value: file.name),
          const SizedBox(height: 8),
          _FileInfoRow(label: '路径', value: file.displayPath),
          const SizedBox(height: 8),
          _FileInfoRow(label: '大小', value: file.displaySize),
        ],
      ),
    );
  }
}

class SelectedFileList extends StatelessWidget {
  const SelectedFileList({
    required this.files,
    super.key,
  });

  final List<SelectedFileInfo> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: files.map((file) {
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SelectedFileCard(file: file),
        );
      }).toList(),
    );
  }
}

class SimulationResultBox extends StatelessWidget {
  const SimulationResultBox({
    required this.result,
    super.key,
  });

  final String? result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            result == null ? const Color(0xFFF9FAFB) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result == null
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result == null
                ? Icons.hourglass_empty_rounded
                : Icons.check_circle_outline,
            color: result == null
                ? const Color(0xFF6B7280)
                : const Color(0xFF047857),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result ?? '点击开始处理后显示结果',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessedResultList extends StatelessWidget {
  const ProcessedResultList({
    required this.results,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
    super.key,
  });

  final List<ProcessedFileResult> results;
  final ValueChanged<ProcessedFileResult> onOpen;
  final ValueChanged<ProcessedFileResult> onShare;
  final ValueChanged<ProcessedFileResult> onDelete;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const SimulationResultBox(result: null);
    }

    return Column(
      children: results.map((result) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.outputName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '${result.outputDisplaySize} · ${result.sizeChangeDescription}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(
                result.outputPath,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onOpen(result),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('打开'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onShare(result),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('发送原文件'),
                  ),
                  TextButton.icon(
                    onPressed: () => onDelete(result),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('删除'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FileInfoRow extends StatelessWidget {
  const _FileInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class OptionChips extends StatelessWidget {
  const OptionChips({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        return ChoiceChip(
          label: Text(option),
          selected: selected == option,
          onSelected: onChanged == null ? null : (_) => onChanged!(option),
        );
      }).toList(),
    );
  }
}

void showPendingSnackBar(
  BuildContext context, {
  String message = '功能逻辑待接入',
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<bool> confirmResultDeletion(
  BuildContext context, {
  required String fileName,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('删除结果文件'),
            content: Text('确定删除“$fileName”吗？此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          );
        },
      ) ??
      false;
}
