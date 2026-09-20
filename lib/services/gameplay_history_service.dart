import 'dart:convert';

import '../models/chat_message.dart';
import '../models/game_state.dart';
import '../models/gameplay_system.dart';
import '../models/gameplay_variable_change.dart';
import 'gameplay_turn_engine.dart';

/// Safe display data. No raw values or hidden rule identifiers escape this view.
class GameplayVariableHistoryStep {
  const GameplayVariableHistoryStep({
    required this.beforeText,
    required this.afterText,
    required this.reason,
    required this.source,
  });

  final String beforeText;
  final String afterText;
  final String reason;
  final String source;

  String get sourceLabel => switch (source) {
        'ai' => '剧情变化',
        'time' => '时间推进',
        'rule' => '规则结算',
        _ => '旧快照',
      };
}

class GameplayVariableHistoryEntry {
  const GameplayVariableHistoryEntry({
    required this.messageId,
    required this.timestamp,
    required this.turn,
    required this.path,
    required this.type,
    required this.label,
    required this.beforeText,
    required this.afterText,
    required this.steps,
    required this.reason,
    required this.legacy,
    required this.segmentId,
    required this.definitionChanged,
  });

  final String messageId;
  final DateTime timestamp;
  final int turn;
  final String path;
  final GameplayVariableType type;
  final String label;
  final String beforeText;
  final String afterText;
  final List<GameplayVariableHistoryStep> steps;
  final String reason;
  final bool legacy;
  final String segmentId;
  final bool definitionChanged;
}

/// Reads only the supplied branch's saved receipts. It never replays a patch,
/// interprets old display strings, or uses today's definition to reveal the past.
class GameplayHistoryService {
  const GameplayHistoryService._();

  static List<GameplayVariableHistoryEntry> forVariable({
    required List<ChatMessage> messages,
    required GameplaySystem currentSystem,
    required GameStateSnapshot currentState,
    required String path,
    int limit = 10,
    bool reveal = false,
  }) {
    if (limit <= 0) return const [];
    final current = currentSystem.variableFor(path);
    if (current == null ||
        current.visibility == GameplayVariableVisibility.engine ||
        (!reveal && !_visible(current, currentState.customVariables))) {
      return const [];
    }

    final entries = <GameplayVariableHistoryEntry>[];
    final seenReceipts = <String>{};
    Map<String, dynamic>? previousRaw;
    GameplayVariableDefinition? previousDefinition;
    GameplayVariableType? lastType;
    var segment = 0;
    var inspectedSnapshot = false;

    for (final message in messages) {
      if (message.role != ChatRole.assistant) continue;
      final raw = message.gameStateSnapshot;
      if (raw == null) continue;
      if (!inspectedSnapshot) {
        final baseline = raw['gameplayBaseline'];
        if (baseline is Map) {
          final baselineState = baseline['state'];
          if (baselineState is Map) {
            previousRaw = Map<String, dynamic>.from(baselineState);
            previousDefinition = _readVariable(baseline['system'], path);
          }
        }
      }
      inspectedSnapshot = true;
      final definitionKnown = raw['gameplayHistoryDefinitionKnown'] != false;
      final definition =
          definitionKnown ? _readVariable(raw['gameplaySystem'], path) : null;
      final records = (raw['gameplayVariableRecords'] is List
              ? raw['gameplayVariableRecords'] as List
              : const [])
          .whereType<Map>()
          .where((record) => record['path'] == path)
          .map((record) => GameplayVariableChange.fromJson(
              Map<String, dynamic>.from(record)))
          .toList(growable: false);
      final type =
          definition?.type ?? (records.isEmpty ? null : records.first.type);
      final definitionChanged = lastType != null && type != lastType;
      if (type != lastType) segment++;
      lastType = type;
      final segmentId = '$path:${type?.name ?? 'absent'}:$segment';

      final version = int.tryParse(
              raw['gameplayVariableHistoryVersion']?.toString() ?? '') ??
          0;
      if (!definitionKnown) {
        // A replay fallback definition has no historical disclosure authority.
      } else if (version > 0 || records.isNotEmpty) {
        for (final record in records) {
          final receiptId =
              '${record.turnId.isEmpty ? message.id : record.turnId}|$path';
          if (!seenReceipts.add(receiptId)) continue;
          final entry = _project(
            message: message,
            record: record,
            current: current,
            reveal: reveal,
            segmentId: segmentId,
            definitionChanged: definitionChanged,
          );
          if (entry != null) entries.add(entry);
        }
      } else if (definition != null && previousRaw != null) {
        final previous = _readState(previousRaw);
        final state = _readState(raw);
        final oldDefinition = previousDefinition;
        if (state != null &&
            previous != null &&
            oldDefinition != null &&
            oldDefinition.type == definition.type &&
            previous.customVariables.containsKey(path) &&
            state.customVariables.containsKey(path)) {
          final entry = _legacy(
            message: message,
            beforeState: previous,
            afterState: state,
            beforeDefinition: oldDefinition,
            afterDefinition: definition,
            current: current,
            reveal: reveal,
            segmentId: segmentId,
            definitionChanged: definitionChanged,
          );
          if (entry != null) entries.add(entry);
        }
      }
      // Keep output memory bounded for long branches. The forward scan only
      // reads this variable so type segments and old snapshot baselines stay
      // correct; it does not deserialize every other variable's receipts.
      if (entries.length > limit) {
        entries.removeRange(0, entries.length - limit);
      }
      previousRaw = raw;
      previousDefinition = definition;
    }
    return entries.reversed.take(limit).toList(growable: false);
  }

