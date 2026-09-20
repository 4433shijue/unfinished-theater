import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/data/gameplay_system_prompt.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_runtime.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/gameplay_prompt_context.dart';
import 'package:ai_roleplay_chat/services/gameplay_system_parser.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/services/turn_state_adjudicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('turn effects and promises survive reload, rewind and branching',
      () async {
    final controller = await _controller();
    await _turn(controller, '公开搜查，并答应保护证人。');
    final firstMessage = controller.currentHistory.messages.last;
    final firstState = controller.currentGameState;
    expect(firstState.customVariables['调查.风险'], 2);
    expect(firstState.customVariables['行动.筹码'], 2);
    expect(firstState.customVariables['世界.时钟'], 1);
    expect(firstState.customVariables['世界.封锁'], true);
    expect(firstState.gameplayRuntime.lastRuleTurns['lockdown'], 1);
    expect(firstState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.open);
    expect(firstMessage.gameStateSnapshot?['gameplaySystem'], isNotNull);
    expect(firstState.gameplayPlayerVariableChanges.join(), contains('封锁'));

    await _turn(controller, '把证人送到安全处，兑现承诺。');
    final secondMessage = controller.currentHistory.messages.last;
    expect(controller.currentGameState.customVariables['行动.筹码'], 2);
    expect(controller.currentGameState.customVariables['世界.时钟'], 1);
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.resolved);
    final stored = await LocalStore().loadGameState('gameplay-integration');
    expect(stored.gameplayRuntime.toJson(),
        controller.currentGameState.gameplayRuntime.toJson());
    expect(GameplayPromptContext.narrative(system: _system(), state: stored),
        contains('保护证人'));

    await controller.deleteMessage(secondMessage.id);
    expect(controller.currentGameState.customVariables['行动.筹码'], 2);
    expect(controller.currentGameState.customVariables['世界.时钟'], 1);
    expect(
        controller.currentGameState.gameplayRuntime.lastRuleTurns['lockdown'],
        1);
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.open);
    expect(
        await controller.createStoryBranchFromMessage(
            messageId: firstMessage.id, branchName: '另一种选择'),
        isNull);
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.open);
    expect(controller.currentGameState.customVariables['行动.筹码'], 2);
    expect(controller.currentGameState.customVariables['世界.时钟'], 1);
  });

  test(
      'deleting the first settled turn keeps the original baseline, not its effects',
      () async {
    final controller = await _controller();
    await _turn(controller, '公开搜查，并答应保护证人。');
    final firstId = controller.currentHistory.messages.last.id;
    await _turn(controller, '把证人送到安全处，兑现承诺。');
    await controller.deleteMessage(firstId);
    expect(controller.currentGameState.customVariables['调查.风险'], 0);
    expect(controller.currentGameState.customVariables['行动.筹码'], 3);
    expect(controller.currentGameState.customVariables['世界.封锁'], false);
    expect(controller.currentGameState.customVariables['世界.时钟'], 1);
    expect(controller.currentGameState.gameplayRuntime.threads, isEmpty);
  });

  test(
      'preview does not save, applying migrates progress and protects old rules',
      () async {
    final controller = await _controller();
    await _turn(controller, '公开搜查，并答应保护证人。');
    final first = controller.currentHistory.messages.last;
    final before = jsonEncode(controller.currentGameState.toJson());
    final preview =
        await controller.previewGameplaySystem('gameplay-integration');
    expect(preview.title, '新草案');
    expect(jsonEncode(controller.currentGameState.toJson()), before);
    expect(controller.currentCharacter!.gameplaySystem!.title, '调查与承诺');
    await controller.applyGameplaySystem('gameplay-integration', preview);
    expect(controller.currentCharacter!.gameplaySystem!.title, '新草案');
    expect(controller.currentGameState.customVariables['调查.风险'], 2);
    expect(controller.currentGameState.customVariables['行动.筹码'], 2);
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.open);
    expect(controller.currentGameState.gameplayRuntime.lastRuleTurns, isEmpty);
    expect(controller.recoverableSaveSnapshots, isNotEmpty);
    final storedCharacters = await LocalStore().loadCharacters();
    expect(
        storedCharacters
            .firstWhere((c) => c.id == 'gameplay-integration')
            .gameplaySystem!
            .title,
        '新草案');
    await controller.createStoryBranchFromMessage(
        messageId: first.id, branchName: '旧规则分支');
    expect(controller.currentCharacter!.gameplaySystem!.title, '调查与承诺');
    expect(
        controller.currentGameState.gameplayRuntime.lastRuleTurns['lockdown'],
        1);
  });

  test('all AI contexts exclude engine values and retain adjudication hints',
      () {
    final system = _system();
    final state = GameStateSnapshot.empty('gameplay-integration').copyWith(
      customVariables: system.initialValues(),
      gameplayRuntime: const GameplayRuntimeState(events: [
        GameplayRuntimeEvent(
            id: 'secret',
            title: '底层密钥',
            description: 'engine-event-secret',
            visibility: GameplayVariableVisibility.engine),
      ]),
    );
    final restored = GameStateSnapshot.fromJson(state.toJson());
    final narrative =
        GameplayPromptContext.narrative(system: system, state: restored);
    final adjudication = TurnStateAdjudicator.buildUserPrompt(
      character: _character(system),
      previousState: restored,
      npcProfiles: const [],
      latestUserMessage: '继续',
      narrativeReply: '你仍在等候。',
    );
    for (final context in [narrative, adjudication]) {
      expect(context, isNot(contains('777709')));
      expect(context, isNot(contains('engine-event-secret')));
      expect(context, contains('公开调查增加风险'));
    }
  });
}

