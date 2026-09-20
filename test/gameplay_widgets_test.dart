import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_runtime.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/services/gameplay_turn_engine.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_author_dialog.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_draft_editors.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_rehearsal_dialog.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_system_readout.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_turn_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reply feedback uses each historical player snapshot only',
      (tester) async {
    await tester.pumpWidget(_host(Column(children: [
      GameplayTurnFeedback(
          message: _message('old', ['旧回合的调查推进', '付出两枚筹码', '解锁码头通行'])),
      GameplayTurnFeedback(message: _message('new', ['新回合的风声变化'])),
    ])));
    expect(find.textContaining('旧回合的调查推进'), findsOneWidget);
    expect(find.textContaining('新回合的风声变化'), findsOneWidget);
    expect(find.text('解锁码头通行'), findsNothing);
    expect(find.textContaining('幕后凶手'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('gameplay-feedback-old')));
    await tester.pumpAndSettle();
    expect(find.text('解锁码头通行'), findsOneWidget);
    expect(find.textContaining('幕后凶手'), findsNothing);
  });

  testWidgets('feedback is absent for missing snapshots, streaming, and users',
      (tester) async {
    await tester.pumpWidget(_host(Column(children: [
      GameplayTurnFeedback(
          message:
              _message('empty', []).copyWith(clearGameStateSnapshot: true)),
      GameplayTurnFeedback(
          message: _message('streaming', ['未完成结算']), isStreaming: true),
      GameplayTurnFeedback(
          message: _message('user', ['用户不该显示']).copyWith(role: ChatRole.user)),
      GameplayTurnFeedback(message: _message('backstage-only', [])),
    ])));
    expect(find.text('这一回合的变化'), findsNothing);
    expect(find.textContaining('幕后凶手'), findsNothing);
  });

  testWidgets('player readout prioritizes safe hints and filters secrets',
      (tester) async {
    final system = _system();
    final state = _state(system).copyWith(
        gameplayRuntime: const GameplayRuntimeState(threads: [
      GameplayStoryThread(
          id: 'visible',
          title: '答应替船工保密',
          description: '归还证词后再回应',
          status: GameplayThreadStatus.resolved),
      GameplayStoryThread(
          id: 'hidden',
          title: '幕后凶手的邀约',
          visibility: GameplayVariableVisibility.director),
    ]));
    await tester
        .pumpWidget(_host(GameplaySystemReadout(system: system, state: state)));
    expect(find.text(system.coreLoop), findsOneWidget);
    expect(find.text('低调调查可以降低暴露'), findsOneWidget);
    expect(find.text('幕后凶手藏在警署'), findsNothing);
    expect(find.text('等待换班会带来新的巡逻'), findsOneWidget);
    expect(find.text('秘密追捕名单'), findsNothing);
    expect(find.text('答应替船工保密'), findsOneWidget);
    expect(find.text('已兑现'), findsOneWidget);
    expect(find.text('幕后凶手的邀约'), findsNothing);
  });

  testWidgets(
      'new missing hints never reveal author prose; legacy hints still work',
      (tester) async {
    final modern = GameplaySystem.fromJson({
      ..._system().toJson(),
      'variables': [
        for (final variable in _system().variables)
          {...variable.toJson(), 'playerHint': ''},
      ],
      'rules': [
        {..._system().rules.first.toJson(), 'playerSummary': ''},
      ]
    });
    await tester.pumpWidget(
        _host(GameplaySystemReadout(system: modern, state: _state(modern))));
    expect(find.text('幕后凶手藏在警署'), findsNothing);
    expect(find.textContaining('秘密追捕名单'), findsNothing);
    final legacy =
        GameplaySystem.fromJson({...modern.toJson(), 'schemaVersion': 2});
    await tester.pumpWidget(
        _host(GameplaySystemReadout(system: legacy, state: _state(legacy))));
    expect(find.text('幕后凶手藏在警署'), findsOneWidget);
  });

  testWidgets(
      'five key states show first, more fold, conditional states reveal',
      (tester) async {
    final system = GameplaySystem.fromJson({
      ..._system().toJson(),
      'variables': [
        for (var i = 0; i < 7; i++)
          {
            ..._system().variables.first.toJson(),
            'key': '状态.v$i',
            'label': '变量$i',
            'isCore': i == 6,
            'playerHint': '说明$i',
            if (i == 5)
              'revealWhen': [
                {'path': '状态.v0', 'op': 'gte', 'value': 5}
              ],
          },
      ],
      'rules': []
    });
    await tester.pumpWidget(
        _host(GameplaySystemReadout(system: system, state: _state(system))));
    expect(find.text('变量6'), findsOneWidget);
    expect(find.text('变量4'), findsNothing);
    expect(find.text('变量5'), findsNothing);
    await tester.ensureVisible(find.text('其他状态（1）'));
    await tester.tap(find.text('其他状态（1）'));
    await tester.pumpAndSettle();
    expect(find.text('变量4'), findsOneWidget);
    expect(find.text('变量5'), findsNothing);
    await tester.pumpWidget(_host(GameplaySystemReadout(
        system: system,
        state: _state(system).copyWith(
            customVariables: {...system.initialValues(), '状态.v0': 6}))));
    await tester.pumpAndSettle();
    expect(find.text('其他状态（2）'), findsOneWidget);
    expect(find.text('变量5'), findsOneWidget);
  });

  testWidgets('backstage shows public explanations as well as hidden variables',
      (tester) async {
    final system = _system();
    await tester.pumpWidget(_host(GameplaySystemReadout(
        system: system, state: _state(system), backstage: true)));
    expect(find.text('幕后凶手藏在警署'), findsOneWidget);
    expect(find.text('警署暗线'), findsOneWidget);
    expect(find.textContaining('秘密追捕名单'), findsOneWidget);
  });

  testWidgets('fuzzy player states show stages without their exact value',
      (tester) async {
    final system = GameplaySystem.fromJson({
      ..._system().toJson(),
      'variables': [
        for (final variable in _system().variables)
          if (variable.key == '调查.暴露')
            {
              ...variable.toJson(),
              'visibility': 'fuzzy',
              'stages': [
                {'min': 0, 'label': '平静'},
                {'min': 5, 'label': '戒备'},
              ]
            }
          else
            variable.toJson(),
      ]
    });
    await tester.pumpWidget(_host(GameplaySystemReadout(
        system: system,
        state: _state(system).copyWith(
          customVariables: {...system.initialValues(), '调查.暴露': 9},
        ))));
    expect(find.text('戒备'), findsOneWidget);
    expect(find.text('9'), findsNothing);
  });

  testWidgets('rehearsal advances time and rules without mutating saved state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final system = _system();
    final original = _state(system);
    final before = jsonEncode(original.toJson());
    await tester.pumpWidget(MaterialApp(
        home: GameplayRehearsalDialog(system: system, state: original)));
    await tester.tap(find.text('推进时间并结算'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已预演 1 回合'), findsOneWidget);
    expect(find.textContaining('距离换班：0 → 1'), findsOneWidget);
    expect(find.textContaining('交涉筹码：10 → 8'), findsOneWidget);
    expect(find.textContaining('等待换班会带来新的巡逻'), findsWidgets);
    expect(jsonEncode(original.toJson()), before);
    expect(original.gameplayRuntime.turn, 0);
    expect(original.customVariables['调查.时钟'], 0);
    await tester.tap(find.text('同一时段再一回合'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已预演 2 回合'), findsOneWidget);
    expect(jsonEncode(original.toJson()), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('variable editor rejects invalid value and returns a draft only',
      (tester) async {
    Map<String, dynamic>? result;
    final variable = _system().variables.first;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async {
                    result = await editGameplayVariable(context, variable);
                  },
                  child: const Text('编辑'),
                )))));
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '开局值'), '200');
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    expect(find.textContaining('超出了变量范围'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(find.widgetWithText(TextField, '开局值'), '4');
    await tester.enterText(find.widgetWithText(TextField, '玩家说明'), '拜访证人会留下痕迹');
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    expect(result?['initialValue'], 4);
    expect(result?['playerHint'], '拜访证人会留下痕迹');
    expect(variable.initialValue, 0);
  });

  testWidgets('author checks differences before returning an applied draft',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final current = _system();
    final generated = GameplaySystem.fromJson({
      ...current.toJson(),
      'title': '新版雾港',
      'variables': [
        for (final variable in current.variables)
          {...variable.toJson(), 'label': '新${variable.label}'},
      ]
    });
    GameplaySystem? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async {
                    result = await showDialog<GameplaySystem>(
                        context: context,
                        builder: (_) => GameplayAuthorDialog(
                              current: current,
                              generated: generated,
                              state: _state(current),
                            ));
                  },
                  child: const Text('打开草稿'),
                )))));
    await tester.tap(find.text('打开草稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑玩法概述'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '玩法名称'), '手工雾港');
    await tester.tap(find.text('保存到草稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '调查'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查并应用'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('应用这份玩法草稿？'), findsOneWidget);
    expect(find.textContaining('雾港调查 → 手工雾港'), findsWidgets);
    await tester.tap(find.text('应用到剧场'));
    await tester.pumpAndSettle();
    expect(result?.title, '手工雾港');
    expect(result?.variableFor('调查.暴露')?.label, '暴露程度');
    expect(result?.variableFor('局势.筹码')?.label, '新交涉筹码');
    expect(current.title, '雾港调查');
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('CAPTURE_GAMEPLAY')) {
    for (final width in [360.0, 1200.0]) {
      testWidgets('capture gameplay player and rehearsal ${width.toInt()}',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final loader = FontLoader('GameplayPreview')
            ..addFont(
                rootBundle.load('assets/fonts/SourceHanSansSC-Regular.otf'));
          await loader.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
        final system = _system();
        final boundary = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: _host(
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GameplaySystemReadout(
                      system: system, state: _state(system)),
                ),
                preview: true)));
        await tester.pumpAndSettle();
        await _capture(tester, boundary, 'player-${width.toInt()}');
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(fontFamily: 'GameplayPreview'),
                home: GameplayRehearsalDialog(
                    system: system, state: _state(system)))));
        await tester.pumpAndSettle();
        await _capture(tester, boundary, 'rehearsal-${width.toInt()}');

        final stagedSystem = GameplaySystem.fromJson({
          ...system.toJson(),
          'rules': [
            {
              ...system.rules.first.toJson(),
              'threads': [
                {
                  'op': 'open',
                  'id': 'dock_promise',
                  'title': '答应替船工保密',
                  'description': '证词刊出时隐去船工身份，换取进入旧码头的机会。',
                  'reason': '换班时获得证词并作出了保密承诺',
                  'visibility': 'public'
                },
              ]
            },
          ]
        });
        final settled = GameplayTurnEngine.apply(
          system: stagedSystem,
          previousState: _state(stagedSystem),
          narrativeState: _state(stagedSystem).copyWith(timeLabel: '上午'),
          content: '[THEATER_PATCH]{"ops":[]}[/THEATER_PATCH]',
          turnId: 'preview-settled',
        );
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: _host(
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: GameplaySystemReadout(
                      system: stagedSystem, state: settled)),
              preview: true,
            )));
        await tester.pumpAndSettle();
        await _capture(tester, boundary, 'player-settled-${width.toInt()}');
        await tester.ensureVisible(find.text('答应替船工保密'));
        await tester.pumpAndSettle();
        await _capture(tester, boundary, 'player-ledger-${width.toInt()}');

        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'GameplayPreview'),
              home: GameplayAuthorDialog(
                  current: system, generated: stagedSystem, state: settled),
            )));
        await tester.pumpAndSettle();
        await _capture(tester, boundary, 'author-${width.toInt()}');
        await tester.ensureVisible(find.text('应用后会发生什么'));
        await tester.pumpAndSettle();
        await _capture(tester, boundary, 'author-review-${width.toInt()}');
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Widget _host(Widget child, {bool preview = false}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: preview ? ThemeData(fontFamily: 'GameplayPreview') : null,
    home: Scaffold(body: SingleChildScrollView(child: child)));

