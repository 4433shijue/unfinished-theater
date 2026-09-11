import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/screens/chat_screen.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppTheme.registerRuntimeThemes(const <RuntimeThemeDefinition>[]);
    AppTheme.themeFor(AppThemeVariant.sakura.id);
  });

  test('choice preview stays ephemeral and receives canonical NPC state',
      () async {
    final client = _StoryUtilityClient();
    final controller = await _createController(client);
    addTearDown(controller.dispose);

    final error = await controller.generateConversationToolReply(
      'branch_preview',
      userRequest: '只预演 A 选项。',
      resultTitle: '选项预演 · A',
      persistResult: false,
    );

    expect(error, isNull);
    expect(controller.currentCharacterToolResults, isEmpty);
    expect(controller.lastGeneratedToolResult?.toolTitle, '选项预演 · A');
    expect(client.userPrompt, contains('只预演 A 选项'));
    expect(client.userPrompt, contains('ID：npc-chen'));
    expect(client.userPrompt, contains('生命周期 已故'));

    final legacyError =
        await controller.generateConversationToolReply('forum_burst');
    expect(legacyError, isNull);
    expect(controller.currentCharacterToolResults, hasLength(1));
    expect(controller.currentCharacterToolResults.single.toolTitle, '世界动态');
  });

  testWidgets('desktop chat consolidates story tools and NPC inbox',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _createController(_StoryUtilityClient());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    expect(find.text(AppTheme.glitchText('故事')), findsOneWidget);
    expect(find.text(AppTheme.glitchText('剧情导演台')), findsNothing);
    expect(find.text(AppTheme.glitchText('世界事件日历')), findsNothing);
    expect(find.text(AppTheme.glitchText('剧情洞察')), findsNothing);
    expect(find.text(AppTheme.glitchText('剧情工具')), findsNothing);
    expect(find.byTooltip(AppTheme.glitchText('预演这个选项')), findsNWidgets(2));
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    await tester.tap(find.text(AppTheme.glitchText('故事')));
    await tester.pumpAndSettle();
    for (final label in <String>['概览', '人物', '线索', '番外']) {
      expect(find.text(AppTheme.glitchText(label)), findsOneWidget);
    }
    await tester.tap(find.text(AppTheme.glitchText('番外')));
    await tester.pumpAndSettle();
    expect(find.text(AppTheme.glitchText('同人文')), findsWidgets);
    expect(find.text(AppTheme.glitchText('NPC 日记')), findsWidgets);
    expect(find.text(AppTheme.glitchText('世界动态')), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppTheme.glitchText('NPC私聊')));
    await tester.pumpAndSettle();
    expect(find.text(AppTheme.glitchText('私聊')), findsOneWidget);
    expect(find.text(AppTheme.glitchText('来信')), findsOneWidget);
    expect(find.byTooltip(AppTheme.glitchText('写 NPC 日记')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('game hub no longer owns the NPC inbox', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _createController(_StoryUtilityClient());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('小游戏中心 ·'));
    await tester.pumpAndSettle();
    expect(find.text(AppTheme.glitchText('来信箱')), findsNothing);
    expect(find.text(AppTheme.glitchText('今日随机来信')), findsNothing);
    expect(find.text(AppTheme.glitchText('成就')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<AppStateController> _createController(
  _StoryUtilityClient client,
) async {
  final character = CharacterProfile(
    id: 'story-workspace-character',
    name: '陈放',
    createdAt: DateTime(2026, 8, 20),
    prompt: '在旧城调查异常事件。',
    modelParams: ModelParams.defaults(),
  );
  final history = DialogueHistory(
    characterId: character.id,
    messages: <ChatMessage>[
      ChatMessage(
        id: 'assistant-choice',
        role: ChatRole.assistant,
        content: '''夜色压低，岔路就在眼前。

[CHOICES]
A｜进入旧站台
B｜留在原地观察
[/CHOICES]''',
        timestamp: DateTime(2026, 8, 20, 20),
        isSummarized: false,
      ),
    ],
  );
  final npc = NpcProfile(
    id: 'npc-chen',
    characterId: character.id,
    name: '陈放',
    createdAt: DateTime(2026, 8, 20),
    updatedAt: DateTime(2026, 8, 20),
    affinity: -3,
    lifecycle: NpcLifecycle.dead,
    impression: '仍有未解的旧事。',
  );
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_settings': jsonEncode(
      AppSettings.initial()
          .copyWith(
            apiUrl: 'https://example.invalid/v1',
            apiKey: 'test-key',
            modelName: 'test-model',
          )
          .toJson(),
    ),
    'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
    'selected_character_id': character.id,
    'history_${character.id}': jsonEncode(history.toJson()),
    'npc_profiles': jsonEncode(<Map<String, dynamic>>[npc.toJson()]),
  });
  final controller = AppStateController(
    store: LocalStore(),
    apiClient: client,
    memoryService: MemoryService(),
  );
  await controller.initialize();
  return controller;
}

Widget _testApp(AppStateController controller) {
  return ChangeNotifierProvider<AppStateController>.value(
    value: controller,
    child: MaterialApp(
      theme: AppTheme.themeFor(controller.settings.themeId),
      home: const Scaffold(body: ChatScreen()),
    ),
  );
}

class _StoryUtilityClient extends LlmApiClient {
  String userPrompt = '';

  @override
  Future<String> runUtilityTask({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.45,
    double topP = 0.9,
    int maxTokens = 8192,
    LlmCancellationToken? cancellationToken,
  }) async {
    this.userPrompt = userPrompt;
    return '<section><h1>生成结果</h1><p>仅供预览。</p></section>';
  }
}
