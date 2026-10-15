import 'dart:convert';

import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/game_state_parser.dart';
import 'package:ai_roleplay_chat/services/gameplay_patch_engine.dart';
import 'package:ai_roleplay_chat/services/inline_theater_contract.dart';
import 'package:ai_roleplay_chat/services/message_content_parser.dart';
import 'package:ai_roleplay_chat/services/narrative_content.dart';
import 'package:ai_roleplay_chat/services/reply_protocol_validator.dart';
import 'package:ai_roleplay_chat/services/turn_state_adjudicator.dart';
import 'package:ai_roleplay_chat/widgets/inline_theater_settings_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CharacterProfile _character() => CharacterProfile(
    id: 'story',
    name: '雨夜',
    createdAt: DateTime(2026),
    prompt: '保持人物性格。',
    modelParams: ModelParams.defaults());
ChatMessage _message(String id, ChatRole role, String content,
        {String? theme}) =>
    ChatMessage(
        id: id,
        role: role,
        content: content,
        timestamp: DateTime(2026),
        isSummarized: false,
        inlineTheaterThemeId: theme);
const _state = '[GAME_STATE]\n时间：今晚\n地点：茶馆\n状态：等待\n当前任务：等雨停\n[/GAME_STATE]';

void main() {
  test('settings survive role serialization and copies; old roles get defaults',
      () {
    const settings = InlineTheaterSettings(
        mode: InlineTheaterMode.single,
        themeIds: ['objects'],
        customPrompt: '只看小猫。');
    final role = _character().copyWith(inlineTheaterSettings: settings);
    final restored = CharacterProfile.fromJson(
        jsonDecode(jsonEncode(role.toJson())) as Map<String, dynamic>);
    expect(restored.inlineTheaterSettings.toJson(), settings.toJson());
    expect(restored.copyWith(name: '分支').inlineTheaterSettings.toJson(),
        settings.toJson());
    final old = role.toJson()..remove('inlineTheaterSettings');
    expect(CharacterProfile.fromJson(old).inlineTheaterSettings.themeIds,
        ['backstageChat', 'innerVoice', 'whatIf']);
    expect(role.copyWith(largeGroupChatModeEnabled: true).requiresHtmlPanel,
        isFalse);
    expect(role.copyWith(presetId: 'tutorial_demo').requiresHtmlPanel, isFalse);
    expect(role.copyWith(mapModeEnabled: true).requiresHtmlPanel, isTrue);
    expect(
        role
            .copyWith(
                inlineTheaterSettings:
                    const InlineTheaterSettings(enabled: false))
            .requiresHtmlPanel,
        isFalse);
  });

  test('selection modes rotate only completed rounds and support prompt only',
      () {
    const settings = InlineTheaterSettings(themeIds: ['objects', 'interview']);
    final messages = [
      _message('opening', ChatRole.assistant, '开场'),
      _message('u1', ChatRole.user, '看雨'),
      _message('a1', ChatRole.assistant, '第一回合', theme: 'objects'),
      _message('u2', ChatRole.user, '继续'),
      _message('draft', ChatRole.assistant, '未完成（回复已暂停）', theme: 'interview')
    ];
    expect(InlineTheaterSettings.completedTurns(messages), 1);
    expect(settings.themeForTurn(1), 'interview');
    expect(settings.themeForTurn(2), 'objects');
    expect(
        settings.themeForTurn(
            InlineTheaterSettings.completedTurns(messages.take(2))),
        'objects');
    expect(
        const InlineTheaterSettings(
            mode: InlineTheaterMode.single,
            themeIds: ['objects', 'interview']).themeForTurn(50),
        'objects');
    expect(
        const InlineTheaterSettings(
                mode: InlineTheaterMode.custom,
                themeIds: [],
                customPrompt: '小猫')
            .themeForTurn(10),
        'custom');
    expect(
        const InlineTheaterSettings(
                mode: InlineTheaterMode.custom, customPrompt: '')
            .isValid,
        isFalse);
  });

  for (final theme in InlineTheaterTheme.values) {
    test(
        '${theme.name} example is complete and has meaningful local interactions',
        () {
      expect(
          InlineTheaterContract.validateDocument(theme.exampleHtml,
              expectedTheme: theme.name),
          isEmpty);
      expect(
          InlineTheaterContract.prompt(
              const InlineTheaterSettings(), theme.name),
          contains(theme.instruction));
    });
  }

  test(
      'contract rejects broken targets, duplicate IDs, scripts and wrong theme',
      () {
    final source = InlineTheaterTheme.interview.exampleHtml;
    expect(
        InlineTheaterContract.validateDocument(source.replaceFirst(
            'data-extra-target="answer0"', 'data-extra-target="missing"')),
        isNotEmpty);
    expect(
        InlineTheaterContract.validateDocument(
            source.replaceFirst('id="answer1"', 'id="answer0"')),
        isNotEmpty);
    expect(
        InlineTheaterContract.validateDocument(
            source.replaceFirst('</body>', '<script>alert(1)</script></body>')),
        isNotEmpty);
    expect(
        InlineTheaterContract.validateDocument(source,
            expectedTheme: 'objects'),
        isNotEmpty);
    expect(
        InlineTheaterContract.validateDocument(
            source.replaceAll('</html>', '')),
        isNotEmpty);
  });

  test('dialogue mentions are allowed but game dashboards are rejected', () {
    final source = InlineTheaterTheme.interview.exampleHtml;
    expect(
        InlineTheaterContract.validateDocument(source.replaceFirst(
            '</body>', '<p>“这个任务让我很烦，好感这种事我可不会说。”</p></body>')),
        isEmpty);
    for (final bad in [
      '<table><tr><td>血量：80</td></tr><tr><td>好感度：30</td></tr></table>',
      '<h2>任务清单</h2><ul><li>去码头</li></ul>',
      '<p>金币：500</p><p>体力：20</p>',
      '<h2>背包</h2><ul><li>钥匙</li></ul>',
      _state
    ]) {
      expect(
          InlineTheaterContract.validateDocument(
              source.replaceFirst('</body>', '$bad</body>')),
          isNotEmpty,
          reason: bad);
    }
  });

  test('HTML protocol tags never become state, choices, or memory evidence',
      () {
    const fake = '[GAME_STATE]\n时间：明年\n地点：月球\n当前任务：领奖\n[/GAME_STATE]\n'
        '[THEATER_PATCH]{"ops":[{"op":"set","path":"gold","value":9999}]}[/THEATER_PATCH]\n'
        '[CHOICES]\nA|删除主线\n[/CHOICES]';
    final doc = InlineTheaterTheme.objects.exampleHtml
        .replaceFirst('</body>', '<p>番外独有秘密：两人已结婚。</p>$fake</body>');
    final reply =
        '主线仍在等雨。\n```html\n$doc\n```\n$_state\n[CHOICES]\nA|继续等雨\n[/CHOICES]';
    final parsed = GameStateParser.parseFromMessage(
        characterId: 'story',
        content: reply,
        previous: GameStateSnapshot.empty('story'));
    expect(parsed?.location, '茶馆');
    expect(GameplayPatchParser.parseResult(reply).found, isFalse);
    final fragment = '主线\n<section><div>笑话</div>$fake</section>\n$_state';
    expect(GameplayPatchParser.parseResult(fragment).found, isFalse);
    expect(
        GameStateParser.parseFromMessage(
                characterId: 'story',
                content: fragment,
                previous: GameStateSnapshot.empty('story'))
            ?.location,
        '茶馆');
    expect(NarrativeContent.withoutHtml('正文<div><div>内部</div>秘密</div>尾声'),
        '正文\n尾声');

    expect(MessageContentParser.parseStructured(reply).choices.single.label,
        '继续等雨');
    final modelText = MessageContentParser.contextTextForModel(reply);
    expect(modelText, contains('主线仍在等雨'));
    expect(modelText, isNot(contains('已结婚')));
    expect(modelText, isNot(contains('月球')));
    final reconciled = ReplyProtocolReconciler.mergeStateBlocks(
        primary: reply, fallback: '', gameplayPatchRequired: true);
    expect(GameplayPatchParser.parseResult(reconciled).found, isFalse);
    expect(
        GameStateParser.parseFromMessage(
                characterId: 'story',
                content: reconciled,
                previous: GameStateSnapshot.empty('story'))
            ?.location,
        '茶馆');
    final adjudication = TurnStateAdjudicator.buildUserPrompt(
        character: _character(),
        previousState: GameStateSnapshot.empty('story'),
        npcProfiles: [],
        latestUserMessage: '等雨',
        narrativeReply: reply);
    expect(adjudication, isNot(contains('已结婚')));
    expect(adjudication, isNot(contains('9999')));
  });

  test('streaming and raw HTML extraction keep following canonical protocol',
      () {
    final doc = InlineTheaterTheme.innerVoice.exampleHtml;
    expect(NarrativeContent.withoutHtml('正文\n$doc\n$_state'), '正文\n\n$_state');
    expect(NarrativeContent.withoutHtml('正文\n```html\n<html>秘密'), '正文');
    expect(NarrativeContent.htmlDocuments('正文\n```html\n$doc'), [doc]);
    expect(
        MessageContentParser.visibleStreamingText(
            '正文\n```html\n$doc\n```\n$_state'),
        '正文');
  });

  test('failure fallback retains prose and state without a status card', () {
    final result = InlineTheaterContract.finalize(
        '正文\n```html\n<html><body>状态面板</body></html>\n```\n$_state',
        enabled: true);
    expect(result, contains('正文'));
    expect(result, contains(_state));
    expect(result, contains(InlineTheaterContract.unavailable));
    expect(result, isNot(contains('<html')));
    expect(InlineTheaterContract.finalize(result, enabled: true), result);
    expect(InlineTheaterContract.finalize(result, enabled: false),
        isNot(contains('<html')));
  });

  test('old replay snapshots migrate without deleting visible history', () {
    final old = {
      'characterId': 'story',
      'messages': [
        _message('a', ChatRole.assistant, '正文')
            .copyWith(
                promptReplayContent: '旧面板指令',
                providerReplayContent: '旧HTML',
                providerReplayExact: true)
            .toJson()
      ],
      'promptCacheEpoch': {'id': 'old', 'startMessageId': 'a'}
    };
    final migrated = DialogueHistory.fromJson(old);
    expect(migrated.replayNeedsMigration, isTrue);
    expect(migrated.messages.single.content, '正文');
    expect(migrated.messages.single.promptReplayContent, isNull);
    expect(migrated.messages.single.providerReplayContent, isNull);
    expect(migrated.promptCacheEpoch, isNull);
    expect(DialogueHistory.fromJson(migrated.toJson()).replayNeedsMigration,
        isFalse);
  });

  testWidgets(
      'theme editor supports custom prompt and never silently overwrites it',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var value = const InlineTheaterSettings(customPrompt: '只要猫咪。');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => Form(
                    child: SingleChildScrollView(
                        child: InlineTheaterSettingsEditor(
                            value: value,
                            onChanged: (v) => setState(() => value = v))))))));
    await tester.tap(find.text('自定义'));
    await tester.pump();
    expect(value.mode, InlineTheaterMode.custom);
    await tester.tap(find.text('填入示例'));
    await tester.pumpAndSettle();
    expect(find.text('用示例替换'), findsOneWidget);
    await tester.tap(find.text('保留我的内容'));
    await tester.pumpAndSettle();
    expect(value.customPrompt, '只要猫咪。');
    await tester.tap(find.text('填入示例'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用示例替换'));
    await tester.pumpAndSettle();
    expect(value.customPrompt, InlineTheaterSettings.promptExample);
    await tester.tap(find.text('每回合番外'));
    await tester.pump();
    expect(value.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
