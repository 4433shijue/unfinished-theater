import 'gameplay_runtime.dart';

enum GameplayVariableType {
  number,
  text,
  boolean,
  choice,
  clock,
  list,
}

enum GameplayVariableVisibility {
  public,
  fuzzy,
  director,
  engine,
}

enum GameplayVariableAuthority {
  ai,
  rule,
  player,
  computed,
}

class GameplayVariableStage {
  const GameplayVariableStage({
    required this.min,
    required this.label,
  });

  factory GameplayVariableStage.fromJson(Map<String, dynamic> json) {
    return GameplayVariableStage(
      min: _readDouble(json['min']) ?? 0,
      label: json['label']?.toString().trim() ?? '',
    );
  }

  final double min;
  final String label;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'min': min,
        'label': label,
      };
}

class GameplayVariableDefinition {
  const GameplayVariableDefinition({
    required this.key,
    required this.label,
    required this.group,
    required this.type,
    required this.visibility,
    required this.authority,
    required this.initialValue,
    required this.description,
    this.min,
    this.max,
    this.maxDelta,
    this.options = const <String>[],
    this.stages = const <GameplayVariableStage>[],
    this.playerHint = '',
    this.isCore = false,
    this.advanceOnTimeChange,
    this.revealWhen = const <GameplayCondition>[],
  });

  factory GameplayVariableDefinition.fromJson(Map<String, dynamic> json) {
    final rawKey = (json['key'] ?? json['path'])?.toString().trim() ?? '';
    final type = _variableTypeFromValue(json['type']?.toString());
    final options = _readStrings(json['options']);
    final stages = (json['stages'] is List ? json['stages'] as List : const [])
        .whereType<Map>()
        .map((item) => GameplayVariableStage.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.label.isNotEmpty)
        .toList()
      ..sort((a, b) => a.min.compareTo(b.min));
    final min = _readDouble(json['min']);
    final max = _readDouble(json['max']);
    final visibility = _visibilityFromValue(json['visibility']?.toString());
    final requestedAuthority =
        _authorityFromValue(json['authority']?.toString());
    final authority = visibility == GameplayVariableVisibility.engine &&
            requestedAuthority == GameplayVariableAuthority.ai
        ? GameplayVariableAuthority.rule
        : requestedAuthority;

    return GameplayVariableDefinition(
      key: rawKey,
      label: json['label']?.toString().trim().isNotEmpty == true
          ? json['label'].toString().trim()
          : _fallbackLabel(rawKey),
      group: json['group']?.toString().trim().isNotEmpty == true
          ? json['group'].toString().trim()
          : '其他',
      type: type,
      visibility: visibility,
      authority: authority,
      initialValue: _normalizeValue(
        type,
        json.containsKey('initialValue')
            ? json['initialValue']
            : json['default'],
        min: min,
        max: max,
        options: options,
      ),
      description: json['description']?.toString().trim() ?? '',
      min: min,
      max: max,
      maxDelta: _readDouble(json['maxDelta']),
      options: options,
      stages: stages,
      playerHint: json['playerHint']?.toString().trim() ?? '',
      isCore: json['isCore'] == true,
      advanceOnTimeChange: _readDouble(json['advanceOnTimeChange']),
      revealWhen: _readConditions(json['revealWhen']),
    );
  }

  final String key;
  final String label;
  final String group;
  final GameplayVariableType type;
  final GameplayVariableVisibility visibility;
  final GameplayVariableAuthority authority;
  final dynamic initialValue;
  final String description;
  final double? min;
  final double? max;
  final double? maxDelta;
  final List<String> options;
  final List<GameplayVariableStage> stages;
  final String playerHint;
  final bool isCore;
  final double? advanceOnTimeChange;
  final List<GameplayCondition> revealWhen;

  bool get isValid =>
      _gameplayVariableKeyPattern.hasMatch(key) && !mirrorsNpcRelationship;

