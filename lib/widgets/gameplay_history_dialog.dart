import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/game_state.dart';
import '../models/gameplay_system.dart';
import '../services/gameplay_history_service.dart';
import '../services/gameplay_turn_engine.dart';
import 'chat_message_bubble.dart';

/// A read-only view of one branch. The service returns visibility-safe entries.
class GameplayHistoryDialog extends StatefulWidget {
  const GameplayHistoryDialog({
    super.key,
    required this.system,
    required this.state,
    required this.messages,
    required this.path,
    required this.storyName,
    this.backstage = false,
  });

  final GameplaySystem system;
  final GameStateSnapshot state;
  final List<ChatMessage> messages;
  final String path;
  final String storyName;
  final bool backstage;

  @override
  State<GameplayHistoryDialog> createState() => _GameplayHistoryDialogState();
}

class _GameplayHistoryDialogState extends State<GameplayHistoryDialog> {
  int _limit = 10;
  late List<GameplayVariableHistoryEntry> _entries = _readEntries();

  List<GameplayVariableHistoryEntry> _readEntries() =>
      GameplayHistoryService.forVariable(
        messages: widget.messages,
        currentSystem: widget.system,
        currentState: widget.state,
        path: widget.path,
        limit: _limit + 1,
        reveal: widget.backstage,
      );

  @override
  void didUpdateWidget(covariant GameplayHistoryDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages != widget.messages ||
        oldWidget.state != widget.state ||
        oldWidget.system != widget.system ||
        oldWidget.path != widget.path ||
        oldWidget.backstage != widget.backstage) {
      _limit = 10;
      _entries = _readEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final variable = widget.system.variableFor(widget.path);
    final values = {
      ...widget.system.initialValues(),
      ...widget.state.customVariables
    };
    final visible = variable != null &&
        variable.visibility != GameplayVariableVisibility.engine &&
        (widget.backstage ||
            (variable.isPlayerFacing &&
                GameplayTurnEngine.matches(
                    conditions: variable.revealWhen, values: values)));
    final entries = visible
        ? _entries.take(_limit).toList()
        : const <GameplayVariableHistoryEntry>[];
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      title: Text(visible ? '${variable.label} · 变化记录' : '变化记录'),
      content: SizedBox(
        width: math.min(720, math.max(260, size.width - 76)),
        height: math.min(680, math.max(180, size.height - 200)),
        child: !visible
            ? const Text('当前没有可查看的状态。')
            : ListView(
                key: const ValueKey('gameplay-history-list'),
                children: [
                  Text(widget.storyName,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 12),
                  Text(
                      '当前 · ${variable.displayValue(values[widget.path], reveal: widget.backstage)}',
                      style: Theme.of(context).textTheme.titleLarge),
                  if ((widget.backstage
                          ? variable.description
                          : variable.playerHint)
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(widget.backstage
                        ? variable.description
                        : variable.playerHint),
                  ],
                  const SizedBox(height: 16),
                  if (entries.isEmpty)
                    const Text('还没有可回溯的变化。继续剧情后，新变化会记录在这里；较早的存档可能没有完整记录。'),
                  for (final entry in entries) _entryCard(entry),
                  if (_entries.length > _limit)
                    OutlinedButton.icon(
                      key: const ValueKey('gameplay-history-more'),
                      onPressed: () => setState(() {
                        _limit += 10;
                        _entries = _readEntries();
                      }),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('查看更早记录'),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'))
      ],
    );
  }

  Widget _entryCard(GameplayVariableHistoryEntry entry) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${entry.turn > 0 ? '第 ${entry.turn} 回合 · ' : ''}${_date(entry.timestamp)}',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text('${entry.beforeText} → ${entry.afterText}',
                  style: Theme.of(context).textTheme.titleMedium),
              if (entry.definitionChanged) ...[
                const SizedBox(height: 6),
                Text('按当时的「${entry.label}」设定记录',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Text(entry.reason.isNotEmpty ? entry.reason : '这一回合没有记录具体原因。'),
              if (entry.legacy) ...[
                const SizedBox(height: 6),
                Text('来自旧存档的状态对比，仅展示能确认的变化。',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              if (entry.steps.length > 1)
                ExpansionTile(
                  key: ValueKey(
                      'history-steps-${entry.messageId}-${entry.path}'),
                  tilePadding: EdgeInsets.zero,
                  title: Text('本轮 ${entry.steps.length} 项变化明细'),
                  children: [
                    for (final step in entry.steps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${step.beforeText} → ${step.afterText}'),
                        subtitle:
                            Text(step.reason.isEmpty ? '未记录具体原因' : step.reason),
                      ),
                  ],
                ),
              const SizedBox(height: 4),
              TextButton.icon(
                key: ValueKey('history-source-${entry.messageId}'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => GameplaySourceDialog(
                    messages: widget.messages,
                    messageId: entry.messageId,
                    storyName: widget.storyName,
                  ),
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('查看对应剧情'),
              ),
            ],
          ),
        ),
      );
}

/// Opens the original branch message, with adjacent narrative turns for context.
/// State blocks remain hidden by the app's regular message renderer.
class GameplaySourceDialog extends StatefulWidget {
  const GameplaySourceDialog({
    super.key,
    required this.messages,
    required this.messageId,
    required this.storyName,
  });
  final List<ChatMessage> messages;
  final String messageId;
  final String storyName;

  @override
  State<GameplaySourceDialog> createState() => _GameplaySourceDialogState();
}

class _GameplaySourceDialogState extends State<GameplaySourceDialog> {
  late int _index =
      widget.messages.indexWhere((item) => item.id == widget.messageId);

  int _adjacent(int direction) {
    for (var cursor = _index + direction;
        cursor >= 0 && cursor < widget.messages.length;
        cursor += direction) {
      if (widget.messages[cursor].role == ChatRole.assistant) return cursor;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final message = _index >= 0 ? widget.messages[_index] : null;
    final previous = _adjacent(-1);
    final next = _adjacent(1);
    final preceding =
        _index > 0 && widget.messages[_index - 1].role == ChatRole.user
            ? widget.messages[_index - 1]
            : null;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      title: Text('${widget.storyName} · 剧情原文'),
      content: SizedBox(
        width: math.min(860, math.max(260, size.width - 68)),
        height: math.min(760, math.max(180, size.height - 220)),
        child: message == null
            ? const Text('对应消息已不在当前分支中。')
            : ListView(
                key: ValueKey('source-message-${message.id}'),
                children: [
                  Text(_date(message.timestamp),
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  if (preceding != null) ...[
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('本轮行动'),
                      children: [
                        ChatMessageBubble(
                            message: preceding,
                            assistantName: widget.storyName),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  ChatMessageBubble(
                      message: message, assistantName: widget.storyName),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed:
                previous < 0 ? null : () => setState(() => _index = previous),
            child: const Text('上一回合')),
        TextButton(
            onPressed: next < 0 ? null : () => setState(() => _index = next),
            child: const Text('下一回合')),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('返回记录')),
      ],
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} ${pad(local.hour)}:${pad(local.minute)}';
}
