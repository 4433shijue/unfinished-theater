// Synthetic data only; run with flutter test. No account or provider is used.
import 'dart:convert';
import 'dart:io';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/story_workflow_test.dart' as fixtures;
import '../test/story_composer_test.dart' show options;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('write expression browser fixture', () async {
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
    await c.updateMessageContent(
        message.id, '$sample\n${fixtures.protocol}\n$options');
    await c.updateNpcMessageContent(
        'a', c.npcMessagesFor('a').last.id, '“**这枚印章**，我见过。”\n\n*他将信推回灯下。*');
    final prefs = await SharedPreferences.getInstance();
    final data = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    final output = Directory('build/story-expression-qa')
      ..createSync(recursive: true);
    File('${output.path}/seed.json').writeAsStringSync(jsonEncode(data));
    File('${output.path}/mock.json').writeAsStringSync(jsonEncode({
      'sample': sample,
      'options': options,
      'protocol': fixtures.protocol,
      'judgment': fixtures.judgment
    }));
    final controls = <String, Object>{};
    for (final skin in AppThemeVariant.values) {
      AppTheme.themeFor(skin.id);
      controls[skin.id] = {
        'hide': AppTheme.glitchText('隐藏面板'),
        'top': AppTheme.glitchText('回到顶部')
      };
    }
    File('${output.path}/skin-controls.json')
        .writeAsStringSync(jsonEncode(controls));
    File('${output.path}/themes.json')
        .writeAsStringSync(jsonEncode(controls.keys.toList()));
  });
}

const sample = '''### 灯下的一封信

阿澈接过你递来的信，指尖停在**紫色火漆**上。窗外的雨声渐密，他却没有立即拆开。

“**先别走**，*让我想一想*。”他抬眼看向门口，又压低声音：“这枚印章，我见过。”

> 纸条上只有一行字：
> “如果有人问起渡船，请先确认他的名字。”

桌旁的伙计收起账本，朝外张望。*远处传来一声短促的船笛。*

“要上楼谈吗？”阿澈将信放回灯下，等着你的回答。
''';
