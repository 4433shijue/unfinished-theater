import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/data_management.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt character data is quarantined before safe defaults are used',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'characters': '{not-json',
    });
    final store = LocalStore();
    final controller = AppStateController(
      store: store,
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.hasInitializationError, isTrue);
    expect(controller.characters, isEmpty);
    expect(controller.quarantinedDataRecords, hasLength(1));
    expect(controller.quarantinedDataRecords.single.rawValue, '{not-json');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('characters'), isFalse);

    await controller.retryInitialization();

    expect(controller.hasInitializationError, isFalse);
    expect(controller.characters, isNotEmpty);
    expect(controller.quarantinedDataRecords, hasLength(1));
  });

  test('pending turn journal replays history and game state together',
      () async {
    final history = DialogueHistory(
      characterId: 'char-1',
      messages: <ChatMessage>[
        ChatMessage(
          id: 'message-1',
          role: ChatRole.assistant,
          content: '已经提交的回复',
          timestamp: DateTime(2026),
          isSummarized: false,
        ),
      ],
    );
    final gameState = GameStateSnapshot.empty('char-1').copyWith(
      metrics: const <String, int>{'压力': 42},
      updatedAt: DateTime(2026),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'turn_commit_char-1': jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'characterId': 'char-1',
        'createdAt': DateTime(2026).toIso8601String(),
        'history': history.toJson(),
        'gameState': gameState.toJson(),
      }),
    });
    final store = LocalStore();

    await store.recoverPendingTurnCommits();

    final recoveredHistory = await store.loadDialogueHistory('char-1');
    final recoveredState = await store.loadGameState('char-1');
    final prefs = await SharedPreferences.getInstance();
    expect(recoveredHistory.messages.single.content, '已经提交的回复');
    expect(recoveredState.metrics['压力'], 42);
    expect(prefs.containsKey('turn_commit_char-1'), isFalse);
  });

  test('completed turn commit removes its journal', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LocalStore();
    final history = DialogueHistory(
      characterId: 'char-2',
      messages: <ChatMessage>[
        ChatMessage(
          id: 'message-2',
          role: ChatRole.user,
          content: '继续',
          timestamp: DateTime(2026),
          isSummarized: false,
        ),
      ],
    );

    await store.commitTurnState(
      history: history,
      gameState: GameStateSnapshot.empty('char-2'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('turn_commit_char-2'), isFalse);
    expect(
      (await store.loadDialogueHistory('char-2')).messages.single.content,
      '继续',
    );
  });

  test('pending archive batch finishes all writes and deletions', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'history_old': '{"characterId":"old","messages":[]}',
      'storage_batch_archive_import': jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'writes': <String, dynamic>{
          'characters': '[]',
          'selected_character_id': 'char-new',
          'history_old': null,
        },
      }),
    });
    final store = LocalStore();

    await store.recoverPendingTurnCommits();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('characters'), '[]');
    expect(prefs.getString('selected_character_id'), 'char-new');
    expect(prefs.containsKey('history_old'), isFalse);
    expect(prefs.containsKey('storage_batch_archive_import'), isFalse);
  });

  test('snapshot for a deleted theater remains available for recovery',
      () async {
    final snapshot = SaveSnapshot(
      id: 'snapshot-deleted',
      characterId: 'deleted-character',
      characterName: '已删除剧场',
      title: '自动保护 · 删除角色前',
      archiveJson: '{"payload":{}}',
      createdAt: DateTime(2026),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'save_snapshots': jsonEncode(<Map<String, dynamic>>[
        snapshot.toJson(),
      ]),
    });
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.recoverableSaveSnapshots, hasLength(1));

    await controller.repairDataHealthIssues();
    expect(controller.recoverableSaveSnapshots, hasLength(1));
  });
}
