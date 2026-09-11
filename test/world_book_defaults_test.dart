import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/world_book.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default world book protects player agency and continuity', () {
    final entry = WorldBookEntry.defaultEntry();

    expect(entry.title, '默认创作规则');
    expect(entry.content, contains('不替玩家决定'));
    expect(entry.content, contains('保持连续'));
    expect(entry.content, isNot(contains('可以生成成年人之间')));
  });

  test('untouched legacy default world book migrates on initialization',
      () async {
    final legacy = WorldBookEntry(
      id: WorldBookEntry.defaultEntry().id,
      title: '默认内容边界',
      content: legacyDefaultWorldBookContent.trim(),
      global: true,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'world_books': jsonEncode(<Map<String, dynamic>>[legacy.toJson()]),
    });
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    final migrated = controller.worldBooks.firstWhere(
      (entry) => entry.id == WorldBookEntry.defaultEntry().id,
    );
    expect(migrated.title, '默认创作规则');
    expect(migrated.content, defaultWorldBookContent.trim());
  });
}
