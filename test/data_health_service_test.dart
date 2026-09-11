import 'package:flutter_test/flutter_test.dart';

import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/data_management.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/map_state.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_migration.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/models/world_book.dart';
import 'package:ai_roleplay_chat/services/data_health_service.dart';

void main() {
  test('reports repairable broken bindings and map pointers', () {
    final character = CharacterProfile(
      id: 'char-1',
      name: '主角',
      description: '',
      prompt: '',
      modelParams: ModelParams.defaults(),
      createdAt: DateTime(2026),
    );
    final npc = NpcProfile(
      id: 'npc-1',
      characterId: 'missing-owner',
      name: '林澈',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      boundCharacterIds: const <String>['char-1', 'missing-bound'],
    );
    final worldBook = WorldBookEntry(
      title: '旧规则',
      content: '内容',
      global: false,
      boundCharacterIds: const <String>['missing-bound'],
    );
    final mapState = MapWorldState.empty('char-1').copyWith(
      currentLocationId: 'missing-location',
      locations: <MapLocationNode>[
        MapLocationNode(id: 'room', name: '教室'),
      ],
    );

    final report = DataHealthService.inspect(
      characters: <CharacterProfile>[character],
      npcs: <NpcProfile>[npc],
      migrations: const <NpcMigrationRecord>[],
      worldBooks: <WorldBookEntry>[worldBook],
      snapshots: const <SaveSnapshot>[],
      histories: <DialogueHistory>[DialogueHistory.empty('orphan')],
      gameStates: <GameStateSnapshot>[GameStateSnapshot.empty('orphan')],
      mapStates: <MapWorldState>[mapState],
    );

    expect(report.repairableCount, greaterThanOrEqualTo(4));
    expect(report.issues.map((item) => item.title).join('\n'),
        contains('地图当前位置断链'));
    expect(report.issues.map((item) => item.title).join('\n'),
        contains('世界书绑定断链'));
  });
}
