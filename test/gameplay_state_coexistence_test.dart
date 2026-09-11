import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/gameplay_system_parser.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps game state when repair returns only the gameplay patch',
      () async {
    final result = await _runSplitProtocolTurn(
      mainReply: _stateOnlyReply,
      repairReply: _patchOnlyReply,
    );

    expect(result.client.adjudicationCalls, 1);
    expect(result.client.repairCalls, 1);
    expect(result.assistant.content, contains('[GAME_STATE]'));
    expect(result.assistant.content, contains('[THEATER_PATCH]'));
    expect(result.controller.currentGameState.location, '旧楼走廊');
    expect(result.controller.currentGameState.customVariables['状态.压力'], 25);
    expect(result.controller.currentGameState.metrics, isNot(contains('压力')));
  });

  test('keeps gameplay patch when repair returns only the game state',
      () async {
    final result = await _runSplitProtocolTurn(
      mainReply: _patchOnlyReplyWithStory,
      repairReply: _stateOnlyBlock,
    );

    expect(result.client.adjudicationCalls, 1);
    expect(result.client.repairCalls, 1);
    expect(result.assistant.content, contains('[GAME_STATE]'));
    expect(result.assistant.content, contains('[THEATER_PATCH]'));
    expect(result.controller.currentGameState.location, '旧楼走廊');
    expect(result.controller.currentGameState.customVariables['状态.压力'], 25);
  });
}

Future<
    ({
      AppStateController controller,
      ChatMessage assistant,
      _SplitProtocolClient client,
    })> _runSplitProtocolTurn({
  required String mainReply,
  required String repairReply,
}) async {
  final character = _character();
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_settings': jsonEncode(_settings().toJson()),
    'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
    'selected_character_id': character.id,
  });
  final client = _SplitProtocolClient(
    mainReply: mainReply,
    repairReply: repairReply,
  );
  final controller = AppStateController(
    store: LocalStore(),
    apiClient: LlmApiClient(client: client),
    memoryService: MemoryService(),
  );
  addTearDown(controller.dispose);

  await controller.initialize();
  expect(await controller.queueUserMessage('检查走廊里的异响。'), isNull);
  expect(await controller.requestAssistantReply(), isNull);
  final assistant = controller.currentHistory.messages.lastWhere(
    (message) => message.role == ChatRole.assistant,
  );
  return (controller: controller, assistant: assistant, client: client);
}

AppSettings _settings() => AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );

CharacterProfile _character() => CharacterProfile(
      id: 'char-gameplay-state',
      name: '状态协议测试',
      createdAt: DateTime(2026, 8, 20),
      prompt: '推进旧楼调查剧情。',
      modelParams: ModelParams.defaults(),
      nextStepOptionsEnabled: false,
      gameplaySystem: GameplaySystemParser.parse('''
{
  "schemaVersion": 2,
  "title": "旧楼调查",
  "summary": "追踪调查压力与线索。",
  "coreLoop": "调查、承压、取得线索。",
  "variables": [
    {"key":"状态.压力","label":"压力","group":"状态","type":"number","visibility":"public","authority":"ai","initialValue":20,"description":"危险场面会增加压力","min":0,"max":100,"maxDelta":10},
    {"key":"调查.线索","label":"线索进度","group":"调查","type":"number","visibility":"fuzzy","authority":"ai","initialValue":0,"description":"发现证据时增长","min":0,"max":100,"maxDelta":10,"stages":[{"min":0,"label":"零散"},{"min":50,"label":"成形"}]},
    {"key":"幕后.追踪者","label":"追踪者距离","group":"幕后","type":"number","visibility":"director","authority":"ai","initialValue":80,"description":"追踪者接近时降低","min":0,"max":100,"maxDelta":10},
    {"key":"幕后.种子","label":"旧楼种子","group":"幕后","type":"number","visibility":"engine","authority":"rule","initialValue":7,"description":"固定秘密","min":0,"max":99}
  ],
  "rules": []
}
'''),
    );

const String _storyAndHtml = '''
你推开旧楼走廊的门，灯光忽然闪了两下。
```html
<div>走廊尽头传来轻响。</div>
```
''';

const String _stateOnlyBlock = '''
[GAME_STATE]
时间：深夜
地点：旧楼走廊
状态：警觉
当前任务：确认异响来源
人物数据：你：保持清醒
关系网：暂无变化
剧情记录：走廊灯光闪烁
NPC变化：无
NPC更新：无
压力：80
[/GAME_STATE]
''';

const String _patchOnlyReply = '''
[THEATER_PATCH]
{"ops":[{"op":"inc","path":"状态.压力","value":5,"reason":"走廊异响带来压迫感"}]}
[/THEATER_PATCH]
''';

const String _stateOnlyReply = '$_storyAndHtml\n$_stateOnlyBlock';
const String _patchOnlyReplyWithStory = '$_storyAndHtml\n$_patchOnlyReply';

class _SplitProtocolClient extends http.BaseClient {
  _SplitProtocolClient({
    required this.mainReply,
    required this.repairReply,
  });

  final String mainReply;
  final String repairReply;
  int adjudicationCalls = 0;
  int repairCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload = request is http.Request
        ? jsonDecode(request.body) as Map<String, dynamic>
        : const <String, dynamic>{};
    if (payload['stream'] == true) {
      final event = jsonEncode(<String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'delta': <String, dynamic>{'content': mainReply},
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

    final messages = payload['messages'];
    final systemPrompt = messages is List && messages.isNotEmpty
        ? (messages.first as Map)['content']?.toString() ?? ''
        : '';
    if (systemPrompt.contains('回合状态裁判员')) {
      adjudicationCalls += 1;
      final body = jsonEncode(<String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'message': <String, dynamic>{'content': '{}'},
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

    repairCalls += 1;
    final body = jsonEncode(<String, dynamic>{
      'choices': <Map<String, dynamic>>[
        <String, dynamic>{
          'message': <String, dynamic>{'content': repairReply},
        },
      ],
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}
