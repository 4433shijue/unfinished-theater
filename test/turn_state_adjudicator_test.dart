import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/services/turn_state_adjudicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('npc lifecycle survives storage and legacy profiles stay active', () {
    final dead = NpcProfile(
      id: 'npc-dead',
      characterId: 'char-1',
      name: '旧友',
      lifecycle: NpcLifecycle.dead,
      createdAt: DateTime.utc(2026, 8, 20),
      updatedAt: DateTime.utc(2026, 8, 20),
    );

    final restored = NpcProfile.fromJson(dead.toJson());
    final legacy = NpcProfile.fromJson(<String, dynamic>{
      ...dead.toJson(),
      'id': 'npc-legacy',
    }..remove('lifecycle'));

    expect(restored.lifecycle, NpcLifecycle.dead);
    expect(restored.canSendMessages, isFalse);
    expect(restored.canChangeAffinity, isFalse);
    expect(legacy.lifecycle, NpcLifecycle.active);
    expect(NpcLifecycleX.tryFromValue('unchanged'), isNull);
  });

  test('adjudicator accepts strict state and gameplay JSON', () {
    final result = TurnStateAdjudicator.parse(
      '''
```json
{
  "gameState": {
    "时间": "深夜",
    "地点": "旧楼",
    "状态": "警觉",
    "当前任务": "确认声源",
    "NPC更新": [{"npcId":"npc-1","name":"林夏","affinityDelta":3}]
  },
  "gameplayPatch": {"ops":[]}
}
```
''',
      gameplayPatchRequired: true,
    );

    expect(result, isNotNull);
    expect(result!.protocolContent, contains('[GAME_STATE]'));
    expect(result.protocolContent, contains('"affinityDelta":3'));
    expect(result.protocolContent, contains('[THEATER_PATCH]'));
  });

  test(
      'second AI call commits canonical affinity, dynamic NPCs and proactive chat',
      () async {
    final character = _character();
    final activeNpc = _npc(
      id: 'npc-active',
      characterId: character.id,
      name: '陈放',
      affinity: 10,
    );
    final deadNpc = _npc(
      id: 'npc-dead',
      characterId: character.id,
      name: '顾闻',
      affinity: 30,
      lifecycle: NpcLifecycle.dead,
    );
    final missingNpc = _npc(
      id: 'npc-missing',
      characterId: character.id,
      name: '沈遥',
      affinity: 12,
      lifecycle: NpcLifecycle.missing,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(_settings().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[
        activeNpc.toJson(),
        deadNpc.toJson(),
        missingNpc.toJson(),
      ]),
    });

    final client = _AdjudicatingClient();
    final store = LocalStore();
    final controller = AppStateController(
      store: store,
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.queueUserMessage('我把伞递给陈放。'), isNull);
    expect(await controller.requestAssistantReply(), isNull);

    expect(client.adjudicationCalls, 1);
    expect(
      controller.currentHistory.messages.last.role,
      ChatRole.assistant,
    );
    expect(controller.currentGameState.location, '车站');

    final updatedActive = controller.npcProfileById(activeNpc.id)!;
    expect(updatedActive.affinity, 14);
    final activeMessages = await store.loadNpcMessages(activeNpc.id);
    expect(activeMessages, hasLength(1));
    expect(activeMessages.single.content, '到家后和我说一声。');
    expect(activeMessages.single.batchId, startsWith('npc_turn::'));

    final dynamicNpc = controller.currentWorldNpcProfiles.singleWhere(
      (npc) => npc.name == '唐禾',
    );
    expect(dynamicNpc.affinity, 2);
    expect(dynamicNpc.lifecycle, NpcLifecycle.active);

    final updatedDead = controller.npcProfileById(deadNpc.id)!;
    expect(updatedDead.affinity, 30);
    expect(await store.loadNpcMessages(deadNpc.id), isEmpty);
    expect(
      await controller.queueNpcUserMessage(deadNpc.id, '你还在吗？'),
      contains('私聊已冻结'),
    );

    final updatedMissing = controller.npcProfileById(missingNpc.id)!;
    expect(updatedMissing.lifecycle, NpcLifecycle.missing);
    expect(updatedMissing.affinity, 12);
    expect(await store.loadNpcMessages(missingNpc.id), isEmpty);
  });

  test('ambient NPC contact is delivered once at the third assistant turn',
      () async {
    final character = _character();
    final npc = _npc(
      id: 'npc-ambient',
      characterId: character.id,
      name: '陈放',
      affinity: 18,
    );
    final history = DialogueHistory(
      characterId: character.id,
      messages: <ChatMessage>[
        for (var index = 1; index <= 3; index++)
          ChatMessage(
            id: 'assistant-$index',
            role: ChatRole.assistant,
            content: '第 $index 轮剧情。',
            timestamp: DateTime.utc(2026, 8, 20, index),
            isSummarized: false,
          ),
      ],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(_settings().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[npc.toJson()]),
      'history_${character.id}': jsonEncode(history.toJson()),
    });
    final client = _AmbientClient();
    final store = LocalStore();
    final controller = AppStateController(
      store: store,
      apiClient: client,
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.debugRunAmbientNpcMessageForTest(
      character.id,
      sourceTurnId: 'assistant-3',
    );
    await controller.debugRunAmbientNpcMessageForTest(
      character.id,
      sourceTurnId: 'assistant-3',
    );

    final messages = await store.loadNpcMessages(npc.id);
    expect(client.utilityCalls, 1);
    expect(messages.map((message) => message.content), <String>[
      '刚才忘了问，你到家了吗？',
      '路上注意安全。',
    ]);
    expect(messages.map((message) => message.batchId).toSet(), hasLength(1));
    expect(controller.pendingNpcLetterNotice, contains('陈放'));
  });
}

