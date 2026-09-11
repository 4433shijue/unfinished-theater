import 'dart:math';

import '../models/map_state.dart';

class MapEngineResult {
  const MapEngineResult({
    required this.state,
    this.logs = const <String>[],
    this.error,
  });

  final MapWorldState state;
  final List<String> logs;
  final String? error;

  bool get isSuccess => error == null;
}

class MapTurnEngine {
  const MapTurnEngine();

  static const int schemaVersion = 2;
  static const int baseActionPoints = 3;
  static const int temporaryActionPointLimit = 5;
  static const int maxActionPoints = 8;

  MapWorldState prepareBlueprint(
    MapWorldState raw, {
    required String characterName,
  }) {
    final seed = raw.seed == 0
        ? _stableHash('${raw.characterId}|$characterName|${raw.title}')
        : raw.seed;
    final locations = _normalizeLocations(raw.locations, characterName);
    final locationIds = locations.map((item) => item.id).toSet();
    final edges = _normalizeEdges(raw.edges, locations);
    final spawnCandidates = _normalizeSpawns(
      raw.spawnCandidates,
      locations,
      edges,
    );
    final inventory = _normalizeInventory(raw.mapInventory);
    final quests = _normalizeQuests(raw.quests, locations);
    final events = _normalizeEvents(raw.worldEvents, locations, edges);
    final agents = _normalizeNpcAgents(
      raw.npcAgents,
      raw.npcPositions,
      locations,
    );
    final positions = _positionsFromAgents(
      agents,
      locations,
      edges: edges,
      turn: 0,
    );

    return raw.copyWith(
      schemaVersion: schemaVersion,
      seed: seed,
      turnNumber: 0,
      baseActionPoints: baseActionPoints,
      currentActionPoints: baseActionPoints,
      temporaryActionPointLimit: temporaryActionPointLimit,
      maxActionPoints: maxActionPoints,
      birthLocationId: '',
      currentLocationId: '',
      currentLocationName: '',
      currentScene: '选择出生地点后，地图主线正式开始。',
      locations: locations
          .map(
            (item) => item.copyWith(
              status: item.status == MapLocationStatus.hidden
                  ? MapLocationStatus.hidden
                  : item.status == MapLocationStatus.locked
                      ? MapLocationStatus.locked
                      : MapLocationStatus.available,
            ),
          )
          .toList(growable: false),
      edges: edges,
      spawnCandidates: spawnCandidates,
      mapInventory: inventory,
      statusEffects: const <MapStatusEffect>[],
      quests: quests,
      worldEvents: events,
      npcAgents: agents,
      npcPositions: positions,
      activeChoices: const <MapStoryChoice>[],
      facts: raw.facts
          .where((item) => item.trim().isNotEmpty)
          .toSet()
          .take(30)
          .toList(growable: false),
      threatClock: 0,
      threatLimit: raw.threatLimit.clamp(8, 30),
      nextMoveDiscount: 0,
      actionItemUsedThisTurn: false,
      mapHtml: '',
      updatedAt: DateTime.now(),
      openingResolved: true,
      eventSummary: locationIds.isEmpty ? '' : '固定世界蓝图已经生成。',
      eventLog: const <String>['固定世界蓝图已经生成，等待选择出生地点。'],
    );
  }

  MapWorldState fallbackBlueprint({
    required String characterId,
    required String characterName,
    required String openingSummary,
  }) {
    const names = <String>[
      '旧城广场',
      '河岸市场',
      '钟楼街',
      '北侧车站',
      '废弃剧院',
      '档案馆',
      '山腰诊所',
      '雾港仓库',
    ];
    final locations = <MapLocationNode>[
      for (var index = 0; index < names.length; index++)
        MapLocationNode(
          id: 'fallback_$index',
          name: names[index],
          description: '$characterName 的故事可能在${names[index]}留下线索。',
          scene: '${names[index]}暂时平静，但局势正在缓慢变化。',
          status: MapLocationStatus.available,
          riskLevel: index < 3
              ? '低'
              : index < 6
                  ? '中'
                  : '高',
          timeCost: '一段路程',
          x: _circleX(index, names.length),
          y: _circleY(index, names.length),
          tags:
              index == 0 ? const <String>['safe', 'social'] : const <String>[],
          actions: <MapActionDefinition>[
            MapActionDefinition(
              id: 'inspect_$index',
              label: '调查${names[index]}',
              description: '寻找此处与当前目标有关的痕迹。',
              kind: 'clue',
              clue: '${names[index]}可能藏有一条关键线索。',
            ),
            MapActionDefinition(
              id: 'observe_$index',
              label: '观察周围动静',
              description: '确认环境、道路和附近人物的变化。',
              kind: 'action',
            ),
          ],
        ),
    ];
    final raw = MapWorldState.empty(characterId).copyWith(
      title: '$characterName 的固定地图',
      stage: '序章',
      mainGoal: '调查这片区域正在发生的异常。',
      openingResolved: true,
      openingSummary: openingSummary,
      locations: locations,
      edges: <MapEdge>[
        for (var index = 0; index < locations.length; index++)
          MapEdge(
            id: 'fallback_edge_$index',
            fromId: locations[index].id,
            toId: locations[(index + 1) % locations.length].id,
            actionPointCost: index % 4 == 3 ? 2 : 1,
            riskLevel: index % 4 == 3 ? '中' : '低',
          ),
        const MapEdge(
          id: 'fallback_chord_a',
          fromId: 'fallback_0',
          toId: 'fallback_4',
          actionPointCost: 2,
          riskLevel: '高',
        ),
        const MapEdge(
          id: 'fallback_chord_b',
          fromId: 'fallback_2',
          toId: 'fallback_6',
          actionPointCost: 1,
          riskLevel: '中',
        ),
      ],
      spawnCandidates: const <MapSpawnCandidate>[
        MapSpawnCandidate(
          locationId: 'fallback_0',
          label: '安全起点',
          description: '道路稳定，适合先熟悉周边。',
          style: 'safe',
        ),
        MapSpawnCandidate(
          locationId: 'fallback_1',
          label: '社交起点',
          description: '人流密集，更容易获得情报。',
          style: 'social',
        ),
        MapSpawnCandidate(
          locationId: 'fallback_6',
          label: '冒险起点',
          description: '离高风险区域更近。',
          style: 'danger',
        ),
      ],
    );
    return prepareBlueprint(raw, characterName: characterName);
  }

