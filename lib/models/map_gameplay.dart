enum MapItemKind {
  restoreActionPoints,
  moveDiscount,
  camp,
  key,
  intel;

  static MapItemKind fromJson(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'restore_action_points':
      case 'restoreactionpoints':
      case 'ap':
      case 'food':
        return MapItemKind.restoreActionPoints;
      case 'move_discount':
      case 'movediscount':
      case 'ticket':
      case 'transport':
        return MapItemKind.moveDiscount;
      case 'camp':
      case 'rest':
        return MapItemKind.camp;
      case 'key':
      case 'access':
        return MapItemKind.key;
      case 'intel':
      case 'map':
      case 'reveal':
        return MapItemKind.intel;
      default:
        return MapItemKind.restoreActionPoints;
    }
  }
}

class MapEdge {
  const MapEdge({
    required this.id,
    required this.fromId,
    required this.toId,
    this.actionPointCost = 1,
    this.riskLevel = '低',
    this.timeCost = '片刻',
    this.tags = const <String>[],
    this.requiredItemId = '',
    this.blocked = false,
    this.discovered = true,
  });

  factory MapEdge.fromJson(Map<String, dynamic> json) {
    final fromId =
        (json['fromId'] ?? json['from'] ?? json['a'])?.toString().trim() ?? '';
    final toId =
        (json['toId'] ?? json['to'] ?? json['b'])?.toString().trim() ?? '';
    final rawCost = json['actionPointCost'] ?? json['cost'] ?? json['apCost'];
    final cost = rawCost is num
        ? rawCost.round()
        : int.tryParse(rawCost?.toString() ?? '') ?? 1;
    return MapEdge(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString().trim()
          : stableId(fromId, toId),
      fromId: fromId,
      toId: toId,
      actionPointCost: cost.clamp(1, 2),
      riskLevel: (json['riskLevel'] ?? json['risk'])?.toString().trim() ?? '低',
      timeCost: (json['timeCost'] ?? json['time'])?.toString().trim() ?? '片刻',
      tags: _readStringList(json['tags']),
      requiredItemId:
          (json['requiredItemId'] ?? json['requiredItem'])?.toString().trim() ??
              '',
      blocked: json['blocked'] == true,
      discovered:
          json['discovered'] is bool ? json['discovered'] as bool : true,
    );
  }

  final String id;
  final String fromId;
  final String toId;
  final int actionPointCost;
  final String riskLevel;
  final String timeCost;
  final List<String> tags;
  final String requiredItemId;
  final bool blocked;
  final bool discovered;

  bool connects(String locationId) =>
      fromId == locationId || toId == locationId;

  String? other(String locationId) {
    if (fromId == locationId) {
      return toId;
    }
    if (toId == locationId) {
      return fromId;
    }
    return null;
  }

  MapEdge copyWith({
    String? id,
    String? fromId,
    String? toId,
    int? actionPointCost,
    String? riskLevel,
    String? timeCost,
    List<String>? tags,
    String? requiredItemId,
    bool? blocked,
    bool? discovered,
  }) {
    return MapEdge(
      id: id ?? this.id,
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      actionPointCost: actionPointCost ?? this.actionPointCost,
      riskLevel: riskLevel ?? this.riskLevel,
      timeCost: timeCost ?? this.timeCost,
      tags: tags ?? this.tags,
      requiredItemId: requiredItemId ?? this.requiredItemId,
      blocked: blocked ?? this.blocked,
      discovered: discovered ?? this.discovered,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'actionPointCost': actionPointCost,
        'riskLevel': riskLevel,
        'timeCost': timeCost,
        'tags': tags,
        'requiredItemId': requiredItemId,
        'blocked': blocked,
        'discovered': discovered,
      };

  static String stableId(String fromId, String toId) {
    final ends = <String>[fromId.trim(), toId.trim()]..sort();
    return 'edge_${ends.join('_')}';
  }
}

class MapSpawnCandidate {
  const MapSpawnCandidate({
    required this.locationId,
    required this.label,
    this.description = '',
    this.style = 'safe',
  });

  factory MapSpawnCandidate.fromJson(Map<String, dynamic> json) {
    return MapSpawnCandidate(
      locationId: (json['locationId'] ?? json['id'])?.toString().trim() ?? '',
      label: (json['label'] ?? json['name'])?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      style: json['style']?.toString().trim() ?? 'safe',
    );
  }

  final String locationId;
  final String label;
  final String description;
  final String style;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'locationId': locationId,
        'label': label,
        'description': description,
        'style': style,
      };
}

