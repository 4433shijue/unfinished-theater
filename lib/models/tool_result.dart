class ToolResult {
  const ToolResult({
    required this.id,
    required this.characterId,
    required this.toolId,
    required this.toolTitle,
    required this.content,
    required this.createdAt,
    this.interactiveTheater = false,
    this.theaterSelectionMode = '',
    this.theaterKinds = const <String>[],
    this.theaterPrompt = '',
    this.theaterStep = 0,
  });

  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      id: json['id']?.toString() ?? '',
      characterId: json['characterId']?.toString() ?? '',
      toolId: json['toolId']?.toString() ?? '',
      toolTitle: json['toolTitle']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      interactiveTheater: json['interactiveTheater'] == true ||
          json['toolId']?.toString() == 'interactive_theater',
      theaterSelectionMode: json['theaterSelectionMode']?.toString() ?? '',
      theaterKinds: json['theaterKinds'] is List
          ? (json['theaterKinds'] as List)
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      theaterPrompt: json['theaterPrompt']?.toString() ?? '',
      theaterStep: _readInt(json['theaterStep']),
    );
  }

  final String id;
  final String characterId;
  final String toolId;
  final String toolTitle;
  final String content;
  final DateTime createdAt;
  final bool interactiveTheater;
  final String theaterSelectionMode;
  final List<String> theaterKinds;
  final String theaterPrompt;
  final int theaterStep;

  bool get isInteractiveTheater =>
      interactiveTheater || toolId == 'interactive_theater';

  ToolResult copyWith({
    String? id,
    String? characterId,
    String? toolId,
    String? toolTitle,
    String? content,
    DateTime? createdAt,
    bool? interactiveTheater,
    String? theaterSelectionMode,
    List<String>? theaterKinds,
    String? theaterPrompt,
    int? theaterStep,
  }) {
    return ToolResult(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      toolId: toolId ?? this.toolId,
      toolTitle: toolTitle ?? this.toolTitle,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      interactiveTheater: interactiveTheater ?? this.interactiveTheater,
      theaterSelectionMode: theaterSelectionMode ?? this.theaterSelectionMode,
      theaterKinds: theaterKinds ?? this.theaterKinds,
      theaterPrompt: theaterPrompt ?? this.theaterPrompt,
      theaterStep: theaterStep ?? this.theaterStep,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'toolId': toolId,
      'toolTitle': toolTitle,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      if (interactiveTheater) ...<String, dynamic>{
        'interactiveTheater': true,
        'theaterSelectionMode': theaterSelectionMode,
        'theaterKinds': theaterKinds,
        'theaterPrompt': theaterPrompt,
        'theaterStep': theaterStep,
      },
    };
  }

  static int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
