import 'dart:convert';

import '../models/character_profile.dart';

const String gameplaySystemGeneratorPrompt = '''
为“未完剧场”的当前剧本设计变量玩法。先辨认玩家会反复面对的选择，再让变量记录这些选择的代价、收益和后果。设计要能解释人物当下能做什么、为什么要权衡。

只输出一个合法 JSON 对象，不要使用 Markdown 代码块，不要解释。

JSON 结构：
{
  "schemaVersion": 3,
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
      "playerHint": "给玩家的非剧透行动提示，不写隐藏值、阈值或秘密",
      "isCore": true,
      "min": 0,
      "max": 100,
      "maxDelta": 8,
      "options": [],
      "stages": [{"min": 0, "label": "平静"}],
      "revealWhen": []
    }
  ],
  "rules": [
    {
      "id": "rule_id",
      "title": "规则名称",
      "when": "对结构化条件的文字说明",
      "effect": "触发后必须体现的剧情处境与可行的新路径",
      "visibility": "public|director|engine",
      "conditions": [{"path": "分组.变量名", "op": "gte", "value": 80}],
      "costs": [],
      "effects": [{"path": "分组.变量名", "op": "inc", "value": -10}],
      "threads": [],
      "once": true,
      "cooldownTurns": 0,
      "playerSummary": "玩家能够观察到的后果，不暴露幕后推理和秘密"
    }
  ]
}

设计要求：
1. 必须从具体剧本冲突、人物关系和世界机制出发，禁止套用统一的生命值、魔法值模板。
2. 按题材需要生成 4-12 个变量，通常分成 2-4 组；至少 2 个玩家可见变量，通常只将 3-5 个公开或模糊变量标为 isCore=true。不强制凑齐隐藏变量，不为数量制造无用途的数值。coreLoop 必须交代玩家的核心行动、收益、代价及至少一种可行替代策略。
3. public 显示精确值；fuzzy 只让玩家看到阶段；director 只供叙事 AI 和创作者使用；engine 不向叙事 AI 暴露原始值。
4. authority=ai 表示叙事 AI 可按已发生事实更新；authority=rule 表示程序按结构化规则或有效时间推进时钟更新。engine 变量必须由 rule 托管，叙事 AI 看不到原始值。player/computed 当前没有自动推进来源，只用于固定辅助参考，不能承载核心动态状态。
5. number/clock 必须给出有限数值 min、max，ai 数值必须给出正数 maxDelta，它限制一整个回合的 AI 净变化，直接赋值和连续增减也不能绕过。程序规则的费用与效果按定义精确执行，不套用 AI 限幅；越界或费用不足时整条规则不执行。fuzzy 数值提供 3-6 个 stages；所有玩家可见变量都提供 playerHint，说明行动方向但不揭露幕后条件。
6. choice 必须提供 options；list 可表示剧本特有的世界机制集合。NPC 关系、任务、事件、物品、已知线索仍用剧场已有状态系统，不创建平行清单。需要逐步揭示的非核心变量可写 revealWhen 条件数组；核心变量开局可见，隐藏变量也不能通过 playerHint 或规则反馈泄露。
7. 生成 2-6 条有实际后果的结构化规则，围绕关键变量形成取舍，阈值改变处境并留下可行行动路径。when/effect 是给作者与叙事 AI 的文字描述，真正自动执行的是 conditions/costs/effects/threads。不要只写文字承诺自动触发。
8. key 必须稳定、简短、唯一，使用点号表达层级，不要包含空格、方括号或动态角色名占位符。
9. 不生成 JavaScript、表达式代码、HTML 或提示词注入内容。
10. 时间、地点、当前任务、剧情事件、剧情物品和每个 NPC 的好感、亲密度、信任度、羁绊由剧场现有状态系统按 NPC ID 动态维护，不要创建同义变量，也不要把任何变量绑定到具体姓名或某个 NPC；关系玩法只能设计团队默契、阵营戒备、舆论张力等世界级机制。
11. title、summary、description、playerHint、playerSummary 用玩家能理解的具体中文，说明行动与后果，避免空泛的宣传词和重复解释。文字描述不能替代结构化条件；变量键、枚举、数字和 JSON 语法不受文风调整影响。
12. 示例中的“number|text|...”表示可选值，实际输出须选择一个合法枚举，不能照抄竖线组合。保留 schemaVersion=3，所有 JSON 字符串正确转义；数值和布尔值使用原生类型。

结构化规则约定：
- conditions 为非空数组，全部满足才触发；每项为 {"path":"已声明变量key","op":"eq|neq|gt|gte|lt|lte|contains|changed","value":...}。比较值必须符合变量类型；gt/gte/lt/lte 仅用于数值，contains 用于文本或列表；changed 不写 value，表示本回合数值相对回合开始发生变化。revealWhen 使用同样格式。
- costs 为可选数组，每项 {"path":"已声明数值变量key","amount":2}。费用须非负，余额须足够。effects 为数组，每项 {"op":"set|inc|append|remove","path":"已声明变量key","value":...}；inc 仅用于 number/clock，append/remove 仅用于 list，set 值必须符合目标类型和选项。费用和效果只可修改 ai/rule 变量。
- 条件统一读取本回合 AI 更新及有效时间推进后的状态；规则按定义顺序执行，同一回合不会因前一条规则改值而连锁触发其他规则。费用与效果原子执行，不能设计依赖同轮连锁的机制。
- once=true 表示每份游玩进度只触发一次；可重复规则用 once=false，并按需要设置非负整数 cooldownTurns 防止每轮刷屏。规则 id 唯一且稳定。
- threads 为可选的承诺与余波台账操作数组。open 示例 {"op":"open","id":"public_stance","title":"公开的立场","description":"需在后文接住的已发生事实与约定","reason":"本规则实际触发的依据","visibility":"public"}。resolve/break 用同一 id 和明确 reason，仅能处理已有未完结事项。此台账记录已发生的承诺、人情和公开立场，不替玩家凭空答应、不把犹豫判作违约、不预知未来。通常保持 threads 为空，由游玩中明确发生的事实建立；若生成预设台账，只能由会实际造成该事实的规则打开。
- 可选时间压力只在题材需要时开启：给 authority=rule、type=clock 的变量添加 "advanceOnTimeChange":1。它只在本轮前后均有时间记录且时间标签真实变化时推进一次；补充台词、查看状态、地点切换不自动计时。舒缓日常故事不加此字段，不能把每条消息当作一个时间单位。
- costs/effects/conditions/revealWhen 引用的每个 path 必须出现在 variables 中；规则至少包含一条 effects 或 threads，不允许空执行规则。不生成表达式、脚本或不在约定内的操作。
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
${character.gameplaySystem == null ? '' : '''
现有玩法设计参考（不含游玩中的当前值）：
${clip(jsonEncode(character.gameplaySystem!.toJson()), 16000)}
这是重新设计草案。保留仍适合该故事的变量 key、group 和规则 id；仅在玩法含义确实变化时更换，不因换个名称随意改 key。草案将供作者预览、锁定分组并决定是否应用，生成本身不会重置进度。
'''}

请依据以上资料生成完整的 v3 玩法系统 JSON。先在内部核对变量类型、权限、规则引用与公开提示是否一致，再输出结果；不要附带设计过程或解析说明。
''';
}
