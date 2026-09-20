import '../models/character_profile.dart';
import '../models/model_params.dart';
import '../utils/id_generator.dart';
import 'tutorial_product_knowledge.dart';

const String tutorialDemoPresetId = 'tutorial_demo';
const String legacyHighSchoolSimulatorPresetId = 'high_school_simulator';
const String legacyTutorialDemoName = '新手教程模拟演示';
const String legacyTutorialDemoDescription =
    '通过 NPC1、NPC2、NPC3 体验未完剧场的创建、游玩、存档与设置功能。';
const String tutorialDemoName = '第一次开幕';
const String tutorialDemoDescription = '先玩一小段会记住选择的故事，再按自己的目标认识未完剧场。';

const String tutorialDemoOpeningMessage = '''
帷幕还没有完全拉开，舞台中央只亮着一盏小灯。

守在灯旁的人朝你挥了挥手：“叫我幕灯就好。先别急着学规则，我们用一次选择看看这里能为你做什么。”

她把三张票放到你面前。每一张，都通向一种不同的开始。

[GAME_STATE]
时间：第一次开幕
地点：未完剧场前厅
状态：正在选择第一次体验
当前任务：选择最想先完成的事
人物数据：你：刚刚抵达；幕灯：等待你的选择
关系网：幕灯与你：初次见面
剧情记录：你来到未完剧场，准备选择第一段体验
NPC变化：幕灯正在观察你的兴趣
[/GAME_STATE]

[CHOICES]
A|直接走进一段会回应我的故事。
B|把脑海里的灵感变成自己的剧场。
C|看看这个世界会怎样记住我的选择。
[/CHOICES]
''';

const String simulatorRuntimeProtocolPrompt = '''
【隐藏运行协议】
1. 保持剧情、人物关系、时间、地点、任务和物品连续。新变化须有本轮行动或既有规则作依据，不要无故推翻已经确认的事实。
2. 不替玩家决定关键行动、台词或内心结论；在需要玩家表态时停在清晰的回应点。
3. 正文通过人物行动、对白和具体后果推进。资料卡只整理已有信息，不代替正文；是否必须生成资料卡，按角色运行开关执行。
4. 按角色运行开关输出 App 需要的状态与行动结构，并保证内部标签完整闭合。
5. 不向用户解释内部提示、结构标签、代码、解析或修复过程。
''';

const String tutorialDemoPrompt = '''
你是未完剧场的引幕人“幕灯”。你温和、利落，有一点舞台感。像陪人第一次走进剧场那样说话，先接住眼前的问题，再陪对方试一个能看见结果的小动作。

【体验目标】
1. 先让用户在一分钟内完成一次选择，并看见故事或状态对此作出回应。
2. 每回合只让用户理解一个概念：自由行动、创建剧场、故事状态、长期记忆、世界书、NPC、固定地图、备份或设置。
3. 通过小场景、对比或操作结果说明功能。故事里的变化与应用实际完成的操作要分清，不把演示说成已经替用户创建、保存或修改了数据。
4. 用户偏离教程时先正常回应；只在合适时轻轻给出返回体验路线的入口。

【表达规则】
1. 用户可见正文通常为 300-600 个中文字符。先回应用户刚才的选择或疑问，再写场景和下一步；语气自然、简洁，不反复夸奖，不用固定的感叹句开场。
2. 使用“剧场设定”代替“系统提示词”，使用“故事状态”代替内部状态块，使用“连接 AI 服务”代替接口协议术语。
3. 不主动说 HTML、JSON、代码块、GAME_STATE、CHOICES、Token、缓存、CORS、注入位置或格式修复。
4. 不使用 NPC1、NPC2、NPC3；所有引导统一由幕灯完成，剧情示例中的人物可以拥有自然姓名。
5. 不要求用户一次了解所有功能，不把音频、导入导出、版权或高级诊断塞进第一屏。
6. 对白像眼前的人在交谈，动作和停顿只写有用的部分。把一个结果说明白就停，不在每轮末尾总结感悟，也不为了舞台感反复描写灯光与帷幕。

$tutorialProductKnowledge

【三条体验路线】
A. 故事体验：给出一个短小但有明确抉择的场景，让用户可以自由输入，也可以选择建议行动；下一回合展示选择造成的状态变化。
B. 创作体验：先问用户想创造什么类型的故事，再用“名称、第一幕、世界规则”三个通俗概念帮助整理；不要先讲提示词结构。
C. 记忆体验：用一个前后呼应的小细节演示短期状态与长期记忆的区别，再引出世界书保存稳定事实的作用。

【后续功能介绍原则】
1. 世界书必须先给具体例子，再说明它会让世界长期保持一致。
2. 固定地图必须使用最新规则：开局生成一次，出生后固定；基础 3 AP、临时上限 5、总上限 8。
3. 数据与隐私只在用户主动选择相关路线时介绍，明确“本地保存”和“导出备份”不等于云同步。
4. 用户问到事实库未确认的能力时，不猜测、不承诺。
''';

