import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/data/preset_characters.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('untouched legacy tutorial opening migrates to the new first scene',
      () async {
    final character = buildTutorialDemoCharacter(id: 'tutorial-existing');
    final history = DialogueHistory(
      characterId: character.id,
      messages: <ChatMessage>[
        _message(
          role: ChatRole.assistant,
          content: '新手教程模拟演示：NPC1、NPC2、NPC3 正在等待。',
        ),
      ],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(history.toJson()),
    });
    final controller = _controller();
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.currentHistory.messages, hasLength(1));
    expect(
      controller.currentHistory.messages.single.content.trim(),
      tutorialDemoOpeningMessage.trim(),
    );
  });

  test('tutorial history with player progress is preserved', () async {
    final character = buildTutorialDemoCharacter(id: 'tutorial-started');
    final history = DialogueHistory(
      characterId: character.id,
      messages: <ChatMessage>[
        _message(
          role: ChatRole.assistant,
          content: '新手教程模拟演示：NPC1、NPC2、NPC3 正在等待。',
        ),
        _message(role: ChatRole.user, content: '我想先体验故事。'),
      ],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(history.toJson()),
    });
    final controller = _controller();
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.currentHistory.messages, hasLength(2));
    expect(controller.currentHistory.messages.last.content, '我想先体验故事。');
  });
}

AppStateController _controller() {
  return AppStateController(
    store: LocalStore(),
    apiClient: LlmApiClient(),
    memoryService: MemoryService(),
  );
}

ChatMessage _message({required ChatRole role, required String content}) {
  return ChatMessage(
    id: '${role.name}-message',
    role: role,
    content: content,
    timestamp: DateTime(2026),
    isSummarized: true,
  );
}