  bool get mirrorsNpcRelationship {
    final text = '$key$label$group$description'
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_.：:|｜-]'), '');
    if (text.contains('好感') ||
        text.contains('亲密度') ||
        text.contains('affinity') ||
        text.contains('favorability')) {
      return true;
    }
    final npcScoped =
        text.contains('npc') || text.contains('角色') || text.contains('人物');
    return npcScoped && (text.contains('信任') || text.contains('trust'));
  }

  bool get isPlayerFacing =>
      visibility == GameplayVariableVisibility.public ||
      visibility == GameplayVariableVisibility.fuzzy;

  bool get acceptsAiUpdates => authority == GameplayVariableAuthority.ai;

  dynamic normalizeValue(dynamic value) {
    return _normalizeValue(
      type,
      value,
      min: min,
      max: max,
      options: options,
    );
  }

  String displayValue(dynamic value, {required bool reveal}) {
    if (!reveal) {
      if (visibility == GameplayVariableVisibility.director) {
        return '幕后推进';
      }
      if (visibility == GameplayVariableVisibility.engine) {
        return '引擎托管';
      }
      if (visibility == GameplayVariableVisibility.fuzzy) {
        final numeric = _readDouble(value);
        if (numeric != null && stages.isNotEmpty) {
          var label = stages.first.label;
          for (final stage in stages) {
            if (numeric >= stage.min) {
              label = stage.label;
            }
          }
          return label;
        }
        return '状态未明';
      }
    }

    if (value is List) {
      return value.isEmpty ? '暂无' : value.join('、');
    }
    if (value is bool) {
      return value ? '是' : '否';
    }
    if (value is num && value == value.roundToDouble()) {
      return value.round().toString();
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '暂无' : text;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'label': label,
        'group': group,
        'type': type.name,
        'visibility': visibility.name,
        'authority': authority.name,
        'initialValue': initialValue,
        'description': description,
        if (playerHint.isNotEmpty) 'playerHint': playerHint,
        if (isCore) 'isCore': isCore,
        if (advanceOnTimeChange != null)
          'advanceOnTimeChange': advanceOnTimeChange,
        if (revealWhen.isNotEmpty)
          'revealWhen': revealWhen.map((item) => item.toJson()).toList(),
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (maxDelta != null) 'maxDelta': maxDelta,
        if (options.isNotEmpty) 'options': options,
        if (stages.isNotEmpty)
          'stages': stages.map((item) => item.toJson()).toList(),
      };
}

class GameplayCondition {
  const GameplayCondition({required this.path, required this.op, this.value});

  factory GameplayCondition.fromJson(Map<String, dynamic> json) =>
      GameplayCondition(
        path: json['path']?.toString().trim() ?? '',
        op: json['op']?.toString().trim() ?? '',
        value: json['value'],
      );

  final String path;
  final String op;
  final dynamic value;

  Map<String, dynamic> toJson() => {'path': path, 'op': op, 'value': value};
}

typedef GameplayRuleCondition = GameplayCondition;

class GameplayRuleCost {
  const GameplayRuleCost({required this.path, required this.amount});

  factory GameplayRuleCost.fromJson(Map<String, dynamic> json) =>
      GameplayRuleCost(
        path: json['path']?.toString().trim() ?? '',
        amount: _readDouble(json['amount']) ?? -1,
      );

  final String path;
  final double amount;

  Map<String, dynamic> toJson() => {'path': path, 'amount': amount};
}

class GameplayRuleEffect {
  const GameplayRuleEffect({required this.op, required this.path, this.value});

  factory GameplayRuleEffect.fromJson(Map<String, dynamic> json) =>
      GameplayRuleEffect(
        op: json['op']?.toString().trim() ?? '',
        path: json['path']?.toString().trim() ?? '',
        value: json['value'],
      );

  final String op;
  final String path;
  final dynamic value;

  Map<String, dynamic> toJson() => {'op': op, 'path': path, 'value': value};
}

