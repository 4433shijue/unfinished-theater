import 'chat_message.dart';
import 'prompt_cache.dart';

class DialogueHistory {
  const DialogueHistory({
    required this.characterId,
    required this.messages,
    this.promptCacheEpoch,
    this.replayNeedsMigration = false,
  });

  factory DialogueHistory.empty(String characterId) {
    return DialogueHistory(characterId: characterId, messages: const []);
  }

  factory DialogueHistory.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List? ?? const [];
    final migrateReplay = json['replayProtocolVersion'] != 2;

    return DialogueHistory(
      replayNeedsMigration: migrateReplay,
      characterId: json['characterId']?.toString() ?? '',
      messages: rawMessages.whereType<Map>().map((item) {
        final message = ChatMessage.fromJson(Map<String, dynamic>.from(item));
        return migrateReplay
            ? message.copyWith(
                clearPromptReplayContent: true,
                clearProviderReplayContent: true,
                providerReplayExact: false)
            : message;
      }).toList(),
      promptCacheEpoch: !migrateReplay && json['promptCacheEpoch'] is Map
          ? PromptCacheEpoch.fromJson(
              Map<String, dynamic>.from(json['promptCacheEpoch'] as Map),
            )
          : null,
    );
  }

  final bool replayNeedsMigration;
  final String characterId;
  final List<ChatMessage> messages;
  final PromptCacheEpoch? promptCacheEpoch;

  DialogueHistory copyWith({
    String? characterId,
    List<ChatMessage>? messages,
    PromptCacheEpoch? promptCacheEpoch,
    bool clearPromptCacheEpoch = false,
  }) {
    return DialogueHistory(
      replayNeedsMigration: replayNeedsMigration,
      characterId: characterId ?? this.characterId,
      messages: messages ?? this.messages,
      promptCacheEpoch: clearPromptCacheEpoch
          ? null
          : promptCacheEpoch ?? this.promptCacheEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'replayProtocolVersion': 2,
      'characterId': characterId,
      'messages': messages.map((message) => message.toJson()).toList(),
      if (promptCacheEpoch != null)
        'promptCacheEpoch': promptCacheEpoch!.toJson(),
    };
  }
}
