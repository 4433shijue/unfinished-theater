import 'dart:convert';

import '../models/game_state.dart';
import '../models/gameplay_runtime.dart';
import '../models/gameplay_system.dart';
import '../models/gameplay_variable_change.dart';
import 'gameplay_patch_engine.dart';

/// Settles one accepted narrative turn. Conditions observe one frozen snapshot,
/// so a rule's effects cannot recursively trigger more rules in the same turn.
class GameplayTurnEngine {
  const GameplayTurnEngine._();

  static GameStateSnapshot apply({
    required GameplaySystem system,
    required GameStateSnapshot previousState,
    required GameStateSnapshot narrativeState,
    required String content,
    bool patchExpected = true,
    String? turnId,
  }) {
    final runtime = previousState.gameplayRuntime;
    final identity = turnId?.trim().isNotEmpty == true
        ? turnId!.trim()
        : _fallbackTurnId(narrativeState, content);
    final initial = GameplayPatchEngine.initializeValues(
        system, previousState.customVariables);
    final metrics = GameplayPatchEngine.removeClaimedLegacyMetrics(
        system, narrativeState.metrics);
    if (runtime.lastTurnId == identity) {
      return narrativeState.copyWith(
        metrics: metrics,
        customVariables: initial,
        customVariablesRevision: previousState.customVariablesRevision,
        gameplayRuntime: runtime,
        gameplayVariableChanges: previousState.gameplayVariableChanges,
        gameplayPlayerVariableChanges:
            previousState.gameplayPlayerVariableChanges,
        gameplayVariableWarnings: previousState.gameplayVariableWarnings,
        gameplayVariableHistoryVersion:
            previousState.gameplayVariableHistoryVersion,
        gameplayVariableRecords: previousState.gameplayVariableRecords,
      );
    }
    final parsed = GameplayPatchParser.parseResult(content);
    if (!parsed.isValid) {
      return narrativeState.copyWith(
        metrics: metrics,
        customVariables: initial,
        customVariablesRevision: previousState.customVariablesRevision,
        gameplayRuntime: runtime,
        gameplayVariableChanges: const [],
        gameplayPlayerVariableChanges: const [],
        gameplayVariableHistoryVersion: 1,
        gameplayVariableRecords: const [],
        gameplayVariableWarnings: [
          if (parsed.error != null)
            parsed.error!
          else if (patchExpected)
            '本轮缺少变量补丁，已保留上一轮玩法状态',
        ],
      );
    }

    final turn = runtime.turn + 1;
    final ai = GameplayPatchEngine.applyAiPatch(
      system: system,
      currentValues: initial,
      operations: parsed.operations,
    );
    var values = ai.values;
    final receiptSteps = <String, List<GameplayVariableChangeStep>>{};
    final aiReceiptValues = Map<String, dynamic>.from(initial);
    for (final change in ai.changes) {
      final beforeValues = Map<String, dynamic>.from(aiReceiptValues);
      aiReceiptValues[change.path] = change.after;
      _recordVariableStep(
        system: system,
        receipts: receiptSteps,
        path: change.path,
        beforeValues: beforeValues,
        afterValues: aiReceiptValues,
        source: 'ai',
        reason: change.reason,
      );
    }
    final warnings = <String>[...ai.rejections];
    final reasons = <String, String>{
      for (final change in ai.changes) change.path: change.reason
    };
    var threads = <GameplayStoryThread>[...runtime.threads];
    final events = <GameplayRuntimeEvent>[...runtime.events];
    final changes = <String>[];
    final playerChanges = <String>[];
    final fired = <String, int>{...runtime.lastRuleTurns};
    final beforeTime = previousState.timeLabel.trim();
    final afterTime = narrativeState.timeLabel.trim();
    final timeAdvanced = beforeTime.isNotEmpty &&
        afterTime.isNotEmpty &&
        beforeTime != afterTime;

    if (timeAdvanced) {
      for (final variable in system.variables) {
        final advance = variable.advanceOnTimeChange;
        if (variable.type != GameplayVariableType.clock ||
            variable.authority != GameplayVariableAuthority.rule ||
            advance == null ||
            !advance.isFinite ||
            advance <= 0) {
          continue;
        }
        final current = _number(values[variable.key]);
        if (current == null || !(current + advance).isFinite) continue;
        final beforeValues = Map<String, dynamic>.from(values);
        values[variable.key] = variable.normalizeValue(current + advance);
        reasons[variable.key] = '剧情时间推进';
        _recordVariableStep(
          system: system,
          receipts: receiptSteps,
          path: variable.key,
          beforeValues: beforeValues,
          afterValues: values,
          source: 'time',
          reason: '剧情时间推进',
        );
      }
    }

    for (final operation in parsed.threads.take(8)) {
      final result = _applyThread(threads, operation, turn);
      if (result.error != null) {
        warnings.add(result.error!);
        continue;
      }
      threads = result.threads;
      if (result.changed != null) {
        _recordThread(result.changed!, events, changes, playerChanges, turn);
      }
    }

    final conditionValues = Map<String, dynamic>.from(values);
    for (final rule in system.rules.take(20)) {
      if (!rule.isExecutable) continue;
      if (rule.conditions.length > 16 ||
          rule.costs.length > 16 ||
          rule.effects.length > 24 ||
          rule.threads.length > 8) {
        warnings.add('${rule.title}：规则超过执行数量限制，整条规则未执行');
        continue;
      }
      final lastTurn = fired[rule.id];
      if (lastTurn != null &&
          (rule.once || turn - lastTurn < rule.cooldownTurns)) {
        continue;
      }
      if (!matches(
          rule: rule, values: conditionValues, previousValues: initial)) {
        continue;
      }
      final candidate = Map<String, dynamic>.from(values);
      final candidateReceipts = <String, List<GameplayVariableChangeStep>>{};
      var candidateThreads = <GameplayStoryThread>[...threads];
      final threadChanges = <GameplayStoryThread>[];
      String? failure;
      for (final cost in rule.costs) {
        final variable = system.variableFor(cost.path);
        final available = _number(candidate[cost.path]);
        if (!_ruleWritable(variable) ||
            !_numeric(variable!) ||
            available == null ||
            !cost.amount.isFinite ||
            cost.amount < 0 ||
            available - cost.amount <
                (variable.min != null && variable.min! > 0
                    ? variable.min!
                    : 0)) {
          failure = '代价不足或费用定义无效（${cost.path}）';
          break;
        }
        final beforeValues = Map<String, dynamic>.from(candidate);
        candidate[cost.path] = variable.normalizeValue(available - cost.amount);
        _recordVariableStep(
          system: system,
          receipts: candidateReceipts,
          path: cost.path,
          beforeValues: beforeValues,
          afterValues: candidate,
          source: 'rule',
          reason: '${rule.title} · 消耗（${rule.effect}）',
          playerReason: rule.playerSummary.isEmpty
              ? '行动消耗'
              : '${rule.playerSummary}（行动消耗）',
          rule: rule,
        );
      }
      if (failure == null) {
        for (final effect in rule.effects) {
          final beforeValues = Map<String, dynamic>.from(candidate);
          failure = _applyEffect(system, candidate, effect);
          if (failure != null) break;
          _recordVariableStep(
            system: system,
            receipts: candidateReceipts,
            path: effect.path,
            beforeValues: beforeValues,
            afterValues: candidate,
            source: 'rule',
            reason: '${rule.title} · ${rule.effect}',
            playerReason:
                rule.playerSummary.isEmpty ? '行动结果' : rule.playerSummary,
            rule: rule,
          );
        }
      }
      if (failure == null) {
        for (final operation in rule.threads) {
          final safeOperation = GameplayThreadOperation(
            op: operation.op,
            id: operation.id,
            title: operation.title,
            description: operation.description,
            reason: operation.reason.isEmpty ? rule.effect : operation.reason,
            visibility: _public(rule.visibility)
                ? operation.visibility
                : rule.visibility,
          );
          final result = _applyThread(candidateThreads, safeOperation, turn,
              forcedVisibility:
                  _public(rule.visibility) ? null : rule.visibility,
              allowEngine: true);
          if (result.error != null) {
            failure = result.error;
            break;
          }
          candidateThreads = result.threads;
          if (result.changed != null) threadChanges.add(result.changed!);
        }
      }
      if (failure != null) {
        warnings.add('${rule.title}：$failure，整条规则未执行');
        continue;
      }
      for (final entry in candidateReceipts.entries) {
        receiptSteps.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
      for (final key in candidate.keys) {
        if (!_equal(values[key], candidate[key])) {
          reasons[key] = _public(rule.visibility) ? rule.playerSummary : '';
        }
      }
      values = candidate;
      threads = candidateThreads;
      fired[rule.id] = turn;
      final visible = _public(rule.visibility);
      final summary =
          rule.playerSummary.isNotEmpty ? rule.playerSummary : '局势发生了变化';
      changes.add('${rule.title}：${rule.effect}');
      if (visible) playerChanges.add('${rule.title}：$summary');
      events.add(GameplayRuntimeEvent(
        id: 'rule_${rule.id}_$turn',
        ruleId: rule.id,
        title: rule.title,
        description: visible ? summary : rule.effect,
        visibility:
            visible ? GameplayVariableVisibility.public : rule.visibility,
        turn: turn,
      ));
      for (final thread in threadChanges) {
        _recordThread(thread, events, changes, playerChanges, turn);
      }
    }

    final variableChanges = <String>[];
    final playerVariableChanges = <String>[];
    final variableRecords = <GameplayVariableChange>[];
    for (final variable in system.variables) {
      final before = initial[variable.key];
      final after = values[variable.key];
      final steps = receiptSteps[variable.key] ?? const [];
      if (steps.isNotEmpty) {
        final beforeVisible =
            _playerVariableVisible(variable, initial, initial);
        final afterVisible = _playerVariableVisible(variable, values, initial);
        variableRecords.add(GameplayVariableChange(
          turnId: identity,
          turn: turn,
          path: variable.key,
          type: variable.type,
          label: variable.label,
          visibility: variable.visibility,
          before: copyGameplayHistoryValue(before),
          after: copyGameplayHistoryValue(after),
          steps: List.unmodifiable(steps),
          playerVisible: beforeVisible || afterVisible,
          playerBefore: beforeVisible
              ? variable.displayValue(before, reveal: false)
              : '当时未公开',
          playerAfter: afterVisible
              ? variable.displayValue(after, reveal: false)
              : '当时未公开',
        ));
      }
      if (_equal(before, after)) continue;
      final reason = reasons[variable.key] ?? '';
      final suffix = reason.isEmpty ? '' : '（$reason）';
      variableChanges.add(
          '${variable.label}：${variable.displayValue(before, reveal: true)} → ${variable.displayValue(after, reveal: true)}$suffix');
      if (!variable.isPlayerFacing ||
          !matches(
              conditions: variable.revealWhen,
              values: values,
              previousValues: initial)) {
        continue;
      }
      final playerBefore = _playerVariableVisible(variable, initial, initial)
          ? variable.displayValue(before, reveal: false)
          : '当时未公开';
      final playerAfter = variable.displayValue(after, reveal: false);
      if (playerBefore == playerAfter) continue;
      final playerReasons = steps
          .where((step) => step.playerVisible && step.playerReason.isNotEmpty)
          .map((step) => step.playerReason)
          .toSet();
      final playerSuffix =
          playerReasons.isEmpty ? '' : '（${playerReasons.join('；')}）';
      playerVariableChanges
          .add('${variable.label}：$playerBefore → $playerAfter$playerSuffix');
    }
    final changed = variableChanges.isNotEmpty || changes.isNotEmpty;
    return narrativeState.copyWith(
      metrics: metrics,
      customVariables: values,
      customVariablesRevision:
          previousState.customVariablesRevision + (changed ? 1 : 0),
      gameplayVariableChanges: [...variableChanges, ...changes],
      gameplayPlayerVariableChanges: [
        ...playerVariableChanges,
        ...playerChanges
      ],
      gameplayVariableWarnings: warnings.take(48).toList(),
      gameplayVariableHistoryVersion: 1,
      gameplayVariableRecords: variableRecords,
      gameplayRuntime: GameplayRuntimeState(
        turn: turn,
        lastTurnId: identity,
        lastRuleTurns: fired,
        threads: threads,
        events:
            events.length > 80 ? events.sublist(events.length - 80) : events,
      ),
    );
  }

  static void _recordVariableStep({
    required GameplaySystem system,
    required Map<String, List<GameplayVariableChangeStep>> receipts,
    required String path,
    required Map<String, dynamic> beforeValues,
    required Map<String, dynamic> afterValues,
    required String source,
    required String reason,
    String? playerReason,
    GameplayRuleDefinition? rule,
  }) {
    final variable = system.variableFor(path);
    if (variable == null || _equal(beforeValues[path], afterValues[path])) {
      return;
    }
    final beforeVisible =
        _playerVariableVisible(variable, beforeValues, beforeValues);
    final afterVisible =
        _playerVariableVisible(variable, afterValues, beforeValues);
    final beforeText = beforeVisible
        ? variable.displayValue(beforeValues[path], reveal: false)
        : '当时未公开';
    final afterText = afterVisible
        ? variable.displayValue(afterValues[path], reveal: false)
        : '当时未公开';
    final playerVisible = (beforeVisible || afterVisible) &&
        (rule == null || _public(rule.visibility)) &&
        (variable.visibility != GameplayVariableVisibility.fuzzy ||
            beforeText != afterText);
    var safeReason = playerReason ?? reason;
    if (variable.visibility == GameplayVariableVisibility.fuzzy) {
      safeReason = source == 'time' ? '剧情时间推进，已知阶段变化' : '剧情推进，已知阶段变化';
    } else if (_mentionsPrivateDefinition(
        system, safeReason, beforeValues, afterValues)) {
      safeReason = source == 'time' ? '剧情时间推进' : '剧情中的行动与结果使状态变化';
    }
    receipts.putIfAbsent(path, () => []).add(GameplayVariableChangeStep(
          source: source,
          before: copyGameplayHistoryValue(beforeValues[path]),
          after: copyGameplayHistoryValue(afterValues[path]),
          reason: reason,
          ruleId: rule?.id ?? '',
          playerVisible: playerVisible,
          playerBefore: playerVisible ? beforeText : '',
          playerAfter: playerVisible ? afterText : '',
          playerReason: playerVisible ? safeReason : '',
        ));
  }

  static bool _playerVariableVisible(GameplayVariableDefinition variable,
          Map<String, dynamic> values, Map<String, dynamic> previousValues) =>
      variable.isPlayerFacing &&
      matches(
          conditions: variable.revealWhen,
          values: values,
          previousValues: previousValues);

  static bool _mentionsPrivateDefinition(GameplaySystem system, String reason,
      Map<String, dynamic> beforeValues, Map<String, dynamic> afterValues) {
    for (final variable in system.variables) {
      if (variable.visibility == GameplayVariableVisibility.public &&
          _playerVariableVisible(variable, beforeValues, beforeValues) &&
          _playerVariableVisible(variable, afterValues, beforeValues)) {
        continue;
      }
      if ((variable.key.isNotEmpty && reason.contains(variable.key)) ||
          (variable.label.isNotEmpty && reason.contains(variable.label))) {
        return true;
      }
    }
    return system.rules.any((rule) =>
        !_public(rule.visibility) &&
        ((rule.title.isNotEmpty && reason.contains(rule.title)) ||
            (rule.id.isNotEmpty && reason.contains(rule.id))));
  }

  /// Used by both runtime settlement and local author previews. No expression
  /// evaluation is performed; unsupported comparisons fail closed.
  static bool matches({
    GameplayRuleDefinition? rule,
    List<GameplayCondition>? conditions,
    required Map<String, dynamic> values,
    Map<String, dynamic>? previousValues,
  }) {
    final checks =
        conditions ?? rule?.conditions ?? const <GameplayCondition>[];
    if (checks.length > 16) return false;
    for (final condition in checks) {
      if (!values.containsKey(condition.path)) return false;
      final current = values[condition.path];
      final expected = condition.value;
      final left = _number(current);
      final right = _number(expected);
      final accepted = switch (condition.op) {
        'eq' => _equal(current, expected),
        'neq' => !_equal(current, expected),
        'gt' => left != null && right != null && left > right,
        'gte' => left != null && right != null && left >= right,
        'lt' => left != null && right != null && left < right,
        'lte' => left != null && right != null && left <= right,
        'contains' => current is List
            ? current.any((item) => _equal(item, expected))
            : current is String &&
                expected is String &&
                current.contains(expected),
        'changed' => previousValues?.containsKey(condition.path) == true &&
            !_equal(previousValues![condition.path], current),
        _ => false,
      };
      if (!accepted) return false;
    }
    return true;
  }

  static String? _applyEffect(GameplaySystem system,
      Map<String, dynamic> values, GameplayRuleEffect effect) {
    final variable = system.variableFor(effect.path);
    if (!_ruleWritable(variable)) return '${effect.path} 不允许规则修改';
    final definition = variable!;
    final before = values[effect.path];
    dynamic candidate;
    switch (effect.op) {
      case 'inc':
        final increment = _number(effect.value);
        final current = _number(before);
        if (!_numeric(definition) || increment == null || current == null) {
          return '${effect.path} 增量无效';
        }
        candidate = current + increment;
      case 'set':
        candidate = effect.value;
      case 'append':
      case 'remove':
        if (definition.type != GameplayVariableType.list ||
            before is! List ||
            effect.value is! String) {
          return '${effect.path} 列表操作无效';
        }
        final item = (effect.value as String).trim();
        candidate = effect.op == 'append'
            ? [...before, if (item.isNotEmpty && !before.contains(item)) item]
            : before.where((existing) => existing != item).toList();
        if ((candidate as List).length > 40) return '${effect.path} 列表已满';
      default:
        return '${effect.path} 操作不受支持';
    }
    if (_numeric(definition)) {
      final number = _number(candidate);
      if (number == null ||
          (definition.min != null && number < definition.min!) ||
          (definition.max != null && number > definition.max!)) {
        return '${effect.path} 结果超出边界';
      }
    } else if (definition.type == GameplayVariableType.boolean &&
        candidate is! bool) {
      return '${effect.path} 需要布尔值';
    } else if ((definition.type == GameplayVariableType.text ||
            definition.type == GameplayVariableType.choice) &&
        candidate is! String) {
      return '${effect.path} 需要文本';
    } else if (definition.type == GameplayVariableType.choice &&
        definition.options.isNotEmpty &&
        !definition.options.contains(candidate)) {
      return '${effect.path} 选项无效';
    } else if (definition.type == GameplayVariableType.list &&
        (candidate is! List ||
            candidate.length > 40 ||
            candidate.any((item) => item is! String))) {
      return '${effect.path} 列表值无效';
    }
    values[effect.path] = definition.normalizeValue(candidate);
    return null;
  }

  static ({
    List<GameplayStoryThread> threads,
    GameplayStoryThread? changed,
    String? error
  }) _applyThread(
    List<GameplayStoryThread> current,
    GameplayThreadOperation operation,
    int turn, {
    GameplayVariableVisibility? forcedVisibility,
    bool allowEngine = false,
  }) {
    final id = operation.id.trim();
    final reason = operation.reason.trim();
    String? failure;
    GameplayStoryThread? changed;
    final index = current.indexWhere((item) => item.id == id);
    if (index >= 0 &&
        current[index].visibility == GameplayVariableVisibility.engine &&
        !allowEngine) {
      failure = '该事项由引擎托管，AI 无权修改';
    } else if (id.isEmpty ||
        id.length > 80 ||
        reason.isEmpty ||
        reason.length > 300 ||
        operation.title.length > 80 ||
        operation.description.length > 600) {
      failure = '承诺与余波需要有效标识和本轮事实依据，且文字不能超过长度限制';
    } else if (operation.op == 'open') {
      if (index >= 0) {
        failure = '事项 $id 已存在，不能重复创建或重开';
      } else if (current.length >= 100) {
        failure = '承诺与余波台账已达 100 项，现有记录已保留';
      } else if (operation.title.trim().isEmpty) {
        failure = '新事项 $id 缺少标题';
      } else {
        changed = GameplayStoryThread(
          id: id,
          title: operation.title.trim(),
          description: operation.description.trim(),
          reason: reason,
          visibility: operation.visibility,
          openedTurn: turn,
          updatedTurn: turn,
        );
      }
    } else if (operation.op == 'resolve' || operation.op == 'break') {
      if (index < 0) {
        failure = '事项 $id 尚未建立，不能结算';
      } else if (current[index].status != GameplayThreadStatus.open) {
        failure = '事项 $id 已经结束，原记录已保留';
      } else {
        changed = current[index].finish(
            operation.op == 'resolve'
                ? GameplayThreadStatus.resolved
                : GameplayThreadStatus.broken,
            current[index].isPlayerFacing &&
                    forcedVisibility == GameplayVariableVisibility.director
                ? '相关后续已经发生'
                : reason,
            turn,
            visibility:
                current[index].visibility == GameplayVariableVisibility.engine
                    ? GameplayVariableVisibility.engine
                    : forcedVisibility == GameplayVariableVisibility.engine
                        ? GameplayVariableVisibility.engine
                        : current[index].visibility);
      }
    } else {
      failure = '事项 $id 的操作不受支持';
    }
    if (failure != null || changed == null) {
      return (threads: current, changed: null, error: failure);
    }
    final next = [...current];
    if (index < 0) {
      next.add(changed);
    } else {
      next[index] = changed;
    }
    return (threads: next, changed: changed, error: null);
  }

  static void _recordThread(
      GameplayStoryThread thread,
      List<GameplayRuntimeEvent> events,
      List<String> changes,
      List<String> playerChanges,
      int turn) {
    final action = switch (thread.status) {
      GameplayThreadStatus.open => '留下后续',
      GameplayThreadStatus.resolved => '已兑现',
      GameplayThreadStatus.broken => '已违背',
    };
    final line = '$action · ${thread.title}（${thread.reason}）';
    changes.add(line);
    if (thread.isPlayerFacing) playerChanges.add(line);
    events.add(GameplayRuntimeEvent(
      id: 'thread_${thread.id}_${thread.status.name}_$turn',
      title: '$action · ${thread.title}',
      description: thread.reason,
      visibility: thread.visibility,
      turn: turn,
    ));
  }

  static bool _public(GameplayVariableVisibility visibility) =>
      visibility == GameplayVariableVisibility.public ||
      visibility == GameplayVariableVisibility.fuzzy;
  static bool _ruleWritable(GameplayVariableDefinition? variable) =>
      variable != null &&
      (variable.authority == GameplayVariableAuthority.ai ||
          variable.authority == GameplayVariableAuthority.rule);
  static bool _numeric(GameplayVariableDefinition variable) =>
      variable.type == GameplayVariableType.number ||
      variable.type == GameplayVariableType.clock;
  static double? _number(dynamic value) {
    final result = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return result != null && result.isFinite ? result : null;
  }

  static bool _equal(dynamic left, dynamic right) => left is num && right is num
      ? left == right
      : jsonEncode(left) == jsonEncode(right);
  static String _fallbackTurnId(GameStateSnapshot state, String content) {
    var hash = 0x811c9dc5;
    for (final code
        in '${state.updatedAt.toIso8601String()}|$content'.codeUnits) {
      hash = ((hash ^ code) * 0x01000193) & 0xffffffff;
    }
    return 'turn_${hash.toRadixString(16)}';
  }
}