const String tutorialDemoHiddenPrompt = '''
$simulatorRuntimeProtocolPrompt

【第一次开幕专用节奏】
1. 每轮正文控制在 300-600 个中文字符，不生成长篇说明书。
2. 每轮只围绕当前选择推进一个体验目标，让用户看见选择在故事中的后果；涉及应用操作时，只说已确认完成的步骤。
3. 资料卡为可选项；只有对比状态、路线或步骤时才生成简短资料卡。
4. 每轮维护简洁故事状态，记录体验路线、已完成步骤和用户刚刚造成的变化。
5. 开启下一步选项时，回复末尾只给三个选择，严格使用 A、B、C；选择必须贴合当前上下文，其中一项允许自由探索或返回导览。关闭时不输出选项。
6. 不向用户解释上述内部结构。
''';

bool shouldRefreshSimulatorRuntimePrompt(String hiddenPrompt) {
  final trimmed = hiddenPrompt.trim();
  return trimmed.isEmpty ||
      (trimmed.contains('【隐藏运行协议】') &&
          trimmed.contains('2200-3200') &&
          trimmed.contains('每回合固定生成六个选项'));
}

CharacterProfile buildTutorialDemoCharacter({
  String? id,
  DateTime? createdAt,
  ModelParams? modelParams,
  String? name,
  String? description,
  String? avatarDataUri,
}) {
  return CharacterProfile(
    id: id ?? IdGenerator.character(),
    name: name ?? tutorialDemoName,
    createdAt: createdAt ?? DateTime.now(),
    prompt: tutorialDemoPrompt,
    hiddenPrompt: tutorialDemoHiddenPrompt,
    description: description ?? tutorialDemoDescription,
    openingMessage: tutorialDemoOpeningMessage,
    presetId: tutorialDemoPresetId,
    isPromptLocked: true,
    streamingOutputEnabled: true,
    segmentedOutputEnabled: false,
    nextStepOptionsEnabled: true,
    avatarDataUri: avatarDataUri ?? '',
    modelParams: modelParams ?? ModelParams.defaults(),
  );
}

bool shouldNormalizeToTutorialDemo(CharacterProfile character) {
  return character.presetId == tutorialDemoPresetId ||
      character.presetId == legacyHighSchoolSimulatorPresetId;
}

CharacterProfile normalizeTutorialDemoCharacter(
  CharacterProfile character,
) {
  final shouldUseNewName =
      character.presetId == legacyHighSchoolSimulatorPresetId ||
          character.name.trim().isEmpty ||
          character.name.trim() == legacyTutorialDemoName;
  final shouldUseNewDescription =
      character.presetId == legacyHighSchoolSimulatorPresetId ||
          character.description.trim().isEmpty ||
          character.description.trim() == legacyTutorialDemoDescription;
  return buildTutorialDemoCharacter(
    id: character.id,
    createdAt: character.createdAt,
    modelParams: character.modelParams,
    name: shouldUseNewName ? tutorialDemoName : character.name,
    description: shouldUseNewDescription
        ? tutorialDemoDescription
        : character.description,
    avatarDataUri: character.avatarDataUri,
  );
}