class MapActionDefinition {
  const MapActionDefinition({
    required this.id,
    required this.label,
    this.description = '',
    this.kind = 'action',
    this.actionPointCost = 1,
    this.riskLevel = '低',
    this.requiredItemId = '',
    this.clue = '',
    this.rewardItemId = '',
    this.oneShot = false,
    this.completed = false,
  });

  factory MapActionDefinition.fromJson(Map<String, dynamic> json) {
    final label =
        (json['label'] ?? json['name'] ?? json['action'])?.toString().trim() ??
            '';
    final rawCost = json['actionPointCost'] ?? json['cost'] ?? json['apCost'];
    final cost = rawCost is num
        ? rawCost.round()
        : int.tryParse(rawCost?.toString() ?? '') ?? 1;
    return MapActionDefinition(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString().trim()
          : _stableSlug(label),
      label: label,
      description:
          (json['description'] ?? json['action'])?.toString().trim() ?? '',
      kind: json['kind']?.toString().trim().toLowerCase() ?? 'action',
      actionPointCost: cost.clamp(1, 2),
      riskLevel: (json['riskLevel'] ?? json['risk'])?.toString().trim() ?? '低',
      requiredItemId:
          (json['requiredItemId'] ?? json['requiredItem'])?.toString().trim() ??
              '',
      clue: json['clue']?.toString().trim() ?? '',
      rewardItemId:
          (json['rewardItemId'] ?? json['rewardItem'])?.toString().trim() ?? '',
      oneShot: json['oneShot'] == true,
      completed: json['completed'] == true,
    );
  }

  final String id;
  final String label;
  final String description;
  final String kind;
  final int actionPointCost;
  final String riskLevel;
  final String requiredItemId;
  final String clue;
  final String rewardItemId;
  final bool oneShot;
  final bool completed;

  MapActionDefinition copyWith({bool? completed}) => MapActionDefinition(
        id: id,
        label: label,
        description: description,
        kind: kind,
        actionPointCost: actionPointCost,
        riskLevel: riskLevel,
        requiredItemId: requiredItemId,
        clue: clue,
        rewardItemId: rewardItemId,
        oneShot: oneShot,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'description': description,
        'kind': kind,
        'actionPointCost': actionPointCost,
        'riskLevel': riskLevel,
        'requiredItemId': requiredItemId,
        'clue': clue,
        'rewardItemId': rewardItemId,
        'oneShot': oneShot,
        'completed': completed,
      };
}

class MapInventoryItem {
  const MapInventoryItem({
    required this.id,
    required this.name,
    required this.kind,
    this.description = '',
    this.quantity = 1,
    this.amount = 1,
    this.targetTag = '',
    this.sideEffect = '',
  });

  factory MapInventoryItem.fromJson(Map<String, dynamic> json) {
    final rawQuantity = json['quantity'] ?? json['count'];
    final quantity = rawQuantity is num
        ? rawQuantity.round()
        : int.tryParse(rawQuantity?.toString() ?? '') ?? 1;
    final rawAmount = json['amount'] ?? json['value'];
    final amount = rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString() ?? '') ?? 1;
    return MapInventoryItem(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      kind: MapItemKind.fromJson(json['kind'] ?? json['type']),
      description: json['description']?.toString().trim() ?? '',
      quantity: quantity.clamp(0, 99),
      amount: amount.clamp(1, 5),
      targetTag: json['targetTag']?.toString().trim() ?? '',
      sideEffect: json['sideEffect']?.toString().trim() ?? '',
    );
  }

  final String id;
  final String name;
  final MapItemKind kind;
  final String description;
  final int quantity;
  final int amount;
  final String targetTag;
  final String sideEffect;

  MapInventoryItem copyWith({int? quantity}) => MapInventoryItem(
        id: id,
        name: name,
        kind: kind,
        description: description,
        quantity: quantity ?? this.quantity,
        amount: amount,
        targetTag: targetTag,
        sideEffect: sideEffect,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'kind': kind.name,
        'description': description,
        'quantity': quantity,
        'amount': amount,
        'targetTag': targetTag,
        'sideEffect': sideEffect,
      };
}

class MapStatusEffect {
  const MapStatusEffect({
    required this.id,
    required this.name,
    this.remainingTurns = 1,
    this.nextTurnActionPointModifier = 0,
    this.description = '',
  });

  factory MapStatusEffect.fromJson(Map<String, dynamic> json) {
    return MapStatusEffect(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      remainingTurns:
          _readInt(json['remainingTurns'], fallback: 1).clamp(0, 99),
      nextTurnActionPointModifier:
          _readInt(json['nextTurnActionPointModifier']).clamp(-2, 2),
      description: json['description']?.toString().trim() ?? '',
    );
  }

