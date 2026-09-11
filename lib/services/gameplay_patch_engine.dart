import 'dart:convert';

import '../models/gameplay_system.dart';

enum GameplayPatchOperationType {
  set,
  increment,
  append,
  remove,
}

class GameplayPatchOperation {
  const GameplayPatchOperation({
    required this.type,
    required this.path,
    required this.value,
    required this.reason,
  });

  factory GameplayPatchOperation.fromJson(Map<String, dynamic> json) {
    final rawOperation = json['op']?.toString().trim().toLowerCase();
    return GameplayPatchOperation(
      type: switch (rawOperation) {
        'inc' || 'increment' => GameplayPatchOperationType.increment,
        'append' || 'add' => GameplayPatchOperationType.append,
        'remove' || 'delete' => GameplayPatchOperationType.remove,
        _ => GameplayPatchOperationType.set,
      },
      path: (json['path'] ?? json['key'])?.toString().trim() ?? '',
      value: json['value'],
      reason: json['reason']?.toString().trim() ?? '',
    );
  }

  final GameplayPatchOperationType type;
  final String path;
  final dynamic value;
  final String reason;
}

class GameplayPatchChange {
  const GameplayPatchChange({
    required this.path,
    required this.before,
    required this.after,
    required this.reason,
  });

  final String path;
  final dynamic before;
  final dynamic after;
  final String reason;
}

class GameplayPatchResult {
  const GameplayPatchResult({
    required this.values,
    required this.changes,
    required this.rejections,
  });

  final Map<String, dynamic> values;
  final List<GameplayPatchChange> changes;
  final List<String> rejections;

  bool get changed => changes.isNotEmpty;
}

class GameplayPatchParseResult {
  const GameplayPatchParseResult({
    required this.found,
    required this.operations,
    this.error,
  });

  final bool found;
  final List<GameplayPatchOperation> operations;
  final String? error;

  bool get isValid => found && error == null;
}

class GameplayPatchParser {
  const GameplayPatchParser._();

  static final RegExp blockPattern = RegExp(
    r'\[THEATER_PATCH\]\s*([\s\S]*?)\s*\[/THEATER_PATCH\]',
    caseSensitive: false,
  );

  static List<GameplayPatchOperation> parse(String content) {
    final result = parseResult(content);
    return result.isValid
        ? result.operations
        : const <GameplayPatchOperation>[];
  }

  static GameplayPatchParseResult parseResult(String content) {
    final matches = blockPattern.allMatches(content).toList(growable: false);
    if (matches.isEmpty) {
      final hasOpeningTag = RegExp(
        r'\[THEATER_PATCH\]',
        caseSensitive: false,
      ).hasMatch(content);
      return GameplayPatchParseResult(
        found: hasOpeningTag,
        operations: const <GameplayPatchOperation>[],
        error: hasOpeningTag ? '变量补丁缺少结束标签' : null,
      );
    }
    var raw = matches.last.group(1)?.trim() ?? '';
    raw = raw
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    if (raw.isEmpty) {
      return const GameplayPatchParseResult(
        found: true,
        operations: <GameplayPatchOperation>[],
        error: '变量补丁内容为空',
      );
    }

    try {
      final decoded = jsonDecode(raw);
      final dynamic rawOperations;
      if (decoded is List) {
        rawOperations = decoded;
      } else if (decoded is Map && decoded['ops'] is List) {
        rawOperations = decoded['ops'];
      } else {
        return const GameplayPatchParseResult(
          found: true,
          operations: <GameplayPatchOperation>[],
          error: '变量补丁必须是操作数组或包含 ops 数组的对象',
        );
      }
      final operations = (rawOperations as List)
          .whereType<Map>()
          .map((item) => GameplayPatchOperation.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.path.isNotEmpty)
          .take(48)
          .toList(growable: false);
      return GameplayPatchParseResult(
        found: true,
        operations: operations,
      );
    } catch (_) {
      return const GameplayPatchParseResult(
        found: true,
        operations: <GameplayPatchOperation>[],
        error: '变量补丁不是合法 JSON',
      );
    }
  }
}

class GameplayPatchEngine {
  const GameplayPatchEngine._();

