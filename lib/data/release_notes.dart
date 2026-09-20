import 'package:flutter/material.dart';

class ReleaseNoteItem {
  const ReleaseNoteItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class ReleaseNotes {
  const ReleaseNotes({
    required this.id,
    required this.version,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String id;
  final String version;
  final String title;
  final String subtitle;
  final List<ReleaseNoteItem> items;
}

const ReleaseNotes currentReleaseNotes = ReleaseNotes(
  id: 'v2.12.0',
  version: 'V2.12.0',
  title: 'V2.12.0 看懂变化，编写规则',
  subtitle: '从变量变化回看剧情，用表单编写玩法，在预演中检查实际后果。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.history,
      title: '每个变量都有变化记录',
      description: '点击玩法面板中的变量，查看当前分支的变化过程与对应剧情；模糊状态按当时能知道的阶段展示。',
    ),
    ReleaseNoteItem(
      icon: Icons.edit_note,
      title: '用表单编写执行规则',
      description: '选择条件、代价、效果与触发频率，把设计保存到草稿；文字叙事规则和自动结算规则有清楚的区别。',
    ),
    ReleaseNoteItem(
      icon: Icons.fact_check_outlined,
      title: '预演能看清触发结果',
      description: '检查条件、资源和冷却对规则的影响，在独立进度中观察结算，确认后再应用到剧场。',
    ),
  ],
);

const ReleaseNotes _v2111ReleaseNotes = ReleaseNotes(
  id: 'v2.11.1',
  version: 'V2.11.1',
  title: 'V2.11.1 剧情与对白优化',
  subtitle: '调整角色对白和小剧场的写作要求，补齐生成结果检查，修复道具鉴定。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.forum_outlined,
      title: '让人物按自己的性格说话',
      description: '优化主线、NPC 私聊、来信与同人文的写作要求，重视人物行动和对话目的，减少重复解释情绪与套话。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_awesome_outlined,
      title: '小互动有合适的篇幅',
      description: '摸一摸、真心话和独立小剧场按内容安排长短；主线长篇、同人文和教程继续保留各自的篇幅要求。',
    ),
    ReleaseNoteItem(
      icon: Icons.fact_check_outlined,
      title: '检查生成结果是否完整',
      description: 'AI 帮你写缺少名称、简介、开场白或剧场设定时，会尝试补全一次；仍不完整会提示重试，避免把半成品当作成功结果。',
    ),
    ReleaseNoteItem(
      icon: Icons.build_outlined,
      title: '修复道具鉴定与模式提醒',
      description: '修复未知道具无法进入鉴定的问题，并调整地图、群聊和普通剧情各自的回复格式要求。',
    ),
  ],
);

const ReleaseNotes _v2110ReleaseNotes = ReleaseNotes(
  id: 'v2.11.0',
  version: 'V2.11.0',
  title: 'V2.11.0 让变量参与剧情',
  subtitle: '行动有提示，回合有反馈；规则、时钟和承诺可以在作者工作台里编辑与预演。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.insights_outlined,
      title: '行动提示与回合反馈',
      description: '玩家面板优先展示关键变量和行动提示，每轮回复附上可见的状态变化，承诺与余波也能继续追踪。',
    ),
    ReleaseNoteItem(
      icon: Icons.rule_outlined,
      title: '规则按条件结算',
      description: '结构化规则支持条件、资源代价、冷却和一次性事件，由本地程序结算；剧情时间变化可以推进时钟，承诺可记录完成或落空。',
    ),
    ReleaseNoteItem(
      icon: Icons.edit_note_rounded,
      title: '作者草稿与本地预演',
      description: '生成结果先进入草稿，可编辑变量和规则、锁定分组、查看改动差异，再决定应用；本地预演使用独立状态，方便检查规则效果。',
    ),
    ReleaseNoteItem(
      icon: Icons.history_rounded,
      title: '旧回合沿用当时的规则',
      description: '重生成、格式修复和剧情分支会按对应历史状态与规则快照重新计算，避免把后来的资源和规则带回旧回合。',
    ),
  ],
);

const ReleaseNotes _v2105ReleaseNotes = ReleaseNotes(
  id: 'v2.10.5',
  version: 'V2.10.5',
  title: 'V2.10.5 提示词精简',
  subtitle: 'HTML 美化框协议去重，指令不再重复打架，回复格式更稳。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.auto_fix_high_outlined,
      title: 'HTML 协议去重',
      description:
          '“至少一个 HTML 代码块”“适配手机”“别在正文解释实现”等要求此前在固定协议里重复出现 4-5 次，现在只保留完整版一处，其余改为引用，指令更一致。',
    ),
    ReleaseNoteItem(
      icon: Icons.bolt_outlined,
      title: '固定前缀更短',
      description:
          '每条请求的固定前缀精简约 200-300 字，模型规则冲突减少，格式修复触发率会下降（修复是额外一次请求，这才是省钱的点）。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_awesome_outlined,
      title: 'HTML 面板规范微调',
      description: '去掉“内容区域允许独立滚动”要求，HTML 只需单文件、适配手机、不引用外部资源。',
    ),
  ],
);

const ReleaseNotes _v2104ReleaseNotes = ReleaseNotes(
  id: 'v2.10.4',
  version: 'V2.10.4',
  title: 'V2.10.4 帮你写改版',
  subtitle: '帮你写改为结构化 JSON 输出，生成结果自动拆进名称、简介、开场白和提示词，实时预览看得见。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.data_object_rounded,
      title: '帮你写输出结构化结果',
      description: '模拟器生成改为 JSON 返回，名称、简介、开场白、系统提示词自动填进各自输入框，不再挤在提示词框里带标题头。',
    ),
    ReleaseNoteItem(
      icon: Icons.visibility_outlined,
      title: '生成过程实时预览',
      description: '生成中会显示滚动预览区（可选中复制），完成后再自动拆分填入；盲盒和润色同样支持。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_fix_normal_outlined,
      title: '旧格式自动兼容',
      description: '遇到仍按旧标签格式输出的模型，会自动续写修复并退回旧解析方式，不会拿到半成品。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_awesome_outlined,
      title: '提示词去说明书味',
      description: '帮你写的指令从“必须/禁止”清单改成更像编辑给作者的口吻，生成内容也更少模板腔。',
    ),
  ],
);

const ReleaseNotes _v2103ReleaseNotes = ReleaseNotes(
  id: 'v2.10.3',
  version: 'V2.10.3',
  title: 'V2.10.3 生成流式与兜底',
  subtitle: '帮你写、角色卡和同人文边生成边显示，截断会自动续写，玩法系统失败也会自动修复一次。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.auto_awesome_outlined,
      title: 'AI 帮你写改为流式输出',
      description: '模拟器生成、开盲盒和润色会边生成边填入提示词框，不用再盯着转圈等结果，中途截断也能看到已生成的部分。',
    ),
    ReleaseNoteItem(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'NPC 角色卡实时预览',
      description: 'AI 帮你写与 AI 补全角色卡会先流式展示生成过程，完成后仍可预览、局部应用或直接覆盖。',
    ),
    ReleaseNoteItem(
      icon: Icons.menu_book_outlined,
      title: '同人文生成过程可见',
      description: '同人文生成时弹出流式窗口实时显示正文，完成后自动展示全文；失败时 10 啥币照常退回。',
    ),
    ReleaseNoteItem(
      icon: Icons.wrap_text_rounded,
      title: '截断自动续写补全',
      description: '生成结果缺段或明显过短时，会自动发起一次续写请求把内容补完整，再进入解析与预览。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '长输出不再被默认上限截断',
      description: '各类工具生成统一显式设置输出上限，帮你写和同人文这类长内容默认可输出更多。',
    ),
    ReleaseNoteItem(
      icon: Icons.healing_outlined,
      title: '玩法系统失败自动修复',
      description: '玩法系统 JSON 解析失败时会携带原文自动修复一次；仍失败也会在错误里显示模型原始输出片段，方便排查或复制。',
    ),
    ReleaseNoteItem(
      icon: Icons.forum_outlined,
      title: '修复 NPC 私聊输入栏消失',
      description:
          'NPC 私聊页的输入栏曾与主聊天共用教程定位 key，页面压栈后输入栏会被截断；现在 NPC 私聊输入栏独立渲染，发送与小飞机恢复可用。',
    ),
  ],
);

const ReleaseNotes _v2102ReleaseNotes = ReleaseNotes(
  id: 'v2.10.2',
  version: 'V2.10.2',
  title: 'V2.10.2 缓存命中修复',
  subtitle: '编辑记忆会重新生效，重新回复能直接命中缓存，阶段换代也不再丢掉整段历史缓存。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.edit_note_rounded,
      title: '编辑过的记忆立即生效',
      description: '长期记忆按内容版本跟踪，编辑或修改过的记忆会在下一轮自动重新注入，不用再等阶段换代。',
    ),
    ReleaseNoteItem(
      icon: Icons.replay_rounded,
      title: '重新回复直接命中缓存',
      description: '重新生成回复不再强制重置整个缓存阶段，请求前缀与上一轮一致时可直接命中，长对话重生成更省。',
    ),
    ReleaseNoteItem(
      icon: Icons.anchor_rounded,
      title: '阶段换代保住历史命中',
      description: '剧情检查点移到请求尾部，换代时固定协议、人设和窗口内历史继续命中缓存，只重新发送检查点与最新回合。',
    ),
    ReleaseNoteItem(
      icon: Icons.fact_check_outlined,
      title: '超预算时给出明确提示',
      description:
          '当协议、世界书、记忆与状态面板本身超出 Prompt 预算时，故事洞察会提示精简固定上下文或调大预算，避免缓存阶段反复重建。',
    ),
    ReleaseNoteItem(
      icon: Icons.library_books_outlined,
      title: '检查点不再漏掉内容',
      description:
          '检查点优先收录最近的记忆，且只把真正写入检查点的内容标记为已注入，超量记忆与世界书会继续随本轮快照注入，不再静默丢失。',
    ),
    ReleaseNoteItem(
      icon: Icons.speed_rounded,
      title: '自动预算统一为 64K',
      description:
          '非 DeepSeek 接口的自动 Prompt 预算从保守的 8.4K 提升到 64K，与 DeepSeek 官方接口一致；模型上下文偏小或中转站容易报错时，可在设置页手动选择更小的预算。',
    ),
  ],
);

const ReleaseNotes _v2101ReleaseNotes = ReleaseNotes(
  id: 'v2.10.1',
  version: 'V2.10.1',
  title: 'V2.10.1 上下文缓存优化',
  subtitle: '长对话会尽量复用稳定前缀，并在容量边界自动换代，减少重复输入成本。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.bolt_rounded,
      title: 'DeepSeek 缓存前缀更稳定',
      description: '固定协议、人设和常驻世界资料集中在前部，动态状态只在需要时注入，连续回复更容易命中上下文缓存。',
    ),
    ReleaseNoteItem(
      icon: Icons.layers_outlined,
      title: '长剧情按阶段滚动',
      description: '消息数量或 Token 预算到达边界时会生成阶段检查点，并从完整对话轮次开启新的缓存阶段。',
    ),
    ReleaseNoteItem(
      icon: Icons.tune_rounded,
      title: 'Prompt 预算可配置',
      description: '设置页可选择自动、8K、16K、32K、64K 或 128K；DeepSeek 官方接口的自动预算为 64K。',
    ),
    ReleaseNoteItem(
      icon: Icons.query_stats_outlined,
      title: '缓存效果可以核对',
      description: '故事洞察会记录命中、未命中、上一轮前缀覆盖率、缓存阶段和滚动原因。',
    ),
  ],
);

const ReleaseNotes _v2100ReleaseNotes = ReleaseNotes(
  id: 'v2.10.0',
  version: 'V2.10.0',
  title: 'V2.10.0 气泡与第一次开幕',
  subtitle: '装扮可以先看效果，新用户也能先玩一小段故事，再按自己的目标认识剧场。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.chat_bubble_outline_rounded,
      title: '气泡皮肤有了真正的轮廓',
      description: '便签折角、票根撕线、胶片齿孔、像素硬边和裂隙装饰不再只是换颜色，长短消息都会保持结构。',
    ),
    ReleaseNoteItem(
      icon: Icons.visibility_outlined,
      title: '装扮页直接实时预览',
      description: '每款气泡在购买、全局装备或绑定角色之前都会显示真实消息预览，自定义 CSS 气泡也使用同一套渲染结果。',
    ),
    ReleaseNoteItem(
      icon: Icons.rocket_launch_outlined,
      title: '第一次开幕先玩再学',
      description: '幕灯会用三条体验路线带你看故事回应、创建剧场和记忆连续性；界面操作仍由高亮引导一步步完成。',
    ),
    ReleaseNoteItem(
      icon: Icons.query_stats_outlined,
      title: '回复用量默认记录',
      description: '新配置会记录每次回复的大致生成消耗；连接的服务不支持时，可以在高级设置中关闭。',
    ),
  ],
);

const ReleaseNotes _v290ReleaseNotes = ReleaseNotes(
  id: 'v2.9.0',
  version: 'V2.9.0',
  title: 'V2.9.0 个性玩法系统公告',
  subtitle: '每个文游现在都能生成自己的变量体系：玩家看见舞台状态，创作者掌握幕后规则。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.auto_awesome_rounded,
      title: 'AI 生成剧本专属玩法',
      description: '角色创建后可以一键读取简介、开场和提示词，生成只属于当前题材的关系、资源、线索、暗线和触发规则。',
    ),
    ReleaseNoteItem(
      icon: Icons.visibility_outlined,
      title: '玩家面板与幕后参数',
      description: '公开变量显示精确值，模糊变量只显示阶段；导演变量和引擎变量留在创作者可查看的幕后面板。',
    ),
    ReleaseNoteItem(
      icon: Icons.rule_rounded,
      title: '变量更新经过规则校验',
      description: 'AI 只能更新当前剧本声明且授权的路径，数值范围、单轮变化量、列表操作和幕后权限都会由本地引擎检查。',
    ),
    ReleaseNoteItem(
      icon: Icons.account_tree_outlined,
      title: '变量跟随剧情分支',
      description: '玩法 Schema 跟随剧本保存，当前变量进入既有游戏状态和消息快照，导出、恢复与分支回退保持一致。',
    ),
  ],
);

const ReleaseNotes _v285ReleaseNotes = ReleaseNotes(
  id: 'v2.8.5',
  version: 'V2.8.5',
  title: 'V2.8.5 启动稳态公告',
  subtitle: '这次先把剧场入口守稳：启动立即有画面，本地数据出错时能看见阶段、复制诊断并直接重试。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.sensors_outlined,
      title: '首帧不再等待本地存档',
      description: 'Web 会先显示原生启动状态并使用包内渲染资源，再连接本地存储和音频插件，慢设备也不会只剩空白页面。',
    ),
    ReleaseNoteItem(
      icon: Icons.restart_alt_rounded,
      title: '初始化失败可以重试',
      description: '平台或数据初始化失败时会结束无限加载，保留原存档并提供重新布景入口，不需要退出应用。',
    ),
    ReleaseNoteItem(
      icon: Icons.fact_check_outlined,
      title: '启动阶段清楚可查',
      description: '读取设置、角色资料、存档校验和剧情现场恢复都有独立阶段，定位卡住的位置更直接。',
    ),
    ReleaseNoteItem(
      icon: Icons.content_copy_rounded,
      title: '一键复制启动诊断',
      description: '故障页可以复制版本、失败阶段、错误类型和堆栈，方便排查，同时不会自动清空本地数据。',
    ),
  ],
);

