import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_runtime.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'regeneration reads the state before the latest turn and replaces its effects',
      () async {
    final client = _Client();
    final controller = await _controller(client);
    await _twoTurns(controller);
    final target = controller.currentHistory.messages.last;
    client.replies.add(_reply(delta: 1));

    expect(await controller.regenerateAssistantMessage(target.id), isNull);

    expect(client.latestGameplayContext, contains('调查.进展 = 3'));
    expect(client.latestGameplayContext, contains('"status":"open"'));
    expect(
        client.latestGameplayContext, isNot(contains('"status":"resolved"')));
    expect(controller.currentGameState.customVariables['调查.进展'], 4);
    expect(controller.currentGameState.customVariables['行动.筹码'], 4);
    expect(controller.currentGameState.customVariables['世界.时钟'], 1);
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.open);
    expect(controller.currentGameState.gameplayRuntime.turn, 2);
    expect(controller.currentHistory.messages.last.id, target.id);
    final stored = await LocalStore().loadGameState('timeline-repair');
    expect(stored.gameplayRuntime.toJson(),
        controller.currentGameState.gameplayRuntime.toJson());
    expect(stored.customVariables['调查.进展'], 4);
  });

  test('regenerating an earlier turn replays later rules and promises once',
      () async {
    final client = _Client();
    final controller = await _controller(client);
    await _twoTurns(controller);
    final first = controller.currentHistory.messages[1];
    final last = controller.currentHistory.messages.last;
    client.replies.add(_reply(delta: 1, openId: 'new_promise'));

    expect(await controller.regenerateAssistantMessage(first.id), isNull);

    expect(client.latestGameplayContext, contains('调查.进展 = 0'));
    expect(
        client.latestGameplayContext, isNot(contains('"status":"resolved"')));
    expect(controller.currentGameState.customVariables['调查.进展'], 3);
    expect(controller.currentGameState.customVariables['行动.筹码'], 4);
    expect(
        controller.currentGameState.gameplayRuntime.lastRuleTurns['lockdown'],
        2);
    expect(controller.currentGameState.gameplayRuntime.turn, 2);
    expect(controller.currentGameState.gameplayRuntime.threads.single.id,
        'new_promise');
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.open);
    expect(
        controller.currentHistory.messages[1]
            .gameStateSnapshot!['customVariables']['调查.进展'],
        1);
    expect(controller.currentHistory.messages.last.id, last.id);
    expect(
        controller.currentHistory.messages.last
            .gameStateSnapshot!['customVariables']['调查.进展'],
        3);
  });

  test(
      'repairing an old reply keeps its snapshot and never adds its delta again',
      () async {
    final client = _Client();
    final controller = await _controller(client);
    await _twoTurns(controller);
    final first = controller.currentHistory.messages[1];
    final baseline = jsonEncode(first.gameStateSnapshot!['gameplayBaseline']);
    client.utilities.add(_reply(delta: 3, openId: 'protect'));

    expect(await controller.repairMessageFormat(first.id), isNull);

    expect(controller.currentGameState.customVariables['调查.进展'], 5);
    expect(controller.currentGameState.customVariables['行动.筹码'], 4);
    expect(controller.currentGameState.gameplayRuntime.turn, 2);
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.resolved);
    final repaired = controller.currentHistory.messages[1];
    expect(repaired.gameStateSnapshot!['customVariables']['调查.进展'], 3);
    expect(
        jsonEncode(repaired.gameStateSnapshot!['gameplayBaseline']), baseline);
    expect(repaired.promptReplayContent, contains('本轮调查结束'));
  });

  test('a corrected protocol replays the whole timeline with revised costs',
      () async {
    final client = _Client();
    final controller = await _controller(client);
    await _twoTurns(controller);
    final first = controller.currentHistory.messages[1];
    client.utilities.add(_reply(delta: 1, openId: 'protect'));

    expect(await controller.repairMessageFormat(first.id), isNull);

    expect(controller.currentGameState.customVariables['调查.进展'], 3);
    expect(controller.currentGameState.customVariables['行动.筹码'], 4);
    expect(
        controller.currentGameState.gameplayRuntime.lastRuleTurns['lockdown'],
        2);
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.resolved);
    expect(
        controller.currentHistory.messages[1]
            .gameStateSnapshot!['customVariables']['调查.进展'],
        1);
  });

  test('format repair restores omitted original state protocols', () async {
    final client = _Client();
    final controller = await _controller(client);
    await _twoTurns(controller);
    final first = controller.currentHistory.messages[1];
    client.utilities.add('正文排版已修复。\n```html\n<div>港口仍然安静。</div>\n```');

    expect(await controller.repairMessageFormat(first.id), isNull);

    expect(controller.currentGameState.customVariables['调查.进展'], 5);
    expect(controller.currentGameState.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.resolved);
    expect(controller.currentHistory.messages[1].content,
        contains('[THEATER_PATCH]'));
    expect(controller.currentHistory.messages[1].content,
        contains('[GAME_STATE]'));
  });

  test('a generated display panel cannot replay a copied gameplay protocol',
      () async {
    final client = _Client();
    final controller = await _controller(client);
    await _twoTurns(controller);
    final first = controller.currentHistory.messages[1];
    final before = jsonEncode(controller.currentGameState.toJson());
    client.utilities.add(_reply(delta: 3, openId: 'protect'));

    expect(await controller.beautifyMessageAsPanel(first.id), isNull);

    final panel = controller.currentHistory.messages.last;
    expect(panel.content, contains('<div>'));
    expect(panel.content, isNot(contains('[THEATER_PATCH]')));
    expect(panel.content, isNot(contains('[GAME_STATE]')));
    expect(panel.gameStateSnapshot, isNull);
    expect(jsonEncode(controller.currentGameState.toJson()), before);
    await controller.updateMessageContent(panel.id, '${panel.content}\n附加排版。');
    expect(controller.currentGameState.customVariables['调查.进展'], 5);
    expect(controller.currentGameState.gameplayRuntime.turn, 2);
  });
}

