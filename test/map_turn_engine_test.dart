import 'package:ai_roleplay_chat/models/map_state.dart';
import 'package:ai_roleplay_chat/services/map_turn_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = MapTurnEngine();

  test('blueprint becomes connected undirected cyclic graph', () {
    final state = engine.prepareBlueprint(
      MapWorldState.empty('graph').copyWith(
        title: '测试图',
        locations: <MapLocationNode>[
          for (var index = 0; index < 8; index++)
            MapLocationNode(
              id: 'n$index',
              name: '地点$index',
              actions: <MapActionDefinition>[
                MapActionDefinition(
                  id: 'a$index',
                  label: '调查地点$index',
                  kind: 'clue',
                ),
              ],
            ),
        ],
      ),
      characterName: '测试角色',
    );

    expect(state.isRulesDriven, isTrue);
    expect(state.locations, hasLength(8));
    expect(state.edges.length, greaterThanOrEqualTo(10));
    expect(state.spawnCandidates, hasLength(3));

    final reached = <String>{state.locations.first.id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final edge in state.edges) {
        if (reached.contains(edge.fromId) && reached.add(edge.toId)) {
          changed = true;
        }
        if (reached.contains(edge.toId) && reached.add(edge.fromId)) {
          changed = true;
        }
      }
    }
    expect(reached, hasLength(state.locations.length));
    for (final edge in state.edges) {
      expect(edge.fromId, isNot(edge.toId));
      final reverseMatches = state.edges.where(
        (other) => other.fromId == edge.toId && other.toId == edge.fromId,
      );
      expect(reverseMatches, isEmpty);
    }
  });

  test('birth starts at 3 AP with a temporary cap of 5 and hard cap of 8', () {
    var state = _readyState(engine);
    final spawn = state.spawnCandidates.first.locationId;
    final birth = engine.selectBirthLocation(state, spawn);
    expect(birth.error, isNull);
    state = birth.state;
    expect(state.currentActionPoints, 3);
    expect(state.temporaryActionPointLimit, 5);
    expect(state.maxActionPoints, 8);

    state = state.copyWith(
      mapInventory: const <MapInventoryItem>[
        MapInventoryItem(
          id: 'stimulant',
          name: '兴奋剂',
          kind: MapItemKind.restoreActionPoints,
          amount: 2,
          quantity: 2,
          sideEffect: 'fatigue',
        ),
        MapInventoryItem(
          id: 'emergency_reserve',
          name: '应急储备',
          kind: MapItemKind.restoreActionPoints,
          amount: 5,
          quantity: 2,
          sideEffect: 'fatigue',
        ),
      ],
    );
    final first = engine.useItem(state, 'stimulant');
    expect(first.error, isNull);
    expect(first.state.currentActionPoints, 5);
    expect(first.state.statusEffects.single.nextTurnActionPointModifier, -1);

    final boosted = engine.useItem(
      first.state.copyWith(actionItemUsedThisTurn: false),
      'emergency_reserve',
    );
    expect(boosted.error, isNull);
    expect(boosted.state.currentActionPoints, 8);

    final capped = engine.useItem(
      boosted.state.copyWith(actionItemUsedThisTurn: false),
      'emergency_reserve',
    );
    expect(capped.error, contains('总上限'));
    expect(capped.state.currentActionPoints, 8);
  });

  test('round refresh respects the temporary AP limit', () {
    var state = _readyState(engine);
    state = engine
        .selectBirthLocation(state, state.spawnCandidates.first.locationId)
        .state
        .copyWith(
      currentActionPoints: 8,
      statusEffects: const <MapStatusEffect>[
        MapStatusEffect(
          id: 'well_rested',
          name: '充分休息',
          nextTurnActionPointModifier: 2,
        ),
      ],
    );

    final next = engine.finishRound(state, '下一回合');

    expect(next.state.currentActionPoints, 5);
    expect(next.state.temporaryActionPointLimit, 5);
    expect(next.state.maxActionPoints, 8);
  });

  test('route works in both directions and respects AP costs', () {
    var state = _readyState(engine);
    state = engine
        .selectBirthLocation(state, state.spawnCandidates.first.locationId)
        .state;
    final edge = state.edges.firstWhere(
      (item) => item.connects(state.currentLocationId),
    );
    final other = edge.other(state.currentLocationId)!;

    final outward = engine.findRoute(state, other);
    final backward =
        engine.findRouteBetween(state, other, state.currentLocationId);

    expect(outward.isReachable, isTrue);
    expect(backward.isReachable, isTrue);
    expect(outward.totalActionPointCost, edge.actionPointCost);
    expect(backward.totalActionPointCost, edge.actionPointCost);
  });

  test('planned movement and NPC turns are deterministic', () {
    var state = _readyState(engine, withNpc: true);
    state = engine
        .selectBirthLocation(state, state.spawnCandidates.first.locationId)
        .state;
    final destination = state.edges
        .firstWhere((edge) => edge.connects(state.currentLocationId))
        .other(state.currentLocationId)!;

    final first = engine.resolvePlannedRound(
      state,
      actions: const <String>[],
      locationIds: <String>[destination],
      timeStep: '下一回合',
    );
    final replay = engine.resolvePlannedRound(
      state,
      actions: const <String>[],
      locationIds: <String>[destination],
      timeStep: '下一回合',
    );

    expect(first.error, isNull);
    expect(first.logs, replay.logs);
    expect(first.state.currentLocationId, replay.state.currentLocationId);
    expect(
      first.state.npcAgents.map((item) => item.toJson()),
      replay.state.npcAgents.map((item) => item.toJson()),
    );
    expect(first.state.threatClock, replay.state.threatClock);
    expect(first.state.currentLocationId, destination);
    expect(first.state.currentActionPoints, 3);
    expect(first.state.turnNumber, 1);

    final beforeNpc = state.npcAgents.single.trueLocationId;
    final afterNpc = first.state.npcAgents.single.trueLocationId;
    if (beforeNpc != afterNpc) {
      expect(
        state.edges.any(
          (edge) =>
              edge.connects(beforeNpc) && edge.other(beforeNpc) == afterNpc,
        ),
        isTrue,
      );
    }
  });

  test('structured plan executes investigation before movement', () {
    var state = _readyState(engine);
    state = engine
        .selectBirthLocation(state, state.spawnCandidates.first.locationId)
        .state;
    final origin = state.currentLocationId;
    final destination =
        state.edges.firstWhere((edge) => edge.connects(origin)).other(origin)!;

    final result = engine.resolvePlannedRound(
      state,
      actions: const <String>['调查地点0'],
      locationIds: <String>[destination],
      timeStep: '下一回合',
      structuredActions: <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'clue',
          'action': '调查地点0',
          'locationId': origin,
        },
        <String, dynamic>{
          'kind': 'location',
          'locationId': destination,
        },
      ],
    );

    final actionLog = result.logs.indexWhere((item) => item.contains('在地点0执行'));
    final movementLog =
        result.logs.indexWhere((item) => item.contains('抵达地点1'));
    expect(result.error, isNull);
    expect(actionLog, greaterThanOrEqualTo(0));
    expect(movementLog, greaterThan(actionLog));
    expect(result.state.discoveredClues, contains('地点0的线索'));
    expect(result.state.currentLocationId, destination);
  });

  test('structured plan executes movement before investigation', () {
    var state = _readyState(engine);
    state = engine
        .selectBirthLocation(state, state.spawnCandidates.first.locationId)
        .state;
    final destination = state.edges
        .firstWhere((edge) => edge.connects(state.currentLocationId))
        .other(state.currentLocationId)!;

    final result = engine.resolvePlannedRound(
      state,
      actions: const <String>['调查地点1'],
      locationIds: <String>[destination],
      timeStep: '下一回合',
      structuredActions: <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'location',
          'locationId': destination,
        },
        <String, dynamic>{
          'kind': 'clue',
          'action': '调查地点1',
          'locationId': destination,
        },
      ],
    );

    final movementLog =
        result.logs.indexWhere((item) => item.contains('抵达地点1'));
    final actionLog = result.logs.indexWhere((item) => item.contains('在地点1执行'));
    expect(result.error, isNull);
    expect(movementLog, greaterThanOrEqualTo(0));
    expect(actionLog, greaterThan(movementLog));
    expect(result.state.discoveredClues, contains('地点1的线索'));
    expect(result.state.currentLocationId, destination);

    final legacyResult = engine.resolvePlannedRound(
      state,
      actions: const <String>['调查地点1'],
      locationIds: <String>[destination],
      timeStep: '下一回合',
    );
    final legacyMovementLog =
        legacyResult.logs.indexWhere((item) => item.contains('抵达地点1'));
    final legacyActionLog =
        legacyResult.logs.indexWhere((item) => item.contains('在地点1执行'));
    expect(legacyMovementLog, greaterThanOrEqualTo(0));
    expect(legacyActionLog, greaterThan(legacyMovementLog));
  });

  test('rules state survives JSON round trip', () {
    final state = _readyState(engine);
    final restored = MapWorldState.fromJson(state.toJson());

    expect(restored.schemaVersion, 2);
    expect(restored.baseActionPoints, 3);
    expect(restored.temporaryActionPointLimit, 5);
    expect(restored.maxActionPoints, 8);
    expect(restored.edges.length, state.edges.length);
    expect(restored.spawnCandidates.length, 3);
    expect(restored.mapInventory, isNotEmpty);
    expect(restored.quests, isNotEmpty);
    expect(restored.worldEvents, isNotEmpty);
  });

  test('older rules saves migrate 5 AP max into the temporary limit', () {
    final restored = MapWorldState.fromJson(<String, dynamic>{
      'characterId': 'legacy-map',
      'schemaVersion': 2,
      'currentActionPoints': 5,
      'maxActionPoints': 5,
    });

    expect(restored.currentActionPoints, 5);
    expect(restored.temporaryActionPointLimit, 5);
    expect(restored.maxActionPoints, 8);
  });
}

