import '../models/game_state.dart';
import '../models/gameplay_system.dart';
import 'gameplay_rule_draft.dart';
import 'gameplay_turn_engine.dart';

class GameplayRuleDiagnosis {
  const GameplayRuleDiagnosis(this.ruleId, this.title, this.reason,
      {this.fired = false});
  final String ruleId;
  final String title;
  final String reason;
  final bool fired;
}

/// Runs the production engine on a detached snapshot and explains its outcome.
/// The clock-only pass uses the same engine to obtain its condition snapshot.
class GameplayRuleRehearsal {
  const GameplayRuleRehearsal._();

  static ({GameStateSnapshot state, List<GameplayRuleDiagnosis> diagnoses})
      run({
    required GameplaySystem system,
    required GameStateSnapshot previous,
    required String timeLabel,
    required String turnId,
  }) {
    final narrative = previous.copyWith(timeLabel: timeLabel);
    final result = GameplayTurnEngine.apply(
      system: system,
      previousState: previous,
      narrativeState: narrative,
      content: '[THEATER_PATCH]{"ops":[]}[/THEATER_PATCH]',
      turnId: turnId,
    );
    final conditionState = GameplayTurnEngine.apply(
      system: GameplaySystem.fromJson({...system.toJson(), 'rules': []}),
      previousState: previous,
      narrativeState: narrative,
      content: '[THEATER_PATCH]{"ops":[]}[/THEATER_PATCH]',
      turnId: turnId,
    );
    final turn = previous.gameplayRuntime.turn + 1;
    final diagnoses = <GameplayRuleDiagnosis>[];
    for (final rule in system.rules) {
      String reason;
      final fired = result.gameplayRuntime.lastRuleTurns[rule.id] == turn;
      final last = previous.gameplayRuntime.lastRuleTurns[rule.id];
      if (!rule.isExecutable) {
        reason = '叙事规则，仅提供剧情说明，不会自动结算。';
      } else if (fired) {
        reason = '本回合已触发，费用与效果按正式引擎结算。';
      } else if (last != null && rule.once) {
        reason = '已经触发过一次，不会重复执行。';
      } else if (last != null && turn - last < rule.cooldownTurns) {
        reason = '冷却中，还需 ${rule.cooldownTurns - (turn - last)} 回合。';
      } else {
        final unmet =
            rule.conditions.where((condition) => !GameplayTurnEngine.matches(
                  conditions: [condition],
                  values: conditionState.customVariables,
                  previousValues: {
                    ...system.initialValues(),
                    ...previous.customVariables,
                  },
                ));
        if (unmet.isNotEmpty) {
          reason =
              '条件未满足：${unmet.map((c) => GameplayRuleDraft.conditionDescription(system, c.toJson())).join('；')}。';
        } else {
          final warnings = result.gameplayVariableWarnings
              .where((warning) => warning.startsWith('${rule.title}：'));
          reason = warnings.isNotEmpty
              ? warnings.join('\n')
              : '本回合未执行，请检查规则配置和本地结算记录。';
        }
      }
      diagnoses.add(
          GameplayRuleDiagnosis(rule.id, rule.title, reason, fired: fired));
    }
    return (state: result, diagnoses: diagnoses);
  }
}
