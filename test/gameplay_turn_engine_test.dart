import 'dart:convert';

import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_runtime.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/services/gameplay_patch_engine.dart';
import 'package:ai_roleplay_chat/services/gameplay_turn_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI set and accumulated increments share one turn budget', () {
    final system = _system();
    final result = GameplayPatchEngine.applyAiPatch(
      system: system,
      currentValues: {'risk': 20},
      operations: [
        _op('inc', 'risk', 6),
        _op('inc', 'risk', 6),
        _op('set', 'risk', 99),
      ],
    );
    expect(result.values['risk'], 28);
    final reversed = GameplayPatchEngine.applyAiPatch(
      system: system,
      currentValues: {'risk': 20},
      operations: [_op('inc', 'risk', 8), _op('set', 'risk', 0)],
    );
    expect(reversed.values['risk'], 12);
    final next = GameplayPatchEngine.applyAiPatch(
      system: system,
      currentValues: result.values,
      operations: [_op('inc', 'risk', 8)],
    );
    expect(next.values['risk'], 36);
  });

  test('nonfinite numeric set, increment, and unknown operations fail closed',
      () {
    final result = GameplayPatchEngine.applyAiPatch(
      system: _system(),
      currentValues: {'risk': 20},
      operations: [
        _op('set', 'risk', double.nan),
        _op('inc', 'risk', double.infinity),
        _op('set', 'risk', 'Infinity'),
        _op('execute', 'risk', 10),
      ],
    );
    expect(result.values['risk'], 20);
    expect(result.rejections, hasLength(4));
    expect(() => jsonEncode(result.values), returnsNormally);
  });

  test('time clocks ignore chat, location changes, and initial time setup', () {
    final system = _system();
    var state = GameStateSnapshot.empty('story');
    state = _turn(system, state, id: 'initial', time: '清晨');
    expect(state.customVariables['clock'], 0);
    state = _turn(system, state, id: 'talk', location: '港口');
    expect(state.customVariables['clock'], 0);
    state = _turn(system, state, id: 'action', time: '午后', location: '仓库');
    expect(state.customVariables['clock'], 1);
    state = _turn(system, state, id: 'talk-again');
    expect(state.customVariables['clock'], 1);
  });

  test(
      'threshold fires once, consumes exact cost, and survives snapshot restore',
      () {
    final system = _system(rules: [
      _rule(
        costs: [const GameplayRuleCost(path: 'money', amount: 6)],
        effects: [
          const GameplayRuleEffect(op: 'set', path: 'sealed', value: true)
        ],
        threads: [
          const GameplayThreadOperation(
              op: 'open', id: 'promise', title: '照顾证人', reason: '证人交出了账本')
        ],
      )
    ]);
    var state = _turn(system, _state(), id: 'one', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 8}
    ]);
    expect(state.customVariables['money'], 14);
    expect(state.customVariables['sealed'], isTrue);
    expect(state.gameplayRuntime.lastRuleTurns['lockdown'], 1);
    expect(
        state.gameplayRuntime.threads.single.status, GameplayThreadStatus.open);
    state = GameStateSnapshot.fromJson(state.toJson());
    state = _turn(system, state, id: 'two');
    expect(state.customVariables['money'], 14);
    expect(state.gameplayRuntime.threads, hasLength(1));
    expect(state.gameplayRuntime.lastRuleTurns['lockdown'], 1);
  });

  test('costs, effects and thread creation are one atomic rule transaction',
      () {
    final system = _system(rules: [
      _rule(
        costs: [
          const GameplayRuleCost(path: 'money', amount: 12),
          const GameplayRuleCost(path: 'money', amount: 12)
        ],
        effects: [
          const GameplayRuleEffect(op: 'set', path: 'sealed', value: true)
        ],
      )
    ]);
    final state = _turn(system, _state(), id: 'no-funds', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 8}
    ]);
    expect(state.customVariables['money'], 20);
    expect(state.customVariables['sealed'], isFalse);
    expect(state.gameplayRuntime.lastRuleTurns, isEmpty);
    expect(state.gameplayVariableWarnings.single, contains('整条规则未执行'));
    final badEffect = _system(rules: [
      _rule(
        costs: [const GameplayRuleCost(path: 'money', amount: 2)],
        effects: [
          const GameplayRuleEffect(op: 'set', path: 'sealed', value: true)
        ],
        threads: [
          const GameplayThreadOperation(
              op: 'resolve', id: 'unknown', reason: '无效结算')
        ],
      )
    ]);
    final rolledBack = _turn(badEffect, _state(), id: 'rollback', ops: [
      {'op': 'set', 'path': 'risk', 'value': 28}
    ]);
    expect(rolledBack.customVariables['money'], 20);
    expect(rolledBack.customVariables['sealed'], isFalse);
  });

  test('rules cannot mutate player or computed values', () {
    for (final key in ['player', 'computed']) {
      final system = _system(rules: [
        _rule(effects: [GameplayRuleEffect(op: 'set', path: key, value: 50)])
      ]);
      final state = _turn(system, _state(), id: key, ops: [
        {'op': 'set', 'path': 'risk', 'value': 28}
      ]);
      expect(state.customVariables[key], 0);
      expect(state.gameplayRuntime.lastRuleTurns, isEmpty);
    }
  });

  test('rules use a frozen snapshot, so effects cannot chain in one turn', () {
    final system = _system(rules: [
      _rule(effects: [
        const GameplayRuleEffect(op: 'set', path: 'sealed', value: true)
      ]),
      const GameplayRuleDefinition(
          id: 'second',
          title: '地下入口',
          when: '封港后',
          effect: '获得入口',
          visibility: GameplayVariableVisibility.public,
          conditions: [
            GameplayCondition(path: 'sealed', op: 'eq', value: true)
          ],
          effects: [
            GameplayRuleEffect(op: 'inc', path: 'money', value: 1)
          ]),
    ]);
    final first = _turn(system, _state(), id: 'first', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 8}
    ]);
    expect(first.gameplayRuntime.lastRuleTurns.keys, ['lockdown']);
    final second = _turn(system, first, id: 'second');
    expect(second.gameplayRuntime.lastRuleTurns.keys, ['lockdown', 'second']);
  });

  test('repeatable rules honor persisted cooldown', () {
    final system = _system(rules: [
      _rule(once: false, cooldown: 2, effects: [
        const GameplayRuleEffect(op: 'inc', path: 'money', value: 1)
      ])
    ]);
    var state = _turn(system, _state(), id: 'one', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 8}
    ]);
    expect(state.customVariables['money'], 21);
    state =
        _turn(system, GameStateSnapshot.fromJson(state.toJson()), id: 'two');
    expect(state.customVariables['money'], 21);
    state = _turn(system, state, id: 'three');
    expect(state.customVariables['money'], 22);
  });

  test('hidden rules and threads never enter player settlement', () {
    final system = _system(rules: [
      _rule(
        visibility: GameplayVariableVisibility.engine,
        effects: [const GameplayRuleEffect(op: 'inc', path: 'money', value: 1)],
      )
    ]);
    var state = _turn(system, _state(), id: 'secret', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 8}
    ], threads: [
      {
        'op': 'open',
        'id': 'secret',
        'title': '真正的凶手',
        'description': '绝密信息',
        'reason': '凶手销毁了证物',
        'visibility': 'director'
      }
    ]);
    expect(state.gameplayVariableChanges.join(), contains('真正的凶手'));
    expect(state.gameplayPlayerVariableChanges.join(), isNot(contains('凶手')));
    expect(state.gameplayPlayerVariableChanges.join(), isNot(contains('封港')));
    state = GameStateSnapshot.fromJson(state.toJson());
    expect(state.gameplayRuntime.events.last.visibility,
        GameplayVariableVisibility.engine);
    expect(state.gameplayRuntime.threads.single.isPlayerFacing, isFalse);
    state = _turn(system, state, id: 'resolve-secret', threads: [
      {
        'op': 'resolve',
        'id': 'secret',
        'reason': '真相已被查明',
        'visibility': 'public'
      }
    ]);
    expect(state.gameplayRuntime.threads.single.isPlayerFacing, isFalse);
    expect(state.gameplayPlayerVariableChanges, isEmpty);
  });

  test(
      'thread lifecycle preserves closed entries and rejects unknown or unsupported changes',
      () {
    final system = _system();
    var state = _turn(system, _state(), id: 'open', threads: [
      {
        'op': 'open',
        'id': 'promise',
        'title': '护送证人',
        'description': '答应带她出城',
        'reason': '证人提出了求助',
        'visibility': 'public'
      },
      {'op': 'resolve', 'id': 'unknown', 'reason': '没有这件事'},
      {'op': 'open', 'id': 'no-reason', 'title': '无依据承诺'},
    ]);
    expect(state.gameplayRuntime.threads, hasLength(1));
    expect(state.gameplayVariableWarnings, hasLength(2));
    state = _turn(system, state, id: 'break', threads: [
      {'op': 'break', 'id': 'promise', 'reason': '你独自离开了港口'}
    ]);
    expect(state.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.broken);
    expect(state.gameplayRuntime.threads.single.description, '答应带她出城');
    state = _turn(system, state, id: 'reopen', threads: [
      {'op': 'open', 'id': 'promise', 'title': '重复承诺', 'reason': '试图覆盖往事'}
    ]);
    expect(state.gameplayRuntime.threads.single.title, '护送证人');
    expect(state.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.broken);
  });

  test(
      'missing and corrupt patches preserve runtime; stable turn ID prevents double settlement',
      () {
    final system = _system();
    final previous = _turn(system, _state(), id: 'done', time: '午后', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 5}
    ]);
    final repeat = _turn(system, previous, id: 'done', time: '夜晚', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 5}
    ]);
    expect(repeat.gameplayRuntime.toJson(), previous.gameplayRuntime.toJson());
    expect(repeat.customVariables, previous.customVariables);
    for (final content in [
      '正文',
      '[THEATER_PATCH]{"ops": invalid}[/THEATER_PATCH]'
    ]) {
      final invalid = GameplayTurnEngine.apply(
          system: system,
          previousState: previous,
          narrativeState: previous.copyWith(timeLabel: '夜晚'),
          content: content,
          turnId: 'repair');
      expect(
          invalid.gameplayRuntime.toJson(), previous.gameplayRuntime.toJson());
      expect(invalid.customVariables, previous.customVariables);
      expect(invalid.gameplayVariableWarnings, isNotEmpty);
    }
    expect(
        GameStateSnapshot.fromJson({'characterId': 'old'})
            .gameplayRuntime
            .isEmpty,
        isTrue);
  });

  test('reveal conditions and changed comparison fail closed on unknown paths',
      () {
    const conditions = [GameplayCondition(path: 'risk', op: 'gte', value: 28)];
    expect(
        GameplayTurnEngine.matches(
            conditions: conditions, values: {'risk': 20}),
        isFalse);
    expect(
        GameplayTurnEngine.matches(
            conditions: conditions, values: {'risk': 28}),
        isTrue);
    expect(
        GameplayTurnEngine.matches(conditions: [
          const GameplayCondition(path: 'unknown', op: 'neq', value: 0)
        ], values: {}),
        isFalse);
    expect(
        GameplayTurnEngine.matches(
            conditions: [const GameplayCondition(path: 'risk', op: 'changed')],
            values: {'risk': 28},
            previousValues: {'risk': 20}),
        isTrue);
  });

  test('oversized conditions stay rejected after model deserialization', () {
    final json = _system(rules: [
      _rule(effects: [
        const GameplayRuleEffect(op: 'set', path: 'sealed', value: true),
      ])
    ]).toJson();
    final rules = json['rules'] as List;
    (rules.single as Map)['conditions'] = [
      for (var i = 0; i < 16; i++) {'path': 'risk', 'op': 'gte', 'value': 0},
      {'path': 'risk', 'op': 'gt', 'value': 200},
    ];
    final restored = GameplaySystem.fromJson(json);
    final state = _turn(restored, _state(), id: 'too-many');
    expect(state.customVariables['sealed'], isFalse);
    expect(state.gameplayRuntime.lastRuleTurns, isEmpty);
  });

  test('malformed or oversized patch arrays cannot settle a gameplay turn', () {
    final system = _system();
    final previous = _turn(system, _state(), id: 'valid');
    for (final body in [
      {
        'ops': [null]
      },
      {
        'ops': [{}]
      },
      {
        'ops': [
          {'op': 'inc', 'path': 'risk'}
        ]
      },
      {
        'ops': [],
        'threads': [false]
      },
      {
        'ops': List.filled(49, {'op': 'inc', 'path': 'risk', 'value': 1})
      },
    ]) {
      final content = '[THEATER_PATCH]${jsonEncode(body)}[/THEATER_PATCH]';
      expect(GameplayPatchParser.parseResult(content).isValid, isFalse);
      final state = GameplayTurnEngine.apply(
        system: system,
        previousState: previous,
        narrativeState: previous.copyWith(timeLabel: '午夜'),
        content: content,
        turnId: 'invalid',
      );
      expect(state.gameplayRuntime.toJson(), previous.gameplayRuntime.toJson());
      expect(state.customVariables['clock'], 0);
      expect(state.gameplayVariableWarnings, isNotEmpty);
    }
  });

  test('overlong thread IDs cannot collide with a valid prefix', () {
    final id = List.filled(80, 'p').join();
    final system = _system();
    final previous = _turn(system, _state(), id: 'open', threads: [
      {
        'op': 'open',
        'id': id,
        'title': '守住承诺',
        'reason': '已经作出承诺',
        'visibility': 'public'
      },
    ]);
    final state = _turn(system, previous, id: 'collision', threads: [
      {
        'op': 'resolve',
        'id': '${id}x',
        'reason': '试图结束另一事项',
        'visibility': 'public'
      },
    ]);
    expect(
        state.gameplayRuntime.threads.single.status, GameplayThreadStatus.open);
    expect(state.gameplayVariableWarnings, isNotEmpty);
  });

  test('contains conditions support text and list with their own semantics',
      () {
    const condition =
        GameplayCondition(path: 'clue', op: 'contains', value: '船票');
    expect(
        GameplayTurnEngine.matches(
            conditions: [condition], values: {'clue': '染盐的船票'}),
        isTrue);
    expect(
        GameplayTurnEngine.matches(conditions: [
          condition
        ], values: {
          'clue': ['船票', '账本']
        }),
        isTrue);
    expect(
        GameplayTurnEngine.matches(conditions: [
          condition
        ], values: {
          'clue': ['染盐的船票']
        }),
        isFalse);
  });

  test(
      'engine-owned threads retain engine visibility through resolution and restore',
      () {
    final engineRule =
        _rule(visibility: GameplayVariableVisibility.engine, threads: [
      const GameplayThreadOperation(
          op: 'open', id: 'engine-secret', title: '引擎秘密', reason: '秘密阶段已激活'),
    ]);
    final system = _system(rules: [engineRule]);
    var state = _turn(system, _state(), id: 'secret', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 8}
    ]);
    state = GameStateSnapshot.fromJson(state.toJson());
    expect(state.gameplayRuntime.threads.single.visibility,
        GameplayVariableVisibility.engine);
    final guessed = _turn(system, state, id: 'guessed-secret', threads: [
      {
        'op': 'resolve',
        'id': 'engine-secret',
        'reason': '试图猜测并结算隐藏事项',
        'visibility': 'public'
      },
    ]);
    expect(guessed.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.open);
    expect(guessed.gameplayVariableWarnings.single, contains('无权修改'));
    expect(
        state.gameplayRuntime.events.every(
            (event) => event.visibility == GameplayVariableVisibility.engine),
        isTrue);
    expect(state.gameplayPlayerVariableChanges.join(), isNot(contains('秘密')));
    final closer = _system(rules: [
      _rule(visibility: GameplayVariableVisibility.director, threads: [
        const GameplayThreadOperation(
            op: 'resolve', id: 'engine-secret', reason: '秘密阶段已完成'),
      ])
    ]);
    final reset = state.copyWith(
        gameplayRuntime: GameplayRuntimeState(
      turn: state.gameplayRuntime.turn,
      threads: state.gameplayRuntime.threads,
    ));
    state = _turn(closer, reset, id: 'resolved');
    state = GameStateSnapshot.fromJson(state.toJson());
    expect(state.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.resolved);
    expect(state.gameplayRuntime.threads.single.visibility,
        GameplayVariableVisibility.engine);
    expect(state.gameplayPlayerVariableChanges, isEmpty);
  });

  test(
      'director resolution preserves known public thread without secret reason',
      () {
    final previous = _turn(_system(), _state(), id: 'promise', threads: [
      {
        'op': 'open',
        'id': 'public-promise',
        'title': '护送证人',
        'description': '答应送她出城',
        'reason': '已经作出承诺',
        'visibility': 'public'
      },
    ]);
    final system = _system(rules: [
      _rule(visibility: GameplayVariableVisibility.director, threads: [
        const GameplayThreadOperation(
            op: 'resolve', id: 'public-promise', reason: '卧底暗中已经接应证人'),
      ])
    ]);
    final state = _turn(system, previous, id: 'secret-resolution', ops: [
      {'op': 'inc', 'path': 'risk', 'value': 8}
    ]);
    expect(state.gameplayRuntime.threads.single.isPlayerFacing, isTrue);
    expect(state.gameplayRuntime.threads.single.status,
        GameplayThreadStatus.resolved);
    expect(state.gameplayRuntime.threads.single.description, '答应送她出城');
    expect(state.gameplayPlayerVariableChanges.join(), isNot(contains('卧底')));
    expect(state.gameplayRuntime.threads.single.reason, isNot(contains('卧底')));
  });
}

