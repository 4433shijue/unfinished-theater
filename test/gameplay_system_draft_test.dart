import 'dart:convert';

import 'package:ai_roleplay_chat/models/gameplay_runtime.dart';
import 'package:ai_roleplay_chat/services/gameplay_system_draft.dart';
import 'package:ai_roleplay_chat/services/gameplay_system_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('schema 3 generation safety', () {
    test('accepts executable rules and checks references before normalizing',
        () {
      final json = _design();
      final system = GameplaySystemParser.parse(jsonEncode(json));
      expect(system.variables, hasLength(4));
      expect(system.rules, hasLength(1));
      _rule(json)['conditions'] = [
        {'path': '调查.不存在', 'op': 'gte', 'value': 2},
      ];
      expect(
          () => GameplaySystemParser.parse(jsonEncode(json)),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'message', contains('不存在'))));
    });

    test('rejects malformed operations instead of silently dropping them', () {
      for (final effects in <dynamic>[
        '增大风险',
        [false],
        [
          {'path': '调查.进展', 'op': 'eval', 'value': 'run()'}
        ],
        [
          {'path': '调查.进展', 'op': 'inc', 'value': '十'}
        ],
        [
          {'path': '调查.进展', 'op': 'append', 'value': '新线索'}
        ],
      ]) {
        final json = _design();
        _rule(json)['effects'] = effects;
        expect(() => GameplaySystemParser.parse(jsonEncode(json)),
            throwsFormatException);
      }
    });

    test('rejects authority violations, invalid reveal conditions and clocks',
        () {
      final ownership = _design();
      _variables(ownership)[1]['authority'] = 'player';
      expect(() => GameplaySystemParser.parse(jsonEncode(ownership)),
          throwsFormatException);
      final reveal = _design();
      _variables(reveal)[1]['revealWhen'] = [
        {'path': '秘密.失踪', 'op': 'eq', 'value': true},
      ];
      expect(() => GameplaySystemParser.parse(jsonEncode(reveal)),
          throwsFormatException);
      final clock = _design();
      _variables(clock)[0]['advanceOnTimeChange'] = 1;
      expect(() => GameplaySystemParser.parse(jsonEncode(clock)),
          throwsFormatException);
    });

    test('rejects negative fees and undocumented promise operations', () {
      final costs = _design();
      _rule(costs)['costs'] = [
        {'path': '调查.进展', 'amount': -1}
      ];
      expect(() => GameplaySystemParser.parse(jsonEncode(costs)),
          throwsFormatException);
      final promise = _design();
      _rule(promise)['threads'] = [
        {'op': 'open', 'id': 'a_promise', 'title': '替港民保密'},
      ];
      expect(() => GameplaySystemParser.parse(jsonEncode(promise)),
          throwsFormatException);
    });

    test('requires a separate player explanation for executable public rules',
        () {
      final json = _design();
      _rule(json).remove('playerSummary');
      expect(
          () => GameplaySystemParser.parse(jsonEncode(json)),
          throwsA(isA<FormatException>().having(
              (e) => e.message, 'message', contains('非剧透的 playerSummary'))));
    });

    test('rejects colliding identities and rules beyond runtime limits', () {
      final duplicate = _design();
      (duplicate['rules'] as List).add({..._rule(duplicate), 'id': ' port_watch '});
      expect(() => GameplaySystemParser.parse(jsonEncode(duplicate)), throwsFormatException);
      final crowded = _design();
      _rule(crowded)['conditions'] = List.generate(17,
          (_) => {'path': '调查.进展', 'op': 'gte', 'value': 60});
      expect(() => GameplaySystemParser.parse(jsonEncode(crowded)), throwsFormatException);
      final truncated = _design();
      _rule(truncated)['threads'] = [
        {'op': 'open', 'id': 'public_promise', 'title': '承诺',
         'reason': List.filled(301, '事').join(), 'visibility': 'public'},
      ];
      expect(() => GameplaySystemParser.parse(jsonEncode(truncated)), throwsFormatException);
    });

    test('keeps legacy prose rules usable in a schema 3 design', () {
      final json = _design();
      _rule(json).remove('conditions');
      _rule(json).remove('effects');
      final system = GameplaySystemParser.parse(jsonEncode(json));
      expect(system.rules.single.when, '调查进展达到六成');
    });
  });

  group('reviewable gameplay draft', () {
    test('keeps story history and only resets rules whose mechanics change',
        () {
      final current = GameplaySystemParser.parse(jsonEncode(_design()));
      final cosmeticJson = _design();
      _rule(cosmeticJson)['title'] = '新的显示名称';
      const runtime = GameplayRuntimeState(
        turn: 8,
        lastTurnId: 'turn-eight',
        lastRuleTurns: {'port_watch': 4, 'removed_rule': 2},
        threads: [GameplayStoryThread(id: 'public_promise', title: '向城中人许诺')],
        events: [
          GameplayRuntimeEvent(id: 'event-four', title: '巡查加密', turn: 4)
        ],
      );
      final cosmetic = GameplaySystemDraft.preview(
        current: current,
        generated: GameplaySystemParser.parse(jsonEncode(cosmeticJson)),
      ).migrateRuntime(runtime);
      expect(cosmetic.lastRuleTurns, {'port_watch': 4});
      final changedJson = _design();
      _rule(changedJson)['cooldownTurns'] = 3;
      final changed = GameplaySystemDraft.preview(
        current: current,
        generated: GameplaySystemParser.parse(jsonEncode(changedJson)),
      ).migrateRuntime(runtime);
      expect(changed.lastRuleTurns, isEmpty);
      expect(changed.turn, 8);
      expect(changed.lastTurnId, 'turn-eight');
      expect(changed.threads.single.title, '向城中人许诺');
      expect(changed.events.single.turn, 4);
    });

    test('preserves locked variables and rules while replacing another group',
        () {
      final current = GameplaySystemParser.parse(jsonEncode(_design()));
      final generatedJson = _design();
      _variables(generatedJson)[0]['initialValue'] = 70;
      _variables(generatedJson)[2]['label'] = '集市声望';
      _rule(generatedJson)['effect'] = '替换后的效果';
      final generated = GameplaySystemParser.parse(jsonEncode(generatedJson));
      final draft = GameplaySystemDraft.merge(
        current: current,
        generated: generated,
        lockedGroups: {'调查'},
      );
      expect(draft.system.variableFor('调查.进展')!.initialValue, 0);
      expect(draft.system.variableFor('城中.声望')!.label, '集市声望');
      expect(draft.system.rules.single.effect, current.rules.single.effect);
      expect(draft.changes, contains(contains('集市声望')));
      expect(current.variableFor('城中.声望')!.label, '城中声望');
    });

    test('explains missing cross-group dependencies of locked rules', () {
      final currentJson = _design();
      _rule(currentJson)['costs'] = [
        {'path': '城中.声望', 'amount': 1}
      ];
      final current = GameplaySystemParser.parse(jsonEncode(currentJson));
      final generatedJson = _design();
      _variables(generatedJson)[2]['key'] = '城中.口碑';
      final generated = GameplaySystemParser.parse(jsonEncode(generatedJson));
      expect(
          () => GameplaySystemDraft.merge(
                current: current,
                generated: generated,
                lockedGroups: {'调查'},
              ),
          throwsA(isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('城中.声望'),
                contains('同时锁定「城中」'),
              ))));
      final draft = GameplaySystemDraft.merge(
        current: current,
        generated: generated,
        lockedGroups: {'调查', '城中'},
      );
      expect(draft.system.variableFor('城中.声望'), isNotNull);
    });

    test(
        'migrates compatible values, resets changed types and trims removed keys',
        () {
      final current = GameplaySystemParser.parse(jsonEncode(_design()));
      final generatedJson = _design();
      _variables(generatedJson)[0]['max'] = 80;
      _variables(generatedJson)[2]
        ..['type'] = 'boolean'
        ..['initialValue'] = false
        ..remove('min')
        ..remove('max');
      _variables(generatedJson)[3]['key'] = '城中.新态度';
      final draft = GameplaySystemDraft.preview(
        current: current,
        generated: GameplaySystemParser.parse(jsonEncode(generatedJson)),
      );
      final migrated = draft.migrateValues({
        '调查.进展': 90,
        '调查.戒备': 8,
        '城中.声望': 70,
        '城中.态度': '开放',
      });
      expect(migrated['调查.进展'], 80);
      expect(migrated['调查.戒备'], 8);
      expect(migrated['城中.声望'], false);
      expect(migrated, isNot(contains('城中.态度')));
      expect(migrated['城中.新态度'], '谨慎');
      expect(draft.migrationNotes.join(), contains('使用新初始值'));
    });

    test('retains prose rules when a locked group has no explicit bindings',
        () {
      final currentJson = _design();
      _rule(currentJson)
        ..remove('conditions')
        ..remove('effects');
      final current = GameplaySystemParser.parse(jsonEncode(currentJson));
      final generatedJson = _design()..['rules'] = <dynamic>[];
      final draft = GameplaySystemDraft.merge(
        current: current,
        generated: GameplaySystemParser.parse(jsonEncode(generatedJson)),
        lockedGroups: {'城中'},
      );
      expect(draft.system.rules, hasLength(1));
      expect(draft.migrationNotes.join(), contains('旧版文字规则'));
    });
  });
}

