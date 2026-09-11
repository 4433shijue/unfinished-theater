import '../models/simulator_prompt_request.dart';

const String simulatorPromptGeneratorSystemPrompt = '''
你在为一部文字游戏搭设定：用户给灵感，你交一份能让另一个 AI 长期演下去的规则书。
你现在不是扮演角色，也不是直接开局。

只输出一个 JSON 对象，不要 Markdown 代码围栏，不要解释：
{
  "name": "模拟器名称",
  "description": "一句话简介，40-80字",
  "opening": "开场白正文",
  "systemPrompt": "完整系统提示词正文"
}

写的时候记住：
- 开场白是玩家踏进这个世界时看到的第一段话——交代处境、氛围和第一步该做什么，别写成使用说明。可以用 {user} 当玩家名字的占位符。
- systemPrompt 要像一本能玩几个月的规则书：总设定、玩家身份、NPC 与关系、核心玩法与成长、状态与资源、回合怎么推进、每轮看哪些状态、文风、第一回合、重开。不用照抄这份清单，但玩起来要立得住。
- 状态系统别用通用模板凑数：时间、地点、任务、资源、关系、物品、声望、压力、好感、线索、阵营……按题材自己挑。NPC 好感度数值和 NPC 对玩家的印象要分开记。
- 别替玩家做决定。第一回合先让玩家完成开局选择，选之前剧情不往前走。
- 题材现实就守现实逻辑，架空就自洽，别前后打架。
- 世界边界不要写死在规则书里——那是玩家世界书的事。用户额外限制里的题材、文风、世界观补充，自然吸收进来。
- 文风跟着题材走，别写成通用模板。
''';

String buildSimulatorPromptGeneratorUserPrompt(
  SimulatorPromptGenerationRequest request,
) {
  final description = request.shortDescription.trim();
  final styleHint = request.styleHint.trim();
  final extraConstraints = request.extraConstraints.trim();
  final roleName = request.roleName.trim();
  final uploadedDocumentText = request.uploadedDocumentText.trim();
  final worldStageMode =
      request.mode == SimulatorPromptGenerationMode.worldStage;
  final modeInstruction = worldStageMode
      ? '''
【本次生成模式：只生成世界设定】
用户要的是“设定”，不是文游模拟器模板，也不是直接开局的剧情壳子。
请把重点放在这个世界为什么成立、如何运转、哪些规则不可违背、人物会被哪些制度/文化/资源/禁忌塑造。

系统提示词应以设定集为核心，包含：
1. 世界基底：时代、地理、社会结构、技术/超自然层级、日常生活质感。
2. 核心规则：力量、资源、身份、代价、禁忌、法律或潜规则如何运行。
3. 势力与群体：主要组织、阶层、阵营、民间网络、冲突利益。
4. 文化与价值观：礼仪、称呼、信仰、审美、流行传闻、普通人的生存逻辑。
5. 长期矛盾：公开冲突、暗线问题、历史遗留、即将爆发的压力。
6. 可游玩接口：玩家角色和外部注入的绑定 NPC 可以怎样自然进入世界，但不要替他们指定固定身份、固定恋爱对象或固定结局。
7. 状态维度：只列出需要追踪的世界状态，如时间、地点、阵营态度、资源、线索、风险、关系变化、事件后果。

NPC 规则只写成外部注入适配：绑定 NPC 会作为“另一个主角/同行者/重要角色”自主行动、表达意见、推动支线，但不得替玩家做决定。
开场白要像“进入一份设定后的第一幕邀请”，简短交代世界处境，并询问玩家角色与绑定 NPC 如何进入；不要写成“欢迎使用某某模拟器”的功能说明。
避免以下内容：玩法宣传、功能介绍、模板化“你将扮演”、把规则写成菜单说明、把某个新 NPC 写死为默认搭档。
'''
      : '''
【本次生成模式：完整文游模拟器】
按传统方式生成完整、可直接游玩的文游模拟器提示词，可以包含该世界自带的 NPC、关系网和长期主线。
如果运行时注入了绑定 NPC 角色卡，也必须让绑定 NPC 自主行动，但不能替玩家做决定。
''';

  return '''
请根据以下信息，生成一份"可直接给 AI 角色使用的完整系统提示词"。

【模拟器灵感】
${request.simulatorIdea.trim()}

【角色名称】
${roleName.isEmpty ? '用户没有填写名称，请根据灵感和文档内容自动生成一个正式、好记、贴合题材的模拟器名称。' : roleName}

【用户上传文档内容】
${uploadedDocumentText.isEmpty ? '无。' : uploadedDocumentText}

【一句话简介】
${description.isEmpty ? '请根据题材自动生成一句简洁、有记忆点的小简介。' : description}

【风格补充】
${styleHint.isEmpty ? '无额外补充，请根据题材自然决定叙事风格。' : styleHint}

【额外限制】
${extraConstraints.isEmpty ? '无额外限制，请保持题材统一、规则完整。' : extraConstraints}

$modeInstruction

生成要求：
1. 这是一个文字游戏模拟器的角色提示词，不是直接开始扮演。
2. 输出必须是完整 JSON，键名固定为 name / description / opening / systemPrompt；systemPrompt 不要重复 name、description 或 opening 的内容结构，只写运行规则本身。
3. 第一回合规则要说明：玩家未做初始选择前，不得正式推进剧情，只能展示开局引导和待确认信息。
4. 开场白要适合第一次打开角色时直接展示给用户，不要太长，重点是让用户知道这个模拟器怎么玩、第一步要做什么。
5. systemPrompt 里要设计长期游玩所需的内容维度，例如时间、地点、当前任务、角色状态、事件卡、NPC 好感度、NPC 印象、剧情物品栏、背包或资源。
6. 提示词要适合长期游玩，规则清楚，题材统一。
7. 如果用户上传了文档，必须把文档里的角色设定、世界观、关系、规则、文风和边界作为主要基础来整理；不要照抄成散文堆砌，要改写成可长期游玩的模拟器提示词。
8. 不要把内容边界写死进系统提示词里，内容边界由用户的世界书功能管理；如果用户在额外限制中写了题材规则、文风偏好或世界观补充，可以自然吸收进去。
9. 如果本次是“只生成世界观”，请优先输出设定集式提示词：少写玩法壳，多写世界运行逻辑、规则、势力、文化、矛盾和可进入接口。
''';
}
