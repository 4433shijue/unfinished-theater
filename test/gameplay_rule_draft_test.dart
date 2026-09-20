import 'dart:convert';

import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_runtime.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/services/gameplay_rule_draft.dart';
import 'package:ai_roleplay_chat/services/gameplay_rule_rehearsal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('untouched structured execution round trips without losing operations',
      () {
    final system = ruleEditorSystem();
    final original = system.rules.single;
    final result =
        validateRule(system, GameplayRuleDraft.executionOf(original));
    expect(result, original.toJson());
  });

  test('execution descriptions never overwrite the player summary', () {
    final system = ruleEditorSystem();
    final execution = GameplayRuleDraft.executionOf(system.rules.single);
    (execution['conditions'] as List)
        .add({'path': '幕后.线人', 'op': 'eq', 'value': true});
    final result = validateRule(system, execution, refresh: true);
    expect(result['when'], contains('秘密线人'));
    expect(result['playerSummary'], '动静太大会引来盘查。');
    expect(result['effect'], contains('筹码'));
    expect(
        () => GameplayRuleDraft.validate(
              system: system,
              original: system.rules.single,
              execution: execution,
              title: '盘查',
              when: '发生动静',
              effect: '招来盘查',
              playerSummary: '',
            ),
        throwsFormatException);
  });

  test('text-only legacy rules are not converted by opening or saving', () {
    final system = ruleEditorSystem(legacy: true);
    final execution = GameplayRuleDraft.executionOf(system.rules.single);
    expect(GameplayRuleDraft.isStructured(execution), isFalse);
    final result = validateRule(system, execution);
    expect(result, system.rules.single.toJson());
    expect(result.containsKey('conditions'), isFalse);
  });

  test(
      'raw invalid references, permissions, values and frequency fail before normalization',
      () {
    final system = ruleEditorSystem();
    final cases = <Map<String, dynamic>>[
      {
        'conditions': [
          {'path': '不存在.变量', 'op': 'eq', 'value': 2}
        ]
      },
      {
        'conditions': [
          {'path': '幕后.线人', 'op': 'gte', 'value': 2}
        ]
      },
      {
        'effects': [
          {'path': '进度.只读', 'op': 'set', 'value': 2}
        ]
      },
      {
        'effects': [
          {'path': '局势.筹码', 'op': 'set', 'value': 101}
        ]
      },
      {
        'effects': [
          {'path': '幕后.线人', 'op': 'set', 'value': 'true'}
        ]
      },
      {
        'effects': [
          {'path': '调查.态度', 'op': 'set', 'value': '不在选项'}
        ]
      },
      {
        'effects': [
          {'path': '调查.证物', 'op': 'append', 'value': ''}
        ]
      },
      {
        'costs': [
          {'path': '幕后.线人', 'amount': 1}
        ]
      },
      {
        'costs': [
          {'path': '局势.筹码', 'amount': -1}
        ]
      },
      {
        'costs': [
          {'path': '进度.只读', 'amount': 1}
        ]
      },
      {'cooldownTurns': -3},
      {'cooldownTurns': '3'},
      {'once': 'false'},
      {'conditions': []},
      {'effects': [], 'threads': []},
      {
        'threads': [
          {
            'op': 'open',
            'id': 'p',
            'title': '约定',
            'reason': '',
            'visibility': 'public'
          }
        ]
      },
      {'title': '高级 JSON 不能改元信息'},
    ];
    for (final patch in cases) {
      final execution = {
        ...GameplayRuleDraft.executionOf(system.rules.single),
        ...patch
      };
      expect(() => validateRule(system, execution), throwsFormatException,
          reason: '$patch');
    }
  });

  test('operator options follow variable type and writable authority', () {
    final system = ruleEditorSystem();
    expect(GameplayRuleDraft.conditionOps(system.variableFor('幕后.线人')!),
        ['eq', 'neq', 'changed']);
    expect(GameplayRuleDraft.effectOps(system.variableFor('调查.证物')!),
        ['set', 'append', 'remove']);
    expect(GameplayRuleDraft.conditionOps(system.variableFor('调查.暴露')!),
        contains('gte'));
    expect(GameplayRuleDraft.writable(system.variableFor('进度.只读')!), isFalse);
  });

  test(
      'boundary previews use actual settlement and preserve the original state',
      () {
    final system = ruleEditorSystem();
    final original = editorState(system);
    final before = jsonEncode(original.toJson());
    final below = _rehearse(
        system,
        original.copyWith(customVariables: {
          ...original.customVariables,
          '调查.暴露': 4,
        }));
    expect(below.diagnoses.single.reason, contains('条件未满足'));
    expect(below.state.customVariables['局势.筹码'], 2);
    final exact = _rehearse(system, original);
    expect(exact.diagnoses.single.fired, isTrue);
    expect(exact.state.customVariables['局势.筹码'], 0);
    expect(exact.state.customVariables['幕后.线人'], isTrue);
    expect(jsonEncode(original.toJson()), before);

    final insufficient = _rehearse(
        system,
        original.copyWith(customVariables: {
          ...original.customVariables,
          '局势.筹码': 1,
        }));
    expect(insufficient.diagnoses.single.reason, contains('代价不足'));
    expect(insufficient.state.customVariables['局势.筹码'], 1);
    expect(insufficient.state.customVariables['幕后.线人'], isFalse);
  });

  test('preview distinguishes already fired, cooldown and narrative rules', () {
    final system = ruleEditorSystem();
    final once = editorState(system).copyWith(
        gameplayRuntime:
            const GameplayRuntimeState(turn: 4, lastRuleTurns: {'check': 3}));
    expect(_rehearse(system, once).diagnoses.single.reason, contains('已经触发过'));
    final repeated = GameplaySystem.fromJson({
      ...system.toJson(),
      'rules': [
        {...system.rules.single.toJson(), 'once': false, 'cooldownTurns': 3}
      ],
    });
    expect(_rehearse(repeated, once).diagnoses.single.reason,
        contains('冷却中，还需 1 回合'));
    final ready = once.copyWith(
        gameplayRuntime:
            const GameplayRuntimeState(turn: 5, lastRuleTurns: {'check': 3}));
    expect(_rehearse(repeated, ready).diagnoses.single.fired, isTrue);
    final legacy = ruleEditorSystem(legacy: true);
    expect(_rehearse(legacy, editorState(legacy)).diagnoses.single.reason,
        contains('叙事规则'));
  });

  test(
      'time-change conditions and cumulative costs match the production engine',
      () {
    final base = ruleEditorSystem();
    final system = GameplaySystem.fromJson({
      ...base.toJson(),
      'variables': [
        ...base.variables.map((v) => v.toJson()),
        {
          'key': '时间.进度',
          'label': '时钟',
          'group': '时间',
          'type': 'clock',
          'visibility': 'public',
          'authority': 'rule',
          'initialValue': 0,
          'min': 0,
          'max': 10,
          'advanceOnTimeChange': 1,
          'description': '时钟',
          'playerHint': '行动会推进时间',
        }
      ],
      'rules': [
        {
          ...base.rules.single.toJson(),
          'conditions': [
            {'path': '时间.进度', 'op': 'changed'}
          ]
        },
        {...base.rules.single.toJson(), 'id': 'second', 'title': '第二次盘查'},
      ],
    });
    final result = GameplayRuleRehearsal.run(
        system: system,
        previous: editorState(system),
        timeLabel: '上午',
        turnId: 'time-1');
    expect(result.diagnoses.first.fired, isTrue);
    expect(result.diagnoses.last.reason, contains('代价不足'));
    expect(result.state.customVariables['时间.进度'], 1);
  });
}

