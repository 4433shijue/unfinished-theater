import '../utils/id_generator.dart';

const String legacyDefaultWorldBookContent = '''
内容边界
1. 可以生成成年人之间的恋爱、暧昧、亲密张力与成熟情感内容。
2. 可以描写成年人之间自愿、平等、明确同意前提下的亲密互动。
''';

const String defaultWorldBookContent = '''
玩家自主与故事连续性
1. 不替玩家决定关键行动、台词、情感归属或内心结论；需要玩家表态时停在清晰的回应点。
2. 已经确认的世界规则、人物关系、时间地点、重要物品和事件后果应保持连续，变化必须在剧情中有原因。
3. NPC 可以主动行动、表达意见和推动支线，但不能夺走玩家对主角的控制权。
4. 涉及亲密关系或高风险互动时，应尊重相关人物的年龄设定、自愿意愿、边界与明确同意。
5. 不把推测写成已经发生的事实；信息不足时通过剧情调查、对话或留白继续推进。
''';

enum WorldBookTriggerMode {
  always,
  keyword,
  regex,
}

extension WorldBookTriggerModeX on WorldBookTriggerMode {
  static WorldBookTriggerMode fromValue(String? value) {
    return WorldBookTriggerMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => WorldBookTriggerMode.always,
    );
  }

  String get label {
    switch (this) {
      case WorldBookTriggerMode.always:
        return '常驻';
      case WorldBookTriggerMode.keyword:
        return '关键词';
      case WorldBookTriggerMode.regex:
        return '正则';
    }
  }
}

enum WorldBookInjectionPosition {
  front,
  middle,
  rear,
}

extension WorldBookInjectionPositionX on WorldBookInjectionPosition {
  static WorldBookInjectionPosition fromValue(String? value) {
    return WorldBookInjectionPosition.values.firstWhere(
      (position) => position.name == value,
      orElse: () => WorldBookInjectionPosition.middle,
    );
  }

  String get label {
    switch (this) {
      case WorldBookInjectionPosition.front:
        return '前部';
      case WorldBookInjectionPosition.middle:
        return '中部';
      case WorldBookInjectionPosition.rear:
        return '后部';
    }
  }
}

class WorldBookEntry {
  WorldBookEntry({
    String? id,
    required this.title,
    required this.content,
    required this.global,
    this.tags = const <String>[],
    this.boundCharacterIds = const <String>[],
    this.triggerMode = WorldBookTriggerMode.always,
    this.keywords = const <String>[],
    this.regexPattern = '',
    this.injectionPosition = WorldBookInjectionPosition.middle,
    this.priority = 50,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? IdGenerator.generic('worldbook'),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory WorldBookEntry.defaultEntry() {
    return WorldBookEntry(
      id: 'worldbook_default_boundary',
      title: '默认创作规则',
      content: defaultWorldBookContent.trim(),
      global: true,
      tags: const <String>['创作边界', '故事连续性'],
      triggerMode: WorldBookTriggerMode.always,
      injectionPosition: WorldBookInjectionPosition.front,
      priority: 90,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory WorldBookEntry.fromJson(Map<String, dynamic> json) {
    final rawIds = json['boundCharacterIds'];
    final rawTags = json['tags'];
    final rawContent = json['content']?.toString() ?? '';
    return WorldBookEntry(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '未命名世界书',
      content: rawContent.replaceFirst(RegExp(r'^\s*八[.、．]\s*'), ''),
      global: json['global'] == true,
      tags: rawTags is List
          ? rawTags
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList(growable: false)
          : const <String>[],
      boundCharacterIds: rawIds is List
          ? rawIds
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      triggerMode:
          WorldBookTriggerModeX.fromValue(json['triggerMode']?.toString()),
      keywords: _readStringList(json['keywords']),
      regexPattern: json['regexPattern']?.toString() ?? '',
      injectionPosition: WorldBookInjectionPositionX.fromValue(
        json['injectionPosition']?.toString(),
      ),
      priority: _readInt(json['priority'], 50).clamp(0, 100),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String title;
  final String content;
  final bool global;
  final List<String> tags;
  final List<String> boundCharacterIds;
  final WorldBookTriggerMode triggerMode;
  final List<String> keywords;
  final String regexPattern;
  final WorldBookInjectionPosition injectionPosition;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool appliesTo(String characterId) {
    return global || boundCharacterIds.contains(characterId);
  }

  WorldBookEntry copyWith({
    String? title,
    String? content,
    bool? global,
    List<String>? tags,
    List<String>? boundCharacterIds,
    WorldBookTriggerMode? triggerMode,
    List<String>? keywords,
    String? regexPattern,
    WorldBookInjectionPosition? injectionPosition,
    int? priority,
    DateTime? updatedAt,
  }) {
    return WorldBookEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      global: global ?? this.global,
      tags: tags ?? this.tags,
      boundCharacterIds: boundCharacterIds ?? this.boundCharacterIds,
      triggerMode: triggerMode ?? this.triggerMode,
      keywords: keywords ?? this.keywords,
      regexPattern: regexPattern ?? this.regexPattern,
      injectionPosition: injectionPosition ?? this.injectionPosition,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'global': global,
      'tags': tags,
      'boundCharacterIds': boundCharacterIds,
      'triggerMode': triggerMode.name,
      'keywords': keywords,
      'regexPattern': regexPattern,
      'injectionPosition': injectionPosition.name,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    return const <String>[];
  }

  static int _readInt(dynamic value, int fallback) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class WorldBookDraft {
  const WorldBookDraft({
    required this.title,
    required this.content,
    required this.global,
    this.tags = const <String>[],
    required this.boundCharacterIds,
    required this.triggerMode,
    this.keywords = const <String>[],
    this.regexPattern = '',
    required this.injectionPosition,
    required this.priority,
  });

  final String title;
  final String content;
  final bool global;
  final List<String> tags;
  final List<String> boundCharacterIds;
  final WorldBookTriggerMode triggerMode;
  final List<String> keywords;
  final String regexPattern;
  final WorldBookInjectionPosition injectionPosition;
  final int priority;
}
