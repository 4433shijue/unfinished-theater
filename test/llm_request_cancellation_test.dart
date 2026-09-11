import 'dart:async';
import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cancel aborts a reply that is stuck before the first token', () async {
    final result = await _buildController(_CancellationPhase.firstToken);
    addTearDown(result.dispose);

    expect(await result.controller.queueUserMessage('有人吗？'), isNull);
    final reply = result.controller.requestAssistantReply();
    await result.transport.mainRequestStarted.future;

    result.controller.cancelCurrentReply();

    expect(await reply.timeout(const Duration(seconds: 2)), isNull);
    expect(await result.transport.mainRequestAborted.future, isTrue);
    expect(result.controller.isSending, isFalse);
    expect(
      result.controller.currentHistory.messages
          .where((message) => message.role == ChatRole.assistant),
      isEmpty,
    );
  });

  test('cancel keeps received story text but never commits partial state',
      () async {
    final result = await _buildController(_CancellationPhase.storyStream);
    addTearDown(result.dispose);

    expect(await result.controller.queueUserMessage('推开门。'), isNull);
    final visible = Completer<void>();
    void watchStory() {
      if (!visible.isCompleted &&
          result.controller.currentHistory.messages.any(
            (message) => message.content.contains('门后传来脚步声'),
          )) {
        visible.complete();
      }
    }

    result.controller.addListener(watchStory);
    final reply = result.controller.requestAssistantReply();
    await visible.future.timeout(const Duration(seconds: 2));

    result.controller.cancelCurrentReply();

    expect(await reply.timeout(const Duration(seconds: 2)), isNull);
    expect(await result.transport.mainRequestAborted.future, isTrue);
    final assistant = result.controller.currentHistory.messages.lastWhere(
      (message) => message.role == ChatRole.assistant,
    );
    expect(assistant.content, contains('门后传来脚步声'));
    expect(assistant.content, contains('回复已暂停'));
    expect(assistant.gameStateSnapshot, isNull);
    expect(result.controller.currentGameState.hasNarrativeState, isFalse);
  });

  test('cancel aborts the second state adjudication request', () async {
    final result = await _buildController(_CancellationPhase.adjudication);
    addTearDown(result.dispose);

    expect(await result.controller.queueUserMessage('继续。'), isNull);
    final reply = result.controller.requestAssistantReply();
    await result.transport.secondaryRequestStarted.future;

    result.controller.cancelCurrentReply();

    expect(await reply.timeout(const Duration(seconds: 2)), isNull);
    expect(await result.transport.secondaryRequestAborted.future, isTrue);
    final assistant = result.controller.currentHistory.messages.lastWhere(
      (message) => message.role == ChatRole.assistant,
    );
    expect(assistant.content, contains('走廊尽头亮起一盏灯'));
    expect(assistant.content, contains('回复已暂停'));
    expect(assistant.gameStateSnapshot, isNull);
  });

  test('cancel aborts a format repair after adjudication falls back', () async {
    final result = await _buildController(_CancellationPhase.formatRepair);
    addTearDown(result.dispose);

    expect(await result.controller.queueUserMessage('继续。'), isNull);
    final reply = result.controller.requestAssistantReply();
    await result.transport.secondaryRequestStarted.future;

    result.controller.cancelCurrentReply();

    expect(await reply.timeout(const Duration(seconds: 2)), isNull);
    expect(await result.transport.secondaryRequestAborted.future, isTrue);
    expect(result.transport.nonStreamingRequestCount, 2);
    final assistant = result.controller.currentHistory.messages.lastWhere(
      (message) => message.role == ChatRole.assistant,
    );
    expect(assistant.content, contains('回复已暂停'));
    expect(assistant.gameStateSnapshot, isNull);
  });
}

Future<
    ({
      AppStateController controller,
      _AbortableTurnClient transport,
      void Function() dispose,
    })> _buildController(_CancellationPhase phase) async {
  final character = CharacterProfile(
    id: 'cancel-character',
    name: '取消测试剧场',
    createdAt: DateTime.utc(2026, 8, 23),
    prompt: '推进一段悬疑剧情。',
    modelParams: ModelParams.defaults(),
    nextStepOptionsEnabled: false,
  );
  final settings = AppSettings.initial().copyWith(
    apiUrl: 'https://example.test',
    apiKey: 'test-key',
    modelName: 'test-model',
    requestTimeoutSeconds: 60,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_settings': jsonEncode(settings.toJson()),
    'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
    'selected_character_id': character.id,
  });

  final transport = _AbortableTurnClient(phase);
  final apiClient = LlmApiClient(client: transport);
  final controller = AppStateController(
    store: LocalStore(),
    apiClient: apiClient,
    memoryService: MemoryService(),
  );
  await controller.initialize();
  return (
    controller: controller,
    transport: transport,
    dispose: () {
      controller.dispose();
      apiClient.close();
    },
  );
}

enum _CancellationPhase { firstToken, storyStream, adjudication, formatRepair }

class _AbortableTurnClient extends http.BaseClient {
  _AbortableTurnClient(this.phase);

  final _CancellationPhase phase;
  final Completer<void> mainRequestStarted = Completer<void>();
  final Completer<bool> mainRequestAborted = Completer<bool>();
  final Completer<void> secondaryRequestStarted = Completer<void>();
  final Completer<bool> secondaryRequestAborted = Completer<bool>();
  int nonStreamingRequestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.AbortableRequest;
    final payload = jsonDecode(abortable.body) as Map<String, dynamic>;
    if (payload['stream'] == true) {
      if (!mainRequestStarted.isCompleted) {
        mainRequestStarted.complete();
      }
      if (phase == _CancellationPhase.adjudication ||
          phase == _CancellationPhase.formatRepair) {
        return _responseForContent('走廊尽头亮起一盏灯。');
      }
      return _hangingResponse(
        request: abortable,
        aborted: mainRequestAborted,
        initialContent:
            phase == _CancellationPhase.storyStream ? '门后传来脚步声。' : '',
      );
    }

    nonStreamingRequestCount += 1;
    if (phase == _CancellationPhase.formatRepair &&
        nonStreamingRequestCount == 1) {
      return _responseForContent('{}');
    }
    if (!secondaryRequestStarted.isCompleted) {
      secondaryRequestStarted.complete();
    }
    return _hangingResponse(
      request: abortable,
      aborted: secondaryRequestAborted,
    );
  }

  http.StreamedResponse _hangingResponse({
    required http.AbortableRequest request,
    required Completer<bool> aborted,
    String initialContent = '',
  }) {
    final stream = StreamController<List<int>>();
    if (initialContent.isNotEmpty) {
      stream.add(
        utf8.encode(
          'data: ${jsonEncode(<String, dynamic>{
                'choices': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'delta': <String, dynamic>{'content': initialContent},
                  },
                ],
              })}\n\n',
        ),
      );
    }
    unawaited(
      request.abortTrigger!.then((_) async {
        if (!aborted.isCompleted) {
          aborted.complete(true);
        }
        stream.addError(http.RequestAbortedException(request.url));
        await stream.close();
      }),
    );
    return http.StreamedResponse(
      stream.stream,
      200,
      headers: const <String, String>{'content-type': 'text/event-stream'},
    );
  }

  http.StreamedResponse _responseForContent(String content) {
    final event = jsonEncode(<String, dynamic>{
      'choices': <Map<String, dynamic>>[
        <String, dynamic>{
          'delta': <String, dynamic>{'content': content},
        },
      ],
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('data: $event\n\ndata: [DONE]\n\n')),
      200,
      headers: const <String, String>{'content-type': 'text/event-stream'},
    );
  }
}
