import 'npc_runtime.dart';

enum NpcMessageRole {
  user,
  npc,
}

enum NpcLifecycle {
  active,
  away,
  missing,
  dead,
  archived,
}

extension NpcLifecycleX on NpcLifecycle {
  static NpcLifecycle fromValue(Object? value) {
    return tryFromValue(value) ?? NpcLifecycle.active;
  }

  static NpcLifecycle? tryFromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return switch (normalized) {
      'active' || 'alive' || '活跃' || '在场' || '存活' => NpcLifecycle.active,
      'away' || '离场' || '暂离' || '远行' => NpcLifecycle.away,
      'missing' || '失踪' || '失联' => NpcLifecycle.missing,
      'dead' || 'deceased' || '死亡' || '已故' => NpcLifecycle.dead,
      'archived' || 'retired' || '归档' || '退场' => NpcLifecycle.archived,
      _ => null,
    };
  }

  String get label => switch (this) {
        NpcLifecycle.active => '活跃',
        NpcLifecycle.away => '离场',
        NpcLifecycle.missing => '失踪',
        NpcLifecycle.dead => '已故',
        NpcLifecycle.archived => '已归档',
      };

  bool get allowsRelationshipChanges =>
      this == NpcLifecycle.active || this == NpcLifecycle.away;

  bool get allowsMessages =>
      this == NpcLifecycle.active || this == NpcLifecycle.away;
}

class NpcGiftRecord {
  const NpcGiftRecord({
    required this.id,
    required this.itemName,
    required this.itemDescription,
    required this.itemEffect,
    required this.source,
    required this.affinityDelta,
    required this.impression,
    required this.createdAt,
  });

  factory NpcGiftRecord.fromJson(Map<String, dynamic> json) {
    return NpcGiftRecord(
      id: json['id']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      itemDescription: json['itemDescription']?.toString() ?? '',
      itemEffect: json['itemEffect']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      affinityDelta: _readBoundedInt(json['affinityDelta'], min: -30, max: 30),
      impression: normalizeNpcImpressionText(
        json['impression']?.toString() ?? '',
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String itemName;
  final String itemDescription;
  final String itemEffect;
  final String source;
  final int affinityDelta;
  final String impression;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'itemName': itemName,
      'itemDescription': itemDescription,
      'itemEffect': itemEffect,
      'source': source,
      'affinityDelta': affinityDelta,
      'impression': impression,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class NpcProfileSource {
  const NpcProfileSource._();

  static const String auto = 'auto';
  static const String manual = 'manual';
  static const String migrationCard = 'migrationCard';

  static String normalize(String value) {
    return switch (value.trim()) {
      manual => manual,
      migrationCard => migrationCard,
      _ => auto,
    };
  }

  static String label(String value) {
    return switch (normalize(value)) {
      manual => '用户创建',
      migrationCard => '带走角色卡',
      _ => '剧情识别',
    };
  }
}

String normalizeNpcImpressionText(String value) {
  final raw = value.trim();
  if (raw.isEmpty) {
    return '';
  }

  String cleanValue(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'^\[|\]$'), '')
        .replaceAll('"', '')
        .replaceAll(RegExp(r'\s*,\s*'), '、')
        .trim();
  }

  final lines = raw
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return raw;
  }

  final normalized = <String>[];
  for (final line in lines) {
    final match = RegExp(r'^([A-Za-z_]+)\s*[:：]\s*(.*)$').firstMatch(line);
    if (match == null) {
      normalized.add(line);
      continue;
    }

    final key = (match.group(1) ?? '').trim();
    final value = cleanValue(match.group(2) ?? '');
    if (value.isEmpty || value == 'null' || value == '[]') {
      continue;
    }

    switch (key) {
      case 'summary':
      case 'impression':
        normalized.add(value);
        break;
      case 'affinityDelta':
      case 'favorabilityDelta':
      case 'relationshipDelta':
        final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), ''));
        final label = parsed == null || parsed <= 0 ? value : '+$parsed';
        normalized.add('好感变化：$label');
        break;
      case 'affinity':
      case 'currentAffinity':
      case 'favorability':
        normalized.add('当前好感：$value');
        break;
      case 'attitude':
        normalized.add('当前态度：$value');
        break;
      case 'relationshipShift':
        normalized.add('关系变化：$value');
        break;
      case 'rememberedDetails':
        normalized.add('记住的细节：$value');
        break;
      case 'futureInfluence':
        normalized.add('后续影响：$value');
        break;
      default:
        normalized.add(value);
        break;
    }
  }

  return normalized.join('\n').trim();
}