  MapEngineResult selectBirthLocation(
    MapWorldState state,
    String locationId,
  ) {
    if (!state.isRulesDriven) {
      return MapEngineResult(state: state, error: '当前不是新版规则地图。');
    }
    if (!state.needsBirthSelection) {
      return MapEngineResult(state: state, error: '出生地点已经确定。');
    }
    final allowed = state.spawnCandidates
        .map((item) => item.locationId)
        .contains(locationId);
    final location = _locationById(state.locations, locationId);
    if (!allowed || location == null) {
      return MapEngineResult(state: state, error: '这个地点不能作为出生地点。');
    }
    final nextLocations = _markCurrent(state.locations, locationId);
    final next = state.copyWith(
      birthLocationId: locationId,
      currentLocationId: locationId,
      currentLocationName: location.name,
      currentScene: location.scene.trim().isEmpty
          ? '你从${location.name}开始了这段旅程。'
          : location.scene,
      locations: nextLocations,
      currentActionPoints: baseActionPoints,
      activeChoices: _choicesForLocation(location),
      eventSummary: '你选择${location.name}作为出生地点。',
      eventLog: <String>[
        '你选择${location.name}作为出生地点。',
        ...state.eventLog,
      ].take(24).toList(growable: false),
      updatedAt: DateTime.now(),
    );
    return MapEngineResult(
      state: next,
      logs: <String>['你从${location.name}开始行动，当前有 3 AP。'],
    );
  }

  MapRouteResult findRoute(
    MapWorldState state,
    String destinationId, {
    MapRouteMode mode = MapRouteMode.leastActionPoints,
  }) {
    return findRouteBetween(
      state,
      state.currentLocationId,
      destinationId,
      mode: mode,
    );
  }

  MapRouteResult findRouteBetween(
    MapWorldState state,
    String fromId,
    String destinationId, {
    MapRouteMode mode = MapRouteMode.leastActionPoints,
  }) {
    if (fromId.isEmpty || destinationId.isEmpty) {
      return const MapRouteResult(
        locationIds: <String>[],
        edges: <MapEdge>[],
        totalActionPointCost: 0,
        blockedReason: '尚未确定起点或终点。',
      );
    }
    if (fromId == destinationId) {
      return MapRouteResult(
        locationIds: <String>[fromId],
        edges: const <MapEdge>[],
        totalActionPointCost: 0,
      );
    }
    final target = _locationById(state.locations, destinationId);
    if (target == null || target.status == MapLocationStatus.hidden) {
      return const MapRouteResult(
        locationIds: <String>[],
        edges: <MapEdge>[],
        totalActionPointCost: 0,
        blockedReason: '目的地尚未发现。',
      );
    }
    if (target.status == MapLocationStatus.locked) {
      return const MapRouteResult(
        locationIds: <String>[],
        edges: <MapEdge>[],
        totalActionPointCost: 0,
        blockedReason: '目的地尚未解锁。',
      );
    }

    final distance = <String, int>{fromId: 0};
    final previousNode = <String, String>{};
    final previousEdge = <String, MapEdge>{};
    final unvisited = state.locations
        .where((item) => item.status != MapLocationStatus.hidden)
        .map((item) => item.id)
        .toSet();

    while (unvisited.isNotEmpty) {
      String? current;
      var best = 1 << 30;
      for (final id in unvisited) {
        final value = distance[id];
        if (value != null && value < best) {
          current = id;
          best = value;
        }
      }
      if (current == null) {
        break;
      }
      unvisited.remove(current);
      if (current == destinationId) {
        break;
      }
      for (final edge in state.edges.where(
        (item) => item.discovered && !item.blocked && item.connects(current!),
      )) {
        final other = edge.other(current);
        if (other == null || !unvisited.contains(other)) {
          continue;
        }
        final location = _locationById(state.locations, other);
        if (location == null ||
            location.status == MapLocationStatus.hidden ||
            location.status == MapLocationStatus.locked) {
          continue;
        }
        if (edge.requiredItemId.isNotEmpty &&
            !_hasItem(state.mapInventory, edge.requiredItemId)) {
          continue;
        }
        final candidate = best + _routeWeight(edge, mode);
        if (candidate < (distance[other] ?? (1 << 30))) {
          distance[other] = candidate;
          previousNode[other] = current;
          previousEdge[other] = edge;
        }
      }
    }

    if (!previousNode.containsKey(destinationId)) {
      return const MapRouteResult(
        locationIds: <String>[],
        edges: <MapEdge>[],
        totalActionPointCost: 0,
        blockedReason: '当前没有可通行路线，可能缺少道具或道路已封锁。',
      );
    }
    final locationIds = <String>[destinationId];
    final edges = <MapEdge>[];
    var cursor = destinationId;
    while (cursor != fromId) {
      final edge = previousEdge[cursor];
      final node = previousNode[cursor];
      if (edge == null || node == null) {
        break;
      }
      edges.add(edge);
      locationIds.add(node);
      cursor = node;
    }
    final orderedEdges = edges.reversed.toList(growable: false);
    final orderedLocations = locationIds.reversed.toList(growable: false);
    var totalCost = orderedEdges.fold<int>(
      0,
      (sum, edge) => sum + edge.actionPointCost,
    );
    if (state.nextMoveDiscount > 0 && orderedEdges.isNotEmpty) {
      totalCost = max(0, totalCost - state.nextMoveDiscount);
    }
    return MapRouteResult(
      locationIds: orderedLocations,
      edges: orderedEdges,
      totalActionPointCost: totalCost,
    );
  }

  MapEngineResult useItem(MapWorldState state, String itemId) {
    if (!state.isRulesDriven || state.needsBirthSelection) {
      return MapEngineResult(state: state, error: '请先完成地图开局。');
    }
    final index = state.mapInventory.indexWhere(
      (item) => item.id == itemId && item.quantity > 0,
    );
    if (index < 0) {
      return MapEngineResult(state: state, error: '这个道具已经用完了。');
    }
    final item = state.mapInventory[index];
    if (state.actionItemUsedThisTurn &&
        item.kind != MapItemKind.key &&
        item.kind != MapItemKind.intel) {
      return MapEngineResult(state: state, error: '每回合只能使用一次行动类道具。');
    }
    final inventory = List<MapInventoryItem>.from(state.mapInventory);
    inventory[index] = item.copyWith(quantity: item.quantity - 1);
    var next = state.copyWith(mapInventory: inventory);
    final logs = <String>[];
    switch (item.kind) {
      case MapItemKind.restoreActionPoints:
        if (state.currentActionPoints >= state.maxActionPoints) {
          return MapEngineResult(state: state, error: '当前行动力已经达到总上限。');
        }
        final restored = min(
          item.amount,
          state.maxActionPoints - state.currentActionPoints,
        );
        next = next.copyWith(
          currentActionPoints: state.currentActionPoints + restored,
          actionItemUsedThisTurn: true,
          statusEffects: item.sideEffect.trim().isEmpty
              ? state.statusEffects
              : <MapStatusEffect>[
                  const MapStatusEffect(
                    id: 'stimulant_fatigue',
                    name: '兴奋剂疲劳',
                    remainingTurns: 1,
                    nextTurnActionPointModifier: -1,
                    description: '下回合基础行动力减少 1。',
                  ),
                  ...state.statusEffects.where(
                    (effect) => effect.id != 'stimulant_fatigue',
                  ),
                ],
        );
        logs.add('使用${item.name}，当前回合恢复 $restored AP。');
      case MapItemKind.moveDiscount:
        next = next.copyWith(
          nextMoveDiscount: max(state.nextMoveDiscount, item.amount),
          actionItemUsedThisTurn: true,
        );
        logs.add('使用${item.name}，下一段移动减少 ${item.amount} AP。');
      case MapItemKind.camp:
        final location = state.currentLocation;
        final safe = location != null &&
            (location.tags.contains('safe') || location.riskLevel == '低');
        if (!safe) {
          return MapEngineResult(state: state, error: '这里只能在安全地点扎营。');
        }
        next = next.copyWith(
          currentActionPoints: 0,
          actionItemUsedThisTurn: true,
          statusEffects: <MapStatusEffect>[
            const MapStatusEffect(
              id: 'well_rested',
              name: '充分休息',
              remainingTurns: 1,
              nextTurnActionPointModifier: 1,
              description: '下回合额外获得 1 AP。',
            ),
            ...state.statusEffects.where(
              (effect) => effect.id != 'well_rested',
            ),
          ],
        );
        logs.add('你在${location.name}扎营，本回合结束，下回合获得额外 AP。');
        next = _finishRound(next, '下一回合', logs);
      case MapItemKind.key:
        return MapEngineResult(state: state, error: '钥匙会在通过对应道路时自动使用。');
      case MapItemKind.intel:
        next = next.copyWith(
          edges: state.edges
              .map((edge) => edge.copyWith(discovered: true))
              .toList(growable: false),
        );
        logs.add('使用${item.name}，地图上的道路情报已经更新。');
    }
    return MapEngineResult(
      state: next.copyWith(
        eventSummary: logs.last,
        eventLog: <String>[...logs.reversed, ...next.eventLog]
            .take(24)
            .toList(growable: false),
        updatedAt: DateTime.now(),
      ),
      logs: logs,
    );
  }

