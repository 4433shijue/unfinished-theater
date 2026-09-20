import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/gameplay_runtime.dart';
import '../models/gameplay_system.dart';
import '../services/gameplay_rule_rehearsal.dart';
import 'gameplay_system_readout.dart';

/// A rehearsal owns a detached snapshot and has no controller/store dependency.
class GameplayRehearsalDialog extends StatefulWidget {
  const GameplayRehearsalDialog(
      {super.key,
      required this.system,
      required this.state,
      this.authorDiagnostics = false});
  final GameplaySystem system;
  final GameStateSnapshot state;
  final bool authorDiagnostics;
  @override
  State<GameplayRehearsalDialog> createState() =>
      _GameplayRehearsalDialogState();
}

class _GameplayRehearsalDialogState extends State<GameplayRehearsalDialog> {
  late GameStateSnapshot _state = _detachedState();
  final _inputs = <String, TextEditingController>{};
  bool _backstage = false;
  String? _error;
  int _step = 0;
  List<GameplayRuleDiagnosis> _diagnoses = const [];

  GameStateSnapshot _detachedState() =>
      GameStateSnapshot.fromJson(jsonDecode(jsonEncode(widget.state.toJson()))
              as Map<String, dynamic>)
          .copyWith(
        timeLabel:
            widget.state.timeLabel.isEmpty ? '预演起点' : widget.state.timeLabel,
        customVariables: jsonDecode(jsonEncode({
          ...widget.system.initialValues(),
          ...widget.state.customVariables
        })) as Map<String, dynamic>,
        gameplayVariableChanges: const [],
        gameplayVariableRecords: const [],
        gameplayPlayerVariableChanges: const [],
        gameplayVariableWarnings: const [],
      );

  @override
  void initState() {
    super.initState();
    for (final variable in widget.system.variables) {
      _inputs[variable.key] = TextEditingController(
          text: _inputText(variable, _state.customVariables[variable.key]));
    }
  }

