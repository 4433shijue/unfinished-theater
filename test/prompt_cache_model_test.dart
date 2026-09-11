import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/prompt_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cache epoch and exact provider replay survive history serialization',
      () {
    final history = DialogueHistory(
      characterId: 'character-1',
      messages: <ChatMessage>[
        ChatMessage(
          id: 'assistant-1',
          role: ChatRole.assistant,
          content: '渲染后的内容',
          timestamp: DateTime(2026, 8, 8),
          isSummarized: false,
          promptReplayContent: '压缩回放',
          providerReplayContent: '供应商原始内容',
          providerReplayExact: true,
        ),
      ],
      promptCacheEpoch: PromptCacheEpoch(
        id: 'epoch-1',
        startMessageId: 'user-1',
        createdAt: DateTime(2026, 8, 8),
        checkpoint: '阶段检查点',
        rolloverCount: 2,
        rolloverReason: 'message_limit',
        stablePrefixDigest: 'abc12345',
        previousPromptTokens: 1234,
        injectedMemorySummaryIds: const <String>['memory-1'],
        injectedWorldBookKeys: const <String>['world-1:v1'],
      ),
    );

    final restored = DialogueHistory.fromJson(history.toJson());
    expect(restored.promptCacheEpoch?.id, 'epoch-1');
    expect(restored.promptCacheEpoch?.checkpoint, '阶段检查点');
    expect(restored.promptCacheEpoch?.previousPromptTokens, 1234);
    expect(
      restored.promptCacheEpoch?.injectedMemorySummaryIds,
      const <String>['memory-1'],
    );
    expect(restored.messages.single.providerReplayContent, '供应商原始内容');
    expect(restored.messages.single.providerReplayExact, isTrue);
  });

  test('cache metric calculates hit rate and previous-prefix coverage', () {
    final metric = PromptCacheMetric(
      id: 'metric-1',
      characterId: 'character-1',
      recordedAt: DateTime(2026, 8, 8),
      model: 'deepseek-chat',
      endpointHost: 'api.deepseek.com',
      cacheEpochId: 'epoch-1',
      rolloverReason: 'warm_append',
      stablePrefixDigest: 'abc12345',
      estimatedPromptTokens: 1600,
      messageCount: 5,
      usedExactAssistantReplay: true,
      previousPromptTokens: 1000,
      inputTokens: 1250,
      outputTokens: 200,
      cacheHitTokens: 800,
      cacheMissTokens: 450,
    );

    expect(metric.cacheHitRate, 64);
    expect(metric.previousPromptCoverage, 80);
    expect(PromptCacheMetric.fromJson(metric.toJson()).cacheHitRate, 64);
  });
}
