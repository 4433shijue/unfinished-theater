class CharacterMemorySummary {
  const CharacterMemorySummary({
    required this.id,
    required this.summaryText,
    required this.relatedMessageIds,
    required this.timestamp,
  });

  factory CharacterMemorySummary.fromJson(Map<String, dynamic> json) {
    final rawIds = json['relatedMessageIds'] as List? ?? const [];

    return CharacterMemorySummary(
      id: json['id']?.toString() ?? '',
      summaryText: json['summaryText']?.toString() ?? '',
      relatedMessageIds: rawIds.map((item) => item.toString()).toList(),
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String summaryText;
  final List<String> relatedMessageIds;
  final DateTime timestamp;

  CharacterMemorySummary copyWith({
    String? id,
    String? summaryText,
    List<String>? relatedMessageIds,
    DateTime? timestamp,
  }) {
    return CharacterMemorySummary(
      id: id ?? this.id,
      summaryText: summaryText ?? this.summaryText,
      relatedMessageIds: relatedMessageIds ?? this.relatedMessageIds,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'summaryText': summaryText,
      'relatedMessageIds': relatedMessageIds,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class CharacterMemory {
  const CharacterMemory({
    required this.characterId,
    required this.summaries,
  });

  factory CharacterMemory.empty(String characterId) {
    return CharacterMemory(characterId: characterId, summaries: const []);
  }

  factory CharacterMemory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['summaries'] as List? ?? const [];

    return CharacterMemory(
      characterId: json['characterId']?.toString() ?? '',
      summaries: rawItems
          .whereType<Map>()
          .map(
            (item) => CharacterMemorySummary.fromJson(
                Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }

  final String characterId;
  final List<CharacterMemorySummary> summaries;

  CharacterMemory copyWith({
    String? characterId,
    List<CharacterMemorySummary>? summaries,
  }) {
    return CharacterMemory(
      characterId: characterId ?? this.characterId,
      summaries: summaries ?? this.summaries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'characterId': characterId,
      'summaries': summaries.map((item) => item.toJson()).toList(),
    };
  }
}
