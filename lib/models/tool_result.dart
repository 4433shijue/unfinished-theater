class ToolResult {
  const ToolResult({
    required this.id,
    required this.characterId,
    required this.toolId,
    required this.toolTitle,
    required this.content,
    required this.createdAt,
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
    );
  }

  final String id;
  final String characterId;
  final String toolId;
  final String toolTitle;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'toolId': toolId,
      'toolTitle': toolTitle,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
