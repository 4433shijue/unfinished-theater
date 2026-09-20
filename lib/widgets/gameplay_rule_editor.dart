import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/gameplay_system.dart';
import '../services/gameplay_rule_draft.dart';
import '../services/gameplay_system_draft.dart';
import 'gameplay_rehearsal_dialog.dart';

class GameplayRuleEditor extends StatefulWidget {
  const GameplayRuleEditor({
    super.key,
    required this.system,
    required this.rule,
    required this.state,
  });

  final GameplaySystem system;
  final GameplayRuleDefinition rule;
  final GameStateSnapshot state;

  @override
  State<GameplayRuleEditor> createState() => _GameplayRuleEditorState();
}

class _GameplayRuleEditorState extends State<GameplayRuleEditor> {
  late final _title = TextEditingController(text: widget.rule.title);
  late final _summary = TextEditingController(text: widget.rule.playerSummary);
  late final _when = TextEditingController(text: widget.rule.when);
  late final _effect = TextEditingController(text: widget.rule.effect);
  late Map<String, dynamic> _execution =
      GameplayRuleDraft.executionOf(widget.rule);
  final _json = TextEditingController();
  bool _advanced = false;
  int _revision = 0;
  String? _error;

  bool get _structured => GameplayRuleDraft.isStructured(_execution);
  List<GameplayVariableDefinition> get _writable =>
      widget.system.variables.where(GameplayRuleDraft.writable).toList();

