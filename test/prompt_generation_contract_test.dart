import 'dart:convert';

import 'package:ai_roleplay_chat/data/gameplay_system_prompt.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_memory.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/simulator_prompt_request.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  for (final field in _completeSimulator.keys) {
    test('simulator missing $field triggers one completion with original brief',
        () async {
      final partial = Map<String, dynamic>.from(_completeSimulator)
        ..remove(field);
      final capture = _ReplyQueue([
        jsonEncode(partial),
        jsonEncode({field: _completeSimulator[field]}),
      ]);
      final client = LlmApiClient(client: capture);
      addTearDown(client.close);

      final result = await client.generateSimulatorPrompt(
        settings: _settings(),
        request: _request(),
      );

      expect(capture.payloads, hasLength(2));
      expect(result.name, '海边电台');
      expect(result.prompt, _completeSimulator['systemPrompt']);
      expect(result.openingMessage, _completeSimulator['opening']);
      expect(result.description, _completeSimulator['description']);
      expect(capture.userPrompt(1), contains('只能通过潮汐通信'));
      expect(capture.userPrompt(1), contains('四个字段都必须是非空字符串'));
    });
  }

  for (final invalid in [42, false, <String>[], <String, dynamic>{}, '   ']) {
    test('simulator rejects non-text or blank prompt $invalid', () async {
      final malformed = {..._completeSimulator, 'systemPrompt': invalid};
      final capture = _ReplyQueue([
        jsonEncode(malformed),
        jsonEncode(_completeSimulator),
      ]);
      final client = LlmApiClient(client: capture);
      addTearDown(client.close);

      final result = await client.generateSimulatorPrompt(
        settings: _settings(),
        request: _request(),
      );

      expect(capture.payloads, hasLength(2));
      expect(result.prompt, _completeSimulator['systemPrompt']);
    });
  }

  test('simulator still incomplete after one completion fails visibly',
      () async {
    final capture = _ReplyQueue([
      '{"name":"海边电台"}',
      '{"description":"潮汐中的故事"}',
    ]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await expectLater(
      client.generateSimulatorPrompt(
          settings: _settings(), request: _request()),
      throwsA(isA<LlmApiException>().having(
        (error) => error.message,
        'message',
        contains('已自动补全一次'),
      )),
    );
    expect(capture.payloads, hasLength(2));
  });

  test('completion cannot erase valid fields with blank or wrong typed values',
      () async {
    final first = {..._completeSimulator}..remove('systemPrompt');
    final capture = _ReplyQueue([
      jsonEncode(first),
      jsonEncode({
        'name': '',
        'description': null,
        'opening': [],
        'system_prompt': _completeSimulator['systemPrompt'],
      }),
    ]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final result = await client.generateSimulatorPrompt(
      settings: _settings(),
      request: _request(),
    );
    expect(capture.payloads, hasLength(2));
    expect(result.name, '海边电台');
    expect(result.openingMessage, _completeSimulator['opening']);
    expect(result.prompt, _completeSimulator['systemPrompt']);
  });

  test('complete legacy JSON alias is accepted without a completion request',
      () async {
    final legacy = {..._completeSimulator}
      ..remove('systemPrompt')
      ..['prompt'] = _completeSimulator['systemPrompt'];
    final capture = _ReplyQueue([jsonEncode(legacy)]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final result = await client.generateSimulatorPrompt(
      settings: _settings(),
      request: _request(),
    );
    expect(capture.payloads, hasLength(1));
    expect(result.prompt, _completeSimulator['systemPrompt']);
  });

  test('incomplete legacy labels never fall back to raw text as success',
      () async {
    final capture = _ReplyQueue([
      '模拟器名称：海边电台\n\n系统提示词：只写出了半份规则。',
      '仍然无法提供开场白。',
    ]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);
    await expectLater(
      client.generateSimulatorPrompt(
          settings: _settings(), request: _request()),
      throwsA(isA<LlmApiException>()),
    );
    expect(capture.payloads, hasLength(2));
  });

  test('partial JSON repair preserves a complete original legacy result',
      () async {
    final capture = _ReplyQueue([
      '模拟器名称：海边电台\n一句话简介：潮汐通信的故事。\n开场白：你刚接班。\n系统提示词：维护世界规则。',
      '{"name":"修复只写了名字"}',
    ]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);
    final result = await client.generateSimulatorPrompt(
      settings: _settings(),
      request: _request(),
    );
    expect(capture.payloads, hasLength(2));
    expect(result.name, '海边电台');
    expect(result.prompt, contains('维护世界规则。'));
  });

  test('empty legacy label cannot borrow the next field as its value',
      () async {
    final capture = _ReplyQueue([
      '模拟器名称：\n一句话简介：潮汐通信的故事。\n开场白：你刚接班。\n系统提示词：维护世界规则。',
      '{}',
    ]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);
    await expectLater(
      client.generateSimulatorPrompt(
          settings: _settings(), request: _request()),
      throwsA(isA<LlmApiException>()),
    );
    expect(capture.payloads, hasLength(2));
  });

  test('gameplay repair receives v3 contract and original story context',
      () async {
    final draft = _gameplayDraft();
    final malformed = jsonDecode(jsonEncode(draft)) as Map<String, dynamic>;
    (malformed['variables'] as List).first['authority'] = 'unknown';
    final capture = _ReplyQueue([jsonEncode(malformed), jsonEncode(draft)]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final result = await client.generateGameplaySystem(
      settings: _settings(),
      character: _character(),
    );

    expect(capture.payloads, hasLength(2));
    expect(result.schemaVersion, 3);
    expect(result.variables, hasLength(4));
    expect(result.rules, hasLength(2));
    expect(capture.systemPrompt(1), contains(gameplaySystemGeneratorPrompt));
    expect(capture.systemPrompt(1), contains('不得通过降低 schemaVersion'));
    expect(capture.userPrompt(1), contains('潮汐通信'));
    expect(capture.userPrompt(1), contains('authority'));
    expect(capture.userPrompt(1), contains('unknown'));
    for (final payload in capture.payloads) {
      expect(payload.containsKey('response_format'), isFalse);
    }
  });

  test('gameplay invalid repair fails after one repair request', () async {
    final capture = _ReplyQueue(['{}', '{}']);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);
    await expectLater(
      client.generateGameplaySystem(
        settings: _settings(),
        character: _character(),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(capture.payloads, hasLength(2));
  });

  for (final mode in [
    'ordinary',
    'ordinary_no_choices',
    'tutorial',
    'tutorial_no_choices',
    'map',
    'group',
  ]) {
    test('$mode composed request and repair retain compatible output contracts',
        () async {
      final capture = _ReplyQueue(['场景正文', '修复后的场景正文']);
      final client = LlmApiClient(client: capture);
      addTearDown(client.close);
      final character = _character().copyWith(
        presetId: mode.startsWith('tutorial') ? 'tutorial_demo' : null,
        mapModeEnabled: mode == 'map',
        largeGroupChatModeEnabled: mode == 'group',
        nextStepOptionsEnabled: !mode.endsWith('no_choices'),
      );
      await client.streamChat(
        settings: _settings(),
        character: character,
        contextMessages: [
          ChatMessage(
            id: 'player-turn',
            role: ChatRole.user,
            content: '我检查电台。',
            timestamp: DateTime(2026, 9, 20),
            isSummarized: false,
          ),
        ],
        memorySummaries: const <CharacterMemorySummary>[],
      ).drain<void>();
      await client.repairChatReplyFormat(
        settings: _settings(),
        character: character,
        originalReply: '潮汐变了，电台仍未发出信号。',
        latestUserMessage: '我检查电台。',
      );

      expect(capture.payloads, hasLength(2));
      for (var i = 0; i < 2; i++) {
        final prompt = capture.systemPrompt(i);
        expect(prompt, contains('[GAME_STATE]'));
        if (mode == 'map') {
          expect(prompt, contains('[MAP_STATE]'));
          expect(prompt, contains('activeChoices'));
          expect(prompt, isNot(contains('正好 A-F 六个')));
          expect(prompt, isNot(contains('A|行动文本 到 F|行动文本')));
          expect(prompt, isNot(contains('HTML：至少一个')));
          expect(prompt, isNot(contains('至少有一个完整 ```html')));
        } else if (mode == 'group') {
          expect(prompt, contains('[GROUP_CHAT]'));
          expect(prompt, contains('speakerId'));
          expect(prompt, contains('replyTo'));
          expect(prompt, contains('npcId'));
          expect(prompt, contains('好感变化'));
          expect(prompt, contains('独立调度'));
          expect(prompt, isNot(contains('频率保持为每 2-3 轮自然触发一次')));
          expect(prompt, isNot(contains('名字｜简介：...｜好感度：...')));
          expect(prompt, isNot(contains('至少有一个完整 ```html')));
        } else if (mode.endsWith('no_choices')) {
          expect(prompt, isNot(contains('最后必须输出一个 [CHOICES]')));
          expect(prompt, isNot(contains('最后必须输出一个且只能输出一个 [CHOICES]')));
          expect(prompt, isNot(contains('[CHOICES] 必须且只能包含')));
        } else if (mode == 'tutorial') {
          expect(prompt, isNot(contains('正好 A-F 六个')));
          expect(prompt, isNot(contains('A|行动文本 到 F|行动文本')));
        } else {
          expect(prompt, contains('[CHOICES]'));
          expect(prompt, contains('```html'));
        }
      }
    });
  }
}

const _completeSimulator = <String, dynamic>{
  'name': '海边电台',
  'description': '潮汐通信中的故事。',
  'opening': '你刚接班，桌上的收音机响了。你打算先问谁？',
  'systemPrompt': '维护海边电台的世界规则，尊重玩家选择。',
};

SimulatorPromptGenerationRequest _request() => SimulatorPromptGenerationRequest(
      roleName: '海边电台',
      simulatorIdea: '海边的人只能通过潮汐通信。',
    );

AppSettings _settings() => AppSettings.initial().copyWith(
      apiUrl: 'https://example.test',
      apiKey: 'test-key',
      modelName: 'test-model',
    );

CharacterProfile _character() => CharacterProfile(
      id: 'prompt-contract',
      name: '海边电台',
      createdAt: DateTime(2026, 9, 20),
      prompt: '住在海边的人只能通过潮汐通信。',
      modelParams: ModelParams.defaults(),
    );

Map<String, dynamic> _gameplayDraft() => {
      'schemaVersion': 3,
      'title': '潮汐通信',
      'summary': '趁潮水合适时把消息送出去。',
      'coreLoop': '收集信号，消耗电量，选择通信时机。',
      'variables': [
        for (var index = 0; index < 4; index++)
          {
            'key': 'radio.signal$index',
            'label': '信号$index',
            'group': '电台',
            'type': 'number',
            'visibility': 'public',
            'authority': 'ai',
            'initialValue': 20,
            'description': '行动改变信号状态。',
            'playerHint': '检查设备，选择发送时机。',
            'min': 0,
            'max': 100,
            'maxDelta': 8,
          },
      ],
      'rules': [
        for (var index = 0; index < 2; index++)
          {
            'id': 'send_signal_$index',
            'title': '传出信号$index',
            'when': '信号足够强时尝试发送。',
            'effect': '电台收到一条可供后续回应的确认。',
            'visibility': 'public',
            'conditions': [
              {'path': 'radio.signal$index', 'op': 'gte', 'value': 80}
            ],
            'effects': [
              {'path': 'radio.signal$index', 'op': 'inc', 'value': -10}
            ],
            'once': true,
            'playerSummary': '电台发出了信号。',
          }
      ],
    };

class _ReplyQueue extends http.BaseClient {
  _ReplyQueue(this.replies);

  final List<String> replies;
  final payloads = <Map<String, dynamic>>[];

  String systemPrompt(int request) =>
      (payloads[request]['messages'] as List).first['content'] as String;

  String userPrompt(int request) =>
      (payloads[request]['messages'] as List).last['content'] as String;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    payloads.add(payload);
    if (payloads.length > replies.length) {
      throw StateError('Unexpected extra AI request');
    }
    final content = replies[payloads.length - 1];
    final streaming = payload['stream'] == true;
    final body = streaming
        ? 'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': content}
                  }
                ]
              })}\n\ndata: [DONE]\n\n'
        : jsonEncode({
            'choices': [
              {
                'message': {'content': content}
              }
            ]
          });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {
        'content-type': streaming ? 'text/event-stream' : 'application/json',
      },
    );
  }
}
