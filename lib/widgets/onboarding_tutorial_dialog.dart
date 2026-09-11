import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tutorial_guide.dart';

class DetailedTutorialDialog extends StatefulWidget {
  const DetailedTutorialDialog({super.key});

  @override
  State<DetailedTutorialDialog> createState() => _DetailedTutorialDialogState();
}

class _DetailedTutorialDialogState extends State<DetailedTutorialDialog> {
  static const List<_TutorialChapter> _chapters = <_TutorialChapter>[
    _TutorialChapter(
      icon: Icons.rocket_launch_outlined,
      title: '开始游玩',
      summary: '从连接服务到完成第一回合。',
      topics: <_TutorialTopic>[
        _TutorialTopic(
          title: '连接 AI 服务',
          body:
              '在设置页填写服务地址、密钥和模型名称，测试连接后保存。不确定内容时可以查看服务提供方的接入说明；接下来的实操引导会带你逐个点击。',
          route: DetailedTutorialRoute.api,
        ),
        _TutorialTopic(
          title: '选择或创建故事',
          body:
              '角色页管理所有互动故事。可以从“第一次开幕”开始，也可以填写名称、简介、开场白和剧场设定创建自己的长期故事。每个故事的聊天、记忆、NPC 和进度互相独立。',
          route: DetailedTutorialRoute.theater,
        ),
        _TutorialTopic(
          title: '完成第一个回合',
          body:
              '普通“发送”会把文字加入当前回合，适合连续补充几条行动；点击小飞机后，AI 才会读取这些内容并继续故事。实操引导会带你完整走过一个回合。',
          route: DetailedTutorialRoute.chat,
        ),
      ],
    ),
    _TutorialChapter(
      icon: Icons.theater_comedy_outlined,
      title: '剧场与设定',
      summary: '角色、世界书、玩家人设和故事状态。',
      topics: <_TutorialTopic>[
        _TutorialTopic(
          title: '角色档案',
          body:
              '每张角色卡都拥有独立的聊天、长期记忆、NPC 和故事进度，切换角色不会混用另一段故事的数据。点击实操后会定位角色页和新建入口。',
          route: DetailedTutorialRoute.theater,
        ),
        _TutorialTopic(
          title: '个性故事状态',
          body:
              '角色创建后，可以让 AI 根据题材生成专属状态，例如信任、压力、线索或阵营态度。故事页显示玩家能知道的信息，幕后信息会保持隐藏。',
          route: DetailedTutorialRoute.theater,
        ),
        _TutorialTopic(
          title: '世界书与用户人设',
          body:
              '世界书保存不会轻易变化的世界事实、人物关系、文风和边界；用户页管理你在故事中扮演的人物。绑定后，它们会在后续剧情中保持一致。',
          route: DetailedTutorialRoute.theater,
        ),
      ],
    ),
    _TutorialChapter(
      icon: Icons.chat_bubble_outline_rounded,
      title: '对话与状态',
      summary: '消息操作、行动建议与故事状态。',
      topics: <_TutorialTopic>[
        _TutorialTopic(
          title: '消息与选项',
          body:
              '消息支持复制、编辑、删除、重新生成、书签和创建剧情分支。手机端长按消息可以打开操作菜单。推荐行动可以直接点选，也可以回填后改成自己的做法。',
          route: DetailedTutorialRoute.chat,
        ),
        _TutorialTopic(
          title: '故事状态与资料卡',
          body:
              '故事会记录时间、地点、任务、关系、物品和重要变化。部分回复还会显示状态卡、论坛、地图或小剧场资料卡，其中的行动可以直接加入输入框。',
          route: DetailedTutorialRoute.chat,
        ),
      ],
    ),
    _TutorialChapter(
      icon: Icons.account_tree_outlined,
      title: '剧情推进',
      summary: '长期记忆、IF 线、地图和导演工具。',
      topics: <_TutorialTopic>[
        _TutorialTopic(
          title: '长期记忆与 IF 线',
          body:
              '聊天达到阈值后会自动生成长期记忆。创建 IF 线时，会复制当时的聊天、记忆、游戏状态、玩法变量和 NPC 印象，之后独立推进，不覆盖主线。',
          route: DetailedTutorialRoute.chat,
        ),
        _TutorialTopic(
          title: '地图、导演指令与世界事件',
          body:
              '固定地图只在开局生成一次，选择出生点后通过点击地点和比较路线推进。每回合基础 3 AP、临时上限 5、总上限 8；输入框左侧可以设置下一回合导演指令，世界事件集中在“故事 > 线索”。',
          route: DetailedTutorialRoute.chat,
        ),
      ],
    ),
    _TutorialChapter(
      icon: Icons.groups_2_outlined,
      title: 'NPC 与故事',
      summary: 'NPC 私聊、来信、人物档案和番外作品。',
      topics: <_TutorialTopic>[
        _TutorialTopic(
          title: 'NPC 档案与私聊',
          body:
              '主线中识别到的 NPC 会进入档案。每个 NPC 可以单独私聊，也可能根据关系和剧情条件主动发来消息。实操会直接指向 NPC 导航入口。',
          route: DetailedTutorialRoute.npc,
        ),
        _TutorialTopic(
          title: '故事工作区与番外',
          body:
              '“故事”集中展示概览、人物、线索和番外作品。同人文、NPC 日记与世界动态都保存在番外；每个回复选项可单独预演，预演结果不会推进主线。',
          route: DetailedTutorialRoute.chat,
        ),
      ],
    ),
    _TutorialChapter(
      icon: Icons.archive_outlined,
      title: '存档与数据',
      summary: '快照、导入导出、本地保存和修复。',
      topics: <_TutorialTopic>[
        _TutorialTopic(
          title: '存档快照与 IF 线',
          body:
              '快照是当前角色状态的本地备份，可以把聊天、状态与玩法变量恢复到某个保存点，也可在这里生成当前进度封面；IF 线则是从某一点继续独立推进的平行剧情。',
          route: DetailedTutorialRoute.settings,
        ),
        _TutorialTopic(
          title: '导入、导出与修复',
          body: '可以导出全部数据或单个角色数据。导入覆盖前建议先导出备份。本地数据清理器会检查断裂绑定、无效地图指针和其他可修复问题。',
          route: DetailedTutorialRoute.settings,
        ),
      ],
    ),
    _TutorialChapter(
      icon: Icons.palette_outlined,
      title: '装扮与高级项',
      summary: '啥币、装扮、气泡和使用状态。',
      topics: <_TutorialTopic>[
        _TutorialTopic(
          title: '啥币、装扮与气泡',
          body:
              '每日任务、成就和版本福利会提供啥币。装扮页可以购买气泡皮肤、实时预览并全局装备，也能绑定给具体角色；角色专属气泡优先于全局设置。',
          route: DetailedTutorialRoute.chat,
        ),
        _TutorialTopic(
          title: '生成用量与手机省电',
          body:
              '生成用量统计可以帮助了解每次回复的大致消耗；服务不兼容时可以关闭。手机省电模式会降低动态背景和文字刷新频率，减少发热与耗电。',
          route: DetailedTutorialRoute.settings,
        ),
      ],
    ),
  ];

