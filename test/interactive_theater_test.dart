import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/interactive_theater.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/tool_result.dart';
import 'package:ai_roleplay_chat/screens/chat_screen.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('interactive theater request supports single, multi, and custom modes',
      () {
    const single = InteractiveTheaterRequest(
      selectionMode: InteractiveTheaterSelectionMode.single,
      kinds: <InteractiveTheaterKind>[InteractiveTheaterKind.branchingDrama],
    );
    expect(single.isValid, isTrue);
    expect(single.toPrompt(), contains('单选小剧场'));
    expect(single.toPrompt(), contains('分支短剧'));

    const multi = InteractiveTheaterRequest(
      selectionMode: InteractiveTheaterSelectionMode.multi,
      kinds: <InteractiveTheaterKind>[
        InteractiveTheaterKind.chatEasterEgg,
        InteractiveTheaterKind.objectExploration,
      ],
      customPrompt: '让雨夜便利店里的人都各自误会一句话。',
    );
    expect(multi.toPrompt(), contains('多选小剧场'));
    expect(multi.toPrompt(), contains('群聊彩蛋'));
    expect(multi.toPrompt(), contains('雨夜便利店'));

    const customOnly = InteractiveTheaterRequest(
      selectionMode: InteractiveTheaterSelectionMode.single,
      kinds: <InteractiveTheaterKind>[],
      customPrompt: '做一段三步的猫咪照顾小游戏。',
    );
    expect(customOnly.isValid, isTrue);
    expect(customOnly.displayTitle, '自定义互动小剧场');
  });

  test('interactive theater metadata survives local serialization', () {
    final original = ToolResultForTest.create();
    final decoded = ToolResultForTest.roundTrip(original);

    expect(decoded.isInteractiveTheater, isTrue);
    expect(decoded.theaterSelectionMode, 'multi');
    expect(decoded.theaterKinds, contains('light_game'));
    expect(decoded.theaterPrompt, contains('猫咪'));
    expect(decoded.theaterStep, 2);
  });

  test('interactive theater stores its result without changing main history',
      () async {
    final client = _InteractiveTheaterClient();
    final character = CharacterProfile(
      id: 'interactive-theater-character',
      name: '雨夜调查员',
      createdAt: DateTime(2026, 9, 27),
      prompt: '在旧城寻找失踪的猫。',
      modelParams: ModelParams.defaults(),
    );
    final history = DialogueHistory(
      characterId: character.id,
      messages: <ChatMessage>[
        ChatMessage(
          id: 'mainline-message',
          role: ChatRole.assistant,
          content: '主线仍停在便利店门口。',
          timestamp: DateTime(2026, 9, 27, 20),
          isSummarized: false,
        ),
      ],
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
    });
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: client,
      memoryService: MemoryService(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    final request = InteractiveTheaterRequest(
      selectionMode: InteractiveTheaterSelectionMode.multi,
      kinds: const <InteractiveTheaterKind>[
        InteractiveTheaterKind.chatEasterEgg,
        InteractiveTheaterKind.lightGame,
      ],
      customPrompt: '让两个人一起照顾一只猫。',
    );
    expect(
      await controller.generateInteractiveTheater(request: request),
      isNull,
    );
    final first = controller.lastGeneratedToolResult;
    expect(first?.isInteractiveTheater, isTrue);
    expect(first?.theaterSelectionMode, 'multi');
    expect(controller.currentHistory.messages, hasLength(1));
    expect(client.prompts.first, contains('不得推进主线'));
    expect(client.prompts.first, contains('data-theater-choice'));

    expect(
      await controller.continueInteractiveTheater(
        previous: first!,
        selections: const <String>['先给猫喂水', '让嘴硬的人负责找纸箱'],
      ),
      isNull,
    );
    expect(controller.lastGeneratedToolResult?.theaterStep, 1);
    expect(controller.currentHistory.messages, hasLength(1));
    expect(client.prompts.last, contains('先给猫喂水'));
  });

  testWidgets('interactive theater builder offers multi-select and an example',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppThemeVariant.sakura.id),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showInteractiveTheaterBuilderDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(AppTheme.glitchText('搭建互动小剧场')), findsOneWidget);
    await tester.tap(find.text(AppTheme.glitchText('多选小剧场')));
    await tester.tap(find.text(AppTheme.glitchText('填入示例')));
    await tester.pump();
    final promptField = tester.widget<TextField>(find.byType(TextField).last);
    expect(promptField.controller?.text, contains('迷路的小猫'));
    expect(find.text(AppTheme.glitchText('群聊彩蛋')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class ToolResultForTest {
  static ToolResult create() {
    return ToolResult(
      id: 'theater-result',
      characterId: 'character',
      toolId: 'interactive_theater',
      toolTitle: '猫咪夜班',
      content: '```html\n<html></html>\n```',
      createdAt: DateTime(2026, 9, 27),
      interactiveTheater: true,
      theaterSelectionMode: 'multi',
      theaterKinds: const <String>['light_game'],
      theaterPrompt: '让两个人照顾一只猫咪。',
      theaterStep: 2,
    );
  }

  static ToolResult roundTrip(ToolResult value) {
    return ToolResult.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value.toJson())) as Map),
    );
  }
}

class _InteractiveTheaterClient extends LlmApiClient {
  final List<String> prompts = <String>[];

  @override
  Stream<String> streamContent({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    double topP = 0.9,
    int maxTokens = 4096,
  }) async* {
    prompts.add(userPrompt);
    yield '''```html
<!doctype html>
<html><body>
<div data-theater-group="main" data-choice-mode="multi">
<button data-theater-choice="one" data-theater-label="先给猫喂水">喂水</button>
</div>
<button data-theater-submit="继续小剧场">继续</button>
</body></html>
```''';
  }
}
