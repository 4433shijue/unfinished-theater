import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/game_state_parser.dart';
import 'package:ai_roleplay_chat/services/gameplay_patch_engine.dart';
import 'package:ai_roleplay_chat/services/gameplay_system_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gameplay system generation', () {
    test('parses a personalized schema and normalizes engine authority', () {
      final system = GameplaySystemParser.parse('''
这里是生成结果：
```json
${_systemJson()}
```
''');

      expect(system.title, '雾港追凶');
      expect(system.variables, hasLength(5));
      expect(system.playerFacingVariableCount, 3);
      expect(system.backstageVariableCount, 2);
      expect(
        system.variableFor('幕后.真相锁')!.authority,
        GameplayVariableAuthority.rule,
      );
    });

    test('survives character profile serialization', () {
      final system = GameplaySystemParser.parse(_systemJson());
      final profile = CharacterProfile(
        id: 'character-1',
        name: '雾港追凶',
        createdAt: DateTime.utc(2026, 8, 7),
        prompt: '调查港口失踪案。',
        gameplaySystem: system,
        modelParams: ModelParams.defaults(),
      );

      final restored = CharacterProfile.fromJson(profile.toJson());

      expect(restored.gameplaySystem?.title, system.title);
      expect(restored.gameplaySystem?.variables, hasLength(5));
      expect(restored.fullSystemPrompt, contains('[THEATER_PATCH]'));
    });

    test('migrates legacy non-engine rule variables to runtime authority', () {
      final legacyJson = _systemJson().replaceFirst(
        '"authority": "ai"',
        '"authority": "rule"',
      );

      final system = GameplaySystemParser.parse(legacyJson);

      expect(system.schemaVersion, 2);
      expect(
        system.variableFor('关系.搭档信任')!.authority,
        GameplayVariableAuthority.ai,
      );
      expect(
        system.variableFor('幕后.真相锁')!.authority,
        GameplayVariableAuthority.rule,
      );
    });

    test('drops variables that mirror NPC affinity', () {
      final system = GameplaySystemParser.parse(
        _systemJson()
            .replaceFirst('"key": "关系.搭档信任"', '"key": "NPC.林夏好感"')
            .replaceFirst('"label": "搭档信任"', '"label": "林夏好感度"'),
      );

      expect(system.variableFor('NPC.林夏好感'), isNull);
      expect(system.variables, hasLength(4));
    });
  });

  group('gameplay patch engine', () {
    test('applies allowed operations and enforces limits and ownership', () {
      final system = GameplaySystemParser.parse(_systemJson());
      final current = system.initialValues();
      final result = GameplayPatchEngine.applyAiPatch(
        system: system,
        currentValues: current,
        operations: const <GameplayPatchOperation>[
          GameplayPatchOperation(
            type: GameplayPatchOperationType.increment,
            path: '关系.搭档信任',
            value: 50,
            reason: '共同承担风险',
          ),
          GameplayPatchOperation(
            type: GameplayPatchOperationType.append,
            path: '调查.关键线索',
            value: '染盐的船票',
            reason: '仓库搜索所得',
          ),
          GameplayPatchOperation(
            type: GameplayPatchOperationType.set,
            path: '幕后.真相锁',
            value: 2,
            reason: '模型试图修改引擎变量',
          ),
          GameplayPatchOperation(
            type: GameplayPatchOperationType.set,
            path: '不存在.变量',
            value: true,
            reason: '越权新增',
          ),
        ],
      );

      expect(result.values['关系.搭档信任'], 28);
      expect(result.values['调查.关键线索'], contains('染盐的船票'));
      expect(result.values['幕后.真相锁'], 1);
      expect(result.changes, hasLength(2));
      expect(result.rejections, hasLength(2));
    });

    test('parses patch blocks and keeps them out of visible story text', () {
      const content = '''
港口的雾里传来汽笛声。
[THEATER_PATCH]
{"ops":[{"op":"inc","path":"关系.搭档信任","value":3,"reason":"交出证据"}]}
[/THEATER_PATCH]
''';

      final operations = GameplayPatchParser.parse(content);
      final visible = GameStateParser.stripStateBlocks(content);

      expect(operations, hasLength(1));
      expect(operations.single.path, '关系.搭档信任');
      expect(visible, '港口的雾里传来汽笛声。');
    });

    test('distinguishes missing, malformed, and valid empty patches', () {
      final missing = GameplayPatchParser.parseResult('港口仍然安静。');
      final unclosed = GameplayPatchParser.parseResult('''
[THEATER_PATCH]
{"ops":[]}
''');
      final invalid = GameplayPatchParser.parseResult('''
[THEATER_PATCH]
{"ops":
[/THEATER_PATCH]
''');
      final empty = GameplayPatchParser.parseResult('''
[THEATER_PATCH]
{"ops":[]}
[/THEATER_PATCH]
''');

      expect(missing.found, isFalse);
      expect(missing.error, isNull);
      expect(unclosed.found, isTrue);
      expect(unclosed.error, contains('结束标签'));
      expect(invalid.error, contains('合法 JSON'));
      expect(empty.isValid, isTrue);
      expect(empty.operations, isEmpty);
    });

    test('custom values remain part of every game state snapshot', () {
      final state = GameStateSnapshot.empty('character-1').copyWith(
        customVariables: <String, dynamic>{
          '关系.搭档信任': 28,
          '调查.关键线索': <String>['旧船票'],
        },
        customVariablesRevision: 3,
        gameplayVariableChanges: const <String>['搭档信任：20 → 28'],
        gameplayPlayerVariableChanges: const <String>['搭档信任：20 → 28'],
        gameplayVariableWarnings: const <String>['幕后.真相锁：该变量由规则控制'],
      );

      final restored = GameStateSnapshot.fromJson(state.toJson());

      expect(restored.customVariables['关系.搭档信任'], 28);
      expect(restored.customVariablesRevision, 3);
      expect(restored.gameplayVariableChanges, hasLength(1));
      expect(restored.gameplayPlayerVariableChanges, hasLength(1));
      expect(restored.gameplayVariableWarnings.single, contains('规则控制'));
      expect(restored.hasNarrativeState, isFalse);
      expect(restored.isEmpty, isFalse);
    });

    test('removes only legacy metrics claimed by gameplay variables', () {
      final system = GameplaySystemParser.parse(
        _systemJson()
            .replaceFirst('"key": "关系.搭档信任"', '"key": "状态.压力"')
            .replaceFirst('"label": "搭档信任"', '"label": "压力"'),
      );

      final metrics = GameplayPatchEngine.removeClaimedLegacyMetrics(
        system,
        const <String, int>{
          '压力': 80,
          '金钱': 120,
          '声望': 15,
        },
      );

      expect(metrics, isNot(contains('压力')));
      expect(metrics['金钱'], 120);
      expect(metrics['声望'], 15);
    });
  });
}

