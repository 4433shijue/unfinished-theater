import 'package:ai_roleplay_chat/models/character_memory.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stale summary marks matching messages without replacing newer turns',
      () {
    final oldMessage = ChatMessage(
      id: 'old',
      role: ChatRole.user,
      content: '旧消息',
      timestamp: DateTime(2026),
      isSummarized: false,
    );
    final newMessage = ChatMessage(
      id: 'new',
      role: ChatRole.user,
      content: '总结请求发出后新增的消息',
      timestamp: DateTime(2026, 1, 2),
      isSummarized: false,
    );
    final summary = CharacterMemorySummary(
      id: 'summary-new',
      summaryText: '旧消息摘要',
      relatedMessageIds: const <String>['old'],
      timestamp: DateTime(2026, 1, 3),
    );
    final staleResult = MemorySummarizationResult(
      history: DialogueHistory(
        characterId: 'char',
        messages: <ChatMessage>[
          oldMessage.copyWith(isSummarized: true),
        ],
      ),
      memory: CharacterMemory(
        characterId: 'char',
        summaries: <CharacterMemorySummary>[summary],
      ),
      summarizedMessageIds: const <String>['old'],
      newSummary: summary,
    );
    final existingSummary = CharacterMemorySummary(
      id: 'summary-existing',
      summaryText: '现有记忆',
      relatedMessageIds: const <String>['earlier'],
      timestamp: DateTime(2025),
    );

    final merged = staleResult.rebaseOnto(
      currentHistory: DialogueHistory(
        characterId: 'char',
        messages: <ChatMessage>[oldMessage, newMessage],
      ),
      currentMemory: CharacterMemory(
        characterId: 'char',
        summaries: <CharacterMemorySummary>[existingSummary],
      ),
    );

    expect(merged.history.messages, hasLength(2));
    expect(merged.history.messages.first.isSummarized, isTrue);
    expect(merged.history.messages.last.id, 'new');
    expect(merged.history.messages.last.isSummarized, isFalse);
    expect(
      merged.memory.summaries.map((item) => item.id),
      <String>['summary-existing', 'summary-new'],
    );
  });

  test('summary for messages deleted meanwhile is discarded', () {
    final summary = CharacterMemorySummary(
      id: 'summary-stale',
      summaryText: '不应复活的摘要',
      relatedMessageIds: const <String>['deleted'],
      timestamp: DateTime(2026),
    );
    final result = MemorySummarizationResult(
      history: DialogueHistory.empty('char'),
      memory: CharacterMemory(
        characterId: 'char',
        summaries: <CharacterMemorySummary>[summary],
      ),
      summarizedMessageIds: const <String>['deleted'],
      newSummary: summary,
    );

    final merged = result.rebaseOnto(
      currentHistory: DialogueHistory.empty('char'),
      currentMemory: CharacterMemory.empty('char'),
    );

    expect(merged.summarizedMessageIds, isEmpty);
    expect(merged.memory.summaries, isEmpty);
  });
}
