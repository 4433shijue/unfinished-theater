import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/models/map_state.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/map_turn_engine.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/services/gameplay_system_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('map mode keeps visible locations Chinese and trims repeated intel',
      () async {
    final character = _character();
    final npc = _npc(character.id);
    final settings = AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );
    final previousMap = MapWorldState.empty(character.id).copyWith(
      currentLocationId: 'location_a',
      currentLocationName: '地点甲',
      locations: <MapLocationNode>[
        MapLocationNode(
          id: 'location_a',
          name: '地点甲',
          status: MapLocationStatus.current,
        ),
      ],
      discoveredClues: <String>[
        for (var i = 0; i < 30; i++) '旧线索$i',
      ],
      npcMovements: <String>[
        '角色甲停在地点甲入口，主动向你搭话：这里有新的动静，先别贸然进去。',
        for (var i = 0; i < 18; i++) '旧动向$i',
      ],
      eventLog: <String>['旧事件'],
      openingResolved: true,
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[npc.toJson()]),
      'map_state_${character.id}': jsonEncode(previousMap.toJson()),
    });

    final client = _FakeMapLlmApiClient(_mapResponse);
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: client,
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final error = await controller.runMapFreeAction('测试行动');

    expect(error, isNull);
    expect(
      client.systemPrompt,
      contains('用户可见地点名必须是简体中文'),
    );
    expect(
      client.userPrompt,
      contains('用户可见文本规则'),
    );
    final state = controller.currentMapState;
    expect(state.currentLocationId, 'location_a');
    expect(state.currentLocationName, '地点甲');
    final location = state.locations.firstWhere(
      (item) => item.id == 'location_a',
    );
    expect(location.name, '地点甲');
    expect(
      state.activeChoices.map((choice) => choice.label),
      contains('继续调查'),
    );
    expect(state.discoveredClues, hasLength(24));
    expect(state.discoveredClues.first, '关键物品甲会影响角色乙');
    expect(
      state.discoveredClues.where(
        (item) => item.contains('保留部分旧记忆'),
      ),
      hasLength(1),
    );
    expect(state.npcMovements, hasLength(16));
    expect(state.eventSummary, '地图摘要：地点甲传来新的动静');
    expect(state.eventLog.first, '地图摘要：地点甲传来新的动静');

    final messages = await LocalStore().loadNpcMessages(npc.id);
    expect(messages, hasLength(1));
    expect(messages.single.content, contains('这里有新的动静'));
  });

  test('rules map narrates settled turns without changing rule authority',
      () async {
    final character = _character().copyWith(gameplaySystem: _gameplaySystem());
    final settings = AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
    });

    final client = _FakeMapLlmApiClient.sequence(<String>[
      _badMapResponse,
      _rulesMapResponseWithGameplayPatch,
      _rulesMapResponseWithGameplayPatch,
    ]);
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: client,
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final error = await controller.generateInitialMap();

    expect(error, isNull);
    expect(client.callCount, 1);
    expect(client.systemPrompt, contains('无向有环图'));
    expect(client.userPrompt, contains('基础行动力 3'));
    expect(controller.currentMapState.isRulesDriven, isTrue);
    expect(controller.currentMapState.locations, hasLength(8));
    expect(
      controller.currentMapState.edges.length,
      greaterThanOrEqualTo(controller.currentMapState.locations.length + 2),
    );
    expect(controller.currentMapState.currentActionPoints, 3);
    expect(controller.currentMapState.temporaryActionPointLimit, 5);
    expect(controller.currentMapState.maxActionPoints, 8);
    expect(controller.currentMapState.needsBirthSelection, isTrue);
    final protectedStateBeforeBirth =
        _protectedGameStateProjection(controller.currentGameState);

    final spawnId = controller.currentMapState.spawnCandidates.first.locationId;
    expect(await controller.selectMapBirthLocation(spawnId), isNull);
    expect(client.callCount, 2);
    expect(
      _protectedGameStateProjection(controller.currentGameState),
      protectedStateBeforeBirth,
    );
    expect(controller.currentGameState.inventory, isNot(contains('物品甲')));
    expect(controller.currentGameState.inventory, isNot(contains('物品乙')));
    expect(
      controller.currentGameState.plotFlags,
      isNot(contains('你抵达地点甲并发现新的动静。')),
    );
    expect(
      controller.currentGameState.profileDetails
          .any((item) => item.contains('站在地点甲边缘')),
      isTrue,
    );
    expect(
      controller.currentGameState.relationshipNotes,
      contains('角色甲：愿意提醒你风险'),
    );
    expect(
      controller.currentGameState.npcUpdates.map((update) => update.name),
      contains('角色甲'),
    );
    expect(
      controller.currentGameState.npcChanges
          .any((item) => item.contains('主动向你搭话')),
      isTrue,
    );
    expect(
      controller.currentWorldNpcProfiles.map((profile) => profile.name),
      contains('角色甲'),
    );
    expect(controller.currentGameState.customVariables['局势.警戒'], 13);
    expect(controller.currentGameState.customVariablesRevision, 1);
    final destination = controller.currentMapState.edges
        .firstWhere(
          (edge) => edge.connects(controller.currentMapState.currentLocationId),
        )
        .other(controller.currentMapState.currentLocationId)!;
    final beforeRound = controller.currentMapState;
    const plannedAction = '检查沿途留下的脚印';
    final expectedSettled = const MapTurnEngine()
        .resolvePlannedRound(
          beforeRound,
          actions: const <String>[plannedAction],
          locationIds: <String>[destination],
          timeStep: '下一回合',
          structuredActions: <Map<String, dynamic>>[
            const <String, dynamic>{
              'kind': 'action',
              'label': plannedAction,
              'action': plannedAction,
            },
            <String, dynamic>{
              'kind': 'location',
              'label': '随后前往目标地点',
              'action': '前往目标地点',
              'locationId': destination,
            },
          ],
        )
        .state;
    expect(
      await controller.runMapPlannedRound(
        actions: const <String>[plannedAction],
        locationIds: <String>[destination],
        timeStep: '下一回合',
        structuredActions: <Map<String, dynamic>>[
          const <String, dynamic>{
            'kind': 'action',
            'label': plannedAction,
            'action': plannedAction,
          },
          <String, dynamic>{
            'kind': 'location',
            'label': '随后前往目标地点',
            'action': '前往目标地点',
            'locationId': destination,
          },
        ],
      ),
      isNull,
    );
    expect(client.callCount, 3);
    expect(controller.currentMapState.turnNumber, 1);
    expect(
      _protectedGameStateProjection(controller.currentGameState),
      protectedStateBeforeBirth,
    );
    expect(controller.currentGameState.customVariables['局势.警戒'], 16);
    expect(controller.currentGameState.customVariablesRevision, 2);
    expect(
      _lockedRulesProjection(controller.currentMapState),
      _lockedRulesProjection(expectedSettled),
    );
    final validLocationIds =
        controller.currentMapState.locations.map((item) => item.id).toSet();
    expect(
      controller.currentMapState.activeChoices.every(
        (choice) =>
            choice.locationId.isEmpty ||
            validLocationIds.contains(choice.locationId),
      ),
      isTrue,
    );
    expect(
      controller.currentMapState.activeChoices
          .where((choice) => choice.locationId.isNotEmpty)
          .every(
            (choice) =>
                choice.locationId ==
                controller.currentMapState.currentLocationId,
          ),
      isTrue,
    );
    expect(client.userPrompt, contains('结算前 MAP_STATE'));
    expect(client.userPrompt, contains('本地结算后 MAP_STATE（权威）'));
    expect(client.userPrompt, contains('不少于 2000 个中文字符'));
    expect(client.userPrompt, contains('本地规则结算日志'));
    expect(
      client.userPrompt.indexOf(plannedAction),
      lessThan(client.userPrompt.indexOf('随后前往目标地点')),
    );

    final history = await LocalStore().loadDialogueHistory(character.id);
    expect(
      history.messages
          .where((message) => message.role.name == 'assistant')
          .last
          .content,
      contains('【地图主线｜地图下一回合】'),
    );
    expect(
      history.messages.any((message) => message.content.contains('【本地回合结算】')),
      isFalse,
    );
  });

  test('rules map keeps the whole turn unchanged when AI narration fails',
      () async {
    final character = _character();
    final settings = AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
    });
    final client = _FakeMapLlmApiClient.sequence(<String>[
      _badMapResponse,
      _badMapResponse,
      _badMapResponse,
    ]);
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: client,
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.generateInitialMap(), isNull);
    final beforeMap = jsonEncode(controller.currentMapState.toJson());
    final beforeGame = jsonEncode(controller.currentGameState.toJson());
    final beforeHistory = await LocalStore().loadDialogueHistory(character.id);
    final spawnId = controller.currentMapState.spawnCandidates.first.locationId;

    final error = await controller.selectMapBirthLocation(spawnId);

    expect(error, contains('AI 叙事失败，本回合未提交'));
    expect(client.callCount, 3);
    expect(jsonEncode(controller.currentMapState.toJson()), beforeMap);
    expect(jsonEncode(controller.currentGameState.toJson()), beforeGame);
    final afterHistory = await LocalStore().loadDialogueHistory(character.id);
    expect(afterHistory.messages.map((message) => message.id),
        beforeHistory.messages.map((message) => message.id));
  });

  test('rules map retries persistence after commit without repeating the turn',
      () async {
    final character = _character();
    final settings = AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
    });
    final store = _FailOnceGameStateStore();
    final client = _FakeMapLlmApiClient.sequence(<String>[
      _badMapResponse,
      _rulesMapResponse,
      _rulesMapResponse,
    ]);
    final controller = AppStateController(
      store: store,
      apiClient: client,
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.generateInitialMap(), isNull);
    final spawnId = controller.currentMapState.spawnCandidates.first.locationId;
    expect(await controller.selectMapBirthLocation(spawnId), isNull);
    final turnBefore = controller.currentMapState.turnNumber;
    store.failNextSave();

    final error = await controller.runMapPlannedRound(
      actions: const <String>['检查当前地点的脚印'],
      locationIds: const <String>[],
      timeStep: '下一回合',
    );

    expect(error, isNull);
    expect(store.injectedFailures, 1);
    expect(controller.currentMapState.turnNumber, turnBefore + 1);
    final persistedMap = await LocalStore().loadMapState(character.id);
    final persistedGame = await LocalStore().loadGameState(character.id);
    final persistedHistory =
        await LocalStore().loadDialogueHistory(character.id);
    expect(persistedMap.turnNumber, turnBefore + 1);
    expect(persistedGame.status, contains('地图回合 ${turnBefore + 1}'));
    expect(
      persistedHistory.messages.last.content,
      contains('【地图主线｜地图下一回合】'),
    );
  });

  test('rules map stays unchanged when the map commit point cannot persist',
      () async {
    final character = _character();
    final settings = AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
    });
    final store = _FailingMapCommitStore();
    final controller = AppStateController(
      store: store,
      apiClient: _FakeMapLlmApiClient.sequence(<String>[
        _badMapResponse,
        _rulesMapResponse,
        _rulesMapResponse,
      ]),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.generateInitialMap(), isNull);
    final spawnId = controller.currentMapState.spawnCandidates.first.locationId;
    expect(await controller.selectMapBirthLocation(spawnId), isNull);
    final beforeMap = jsonEncode(controller.currentMapState.toJson());
    final beforeGame = jsonEncode(controller.currentGameState.toJson());
    final beforeHistory = await LocalStore().loadDialogueHistory(character.id);
    store.failNextSaves(2);

    final error = await controller.runMapPlannedRound(
      actions: const <String>['检查当前地点的门窗'],
      locationIds: const <String>[],
      timeStep: '下一回合',
    );

    expect(error, contains('本回合未提交'));
    expect(store.injectedFailures, 2);
    expect(jsonEncode(controller.currentMapState.toJson()), beforeMap);
    expect(jsonEncode(controller.currentGameState.toJson()), beforeGame);
    final afterMap = await LocalStore().loadMapState(character.id);
    final afterHistory = await LocalStore().loadDialogueHistory(character.id);
    expect(jsonEncode(afterMap.toJson()), beforeMap);
    expect(
      afterHistory.messages.map((message) => message.id),
      beforeHistory.messages.map((message) => message.id),
    );
  });

  test('rules map removes current locked and unreachable AI location choices',
      () async {
    final character = _character();
    final settings = AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );
    final rulesState = MapWorldState.empty(character.id).copyWith(
      title: '可达性测试地图',
      openingResolved: true,
      schemaVersion: 2,
      seed: 17,
      turnNumber: 1,
      birthLocationId: 'location_a',
      currentLocationId: 'location_a',
      currentLocationName: '地点甲',
      locations: <MapLocationNode>[
        MapLocationNode(
          id: 'location_a',
          name: '地点甲',
          status: MapLocationStatus.current,
        ),
        MapLocationNode(
          id: 'location_b',
          name: '地点乙',
          status: MapLocationStatus.available,
        ),
        MapLocationNode(
          id: 'location_c',
          name: '地点丙',
          status: MapLocationStatus.available,
        ),
        MapLocationNode(
          id: 'location_d',
          name: '地点丁',
          status: MapLocationStatus.locked,
        ),
      ],
      edges: const <MapEdge>[
        MapEdge(
          id: 'edge_ab',
          fromId: 'location_a',
          toId: 'location_b',
        ),
        MapEdge(
          id: 'edge_ac',
          fromId: 'location_a',
          toId: 'location_c',
          blocked: true,
        ),
      ],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'map_state_${character.id}': jsonEncode(rulesState.toJson()),
    });
    final response = _rulesMapResponseWithChoices(
      const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'stay_current',
          'label': '返回地点甲中心',
          'action': '返回地点甲中心查看告示',
          'kind': 'location',
          'locationId': 'location_a',
        },
        <String, dynamic>{
          'id': 'go_reachable',
          'label': '前往地点乙',
          'action': '前往地点乙调查道路',
          'kind': 'location',
          'locationId': 'location_b',
        },
        <String, dynamic>{
          'id': 'go_blocked',
          'label': '前往地点丙',
          'action': '前往地点丙查看封锁道路',
          'kind': 'location',
          'locationId': 'location_c',
        },
        <String, dynamic>{
          'id': 'go_locked',
          'label': '前往地点丁',
          'action': '前往地点丁检查锁门',
          'kind': 'location',
          'locationId': 'location_d',
        },
      ],
    );
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: _FakeMapLlmApiClient(response),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.runMapFreeAction('检查地点甲的墙面'), isNull);

    final choices = controller.currentMapState.activeChoices;
    expect(choices, hasLength(greaterThanOrEqualTo(3)));
    expect(
      choices
          .where((choice) => choice.kind == MapStoryChoiceKind.location)
          .map((choice) => choice.locationId),
      <String>['location_b'],
    );
    expect(
      choices.any((choice) => choice.kind != MapStoryChoiceKind.location),
      isTrue,
    );
  });

  test('map opening choices are local and do not call AI', () async {
    final character = _character();
    final settings = AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
    });
    final client = _FakeMapLlmApiClient(_badMapResponse);
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: client,
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.generateMapOpeningChoices(), isNull);
    expect(controller.currentMapState.openingChoices, hasLength(12));
    expect(client.callCount, 0);
  });

  test('map mode applies and persists gameplay variable patches', () async {
    final character = _character().copyWith(
      gameplaySystem: _gameplaySystem(),
    );
    final settings = AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );
    final response = _mapResponse.replaceFirst(
      '\n[MAP_STATE]',
      '''

[THEATER_PATCH]
{"ops":[{"op":"inc","path":"局势.警戒","value":3,"reason":"地点甲出现新的动静"}]}
[/THEATER_PATCH]

[MAP_STATE]''',
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'map_state_${character.id}': jsonEncode(
        MapWorldState.empty(character.id)
            .copyWith(
              currentLocationId: 'location_a',
              currentLocationName: '地点甲',
              locations: <MapLocationNode>[
                MapLocationNode(
                  id: 'location_a',
                  name: '地点甲',
                  status: MapLocationStatus.current,
                ),
              ],
              openingResolved: true,
            )
            .toJson(),
      ),
    });

    final client = _FakeMapLlmApiClient(response);
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: client,
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final error = await controller.runMapFreeAction('检查新的动静');

    expect(error, isNull);
    expect(client.userPrompt, contains('局势.警戒 = 10'));
    expect(controller.currentGameState.customVariables['局势.警戒'], 13);
    expect(controller.currentGameState.customVariablesRevision, 1);
    expect(
      controller.currentGameState.gameplayVariableChanges.single,
      contains('警戒：10 → 13'),
    );
    final persisted = await LocalStore().loadGameState(character.id);
    expect(persisted.customVariables['局势.警戒'], 13);
  });
}

