import 'dart:convert';

import '../models/gameplay_runtime.dart';
import '../models/gameplay_system.dart';
import 'gameplay_system_parser.dart';

/// A reviewable design change. Constructing a draft never changes saved progress.
class GameplaySystemDraft {
  GameplaySystemDraft._({
    required this.current,
    required this.system,
    required this.lockedGroups,
    required this.changes,
    required this.migrationNotes,
  });

  factory GameplaySystemDraft.preview({
    required GameplaySystem current,
    required GameplaySystem generated,
  }) =>
      GameplaySystemDraft.merge(
        current: current,
        generated: generated,
        lockedGroups: const {},
      );

  factory GameplaySystemDraft.merge({
    required GameplaySystem current,
    required GameplaySystem generated,
    required Set<String> lockedGroups,
  }) {
    final existingGroups = current.variables.map((v) => v.group).toSet();
    final unknownGroups = lockedGroups.difference(existingGroups);
    if (unknownGroups.isNotEmpty) {
      throw FormatException('无法锁定不存在的分组：${unknownGroups.join('、')}。');
    }
    final lockedVariables = current.variables
        .where((variable) => lockedGroups.contains(variable.group))
        .toList();
    final lockedKeys = lockedVariables.map((variable) => variable.key).toSet();
    final variables = [
      ...lockedVariables,
      ...generated.variables.where((variable) =>
          !lockedGroups.contains(variable.group) &&
          !lockedKeys.contains(variable.key)),
    ];
    final preservedRules = current.rules.where((rule) {
      if (lockedGroups.isEmpty) return false;
      final references = _references(rule.toJson());
      // Old prose rules have no dependable variable binding. Preserve them when
      // any group is locked so regeneration cannot silently discard that logic.
      return references.isEmpty || references.any(lockedKeys.contains);
    }).toList();
    final preservedIds = preservedRules.map((rule) => rule.id).toSet();
    final rules = [
      ...preservedRules,
      ...generated.rules.where((rule) =>
          !preservedIds.contains(rule.id) &&
          !_references(rule.toJson()).any(lockedKeys.contains)),
    ];
    if (variables.length > 36 || rules.length > 20) {
      throw const FormatException('锁定分组与新草案合并后超过 36 个变量或 20 条规则，请减少草案内容。');
    }
    final merged = GameplaySystem.fromJson({
      ...generated.toJson(),
      'schemaVersion': current.schemaVersion > generated.schemaVersion
          ? current.schemaVersion
          : generated.schemaVersion,
      'variables': variables.map((item) => item.toJson()).toList(),
      'rules': rules.map((item) => item.toJson()).toList(),
    });
    final available = variables.map((v) => v.key).toSet();
    for (final variable in lockedVariables) {
      _checkLockedReferences(
        references: _references(variable.toJson()),
        owner: '变量「${variable.label}」',
        current: current,
        merged: merged,
        available: available,
      );
    }
    for (final rule in preservedRules) {
      _checkLockedReferences(
        references: _references(rule.toJson()),
        owner: '规则「${rule.title}」',
        current: current,
        merged: merged,
        available: available,
      );
    }
    GameplaySystemParser.validateSystem(merged);
    final unchanged = <String>[];
    final reset = <String>[];
    final removed = current.variables
        .where((v) => merged.variableFor(v.key) == null)
        .map((v) => v.label)
        .toList();
    for (final variable in merged.variables) {
      final previous = current.variableFor(variable.key);
      if (previous != null && previous.type == variable.type) {
        unchanged.add(variable.label);
      } else {
        reset.add(variable.label);
      }
    }
    final migrationNotes = <String>[
      if (unchanged.isNotEmpty) '同 key、同类型的变量保留现有进度；若范围或选项改变，会按新定义调整。',
      if (reset.isNotEmpty) '使用新初始值：${reset.join('、')}。',
      if (removed.isNotEmpty) '从当前玩法移除：${removed.join('、')}。旧消息快照仍保留原始进度。',
      '承诺与余波保留；同 id 且执行条件、费用、效果未改变的规则保留触发记录，改写执行机制的规则重新计次。',
      if (lockedGroups.isNotEmpty &&
          preservedRules.any((r) => _references(r.toJson()).isEmpty))
        '旧版文字规则无法准确识别所属分组，锁组时一并保留，请检查是否仍符合新玩法。',
    ];
    return GameplaySystemDraft._(
      current: current,
      system: merged,
      lockedGroups: Set.unmodifiable(lockedGroups),
      changes: List.unmodifiable(_changes(current, merged)),
      migrationNotes: List.unmodifiable(migrationNotes),
    );
  }

