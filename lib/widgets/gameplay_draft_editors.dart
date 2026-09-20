import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/gameplay_system.dart';

Future<Map<String, dynamic>?> editGameplayVariable(
  BuildContext context,
  GameplayVariableDefinition variable,
) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _VariableEditor(variable: variable),
    );

class _VariableEditor extends StatefulWidget {
  const _VariableEditor({required this.variable});
  final GameplayVariableDefinition variable;
  @override
  State<_VariableEditor> createState() => _VariableEditorState();
}

class _VariableEditorState extends State<_VariableEditor> {
  late final _label = TextEditingController(text: widget.variable.label);
  late final _hint = TextEditingController(text: widget.variable.playerHint);
  late final _description =
      TextEditingController(text: widget.variable.description);
  late final _initial = TextEditingController(
      text: widget.variable.initialValue is String
          ? widget.variable.initialValue as String
          : jsonEncode(widget.variable.initialValue));
  late bool _core = widget.variable.isCore;
  String? _error;

  @override
  void dispose() {
    for (final field in [_label, _hint, _description, _initial]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('编辑 ${widget.variable.label}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: _label,
                    decoration: const InputDecoration(labelText: '名称')),
                TextField(
                    controller: _hint,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: '玩家说明', helperText: '说明含义和能影响它的行动，保留隐藏剧情。')),
                TextField(
                    controller: _description,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '作者说明与更新条件')),
                TextField(
                    controller: _initial,
                    decoration: InputDecoration(
                        labelText: '开局值',
                        helperText: switch (widget.variable.type) {
                          GameplayVariableType.list =>
                            '集合填写 JSON 数组，例如 ["旧地图"]',
                          GameplayVariableType.boolean => '填写 true 或 false',
                          _ => '已有同类变量保留当前进度；开局值用于新变量。',
                        })),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _core,
                    title: const Text('优先显示为关键状态'),
                    onChanged: (value) =>
                        setState(() => _core = value ?? false)),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消')),
          FilledButton(onPressed: _save, child: const Text('保存到草稿')),
        ],
      );

  void _save() {
    try {
      if (_label.text.trim().isEmpty) throw const FormatException('名称不能为空。');
      final type = widget.variable.type;
      final dynamic value = type == GameplayVariableType.text ||
              type == GameplayVariableType.choice
          ? _initial.text
          : jsonDecode(_initial.text);
      final valid = switch (type) {
        GameplayVariableType.number ||
        GameplayVariableType.clock =>
          value is num && value.isFinite,
        GameplayVariableType.boolean => value is bool,
        GameplayVariableType.list => value is List,
        GameplayVariableType.choice => widget.variable.options.contains(value),
        GameplayVariableType.text => value is String,
      };
      if (!valid) throw const FormatException('开局值与变量类型不匹配。');
      if (value is num &&
          ((widget.variable.min != null && value < widget.variable.min!) ||
              (widget.variable.max != null && value > widget.variable.max!))) {
        throw const FormatException('开局值超出了变量范围。');
      }
      Navigator.of(context).pop({
        ...widget.variable.toJson(),
        'label': _label.text.trim(),
        'playerHint': _hint.text.trim(),
        'description': _description.text.trim(),
        'initialValue': value,
        'isCore': _core,
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }
}

Future<Map<String, dynamic>?> editGameplayRule(
        BuildContext context, GameplayRuleDefinition rule) =>
    showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _RuleEditor(rule: rule));

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.rule});
  final GameplayRuleDefinition rule;
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final _title = TextEditingController(text: widget.rule.title);
  late final _summary = TextEditingController(text: widget.rule.playerSummary);
  late final _when = TextEditingController(text: widget.rule.when);
  late final _effect = TextEditingController(text: widget.rule.effect);
  late final _execution = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert({
    for (final entry in widget.rule.toJson().entries)
      if (!{'id', 'title', 'when', 'effect', 'playerSummary', 'visibility'}
          .contains(entry.key))
        entry.key: entry.value,
  }));
  String? _error;

  @override
  void dispose() {
    for (final field in [_title, _summary, _when, _effect, _execution]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('编辑规则'),
        content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: '规则名称')),
                TextField(
                    controller: _summary,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '玩家能预见的规则')),
                TextField(
                    controller: _when,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '触发情景说明')),
                TextField(
                    controller: _effect,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '剧情后果说明')),
                ExpansionTile(
                  title: const Text('高级 · 实际结算条件与效果'),
                  subtitle: const Text('修改自动触发、数值代价和后果后，建议先预演。'),
                  children: [
                    TextField(
                        controller: _execution,
                        minLines: 8,
                        maxLines: 16,
                        decoration: const InputDecoration(
                            labelText: '执行规则 JSON',
                            helperText: '上方文字解释玩法；此处配置本地结算。'))
                  ],
                ),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ],
            ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消')),
          FilledButton(
              onPressed: () {
                try {
                  final execution = jsonDecode(_execution.text);
                  if (execution is! Map ||
                      _title.text.trim().isEmpty ||
                      _when.text.trim().isEmpty ||
                      _effect.text.trim().isEmpty) {
                    throw const FormatException(
                        '填写规则名称、触发说明和后果；执行配置应为 JSON 对象。');
                  }
                  Navigator.of(context).pop({
                    ...widget.rule.toJson(),
                    ...Map<String, dynamic>.from(execution),
                    'id': widget.rule.id,
                    'title': _title.text.trim(),
                    'when': _when.text.trim(),
                    'effect': _effect.text.trim(),
                    'playerSummary': _summary.text.trim(),
                    'visibility': widget.rule.visibility.name,
                  });
                } catch (error) {
                  setState(() => _error = error.toString());
                }
              },
              child: const Text('保存到草稿')),
        ],
      );
}
