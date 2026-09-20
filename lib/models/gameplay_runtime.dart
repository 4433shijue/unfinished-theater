import 'gameplay_system.dart';

enum GameplayThreadStatus { open, resolved, broken }

class GameplayThreadOperation {
  const GameplayThreadOperation({
    required this.op,
    required this.id,
    this.title = '',
    this.description = '',
    this.reason = '',
    this.visibility = GameplayVariableVisibility.public,
  });

  factory GameplayThreadOperation.fromJson(Map<String, dynamic> json) =>
      GameplayThreadOperation(
        op: _text(json['op'], 16),
        id: _text(json['id'], 81),
        title: _text(json['title'], 80),
        description: _text(json['description'], 600),
        reason: _text(json['reason'], 300),
        visibility: _visibility(json['visibility']),
      );

  final String op;
  final String id;
  final String title;
  final String description;
  final String reason;
  final GameplayVariableVisibility visibility;

  Map<String, dynamic> toJson() => {
        'op': op,
        'id': id,
        if (title.isNotEmpty) 'title': title,
        if (description.isNotEmpty) 'description': description,
        'reason': reason,
        'visibility': visibility.name,
      };
}

class GameplayStoryThread {
  const GameplayStoryThread({
    required this.id,
    required this.title,
    this.description = '',
    this.reason = '',
    this.visibility = GameplayVariableVisibility.public,
    this.status = GameplayThreadStatus.open,
    this.openedTurn = 0,
    this.updatedTurn = 0,
  });

  factory GameplayStoryThread.fromJson(Map<String, dynamic> json) =>
      GameplayStoryThread(
        id: _text(json['id'], 80),
        title: _text(json['title'], 80),
        description: _text(json['description'], 600),
        reason: _text(json['reason'], 300),
        visibility: _runtimeVisibility(json['visibility']),
        status: switch (json['status']) {
          'resolved' => GameplayThreadStatus.resolved,
          'broken' => GameplayThreadStatus.broken,
          _ => GameplayThreadStatus.open,
        },
        openedTurn: _integer(json['openedTurn']),
        updatedTurn: _integer(json['updatedTurn']),
      );

  final String id;
  final String title;
  final String description;
  final String reason;
  final GameplayVariableVisibility visibility;
  final GameplayThreadStatus status;
  final int openedTurn;
  final int updatedTurn;

  bool get isPlayerFacing => visibility == GameplayVariableVisibility.public;

  GameplayStoryThread finish(
          GameplayThreadStatus nextStatus, String nextReason, int turn,
          {GameplayVariableVisibility? visibility}) =>
      GameplayStoryThread(
        id: id,
        title: title,
        description: description,
        reason: nextReason,
        visibility: visibility ?? this.visibility,
        status: nextStatus,
        openedTurn: openedTurn,
        updatedTurn: turn,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'reason': reason,
        'visibility': visibility.name,
        'status': status.name,
        'openedTurn': openedTurn,
        'updatedTurn': updatedTurn,
      };
}

class GameplayRuntimeEvent {
  const GameplayRuntimeEvent({
    required this.id,
    required this.title,
    this.ruleId = '',
    this.description = '',
    this.visibility = GameplayVariableVisibility.director,
    this.turn = 0,
  });

  factory GameplayRuntimeEvent.fromJson(Map<String, dynamic> json) =>
      GameplayRuntimeEvent(
        id: _text(json['id'], 120),
        ruleId: _text(json['ruleId'], 80),
        title: _text(json['title'], 80),
        description: _text(json['description'], 600),
        visibility: _runtimeVisibility(json['visibility']),
        turn: _integer(json['turn']),
      );

  final String id;
  final String ruleId;
  final String title;
  final String description;
  final GameplayVariableVisibility visibility;
  final int turn;

  bool get isPlayerFacing => visibility == GameplayVariableVisibility.public;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleId': ruleId,
        'title': title,
        'description': description,
        'visibility': visibility.name,
        'turn': turn,
      };
}

class GameplayRuntimeState {
  const GameplayRuntimeState({
    this.turn = 0,
    this.lastTurnId = '',
    this.lastRuleTurns = const <String, int>{},
    this.threads = const <GameplayStoryThread>[],
    this.events = const <GameplayRuntimeEvent>[],
  });

  factory GameplayRuntimeState.fromJson(Map<String, dynamic> json) {
    final seenThreads = <String>{};
    return GameplayRuntimeState(
      turn: _integer(json['turn']),
      lastTurnId: _text(json['lastTurnId'], 160),
      lastRuleTurns: json['lastRuleTurns'] is Map
          ? {
              for (final entry
                  in (json['lastRuleTurns'] as Map).entries.take(200))
                _text(entry.key, 80): _integer(entry.value),
            }
          : const {},
      threads: (json['threads'] is List ? json['threads'] as List : const [])
          .whereType<Map>()
          .map((raw) =>
              GameplayStoryThread.fromJson(Map<String, dynamic>.from(raw)))
          .where((thread) =>
              thread.id.isNotEmpty &&
              thread.title.isNotEmpty &&
              seenThreads.add(thread.id))
          .take(100)
          .toList(),
      events: (json['events'] is List ? json['events'] as List : const [])
          .whereType<Map>()
          .map((raw) =>
              GameplayRuntimeEvent.fromJson(Map<String, dynamic>.from(raw)))
          .where((event) => event.id.isNotEmpty)
          .take(80)
          .toList(),
    );
  }

  final int turn;
  final String lastTurnId;
  final Map<String, int> lastRuleTurns;
  final List<GameplayStoryThread> threads;
  final List<GameplayRuntimeEvent> events;

  bool get isEmpty =>
      turn == 0 && threads.isEmpty && events.isEmpty && lastRuleTurns.isEmpty;

  Map<String, dynamic> toJson() => {
        'turn': turn,
        'lastTurnId': lastTurnId,
        'lastRuleTurns': lastRuleTurns,
        'threads': threads.map((item) => item.toJson()).toList(),
        'events': events.map((item) => item.toJson()).toList(),
      };
}

String _text(dynamic value, int limit) {
  final text = value?.toString().trim() ?? '';
  return text.length <= limit ? text : text.substring(0, limit);
}

int _integer(dynamic value) =>
    (int.tryParse(value?.toString() ?? '') ?? 0).clamp(0, 1000000000);

GameplayVariableVisibility _visibility(dynamic value) => value == 'public'
    ? GameplayVariableVisibility.public
    : GameplayVariableVisibility.director;

GameplayVariableVisibility _runtimeVisibility(dynamic value) =>
    value == 'engine' ? GameplayVariableVisibility.engine : _visibility(value);
