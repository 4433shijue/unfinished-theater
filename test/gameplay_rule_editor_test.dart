import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_draft_editors.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_rehearsal_dialog.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_rule_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gameplay_rule_draft_test.dart' show ruleEditorSystem, editorState;

void main() {
  testWidgets(
      'numeric form saves real conditions and preserves separate player prose',
      (tester) async {
    final system = ruleEditorSystem();
    Map<String, dynamic>? result;
    await _open(tester, system, (value) => result = value);
    await _show(tester, find.byKey(const ValueKey('condition-value-0')));
    await tester.enterText(
        find.byKey(const ValueKey('condition-value-0')), '7');
    await _show(
        tester, find.byKey(const ValueKey('rule-execution-description')));
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('rule-execution-description')))
            .data,
        contains('暴露程度达到或超过 7'));
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    expect((result!['conditions'] as List).single['value'], 7);
    expect(result!['when'], system.rules.single.when);
    expect(result!['effect'], system.rules.single.effect);
    expect(result!['playerSummary'], system.rules.single.playerSummary);
    expect(system.rules.single.conditions.single.value, 5);
  });

  testWidgets(
      'advanced JSON returns to typed form without losing costs or threads',
      (tester) async {
    final system = ruleEditorSystem();
    Map<String, dynamic>? result;
    await _open(tester, system, (value) => result = value);
    await _show(tester, find.text('高级 JSON'));
    await tester.tap(find.text('高级 JSON'));
    await tester.pumpAndSettle();
    final execution = {
      'conditions': [
        {'path': '调查.证物', 'op': 'contains', 'value': '钥匙'}
      ],
      'costs': [
        {'path': '局势.筹码', 'amount': 2}
      ],
      'effects': [
        {'path': '调查.态度', 'op': 'set', 'value': '大胆'}
      ],
      'threads': [
        {
          'op': 'open',
          'id': 'promise',
          'title': '归还钥匙',
          'description': '交还给船工',
          'reason': '换得进入码头的许可',
          'visibility': 'director'
        }
      ],
      'once': false,
      'cooldownTurns': 3,
    };
    await _show(tester, find.byKey(const ValueKey('rule-json')), step: -200);
    await tester.enterText(
        find.byKey(const ValueKey('rule-json')), jsonEncode(execution));
    await _show(tester, find.text('校验并回到表单'));
    await tester.tap(find.text('校验并回到表单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    for (final entry in execution.entries) {
      expect(result![entry.key], entry.value, reason: entry.key);
    }
  });

  testWidgets(
      'bad advanced values remain editable and cannot be silently clamped',
      (tester) async {
    final system = ruleEditorSystem();
    Map<String, dynamic>? result;
    await _open(tester, system, (value) => result = value);
    await _show(tester, find.text('高级 JSON'));
    await tester.tap(find.text('高级 JSON'));
    await tester.pumpAndSettle();
    await _show(tester, find.byKey(const ValueKey('rule-json')), step: -200);
    await tester.enterText(find.byKey(const ValueKey('rule-json')),
        '{"conditions": [], "cooldownTurns": -1}');
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(GameplayRuleEditor), findsOneWidget);
    await _show(tester, find.byKey(const ValueKey('rule-editor-error')));
    expect(find.textContaining('缺少非空触发条件'), findsOneWidget);
  });

  testWidgets(
      'legacy prose stays prose until the author explicitly configures execution',
      (tester) async {
    final system = ruleEditorSystem(legacy: true);
    Map<String, dynamic>? result;
    await _open(tester, system, (value) => result = value);
    expect(find.text('叙事规则'), findsOneWidget);
    expect(find.text('同时满足以下条件（并且）'), findsNothing);
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    expect(result!.containsKey('conditions'), isFalse);
    await tester.tap(find.text('打开规则'));
    await tester.pumpAndSettle();
    await _show(tester, find.byKey(const ValueKey('rule-convert')));
    await tester.tap(find.byKey(const ValueKey('rule-convert')));
    await tester.pumpAndSettle();
    expect(find.text('同时满足以下条件（并且）'), findsOneWidget);
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    expect(find.byType(GameplayRuleEditor), findsOneWidget);
  });

  testWidgets('variable type changes offer appropriate values and permissions',
      (tester) async {
    final system = ruleEditorSystem();
    Map<String, dynamic>? result;
    await _open(tester, system, (value) => result = value);
    await _show(tester, find.byKey(const ValueKey('conditions-path-0')));
    await tester.tap(find.byKey(const ValueKey('conditions-path-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('态度').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('condition-value-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('大胆').last);
    await tester.pumpAndSettle();
    await _show(tester, find.byKey(const ValueKey('effects-path-0')));
    await tester.tap(find.byKey(const ValueKey('effects-path-0')));
    await tester.pumpAndSettle();
    expect(find.text('只读进度'), findsNothing);
    await tester.tap(find.text('秘密线人').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    final condition = (result!['conditions'] as List).single;
    expect(condition['path'], '调查.态度');
    expect(condition['op'], 'eq');
    expect(condition['value'], '大胆');
  });

  testWidgets(
      'author rehearsal shows actual reasons and accepts boolean starting values',
      (tester) async {
    final system = ruleEditorSystem();
    final original = editorState(system);
    final before = jsonEncode(original.toJson());
    await tester.pumpWidget(MaterialApp(
        home: GameplayRehearsalDialog(
            system: system, state: original, authorDiagnostics: true)));
    await _show(tester, find.text('调整预演起点'));
    await tester.tap(find.text('调整预演起点'));
    await tester.pumpAndSettle();
    await _show(tester, find.byKey(const ValueKey('rehearsal-局势.筹码')));
    await tester.enterText(find.byKey(const ValueKey('rehearsal-局势.筹码')), '1');
    await _show(tester, find.byKey(const ValueKey('rehearsal-幕后.线人-false')));
    await tester.tap(find.byKey(const ValueKey('rehearsal-幕后.线人-false')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('是').last);
    await tester.pumpAndSettle();
    await _show(tester, find.text('同一时段再一回合'));
    await tester.tap(find.text('同一时段再一回合'));
    await tester.pumpAndSettle();
    await _show(tester, find.textContaining('代价不足'));
    expect(find.textContaining('代价不足'), findsOneWidget);
    expect(jsonEncode(original.toJson()), before);
  });

  testWidgets('rule form lays out at mobile width without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(tester, ruleEditorSystem(), (_) {});
    await _show(tester, find.byKey(const ValueKey('condition-value-0')));
    expect(tester.takeException(), isNull);
    await _show(tester, find.text('高级 JSON'));
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('CAPTURE_RULE_EDITOR')) {
    for (final width in [360.0, 1200.0]) {
      testWidgets('capture rule editor at ${width.toInt()}', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final font = FontLoader('RulePreview')
            ..addFont(
                rootBundle.load('assets/fonts/SourceHanSansSC-Regular.otf'));
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
        final boundary = GlobalKey();
        final system = ruleEditorSystem();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(fontFamily: 'RulePreview'),
                home: GameplayRuleEditor(
                    system: system,
                    rule: system.rules.single,
                    state: editorState(system)))));
        await tester.pumpAndSettle();
        await _capture(tester, boundary, 'rule-form-${width.toInt()}');
        await _show(tester, find.text('实际执行说明 · 仅作者可见'));
        await _capture(tester, boundary, 'rule-summary-${width.toInt()}');
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(fontFamily: 'RulePreview'),
                home: GameplayRehearsalDialog(
                    system: system,
                    state: editorState(system).copyWith(customVariables: {
                      ...system.initialValues(),
                      '局势.筹码': 1,
                    }),
                    authorDiagnostics: true))));
        await tester.pumpAndSettle();
        await _show(tester, find.text('同一时段再一回合'));
        await tester.tap(find.text('同一时段再一回合'));
        await tester.pumpAndSettle();
        await _show(tester, find.textContaining('代价不足'));
        await _capture(tester, boundary, 'rule-rehearsal-${width.toInt()}');
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _open(WidgetTester tester, GameplaySystem system,
    ValueChanged<Map<String, dynamic>?> onResult) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      onResult(await editGameplayRule(
                          context, system.rules.single,
                          system: system, state: editorState(system)));
                    },
                    child: const Text('打开规则')),
              ))));
  await tester.tap(find.text('打开规则'));
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder finder,
    {double step = 200}) async {
  await tester.scrollUntilVisible(finder, step,
      scrollable: find.byType(Scrollable).first, maxScrolls: 45);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('.tmp/rule-editor-previews');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
