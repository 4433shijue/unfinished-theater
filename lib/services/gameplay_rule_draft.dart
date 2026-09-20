import 'dart:convert';

import '../models/gameplay_system.dart';
import 'gameplay_system_parser.dart';

/// Author-only helpers. Player summaries are never derived from execution data.
class GameplayRuleDraft {
  const GameplayRuleDraft._();

  static const metadata = {
    'id',
    'title',
    'when',
    'effect',
    'playerSummary',
    'visibility'
  };
  static const executionFields = ['conditions', 'costs', 'effects', 'threads'];

  static Map<String, dynamic> executionOf(GameplayRuleDefinition rule) => {
        for (final entry in rule.toJson().entries)
          if (!metadata.contains(entry.key)) entry.key: entry.value,
      };

  static bool isStructured(Map<String, dynamic> execution) =>
      executionFields.any(execution.containsKey);

  static bool numeric(GameplayVariableDefinition variable) =>
      variable.type == GameplayVariableType.number ||
      variable.type == GameplayVariableType.clock;

  static bool writable(GameplayVariableDefinition variable) =>
      variable.authority == GameplayVariableAuthority.ai ||
      variable.authority == GameplayVariableAuthority.rule;

  static List<String> conditionOps(GameplayVariableDefinition variable) => [
        'eq',
        'neq',
        if (numeric(variable)) ...['gt', 'gte', 'lt', 'lte'],
        if (variable.type == GameplayVariableType.text ||
            variable.type == GameplayVariableType.list)
          'contains',
        'changed',
      ];

  static List<String> effectOps(GameplayVariableDefinition variable) => [
        'set',
        if (numeric(variable)) 'inc',
        if (variable.type == GameplayVariableType.list) ...['append', 'remove'],
      ];

  static dynamic defaultValue(GameplayVariableDefinition variable,
      {String op = 'set'}) {
    if (['contains', 'append', 'remove'].contains(op)) return '';
    if (op == 'inc') return 0;
    return variable.initialValue;
  }

  static const opLabels = {
    'eq': '等于',
    'neq': '不等于',
    'gt': '大于',
    'gte': '达到或超过',
    'lt': '小于',
    'lte': '不超过',
    'contains': '包含',
    'changed': '本回合发生变化',
    'set': '设为',
    'inc': '增减',
    'append': '加入',
    'remove': '移除',
  };

  static String conditionDescription(
      GameplaySystem system, Map<String, dynamic> condition) {
    final name = system.variableFor('${condition['path']}')?.label ??
        '${condition['path']}';
    final op = '${condition['op']}';
    return '$name${opLabels[op] ?? op}'
        '${op == 'changed' ? '' : ' ${_value(condition['value'])}'}';
  }

  static ({String when, String effect}) describe(
      GameplaySystem system, Map<String, dynamic> execution) {
    final conditions = _rows(execution['conditions']);
    final details = <String>[
      for (final cost in _rows(execution['costs']))
        '扣除${system.variableFor('${cost['path']}')?.label ?? cost['path']} ${cost['amount']}',
      for (final effect in _rows(execution['effects']))
        '${system.variableFor('${effect['path']}')?.label ?? effect['path']}'
            '${opLabels[effect['op']] ?? effect['op']} ${_value(effect['value'])}',
      for (final thread in _rows(execution['threads']))
        '${switch (thread['op']) {
          'resolve' => '兑现',
          'break' => '打破',
          _ => '留下'
        }}'
            '「${thread['title'] ?? thread['id']}」',
    ];
    final once = execution['once'] != false;
    final frequency =
        once ? '仅触发一次' : '可重复触发，间隔至少 ${execution['cooldownTurns'] ?? 0} 回合';
    return (
      when: conditions.isEmpty
          ? '尚未设置触发条件'
          : '${conditions.map((c) => conditionDescription(system, c)).join('，并且')}；$frequency',
      effect: details.isEmpty ? '尚未设置执行效果' : details.join('；'),
    );
  }

  /// Validate raw JSON before model normalization can clamp or drop bad values.
  static Map<String, dynamic> validate({
    required GameplaySystem system,
    required GameplayRuleDefinition original,
    required Map<String, dynamic> execution,
    required String title,
    required String when,
    required String effect,
    required String playerSummary,
    bool refreshDescription = false,
  }) {
    if (title.trim().isEmpty || when.trim().isEmpty || effect.trim().isEmpty) {
      throw const FormatException('填写规则名称、触发说明和后果说明。');
    }
    if (execution.keys.any(metadata.contains)) {
      throw const FormatException('执行 JSON 只填写条件、费用、效果、承诺和触发频率；名称与玩家说明在上方修改。');
    }
    final description = describe(system, execution);
    final structured = isStructured(execution);
    if (structured &&
        [GameplayVariableVisibility.public, GameplayVariableVisibility.fuzzy]
            .contains(original.visibility) &&
        playerSummary.trim().isEmpty) {
      throw const FormatException('请单独填写玩家能预见的规则，避免展示幕后执行条件。');
    }
    final rule = <String, dynamic>{
      'id': original.id,
      'title': title.trim(),
      'when': refreshDescription && structured ? description.when : when.trim(),
      'effect':
          refreshDescription && structured ? description.effect : effect.trim(),
      'visibility': original.visibility.name,
      'playerSummary': playerSummary.trim(),
      ...execution,
    };
    final rawSystem = {
      ...system.toJson(),
      'rules': [
        for (final existing in system.rules)
          existing.id == original.id ? rule : existing.toJson(),
        if (!system.rules.any((r) => r.id == original.id)) rule,
      ],
    };
    GameplaySystemParser.parse(jsonEncode(rawSystem));
    return rule;
  }

  static Iterable<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row))
      : const <Map<String, dynamic>>[];

  static String _value(dynamic value) =>
      value is String ? value : jsonEncode(value);
}