GameplayPatchOperation _op(String op, String path, dynamic value) =>
    GameplayPatchOperation.fromJson({'op': op, 'path': path, 'value': value});

GameStateSnapshot _state() =>
    GameStateSnapshot.empty('story').copyWith(timeLabel: '清晨');

GameStateSnapshot _turn(
  GameplaySystem system,
  GameStateSnapshot state, {
  required String id,
  String? time,
  String? location,
  List<Map<String, dynamic>> ops = const [],
  List<Map<String, dynamic>> threads = const [],
}) =>
    GameplayTurnEngine.apply(
        system: system,
        previousState: state,
        narrativeState: state.copyWith(timeLabel: time, location: location),
        turnId: id,
        content: '[THEATER_PATCH]${jsonEncode({
              'ops': ops,
              'threads': threads
            })}[/THEATER_PATCH]');

GameplayRuleDefinition _rule({
  List<GameplayRuleCost> costs = const [],
  List<GameplayRuleEffect> effects = const [],
  List<GameplayThreadOperation> threads = const [],
  bool once = true,
  int cooldown = 0,
  GameplayVariableVisibility visibility = GameplayVariableVisibility.public,
}) =>
    GameplayRuleDefinition(
        id: 'lockdown',
        title: '封港',
        when: '警戒达到 28',
        effect: '封港并开启地下路线',
        visibility: visibility,
        conditions: [
          const GameplayCondition(path: 'risk', op: 'gte', value: 28)
        ],
        costs: costs,
        effects: effects,
        threads: threads,
        once: once,
        cooldownTurns: cooldown,
        playerSummary: '普通出口已被封锁');

