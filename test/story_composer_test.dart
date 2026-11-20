import 'dart:async';
import 'dart:convert';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/story_composer.dart';
import 'package:ai_roleplay_chat/models/story_continuity.dart';
import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/services/choice_strategy.dart';
import 'package:ai_roleplay_chat/services/message_content_parser.dart';
import 'package:ai_roleplay_chat/services/chat_export_builder.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/widgets/chat_input_bar.dart';
import 'package:ai_roleplay_chat/widgets/story_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'story_workflow_test.dart' as fixtures;

const options =
    '[CHOICES]\nA|递上路引，办理进城手续。\nB|陪被拒之门外的旅人寻找今晚住处。\nC|记录盘查规律，追查突然封城的原因。\nD|公开要求负责人解释城门收费。\nE|在城外摆摊代写申诉，收集过客见闻。\nF|向守卫申请担任门口石狮子的替班，摆好姿势等他安排值守。\n[/CHOICES]';

class ComposerClient extends fixtures.ScriptedClient {
  String response = options;
  Completer<void>? hold;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload = jsonDecode((request as http.Request).body) as Map;
    final text =
        (payload['messages'] as List).map((m) => m['content']).join('\n');
    if (!text.contains('只生成下一步选项') && !text.contains('把玩家已经写出的意图')) {
      return super.send(request);
    }
    requests.add(text);
    if (hold != null) {
      await hold!.future;
    }
    final content = text.contains('把玩家已经写出的意图')
        ? jsonEncode({
            'suggestions': ['外面还在下雨，再坐一会儿好吗？', '我给他的杯子添了水，轻声请他留下。']
          })
        : response;
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'choices': [
            {
              'message': {'content': content}
            }
          ]
        }))),
        200,
        headers: {'content-type': 'application/json'});
  }
}