  MapEngineResult resolvePlannedRound(
    MapWorldState state, {
    required List<String> actions,
    required List<String> locationIds,
    required String timeStep,
    MapRouteMode routeMode = MapRouteMode.leastActionPoints,
    List<Map<String, dynamic>> structuredActions =
        const <Map<String, dynamic>>[],
  }) {
    if (!state.isRulesDriven) {
      return MapEngineResult(state: state, error: '当前不是新版规则地图。');
    }
    if (state.needsBirthSelection) {
      return MapEngineResult(state: state, error: '请先选择出生地点。');
    }
    var next = state;
    final logs = <String>[];

    bool moveTo(String destinationId, MapRouteMode selectedRouteMode) {
      final movement = _moveAlongRoute(
        next,
        destinationId,
        routeMode: selectedRouteMode,
      );
      next = movement.state;
      logs.addAll(movement.logs);
      if (!movement.isSuccess) {
        logs.add(movement.error!);
        return false;
      }
      return true;
    }

    bool perform(String action) {
      if (next.currentActionPoints <= 0) {
        logs.add('行动力已经耗尽，剩余行动没有执行。');
        return false;
      }
      final resolution = _performAction(next, action);
      next = resolution.state;
      logs.addAll(resolution.logs);
      if (!resolution.isSuccess) {
        logs.add(resolution.error!);
      }
      return true;
    }

    var hasPlannedStep = false;
    if (structuredActions.isEmpty) {
      hasPlannedStep = locationIds.isNotEmpty || actions.isNotEmpty;
      for (final destinationId in locationIds.toSet()) {
        if (!moveTo(destinationId, routeMode)) {
          break;
        }
      }
      for (final action in actions.toSet()) {
        if (!perform(action)) {
          break;
        }
      }
    } else {
      final representedLocationIds = <String>{};
      final representedActions = <String>{};
      var shouldContinue = true;
      for (final item in structuredActions) {
        final kind = item['kind']?.toString().trim().toLowerCase() ?? '';
        final locationId = item['locationId']?.toString().trim() ?? '';
        final selectedRouteMode = _routeModeFromStructuredAction(
          item['routeMode'],
          routeMode,
        );
        if (kind == 'location') {
          if (locationId.isEmpty) {
            continue;
          }
          hasPlannedStep = true;
          representedLocationIds.add(locationId);
          shouldContinue = moveTo(locationId, selectedRouteMode);
        } else {
          final action = (item['action']?.toString().trim().isNotEmpty ?? false)
              ? item['action'].toString().trim()
              : (item['actionText']?.toString().trim().isNotEmpty ?? false)
                  ? item['actionText'].toString().trim()
                  : item['label']?.toString().trim() ?? '';
          if (action.isEmpty) {
            continue;
          }
          hasPlannedStep = true;
          representedActions.add(action);
          if (locationId.isNotEmpty) {
            representedLocationIds.add(locationId);
            if (locationId != next.currentLocationId) {
              shouldContinue = moveTo(locationId, selectedRouteMode);
            }
          }
          if (shouldContinue) {
            shouldContinue = perform(action);
          }
        }
        if (!shouldContinue) {
          break;
        }
      }
      if (shouldContinue) {
        for (final destinationId in locationIds.toSet()) {
          if (!representedLocationIds.add(destinationId)) {
            continue;
          }
          hasPlannedStep = true;
          if (!moveTo(destinationId, routeMode)) {
            shouldContinue = false;
            break;
          }
        }
      }
      if (shouldContinue) {
        for (final action in actions.toSet()) {
          if (!representedActions.add(action)) {
            continue;
          }
          hasPlannedStep = true;
          if (!perform(action)) {
            break;
          }
        }
      }
    }
    if (!hasPlannedStep) {
      logs.add('你暂时没有采取行动，让时间自然向前推进。');
    }
    next = _finishRound(next, timeStep, logs);
    final summary = logs.isEmpty ? '地图回合已经推进。' : logs.last;
    next = next.copyWith(
      eventSummary: summary,
      eventLog: <String>[...logs.reversed, ...next.eventLog]
          .where((item) => item.trim().isNotEmpty)
          .take(24)
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
    return MapEngineResult(state: next, logs: logs);
  }

  MapRouteMode _routeModeFromStructuredAction(
    Object? value,
    MapRouteMode fallback,
  ) {
    switch (value?.toString().trim()) {
      case 'safest':
        return MapRouteMode.safest;
      case 'fastest':
        return MapRouteMode.fastest;
      case 'leastActionPoints':
        return MapRouteMode.leastActionPoints;
      default:
        return fallback;
    }
  }

  MapEngineResult finishRound(MapWorldState state, String timeStep) {
    final logs = <String>['你主动结束了当前回合。'];
    final next = _finishRound(state, timeStep, logs).copyWith(
      eventSummary: logs.last,
      eventLog: <String>[...logs.reversed, ...state.eventLog]
          .take(24)
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
    return MapEngineResult(state: next, logs: logs);
  }

  MapEngineResult _moveAlongRoute(
    MapWorldState state,
    String destinationId, {
    required MapRouteMode routeMode,
  }) {
    final route = findRoute(state, destinationId, mode: routeMode);
    if (!route.isReachable) {
      return MapEngineResult(state: state, error: route.blockedReason);
    }
    if (route.edges.isEmpty) {
      return MapEngineResult(state: state, logs: const <String>['你已经在目标地点。']);
    }
    var next = state;
    final logs = <String>[];
    var currentId = state.currentLocationId;
    var discount = state.nextMoveDiscount;
    var traversed = false;
    for (final edge in route.edges) {
      final destination = edge.other(currentId);
      if (destination == null) {
        break;
      }
      final cost = max(0, edge.actionPointCost - (traversed ? 0 : discount));
      if (cost > next.currentActionPoints) {
        final location = _locationById(next.locations, destination);
        return MapEngineResult(
          state: next,
          logs: logs,
          error: '行动力不足，无法继续前往${location?.name ?? '下一地点'}。',
        );
      }
      final location = _locationById(next.locations, destination)!;
      next = next.copyWith(
        currentActionPoints: next.currentActionPoints - cost,
        currentLocationId: destination,
        currentLocationName: location.name,
        currentScene: location.scene.trim().isEmpty
            ? '你抵达${location.name}，开始观察周围。'
            : location.scene,
        locations: _markCurrent(next.locations, destination),
        nextMoveDiscount: 0,
        activeChoices: _choicesForLocation(location),
      );
      logs.add('沿${edge.riskLevel}风险道路抵达${location.name}，消耗 $cost AP。');
      traversed = true;
      discount = 0;
      currentId = destination;
      if (_riskRoll(next.seed, next.turnNumber, edge.id, edge.riskLevel)) {
        final penalty = next.currentActionPoints > 0 ? 1 : 0;
        next = next.copyWith(
          currentActionPoints: next.currentActionPoints - penalty,
          threatClock: next.threatClock + 1,
        );
        logs.add(
          penalty > 0 ? '途中发生意外，额外消耗 1 AP，危机时钟上升。' : '途中出现危险迹象，危机时钟上升。',
        );
      }
    }
    return MapEngineResult(state: next, logs: logs);
  }

  MapEngineResult _performAction(MapWorldState state, String actionText) {
    final action = actionText.trim();
    if (action.isEmpty) {
      return MapEngineResult(state: state, error: '行动内容为空。');
    }
    final location = state.currentLocation;
    if (location == null) {
      return MapEngineResult(state: state, error: '当前没有可执行行动的地点。');
    }
    MapActionDefinition? definition;
    for (final item in location.actions) {
      if (item.label == action ||
          item.description == action ||
          action.contains(item.label)) {
        definition = item;
        break;
      }
    }
    MapStoryChoice? choice;
    for (final item in state.activeChoices) {
      if (item.label == action ||
          item.action == action ||
          action.contains(item.label)) {
        choice = item;
        break;
      }
    }
    final kind =
        definition?.kind ?? choice?.kind.name ?? _inferActionKind(action);
    final cost = definition?.actionPointCost ?? (kind == 'danger' ? 2 : 1);
    if (cost > state.currentActionPoints) {
      return MapEngineResult(
        state: state,
        error: '执行“$action”需要 $cost AP，当前行动力不足。',
      );
    }
    final requiredItemId = definition?.requiredItemId ?? '';
    if (requiredItemId.isNotEmpty &&
        !_hasItem(state.mapInventory, requiredItemId)) {
      return MapEngineResult(state: state, error: '执行这个行动需要特定道具。');
    }
    var next =
        state.copyWith(currentActionPoints: state.currentActionPoints - cost);
    final logs = <String>['在${location.name}执行“$action”，消耗 $cost AP。'];
    var clues = List<String>.from(next.discoveredClues);
    final clue = definition?.clue.trim() ?? '';
    if (kind == 'clue') {
      final discovered = clue.isNotEmpty ? clue : '${location.name}的调查取得了新进展。';
      if (!clues.contains(discovered)) {
        clues.insert(0, discovered);
        logs.add('获得线索：$discovered');
      }
    }
    var inventory = next.mapInventory;
    final rewardId = definition?.rewardItemId.trim() ?? '';
    if (rewardId.isNotEmpty) {
      inventory = _grantItem(inventory, rewardId);
      final reward = inventory.firstWhere((item) => item.id == rewardId);
      logs.add('获得道具：${reward.name}。');
    }
    var threat = next.threatClock;
    if (kind == 'danger') {
      threat += 1;
      logs.add('高风险行动让危机时钟上升。');
    }
    final quests = _advanceQuests(next.quests, location.id, logs);
    final actions = location.actions
        .map(
          (item) => item.id == definition?.id && item.oneShot
              ? item.copyWith(completed: true)
              : item,
        )
        .toList(growable: false);
    final locations = next.locations
        .map((item) =>
            item.id == location.id ? item.copyWith(actions: actions) : item)
        .toList(growable: false);
    next = next.copyWith(
      discoveredClues: clues.take(30).toList(growable: false),
      mapInventory: inventory,
      quests: quests,
      threatClock: threat,
      locations: locations,
      currentScene: _actionScene(location.name, action, kind),
      activeChoices: _choicesForLocation(
        locations.firstWhere((item) => item.id == location.id),
      ),
    );
    return MapEngineResult(state: next, logs: logs);
  }

  MapWorldState _finishRound(
    MapWorldState state,
    String timeStep,
    List<String> logs,
  ) {
    final advance = _turnAdvance(timeStep);
    var next = state;
    for (var index = 0; index < advance; index++) {
      final nextTurn = next.turnNumber + 1;
      final agents = _advanceNpcAgents(next, nextTurn, logs);
      final positions = _positionsFromAgents(
        agents,
        next.locations,
        edges: next.edges,
        playerLocationId: next.currentLocationId,
        previous: next.npcPositions,
        turn: nextTurn,
      );
      next = next.copyWith(
        turnNumber: nextTurn,
        threatClock: next.threatClock + 1,
        npcAgents: agents,
        npcPositions: positions,
        npcMovements: logs
            .where((item) => item.startsWith('NPC '))
            .toList(growable: false),
      );
      next = _triggerWorldEvent(next, logs);
    }
    final effects = <MapStatusEffect>[];
    var actionPointModifier = 0;
    for (final effect in next.statusEffects) {
      actionPointModifier += effect.nextTurnActionPointModifier;
      if (effect.remainingTurns > 1) {
        effects.add(effect.copyWith(remainingTurns: effect.remainingTurns - 1));
      }
    }
    final refreshed = (next.baseActionPoints + actionPointModifier)
        .clamp(1, next.temporaryActionPointLimit);
    final quests = next.quests.map((quest) {
      if (quest.status == MapQuestStatus.active &&
          quest.deadlineTurn > 0 &&
          next.turnNumber > quest.deadlineTurn) {
        logs.add('任务“${quest.title}”因错过期限而失败。');
        return quest.copyWith(status: MapQuestStatus.failed);
      }
      return quest;
    }).toList(growable: false);
    if (next.threatClock >= next.threatLimit) {
      logs.add('危机时钟达到临界值，世界局势进入更危险的阶段。');
    }
    return next.copyWith(
      currentActionPoints: refreshed,
      statusEffects: effects,
      quests: quests,
      nextMoveDiscount: 0,
      actionItemUsedThisTurn: false,
      timeLabel: '第 ${next.turnNumber} 回合',
      stage: next.threatClock >= next.threatLimit ? '危机' : next.stage,
      mainGoal: _mainGoalFromQuests(quests, next.mainGoal),
      updatedAt: DateTime.now(),
    );
  }

  List<MapNpcAgentState> _advanceNpcAgents(
    MapWorldState state,
    int turn,
    List<String> logs,
  ) {
    return state.npcAgents.map((agent) {
      final target = _npcTarget(agent, turn);
      final candidates = <String>{agent.trueLocationId};
      for (final edge in state.edges.where(
        (item) =>
            item.discovered &&
            !item.blocked &&
            item.connects(agent.trueLocationId),
      )) {
        final other = edge.other(agent.trueLocationId);
        final location =
            other == null ? null : _locationById(state.locations, other);
        if (location != null &&
            location.status != MapLocationStatus.hidden &&
            location.status != MapLocationStatus.locked) {
          candidates.add(other!);
        }
      }
      var nextLocationId = agent.trueLocationId;
      var bestScore = -100000;
      for (final candidate in candidates) {
        final score = _npcActionScore(
          state: state,
          agent: agent,
          candidateId: candidate,
          targetId: target,
          turn: turn,
        );
        if (score > bestScore) {
          bestScore = score;
          nextLocationId = candidate;
        }
      }
      if (nextLocationId == agent.trueLocationId) {
        return agent.copyWith(
          status: target.isEmpty ? '观察局势' : '等待时机',
          intent: agent.goal.trim().isEmpty ? '观察局势' : agent.goal,
        );
      }
      final nextLocation = _locationById(state.locations, nextLocationId);
      if (nextLocation == null) {
        return agent;
      }
      logs.add('NPC ${agent.name}采取了行动。');
      return agent.copyWith(
        trueLocationId: nextLocationId,
        status: '行动中',
        intent: agent.goal.trim().isEmpty ? '按自己的计划行动' : agent.goal,
      );
    }).toList(growable: false);
  }

  int _npcActionScore({
    required MapWorldState state,
    required MapNpcAgentState agent,
    required String candidateId,
    required String targetId,
    required int turn,
  }) {
    var score = candidateId == agent.trueLocationId ? 15 : 0;
    if (candidateId == targetId && targetId.isNotEmpty) {
      score += 420;
    } else if (targetId.isNotEmpty) {
      final route = findRouteBetween(
        state,
        candidateId,
        targetId,
        mode: agent.riskTolerance < 45
            ? MapRouteMode.safest
            : MapRouteMode.leastActionPoints,
      );
      if (route.isReachable) {
        score += 240 - route.edges.length * 32;
      } else {
        score -= 180;
      }
    }

    final playerId = state.currentLocationId;
    if (playerId.isNotEmpty) {
      final playerRoute = findRouteBetween(
        state,
        candidateId,
        playerId,
        mode: MapRouteMode.leastActionPoints,
      );
      if (playerRoute.isReachable) {
        final closeness = max(0, 5 - playerRoute.edges.length) * 12;
        if (agent.relation >= 35 || agent.relation <= -35) {
          score += closeness;
        } else {
          score -= max(0, 2 - playerRoute.edges.length) * 8;
        }
      }
    }

    final movementEdge = state.edges
        .where(
          (edge) =>
              edge.connects(agent.trueLocationId) &&
              edge.other(agent.trueLocationId) == candidateId,
        )
        .firstOrNull;
    if (movementEdge != null) {
      final caution = 100 - agent.riskTolerance;
      score -= _riskScore(movementEdge.riskLevel) * caution ~/ 8;
      score -= movementEdge.actionPointCost * 10;
      if (agent.traits.any((trait) => trait.contains('谨慎'))) {
        score -= _riskScore(movementEdge.riskLevel) * 12;
      }
      if (agent.traits.any((trait) => trait.contains('冒险'))) {
        score += _riskScore(movementEdge.riskLevel) * 8;
      }
    }
    score += _stableHash('${state.seed}|$turn|${agent.id}|$candidateId') % 23;
    return score;
  }

  MapWorldState _triggerWorldEvent(MapWorldState state, List<String> logs) {
    final eligible = state.worldEvents
        .where(
          (event) =>
              !event.resolved &&
              event.triggerTurn <= state.turnNumber &&
              (event.locationId.isEmpty ||
                  event.locationId == state.currentLocationId),
        )
        .toList(growable: false);
    if (eligible.isEmpty) {
      return state;
    }
    eligible.sort((a, b) {
      final aScore = _stableHash('${state.seed}|${state.turnNumber}|${a.id}') %
          max(1, a.weight);
      final bScore = _stableHash('${state.seed}|${state.turnNumber}|${b.id}') %
          max(1, b.weight);
      return bScore.compareTo(aScore);
    });
    final event = eligible.first;
    var inventory = state.mapInventory;
    if (event.rewardItemId.isNotEmpty) {
      inventory = _grantItem(inventory, event.rewardItemId);
    }
    final clues = List<String>.from(state.discoveredClues);
    if (event.clue.isNotEmpty && !clues.contains(event.clue)) {
      clues.insert(0, event.clue);
    }
    final edges = state.edges
        .map(
          (edge) => edge.id == event.blockEdgeId
              ? edge.copyWith(blocked: true)
              : edge,
        )
        .toList(growable: false);
    final events = state.worldEvents
        .map((item) =>
            item.id == event.id ? item.copyWith(resolved: true) : item)
        .toList(growable: false);
    final narrative =
        event.narrative.trim().isEmpty ? event.title : event.narrative;
    logs.add('事件：$narrative');
    return state.copyWith(
      worldEvents: events,
      mapInventory: inventory,
      discoveredClues: clues.take(30).toList(growable: false),
      edges: edges,
      threatClock: max(0, state.threatClock + event.threatDelta),
      currentScene: narrative,
    );
  }

  List<MapLocationNode> _normalizeLocations(
    List<MapLocationNode> incoming,
    String characterName,
  ) {
    final result = <MapLocationNode>[];
    final seen = <String>{};
    for (final raw in incoming.take(10)) {
      var id = raw.id.trim();
      if (id.isEmpty) {
        id = 'location_${result.length}';
      }
      if (seen.contains(id)) {
        continue;
      }
      seen.add(id);
      final name =
          raw.name.trim().isEmpty ? '地点${result.length + 1}' : raw.name.trim();
      result.add(
        raw.copyWith(
          id: id,
          name: name,
          description: raw.description.trim().isEmpty
              ? '$name 是 $characterName 所在世界的一处重要地点。'
              : raw.description.trim(),
          riskLevel: _normalizeRisk(raw.riskLevel),
          actions: _normalizeActions(raw.actions, name, result.length),
        ),
      );
    }
    const fillerNames = <String>[
      '旧城广场',
      '河岸市场',
      '钟楼街',
      '北侧车站',
      '废弃剧院',
      '档案馆',
      '山腰诊所',
      '雾港仓库',
      '环城公园',
      '地下通道',
    ];
    var fillerIndex = 0;
    while (result.length < 8) {
      var name = fillerNames[fillerIndex % fillerNames.length];
      while (result.any((item) => item.name == name)) {
        fillerIndex += 1;
        name =
            '${fillerNames[fillerIndex % fillerNames.length]}${fillerIndex + 1}';
      }
      final id = 'local_${result.length}';
      result.add(
        MapLocationNode(
          id: id,
          name: name,
          description: '$name 补足了固定地图的连接结构。',
          scene: '$name 还没有发生显著事件。',
          status: MapLocationStatus.available,
          riskLevel: result.length > 5 ? '中' : '低',
          actions: _normalizeActions(
              const <MapActionDefinition>[], name, result.length),
        ),
      );
      fillerIndex += 1;
    }
    final hasUsefulCoordinates = result
            .map((item) =>
                '${item.x.toStringAsFixed(2)}:${item.y.toStringAsFixed(2)}')
            .toSet()
            .length >
        result.length ~/ 2;
    return result.asMap().entries.map((entry) {
      if (hasUsefulCoordinates) {
        return entry.value;
      }
      return entry.value.copyWith(
        x: _circleX(entry.key, result.length),
        y: _circleY(entry.key, result.length),
      );
    }).toList(growable: false);
  }

  List<MapActionDefinition> _normalizeActions(
    List<MapActionDefinition> incoming,
    String locationName,
    int index,
  ) {
    final actions = incoming
        .where((item) => item.label.trim().isNotEmpty)
        .take(4)
        .toList(growable: true);
    if (actions.isEmpty) {
      actions.addAll(<MapActionDefinition>[
        MapActionDefinition(
          id: 'inspect_${index}_local',
          label: '调查$locationName',
          description: '寻找与当前目标有关的痕迹。',
          kind: 'clue',
          clue: '$locationName出现了一条值得追查的新线索。',
        ),
        MapActionDefinition(
          id: 'observe_${index}_local',
          label: '观察周围动静',
          description: '确认附近人物和环境的变化。',
          kind: 'action',
        ),
      ]);
    }
    return actions;
  }

  List<MapEdge> _normalizeEdges(
    List<MapEdge> incoming,
    List<MapLocationNode> locations,
  ) {
    final ids = locations.map((item) => item.id).toSet();
    final byPair = <String, MapEdge>{};
    for (final raw in incoming) {
      if (raw.fromId == raw.toId ||
          !ids.contains(raw.fromId) ||
          !ids.contains(raw.toId)) {
        continue;
      }
      final key = MapEdge.stableId(raw.fromId, raw.toId);
      byPair.putIfAbsent(
        key,
        () => raw.copyWith(
          id: raw.id.trim().isEmpty ? key : raw.id.trim(),
          actionPointCost: raw.actionPointCost.clamp(1, 2),
          riskLevel: _normalizeRisk(raw.riskLevel),
        ),
      );
    }
    final edges = byPair.values.toList(growable: true);
    if (locations.length < 2) {
      return edges;
    }

    final connected = <String>{locations.first.id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final edge in edges) {
        if (connected.contains(edge.fromId) && connected.add(edge.toId)) {
          changed = true;
        }
        if (connected.contains(edge.toId) && connected.add(edge.fromId)) {
          changed = true;
        }
      }
    }
    for (final location in locations) {
      if (connected.contains(location.id)) {
        continue;
      }
      final anchor = connected.last;
      final edge = MapEdge(
        id: MapEdge.stableId(anchor, location.id),
        fromId: anchor,
        toId: location.id,
        actionPointCost: 1,
        riskLevel: '低',
      );
      edges.add(edge);
      connected.add(location.id);
    }

    int degree(String id) => edges.where((edge) => edge.connects(id)).length;
    var chordOffset = 2;
    while (edges.length < locations.length + 2) {
      var added = false;
      for (var index = 0; index < locations.length; index++) {
        final from = locations[index].id;
        final to = locations[(index + chordOffset) % locations.length].id;
        final key = MapEdge.stableId(from, to);
        if (from != to &&
            !edges.any(
                (edge) => MapEdge.stableId(edge.fromId, edge.toId) == key) &&
            degree(from) < 4 &&
            degree(to) < 4) {
          edges.add(
            MapEdge(
              id: key,
              fromId: from,
              toId: to,
              actionPointCost: edges.length.isEven ? 1 : 2,
              riskLevel: edges.length.isEven ? '中' : '低',
            ),
          );
          added = true;
          if (edges.length >= locations.length + 2) {
            break;
          }
        }
      }
      chordOffset += 1;
      if (!added || chordOffset >= locations.length) {
        break;
      }
    }
    return edges;
  }

  List<MapSpawnCandidate> _normalizeSpawns(
    List<MapSpawnCandidate> incoming,
    List<MapLocationNode> locations,
    List<MapEdge> edges,
  ) {
    final ids = locations.map((item) => item.id).toSet();
    final result = <MapSpawnCandidate>[];
    final seen = <String>{};
    for (final raw in incoming) {
      if (!ids.contains(raw.locationId) || !seen.add(raw.locationId)) {
        continue;
      }
      final location = _locationById(locations, raw.locationId)!;
      if (location.status == MapLocationStatus.hidden ||
          location.status == MapLocationStatus.locked) {
        continue;
      }
      result.add(
        MapSpawnCandidate(
          locationId: raw.locationId,
          label: raw.label.trim().isEmpty ? location.name : raw.label.trim(),
          description: raw.description.trim().isEmpty
              ? '从${location.name}开始这段旅程。'
              : raw.description.trim(),
          style: raw.style,
        ),
      );
      if (result.length == 3) {
        break;
      }
    }
    final fallback = locations
        .where(
          (item) =>
              item.status != MapLocationStatus.hidden &&
              item.status != MapLocationStatus.locked,
        )
        .toList(growable: false)
      ..sort((a, b) {
        final risk = _riskScore(a.riskLevel).compareTo(_riskScore(b.riskLevel));
        if (risk != 0) {
          return risk;
        }
        final degreeA = edges.where((edge) => edge.connects(a.id)).length;
        final degreeB = edges.where((edge) => edge.connects(b.id)).length;
        return degreeB.compareTo(degreeA);
      });
    const styles = <String>['safe', 'social', 'danger'];
    for (final location in fallback) {
      if (result.length >= 3) {
        break;
      }
      if (!seen.add(location.id)) {
        continue;
      }
      final style = styles[result.length];
      result.add(
        MapSpawnCandidate(
          locationId: location.id,
          label: style == 'safe'
              ? '安全起点 · ${location.name}'
              : style == 'social'
                  ? '社交起点 · ${location.name}'
                  : '冒险起点 · ${location.name}',
          description: style == 'safe'
              ? '风险较低，适合先熟悉地图。'
              : style == 'social'
                  ? '道路较多，更容易接触不同人物。'
                  : '离高风险区域更近，推进速度更快。',
          style: style,
        ),
      );
    }
    return result;
  }

  List<MapInventoryItem> _normalizeInventory(List<MapInventoryItem> incoming) {
    final result = incoming
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .take(8)
        .toList(growable: true);
    if (!result.any((item) => item.kind == MapItemKind.restoreActionPoints)) {
      result.add(
        const MapInventoryItem(
          id: 'portable_ration',
          name: '便携口粮',
          kind: MapItemKind.restoreActionPoints,
          description: '当前回合恢复 1 AP。',
          quantity: 2,
          amount: 1,
        ),
      );
    }
    if (!result.any((item) => item.kind == MapItemKind.moveDiscount)) {
      result.add(
        const MapInventoryItem(
          id: 'travel_ticket',
          name: '交通票',
          kind: MapItemKind.moveDiscount,
          description: '下一段移动减少 1 AP。',
          quantity: 1,
          amount: 1,
        ),
      );
    }
    return result;
  }

  List<MapQuestState> _normalizeQuests(
    List<MapQuestState> incoming,
    List<MapLocationNode> locations,
  ) {
    final ids = locations.map((item) => item.id).toSet();
    final result = incoming
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .take(6)
        .map(
          (item) => MapQuestState(
            id: item.id,
            title: item.title,
            description: item.description,
            targetLocationIds: item.targetLocationIds
                .where(ids.contains)
                .toList(growable: false),
            progress: item.progress,
            total: item.total,
            deadlineTurn: item.deadlineTurn,
            status: item.status,
          ),
        )
        .toList(growable: true);
    if (result.isEmpty) {
      result.add(
        MapQuestState(
          id: 'main_investigation',
          title: '追查地图上的异常',
          description: '前往不同地点调查并收集三条有效线索。',
          targetLocationIds:
              locations.skip(1).take(4).map((item) => item.id).toList(),
          total: 3,
          deadlineTurn: 12,
        ),
      );
    }
    return result;
  }

  List<MapWorldEvent> _normalizeEvents(
    List<MapWorldEvent> incoming,
    List<MapLocationNode> locations,
    List<MapEdge> edges,
  ) {
    final locationIds = locations.map((item) => item.id).toSet();
    final edgeIds = edges.map((item) => item.id).toSet();
    final result = incoming
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .take(16)
        .map(
          (item) => MapWorldEvent(
            id: item.id,
            title: item.title,
            narrative: item.narrative,
            locationId:
                locationIds.contains(item.locationId) ? item.locationId : '',
            kind: item.kind,
            triggerTurn: item.triggerTurn,
            weight: item.weight,
            clue: item.clue,
            rewardItemId: item.rewardItemId,
            threatDelta: item.threatDelta,
            blockEdgeId:
                edgeIds.contains(item.blockEdgeId) ? item.blockEdgeId : '',
            resolved: item.resolved,
          ),
        )
        .toList(growable: true);
    if (result.isEmpty && locations.isNotEmpty) {
      result.addAll(<MapWorldEvent>[
        MapWorldEvent(
          id: 'local_signal',
          title: '远处的信号',
          narrative: '远处传来短促的信号，某个角色似乎正在抢先行动。',
          triggerTurn: 2,
          clue: '有人正在沿地图道路寻找同一个目标。',
          threatDelta: 1,
        ),
        MapWorldEvent(
          id: 'local_supply',
          title: '遗落的补给',
          narrative: '你在道路边发现一份尚可使用的便携口粮。',
          triggerTurn: 4,
          rewardItemId: 'portable_ration',
        ),
        MapWorldEvent(
          id: 'emergency_reserve_drop',
          title: '封存的应急储备',
          narrative: '一份高浓度应急储备被重新启用，可以短暂突破常规行动力上限。',
          triggerTurn: 6,
          rewardItemId: 'emergency_reserve',
        ),
      ]);
    }
    return result;
  }

  List<MapNpcAgentState> _normalizeNpcAgents(
    List<MapNpcAgentState> incoming,
    List<MapNpcPosition> positions,
    List<MapLocationNode> locations,
  ) {
    final ids = locations.map((item) => item.id).toSet();
    final result = incoming
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.name.isNotEmpty &&
              ids.contains(item.trueLocationId),
        )
        .take(12)
        .toList(growable: true);
    if (result.isEmpty) {
      for (final position in positions.take(12)) {
        if (!ids.contains(position.locationId)) {
          continue;
        }
        result.add(
          MapNpcAgentState(
            id: position.id,
            name: position.name,
            trueLocationId: position.locationId,
            homeLocationId: position.locationId,
            goalLocationId:
                locations[(result.length + 2) % locations.length].id,
            goal: position.intent,
            lastKnownLocationId: position.locationId,
            status: position.status,
            intent: position.intent,
          ),
        );
      }
    }
    return result;
  }

