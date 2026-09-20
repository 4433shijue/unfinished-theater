import 'dart:convert';

import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/services/gameplay_history_service.dart';
import 'package:ai_roleplay_chat/services/gameplay_turn_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('receipts capture accepted clamped values and all operation reasons',
      () {
    final system = _system([_variable('risk', initial: 20, maxDelta: 8)]);
    final state = _turn(system, _empty(), 'one', ops: [
      _op('inc', 'risk', 6, '盘问时答错了口令'),
      _op('inc', 'risk', 9, '检查者注意到了武器'),
    ]);
    final receipt = state.gameplayVariableRecords.single;
    expect(receipt.path, 'risk');
    expect(receipt.before, 20);
    expect(receipt.after, 28);
    expect(receipt.steps.map((step) => step.after), [26, 28]);
    expect(receipt.steps.map((step) => step.source), ['ai', 'ai']);
    expect(receipt.steps.last.reason, '检查者注意到了武器');
    final restored = GameStateSnapshot.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>);
    expect(restored.gameplayVariableRecords.single.toJson(), receipt.toJson());
    expect(restored.copyWith(location: '港口').gameplayVariableHistoryVersion, 1);
  });

  test('time, rule cost and rule effect have separate actual receipts', () {
    final system = _system([
      _variable('money', initial: 20),
      _variable('clock',
          type: GameplayVariableType.clock,
          authority: GameplayVariableAuthority.rule,
          advance: 1),
    ], rules: [
      _rule(costs: [
        const GameplayRuleCost(path: 'money', amount: 2)
      ], effects: [
        const GameplayRuleEffect(op: 'inc', path: 'money', value: 5),
      ]),
    ]);
    final state =
        _turn(system, _empty().copyWith(timeLabel: '清晨'), 'one', time: '午后');
    final money =
        state.gameplayVariableRecords.firstWhere((r) => r.path == 'money');
    expect(money.steps.map((step) => [step.before, step.after]), [
      [20, 18],
      [18, 23]
    ]);
    expect(money.steps.every((step) => step.ruleId == 'rule'), isTrue);
    final clock =
        state.gameplayVariableRecords.firstWhere((r) => r.path == 'clock');
    expect(clock.steps.single.source, 'time');
    expect(clock.after, 1);
  });

  test('failed atomic rule leaves no receipt or deduction', () {
    final system = _system([
      _variable('money', initial: 20)
    ], rules: [
      _rule(costs: [
        const GameplayRuleCost(path: 'money', amount: 2)
      ], effects: [
        const GameplayRuleEffect(op: 'set', path: 'money', value: 999),
      ]),
    ]);
    final state = _turn(system, _empty(), 'one');
    expect(state.customVariables['money'], 20);
    expect(state.gameplayVariableRecords, isEmpty);
    expect(state.gameplayVariableWarnings.single, contains('整条规则未执行'));
  });

  test('net-zero rule transaction keeps both cost and refund details', () {
    final system = _system([
      _variable('money', initial: 20)
    ], rules: [
      _rule(costs: [
        const GameplayRuleCost(path: 'money', amount: 2)
      ], effects: [
        const GameplayRuleEffect(op: 'inc', path: 'money', value: 2),
      ]),
    ]);
    final state = _turn(system, _empty(), 'one');
    final entry =
        _history(system, state, [_message('one', state, system)], 'money')
            .single;
    expect(entry.beforeText, '20');
    expect(entry.afterText, '20');
    expect(entry.steps.map((step) => step.afterText), ['18', '20']);
  });

  test('duplicate turn is idempotent and missing patch clears old receipts',
      () {
    final system = _system([_variable('risk')]);
    final first = _turn(system, _empty(), 'one', ops: [_op('inc', 'risk', 5)]);
    final duplicate = _turn(system, first, 'one', ops: [_op('inc', 'risk', 5)]);
    expect(duplicate.customVariables['risk'], 5);
    expect(duplicate.gameplayVariableRecords, hasLength(1));
    final missing = GameplayTurnEngine.apply(
        system: system,
        previousState: duplicate,
        narrativeState: duplicate,
        content: '仅有正文',
        turnId: 'two');
    expect(missing.gameplayVariableRecords, isEmpty);
    expect(missing.gameplayVariableHistoryVersion, 1);
    final messages = [
      _message('one', first, system),
      _message('copy', duplicate, system),
      _message('two', missing, system),
    ];
    expect(_history(system, missing, messages, 'risk').map((e) => e.messageId),
        ['one']);
  });

  test('history reads current branch only and retains source message ids', () {
    final system = _system([_variable('risk')]);
    final first = _turn(system, _empty(), 'one', ops: [_op('inc', 'risk', 5)]);
    final oldBranch = _turn(system, first, 'old', ops: [_op('inc', 'risk', 4)]);
    final newBranch = _turn(system, first, 'new', ops: [_op('inc', 'risk', 1)]);
    final oldMessages = [
      _message('one', first, system),
      _message('old', oldBranch, system)
    ];
    final newMessages = [
      _message('one', first, system),
      _message('new', newBranch, system)
    ];
    final beforeJson = jsonEncode(newMessages.map((m) => m.toJson()).toList());
    expect(
        _history(system, oldBranch, oldMessages, 'risk').first.afterText, '9');
    final newHistory = _history(system, newBranch, newMessages, 'risk');
    expect(newHistory.map((e) => e.messageId), ['new', 'one']);
    expect(newHistory.first.afterText, '6');
    expect(jsonEncode(newMessages.map((m) => m.toJson()).toList()), beforeJson);
    expect(_history(system, first, [newMessages.first], 'risk'), hasLength(1));
  });

  test('pagination returns latest first and honors requested limit', () {
    final system = _system([_variable('risk')]);
    var state = _empty();
    final messages = <ChatMessage>[];
    for (var i = 0; i < 14; i++) {
      state = _turn(system, state, 'turn$i', ops: [_op('inc', 'risk', 1)]);
      messages.add(_message('turn$i', state, system));
    }
    expect(_history(system, state, messages, 'risk'), hasLength(10));
    expect(_history(system, state, messages, 'risk').first.messageId, 'turn13');
    expect(
        GameplayHistoryService.forVariable(
            messages: messages,
            currentSystem: system,
            currentState: state,
            path: 'risk',
            limit: 11),
        hasLength(11));
    expect(
        GameplayHistoryService.forVariable(
            messages: messages,
            currentSystem: system,
            currentState: state,
            path: 'risk',
            limit: 0),
        isEmpty);
  });

  test('fuzzy history freezes stages and never forwards numeric reasons', () {
    final system = _system([
      _variable('risk',
          initial: 20, visibility: GameplayVariableVisibility.fuzzy)
    ]);
    final state = _turn(system, _empty(), 'one', ops: [
      _op('inc', 'risk', 40, '警戒由20提高至60，超过秘密阈值50'),
    ]);
    final entry =
        _history(system, state, [_message('one', state, system)], 'risk')
            .single;
    expect(entry.beforeText, '平静');
    expect(entry.afterText, '紧张');
    final playerText = '${entry.beforeText}${entry.afterText}${entry.reason}'
        '${entry.steps.map((s) => '${s.beforeText}${s.afterText}${s.reason}')}';
    expect(playerText, isNot(matches(RegExp(r'\d'))));
    final publicNow = _system([_variable('risk')]);
    final old =
        _history(publicNow, state, [_message('one', state, system)], 'risk')
            .single;
    expect(old.beforeText, '平静');
    expect(old.afterText, '紧张');
  });

  test('fuzzy changes inside one known stage are not exposed', () {
    final system = _system([
      _variable('risk',
          initial: 20, visibility: GameplayVariableVisibility.fuzzy)
    ]);
    final state = _turn(system, _empty(), 'one', ops: [_op('inc', 'risk', 1)]);
    expect(state.gameplayVariableRecords, hasLength(1));
    expect(_history(system, state, [_message('one', state, system)], 'risk'),
        isEmpty);
  });

  test('current fuzzy or private definition cannot disclose public old values',
      () {
    final old = _system([_variable('risk', initial: 20)]);
    final state =
        _turn(old, _empty(), 'one', ops: [_op('inc', 'risk', 40, '增加40')]);
    final messages = [_message('one', state, old)];
    final fuzzy = _system(
        [_variable('risk', visibility: GameplayVariableVisibility.fuzzy)]);
    final entry = _history(fuzzy, state, messages, 'risk').single;
    expect(entry.beforeText, '数值已隐藏');
    expect(entry.afterText, '数值已隐藏');
    expect(entry.steps, isEmpty);
    expect(entry.reason, isNot(contains('40')));
    for (final visibility in [
      GameplayVariableVisibility.director,
      GameplayVariableVisibility.engine
    ]) {
      final hidden = _system([_variable('risk', visibility: visibility)]);
      expect(_history(hidden, state, messages, 'risk'), isEmpty);
    }
  });

  test('revealing later never exposes an earlier unrevealed turn', () {
    final system = _system([
      _variable('risk', initial: 20, revealWhen: [
        const GameplayCondition(path: 'known', op: 'eq', value: true),
      ]),
      _variable('known', type: GameplayVariableType.boolean, initial: false),
    ]);
    final first = _turn(system, _empty(), 'one', ops: [_op('inc', 'risk', 10)]);
    final second = _turn(system, first, 'two', ops: [
      _op('set', 'known', true),
      _op('inc', 'risk', 10),
    ]);
    final entries = _history(
        system,
        second,
        [
          _message('one', first, system),
          _message('two', second, system),
        ],
        'risk');
    expect(entries, hasLength(1));
    expect(entries.single.beforeText, '当时未公开');
    expect(entries.single.afterText, '40');
    expect(entries.single.steps.single.beforeText, '30');
    // That value was already known when this specific operation executed.
    expect(first.gameplayVariableRecords.single.playerVisible, isFalse);
  });

  test('hidden rules affecting a public value keep their reasons private', () {
    final system = _system([
      _variable('money', initial: 20)
    ], rules: [
      _rule(visibility: GameplayVariableVisibility.director, effects: [
        const GameplayRuleEffect(op: 'inc', path: 'money', value: 5),
      ]),
    ]);
    final state = _turn(system, _empty(), 'one');
    final entry =
        _history(system, state, [_message('one', state, system)], 'money')
            .single;
    expect(entry.afterText, '25');
    expect(entry.steps, isEmpty);
    expect(entry.reason, '未记录可公开的原因');
    expect(state.gameplayPlayerVariableChanges.join(), isNot(contains('幕后交易')));
  });

  test('AI reasons mentioning private definitions are redacted', () {
    final system = _system([
      _variable('risk'),
      _variable('secret',
          visibility: GameplayVariableVisibility.director, label: '卧底身份'),
    ]);
    final state = _turn(system, _empty(), 'one', ops: [
      _op('inc', 'risk', 2, '卧底身份已暴露'),
    ]);
    final entry =
        _history(system, state, [_message('one', state, system)], 'risk')
            .single;
    expect(entry.reason, isNot(contains('卧底')));
    expect(state.gameplayVariableRecords.single.steps.single.reason,
        contains('卧底'));
  });

  test('hidden net-zero rule does not reveal an otherwise private event', () {
    final system = _system([
      _variable('money', initial: 20),
    ], rules: [
      _rule(
        visibility: GameplayVariableVisibility.director,
        costs: [const GameplayRuleCost(path: 'money', amount: 2)],
        effects: [
          const GameplayRuleEffect(op: 'inc', path: 'money', value: 2),
        ],
      ),
    ]);
    final state = _turn(system, _empty(), 'one');
    expect(state.gameplayVariableRecords.single.steps, hasLength(2));
    expect(_history(system, state, [_message('one', state, system)], 'money'),
        isEmpty);
  });

  test('old director receipts remain private after definition becomes public',
      () {
    final hidden = _system(
        [_variable('risk', visibility: GameplayVariableVisibility.director)]);
    final state = _turn(hidden, _empty(), 'one', ops: [_op('inc', 'risk', 2)]);
    final current = _system([_variable('risk')]);
    final messages = [_message('one', state, hidden)];
    expect(_history(current, state, messages, 'risk'), isEmpty);
    expect(
        GameplayHistoryService.forVariable(
                messages: messages,
                currentSystem: current,
                currentState: state,
                path: 'risk',
                reveal: true)
            .single
            .afterText,
        '2');
  });

  test('current reveal conditions also gate old receipts', () {
    final system = _system([_variable('risk')]);
    final state = _turn(system, _empty(), 'one', ops: [_op('inc', 'risk', 2)]);
    final current = _system([
      _variable('risk', revealWhen: [
        const GameplayCondition(path: 'known', op: 'eq', value: true),
      ])
    ]);
    expect(_history(current, state, [_message('one', state, system)], 'risk'),
        isEmpty);
  });

  test('legacy snapshots require historical definitions and confirmed baseline',
      () {
    final system = _system([_variable('risk', initial: 20)]);
    final before = _empty().copyWith(customVariables: {'risk': 31});
    final after = before.copyWith(
        customVariables: {'risk': 37},
        gameplayVariableChanges: ['伪造原因：秘密任务'],
        gameplayPlayerVariableChanges: ['不可当作结构化数据']);
    final message = _message('old', after, system, baseline: before);
    final entry = _history(system, after, [message], 'risk').single;
    expect(entry.beforeText, '31');
    expect(entry.afterText, '37');
    expect(entry.legacy, isTrue);
    expect(entry.reason, contains('未记录变化原因'));
    expect(entry.reason, isNot(contains('秘密任务')));
    expect(_history(system, after, [_message('old', after, system)], 'risk'),
        isEmpty);
    final noDefinition = message.copyWith(gameStateSnapshot: after.toJson());
    expect(_history(system, after, [noDefinition], 'risk'), isEmpty);
  });

  test(
      'legacy inference uses adjacent saved snapshots and never replays content',
      () {
    final system = _system([_variable('risk')]);
    final first = _empty().copyWith(customVariables: {'risk': 7});
    final second = _empty().copyWith(customVariables: {'risk': 12});
    final messages = [
      _message('one', first, system),
      _message('two', second, system).copyWith(
          content:
              '[THEATER_PATCH]{"ops":[{"op":"set","path":"risk","value":99}]}[/THEATER_PATCH]'),
    ];
    final entries = _history(system, second, messages, 'risk');
    expect(entries, hasLength(1));
    expect(entries.single.afterText, '12');
  });

  test('legacy values hidden then cannot be revealed by the current definition',
      () {
    final hidden = _system(
        [_variable('risk', visibility: GameplayVariableVisibility.director)]);
    final public = _system([_variable('risk')]);
    final before = _empty().copyWith(customVariables: {'risk': 3});
    final after = _empty().copyWith(customVariables: {'risk': 7});
    expect(
        _history(public, after,
            [_message('one', after, hidden, baseline: before)], 'risk'),
        isEmpty);
  });

  test('same key with changed type has separate history segments', () {
    final numeric = _system([_variable('risk', label: '警戒')]);
    final first = _turn(numeric, _empty(), 'one', ops: [_op('inc', 'risk', 3)]);
    final text = _system([
      _variable('risk',
          label: '行动阶段', type: GameplayVariableType.text, initial: '准备')
    ]);
    final second =
        _turn(text, _empty(), 'two', ops: [_op('set', 'risk', '出发')]);
    final entries = _history(
        text,
        second,
        [
          _message('one', first, numeric),
          _message('two', second, text),
        ],
        'risk');
    expect(entries, hasLength(2));
    expect(entries.first.type, GameplayVariableType.text);
    expect(entries.first.definitionChanged, isTrue);
    expect(entries.first.segmentId, isNot(entries.last.segmentId));
    expect(entries.last.label, '警戒');
    expect(entries.last.afterText, '3');
  });

  test('list receipt is not mutated by later state list edits', () {
    final system = _system([
      _variable('clues', type: GameplayVariableType.list, initial: <String>[])
    ]);
    final state =
        _turn(system, _empty(), 'one', ops: [_op('append', 'clues', '账本')]);
    (state.customVariables['clues'] as List)[0] = '新证词';
    expect(state.gameplayVariableRecords.single.after, ['账本']);
    expect(state.gameplayVariableRecords.single.steps.single.after, ['账本']);
  });
}