const ReleaseNotes _v284ReleaseNotes = ReleaseNotes(
  id: 'v2.8.4',
  version: 'V2.8.4 / 正式版 1.0',
  title: '正式版 1.0 入场',
  subtitle: '这次把发布前最重要的体验整理好：去掉内置 BGM，改成本地音频库，并补上新手教程演示。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.theater_comedy_outlined,
      title: '直接入场',
      description: '打开后即可进入小剧场，方便演示、试用和作品集展示。',
    ),
    ReleaseNoteItem(
      icon: Icons.library_music_outlined,
      title: '本地音频库',
      description: '音乐面板不再内置 BGM，改为上传你自己有权使用的音频文件，并可播放、重命名和整理歌单。',
    ),
    ReleaseNoteItem(
      icon: Icons.add_box_outlined,
      title: '音频格子',
      description: '初始提供 3 个音频格子，后续可用 30 啥币解锁新的本地音频格。',
    ),
    ReleaseNoteItem(
      icon: Icons.school_outlined,
      title: '新手教程模拟演示',
      description: '内置预设改为安全的新手教程演示，用 NPC1、NPC2、NPC3 带你熟悉创建、游玩、存档和设置。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '正式版启动资金',
      description: '正式版上线纪念福利已放进邮箱，可领取 200 啥币。',
    ),
  ],
);

const ReleaseNotes _v283ReleaseNotes = ReleaseNotes(
  id: 'v2.8.3',
  version: 'V2.8.3',
  title: 'V2.8.3 地图主线稳态公告',
  subtitle: '这次专门打磨地图模式：地图状态更稳，事件日志更准，坏格式会更早被拦住修好。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.map_outlined,
      title: '地图状态校验加强',
      description:
          '地图模式现在会检查 GAME_STATE、MAP_STATE、地点表、NPC 位置和下一步行动，发现缺字段、混入普通选项或行动太空泛时会先走格式修复。',
    ),
    ReleaseNoteItem(
      icon: Icons.event_note_outlined,
      title: '事件日志改用摘要',
      description:
          'MAP_STATE 新增 eventSummary 字段，地图事件记录优先保存一句本轮摘要，不再从长正文里硬截一段，长期游玩时更清爽。',
    ),
    ReleaseNoteItem(
      icon: Icons.rule_folder_outlined,
      title: '行动建议更具体',
      description:
          'activeChoices 收紧为 3-5 个可直接放入行动篮子的具体行动，减少“继续探索”“观察周围”这类点了也没信息量的空泛按钮。',
    ),
    ReleaseNoteItem(
      icon: Icons.translate_outlined,
      title: '用户可见地图文本更稳',
      description:
          '地点名、按钮文案、地点描述和场景摘要继续要求使用简体中文；后台 id 仍可用英文或拼音，但不会直接污染用户看到的地图文字。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_fix_high_outlined,
      title: '地图修复提示同步升级',
      description:
          '地图修复器现在也知道 eventSummary、3-5 个行动、中文可见文本和地点锁定规则，修坏格式时更不容易把旧地图改乱。',
    ),
  ],
);

const ReleaseNotes _v282ReleaseNotes = ReleaseNotes(
  id: 'v2.8.2',
  version: 'V2.8.2',
  title: 'V2.8.2 大型群聊模式公告',
  subtitle: '这次给文游模拟器新增大型群聊模式：旁白推进剧情，当前场景 NPC 分气泡发言，主线像群聊现场一样一条条冒出来。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.forum_outlined,
      title: '新增大型群聊模式',
      description:
          '创建或编辑模拟器时可以开启大型群聊模式；开启后 AI 回复会固定生成旁白和当前场景 NPC 的群聊气泡流，模式开启后不能退回普通文游。',
    ),
    ReleaseNoteItem(
      icon: Icons.record_voice_over_outlined,
      title: '旁白和 NPC 分工更清楚',
      description: '旁白负责动作、场景、心理和剧情推进，NPC 气泡只保留角色真正说出口的话，避免台词里混入动作描写。',
    ),
    ReleaseNoteItem(
      icon: Icons.dashboard_customize_outlined,
      title: '只保留状态面板',
      description: '大型群聊模式不会再注入六个行动选项和 HTML 美化框规则，只沿用现有游戏状态面板，减少格式打架。',
    ),
    ReleaseNoteItem(
      icon: Icons.sms_outlined,
      title: '随机 NPC 私聊节奏',
      description: '群聊主线会按 2-3 轮节奏自然触发当前场景 NPC 私聊；没有合适私聊时仍会保持主线群聊推进。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_fix_high_outlined,
      title: '群聊格式轻量修复',
      description: '如果模型偶尔漏掉群聊结构、误出选项或 HTML，App 会优先本地清理并尝试补回可展示的群聊气泡和状态块。',
    ),
  ],
);

const ReleaseNotes _v281ReleaseNotes = ReleaseNotes(
  id: 'v2.8.1',
  version: 'V2.8.1',
  title: 'V2.8.1 手机底栏与主题动效修复公告',
  subtitle: '这次专门处理两个手机端观感问题：雨巷电台的雨点不再串到其他 UI，底部输入栏和导航栏也改成更贴近微信的横向铺满样式。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.water_drop_outlined,
      title: '雨巷电台雨点不再残留',
      description: '聊天背景动效会跟随当前主题重新判断，切到没有雨效的 UI 后，聊天区里的雨点会立刻消失。',
    ),
    ReleaseNoteItem(
      icon: Icons.keyboard_alt_outlined,
      title: '输入栏边框横向铺满',
      description: '手机端主聊天输入区不再像浮动卡片一样左右留空，边框改为贴近屏幕两侧，内部输入框和按钮保持舒适间距。',
    ),
    ReleaseNoteItem(
      icon: Icons.space_bar_outlined,
      title: '底部导航改为整条底栏',
      description: '对话、角色、NPC 和设置导航改成贴边底栏，只保留内部选中态圆角，减少底部灰边和空白感。',
    ),
  ],
);

const ReleaseNotes _v280ReleaseNotes = ReleaseNotes(
  id: 'v2.8.0',
  version: 'V2.8.0',
  title: 'V2.8.0 通用缓存命中优化公告',
  subtitle:
      '这次重做主聊天请求结构：不绑定 DeepSeek 私有字段，不额外调用模型，让支持缓存的 API 更容易复用前缀，中转站和其他兼容接口也能照常使用。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.anchor_outlined,
      title: '稳定前缀更稳定',
      description: '主聊天第一段 system 只保留固定协议、角色设定和常驻前中部世界书，减少每轮状态变化打断缓存前缀。',
    ),
    ReleaseNoteItem(
      icon: Icons.article_outlined,
      title: '本轮资料进入用户快照',
      description:
          '当前状态、相关记忆、NPC 摘要、触发型世界书和导演指令会合并到用户消息里的隐藏上下文快照，仍是标准 Chat API 格式。',
    ),
    ReleaseNoteItem(
      icon: Icons.replay_circle_filled_outlined,
      title: '历史回合可复用 replay',
      description: '用户回合会保存当时的上下文快照，AI 回合会保存正文前缀；下一轮优先复用这些隐藏内容，提高连续对话的缓存友好度。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '不牺牲长正文',
      description:
          '主聊天 2000 字以上正文要求不变，HTML、状态块和选项仍不会被完整塞回历史请求，避免为了缓存反而扩大中转站成本。',
    ),
  ],
);

const ReleaseNotes _v279ReleaseNotes = ReleaseNotes(
  id: 'v2.7.9',
  version: 'V2.7.9',
  title: 'V2.7.9 手机端主题 UI 修复公告',
  subtitle: '这次专门收拾手机端主题界面：顶部和底部更轻，特色 UI 切换不再串背景，NPC 私聊也会跟着当前主题走。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.space_dashboard_outlined,
      title: '显示面板不再堆满首屏',
      description: '手机端继续剧情看板改成轻摘要，只保留关键任务或上次停留提示，详细状态仍可从剧情信息和游戏面板进入。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_awesome_motion_outlined,
      title: '特色 UI 动态背景不再串台',
      description: '主题背景会按当前主题和动态效果重新挂载，自定义主题没有指定动态效果时只显示自己的配色背景。',
    ),
    ReleaseNoteItem(
      icon: Icons.phone_android_outlined,
      title: '顶部和底部导航更轻',
      description: '主聊天手机顶栏和底边栏去掉厚边框，改为更接近手机系统导航的轻遮罩、图标和文字选中态。',
    ),
    ReleaseNoteItem(
      icon: Icons.sms_outlined,
      title: 'NPC 私聊顶栏适配主题',
      description: 'NPC 私聊页不再露出固定黑色顶栏，返回、选择、重回、导出和印象按钮都会使用当前主题色。',
    ),
  ],
);

const ReleaseNotes _v278ReleaseNotes = ReleaseNotes(
  id: 'v2.7.8',
  version: 'V2.7.8',
  title: 'V2.7.8 剧情显示修复公告',
  subtitle: '这次集中处理截图里暴露出的沉浸感、主题对比、NPC 详情滚动和上下文费用问题，让主聊天继续长文好读，但少把结构内容带进下一轮。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.auto_fix_high_outlined,
      title: '剧情正文不再露出实现说明',
      description:
          '强化输出协议并加入本地清理，过滤“完整自包含 HTML 状态面板、适配手机竖屏”等出戏说明，保留真正的剧情文字和可视化面板。',
    ),
    ReleaseNoteItem(
      icon: Icons.inventory_2_outlined,
      title: '裸状态字段不再混进正文',
      description:
          '当模型忘记包 [GAME_STATE] 时，App 会识别时间、地点、状态、任务、人物数据等连续状态面板，避免和正文重复显示。',
    ),
    ReleaseNoteItem(
      icon: Icons.contrast_outlined,
      title: '开局帷幕文字更清楚',
      description: '帷幕标题和副标题按当前主题帷幕颜色动态选择高对比文字，粉绿、浅色和自定义主题下更稳。',
    ),
    ReleaseNoteItem(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'NPC 详情展开后可滚动',
      description: '私聊页展开印象和羁绊时间线时会使用内部滚动区域，不再只能点折叠才能回到输入。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '历史上下文更省输入',
      description: '发给模型的历史助手回复会省略本地已保存的 HTML 面板、选项和状态块，减少未命中输入；长正文输出规则保持不变。',
    ),
  ],
);

const ReleaseNotes _v277ReleaseNotes = ReleaseNotes(
  id: 'v2.7.7',
  version: 'V2.7.7',
  title: 'V2.7.7 剧情舞台布局公告',
  subtitle: '这次把手机端聊天页往互动小说方向推进：场景、选项、快捷动作和剧情信息都更靠前，同时继续跟随当前主题色。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
        icon: Icons.theater_comedy_outlined,
        title: '手机端顶部改成剧情舞台条',
        description: '对话页会优先展示当前地点、时间、状态和本轮剧情目标，没有状态时也会自然退回角色与记忆信息。'),
    ReleaseNoteItem(
      icon: Icons.menu_book_outlined,
      title: '新增剧情信息抽屉',
      description: '右上角可打开当前剧情、在场角色、关系数值、最近记忆和游戏面板摘要，全部读取本地已有数据，不额外调用模型。',
    ),
    ReleaseNoteItem(
      icon: Icons.touch_app_outlined,
      title: '底部加入快捷动作',
      description: '手机端输入区新增继续、追问、靠近、观察、沉默、转移话题等动作按钮，点击后填入输入框，用户仍可编辑后再发送。',
    ),
    ReleaseNoteItem(
      icon: Icons.route_outlined,
      title: '剧情选项更像互动小说',
      description: 'AI 回复里的下一步选项默认展开，选中反馈更明显，并继续使用当前主题色，不会跳出原来的 UI 风格。',
    ),
  ],
);

const ReleaseNotes _v276ReleaseNotes = ReleaseNotes(
  id: 'v2.7.6',
  version: 'V2.7.6',
  title: 'V2.7.6 主题色补全公告',
  subtitle: '这次专门补齐主题覆盖：自定义主题、开场帷幕、互动面板和设置预设会更完整地跟随当前 UI 色彩。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.palette_outlined,
      title: '自定义主题不再露出默认底色',
      description: '首页背景、动态背景层、分享卡主题名和设置预设会识别自定义主题，不再把自定义主题误当成默认配色。',
    ),
    ReleaseNoteItem(
      icon: Icons.theater_comedy_outlined,
      title: '开场帷幕跟随当前主题',
      description: '拉开剧场帷幕的颜色会从当前主题推导，不再所有主题都显示同一套红金开屏。',
    ),
    ReleaseNoteItem(
      icon: Icons.web_asset_outlined,
      title: '互动面板预览更贴合主题',
      description: '聊天里的 HTML 互动面板和全屏预览改用当前主题面板色，浅色、深色和自定义主题切换时更统一。',
    ),
    ReleaseNoteItem(
      icon: Icons.error_outline_rounded,
      title: '弹窗状态色更一致',
      description: '导入、清理、存档、头像和 NPC 编辑里的提示卡片改用主题面板和主题错误色，减少固定黑白粉色跳出来的感觉。',
    ),
  ],
);

const ReleaseNotes _v275ReleaseNotes = ReleaseNotes(
  id: 'v2.7.5',
  version: 'V2.7.5',
  title: 'V2.7.5 上下文减负公告',
  subtitle: '这次不压短主线长文，而是把无效输入、世界书触发和用量观察整理得更稳，兼顾官方接口和中转站。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.rule_folder_outlined,
      title: '世界书按本轮触发',
      description: '常驻规则继续保留，关键词和正则世界书会根据最近对话、游戏状态和本轮资料本地匹配，命中后再进入主聊天。',
    ),
    ReleaseNoteItem(
      icon: Icons.psychology_alt_outlined,
      title: '长期记忆更会挑重点',
      description: '长期记忆会在保留近期摘要的同时，用本地关键词匹配补入和当前行动、地点、人物更相关的内容，减少无关旧记忆挤占上下文。',
    ),
    ReleaseNoteItem(
      icon: Icons.query_stats_outlined,
      title: '用量统计兼容优先',
      description: '新增增强流式用量统计开关，默认关闭；支持的接口可用于观察缓存命中，普通中转站不支持时也不会影响聊天。',
    ),
    ReleaseNoteItem(
      icon: Icons.speed_outlined,
      title: '后台抽取更克制',
      description: 'NPC 自动抽取增加本地节流和信号判断，能从状态块与近期内容判断没有新角色变化时，不再每轮额外麻烦模型。',
    ),
  ],
);