  List<MapNpcPosition> _positionsFromAgents(
    List<MapNpcAgentState> agents,
    List<MapLocationNode> locations, {
    required List<MapEdge> edges,
    String playerLocationId = '',
    List<MapNpcPosition> previous = const <MapNpcPosition>[],
    required int turn,
  }) {
    final previousById = <String, MapNpcPosition>{
      for (final item in previous) item.id: item,
    };
    return agents.map((agent) {
      final visible = playerLocationId.isEmpty ||
          agent.trueLocationId == playerLocationId ||
          _isAdjacentLocation(
            agent.trueLocationId,
            playerLocationId,
            edges,
          );
      final old = previousById[agent.id];
      final knownId = visible
          ? agent.trueLocationId
          : old?.locationId ?? agent.lastKnownLocationId;
      final knownLocation = _locationById(locations, knownId);
      return MapNpcPosition(
        id: agent.id,
        name: agent.name,
        locationId: knownId,
        locationName: knownLocation?.name ?? '位置未知',
        status: visible ? agent.status : '最后已知',
        intent: agent.intent.trim().isEmpty ? agent.goal : agent.intent,
        lastSeen: visible ? '第 $turn 回合' : old?.lastSeen ?? '开局情报',
      );
    }).toList(growable: false);
  }

  List<MapQuestState> _advanceQuests(
    List<MapQuestState> quests,
    String locationId,
    List<String> logs,
  ) {
    return quests.map((quest) {
      if (quest.status != MapQuestStatus.active ||
          (quest.targetLocationIds.isNotEmpty &&
              !quest.targetLocationIds.contains(locationId))) {
        return quest;
      }
      final progress = min(quest.total, quest.progress + 1);
      if (progress >= quest.total) {
        logs.add('任务完成：${quest.title}。');
        return quest.copyWith(
          progress: progress,
          status: MapQuestStatus.completed,
        );
      }
      logs.add('任务推进：${quest.title}（$progress/${quest.total}）。');
      return quest.copyWith(progress: progress);
    }).toList(growable: false);
  }