List<GameplayCondition> _readConditions(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .take(17)
        .map((item) =>
            GameplayCondition.fromJson(Map<String, dynamic>.from(item)))
        .toList()
    : const <GameplayCondition>[];

class GameplayRuleDefinition {
  const GameplayRuleDefinition({
    required this.id,
    required this.title,
    required this.when,
    required this.effect,
    required this.visibility,
    this.conditions = const <GameplayCondition>[],
    this.costs = const <GameplayRuleCost>[],
    this.effects = const <GameplayRuleEffect>[],
    this.threads = const <GameplayThreadOperation>[],
    this.once = true,
    this.cooldownTurns = 0,
    this.playerSummary = '',
  });

  factory GameplayRuleDefinition.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString().trim() ?? '';
    return GameplayRuleDefinition(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString().trim()
          : _stableRuleId(title),
      title: title.isEmpty ? '未命名规则' : title,
      when: json['when']?.toString().trim() ?? '',
      effect: json['effect']?.toString().trim() ?? '',
      visibility: _visibilityFromValue(json['visibility']?.toString()),
      conditions: _readConditions(json['conditions']),
      costs: (json['costs'] is List ? json['costs'] as List : const [])
          .whereType<Map>()
          .take(17)
          .map((item) =>
              GameplayRuleCost.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      effects: (json['effects'] is List ? json['effects'] as List : const [])
          .whereType<Map>()
          .take(25)
          .map((item) =>
              GameplayRuleEffect.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      threads: (json['threads'] is List ? json['threads'] as List : const [])
          .whereType<Map>()
          .take(9)
          .map((item) =>
              GameplayThreadOperation.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      once: json['once'] != false,
      cooldownTurns:
          (int.tryParse(json['cooldownTurns']?.toString() ?? '') ?? 0)
              .clamp(0, 10000),
      playerSummary: json['playerSummary']?.toString().trim() ?? '',
    );
  }

  final String id;
  final String title;
  final String when;
  final String effect;
  final GameplayVariableVisibility visibility;
  final List<GameplayCondition> conditions;
  final List<GameplayRuleCost> costs;
  final List<GameplayRuleEffect> effects;
  final List<GameplayThreadOperation> threads;
  final bool once;
  final int cooldownTurns;
  final String playerSummary;

  bool get isExecutable =>
      conditions.isNotEmpty && (effects.isNotEmpty || threads.isNotEmpty);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'when': when,
        'effect': effect,
        'visibility': visibility.name,
        if (conditions.isNotEmpty)
          'conditions': conditions.map((item) => item.toJson()).toList(),
        if (costs.isNotEmpty)
          'costs': costs.map((item) => item.toJson()).toList(),
        if (effects.isNotEmpty)
          'effects': effects.map((item) => item.toJson()).toList(),
        if (threads.isNotEmpty)
          'threads': threads.map((item) => item.toJson()).toList(),
        'once': once,
        'cooldownTurns': cooldownTurns,
        if (playerSummary.isNotEmpty) 'playerSummary': playerSummary,
      };
}

class GameplaySystem {
  const GameplaySystem({
    required this.schemaVersion,
    required this.title,
    required this.summary,
    required this.coreLoop,
    required this.generatedAt,
    required this.variables,
    required this.rules,
  });

  factory GameplaySystem.fromJson(Map<String, dynamic> json) {
    final rawSchemaVersion =
        int.tryParse(json['schemaVersion']?.toString() ?? '') ?? 1;
    final variables = <GameplayVariableDefinition>[];
    final seenKeys = <String>{};
    final rawVariables = json['variables'];
    if (rawVariables is List) {
      for (final raw in rawVariables.whereType<Map>()) {
        final normalizedRaw = Map<String, dynamic>.from(raw);
        if (rawSchemaVersion < 2) {
          final visibility = _visibilityFromValue(
            normalizedRaw['visibility']?.toString(),
          );
          final authority = _authorityFromValue(
            normalizedRaw['authority']?.toString(),
          );
          if (visibility != GameplayVariableVisibility.engine &&
              (authority == GameplayVariableAuthority.rule ||
                  authority == GameplayVariableAuthority.computed)) {
            normalizedRaw['authority'] = GameplayVariableAuthority.ai.name;
          }
        }
        final definition = GameplayVariableDefinition.fromJson(
          normalizedRaw,
        );
        if (!definition.isValid || !seenKeys.add(definition.key)) {
          continue;
        }
        variables.add(definition);
        if (variables.length >= 36) {
          break;
        }
      }
    }

    final rules = <GameplayRuleDefinition>[];
    final seenRuleIds = <String>{};
    final rawRules = json['rules'];
    if (rawRules is List) {
      for (final raw in rawRules.whereType<Map>()) {
        final rule = GameplayRuleDefinition.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if ((!rule.isExecutable &&
                (rule.when.isEmpty || rule.effect.isEmpty)) ||
            !seenRuleIds.add(rule.id)) {
          continue;
        }
        rules.add(rule);
        if (rules.length >= 20) {
          break;
        }
      }
    }

    return GameplaySystem(
      schemaVersion: rawSchemaVersion < 2 ? 2 : rawSchemaVersion,
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : '个性化玩法系统',
      summary: json['summary']?.toString().trim() ?? '',
      coreLoop: json['coreLoop']?.toString().trim() ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
      variables: variables,
      rules: rules,
    );
  }

  final int schemaVersion;
  final String title;
  final String summary;
  final String coreLoop;
  final DateTime generatedAt;
  final List<GameplayVariableDefinition> variables;
  final List<GameplayRuleDefinition> rules;

  bool get isUsable => variables.length >= 4;

  int get playerFacingVariableCount =>
      variables.where((item) => item.isPlayerFacing).length;

  int get backstageVariableCount =>
      variables.where((item) => !item.isPlayerFacing).length;

  GameplayVariableDefinition? variableFor(String key) {
    for (final variable in variables) {
      if (variable.key == key) {
        return variable;
      }
    }
    return null;
  }

  Map<String, dynamic> initialValues() => <String, dynamic>{
        for (final variable in variables) variable.key: variable.initialValue,
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'title': title,
        'summary': summary,
        'coreLoop': coreLoop,
        'generatedAt': generatedAt.toIso8601String(),
        'variables': variables.map((item) => item.toJson()).toList(),
        'rules': rules.map((item) => item.toJson()).toList(),
      };
}

final RegExp _gameplayVariableKeyPattern = RegExp(
  r'^[\p{L}\p{N}_-]+(?:\.[\p{L}\p{N}_-]+)*$',
  unicode: true,
);

GameplayVariableType _variableTypeFromValue(String? value) {
  final normalized = value?.trim().toLowerCase();
  return switch (normalized) {
    'number' || 'int' || 'double' => GameplayVariableType.number,
    'boolean' || 'bool' => GameplayVariableType.boolean,
    'choice' || 'enum' => GameplayVariableType.choice,
    'clock' || 'progress' => GameplayVariableType.clock,
    'list' || 'array' => GameplayVariableType.list,
    _ => GameplayVariableType.text,
  };
}

GameplayVariableVisibility _visibilityFromValue(String? value) {
  final normalized = value?.trim().toLowerCase();
  return switch (normalized) {
    'fuzzy' => GameplayVariableVisibility.fuzzy,
    'director' || 'hidden' => GameplayVariableVisibility.director,
    'engine' || 'private' => GameplayVariableVisibility.engine,
    _ => GameplayVariableVisibility.public,
  };
}

GameplayVariableAuthority _authorityFromValue(String? value) {
  final normalized = value?.trim().toLowerCase();
  return switch (normalized) {
    'rule' || 'engine' => GameplayVariableAuthority.rule,
    'player' => GameplayVariableAuthority.player,
    'computed' => GameplayVariableAuthority.computed,
    _ => GameplayVariableAuthority.ai,
  };
}

dynamic _normalizeValue(
  GameplayVariableType type,
  dynamic value, {
  required double? min,
  required double? max,
  required List<String> options,
}) {
  switch (type) {
    case GameplayVariableType.number:
    case GameplayVariableType.clock:
      var numeric = _readDouble(value) ?? 0;
      if (min != null && numeric < min) {
        numeric = min;
      }
      if (max != null && numeric > max) {
        numeric = max;
      }
      return numeric == numeric.roundToDouble() ? numeric.round() : numeric;
    case GameplayVariableType.boolean:
      if (value is bool) {
        return value;
      }
      final normalized = value?.toString().trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == '是';
    case GameplayVariableType.choice:
      final normalized = value?.toString().trim() ?? '';
      if (options.isEmpty || options.contains(normalized)) {
        return normalized;
      }
      return options.first;
    case GameplayVariableType.list:
      return _readStrings(value);
    case GameplayVariableType.text:
      return value?.toString().trim() ?? '';
  }
}

double? _readDouble(dynamic value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite ? parsed : null;
}

List<String> _readStrings(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(40)
        .toList(growable: false);
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return const <String>[];
  }
  return text
      .split(RegExp(r'[,，;；\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(40)
      .toList(growable: false);
}

String _fallbackLabel(String key) {
  final segments = key.split('.');
  return segments.isEmpty || segments.last.trim().isEmpty
      ? '未命名变量'
      : segments.last.trim();
}

String _stableRuleId(String value) {
  var hash = 0x811c9dc5;
  for (final code in value.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 'rule_${hash.toRadixString(16).padLeft(8, '0')}';
}