const ReleaseNotes _v274ReleaseNotes = ReleaseNotes(
  id: 'v2.7.4',
  version: 'V2.7.4',
  title: 'V2.7.4 阅读减压公告',
  subtitle: '这次继续打磨主聊天：右侧跳转控件更轻，正式剧情回复更接近轻小说的长段阅读体验。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.unfold_less_rounded,
      title: '上下跳转更不挡内容',
      description: '聊天区右侧的一键回顶部、回底部保留原功能，但去掉大边框和整块底板，改成两个独立小按钮，减少遮挡和误触。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_stories_outlined,
      title: '主聊天剧情更长',
      description: '正式剧情推进会按轻小说节奏扩写正文，更多场景、动作、对白和情绪铺垫；角色卡润色、听心声、摘要等小工具不会被强制拉长。',
    ),
    ReleaseNoteItem(
      icon: Icons.article_outlined,
      title: '长回复也要守格式',
      description:
          '正文扩写只发生在用户可读剧情里，HTML 面板、状态块、地图状态和下一步选项仍按原格式输出，降低长文导致掉结构的概率。',
    ),
  ],
);

const ReleaseNotes _v273ReleaseNotes = ReleaseNotes(
  id: 'v2.7.3',
  version: 'V2.7.3',
  title: 'V2.7.3 头像与倒带公告',
  subtitle: '这次把角色头像补到 NPC 和用户角色上，同时修正清空聊天记录后的 NPC 残留问题，让“倒带重来”更符合直觉。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.add_photo_alternate_outlined,
      title: 'NPC 可以上传头像',
      description: '新建或编辑 NPC 时可以选择本地图片作为头像，NPC 列表、私聊页和带 TA 走的预览都会沿用这张头像。',
    ),
    ReleaseNoteItem(
      icon: Icons.account_circle_outlined,
      title: '用户角色可以上传头像',
      description: '用户角色编辑页新增头像入口，绑定到文游后可以更清楚地区分不同主角人设。',
    ),
    ReleaseNoteItem(
      icon: Icons.restore_rounded,
      title: '清空聊天会同步清空本周目 NPC',
      description:
          '清空某个文游模拟器的聊天记录时，会一起移除这个模拟器里从剧情生成或本地创建的 NPC，并清理对应私聊记录；全局或跨世界复用的角色卡不会被误删。',
    ),
  ],
);

const ReleaseNotes _v272ReleaseNotes = ReleaseNotes(
  id: 'v2.7.2',
  version: 'V2.7.2',
  title: 'V2.7.2 NPC 私聊减压公告',
  subtitle: '这次专门整理 NPC 私聊：关系信息收起来，心声改成指定气泡触发，新建 NPC 也更容易补成完整角色卡。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.unfold_less_rounded,
      title: '关系面板可折叠',
      description: 'NPC 私聊顶部默认只保留好感度和羁绊摘要，展开后再查看当前印象、印象变化和羁绊时间线，聊天首屏更轻。 ',
    ),
    ReleaseNoteItem(
      icon: Icons.hearing_rounded,
      title: '指定气泡听心声',
      description: '“听心声”迁移到长按 NPC 气泡菜单，可以针对某一句话生成或重写心声；已生成的心声默认折叠在气泡下方。 ',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_fix_high_outlined,
      title: '创建 NPC 可 AI 补全',
      description:
          '新建或编辑 NPC 时，可以把已写的角色卡、简介、初始印象交给 AI 润色补全，并先预览再选择应用到空字段或全部应用。',
    ),
    ReleaseNoteItem(
      icon: Icons.timeline_rounded,
      title: '羁绊与印象更清楚',
      description: '羁绊阶段整理成时间线展示，当前印象改成差异提示卡，减少重复长文本压在聊天顶部的感觉。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.7.2 更新福利通过邮箱发放 50 啥币。',
    ),
  ],
);

const ReleaseNotes _v271ReleaseNotes = ReleaseNotes(
  id: 'v2.7.1',
  version: 'V2.7.1',
  title: 'V2.7.1 手机省电优化公告',
  subtitle: '这次是给手机端降温的小修：保留 2.7.0 的新布局，同时减少后台视觉动效和流式刷新带来的持续压力。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.battery_saver_outlined,
      title: '新增手机省电模式',
      description: '显示与交互里新增“手机省电模式”，手机端默认开启；需要更完整动效时可以手动关闭。',
    ),
    ReleaseNoteItem(
      icon: Icons.blur_off_outlined,
      title: '高级主题静态化',
      description: '省电模式下，花未必是花、机械城、雨声电台、天空牧场、黑胶回忆、旧日回响、裂隙中转站等高级主题不再持续播放背景动画。',
    ),
    ReleaseNoteItem(
      icon: Icons.speed_outlined,
      title: '流式回复更省资源',
      description: 'AI 仍会边生成边显示，但省电模式会降低中途刷新频率，减少长回复时的整屏重绘。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '修复福利',
      description: 'V2.7.1 修复福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v270ReleaseNotes = ReleaseNotes(
  id: 'v2.7.0',
  version: 'V2.7.0',
  title: 'V2.7.0 手机端界面重构公告',
  subtitle: '这次把手机端主界面重新整理成更像移动游戏的结构：顶部轻一点，底部少一栏，剧情内容更靠前。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.menu_open_rounded,
      title: '顶部工具收进菜单',
      description:
          '对话页手机端不再横向挤满工具按钮；小游戏中心、邮箱、NPC私聊、游戏面板、地图主线、剧情工具等入口统一收进左上角功能菜单，原功能和回调保持不变。',
    ),
    ReleaseNoteItem(
      icon: Icons.account_circle_outlined,
      title: '右上角直达用户',
      description: '用户页不再占用底部导航位置，点对话页右上角头像即可直接进入用户人设与偏好管理。',
    ),
    ReleaseNoteItem(
      icon: Icons.space_dashboard_outlined,
      title: '底部四栏更清爽',
      description: '手机端底部导航调整为“对话、角色、NPC、设置”四项，NPC 名称保留不变，减少小屏误触和拥挤感。',
    ),
    ReleaseNoteItem(
      icon: Icons.phone_android_outlined,
      title: '聊天第一屏更像游戏',
      description:
          '移动端对话页顶部只保留菜单、当前角色和用户入口，让当前角色卡、继续剧情、正文、选项和输入区更像一个完整的文字游戏界面。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.7.0 更新福利通过邮箱发放 70 啥币。',
    ),
  ],
);

const ReleaseNotes _v266ReleaseNotes = ReleaseNotes(
  id: 'v2.6.6',
  version: 'V2.6.6',
  title: 'V2.6.6 缓存命中优化公告',
  subtitle: '这次把 AI 请求结构理顺：固定设定更稳定，动态状态更靠后，连续游玩更容易吃到 DeepSeek 缓存。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.account_tree_outlined,
      title: '提示词分层重排',
      description:
          '主聊天请求改成固定协议与角色设定在前，聊天历史居中，用户人设、记忆、状态和本轮提醒在后。更利于缓存命中，同时保留原本的游玩信息。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_stories_outlined,
      title: '世界书顺序更稳定',
      description: '同优先级世界书不再因为编辑时间变化而频繁换位，常驻设定会以更稳定的顺序进入请求前缀。',
    ),
    ReleaseNoteItem(
      icon: Icons.rule_folder_outlined,
      title: '格式提醒继续兜底',
      description:
          'HTML、GAME_STATE、CHOICES 和地图模式规则仍会在本轮动态提示里复核，优化缓存的同时不牺牲回复结构。',
    ),
    ReleaseNoteItem(
      icon: Icons.speed_outlined,
      title: '缓存用量可观察',
      description:
          '兼容读取 DeepSeek 返回的 prompt_cache_hit_tokens 和 prompt_cache_miss_tokens，方便后续验证命中效果。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.6.6 更新福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v265ReleaseNotes = ReleaseNotes(
  id: 'v2.6.5',
  version: 'V2.6.5',
  title: 'V2.6.5 地图主线修复公告',
  subtitle: '这次专门修地图主线：悬浮球更干净，线索动向更克制，地点展示统一回到简体中文。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.map_outlined,
      title: '悬浮地图去掉数字干扰',
      description: '悬浮球左上角不再显示会越攒越大的线索数字，只保留行动篮子需要看的数量提示。',
    ),
    ReleaseNoteItem(
      icon: Icons.hub_outlined,
      title: '线索与动向瘦身',
      description: '地图会优先保留最新关键线索和最新 NPC 动向，并对相似内容做去重，避免回合多了以后越堆越乱。',
    ),
    ReleaseNoteItem(
      icon: Icons.assignment_outlined,
      title: '状态面板补完整',
      description:
          '地图主线提示词要求 GAME_STATE 覆盖时间、地点、状态、任务、人物数据、物品栏、关系网、剧情记录、NPC变化和 NPC更新。',
    ),
    ReleaseNoteItem(
      icon: Icons.chat_bubble_outline,
      title: 'NPC 主动消息接回私聊',
      description: '地图动向里出现 NPC 主动联系、搭话或发消息时，会同步进入对应 NPC 私聊，不再只停在地图摘要里。',
    ),
    ReleaseNoteItem(
      icon: Icons.translate_outlined,
      title: '地点展示统一中文',
      description: '后台地点 id 仍可使用英文或拼音，但用户看到的当前位置、地点名和行动按钮会使用简体中文兜底。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.6.5 修复福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v264ReleaseNotes = ReleaseNotes(
  id: 'v2.6.4',
  version: 'V2.6.4',
  title: 'V2.6.4 功能栏交互更新公告',
  subtitle: '这次把底部五栏改得更轻，顺手把角色删除入口补回到小屏卡片里。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.touch_app_outlined,
      title: '功能栏改成无边框',
      description: '对话、角色、NPC、用户和设置五个入口去掉常驻描边，只有选中、悬停或按下时会亮起来。',
    ),
    ReleaseNoteItem(
      icon: Icons.phone_android_outlined,
      title: '小屏也能删角色',
      description: '角色卡在紧凑布局下也会显示删除按钮，不再因为窗口宽度变窄而藏起来。',
    ),
    ReleaseNoteItem(
      icon: Icons.inventory_2_outlined,
      title: '产物命名归位',
      description: '双端打包产物改为“未完剧场+版本号”的命名方式，Web 和 Android 包更好识别。',
    ),
    ReleaseNoteItem(
      icon: Icons.verified_outlined,
      title: '发版流程同步',
      description: '发布 skill 已同步新的产物命名规则，后续版本会按同一标准验收。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.6.4 更新福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v263ReleaseNotes = ReleaseNotes(
  id: 'v2.6.3',
  version: 'V2.6.3',
  title: 'V2.6.3 同人文番外修复公告',
  subtitle: '这次专门修同人文：灵感先说话，主线只负责提供人物关系和性格参考。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.casino_outlined,
      title: '盲盒改为本地抽题',
      description: '开盲盒会先在本地从 1-99 灵感池抽出编号和题材，再把“#编号 灵感词”作为本篇灵感生成。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_stories_outlined,
      title: '番外优先服从灵感',
      description: '同人文提示词明确把自填灵感或盲盒灵感设为最高优先级，不再默认接着当前主线往下写。',
    ),
    ReleaseNoteItem(
      icon: Icons.account_tree_outlined,
      title: '主线资料降为参考',
      description: '游戏面板、世界书、长期记忆和最近聊天记录仍会注入，但只作为关系、性格、称呼和互动张力参考。',
    ),
    ReleaseNoteItem(
      icon: Icons.verified_outlined,
      title: '回归测试补强',
      description: '新增盲盒灵感池测试，锁住 1-99 题材编号、原文词条和本地抽取格式。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.6.3 修复福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v262ReleaseNotes = ReleaseNotes(
  id: 'v2.6.2',
  version: 'V2.6.2',
  title: 'V2.6.2 时间线回滚修复公告',
  subtitle: '这次专门修删除消息和剧情分支：状态、NPC 印象和分支时间线要一起回到正确位置。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.restore_outlined,
      title: '删除回复会回滚状态',
      description: '删除 AI 回复后，状态面板会回到上一回合；批量删除、编辑 AI 回复和重生成也会重新对齐当前状态。',
    ),
    ReleaseNoteItem(
      icon: Icons.people_alt_outlined,
      title: 'NPC 印象跟着回退',
      description:
          '主线 GAME_STATE 自动生成的 NPC 档案会按剩余历史重建，删除某回合后不会继续停留在被删除前的好感和印象。',
    ),
    ReleaseNoteItem(
      icon: Icons.account_tree_outlined,
      title: '分支不再继承未来 NPC',
      description: '从较早回合创建分支后，只会看到分支点之前已经存在或明确绑定到该分支的 NPC，主线后面才遇到的人不会穿越进来。',
    ),
    ReleaseNoteItem(
      icon: Icons.verified_outlined,
      title: '回归测试补强',
      description: '新增删除回滚、自动 NPC 移除、分支未来 NPC 隔离等测试，专门守住这次修复的时间线边界。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.6.2 修复福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v261ReleaseNotes = ReleaseNotes(
  id: 'v2.6.1',
  version: 'V2.6.1',
  title: 'V2.6.1 NPC 私聊修复公告',
  subtitle: '这次专门修 NPC 档案和私聊边界：状态归状态，聊天归聊天，列表也要看得见。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.people_alt_outlined,
      title: 'NPC 列表归位',
      description:
          'NPC更新 会稳定创建或更新 NPC 档案；绑定到当前角色、根角色或分支的 NPC 也会出现在当前世界 NPC 列表。',
    ),
    ReleaseNoteItem(
      icon: Icons.chat_bubble_outline_rounded,
      title: '私聊只留真话',
      description: '“等待回复中”“明日将联系”“信已传递”等状态句不会再被塞进 NPC 私聊气泡，NPC 私聊只保留真实聊天话语。',
    ),
    ReleaseNoteItem(
      icon: Icons.rule_folder_outlined,
      title: '状态边界收紧',
      description:
          'NPC变化 继续作为状态面板文本；NPC更新 才负责档案；主动消息会先判断是否像真实聊天，避免状态面板和私聊互相串台。',
    ),
    ReleaseNoteItem(
      icon: Icons.verified_outlined,
      title: '回归测试补强',
      description: '新增 NPC 状态过滤、GAME_STATE 解析和绑定 NPC 列表可见性的测试，防止同类问题下次偷偷回来。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.6.1 修复福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v260ReleaseNotes = ReleaseNotes(
  id: 'v2.6.0',
  version: 'V2.6',
  title: 'V2.6 框架升级公告',
  subtitle: '这次把底层更稳的几块补上：存档封套、AI 请求管线、NPC 运行状态和更新福利一起到位。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.inventory_2_outlined,
      title: 'V2 存档封套',
      description: '导出的数据包现在带 schema、版本号、时间戳和 checksum，导入时仍兼容旧存档，后续迁移也有落点。',
    ),
    ReleaseNoteItem(
      icon: Icons.account_tree_outlined,
      title: 'AI 请求管线',
      description: '聊天回复统一经过请求上下文、token 预算和 trace 记录，暂停流式回复也在同一条链路里处理。',
    ),
    ReleaseNoteItem(
      icon: Icons.hub_outlined,
      title: 'NPC 运行状态',
      description: 'NPC 会在剧情状态更新时沉淀心情、地点、目标、关系边、记忆和世界事件，后续跨轮表现更有连续性。',
    ),
    ReleaseNoteItem(
      icon: Icons.verified_outlined,
      title: '回归测试补强',
      description: '新增存档封套、token 估算和 NPC runtime 的测试，减少底层升级时的手滑风险。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.6 更新福利通过邮箱发放 70 啥币。',
    ),
  ],
);

