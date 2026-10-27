import 'package:ai_roleplay_chat/widgets/character_editor_dialog.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_roleplay_chat/widgets/story_creation_editors.dart';
import 'package:ai_roleplay_chat/widgets/turn_settlement_dialog.dart';
import 'package:ai_roleplay_chat/models/story_opening_draft.dart';
import 'package:ai_roleplay_chat/models/turn_settlement.dart';
import 'story_evolution_test.dart' as fixture;

void main() {
  testWidgets('save failure leaves the edited draft open for retry',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: CharacterEditorDialog(
            initialCharacter: CharacterProfile(
                id: 'w',
                name: '草稿保留',
                createdAt: DateTime(2026),
                prompt: '世界设定原文',
                modelParams: ModelParams.defaults()),
            onSave: (_) async {
              throw StateError('disk failure');
            })));
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterEditorDialog), findsOneWidget);
    expect(find.textContaining('保存失败，草稿已保留'), findsWidgets);
    expect(find.text('世界设定原文'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'author secret inspection does not reveal knowledge; locks disable regeneration',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    StoryOpeningDraft draft = fixture.openingDraft();
    final locked = <String>{};
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: StatefulBuilder(
                    builder: (c, set) => StoryOpeningEditor(
                        value: draft,
                        locked: locked,
                        onChanged: (v) => set(() => draft = v),
                        onRegenerate: (_) async {}))))));
    expect(find.textContaining('只有本人知道'), findsNothing);
    await tester.tap(find.text('人物1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作者查看 · 含剧透').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('只有本人知道的暗号1'), findsOneWidget);
    expect(draft.npcs.first['secretRevealed'], isNot(true));
    await tester.tap(find.text('锁定人物').first);
    await tester.pumpAndSettle();
    expect(locked, contains('npc:n1'));
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '重新生成此人').first)
            .onPressed,
        isNull);
  });
  testWidgets(
      'settlement is scrollable at phone width and displays actual changes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TurnSettlementPanel(
                settlement: TurnSettlement(worldId: 'w', turnId: 't', entries: [
      {
        'category': '物品',
        'label': '止血药',
        'before': 3,
        'after': 2,
        'delta': -1,
        'reason': '包扎'
      },
      for (var i = 0; i < 14; i++)
        {
          'category': '好感',
          'label': '人物$i',
          'before': 0,
          'after': 5,
          'delta': 5,
          'reason': '帮忙'
        }
    ])))));
    expect(find.textContaining('3 → 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('继续阅读'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
