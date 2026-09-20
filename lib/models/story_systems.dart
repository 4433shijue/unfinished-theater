import '../utils/id_generator.dart';

class TurnDirective {
  const TurnDirective({
    required this.mood,
    required this.focus,
    required this.note,
    required this.intensity,
  });

  factory TurnDirective.fromJson(Map<String, dynamic> json) {
    return TurnDirective(
      mood: json['mood']?.toString() ?? '',
      focus: json['focus']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      intensity: _readInt(json['intensity'], fallback: 2),
    );
  }

  final String mood;
  final String focus;
  final String note;
  final int intensity;

  bool get isEmpty =>
      mood.trim().isEmpty && focus.trim().isEmpty && note.trim().isEmpty;

  String toPrompt() {
    final buffer = StringBuffer()
      ..writeln('本轮临时导演指令，只影响这一次回复，不写入长期角色设定。')
      ..writeln('通过镜头取舍、对白节奏与具体行动体现要求，保留人物原有口吻；'
          '不直接复述导演指令，不用氛围要求改写既有事实、替玩家作决定或覆盖状态协议。')
      ..writeln('强度：${intensity.clamp(1, 5)}/5');
    if (mood.trim().isNotEmpty) {
      buffer.writeln('氛围：${mood.trim()}');
    }
    if (focus.trim().isNotEmpty) {
      buffer.writeln('镜头重点：${focus.trim()}');
    }
    if (note.trim().isNotEmpty) {
      buffer.writeln('用户补充：${note.trim()}');
    }
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mood': mood,
      'focus': focus,
      'note': note,
      'intensity': intensity,
    };
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class WorldCalendarEvent {
  WorldCalendarEvent({
    String? id,
    required this.characterId,
    required this.title,
    required this.timeLabel,
    required this.description,
    this.stage = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? IdGenerator.generic('calendar'),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory WorldCalendarEvent.fromJson(Map<String, dynamic> json) {
    return WorldCalendarEvent(
      id: json['id']?.toString(),
      characterId: json['characterId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      timeLabel: json['timeLabel']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String characterId;
  final String title;
  final String timeLabel;
  final String description;
  final String stage;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorldCalendarEvent copyWith({
    String? id,
    String? characterId,
    String? title,
    String? timeLabel,
    String? description,
    String? stage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorldCalendarEvent(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      title: title ?? this.title,
      timeLabel: timeLabel ?? this.timeLabel,
      description: description ?? this.description,
      stage: stage ?? this.stage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'title': title,
      'timeLabel': timeLabel,
      'description': description,
      'stage': stage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