const ReleaseNotes _v255ReleaseNotes = ReleaseNotes(
  id: 'v2.5.5',
  version: 'V2.5.5',
  title: 'V2.5.5 轻量操控公告',
  subtitle: '这次只做小而实用的聊天体验：看 token、少占屏、可暂停。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.speed_outlined,
      title: 'Token 估算',
      description: '聊天气泡底部会像时间戳一样显示本条消息或本轮请求的近似 tokens，方便判断上下文负担。',
    ),
    ReleaseNoteItem(
      icon: Icons.unfold_less_rounded,
      title: '行动选项默认折叠',
      description: 'AI 生成的下一步行动选项默认收起，需要时点「展开」再看，长聊天回看旧记录更省滚动距离。',
    ),
    ReleaseNoteItem(
      icon: Icons.pause_circle_outline_rounded,
      title: '发射键可暂停',
      description: '触发 AI 回复后，发射键会切换为暂停键；如果手滑点错或想中断当前回复，再点一次即可暂停。',
    ),
    ReleaseNoteItem(
      icon: Icons.tune_outlined,
      title: '保持小版本边界',
      description: 'V2.5.5 不扩大战线，只围绕聊天区空间、可控性和请求体感做轻量优化。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.5.5 更新福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v254ReleaseNotes = ReleaseNotes(
  id: 'v2.5.4',
  version: 'V2.5.4',
  title: 'V2.5.4 地图公告',
  subtitle: '地图主线现在更像剧情导航仪：看目标、看地点状态，也能追 NPC 在哪里。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.explore_outlined,
      title: '主线罗盘',
      description: '地图页顶部新增主线罗盘，集中展示当前阶段、目标、时间、地点和推荐下一步，回到长剧情时不再容易迷路。',
    ),
    ReleaseNoteItem(
      icon: Icons.place_outlined,
      title: '地点状态卡',
      description: '当前地点会单独展示状态、风险、耗时、相关 NPC、线索和可做行动，地点棋盘不再只是地点列表。',
    ),
    ReleaseNoteItem(
      icon: Icons.people_alt_outlined,
      title: 'NPC 位置追踪',
      description: 'MAP_STATE 新增 npcPositions，地图页可显示重要 NPC 的所在地点、状态、意图和最后出现时间。',
    ),
    ReleaseNoteItem(
      icon: Icons.route_outlined,
      title: '地图协议补强',
      description:
          '地图 AI 输出要求补齐 npcPositions，并继续维护 currentScene、locations、activeChoices、线索和 NPC 动向，后续地图推进更稳定。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.5.4 更新福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v253ReleaseNotes = ReleaseNotes(
  id: 'v2.5.3',
  version: 'V2.5.3',
  title: 'V2.5.3 美化公告',
  subtitle: '六套基础色换成更耐读的杂志式界面，剧情也能做成漂亮分享卡了。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.palette_outlined,
      title: '基础六色杂志式升级',
      description:
          '雾粉紫、杏桃日落、雾蓝破晓、鼠尾草薄荷、月柠浅雾和森林莓晨露保留原本配色身份，整体卡片、气泡和面板改成更低噪音、更像出版物内页的阅读风格。',
    ),
    ReleaseNoteItem(
      icon: Icons.article_outlined,
      title: '剧情分享卡',
      description:
          '聊天工具栏新增剧情分享卡，可把最近剧情或已勾选消息生成带当前主题色的长图式 HTML 卡片，方便打开后截图、下载或分享。',
    ),
    ReleaseNoteItem(
      icon: Icons.view_agenda_outlined,
      title: '导出模式补强',
      description: '导出模式现在不仅能导出 HTML 聊天记录，也能把所选消息直接做成剧情分享卡，适合只截取一个精彩回合。',
    ),
    ReleaseNoteItem(
      icon: Icons.text_fields_outlined,
      title: '基础主题字体层级调整',
      description: '基础主题里的标题和剧情阅读区域更偏衬线出版感，按钮、输入和功能区继续保持清晰可操作。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_awesome_outlined,
      title: '分享卡保留当前主题',
      description: '生成的剧情卡会读取当前主题色，基础六色能分别产出对应的纸面、标题、边框和选项块效果。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.5.3 更新福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v252ReleaseNotes = ReleaseNotes(
  id: 'v2.5.2',
  version: 'V2.5.2',
  title: 'V2.5.2 修复公告',
  subtitle: 'NPC 私聊回到私聊本位，网页也少背一点行李再开场。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.forum_outlined,
      title: 'NPC 私聊归位',
      description:
          '底部 NPC 入口仍叫 NPC 私聊，只显示当前世界 NPC；已整理成角色卡但来源属于当前世界的 NPC 仍会正常出现。',
    ),
    ReleaseNoteItem(
      icon: Icons.badge_outlined,
      title: '角色库不混入私聊',
      description:
          '跨世界绑定或全局绑定的 NPC 角色卡不再混进别的世界 NPC 私聊与来信箱，避免打开 A 世界时看见 B 世界的人。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_fix_high_outlined,
      title: '创建 NPC 可 AI 帮写',
      description: '新建 NPC 时可以填一点人物灵感，让 AI 生成名字、简介、初始印象和完整角色卡，再由用户继续微调。',
    ),
    ReleaseNoteItem(
      icon: Icons.speed_outlined,
      title: 'Web 启动减负',
      description: '网页端存档保护仍保留，但大型本地备份改为启动后延迟刷新，减少公网部署后的白屏等待。',
    ),
    ReleaseNoteItem(
      icon: Icons.music_note_outlined,
      title: '音乐资源瘦身',
      description: '背景音乐重新压缩到更适合 Web 分发的体积，并把加载超时提示改得更明确，不影响聊天和存档。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.5.2 修复福利通过邮箱发放 30 啥币。',
    ),
  ],
);

const ReleaseNotes _v251ReleaseNotes = ReleaseNotes(
  id: 'v2.5.1',
  version: 'V2.5.1',
  title: 'V2.5.1 修复公告',
  subtitle: 'NPC 终于有了自己的门牌，分支也不再把未来偷渡回过去。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.badge_outlined,
      title: '新增 NPC 页',
      description: '底部功能栏新增 NPC 入口，已整理成角色卡的 NPC 会集中展示；原世界 NPC 私聊仍然保留并可正常聊天。',
    ),
    ReleaseNoteItem(
      icon: Icons.rule_folder_outlined,
      title: 'NPC 角色库去重',
      description: '修复创建分支或整理角色卡后，同一个 NPC 在角色库里重复显示的问题，旧数据加载时也会自动合并重复卡。',
    ),
    ReleaseNoteItem(
      icon: Icons.edit_outlined,
      title: '完整角色卡可编辑',
      description: 'NPC 角色卡详情新增编辑入口，可直接修改完整角色卡、简介、印象和绑定信息。',
    ),
    ReleaseNoteItem(
      icon: Icons.fork_right_outlined,
      title: '分支读取历史状态',
      description: '从早期消息创建分支时，会优先读取该消息附近的历史状态快照，不再带入结局后的 NPC 印象、人物和状态面板。',
    ),
    ReleaseNoteItem(
      icon: Icons.palette_outlined,
      title: '森林莓晨露改色',
      description: '森林莓晨露改成莓果粉主色调，晨露绿作为辅助色，和鼠尾草薄荷明显拉开差异。',
    ),
    ReleaseNoteItem(
      icon: Icons.public_outlined,
      title: '世界观生成更像设定',
      description: '“只生成世界观”改为设定集导向，重点写世界运行逻辑、规则、势力、文化、冲突和进入接口。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.5.1 修复福利通过邮箱发放 50 啥币。',
    ),
  ],
);

const ReleaseNotes _v250ReleaseNotes = ReleaseNotes(
  id: 'v2.5.0',
  version: 'V2.5',
  title: 'V2.5 更新公告',
  subtitle: 'NPC 会收礼，也会有心声；创作和世界书都少一点折腾。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: 'NPC 送礼与心声',
      description: 'NPC 私聊输入框左侧新增工具菜单，可送背包剧情道具或购买小卖部商品送礼，也能听听当前气泡里 TA 的心声。',
    ),
    ReleaseNoteItem(
      icon: Icons.badge_outlined,
      title: 'NPC 角色库补完',
      description: '补全角色卡后的 NPC 仍可私聊、编辑、查看详情并绑定到其他世界，角色库不再只是一个不能点开的简介。',
    ),
    ReleaseNoteItem(
      icon: Icons.travel_explore_outlined,
      title: '带走 NPC 双出口',
      description: '带 TA 走现在可选择生成可游玩的新世界，或只保存前尘世界观；新世界提示词更贴近创建模拟器模板，状态面板也更统一。',
    ),
    ReleaseNoteItem(
      icon: Icons.upload_file_outlined,
      title: '文档生成提示词',
      description:
          '创建角色时，“帮你写”和“自己写”都支持上传 md、json、doc、docx、txt 等文本类文件，AI 可基于文档生成或润色提示词。',
    ),
    ReleaseNoteItem(
      icon: Icons.replay_circle_filled_outlined,
      title: '重生成更可控',
      description: '主聊天和 NPC 私聊点重新回复时会弹出方向输入框，留空直接重生，填写后会作为隐藏要求加入本轮重生成。',
    ),
    ReleaseNoteItem(
      icon: Icons.menu_book_outlined,
      title: '世界书简化',
      description: '世界书删除触发方式配置，改为按绑定、全局、注入位置和优先级稳定注入，少一个容易玩懵的开关。',
    ),
    ReleaseNoteItem(
      icon: Icons.psychology_alt_outlined,
      title: '记忆、分支和番外',
      description: '长期记忆可手动新增编辑；早期消息创建分支会读取对应历史状态；同人文盲盒直接生成并自动拟标题。',
    ),
    ReleaseNoteItem(
      icon: Icons.palette_outlined,
      title: '主题与前尘修补',
      description: '鼠尾草薄荷和森林莓晨露配色拉开差异；前尘档案馆滚动、前尘回声触发和带走 NPC 沉浸提示词一起修补。',
    ),
    ReleaseNoteItem(
      icon: Icons.savings_outlined,
      title: '更新福利',
      description: 'V2.5 版本福利通过邮箱发放 70 啥币。',
    ),
  ],
);

const ReleaseNotes _v242ReleaseNotes = ReleaseNotes(
  id: 'v2.4.2',
  version: 'V2.4.2',
  title: 'V2.4.2 更新公告',
  subtitle: '手机端不再只剩省略号，NPC 也有了正式角色库。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.phone_android_outlined,
      title: '手机端换行优化',
      description: '角色页、NPC 库、唱片机、设置页、世界书、背包和弹窗都减少省略号，标题、简介和关键说明会优先换行展示。',
    ),
    ReleaseNoteItem(
      icon: Icons.badge_outlined,
      title: 'NPC 角色库',
      description: 'NPC 可整理成干净可复用角色卡，角色页和 NPC 库会单独展示，并保留查看角色卡、绑定到世界和重新补全入口。',
    ),
    ReleaseNoteItem(
      icon: Icons.hub_outlined,
      title: '绑定流程升级',
      description:
          '绑定到世界前会提示先补全 NPC 角色卡；绑定后的 NPC 会作为可自主行动的同行 NPC / 重要配角注入目标模拟器。',
    ),
    ReleaseNoteItem(
      icon: Icons.tune_rounded,
      title: '设置目录补全',
      description: '设置页 API、记忆、显示、预设、存档和说明六个目录都可点击跳转，并新增当前目录高亮与轻提示。',
    ),
    ReleaseNoteItem(
      icon: Icons.music_note_outlined,
      title: '唱片机手机重排',
      description: '当前播放卡片改为纵向信息和独立控制行，长歌名和下拉选歌不再被切成一字一行。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '更新福利',
      description: 'V2.4.2 手机端适配、NPC 角色库、设置目录补全版本福利通过邮箱发放 50 啥币。',
    ),
  ],
);

const ReleaseNotes _v241ReleaseNotes = ReleaseNotes(
  id: 'v2.4.1',
  version: 'V2.4.1',
  title: 'V2.4.1 更新公告',
  subtitle: '开幕之前，先亲手拉开帷幕。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.theater_comedy_outlined,
      title: '拖拽开幕',
      description: '进入应用时新增剧场帷幕层，桌面端用鼠标、手机端用手指拖开帷幕后再进入正式界面。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_stories_outlined,
      title: '开场白',
      description: '开幕页加入“故事不是被写完才开始；当你拉开帷幕，它才获得命运。”，让进入剧场更有仪式感。',
    ),
    ReleaseNoteItem(
      icon: Icons.music_note_outlined,
      title: '开幕后接上音乐',
      description: '拉开帷幕本身就是一次用户手势，开幕后会自动尝试播放当前唱片机曲目，网页端也更符合浏览器播放规则。',
    ),
    ReleaseNoteItem(
      icon: Icons.devices_rounded,
      title: '网页和手机共用',
      description: '开幕层使用 Flutter 原生绘制，Web、PWA 和 Android 共用同一套视觉与交互。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '更新福利',
      description: 'V2.4.1 开幕帷幕版本福利通过邮箱发放 41 啥币。',
    ),
  ],
);

