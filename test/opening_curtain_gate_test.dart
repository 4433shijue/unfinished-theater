import 'package:ai_roleplay_chat/widgets/opening_curtain_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('curtain handle supports a tap to open', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OpeningCurtainGate(
          ready: true,
          loadingLabel: '正在准备舞台',
          onOpened: () async {
            opened += 1;
          },
          child: const Center(child: Text('剧场主界面')),
        ),
      ),
    );

    await tester.tap(find.textContaining('拖拽开幕'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 600));

    expect(opened, 1);
    expect(find.text('剧场主界面'), findsOneWidget);
    expect(find.textContaining('拖拽开幕'), findsNothing);
  });

  testWidgets('curtain uses a bundled Chinese font before opening',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OpeningCurtainGate(
          ready: true,
          loadingLabel: '正在准备舞台',
          onOpened: () async {},
          child: const SizedBox.shrink(),
        ),
      ),
    );

    for (final text in <String>[
      '未完剧场',
      '故事不是被写完才开始；当你拉开帷幕，它才获得命运。',
      '拖拽开幕',
    ]) {
      final widget = tester.widget<Text>(find.text(text));
      expect(widget.style?.fontFamily, 'FlowerWenDingKai');
    }
  });

  testWidgets('curtain opens immediately when animations are disabled',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OpeningCurtainGate(
            ready: true,
            loadingLabel: '正在准备舞台',
            onOpened: () async {
              opened += 1;
            },
            child: const Center(child: Text('剧场主界面')),
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('拖拽开幕'));
    await tester.pump();

    expect(opened, 1);
    expect(find.text('剧场主界面'), findsOneWidget);
    expect(find.textContaining('拖拽开幕'), findsNothing);
  });
}