  static Map<String, int> removeClaimedLegacyMetrics(
    GameplaySystem system,
    Map<String, int> metrics,
  ) {
    if (metrics.isEmpty) {
      return metrics;
    }
    final claimed =
        system.variables.map(_claimedLegacyMetric).whereType<String>().toSet();
    if (claimed.isEmpty) {
      return metrics;
    }
    return <String, int>{
      for (final entry in metrics.entries)
        if (!claimed.contains(entry.key)) entry.key: entry.value,
    };
  }

  static Map<String, dynamic> initializeValues(
    GameplaySystem system,
    Map<String, dynamic> existing,
  ) {
    return <String, dynamic>{
      for (final variable in system.variables)
        variable.key: variable.normalizeValue(
          existing.containsKey(variable.key)
              ? existing[variable.key]
              : variable.initialValue,
        ),
    };
  }

  static GameplayPatchResult applyAiPatch({
    required GameplaySystem system,
    required Map<String, dynamic> currentValues,
    required List<GameplayPatchOperation> operations,
  }) {
    final values = initializeValues(system, currentValues);
    final changes = <GameplayPatchChange>[];
    final rejections = <String>[];

    for (final operation in operations) {
      final variable = system.variableFor(operation.path);
      if (variable == null) {
        rejections.add('${operation.path}：变量未在当前剧本中声明');
        continue;
      }
      if (!variable.acceptsAiUpdates) {
        rejections.add('${operation.path}：该变量由规则或玩家控制');
        continue;
      }

      final before = values[variable.key];
      dynamic candidate;
      switch (operation.type) {
        case GameplayPatchOperationType.set:
          candidate = variable.normalizeValue(operation.value);
        case GameplayPatchOperationType.increment:
          if (variable.type != GameplayVariableType.number &&
              variable.type != GameplayVariableType.clock) {
            rejections.add('${operation.path}：非数值变量不能增减');
            continue;
          }
          final delta = operation.value is num
              ? (operation.value as num).toDouble()
              : double.tryParse(operation.value?.toString() ?? '');
          if (delta == null) {
            rejections.add('${operation.path}：增量不是有效数字');
            continue;
          }
          final limit = variable.maxDelta;
          final safeDelta = limit == null
              ? delta
              : delta.clamp(-limit.abs(), limit.abs()).toDouble();
          final current = before is num ? before.toDouble() : 0;
          candidate = variable.normalizeValue(current + safeDelta);
        case GameplayPatchOperationType.append:
          if (variable.type != GameplayVariableType.list) {
            rejections.add('${operation.path}：只有列表变量可以追加');
            continue;
          }
          final next = <String>[
            ...(before is List
                ? before.map((item) => item.toString())
                : const []),
            operation.value?.toString().trim() ?? '',
          ].where((item) => item.isNotEmpty).toSet().take(40).toList();
          candidate = variable.normalizeValue(next);
        case GameplayPatchOperationType.remove:
          if (variable.type != GameplayVariableType.list) {
            rejections.add('${operation.path}：只有列表变量可以移除条目');
            continue;
          }
          final removed = operation.value?.toString().trim() ?? '';
          candidate = variable.normalizeValue(
            before is List
                ? before
                    .map((item) => item.toString())
                    .where((item) => item != removed)
                    .toList()
                : const <String>[],
          );
      }

      if (_jsonEquals(before, candidate)) {
        continue;
      }
      values[variable.key] = candidate;
      changes.add(
        GameplayPatchChange(
          path: variable.key,
          before: before,
          after: candidate,
          reason: operation.reason,
        ),
      );
    }

    return GameplayPatchResult(
      values: values,
      changes: changes,
      rejections: rejections,
    );
  }

  static bool _jsonEquals(dynamic left, dynamic right) =>
      jsonEncode(left) == jsonEncode(right);

  static String? _claimedLegacyMetric(GameplayVariableDefinition variable) {
    final text = '${variable.key}${variable.label}'
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_.：:|｜-]'), '');
    if (text.contains('压力') || text.contains('stress')) {
      return '压力';
    }
    if (text.contains('精力') ||
        text.contains('体力') ||
        text.contains('energy') ||
        text.contains('stamina')) {
      return '精力';
    }
    if (text.contains('金钱') ||
        text.contains('零花钱') ||
        text.contains('金币') ||
        text.contains('货币') ||
        text.contains('money') ||
        text.contains('cash')) {
      return '金钱';
    }
    if (text.contains('声望') || text.contains('reputation')) {
      return '声望';
    }
    if (text.contains('好感') || text.contains('affinity')) {
      return '好感';
    }
    return null;
  }
}
