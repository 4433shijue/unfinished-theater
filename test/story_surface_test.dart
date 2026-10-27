import 'package:ai_roleplay_chat/widgets/story_surface.dart';
import 'package:ai_roleplay_chat/widgets/turn_settlement_dialog.dart';
import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:ai_roleplay_chat/models/turn_settlement.dart';
import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'story_workflow_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    AppTheme.registerRuntimeThemes([]);
    AppTheme.themeFor('sakura');
  });
  final receipt = TurnSettlement(worldId: 'world', turnId: 'turn', entries: [
    for (var i = 0; i < 24; i++)
      {
        'category': '好感',
        'label': '旅人$i',
        'before': 0,
        'after': 5,
        'delta': 5,
        'reason': '帮忙找回信件'
      }
  ]);
  for (final size in [
    const Size(390, 844),
    const Size(1280, 950),
    const Size(844, 390),
    const Size(320, 568)
  ]) {
    testWidgets('settlement is centered and scrollable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await fixtures.fixture(fixtures.ScriptedClient());
      await tester.pumpWidget(ChangeNotifierProvider<AppStateController>.value(
          value: c,
          child: MaterialApp(
              theme: AppTheme.themeFor('rift_relay'),
              home: Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () => showTurnSettlement(context, receipt),
                          child: const Text('打开')))))));
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final rect =
          tester.getRect(find.byKey(const ValueKey('story-dialog-surface')));
      expect(rect.center.dx, closeTo(size.width / 2, 1));
      expect(rect.center.dy, closeTo(size.height / 2, 1));
      expect(rect.width, lessThanOrEqualTo(500));
      expect(rect.height, lessThanOrEqualTo(size.height * .72 + 1));
      expect(rect.top, greaterThan(20));
      expect(rect.bottom, lessThan(size.height - 20));
      expect(find.byType(BottomSheet), findsNothing);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('继续阅读'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('继续阅读'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryDialog), findsNothing);
    });
  }
  for (final variant in AppThemeVariant.values) {
    testWidgets('story surface inherits ${variant.id} skin and controls',
        (tester) async {
      final theme = AppTheme.themeFor(variant.id);
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: const StoryAlertDialog(
              title: Text('开局预览'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                StoryExpansionSection(
                    title: Text('高级设置'), children: [Text('指令原文')]),
                FilterChip(
                    label: Text('锁定人物'), selected: true, onSelected: null),
              ])),
              actions: [FilledButton(onPressed: null, child: Text('保存'))])));
      await tester.pumpAndSettle();
      final surface = tester
          .widget<DecoratedBox>(
              find.byKey(const ValueKey('story-dialog-surface')))
          .decoration as BoxDecoration;
      expect((surface.gradient as LinearGradient).colors.every((c) => c.a == 1),
          isTrue);
      expect(surface.border, AppTheme.glassPanel(highlighted: true).border);
      expect(surface.borderRadius,
          AppTheme.glassPanel(highlighted: true).borderRadius);
      final context = tester.element(find.text('保存'));
      expect(Theme.of(context).filledButtonTheme.style?.backgroundBuilder,
          theme.filledButtonTheme.style?.backgroundBuilder);
      expect(Theme.of(context).textTheme.bodyMedium?.fontFamily,
          theme.textTheme.bodyMedium?.fontFamily);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'custom skins use their palette and radius without preset artwork',
      (tester) async {
    final base = AppThemeVariant.riftRelay;
    AppTheme.registerRuntimeThemes([
      RuntimeThemeDefinition(
          id: 'custom_theme_test',
          label: '自定义',
          description: '',
          baseThemeId: base.id,
          palette: base.palette,
          radius: 11)
    ]);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.themeFor('custom_theme_test'),
        home:
            const StoryAlertDialog(title: Text('人物'), content: Text('当前身份'))));
    final panel = tester
        .widget<DecoratedBox>(
            find.byKey(const ValueKey('story-dialog-surface')))
        .decoration as BoxDecoration;
    expect(panel.borderRadius, BorderRadius.circular(11));
    expect(AppTheme.usesRasterButtonArtwork, isFalse);
    expect(tester.takeException(), isNull);
  });
}
