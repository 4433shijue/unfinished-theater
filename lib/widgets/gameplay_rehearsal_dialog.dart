import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/gameplay_runtime.dart';
import '../models/gameplay_system.dart';
import '../services/gameplay_turn_engine.dart';
import 'gameplay_system_readout.dart';

/// A rehearsal owns a detached snapshot and has no controller/store dependency.
class GameplayRehearsalDialog extends StatefulWidget {
  const GameplayRehearsalDialog(
      {super.key, required this.system, required this.state});
  final GameplaySystem system;
  final GameStateSnapshot state;
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
        gameplayPlayerVariableChanges: const [],
        gameplayVariableWarnings: const [],
      );

  @override
  void initState() {
    super.initState();
    for (final variable in widget.system.variables) {
      if (variable.type == GameplayVariableType.number ||
          variable.type == GameplayVariableType.clock) {
        _inputs[variable.key] = TextEditingController(
            text: '${_state.customVariables[variable.key]}');
      }
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
      entry.value.text = '${_state.customVariables[entry.key]}';
    }
  }

  bool _setStartingValues() {
    final values = Map<String, dynamic>.from(_state.customVariables);
    for (final entry in _inputs.entries) {
      final variable = widget.system.variableFor(entry.key)!;
      final value = num.tryParse(entry.value.text);
      if (value == null ||
          !value.isFinite ||
          (variable.min != null && value < variable.min!) ||
          (variable.max != null && value > variable.max!)) {
        setState(() => _error = '${variable.label}需要填写范围内的数值。');
        return false;
      }
      values[entry.key] = variable.normalizeValue(value);
    }
    _state = _state.copyWith(customVariables: values);
    _error = null;
    return true;
  }

  void _advance({required bool timeChanges}) {
    if (!_setStartingValues()) return;
    try {
      final next = GameplayTurnEngine.apply(
        system: widget.system,
        previousState: _state,
        narrativeState: _state.copyWith(
          timeLabel: timeChanges ? '模拟时段 ${_step + 1}' : _state.timeLabel,
        ),
        content: '[THEATER_PATCH]{"ops":[]}[/THEATER_PATCH]',
        turnId: 'rehearsal-${++_step}',
      );
      setState(() {
        _state = next;
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
                '这是当前进度的独立副本。可以设置数值起点、推进回合和时间，观察本地规则与余波；预演不会生成正文，也不会保存到正式剧情。'),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      key: ValueKey('rehearsal-${entry.key}'),
                      controller: entry.value,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: InputDecoration(
                          labelText:
                              widget.system.variableFor(entry.key)!.label,
                          helperText:
                              '范围 ${widget.system.variableFor(entry.key)!.min ?? "不限"} ~ ${widget.system.variableFor(entry.key)!.max ?? "不限"}'),
                    ),
                  ),
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
}