const ReleaseNotes _v240ReleaseNotes = ReleaseNotes(
  id: 'v2.4.0',
  version: 'V2.4',
  title: 'V2.4 更新公告',
  subtitle: '找得到、回得去、不怕丢：大剧场终于有了总控台。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.search_rounded,
      title: '全局搜索',
      description: '顶部新增全局搜索，可同时查角色、聊天、消息书签、NPC、世界书、剧情工具、同人文和前尘档案。',
    ),
    ReleaseNoteItem(
      icon: Icons.history_rounded,
      title: '继续上次剧情',
      description: '聊天页新增继续看板，回到故事时能直接看到上次停在哪、当前任务、未读 NPC、邮箱和书签。',
    ),
    ReleaseNoteItem(
      icon: Icons.bookmark_added_rounded,
      title: '消息书签',
      description: '每条聊天消息都能加入书签并写备注，关键告白、伏笔、分歧点和重要线索以后都能一键找回。',
    ),
    ReleaseNoteItem(
      icon: Icons.health_and_safety_outlined,
      title: '自动保护快照',
      description: '清空记录、删除角色、批量删消息和导入覆盖前会自动保存保护快照，误操作后更容易恢复。',
    ),
    ReleaseNoteItem(
      icon: Icons.tune_rounded,
      title: '设置页目录',
      description: '设置页新增快速目录，API、记忆、显示、预设、存档迁移和说明入口都能直接跳转。',
    ),
    ReleaseNoteItem(
      icon: Icons.touch_app_outlined,
      title: '消息操作更清楚',
      description: '消息操作补上书签入口和书签标识，手机端长按、桌面端悬停都能更快处理重要内容。',
    ),
    ReleaseNoteItem(
      icon: Icons.backup_outlined,
      title: '存档更安心',
      description: '自动保护快照会控制数量，避免无限膨胀；手动快照和导入导出流程继续保留。',
    ),
    ReleaseNoteItem(
      icon: Icons.fact_check_outlined,
      title: '文档和交接同步',
      description: 'README、用户手册、工作说明和交接文档同步更新到 V2.4，后续维护能直接接上。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '更新福利',
      description: 'V2.4 总控台版本福利通过邮箱发放 100 啥币。',
    ),
  ],
);

const ReleaseNotes _v231ReleaseNotes = ReleaseNotes(
  id: 'v2.3.1',
  version: 'V2.3.1',
  title: 'V2.3.1 更新公告',
  subtitle: 'NPC 角色卡与世界绑定：把喜欢的人带进更多故事里。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.badge_outlined,
      title: 'NPC 角色卡',
      description: 'NPC 库新增完整角色卡字段，手动创建的 NPC 和带走的 NPC 都能整理成可复用角色资产。',
    ),
    ReleaseNoteItem(
      icon: Icons.hub_outlined,
      title: '绑定世界',
      description: 'NPC 可以绑定到指定模拟器，也可以设为全局绑定；进入剧情后会作为另一个主角自主行动。',
    ),
    ReleaseNoteItem(
      icon: Icons.travel_explore_outlined,
      title: '带走 NPC 双路径',
      description: '带 TA 走现在既能生成专属新世界模拟器，也能只生成 NPC 角色卡，再绑定到别的世界一起玩。',
    ),
    ReleaseNoteItem(
      icon: Icons.auto_fix_high_outlined,
      title: 'AI 补全角色卡',
      description: '编辑 NPC 时可让 AI 根据主线、私聊、印象和羁绊补全身份、性格、目标、说话风格和跨世界行动规则。',
    ),
    ReleaseNoteItem(
      icon: Icons.public_outlined,
      title: '只生成世界观',
      description: '创建文游模拟器的“帮你写”新增完整模拟器 / 只生成世界观两档，方便带着玩家和绑定 NPC 进入新舞台。',
    ),
    ReleaseNoteItem(
      icon: Icons.psychology_alt_outlined,
      title: '自主行动规则',
      description: '主线提示词会明确：玩家只操控自己，绑定 NPC 会自行判断和行动，但不能替玩家做决定。',
    ),
    ReleaseNoteItem(
      icon: Icons.music_note_outlined,
      title: 'Web 背景音乐修复',
      description: '公网 Web 包补上音乐插件注册和首次交互补播，打开页面会尽量自动接上背景音乐。',
    ),
    ReleaseNoteItem(
      icon: Icons.backup_outlined,
      title: '部署存档保护',
      description: 'Web 端本地存档改用稳定前缀并自动迁移旧数据，同时写入浏览器备份，更新部署目录时更不容易丢存档。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '更新福利',
      description: 'V2.3.1 NPC 角色卡版本福利通过邮箱发放 50 啥币。',
    ),
  ],
);

const ReleaseNotes _v230ReleaseNotes = ReleaseNotes(
  id: 'v2.3.0',
  version: 'V2.3',
  title: 'V2.3 更新公告',
  subtitle: '前尘档案馆与再续前缘：旧世界告别后，新世界继续生长。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.waving_hand_outlined,
      title: '旧世界告别',
      description: '点“带 TA 走”后先选择要不要告别：可跳过、只留一句、自己写，或让 AI 生成一场旧世界最后回合。',
    ),
    ReleaseNoteItem(
      icon: Icons.route_outlined,
      title: '再续前缘路线锁',
      description: '迁徙配置新增关系路线：跟随旧羁绊、恋人、挚友、宿敌、共犯、守护、师徒、破镜、不恋爱化或自然变化。',
    ),
    ReleaseNoteItem(
      icon: Icons.history_edu_outlined,
      title: '前尘档案馆',
      description: '角色页新增独立档案馆，可搜索、分组、查看来源、告别、迁徙档案、世界书、角色卡、开场白、信物、任务、回声和纪念册。',
    ),
    ReleaseNoteItem(
      icon: Icons.person_pin_circle_outlined,
      title: '前尘新世界分组',
      description: '角色页拆成主舞台角色、前尘新世界和剧情分支，带走的 NPC 不再混在普通角色里。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '信物、任务、回声',
      description: '迁徙成功会保存前尘信物和关系任务；迁徙角色聊天页可触发前尘回声，让旧世界自然回到当前剧情。',
    ),
    ReleaseNoteItem(
      icon: Icons.construction_outlined,
      title: '迁徙重修台与纪念册',
      description: '前尘档案支持 AI 重修指定部分，并可手动把重要片段加入双人纪念册。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '更新福利',
      description: 'V2.3 前尘档案馆版本福利通过邮箱发放 120 啥币。',
    ),
  ],
);

const ReleaseNotes _v220ReleaseNotes = ReleaseNotes(
  id: 'v2.2.0',
  version: 'V2.2',
  title: 'V2.2 更新公告',
  subtitle: '带走 NPC 变成真正的迁徙仪式：先看清前尘，再确认新世界。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.fact_check_outlined,
      title: '迁徙预览确认',
      description: '带 TA 走不再直接写入角色列表，AI 会先生成旧世界档案、前尘世界书、新角色卡和开场白，确认后才创建。',
    ),
    ReleaseNoteItem(
      icon: Icons.memory_outlined,
      title: '三档记忆强度',
      description: '迁徙时可选择完整记得、片段记得或只留熟悉感，新世界会按不同记忆强度处理前尘关系。',
    ),
    ReleaseNoteItem(
      icon: Icons.travel_explore_outlined,
      title: '迁徙记录',
      description:
          '每次带走都会保存来源 NPC、新角色、前尘世界书、选项和生成结果；旧 NPC 卡片会显示 TA 已经被带去哪个新世界。',
    ),
    ReleaseNoteItem(
      icon: Icons.person_pin_circle_outlined,
      title: '新角色来源标记',
      description: '由 NPC 迁徙生成的角色会在角色列表和详情里标出来源，不再像凭空出现的新角色。',
    ),
    ReleaseNoteItem(
      icon: Icons.import_export_rounded,
      title: '导出导入保留链路',
      description: '数据存档会带上 NPC 迁徙记录，换设备后仍能知道 TA 从哪个旧世界、哪个 NPC 被带来。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '更新福利',
      description: 'V2.2 带走 NPC 重构福利通过邮箱发放 80 啥币。',
    ),
  ],
);

const ReleaseNotes _v214ReleaseNotes = ReleaseNotes(
  id: 'v2.1.4',
  version: 'V2.1.4',
  title: 'V2.1.4 更新公告',
  subtitle: '地图主线回到聊天里：读长剧情，用悬浮地图组织下一步。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.map_outlined,
      title: '聊天内悬浮地图',
      description: '地图主线不再把你带到独立小页面，聊天页会显示可拖动悬浮地图，点开就能看地点、线索和主线提示。',
    ),
    ReleaseNoteItem(
      icon: Icons.shopping_basket_outlined,
      title: '行动篮子',
      description: '点地点、调查线索、找 NPC 或输入自由行动都会先放入行动篮子，确认后才统一推进本回合。',
    ),
    ReleaseNoteItem(
      icon: Icons.public_rounded,
      title: '稳定大地图',
      description: '首次生成 6-7 个大地点，后续锁定地点 id 和名称，只更新状态、NPC、线索、风险、时间成本和推荐行动。',
    ),
    ReleaseNoteItem(
      icon: Icons.verified_outlined,
      title: '地图状态校验',
      description: '地图回复会校验 MAP_STATE，格式坏掉会自动低温修复；修复失败时旧地图和行动篮子都会保留。',
    ),
    ReleaseNoteItem(
      icon: Icons.wrap_text_rounded,
      title: '手机端更好读',
      description: '游戏状态面板、地图地点、线索、NPC 动向和行动建议都允许换行展示，不再靠省略号藏关键信息。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '更新福利',
      description: 'V2.1.4 地图主线重构福利通过邮箱发放 50 啥币。',
    ),
  ],
);

const ReleaseNotes _v213ReleaseNotes = ReleaseNotes(
  id: 'v2.1.3',
  version: 'V2.1.3',
  title: 'V2.1.3 更新公告',
  subtitle: '世界书升级成上下文调度器，设定终于能按时登场了。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.auto_stories_outlined,
      title: '世界书稳定注入',
      description: '世界书按绑定范围、注入位置和优先级进入提示词，适合硬设定、世界观、地点、NPC、道具和事件资料。',
    ),
    ReleaseNoteItem(
      icon: Icons.vertical_align_center_rounded,
      title: '前中后注入位置',
      description: '每条世界书可以选择前部、中部或后部注入：文风和禁令放前面，世界观放中间，当前剧情提醒放后面。',
    ),
    ReleaseNoteItem(
      icon: Icons.sort_rounded,
      title: '优先级排序',
      description: '世界书新增 0-100 优先级，同一注入位置会优先放入更重要的条目，避免关键设定被普通资料挤下去。',
    ),
    ReleaseNoteItem(
      icon: Icons.memory_outlined,
      title: '更友好的上下文缓存',
      description: '常驻和稳定内容更靠前，按需触发的世界书更靠后，减少每轮动态资料对提示词前缀缓存的影响。',
    ),
    ReleaseNoteItem(
      icon: Icons.card_giftcard_outlined,
      title: '更新福利',
      description: 'V2.1.3 世界书专项更新福利通过邮箱发放 50 啥币。',
    ),
  ],
);

const ReleaseNotes _v211ReleaseNotes = ReleaseNotes(
  id: 'v2.1.1',
  version: 'V2.1.1',
  title: 'V2.1.1 更新公告',
  subtitle: '电脑端网页版唱片机补丁，先把按钮和滑动救回来。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.mouse_outlined,
      title: '电脑端可点可拖',
      description: '修复电脑端网页版唱片机按钮、音量、循环、下拉和歌单操作不响应的问题，横向选歌也支持鼠标和触控板拖动。',
    ),
    ReleaseNoteItem(
      icon: Icons.view_carousel_outlined,
      title: '滑动切歌',
      description: '在唱片卡片滑到已解锁歌曲时会直接切歌，并减少和小游戏中心外层分页手势抢事件的情况。',
    ),
    ReleaseNoteItem(
      icon: Icons.error_outline_rounded,
      title: '播放失败提示',
      description: 'Web 音频加载或播放失败时会显示错误提示，不再像没点到一样安静失败。',
    ),
  ],
);

const ReleaseNotes _v210ReleaseNotes = ReleaseNotes(
  id: 'v2.1.0',
  version: 'V2.1',
  title: 'V2.1 更新公告',
  subtitle: '剧场唱片机开张，聊天终于有自己的背景音乐了。',
  items: <ReleaseNoteItem>[
    ReleaseNoteItem(
      icon: Icons.library_music_outlined,
      title: '剧场唱片机',
      description: '小游戏中心新增唱片机页，支持播放、暂停、上一首、下一首、音量、单曲循环和歌单循环。',
    ),
    ReleaseNoteItem(
      icon: Icons.style_outlined,
      title: '主题曲库',
      description: '14 首背景音乐对应现有主题，六首基础主题曲默认解锁，其余主题曲可用 70 啥币永久解锁。',
    ),
    ReleaseNoteItem(
      icon: Icons.view_carousel_outlined,
      title: '滑动卡片与下拉切歌',
      description: '歌曲支持横向滑动卡片选择，也能用下拉列表快速切歌；未解锁歌曲会显示解锁价格。',
    ),
    ReleaseNoteItem(
      icon: Icons.playlist_play_outlined,
      title: '自定义歌单',
      description: '已解锁歌曲可加入歌单，支持移出、播放和拖拽排序，歌单顺序会随本地存档保存。',
    ),
    ReleaseNoteItem(
      icon: Icons.emoji_events_outlined,
      title: '音乐成就与福利',
      description: '新增播放、切歌、解锁、歌单和主题曲彩蛋成就；V2.1 更新福利通过邮箱发放 70 啥币。',
    ),
  ],
);