  @override
  void dispose() {
    for (final field in _inputs.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _syncInputs() {
    for (final entry in _inputs.entries) {
      entry.value.text = _inputText(widget.system.variableFor(entry.key)!,
          _state.customVariables[entry.key]);
    }
  }

  bool _setStartingValues() {
    final values = Map<String, dynamic>.from(_state.customVariables);
    for (final entry in _inputs.entries) {
      final variable = widget.system.variableFor(entry.key)!;
      dynamic value;
      try {
        value = switch (variable.type) {
          GameplayVariableType.text ||
          GameplayVariableType.choice =>
            entry.value.text,
          _ => jsonDecode(entry.value.text),
        };
      } catch (_) {
        setState(() => _error = '${variable.label}的值格式不正确。');
        return false;
      }
      final valid = switch (variable.type) {
        GameplayVariableType.number ||
        GameplayVariableType.clock =>
          value is num &&
              value.isFinite &&
              (variable.min == null || value >= variable.min!) &&
              (variable.max == null || value <= variable.max!),
        GameplayVariableType.boolean => value is bool,
        GameplayVariableType.choice => variable.options.contains(value),
        GameplayVariableType.list => value is List &&
            value.length <= 40 &&
            value.every((item) => item is String),
        GameplayVariableType.text => value is String,
      };
      if (!valid) {
        setState(() => _error = '${variable.label}的值与类型、范围或选项不匹配。');
        return false;
      }
      values[entry.key] = value;
    }
    _state = _state.copyWith(customVariables: values);
    _error = null;
    return true;
  }

  void _advance({required bool timeChanges}) {
    if (!_setStartingValues()) return;
    try {
      final next = GameplayRuleRehearsal.run(
        system: widget.system,
        previous: _state,
        timeLabel: timeChanges ? '模拟时段 ${_step + 1}' : _state.timeLabel,
        turnId: 'rehearsal-${++_step}',
      );
      setState(() {
        _state = next.state;
        _diagnoses = next.diagnoses;
        _error = null;
        _syncInputs();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      title: const Text('本地预演'),
      content: SizedBox(
        width: math.min(760, math.max(260, size.width - 76)),
        height: math.min(720, math.max(220, size.height - 210)),
        child: ListView(
          children: [
            const Text(
                '这是当前进度的独立副本。可以设置变量起点、推进回合和时间，观察本地规则与余波；预演不会生成正文，也不会保存到正式剧情。'),
            const SizedBox(height: 12),
            Text('已预演 $_step 回合 · ${_state.timeLabel}'),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ExpansionTile(
              title: const Text('调整预演起点'),
              subtitle: const Text('改变起点后，再推进一回合检查条件与代价。'),
              children: [
                for (final entry in _inputs.entries)
                  _startingValue(entry.key, entry.value),
              ],
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: () => _advance(timeChanges: true),
                  icon: const Icon(Icons.schedule),
                  label: const Text('推进时间并结算')),
              OutlinedButton(
                  onPressed: () => _advance(timeChanges: false),
                  child: const Text('同一时段再一回合')),
              TextButton(
                  onPressed: () => setState(() {
                        _state = _detachedState();
                        _step = 0;
                        _error = null;
                        _diagnoses = const [];
                        _syncInputs();
                      }),
                  child: const Text('回到当前进度')),
              TextButton(
                  onPressed: () => setState(() {
                        _state =
                            GameStateSnapshot.empty(widget.state.characterId)
                                .copyWith(
                          timeLabel: '预演开局',
                          customVariables: widget.system.initialValues(),
                          gameplayRuntime: const GameplayRuntimeState(),
                        );
                        _step = 0;
                        _error = null;
                        _diagnoses = const [];
                        _syncInputs();
                      }),
                  child: const Text('从开局重新预演')),
            ]),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('查看幕后结算'),
                value: _backstage,
                onChanged: (value) => setState(() => _backstage = value)),
            const Divider(),
            if ((widget.authorDiagnostics || _backstage) &&
                _diagnoses.isNotEmpty)
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title: const Text('本回合规则检查 · 作者可见'),
                children: [
                  for (final diagnosis in _diagnoses)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(diagnosis.fired
                            ? Icons.check_circle_outline
                            : Icons.info_outline),
                        title: Text(diagnosis.title),
                        subtitle: Text(diagnosis.reason))
                ],
              ),
            GameplaySystemReadout(
                system: widget.system, state: _state, backstage: _backstage),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('结束预演'))
      ],
    );
  }

  String _inputText(GameplayVariableDefinition variable, dynamic value) =>
      variable.type == GameplayVariableType.text ||
              variable.type == GameplayVariableType.choice
          ? '$value'
          : jsonEncode(value);

  Widget _startingValue(String key, TextEditingController controller) {
    final variable = widget.system.variableFor(key)!;
    final options = variable.type == GameplayVariableType.boolean
        ? const {'true': '是', 'false': '否'}
        : variable.type == GameplayVariableType.choice
            ? {for (final option in variable.options) option: option}
            : null;
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: options != null
            ? DropdownButtonFormField<String>(
                key: ValueKey('rehearsal-$key-${controller.text}'),
                initialValue: options.containsKey(controller.text)
                    ? controller.text
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: variable.label),
                items: [
                  for (final option in options.entries)
                    DropdownMenuItem(
                        value: option.key, child: Text(option.value))
                ],
                onChanged: (value) {
                  if (value != null) controller.text = value;
                })
            : TextField(
                key: ValueKey('rehearsal-$key'),
                controller: controller,
                keyboardType: variable.type == GameplayVariableType.number ||
                        variable.type == GameplayVariableType.clock
                    ? const TextInputType.numberWithOptions(
                        decimal: true, signed: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                    labelText: variable.label,
                    helperText: switch (variable.type) {
                      GameplayVariableType.number ||
                      GameplayVariableType.clock =>
                        '范围 ${variable.min ?? "不限"} ~ ${variable.max ?? "不限"}',
                      GameplayVariableType.list => '填写文本数组，例如 ["旧地图"]',
                      _ => null,
                    })));
  }
}