extension NpcMessageRoleX on NpcMessageRole {
  static NpcMessageRole fromValue(String? value) {
    return NpcMessageRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => NpcMessageRole.npc,
    );
  }
}

class NpcProfile {
  const NpcProfile({
    required this.id,
    required this.characterId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.avatarDataUri = '',
    this.impression = '',
    this.affinity = 0,
    this.lifecycle = NpcLifecycle.active,
    this.impressionHistory = const <NpcImpressionEntry>[],
    this.bondRoute = const NpcBondRoute(),
    this.sourceType = NpcProfileSource.auto,
    this.roleCard = '',
    this.roleCardFinalized = false,
    this.companionEnabled = false,
    this.globalBinding = false,
    this.boundCharacterIds = const <String>[],
    this.giftHistory = const <NpcGiftRecord>[],
    this.runtimeState = const NpcRuntimeState(),
    this.npcMemory = const <NpcMemoryEntry>[],
    this.relationshipEdges = const <RelationshipEdge>[],
    this.worldEvents = const <WorldEvent>[],
  });

  factory NpcProfile.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['impressionHistory'];
    final rawBondRoute = json['bondRoute'];
    final rawBoundCharacterIds = json['boundCharacterIds'];
    final rawGiftHistory = json['giftHistory'];
    final rawRuntimeState = json['runtimeState'];
    final rawNpcMemory = json['npcMemory'];
    final rawRelationshipEdges = json['relationshipEdges'];
    final rawWorldEvents = json['worldEvents'];
    return NpcProfile(
      id: json['id']?.toString() ?? '',
      characterId: json['characterId']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名 NPC',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      description: json['description']?.toString() ?? '',
      avatarDataUri: json['avatarDataUri']?.toString() ?? '',
      impression:
          normalizeNpcImpressionText(json['impression']?.toString() ?? ''),
      affinity:
          _readInt(json['affinity'] ?? json['favorability'] ?? json['好感度']),
      lifecycle: NpcLifecycleX.fromValue(
        json['lifecycle'] ?? json['lifeState'] ?? json['生命周期'],
      ),
      impressionHistory: rawHistory is List
          ? rawHistory
              .whereType<Map>()
              .map(
                (item) => NpcImpressionEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <NpcImpressionEntry>[],
      bondRoute: rawBondRoute is Map
          ? NpcBondRoute.fromJson(Map<String, dynamic>.from(rawBondRoute))
          : NpcBondRoute.fromLegacyAffinity(
              affinity: _readInt(
                json['affinity'] ?? json['favorability'] ?? json['好感度'],
              ),
              impression: json['impression']?.toString() ?? '',
            ),
      sourceType:
          NpcProfileSource.normalize(json['sourceType']?.toString() ?? ''),
      roleCard: json['roleCard']?.toString() ?? '',
      roleCardFinalized:
          json['roleCardFinalized'] == true || json['npcRoleCardReady'] == true,
      companionEnabled: json['companionEnabled'] == true,
      globalBinding: json['globalBinding'] == true,
      boundCharacterIds: rawBoundCharacterIds is List
          ? rawBoundCharacterIds
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList(growable: false)
          : const <String>[],
      giftHistory: rawGiftHistory is List
          ? rawGiftHistory
              .whereType<Map>()
              .map(
                (item) => NpcGiftRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <NpcGiftRecord>[],
      runtimeState: rawRuntimeState is Map
          ? NpcRuntimeState.fromJson(Map<String, dynamic>.from(rawRuntimeState))
          : const NpcRuntimeState(),
      npcMemory: rawNpcMemory is List
          ? rawNpcMemory
              .whereType<Map>()
              .map(
                (item) => NpcMemoryEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.summary.trim().isNotEmpty)
              .take(30)
              .toList(growable: false)
          : const <NpcMemoryEntry>[],
      relationshipEdges: rawRelationshipEdges is List
          ? rawRelationshipEdges
              .whereType<Map>()
              .map(
                (item) => RelationshipEdge.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.targetId.trim().isNotEmpty)
              .take(20)
              .toList(growable: false)
          : const <RelationshipEdge>[],
      worldEvents: rawWorldEvents is List
          ? rawWorldEvents
              .whereType<Map>()
              .map(
                (item) => WorldEvent.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.summary.trim().isNotEmpty)
              .take(40)
              .toList(growable: false)
          : const <WorldEvent>[],
    );
  }

  final String id;
  final String characterId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String description;
  final String avatarDataUri;
  final String impression;
  final int affinity;
  final NpcLifecycle lifecycle;
  final List<NpcImpressionEntry> impressionHistory;
  final NpcBondRoute bondRoute;
  final String sourceType;
  final String roleCard;
  final bool roleCardFinalized;
  final bool companionEnabled;
  final bool globalBinding;
  final List<String> boundCharacterIds;
  final List<NpcGiftRecord> giftHistory;
  final NpcRuntimeState runtimeState;
  final List<NpcMemoryEntry> npcMemory;
  final List<RelationshipEdge> relationshipEdges;
  final List<WorldEvent> worldEvents;

  bool get hasReusableRoleCard =>
      roleCardFinalized || roleCard.trim().isNotEmpty;

  bool get hasExplicitBinding => globalBinding || boundCharacterIds.isNotEmpty;

  bool get canChangeAffinity => lifecycle.allowsRelationshipChanges;

  bool get canSendMessages => lifecycle.allowsMessages;

  bool isBoundTo(String characterId) {
    final trimmed = characterId.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (globalBinding) {
      return true;
    }
    if (boundCharacterIds.isNotEmpty) {
      return boundCharacterIds.contains(trimmed);
    }
    return this.characterId == trimmed;
  }

  NpcProfile copyWith({
    String? id,
    String? characterId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? avatarDataUri,
    String? impression,
    int? affinity,
    NpcLifecycle? lifecycle,
    List<NpcImpressionEntry>? impressionHistory,
    NpcBondRoute? bondRoute,
    String? sourceType,
    String? roleCard,
    bool? roleCardFinalized,
    bool? companionEnabled,
    bool? globalBinding,
    List<String>? boundCharacterIds,
    List<NpcGiftRecord>? giftHistory,
    NpcRuntimeState? runtimeState,
    List<NpcMemoryEntry>? npcMemory,
    List<RelationshipEdge>? relationshipEdges,
    List<WorldEvent>? worldEvents,
    bool clearBoundCharacterIds = false,
  }) {
    return NpcProfile(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      avatarDataUri: avatarDataUri ?? this.avatarDataUri,
      impression: impression ?? this.impression,
      affinity: affinity ?? this.affinity,
      lifecycle: lifecycle ?? this.lifecycle,
      impressionHistory: impressionHistory ?? this.impressionHistory,
      bondRoute: bondRoute ?? this.bondRoute,
      sourceType: sourceType ?? this.sourceType,
      roleCard: roleCard ?? this.roleCard,
      roleCardFinalized: roleCardFinalized ?? this.roleCardFinalized,
      companionEnabled: companionEnabled ?? this.companionEnabled,
      globalBinding: globalBinding ?? this.globalBinding,
      boundCharacterIds: clearBoundCharacterIds
          ? const <String>[]
          : boundCharacterIds ?? this.boundCharacterIds,
      giftHistory: giftHistory ?? this.giftHistory,
      runtimeState: runtimeState ?? this.runtimeState,
      npcMemory: npcMemory ?? this.npcMemory,
      relationshipEdges: relationshipEdges ?? this.relationshipEdges,
      worldEvents: worldEvents ?? this.worldEvents,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'avatarDataUri': avatarDataUri,
      'impression': impression,
      'affinity': affinity,
      'lifecycle': lifecycle.name,
      'impressionHistory':
          impressionHistory.map((item) => item.toJson()).toList(),
      'bondRoute': bondRoute.toJson(),
      'sourceType': sourceType,
      'roleCard': roleCard,
      'roleCardFinalized': roleCardFinalized,
      'companionEnabled': companionEnabled,
      'globalBinding': globalBinding,
      'boundCharacterIds': boundCharacterIds,
      'giftHistory': giftHistory.map((item) => item.toJson()).toList(),
      'runtimeState': runtimeState.toJson(),
      'npcMemory': npcMemory.map((item) => item.toJson()).toList(),
      'relationshipEdges':
          relationshipEdges.map((item) => item.toJson()).toList(),
      'worldEvents': worldEvents.map((item) => item.toJson()).toList(),
    };
  }

  static int _readInt(dynamic value) {
    return _readBoundedInt(value, min: -100, max: 100);
  }
}

int _readBoundedInt(dynamic value, {required int min, required int max}) {
  if (value is num) {
    return value.round().clamp(min, max);
  }
  final parsed = int.tryParse(
    value?.toString().replaceAll(RegExp(r'[^0-9-]'), '') ?? '',
  );
  return (parsed ?? 0).clamp(min, max);
}

class NpcBondRoute {
  const NpcBondRoute({
    this.score = 0,
    this.stage = '初见',
    this.route = '未知线',
    this.latestEvent = '',
    this.keywords = const <String>[],
    this.events = const <NpcBondEvent>[],
    this.updatedAt,
  });

