import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/widgets/story_workbench.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'story_workflow_test.dart' as fixtures;

void main() {
  testWidgets('duplicate text requires choosing an occurrence before preview',
      (tester) async {
    final c = (await tester.runAsync(() async {
      final c = await fixtures.fixture(fixtures.ScriptedClient());
      await c.queueUserMessage('开始');
      await c.requestAssistantReply();
      final id = c.currentHistory.messages.last.id;
      await c.updateMessageContent(id, '他说重复，然后又说重复。\n${fixtures.protocol}');
      return c;
    }))!;
    final id = c.currentHistory.messages.last.id;
    await tester.pumpWidget(ChangeNotifierProvider<AppStateController>.value(
      value: c,
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () =>
                          showStoryRewriteDialog(context, id, selection: '重复'),
                      child: const Text('打开'))))),
    ));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('这段文字出现多次，请按顺序与上下文选择要改的位置。'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '生成预览'))
            .onPressed,
        isNull);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2.').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '生成预览'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });
}
