import 'map_gameplay.dart';

export 'map_gameplay.dart';

class MapLocationNode {
  MapLocationNode({
    required this.id,
    required this.name,
    this.parentId = '',
    this.description = '',
    this.html = '',
    this.scene = '',
    this.status = MapLocationStatus.available,
    this.npcs = const <String>[],
    this.clues = const <String>[],
    this.nextActions = const <String>[],
    this.riskLevel = '',
    this.timeCost = '',
    this.x = 0.5,
    this.y = 0.5,
    this.tags = const <String>[],
    this.actions = const <MapActionDefinition>[],
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory MapLocationNode.fromJson(Map<String, dynamic> json) {
    return MapLocationNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentId: json['parentId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      html: json['html']?.toString() ?? '',
      scene: json['scene']?.toString() ?? '',
      status: MapLocationStatus.fromJson(json['status']),
      npcs: _readStringList(json['npcs']),
      clues: _readStringList(json['clues']),
      nextActions: _readStringList(json['nextActions']),
      riskLevel:
          json['riskLevel']?.toString() ?? json['risk']?.toString() ?? '',
      timeCost: json['timeCost']?.toString() ?? json['cost']?.toString() ?? '',
      x: _readDouble(json['x'], fallback: 0.5).clamp(0.05, 0.95),
      y: _readDouble(json['y'], fallback: 0.5).clamp(0.05, 0.95),
      tags: _readStringList(json['tags']),
      actions: _readMapActions(json['actions']),
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String name;
  final String parentId;
  final String description;
  final String html;
  final String scene;
  final MapLocationStatus status;
  final List<String> npcs;
  final List<String> clues;
  final List<String> nextActions;
  final String riskLevel;
  final String timeCost;
  final double x;
  final double y;
  final List<String> tags;
  final List<MapActionDefinition> actions;
  final DateTime generatedAt;

  bool get hasGeneratedContent =>
      html.trim().isNotEmpty || scene.trim().isNotEmpty;

  bool get isCurrentCandidate => status == MapLocationStatus.current;

  bool get isExploredCandidate => status == MapLocationStatus.explored;

  MapLocationNode copyWith({
    String? id,
    String? name,
    String? parentId,
    String? description,
    String? html,
    String? scene,
    MapLocationStatus? status,
    List<String>? npcs,
    List<String>? clues,
    List<String>? nextActions,
    String? riskLevel,
    String? timeCost,
    double? x,
    double? y,
    List<String>? tags,
    List<MapActionDefinition>? actions,
    DateTime? generatedAt,
  }) {
    return MapLocationNode(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      description: description ?? this.description,
      html: html ?? this.html,
      scene: scene ?? this.scene,
      status: status ?? this.status,
      npcs: npcs ?? this.npcs,
      clues: clues ?? this.clues,
      nextActions: nextActions ?? this.nextActions,
      riskLevel: riskLevel ?? this.riskLevel,
      timeCost: timeCost ?? this.timeCost,
      x: x ?? this.x,
      y: y ?? this.y,
      tags: tags ?? this.tags,
      actions: actions ?? this.actions,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'parentId': parentId,
      'description': description,
      'html': html,
      'scene': scene,
      'status': status.name,
      'npcs': npcs,
      'clues': clues,
      'nextActions': nextActions,
      'riskLevel': riskLevel,
      'timeCost': timeCost,
      'x': x,
      'y': y,
      'tags': tags,
      'actions': actions.map((item) => item.toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

enum MapLocationStatus {
  locked,
  available,
  current,
  explored,
  hidden;

  static MapLocationStatus fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    switch (raw) {
      case 'available':
      case 'unlocked':
      case 'open':
      case '可前往':
      case '已解锁':
        return MapLocationStatus.available;
      case 'current':
      case 'active':
      case '当前位置':
      case '当前':
        return MapLocationStatus.current;
      case 'explored':
      case 'visited':
      case 'done':
      case '已探索':
      case '去过':
        return MapLocationStatus.explored;
      case 'hidden':
      case 'secret':
      case '隐藏':
      case '未知':
        return MapLocationStatus.hidden;
      case 'locked':
      case '锁定':
      case '未解锁':
        return MapLocationStatus.locked;
      default:
        return MapLocationStatus.available;
    }
  }
}

class MapStoryChoice {
  const MapStoryChoice({
    required this.id,
    required this.label,
    this.action = '',
    this.locationId = '',
    this.kind = MapStoryChoiceKind.action,
    this.riskLevel = '',
    this.timeCost = '',
  });

  factory MapStoryChoice.fromJson(Map<String, dynamic> json) {
    final label = json['label']?.toString() ??
        json['title']?.toString() ??
        json['action']?.toString() ??
        '';
    return MapStoryChoice(
      id: json['id']?.toString() ?? label,
      label: label,
      action: json['action']?.toString() ??
          json['prompt']?.toString() ??
          json['description']?.toString() ??
          label,
      locationId: json['locationId']?.toString() ?? '',
      kind: MapStoryChoiceKind.fromJson(json['kind'] ?? json['type']),
      riskLevel:
          json['riskLevel']?.toString() ?? json['risk']?.toString() ?? '',
      timeCost: json['timeCost']?.toString() ?? json['cost']?.toString() ?? '',
    );
  }

  final String id;
  final String label;
  final String action;
  final String locationId;
  final MapStoryChoiceKind kind;
  final String riskLevel;
  final String timeCost;

  MapStoryChoice copyWith({
    String? id,
    String? label,
    String? action,
    String? locationId,
    MapStoryChoiceKind? kind,
    String? riskLevel,
    String? timeCost,
  }) {
    return MapStoryChoice(
      id: id ?? this.id,
      label: label ?? this.label,
      action: action ?? this.action,
      locationId: locationId ?? this.locationId,
      kind: kind ?? this.kind,
      riskLevel: riskLevel ?? this.riskLevel,
      timeCost: timeCost ?? this.timeCost,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'action': action,
      'locationId': locationId,
      'kind': kind.name,
      'riskLevel': riskLevel,
      'timeCost': timeCost,
    };
  }
}

enum MapStoryChoiceKind {
  action,
  location,
  clue,
  social,
  danger,
  rest;

  static MapStoryChoiceKind fromJson(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    switch (raw) {
      case 'location':
      case 'place':
      case '地点':
      case '移动':
        return MapStoryChoiceKind.location;
      case 'clue':
      case 'investigate':
      case '线索':
      case '调查':
        return MapStoryChoiceKind.clue;
      case 'social':
      case 'npc':
      case 'relationship':
      case '社交':
        return MapStoryChoiceKind.social;
      case 'danger':
      case 'conflict':
      case 'battle':
      case '危险':
      case '冲突':
        return MapStoryChoiceKind.danger;
      case 'rest':
      case 'time':
      case '休整':
      case '时间':
        return MapStoryChoiceKind.rest;
      case 'action':
      default:
        return MapStoryChoiceKind.action;
    }
  }
}

class MapNpcPosition {
  const MapNpcPosition({
    required this.id,
    required this.name,
    this.locationId = '',
    this.locationName = '',
    this.status = '',
    this.intent = '',
    this.lastSeen = '',
  });

  factory MapNpcPosition.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ??
        json['npc']?.toString() ??
        json['npcName']?.toString() ??
        '';
    return MapNpcPosition(
      id: json['id']?.toString() ?? name,
      name: name,
      locationId: json['locationId']?.toString() ?? '',
      locationName: json['locationName']?.toString() ??
          json['location']?.toString() ??
          '',
      status: json['status']?.toString() ?? '',
      intent: json['intent']?.toString() ??
          json['nextMove']?.toString() ??
          json['goal']?.toString() ??
          '',
      lastSeen: json['lastSeen']?.toString() ?? json['time']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
  final String locationId;
  final String locationName;
  final String status;
  final String intent;
  final String lastSeen;

  MapNpcPosition copyWith({
    String? id,
    String? name,
    String? locationId,
    String? locationName,
    String? status,
    String? intent,
    String? lastSeen,
  }) {
    return MapNpcPosition(
      id: id ?? this.id,
      name: name ?? this.name,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      status: status ?? this.status,
      intent: intent ?? this.intent,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'locationId': locationId,
      'locationName': locationName,
      'status': status,
      'intent': intent,
      'lastSeen': lastSeen,
    };
  }
}

class MapOpeningChoice {
  MapOpeningChoice({
    required this.id,
    required this.category,
    required this.label,
    this.description = '',
    this.prompt = '',
  });

  factory MapOpeningChoice.fromJson(Map<String, dynamic> json) {
    return MapOpeningChoice(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
    );
  }

  final String id;
  final String category;
  final String label;
  final String description;
  final String prompt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'category': category,
      'label': label,
      'description': description,
      'prompt': prompt,
    };
  }
}

class MapWorldState {
  const MapWorldState({
    required this.characterId,
    required this.updatedAt,
    this.title = '',
    this.timeLabel = '',
    this.stage = '',
    this.mainGoal = '',
    this.currentScene = '',
    this.currentLocationId = '',
    this.currentLocationName = '',
    this.mapHtml = '',
    this.locations = const <MapLocationNode>[],
    this.activeChoices = const <MapStoryChoice>[],
    this.discoveredClues = const <String>[],
    this.npcPositions = const <MapNpcPosition>[],
    this.npcMovements = const <String>[],
    this.eventSummary = '',
    this.eventLog = const <String>[],
    this.openingChoices = const <MapOpeningChoice>[],
    this.openingResolved = false,
    this.openingSummary = '',
    this.schemaVersion = 1,
    this.seed = 0,
    this.turnNumber = 0,
    this.baseActionPoints = 3,
    this.currentActionPoints = 3,
    this.temporaryActionPointLimit = 5,
    this.maxActionPoints = 8,
    this.birthLocationId = '',
    this.spawnCandidates = const <MapSpawnCandidate>[],
    this.edges = const <MapEdge>[],
    this.mapInventory = const <MapInventoryItem>[],
    this.statusEffects = const <MapStatusEffect>[],
    this.quests = const <MapQuestState>[],
    this.worldEvents = const <MapWorldEvent>[],
    this.npcAgents = const <MapNpcAgentState>[],
    this.facts = const <String>[],
    this.threatClock = 0,
    this.threatLimit = 12,
    this.nextMoveDiscount = 0,
    this.actionItemUsedThisTurn = false,
  });

  factory MapWorldState.empty(String characterId) {
    return MapWorldState(
      characterId: characterId,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory MapWorldState.fromJson(Map<String, dynamic> json) {
    final rawLocations = json['locations'];
    final rawNpcPositions = json['npcPositions'];
    final rawEventLog = json['eventLog'];
    final rawOpeningChoices = json['openingChoices'];
    final hasTemporaryActionPointLimit =
        json.containsKey('temporaryActionPointLimit');
    final temporaryActionPointLimit = _readInt(
      hasTemporaryActionPointLimit
          ? json['temporaryActionPointLimit']
          : json['maxActionPoints'],
      fallback: 5,
    ).clamp(3, 8);
    final maxActionPoints = hasTemporaryActionPointLimit
        ? _readInt(json['maxActionPoints'], fallback: 8)
            .clamp(temporaryActionPointLimit, 8)
        : 8;
    return MapWorldState(
      characterId: json['characterId']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: json['title']?.toString() ?? '',
      timeLabel: json['timeLabel']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      mainGoal: json['mainGoal']?.toString() ?? '',
      currentScene: json['currentScene']?.toString() ?? '',
      currentLocationId: json['currentLocationId']?.toString() ?? '',
      currentLocationName: json['currentLocationName']?.toString() ?? '',
      mapHtml: json['mapHtml']?.toString() ?? '',
      locations: rawLocations is List
          ? rawLocations
              .whereType<Map>()
              .map(
                (item) =>
                    MapLocationNode.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.trim().isNotEmpty)
              .toList(growable: false)
          : const <MapLocationNode>[],
      activeChoices: _readChoiceList(json['activeChoices']),
      discoveredClues: _readStringList(json['discoveredClues']),
      npcPositions: rawNpcPositions is List
          ? rawNpcPositions
              .whereType<Map>()
              .map(
                (item) =>
                    MapNpcPosition.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.name.trim().isNotEmpty)
              .toList(growable: false)
          : const <MapNpcPosition>[],
      npcMovements: _readStringList(json['npcMovements']),
      eventSummary: json['eventSummary']?.toString() ?? '',
      eventLog: rawEventLog is List
          ? rawEventLog
              .map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      openingChoices: rawOpeningChoices is List
          ? rawOpeningChoices
              .whereType<Map>()
              .map(
                (item) =>
                    MapOpeningChoice.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.trim().isNotEmpty)
              .toList(growable: false)
          : const <MapOpeningChoice>[],
      openingResolved: json['openingResolved'] == true,
      openingSummary: json['openingSummary']?.toString() ?? '',
      schemaVersion: _readInt(json['schemaVersion'], fallback: 1),
      seed: _readInt(json['seed']),
      turnNumber: _readInt(json['turnNumber']),
      baseActionPoints:
          _readInt(json['baseActionPoints'], fallback: 3).clamp(1, 5),
      currentActionPoints: _readInt(
        json['currentActionPoints'],
        fallback: 3,
      ).clamp(0, maxActionPoints),
      temporaryActionPointLimit: temporaryActionPointLimit,
      maxActionPoints: maxActionPoints,
      birthLocationId: json['birthLocationId']?.toString() ?? '',
      spawnCandidates: _readObjectList(
        json['spawnCandidates'],
        MapSpawnCandidate.fromJson,
      ),
      edges: _readObjectList(json['edges'], MapEdge.fromJson),
      mapInventory: _readObjectList(
        json['mapInventory'] ?? json['items'],
        MapInventoryItem.fromJson,
      ),
      statusEffects: _readObjectList(
        json['statusEffects'],
        MapStatusEffect.fromJson,
      ),
      quests: _readObjectList(json['quests'], MapQuestState.fromJson),
      worldEvents: _readObjectList(
        json['worldEvents'] ?? json['events'],
        MapWorldEvent.fromJson,
      ),
      npcAgents: _readObjectList(
        json['npcAgents'],
        MapNpcAgentState.fromJson,
      ),
      facts: _readStringList(json['facts']),
      threatClock: _readInt(json['threatClock']).clamp(0, 9999),
      threatLimit: _readInt(json['threatLimit'], fallback: 12).clamp(4, 9999),
      nextMoveDiscount: _readInt(json['nextMoveDiscount']).clamp(0, 2),
      actionItemUsedThisTurn: json['actionItemUsedThisTurn'] == true,
    );
  }

  final String characterId;
  final DateTime updatedAt;
  final String title;
  final String timeLabel;
  final String stage;
  final String mainGoal;
  final String currentScene;
  final String currentLocationId;
  final String currentLocationName;
  final String mapHtml;
  final List<MapLocationNode> locations;
  final List<MapStoryChoice> activeChoices;
  final List<String> discoveredClues;
  final List<MapNpcPosition> npcPositions;
  final List<String> npcMovements;
  final String eventSummary;
  final List<String> eventLog;
  final List<MapOpeningChoice> openingChoices;
  final bool openingResolved;
  final String openingSummary;
  final int schemaVersion;
  final int seed;
  final int turnNumber;
  final int baseActionPoints;
  final int currentActionPoints;
  final int temporaryActionPointLimit;
  final int maxActionPoints;
  final String birthLocationId;
  final List<MapSpawnCandidate> spawnCandidates;
  final List<MapEdge> edges;
  final List<MapInventoryItem> mapInventory;
  final List<MapStatusEffect> statusEffects;
  final List<MapQuestState> quests;
  final List<MapWorldEvent> worldEvents;
  final List<MapNpcAgentState> npcAgents;
  final List<String> facts;
  final int threatClock;
  final int threatLimit;
  final int nextMoveDiscount;
  final bool actionItemUsedThisTurn;

  bool get isEmpty =>
      mapHtml.trim().isEmpty && locations.isEmpty && eventLog.isEmpty;

  bool get needsOpeningSetup =>
      !openingResolved && mapHtml.trim().isEmpty && locations.isEmpty;

  bool get isRulesDriven => schemaVersion >= 2 && edges.isNotEmpty;

  bool get needsBirthSelection =>
      isRulesDriven && birthLocationId.trim().isEmpty;

  MapLocationNode? get currentLocation {
    final id = currentLocationId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final location in locations) {
      if (location.id == id) {
        return location;
      }
    }
    return null;
  }

  String get activeHtml {
    final locationHtml = currentLocation?.html.trim() ?? '';
    return locationHtml.isNotEmpty ? locationHtml : mapHtml;
  }

  String get activeScene {
    final locationScene = currentLocation?.scene.trim() ?? '';
    return currentScene.trim().isNotEmpty ? currentScene : locationScene;
  }

  MapWorldState copyWith({
    String? characterId,
    DateTime? updatedAt,
    String? title,
    String? timeLabel,
    String? stage,
    String? mainGoal,
    String? currentScene,
    String? currentLocationId,
    String? currentLocationName,
    String? mapHtml,
    List<MapLocationNode>? locations,
    List<MapStoryChoice>? activeChoices,
    List<String>? discoveredClues,
    List<MapNpcPosition>? npcPositions,
    List<String>? npcMovements,
    String? eventSummary,
    List<String>? eventLog,
    List<MapOpeningChoice>? openingChoices,
    bool? openingResolved,
    String? openingSummary,
    int? schemaVersion,
    int? seed,
    int? turnNumber,
    int? baseActionPoints,
    int? currentActionPoints,
    int? temporaryActionPointLimit,
    int? maxActionPoints,
    String? birthLocationId,
    List<MapSpawnCandidate>? spawnCandidates,
    List<MapEdge>? edges,
    List<MapInventoryItem>? mapInventory,
    List<MapStatusEffect>? statusEffects,
    List<MapQuestState>? quests,
    List<MapWorldEvent>? worldEvents,
    List<MapNpcAgentState>? npcAgents,
    List<String>? facts,
    int? threatClock,
    int? threatLimit,
    int? nextMoveDiscount,
    bool? actionItemUsedThisTurn,
  }) {
    return MapWorldState(
      characterId: characterId ?? this.characterId,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      timeLabel: timeLabel ?? this.timeLabel,
      stage: stage ?? this.stage,
      mainGoal: mainGoal ?? this.mainGoal,
      currentScene: currentScene ?? this.currentScene,
      currentLocationId: currentLocationId ?? this.currentLocationId,
      currentLocationName: currentLocationName ?? this.currentLocationName,
      mapHtml: mapHtml ?? this.mapHtml,
      locations: locations ?? this.locations,
      activeChoices: activeChoices ?? this.activeChoices,
      discoveredClues: discoveredClues ?? this.discoveredClues,
      npcPositions: npcPositions ?? this.npcPositions,
      npcMovements: npcMovements ?? this.npcMovements,
      eventSummary: eventSummary ?? this.eventSummary,
      eventLog: eventLog ?? this.eventLog,
      openingChoices: openingChoices ?? this.openingChoices,
      openingResolved: openingResolved ?? this.openingResolved,
      openingSummary: openingSummary ?? this.openingSummary,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      seed: seed ?? this.seed,
      turnNumber: turnNumber ?? this.turnNumber,
      baseActionPoints: baseActionPoints ?? this.baseActionPoints,
      currentActionPoints: currentActionPoints ?? this.currentActionPoints,
      temporaryActionPointLimit:
          temporaryActionPointLimit ?? this.temporaryActionPointLimit,
      maxActionPoints: maxActionPoints ?? this.maxActionPoints,
      birthLocationId: birthLocationId ?? this.birthLocationId,
      spawnCandidates: spawnCandidates ?? this.spawnCandidates,
      edges: edges ?? this.edges,
      mapInventory: mapInventory ?? this.mapInventory,
      statusEffects: statusEffects ?? this.statusEffects,
      quests: quests ?? this.quests,
      worldEvents: worldEvents ?? this.worldEvents,
      npcAgents: npcAgents ?? this.npcAgents,
      facts: facts ?? this.facts,
      threatClock: threatClock ?? this.threatClock,
      threatLimit: threatLimit ?? this.threatLimit,
      nextMoveDiscount: nextMoveDiscount ?? this.nextMoveDiscount,
      actionItemUsedThisTurn:
          actionItemUsedThisTurn ?? this.actionItemUsedThisTurn,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'updatedAt': updatedAt.toIso8601String(),
      'title': title,
      'timeLabel': timeLabel,
      'stage': stage,
      'mainGoal': mainGoal,
      'currentScene': currentScene,
      'currentLocationId': currentLocationId,
      'currentLocationName': currentLocationName,
      'mapHtml': mapHtml,
      'locations': locations.map((item) => item.toJson()).toList(),
      'activeChoices': activeChoices.map((item) => item.toJson()).toList(),
      'discoveredClues': discoveredClues,
      'npcPositions': npcPositions.map((item) => item.toJson()).toList(),
      'npcMovements': npcMovements,
      'eventSummary': eventSummary,
      'eventLog': eventLog,
      'openingChoices': openingChoices.map((item) => item.toJson()).toList(),
      'openingResolved': openingResolved,
      'openingSummary': openingSummary,
      'schemaVersion': schemaVersion,
      'seed': seed,
      'turnNumber': turnNumber,
      'baseActionPoints': baseActionPoints,
      'currentActionPoints': currentActionPoints,
      'temporaryActionPointLimit': temporaryActionPointLimit,
      'maxActionPoints': maxActionPoints,
      'birthLocationId': birthLocationId,
      'spawnCandidates': spawnCandidates.map((item) => item.toJson()).toList(),
      'edges': edges.map((item) => item.toJson()).toList(),
      'mapInventory': mapInventory.map((item) => item.toJson()).toList(),
      'statusEffects': statusEffects.map((item) => item.toJson()).toList(),
      'quests': quests.map((item) => item.toJson()).toList(),
      'worldEvents': worldEvents.map((item) => item.toJson()).toList(),
      'npcAgents': npcAgents.map((item) => item.toJson()).toList(),
      'facts': facts,
      'threatClock': threatClock,
      'threatLimit': threatLimit,
      'nextMoveDiscount': nextMoveDiscount,
      'actionItemUsedThisTurn': actionItemUsedThisTurn,
    };
  }
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<MapStoryChoice> _readChoiceList(Object? value) {
  if (value is! List) {
    return const <MapStoryChoice>[];
  }
  return value
      .whereType<Map>()
      .map((item) => MapStoryChoice.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.label.trim().isNotEmpty)
      .toList(growable: false);
}

List<MapActionDefinition> _readMapActions(Object? value) {
  return _readObjectList(value, MapActionDefinition.fromJson);
}

List<T> _readObjectList<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _readDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