CharacterProfile _character() {
  return CharacterProfile(
    id: 'char-map',
    name: '测试角色',
    createdAt: DateTime(2026, 5, 23),
    prompt: '用于测试地图主线的角色设定。',
    modelParams: ModelParams.defaults(),
    mapModeEnabled: true,
  );
}

NpcProfile _npc(String characterId) {
  return NpcProfile(
    id: 'npc-role-a',
    characterId: characterId,
    name: '角色甲',
    description: '用于测试地图 NPC 主动消息的中性角色。',
    createdAt: DateTime(2026, 5, 23),
    updatedAt: DateTime(2026, 5, 23),
    boundCharacterIds: <String>[characterId],
  );
}

GameplaySystem _gameplaySystem() => GameplaySystemParser.parse('''
{
  "schemaVersion": 1,
  "title": "地点甲警戒网",
  "summary": "追踪地图调查引发的局势变化。",
  "coreLoop": "调查地点、承担风险、降低警戒。",
  "variables": [
    {"key":"局势.警戒","label":"警戒","group":"局势","type":"number","visibility":"public","authority":"ai","initialValue":10,"description":"公开行动或异常动静会提高警戒","min":0,"max":100,"maxDelta":8},
    {"key":"调查.线索进度","label":"线索进度","group":"调查","type":"number","visibility":"fuzzy","authority":"ai","initialValue":0,"description":"确认关键线索时推进","min":0,"max":100,"maxDelta":10,"stages":[{"min":0,"label":"零散"},{"min":50,"label":"成形"}]},
    {"key":"幕后.追踪者距离","label":"追踪者距离","group":"幕后","type":"number","visibility":"director","authority":"ai","initialValue":80,"description":"追踪者接近时降低","min":0,"max":100,"maxDelta":10},
    {"key":"幕后.地图种子","label":"地图种子","group":"幕后","type":"number","visibility":"engine","authority":"rule","initialValue":771,"description":"固定地图秘密"}
  ],
  "rules": []
}
''');

