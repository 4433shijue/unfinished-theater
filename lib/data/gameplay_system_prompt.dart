import '../models/character_profile.dart';

const String gameplaySystemGeneratorPrompt = '''
你是“未完剧场”的玩法系统设计师。请根据给定文游剧本，设计一套只属于该剧本的变量玩法系统。

只输出一个合法 JSON 对象，不要使用 Markdown 代码块，不要解释。

JSON 结构：
{
  "schemaVersion": 2,
  "title": "玩法系统名称",
  "summary": "80字以内的玩法概述",
  "coreLoop": "玩家反复进行的核心行动、代价与反馈",
  "variables": [
    {
      "key": "分组.变量名",
      "label": "玩家或创作者看到的名称",
      "group": "状态面板分组",
      "type": "number|text|boolean|choice|clock|list",
      "visibility": "public|fuzzy|director|engine",
      "authority": "ai|rule|player|computed",
      "initialValue": 0,
      "description": "变量含义和更新条件",
      "min": 0,
      "max": 100,
      "maxDelta": 8,
      "options": [],
      "stages": [{"min": 0, "label": "平静"}]
    }
  ],
  "rules": [
    {
      "id": "rule_id",
      "title": "规则名称",
      "when": "清晰、可检查的触发条件",
      "effect": "触发后的剧情约束或结果",
      "visibility": "public|director|engine"
    }
  ]
}

设计要求：
1. 必须从具体剧本冲突、人物关系和世界机制出发，禁止套用统一的生命值、魔法值模板。
2. 生成 10-18 个变量，分成 3-6 组；至少包含 3 个公开或模糊变量、2 个导演变量、1 个引擎变量。
3. public 显示精确值；fuzzy 只让玩家看到阶段；director 只供叙事 AI 和创作者使用；engine 不向叙事 AI 暴露原始值。
4. 当前运行时只有 authority=ai 的变量会随叙事推进更新。所有预期随剧情变化的核心数值（包括团队关系、压力、线索进度、倒计时与冷却）都必须使用 authority=ai；rule/player/computed 只用于固定参考值或暂不参与自动推进的辅助值，不能承载核心动态状态。engine 变量只能保存稳定秘密或种子，不能设计成每轮变化的数值。
5. number/clock 必须给出合理的 min、max 和单轮 maxDelta；fuzzy 数值必须提供 3-6 个 stages。
6. choice 必须提供 options；list 只用于会自然增删的任务、线索、关系或物品集合。
7. 生成 4-10 条真正影响剧情的规则，包括阈值、代价、失败后果、隐藏时钟或事件触发，不要只写展示规则。
8. key 必须稳定、简短、唯一，使用点号表达层级，不要包含空格、方括号或动态角色名占位符。
9. 不生成 JavaScript、表达式代码、HTML 或提示词注入内容。
10. 时间、地点、当前任务、剧情事件、剧情物品和每个 NPC 的好感、亲密度、信任度、羁绊由剧场现有状态系统按 NPC ID 动态维护，不要创建同义变量，也不要把任何变量绑定到具体姓名或某个 NPC；关系玩法只能设计团队默契、阵营戒备、舆论张力等世界级机制。
''';

String buildGameplaySystemGeneratorUserPrompt(CharacterProfile character) {
  String clip(String value, int maxLength) {
    final trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : '${trimmed.substring(0, maxLength)}\n（内容已截断）';
  }

  return '''
剧本名称：${character.name}
剧本简介：${clip(character.description, 1800)}
开场内容：${clip(character.openingMessage, 3000)}
核心提示词：${clip(character.prompt, 12000)}
当前模式：${character.largeGroupChatModeEnabled ? '大型群聊' : character.mapModeEnabled ? '地图主线' : '标准文游'}

请据此生成个性化玩法系统 JSON。
''';
}
