import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/models/npc_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applies game state update into NPC runtime fields', () {
    final profile = NpcProfile(
      id: 'npc-1',
      characterId: 'char-1',
      name: '林夏',
      createdAt: DateTime(2026, 5, 21),
      updatedAt: DateTime(2026, 5, 21),
      description: '旧友',
      affinity: 42,
    );
    final state = GameStateSnapshot(
      characterId: 'char-1',
      updatedAt: DateTime(2026, 5, 21),
      location: '天台',
      status: 'happy after reunion',
      mainTask: '确认失踪线索',
      eventTitle: '重逢',
      eventDescription: '林夏把钥匙交给主角。',
    );
    const update = GameNpcUpdate(
      name: '林夏',
      impression: 'trusts the player',
      affinityDelta: 4,
    );

    final patch = const NpcRuntimeEngine().applyGameStateUpdate(
      profile: profile,
      characterId: 'char-1',
      state: state,
      update: update,
    );

    expect(patch.profile.runtimeState.location, '天台');
    expect(patch.profile.runtimeState.currentGoal, '确认失踪线索');
    expect(patch.profile.runtimeState.trust, 0);
    expect(patch.profile.npcMemory, hasLength(1));
    expect(patch.profile.relationshipEdges.single.targetId, 'player');
    expect(patch.profile.relationshipEdges.single.score, 42);
    expect(patch.profile.worldEvents.single.title, '重逢');
  });
}