class _FakeMapLlmApiClient extends LlmApiClient {
  _FakeMapLlmApiClient(String response) : _responses = <String>[response];

  _FakeMapLlmApiClient.sequence(List<String> responses)
      : _responses = List<String>.from(responses);

  final List<String> _responses;
  String systemPrompt = '';
  String userPrompt = '';
  String repairPrompt = '';
  int callCount = 0;

  @override
  Future<String> runUtilityTask({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.45,
    double topP = 0.9,
    int maxTokens = 8192,
    LlmCancellationToken? cancellationToken,
  }) async {
    callCount += 1;
    this.systemPrompt = systemPrompt;
    this.userPrompt = userPrompt;
    final responseIndex = callCount - 1 < _responses.length
        ? callCount - 1
        : _responses.length - 1;
    final response = _responses[responseIndex];
    if (systemPrompt.contains('格式修复器')) {
      repairPrompt = userPrompt;
      return response;
    }
    return response;
  }
}

class _FailOnceGameStateStore extends LocalStore {
  bool _failNext = false;
  int injectedFailures = 0;

  void failNextSave() => _failNext = true;

  @override
  Future<void> saveGameState(GameStateSnapshot state) async {
    if (_failNext) {
      _failNext = false;
      injectedFailures += 1;
      throw StateError('注入的游戏状态保存失败');
    }
    await super.saveGameState(state);
  }
}