  final String id;
  final String name;
  final int remainingTurns;
  final int nextTurnActionPointModifier;
  final String description;

  MapStatusEffect copyWith({int? remainingTurns}) => MapStatusEffect(
        id: id,
        name: name,
        remainingTurns: remainingTurns ?? this.remainingTurns,
        nextTurnActionPointModifier: nextTurnActionPointModifier,
        description: description,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'remainingTurns': remainingTurns,
        'nextTurnActionPointModifier': nextTurnActionPointModifier,
        'description': description,
      };
}

enum MapQuestStatus {
  active,
  completed,
  failed;

  static MapQuestStatus fromJson(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'completed':
      case 'done':
        return MapQuestStatus.completed;
      case 'failed':
      case 'expired':
        return MapQuestStatus.failed;
      default:
        return MapQuestStatus.active;
    }
  }
}

class MapQuestState {
  const MapQuestState({
    required this.id,
    required this.title,
    this.description = '',
    this.targetLocationIds = const <String>[],
    this.progress = 0,
    this.total = 3,
    this.deadlineTurn = 0,
    this.status = MapQuestStatus.active,
  });

  factory MapQuestState.fromJson(Map<String, dynamic> json) => MapQuestState(
        id: json['id']?.toString().trim() ?? '',
        title: (json['title'] ?? json['name'])?.toString().trim() ?? '',
        description: json['description']?.toString().trim() ?? '',
        targetLocationIds: _readStringList(
          json['targetLocationIds'] ?? json['locations'],
        ),
        progress: _readInt(json['progress']).clamp(0, 999),
        total: _readInt(json['total'], fallback: 3).clamp(1, 999),
        deadlineTurn: _readInt(json['deadlineTurn']).clamp(0, 9999),
        status: MapQuestStatus.fromJson(json['status']),
      );

  final String id;
  final String title;
  final String description;
  final List<String> targetLocationIds;
  final int progress;
  final int total;
  final int deadlineTurn;
  final MapQuestStatus status;

  MapQuestState copyWith({
    int? progress,
    MapQuestStatus? status,
  }) =>
      MapQuestState(
        id: id,
        title: title,
        description: description,
        targetLocationIds: targetLocationIds,
        progress: progress ?? this.progress,
        total: total,
        deadlineTurn: deadlineTurn,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'targetLocationIds': targetLocationIds,
        'progress': progress,
        'total': total,
        'deadlineTurn': deadlineTurn,
        'status': status.name,
      };
}

class MapWorldEvent {
  const MapWorldEvent({
    required this.id,
    required this.title,
    required this.narrative,
    this.locationId = '',
    this.kind = 'story',
    this.triggerTurn = 1,
    this.weight = 1,
    this.clue = '',
    this.rewardItemId = '',
    this.threatDelta = 0,
    this.blockEdgeId = '',
    this.resolved = false,
  });

  factory MapWorldEvent.fromJson(Map<String, dynamic> json) => MapWorldEvent(
        id: json['id']?.toString().trim() ?? '',
        title: (json['title'] ?? json['name'])?.toString().trim() ?? '',
        narrative:
            (json['narrative'] ?? json['description'])?.toString().trim() ?? '',
        locationId: json['locationId']?.toString().trim() ?? '',
        kind: json['kind']?.toString().trim() ?? 'story',
        triggerTurn: _readInt(json['triggerTurn'], fallback: 1).clamp(1, 9999),
        weight: _readInt(json['weight'], fallback: 1).clamp(1, 100),
        clue: json['clue']?.toString().trim() ?? '',
        rewardItemId:
            (json['rewardItemId'] ?? json['rewardItem'])?.toString().trim() ??
                '',
        threatDelta: _readInt(json['threatDelta']).clamp(-10, 10),
        blockEdgeId: json['blockEdgeId']?.toString().trim() ?? '',
        resolved: json['resolved'] == true,
      );

  final String id;
  final String title;
  final String narrative;
  final String locationId;
  final String kind;
  final int triggerTurn;
  final int weight;
  final String clue;
  final String rewardItemId;
  final int threatDelta;
  final String blockEdgeId;
  final bool resolved;

  MapWorldEvent copyWith({bool? resolved}) => MapWorldEvent(
        id: id,
        title: title,
        narrative: narrative,
        locationId: locationId,
        kind: kind,
        triggerTurn: triggerTurn,
        weight: weight,
        clue: clue,
        rewardItemId: rewardItemId,
        threatDelta: threatDelta,
        blockEdgeId: blockEdgeId,
        resolved: resolved ?? this.resolved,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'narrative': narrative,
        'locationId': locationId,
        'kind': kind,
        'triggerTurn': triggerTurn,
        'weight': weight,
        'clue': clue,
        'rewardItemId': rewardItemId,
        'threatDelta': threatDelta,
        'blockEdgeId': blockEdgeId,
        'resolved': resolved,
      };
}

