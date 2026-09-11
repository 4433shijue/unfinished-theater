import 'package:flutter_test/flutter_test.dart';

import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/map_state.dart';
import 'package:ai_roleplay_chat/models/world_book.dart';
import 'package:ai_roleplay_chat/services/story_insight_service.dart';

void main() {
  test('previews active world books from current context', () {
    final entries = <WorldBookEntry>[
      WorldBookEntry(
        title: '天台规则',
        content: '天台上不能高声说话。',
        global: false,
        boundCharacterIds: const <String>['char-1'],
        triggerMode: WorldBookTriggerMode.keyword,
        keywords: const <String>['天台'],
        priority: 80,
      ),
      WorldBookEntry(
        title: '医务室规则',
        content: '医务室总是锁门。',
        global: false,
        boundCharacterIds: const <String>['char-1'],
        triggerMode: WorldBookTriggerMode.keyword,
        keywords: const <String>['医务室'],
        priority: 40,
      ),
    ];

    final preview = StoryInsightService.previewWorldBooks(
      entries: entries,
      characterId: 'char-1',
      rootCharacterId: 'char-1',
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '去天台看看。',
          timestamp: DateTime(2026),
          isSummarized: false,
        ),
      ],
      gameState: GameStateSnapshot.empty('char-1').copyWith(location: '天台'),
      runtimeAddendum: '',
    );

    expect(preview.first.title, '天台规则');
    expect(preview.first.active, isTrue);
    expect(preview.last.title, '医务室规则');
    expect(preview.last.active, isFalse);
  });

  test('builds map objective board from map state', () {
    final mapState = MapWorldState.empty('char-1').copyWith(
      mainGoal: '查清广播来源',
      currentLocationId: 'roof',
      currentLocationName: '天台',
      discoveredClues: const <String>['旧录音带'],
      locations: <MapLocationNode>[
        MapLocationNode(
          id: 'roof',
          name: '天台',
          riskLevel: '中',
          clues: const <String>['生锈门锁'],
          npcs: const <String>['林澈'],
        ),
      ],
      activeChoices: const <MapStoryChoice>[
        MapStoryChoice(id: 'c1', label: '检查广播线'),
      ],
    );

    final board = StoryInsightService.buildMapObjectiveBoard(
      gameState: GameStateSnapshot.empty('char-1'),
      mapState: mapState,
    );

    expect(board.mainGoal, '查清广播来源');
    expect(board.currentLocation, '天台');
    expect(board.clues, containsAll(<String>['旧录音带', '生锈门锁']));
    expect(board.relatedNpcs, contains('林澈'));
    expect(board.nextActions, contains('检查广播线'));
  });
}
