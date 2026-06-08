import 'package:flutter/material.dart';

import '../../../core/app_info.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/active_task_service.dart';
import '../../../core/services/conversion_history_service.dart';
import '../../app_info/presentation/app_info_page.dart';
import '../data/conversion_features.dart';
import 'widgets/feature_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _historyService = ConversionHistoryService();
  final _activeTaskService = ActiveTaskService.instance;

  List<ConversionRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final records = await _historyService.loadRecords();
      if (mounted) {
        setState(() => _records = records);
      }
    } on Object {
      if (mounted) {
        setState(() => _records = []);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(AppInfo.name,
                              style: textTheme.headlineMedium),
                        ),
                        IconButton(
                          tooltip: '关于',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AppInfoPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '本地优先的轻量转换工具',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<ActiveTaskState?>(
                      valueListenable: _activeTaskService.state,
                      builder: (context, task, _) {
                        return _HomeStatusCard(
                          task: task,
                          records: _records,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid.builder(
                itemCount: conversionFeatures.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 156,
                ),
                itemBuilder: (context, index) {
                  final feature = conversionFeatures[index];
                  return FeatureCard(
                    feature: feature,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: feature.pageBuilder,
                        ),
                      );
                      await _loadSummary();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeStatusCard extends StatelessWidget {
  const _HomeStatusCard({
    required this.task,
    required this.records,
  });

  final ActiveTaskState? task;
  final List<ConversionRecord> records;

  @override
  Widget build(BuildContext context) {
    final audioCount = records
        .where((record) => record.type == ConversionRecordType.audio)
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: task == null
          ? Row(
              children: [
                const Icon(Icons.task_alt_rounded, color: Color(0xFF047857)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '当前空闲 · 共 ${records.length} 条记录 · 音频 $audioCount 条',
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task!.isCancelling ? '正在取消任务' : task!.title),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: task!.progress),
              ],
            ),
    );
  }
}