String _systemJson() => '''
{
  "schemaVersion": 1,
  "title": "雾港追凶",
  "summary": "在封港前拼合证据并守住搭档关系。",
  "coreLoop": "调查地点、交换情报、承受警戒上升并锁定真相。",
  "variables": [
    {
      "key": "关系.搭档信任",
      "label": "搭档信任",
      "group": "关系",
      "type": "number",
      "visibility": "public",
      "authority": "ai",
      "initialValue": 20,
      "description": "共同承担风险或隐瞒事实时变化",
      "min": 0,
      "max": 100,
      "maxDelta": 8
    },
    {
      "key": "调查.港口警戒",
      "label": "港口警戒",
      "group": "调查",
      "type": "clock",
      "visibility": "fuzzy",
      "authority": "ai",
      "initialValue": 1,
      "description": "公开行动和失败会推动警戒",
      "min": 0,
      "max": 6,
      "maxDelta": 1,
      "stages": [
        {"min": 0, "label": "平静"},
        {"min": 2, "label": "有所察觉"},
        {"min": 5, "label": "全面搜捕"}
      ]
    },
    {
      "key": "调查.关键线索",
      "label": "关键线索",
      "group": "调查",
      "type": "list",
      "visibility": "public",
      "authority": "ai",
      "initialValue": [],
      "description": "已经确认的关键证据"
    },
    {
      "key": "幕后.凶手戒心",
      "label": "凶手戒心",
      "group": "幕后",
      "type": "number",
      "visibility": "director",
      "authority": "ai",
      "initialValue": 10,
      "description": "凶手对调查方向的察觉程度",
      "min": 0,
      "max": 100,
      "maxDelta": 10
    },
    {
      "key": "幕后.真相锁",
      "label": "真相锁",
      "group": "幕后",
      "type": "number",
      "visibility": "engine",
      "authority": "ai",
      "initialValue": 1,
      "description": "引擎持有的真实结局编号",
      "min": 1,
      "max": 4
    }
  ],
  "rules": [
    {
      "id": "port_lockdown",
      "title": "封港",
      "when": "调查.港口警戒达到6",
      "effect": "关闭普通离港路线并触发搜捕",
      "visibility": "director"
    }
  ]
}
''';
