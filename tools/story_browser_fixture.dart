import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
// Offline browser QA seed. Run with flutter test; never reads production data.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/story_workflow_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('write isolated synthetic browser fixture', () async {
    final c = await fixtures.fixture(fixtures.ScriptedClient());
    await c.queueUserMessage('我把信放在灯下，等他先开口。');
    await c.requestAssistantReply();
    await c.queueNpcUserMessage('a', '那封信先放在这里。');
    await c.requestNpcReply('a');
    await c.rememberStoryFact(
        text: '信还没有拆开。',
        sourceIds: [c.currentHistory.messages.last.id],
        key: 'sealed-letter');
    final prefs = await SharedPreferences.getInstance();
    final data = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    final file = File('build/story-qa/seed.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(data));
    File('build/story-qa/mock-responses.json').writeAsStringSync(jsonEncode(
        {'judgment': fixtures.judgment, 'protocol': fixtures.protocol}));
    expect(c.currentContinuity.events, hasLength(2));
  });
}