GameplaySystem _system({List<GameplayRuleDefinition> rules = const []}) =>
    GameplaySystem(
      schemaVersion: 3,
      title: '雾港',
      summary: '',
      coreLoop: '',
      generatedAt: DateTime(2026),
      rules: rules,
      variables: [
        _variable('risk', initial: 20, maxDelta: 8),
        _variable('money', initial: 20, maxDelta: 1),
        _variable('clock',
            type: GameplayVariableType.clock,
            authority: GameplayVariableAuthority.rule,
            advance: 1),
        _variable('sealed',
            type: GameplayVariableType.boolean,
            initial: false,
            authority: GameplayVariableAuthority.rule),
        _variable('player', authority: GameplayVariableAuthority.player),
        _variable('computed', authority: GameplayVariableAuthority.computed),
      ],
    );

GameplayVariableDefinition _variable(
  String key, {
  dynamic initial = 0,
  double? maxDelta,
  GameplayVariableType type = GameplayVariableType.number,
  GameplayVariableAuthority authority = GameplayVariableAuthority.ai,
  double? advance,
}) =>
    GameplayVariableDefinition(
        key: key,
        label: key,
        group: '状态',
        type: type,
        visibility: GameplayVariableVisibility.public,
        authority: authority,
        initialValue: initial,
        description: '',
        min: 0,
        max: 100,
        maxDelta: maxDelta,
        advanceOnTimeChange: advance);
