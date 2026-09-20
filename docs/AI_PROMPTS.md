# 内部 AI 提示词维护

本清单按独立功能任务计数，共 50 套。system/user 配对、流式和非流式调用、同任务重试不重复计算。角色设定、世界书、状态快照等注入内容也不另算一套。连接测试只发送 `ping`，不在内容生成清单内。

## 写法与协议

剧情与对白采用 human-writing 的人物、行动、因果和视角原则。角色按自己的身份、关系和当前目的说话，环境细节跟随人物注意力，每个场景增加行动、信息或关系变化。避免重复解释情绪、无根据的亲密升级、固定口癖和结尾强行总结。

这些写法只影响自然语言内容。JSON 键名、字段类型、枚举、标签、顺序、变量权限和数值范围属于机器协议。修改描述、对白等字符串时，仍须保持 JSON 转义正确。不能把散文标点要求应用到 JSON、HTML 或状态字段。

不同任务的创作权限需要明确区分。

- 主剧情可在世界规则和当前状态内创造事件，关键选择留给玩家。
- 日记、梦境、番外等可创造符合人物的片段，其内容不自动成为主线事实。
- 提要、人物提取、长期记忆只整理已有事实，保留未完成事项和不确定性。
- 状态裁判依据已发生的行为和结算结果更新状态，不能为了戏剧效果更改数值。
- 格式修复只修结构和表达错误，不推进剧情、不增加奖励，也不重复结算变量。

普通主剧情继续保留长篇要求，教程保持短回合，同人文保留长篇目标。轻量道具和独立小剧场根据任务给出适当篇幅，不再统一要求至少 2000 字。

## 50 套任务清单

下表中的方法名用于定位代码，避免文案调整后行号失效。

| 编号 | 任务 | 输出形式 | 主要位置 |
| --- | --- | --- | --- |
| 1 | 世界日历 | JSON | `AppStateController.generateWorldCalendar` |
| 2 | 神秘商店 | JSON | `generateMysteryShopOffers` |
| 3 | 黑市 | JSON | `generateBlackMarketOffers` |
| 4 | 道具鉴定 | JSON | `identifyStoryInventoryItem` |
| 5 | 道具合成 | JSON | `synthesizeStoryInventoryItems` |
| 6 | NPC 收礼反应 | JSON | `sendNpcGift` / `_buildNpcGiftPrompt` |
| 7 | NPC 前尘迁移清单 | JSON | `_npcMigrationManifestSystemPrompt` |
| 8 | NPC 新世界资料包 | JSON | `_npcMigrationBundleSystemPrompt` |
| 9 | NPC 告别场景 | JSON，含叙事与面板字符串 | `buildNpcFarewellDraft` |
| 10 | NPC 迁移档案重修 | 按所选部分返回 JSON 或正文 | `reviseNpcMigrationRecord` |
| 11 | 补全已有 NPC 角色卡 | JSON | `buildNpcRoleCardDraft` |
| 12 | 从灵感创建 NPC 角色卡 | JSON | `buildNpcRoleCardDraftFromInspiration` |
| 13 | NPC 私聊 | JSON | `requestNpcReply` |
| 14 | NPC 心声 | 纯文字 | `generateNpcInnerVoice` |
| 15 | 固定地图蓝图 | JSON | `generateInitialMap` |
| 16 | 规则地图回合叙事 | 正文及状态协议块 | `_runRulesMapNarrativeTask` |
| 17 | 旧地图回合叙事 | 正文及状态协议块 | `_runMapTask`，旧存档兼容 |
| 18 | 同人文及截断续写 | 纯文字 | `generateFanfic` / `_buildFanficContinuationPrompt` |
| 19 | 回复面板美化 | HTML | `beautifyMessageAsPanel` |
| 20 | 手动回复格式修复 | 保留原回复模式 | `repairMessageFormat` |
| 21 | 地图协议修复 | 正文及状态协议块 | `_mapRepairSystemPrompt` |
| 22 | 提取 NPC 档案 | JSON | `_runNpcExtractionWhenIdle` |
| 23 | NPC 主动来信 | JSON | `_npcLetterSystemPrompt` |
| 24 | NPC 迁移 JSON 修复 | JSON | `_npcMigrationJsonRepairSystemPrompt` |
| 25 | 上集提要 | 文字 | `_utilitySpec('recap')` |
| 26 | 人物关系图 | HTML | `_utilitySpec('relationship')` |
| 27 | 剧情存档封面 | HTML | `_utilitySpec('cover')` |
| 28 | 伏笔本 | Markdown / HTML | `_utilitySpec('foreshadow')` |
| 29 | 分支预演 | 文字 | `_utilitySpec('branch_preview')` |
| 30 | NPC 日记 | Markdown / HTML | `_utilitySpec('npc_diary')` |
| 31 | 世界动态 | 文字 / HTML | `_utilitySpec('world_feed')`，另有两个共用别名 |
| 32 | 灵感骰子 | 六个行动灵感 | `_utilitySpec('inspiration_dice')` |
| 33 | 梦境碎片 | 叙事 | `_utilitySpec('dream_fragment')` |
| 34 | 吐槽小剧场 | 叙事 | `_utilitySpec('comedy_stage')` |
| 35 | NPC 八卦小报 | 文字 / HTML | `_utilitySpec('npc_gossip')` |
| 36 | 路人视角 | 叙事 | `_utilitySpec('passerby_camera')` |
| 37 | 今日电台 | Markdown / HTML | `_utilitySpec('mood_radio')` |
| 38 | 离谱预言 | 叙事 | `_utilitySpec('prophecy_trash')` |
| 39 | 变小孩喷雾 | 纯文字 | `_utilitySpec('child_spray')` |
| 40 | 兽耳魔药 | 纯文字 | `_utilitySpec('beast_ear_potion')` |
| 41 | 摸一摸 | 纯文字 | `_utilitySpec('touch')` |
| 42 | 真心话棒棒糖 | 纯文字 | `_utilitySpec('truth_lollipop')` |
| 43 | 主剧场回复 | 按模式组合正文和协议块 | `LlmApiClient` 的主回复构建流程 |
| 44 | 长期记忆摘要 | 事实要点 | `LlmApiClient.summarizeConversation` |
| 45 | 模拟器 / 世界设定生成 | JSON | `data/simulator_prompt_generator.dart` |
| 46 | 变量玩法设计生成 | JSON | `data/gameplay_system_prompt.dart` |
| 47 | 回合状态裁判 | JSON | `TurnStateAdjudicator` |
| 48 | 模拟器 JSON 补全 | JSON | `LlmApiClient._buildSimulatorJsonContinuationPrompt` |
| 49 | 变量玩法 JSON 修复 | JSON | `LlmApiClient._repairGameplaySystemJson` |
| 50 | 主回复协议自动修复 | 按模式组合正文和协议块 | `LlmApiClient.repairChatReplyFormat` |

