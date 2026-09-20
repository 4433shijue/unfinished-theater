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
