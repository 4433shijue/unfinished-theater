import 'dart:convert';
import 'dart:io';

import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/services/html_interaction_bridge.dart';
import 'package:ai_roleplay_chat/services/runnable_html_sandbox.dart';

void main() {
  final directory = Directory('build/inline-theater-qa')
    ..createSync(recursive: true);
  final fixtures = <String, String>{};
  for (final theme in InlineTheaterTheme.values) {
    fixtures[theme.name] = RunnableHtmlSandbox.build(
        document: theme.exampleHtml,
        trustedBridgeScript: HtmlInteractionBridge.build(
            policy: HtmlInteractionPolicy.localOnly, webBridgeId: 'qa'));
  }
  const legacy =
      '<html><body><button data-action="继续等雨">旧工具行动</button><button data-extra-action="reveal" data-extra-target="reveal">揭晓</button><p id="reveal" hidden>隐藏对白</p><script>window.compromised=true</script></body></html>';
  for (final policy in HtmlInteractionPolicy.values) {
    fixtures[policy.name] = RunnableHtmlSandbox.build(
        document: legacy,
        trustedBridgeScript:
            HtmlInteractionBridge.build(policy: policy, webBridgeId: 'qa'));
  }
  fixtures['native'] = RunnableHtmlSandbox.build(
      document: InlineTheaterTheme.objects.exampleHtml,
      trustedBridgeScript:
          HtmlInteractionBridge.build(policy: HtmlInteractionPolicy.localOnly));
  File('${directory.path}/fixtures.json')
      .writeAsStringSync(jsonEncode(fixtures));
}
