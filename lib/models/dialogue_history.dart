import 'chat_message.dart';
import 'prompt_cache.dart';

class DialogueHistory {
  const DialogueHistory({
    required this.characterId,
    required this.messages,
    this.promptCacheEpoch,
  });

  factory DialogueHistory.empty(String characterId) {
    return DialogueHistory(characterId: characterId, messages: const []);
  }

  factory DialogueHistory.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List? ?? const [];

    return DialogueHistory(
      characterId: json['characterId']?.toString() ?? '',
      messages: rawMessages
          .whereType<Map>()
          .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      promptCacheEpoch: json['promptCacheEpoch'] is Map
          ? PromptCacheEpoch.fromJson(
              Map<String, dynamic>.from(json['promptCacheEpoch'] as Map),
            )
          : null,
    );
  }

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
      characterId: characterId ?? this.characterId,
      messages: messages ?? this.messages,
      promptCacheEpoch: clearPromptCacheEpoch
          ? null
          : promptCacheEpoch ?? this.promptCacheEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'characterId': characterId,
      'messages': messages.map((message) => message.toJson()).toList(),
      if (promptCacheEpoch != null)
        'promptCacheEpoch': promptCacheEpoch!.toJson(),
    };
  }
}
