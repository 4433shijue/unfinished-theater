import 'dart:async';
import 'dart:convert';

import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('utility stream accepts SSE data lines without a space', () async {
    final body = [
      'data:${jsonEncode(<String, dynamic>{
            'choices': <Map<String, dynamic>>[
              <String, dynamic>{
                'delta': <String, dynamic>{'content': '收到'},
              },
            ],
          })}',
      'data: [DONE]',
      '',
    ].join('\n');
    final client = LlmApiClient(client: _StreamClient(body));
    addTearDown(client.close);

    final chunks = await client
        .streamContent(
          settings: _settings(),
          systemPrompt: 'system',
          userPrompt: 'user',
        )
        .toList();

    expect(chunks, <String>['收到']);
  });

  test('utility stream honors a timeout shorter than 180 seconds', () async {
    final streamController = StreamController<List<int>>();
    addTearDown(streamController.close);
    final client = LlmApiClient(
      client: _HangingStreamClient(streamController.stream),
    );
    addTearDown(client.close);

    final stopwatch = Stopwatch()..start();
    await expectLater(
      client
          .streamContent(
            settings: _settings(timeoutSeconds: 1),
            systemPrompt: 'system',
            userPrompt: 'user',
          )
          .drain<void>(),
      throwsA(
        isA<LlmApiException>().having(
          (error) => error.message,
          'message',
          contains('超时'),
        ),
      ),
    );
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });
}

AppSettings _settings({int timeoutSeconds = 60}) {
  return AppSettings.initial().copyWith(
    apiUrl: 'https://example.com',
    apiKey: 'test-key',
    modelName: 'test-model',
    requestTimeoutSeconds: timeoutSeconds,
  );
}

class _StreamClient extends http.BaseClient {
  _StreamClient(this.body);

  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: const <String, String>{'content-type': 'text/event-stream'},
    );
  }
}

class _HangingStreamClient extends http.BaseClient {
  _HangingStreamClient(this.stream);

  final Stream<List<int>> stream;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      stream,
      200,
      headers: const <String, String>{'content-type': 'text/event-stream'},
    );
  }
}