  List<MapInventoryItem> _grantItem(
    List<MapInventoryItem> inventory,
    String itemId,
  ) {
    final result = List<MapInventoryItem>.from(inventory);
    final index = result.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      result[index] =
          result[index].copyWith(quantity: result[index].quantity + 1);
      return result;
    }
    result.add(_catalogItem(itemId));
    return result;
  }

  MapInventoryItem _catalogItem(String id) {
    switch (id) {
      case 'travel_ticket':
        return const MapInventoryItem(
          id: 'travel_ticket',
          name: '交通票',
          kind: MapItemKind.moveDiscount,
          description: '下一段移动减少 1 AP。',
        );
      case 'stimulant':
        return const MapInventoryItem(
          id: 'stimulant',
          name: '兴奋剂',
          kind: MapItemKind.restoreActionPoints,
          description: '恢复 2 AP，但下回合陷入疲劳。',
          amount: 2,
          sideEffect: 'fatigue',
        );
      case 'camp_kit':
        return const MapInventoryItem(
          id: 'camp_kit',
          name: '野营工具',
          kind: MapItemKind.camp,
          description: '在安全地点结束本回合，下回合额外获得 1 AP。',
        );
      case 'emergency_reserve':
        return const MapInventoryItem(
          id: 'emergency_reserve',
          name: '应急储备',
          kind: MapItemKind.restoreActionPoints,
          description: '恢复 5 AP，可突破临时上限，但不会超过 8 AP 总上限。',
          amount: 5,
          sideEffect: 'fatigue',
        );
      default:
        return const MapInventoryItem(
          id: 'portable_ration',
          name: '便携口粮',
          kind: MapItemKind.restoreActionPoints,
          description: '当前回合恢复 1 AP。',
        );
    }
  }

  String _npcTarget(MapNpcAgentState agent, int turn) {
    if (agent.scheduleLocationIds.isNotEmpty) {
      return agent.scheduleLocationIds[turn % agent.scheduleLocationIds.length];
    }
    return agent.goalLocationId;
  }

  static List<MapLocationNode> _markCurrent(
    List<MapLocationNode> locations,
    String currentId,
  ) {
    return locations.map((location) {
      if (location.id == currentId) {
        return location.copyWith(status: MapLocationStatus.current);
      }
      if (location.status == MapLocationStatus.current) {
        return location.copyWith(status: MapLocationStatus.explored);
      }
      return location;
    }).toList(growable: false);
  }

  static List<MapStoryChoice> _choicesForLocation(MapLocationNode location) {
    final choices = location.actions
        .where((item) => !item.completed)
        .take(5)
        .map(
          (item) => MapStoryChoice(
            id: item.id,
            label: item.label,
            action:
                item.description.trim().isEmpty ? item.label : item.description,
            locationId: location.id,
            kind: MapStoryChoiceKind.fromJson(item.kind),
            riskLevel: item.riskLevel,
            timeCost: '${item.actionPointCost} AP',
          ),
        )
        .toList(growable: true);
    if (choices.length < 3) {
      choices.add(
        MapStoryChoice(
          id: 'rest_${location.id}',
          label: '休整并观察',
          action: '在${location.name}休整并观察周围变化',
          locationId: location.id,
          kind: MapStoryChoiceKind.rest,
          riskLevel: '低',
          timeCost: '1 AP',
        ),
      );
    }
    return choices.take(5).toList(growable: false);
  }

  static MapLocationNode? _locationById(
    List<MapLocationNode> locations,
    String id,
  ) {
    for (final location in locations) {
      if (location.id == id) {
        return location;
      }
    }
    return null;
  }

  static bool _hasItem(List<MapInventoryItem> inventory, String id) =>
      inventory.any((item) => item.id == id && item.quantity > 0);

  static int _routeWeight(MapEdge edge, MapRouteMode mode) {
    switch (mode) {
      case MapRouteMode.leastActionPoints:
        return edge.actionPointCost * 100 + _riskScore(edge.riskLevel);
      case MapRouteMode.safest:
        return _riskScore(edge.riskLevel) * 100 + edge.actionPointCost;
      case MapRouteMode.fastest:
        return _timeScore(edge.timeCost) * 100 + edge.actionPointCost;
    }
  }

  static int _riskScore(String value) {
    final risk = value.trim().toLowerCase();
    if (risk.contains('高') ||
        risk.contains('danger') ||
        risk.contains('high')) {
      return 3;
    }
    if (risk.contains('中') || risk.contains('medium')) {
      return 2;
    }
    return 1;
  }

  static int _timeScore(String value) {
    final time = value.trim();
    if (time.contains('半天') || time.contains('小时')) {
      return 3;
    }
    if (time.contains('分钟') || time.contains('一段')) {
      return 2;
    }
    return 1;
  }

  static String _normalizeRisk(String value) {
    switch (_riskScore(value)) {
      case 3:
        return '高';
      case 2:
        return '中';
      default:
        return '低';
    }
  }

  static bool _riskRoll(int seed, int turn, String edgeId, String risk) {
    final threshold = switch (_riskScore(risk)) { 3 => 38, 2 => 20, _ => 7 };
    return _stableHash('$seed|$turn|$edgeId') % 100 < threshold;
  }

  static int _turnAdvance(String value) {
    final step = value.trim();
    if (step.contains('一天') || step.contains('一日')) {
      return 3;
    }
    if (step.contains('阶段') || step.contains('关键事件')) {
      return 2;
    }
    return 1;
  }

  static String _mainGoalFromQuests(
    List<MapQuestState> quests,
    String fallback,
  ) {
    for (final quest in quests) {
      if (quest.status == MapQuestStatus.active) {
        return '${quest.title}（${quest.progress}/${quest.total}）';
      }
    }
    return fallback.trim().isEmpty ? '寻找新的行动目标。' : fallback;
  }

  static String _inferActionKind(String value) {
    if (RegExp(r'调查|搜索|检查|线索|翻找').hasMatch(value)) {
      return 'clue';
    }
    if (RegExp(r'交谈|询问|拜访|帮助|说服').hasMatch(value)) {
      return 'social';
    }
    if (RegExp(r'战斗|攻击|强行|突破|潜入').hasMatch(value)) {
      return 'danger';
    }
    if (RegExp(r'休息|等待|扎营').hasMatch(value)) {
      return 'rest';
    }
    return 'action';
  }

  static String _actionScene(String location, String action, String kind) {
    switch (kind) {
      case 'clue':
        return '你在$location完成了“$action”，新的线索让局势更加清晰。';
      case 'social':
        return '你在$location完成了“$action”，人物之间的态度随之变化。';
      case 'danger':
        return '你在$location冒险执行“$action”，危险正在逼近。';
      case 'rest':
        return '你在$location暂时休整，并观察局势变化。';
      default:
        return '你在$location执行了“$action”，世界对这次行动作出了回应。';
    }
  }

  static bool _isAdjacentLocation(
    String first,
    String second,
    List<MapEdge> edges,
  ) {
    if (first.isEmpty || second.isEmpty) {
      return false;
    }
    return edges.any(
      (edge) =>
          (edge.fromId == first && edge.toId == second) ||
          (edge.fromId == second && edge.toId == first),
    );
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static double _circleX(int index, int total) =>
      0.5 + cos((2 * pi * index / total) - pi / 2) * 0.38;

  static double _circleY(int index, int total) =>
      0.5 + sin((2 * pi * index / total) - pi / 2) * 0.38;
}
