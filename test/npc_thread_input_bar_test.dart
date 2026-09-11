import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/screens/npc_chats_screen.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/widgets/chat_input_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 回归测试：NPC 私聊线程页输入栏曾因与主聊天共用教程 GlobalKey
  // （chatInput/chatSend/chatLaunch）而在压栈路由下被截断消失。
  testWidgets('npc thread input bar survives push over main chat',
      (tester) async {
    final character = _character();
    final npc = NpcProfile(
      id: 'npc-1',
      characterId: character.id,
      name: '测试 NPC',
      description: '一个测试用 NPC。',
      createdAt: DateTime(2026, 8, 18),
      updatedAt: DateTime(2026, 8, 18),
      sourceType: NpcProfileSource.manual,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(_settings().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[npc.toJson()]),
    });

    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: _FakeClient()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await controller.initialize();

    // 模拟真实场景：主聊天页（带 ChatInputBar）仍在导航栈里，
    // NPC 线程页作为新路由压在上面。
    await tester.pumpWidget(
      ChangeNotifierProvider<AppStateController>.value(
        value: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NpcChatThreadScreen(
                              npcId: 'npc-1',
                            ),
                          ),
                        ),
                        child: const Text('打开 NPC 私聊'),
                      ),
                    ),
                  ),
                  // 主聊天的输入栏，与 NPC 线程共用 TutorialTargetId.chatInput
                  ChatInputBar(
                    isSending: false,
                    canPause: false,
                    hasPendingMessages: false,
                    onSend: (_) async {},
                    onLaunch: () async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开 NPC 私聊'));
    await tester.pumpAndSettle();

    // 线程页已打开：能看到 NPC 头部卡片
    expect(find.textContaining('和 测试 NPC 私聊'), findsOneWidget);

    // 修复验证：NPC 线程页（onstage）的输入栏完整渲染——
    // 文本框 + 发送键 + 小飞机 + 加号都在；主聊天那条 offstage
    // 路由的输入栏不会被 finder 计入。
    final inputBar = find.byType(ChatInputBar);
    expect(inputBar, findsOneWidget);
    final allInputBars = find.byType(ChatInputBar, skipOffstage: false);
    expect(allInputBars, findsNWidgets(2));
    final inputBarWidgets = tester.widgetList<ChatInputBar>(allInputBars);
    expect(
      inputBarWidgets.where((bar) => bar.tutorialTargetsEnabled),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    final textFields = find.byType(TextField);
    expect(textFields, findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.near_me_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.enterText(textFields, '你好');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    final messages = controller.npcMessagesFor(npc.id);
    expect(messages, hasLength(1));
    expect(messages.single.content, '你好');
  });

  testWidgets('dead npc thread explains and disables private chat',
      (tester) async {
    final character = _character();
    final npc = NpcProfile(
      id: 'npc-dead',
      characterId: character.id,
      name: '旧友',
      lifecycle: NpcLifecycle.dead,
      createdAt: DateTime(2026, 8, 20),
      updatedAt: DateTime(2026, 8, 20),
      sourceType: NpcProfileSource.manual,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(_settings().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[npc.toJson()]),
    });
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: _FakeClient()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppStateController>.value(
        value: controller,
        child: const MaterialApp(
          home: NpcChatThreadScreen(npcId: 'npc-dead'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('私聊与好感已冻结'), findsWidgets);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.add_rounded))
          .onPressed,
      isNull,
    );
  });
}

AppSettings _settings() {
  return AppSettings.initial().copyWith(
    apiUrl: 'https://example.test',
    apiKey: 'test-key',
    modelName: 'test-model',
  );
}

CharacterProfile _character() {
  return CharacterProfile(
    id: 'char-1',
    name: '测试角色',
    createdAt: DateTime(2026, 8, 18),
    prompt: '扮演一个测试角色。',
    modelParams: ModelParams.defaults(),
  );
}

class _FakeClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      200,
      headers: const <String, String>{'content-type': 'text/event-stream'},
    );
  }
}
