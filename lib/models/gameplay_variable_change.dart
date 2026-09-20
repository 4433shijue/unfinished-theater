import 'dart:convert';

import 'gameplay_system.dart';

/// An immutable receipt of an accepted operation, including its player-safe
/// presentation at the moment it happened. Raw values are for author inspection.
class GameplayVariableChangeStep {
  const GameplayVariableChangeStep({
    required this.source,
    required this.before,
    required this.after,
    required this.reason,
    this.ruleId = '',
    this.playerVisible = false,
    this.playerBefore = '',
    this.playerAfter = '',
    this.playerReason = '',
  });

  factory GameplayVariableChangeStep.fromJson(Map<String, dynamic> json) =>
      GameplayVariableChangeStep(
        source: json['source']?.toString() ?? '',
        before: copyGameplayHistoryValue(json['before']),
        after: copyGameplayHistoryValue(json['after']),
        reason: json['reason']?.toString() ?? '',
        ruleId: json['ruleId']?.toString() ?? '',
        playerVisible: json['playerVisible'] == true,
        playerBefore: json['playerBefore']?.toString() ?? '',
        playerAfter: json['playerAfter']?.toString() ?? '',
        playerReason: json['playerReason']?.toString() ?? '',
      );

  final String source;
  final dynamic before;
  final dynamic after;
  final String reason;
  final String ruleId;
  final bool playerVisible;
  final String playerBefore;
  final String playerAfter;
  final String playerReason;

  Map<String, dynamic> toJson() => {
        'source': source,
        'before': copyGameplayHistoryValue(before),
        'after': copyGameplayHistoryValue(after),
        'reason': reason,
        if (ruleId.isNotEmpty) 'ruleId': ruleId,
        'playerVisible': playerVisible,
        if (playerVisible) ...{
          'playerBefore': playerBefore,
          'playerAfter': playerAfter,
          'playerReason': playerReason,
        },
      };
}

/// One variable's settlement in one turn, including net-zero transactions.
class GameplayVariableChange {
  const GameplayVariableChange({
    required this.turnId,
    required this.turn,
    required this.path,
    required this.type,
    required this.label,
    required this.visibility,
    required this.before,
    required this.after,
    this.steps = const [],
    this.playerVisible = false,
    this.playerBefore = '',
    this.playerAfter = '',
  });

  factory GameplayVariableChange.fromJson(Map<String, dynamic> json) =>
      GameplayVariableChange(
        turnId: json['turnId']?.toString() ?? '',
        turn: int.tryParse(json['turn']?.toString() ?? '') ?? 0,
        path: json['path']?.toString() ?? '',
        type: GameplayVariableType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => GameplayVariableType.text,
        ),
        label: json['label']?.toString() ?? '',
        visibility: GameplayVariableVisibility.values.firstWhere(
          (value) => value.name == json['visibility'],
          orElse: () => GameplayVariableVisibility.engine,
        ),
        before: copyGameplayHistoryValue(json['before']),
        after: copyGameplayHistoryValue(json['after']),
        steps: (json['steps'] is List ? json['steps'] as List : const [])
            .whereType<Map>()
            .map((value) => GameplayVariableChangeStep.fromJson(
                Map<String, dynamic>.from(value)))
            .toList(growable: false),
        playerVisible: json['playerVisible'] == true,
        playerBefore: json['playerBefore']?.toString() ?? '',
        playerAfter: json['playerAfter']?.toString() ?? '',
      );

  final String turnId;
  final int turn;
  final String path;
  final GameplayVariableType type;
  final String label;
  final GameplayVariableVisibility visibility;
  final dynamic before;
  final dynamic after;
  final List<GameplayVariableChangeStep> steps;
  final bool playerVisible;
  final String playerBefore;
  final String playerAfter;

  Map<String, dynamic> toJson() => {
        'turnId': turnId,
        'turn': turn,
        'path': path,
        'type': type.name,
        'label': label,
        'visibility': visibility.name,
        'before': copyGameplayHistoryValue(before),
        'after': copyGameplayHistoryValue(after),
        'steps': steps.map((step) => step.toJson()).toList(),
        'playerVisible': playerVisible,
        if (playerVisible) ...{
          'playerBefore': playerBefore,
          'playerAfter': playerAfter,
        },
      };
}

dynamic copyGameplayHistoryValue(dynamic value) =>
    value is Map || value is List ? jsonDecode(jsonEncode(value)) : value;