  int _chapterIndex = 0;
  int _topicIndex = 0;

  _TutorialChapter get _chapter => _chapters[_chapterIndex];
  _TutorialTopic get _topic => _chapter.topics[_topicIndex];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 720;
    final maxWidth = math.min(size.width - (compact ? 16 : 48), 920.0);
    final maxHeight = math.min(size.height - (compact ? 24 : 64), 740.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 24,
        vertical: compact ? 12 : 32,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 22),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.menu_book_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppTheme.glitchText('完整功能教程'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            AppTheme.glitchText('先选一个目标，再跟着高亮位置实际操作。'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textWeak),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: compact
                    ? Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: DropdownButtonFormField<int>(
                              key: ValueKey<int>(_chapterIndex),
                              initialValue: _chapterIndex,
                              decoration: const InputDecoration(
                                labelText: '教程章节',
                              ),
                              items: List<DropdownMenuItem<int>>.generate(
                                _chapters.length,
                                (index) => DropdownMenuItem<int>(
                                  value: index,
                                  child: Text(_chapters[index].title),
                                ),
                              ),
                              onChanged: (value) {
                                if (value != null) {
                                  _selectChapter(value);
                                }
                              },
                            ),
                          ),
                          Expanded(child: _buildTopicBody(context)),
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          SizedBox(
                            width: 218,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(10),
                              itemCount: _chapters.length,
                              itemBuilder: (context, index) {
                                final chapter = _chapters[index];
                                return ListTile(
                                  selected: index == _chapterIndex,
                                  leading: Icon(chapter.icon),
                                  title:
                                      Text(AppTheme.glitchText(chapter.title)),
                                  subtitle: Text(
                                    AppTheme.glitchText(chapter.summary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectChapter(index),
                                );
                              },
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: _buildTopicBody(context)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicBody(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_chapter.icon, color: AppTheme.activePrimary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppTheme.glitchText(_chapter.title),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: List<ButtonSegment<int>>.generate(
                _chapter.topics.length,
                (index) => ButtonSegment<int>(
                  value: index,
                  label: Text(_chapter.topics[index].title),
                ),
              ),
              selected: <int>{_topicIndex},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _topicIndex = selection.first);
              },
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppTheme.glitchText(_topic.title),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: StreamingTutorialText(
                key: ValueKey<String>('$_chapterIndex-$_topicIndex'),
                text: _topic.body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.7,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                detailedTutorialSequence(_topic.route, _topic.title),
              ),
              icon: const Icon(Icons.touch_app_rounded),
              label: Text(AppTheme.glitchText('进入界面，跟随高亮操作')),
            ),
          ),
        ],
      ),
    );
  }

  void _selectChapter(int index) {
    setState(() {
      _chapterIndex = index;
      _topicIndex = 0;
    });
  }
}

class _TutorialChapter {
  const _TutorialChapter({
    required this.icon,
    required this.title,
    required this.summary,
    required this.topics,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<_TutorialTopic> topics;
}

class _TutorialTopic {
  const _TutorialTopic({
    required this.title,
    required this.body,
    required this.route,
  });

  final String title;
  final String body;
  final DetailedTutorialRoute route;
}
