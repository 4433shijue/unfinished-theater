import '../services/npc_message_classifier.dart';

class StoryInventoryItem {
  const StoryInventoryItem({
    required this.id,
    required this.name,
    this.description = '',
    this.effect = '',
    this.source = '',
    this.identified = true,
    this.mysteryHint = '',
    this.createdAt,
  });

  factory StoryInventoryItem.fromJson(Map<String, dynamic> json) {
    return StoryInventoryItem(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      effect: json['effect']?.toString().trim() ?? '',
      source: json['source']?.toString().trim() ?? '',
      identified:
          json['identified'] is bool ? json['identified'] as bool : true,
      mysteryHint: json['mysteryHint']?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    ).normalized();
  }

  factory StoryInventoryItem.fromName(
    String name, {
    String description = '',
    String effect = '',
    String source = '',
    bool identified = true,
    String mysteryHint = '',
  }) {
    final trimmedName = name.trim();
    return StoryInventoryItem(
      id: _stableStoryItemId(trimmedName),
      name: trimmedName,
      description: description.trim(),
      effect: effect.trim(),
      source: source.trim(),
      identified: identified,
      mysteryHint: mysteryHint.trim(),
      createdAt: DateTime.now(),
    );
  }

  final String id;
  final String name;
  final String description;
  final String effect;
  final String source;
  final bool identified;
  final String mysteryHint;
  final DateTime? createdAt;

  StoryInventoryItem normalized() {
    final safeName = name.trim();
    return StoryInventoryItem(
      id: id.trim().isEmpty ? _stableStoryItemId(safeName) : id.trim(),
      name: safeName,
      description: description.trim(),
      effect: effect.trim(),
      source: source.trim(),
      identified: identified,
      mysteryHint: mysteryHint.trim(),
      createdAt: createdAt,
    );
  }