  @override
  void dispose() {
    for (final field in [_title, _summary, _when, _effect, _json]) {
      field.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(String field) =>
      (_execution[field] as List? ?? []).cast<Map<String, dynamic>>();

  void _change(VoidCallback update, {bool refresh = false}) => setState(() {
        update();
        _error = null;
        if (refresh) _revision++;
      });

  void _add(String field, Map<String, dynamic> row) => _change(() {
        _execution[field] = [..._rows(field), row];
      });

  void _remove(String field, int index) => _change(() {
        _execution[field] = [..._rows(field)]..removeAt(index);
      }, refresh: true);

  Map<String, dynamic> _validated({Map<String, dynamic>? execution}) =>
      GameplayRuleDraft.validate(
        system: widget.system,
        original: widget.rule,
        execution: execution ?? _execution,
        title: _title.text,
        when: _when.text,
        effect: _effect.text,
        playerSummary: _summary.text,
      );

  void _openJson() => setState(() {
        _json.text = const JsonEncoder.withIndent('  ').convert(_execution);
        _advanced = true;
        _error = null;
      });

  Map<String, dynamic> _readJson() {
    final decoded = jsonDecode(_json.text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('执行配置应为 JSON 对象。');
    }
    _validated(execution: decoded);
    return decoded;
  }

  bool _applyJson() {
    try {
      final next = _readJson();
      setState(() {
        _execution = next;
        _advanced = false;
        _revision++;
        _error = null;
      });
      return true;
    } catch (error) {
      setState(() => _error = error.toString());
      return false;
    }
  }

  void _save() {
    try {
      if (_advanced && !_applyJson()) return;
      Navigator.of(context).pop(_validated());
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _rehearse() async {
    try {
      if (_advanced && !_applyJson()) return;
      final rule = _validated();
      final system = GameplaySystem.fromJson({
        ...widget.system.toJson(),
        'rules': [
          for (final existing in widget.system.rules)
            existing.id == widget.rule.id ? rule : existing.toJson(),
        ],
      });
      final draft = GameplaySystemDraft.preview(
          current: widget.system, generated: system);
      await showDialog<void>(
          context: context,
          builder: (_) => GameplayRehearsalDialog(
              system: system,
              state: widget.state.copyWith(
                  customVariables:
                      draft.migrateValues(widget.state.customVariables),
                  gameplayRuntime:
                      draft.migrateRuntime(widget.state.gameplayRuntime)),
              authorDiagnostics: true));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final description = GameplayRuleDraft.describe(widget.system, _execution);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      title: const Text('编辑规则'),
      content: SizedBox(
        width: math.min(720, math.max(260, size.width - 76)),
        height: math.min(760, math.max(220, size.height - 210)),
        child: ListView(children: [
          TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '规则名称')),
          TextField(
              controller: _summary,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: '玩家能预见的规则',
                  helperText: '单独填写玩家已知的线索与代价，不会自动复制幕后条件。')),
          const SizedBox(height: 16),
          if (!_structured && !_advanced) ...[
            const Text('叙事规则', style: TextStyle(fontWeight: FontWeight.w700)),
            const Text('这条旧规则只说明剧情，不会自动修改数值。转换前请自行确定条件和效果。'),
            TextField(
                controller: _when,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '触发情景说明')),
            TextField(
                controller: _effect,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '剧情后果说明')),
            TextButton.icon(
                key: const ValueKey('rule-convert'),
                onPressed: () => _change(() {
                      _execution.addAll({
                        'conditions': <Map<String, dynamic>>[],
                        'costs': <Map<String, dynamic>>[],
                        'effects': <Map<String, dynamic>>[],
                        'threads': <Map<String, dynamic>>[]
                      });
                    }),
                icon: const Icon(Icons.build_outlined),
                label: const Text('手动配置自动规则')),
          ],
          if (_advanced) ...[
            const Text('高级执行 JSON',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Text('与表单使用同一份草稿。切回表单前会校验，不会静默丢弃错误字段。'),
            TextField(
                key: const ValueKey('rule-json'),
                controller: _json,
                minLines: 10,
                maxLines: 22,
                decoration: const InputDecoration(labelText: '执行规则 JSON')),
            TextButton(onPressed: _applyJson, child: const Text('校验并回到表单')),
          ] else ...[
            if (_structured) ...[
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('作者剧情安排'),
                subtitle: const Text('保留触发情景和后续剧情；实际结算以下方表单为准。'),
                children: [
                  TextField(
                      controller: _when,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '触发情景说明')),
                  TextField(
                      controller: _effect,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '剧情后果说明')),
                ],
              ),
              _section(
                  '同时满足以下条件（并且）',
                  'conditions',
                  16,
                  widget.system.variables.isEmpty
                      ? null
                      : () {
                          final variable = widget.system.variables.first;
                          _add('conditions', {
                            'path': variable.key,
                            'op': 'eq',
                            'value': variable.initialValue
                          });
                        },
                  _condition),
              _section(
                  '触发时支付的代价',
                  'costs',
                  16,
                  _writable.any(GameplayRuleDraft.numeric)
                      ? () {
                          final variable =
                              _writable.firstWhere(GameplayRuleDraft.numeric);
                          _add('costs', {'path': variable.key, 'amount': 0});
                        }
                      : null,
                  _cost),
              _section(
                  '执行后的变化',
                  'effects',
                  24,
                  _writable.isEmpty
                      ? null
                      : () {
                          final variable = _writable.first;
                          _add('effects', {
                            'path': variable.key,
                            'op': 'set',
                            'value': variable.initialValue
                          });
                        },
                  _effectRow),
              _section(
                  '承诺与余波',
                  'threads',
                  8,
                  () => _add('threads', {
                        'op': 'open',
                        'id': '',
                        'title': '',
                        'description': '',
                        'reason': '',
                        'visibility': 'public',
                      }),
                  _thread),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('只触发一次'),
                  value: _execution['once'] != false,
                  onChanged: (value) =>
                      _change(() => _execution['once'] = value)),
              TextFormField(
                  key: ValueKey('rule-cooldown-$_revision'),
                  initialValue: '${_execution['cooldownTurns'] ?? 0}',
                  enabled: _execution['once'] == false,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '最少间隔回合',
                      helperText: '重复规则使用；0 或 1 表示下一回合即可再次触发。'),
                  onChanged: (value) => _change(() =>
                      _execution['cooldownTurns'] =
                          int.tryParse(value) ?? value)),
              const SizedBox(height: 18),
              const Text('实际执行说明 · 仅作者可见',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('${description.when}\n${description.effect}',
                  key: const ValueKey('rule-execution-description')),
              const Text('执行说明始终根据当前配置生成。玩家说明和作者剧情安排单独保留。'),
              TextButton(
                  onPressed: () {
                    _when.text = description.when;
                    _effect.text = description.effect;
                    setState(() {});
                  },
                  child: const Text('采用执行说明作为作者剧情安排')),
            ],
            TextButton.icon(
                onPressed: _openJson,
                icon: const Icon(Icons.code),
                label: const Text('高级 JSON')),
          ],
          if (_error != null)
            Text(_error!,
                key: const ValueKey('rule-editor-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        OutlinedButton(onPressed: _rehearse, child: const Text('预演草稿')),
        FilledButton(onPressed: _save, child: const Text('保存到草稿')),
      ],
    );
  }