class MapNpcAgentState {
  const MapNpcAgentState({
    required this.id,
    required this.name,
    required this.trueLocationId,
    this.homeLocationId = '',
    this.goalLocationId = '',
    this.goal = '',
    this.traits = const <String>[],
    this.scheduleLocationIds = const <String>[],
    this.knowledge = const <String>[],
    this.relation = 0,
    this.riskTolerance = 50,
    this.lastKnownLocationId = '',
    this.lastKnownTurn = 0,
    this.status = '行动中',
    this.intent = '',
  });

  factory MapNpcAgentState.fromJson(Map<String, dynamic> json) {
    final locationId =
        (json['trueLocationId'] ?? json['locationId'] ?? json['homeLocationId'])
                ?.toString()
                .trim() ??
            '';
    return MapNpcAgentState(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      trueLocationId: locationId,
      homeLocationId: json['homeLocationId']?.toString().trim() ?? locationId,
      goalLocationId: json['goalLocationId']?.toString().trim() ?? '',
      goal: json['goal']?.toString().trim() ?? '',
      traits: _readStringList(json['traits']),
      scheduleLocationIds: _readStringList(
        json['scheduleLocationIds'] ?? json['schedule'],
      ),
      knowledge: _readStringList(json['knowledge']),
      relation: _readInt(json['relation']).clamp(-100, 100),
      riskTolerance:
          _readInt(json['riskTolerance'], fallback: 50).clamp(0, 100),
      lastKnownLocationId:
          json['lastKnownLocationId']?.toString().trim() ?? locationId,
      lastKnownTurn: _readInt(json['lastKnownTurn']).clamp(0, 9999),
      status: json['status']?.toString().trim() ?? '行动中',
      intent: json['intent']?.toString().trim() ?? '',
    );
  }

  final String id;
  final String name;
  final String trueLocationId;
  final String homeLocationId;
  final String goalLocationId;
  final String goal;
  final List<String> traits;
  final List<String> scheduleLocationIds;
  final List<String> knowledge;
  final int relation;
  final int riskTolerance;
  final String lastKnownLocationId;
  final int lastKnownTurn;
  final String status;
  final String intent;

  MapNpcAgentState copyWith({
    String? trueLocationId,
    String? lastKnownLocationId,
    int? lastKnownTurn,
    int? relation,
    String? status,
    String? intent,
  }) =>
      MapNpcAgentState(
        id: id,
        name: name,
        trueLocationId: trueLocationId ?? this.trueLocationId,
        homeLocationId: homeLocationId,
        goalLocationId: goalLocationId,
        goal: goal,
        traits: traits,
        scheduleLocationIds: scheduleLocationIds,
        knowledge: knowledge,
        relation: relation ?? this.relation,
        riskTolerance: riskTolerance,
        lastKnownLocationId: lastKnownLocationId ?? this.lastKnownLocationId,
        lastKnownTurn: lastKnownTurn ?? this.lastKnownTurn,
        status: status ?? this.status,
        intent: intent ?? this.intent,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'trueLocationId': trueLocationId,
        'homeLocationId': homeLocationId,
        'goalLocationId': goalLocationId,
        'goal': goal,
        'traits': traits,
        'scheduleLocationIds': scheduleLocationIds,
        'knowledge': knowledge,
        'relation': relation,
        'riskTolerance': riskTolerance,
        'lastKnownLocationId': lastKnownLocationId,
        'lastKnownTurn': lastKnownTurn,
        'status': status,
        'intent': intent,
      };
}

class MapRouteResult {
  const MapRouteResult({
    required this.locationIds,
    required this.edges,
    required this.totalActionPointCost,
    this.blockedReason = '',
  });

  final List<String> locationIds;
  final List<MapEdge> edges;
  final int totalActionPointCost;
  final String blockedReason;

  bool get isReachable => blockedReason.isEmpty && locationIds.isNotEmpty;
}

enum MapRouteMode {
  leastActionPoints,
  safest,
  fastest,
}

class MapTurnResolution {
  const MapTurnResolution({
    required this.stateJson,
    required this.logs,
    required this.summary,
  });

  final Map<String, dynamic> stateJson;
  final List<String> logs;
  final String summary;
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

int _readInt(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _stableSlug(String value) {
  var hash = 0x811c9dc5;
  for (final code in value.trim().codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 'action_${hash.toRadixString(16).padLeft(8, '0')}';
}
