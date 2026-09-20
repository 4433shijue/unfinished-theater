import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/services/gameplay_turn_engine.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_history_dialog.dart';
import 'package:ai_roleplay_chat/widgets/gameplay_system_readout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reading another branch history does not select it or write state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final data = _fixture(2);
    final history =
        DialogueHistory(characterId: 'other-branch', messages: data.messages);
    await store.saveDialogueHistory(history);
    await store.saveGameState(data.state.copyWith(characterId: 'other-branch'));
    final controller = AppStateController(
        store: store,
        apiClient: LlmApiClient(),
        memoryService: MemoryService());
    addTearDown(controller.dispose);
    final selected = controller.selectedCharacterId;
    final read = await controller.gameplayHistoryContextFor('other-branch');
    expect(read.history.messages.last.id, 'reply-2');
    expect(read.state.customVariables['调查.戒备'], 2);
    expect(controller.selectedCharacterId, selected);
    expect((await store.loadDialogueHistory('other-branch')).toJson(),
        history.toJson());
  });

  testWidgets(
      'live variable cards open history; rehearsal cards stay read-only',
      (tester) async {
    final data = _fixture(1);
    String? tapped;
    await tester.pumpWidget(_host(SingleChildScrollView(
      child: GameplaySystemReadout(
        system: data.system,
        state: data.state,
        onVariableTap: (variable) => tapped = variable.key,
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('variable-history-调查.戒备')));
    expect(tapped, '调查.戒备');
    await tester.pumpWidget(_host(SingleChildScrollView(
      child: GameplaySystemReadout(system: data.system, state: data.state),
    )));
    expect(find.byKey(const ValueKey('variable-history-调查.戒备')), findsNothing);
  });

  testWidgets('history paginates and opens the exact original branch turn',
      (tester) async {
    final data = _fixture(12);
    await tester.pumpWidget(_host(_dialog(data)));
    expect(
        find.byKey(const ValueKey('history-source-reply-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-source-reply-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('history-source-reply-12')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('source-message-reply-12')), findsOneWidget);
    expect(find.textContaining('第12次走访，证人收起了伞。'), findsWidgets);
    expect(find.textContaining('秘密门牌'), findsNothing);
    await tester.tap(find.text('上一回合'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('source-message-reply-11')), findsOneWidget);
    await tester.tap(find.text('返回记录'));
    await tester.pumpAndSettle();
    // Reopen the read-only view so pagination is tested independently of the
    // source-dialog navigation state.
    await tester.pumpWidget(_host(_dialog(data)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gameplay-history-more')),
      280,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('gameplay-history-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gameplay-history-more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('history-source-reply-1')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('gameplay-history-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
        find.byKey(const ValueKey('history-source-reply-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('gameplay-history-more')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden current variables cannot be viewed through the dialog',
      (tester) async {
    final data = _fixture(2);
    await tester.pumpWidget(_host(GameplayHistoryDialog(
      system: data.system,
      state: data.state,
      messages: data.messages,
      path: '调查.暗线',
      storyName: '雾港',
    )));
    expect(find.text('当前没有可查看的状态。'), findsOneWidget);
    expect(find.textContaining('秘密门牌'), findsNothing);
    expect(find.textContaining('幕后联系人'), findsNothing);
  });

  testWidgets('empty and removed source records have clear read-only states',
      (tester) async {
    final data = _fixture(0);
    await tester.pumpWidget(_host(_dialog(data)));
    expect(find.textContaining('还没有可回溯的变化'), findsOneWidget);
    await tester.pumpWidget(_host(const GameplaySourceDialog(
      messages: [],
      messageId: 'removed',
      storyName: '雾港',
    )));
    expect(find.text('对应消息已不在当前分支中。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800)
  ]) {
    testWidgets('history layout ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = Platform.environment['CAPTURE_GAMEPLAY_TOOLS'] == '1';
      if (capture) {
        await (FontLoader('GameplayPreview')
              ..addFont(
                  rootBundle.load('assets/fonts/SourceHanSansSC-Regular.otf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: _host(_dialog(_fixture(3)), capture: capture)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (capture) await _capture(tester, key, 'history-${size.width.toInt()}');
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('history-source-reply-3'))),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('history-source-reply-3')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('source-message-reply-3')), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (capture) await _capture(tester, key, 'source-${size.width.toInt()}');
    });
  }
}

typedef _Data = ({
  GameplaySystem system,
  GameStateSnapshot state,
  List<ChatMessage> messages
});

_Data _fixture(int turns) {
  final system = GameplaySystem(
    schemaVersion: 3,
    title: '雾港调查',
    summary: '追查码头失踪案',
    coreLoop: '询问证人，留意戒备变化。',
    generatedAt: DateTime(2026, 9, 20),
    variables: const [
      GameplayVariableDefinition(
          key: '调查.戒备',
          label: '戒备程度',
          group: '调查',
          type: GameplayVariableType.number,
          visibility: GameplayVariableVisibility.public,
          authority: GameplayVariableAuthority.ai,
          initialValue: 0,
          min: 0,
          max: 100,
          maxDelta: 5,
          description: '盘问引起注意',
          playerHint: '低调走访可以减少暴露。',
          isCore: true),
      GameplayVariableDefinition(
          key: '调查.暗线',
          label: '幕后联系人',
          group: '调查',
          type: GameplayVariableType.text,
          visibility: GameplayVariableVisibility.director,
          authority: GameplayVariableAuthority.ai,
          initialValue: '秘密门牌',
          description: '不能泄露'),
    ],
    rules: const [],
  );
  var state = GameStateSnapshot(
      characterId: 'theater',
      updatedAt: DateTime(2026, 9, 20),
      customVariables: system.initialValues());
  final messages = <ChatMessage>[];
  for (var i = 1; i <= turns; i++) {
    final content = '第$i次走访，证人收起了伞。\n'
        '[THEATER_PATCH]${jsonEncode({
          'ops': [
            {'op': 'inc', 'path': '调查.戒备', 'value': 1, 'reason': '走访引起了巡逻者的注意'}
          ],
          'private': '秘密门牌'
        })}[/THEATER_PATCH]';
    state = GameplayTurnEngine.apply(
        system: system,
        previousState: state,
        narrativeState: state,
        content: content,
        turnId: 'reply-$i');
    messages.add(ChatMessage(
        id: 'input-$i',
        role: ChatRole.user,
        content: '我去寻找第$i位证人。',
        timestamp: DateTime(2026, 9, 20, 10, i),
        isSummarized: false));
    messages.add(ChatMessage(
        id: 'reply-$i',
        role: ChatRole.assistant,
        content: content,
        timestamp: DateTime(2026, 9, 20, 10, i),
        isSummarized: false,
        gameStateSnapshot: {
          ...state.toJson(),
          'gameplaySystem': system.toJson()
        }));
  }
  return (system: system, state: state, messages: messages);
}

Widget _dialog(_Data data) => GameplayHistoryDialog(
    system: data.system,
    state: data.state,
    messages: data.messages,
    path: '调查.戒备',
    storyName: '雾港调查 · 雨夜分支');

Widget _host(Widget child, {bool capture = false}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          fontFamily: capture ? 'GameplayPreview' : null,
          colorSchemeSeed: const Color(0xff486764)),
      home: Scaffold(body: child),
    );

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('.tmp/gameplay-tools-previews');
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