class _FailingMapCommitStore extends LocalStore {
  int _remainingFailures = 0;
  int injectedFailures = 0;

  void failNextSaves(int count) => _remainingFailures = count;

  @override
  Future<void> saveMapState(MapWorldState state) async {
    if (_remainingFailures > 0) {
      _remainingFailures -= 1;
      injectedFailures += 1;
      throw StateError('注入的地图状态保存失败');
    }
    await super.saveMapState(state);
  }
}

Map<String, dynamic> _protectedGameStateProjection(GameStateSnapshot state) {
  return <String, dynamic>{
    'inventory': state.inventory,
    'storyInventory': state.storyInventory
        .map((item) => item.toJson())
        .toList(growable: false),
    'metrics': state.metrics,
  };
}

String _rulesMapResponseWithChoices(List<Map<String, dynamic>> choices) {
  final replacement =
      '"activeChoices": ${const JsonEncoder.withIndent('  ').convert(choices)},\n'
      '  "discoveredClues"';
  final result = _rulesMapResponse.replaceFirst(
    RegExp(r'"activeChoices": \[[\s\S]*?\n  \],\n  "discoveredClues"'),
    replacement,
  );
  if (identical(result, _rulesMapResponse) || result == _rulesMapResponse) {
    throw StateError('测试地图回复没有 activeChoices 块');
  }
  return result;
}