Future<AppStateController> _controller() async {
  final system = _system();
  final character = _character(system);
  SharedPreferences.setMockInitialValues({
    'app_settings': jsonEncode(AppSettings.initial()
        .copyWith(
            apiUrl: 'https://example.test',
            apiKey: 'test-key',
            modelName: 'test-model')
        .toJson()),
    'characters': jsonEncode([character.toJson()]),
    'selected_character_id': character.id,
    'game_state_${character.id}': jsonEncode(
        GameStateSnapshot.empty(character.id)
            .copyWith(
                timeLabel: '黄昏',
                location: '城门',
                customVariables: system.initialValues())
            .toJson()),
  });
  final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: _Client()),
      memoryService: MemoryService());
  addTearDown(controller.dispose);
  await controller.initialize();
  return controller;
}

Future<void> _turn(AppStateController controller, String text) async {
  expect(await controller.queueUserMessage(text), isNull);
  expect(await controller.requestAssistantReply(), isNull);
}

CharacterProfile _character(GameplaySystem system) => CharacterProfile(
      id: 'gameplay-integration',
      name: '调查剧场',
      createdAt: DateTime.utc(2026, 9, 20),
      prompt: '推进调查并尊重选择。',
      modelParams: ModelParams.defaults(),
      nextStepOptionsEnabled: false,
      gameplaySystem: system,
    );

GameplaySystem _system({bool revised = false}) =>
    GameplaySystemParser.parse(jsonEncode({
      'schemaVersion': 3,
      'title': revised ? '新草案' : '调查与承诺',
      'summary': '权衡调查和暴露',
      'coreLoop': '调查带来进展，也需要付出代价。',
      'variables': [
        {
          'key': '调查.风险',
          'label': '风险',
          'group': '调查',
          'type': 'number',
          'visibility': 'public',
          'authority': 'ai',
          'initialValue': revised ? 6 : 0,
          'description': '公开调查增加风险',
          'playerHint': '公开行动会提高风险',
          'min': 0,
          'max': 10,
          'maxDelta': 2,
          'isCore': true
        },
        {
          'key': '行动.筹码',
          'label': '筹码',
          'group': '行动',
          'type': 'number',
          'visibility': 'public',
          'authority': 'rule',
          'initialValue': 3,
          'description': '规则行动消耗筹码',
          'min': 0,
          'max': 5
        },
        {
          'key': '世界.时钟',
          'label': '时钟',
          'group': '世界',
          'type': 'clock',
          'visibility': 'public',
          'authority': 'rule',
          'initialValue': 0,
          'description': '时间推进一次前进一格',
          'min': 0,
          'max': 6,
          'advanceOnTimeChange': 1
        },
        {
          'key': '世界.封锁',
          'label': '封锁',
          'group': '世界',
          'type': 'boolean',
          'visibility': 'public',
          'authority': 'rule',
          'initialValue': false,
          'description': '路线是否已封锁'
        },
        {
          'key': '引擎.秘密',
          'label': '内部秘密',
          'group': '引擎',
          'type': 'number',
          'visibility': 'engine',
          'authority': 'rule',
          'initialValue': 777709,
          'description': '不能暴露的原始值',
          'min': 0,
          'max': 999999
        },
      ],
      'rules': [
        {
          'id': 'lockdown',
          'title': '封锁',
          'when': '风险达到2',
          'effect': '路线已封锁，后续需要寻找其他出路',
          'visibility': 'public',
          'playerSummary': '城门关闭，可以寻找新的出路',
          'once': true,
          'conditions': [
            {'path': '调查.风险', 'op': 'gte', 'value': 2}
          ],
          'costs': [
            {'path': '行动.筹码', 'amount': revised ? 2 : 1}
          ],
          'effects': [
            {'path': '世界.封锁', 'op': 'set', 'value': true}
          ],
        },
      ],
    }));

class _Client extends http.BaseClient {
  int turns = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    if (payload['stream'] == true) {
      turns++;
      final patch = turns == 1
          ? {
              'ops': [
                {'op': 'inc', 'path': '调查.风险', 'value': 8, 'reason': '公开搜查'}
              ],
              'threads': [
                {
                  'op': 'open',
                  'id': 'protect',
                  'title': '保护证人',
                  'description': '将证人送到安全处',
                  'reason': '你明确答应保护证人',
                  'visibility': 'public'
                }
              ]
            }
          : {
              'ops': [],
              'threads': [
                {'op': 'resolve', 'id': 'protect', 'reason': '证人已经安全抵达避难所'}
              ]
            };
      final body = '''
${turns == 1 ? '你公开搜查，并答应将证人送到安全处。' : '你把证人送到避难所，兑现了保护他的承诺。'}
```html
<div>城门口的灯已经点亮。</div>
```
[GAME_STATE]
时间：夜晚
地点：城门
状态：警觉
当前任务：调查封锁
人物数据：你保持清醒
关系网：暂无变化
剧情记录：证人得到帮助
NPC变化：无
NPC更新：无
[/GAME_STATE]
[THEATER_PATCH]
${jsonEncode(patch)}
[/THEATER_PATCH]
''';
      final event = jsonEncode({
        'choices': [
          {
            'delta': {'content': body}
          }
        ]
      });
      return http.StreamedResponse(
          Stream.value(utf8.encode('data: $event\n\ndata: [DONE]\n\n')), 200,
          headers: {'content-type': 'text/event-stream'});
    }
    final system =
        ((payload['messages'] as List).first as Map)['content'].toString();
    final content = system == gameplaySystemGeneratorPrompt
        ? jsonEncode(_system(revised: true).toJson())
        : '{}';
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'choices': [
            {
              'message': {'content': content}
            }
          ]
        }))),
        200,
        headers: {'content-type': 'application/json'});
  }
}