GameStateSnapshot _empty() => GameStateSnapshot.empty('story');

GameplayVariableDefinition _variable(
  String key, {
  String? label,
  dynamic initial = 0,
  double? maxDelta,
  GameplayVariableType type = GameplayVariableType.number,
  GameplayVariableVisibility visibility = GameplayVariableVisibility.public,
  GameplayVariableAuthority authority = GameplayVariableAuthority.ai,
  double? advance,
  List<GameplayCondition> revealWhen = const [],
}) =>
    GameplayVariableDefinition(
      key: key,
      label: label ?? key,
      group: '状态',
      type: type,
      visibility: visibility,
      authority: authority,
      initialValue: initial,
      description: '',
      min: 0,
      max: 100,
      maxDelta: maxDelta,
      advanceOnTimeChange: advance,
      revealWhen: revealWhen,
      stages: const [
        GameplayVariableStage(min: 0, label: '平静'),
        GameplayVariableStage(min: 50, label: '紧张'),
      ],
    );

GameplaySystem _system(List<GameplayVariableDefinition> variables,
        {List<GameplayRuleDefinition> rules = const []}) =>
    GameplaySystem(
      schemaVersion: 3,
      title: '雾港',
      summary: '',
      coreLoop: '',
      generatedAt: DateTime(2026),
      variables: variables,
      rules: rules,
    );