Map<String, dynamic> _design() => {
      'schemaVersion': 3,
      'title': '雾港暗潮',
      'summary': '在进展与戒备之间权衡。',
      'coreLoop': '公开调查推进较快，潜伏则可以降低戒备。',
      'variables': <Map<String, dynamic>>[
        _number('调查.进展', '调查进展', '调查'),
        _number('调查.戒备', '港口戒备', '调查'),
        _number('城中.声望', '城中声望', '城中'),
        {
          'key': '城中.态度',
          'label': '集市态度',
          'group': '城中',
          'type': 'choice',
          'visibility': 'public',
          'authority': 'ai',
          'initialValue': '谨慎',
          'options': ['谨慎', '开放'],
          'description': '市场整体氛围'
        },
      ],
      'rules': <Map<String, dynamic>>[
        {
          'id': 'port_watch',
          'title': '港口加派巡查',
          'when': '调查进展达到六成',
          'effect': '巡查加密，开放潜行路线',
          'visibility': 'public',
          'playerSummary': '港口加派巡查，潜行路线仍可通行。',
          'conditions': [
            {'path': '调查.进展', 'op': 'gte', 'value': 60}
          ],
          'effects': [
            {'path': '调查.戒备', 'op': 'inc', 'value': 10}
          ]
        },
      ],
    };

Map<String, dynamic> _number(String key, String label, String group) => {
      'key': key,
      'label': label,
      'group': group,
      'type': 'number',
      'visibility': 'public',
      'authority': 'ai',
      'initialValue': 0,
      'description': '行动可改变当前局势',
      'min': 0,
      'max': 100,
      'maxDelta': 8,
    };

List<Map<String, dynamic>> _variables(Map<String, dynamic> json) =>
    json['variables'] as List<Map<String, dynamic>>;

Map<String, dynamic> _rule(Map<String, dynamic> json) =>
    (json['rules'] as List<Map<String, dynamic>>).first;