Map<String, dynamic> validateRule(
    GameplaySystem system, Map<String, dynamic> execution,
    {bool refresh = false}) {
  final rule = system.rules.single;
  return GameplayRuleDraft.validate(
      system: system,
      original: rule,
      execution: execution,
      title: rule.title,
      when: rule.when,
      effect: rule.effect,
      playerSummary: rule.playerSummary,
      refreshDescription: refresh);
}

({GameStateSnapshot state, List<GameplayRuleDiagnosis> diagnoses}) _rehearse(
        GameplaySystem system, GameStateSnapshot state) =>
    GameplayRuleRehearsal.run(
        system: system,
        previous: state,
        timeLabel: state.timeLabel,
        turnId: 'test-${state.gameplayRuntime.turn + 1}');

GameplaySystem ruleEditorSystem({bool legacy = false}) => GameplaySystem(
      schemaVersion: 3,
      title: '调查',
      summary: '调查',
      coreLoop: '搜集线索',
      generatedAt: DateTime(2026),
      variables: const [
        GameplayVariableDefinition(
            key: '调查.暴露',
            label: '暴露程度',
            group: '调查',
            type: GameplayVariableType.number,
            visibility: GameplayVariableVisibility.public,
            authority: GameplayVariableAuthority.ai,
            initialValue: 5,
            min: 0,
            max: 10,
            description: '暴露'),
        GameplayVariableDefinition(
            key: '局势.筹码',
            label: '筹码',
            group: '局势',
            type: GameplayVariableType.number,
            visibility: GameplayVariableVisibility.public,
            authority: GameplayVariableAuthority.rule,
            initialValue: 2,
            min: 0,
            max: 100,
            description: '筹码'),
        GameplayVariableDefinition(
            key: '幕后.线人',
            label: '秘密线人',
            group: '幕后',
            type: GameplayVariableType.boolean,
            visibility: GameplayVariableVisibility.director,
            authority: GameplayVariableAuthority.rule,
            initialValue: false,
            description: '隐藏身份'),
        GameplayVariableDefinition(
            key: '调查.态度',
            label: '态度',
            group: '调查',
            type: GameplayVariableType.choice,
            visibility: GameplayVariableVisibility.public,
            authority: GameplayVariableAuthority.ai,
            initialValue: '谨慎',
            options: ['谨慎', '大胆'],
            description: '态度'),
        GameplayVariableDefinition(
            key: '调查.证物',
            label: '证物',
            group: '调查',
            type: GameplayVariableType.list,
            visibility: GameplayVariableVisibility.public,
            authority: GameplayVariableAuthority.rule,
            initialValue: ['钥匙'],
            description: '证物'),
        GameplayVariableDefinition(
            key: '进度.只读',
            label: '只读进度',
            group: '进度',
            type: GameplayVariableType.number,
            visibility: GameplayVariableVisibility.public,
            authority: GameplayVariableAuthority.computed,
            initialValue: 0,
            min: 0,
            max: 10,
            description: '只读'),
      ],
      rules: [
        GameplayRuleDefinition(
          id: 'check',
          title: '盘查',
          when: '暴露达到阈值',
          effect: '有人跟踪',
          visibility: GameplayVariableVisibility.public,
          playerSummary: '动静太大会引来盘查。',
          conditions: legacy
              ? const []
              : const [GameplayCondition(path: '调查.暴露', op: 'gte', value: 5)],
          costs: legacy
              ? const []
              : const [GameplayRuleCost(path: '局势.筹码', amount: 2)],
          effects: legacy
              ? const []
              : const [
                  GameplayRuleEffect(op: 'set', path: '幕后.线人', value: true)
                ],
        )
      ],
    );

GameStateSnapshot editorState(GameplaySystem system) => GameStateSnapshot(
    characterId: 'test',
    updatedAt: DateTime(2026),
    timeLabel: '清晨',
    customVariables: system.initialValues());
