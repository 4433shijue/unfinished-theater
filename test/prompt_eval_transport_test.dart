import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../tools/prompt_eval/eval_transport.dart';

http.Request request({int? maxTokens = 8192, bool stream = false}) =>
    http.Request('POST', Uri.parse('https://example.invalid/v1/chat/completions'))
      ..headers['Authorization'] = 'Bearer do-not-save-this'
      ..body = jsonEncode({'model': 'test', 'messages': [{'role': 'user', 'content': 'hello'}], if (maxTokens != null) 'max_tokens': maxTokens, 'stream': stream});

void main() {
  test('hard total request budget blocks extra repair calls before transmission', () async {
    final budget = EvalBudget(maxRequests: 1, maxOutputTokens: 16384);
    final client = EvalTransport(budget: budget, mockReply: (_, __) => '{}');
    await client.send(request());
    await expectLater(client.send(request()), throwsA(isA<EvalBudgetExceeded>()));
    expect(client.records, hasLength(1));
    expect(budget.requests, 1);
    expect(budget.exhausted, isTrue);
  });

  test('output reservation blocks the next call even with unused provider quota', () async {
    final budget = EvalBudget(maxRequests: 10, maxOutputTokens: 8192);
    final client = EvalTransport(budget: budget, mockReply: (_, __) => 'short');
    await client.send(request());
    await expectLater(client.send(request()), throwsA(isA<EvalBudgetExceeded>()));
    expect(budget.reservedOutputTokens, 8192);
  });

  test('offline mode never invokes a supplied network client', () async {
    final client = EvalTransport(budget: EvalBudget(maxRequests: 1, maxOutputTokens: 8192),
      delegate: MockClient((_) => throw StateError('network forbidden')),
      mockReply: (_, __) => 'synthetic');
    final response = await client.send(request(stream: true));
    expect(await response.stream.bytesToString(), contains('synthetic'));
    expect(client.records.single['source'], 'synthetic_mock');
  });

  test('headers and configured credential never enter recorded JSON', () async {
    const key = 'do-not-save-this';
    final client = EvalTransport(budget: EvalBudget(maxRequests: 1, maxOutputTokens: 8192),
      secret: key, mockReply: (_, __) => 'echo $key');
    await client.send(request());
    final data = jsonEncode(client.records);
    expect(data, isNot(contains(key)));
    expect(data, isNot(contains('Authorization')));
    expect(data, contains('[REDACTED]'));
  });

  test('missing production output cap is added and disclosed', () async {
    final client = EvalTransport(budget: EvalBudget(maxRequests: 1, maxOutputTokens: 8192), mockReply: (_, __) => 'summary');
    await client.send(request(maxTokens: null));
    expect(client.records.single['outputCapAdded'], isTrue);
    expect((client.records.single['payload'] as Map)['max_tokens'], 8192);
  });

  test('live failure is recorded once without retry or retaining error body', () async {
    var calls = 0;
    final client = EvalTransport(live: true,
      budget: EvalBudget(maxRequests: 3, maxOutputTokens: 24576), mockReply: (_, __) => '',
      delegate: MockClient((_) async { calls++; return http.Response('secret provider detail', 429); }));
    await expectLater(client.send(request()), throwsException);
    expect(calls, 1);
    expect(client.records.single['status'], 'http_error');
    expect(jsonEncode(client.records), isNot(contains('secret provider detail')));
  });

  test('live SSE usage and finish reason remain separate from prose', () async {
    final client = EvalTransport(live: true,
      budget: EvalBudget(maxRequests: 1, maxOutputTokens: 8192), mockReply: (_, __) => '',
      delegate: MockClient((_) async => http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices':[{'delta':{'content':'你好'},'finish_reason':'stop'}]})}\n\ndata: ${jsonEncode({'choices':[],'usage':{'prompt_tokens':12,'completion_tokens':2}})}\n\ndata: [DONE]\n\n'), 200)));
    await client.send(request(stream: true));
    final record = client.records.single;
    expect(record['response'], '你好');
    expect(record['finishReason'], 'stop');
    expect(record['usage'], {'prompt_tokens':12,'completion_tokens':2});
  });

  test('live fault fixture is marked and does not transmit first call', () async {
    var networkCalls = 0;
    final client = EvalTransport(live: true, forceFirstMock: true,
      budget: EvalBudget(maxRequests: 2, maxOutputTokens: 16384), mockReply: (_, __) => '{',
      delegate: MockClient((_) async {networkCalls++; return http.Response(jsonEncode({'choices':[{'message':{'content':'{}'}}]}),200);}));
    await client.send(request());
    await client.send(request());
    expect(networkCalls, 1);
    expect(client.records.map((r) => r['source']), ['fault_fixture','live_model']);
  });
}