const List<ReleaseNotes> releaseNotesHistory = <ReleaseNotes>[
  currentReleaseNotes,
  _v2111ReleaseNotes,
  _v2110ReleaseNotes,
  _v2105ReleaseNotes,
  _v2104ReleaseNotes,
  _v2103ReleaseNotes,
  _v2102ReleaseNotes,
  _v2101ReleaseNotes,
  _v2100ReleaseNotes,
  _v290ReleaseNotes,
  _v285ReleaseNotes,
  _v284ReleaseNotes,
  _v283ReleaseNotes,
  _v282ReleaseNotes,
  _v281ReleaseNotes,
  _v280ReleaseNotes,
  _v279ReleaseNotes,
  _v278ReleaseNotes,
  _v277ReleaseNotes,
  _v276ReleaseNotes,
  _v275ReleaseNotes,
  _v274ReleaseNotes,
  _v273ReleaseNotes,
  _v272ReleaseNotes,
  _v271ReleaseNotes,
  _v270ReleaseNotes,
  _v266ReleaseNotes,
  _v265ReleaseNotes,
  _v264ReleaseNotes,
  _v263ReleaseNotes,
  _v262ReleaseNotes,
  _v261ReleaseNotes,
  _v260ReleaseNotes,
  _v255ReleaseNotes,
  _v254ReleaseNotes,
  _v253ReleaseNotes,
  _v252ReleaseNotes,
  _v251ReleaseNotes,
  _v250ReleaseNotes,
  _v242ReleaseNotes,
  _v241ReleaseNotes,
  _v240ReleaseNotes,
  _v231ReleaseNotes,
  _v230ReleaseNotes,
  _v220ReleaseNotes,
  _v214ReleaseNotes,
  _v213ReleaseNotes,
  _v211ReleaseNotes,
  _v210ReleaseNotes,
  ReleaseNotes(
    id: 'v2.0.5',
    version: 'V2.0.5',
    title: 'V2.0.5 更新公告',
    subtitle: '长聊天减负，导入和数据统计也少一点原地发呆。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.speed_outlined,
        title: '聊天解析缓存',
        description: '聊天消息的 Markdown、选项和 HTML 解析结果会按内容复用，长记录来回滚动时不用反复拆同一段文本。',
      ),
      ReleaseNoteItem(
        icon: Icons.unfold_less_rounded,
        title: '旧 HTML 面板默认折叠',
        description: '最近回复仍会自动显示美化框，较早消息的 HTML 面板会先折叠，点击展开或全屏时才真正渲染。',
      ),
      ReleaseNoteItem(
        icon: Icons.file_open_outlined,
        title: '大存档预览后台化',
        description: '导入较大的 JSON 存档时，预览解析会放到后台处理，减少 2-3MB 文件把页面卡住的情况。',
      ),
      ReleaseNoteItem(
        icon: Icons.storage_outlined,
        title: '数据体积统计变轻',
        description: '数据清理器改为直接读取本地存储 key 的大小，不再为了估算 MB 重新拼一整份导出包。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '性能专项福利',
        description: 'V2.0.5 性能专项福利通过邮箱发放 50 啥币，给长聊天减负工程报销一点茶水。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v2.0.4',
    version: 'V2.0.4',
    title: 'V2.0.4 更新公告',
    subtitle: '带走 NPC 返工成真正的双人文游模拟器，前尘不再复制粘贴。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.auto_awesome_outlined,
        title: '带走 NPC 分段生成',
        description: '迁徙流程拆成旧世界档案、专属世界书、角色模拟器三段 AI 生成，减少世界书内容重复，也让信息更完整。',
      ),
      ReleaseNoteItem(
        icon: Icons.sports_esports_outlined,
        title: '新角色仍是文游模拟器',
        description:
            '带走后生成的角色会继续要求纯文本剧情、HTML 美化框、GAME_STATE 和 CHOICES，故事主体只围绕你和 TA 展开。',
      ),
      ReleaseNoteItem(
        icon: Icons.record_voice_over_outlined,
        title: '叙事人称可选择',
        description: '带走 NPC 弹窗新增第二人称、第一人称、第三人称选项，生成提示词和世界书都会跟着写入对应叙事要求。',
      ),
      ReleaseNoteItem(
        icon: Icons.menu_book_outlined,
        title: '前尘世界书不再重复',
        description: '迁徙生成的世界书改为单一标签展示，世界书列表按主标签分组，避免同一本书在多个分组里反复出现。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '小修福利',
        description: 'V2.0.4 修补更新福利通过邮箱发放 50 啥币，算是给前尘返工师傅的茶水钱。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v2.0.3',
    version: 'V2.0.3',
    title: 'V2.0.3 更新公告',
    subtitle: '未完剧场正式改名，自定义主题工坊也开门营业。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.css_outlined,
        title: '自定义主题工坊',
        description: '设置页新增 200 啥币自定义主题格子，可选择已有主题做底稿，再用 CSS 变量覆盖成自己的全局样式。',
      ),
      ReleaseNoteItem(
        icon: Icons.palette_outlined,
        title: '可复制、可导入、可预览',
        description: '主题编辑器内置示例 CSS，支持复制、填入、导入 .css/.txt，并在保存前实时预览色彩和聊天气泡效果。',
      ),
      ReleaseNoteItem(
        icon: Icons.theater_comedy_outlined,
        title: '新名字：未完剧场',
        description: '应用标题、PWA 名称和 Android 显示名同步改为“未完剧场”，故事没写完，剧场先亮灯。',
      ),
      ReleaseNoteItem(
        icon: Icons.swap_horiz_rounded,
        title: '桌面工具栏可横滑',
        description: '顶部工具栏按钮变多后，桌面端也会显示横向滚动条，不会再把后面的按钮硬挤出屏幕。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '新成就与福利',
        description: '新增自定义主题相关成就和“主题裁缝”称号，并发放 V2.0.3 小版本 50 啥币福利。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v2.0.2',
    version: 'V2.0.2',
    title: 'V2.0.2 更新公告',
    subtitle: '气泡装扮开放自定义，NPC 私聊也终于穿上边框了。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.css_outlined,
        title: '自定义气泡格子',
        description: '装扮页新增 50 啥币自定义气泡格子，可输入名称、介绍和 CSS 子集样式，保存后可全局装备。',
      ),
      ReleaseNoteItem(
        icon: Icons.content_copy_outlined,
        title: '示例 CSS',
        description: '编辑器内置可复制示例，也支持导入 .css/.txt 文件；用户可以直接改，或丢给别的 AI 生成新的气泡样式。',
      ),
      ReleaseNoteItem(
        icon: Icons.chat_bubble_outline_rounded,
        title: '角色专属气泡',
        description: '气泡边框支持全局装备，也可以绑定当前角色；主聊天按“角色专属 > 全局”自动生效。',
      ),
      ReleaseNoteItem(
        icon: Icons.sms_outlined,
        title: 'NPC 私聊适配',
        description: 'NPC 私聊消息气泡也会读取当前气泡边框或自定义气泡，不再只有主聊天能换装。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '新成就与福利',
        description: '新增自定义气泡相关成就，并发放 V2.0.2 小版本 50 啥币福利。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v2.0.1',
    version: 'V2.0.1',
    title: 'V2.0.1 更新公告',
    subtitle: '羁绊路线在手机端更顺手，气泡边框也先摊开给你挑。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.phone_android_outlined,
        title: 'NPC 卡片窄屏修复',
        description: 'NPC 私聊列表在手机端会改用更紧凑的资料卡布局，头像、简介、操作按钮和状态胶囊不再互相挤压。',
      ),
      ReleaseNoteItem(
        icon: Icons.route_outlined,
        title: '羁绊状态更清楚',
        description: '“未知线”会在列表里自动收起，长羁绊标签会省略显示，避免把胶囊撑破。',
      ),
      ReleaseNoteItem(
        icon: Icons.chat_bubble_outline_rounded,
        title: '气泡边框清单',
        description: '整理当前全部气泡边框的名称、风格和来源，为下一步重构做准备。',
      ),
      ReleaseNoteItem(
        icon: Icons.preview_outlined,
        title: '边框预览 HTML',
        description: '新增静态预览页，商店款和转盘限定款分开展示，可切换浅底、暗底和花非花纸底。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '小版本福利',
        description: 'V2.0.1 修补更新福利已加入邮箱，送你 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v2.0.0',
    version: 'V2.0.0',
    title: 'V2.0.0 更新公告',
    subtitle: '喜欢的 NPC 不必留在旧世界里，羁绊也不再只是一个好感数字。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.travel_explore_outlined,
        title: '带走 NPC',
        description: 'NPC 私聊页新增“带 TA 走”，可让 AI 补全角色卡，把喜欢的 NPC 带到只属于你们的新世界。',
      ),
      ReleaseNoteItem(
        icon: Icons.route_outlined,
        title: '羁绊路线',
        description: 'NPC 档案新增阶段、路线倾向、羁绊进度、关键词和节点历史，主线与私聊都会继续沉淀关系。',
      ),
      ReleaseNoteItem(
        icon: Icons.auto_fix_high_outlined,
        title: 'AI 补全设定',
        description: '带走时会整理旧世界印象、私聊片段和羁绊节点，生成独立角色、开场白和绑定世界书。',
      ),
      ReleaseNoteItem(
        icon: Icons.translate_outlined,
        title: '印象中文化',
        description:
            'NPC 私聊后保存的印象会清理 summary、affinityDelta、attitude 等英文标签，只展示简体中文。',
      ),
      ReleaseNoteItem(
        icon: Icons.palette_outlined,
        title: '主题适配',
        description: '羁绊路线和带走 NPC 的界面跟随当前主题，个性化 UI 也补上专属文案。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '新成就',
        description: '新增“我带你走”“关系不是数字”“旧世界的回音”等羁绊和迁徙成就。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.9',
    version: 'V1.9.9',
    title: 'V1.9.9 更新公告',
    subtitle: '晴空牧场、黑胶往事两套 100 啥币主题上新，成就系统和手机端显示继续扩容。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.wb_sunny_outlined,
        title: '新增晴空牧场',
        description: '100 啥币解锁，小赖字体全局应用，云朵、草坡和轻亮配色一起上新，首次装扮可解锁专属成就。',
      ),
      ReleaseNoteItem(
        icon: Icons.album_outlined,
        title: '新增黑胶往事',
        description: '100 啥币解锁，思源宋体搭配霞鹜文楷，旋转黑胶唱片、唱针和复古咖啡馆质感一起上新。',
      ),
      ReleaseNoteItem(
        icon: Icons.font_download_outlined,
        title: '裂隙字体重构',
        description: '裂隙中转站全局切换为字体传奇特战体，保留原主题文案和彩蛋。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '成就系统扩容',
        description: '同人文、主题首装扮、存档、导入、数据清理器和世界书批量绑定都新增成就，隐藏成就解锁后会标记“隐藏”。',
      ),
      ReleaseNoteItem(
        icon: Icons.phone_android_outlined,
        title: '手机端显示优化',
        description: '游戏状态面板长文本会自动换行，角色卡窄屏只保留头像、名称和一句简介。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利补发',
        description: '补发 V1.9.8 更新福利，并发放 V1.9.9 小版本 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.8',
    version: 'V1.9.8',
    title: 'V1.9.8 更新公告',
    subtitle: '花非花、机械迷城和雨巷电台三套个性 UI 重构，动态背景和预置字体一起上新。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.settings_suggest_outlined,
        title: '机械迷城 UI 重构',
        description: '主题改成青铜齿轮质感，导航按钮、聊天背景和页面氛围都同步统一。',
      ),
      ReleaseNoteItem(
        icon: Icons.local_florist_outlined,
        title: '花非花 UI 重构',
        description: '接入文鼎 PL 简中楷体作为预置字体，保留特色文案，并加入水墨花影和飘落花瓣。',
      ),
      ReleaseNoteItem(
        icon: Icons.water_drop_outlined,
        title: '雨巷电台 UI 重构',
        description: '雨点改成分布式随机落下，搭配玻璃水纹和安静的雨夜蓝灰色。',
      ),
      ReleaseNoteItem(
        icon: Icons.dashboard_customize_outlined,
        title: '付费主题按钮布局调整',
        description: '三套个性化 UI 的宽屏导航改成更有场景感的横向按钮，保留功能同时更像解锁外观。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.7',
    version: 'V1.9.7',
    title: 'V1.9.7 更新公告',
    subtitle: '背包、存档、导入预览、数据清理器和六套莫兰迪基础主题一起补强。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.delete_sweep_outlined,
        title: '背包批量删除',
        description: '功能券背包和剧情物品栏新增批量管理，可单选、全选、分类全选并删除所选。',
      ),
      ReleaseNoteItem(
        icon: Icons.save_as_outlined,
        title: '存档快照',
        description: '设置页新增当前角色存档快照，可保存、恢复、删除；它是回到保存点，不是新 IF 线。',
      ),
      ReleaseNoteItem(
        icon: Icons.manage_search_outlined,
        title: '导入前预览和数据清理器',
        description: '导入 JSON 前会显示角色、消息、NPC、世界书等概要；清理器可查看数据体积并清缓存。',
      ),
      ReleaseNoteItem(
        icon: Icons.sell_outlined,
        title: '世界书标签和批量绑定',
        description: '世界书支持标签分组、筛选、批量绑定角色、批量设全局和批量删除，界面继续跟随当前主题。',
      ),
      ReleaseNoteItem(
        icon: Icons.palette_outlined,
        title: '六套基础主题重构',
        description: '粉紫、日落、破晓、薄荷、月柠、森莓全部去霓虹，改成更清爽的低饱和莫兰迪配色。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.6',
    version: 'V1.9.6',
    title: 'V1.9.6 更新公告',
    subtitle: '存档迁移补强：导入数据现在可以直接选择本地文件。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.upload_file_outlined,
        title: '导入支持上传文件',
        description: '设置页导入数据弹窗新增选择存档文件入口，可直接读取 JSON/TXT 存档内容。',
      ),
      ReleaseNoteItem(
        icon: Icons.description_outlined,
        title: '文件信息提示',
        description: '选择文件后会显示文件名和大小，并把内容填入导入框，方便确认后再导入。',
      ),
      ReleaseNoteItem(
        icon: Icons.content_paste_outlined,
        title: '粘贴入口保留',
        description: '原来的粘贴 JSON 方式仍然保留，也新增清空内容按钮，临时换存档更顺手。',
      ),
      ReleaseNoteItem(
        icon: Icons.ios_share_outlined,
        title: '导出文件名更新',
        description: '安全存档、完整存档和单角色存档的导出文件名同步到 V1.9.6。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.5',
    version: 'V1.9.5',
    title: 'V1.9.5 更新公告',
    subtitle: '地图主线大迭代：地图页现在能直接看剧情、点行动、推进主线。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.auto_stories_outlined,
        title: '地图内直接读主线',
        description: 'AI 生成后的当前场景、主线阶段和目标会直接显示在地图页，不用退出到聊天记录里翻。',
      ),
      ReleaseNoteItem(
        icon: Icons.touch_app_rounded,
        title: '下一步行动可点击',
        description: '地图主线会保存 3-5 个下一步行动，点一下加入下一回合计划，再统一推进。',
      ),
      ReleaseNoteItem(
        icon: Icons.map_outlined,
        title: '地点棋盘升级',
        description: '地点会显示当前位置、可前往、已探索、锁定、隐藏等状态，并记录 NPC、线索和地点摘要。',
      ),
      ReleaseNoteItem(
        icon: Icons.forum_outlined,
        title: '一键带入聊天',
        description: '地图页新增带入聊天入口，会把当前阶段、目标、地点、场景和可选行动同步到聊天。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.4',
    version: 'V1.9.4',
    title: 'V1.9.4 更新公告',
    subtitle: '世界书长内容收起，头像上传和新手教程导览也补齐了。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.menu_book_rounded,
        title: '世界书长内容折叠',
        description: '世界书内容过长时列表只显示预览，点击展开会居中打开完整内容，并可直接编辑保存。',
      ),
      ReleaseNoteItem(
        icon: Icons.upload_file_rounded,
        title: '模拟器头像上传',
        description: '创建或编辑角色时可从手机/电脑本地选择图片作为头像，并在角色列表和聊天概览中显示。',
      ),
      ReleaseNoteItem(
        icon: Icons.assistant_navigation,
        title: '新手教程重做',
        description: '教程扩充为更细的流式导览，每一步都有箭头指向目标区域，并新增右上角 skip。',
      ),
      ReleaseNoteItem(
        icon: Icons.workspace_premium_outlined,
        title: '乖宝宝 / 坏宝宝成就',
        description: '完整看完教程或直接跳过教程都可各解锁一个 20 啥币成就，设置页回看教程也能补拿。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.2',
    version: 'V1.9.2',
    title: 'V1.9.2 更新公告',
    subtitle: '长期记忆改成可管理入口，查看、编辑和删除都更顺手。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.auto_stories_outlined,
        title: '整理长期记忆',
        description: '长期记忆收缩为按钮入口，点开后可以逐条查看。',
      ),
      ReleaseNoteItem(
        icon: Icons.edit_note_rounded,
        title: '记忆可编辑',
        description: '每条长期记忆都支持编辑和删除，并会保存到本地缓存。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.9.2 小版本福利将通过邮箱发放 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.1',
    version: 'V1.9.1',
    title: 'V1.9.1 更新公告',
    subtitle: '小修一轮：优化 AI 回复格式稳定性，手机长按操作也更顺手。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.rule_rounded,
        title: '优化回复格式',
        description: '强化剧情回复的格式稳定性，降低只生成纯文字、不生成面板和选项的概率。',
      ),
      ReleaseNoteItem(
        icon: Icons.touch_app_rounded,
        title: '调整手机长按菜单',
        description: '手机端长按消息后，操作菜单改为屏幕中间弹窗。',
      ),
      ReleaseNoteItem(
        icon: Icons.nightlife_outlined,
        title: '调整黑心小卖部',
        description: '黑心小卖部改为点击后生成高价怪货，每次看货或重开货单收取 10 啥币。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.9.1 小版本福利将通过邮箱发放 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.9.0',
    version: 'V1.9',
    title: 'V1.9 更新公告',
    subtitle: '剧情掌控更细，地图开局更稳，同时关闭试玩入口。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.movie_filter_outlined,
        title: '新增剧情导演台',
        description: '可以给下一回合临时加氛围、镜头重点和补充要求，只影响一次回复，不会污染角色提示词。',
      ),
      ReleaseNoteItem(
        icon: Icons.casino_outlined,
        title: '新增地图开局生成器',
        description: '地图主线第一次生成前，会先给出出身、起点、目标等开局选择，选好后再生成地图。',
      ),
      ReleaseNoteItem(
        icon: Icons.event_note_outlined,
        title: '新增世界事件日历',
        description: '可以生成未来事件节奏表，后续回复会参考它埋伏笔、回收事件，适合长线文游。',
      ),
      ReleaseNoteItem(
        icon: Icons.dynamic_feed_outlined,
        title: '剧情工具补充',
        description: '新增 NPC 日记和世界论坛，生成结果独立保存，不会混进主聊天记录。',
      ),
      ReleaseNoteItem(
        icon: Icons.power_settings_new_rounded,
        title: '关闭试玩入口',
        description: '设置页不再提供试玩开关，源码中的预置接口与密钥已移除，想玩必须配置自己的 API。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.9 大版本福利将通过邮箱发放 70 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.8.1',
    version: 'V1.8.1',
    title: 'V1.8.1 更新公告',
    subtitle: '优化 AI 请求结构，尽量提高缓存命中，同时继续把格式协议放在最高优先级。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.account_tree_outlined,
        title: '提示词结构重排',
        description: '请求会按“固定协议、角色设定、动态状态”的顺序组织，降低掉格式风险，也更适合 DeepSeek 缓存。',
      ),
      ReleaseNoteItem(
        icon: Icons.lock_outline_rounded,
        title: '隐藏协议继续隐藏',
        description: '角色编辑界面仍然只显示用户该看的角色设定，底层格式协议和运行开关不会暴露出来。',
      ),
      ReleaseNoteItem(
        icon: Icons.map_outlined,
        title: '地图主线同步优化',
        description: '地图主线的生成请求也改为同样的分层结构，避免地图模式下协议和角色设定互相抢位置。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.8.1 小版本福利将通过邮箱发放 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.8.0',
    version: 'V1.8.0',
    title: 'V1.8.0 更新公告',
    subtitle: '啥币经济系统大扩容：转盘、黑市、鉴定、合成、债务和 NPC 回礼都来了。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.casino_outlined,
        title: '新增幸运转转转',
        description: '3 啥币转一次，包含大奖、小奖励、谢谢惠顾、限定称号和限定气泡碎片，并加入保底机制。',
      ),
      ReleaseNoteItem(
        icon: Icons.storefront_outlined,
        title: '新增黑心小卖部',
        description: '每天刷新怪货，可能买到效果未知的剧情物品；啥币不够时可以赊账，老板会记小本本。',
      ),
      ReleaseNoteItem(
        icon: Icons.manage_search_rounded,
        title: '新增鉴定与合成',
        description: '未知道具可花 3 啥币鉴定；两个剧情物品可花 5 啥币合成一个更怪的新东西。',
      ),
      ReleaseNoteItem(
        icon: Icons.volunteer_activism_outlined,
        title: 'NPC 回礼与名场面',
        description: '剧情物品投入主线后，NPC 可能回赠专属物品；道具触发的高光片段会保存为名场面记录。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.8.0 大版本福利将通过邮箱发放 70 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.7.2',
    version: 'V1.7.2',
    title: 'V1.7.2 更新公告',
    subtitle: '啥币经济系统补齐：功能券不扰主线，剧情物品正式接入主线。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.backpack_outlined,
        title: '剧情物品栏可用可销毁',
        description: '自定义商品和神秘小卖部商品会进入当前角色的剧情物品栏，可以投入主线，也可以直接销毁。',
      ),
      ReleaseNoteItem(
        icon: Icons.storefront_outlined,
        title: '神秘小卖部补齐',
        description: '点击看看好货会按当前世界观生成 5 件剧情商品，买下后只属于当前模拟器。',
      ),
      ReleaseNoteItem(
        icon: Icons.local_activity_outlined,
        title: '功能券边界更清楚',
        description: '商店剧情券、变小孩喷雾、兽耳魔药等功能券仍只生成小剧场或工具内容，不会改动主线。',
      ),
      ReleaseNoteItem(
        icon: Icons.favorite_border_rounded,
        title: 'NPC 好感与印象拆分',
        description: 'NPC 好感度会作为数值单独显示，印象继续保存为文字判断，后续剧情读取更清楚。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.7.2 小版本福利已发放，记得去邮箱领取 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.7.1',
    version: 'V1.7.1',
    title: 'V1.7.1 更新公告',
    subtitle: '地图主线继续打磨：分支可删除、地图可全屏，行动也能先排队再结算。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.call_split_rounded,
        title: '剧情分支可删除',
        description: '不想玩的 if 线可以直接删掉，主线和其他分支不会被牵连。',
      ),
      ReleaseNoteItem(
        icon: Icons.fullscreen_rounded,
        title: '地图支持全屏阅读',
        description: '交互地图右侧留出滑动区，也新增全屏阅读入口，手机端查看更舒服。',
      ),
      ReleaseNoteItem(
        icon: Icons.playlist_add_check_rounded,
        title: '地图行动计划',
        description: '地点和行动可以先加入下一回合计划，再统一推进时间与剧情。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.7.1 小版本福利已发放，记得去邮箱领取 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.6.2',
    version: 'V1.6.2',
    title: 'V1.6.2 更新公告',
    subtitle: '修复主题显示与模拟器生成稳定性，并补充一批新成就。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.auto_fix_high_rounded,
        title: '优化 AI 帮写模拟器',
        description: '清理会和隐藏规则打架的生成约束，开盲盒和手动灵感生成的提示词更干净。',
      ),
      ReleaseNoteItem(
        icon: Icons.casino_outlined,
        title: '优化开盲盒题材范围',
        description: '普通版和怀旧版开盲盒的题材池重新整理，减少单调跑偏。',
      ),
      ReleaseNoteItem(
        icon: Icons.local_florist_outlined,
        title: '修复花非花显示',
        description: '优化花非花主题下的聊天气泡和边框对比度。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '新增成就',
        description: '新增 15 个非隐藏成就，并同步整理项目里的成就清单文档。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.6.2 更新福利通过邮箱发放 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.6.1',
    version: 'V1.6.1',
    title: 'V1.6.1 更新公告',
    subtitle: '新增「花非花」主题，并继续收尾 V1.6 的固定工作。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.local_florist_outlined,
        title: '新增花非花主题',
        description: '新增灰白旧纸与暗红花痕风格主题「花非花」，100 啥币解锁，首次切换可解锁成就。',
      ),
      ReleaseNoteItem(
        icon: Icons.sms_outlined,
        title: 'NPC 私聊消息能力拉满',
        description: 'NPC 私聊现在和主聊天一样强：可以删除、编辑、重新回复、多选批量删除和导出记录。',
      ),
      ReleaseNoteItem(
        icon: Icons.dashboard_customize_outlined,
        title: '游戏面板格式更稳',
        description: '[GAME_STATE] 解析抗干扰升级，不再被塞进 F 选项；面板文字自动换行，手机端更好看。',
      ),
      ReleaseNoteItem(
        icon: Icons.terminal_rounded,
        title: '世界书系统上线',
        description: '新建角色旁边新增世界书按钮。可以给模拟器注入内容边界、行文风格和世界观补充，全局生效或绑定特定角色。',
      ),
      ReleaseNoteItem(
        icon: Icons.storefront_outlined,
        title: '商店小剧场重做 + 四个新道具',
        description: '所有商店道具统一改为居中流式小剧场弹窗。新增变小孩喷雾、兽耳魔药、摸一摸和真心话棒棒糖。',
      ),
      ReleaseNoteItem(
        icon: Icons.fullscreen_outlined,
        title: 'HTML 内容全屏查看',
        description: '商店生成的和聊天中出现的 HTML 小剧场都支持全屏，手机党想细看终于不用双指缩放了。',
      ),
      ReleaseNoteItem(
        icon: Icons.code_outlined,
        title: '格式工具换新',
        description:
            '长按消息里的"修复格式"升级为格式说明和插入工具，一键插入 [GAME_STATE]、[CHOICES]、[BUBBLE] 等代码。',
      ),
      ReleaseNoteItem(
        icon: Icons.visibility_outlined,
        title: '深渊观测站彩蛋重做',
        description: '切换克苏鲁主题后体验更沉浸：三分钟后居中弹出流式文字，之后每隔一段时间随机出现低语...还有隐藏成就等你发现。',
      ),
      ReleaseNoteItem(
        icon: Icons.auto_fix_high_rounded,
        title: 'AI 帮写模拟器输出更强',
        description: '生成的文游模拟器更稳定地输出 HTML 美化内容 + 六个选项，不再退化成纯文本。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '版本福利',
        description: 'V1.6.1 更新福利通过邮箱发放 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.5.5',
    version: 'V1.5.5',
    title: 'V1.5.5 更新公告',
    subtitle: '新增体验模式，并优化裂隙中转站与主题体验。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.play_circle_outline_rounded,
        title: '新增体验模式',
        description: '设置页新增试玩入口，开启后无需填写 API 也能先体验聊天。',
      ),
      ReleaseNoteItem(
        icon: Icons.memory_outlined,
        title: '优化裂隙中转站',
        description: '调整主题字体与 NPC 命名，让小世界和宿主语义更清楚。',
      ),
      ReleaseNoteItem(
        icon: Icons.visibility_outlined,
        title: '新增主题彩蛋',
        description: '新增主题彩蛋，用户可自行游玩体验...👁 👁',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.5.4',
    version: 'V1.5.4',
    title: 'V1.5.4 更新公告',
    subtitle: '新增一套需要啥币解锁的终端系 UI 主题。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.memory_outlined,
        title: '新增裂隙中转站',
        description: '新增低饱和灰蓝终端风主题，界面文案会切换成任务、宿主、世界线风格。',
      ),
      ReleaseNoteItem(
        icon: Icons.lock_open_outlined,
        title: '主题可用啥币解锁',
        description: '裂隙中转站需要 100 啥币解锁，解锁后可在设置页保存启用。',
      ),
      ReleaseNoteItem(
        icon: Icons.mail_outline_rounded,
        title: '更新福利',
        description: 'V1.5.4 更新福利会通过邮箱发放 50 啥币。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.5.3',
    version: 'V1.5.3',
    title: 'V1.5.3 更新公告',
    subtitle: '这次微调主题、装扮、成就和开盲盒体验。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.visibility_outlined,
        title: '优化主题文字',
        description: '克苏鲁和愚人节主题的界面文案覆盖更完整。',
      ),
      ReleaseNoteItem(
        icon: Icons.auto_awesome_outlined,
        title: '优化装扮显示',
        description: '气泡边框会更直观地显示在聊天气泡上。',
      ),
      ReleaseNoteItem(
        icon: Icons.casino_outlined,
        title: '优化开盲盒',
        description: '新增“开盲盒（怀旧版）”，保留经典传统文游口味。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '新增成就',
        description: '补充主题、装扮、商店、盲盒和工具箱相关成就。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.5.2',
    version: 'V1.5.2',
    title: 'V1.5.2 更新公告',
    subtitle: '这次补齐小游戏中心的反馈体验，并新增克苏鲁风格 UI 主题。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.hourglass_top_rounded,
        title: '商店生成有等待提示',
        description: '使用商店功能券时，会显示“商店老板努力中...”，让你知道 AI 正在生成结果，不是卡住了。',
      ),
      ReleaseNoteItem(
        icon: Icons.vertical_align_top_rounded,
        title: '成功提示改到顶层',
        description: '购买、领取啥币、装备装扮等提示会显示在屏幕顶部，不容易再被弹窗、底栏或输入框挡住。',
      ),
      ReleaseNoteItem(
        icon: Icons.auto_awesome_outlined,
        title: '装扮入口更清楚',
        description: '装扮页增加说明：称号、边框、贴纸买完后就在本页装备，当前装扮也会集中显示。',
      ),
      ReleaseNoteItem(
        icon: Icons.school_outlined,
        title: '新手教程补充小游戏功能',
        description: '教程新增啥币、每日任务、商店、背包、装扮、成就、NPC 来信箱和剧情工具说明。',
      ),
      ReleaseNoteItem(
        icon: Icons.visibility_outlined,
        title: '新增克苏鲁主题',
        description: '新增“深渊观测站”UI：暗红封印、旧纸噪点、深渊低语感命名。只改变界面，不改变角色提示词。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.5.1',
    version: 'V1.5.1',
    title: 'V1.5.1 更新公告',
    subtitle: '这次主要调整愚人节特调主题、恢复主面板剧情工具，并给商店换上一批新的趣味功能券。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.bug_report_outlined,
        title: '愚人节特调重做',
        description: '愚人节特调改成病毒故障风：终端绿、报警红、扫描线、破损窗口和乱码 UI 文案。',
      ),
      ReleaseNoteItem(
        icon: Icons.auto_fix_high_rounded,
        title: '剧情工具回归主面板',
        description: '上集提要、人物关系图、存档封面、伏笔本和分支预演重新回到聊天页顶部，直接点就能用。',
      ),
      ReleaseNoteItem(
        icon: Icons.storefront_outlined,
        title: '商店换新货',
        description: '商店改卖吐槽小剧场、论坛热帖、NPC 八卦小报、路人视角、谣言公告栏等趣味券。',
      ),
      ReleaseNoteItem(
        icon: Icons.history_rounded,
        title: '生成记录可回看',
        description: '商店券生成的工具结果会进入历史生成记录，NPC 来信券则会保存在 NPC 来信/私聊记录里。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.5',
    version: 'V1.5',
    title: 'V1.5 史诗级更新公告',
    subtitle: '这次把小程序往“私人文字游戏机”方向推了一大步：新增啥币、商店、背包、成就、装扮、陪伴等级和 NPC 来信箱。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.savings_outlined,
        title: '新增啥币系统',
        description: '聊天、每日任务、成就和签到都能获得啥币，用来购买剧情功能券和装扮。',
      ),
      ReleaseNoteItem(
        icon: Icons.storefront_outlined,
        title: '新增商店和背包',
        description: '前情回顾、预演选项、NPC 来信、伏笔放大镜、关系雷达等功能改成买券后在背包里使用，不再挤在主面板上。',
      ),
      ReleaseNoteItem(
        icon: Icons.emoji_events_outlined,
        title: '新增成就和称号',
        description: '加入一大批搞怪成就，例如“宫里来新人了”“我只是想给每个人一个家”“来也匆匆去也匆匆？”。',
      ),
      ReleaseNoteItem(
        icon: Icons.auto_awesome_outlined,
        title: '新增装扮系统',
        description: '可以装备称号、边框和小贴纸，部分装扮默认拥有，更多装扮可用啥币购买或通过成就解锁。',
      ),
      ReleaseNoteItem(
        icon: Icons.favorite_border_rounded,
        title: '新增陪伴等级',
        description: '和同一个 AI 角色聊得越多，陪伴等级越高；这只影响本地 UI 和玩法记录，不会改模型本身。',
      ),
      ReleaseNoteItem(
        icon: Icons.mark_email_unread_outlined,
        title: '新增 NPC 来信箱',
        description: 'NPC 主动消息会集中展示；也可以花 NPC 来信券或每天随机触发一封来信。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.4.3',
    version: 'V1.4.3',
    title: 'V1.4.3 更新公告',
    subtitle: '这次新增一个完全不同的手绘主题，并修复了游戏面板在小屏上的文字挤压问题。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.gesture_rounded,
        title: '新增愚人节特调',
        description: '新增手绘贴纸风主题，深色纸张底配低饱和便签色，走怪味路线但不使用霓虹效果。',
      ),
      ReleaseNoteItem(
        icon: Icons.palette_outlined,
        title: '主题列表扩充',
        description: '设置页现在可以在原有主题之外选择“愚人节特调”，适合想换点怪风格的时候用。',
      ),
      ReleaseNoteItem(
        icon: Icons.dashboard_customize_outlined,
        title: '游戏面板显示修复',
        description: '修复手机端游戏面板标题被挤成竖排的问题，时间、地点和状态会自动换行展示。',
      ),
      ReleaseNoteItem(
        icon: Icons.fit_screen_outlined,
        title: '小屏空间优化',
        description: '游戏面板弹窗在手机上更宽一些，列表文字有更多显示空间。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.4.2',
    version: 'V1.4.2',
    title: 'V1.4.2 更新公告',
    subtitle: '这次主要优化 UI 界面：降低视觉噪音，保留六套主题色，同时让聊天、角色和设置页面更耐看。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.palette_outlined,
        title: '界面观感优化',
        description: '六套主题色继续保留，但整体发光、透明叠层和高饱和装饰都更克制。',
      ),
      ReleaseNoteItem(
        icon: Icons.chat_bubble_outline_rounded,
        title: '聊天区更清爽',
        description: '聊天气泡、输入框和选项面板降低了阴影和边框强度，阅读时更舒服。',
      ),
      ReleaseNoteItem(
        icon: Icons.view_sidebar_outlined,
        title: '导航更稳重',
        description: '底部导航、侧栏和顶部标题减少英文装饰词，信息层级更清楚。',
      ),
      ReleaseNoteItem(
        icon: Icons.tune_rounded,
        title: '按钮和卡片微调',
        description: '按钮圆角、卡片边框、空状态和角色卡片都做了轻量调整，看起来更像一个完整的小应用。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.4.1',
    version: 'V1.4.1',
    title: 'V1.4.1 更新公告',
    subtitle: '这次把文游体验继续做细：游戏面板改成悬浮窗，NPC 会自动沉淀印象并可能主动发来私聊。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.dashboard_customize_outlined,
        title: '游戏面板悬浮窗',
        description: '聊天页顶部新增“游戏面板”按钮，点开后查看人物数据、任务、事件、背包、关系网和剧情记录。',
      ),
      ReleaseNoteItem(
        icon: Icons.mark_chat_unread_outlined,
        title: 'NPC 主动消息',
        description: '主线剧情推进时，AI 可以在后台更新 NPC 对你的印象，并把适合的主动消息保存到 NPC 私聊里。',
      ),
      ReleaseNoteItem(
        icon: Icons.account_tree_outlined,
        title: 'NPC 印象更稳定',
        description: '就算你不打开 NPC 私聊，主线每轮也会维护 NPC 对用户角色的态度和关系变化。',
      ),
      ReleaseNoteItem(
        icon: Icons.web_asset_rounded,
        title: '剧情和面板分工',
        description: '隐藏规则更明确：小说剧情用纯文字阅读，论坛、事件、任务板、小剧场等资料模块进 HTML 美化面板。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.4',
    version: 'V1.4',
    title: 'V1.4 更新公告',
    subtitle: '这次开始把它推进成 AI 文游小游戏：新增游戏状态面板、状态存档协议和“润色你的人物”。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.dashboard_customize_outlined,
        title: '游戏状态面板',
        description: 'AI 每轮可以沉淀时间、地点、任务、事件卡、背包和数值，App 会解析后展示成游戏面板。',
      ),
      ReleaseNoteItem(
        icon: Icons.save_as_outlined,
        title: '状态本地存档',
        description: '新增 [GAME_STATE] 结构化状态协议，AI 掉格式也会尽量宽松解析，解析不到就沿用旧状态。',
      ),
      ReleaseNoteItem(
        icon: Icons.auto_fix_high_rounded,
        title: '润色你的人物',
        description: '新建普通角色时，可以让 AI 把你上传的人物设定润色成可长期游玩的文游模拟器。',
      ),
      ReleaseNoteItem(
        icon: Icons.palette_outlined,
        title: '跟随当前主题',
        description: '新增状态面板和润色功能都跟随当前 UI 主题色，不会突然冒出一块不搭的界面。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.3.3',
    version: 'V1.3.3',
    title: 'V1.3.3 更新公告',
    subtitle: '这次修了几个影响游玩的细节：慢响应不再轻易超时，选项格式也会自动修。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.timer_outlined,
        title: '超时放宽到三分钟',
        description: 'AI 响应慢一点不会再 60 秒就被误判失败，聊天、工具和测试请求都会至少等待 3 分钟。',
      ),
      ReleaseNoteItem(
        icon: Icons.stream_outlined,
        title: '角色流式输出开关',
        description: '创建或编辑 AI 角色时可以控制流式输出。开启后先显示纯文字，代码等生成完再渲染。',
      ),
      ReleaseNoteItem(
        icon: Icons.fact_check_outlined,
        title: '选项格式自动修复',
        description: 'AI 把 [CHOICES] 写歪、少写结束标签，或者你手动编辑后格式不标准，系统会优先本地修正。',
      ),
      ReleaseNoteItem(
        icon: Icons.edit_note_outlined,
        title: '编辑后自动归一',
        description: '现在手动编辑 AI 回复并保存时，会自动把常见的 A|、A:、A. 等选项写法整理成可点击选项。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.3.2',
    version: 'V1.3.2',
    title: 'V1.3.2 更新公告',
    subtitle: '这次重点优化手机端体验：AI 工具箱变成悬浮弹窗，新增角色开场白和用户角色性别字段。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.auto_awesome_motion_outlined,
        title: '工具箱悬浮弹窗',
        description: 'AI 剧情工具箱不再从底部滑出，会以跟随当前主题色的悬浮窗口打开，手机和网页都更好点。',
      ),
      ReleaseNoteItem(
        icon: Icons.chat_bubble_outline_rounded,
        title: '角色开场白',
        description: '新建角色可以填写开场白；预设模拟器、AI 帮你写和开盲盒生成的模拟器会自动带开场白。',
      ),
      ReleaseNoteItem(
        icon: Icons.person_pin_circle_outlined,
        title: '用户角色更准',
        description: '用户角色新增性别字段，开场白里的 {user} 会自动替换成绑定的用户角色名称。',
      ),
      ReleaseNoteItem(
        icon: Icons.fit_screen_outlined,
        title: '界面缩放增强',
        description: '设置页新增小屏紧凑、标准、舒适、大字几个缩放预设，小屏手机更不容易挤在一起。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.3.1',
    version: 'V1.3.1',
    title: 'V1.3.1 更新公告',
    subtitle: 'NPC 系统继续进化：主线聊天会自动识别 NPC 档案，开盲盒也会真正生成一个具体模拟器。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.manage_search_rounded,
        title: '自动抓取 NPC',
        description: '主线 AI 回复结束后，会在后台从最近剧情中提取 NPC 名字、简介和对主角的印象。',
      ),
      ReleaseNoteItem(
        icon: Icons.badge_outlined,
        title: 'NPC 档案可编辑',
        description: '自动生成的 NPC 会进入 NPC 私聊页，用户可以继续手动修改名字、简介和初始印象。',
      ),
      ReleaseNoteItem(
        icon: Icons.psychology_alt_outlined,
        title: '印象更明显',
        description: 'NPC 列表和私聊页顶部都会显示 NPC 当前对主角的印象，方便判断关系状态。',
      ),
      ReleaseNoteItem(
        icon: Icons.casino_outlined,
        title: '修正开盲盒',
        description: '开盲盒不再生成“盲盒文游模拟器”，而是让 AI 自主决定题材并生成一个真正可玩的模拟器。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.3',
    version: 'V1.3',
    title: 'V1.3 更新公告',
    subtitle: '新增 NPC 私聊系统：支线聊天不会混入主线，但会沉淀 NPC 对用户角色的印象，并影响后续剧情。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.sms_outlined,
        title: '新增 NPC 私聊',
        description: '可以给当前 AI 角色创建 NPC，并进入独立聊天界面，像手机聊天一样连续发送多个气泡。',
      ),
      ReleaseNoteItem(
        icon: Icons.forum_outlined,
        title: 'NPC 分段回复',
        description: '用户多条气泡合并触发一次回复，NPC 会一次返回 2-5 条短气泡，更像真实即时通讯。',
      ),
      ReleaseNoteItem(
        icon: Icons.psychology_alt_outlined,
        title: '印象系统',
        description: '每次 NPC 私聊结束后都会生成印象变化，保存到 NPC 档案，后续主线会自然参考这些关系状态。',
      ),
      ReleaseNoteItem(
        icon: Icons.route_outlined,
        title: '不污染主线',
        description: 'NPC 私聊记录独立保存，不进入正式对话历史；主线只读取浓缩后的 NPC 印象上下文。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.2.2',
    version: 'V1.2.2',
    title: 'V1.2.2 更新公告',
    subtitle: '同步网页端与 APK 端体验，整理网页入口信息，并继续保留历史公告查询。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.web_asset_rounded,
        title: '网页端功能同步',
        description: '聊天、角色、用户人设、AI 工具箱、主题切换、HTML 互动预览等功能继续共用同一套核心逻辑。',
      ),
      ReleaseNoteItem(
        icon: Icons.public_rounded,
        title: '网页应用信息修正',
        description: '浏览器标题、PWA 名称和网页描述从 Flutter 默认值改成了 AI 角色剧场。',
      ),
      ReleaseNoteItem(
        icon: Icons.terminal_rounded,
        title: '固定端口启动脚本',
        description:
            '新增 run_web.ps1，用 127.0.0.1:5173 启动网页端，减少本地缓存因端口变化看似丢失的问题。',
      ),
      ReleaseNoteItem(
        icon: Icons.archive_outlined,
        title: '历史公告查询',
        description: '设置页可以重新查看过往版本更新说明。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.2.1',
    version: 'V1.2.1',
    title: 'V1.2.1 更新公告',
    subtitle: 'AI 剧情工具箱从正式聊天中拆出，新增独立历史记录，并优化开盲盒和长文规则。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.inventory_2_outlined,
        title: '工具箱结果独立保存',
        description: '上集提要、人物关系图、存档封面等结果不再混入聊天记录，会保存到工具箱历史里。',
      ),
      ReleaseNoteItem(
        icon: Icons.casino_outlined,
        title: '开盲盒更像抽题材',
        description: '开盲盒会随机生成更有新意的文游模拟器方向，不再把角色命名成盲盒模拟器。',
      ),
      ReleaseNoteItem(
        icon: Icons.menu_book_outlined,
        title: '强化长篇阅读体验',
        description: '隐藏规则要求非代码剧情正文至少 3000 字，HTML 代码不能拿来凑字数。',
      ),
      ReleaseNoteItem(
        icon: Icons.campaign_outlined,
        title: '设置页可查历史公告',
        description: '以后可以在设置页重新查看过往版本更新说明。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.2',
    version: 'V1.2',
    title: 'V1.2 更新公告',
    subtitle: '新增互动式剧情面板系统，并加入一组可调用 AI 的剧情辅助工具。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.web_asset_rounded,
        title: 'HTML 变成互动剧情面板',
        description: 'AI 生成的 HTML 面板支持全屏、重置、复制源码、导出 HTML。',
      ),
      ReleaseNoteItem(
        icon: Icons.touch_app_rounded,
        title: '面板按钮可填入输入框',
        description: 'HTML 里的行动按钮如果带有互动标记，点击后会自动填入聊天输入框。',
      ),
      ReleaseNoteItem(
        icon: Icons.auto_fix_high_rounded,
        title: '新增 AI 剧情工具箱',
        description: '可生成上集提要、人物关系图、剧情存档封面、伏笔本和选项后果预演。',
      ),
      ReleaseNoteItem(
        icon: Icons.construction_rounded,
        title: '消息级 AI 修复和美化',
        description: '长按 AI 回复可以美化成互动面板，也可以修复格式错误。',
      ),
    ],
  ),
  ReleaseNotes(
    id: 'v1.1',
    version: 'V1.1',
    title: 'V1.1 更新公告',
    subtitle: '修复主题背景、优化手机端创建角色体验，并加入版本更新提示。',
    items: <ReleaseNoteItem>[
      ReleaseNoteItem(
        icon: Icons.palette_outlined,
        title: '主题背景跟随美化方案',
        description: '切换不同主题后，聊天背景和氛围光会一起换色。',
      ),
      ReleaseNoteItem(
        icon: Icons.theater_comedy_outlined,
        title: '创建文游模拟器更适配手机',
        description: '窄屏下按钮和说明文字会自动换行，避免文字被挤成竖排。',
      ),
      ReleaseNoteItem(
        icon: Icons.campaign_outlined,
        title: '新增版本更新公告',
        description: '每次安装新版本，程序会告诉你这次更新了什么。',
      ),
      ReleaseNoteItem(
        icon: Icons.android_rounded,
        title: '安装包按版本号输出',
        description: '安装包按版本号命名，方便区分。',
      ),
    ],
  ),
];
