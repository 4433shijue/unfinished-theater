import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/character_profile.dart';
import '../models/gameplay_system.dart';
import '../theme/app_theme.dart';

enum _GameplaySystemView {
  player,
  backstage,
}

class GameplaySystemDialog extends StatefulWidget {
  const GameplaySystemDialog({
    super.key,
    required this.characterId,
  });

  final String characterId;

  @override
  State<GameplaySystemDialog> createState() => _GameplaySystemDialogState();
}

class _GameplaySystemDialogState extends State<GameplaySystemDialog> {
  _GameplaySystemView _view = _GameplaySystemView.player;
  bool _isGenerating = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final character = _findCharacter(controller.characters);
    final system = character?.gameplaySystem;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 620;
    final width = math.max(
      300.0,
      math.min(760.0, size.width - (compact ? 28.0 : 72.0)),
    );
    final height = math.max(360.0, math.min(720.0, size.height - 96.0));

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 28,
        vertical: compact ? 18 : 28,
      ),
      titlePadding: EdgeInsets.fromLTRB(
        compact ? 18 : 24,
        compact ? 18 : 24,
        compact ? 18 : 24,
        0,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        compact ? 18 : 24,
        16,
        compact ? 18 : 24,
        12,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        compact ? 14 : 20,
        0,
        compact ? 14 : 20,
        compact ? 14 : 18,
      ),
      title: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppTheme.activePrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppTheme.glitchText('玩法系统'),
              maxLines: 2,
              style: compact ? Theme.of(context).textTheme.headlineSmall : null,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        height: height,
        child: character == null
            ? const Center(child: Text('剧场已经不存在。'))
            : system == null
                ? _buildEmptyState(context, character)
                : _buildSystem(context, character, system, controller),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('关闭')),
        ),
        FilledButton.icon(
          onPressed: _isGenerating || character == null
              ? null
              : () => _generate(character),
          icon: _isGenerating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(
            AppTheme.glitchText(
              _isGenerating
                  ? '正在生成'
                  : system == null
                      ? '生成玩法系统'
                      : '重新生成',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, CharacterProfile character) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.activePrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.activeLine),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  size: 34,
                  color: AppTheme.activePrimary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                character.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                AppTheme.glitchText('尚未生成专属玩法参数'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                _ErrorNotice(message: _error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystem(
    BuildContext context,
    CharacterProfile character,
    GameplaySystem system,
    AppStateController controller,
  ) {
    final values = controller.gameplayValuesFor(character.id);
    final changes = controller.gameplayVariableChangesFor(
      character.id,
      playerFacingOnly: _view == _GameplaySystemView.player,
    );
    final warnings = _view == _GameplaySystemView.backstage
        ? controller.gameplayVariableWarningsFor(character.id)
        : const <String>[];
    final variables = _view == _GameplaySystemView.player
        ? system.variables.where((item) => item.isPlayerFacing).toList()
        : system.variables.where((item) => !item.isPlayerFacing).toList();
    final groups = <String, List<GameplayVariableDefinition>>{};
    for (final variable in variables) {
      groups.putIfAbsent(variable.group, () => []).add(variable);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          system.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        if (system.summary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            system.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.45,
                ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_GameplaySystemView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _GameplaySystemView.player,
                icon: Icon(Icons.visibility_outlined),
                label: Text('玩家面板'),
              ),
              ButtonSegment(
                value: _GameplaySystemView.backstage,
                icon: Icon(Icons.theater_comedy_outlined),
                label: Text('幕后参数'),
              ),
            ],
            selected: <_GameplaySystemView>{_view},
            onSelectionChanged: (selection) {
              setState(() => _view = selection.first);
            },
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorNotice(message: _error!),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            children: [
              if (changes.isNotEmpty || warnings.isNotEmpty) ...[
                _GameplayRoundReport(
                  changes: changes,
                  warnings: warnings,
                ),
                const SizedBox(height: 18),
              ],
              if (_view == _GameplaySystemView.backstage) ...[
                _BackstageSummary(system: system),
                const SizedBox(height: 18),
              ],
              for (final entry in groups.entries) ...[
                _VariableGroup(
                  title: entry.key,
                  variables: entry.value,
                  values: values,
                  reveal: _view == _GameplaySystemView.backstage,
                ),
                const SizedBox(height: 18),
              ],
              if (_view == _GameplaySystemView.backstage &&
                  system.rules.isNotEmpty)
                _RuleList(rules: system.rules),
            ],
          ),
        ),
      ],
    );
  }

  CharacterProfile? _findCharacter(List<CharacterProfile> characters) {
    for (final character in characters) {
      if (character.id == widget.characterId) {
        return character;
      }
    }
    return null;
  }

  Future<void> _generate(CharacterProfile character) async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      await context
          .read<AppStateController>()
          .generateGameplaySystem(character.id);
      if (!mounted) {
        return;
      }
      setState(() => _view = _GameplaySystemView.player);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}

