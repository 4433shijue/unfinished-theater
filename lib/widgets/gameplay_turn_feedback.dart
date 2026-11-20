import '../models/turn_settlement.dart';
import 'turn_settlement_dialog.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';

/// Reads only the player-facing settlement saved with this particular reply.
class GameplayTurnFeedback extends StatelessWidget {
  const GameplayTurnFeedback({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  final ChatMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    if (isStreaming || message.role != ChatRole.assistant) {
      return const SizedBox.shrink();
    }
    final settlement = TurnSettlement.of(message);
    if (settlement != null) {
      final entries =
          settlement.entries.where((e) => e['visibility'] == 'public').toList();
      bool important(Map<String, dynamic> e) =>
          e['category'] == '人物状态' ||
          (e['category'] == '任务' && e['after'] == '已完成') ||
          (e['category'] == '承诺与伏笔' && ['已兑现', '已失约'].contains(e['after']));
      entries.sort(
          (a, b) => (important(b) ? 1 : 0).compareTo(important(a) ? 1 : 0));
      final emphasis = !settlement.complete || entries.any(important);
      String label(Map<String, dynamic> e) {
        final delta = e['delta'];
        if (delta is num) return '${e['label']} ${delta > 0 ? '+' : ''}$delta';
        return '${e['label']}${e['after'] == null ? '' : ' · ${e['after']}'}';
      }

      return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
              decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: emphasis ? .12 : .04),
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                  dense: true,
                  leading: Icon(!settlement.complete
                      ? Icons.error_outline
                      : emphasis
                          ? Icons.auto_awesome
                          : Icons.receipt_long),
                  title: Text(settlement.complete
                      ? entries.isEmpty
                          ? '本回合没有公开状态变化'
                          : entries.take(2).map(label).join(' · ')
                      : '结算未完成 · 重试或回退'),
                  subtitle: Text(settlement.complete
                      ? '查看全部 · ${entries.length} 项变化'
                      : settlement.error),
                  onTap: () => showTurnSettlement(context, settlement))));
    }
    final raw = message.gameStateSnapshot?['gameplayPlayerVariableChanges'];
    final changes = raw is List
        ? raw
            .whereType<String>()
            .where((item) => item.trim().isNotEmpty)
            .toList()
        : const <String>[];
    if (changes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          key: ValueKey('gameplay-feedback-${message.id}'),
          leading: const Icon(Icons.auto_awesome_outlined, size: 20),
          title: const Text('这一回合的变化'),
          subtitle: Text(
            changes.take(2).join('\n'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final change in changes)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(change),
              ),
          ],
        ),
      ),
    );
  }
}
