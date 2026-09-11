import 'dart:async';
import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_memory.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/world_book.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('main chat injects only matching triggered world books', () async {
    final character = _character();
    final settings = _settings();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'world_books': jsonEncode(<Map<String, dynamic>>[
        _worldBook(
          id: 'always',
          title: '常驻边界',
          content: '常驻规则内容。',
          mode: WorldBookTriggerMode.always,
        ).toJson(),
        _worldBook(
          id: 'match-keyword',
          title: '码头茶香',
          content: '码头茶香会引出掌柜。',
          mode: WorldBookTriggerMode.keyword,
          keywords: const <String>['茶香'],
          position: WorldBookInjectionPosition.rear,
        ).toJson(),
        _worldBook(
          id: 'miss-keyword',
          title: '雪山规则',
          content: '雪山才会出现的规则。',
          mode: WorldBookTriggerMode.keyword,
          keywords: const <String>['雪山'],
          position: WorldBookInjectionPosition.rear,
        ).toJson(),
        _worldBook(
          id: 'match-regex',
          title: '雨巷正则',
          content: '雨巷里的灯会闪烁。',
          mode: WorldBookTriggerMode.regex,
          regexPattern: '雨巷.*码头',
          position: WorldBookInjectionPosition.rear,
        ).toJson(),
        _worldBook(
          id: 'miss-regex',
          title: '沙漠正则',
          content: '沙漠里的风暴。',
          mode: WorldBookTriggerMode.regex,
          regexPattern: '沙漠',
          position: WorldBookInjectionPosition.rear,
        ).toJson(),
      ]),
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            _message('m1', ChatRole.user, '我在雨巷码头闻到茶香。'),
          ],
        ).toJson(),
      ),
    });

    final client = _CaptureStreamingClient();
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final error = await controller.requestAssistantReply();

    expect(error, isNull);
    final payloadText = jsonEncode(client.payload);
    expect(payloadText, contains('常驻规则内容'));
    expect(payloadText, contains('码头茶香会引出掌柜'));
    expect(payloadText, contains('雨巷里的灯会闪烁'));
    expect(payloadText, isNot(contains('雪山才会出现的规则')));
    expect(payloadText, isNot(contains('沙漠里的风暴')));
  });

  test('memory selection keeps recent and locally relevant summaries',
      () async {
    final character = _character();
    final settings = _settings().copyWith(memoryContextItems: 3);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            _message('m1', ChatRole.user, '我回到雨巷码头找掌柜确认茶香来源。'),
          ],
        ).toJson(),
      ),
      'game_state_${character.id}': jsonEncode(
        GameStateSnapshot.empty(character.id)
            .copyWith(location: '雨巷码头', mainTask: '寻找掌柜')
            .toJson(),
      ),
      'memory_${character.id}': jsonEncode(
        CharacterMemory(
          characterId: character.id,
          summaries: <CharacterMemorySummary>[
            _summary('old-related', '掌柜曾在雨巷码头留下茶香暗号。', 1),
            _summary('old-unrelated', '雪山猎人提过冰湖路线。', 2),
            _summary('recent-a', '最近你买了一把旧伞。', 3),
            _summary('recent-b', '刚才你遇见沉默的邮差。', 4),
          ],
        ).toJson(),
      ),
    });

    final client = _CaptureStreamingClient();
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final error = await controller.requestAssistantReply();

    expect(error, isNull);
    final requestMessages = client.payload['messages'] as List;
    final stablePrompt = (requestMessages.first as Map)['content'] as String;
    final dynamicPrompt = (requestMessages.last as Map)['content'] as String;
    // V2.10.2 起检查点（含记忆快照）移到请求尾部的本轮快照里，
    // 固定前缀只保留协议、人设与常驻世界资料。
    expect(stablePrompt, isNot(contains('掌柜曾在雨巷码头留下茶香暗号')));
    expect(dynamicPrompt, contains('掌柜曾在雨巷码头留下茶香暗号'));
    expect(dynamicPrompt, contains('最近你买了一把旧伞'));
    expect(dynamicPrompt, contains('刚才你遇见沉默的邮差'));
    expect(dynamicPrompt, isNot(contains('雪山猎人提过冰湖路线')));
    expect(stablePrompt, isNot(contains('雪山猎人提过冰湖路线')));
  });

  test('main chat persists prompt replay snapshots for stable prefix reuse',
      () async {
    final character = _character();
    final settings = _settings();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            _message('m1', ChatRole.user, '我在雨巷码头闻到茶香。'),
          ],
        ).toJson(),
      ),
      'game_state_${character.id}': jsonEncode(
        GameStateSnapshot.empty(character.id)
            .copyWith(location: '雨巷码头', mainTask: '寻找掌柜')
            .toJson(),
      ),
    });

    final client = _CaptureStreamingClient();
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final firstError = await controller.requestAssistantReply();
    expect(firstError, isNull);

    final firstHistory = controller.currentHistory.messages;
    final firstUser =
        firstHistory.firstWhere((item) => item.role == ChatRole.user);
    final firstAssistant =
        firstHistory.lastWhere((item) => item.role == ChatRole.assistant);
    expect(firstUser.promptReplayContent, contains('【本轮上下文快照'));
    expect(firstUser.promptReplayContent, contains('【用户本轮输入】'));
    expect(firstAssistant.promptReplayContent, contains('正文'));
    expect(firstAssistant.promptReplayContent, isNot(contains('[GAME_STATE]')));

    await controller.queueUserMessage('继续追查茶香。');
    final secondError = await controller.requestAssistantReply();
    expect(secondError, isNull);

    final secondPayloadMessages = client.payloads.last['messages'] as List;
    expect(
      secondPayloadMessages.map((item) => (item as Map)['role']),
      containsAllInOrder(<String>['system', 'user', 'assistant', 'user']),
    );
    expect(
      (secondPayloadMessages[1] as Map)['content'],
      firstUser.promptReplayContent,
    );
    expect(
      (secondPayloadMessages[2] as Map)['content'],
      firstAssistant.promptReplayContent,
    );
  });

  test('message limit rolls the epoch and keeps its next prefix byte-stable',
      () async {
    final character = _character().copyWith(
      modelParams: ModelParams.defaults().copyWith(contextLength: 4),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(_settings().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            _message('u1', ChatRole.user, '第一轮。'),
            _message('a1', ChatRole.assistant, '第一轮回复。'),
            _message('u2', ChatRole.user, '第二轮。'),
            _message('a2', ChatRole.assistant, '第二轮回复。'),
            _message('u3', ChatRole.user, '第三轮。'),
          ],
        ).toJson(),
      ),
    });

    final client = _CaptureStreamingClient();
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.requestAssistantReply(), isNull);

    final firstEpoch = controller.currentHistory.promptCacheEpoch;
    final firstPayloadMessages = client.payloads.first['messages'] as List;
    final firstStablePrefix =
        (firstPayloadMessages.first as Map)['content'] as String;
    expect(firstEpoch, isNotNull);
    expect(firstEpoch?.rolloverReason, 'message_limit');
    expect(firstEpoch?.startMessageId, 'u3');
    expect(firstEpoch?.checkpoint, contains('第一轮。'));
    expect(
      firstPayloadMessages.map((item) => (item as Map)['role']),
      <String>['system', 'user'],
    );

    await controller.queueUserMessage('第四轮。');
    expect(await controller.requestAssistantReply(), isNull);

    final secondEpoch = controller.currentHistory.promptCacheEpoch;
    final secondPayloadMessages = client.payloads.last['messages'] as List;
    final secondStablePrefix =
        (secondPayloadMessages.first as Map)['content'] as String;
    expect(secondEpoch?.id, firstEpoch?.id);
    expect(secondEpoch?.rolloverReason, 'warm_append');
    expect(secondStablePrefix, firstStablePrefix);
    expect(
      secondPayloadMessages.map((item) => (item as Map)['role']),
      <String>['system', 'user', 'assistant', 'user'],
    );
  });

  test('regenerate keeps the epoch and reuses the previous request prefix',
      () async {
    final character = _character();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(_settings().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            _message('u1', ChatRole.user, '第一轮行动。'),
          ],
        ).toJson(),
      ),
    });

    final client = _CaptureStreamingClient();
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.requestAssistantReply(), isNull);

    final firstEpoch = controller.currentHistory.promptCacheEpoch;
    expect(firstEpoch, isNotNull);
    final firstMessages = client.payloads.first['messages'] as List;

    final assistantId = controller.currentHistory.messages
        .lastWhere((message) => message.role == ChatRole.assistant)
        .id;
    expect(await controller.regenerateAssistantMessage(assistantId), isNull);

    final secondEpoch = controller.currentHistory.promptCacheEpoch;
    final secondMessages = client.payloads.last['messages'] as List;
    // 重生成不再强制换代：同一缓存阶段，且请求前缀与上一轮逐字一致，
    // 服务端可直接命中上下文缓存。
    expect(secondEpoch?.id, firstEpoch?.id);
    expect(secondEpoch?.rolloverReason, 'warm_append');
    expect(secondMessages, firstMessages);
  });

  test('edited memory summaries are re-injected within the same epoch',
      () async {
    final character = _character();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(_settings().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            _message('u1', ChatRole.user, '我回到雨巷码头。'),
          ],
        ).toJson(),
      ),
      'memory_${character.id}': jsonEncode(
        CharacterMemory(
          characterId: character.id,
          summaries: <CharacterMemorySummary>[
            _summary('mem-a', '掌柜留下的旧暗号。', 1),
          ],
        ).toJson(),
      ),
    });

    final client = _CaptureStreamingClient();
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(await controller.requestAssistantReply(), isNull);
    final epochIdBefore = controller.currentHistory.promptCacheEpoch?.id;
    expect(epochIdBefore, isNotNull);

    final editError = await controller.updateMemorySummary(
      'mem-a',
      '掌柜留下的新暗号：雨夜三声敲门。',
    );
    expect(editError, isNull);

    await controller.queueUserMessage('继续追查。');
    expect(await controller.requestAssistantReply(), isNull);

    final latestPayloadText = jsonEncode(client.payload);
    final epochIdAfter = controller.currentHistory.promptCacheEpoch?.id;
    // 编辑后的记忆在同一个缓存阶段内重新注入，无需等待换代。
    expect(epochIdAfter, epochIdBefore);
    expect(latestPayloadText, contains('掌柜留下的新暗号：雨夜三声敲门。'));
  });

  test('main chat stores assistant output tokens after stream finishes',
      () async {
    final character = _character();
    final settings = _settings().copyWith(includeStreamUsage: true);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            _message('m1', ChatRole.user, '继续调查。'),
          ],
        ).toJson(),
      ),
    });

    final client = _CaptureStreamingClient(completionTokens: 37);
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final error = await controller.requestAssistantReply();

    expect(error, isNull);
    expect(client.payload['stream_options'], <String, dynamic>{
      'include_usage': true,
    });
    final assistant = controller.currentHistory.messages
        .lastWhere((message) => message.role == ChatRole.assistant);
    expect(assistant.tokenEstimate, 37);
  });

  test('main chat leaves assistant tokens empty when stream usage is absent',
      () async {
    final character = _character();
    final settings = _settings();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(settings.toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            _message('m1', ChatRole.user, '继续调查。'),
          ],
        ).toJson(),
      ),
    });

    final client = _CaptureStreamingClient();
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: client),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final error = await controller.requestAssistantReply();

    expect(error, isNull);
    final assistant = controller.currentHistory.messages
        .lastWhere((message) => message.role == ChatRole.assistant);
    expect(assistant.tokenEstimate, isNull);
  });

  test('npc extraction skips replies without npc signals', () async {
    final character = _character();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(_settings().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            for (var i = 0; i < 3; i++) ...<ChatMessage>[
              _message('u$i', ChatRole.user, '继续观察。'),
              _message('a$i', ChatRole.assistant, '风吹过空荡的走廊，没有任何人出现。'),
            ],
          ],
        ).toJson(),
      ),
    });

    final client = _UtilityCaptureClient();
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: client,
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.debugRunNpcExtractionForTest(character.id);

    expect(client.utilityCalls, 0);
  });
}

