import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/gameplay_system.dart';
import '../models/game_state.dart';
import 'gameplay_rule_editor.dart';

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
  BuildContext context,
  GameplayRuleDefinition rule, {
  required GameplaySystem system,
  required GameStateSnapshot state,
}) =>
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => GameplayRuleEditor(
        system: system,
        rule: rule,
        state: state,
      ),
    );
