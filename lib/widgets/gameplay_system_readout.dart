import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/gameplay_system.dart';
import '../services/gameplay_turn_engine.dart';

/// The same state readout is used by the live panel and isolated rehearsals.
class GameplaySystemReadout extends StatelessWidget {
  const GameplaySystemReadout({
    super.key,
    required this.system,
    required this.state,
    this.backstage = false,
    this.onVariableTap,
  });

  final GameplaySystem system;
  final GameStateSnapshot state;
  final bool backstage;
  final ValueChanged<GameplayVariableDefinition>? onVariableTap;

  @override
  Widget build(BuildContext context) {
    final values = {...system.initialValues(), ...state.customVariables};
    final visible = system.variables.where((item) {
      if (backstage) return true;
      return item.isPlayerFacing &&
          GameplayTurnEngine.matches(
            conditions: item.revealWhen,
            values: values,
          );
    }).toList();
    final ordered = [
      ...visible.where((item) => item.isCore),
      ...visible.where((item) => !item.isCore),
    ];
    final primary = backstage ? visible : ordered.take(5).toList();
    final secondary =
        backstage ? <GameplayVariableDefinition>[] : ordered.skip(5).toList();
    final changes = backstage
        ? state.gameplayVariableChanges
        : state.gameplayPlayerVariableChanges;
    final rules = system.rules.where((rule) =>
        backstage || rule.visibility == GameplayVariableVisibility.public);
    final threads = state.gameplayRuntime.threads
        .where((thread) => backstage || thread.isPlayerFacing)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (system.coreLoop.trim().isNotEmpty)
          _Section(
            title: '这一局怎么玩',
            child: Text(system.coreLoop),
          ),
        if (changes.isNotEmpty)
          _Section(
            title: '最近一回合',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final change in changes) _Line(change)],
            ),
          ),
        _Section(
          title: backstage ? '全部变量 · 作者视角' : '当前关键状态',
          child: primary.isEmpty
              ? const Text('剧情推进后，这里会出现你能察觉的状态。')
              : _VariableGroups(
                  variables: primary,
                  values: values,
                  backstage: backstage,
                  onVariableTap: onVariableTap,
                  legacyHints: system.schemaVersion < 3),
        ),
        if (secondary.isNotEmpty)
          ExpansionTile(
            key: ValueKey('gameplay-secondary-${system.generatedAt}'),
            tilePadding: EdgeInsets.zero,
            title: Text('其他状态（${secondary.length}）'),
            children: [
              _VariableGroups(
                  variables: secondary,
                  values: values,
                  backstage: false,
                  onVariableTap: onVariableTap,
                  legacyHints: system.schemaVersion < 3)
            ],
          ),
        if (rules.isNotEmpty)
          _Section(
            title: backstage ? '触发规则与后果' : '可以预见的规则',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rule.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(backstage
                            ? '${rule.when} → ${rule.effect}'
                            : rule.playerSummary.trim().isNotEmpty
                                ? rule.playerSummary
                                : system.schemaVersion < 3
                                    ? '${rule.when} → ${rule.effect}'
                                    : '留意剧情中的机会与代价，满足条件后会有新的后续。'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        _Section(
          title: '承诺与余波',
          child: threads.isEmpty
              ? const Text('还没有留下需要继续回应的承诺或后果。')
              : Column(
                  children: [
                    for (final thread in threads.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(switch (thread.status.name) {
                          'resolved' => Icons.task_alt,
                          'broken' => Icons.heart_broken_outlined,
                          _ => Icons.pending_actions,
                        }),
                        title: Text(thread.title),
                        subtitle: Text([
                          if (thread.description.isNotEmpty) thread.description,
                          if (thread.reason.isNotEmpty) thread.reason,
                        ].join('\n')),
                        trailing: Text(switch (thread.status.name) {
                          'resolved' => '已兑现',
                          'broken' => '已破裂',
                          _ => '待回应',
                        }),
                      ),
                  ],
                ),
        ),
        if (backstage && state.gameplayVariableWarnings.isNotEmpty)
          _Section(
            title: '结算检查',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final warning in state.gameplayVariableWarnings)
                  _Line(warning)
              ],
            ),
          ),
      ],
    );
  }
}

class _VariableGroups extends StatelessWidget {
  const _VariableGroups(
      {required this.variables,
      required this.values,
      required this.backstage,
      this.onVariableTap,
      required this.legacyHints});
  final List<GameplayVariableDefinition> variables;
  final Map<String, dynamic> values;
  final bool backstage;
  final bool legacyHints;
  final ValueChanged<GameplayVariableDefinition>? onVariableTap;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<GameplayVariableDefinition>>{};
    for (final variable in variables) {
      groups.putIfAbsent(variable.group, () => []).add(variable);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child:
                Text(group.key, style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final variable in group.value)
            _VariableTile(
                variable: variable,
                value: values[variable.key],
                backstage: backstage,
                onTap: onVariableTap == null ||
                        variable.visibility == GameplayVariableVisibility.engine
                    ? null
                    : () => onVariableTap!(variable),
                legacyHints: legacyHints),
        ],
      ],
    );
  }
}

class _VariableTile extends StatelessWidget {
  const _VariableTile(
      {required this.variable,
      required this.value,
      required this.backstage,
      this.onTap,
      required this.legacyHints});
  final GameplayVariableDefinition variable;
  final dynamic value;
  final bool backstage;
  final bool legacyHints;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hint = backstage
        ? variable.description
        : variable.playerHint.trim().isNotEmpty
            ? variable.playerHint
            : legacyHints
                ? variable.description
                : '';
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Text(variable.label,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Flexible(
                  child: Text(variable.displayValue(value, reveal: backstage),
                      textAlign: TextAlign.end)),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.history, size: 18),
              ],
            ],
          ),
          if (hint.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (backstage)
            Text(
                '${variable.key} · ${variable.visibility.name} · ${variable.authority.name}',
                style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: '查看${variable.label}的变化记录',
      child: InkWell(
        key: ValueKey('variable-history-${variable.key}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text),
      );
}
