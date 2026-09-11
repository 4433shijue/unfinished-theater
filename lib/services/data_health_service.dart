import '../models/character_profile.dart';
import '../models/data_management.dart';
import '../models/dialogue_history.dart';
import '../models/game_state.dart';
import '../models/map_state.dart';
import '../models/npc_migration.dart';
import '../models/npc_profile.dart';
import '../models/world_book.dart';

enum DataHealthSeverity {
  info,
  warning,
  danger,
}

class DataHealthIssue {
  const DataHealthIssue({
    required this.severity,
    required this.title,
    required this.description,
    this.repairable = false,
  });

  final DataHealthSeverity severity;
  final String title;
  final String description;
  final bool repairable;
}

class DataHealthReport {
  const DataHealthReport({
    required this.issues,
    required this.scannedAt,
  });

  final List<DataHealthIssue> issues;
  final DateTime scannedAt;

  int get repairableCount => issues.where((issue) => issue.repairable).length;

  int get dangerCount => issues
      .where((issue) => issue.severity == DataHealthSeverity.danger)
      .length;

  int get warningCount => issues
      .where((issue) => issue.severity == DataHealthSeverity.warning)
      .length;

  bool get isClean => issues.isEmpty;
}

class DataHealthService {
  const DataHealthService._();

  static DataHealthReport inspect({
    required List<CharacterProfile> characters,
    required List<NpcProfile> npcs,
    required List<NpcMigrationRecord> migrations,
    required List<WorldBookEntry> worldBooks,
    required List<SaveSnapshot> snapshots,
    required Iterable<DialogueHistory> histories,
    required Iterable<GameStateSnapshot> gameStates,
    required Iterable<MapWorldState> mapStates,
  }) {
    final issues = <DataHealthIssue>[];
    final characterIds = characters.map((item) => item.id).toSet();
    final npcIds = npcs.map((item) => item.id).toSet();

    for (final npc in npcs) {
      final owner = npc.characterId.trim();
      final boundIds =
          npc.boundCharacterIds.where((id) => id.trim().isNotEmpty);
      final hasKnownOwner = owner.isEmpty || characterIds.contains(owner);
      final hasKnownBinding =
          npc.globalBinding || boundIds.every(characterIds.contains);
      if (!hasKnownOwner || !hasKnownBinding) {
        issues.add(
          DataHealthIssue(
            severity: DataHealthSeverity.warning,
            title: 'NPC 绑定指向不存在的角色',
            description: '${npc.name} 的来源或绑定角色已经不存在。',
            repairable: true,
          ),
        );
      }
    }

    for (final migration in migrations) {
      final sourceDetached = migration.sourceNpcId.trim().isNotEmpty &&
          !npcIds.contains(migration.sourceNpcId);
      final worldDetached = migration.sourceCharacterId.trim().isNotEmpty &&
          !characterIds.contains(migration.sourceCharacterId);
      final createdDetached = migration.createsCharacter &&
          !characterIds.contains(migration.createdCharacterId);
      if (sourceDetached || worldDetached || createdDetached) {
        issues.add(
          DataHealthIssue(
            severity: DataHealthSeverity.info,
            title: '前尘档案已失联',
            description: '${migration.sourceNpcName} 的原 NPC 或关联世界已删除，档案快照仍会保留。',
            repairable: false,
          ),
        );
      }
    }

    for (final entry in worldBooks) {
      if (!entry.global &&
          entry.boundCharacterIds.any((id) => !characterIds.contains(id))) {
        issues.add(
          DataHealthIssue(
            severity: DataHealthSeverity.warning,
            title: '世界书绑定断链',
            description: '「${entry.title}」绑定了不存在的角色。',
            repairable: true,
          ),
        );
      }
      if (entry.triggerMode == WorldBookTriggerMode.regex &&
          entry.regexPattern.trim().isNotEmpty) {
        try {
          RegExp(entry.regexPattern);
        } catch (_) {
          issues.add(
            DataHealthIssue(
              severity: DataHealthSeverity.danger,
              title: '世界书正则无效',
              description: '「${entry.title}」的正则无法解析，本轮不会触发。',
              repairable: false,
            ),
          );
        }
      }
    }

    for (final snapshot in snapshots) {
      if (!characterIds.contains(snapshot.characterId)) {
        issues.add(
          DataHealthIssue(
            severity: DataHealthSeverity.info,
            title: '快照角色已不存在',
            description: '「${snapshot.title}」保留着已删除剧场的数据，可从恢复中心重新导入。',
            repairable: false,
          ),
        );
      }
      if (snapshot.archiveJson.trim().isEmpty) {
        issues.add(
          DataHealthIssue(
            severity: DataHealthSeverity.danger,
            title: '空快照',
            description: '「${snapshot.title}」没有可恢复的存档内容。',
            repairable: true,
          ),
        );
      }
    }

    for (final history in histories) {
      if (!characterIds.contains(history.characterId)) {
        issues.add(
          const DataHealthIssue(
            severity: DataHealthSeverity.info,
            title: '聊天历史孤儿数据',
            description: '存在不属于当前角色列表的聊天历史缓存。',
            repairable: true,
          ),
        );
      }
    }

    for (final state in gameStates) {
      if (state.characterId.trim().isNotEmpty &&
          !characterIds.contains(state.characterId)) {
        issues.add(
          const DataHealthIssue(
            severity: DataHealthSeverity.info,
            title: '游戏状态孤儿数据',
            description: '存在不属于当前角色列表的 GAME_STATE 缓存。',
            repairable: true,
          ),
        );
      }
    }

    for (final state in mapStates) {
      if (state.characterId.trim().isNotEmpty &&
          !characterIds.contains(state.characterId)) {
        issues.add(
          const DataHealthIssue(
            severity: DataHealthSeverity.info,
            title: '地图状态孤儿数据',
            description: '存在不属于当前角色列表的 MAP_STATE 缓存。',
            repairable: true,
          ),
        );
      }
      final ids = state.locations.map((location) => location.id).toSet();
      if (state.currentLocationId.trim().isNotEmpty &&
          ids.isNotEmpty &&
          !ids.contains(state.currentLocationId)) {
        issues.add(
          DataHealthIssue(
            severity: DataHealthSeverity.warning,
            title: '地图当前位置断链',
            description:
                '「${state.title.trim().isEmpty ? state.characterId : state.title}」的 currentLocationId 不在地点列表中。',
            repairable: true,
          ),
        );
      }
    }

    return DataHealthReport(
      issues: issues.toList(growable: false),
      scannedAt: DateTime.now(),
    );
  }
}