  final GameplaySystem current;
  final GameplaySystem system;
  final Set<String> lockedGroups;
  final List<String> changes;
  final List<String> migrationNotes;

  Map<String, dynamic> migrateValues(Map<String, dynamic> currentValues) => {
        for (final variable in system.variables)
          variable.key:
              current.variableFor(variable.key)?.type == variable.type &&
                      currentValues.containsKey(variable.key)
                  ? variable.normalizeValue(currentValues[variable.key])
                  : variable.initialValue,
      };

  GameplayRuntimeState migrateRuntime(GameplayRuntimeState runtime) {
    final previous = {for (final rule in current.rules) rule.id: rule};
    final retainedIds = {
      for (final rule in system.rules)
        if (previous.containsKey(rule.id) &&
            _executionSignature(previous[rule.id]!) ==
                _executionSignature(rule))
          rule.id,
    };
    return GameplayRuntimeState(
      turn: runtime.turn,
      lastTurnId: runtime.lastTurnId,
      lastRuleTurns: {
        for (final entry in runtime.lastRuleTurns.entries)
          if (retainedIds.contains(entry.key)) entry.key: entry.value,
      },
      threads: runtime.threads,
      events: runtime.events,
    );
  }

  static String _executionSignature(GameplayRuleDefinition rule) => jsonEncode({
        'conditions': rule.conditions.map((item) => item.toJson()).toList(),
        'costs': rule.costs.map((item) => item.toJson()).toList(),
        'effects': rule.effects.map((item) => item.toJson()).toList(),
        'threads': rule.threads.map((item) => item.toJson()).toList(),
        'once': rule.once,
        'cooldownTurns': rule.cooldownTurns,
      });

  static void _checkLockedReferences({
    required Set<String> references,
    required String owner,
    required GameplaySystem current,
    required GameplaySystem merged,
    required Set<String> available,
  }) {
    for (final path in references) {
      final oldVariable = current.variableFor(path);
      final newVariable = merged.variableFor(path);
      if (!available.contains(path) ||
          (oldVariable != null && newVariable?.type != oldVariable.type)) {
        final group = oldVariable?.group ?? path;
        throw FormatException(
          '保留的$owner依赖「$path」，但新草案移除或改变了它的类型。'
          '请同时锁定「$group」分组，或在草案中恢复该变量。',
        );
      }
    }
  }

  static Set<String> _references(dynamic value) {
    final result = <String>{};
    if (value is Map) {
      if (value['path'] is String) result.add(value['path'] as String);
      for (final child in value.values) {
        result.addAll(_references(child));
      }
    } else if (value is List) {
      for (final child in value) {
        result.addAll(_references(child));
      }
    }
    return result;
  }

  static List<String> _changes(GameplaySystem current, GameplaySystem next) {
    final changes = <String>[];
    if (current.title != next.title) {
      changes.add('玩法名称：${current.title} → ${next.title}');
    }
    if (current.coreLoop != next.coreLoop || current.summary != next.summary) {
      changes.add('更新玩法概述与核心行动说明');
    }
    for (final variable in current.variables) {
      if (next.variableFor(variable.key) == null) {
        changes.add('移除变量：${variable.group} / ${variable.label}');
      }
    }
    for (final variable in next.variables) {
      final previous = current.variableFor(variable.key);
      if (previous == null) {
        changes.add('新增变量：${variable.group} / ${variable.label}');
      } else if (jsonEncode(previous.toJson()) !=
          jsonEncode(variable.toJson())) {
        changes.add('调整变量：${variable.group} / ${variable.label}'
            '${previous.type != variable.type ? '（类型改变，将使用新初始值）' : ''}');
      }
    }
    final currentRules = {for (final rule in current.rules) rule.id: rule};
    final nextRules = {for (final rule in next.rules) rule.id: rule};
    for (final rule in current.rules) {
      if (!nextRules.containsKey(rule.id)) changes.add('移除规则：${rule.title}');
    }
    for (final rule in next.rules) {
      final previous = currentRules[rule.id];
      if (previous == null) {
        changes.add('新增规则：${rule.title}');
      } else if (jsonEncode(previous.toJson()) != jsonEncode(rule.toJson())) {
        changes.add('调整规则：${rule.title}');
      }
    }
    return changes.isEmpty ? ['变量与规则没有变化'] : changes;
  }
}
