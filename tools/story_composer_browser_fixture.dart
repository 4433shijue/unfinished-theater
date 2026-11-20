// Synthetic data only; run with flutter test. No account or provider is used.
import 'dart:convert';
import 'dart:io';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/story_workflow_test.dart' as fixtures;
import '../test/story_composer_test.dart' show options;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('write composer browser fixture', () async {
    final c = await fixtures.fixture(fixtures.ScriptedClient());
    await c.queueUserMessage('我把信放在灯下，等他先开口。');
    await c.requestAssistantReply();
    await c.queueNpcUserMessage('a', '那封信先放在这里。');
    await c.requestNpcReply('a');
    await c.updateCharacter(
        'world',
        CharacterDraft(
            name: '渡口来信',
            prompt: '古代渡口，人物各有自己的判断。',
            nextStepOptionsEnabled: true,
            inlineTheaterSettings: const InlineTheaterSettings(enabled: false),
            modelParams: ModelParams.defaults()));
    final message = c.currentHistory.messages.last;
    await c.updateMessageContent(message.id, '${message.content}\n$options');
    final prefs = await SharedPreferences.getInstance();
    final data = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    final output = Directory('build/story-composer-qa')
      ..createSync(recursive: true);
    File('${output.path}/seed.json').writeAsStringSync(jsonEncode(data));
    File('${output.path}/mock.json').writeAsStringSync(jsonEncode({
      'options': options,
      'protocol': fixtures.protocol,
      'judgment': fixtures.judgment
    }));
  });
}
