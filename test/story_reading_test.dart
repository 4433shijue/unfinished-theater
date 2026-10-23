import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_roleplay_chat/widgets/story_anchored_list.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
        'measured long-history anchors, growth and deleted recovery at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      final key = GlobalKey<StoryAnchoredListState>();
      var ids = List.generate(600, (i) => 'm$i');
      var generating = false;
      String? saved;
      double? fraction;
      Widget view() => MaterialApp(
          home: Scaffold(
              body: StoryAnchoredList(
                  key: key,
                  controller: scroll,
                  ids: List.of(ids),
                  scopeKey: 'world',
                  generating: generating,
                  onPosition: (id, f, leaving) {
                    saved = id;
                    fraction = f;
                  },
                  savedPosition: const {'messageId': 'm320', 'fraction': 0.35},
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => SizedBox(
                      height: i % 3 == 0
                          ? 820
                          : i % 3 == 1
                              ? 92
                              : 270,
                      child: Text(ids[i], key: ValueKey('text-${ids[i]}'))))));
      await tester.pumpWidget(view());
      for (var i = 0; i < 75; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(saved, 'm320');
      expect(fraction, closeTo(0.35, 0.02));
      final offset = scroll.offset;
      ids.add('new');
      generating = true;
      await tester.pumpWidget(view());
      await tester.pump();
      expect(scroll.offset, closeTo(offset, 1));
      expect(find.text('有新内容'), findsOneWidget);
      generating = false;
      ids.remove('m320');
      await tester.pumpWidget(view());
      for (var i = 0; i < 75; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(saved, 'm321');
      await tester.tap(find.text('有新内容'));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(scroll.position.extentAfter, lessThan(1));
      expect(find.text('有新内容'), findsNothing);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(saved, 'm0');
      expect(fraction, closeTo(0, 0.01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    });
  }
  testWidgets('missing persisted anchor chooses surviving neighbor',
      (tester) async {
    final scroll = ScrollController();
    String? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StoryAnchoredList(
                controller: scroll,
                ids: List.generate(20, (i) => 'm$i'),
                onPosition: (id, _, __) {
                  saved = id;
                },
                savedPosition: const {
                  'messageId': 'deleted',
                  'nextId': 'm8',
                  'index': 8
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    SizedBox(height: 300, child: Text('m$i'))))));
    for (var i = 0; i < 75; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(saved, 'm8');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
}
