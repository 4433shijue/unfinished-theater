import 'dart:convert';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/chat_export_builder.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/story_markdown_document.dart';
import 'package:ai_roleplay_chat/services/story_rewrite_service.dart';
import 'package:ai_roleplay_chat/services/story_share_card_builder.dart';
import 'package:ai_roleplay_chat/widgets/chat_message_bubble.dart';
import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:ai_roleplay_chat/theme/story_text_palette.dart';
import 'package:ai_roleplay_chat/widgets/story_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:html/parser.dart' as html_parser;
import 'story_workflow_test.dart' as fixtures;

ChatMessage message(String text,
        {ChatRole role = ChatRole.assistant, String id = 'm'}) =>
    ChatMessage(
        id: id,
        content: text,
        role: role,
        timestamp: DateTime(2026),
        isSummarized: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in ['main', 'map', 'group']) {
    test(
        '$mode request authorizes the pending turn, not an old action or suggestion',
        () async {
      late List<dynamic> sent;
      final client = LlmApiClient(client: MockClient((request) async {
        sent = jsonDecode(request.body)['messages'];
        return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '他等着你回应。'}
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      addTearDown(client.close);
      await client.sendChat(
          settings: AppSettings.initial().copyWith(
              apiUrl: 'https://example.test/v1',
              apiKey: 'fixture',
              modelName: 'test'),
          character: CharacterProfile(
              id: 'story',
              name: '灯下',
              createdAt: DateTime(2026),
              prompt: '神秘来客',
              modelParams: ModelParams.defaults(),
              mapModeEnabled: mode == 'map',
              largeGroupChatModeEnabled: mode == 'group'),
          contextMessages: [
            message('旧回合买了船票', role: ChatRole.user),
            message('他提出上船。未选路线：替他还债。'),
            message('我把信递给他。', role: ChatRole.user),
            message('先不递信，只问他认不认识寄信人。', role: ChatRole.user)
          ],
          memorySummaries: []);
      final system = sent.first['content'] as String;
      final current = sent.last['content'] as String;
      final authorization =
          current.split('【本轮实际提交｜玩家行动范围】').last.split('【本轮提交结束】').first;
      expect(system, contains('玩家决定权'));
      expect(system, contains('连续的小说自然段'));
      expect(system, isNot(contains('> **来信**')));
      expect(system, contains('即使尚未达到字数目标'));
      expect(authorization, contains('我把信递给他'));
      expect(authorization, contains('先不递信'));
      expect(authorization, isNot(contains('买了船票')));
      expect(authorization, isNot(contains('替他还债')));
      expect(current, contains('后发的明确修订优先'));
    });
  }

  test('private messages carry the same boundary without exposing another NPC',
      () async {
    final api = fixtures.ScriptedClient();
    final c = await fixtures.fixture(api);
    await c.queueNpcUserMessage('a', '把信给你看看，但先别答应任何人。');
    expect(await c.requestNpcReply('a'), isNull);
    expect(api.requests.last, contains('【玩家决定权'));
    expect(api.requests.last, contains('NPC 私聊｜纯线上聊天'));
    expect(api.requests.last, contains('不用双引号包住台词'));
    expect(api.requests.last, isNot(contains('【剧情正文的 Markdown 表现】')));
    expect(api.requests.last, contains('把信给你看看'));
  });

  test('NPC sentence normalization preserves rich text and the final sentence',
      () async {
    final api = _RichNpcClient();
    final c = await fixtures.fixture(api);
    await c.queueNpcUserMessage('a', '先别拆信。');
    expect(await c.requestNpcReply('a'), isNull);
    expect(c.npcMessagesFor('a').last.content, api.reply);
    api.reply = '第一句。第二句。第三句。第四句。第五句。第六句。';
    await c.queueNpcUserMessage('a', '接着说。');
    expect(await c.requestNpcReply('a'), isNull);
    expect(c.npcMessagesFor('a').last.content, contains('第六句。'));
  });

  for (final bg in [const Color(0xFFF3ECFA), const Color(0xFF1D102A)]) {
    test('purple speech stays purple and readable on ${bg.toARGB32()}', () {
      final palette = StoryTextPalette.resolve(
          primary: const Color(0xFFB89ADC), backgrounds: [bg], underlay: bg);
      expect(StoryTextPalette.contrast(palette.dialogue, bg),
          greaterThanOrEqualTo(4.5));
      expect(
          (HSLColor.fromColor(palette.dialogue).hue -
                  HSLColor.fromColor(const Color(0xFFB89ADC)).hue)
              .abs(),
          lessThan(2));
      expect(palette.dialogue.computeLuminance() < bg.computeLuminance(),
          bg.computeLuminance() > .35);
    });
  }
  test('a light custom bubble on a dark skin gets dark speech', () {
    AppTheme.themeFor('cthulhu');
    final palette = StoryTextPalette.resolve(backgrounds: [Colors.white]);
    expect(palette.dialogue.computeLuminance(), lessThan(.2));
    expect(StoryTextPalette.contrast(palette.dialogue, Colors.white),
        greaterThanOrEqualTo(4.5));
    AppTheme.themeFor('sakura');
  });

  test('every built-in skin keeps default speech readable', () {
    for (final skin in AppThemeVariant.values) {
      AppTheme.themeFor(skin.id);
      final surfaces =
          ChatMessageBubble.assistantBackgrounds('frame_default', null);
      final palette = StoryTextPalette.resolve(backgrounds: surfaces);
      final backdrop = StoryTextPalette.opaque(
          AppTheme.panel, skin.palette.background.first);
      final opaque =
          surfaces.map((s) => StoryTextPalette.opaque(s, backdrop)).toList();
      double worst(Color c) => opaque
          .map((s) => StoryTextPalette.contrast(c, s))
          .reduce((a, b) => a < b ? a : b);
      expect(worst(palette.dialogue), greaterThanOrEqualTo(4.5),
          reason: skin.id);
      for (final ink in [palette.body, palette.emphasis, palette.muted]) {
        expect(worst(ink), greaterThanOrEqualTo(4.5), reason: skin.id);
      }
    }
    AppTheme.themeFor('sakura');
  });

  test('vinyl story ink stays legible across the sleeve and its texture', () {
    AppTheme.themeFor('vinyl_memories');
    addTearDown(() => AppTheme.themeFor('sakura'));
    for (final frame in ['frame_default', 'frame_film_strip']) {
      final stops = ChatMessageBubble.assistantBackgrounds(frame, null);
      final ink = StoryTextPalette.resolve(backgrounds: stops);
      expect(ink.body, isNot(ink.dialogue));
      expect(ink.dialogue.r, greaterThan(ink.dialogue.b));
      for (final backdrop in [Colors.black, Colors.white]) {
        for (var i = 1; i < stops.length; i++) {
          for (final t in [0.0, .25, .5, .75, 1.0]) {
            final bg = StoryTextPalette.opaque(
                Color.lerp(stops[i - 1], stops[i], t)!, backdrop);
            for (final color in [
              ink.body,
              ink.dialogue,
              ink.emphasis,
              ink.muted
            ]) {
              expect(StoryTextPalette.contrast(color, bg),
                  greaterThanOrEqualTo(4.5),
                  reason: '$frame / $backdrop / $i / $t');
              expect(
                  color.computeLuminance(), greaterThan(bg.computeLuminance()));
            }
          }
        }
      }
    }
  });

  test('ASCII and encoded quotes export without touching inline code', () {
    final html = StoryMarkdownDocument.toHtml(
        '"Wait **here**." &quot;Yes&quot; `"code"`');
    expect(html, contains('<span class="story-dialogue">Wait '));
    expect(html, contains('<code>&quot;code&quot;</code>'));
    expect(html, contains('Yes'));
    expect(html_parser.parseFragment(html).text, 'Wait here. Yes "code"');
  });

  test('group export and share preserve speaker and styled speech', () {
    final raw = '[GROUP_CHAT]\n${jsonEncode({
          'messages': [
            {'speaker': '阿澈', 'speakerId': 'a', 'content': '“**等我**。”'},
            {'speaker': '小舟', 'speakerId': 'b', 'content': '“我去看看。”'},
          ]
        })}\n[/GROUP_CHAT]';
    final messages = [message(raw)];
    for (final html in [
      ChatExportBuilder.buildHtml(
          title: '测试', assistantName: '群聊', messages: messages),
      StoryShareCardBuilder.buildHtml(
          title: '测试',
          assistantName: '群聊',
          messages: messages,
          palette: AppTheme.activePalette,
          themeLabel: '测试'),
    ]) {
      expect(html, contains('阿澈'));
      expect(html, contains('小舟'));
      expect(html, contains('class="story-dialogue"'));
      expect(html, isNot(contains('[GROUP_CHAT]')));
    }
  });

  test('HTML dialogue spans retain nested Markdown and leave code/URLs intact',
      () {
    final rendered = StoryMarkdownDocument.toHtml(
        '他说：“**先别走**，*等一下*。”旁白。\n\n`“代码”` [链接](https://example.test/a?q=word)\n\n| 话 |\n| --- |\n| 「等我」 |');
    expect(rendered, contains('class="story-dialogue"'));
    expect(rendered, contains('<strong>'));
    expect(rendered, contains('<em>'));
    expect(rendered, contains('<code>“代码”</code>'));
    expect(rendered, contains('href="https://example.test/a?q=word"'));
    expect(rendered, contains('<table>'));
    expect(rendered, isNot(contains('<story-dialogue')));
  });

  test('rendered selection maps Markdown and entities back to the exact source',
      () {
    const raw = '他说：“**先别走**，*等一下* &amp; 看我。”';
    final targets = StoryRewriteService.targets('m', raw);
    final found = StoryRewriteService.selectedTargets(targets, '先别走，等一下 & 看我');
    expect(found, hasLength(1));
    final replaced = StoryRewriteService.replace(raw, found.single, '坐一会儿');
    expect(StoryMarkdownDocument.projection(replaced).text, '他说：坐一会儿。');
    expect(replaced, '他说：“坐一会儿。”');
    expect(replaced, isNot(contains('**')));
  });
  test('partial formatting selection preserves the unselected prefix', () {
    const raw = '**先坐下** 再说。';
    final found = StoryRewriteService.selectedTargets(
        StoryRewriteService.targets('m', raw), '坐下 再说');
    final result = StoryRewriteService.replace(raw, found.single, '听我说');
    expect(result, '**先**听我说。');
  });

  test('reading, export and selection agree across dialogue boundaries', () {
    const raw = '他问：“你认得\n**这个名字**吗？”又说：“别急。”';
    final projected = StoryMarkdownDocument.projection(raw);
    expect(projected.text, '他问：你认得\n这个名字吗？又说：别急。');
    final html = html_parser.parseFragment(StoryMarkdownDocument.toHtml(raw));
    expect(html.text, projected.text);
    expect(html.querySelectorAll('.story-dialogue').map((e) => e.text).join(),
        '你认得\n这个名字吗？别急。');
    final found = StoryRewriteService.selectedTargets(
        StoryRewriteService.targets('m', raw), '吗？又说：别');
    final next = StoryRewriteService.replace(raw, found.single, '。他等着。');
    expect(next, '他问：“你认得\n**这个名字**”。他等着。“急。”');
  });

  test('selection across a link or code keeps unselected delimiters valid', () {
    for (final raw in ['[先坐下](https://example.test) 再说。', '`先坐下` 再说。']) {
      final found = StoryRewriteService.selectedTargets(
          StoryRewriteService.targets('m', raw), '坐下 再说');
      final result = StoryRewriteService.replace(raw, found.single, '听我说');
      expect(StoryMarkdownDocument.projection(result).text, '先听我说。');
      expect(StoryMarkdownDocument.toHtml(result), isNot(contains('](')));
    }
  });
  test('duplicate visible selections remain explicit alternatives', () {
    const raw = '甲说：“**等我**。”\n\n乙说：“*等我*。”';
    final found = StoryRewriteService.selectedTargets(
        StoryRewriteService.targets('m', raw), '等我');
    expect(found, hasLength(2));
    expect(found.first.start, isNot(found.last.start));
    expect(StoryRewriteService.replace(raw, found.last, '稍等'),
        '甲说：“**等我**。”\n\n乙说：“*稍等*。”');
  });
  test('group JSON rewriting keeps speaker and sibling messages', () {
    final raw = '[GROUP_CHAT]\n${jsonEncode({
          'messages': [
            {'id': 'g1', 'speakerId': 'a', 'content': '“**等我**。”'},
            {'id': 'g2', 'speakerId': 'b', 'content': '“等我。”'}
          ]
        })}\n[/GROUP_CHAT]';
    final found = StoryRewriteService.selectedTargets(
        StoryRewriteService.targets('m', raw), '等我');
    expect(found, hasLength(2));
    final result = StoryRewriteService.replace(raw, found.first, '再坐一下');
    expect(result, contains('“**再坐一下**。”'));
    expect(result, contains('"speakerId":"b","content":"“等我。”"'));
  });
  test(
      'exports include the selected skin colors without changing stored Markdown',
      () {
    final m = message('“**等我**。”');
    final palette = StoryTextPalette.resolve(
        primary: Colors.purple, backgrounds: [Colors.white]);
    final output = ChatExportBuilder.buildHtml(
        title: '灯下', assistantName: '阿澈', messages: [m], textPalette: palette);
    expect(output, contains(palette.css['dialogue']!));
    expect(output, contains('class="story-dialogue"'));
    expect(m.content, '“**等我**。”');
  });

  testWidgets(
      'mixed dialogue, tables, lists and streaming retain all text once',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SelectionArea(
                child: StoryMarkdown(
                    data:
                        '他说：“**先别走**，*等一下*。”旁白。\n\n- 「第一句」\n- 第二句\n\n| 人 | 话 |\n| --- | --- |\n| 甲 | 『等我』 |\n\n> 信上写着：“明天见。”',
                    backgrounds: const [Colors.white])))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .join('|');
    expect('先别走'.allMatches(rich), hasLength(1));
    expect(rich, contains('第一句'));
    expect(rich, contains('他说：'));
    expect(rich, isNot(contains('“')));
    expect(rich, isNot(contains('”')));
    expect(rich, contains('旁白。'));
    expect(rich, contains('第二句'));
    expect(rich, contains('『等我』'));
    expect(rich, contains('明天见'));
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: StoryMarkdown(data: '他说：“还没说完\n下一段', isStreaming: true))));
    expect(tester.takeException(), isNull);
  });
}

class _RichNpcClient extends fixtures.ScriptedClient {
  String reply = '“**我不会擅自拆信**。”\n\n*先等你的答复。*';
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'messages': [reply]
                  })
                }
              }
            ]
          }))),
          200,
          headers: {'content-type': 'application/json'});
}