  Widget _section(String title, String field, int limit, VoidCallback? add,
      Widget Function(Map<String, dynamic>, int) builder) {
    final rows = _rows(field);
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          for (var index = 0; index < rows.length; index++)
            Card(
                key: ValueKey('$field-$index-$_revision'),
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          builder(rows[index], index),
                          Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                  key: ValueKey('remove-$field-$index'),
                                  onPressed: () => _remove(field, index),
                                  icon: const Icon(Icons.remove_circle_outline,
                                      size: 18),
                                  label: const Text('移除这一项'))),
                        ]))),
          TextButton.icon(
              key: ValueKey('add-$field'),
              onPressed: rows.length < limit ? add : null,
              icon: const Icon(Icons.add, size: 18),
              label: Text(switch (field) {
                'conditions' => '添加条件',
                'costs' => '添加代价',
                'effects' => '添加变化',
                _ => '添加承诺操作',
              })),
          if (add == null) const Text('当前没有可用于这一项的变量。'),
        ]));
  }

  Widget _select(String label, String? value, Map<String, String> options,
          ValueChanged<String> changed,
          {Key? key}) =>
      DropdownButtonFormField<String>(
        key: key,
        initialValue: options.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final option in options.entries)
            DropdownMenuItem(
                value: option.key,
                child: Text(option.value, overflow: TextOverflow.ellipsis))
        ],
        onChanged: (value) {
          if (value != null) changed(value);
        },
      );

  Widget _variable(String field, int index, Map<String, dynamic> row,
          List<GameplayVariableDefinition> variables) =>
      _select(
        '变量',
        row['path'] as String?,
        {for (final variable in variables) variable.key: variable.label},
        (path) => _change(() {
          row['path'] = path;
          if (field != 'costs') {
            row['op'] = field == 'conditions' ? 'eq' : 'set';
            row['value'] = widget.system.variableFor(path)!.initialValue;
          }
        }, refresh: true),
        key: ValueKey('$field-path-$index'),
      );

  Widget _condition(Map<String, dynamic> row, int index) {
    final variable = widget.system.variableFor('${row['path']}');
    return Column(children: [
      _variable('conditions', index, row, widget.system.variables),
      if (variable != null) ...[
        _select(
            '比较方式',
            row['op'] as String?,
            {
              for (final op in GameplayRuleDraft.conditionOps(variable))
                op: GameplayRuleDraft.opLabels[op]!,
            },
            (op) => _change(() {
                  row['op'] = op;
                  row['value'] =
                      GameplayRuleDraft.defaultValue(variable, op: op);
                }, refresh: true),
            key: ValueKey('condition-op-$index')),
        if (row['op'] != 'changed')
          _valueField(variable, row, 'condition-value-$index'),
      ],
    ]);
  }

  Widget _cost(Map<String, dynamic> row, int index) => Column(children: [
        _variable('costs', index, row,
            _writable.where(GameplayRuleDraft.numeric).toList()),
        TextFormField(
            key: ValueKey('cost-amount-$index'),
            initialValue: '${row['amount']}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: '扣除数值', helperText: '余额不足时整条规则不执行。'),
            onChanged: (value) =>
                _change(() => row['amount'] = num.tryParse(value) ?? value)),
      ]);

  Widget _effectRow(Map<String, dynamic> row, int index) {
    final variable = widget.system.variableFor('${row['path']}');
    return Column(children: [
      _variable('effects', index, row, _writable),
      if (variable != null) ...[
        _select(
            '变化方式',
            row['op'] as String?,
            {
              for (final op in GameplayRuleDraft.effectOps(variable))
                op: GameplayRuleDraft.opLabels[op]!,
            },
            (op) => _change(() {
                  row['op'] = op;
                  row['value'] =
                      GameplayRuleDraft.defaultValue(variable, op: op);
                }, refresh: true),
            key: ValueKey('effect-op-$index')),
        _valueField(variable, row, 'effect-value-$index'),
      ],
    ]);
  }

  Widget _valueField(GameplayVariableDefinition variable,
      Map<String, dynamic> row, String key) {
    final textItem = ['contains', 'append', 'remove'].contains(row['op']);
    if (!textItem && variable.type == GameplayVariableType.boolean) {
      return _select('值', '${row['value']}', const {'true': '是', 'false': '否'},
          (value) => _change(() => row['value'] = value == 'true'),
          key: ValueKey(key));
    }
    if (!textItem && variable.type == GameplayVariableType.choice) {
      return _select(
          '值',
          row['value'] as String?,
          {for (final option in variable.options) option: option},
          (value) => _change(() => row['value'] = value),
          key: ValueKey(key));
    }
    final numeric = GameplayRuleDraft.numeric(variable);
    final list = !textItem && variable.type == GameplayVariableType.list;
    return TextFormField(
        key: ValueKey(key),
        initialValue: list ? jsonEncode(row['value']) : '${row['value'] ?? ''}',
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(
            labelText: textItem ? '文本项' : '值',
            helperText: list
                ? '填写文本数组，例如 ["旧地图", "钥匙"]'
                : numeric
                    ? '变量范围 ${variable.min ?? "不限"} ~ ${variable.max ?? "不限"}；增减可填写负数。'
                    : null),
        onChanged: (value) => _change(() {
              if (numeric) {
                row['value'] = num.tryParse(value) ?? value;
              } else if (list) {
                try {
                  row['value'] = jsonDecode(value);
                } catch (_) {
                  row['value'] = value;
                }
              } else {
                row['value'] = value;
              }
            }));
  }

  Widget _thread(Map<String, dynamic> row, int index) => Column(children: [
        _select(
            '承诺操作',
            row['op'] as String?,
            const {
              'open': '留下承诺或余波',
              'resolve': '兑现已有事项',
              'break': '打破已有事项',
            },
            (value) => _change(() => row['op'] = value, refresh: true),
            key: ValueKey('thread-op-$index')),
        for (final field in [
          'id',
          if (row['op'] == 'open') ...['title', 'description'],
          'reason'
        ])
          TextFormField(
              key: ValueKey('thread-$field-$index'),
              initialValue: '${row[field] ?? ''}',
              decoration: InputDecoration(
                  labelText: switch (field) {
                    'id' => '事项标识',
                    'title' => '事项标题',
                    'description' => '事项说明',
                    _ => '变化原因',
                  },
                  helperText: field == 'id' ? '兑现或打破时，沿用已有事项的同一标识。' : null),
              onChanged: (value) => _change(() => row[field] = value)),
        _select(
            '事项可见范围',
            row['visibility'] as String? ?? 'public',
            const {'public': '玩家可见', 'director': '幕后事项'},
            (value) => _change(() => row['visibility'] = value),
            key: ValueKey('thread-visibility-$index')),
      ]);
}