  StoryInventoryItem copyWith({
    String? id,
    String? name,
    String? description,
    String? effect,
    String? source,
    bool? identified,
    String? mysteryHint,
    DateTime? createdAt,
  }) {
    return StoryInventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      effect: effect ?? this.effect,
      source: source ?? this.source,
      identified: identified ?? this.identified,
      mysteryHint: mysteryHint ?? this.mysteryHint,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'effect': effect,
      'source': source,
      'identified': identified,
      'mysteryHint': mysteryHint,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static String _stableStoryItemId(String value) {
    final normalized = value.trim();
    var hash = 0x811c9dc5;
    for (final code in normalized.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'story_${hash.toRadixString(16).padLeft(8, '0')}';
  }
}

class StoryShopOffer {
  const StoryShopOffer({
    required this.id,
    required this.name,
    required this.description,
    required this.effect,
    required this.cost,
  });

  factory StoryShopOffer.fromJson(Map<String, dynamic> json) {
    final rawCost = json['cost'] ?? json['price'] ?? json['啥币'];
    final cost = rawCost is num
        ? rawCost.round()
        : int.tryParse(rawCost?.toString() ?? '') ?? 10;
    return StoryShopOffer(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      effect: json['effect']?.toString().trim() ?? '',
      cost: cost.clamp(1, 500),
    ).normalized();
  }

  final String id;
  final String name;
  final String description;
  final String effect;
  final int cost;

  StoryShopOffer normalized() {
    final safeName = name.trim().isEmpty ? '神秘货物' : name.trim();
    return StoryShopOffer(
      id: id.trim().isEmpty
          ? StoryInventoryItem._stableStoryItemId(safeName)
          : id.trim(),
      name: safeName,
      description:
          description.trim().isEmpty ? '老板说这玩意儿肯定有用。' : description.trim(),
      effect: effect.trim().isEmpty ? '由当前剧情自然决定用途。' : effect.trim(),
      cost: cost.clamp(1, 500),
    );
  }
}

class GameStateSnapshot {
  const GameStateSnapshot({
    required this.characterId,
    required this.updatedAt,
    this.location = '',
    this.timeLabel = '',
    this.status = '',
    this.mainTask = '',
    this.profileDetails = const <String>[],
    this.sideTasks = const <String>[],
    this.completedTasks = const <String>[],
    this.inventory = const <String>[],
    this.storyInventory = const <StoryInventoryItem>[],
    this.eventTitle = '',
    this.eventDescription = '',
    this.relationshipNotes = const <String>[],
    this.plotFlags = const <String>[],
    this.npcChanges = const <String>[],
    this.npcUpdates = const <GameNpcUpdate>[],
    this.metrics = const <String, int>{},
    this.customVariables = const <String, dynamic>{},
    this.customVariablesRevision = 0,
    this.gameplayVariableChanges = const <String>[],
    this.gameplayPlayerVariableChanges = const <String>[],
    this.gameplayVariableWarnings = const <String>[],
  });

  factory GameStateSnapshot.empty(String characterId) {
    return GameStateSnapshot(
      characterId: characterId,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) {
    final inventory = _readStringList(json['inventory']);
    final storyInventory = _mergeStoryInventory(
      _readStoryInventory(json['storyInventory']),
      inventory,
    );
    return GameStateSnapshot(
      characterId: json['characterId']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      location: json['location']?.toString() ?? '',
      timeLabel: json['timeLabel']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      mainTask: json['mainTask']?.toString() ?? '',
      profileDetails: _readStringList(json['profileDetails']),
      sideTasks: _readStringList(json['sideTasks']),
      completedTasks: _readStringList(json['completedTasks']),
      inventory: inventory,
      storyInventory: storyInventory,
      eventTitle: json['eventTitle']?.toString() ?? '',
      eventDescription: json['eventDescription']?.toString() ?? '',
      relationshipNotes: _readStringList(json['relationshipNotes']),
      plotFlags: _readStringList(json['plotFlags']),
      npcChanges: _readStringList(json['npcChanges']),
      npcUpdates: _readNpcUpdates(json['npcUpdates']),
      metrics: _readMetrics(json['metrics']),
      customVariables: json['customVariables'] is Map
          ? Map<String, dynamic>.from(json['customVariables'] as Map)
          : const <String, dynamic>{},
      customVariablesRevision:
          int.tryParse(json['customVariablesRevision']?.toString() ?? '') ?? 0,
      gameplayVariableChanges: _readStringList(json['gameplayVariableChanges']),
      gameplayPlayerVariableChanges:
          _readStringList(json['gameplayPlayerVariableChanges']),
      gameplayVariableWarnings:
          _readStringList(json['gameplayVariableWarnings']),
    );
  }

  final String characterId;
  final DateTime updatedAt;
  final String location;
  final String timeLabel;
  final String status;
  final String mainTask;
  final List<String> profileDetails;
  final List<String> sideTasks;
  final List<String> completedTasks;
  final List<String> inventory;
  final List<StoryInventoryItem> storyInventory;
  final String eventTitle;
  final String eventDescription;
  final List<String> relationshipNotes;
  final List<String> plotFlags;
  final List<String> npcChanges;
  final List<GameNpcUpdate> npcUpdates;
  final Map<String, int> metrics;
  final Map<String, dynamic> customVariables;
  final int customVariablesRevision;
  final List<String> gameplayVariableChanges;
  final List<String> gameplayPlayerVariableChanges;
  final List<String> gameplayVariableWarnings;

  bool get hasNarrativeState {
    return location.trim().isNotEmpty ||
        timeLabel.trim().isNotEmpty ||
        status.trim().isNotEmpty ||
        mainTask.trim().isNotEmpty ||
        profileDetails.isNotEmpty ||
        sideTasks.isNotEmpty ||
        completedTasks.isNotEmpty ||
        inventory.isNotEmpty ||
        storyInventory.isNotEmpty ||
        eventTitle.trim().isNotEmpty ||
        eventDescription.trim().isNotEmpty ||
        relationshipNotes.isNotEmpty ||
        plotFlags.isNotEmpty ||
        npcChanges.isNotEmpty ||
        npcUpdates.isNotEmpty ||
        metrics.isNotEmpty;
  }

  bool get isEmpty {
    return !hasNarrativeState && customVariables.isEmpty;
  }

  GameStateSnapshot copyWith({
    String? characterId,
    DateTime? updatedAt,
    String? location,
    String? timeLabel,
    String? status,
    String? mainTask,
    List<String>? profileDetails,
    List<String>? sideTasks,
    List<String>? completedTasks,
    List<String>? inventory,
    List<StoryInventoryItem>? storyInventory,
    String? eventTitle,
    String? eventDescription,
    List<String>? relationshipNotes,
    List<String>? plotFlags,
    List<String>? npcChanges,
    List<GameNpcUpdate>? npcUpdates,
    Map<String, int>? metrics,
    Map<String, dynamic>? customVariables,
    int? customVariablesRevision,
    List<String>? gameplayVariableChanges,
    List<String>? gameplayPlayerVariableChanges,
    List<String>? gameplayVariableWarnings,
  }) {
    return GameStateSnapshot(
      characterId: characterId ?? this.characterId,
      updatedAt: updatedAt ?? this.updatedAt,
      location: location ?? this.location,
      timeLabel: timeLabel ?? this.timeLabel,
      status: status ?? this.status,
      mainTask: mainTask ?? this.mainTask,
      profileDetails: profileDetails ?? this.profileDetails,
      sideTasks: sideTasks ?? this.sideTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      inventory: inventory ?? this.inventory,
      storyInventory: storyInventory ?? this.storyInventory,
      eventTitle: eventTitle ?? this.eventTitle,
      eventDescription: eventDescription ?? this.eventDescription,
      relationshipNotes: relationshipNotes ?? this.relationshipNotes,
      plotFlags: plotFlags ?? this.plotFlags,
      npcChanges: npcChanges ?? this.npcChanges,
      npcUpdates: npcUpdates ?? this.npcUpdates,
      metrics: metrics ?? this.metrics,
      customVariables: customVariables ?? this.customVariables,
      customVariablesRevision:
          customVariablesRevision ?? this.customVariablesRevision,
      gameplayVariableChanges:
          gameplayVariableChanges ?? this.gameplayVariableChanges,
      gameplayPlayerVariableChanges:
          gameplayPlayerVariableChanges ?? this.gameplayPlayerVariableChanges,
      gameplayVariableWarnings:
          gameplayVariableWarnings ?? this.gameplayVariableWarnings,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'updatedAt': updatedAt.toIso8601String(),
      'location': location,
      'timeLabel': timeLabel,
      'status': status,
      'mainTask': mainTask,
      'profileDetails': profileDetails,
      'sideTasks': sideTasks,
      'completedTasks': completedTasks,
      'inventory': inventory,
      'storyInventory': storyInventory.map((item) => item.toJson()).toList(),
      'eventTitle': eventTitle,
      'eventDescription': eventDescription,
      'relationshipNotes': relationshipNotes,
      'plotFlags': plotFlags,
      'npcChanges': npcChanges,
      'npcUpdates': npcUpdates.map((item) => item.toJson()).toList(),
      'metrics': metrics,
      if (customVariables.isNotEmpty) 'customVariables': customVariables,
      if (customVariablesRevision > 0)
        'customVariablesRevision': customVariablesRevision,
      if (gameplayVariableChanges.isNotEmpty)
        'gameplayVariableChanges': gameplayVariableChanges,
      if (gameplayPlayerVariableChanges.isNotEmpty)
        'gameplayPlayerVariableChanges': gameplayPlayerVariableChanges,
      if (gameplayVariableWarnings.isNotEmpty)
        'gameplayVariableWarnings': gameplayVariableWarnings,
    };
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    if (value is String) {
      return value
          .split(RegExp(r'[;；、,\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return const <String>[];
  }

  static List<StoryInventoryItem> _readStoryInventory(dynamic value) {
    if (value is! List) {
      return const <StoryInventoryItem>[];
    }

    return value
        .map((item) {
          if (item is Map) {
            return StoryInventoryItem.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return StoryInventoryItem.fromName(item.toString());
        })
        .where((item) => item.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  static List<StoryInventoryItem> _mergeStoryInventory(
    List<StoryInventoryItem> existing,
    List<String> legacyInventory,
  ) {
    final result = <StoryInventoryItem>[];
    final seen = <String>{};

    void add(StoryInventoryItem item) {
      final normalized = item.normalized();
      final key = normalized.name.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) {
        return;
      }
      seen.add(key);
      result.add(normalized);
    }

    for (final item in existing) {
      add(item);
    }
    for (final name in legacyInventory) {
      add(StoryInventoryItem.fromName(name, source: 'game_state'));
    }

    return result;
  }

  static List<GameNpcUpdate> _readNpcUpdates(dynamic value) {
    if (value is! List) {
      return const <GameNpcUpdate>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => GameNpcUpdate.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => !item.isEmpty)
        .toList(growable: false);
  }

  static Map<String, int> _readMetrics(dynamic value) {
    if (value is! Map) {
      return const <String, int>{};
    }

    final result = <String, int>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) {
        continue;
      }
      final raw = entry.value;
      final parsed = raw is num
          ? raw.round()
          : int.tryParse(raw.toString().replaceAll(RegExp(r'[^0-9-]'), ''));
      if (parsed != null) {
        result[key] = parsed.clamp(0, 9999);
      }
    }
    return result;
  }
}

class GameNpcUpdate {
  const GameNpcUpdate({
    required this.name,
    this.npcId = '',
    this.description = '',
    this.impression = '',
    this.affinity,
    this.affinityDelta,
    this.lifecycle = '',
    this.lifecycleReason = '',
    this.proactiveMessage = '',
  });

  factory GameNpcUpdate.fromJson(Map<String, dynamic> json) {
    final rawAffinity =
        json['affinity'] ?? json['favorability'] ?? json['好感度'] ?? json['好感'];
    final rawAffinityDelta = json['affinityDelta'] ??
        json['favorabilityDelta'] ??
        json['好感变化'] ??
        json['好感度变化'];
    final rawProactiveMessage = (json['proactiveMessage'] ??
                json['message'] ??
                json['主动消息'] ??
                json['私聊消息'] ??
                json['npcMessage'])
            ?.toString()
            .trim() ??
        '';
    return GameNpcUpdate(
      npcId:
          (json['npcId'] ?? json['id'] ?? json['NPC ID'])?.toString().trim() ??
              '',
      name: (json['name'] ?? json['姓名'] ?? json['名字'] ?? json['npc'])
              ?.toString()
              .trim() ??
          '',
      description:
          (json['description'] ?? json['简介'] ?? json['描述'] ?? json['人设'])
                  ?.toString()
                  .trim() ??
              '',
      impression: (json['impression'] ?? json['印象'] ?? json['态度'] ?? json['关系'])
              ?.toString()
              .trim() ??
          '',
      affinity: rawAffinity == null
          ? null
          : rawAffinity is num
              ? rawAffinity.round().clamp(-100, 100)
              : int.tryParse(rawAffinity.toString().replaceAll(
                    RegExp(r'[^0-9-]'),
                    '',
                  ))?.clamp(-100, 100),
      affinityDelta: rawAffinityDelta == null
          ? null
          : rawAffinityDelta is num
              ? rawAffinityDelta.round().clamp(-12, 12)
              : int.tryParse(rawAffinityDelta.toString().replaceAll(
                    RegExp(r'[^0-9-]'),
                    '',
                  ))?.clamp(-12, 12),
      lifecycle: (json['lifecycle'] ?? json['lifeState'] ?? json['生命周期'])
              ?.toString()
              .trim() ??
          '',
      lifecycleReason:
          (json['lifecycleReason'] ?? json['生命周期原因'] ?? json['状态原因'])
                  ?.toString()
                  .trim() ??
              '',
      proactiveMessage:
          NpcMessageClassifier.isDeliverableChatBubble(rawProactiveMessage)
              ? rawProactiveMessage
              : '',
    );
  }

  final String name;
  final String npcId;
  final String description;
  final String impression;
  final int? affinity;
  final int? affinityDelta;
  final String lifecycle;
  final String lifecycleReason;
  final String proactiveMessage;

  bool get isEmpty =>
      name.trim().isEmpty &&
      npcId.trim().isEmpty &&
      description.trim().isEmpty &&
      impression.trim().isEmpty &&
      affinity == null &&
      affinityDelta == null &&
      lifecycle.trim().isEmpty &&
      proactiveMessage.trim().isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'npcId': npcId,
      'description': description,
      'impression': impression,
      'affinity': affinity,
      'affinityDelta': affinityDelta,
      'lifecycle': lifecycle,
      'lifecycleReason': lifecycleReason,
      'proactiveMessage': proactiveMessage,
    };
  }
}