Map<String, dynamic> _lockedRulesProjection(MapWorldState state) {
  return <String, dynamic>{
    'schemaVersion': state.schemaVersion,
    'seed': state.seed,
    'turnNumber': state.turnNumber,
    'baseActionPoints': state.baseActionPoints,
    'currentActionPoints': state.currentActionPoints,
    'temporaryActionPointLimit': state.temporaryActionPointLimit,
    'maxActionPoints': state.maxActionPoints,
    'birthLocationId': state.birthLocationId,
    'currentLocationId': state.currentLocationId,
    'currentLocationName': state.currentLocationName,
    'timeLabel': state.timeLabel,
    'stage': state.stage,
    'mainGoal': state.mainGoal,
    'threatClock': state.threatClock,
    'threatLimit': state.threatLimit,
    'nextMoveDiscount': state.nextMoveDiscount,
    'actionItemUsedThisTurn': state.actionItemUsedThisTurn,
    'edges': state.edges.map((item) => item.toJson()).toList(),
    'spawnCandidates':
        state.spawnCandidates.map((item) => item.toJson()).toList(),
    'mapInventory': state.mapInventory.map((item) => item.toJson()).toList(),
    'statusEffects': state.statusEffects.map((item) => item.toJson()).toList(),
    'quests': state.quests.map((item) => item.toJson()).toList(),
    'worldEvents': state.worldEvents.map((item) => item.toJson()).toList(),
    'npcAgents': state.npcAgents.map((item) => item.toJson()).toList(),
    'facts': state.facts,
    'locations': state.locations
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'name': item.name,
            'parentId': item.parentId,
            'status': item.status.name,
            'riskLevel': item.riskLevel,
            'timeCost': item.timeCost,
            'x': item.x,
            'y': item.y,
            'tags': item.tags,
            'actions': item.actions.map((action) => action.toJson()).toList(),
          },
        )
        .toList(),
  };
}