class _VariableGroup extends StatelessWidget {
  const _VariableGroup({
    required this.title,
    required this.variables,
    required this.values,
    required this.reveal,
  });

  final String title;
  final List<GameplayVariableDefinition> variables;
  final Map<String, dynamic> values;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.panel.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.activeLine),
          ),
          child: Column(
            children: [
              for (var index = 0; index < variables.length; index++) ...[
                _VariableRow(
                  variable: variables[index],
                  value: values.containsKey(variables[index].key)
                      ? values[variables[index].key]
                      : variables[index].initialValue,
                  reveal: reveal,
                ),
                if (index != variables.length - 1)
                  Divider(height: 1, color: AppTheme.activeLine),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VariableRow extends StatelessWidget {
  const _VariableRow({
    required this.variable,
    required this.value,
    required this.reveal,
  });

  final GameplayVariableDefinition variable;
  final dynamic value;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _visibilityIcon(variable.visibility),
            size: 19,
            color: _visibilityColor(variable.visibility),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variable.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (reveal && variable.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    variable.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              variable.displayValue(value, reveal: reveal),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.contrastText,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameplayRoundReport extends StatelessWidget {
  const _GameplayRoundReport({
    required this.changes,
    required this.warnings,
  });

  final List<String> changes;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.activeSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近一次变量结算',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          for (final change in changes)
            _GameplayReportLine(
              icon: Icons.trending_up_rounded,
              color: AppTheme.activeSecondary,
              text: change,
            ),
          for (final warning in warnings)
            _GameplayReportLine(
              icon: Icons.warning_amber_rounded,
              color: errorColor,
              text: warning,
            ),
        ],
      ),
    );
  }
}

class _GameplayReportLine extends StatelessWidget {
  const _GameplayReportLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackstageSummary extends StatelessWidget {
  const _BackstageSummary({required this.system});

  final GameplaySystem system;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.activeSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _CountLabel(label: '公开 ${system.playerFacingVariableCount}'),
          _CountLabel(label: '幕后 ${system.backstageVariableCount}'),
          _CountLabel(label: '规则 ${system.rules.length}'),
          _CountLabel(label: 'Schema v${system.schemaVersion}'),
        ],
      ),
    );
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList({required this.rules});

  final List<GameplayRuleDefinition> rules;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '触发规则',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _visibilityIcon(rule.visibility),
                  size: 18,
                  color: _visibilityColor(rule.visibility),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '${rule.title}\n',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      children: [
                        TextSpan(
                          text: '${rule.when} → ${rule.effect}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                    height: 1.45,
                                    fontWeight: FontWeight.w400,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppTheme.textMuted,
          ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.26),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
      ),
    );
  }
}

IconData _visibilityIcon(GameplayVariableVisibility visibility) {
  return switch (visibility) {
    GameplayVariableVisibility.public => Icons.visibility_outlined,
    GameplayVariableVisibility.fuzzy => Icons.blur_on_rounded,
    GameplayVariableVisibility.director => Icons.theater_comedy_outlined,
    GameplayVariableVisibility.engine => Icons.memory_rounded,
  };
}

Color _visibilityColor(GameplayVariableVisibility visibility) {
  return switch (visibility) {
    GameplayVariableVisibility.public => AppTheme.activePrimary,
    GameplayVariableVisibility.fuzzy => AppTheme.activeAccent,
    GameplayVariableVisibility.director => AppTheme.activeSecondary,
    GameplayVariableVisibility.engine => AppTheme.textMuted,
  };
}