Future<void> openChoiceWorld(AppStateController c) async {
  await c.createCharacter(CharacterDraft(
      name: '城门',
      prompt: '古代城门，没有超能力。',
      openingMessage: '门口有一对石狮子。守卫拦住了你。\n${fixtures.protocol}\n$options',
      nextStepOptionsEnabled: true,
      inlineTheaterSettings: const InlineTheaterSettings(enabled: false),
      modelParams: ModelParams.defaults()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('quote fingerprints use the portable FNV reference', () {
    expect(StoryQuote.digest('hello'), '5:4f9f2cab');
    expect(StoryQuote.digest(''), '0:811c9dc5');
  });
  test(
      'choice contract rejects duplicate labels despite punctuation and numbering',
      () {
    final parsed = MessageContentParser.parseStructured(options).choices;
    expect(ChoiceStrategy.issues(parsed), isEmpty);
    expect(
        ChoiceStrategy.issues([
          parsed.first,
          ...parsed.skip(1).take(4),
          const MessageChoice(index: 'F', label: '递上路引 办理进城手续！')
        ]),
        contains('选项有空白或明显重复'));
    expect(ChoiceStrategy.issues(parsed.take(5).toList()), isNotEmpty);
  });
  test('shared strategy stays out of tutorial, map, group and disabled choices',
      () {
    final c = CharacterProfile(
        id: 'w',
        name: '剧本',
        prompt: '剧情',
        createdAt: fixtures.date,
        modelParams: ModelParams.defaults());
    expect(c.fullSystemPrompt, contains('世界内极限荒诞'));
    for (final alternate in [
      c.copyWith(mapModeEnabled: true),
      c.copyWith(largeGroupChatModeEnabled: true),
      c.copyWith(presetId: 'tutorial_demo'),
      c.copyWith(nextStepOptionsEnabled: false)
    ]) {
      expect(alternate.fullSystemPrompt, isNot(contains('世界内极限荒诞')));
    }
  });
  test('choice replacement preserves narrative, provider replay and settlement',
      () async {
    final api = ComposerClient();
    final c = await fixtures.fixture(api);
    await openChoiceWorld(c);
    final before = c.currentHistory.messages.last;
    final state = jsonEncode(c.currentGameState.toJson());
    final npcs = jsonEncode(c.npcProfiles.map((n) => n.toJson()).toList());
    await c.refreshChoices(before.id);
    final after = c.currentHistory.messages.last;
    expect(after.content, before.content);
    expect(after.providerReplayContent, before.providerReplayContent);
    expect(after.gameStateSnapshot, before.gameStateSnapshot);
    expect(jsonEncode(c.currentGameState.toJson()), state);
    expect(jsonEncode(c.npcProfiles.map((n) => n.toJson()).toList()), npcs);
    expect(after.choiceOverride, options);
    expect(api.requests, hasLength(1));
    expect(api.requests.single, isNot(contains('后台密令884')));
  });
  test('invalid and stale option replacements retain the original', () async {
    final api = ComposerClient()
      ..response = '[CHOICES]\nA|重复\nB|重复\n[/CHOICES]';
    final c = await fixtures.fixture(api);
    await openChoiceWorld(c);
    final message = c.currentHistory.messages.last;
    await expectLater(c.refreshChoices(message.id), throwsFormatException);
    expect(c.currentHistory.messages.last.choiceOverride, isNull);
    api.response = options;
    api.hold = Completer<void>();
    final request = c.refreshChoices(message.id);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.canRefreshChoices(message), isFalse);
    await c.selectCharacter('world');
    api.hold!.complete();
    await expectLater(request, throwsStateError);
    expect(c.choicesRefreshing, isFalse);
  });
  test('effective choices and quotes survive JSON and HTML export', () {
    const quote = StoryQuote(
        worldId: 'w',
        messageId: 'source',
        text: '<他问你是否留下>',
        sourceDigest: 'digest');
    final user = ChatMessage(
        id: 'u',
        role: ChatRole.user,
        content: '留下。',
        quote: quote,
        timestamp: fixtures.date,
        isSummarized: false);
    final message = ChatMessage(
        id: 'm',
        role: ChatRole.assistant,
        content: '城门关闭。',
        choiceOverride: options,
        choiceSourceDigest: StoryQuote.digest('城门关闭。'),
        timestamp: fixtures.date,
        isSummarized: false);
    expect(
        ChatMessage.fromJson(message.toJson()).displayContent, contains('石狮子'));
    expect(message.copyWith(content: '剧情改写了。').displayContent,
        isNot(contains('[CHOICES]')));
    final html = ChatExportBuilder.buildHtml(
        title: '导出', assistantName: '剧场', messages: [user, message]);
    expect(html, contains('&lt;他问你是否留下&gt;'));
    expect(html, contains('石狮子'));
  });
  test(
      'quotes are sent once as a reply target and stale sources cannot be queued',
      () async {
    final api = ComposerClient();
    final c = await fixtures.fixture(api);
    await c.queueUserMessage('开灯');
    await c.requestAssistantReply();
    final source = c.currentHistory.messages.last;
    final quote = c.makeStoryQuote(source.id, source.content, '他停下来等你回应。');
    expect(await c.queueUserMessage('我点点头。', quote: quote), isNull);
    expect(c.currentHistory.messages.last.content, '我点点头。');
    await c.requestAssistantReply();
    expect(
        api.requests.any((r) => r.contains('仅指明回应对象') && r.contains('我点点头。')),
        isTrue);
    await c.updateMessageContent(source.id, '原文已经改写。\n${fixtures.protocol}');
    expect(await c.queueUserMessage('继续', quote: quote), contains('引用原文已变化'));
  });
  test(
      'private notes stay out of prompts and clone independently with empty branch drafts',
      () async {
    final api = ComposerClient();
    final c = await fixtures.fixture(api);
    await c.savePrivateNote('world', '私人便签密码987654');
    await c.saveComposerDraft(
        'world', const ComposerDraft(text: '尚未发送的草稿6789'));
    await c.queueUserMessage('开灯');
    await c.requestAssistantReply();
    expect(api.requests.join(), isNot(contains('密码987654')));
    expect(api.requests.join(), isNot(contains('草稿6789')));
    expect(
        await c.createStoryBranchFromMessage(
            messageId: c.currentHistory.messages.last.id, branchName: '另一条路'),
        isNull);
    final branch = c.currentCharacter!.id;
    expect(await c.loadPrivateNote(branch), '私人便签密码987654');
    expect((await c.loadComposerDraft(branch)).text, isEmpty);
    await c.savePrivateNote(branch, '分支便签');
    expect(await c.loadPrivateNote('world'), '私人便签密码987654');
  });
  test(
      'editor saves serialize with reading updates and snapshots exclude editor data',
      () async {
    await fixtures.fixture(ComposerClient());
    final store = LocalStore();
    await Future.wait([
      store.saveStoryReading('world', 'main', {'messageId': 'm'}),
      store.saveStoryReading('world', 'composer/main', {'text': '草稿'}),
      store.saveStoryReading('world', 'privateNote', {'text': '便签'}),
    ]);
    final reading = await store.loadStoryReading('world');
    expect(reading.keys, containsAll(['main', 'composer/main', 'privateNote']));
    expect(
        StoryContinuityState(characterId: 'world', data: {'reading': reading})
            .snapshot()
            .containsKey('reading'),
        isFalse);
  });
  test(
      'addressing is scoped to NPC and world and remains independent of identity',
      () async {
    final api = ComposerClient();
    final c = await fixtures.fixture(api);
    await c.saveNpcAddressing(
        'a', {'toNpc': '小月亮', 'toPlayer': '旅人', 'condition': '独处时'});
    await c.queueNpcUserMessage('a', '你好');
    await c.requestNpcReply('a');
    expect(api.requests.last, contains('小月亮'));
    expect(c.npcProfileById('a')!.name, '阿澈');
    await c.queueNpcUserMessage('b', '你好');
    await c.requestNpcReply('b');
    expect(api.requests.last, isNot(contains('小月亮')));
    await c.selectCharacter('other');
    expect(c.npcAddressing('a'), isEmpty);
    await c.selectCharacter('world');
    expect(c.npcAddressing('a')['toNpc'], '小月亮');
  });
  test(
      'expression assistance returns two candidates without adding a message or changing state',
      () async {
    final api = ComposerClient();
    final c = await fixtures.fixture(api);
    final count = c.currentHistory.messages.length;
    final state = jsonEncode(c.currentGameState.toJson());
    final candidates =
        await c.helpExpress('world', const ComposerDraft(text: '想挽留他，不想太卑微'));
    expect(candidates, hasLength(2));
    expect(c.currentHistory.messages, hasLength(count));
    expect(jsonEncode(c.currentGameState.toJson()), state);
    expect(api.requests, hasLength(1));
    expect(api.requests.single, isNot(contains('后台密令884')));
  });
  test('archive round trip preserves notes, drafts, phrases and addressing',
      () async {
    final c = await fixtures.fixture(ComposerClient());
    await c.savePrivateNote('world', '下次问问戒指');
    await c.saveComposerDraft('world', const ComposerDraft(text: '未发送'));
    await c.saveDirectorPhrase('慢一点', '停留在这一刻');
    await c.saveNpcAddressing('a', {'toNpc': '小月亮'});
    final archive = await c.exportAllDataArchive();
    await c.savePrivateNote('world', '后来改了');
    c.rememberPrivateNote('world', '尚未落盘的旧便签');
    c.rememberComposerDraft('world', const ComposerDraft(text: '待保存的旧草稿'));
    expect(await c.importDataArchive(archive, replaceExisting: true), isNull);
    expect(await c.loadPrivateNote('world'), '下次问问戒指');
    expect((await c.loadComposerDraft('world')).text, '未发送');
    expect(c.settings.directorPhrases['慢一点'], '停留在这一刻');
    expect(c.npcAddressing('a')['toNpc'], '小月亮');
  });
  test('plot branch quotes resolve inside the new world', () async {
    final c = await fixtures.fixture(ComposerClient());
    await c.queueUserMessage('点灯');
    await c.requestAssistantReply();
    final main = c.currentHistory.messages.last;
    await c.queueUserMessage('我回应这句话',
        quote: c.makeStoryQuote(main.id, main.content, '灯亮了。'));
    await c.requestAssistantReply();
    await c.queueNpcUserMessage('a', '你好');
    await c.requestNpcReply('a');
    final source = c.npcMessagesFor('a').last;
    await c.queueNpcUserMessage('a', '接着说',
        quote: c.makeStoryQuote(source.id, source.content, source.content,
            npcId: 'a'));
    await c.requestNpcReply('a');
    final target = c.npcMessagesFor('a').last;
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(target.id, npcId: 'a').single,
        StoryRewriteMode.plot,
        '改成坦诚相告');
    await c.applyStoryRewrite(preview, branchName: '引用 IF');
    final mainQuote =
        c.currentHistory.messages.firstWhere((m) => m.quote != null).quote!;
    final npcQuote =
        c.npcMessagesFor('a').firstWhere((m) => m.quote != null).quote!;
    for (final quote in [mainQuote, npcQuote]) {
      expect(quote.worldId, c.currentCharacter!.id);
      expect(c.quoteIsCurrent(quote), isTrue);
    }
    await c.selectCharacter('world');
    expect(
        c.currentHistory.messages
            .firstWhere((m) => m.quote != null)
            .quote!
            .worldId,
        'world');
  });
  testWidgets('input keeps draft on failed save and clears only after success',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChatInputBar(
                isSending: false,
                canPause: false,
                hasPendingMessages: false,
                tutorialTargetsEnabled: false,
                onSend: (_) async {
                  if (fail) {
                    throw StateError('磁盘写入失败');
                  }
                },
                onLaunch: () async {}))));
    await tester.enterText(find.byType(TextField), '保留这句话');
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '保留这句话'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });
  testWidgets('composer draft restores and tools fit phone width',
      (tester) async {
    final c = await fixtures.fixture(ComposerClient());
    await c.saveComposerDraft('world', const ComposerDraft(text: '还没说完的话'));
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
            home: Scaffold(
                body: Align(
                    alignment: Alignment.bottomCenter,
                    child: StoryComposer(
                        worldId: 'world',
                        isSending: false,
                        canPause: false,
                        hasPendingMessages: false,
                        tutorialTargetsEnabled: false,
                        onSend: (_, __) async => null,
                        onLaunch: () async {}))))));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '还没说完的话'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isFalse);
    await tester.tap(find.byTooltip('写作小工具'));
    await tester.pumpAndSettle();
    expect(find.text('私人便签'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
