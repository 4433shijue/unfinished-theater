import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// The recorder sees the final production request; it never stores headers.
class EvalBudget {
  EvalBudget({required this.maxRequests, required this.maxOutputTokens});
  final int maxRequests;
  final int maxOutputTokens;
  int requests = 0;
  int reservedOutputTokens = 0;
  bool exhausted = false;

  void reserve(int outputTokens) {
    if (requests >= maxRequests ||
        reservedOutputTokens + outputTokens > maxOutputTokens) {
      exhausted = true;
      throw const EvalBudgetExceeded();
    }
    requests++;
    reservedOutputTokens += outputTokens;
  }
}

class EvalBudgetExceeded implements Exception {
  const EvalBudgetExceeded();
  @override
  String toString() => 'Evaluation request/output reservation budget exhausted';
}

class EvalTransport extends http.BaseClient {
  EvalTransport({
    required this.budget,
    required this.mockReply,
    this.live = false,
    this.delegate,
    this.secret = '',
    this.allowedHost = 'example.invalid',
    this.defaultOutputCap = 8192,
    this.maxResponseBytes = 4 * 1024 * 1024,
    this.forceFirstMock = false,
    this.onRecord,
  });

  final EvalBudget budget;
  final String Function(int index, Map<String, dynamic> payload) mockReply;
  final bool live;
  final http.Client? delegate;
  final String secret;
  final String allowedHost;
  final int defaultOutputCap;
  final int maxResponseBytes;
  final bool forceFirstMock;
  final void Function()? onRecord;
  final records = <Map<String, dynamic>>[];

  String redact(String value) => secret.isEmpty
      ? value
      : value.replaceAll(secret, '[REDACTED]');

  dynamic scrub(dynamic value) {
    if (value is String) return redact(value);
    if (value is List) return value.map(scrub).toList();
    if (value is Map) {
      return {for (final e in value.entries) '${e.key}': scrub(e.value)};
    }
    return value;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is! http.Request || request.method != 'POST') {
      throw StateError('Only production POST requests are allowed');
    }
    if (request.url.host != allowedHost ||
        (live && request.url.scheme != 'https')) {
      throw StateError('Unexpected evaluation endpoint');
    }
    final payload = jsonDecode(request.body) as Map<String, dynamic>;
    final suppliedCap = payload['max_tokens'] as int?;
    final cap = suppliedCap ?? defaultOutputCap;
    if (cap <= 0) throw StateError('Output cap must be positive');
    budget.reserve(cap);
    // Some production utility calls have no cap. Bound only those requests and
    // disclose this modification; preserve existing production caps verbatim.
    if (suppliedCap == null) payload['max_tokens'] = cap;
    final index = records.length;
    final record = <String, dynamic>{
      'index': index,
      'phase': index == 0 ? 'initial' : 'additional',
      'source': !live ? 'synthetic_mock' : forceFirstMock && index == 0 ? 'fault_fixture' : 'live_model',
      'payload': scrub(payload),
      'outputCapAdded': suppliedCap == null,
      'reservedOutputTokens': cap,
      'response': '',
      'usage': null,
      'status': 'started',
    };
    records.add(record);
    onRecord?.call();
    final watch = Stopwatch()..start();
    try {
      if (!live || (forceFirstMock && index == 0)) {
        final text = mockReply(index, payload);
        record.addAll({
          'response': redact(text),
          'elapsedMs': watch.elapsedMilliseconds,
          'status': 'ok',
        });
        onRecord?.call();
        final streaming = payload['stream'] == true;
        final body = streaming
            ? 'data: ${jsonEncode({'choices': [{'delta': {'content': text}}]})}\n\ndata: [DONE]\n\n'
            : jsonEncode({'choices': [{'message': {'content': text}}]});
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200,
            headers: {'content-type': streaming ? 'text/event-stream' : 'application/json'});
      }
      // Preserve the exact production Request when its output cap already
      // exists. Rebuilding it can change transport headers in provider-specific
      // ways; only utility calls that lacked a cap need a replacement body.
      final outgoing = suppliedCap == null
          ? (http.Request('POST', request.url)
            ..headers.addAll(request.headers)
            ..body = jsonEncode(payload)
            ..followRedirects = false)
          : request;
      final response = await delegate!.send(outgoing).timeout(const Duration(minutes: 3));
      record['httpStatus'] = response.statusCode;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Do not retain provider error bodies, which can echo credentials.
        record['status'] = 'http_error';
        await response.stream.listen((_) {}).cancel();
        throw HttpException('Provider HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      int? firstByteMs;
      await for (final part in response.stream.timeout(const Duration(minutes: 3))) {
        firstByteMs ??= watch.elapsedMilliseconds;
        bytes.addAll(part);
        if (bytes.length > maxResponseBytes) {
          throw StateError('Provider response exceeded local byte limit');
        }
      }
      final raw = utf8.decode(bytes);
      final chunks = <String>[];
      if (payload['stream'] == true) {
        for (final line in const LineSplitter().convert(raw)) {
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          final decoded = jsonDecode(data) as Map<String, dynamic>;
          _extract(decoded, chunks, record, streaming: true);
        }
      } else {
        _extract(jsonDecode(raw) as Map<String, dynamic>, chunks, record,
            streaming: false);
      }
      record.addAll({
        'response': redact(chunks.join()),
        'firstByteMs': firstByteMs,
        'elapsedMs': watch.elapsedMilliseconds,
        'status': 'ok',
      });
      onRecord?.call();
      return http.StreamedResponse(Stream.value(bytes), response.statusCode,
          headers: response.headers);
    } catch (error) {
      record['status'] = record['status'] == 'http_error' ? 'http_error' : 'transport_error';
      record['errorType'] = error.runtimeType.toString();
      record['elapsedMs'] = watch.elapsedMilliseconds;
      onRecord?.call();
      rethrow;
    }
  }

  void _extract(Map<String, dynamic> data, List<String> chunks,
      Map<String, dynamic> record, {required bool streaming}) {
    if (data['usage'] is Map) record['usage'] = scrub(data['usage']);
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) return;
    final choice = choices.first as Map;
    final message = choice[streaming ? 'delta' : 'message'];
    if (message is Map && message['content'] is String) {
      chunks.add(message['content'] as String);
    }
    if (choice['finish_reason'] != null) record['finishReason'] = choice['finish_reason'];
  }

  @override
  void close() => delegate?.close();
}
