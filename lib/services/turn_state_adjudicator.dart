import 'dart:convert';

import '../models/character_profile.dart';
import '../models/game_state.dart';
import '../models/npc_profile.dart';
import 'gameplay_patch_engine.dart';
import 'reply_protocol_validator.dart';

class TurnStateAdjudication {
  const TurnStateAdjudication({required this.protocolContent});

  final String protocolContent;
}

class TurnStateAdjudicator {
  const TurnStateAdjudicator._();

  static String buildSystemPrompt({required bool gameplayPatchRequired}) {
    return '''
你是文字游戏的“回合状态裁判员”，不是剧情作者。
你只能依据玩家行动、上一轮已保存状态和本轮剧情正文进行结算，不得新增正文里没有发生的事实。

只输出一个完整 JSON 对象，不要 Markdown 围栏、解释或额外文字：
{
  "gameState": {
    "时间": "",
    "地点": "",
    "状态": "",
    "当前任务": "",
    "人物数据": [],
    "剧情物品栏": [],
    "关系网": [],
    "剧情记录": [],
    "NPC变化": [],
    "NPC更新": [
      {
        "npcId": "已建档 NPC 的稳定 ID；新 NPC 留空",
        "name": "NPC 名字",
        "description": "只在新建或确有变化时填写",
        "impression": "本轮形成的自然语言印象",
        "affinityDelta": 0,
        "lifecycle": "active/away/missing/dead/archived；无转换时留空",
        "lifecycleReason": "生命周期转换的正文事实；无转换时留空",
        "proactiveMessage": "NPC 本轮真正发出的私聊原话；没有就留空"
      }
    ]
  },
  "gameplayPatch": {"ops": []}
}

裁判规则：
1. gameState 至少保留时间、地点、状态、当前任务等核心状态；没变的可沿用上轮。
2. NPC 好感的唯一事实源是 NPC 档案。已建档 NPC 只写 npcId 和 affinityDelta，单轮范围 -12..12；不要输出绝对好感度。
3. dead、missing、archived NPC 不能增减好感，不能发主动消息。只有正文明确写出复活、恢复联络或重新启用时，才能改回 active/away，并必须填写 lifecycleReason。
4. proactiveMessage 只能写 NPC 真正会发出的聊天原话；“明日将联系”“等待回复”等状态不是消息。
5. 新 NPC 可以动态加入 NPC更新，不需要改动玩法变量表。
6. 玩法变量不得复制任何 NPC 的好感、亲密度或信任度。
${gameplayPatchRequired ? '7. gameplayPatch 必须存在，只修改已声明的玩法变量；确实无变化时 ops 为空。' : '7. 本剧场未启用玩法变量，gameplayPatch 固定输出 {"ops":[]} 且不会被应用。'}
''';
  }

  static String buildUserPrompt({
    required CharacterProfile character,
    required GameStateSnapshot previousState,
    required List<NpcProfile> npcProfiles,
    required String latestUserMessage,
    required String narrativeReply,
  }) {
    final state = <String, dynamic>{
      'time': previousState.timeLabel,
      'location': previousState.location,
      'status': previousState.status,
      'mainTask': previousState.mainTask,
      'profileDetails': previousState.profileDetails,
      'storyInventory':
          previousState.storyInventory.map((item) => item.toJson()).toList(),
      'relationshipNotes': previousState.relationshipNotes,
      'plotFlags': previousState.plotFlags,
      'metrics': previousState.metrics,
    };
    final npcs = npcProfiles
        .map(
          (npc) => <String, dynamic>{
            'npcId': npc.id,
            'name': npc.name,
            'affinity': npc.affinity,
            'lifecycle': npc.lifecycle.name,
            'impression': npc.impression,
            'location': npc.runtimeState.location,
            'currentGoal': npc.runtimeState.currentGoal,
          },
        )
        .toList(growable: false);
    final gameplay = character.gameplaySystem;
    final variables = gameplay == null
        ? const <Map<String, dynamic>>[]
        : gameplay.variables
            .map(
              (variable) => <String, dynamic>{
                'path': variable.key,
                'label': variable.label,
                'authority': variable.authority.name,
                'currentValue': previousState.customVariables[variable.key],
                'min': variable.min,
                'max': variable.max,
                'maxDelta': variable.maxDelta,
              },
            )
            .toList(growable: false);

    return '''
【剧场】${character.name}
【玩家本轮行动】
${latestUserMessage.trim().isEmpty ? '未提供' : latestUserMessage.trim()}

【上一轮已保存状态】
${jsonEncode(state)}

【NPC 唯一事实源】
${jsonEncode(npcs)}

【已声明玩法变量】
${jsonEncode(variables)}

【本轮剧情正文与展示内容】
$narrativeReply
''';
  }

  static TurnStateAdjudication? parse(
    String raw, {
    required bool gameplayPatchRequired,
  }) {
    final decoded = _decodeObject(raw);
    if (decoded == null) {
      return null;
    }
    final rawState = decoded['gameState'] ?? decoded['state'];
    if (rawState is! Map) {
      return null;
    }
    final stateBlock = '[GAME_STATE]\n'
        '${jsonEncode(Map<String, dynamic>.from(rawState))}\n'
        '[/GAME_STATE]';
    if (!ReplyProtocolReconciler.hasUsableGameState(stateBlock)) {
      return null;
    }

    final blocks = <String>[stateBlock];
    if (gameplayPatchRequired) {
      final rawPatch = decoded['gameplayPatch'] ?? decoded['theaterPatch'];
      if (rawPatch is! Map) {
        return null;
      }
      final patchBlock = '[THEATER_PATCH]\n'
          '${jsonEncode(Map<String, dynamic>.from(rawPatch))}\n'
          '[/THEATER_PATCH]';
      if (!GameplayPatchParser.parseResult(patchBlock).isValid) {
        return null;
      }
      blocks.add(patchBlock);
    }
    return TurnStateAdjudication(protocolContent: blocks.join('\n\n'));
  }

  static Map<String, dynamic>? _decodeObject(String raw) {
    var normalized = raw.trim();
    normalized = normalized
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    final start = normalized.indexOf('{');
    final end = normalized.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalized.substring(start, end + 1));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
