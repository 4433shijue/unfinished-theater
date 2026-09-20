import 'model_params.dart';
import 'gameplay_system.dart';

class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.prompt,
    required this.modelParams,
    this.description = '',
    this.openingMessage = '',
    this.hiddenPrompt = '',
    this.presetId,
    this.isPromptLocked = false,
    this.streamingOutputEnabled = true,
    this.segmentedOutputEnabled = false,
    this.nextStepOptionsEnabled = true,
    this.mapModeEnabled = false,
    this.largeGroupChatModeEnabled = false,
    this.avatarDataUri = '',
    this.branchSourceCharacterId,
    this.branchOriginMessageId,
    this.branchName = '',
    this.sourceType = '',
    this.sourceCharacterId,
    this.sourceNpcId,
    this.sourceMigrationRecordId,
    this.gameplaySystem,
  });

  factory CharacterProfile.fromJson(Map<String, dynamic> json) {
    final rawModelParams = json['modelParams'];

    return CharacterProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名角色',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      prompt: json['prompt']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      openingMessage: json['openingMessage']?.toString() ?? '',
      hiddenPrompt: json['hiddenPrompt']?.toString() ?? '',
      presetId: json['presetId']?.toString(),
      isPromptLocked: json['isPromptLocked'] == true,
      streamingOutputEnabled: json['streamingOutputEnabled'] != false,
      segmentedOutputEnabled: json['segmentedOutputEnabled'] == true,
      nextStepOptionsEnabled: json['nextStepOptionsEnabled'] != false,
      mapModeEnabled: json['mapModeEnabled'] == true,
      largeGroupChatModeEnabled: json['largeGroupChatModeEnabled'] == true,
      avatarDataUri: json['avatarDataUri']?.toString() ?? '',
      branchSourceCharacterId: json['branchSourceCharacterId']?.toString(),
      branchOriginMessageId: json['branchOriginMessageId']?.toString(),
      branchName: json['branchName']?.toString() ?? '',
      sourceType: json['sourceType']?.toString() ?? '',
      sourceCharacterId: json['sourceCharacterId']?.toString(),
      sourceNpcId: json['sourceNpcId']?.toString(),
      sourceMigrationRecordId: json['sourceMigrationRecordId']?.toString(),
      gameplaySystem: json['gameplaySystem'] is Map
          ? GameplaySystem.fromJson(
              Map<String, dynamic>.from(json['gameplaySystem'] as Map),
            )
          : null,
      modelParams: ModelParams.fromJson(
        rawModelParams is Map
            ? Map<String, dynamic>.from(rawModelParams)
            : const <String, dynamic>{},
      ),
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final String prompt;
  final String description;
  final String openingMessage;
  final String hiddenPrompt;
  final String? presetId;
  final bool isPromptLocked;
  final bool streamingOutputEnabled;
  final bool segmentedOutputEnabled;
  final bool nextStepOptionsEnabled;
  final bool mapModeEnabled;
  final bool largeGroupChatModeEnabled;
  final String avatarDataUri;
  final String? branchSourceCharacterId;
  final String? branchOriginMessageId;
  final String branchName;
  final String sourceType;
  final String? sourceCharacterId;
  final String? sourceNpcId;
  final String? sourceMigrationRecordId;
  final GameplaySystem? gameplaySystem;
  final ModelParams modelParams;

  bool get isPresetRole => presetId != null && presetId!.trim().isNotEmpty;

  bool get isTutorialDemo => presetId == 'tutorial_demo';

  int get preferredChoiceCount => isTutorialDemo ? 3 : 6;

  bool get requiresHtmlPanel => !isTutorialDemo;

  bool get isStoryBranch =>
      branchSourceCharacterId != null &&
      branchSourceCharacterId!.trim().isNotEmpty;

  bool get isNpcMigration =>
      sourceType.trim() == 'npc_migration' &&
      sourceNpcId != null &&
      sourceNpcId!.trim().isNotEmpty;

  String get rootCharacterId =>
      isStoryBranch ? branchSourceCharacterId!.trim() : id;

  String get visibleBlurb {
    final trimmedDescription = description.trim();
    if (trimmedDescription.isNotEmpty) {
      return trimmedDescription;
    }
    return prompt.trim();
  }

  String get runtimeProtocolPrompt {
    if (largeGroupChatModeEnabled) {
      return _largeGroupChatRuntimePrompt;
    }

    final parts = <String>[
      hiddenPrompt.trim(),
      _runtimeSwitchPrompt.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join('\n\n');
  }

  String get fullSystemPrompt {
    final parts = <String>[
      runtimeProtocolPrompt.trim(),
      prompt.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join('\n\n');
  }

  String get _runtimeSwitchPrompt {
    if (largeGroupChatModeEnabled) {
      return _largeGroupChatRuntimePrompt;
    }
    if (isTutorialDemo) {
      return _tutorialDemoRuntimePrompt;
    }

    final buffer = StringBuffer()
      ..writeln('【本角色运行开关｜格式完成优先】')
      ..writeln('一次正式剧情回复必须同时满足正文长度和当前模式的结构要求；具体需要哪些标签与资料卡，以本节的模式和开关为准。');

    buffer.writeln(
      '如果角色设定要求长篇叙事，HTML/CSS/JS、[GAME_STATE] 和 [CHOICES] 都不能替代正文；正文完成后仍必须继续输出 App 所需结构。',
    );

    buffer
      ..writeln()
      ..writeln('【主聊天叙事长度｜轻小说正文】')
      ..writeln(
          '当本轮属于主聊天里的角色扮演、文游、模拟器、沉浸模式或剧情推进时，纯文字剧情正文目标为 2200-3200 个中文字符，硬性下限为 2000 个中文字符。')
      ..writeln(
          '长度只统计用户直接阅读的剧情正文，不统计 HTML、[BUBBLE] 标签、[GAME_STATE]、[THEATER_PATCH]、[MAP_STATE]、[CHOICES]、JSON 字段名或系统说明。')
      ..writeln(
          '以自然段展开人物眼下要办的事。关键交锋与选择写成具体场景，重复过程简洁带过；不要用提纲、列表、总结或反复描写同一种情绪凑字数。')
      ..writeln('如果用户输入很短，也要基于当前剧情合理扩写；可以描写 NPC 和环境反应，但不要替玩家决定明确行动、台词或内心结论。')
      ..writeln('格式优先级不变：只能扩写正文文本，不能为了凑字数破坏固定标签、代码块或状态块结构。')
      ..writeln(_narrativeVoicePrompt);

    if (streamingOutputEnabled) {
      buffer.writeln(
        '当前角色开启流式输出。正文可以逐步出现；HTML、CSS、JS 会在回复完成后再由前端渲染。',
      );
    } else {
      buffer.writeln(
        '当前角色关闭流式输出。请仍然输出完整内容，前端会等整条回复完成后再展示。',
      );
    }

    if (segmentedOutputEnabled) {
      buffer
        ..writeln(
            '当前角色已开启分段输出。正式内容可以拆成一个或多个气泡，每个气泡必须使用 [BUBBLE] 和 [/BUBBLE] 包裹。')
        ..writeln(
            '每个 [BUBBLE] 内可以放一个完整的 Markdown 段落或一个完整的 ```html 代码块。不要把 [CHOICES] 放进 [BUBBLE] 里面。');
    } else {
      buffer.writeln('当前角色关闭分段输出。不要使用 [BUBBLE] 标签。');
    }

    if (nextStepOptionsEnabled && !mapModeEnabled) {
      buffer
        ..writeln('当前角色开启“下一步选项”。正式剧情回复必须在整条回复最底部输出一个 [CHOICES] 选项块。')
        ..writeln(
            '选项永远放在全部正文、全部 HTML、全部气泡、[GAME_STATE]${gameplaySystem == null ? '' : ' 和 [THEATER_PATCH]'}之后。')
        ..writeln(
            '选项块必须用 [CHOICES] 开始，并用 [/CHOICES] 结束；每行必须是 A|行动文本 这种格式，按 A-F 给出 6 个可执行行动。');
    } else if (!mapModeEnabled) {
      buffer
        ..writeln(
            '当前角色关闭“下一步选项”。本条规则覆盖前文任何选项要求：不要输出 [CHOICES]，不要输出 A/B/C/D/E/F 下一步选项。')
        ..writeln('正文保持连贯阅读，仍须输出本模式要求的 HTML 和独立状态块；关闭选项不等于关闭状态维护。');
    }

    if (mapModeEnabled) {
      buffer
        ..writeln()
        ..writeln('【地图主线模式，最高优先级】')
        ..writeln(
            '当前角色启用了不可逆固定地图主线模式。地图开局只生成一次固定蓝图，用户通过点击路线和行动篮子组织下一步；每回合先由本地规则结算，再由 AI 根据结算事实续写剧情。')
        ..writeln('不要把地图模式写成和主聊天平行的支线；地图中发生的事件就是当前主线。不要退回普通 [CHOICES] 主导。')
        ..writeln(
            '正式地图推进必须输出可阅读长剧情、独立 [GAME_STATE]${gameplaySystem == null ? '' : '、独立 [THEATER_PATCH]'}、独立 [MAP_STATE]；不要输出 [CHOICES]。')
        ..writeln(
            '[MAP_STATE] 必须维护 currentLocationId、mainGoal、currentScene、locations、activeChoices。activeChoices 是给行动篮子的建议，不是普通选项块。')
        ..writeln(
            '如果已有地图地点，必须沿用固定的地点与道路 id/name，不要新增、删除、改名或替换地图拓扑；只能更新状态、NPC、线索、最近场景和行动建议。')
        ..writeln(
            '如果需要生成地图、地点、地点事件或时间推进结果，必须保持地点、时间、NPC印象、任务和背包状态连续，不要和既有剧情互相打架。');
    }

    buffer
      ..writeln()
      ..writeln('【结构标签底线】')
      ..writeln(mapModeEnabled
          ? '正式地图剧情回复不要退化成纯文本收尾；必须有正文、独立 [GAME_STATE] 状态块${gameplaySystem == null ? '' : '、独立 [THEATER_PATCH] 变量补丁'}和独立 [MAP_STATE] 状态块，不要输出 [CHOICES]。'
          : '正式剧情回复不要退化成纯文本收尾；必须有正文、至少一个 ```html 代码块、独立 [GAME_STATE] 状态块，并按开关决定是否输出 [CHOICES]。')
      ..writeln('[GAME_STATE] 只给 App 解析，不能写进 HTML、Markdown 代码块、[BUBBLE] 或选项文字。')
      ..writeln(gameplaySystem == null
          ? ''
          : '[THEATER_PATCH] 只给 App 解析，必须放在 [GAME_STATE] 之后；不要写进 HTML、Markdown 代码块、[BUBBLE] 或选项文字。')
      ..writeln(mapModeEnabled
          ? gameplaySystem == null
              ? '[GAME_STATE] 必须完整闭合后再输出 [MAP_STATE]；[MAP_STATE] 也必须完整闭合。'
              : '[GAME_STATE] 必须完整闭合后输出 [THEATER_PATCH]，再输出 [MAP_STATE]；三个状态块都必须完整闭合。'
          : gameplaySystem == null
              ? '[GAME_STATE] 开始标签和 [/GAME_STATE] 结束标签必须各占单独一行；如果开启 [CHOICES]，[GAME_STATE] 必须完整闭合后才输出 [CHOICES]。'
              : '[GAME_STATE] 必须完整闭合后输出 [THEATER_PATCH]；如果开启 [CHOICES]，[THEATER_PATCH] 必须完整闭合后才输出 [CHOICES]。')
      ..writeln('状态块至少包含：时间、地点、状态、当前任务、人物数据、关系网、剧情记录、NPC变化。')
      ..writeln()
      ..writeln('【正文与 HTML 分工】')
      ..writeln(
          '剧情正文、人物心理、场景推进和对白必须优先用纯文字或 Markdown 正常呈现，不能全部塞进 HTML。纯文字剧情必须承担主要阅读体验。')
      ..writeln(
          '除剧情正文以外的功能型内容放进完整 ```html 代码块：论坛消息、小剧场吐槽、突发事件、公告栏、状态卡、任务板、关系网、地图、背包、新闻流等。')
      ..writeln(mapModeEnabled
          ? '地图模式的 HTML 资料卡为可选项，只在确实帮助阅读时提供；地图与行动建议仍由独立 [MAP_STATE] 维护。'
          : '没有特殊资料时，给一个简短的状态卡或任务板就行。')
      ..writeln('HTML 必须是单文件完整文档，适配手机屏幕，不引用外部资源。')
      ..writeln(
          '上述 HTML 要求是内部格式协议，不要在用户可见剧情正文里解释“HTML 状态面板、自包含、适配手机竖屏、代码块、用于本轮展示”等实现说明。')
      ..writeln(mapModeEnabled
          ? 'HTML 里的行动按钮如有点击行为，必须带 data-prompt 或 data-action；地图模式始终不输出 [CHOICES]。'
          : 'HTML 里的行动按钮如有点击行为，必须带 data-prompt 或 data-action；它们不等同于 [CHOICES]，[CHOICES] 仍按开关规则放在整条回复最底部。');

    return buffer.toString().trim();
  }

  static const String _narrativeVoicePrompt = '''
【叙事与对白】
沿用当前角色与世界设定的文体，不把不同题材和人物都写成同一种口吻。直接承接玩家刚刚说过或做过的事，让 NPC 因自己的目标采取行动，后果应接得上既有关系与世界规则。
每个主要段落带来新的动作、信息或局势变化。细节跟着当前视角注意到的事走；人物只知道自己能够知道的内容，猜测不能写成已证实的秘密。
对白服务人物当下的目的，可以试探、回避、说一半，也可以直说。语气差异来自身份、关系和压力，不靠重复口头禅；双方已知的背景不用借对白重讲。
动作已经显出情绪时，少补一句解释。避免成串比喻、整齐排比和空泛抒情，不替每一幕总结道理，也不固定以反转、谜语或新危机收尾。在需要玩家回应的地方留下清楚的处境。
这些文风要求只作用于可阅读正文与 JSON 内的叙事字符串，不改变字段名、标签、枚举、数值约束或输出结构。
''';

  String get _tutorialDemoRuntimePrompt => '''
【第一次开幕运行规则｜最高优先级】
1. 这是面向普通玩家的短体验，不执行普通文游的 2000 字长篇规则。
2. 用户可见正文保持 300-600 个中文字符；承接用户刚做的选择，用一个小场景或可见结果推进一个体验目标，不写产品说明书。
3. HTML 资料卡不是必需；只有状态对比或步骤确实需要时才输出一个简短、适配手机的资料卡。
4. 每轮必须维护独立 [GAME_STATE]，但绝不向用户解释这个内部标签。
5. ${nextStepOptionsEnabled ? '只输出 A-C 三个上下文相关行动，不输出 D-F；其中一项应允许自由探索、换条路线或返回导览。' : '当前关闭下一步选项，不输出 [CHOICES] 或 A-F 建议行动，仍须维护 [GAME_STATE]。'}
6. 正文 -> 可选资料卡 -> [GAME_STATE]${nextStepOptionsEnabled ? ' -> [CHOICES]' : ''}。内部结构必须完整闭合。
7. 不替玩家决定关键行动、台词或内心结论。
''';

  String get _largeGroupChatRuntimePrompt {
    final buffer = StringBuffer()
      ..writeln('【大型群聊模式，最高优先级】')
      ..writeln('当前角色启用了不可逆大型群聊模式。这是独立主线模式，不是普通文游的分段输出，也不是 HTML 美化框。')
      ..writeln(
          '本模式覆盖隐藏协议里关于长篇纯文字正文、HTML 美化框、[BUBBLE] 分段、[CHOICES] 六选项和地图主线的要求。')
      ..writeln(
          '正式剧情回复绝不能回退成普通纯文游大段叙事，绝不能输出 HTML/CSS/JS，绝不能输出 [CHOICES]，绝不能输出 [BUBBLE]，绝不能输出 [MAP_STATE]。')
      ..writeln()
      ..writeln('【群聊输出结构】')
      ..writeln('每次正式回复必须按顺序输出：')
      ..writeln('1. 独立 [GROUP_CHAT] JSON 块。')
      ..writeln('2. 独立 [GAME_STATE] 状态块。')
      ..writeln(gameplaySystem == null ? '' : '3. 独立 [THEATER_PATCH] 变量补丁。')
      ..writeln('除此之外不要输出其他解释、标题、HTML 或六选项。')
      ..writeln()
      ..writeln('[GROUP_CHAT] JSON 格式必须如下：')
      ..writeln('[GROUP_CHAT]')
      ..writeln('{')
      ..writeln('  "mode": "large_group_chat",')
      ..writeln('  "messages": [')
      ..writeln(
          '    {"id": "msg_1", "type": "narration", "speakerId": "narrator", "speaker": "旁白", "replyTo": "", "content": "剧情推进、动作、环境、心理、冲突或场景变化。"},')
      ..writeln(
          '    {"id": "msg_2", "type": "npc", "speakerId": "NPC档案ID", "speaker": "NPC名字", "replyTo": "msg_1", "content": "这里只写这个 NPC 亲口说出的话。"}')
      ..writeln('  ]')
      ..writeln('}')
      ..writeln('[/GROUP_CHAT]')
      ..writeln(
          'JSON 只能使用上述字段：mode、messages、id、type、speakerId、speaker、replyTo、content；不要添加 align、side、avatar、style 等前端字段。')
      ..writeln(
          'type 只能是 "narration" 或 "npc"；旁白消息必须写 {"type":"narration","speaker":"旁白"}；角色消息必须写 {"type":"npc","speaker":"角色名"}。')
      ..writeln(
          '每条消息 id 在本轮内唯一并按 msg_1、msg_2 递增；已存在于 NPC 档案的角色必须使用其真实 speakerId，不要编造另一个 id。新登场且尚无档案的 NPC 可以把 speakerId 写为空字符串。')
      ..writeln(
          'replyTo 用于明确回应本轮前一条消息，填写目标消息 id；没有明确回复对象时写空字符串。旁白 speakerId 固定为 narrator。')
      ..writeln()
      ..writeln('【群聊气泡规则】')
      ..writeln(_narrativeVoicePrompt)
      ..writeln(
          '消息数量服从剧情节奏：过渡、等待或安静场景 2-4 条，普通交流 4-7 条，多人争执、高潮或突发事件 8-12 条。不要为了凑数量制造废话。')
      ..writeln('一旦局面需要玩家表态、选择、回答或承担关键行动，就停在清晰的回应点，把决定权交给玩家，不要让 NPC 自己把冲突聊完。')
      ..writeln('只允许当前场景内明确在场、正在连线或刚刚参与事件的 NPC 发言；不要让当前场景外的 NPC 乱入。')
      ..writeln('旁白气泡负责所有动作、环境、神态、心理、沉默、靠近、离开、递物、攻击、防御、冲突升级和剧情推进；旁白可以输出长段剧情。')
      ..writeln(
          '旁白 content 不能替任何角色说台词，不能写「某某：……」、不能写带引号的角色发言；如果有人开口，必须拆成单独 NPC 气泡。')
      ..writeln('NPC 气泡只能写该 NPC 亲口说出来的话，不能写动作描写、神态描写、心理描写、环境描写、括号动作或旁白式说明。')
      ..writeln(
          'NPC content 里不要写「他说/她说/我看向/（沉默）/笑了笑/低头/转身」这类叙述；只保留可直接放进聊天气泡的原话。')
      ..writeln('如果 NPC 需要动作、表情、沉默或离场，必须先用旁白气泡描述，再让 NPC 单独说台词。')
      ..writeln(
          '不要机械让所有 NPC 轮流发言；根据当前剧情选择真正需要说话的人。可以有打断、争论、补充、沉默后的爆发和旁白推进后的集体反应。')
      ..writeln()
      ..writeln('【状态面板与 NPC 私聊】')
      ..writeln(
          '[GAME_STATE] 沿用普通文游状态面板格式，至少包含时间、地点、状态、当前任务、人物数据、关系网、剧情记录、NPC变化、NPC更新。')
      ..writeln('NPC更新｜主动消息 只记录本轮正文中实际发生的私聊原话；没有真实私聊时写无，不把联系计划写成已经发出的消息。')
      ..writeln(
          '周期性主动私聊由 App 在本轮提交后独立调度，不要为了固定轮数自行触发。missing、dead、archived NPC 不得发送消息或改变好感。')
      ..writeln(
          'NPC变化只写状态面板可读变化；NPC更新使用格式「npcId：已建档 NPC 的稳定 ID；新 NPC 留空｜名字：...｜简介：...｜好感变化：...｜印象：...｜生命周期：...｜生命周期原因：...｜主动消息：无或本轮真实私聊原话」。NPC 档案是好感唯一事实源，只写变化量，不重复写绝对好感。')
      ..writeln()
      ..writeln('【最终底线】')
      ..writeln(
          '输出必须有 [GROUP_CHAT]、[GAME_STATE]${gameplaySystem == null ? '' : ' 和 [THEATER_PATCH]'}，不能只有纯文本。')
      ..writeln(
          '[GROUP_CHAT]、[GAME_STATE]${gameplaySystem == null ? '' : '、[THEATER_PATCH]'}都不得写进 Markdown 代码块。')
      ..writeln('不要向用户解释这些协议，不要说“下面是 JSON/状态面板/群聊模式”。');

    if (streamingOutputEnabled) {
      buffer.writeln('当前角色开启流式输出；前端会在回复完成后按消息数组渲染成群聊气泡。');
    } else {
      buffer.writeln('当前角色关闭流式输出；前端会等待整条回复完成后按消息数组渲染成群聊气泡。');
    }

    return buffer.toString().trim();
  }

  CharacterProfile copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? prompt,
    String? description,
    String? openingMessage,
    String? hiddenPrompt,
    String? presetId,
    bool? isPromptLocked,
    bool? streamingOutputEnabled,
    bool? segmentedOutputEnabled,
    bool? nextStepOptionsEnabled,
    bool? mapModeEnabled,
    bool? largeGroupChatModeEnabled,
    String? avatarDataUri,
    String? branchSourceCharacterId,
    String? branchOriginMessageId,
    String? branchName,
    String? sourceType,
    String? sourceCharacterId,
    String? sourceNpcId,
    String? sourceMigrationRecordId,
    GameplaySystem? gameplaySystem,
    ModelParams? modelParams,
  }) {
    return CharacterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      prompt: prompt ?? this.prompt,
      description: description ?? this.description,
      openingMessage: openingMessage ?? this.openingMessage,
      hiddenPrompt: hiddenPrompt ?? this.hiddenPrompt,
      presetId: presetId ?? this.presetId,
      isPromptLocked: isPromptLocked ?? this.isPromptLocked,
      streamingOutputEnabled:
          streamingOutputEnabled ?? this.streamingOutputEnabled,
      segmentedOutputEnabled:
          segmentedOutputEnabled ?? this.segmentedOutputEnabled,
      nextStepOptionsEnabled:
          nextStepOptionsEnabled ?? this.nextStepOptionsEnabled,
      mapModeEnabled: mapModeEnabled ?? this.mapModeEnabled,
      largeGroupChatModeEnabled:
          largeGroupChatModeEnabled ?? this.largeGroupChatModeEnabled,
      avatarDataUri: avatarDataUri ?? this.avatarDataUri,
      branchSourceCharacterId:
          branchSourceCharacterId ?? this.branchSourceCharacterId,
      branchOriginMessageId:
          branchOriginMessageId ?? this.branchOriginMessageId,
      branchName: branchName ?? this.branchName,
      sourceType: sourceType ?? this.sourceType,
      sourceCharacterId: sourceCharacterId ?? this.sourceCharacterId,
      sourceNpcId: sourceNpcId ?? this.sourceNpcId,
      sourceMigrationRecordId:
          sourceMigrationRecordId ?? this.sourceMigrationRecordId,
      gameplaySystem: gameplaySystem ?? this.gameplaySystem,
      modelParams: modelParams ?? this.modelParams,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'prompt': prompt,
      'description': description,
      'openingMessage': openingMessage,
      'hiddenPrompt': hiddenPrompt,
      'presetId': presetId,
      'isPromptLocked': isPromptLocked,
      'streamingOutputEnabled': streamingOutputEnabled,
      'segmentedOutputEnabled': segmentedOutputEnabled,
      'nextStepOptionsEnabled': nextStepOptionsEnabled,
      'mapModeEnabled': mapModeEnabled,
      'largeGroupChatModeEnabled': largeGroupChatModeEnabled,
      'avatarDataUri': avatarDataUri,
      'branchSourceCharacterId': branchSourceCharacterId,
      'branchOriginMessageId': branchOriginMessageId,
      'branchName': branchName,
      'sourceType': sourceType,
      'sourceCharacterId': sourceCharacterId,
      'sourceNpcId': sourceNpcId,
      'sourceMigrationRecordId': sourceMigrationRecordId,
      if (gameplaySystem != null) 'gameplaySystem': gameplaySystem!.toJson(),
      'modelParams': modelParams.toJson(),
    };
  }
}

class CharacterDraft {
  const CharacterDraft({
    required this.name,
    required this.prompt,
    this.description = '',
    this.openingMessage = '',
    this.hiddenPrompt = '',
    this.streamingOutputEnabled = true,
    this.segmentedOutputEnabled = false,
    this.nextStepOptionsEnabled = true,
    this.mapModeEnabled = false,
    this.largeGroupChatModeEnabled = false,
    this.avatarDataUri = '',
    required this.modelParams,
  });

  final String name;
  final String prompt;
  final String description;
  final String openingMessage;
  final String hiddenPrompt;
  final bool streamingOutputEnabled;
  final bool segmentedOutputEnabled;
  final bool nextStepOptionsEnabled;
  final bool mapModeEnabled;
  final bool largeGroupChatModeEnabled;
  final String avatarDataUri;
  final ModelParams modelParams;
}
