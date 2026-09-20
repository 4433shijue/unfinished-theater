import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/gamification.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('continuation keeps original inspiration and appends only the new body',
      () async {
    const partial = '标题：雨夜修车\n陈放推开修理铺的门，林夏还握着那把扳手。';
    const continuation = '她把钥匙放到桌边，示意他先把湿外套脱下来。';
    final client = _FanficClient(<String>[partial, continuation]);
    final controller = await _createController(client);
    addTearDown(controller.dispose);

    expect(await _generate(controller), isNull);

    expect(client.prompts, hasLength(2));
    final retry = client.prompts.last;
    expect(retry, contains('两名修理师在雨夜替对方修好自行车'));
    expect(retry, contains('陈放'));
    expect(retry, contains('林夏'));
    expect(retry, contains(partial));
    expect(retry, contains('只输出需要追加的正文'));
    final saved = controller.lastGeneratedFanficResult!;
    expect(saved.title, '雨夜修车');
    expect(saved.content, '$partial\n\n$continuation');
    expect(controller.gamification.coins, 10);
  });

  test('long body without title uses local title and never requests new scenes',
      () async {
    final body = List<String>.filled(250, '两人收好工具，关上修理铺。').join();
    final client = _FanficClient(<String>[body]);
    final controller = await _createController(client);
    addTearDown(controller.dispose);

    expect(await _generate(controller), isNull);

    expect(client.prompts, hasLength(1));
    final saved = controller.lastGeneratedFanficResult!;
    expect(saved.title, contains('陈放 × 林夏'));
    expect(saved.title, contains('两名修理师'));
    expect(saved.content, body);
  });
}

Future<String?> _generate(AppStateController controller) {
  return controller.generateFanfic(
    pairingMode: 'npc_npc',
    firstParticipantId: 'npc-chen',
    secondParticipantId: 'npc-lin',
    inspiration: '两名修理师在雨夜替对方修好自行车',
    blindBox: false,
  );
}

Future<AppStateController> _createController(_FanficClient client) async {
  final now = DateTime(2026, 9, 20);
  final character = CharacterProfile(
    id: 'fanfic-context-world',
    name: '旧城调查',
    createdAt: now,
    prompt: '在旧站台调查异常事件。',
    modelParams: ModelParams.defaults(),
  );
  final npcs = <NpcProfile>[
    NpcProfile(
      id: 'npc-chen',
      characterId: character.id,
      name: '陈放',
      description: '话少，遇到困难先动手试。',
      createdAt: now,
      updatedAt: now,
    ),
    NpcProfile(
      id: 'npc-lin',
      characterId: character.id,
      name: '林夏',
      description: '愿意耐心听完对方的话。',
      createdAt: now,
      updatedAt: now,
    ),
  ];
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_settings': jsonEncode(
      AppSettings.initial()
          .copyWith(
            apiUrl: 'https://example.invalid/v1',
            apiKey: 'test-key',
            modelName: 'test-model',
          )
          .toJson(),
    ),
    'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
    'selected_character_id': character.id,
    'npc_profiles': jsonEncode(npcs.map((npc) => npc.toJson()).toList()),
    'gamification_state':
        jsonEncode(GamificationState.initial().copyWith(coins: 20).toJson()),
  });
  final controller = AppStateController(
    store: LocalStore(),
    apiClient: client,
    memoryService: MemoryService(),
  );
  await controller.initialize();
  return controller;
}

class _FanficClient extends LlmApiClient {
  _FanficClient(this.responses);

  final List<String> responses;
  final List<String> prompts = <String>[];

  @override
  Stream<String> streamUtilityTask({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.65,
    double topP = 0.9,
    int maxTokens = 8192,
    LlmCancellationToken? cancellationToken,
  }) async* {
    final index = prompts.length;
    prompts.add(userPrompt);
    yield responses[index];
  }
}