  factory NpcBondRoute.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'];
    final rawEvents = json['events'];
    final score = _readScore(json['score'] ?? json['bondScore']);
    return NpcBondRoute(
      score: score,
      stage: (json['stage']?.toString().trim().isNotEmpty ?? false)
          ? json['stage'].toString().trim()
          : stageForScore(score),
      route: (json['route']?.toString().trim().isNotEmpty ?? false)
          ? json['route'].toString().trim()
          : '未知线',
      latestEvent: json['latestEvent']?.toString().trim() ?? '',
      keywords: rawKeywords is List
          ? rawKeywords
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .take(8)
              .toList(growable: false)
          : const <String>[],
      events: rawEvents is List
          ? rawEvents
              .whereType<Map>()
              .map(
                (item) => NpcBondEvent.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.summary.trim().isNotEmpty)
              .take(20)
              .toList(growable: false)
          : const <NpcBondEvent>[],
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  factory NpcBondRoute.fromLegacyAffinity({
    required int affinity,
    required String impression,
  }) {
    final score = affinity <= 0 ? 0 : affinity.clamp(0, 100);
    final normalizedImpression = normalizeNpcImpressionText(impression);
    return NpcBondRoute(
      score: score,
      stage: stageForScore(score),
      route: inferRoute(normalizedImpression, fallback: '未知线'),
      latestEvent: normalizedImpression,
      keywords: inferKeywords(normalizedImpression),
      updatedAt: DateTime.now(),
    );
  }

  final int score;
  final String stage;
  final String route;
  final String latestEvent;
  final List<String> keywords;
  final List<NpcBondEvent> events;
  final DateTime? updatedAt;

  NpcBondRoute copyWith({
    int? score,
    String? stage,
    String? route,
    String? latestEvent,
    List<String>? keywords,
    List<NpcBondEvent>? events,
    DateTime? updatedAt,
  }) {
    return NpcBondRoute(
      score: score ?? this.score,
      stage: stage ?? this.stage,
      route: route ?? this.route,
      latestEvent: latestEvent ?? this.latestEvent,
      keywords: keywords ?? this.keywords,
      events: events ?? this.events,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'score': score,
      'stage': stage,
      'route': route,
      'latestEvent': latestEvent,
      'keywords': keywords,
      'events': events.map((item) => item.toJson()).toList(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static int _readScore(dynamic value) {
    if (value is num) {
      return value.round().clamp(0, 100);
    }
    final parsed = int.tryParse(
      value?.toString().replaceAll(RegExp(r'[^0-9-]'), '') ?? '',
    );
    return (parsed ?? 0).clamp(0, 100);
  }

  static String stageForScore(int score) {
    if (score >= 80) return '深羁绊';
    if (score >= 65) return '分岔';
    if (score >= 45) return '牵绊';
    if (score >= 25) return '信任';
    if (score >= 10) return '熟悉';
    return '初见';
  }

  static String inferRoute(String text, {String fallback = '未知线'}) {
    final value = text.trim();
    if (value.isEmpty) {
      return fallback;
    }
    bool hasAny(List<String> words) => words.any(value.contains);
    if (hasAny(<String>['暧昧', '心动', '喜欢', '吃醋', '恋人', '占有', '亲密'])) {
      return '恋人线';
    }
    if (hasAny(<String>['挚友', '朋友', '信任', '陪伴', '默契', '安心'])) {
      return '挚友线';
    }
    if (hasAny(<String>['宿敌', '挑衅', '竞争', '较劲', '不服', '对抗'])) {
      return '宿敌线';
    }
    if (hasAny(<String>['共犯', '秘密', '隐瞒', '同谋', '一起冒险'])) {
      return '共犯线';
    }
    if (hasAny(<String>['守护', '保护', '照顾', '担心', '放心不下'])) {
      return '守护线';
    }
    if (hasAny(<String>['师徒', '教导', '指导', '训练', '学习'])) {
      return '师徒线';
    }
    if (hasAny(<String>['破镜', '误会', '分开', '重逢', '道歉', '修复'])) {
      return '破镜线';
    }
    return fallback;
  }

  static List<String> inferKeywords(String text) {
    const candidates = <String>[
      '信任',
      '陪伴',
      '暧昧',
      '吃醋',
      '保护',
      '秘密',
      '竞争',
      '重逢',
      '道歉',
      '依赖',
      '试探',
      '默契',
    ];
    return candidates
        .where((keyword) => text.contains(keyword))
        .take(6)
        .toList(growable: false);
  }
}

class NpcBondEvent {
  const NpcBondEvent({
    required this.id,
    required this.summary,
    required this.stage,
    required this.route,
    required this.scoreDelta,
    required this.createdAt,
  });

  factory NpcBondEvent.fromJson(Map<String, dynamic> json) {
    return NpcBondEvent(
      id: json['id']?.toString() ?? '',
      summary: normalizeNpcImpressionText(json['summary']?.toString() ?? ''),
      stage: json['stage']?.toString() ?? '初见',
      route: json['route']?.toString() ?? '未知线',
      scoreDelta: NpcBondRoute._readScore(json['scoreDelta']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String summary;
  final String stage;
  final String route;
  final int scoreDelta;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'summary': summary,
      'stage': stage,
      'route': route,
      'scoreDelta': scoreDelta,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class NpcImpressionEntry {
  const NpcImpressionEntry({
    required this.id,
    required this.summary,
    required this.createdAt,
  });

  factory NpcImpressionEntry.fromJson(Map<String, dynamic> json) {
    return NpcImpressionEntry(
      id: json['id']?.toString() ?? '',
      summary: normalizeNpcImpressionText(json['summary']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String summary;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'summary': summary,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class NpcChatMessage {
  const NpcChatMessage({
    required this.id,
    required this.npcId,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.batchId,
    this.innerVoice = '',
    this.innerVoiceGeneratedAt,
  });

  factory NpcChatMessage.fromJson(Map<String, dynamic> json) {
    return NpcChatMessage(
      id: json['id']?.toString() ?? '',
      npcId: json['npcId']?.toString() ?? '',
      role: NpcMessageRoleX.fromValue(json['role']?.toString()),
      content: json['content']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      batchId: json['batchId']?.toString() ?? '',
      innerVoice: json['innerVoice']?.toString() ?? '',
      innerVoiceGeneratedAt:
          DateTime.tryParse(json['innerVoiceGeneratedAt']?.toString() ?? ''),
    );
  }

  final String id;
  final String npcId;
  final NpcMessageRole role;
  final String content;
  final DateTime timestamp;
  final String batchId;
  final String innerVoice;
  final DateTime? innerVoiceGeneratedAt;

  NpcChatMessage copyWith({
    String? id,
    String? npcId,
    NpcMessageRole? role,
    String? content,
    DateTime? timestamp,
    String? batchId,
    String? innerVoice,
    DateTime? innerVoiceGeneratedAt,
  }) {
    return NpcChatMessage(
      id: id ?? this.id,
      npcId: npcId ?? this.npcId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      batchId: batchId ?? this.batchId,
      innerVoice: innerVoice ?? this.innerVoice,
      innerVoiceGeneratedAt:
          innerVoiceGeneratedAt ?? this.innerVoiceGeneratedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'npcId': npcId,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'batchId': batchId,
      'innerVoice': innerVoice,
      'innerVoiceGeneratedAt': innerVoiceGeneratedAt?.toIso8601String(),
    };
  }
}

class NpcProfileDraft {
  const NpcProfileDraft({
    required this.name,
    this.avatarDataUri = '',
    this.description = '',
    this.impression = '',
    this.affinity = 0,
    this.lifecycle = NpcLifecycle.active,
    this.sourceType = NpcProfileSource.manual,
    this.roleCard = '',
    this.roleCardFinalized = false,
    this.companionEnabled = false,
    this.globalBinding = false,
    this.boundCharacterIds = const <String>[],
  });

  final String name;
  final String avatarDataUri;
  final String description;
  final String impression;
  final int affinity;
  final NpcLifecycle lifecycle;
  final String sourceType;
  final String roleCard;
  final bool roleCardFinalized;
  final bool companionEnabled;
  final bool globalBinding;
  final List<String> boundCharacterIds;

  NpcProfileDraft copyWith({
    String? name,
    String? avatarDataUri,
    String? description,
    String? impression,
    int? affinity,
    NpcLifecycle? lifecycle,
    String? sourceType,
    String? roleCard,
    bool? roleCardFinalized,
    bool? companionEnabled,
    bool? globalBinding,
    List<String>? boundCharacterIds,
  }) {
    return NpcProfileDraft(
      name: name ?? this.name,
      avatarDataUri: avatarDataUri ?? this.avatarDataUri,
      description: description ?? this.description,
      impression: impression ?? this.impression,
      affinity: affinity ?? this.affinity,
      lifecycle: lifecycle ?? this.lifecycle,
      sourceType: sourceType ?? this.sourceType,
      roleCard: roleCard ?? this.roleCard,
      roleCardFinalized: roleCardFinalized ?? this.roleCardFinalized,
      companionEnabled: companionEnabled ?? this.companionEnabled,
      globalBinding: globalBinding ?? this.globalBinding,
      boundCharacterIds: boundCharacterIds ?? this.boundCharacterIds,
    );
  }
}

class NpcRoleCardDraftResult {
  const NpcRoleCardDraftResult({
    this.draft,
    this.error,
  });

  final NpcProfileDraft? draft;
  final String? error;

  bool get isSuccess => draft != null && error == null;
}