GameplayRuleDefinition _rule({
  List<GameplayRuleCost> costs = const [],
  List<GameplayRuleEffect> effects = const [],
  GameplayVariableVisibility visibility = GameplayVariableVisibility.public,
}) =>
    GameplayRuleDefinition(
      id: 'rule',
      title: '幕后交易',
      when: '满足资金条件',
      effect: '秘密转移资金',
      visibility: visibility,
      playerSummary: '完成交易',
      conditions: const [GameplayCondition(path: 'money', op: 'gte', value: 1)],
      costs: costs,
      effects: effects,
    );

Map<String, dynamic> _op(String op, String path, dynamic value,
        [String reason = '本轮行动导致变化']) =>
    {
      'op': op,
      'path': path,
      'value': value,
      'reason': reason,
    };

GameStateSnapshot _turn(
        GameplaySystem system, GameStateSnapshot previous, String id,
        {List<Map<String, dynamic>> ops = const [], String? time}) =>
    GameplayTurnEngine.apply(
        system: system,
        previousState: previous,
        narrativeState: previous.copyWith(timeLabel: time),
        turnId: id,
        content: '[THEATER_PATCH]${jsonEncode({'ops': ops})}[/THEATER_PATCH]');

ChatMessage _message(String id, GameStateSnapshot state, GameplaySystem system,
        {GameStateSnapshot? baseline}) =>
    ChatMessage(
      id: id,
      role: ChatRole.assistant,
      content: '对应剧情',
      timestamp: DateTime(2026, 9, 20),
      isSummarized: false,
      gameStateSnapshot: {
        ...state.toJson(),
        'gameplaySystem': system.toJson(),
        if (baseline != null)
          'gameplayBaseline': {
            'state': baseline.toJson(),
            'system': system.toJson(),
          },
      },
    );

List<GameplayVariableHistoryEntry> _history(GameplaySystem current,
        GameStateSnapshot state, List<ChatMessage> messages, String path) =>
    GameplayHistoryService.forVariable(
        messages: messages,
        currentSystem: current,
        currentState: state,
        path: path);
