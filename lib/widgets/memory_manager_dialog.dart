import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/character_memory.dart';
import '../theme/app_theme.dart';

Future<void> showMemoryManagerDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _MemoryManagerDialog(),
  );
}

class _MemoryManagerDialog extends StatelessWidget {
  const _MemoryManagerDialog();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final character = controller.currentCharacter;
    final memory = controller.currentMemory;
    final summaries = memory.summaries.reversed.toList(growable: false);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppTheme.glitchText('长期记忆库'),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.textMain,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppTheme.glitchText(
                            character == null
                                ? '当前没有选中角色。'
                                : '${character.name} · ${summaries.length} 条${AppTheme.glitchText('长期记忆')}',
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: AppTheme.glitchText('新增记忆'),
                    onPressed:
                        character == null ? null : () => _addMemory(context),
                    icon: const Icon(Icons.add_rounded),
                  ),
                  IconButton(
                    tooltip: AppTheme.glitchText('关闭'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: summaries.isEmpty
                    ? const _MemoryEmptyState()
                    : ListView.separated(
                        itemCount: summaries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final summary = summaries[index];
                          return _MemorySummaryCard(
                            summary: summary,
                            index: summaries.length - index,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMemory(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _MemoryEditDialog(
        initialText: '',
        title: '新增记忆',
        actionLabel: '添加',
      ),
    );
    if (text == null || !context.mounted) {
      return;
    }
    final error =
        await context.read<AppStateController>().addMemorySummary(text);
    if (!context.mounted) {
      return;
    }
    _showMemoryNotice(
      context,
      error ?? '长期记忆已添加。',
      isError: error != null,
    );
  }
}

class _MemoryEmptyState extends StatelessWidget {
  const _MemoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.panel.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.activeLine),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_stories_outlined,
              color: AppTheme.activeSoft,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              AppTheme.glitchText('还没有长期记忆'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textMain,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText(
                '聊到一定消息量后，系统会自动把关键内容整理到这里。',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemorySummaryCard extends StatelessWidget {
  const _MemorySummaryCard({
    required this.summary,
    required this.index,
  });

  final CharacterMemorySummary summary;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panel.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.activeLine),
        boxShadow: [
          BoxShadow(
            color: AppTheme.activeAccent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  '${AppTheme.glitchText('长期记忆')} $index · ${_formatMemoryTime(summary.timestamp)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton.filledTonal(
                style: AppTheme.skinIconButtonStyle(),
                tooltip:
                    '${AppTheme.glitchText('编辑')}${AppTheme.glitchText('记忆')}',
                onPressed: () => _editMemory(context, summary),
                icon: const Icon(Icons.edit_rounded, size: 18),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                style: AppTheme.skinIconButtonStyle(),
                tooltip:
                    '${AppTheme.glitchText('删除')}${AppTheme.glitchText('记忆')}',
                onPressed: () => _deleteMemory(context, summary),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary.summaryText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMain,
                  height: 1.65,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMemory(
    BuildContext context,
    CharacterMemorySummary summary,
  ) async {
    final nextText = await showDialog<String>(
      context: context,
      builder: (context) => _MemoryEditDialog(initialText: summary.summaryText),
    );
    if (nextText == null || !context.mounted) {
      return;
    }
    final error = await context
        .read<AppStateController>()
        .updateMemorySummary(summary.id, nextText);
    if (!context.mounted) {
      return;
    }
    _showMemoryNotice(
      context,
      error ?? '长期记忆已更新。',
      isError: error != null,
    );
  }

  Future<void> _deleteMemory(
    BuildContext context,
    CharacterMemorySummary summary,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _MemoryDeleteDialog(summary: summary),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final error = await context
        .read<AppStateController>()
        .deleteMemorySummary(summary.id);
    if (!context.mounted) {
      return;
    }
    _showMemoryNotice(
      context,
      error ?? '这条长期记忆已经删除。',
      isError: error != null,
    );
  }
}

class _MemoryEditDialog extends StatefulWidget {
  const _MemoryEditDialog({
    required this.initialText,
    this.title = '编辑记忆',
    this.actionLabel = '保存',
  });

  final String initialText;
  final String title;
  final String actionLabel;

  @override
  State<_MemoryEditDialog> createState() => _MemoryEditDialogState();
}

class _MemoryEditDialogState extends State<_MemoryEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppTheme.glitchText(widget.title),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textMain,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: '${AppTheme.glitchText('记忆')}内容',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppTheme.glitchText('取消')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text.trim()),
                    child: Text(AppTheme.glitchText(widget.actionLabel)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryDeleteDialog extends StatelessWidget {
  const _MemoryDeleteDialog({required this.summary});

  final CharacterMemorySummary summary;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${AppTheme.glitchText('删除')}${AppTheme.glitchText('记忆')}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textMain,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                AppTheme.glitchText('真的要删掉这条长期记忆吗？删除后不会影响原聊天记录。'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.panel.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.activeLine),
                ),
                child: Text(
                  summary.summaryText,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMain,
                        height: 1.5,
                      ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(AppTheme.glitchText('否')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(AppTheme.glitchText('是，删除')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatMemoryTime(DateTime timestamp) {
  final local = timestamp.toLocal();
  return '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

void _showMemoryNotice(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.activeAccent,
        content: Text(AppTheme.glitchText(message)),
      ),
    );
}
