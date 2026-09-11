import 'package:ai_roleplay_chat/utils/api_endpoint_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts HTTPS and normalizes the chat endpoint', () {
    expect(
      ApiEndpointResolver.chatCompletions('https://api.example.com/v1'),
      Uri.parse('https://api.example.com/v1/chat/completions'),
    );
  });

  test('blocks remote cleartext HTTP unless explicitly allowed', () {
    expect(
      () => ApiEndpointResolver.chatCompletions('http://api.example.com/v1'),
      throwsA(isA<FormatException>()),
    );
    expect(
      ApiEndpointResolver.chatCompletions(
        'http://api.example.com/v1',
        allowInsecureHttp: true,
      ),
      Uri.parse('http://api.example.com/v1/chat/completions'),
    );
  });

  test('allows loopback HTTP without weakening remote endpoints', () {
    expect(
      ApiEndpointResolver.chatCompletions('http://127.0.0.1:11434'),
      Uri.parse('http://127.0.0.1:11434/v1/chat/completions'),
    );
    expect(
      ApiEndpointResolver.models('http://localhost:11434/v1'),
      Uri.parse('http://localhost:11434/v1/models'),
    );
  });

  test('rejects unsupported schemes and URL credentials', () {
    expect(
      () => ApiEndpointResolver.chatCompletions('ftp://api.example.com'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ApiEndpointResolver.chatCompletions(
        'https://user:password@api.example.com',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