AppSettings _settings() => AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );

CharacterProfile _character() => CharacterProfile(
      id: 'char-adjudicator',
      name: '裁决测试剧场',
      createdAt: DateTime.utc(2026, 8, 20),
      prompt: '推进一段现代都市剧情。',
      modelParams: ModelParams.defaults(),
      nextStepOptionsEnabled: false,
    );

NpcProfile _npc({
  required String id,
  required String characterId,
  required String name,
  required int affinity,
  NpcLifecycle lifecycle = NpcLifecycle.active,
}) {
  return NpcProfile(
    id: id,
    characterId: characterId,
    name: name,
    affinity: affinity,
    lifecycle: lifecycle,
    createdAt: DateTime.utc(2026, 8, 20),
    updatedAt: DateTime.utc(2026, 8, 20),
    sourceType: NpcProfileSource.auto,
    boundCharacterIds: <String>[characterId],
  );
}

class _AdjudicatingClient extends http.BaseClient {
  int adjudicationCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload = request is http.Request
        ? jsonDecode(request.body) as Map<String, dynamic>
        : const <String, dynamic>{};
    if (payload['stream'] == true) {
      const story = '''
雨停在车站外。你把伞递给陈放，他接过伞，提醒你到家后报个平安。
```html
<div>车站 · 雨后</div>
```
''';
      final event = jsonEncode(<String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'delta': <String, dynamic>{'content': story},
          },
        ],
      });
      return http.StreamedResponse(
        Stream<List<int>>.value(
          utf8.encode('data: $event\n\ndata: [DONE]\n\n'),
        ),
        200,
        headers: const <String, String>{
          'content-type': 'text/event-stream',
        },
      );
    }

    adjudicationCalls += 1;
    final content = jsonEncode(<String, dynamic>{
      'gameState': <String, dynamic>{
        '时间': '晚上九点',
        '地点': '车站',
        '状态': '雨后分别',
        '当前任务': '平安到家',
        '人物数据': <String>['你：准备返程'],
        '关系网': <String>['陈放：开始关心你的安全'],
        '剧情记录': <String>['你把伞递给陈放'],
        'NPC变化': <String>['陈放接受了你的伞'],
        'NPC更新': <Map<String, dynamic>>[
          <String, dynamic>{
            'npcId': 'npc-active',
            'name': '陈放',
            'affinityDelta': 4,
            'impression': '觉得你细心可靠',
            'proactiveMessage': '到家后和我说一声。',
          },
          <String, dynamic>{
            'npcId': 'npc-active',
            'name': '陈放',
            'affinityDelta': 4,
            'proactiveMessage': '到家后和我说一声。',
          },
          <String, dynamic>{
            'name': '唐禾',
            'description': '在车站帮忙指路的路人',
            'affinityDelta': 2,
            'lifecycle': 'active',
          },
          <String, dynamic>{
            'npcId': 'npc-dead',
            'name': '顾闻',
            'affinityDelta': 5,
            'proactiveMessage': '我一直都在。',
          },
          <String, dynamic>{
            'npcId': 'npc-missing',
            'name': '沈遥',
            'affinityDelta': 3,
            'lifecycle': 'active',
            'proactiveMessage': '我回来了。',
          },
        ],
      },
      'gameplayPatch': <String, dynamic>{'ops': <Object>[]},
    });
    final body = jsonEncode(<String, dynamic>{
      'choices': <Map<String, dynamic>>[
        <String, dynamic>{
          'message': <String, dynamic>{'content': content},
        },
      ],
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: const <String, String>{
        'content-type': 'application/json',
      },
    );
  }
}

class _AmbientClient extends LlmApiClient {
  int utilityCalls = 0;

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
    utilityCalls += 1;
    return jsonEncode(<String, dynamic>{
      'messages': <String>[
        '刚才忘了问，你到家了吗？',
        '路上注意安全。',
      ],
    });
  }
}