ChatMessage _message(String id, List<String> changes) => ChatMessage(
      id: id,
      role: ChatRole.assistant,
      content: '剧情正文',
      timestamp: DateTime(2026),
      isSummarized: false,
      gameStateSnapshot: {
        'gameplayPlayerVariableChanges': changes,
        'gameplayVariableChanges': ['幕后凶手是谁'],
        'gameplayVariableWarnings': ['幕后凶手校验']
      },
    );

GameplaySystem _system() => GameplaySystem(
      schemaVersion: 3,
      title: '雾港调查',
      summary: '用有限时间换取证词，承担留下痕迹的后果。',
      coreLoop: '走访证人 → 消耗筹码并推进时间 → 换取进入码头的机会。',
      generatedAt: DateTime(2026),
      variables: const [
        GameplayVariableDefinition(
            key: '调查.暴露',
            label: '暴露程度',
            group: '调查',
            type: GameplayVariableType.number,
            visibility: GameplayVariableVisibility.public,
            authority: GameplayVariableAuthority.ai,
            initialValue: 0,
            min: 0,
            max: 10,
            maxDelta: 2,
            description: '幕后凶手藏在警署',
            playerHint: '低调调查可以降低暴露',
            isCore: true),
        GameplayVariableDefinition(
            key: '调查.时钟',
            label: '距离换班',
            group: '调查',
            type: GameplayVariableType.clock,
            visibility: GameplayVariableVisibility.public,
            authority: GameplayVariableAuthority.rule,
            initialValue: 0,
            min: 0,
            max: 6,
            description: '每个实际时段推进一次',
            playerHint: '调查行动推进时间，换班后会出现新机会',
            advanceOnTimeChange: 1),
        GameplayVariableDefinition(
            key: '局势.筹码',
            label: '交涉筹码',
            group: '局势',
            type: GameplayVariableType.number,
            visibility: GameplayVariableVisibility.public,
            authority: GameplayVariableAuthority.ai,
            initialValue: 10,
            min: 0,
            max: 20,
            maxDelta: 3,
            description: '用于交换证词',
            playerHint: '深入打听可能需要付出筹码'),
        GameplayVariableDefinition(
            key: '局势.暗线',
            label: '警署暗线',
            group: '局势',
            type: GameplayVariableType.boolean,
            visibility: GameplayVariableVisibility.director,
            authority: GameplayVariableAuthority.rule,
            initialValue: false,
            description: '警署暗线的追捕命令'),
      ],
      rules: const [
        GameplayRuleDefinition(
          id: 'shift',
          title: '码头换班',
          when: '时钟达到一个时段',
          effect: '秘密追捕名单已下发',
          visibility: GameplayVariableVisibility.public,
          playerSummary: '等待换班会带来新的巡逻',
          conditions: [GameplayCondition(path: '调查.时钟', op: 'gte', value: 1)],
          costs: [GameplayRuleCost(path: '局势.筹码', amount: 2)],
          effects: [GameplayRuleEffect(op: 'set', path: '局势.暗线', value: true)],
        )
      ],
    );

GameStateSnapshot _state(GameplaySystem system) => GameStateSnapshot(
      characterId: 'theater',
      updatedAt: DateTime(2026),
      timeLabel: '清晨',
      customVariables: system.initialValues(),
    );

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('.tmp/gameplay-previews');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