Future<AppStateController> _controller(_Client client) async {
  final system = _system();
  final character = CharacterProfile(
    id: 'timeline-repair',
    name: '调查剧场',
    createdAt: DateTime.utc(2026, 9, 20),
    prompt: '推进调查，尊重选择。',
    modelParams: ModelParams.defaults(),
    nextStepOptionsEnabled: false,
    gameplaySystem: system,
  );
  SharedPreferences.setMockInitialValues({
    'app_settings': jsonEncode(AppSettings.initial()
        .copyWith(
          apiUrl: 'https://example.test',
          apiKey: 'test-key',
          modelName: 'test-model',
        )
        .toJson()),
    'characters': jsonEncode([character.toJson()]),
    'selected_character_id': character.id,
    'game_state_${character.id}':
        jsonEncode(GameStateSnapshot.empty(character.id)
            .copyWith(
              timeLabel: '黄昏',
              location: '港口',
              customVariables: system.initialValues(),
            )
            .toJson()),
  });
  final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService());
  addTearDown(controller.dispose);
  await controller.initialize();
  return controller;
}

Future<void> _twoTurns(AppStateController controller) async {
  for (final text in ['调查港口并答应保护证人。', '继续调查并护送证人到安全处。']) {
    expect(await controller.queueUserMessage(text), isNull);
    expect(await controller.requestAssistantReply(), isNull);
  }
  expect(controller.currentGameState.customVariables['调查.进展'], 5);
  expect(controller.currentGameState.gameplayRuntime.threads.single.status,
      GameplayThreadStatus.resolved);
}

GameplaySystem _system() => GameplaySystem.fromJson({
      'schemaVersion': 3,
      'title': '调查与承诺',
      'summary': '行动与代价',
      'coreLoop': '调查会引来巡查。',
      'variables': [
        {
          'key': '调查.进展',
          'label': '进展',
          'group': '调查',
          'type': 'number',
          'visibility': 'public',
          'authority': 'ai',
          'initialValue': 0,
          'min': 0,
          'max': 100,
          'maxDelta': 10,
          'description': '搜查后更新进展'
        },
        {
          'key': '行动.筹码',
          'label': '筹码',
          'group': '行动',
          'type': 'number',
          'visibility': 'public',
          'authority': 'rule',
          'initialValue': 5,
          'min': 0,
          'max': 10
        },
        {
          'key': '世界.时钟',
          'label': '时钟',
          'group': '世界',
          'type': 'clock',
          'visibility': 'public',
          'authority': 'rule',
          'initialValue': 0,
          'min': 0,
          'max': 10,
          'advanceOnTimeChange': 1
        },
        {
          'key': '世界.封锁',
          'label': '封锁',
          'group': '世界',
          'type': 'boolean',
          'visibility': 'public',
          'authority': 'rule',
          'initialValue': false
        },
      ],
      'rules': [
        {
          'id': 'lockdown',
          'title': '封锁',
          'when': '进展达到3',
          'effect': '港口加派巡查',
          'visibility': 'public',
          'playerSummary': '需要寻找其他出路',
          'conditions': [
            {'path': '调查.进展', 'op': 'gte', 'value': 3}
          ],
          'costs': [
            {'path': '行动.筹码', 'amount': 1}
          ],
          'effects': [
            {'path': '世界.封锁', 'op': 'set', 'value': true}
          ]
        },
      ],
    });

String _reply({required int delta, String? openId, bool resolve = false}) => '''
本轮调查结束，证人按约抵达安全处。
```html
<div>港口的灯已经点亮。</div>
```
[GAME_STATE]
时间：夜晚
地点：港口
状态：警觉
当前任务：调查港口
人物数据：你保持清醒
关系网：暂无变化
剧情记录：搜查港口
NPC变化：无
NPC更新：无
[/GAME_STATE]
[THEATER_PATCH]
${jsonEncode({
          'ops': [
            {'op': 'inc', 'path': '调查.进展', 'value': delta, 'reason': '搜查获得进展'}
          ],
          'threads': [
            if (openId != null)
              {
                'op': 'open',
                'id': openId,
                'title': '保护证人',
                'description': '护送证人到安全处',
                'reason': '玩家明确答应保护',
                'visibility': 'public'
              },
            if (resolve)
              {'op': 'resolve', 'id': 'protect', 'reason': '证人已经抵达安全处'},
          ]
        })}
[/THEATER_PATCH]
''';

class _Client extends http.BaseClient {
  final replies = <String>[
    _reply(delta: 3, openId: 'protect'),
    _reply(delta: 2, resolve: true)
  ];
  final utilities = <String>[];
  String latestGameplayContext = '';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    final text = (payload['messages'] as List)
        .map((m) => (m as Map)['content'])
        .join('\n');
    if (payload['stream'] == true) {
      final start = text.lastIndexOf('【剧场玩法系统');
      latestGameplayContext = start == -1 ? text : text.substring(start);
      final body = replies.removeAt(0);
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
    final content = text.contains('任务：修复回复格式') || text.contains('任务：美化成互动面板')
        ? utilities.removeAt(0)
        : '{}';
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'choices': [
            {
              'message': {'content': content}
            }
          ],
        }))),
        200,
        headers: {'content-type': 'application/json'});
  }
}
