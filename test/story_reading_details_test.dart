import 'package:ai_roleplay_chat/services/story_markdown_document.dart';
import 'package:ai_roleplay_chat/widgets/story_anchored_list.dart';
import 'package:ai_roleplay_chat/widgets/story_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;

void main() {
  test('old labelled quotations remain ordinary Markdown with their full text',
      () {
    for (final label in ['来信', '纸条', '短信', '广播']) {
      final src = '> **$label**\n> 第一行\n>\n> 第二行';
      final quote = html
          .parseFragment(StoryMarkdownDocument.toHtml(src))
          .querySelector('blockquote')!;
      expect(quote.classes, isEmpty);
      expect(quote.text, contains(label));
      expect(quote.text, contains('第二行'));
    }
    expect(
        html
            .parseFragment(StoryMarkdownDocument.toHtml('雨停。\n\n---\n\n天亮。'))
            .querySelectorAll('.story-break'),
        hasLength(1));
    expect(StoryMarkdownDocument.endsInSpokenParagraph('门响了。\n\n“**谁？**”'),
        isTrue);
    expect(StoryMarkdownDocument.endsInSpokenParagraph('“谁？”他等着。'), isFalse);
  });
  test('copy uses offsets and includes only complete dialogue delimiters', () {
    const src = '回信。“**回信**。”又写：“回信。”';
    final r =
        StoryMarkdownDocument.copyRun(StoryMarkdownDocument.nodes(src).single);
    expect(r.slice(0, 3), '回信。');
    expect(r.slice(3, 6), '“回信。”');
    expect(r.slice(3, 5), '回信');
    expect(r.slice(0, r.visible.length), '回信。“回信。”又写：“回信。”');
    expect(StoryMarkdownDocument.plainText('他说：\n\n> **来信**\n> “**明晚**。”'),
        '他说：\n\n来信\n“明晚。”');
  });
  testWidgets(
      'completed paragraphs remain mounted during streaming and interruption',
      (t) async {
    Widget page(String tail, bool live) => MaterialApp(
        home: Scaffold(
            body: StorySelectionArea(
                child: StoryMarkdown(
                    data: '“守在这里。”\n\n$tail', isStreaming: live))));
    await t.pumpWidget(page('> **来', true));
    final first = t.element(find.byType(StoryReadingParagraph).first);
    for (final s in ['> **来信**', '> **来信**\n> “等', '> **来信**\n> “等我。”']) {
      await t.pumpWidget(page(s, true));
      expect(t.element(find.byType(StoryReadingParagraph).first), same(first));
    }
    await t.pumpWidget(page('> **来信**\n> “等我。”', false));
    expect(find.textContaining('等我。', findRichText: true), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('native copy keeps repeated speech and paragraph boundaries',
      (t) async {
    String? clipboard;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = call.arguments['text'] as String;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    String? actual;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StorySelectionArea(
                onChanged: (s) => actual = s,
                child: const StoryMarkdown(data: '回信。\n\n“**回信**。”')))));
    await t.pumpAndSettle();
    t
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await t.pump();
    expect(actual, '回信。回信。');
    Actions.invoke(t.element(find.byType(StoryReadingParagraph).first),
        CopySelectionTextIntent.copy);
    await t.pump();
    expect(clipboard, '回信。\n\n“回信。”');
  });
  testWidgets(
      'return cue matches a single unchanged paragraph and clears on scroll',
      (t) async {
    final ctrl = ScrollController();
    bool active = true;
    String first = '靠岸';
    bool duplicate = false;
    Widget view() => MaterialApp(
        home: Scaffold(
            body: StoryAnchoredList(
                controller: ctrl,
                ids: const ['m1', 'm2'],
                scopeKey: 'world',
                savedPosition: const {'messageId': 'm1'},
                readingActive: active,
                onPosition: (_, __, ___) {},
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Column(children: [
                      for (final s in [
                        i == 0 ? first : '下一回合',
                        duplicate ? first : '信封',
                        '灯灭'
                      ])
                        StoryReadingParagraph(
                            text: s,
                            child: SizedBox(height: 230, child: Text(s))),
                    ]))));
    Future<void> draw() async {
      await t.pumpWidget(view());
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
    }

    final cue = find.byKey(const ValueKey('story-return-cue'));
    await draw();
    active = false;
    await draw();
    active = true;
    await draw();
    expect(cue, findsOneWidget);
    ctrl.jumpTo(60);
    await t.pump();
    expect(cue, findsNothing);
    active = false;
    await draw();
    first = '改写后';
    active = true;
    await draw();
    expect(cue, findsNothing);
    duplicate = true;
    await draw();
    active = false;
    await draw();
    active = true;
    await draw();
    expect(cue, findsNothing);
    await t.pumpWidget(const SizedBox());
    ctrl.dispose();
  });
}
