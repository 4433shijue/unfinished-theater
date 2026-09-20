import 'dart:convert';

import '../models/gameplay_system.dart';

class GameplaySystemParser {
  const GameplaySystemParser._();

  static GameplaySystem parse(String raw) {
    var normalized = raw.trim();
    normalized = normalized
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    final start = normalized.indexOf('{');
    final end = normalized.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('AI 没有返回玩法系统 JSON。');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(normalized.substring(start, end + 1));
    } catch (_) {
      throw const FormatException('玩法系统 JSON 无法解析，请重新生成。');
    }
    if (decoded is! Map) {
      throw const FormatException('玩法系统必须是一个 JSON 对象。');
    }

    final json = Map<String, dynamic>.from(decoded);
    final system = GameplaySystem.fromJson(json);
    _validateSchema(json, system);
    if (!system.isUsable) {
      throw const FormatException('AI 生成的有效变量不足，请重新生成。');
    }
    if (system.playerFacingVariableCount < 2) {
      throw const FormatException('玩法系统缺少玩家可见变量，请重新生成。');
    }
    return system;
  }

  /// Checks generated drafts without silently dropping malformed rule entries.
  static void validateSystem(GameplaySystem system) {
    _validateSchema(system.toJson(), system);
    if (!system.isUsable || system.playerFacingVariableCount < 2) {
      throw const FormatException('玩法草案至少需要 4 个有效变量和 2 个玩家可见变量。');
    }
  }

  static void _validateSchema(
    Map<String, dynamic> json,
    GameplaySystem system,
  ) {
    final strict = (int.tryParse('${json['schemaVersion']}') ?? 1) >= 3;
    final rawVariables = json['variables'];
    if (strict) {
      if (rawVariables is! List || rawVariables.length > 36) {
        _invalid('变量', '必须是最多 36 项的数组');
      }
      final seen = <String>{};
      for (final raw in rawVariables) {
        if (raw is! Map) _invalid('变量', '每项必须是对象');
        final variable = Map<String, dynamic>.from(raw);
        final key = variable['key']?.toString() ?? '';
        final label = '变量「$key」';
        if (!seen.add(key)) _invalid(label, 'key 重复');
        if (system.variableFor(key) == null) {
          _invalid(label, 'key 无效、变量超过数量限制，或重复维护了 NPC 关系');
        }
        if (!GameplayVariableType.values
            .any((v) => v.name == variable['type'])) {
          _invalid(label, 'type 不是支持的变量类型');
        }
        if (!GameplayVariableVisibility.values
            .any((v) => v.name == variable['visibility'])) {
          _invalid(label, 'visibility 不是支持的可见级别');
        }
        if (!GameplayVariableAuthority.values
            .any((v) => v.name == variable['authority'])) {
          _invalid(label, 'authority 不是支持的更新权限');
        }
        final definition = system.variableFor(key)!;
        if (_isNumeric(definition)) {
          if (!_finite(variable['min']) ||
              !_finite(variable['max']) ||
              (variable['min'] as num) > (variable['max'] as num)) {
            _invalid(label, '数值范围 min/max 必须有效且 min 不大于 max');
          }
          if (variable.containsKey('maxDelta') &&
              (!_finite(variable['maxDelta']) ||
                  (variable['maxDelta'] as num) <= 0)) {
            _invalid(label, 'maxDelta 必须是正数');
          }
        }
        if (definition.type == GameplayVariableType.choice &&
            (variable['options'] is! List || definition.options.isEmpty)) {
          _invalid(label, '选项变量必须提供非空 options');
        }
        if (!variable.containsKey('initialValue') ||
            !_validValue(variable['initialValue'], definition)) {
          _invalid(label, 'initialValue 与类型、范围或选项不匹配');
        }
        if (variable.containsKey('isCore') && variable['isCore'] is! bool) {
          _invalid(label, 'isCore 必须是布尔值');
        }
        if (variable.containsKey('advanceOnTimeChange')) {
          final step = variable['advanceOnTimeChange'];
          if (definition.type != GameplayVariableType.clock ||
              definition.authority != GameplayVariableAuthority.rule ||
              !_finite(step) ||
              (step as num) <= 0) {
            _invalid(label, '有效时间推进仅支持 rule 托管的 clock，步长须为正数');
          }
        }
        if (variable.containsKey('revealWhen')) {
          _conditions(variable['revealWhen'], system, '$label 的揭示条件',
              allowEmpty: true);
        }
      }
    }
    final rawRules = json['rules'];
    if (rawRules != null && rawRules is! List) {
      if (strict) _invalid('规则', '必须是数组');
      return;
    }
    if (rawRules is! List) return;
    if (strict && rawRules.length > 20) _invalid('规则', '不能超过 20 条');
    final ids = <String>{};
    for (final raw in rawRules) {
      if (raw is! Map) {
        if (strict) _invalid('规则', '每项必须是对象');
        continue;
      }
      final rule = Map<String, dynamic>.from(raw);
      final label = '规则「${rule['title'] ?? rule['id'] ?? '未命名'}」';
      final structured =
          ['conditions', 'effects', 'costs', 'threads'].any(rule.containsKey);
      if (!strict && !structured) continue;
      final id = rule['id'];
      if (id is! String || id.trim().isEmpty || !ids.add(id.trim())) {
        _invalid(label, 'id 必须非空且唯一');
      }
      if (id.trim().length > 80) _invalid(label, 'id 不能超过 80 个字符');
      for (final field in ['when', 'effect']) {
        if (rule[field] is! String || (rule[field] as String).trim().isEmpty) {
          _invalid(label, '缺少 $field 的文字说明');
        }
      }
      if (!structured) continue; // Existing text rules remain readable.
      if (!['public', 'fuzzy', 'director', 'engine']
          .contains(rule['visibility'])) {
        _invalid(label, 'visibility 不是支持的可见级别');
      }
      if (strict &&
          ['public', 'fuzzy'].contains(rule['visibility']) &&
          (rule['playerSummary'] is! String ||
              (rule['playerSummary'] as String).trim().isEmpty)) {
        _invalid(label, '公开规则须填写非剧透的 playerSummary，避免展示幕后触发说明');
      }
      _conditions(rule['conditions'], system, label);
      if (rule.containsKey('once') && rule['once'] is! bool) {
        _invalid(label, 'once 必须是布尔值');
      }
      final cooldown = rule['cooldownTurns'];
      if (cooldown != null &&
          (cooldown is! int || cooldown < 0 || cooldown > 10000)) {
        _invalid(label, 'cooldownTurns 必须是 0–10000 之间的整数');
      }
      final effects = _entries(rule['effects'], '$label 的效果');
      final costs = _entries(rule['costs'], '$label 的费用');
      final threads = _entries(rule['threads'], '$label 的承诺与余波');
      if (effects.length > 24 || costs.length > 16 || threads.length > 8) {
        _invalid(label, '每条规则最多 24 项效果、16 项费用和 8 项承诺操作');
      }
      if (effects.isEmpty && threads.isEmpty) {
        _invalid(label, '结构化规则至少需要一条效果或承诺与余波操作');
      }
      for (final cost in costs) {
        final definition =
            _variable(cost['path'], system, label, writable: true);
        if (!_isNumeric(definition) ||
            !_finite(cost['amount']) ||
            (cost['amount'] as num) < 0) {
          _invalid(label, '费用必须引用数值变量，amount 必须是非负数');
        }
      }
      for (final effect in effects) {
        final definition =
            _variable(effect['path'], system, label, writable: true);
        final op = effect['op'];
        final value = effect['value'];
        switch (op) {
          case 'set':
            if (!_validValue(value, definition)) {
              _invalid(label, '${definition.key} 的赋值不符合类型、范围或选项');
            }
          case 'inc':
            if (!_isNumeric(definition) || !_finite(value)) {
              _invalid(label, 'inc 仅支持数值变量和有限数值');
            }
          case 'append':
          case 'remove':
            if (definition.type != GameplayVariableType.list ||
                value is! String ||
                value.trim().isEmpty) {
              _invalid(label, '$op 仅支持列表变量和非空文本项');
            }
          default:
            _invalid(label, '不支持的效果操作 $op');
        }
      }
      for (final thread in threads) {
        if (!['open', 'resolve', 'break'].contains(thread['op'])) {
          _invalid(label, '承诺与余波操作必须为 open、resolve 或 break');
        }
        for (final field in [
          'id',
          'reason',
          if (thread['op'] == 'open') 'title'
        ]) {
          if (thread[field] is! String ||
              (thread[field] as String).trim().isEmpty) {
            _invalid(label, '承诺与余波缺少 $field');
          }
        }
        if ((thread['id'] as String).trim().length > 80) {
          _invalid(label, '承诺与余波 id 不能超过 80 个字符');
        }
        for (final field
            in {'title': 80, 'description': 600, 'reason': 300}.entries) {
          final value = thread[field.key];
          if (value != null &&
              (value is! String || value.trim().length > field.value)) {
            _invalid(label, '承诺与余波 ${field.key} 必须是最多 ${field.value} 字的文本');
          }
        }
        if (thread['visibility'] != null &&
            !['public', 'director'].contains(thread['visibility'])) {
          _invalid(label, '承诺与余波仅支持 public 或 director 可见级别');
        }
      }
    }
  }

  static void _conditions(dynamic raw, GameplaySystem system, String label,
      {bool allowEmpty = false}) {
    final conditions = _entries(raw, '$label 的条件');
    if (!allowEmpty && conditions.isEmpty) _invalid(label, '缺少非空触发条件');
    if (conditions.length > 16) _invalid(label, '最多支持 16 项条件');
    for (final condition in conditions) {
      final definition = _variable(condition['path'], system, label);
      final op = condition['op'];
      if (!['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'contains', 'changed']
          .contains(op)) {
        _invalid(label, '不支持的条件操作 $op');
      }
      if (op == 'changed') continue;
      final value = condition['value'];
      if (['gt', 'gte', 'lt', 'lte'].contains(op)) {
        if (!_isNumeric(definition) || !_finite(value)) {
          _invalid(label, '数值比较仅支持数值变量和有限数值');
        }
      } else if (op == 'contains') {
        if (![GameplayVariableType.text, GameplayVariableType.list]
                .contains(definition.type) ||
            value is! String ||
            value.isEmpty) {
          _invalid(label, 'contains 仅支持文本或列表变量和非空文本');
        }
      } else if (!_validValue(value, definition, enforceRange: false)) {
        _invalid(label, '${definition.key} 的比较值与变量类型不匹配');
      }
    }
  }

  static List<Map<String, dynamic>> _entries(dynamic raw, String label) {
    if (raw == null) return const [];
    if (raw is! List || raw.any((item) => item is! Map)) {
      _invalid(label, '必须是对象数组');
    }
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static GameplayVariableDefinition _variable(
      dynamic path, GameplaySystem system, String label,
      {bool writable = false}) {
    final definition = path is String ? system.variableFor(path) : null;
    if (definition == null) _invalid(label, '引用的变量「$path」不存在');
    if (writable &&
        ![GameplayVariableAuthority.ai, GameplayVariableAuthority.rule]
            .contains(definition.authority)) {
      _invalid(label, '不能修改 player/computed 托管变量「$path」');
    }
    return definition;
  }

  static bool _isNumeric(GameplayVariableDefinition definition) =>
      definition.type == GameplayVariableType.number ||
      definition.type == GameplayVariableType.clock;

  static bool _finite(dynamic value) => value is num && value.isFinite;

  static bool _validValue(dynamic value, GameplayVariableDefinition definition,
      {bool enforceRange = true}) {
    switch (definition.type) {
      case GameplayVariableType.number:
      case GameplayVariableType.clock:
        return _finite(value) &&
            (!enforceRange ||
                ((definition.min == null ||
                        (value as num) >= definition.min!) &&
                    (definition.max == null ||
                        (value as num) <= definition.max!)));
      case GameplayVariableType.text:
        return value is String;
      case GameplayVariableType.boolean:
        return value is bool;
      case GameplayVariableType.choice:
        return value is String && definition.options.contains(value);
      case GameplayVariableType.list:
        return value is List &&
            value.length <= 40 &&
            value.every((item) => item is String);
    }
  }

  static Never _invalid(String label, String reason) =>
      throw FormatException('$label：$reason。请调整草案或重新生成。');
}