AppSettings _settings() {
  return AppSettings.initial().copyWith(
    apiUrl: 'https://example.test',
    apiKey: 'test-key',
    modelName: 'test-model',
  );
}

CharacterProfile _character() {
  return CharacterProfile(
    id: 'char-context',
    name: '上下文测试角色',
    createdAt: DateTime(2026, 5, 25),
    prompt: '扮演一个雨巷里的说书人。',
    modelParams: ModelParams.defaults(),
  );
}

WorldBookEntry _worldBook({
  required String id,
  required String title,
  required String content,
  required WorldBookTriggerMode mode,
  List<String> keywords = const <String>[],
  String regexPattern = '',
  WorldBookInjectionPosition position = WorldBookInjectionPosition.middle,
}) {
  return WorldBookEntry(
    id: id,
    title: title,
    content: content,
    global: true,
    triggerMode: mode,
    keywords: keywords,
    regexPattern: regexPattern,
    injectionPosition: position,
    priority: 50,
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );
}

ChatMessage _message(String id, ChatRole role, String content) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    timestamp: DateTime(2026, 5, 25),
    isSummarized: false,
  );
}

CharacterMemorySummary _summary(String id, String text, int day) {
  return CharacterMemorySummary(
    id: id,
    summaryText: text,
    relatedMessageIds: const <String>[],
    timestamp: DateTime(2026, 5, day),
  );
}

