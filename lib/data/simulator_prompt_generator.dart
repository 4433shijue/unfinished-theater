import 'dart:convert';
import 'gameplay_system_prompt.dart';
import '../models/simulator_prompt_request.dart';

const String simulatorPromptGeneratorSystemPrompt = '''
根据用户的灵感，为文字游戏编写能长期使用的设定与运行规则。本次交付的是角色提示词，实际剧情由另一个 AI 在游玩时展开。

只输出一个 JSON 对象，不要 Markdown 代码围栏，不要解释：
{
  "name": "模拟器名称",
  "description": "一句话简介，40-80字",
  "opening": "开场白正文",
  "systemPrompt": "完整系统提示词正文"
}
四个基础键必须齐全，值都必须是非空字符串。用户要求结构化开局时，额外提供 openingDraft 对象。字符串内的换行、引号和反斜杠要正确转义，不要用 null、数组或嵌套对象代替正文。

内容要求：
- 开场白直接写玩家眼前的处境，给出可回应的问题或行动机会。通过具体的人物、环境和动作建立氛围，不写欢迎语或功能介绍。可以用 {user} 代指玩家。
- systemPrompt 交代世界如何运转、人物各自想要什么、行动的条件与代价，以及回合、状态、开局和重开规则。每条规则都应帮助模型处理实际游玩情况，不堆设定名词或宣传语。
- 按题材选择需要追踪的时间、地点、任务、资源、关系、物品或线索。NPC 好感度数值和 NPC 对玩家的印象分开记录，不照搬通用数值面板。
- 玩家决定自己的台词、态度和关键行动。NPC 可以试探、建议或拒绝；需要玩家选择时停下来。第一回合完成初始选择前，只展示开局引导和待确认信息。
- 现实题材遵守现实逻辑；架空题材保持人物、时间、因果和世界规则一致。关键转折应有此前行动或已知规则作为依据。
- 世界边界由玩家世界书管理，不在生成的规则里擅自写死。吸收用户明确提供的题材限制、文风偏好与世界观补充。
- 文风服从题材和用户要求。人物的身份、关系与眼下目的决定说话方式，不给所有人套同一种口吻。用可感知的细节和选择表现情绪，已经写清的感受不再反复解释，不强加升华或固定结尾。
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
本次交付以世界设定为核心。写清世界如何运转、规则的适用条件，以及制度、文化、资源和禁忌怎样影响人物的日常选择。

系统提示词应以设定集为核心，包含：
1. 世界基底：时代、地理、社会结构、技术/超自然层级、日常生活质感。
2. 核心规则：力量、资源、身份、代价、禁忌、法律或潜规则如何运行。
3. 势力与群体：主要组织、阶层、阵营、民间网络、冲突利益。
4. 文化与价值观：礼仪、称呼、信仰、审美、流行传闻、普通人的生存逻辑。
5. 长期矛盾：公开冲突、暗线问题、历史遗留、即将爆发的压力。
6. 可游玩接口：玩家角色和外部注入的绑定 NPC 可以怎样自然进入世界，但不要替他们指定固定身份、固定恋爱对象或固定结局。
7. 状态维度：只列出需要追踪的世界状态，如时间、地点、阵营态度、资源、线索、风险、关系变化、事件后果。

NPC 规则适配外部注入的角色卡。绑定 NPC 作为同行者或重要角色，自主行动、表达意见并推动支线，始终保留玩家的选择权。
开场白简短交代一处可进入的场景和眼前的动静，再邀请玩家决定自己与绑定 NPC 怎样进入。不指定尚未确认的身份与关系。
避免以下内容：玩法宣传、功能介绍、模板化“你将扮演”、把规则写成菜单说明、把某个新 NPC 写死为默认搭档。
'''
      : '''
【本次生成模式：完整文游模拟器】
生成完整、可直接游玩的文游模拟器提示词，可以包含该世界自带的 NPC、关系网和长期主线。重要 NPC 应有自己的目标和难处，支线从人物行动与关系中产生。
如果运行时注入了绑定 NPC 角色卡，也必须让绑定 NPC 自主行动，但不能替玩家做决定。
''';

  return '''
请将以下资料整理为可直接给 AI 角色使用的设定与运行规则，并按规定 JSON 结构交付。

${request.advancedSettings.toPrompt()}
${request.includeOpening ? storyOpeningGenerationContract(request) : ''}
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
2. 输出必须是完整 JSON，基础键名为 name / description / opening / systemPrompt，四个值都必须是非空字符串；systemPrompt 只写设定与运行规则，不重复抄写其他三个字段。
3. 第一回合规则要说明：玩家未做初始选择前，不得正式推进剧情，只能展示开局引导和待确认信息。
4. 开场白适合第一次打开角色时直接展示。让玩家看见自己面对的处境和可回应的第一步，篇幅简短，不罗列功能菜单。
5. HTML 美化窗口只生成非正史互动番外，不能承载状态、变量、任务或背包面板；具体主题和交互规则由 App 的每回合番外设置提供。
6. systemPrompt 里要设计长期游玩所需的内容维度，例如时间、地点、当前任务、角色状态、事件卡、NPC 好感度、NPC 印象、剧情物品栏、背包或资源。
7. 提示词要适合长期游玩，规则清楚，题材统一。
7. 如果用户上传了文档，必须把文档里的角色设定、世界观、关系、规则、文风和边界作为主要基础来整理；不要照抄成散文堆砌，要改写成可长期游玩的模拟器提示词。
8. 不要把内容边界写死进系统提示词里，内容边界由用户的世界书功能管理；如果用户在额外限制中写了题材规则、文风偏好或世界观补充，可以自然吸收进去。
9. 如果本次是“只生成世界观”，请优先输出设定集式提示词：少写玩法壳，多写世界运行逻辑、规则、势力、文化、矛盾和可进入接口。
''';
}

String storyOpeningGenerationContract(
        SimulatorPromptGenerationRequest request) =>
    '''
【结构化开局，必须额外提供 openingDraft 对象】
四个基础字符串仍需保留。另附 openingDraft，不能只在 systemPrompt 里描述人物和数值：
{"npcs":[{"id":"稳定短ID","name":"公开姓名","publicIdentity":"公开身份","trueIdentity":"真实身份，可留空","personality":"性格","secret":"秘密，可留空","secretRevealed":false,"appeared":true,"faction":"阵营","goal":"当前目标","stance":"对玩家的立场","affinity":0,"affinityReason":"初始关系原因"}],"relationships":[{"from":"人物ID","to":"人物ID","label":"关系","public":false}],"items":[{"id":"item_1","name":"物品名","quantity":1,"description":"公开说明","source":"开局携带"}],"gameplaySystem":{}}
人物数量：${request.advancedSettings.npcCount == 0 ? '3—6' : request.advancedSettings.npcCount}；全员有不同目标，只安排少数人在开场登场。未揭露的秘密只放 trueIdentity/secret，禁止写入公开简介、开场、systemPrompt、publicIdentity 或人物公开关系。不要把好感、任务、物品重复做成玩法变量。
gameplaySystem 遵循以下既有玩法约定，但作为 openingDraft 的内嵌对象返回：
$gameplaySystemGeneratorPrompt
${request.existingOpening == null ? '' : '现有开局（保留稳定 ID）：${jsonEncode(request.existingOpening!.toJson())}'}
${request.regenerateSection.isEmpty ? '' : '本次只调整指定部分 ${request.regenerateSection}，其余字段原样保留。'}
''';