MapWorldState _readyState(
  MapTurnEngine engine, {
  bool withNpc = false,
}) {
  final locations = <MapLocationNode>[
    for (var index = 0; index < 8; index++)
      MapLocationNode(
        id: 'node_$index',
        name: '地点$index',
        status: MapLocationStatus.available,
        riskLevel: index.isEven ? '低' : '中',
        tags: index == 0 ? const <String>['safe'] : const <String>[],
        actions: <MapActionDefinition>[
          MapActionDefinition(
            id: 'inspect_$index',
            label: '调查地点$index',
            description: '检查地点$index的痕迹',
            kind: 'clue',
            clue: '地点$index的线索',
          ),
        ],
      ),
  ];
  return engine.prepareBlueprint(
    MapWorldState.empty('engine').copyWith(
      title: '引擎测试地图',
      locations: locations,
      edges: <MapEdge>[
        for (var index = 0; index < locations.length; index++)
          MapEdge(
            id: 'edge_$index',
            fromId: locations[index].id,
            toId: locations[(index + 1) % locations.length].id,
            actionPointCost: index == 1 ? 2 : 1,
          ),
        const MapEdge(
          id: 'chord_a',
          fromId: 'node_0',
          toId: 'node_4',
          actionPointCost: 2,
          riskLevel: '高',
        ),
        const MapEdge(
          id: 'chord_b',
          fromId: 'node_2',
          toId: 'node_6',
        ),
      ],
      spawnCandidates: const <MapSpawnCandidate>[
        MapSpawnCandidate(
          locationId: 'node_0',
          label: '安全起点',
          style: 'safe',
        ),
        MapSpawnCandidate(
          locationId: 'node_2',
          label: '社交起点',
          style: 'social',
        ),
        MapSpawnCandidate(
          locationId: 'node_5',
          label: '冒险起点',
          style: 'danger',
        ),
      ],
      npcAgents: withNpc
          ? const <MapNpcAgentState>[
              MapNpcAgentState(
                id: 'npc_1',
                name: '测试 NPC',
                trueLocationId: 'node_3',
                homeLocationId: 'node_3',
                goalLocationId: 'node_6',
                goal: '前往地点6',
              ),
            ]
          : const <MapNpcAgentState>[],
    ),
    characterName: '测试角色',
  );
}
