import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_roleplay_chat/models/data_management.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/map_state.dart';
import 'package:ai_roleplay_chat/models/npc_migration.dart';
import 'package:ai_roleplay_chat/services/data_health_service.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';

void main() {
  group('NPC migration compatibility', () {
    test('legacy world-book records are not mistaken for new characters', () {
      final record = NpcMigrationRecord.fromJson(<String, dynamic>{
        'id': 'legacy-migration',
        'sourceCharacterId': 'source-character',
        'sourceCharacterName': '旧世界',
        'sourceNpcId': 'source-npc',
        'sourceNpcName': '林澈',
        'createdCharacterId': 'source-character',
        'createdCharacterName': '旧世界',
        'worldBookId': 'world-book',
        'worldBookTitle': '前尘',
        'worldType': '现代都市',
        'memoryMode': NpcMigrationMemoryMode.fragments,
        'archiveText': '旧版纯文本档案',
        'worldBookContent': '世界书正文',
        'createdAt': '2026-08-23T10:00:00.000',
      });

      expect(record.outputKind, NpcMigrationOutputKind.worldBookOnly);
      expect(record.createsCharacter, isFalse);
      expect(record.manifest.archive.summary, '旧版纯文本档案');
      expect(record.manifest.qualityWarnings, isNotEmpty);
    });

    test('structured manifest and echo status survive JSON round-trip', () {
      final record = _record(
        outputKind: NpcMigrationOutputKind.newWorld,
        createdCharacterId: 'new-character',
        manifest: const NpcMigrationManifest(
          schemaVersion: 1,
          archive: NpcMigrationArchiveData(
            summary: '两人曾共同守住灯塔。',
            continuityFacts: <String>['灯塔没有熄灭'],
          ),
          memoryPolicy: NpcMigrationMemoryPolicy(
            mode: NpcMigrationMemoryMode.echo,
            echoSeeds: <String>['雨夜的灯光'],
            forbiddenRecall: <String>['普通回合不得主动复述旧世界事实'],
          ),
          relationship: NpcMigrationRelationshipPlan(
            mode: NpcMigrationRelationshipLock.noRomance,
            hardConstraints: <String>['禁止恋爱化'],
          ),
          keepsake: NpcMigrationKeepsake(name: '旧钥匙'),
          tasks: <NpcMigrationTask>[
            NpcMigrationTask(id: 'task-1', title: '找到灯塔'),
          ],
        ),
        echoEvents: const <NpcMigrationEchoEvent>[
          NpcMigrationEchoEvent(
            id: 'echo-1',
            status: NpcMigrationEchoStatus.failed,
            errorMessage: '网络中断',
          ),
        ],
      );

      final json = record.toJson()
        ..['memoryMode'] = NpcMigrationMemoryMode.full
        ..['relationshipLock'] = NpcMigrationRelationshipLock.lover
        ..['keepsake'] = const NpcMigrationKeepsake(name: '错误副本').toJson();
      final restored = NpcMigrationRecord.fromJson(json);

      expect(restored.outputKind, NpcMigrationOutputKind.newWorld);
      expect(restored.createsCharacter, isTrue);
      expect(restored.memoryMode, NpcMigrationMemoryMode.echo);
      expect(restored.manifest.memoryPolicy.runtimeFacts, isEmpty);
      expect(restored.manifest.memoryPolicy.echoSeeds, <String>['雨夜的灯光']);
      expect(restored.relationshipLock, NpcMigrationRelationshipLock.noRomance);
      expect(restored.manifest.relationship.mode,
          NpcMigrationRelationshipLock.noRomance);
      expect(restored.keepsake.name, '旧钥匙');
      expect(restored.manifest.tasks.single.title, '找到灯塔');
      expect(restored.echoEvents.single.status, NpcMigrationEchoStatus.failed);
      expect(restored.echoEvents.single.errorMessage, '网络中断');
    });

    test('legacy echo events default to completed', () {
      final event = NpcMigrationEchoEvent.fromJson(<String, dynamic>{
        'id': 'legacy-echo',
        'summary': '听见了旧日钟声',
      });

      expect(event.status, NpcMigrationEchoStatus.completed);
      expect(event.errorMessage, isEmpty);
    });
  });

  test('world-book-only records persist without a created character', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LocalStore();
    final record = _record(
      outputKind: NpcMigrationOutputKind.worldBookOnly,
      createdCharacterId: '',
    );

    await store.saveNpcMigrations(<NpcMigrationRecord>[record]);
    final restored = await store.loadNpcMigrations();

    expect(restored, hasLength(1));
    expect(restored.single.id, record.id);
    expect(restored.single.outputKind, NpcMigrationOutputKind.worldBookOnly);
    expect(restored.single.createdCharacterId, isEmpty);
    expect(restored.single.createsCharacter, isFalse);
  });

  test('detached migration archives are informational and not repairable', () {
    final report = DataHealthService.inspect(
      characters: const [],
      npcs: const [],
      migrations: <NpcMigrationRecord>[
        _record(
          outputKind: NpcMigrationOutputKind.newWorld,
          createdCharacterId: 'deleted-character',
        ),
      ],
      worldBooks: const [],
      snapshots: const <SaveSnapshot>[],
      histories: const <DialogueHistory>[],
      gameStates: const <GameStateSnapshot>[],
      mapStates: const <MapWorldState>[],
    );

    final issue = report.issues.singleWhere(
      (item) => item.title == '前尘档案已失联',
    );
    expect(issue.severity, DataHealthSeverity.info);
    expect(issue.repairable, isFalse);
    expect(report.repairableCount, 0);
  });
}

NpcMigrationRecord _record({
  required String outputKind,
  required String createdCharacterId,
  NpcMigrationManifest manifest = const NpcMigrationManifest(
    archive: NpcMigrationArchiveData(summary: '前尘档案'),
  ),
  List<NpcMigrationEchoEvent> echoEvents = const <NpcMigrationEchoEvent>[],
}) {
  return NpcMigrationRecord(
    id: 'migration-1',
    sourceCharacterId: 'source-character',
    sourceCharacterName: '旧世界',
    sourceNpcId: 'source-npc',
    sourceNpcName: '林澈',
    createdCharacterId: createdCharacterId,
    createdCharacterName: createdCharacterId.isEmpty ? '' : '新世界林澈',
    worldBookId: 'world-book-1',
    worldBookTitle: '你们的前尘',
    worldType: '现代都市',
    inspiration: '',
    narrativeVoice: 'second',
    memoryMode: manifest.memoryPolicy.mode,
    archiveText: '前尘档案',
    worldBookContent: '世界书正文',
    characterPrompt: '',
    openingMessage: '',
    characterDescription: '',
    sourceDigest: 'digest',
    outputKind: outputKind,
    manifest: manifest,
    echoEvents: echoEvents,
    createdAt: DateTime(2026, 8, 23, 10),
  );
}