  static GameplayVariableHistoryEntry? _project({
    required ChatMessage message,
    required GameplayVariableChange record,
    required GameplayVariableDefinition current,
    required bool reveal,
    required String segmentId,
    required bool definitionChanged,
  }) {
    if (record.visibility == GameplayVariableVisibility.engine ||
        (!reveal &&
            (!record.playerVisible ||
                record.visibility == GameplayVariableVisibility.director))) {
      return null;
    }
    final maskOldNumbers = !reveal &&
        current.visibility == GameplayVariableVisibility.fuzzy &&
        record.visibility != GameplayVariableVisibility.fuzzy;
    final before = reveal
        ? _display(record.before)
        : maskOldNumbers
            ? '数值已隐藏'
            : record.playerBefore;
    final after = reveal
        ? _display(record.after)
        : maskOldNumbers
            ? '数值已隐藏'
            : record.playerAfter;
    final steps = <GameplayVariableHistoryStep>[
      if (!maskOldNumbers)
        for (final step in record.steps)
          if (reveal || step.playerVisible)
            GameplayVariableHistoryStep(
              beforeText: reveal ? _display(step.before) : step.playerBefore,
              afterText: reveal ? _display(step.after) : step.playerAfter,
              reason: reveal ? step.reason : step.playerReason,
              source: step.source,
            ),
    ];
    // A fuzzy change inside one stage, or a hidden rule with no visible net
    // effect, must not reveal that an otherwise private operation occurred.
    if (!reveal && before == after && steps.isEmpty && !maskOldNumbers) {
      return null;
    }
    final reasons = steps
        .map((step) => step.reason.trim())
        .where((reason) => reason.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return GameplayVariableHistoryEntry(
      messageId: message.id,
      timestamp: message.timestamp,
      turn: record.turn,
      path: record.path,
      type: record.type,
      label: record.label,
      beforeText: before,
      afterText: after,
      steps: steps,
      reason: reasons.isEmpty ? '未记录可公开的原因' : reasons.join('；'),
      legacy: false,
      segmentId: segmentId,
      definitionChanged: definitionChanged,
    );
  }

  static GameplayVariableHistoryEntry? _legacy({
    required ChatMessage message,
    required GameStateSnapshot beforeState,
    required GameStateSnapshot afterState,
    required GameplayVariableDefinition beforeDefinition,
    required GameplayVariableDefinition afterDefinition,
    required GameplayVariableDefinition current,
    required bool reveal,
    required String segmentId,
    required bool definitionChanged,
  }) {
    if (beforeDefinition.visibility == GameplayVariableVisibility.engine ||
        afterDefinition.visibility == GameplayVariableVisibility.engine) {
      return null;
    }
    final path = afterDefinition.key;
    final beforeValue = beforeState.customVariables[path];
    final afterValue = afterState.customVariables[path];
    if (jsonEncode(beforeValue) == jsonEncode(afterValue)) return null;
    final beforeVisible =
        _visible(beforeDefinition, beforeState.customVariables);
    final afterVisible = _visible(afterDefinition, afterState.customVariables);
    if (!reveal && !beforeVisible && !afterVisible) return null;
    // A changed definition is never an authorization to disclose older values.
    String display(
        GameplayVariableDefinition definition, dynamic value, bool visible) {
      if (reveal) return _display(value);
      if (!visible) return '当时未公开';
      if (current.visibility == GameplayVariableVisibility.fuzzy &&
          definition.visibility != GameplayVariableVisibility.fuzzy) {
        return '数值已隐藏';
      }
      return definition.displayValue(value, reveal: false);
    }

    final before = display(beforeDefinition, beforeValue, beforeVisible);
    final after = display(afterDefinition, afterValue, afterVisible);
    if (before == after) return null;
    return GameplayVariableHistoryEntry(
      messageId: message.id,
      timestamp: message.timestamp,
      turn: afterState.gameplayRuntime.turn,
      path: path,
      type: afterDefinition.type,
      label: afterDefinition.label,
      beforeText: before,
      afterText: after,
      steps: const [],
      reason: '旧存档仅能确认前后状态，未记录变化原因',
      legacy: true,
      segmentId: segmentId,
      definitionChanged: definitionChanged,
    );
  }

  static bool _visible(
          GameplayVariableDefinition definition, Map<String, dynamic> values) =>
      definition.isPlayerFacing &&
      GameplayTurnEngine.matches(
        conditions: definition.revealWhen,
        values: values,
        previousValues: values,
      );

  static GameStateSnapshot? _readState(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return GameStateSnapshot.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static GameplayVariableDefinition? _readVariable(dynamic raw, String path) {
    if (raw is! Map || raw['variables'] is! List) return null;
    try {
      for (final variable in (raw['variables'] as List).whereType<Map>()) {
        if ((variable['key'] ?? variable['path']) == path) {
          return GameplayVariableDefinition.fromJson(
              Map<String, dynamic>.from(variable));
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _display(dynamic value) {
    if (value is List) return value.isEmpty ? '暂无' : value.join('、');
    if (value is bool) return value ? '是' : '否';
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.round().toString();
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '暂无' : text;
  }
}