const String _mapResponse = '''
地点甲传来新的动静，角色甲提醒你先观察。

[GAME_STATE]
时间：黄昏
地点：地点甲
状态：正在调查地点甲
当前任务：判断地点甲是否安全
人物数据：你：站在地点甲边缘，保持警惕
剧情物品栏：物品甲、物品乙
关系网：角色甲：愿意提醒你风险
剧情记录：你抵达地点甲并发现新的动静。
NPC变化：角色甲：停在地点甲入口，主动向你搭话。
NPC更新：角色甲｜简介：用于测试地图 NPC 主动消息的中性角色｜好感度：8｜印象：觉得你保持谨慎｜主动消息：这里有新的动静，先别贸然进去。
[/GAME_STATE]

[MAP_STATE]
{
  "title": "测试地图",
  "timeLabel": "黄昏",
  "stage": "地点甲调查",
  "mainGoal": "找出地点甲的新动静来源",
  "currentLocationId": "location_a",
  "currentLocationName": "location_a",
  "currentScene": "地点甲出现了新的变化。",
  "locations": [
    {
      "id": "location_a",
      "name": "地点甲",
      "description": "地点甲位于测试地图边缘。",
      "scene": "地点甲附近有物品甲留下的痕迹。",
      "status": "current",
      "npcs": ["角色甲"],
      "clues": ["地点甲出现周期性提示"],
      "nextActions": ["检查物品甲"],
      "riskLevel": "中",
      "timeCost": "10分钟"
    }
  ],
  "activeChoices": [
    {
      "id": "inspect_well",
      "label": "inspect_well",
      "action": "继续调查",
      "kind": "clue",
      "locationId": "location_a"
    },
    {
      "id": "talk_role_a",
      "label": "询问角色甲",
      "action": "询问角色甲新的动静",
      "kind": "social",
      "locationId": "location_a"
    },
    {
      "id": "check_item_a",
      "label": "检查物品甲",
      "action": "检查物品甲附近的痕迹",
      "kind": "clue",
      "locationId": "location_a"
    }
  ],
  "discoveredClues": [
    "关键物品甲会影响角色乙",
    "角色乙保留部分旧记忆",
    "角色乙可能保留部分旧记忆",
    "地点甲出现周期性提示",
    "物品甲附近有残留痕迹",
    "新线索05",
    "新线索06",
    "新线索07",
    "新线索08",
    "新线索09",
    "新线索10",
    "新线索11",
    "新线索12",
    "新线索13",
    "新线索14",
    "新线索15",
    "新线索16",
    "新线索17",
    "新线索18",
    "新线索19",
    "新线索20",
    "新线索21",
    "新线索22",
    "新线索23",
    "新线索24",
    "新线索25"
  ],
  "npcPositions": [
    {
      "id": "role_a",
      "name": "角色甲",
      "locationId": "location_a",
      "locationName": "location_a",
      "status": "主动提醒你",
      "intent": "阻止你贸然进入"
    }
  ],
  "npcMovements": [
    "NPC【角色甲】停在地点甲入口，主动向你搭话：这里有新的动静，先别贸然进去。",
    "地点甲入口有脚步声",
    "新动向02",
    "新动向03",
    "新动向04",
    "新动向05",
    "新动向06",
    "新动向07",
    "新动向08",
    "新动向09",
    "新动向10",
    "新动向11",
    "新动向12",
    "新动向13",
    "新动向14",
    "新动向15",
    "新动向16"
  ],
  "eventSummary": "地图摘要：地点甲传来新的动静"
}
[/MAP_STATE]
''';

