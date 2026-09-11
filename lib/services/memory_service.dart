import '../models/app_settings.dart';
import '../models/character_memory.dart';
import '../models/character_profile.dart';
import '../models/dialogue_history.dart';
import '../utils/id_generator.dart';
import 'llm_api_client.dart';

class MemorySummarizationResult {
  const MemorySummarizationResult({
    required this.history,
    required this.memory,
    required this.summarizedMessageIds,
    required this.newSummary,
  });

  final DialogueHistory history;
  final CharacterMemory memory;
  final List<String> summarizedMessageIds;
  final CharacterMemorySummary newSummary;

  MemorySummarizationResult rebaseOnto({
    required DialogueHistory currentHistory,
    required CharacterMemory currentMemory,
  }) {
    final currentMessageIds =
        currentHistory.messages.map((message) => message.id).toSet();
    final retainedIds = summarizedMessageIds
        .where(currentMessageIds.contains)
        .toList(growable: false);
    if (retainedIds.isEmpty) {
      return MemorySummarizationResult(
        history: currentHistory,
        memory: currentMemory,
        summarizedMessageIds: const <String>[],
        newSummary: newSummary.copyWith(relatedMessageIds: const <String>[]),
      );
    }

    final retainedIdSet = retainedIds.toSet();
    final mergedHistory = currentHistory.copyWith(
      messages: currentHistory.messages
          .map(
            (message) => retainedIdSet.contains(message.id)
                ? message.copyWith(isSummarized: true)
                : message,
          )
          .toList(growable: false),
    );
    final alreadyPresent = currentMemory.summaries.any(
      (summary) => summary.id == newSummary.id,
    );
    final mergedMemory = alreadyPresent
        ? currentMemory
        : currentMemory.copyWith(
            summaries: <CharacterMemorySummary>[
              ...currentMemory.summaries,
              newSummary.copyWith(relatedMessageIds: retainedIds),
            ],
          );
    return MemorySummarizationResult(
      history: mergedHistory,
      memory: mergedMemory,
      summarizedMessageIds: retainedIds,
      newSummary: newSummary.copyWith(relatedMessageIds: retainedIds),
    );
  }
}

class MemoryService {
  Future<MemorySummarizationResult?> maybeSummarize({
    required AppSettings settings,
    required CharacterProfile character,
    required DialogueHistory history,
    required CharacterMemory memory,
    required LlmApiClient apiClient,
  }) async {
    final summarySettings = settings.memorySettingsOrFallback();
    if (!summarySettings.canChat) {
      return null;
    }

    final pendingMessages =
        history.messages.where((message) => !message.isSummarized).toList();

    if (pendingMessages.length < settings.autoSummaryMinMessages) {
      return null;
    }

    final summaryText = await apiClient.summarizeConversation(
      settings: summarySettings,
      character: character,
      messages: pendingMessages,
    );

    if (summaryText.trim().isEmpty) {
      return null;
    }

    final relatedIds = pendingMessages.map((message) => message.id).toSet();
    final updatedHistory = history.copyWith(
      messages: history.messages
          .map(
            (message) => relatedIds.contains(message.id)
                ? message.copyWith(isSummarized: true)
                : message,
          )
          .toList(),
    );

    final newSummary = CharacterMemorySummary(
      id: IdGenerator.summary(),
      summaryText: summaryText.trim(),
      relatedMessageIds: relatedIds.toList(),
      timestamp: DateTime.now(),
    );
    final updatedMemory = memory.copyWith(
      summaries: <CharacterMemorySummary>[
        ...memory.summaries,
        newSummary,
      ],
    );

    return MemorySummarizationResult(
      history: updatedHistory,
      memory: updatedMemory,
      summarizedMessageIds: relatedIds.toList(growable: false),
      newSummary: newSummary,
    );
  }
}