class _CaptureStreamingClient extends http.BaseClient {
  _CaptureStreamingClient({this.completionTokens});

  Map<String, dynamic> payload = const <String, dynamic>{};
  final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[];
  final int? completionTokens;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var requestPayload = const <String, dynamic>{};
    if (request is http.Request) {
      requestPayload = jsonDecode(request.body) as Map<String, dynamic>;
      if (requestPayload['stream'] == true) {
        payload = requestPayload;
        payloads.add(requestPayload);
      }
    }
    if (requestPayload['stream'] != true) {
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
    final response = jsonEncode(<String, dynamic>{
      'choices': <Map<String, dynamic>>[
        <String, dynamic>{
          'delta': <String, dynamic>{'content': _validAssistantReply},
        },
      ],
    });
    final usage = completionTokens == null
        ? ''
        : 'data: ${jsonEncode(<String, dynamic>{
                'usage': <String, dynamic>{
                  'prompt_tokens': 120,
                  'completion_tokens': completionTokens,
                },
              })}\n\n';
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode('data: $response\n\n${usage}data: [DONE]\n\n'),
      ),
      200,
    );
  }
}

const String _validAssistantReply = '''
正文
```html
<html></html>
```
[GAME_STATE]
时间：夜晚
地点：雨巷码头
状态：继续调查
当前任务：寻找掌柜
人物数据：你：清醒
关系网：掌柜：待确认
剧情记录：继续调查
NPC变化：无
NPC更新：无
[/GAME_STATE]

[CHOICES]
A|继续观察
B|询问掌柜
C|检查茶香
D|回到码头
E|等待片刻
F|换个方向
[/CHOICES]
''';

class _UtilityCaptureClient extends LlmApiClient {
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
    return '{"npcs":[]}';
  }
}
