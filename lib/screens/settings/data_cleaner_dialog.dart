part of '../settings_screen.dart';

class _DataCleanerDialog extends StatefulWidget {
  const _DataCleanerDialog();

  @override
  State<_DataCleanerDialog> createState() => _DataCleanerDialogState();
}

class _DataCleanerDialogState extends State<_DataCleanerDialog> {
  late Future<DataStorageReport> _reportFuture;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _reportFuture = context.read<AppStateController>().buildDataStorageReport();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final controller = context.watch<AppStateController>();
    final healthReport = controller.dataHealthReport;
    final quarantined = controller.quarantinedDataRecords;
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(AppTheme.glitchText('数据保险箱')),
      content: SizedBox(
        width: min(size.width * 0.9, 720),
        child: FutureBuilder<DataStorageReport>(
          future: _reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final report = snapshot.data;
            if (report == null) {
              return const _SoftSettingsLine(
                icon: Icons.error_outline_rounded,
                text: '暂时没能读取数据体积。',
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText(
                    '当前游戏数据约 ${_formatBytes(report.totalBytes)}。损坏原文会先隔离保留，不会被空数据静默覆盖。这里也不会碰 C 盘开发缓存。',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                if (quarantined.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _QuarantinedDataPanel(
                    records: quarantined,
                    working: _working,
                    onCopy: _copyQuarantinedData,
                    onDownload: _downloadQuarantinedData,
                    onDelete: _deleteQuarantinedData,
                  ),
                ],
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: size.height * 0.34),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: report.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = report.items[index];
                      return _StorageReportTile(item: item);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _DataHealthPanel(
                  report: healthReport,
                  working: _working,
                  onRepair: healthReport.repairableCount == 0
                      ? null
                      : _runHealthRepair,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _runCleaner(
                                title: '清理剧情工具历史',
                                action: context
                                    .read<AppStateController>()
                                    .clearCurrentCharacterToolResults,
                              ),
                      icon: const Icon(Icons.auto_fix_high_outlined),
                      label: Text(AppTheme.glitchText('清剧情工具历史')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _runCleaner(
                                title: '清理历史同人文',
                                action: context
                                    .read<AppStateController>()
                                    .clearCurrentCharacterFanficResults,
                              ),
                      icon: const Icon(Icons.history_edu_outlined),
                      label: Text(AppTheme.glitchText('清历史同人文')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _runCleaner(
                                title: '清理地图 HTML 缓存',
                                action: context
                                    .read<AppStateController>()
                                    .clearCurrentMapHtmlCache,
                              ),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(AppTheme.glitchText('清地图 HTML 缓存')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _runCleaner(
                                title: '清理 NPC 私聊消息',
                                action: context
                                    .read<AppStateController>()
                                    .clearCurrentCharacterNpcMessages,
                              ),
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(AppTheme.glitchText('清 NPC 私聊')),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('关闭')),
        ),
      ],
    );
  }

  Future<void> _runHealthRepair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text(AppTheme.glitchText('一键修复存档健康问题')),
        content: Text(
          AppTheme.glitchText(
            '将移除断链绑定、无效快照和失效地图位置指针，不会清空正常聊天与角色数据。',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.healing_outlined),
            label: Text(AppTheme.glitchText('开始修复')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _working = true);
    final message =
        await context.read<AppStateController>().repairDataHealthIssues();
    if (!mounted) {
      return;
    }
    setState(() {
      _working = false;
      _reportFuture =
          context.read<AppStateController>().buildDataStorageReport();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText(message ?? '修复已完成。'))),
    );
  }

  Future<void> _copyQuarantinedData(QuarantinedDataRecord record) async {
    await Clipboard.setData(ClipboardData(text: record.rawValue));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('隔离原文已复制。')),
    );
  }