final String _rulesMapResponse = '''
${List<String>.generate(
  72,
  (index) =>
      '风从廊檐下穿过，灯影随脚步轻轻晃动。你依照刚才选定的行动继续向前，沿途的痕迹、人物的神情与逐渐逼近的声响彼此印证。同行者压低声音说出新的判断，又及时停下来等待你的回应；这段经历只呈现已经结算的行动后果，没有替你决定下一步。',
).join('\n')}
$_mapResponse
''';

final String _rulesMapResponseWithGameplayPatch =
    _rulesMapResponse.replaceFirst(
  '\n[MAP_STATE]',
  '''

[THEATER_PATCH]
{"ops":[{"op":"inc","path":"局势.警戒","value":3,"reason":"地图行动引起了新的注意"}]}
[/THEATER_PATCH]

[MAP_STATE]''',
);

const String _badMapResponse = '''
地点甲传来新的动静，但这次模型忘了状态面板。

[MAP_STATE]
{
  "title": "测试地图",
  "timeLabel": "黄昏",
  "stage": "地点甲调查",
  "mainGoal": "找出地点甲的新动静来源",
  "currentLocationId": "location_a",
  "currentLocationName": "地点甲",
  "currentScene": "地点甲出现了新的变化。",
  "locations": [
    {
      "id": "location_a",
      "name": "地点甲",
      "description": "地点甲位于测试地图边缘。",
      "scene": "地点甲附近有物品甲留下的痕迹。",
      "status": "current",
      "npcs": ["角色甲"],
      "clues": ["地点甲出现周期性提示"],
      "nextActions": ["检查物品甲"],
      "riskLevel": "中",
      "timeCost": "10分钟"
    },
    {
      "id": "location_b",
      "name": "地点乙",
      "description": "地点乙仍在远处。",
      "status": "available"
    },
    {
      "id": "location_c",
      "name": "地点丙",
      "description": "地点丙藏着旧记录。",
      "status": "available"
    },
    {
      "id": "location_d",
      "name": "地点丁",
      "description": "地点丁暂时封锁。",
      "status": "locked"
    },
    {
      "id": "location_e",
      "name": "地点戊",
      "description": "地点戊灯光昏暗。",
      "status": "available"
    },
    {
      "id": "location_f",
      "name": "地点己",
      "description": "地点己靠近出口。",
      "status": "available"
    }
  ],
  "activeChoices": [
    {
      "id": "continue",
      "label": "继续探索",
      "action": "继续探索",
      "kind": "action"
    },
    {
      "id": "look",
      "label": "观察周围",
      "action": "观察周围",
      "kind": "clue"
    },
    {
      "id": "wait",
      "label": "等待",
      "action": "等待",
      "kind": "rest"
    }
  ],
  "discoveredClues": ["地点甲出现周期性提示"],
  "npcPositions": [
    {
      "id": "role_a",
      "name": "角色甲",
      "locationId": "location_a",
      "locationName": "地点甲",
      "status": "主动提醒你",
      "intent": "阻止你贸然进入"
    }
  ],
  "npcMovements": ["角色甲停在地点甲入口"],
  "eventSummary": "地点甲传来新的动静"
}
[/MAP_STATE]

[CHOICES]
A|继续探索
[/CHOICES]
''';
