enum ChatRole {
  user,
  assistant,
}

extension ChatRoleX on ChatRole {
  static ChatRole fromValue(String? value) {
    return ChatRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => ChatRole.assistant,
    );
  }

  String get label {
    switch (this) {
      case ChatRole.user:
        return '你';
      case ChatRole.assistant:
        return '角色';
    }
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.isSummarized,
    this.isBookmarked = false,
    this.bookmarkNote = '',
    this.gameStateSnapshot,
    this.tokenEstimate,
    this.promptReplayContent,
    this.providerReplayContent,
    this.providerReplayExact = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: ChatRoleX.fromValue(json['role']?.toString()),
      content: json['content']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      isSummarized: json['isSummarized'] == true,
      isBookmarked: json['isBookmarked'] == true,
      bookmarkNote: json['bookmarkNote']?.toString() ?? '',
      gameStateSnapshot: json['gameStateSnapshot'] is Map
          ? Map<String, dynamic>.from(json['gameStateSnapshot'] as Map)
          : null,
      tokenEstimate: _readNullableInt(json['tokenEstimate']),
      promptReplayContent: json['promptReplayContent']?.toString(),
      providerReplayContent: json['providerReplayContent']?.toString(),
      providerReplayExact: json['providerReplayExact'] == true,
    );
  }

  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final bool isSummarized;
  final bool isBookmarked;
  final String bookmarkNote;
  final Map<String, dynamic>? gameStateSnapshot;
  final int? tokenEstimate;
  final String? promptReplayContent;
  final String? providerReplayContent;
  final bool providerReplayExact;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    bool? isSummarized,
    bool? isBookmarked,
    String? bookmarkNote,
    Map<String, dynamic>? gameStateSnapshot,
    bool clearGameStateSnapshot = false,
    int? tokenEstimate,
    bool clearTokenEstimate = false,
    String? promptReplayContent,
    bool clearPromptReplayContent = false,
    String? providerReplayContent,
    bool clearProviderReplayContent = false,
    bool? providerReplayExact,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isSummarized: isSummarized ?? this.isSummarized,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      bookmarkNote: bookmarkNote ?? this.bookmarkNote,
      gameStateSnapshot: clearGameStateSnapshot
          ? null
          : gameStateSnapshot ?? this.gameStateSnapshot,
      tokenEstimate:
          clearTokenEstimate ? null : tokenEstimate ?? this.tokenEstimate,
      promptReplayContent: clearPromptReplayContent
          ? null
          : promptReplayContent ?? this.promptReplayContent,
      providerReplayContent: clearProviderReplayContent
          ? null
          : providerReplayContent ?? this.providerReplayContent,
      providerReplayExact: providerReplayExact ?? this.providerReplayExact,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isSummarized': isSummarized,
      'isBookmarked': isBookmarked,
      'bookmarkNote': bookmarkNote,
      if (gameStateSnapshot != null) 'gameStateSnapshot': gameStateSnapshot,
      if (tokenEstimate != null) 'tokenEstimate': tokenEstimate,
      if (promptReplayContent != null && promptReplayContent!.trim().isNotEmpty)
        'promptReplayContent': promptReplayContent,
      if (providerReplayContent != null && providerReplayContent!.isNotEmpty)
        'providerReplayContent': providerReplayContent,
      if (providerReplayExact) 'providerReplayExact': true,
    };
  }
}

int? _readNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '');
}