  Future<void> _downloadQuarantinedData(
    QuarantinedDataRecord record,
  ) async {
    final safeKey = record.storageKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final saved = await downloadTextFile(
      filename: 'wwjc_quarantine_${safeKey}_${record.id}.txt',
      content: record.rawValue,
      mimeType: 'text/plain;charset=utf-8',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? '隔离原文已导出。' : '导出失败，请稍后再试。')),
    );
  }

  Future<void> _deleteQuarantinedData(QuarantinedDataRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text(AppTheme.glitchText('删除隔离原文')),
        content: Text(
          AppTheme.glitchText('删除后无法从应用内恢复这份原始数据。建议先复制或导出后再删除。'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(AppTheme.glitchText('确认删除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _working = true);
    await context
        .read<AppStateController>()
        .deleteQuarantinedDataRecord(record.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _working = false;
      _reportFuture =
          context.read<AppStateController>().buildDataStorageReport();
    });
  }

  Future<void> _runCleaner({
    required String title,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text(AppTheme.glitchText(title)),
        content: Text(AppTheme.glitchText('确认执行这项清理吗？清理后本项历史不会再显示。')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTheme.glitchText('清理')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _working = true);
    await action();
    if (!mounted) {
      return;
    }
    await context.read<AppStateController>().noteDataCleanerRun();
    if (!mounted) {
      return;
    }
    setState(() {
      _working = false;
      _reportFuture =
          context.read<AppStateController>().buildDataStorageReport();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title 已完成。')),
    );
  }
}

class _QuarantinedDataPanel extends StatelessWidget {
  const _QuarantinedDataPanel({
    required this.records,
    required this.working,
    required this.onCopy,
    required this.onDownload,
    required this.onDelete,
  });

  final List<QuarantinedDataRecord> records;
  final bool working;
  final ValueChanged<QuarantinedDataRecord> onCopy;
  final ValueChanged<QuarantinedDataRecord> onDownload;
  final ValueChanged<QuarantinedDataRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTheme.glitchText('已隔离 ${records.length} 份损坏原文'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            AppTheme.glitchText('应用已停止使用这些内容。复制后可人工修复，确认不再需要时再删除。'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
          ),
          const SizedBox(height: 10),
          for (final record in records.take(6))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_storageKeyLabel(record.storageKey)} · '
                      '${_formatBytes(record.sizeBytes)} · '
                      '${record.detectedAt.toLocal().toString().split('.').first}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: AppTheme.glitchText('复制原文'),
                    onPressed: working ? null : () => onCopy(record),
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
                  IconButton(
                    tooltip: AppTheme.glitchText('导出原文'),
                    onPressed: working ? null : () => onDownload(record),
                    icon: const Icon(Icons.download_outlined),
                  ),
                  IconButton(
                    tooltip: AppTheme.glitchText('删除隔离原文'),
                    onPressed: working ? null : () => onDelete(record),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          if (records.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(AppTheme.glitchText('另有 ${records.length - 6} 份记录未展开。')),
            ),
        ],
      ),
    );
  }

  String _storageKeyLabel(String key) {
    if (key == 'characters') return '剧场列表';
    if (key.startsWith('history_')) return '聊天历史';
    if (key.startsWith('memory_')) return '长期记忆';
    if (key.startsWith('game_state_')) return '游戏状态';
    if (key.startsWith('map_state_')) return '地图状态';
    if (key.startsWith('npc_messages_')) return 'NPC 私聊';
    if (key.startsWith('turn_commit_')) return '剧情提交日志';
    return key;
  }
}

class _DataHealthPanel extends StatelessWidget {
  const _DataHealthPanel({
    required this.report,
    required this.working,
    required this.onRepair,
  });

  final DataHealthReport report;
  final bool working;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) {
    final topIssues = report.issues.take(5).toList(growable: false);
    final clean = report.isClean;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFillStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              clean ? AppTheme.activeLine : Theme.of(context).colorScheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                clean ? Icons.verified_outlined : Icons.health_and_safety,
                color: clean
                    ? AppTheme.activeSoft
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppTheme.glitchText(
                    clean
                        ? '存档健康检查 · 暂无异常'
                        : '存档健康检查 · ${report.issues.length} 个提醒',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: working ? null : onRepair,
                icon: working
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.healing_outlined),
                label: Text(
                  AppTheme.glitchText('一键修复 ${report.repairableCount}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppTheme.glitchText(
              clean
                  ? '已检查 NPC 绑定、世界书触发、快照、聊天缓存和地图位置指针。'
                  : '危险 ${report.dangerCount} · 警告 ${report.warningCount} · 可修复 ${report.repairableCount}',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          if (topIssues.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final issue in topIssues) _DataHealthIssueLine(issue: issue),
            if (report.issues.length > topIssues.length)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  AppTheme.glitchText(
                    '还有 ${report.issues.length - topIssues.length} 项已折叠。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textWeak,
                      ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DataHealthIssueLine extends StatelessWidget {
  const _DataHealthIssueLine({required this.issue});

  final DataHealthIssue issue;

  @override
  Widget build(BuildContext context) {
    final icon = switch (issue.severity) {
      DataHealthSeverity.danger => Icons.error_outline_rounded,
      DataHealthSeverity.warning => Icons.warning_amber_rounded,
      DataHealthSeverity.info => Icons.info_outline_rounded,
    };
    final color = switch (issue.severity) {
      DataHealthSeverity.danger => Theme.of(context).colorScheme.error,
      DataHealthSeverity.warning => Theme.of(context).colorScheme.tertiary,
      DataHealthSeverity.info => AppTheme.activeSoft,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText(issue.title),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.textMain,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppTheme.glitchText(issue.description),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
            ),
          ),
          if (issue.repairable)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Chip(
                label: Text(AppTheme.glitchText('可修')),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _StorageReportTile extends StatelessWidget {
  const _StorageReportTile({required this.item});

  final DataStorageReportItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.storage_outlined, color: AppTheme.activeSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${item.label} 路 ${_formatBytes(item.bytes)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textMain,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