其中 21 套要求完整 JSON，1 套按分支选择 JSON 或正文，5 套回复包含 JSON 协议块，23 套输出文字或 HTML。第 4 项在本次修改前被互相矛盾的提前返回阻断，修复后恢复首次鉴定。

## 共用规则与模式

- `models/character_profile.dart` 管理普通、教程、地图和群聊的运行协议。
- `data/preset_characters.dart` 管理内置教程与模拟器规则；产品能力以 `tutorial_product_knowledge.dart` 的事实库为准。
- `services/gameplay_prompt_context.dart` 注入变量可见性、允许写入的路径、本地结算与承诺约束。
- `models/story_systems.dart` 把临时导演偏好转换为指令，偏好不能替玩家作决定或改写已发生的事实。

普通模式按开关输出 A–F 六个选项；教程使用 A–C 三个选项，HTML 可选。地图使用 `[MAP_STATE]` 的地点和行动，不输出 `[CHOICES]`，HTML 可选。群聊使用 `[GROUP_CHAT]`，不输出 HTML、地图块或行动选项。关闭选项不能关闭状态回传。

`[GAME_STATE]` 使用状态字段文本；`[GROUP_CHAT]`、`[MAP_STATE]`、`[THEATER_PATCH]` 内为 JSON。启用变量玩法时，`[THEATER_PATCH]` 位于 `[GAME_STATE]` 后。导演信息可以参与后台判断，不能直接泄漏到玩家可见的正文、HTML、选项或公开字段；engine 私有变量不会注入模型。

## 验证边界

应用兼容用户配置的 Chat Completions 服务，没有对所有服务强制启用 `response_format` 或 `json_schema`。结构可靠性依赖明确的输出要求、解析校验与有限修复。

模拟器成功结果必须包含非空字符串 `name`、`description`、`opening`、`systemPrompt`。缺失或类型错误会进入一次补全，补全后仍不完整应报告失败；完整的旧标签格式继续兼容。玩法修复需带上完整 schema 与原始错误，修复后仍经过正式解析器。

测试应检查请求组合、解析行为、有限重试、模式差异、变量权限与失败回滚。不要把测试写成大量文案逐字快照，也不要把模拟 HTTP 测试描述为真实模型文风验收。文风效果需要使用相同模型和相同剧情样本对比。
