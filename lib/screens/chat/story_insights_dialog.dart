part of '../chat_screen.dart';

Future<void> showStoryInsightsDialog(
  BuildContext context, {
  required VoidCallback onCreateFanfic,
  required Future<void> Function(NpcProfile npc) onCreateNpcDiary,
  required Future<void> Function() onCreateWorldFeed,
  required Future<void> Function(ToolResult result) onOpenToolResult,
  required Future<void> Function(FanficResult result) onOpenFanficResult,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final compact = size.width < 680;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 28,
          vertical: compact ? 12 : 30,
        ),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? size.width - 16 : 920,
            maxHeight: size.height * (compact ? 0.88 : 0.82),
          ),
          child: Container(
            decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
            padding: EdgeInsets.all(compact ? 12 : 18),
            child: DefaultTabController(
              length: 4,
              child: Consumer<AppStateController>(
                builder: (context, controller, _) {
                  final timeline = controller.currentStoryTimeline;
                  final objective = controller.currentMapObjectiveBoard;
                  final ensemble = controller.currentNpcEnsemble;
                  final memory = controller.currentMemory;
                  final gameState = controller.currentGameState;
                  final profiles = controller.currentWorldNpcProfiles;
                  final calendar = controller.currentWorldCalendarEvents;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.auto_stories_outlined,
                              color: AppTheme.activeSoft),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppTheme.glitchText('故事'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppTheme.contrastText,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: AppTheme.glitchText('关闭'),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TabBar(
                        isScrollable: compact,
                        tabs: const <Widget>[
                          Tab(
                              icon: Icon(Icons.space_dashboard_outlined),
                              text: '概览'),
                          Tab(
                              icon: Icon(Icons.people_alt_outlined),
                              text: '人物'),
                          Tab(
                              icon: Icon(Icons.travel_explore_outlined),
                              text: '线索'),
                          Tab(
                              icon: Icon(Icons.auto_awesome_outlined),
                              text: '番外'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TabBarView(
                          children: <Widget>[
                            _StoryOverviewTab(
                              entries: timeline,
                              board: objective,
                              memory: memory,
                              gameState: gameState,
                            ),
                            _StoryPeopleTab(
                              profiles: profiles,
                              insights: ensemble,
                            ),
                            _StoryCluesTab(
                              board: objective,
                              gameState: gameState,
                              events: calendar,
                              isGenerating: controller.isSending,
                            ),
                            _StoryExtrasTab(
                              fanfics: controller.currentCharacterFanficResults,
                              tools: controller.currentCharacterToolResults,
                              npcs: profiles,
                              isGenerating: controller.isSending,
                              onCreateFanfic: onCreateFanfic,
                              onCreateNpcDiary: onCreateNpcDiary,
                              onCreateWorldFeed: onCreateWorldFeed,
                              onOpenToolResult: onOpenToolResult,
                              onOpenFanficResult: onOpenFanficResult,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _StoryOverviewTab extends StatelessWidget {
  const _StoryOverviewTab({
    required this.entries,
    required this.board,
    required this.memory,
    required this.gameState,
  });

  final List<StoryTimelineEntry> entries;
  final MapObjectiveBoard board;
  final CharacterMemory memory;
  final GameStateSnapshot gameState;

  @override
  Widget build(BuildContext context) {
    final latestMemory =
        memory.summaries.isEmpty ? null : memory.summaries.last;
    final fallbackSummary = entries
        .take(3)
        .map((entry) => entry.detail.trim())
        .where((value) => value.isNotEmpty)
        .join('\n\n');
    final summary = latestMemory?.summaryText.trim().isNotEmpty == true
        ? latestMemory!.summaryText.trim()
        : fallbackSummary;
    return ListView(
      children: <Widget>[
        _InsightCard(
          icon: Icons.history_edu_outlined,
          title: '前情摘要',
          subtitle: latestMemory == null ? '根据当前时间线整理' : '来自最新长期记忆',
          child: Text(
            AppTheme.glitchText(
              summary.isEmpty ? '剧情还没有形成可用摘要，继续推进几轮后会自动出现。' : summary,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.55,
                ),
          ),
        ),
        const SizedBox(height: 10),
        _InsightCard(
          icon: Icons.flag_outlined,
          title: '当前进度',
          subtitle: board.currentLocation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InsightKeyValue(label: '主线目标', value: board.mainGoal),
              _InsightKeyValue(label: '短期目标', value: board.shortTermGoal),
              _InsightKeyValue(label: '风险', value: board.riskLevel),
              if (gameState.status.trim().isNotEmpty)
                _InsightKeyValue(label: '状态', value: gameState.status),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppTheme.glitchText('最近时间线'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          const _InsightEmpty(
            icon: Icons.timeline,
            text: '还没有足够剧情记录生成时间线。',
          )
        else
          for (final entry in entries.take(10)) ...<Widget>[
            _InsightCard(
              icon: Icons.adjust_rounded,
              title: entry.title,
              subtitle: <String>[
                if (entry.subtitle.trim().isNotEmpty) entry.subtitle,
                entry.source,
              ].join(' · '),
              child: Text(
                AppTheme.glitchText(entry.detail),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _StoryPeopleTab extends StatelessWidget {
  const _StoryPeopleTab({
    required this.profiles,
    required this.insights,
  });

  final List<NpcProfile> profiles;
  final List<NpcEnsembleInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const _InsightEmpty(
        icon: Icons.people_outline,
        text: '当前世界还没有 NPC。推进剧情或手动创建后会显示在这里。',
      );
    }
    final insightByName = <String, NpcEnsembleInsight>{
      for (final item in insights) item.name.trim().toLowerCase(): item,
    };
    return ListView.separated(
      itemCount: profiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        final insight = insightByName[profile.name.trim().toLowerCase()];
        return _InsightCard(
          icon: profile.lifecycle.allowsMessages
              ? Icons.person_pin_circle_outlined
              : Icons.person_off_outlined,
          title: profile.name,
          subtitle: '${profile.lifecycle.label} · ID ${profile.id}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InsightKeyValue(label: '好感', value: '${profile.affinity}'),
              _InsightKeyValue(
                label: '羁绊',
                value:
                    '${profile.bondRoute.stage} · ${profile.bondRoute.route} · ${profile.bondRoute.score}/100',
              ),
              if (insight != null) ...<Widget>[
                _InsightKeyValue(label: '位置', value: insight.location),
                _InsightKeyValue(label: '目标', value: insight.goal),
                _InsightKeyValue(label: '私聊', value: insight.privateChatState),
              ],
              const SizedBox(height: 4),
              Text(
                AppTheme.glitchText(
                  profile.impression.trim().isEmpty
                      ? '暂时没有形成明确印象。'
                      : profile.impression,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StoryCluesTab extends StatelessWidget {
  const _StoryCluesTab({
    required this.board,
    required this.gameState,
    required this.events,
    required this.isGenerating,
  });

  final MapObjectiveBoard board;
  final GameStateSnapshot gameState;
  final List<WorldCalendarEvent> events;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    final clues = <String>{
      ...board.clues.map((item) => item.trim()),
      ...gameState.plotFlags.map((item) => item.trim()),
    }.where((item) => item.isNotEmpty).toList(growable: false);
    return ListView(
      children: <Widget>[
        _InsightListCard(
          title: '伏笔与线索',
          icon: Icons.lightbulb_outline_rounded,
          items: clues,
          emptyText: '还没有明确记录的伏笔或线索。',
        ),
        const SizedBox(height: 10),
        _InsightListCard(
          title: '下一步行动',
          icon: Icons.route_outlined,
          items: board.nextActions,
          emptyText: '当前没有结构化行动建议。',
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppTheme.glitchText('世界事件'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: isGenerating
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await context
                          .read<AppStateController>()
                          .generateWorldCalendar();
                      if (!context.mounted || error == null) {
                        return;
                      }
                      messenger.showSnackBar(SnackBar(content: Text(error)));
                    },
              icon: isGenerating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(AppTheme.glitchText(events.isEmpty ? '生成' : '刷新')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          const _InsightEmpty(
            icon: Icons.event_note_outlined,
            text: '还没有世界事件日历。',
          )
        else
          for (final event in events) ...<Widget>[
            _InsightCard(
              icon: Icons.event_note_outlined,
              title: event.title,
              subtitle: '${event.timeLabel} · ${event.stage}',
              child: Text(
                AppTheme.glitchText(event.description),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

enum _StoryExtraFilter { all, fanfic, diary, world, legacy }

class _StoryExtrasTab extends StatefulWidget {
  const _StoryExtrasTab({
    required this.fanfics,
    required this.tools,
    required this.npcs,
    required this.isGenerating,
    required this.onCreateFanfic,
    required this.onCreateNpcDiary,
    required this.onCreateWorldFeed,
    required this.onOpenToolResult,
    required this.onOpenFanficResult,
  });

  final List<FanficResult> fanfics;
  final List<ToolResult> tools;
  final List<NpcProfile> npcs;
  final bool isGenerating;
  final VoidCallback onCreateFanfic;
  final Future<void> Function(NpcProfile npc) onCreateNpcDiary;
  final Future<void> Function() onCreateWorldFeed;
  final Future<void> Function(ToolResult result) onOpenToolResult;
  final Future<void> Function(FanficResult result) onOpenFanficResult;

  @override
  State<_StoryExtrasTab> createState() => _StoryExtrasTabState();
}

class _StoryExtrasTabState extends State<_StoryExtrasTab> {
  _StoryExtraFilter _filter = _StoryExtraFilter.all;

  @override
  Widget build(BuildContext context) {
    final artifacts = <_StoryArtifactEntry>[
      ...widget.fanfics.map(_StoryArtifactEntry.fanfic),
      ...widget.tools.map(_StoryArtifactEntry.tool),
    ]..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final visible = artifacts
        .where((entry) =>
            _filter == _StoryExtraFilter.all || entry.filter == _filter)
        .toList(growable: false);
    return ListView(
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: widget.isGenerating ? null : widget.onCreateFanfic,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(AppTheme.glitchText('同人文')),
            ),
            OutlinedButton.icon(
              onPressed: widget.isGenerating || widget.npcs.isEmpty
                  ? null
                  : _chooseNpcDiary,
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(AppTheme.glitchText('NPC 日记')),
            ),
            OutlinedButton.icon(
              onPressed: widget.isGenerating
                  ? null
                  : () => unawaited(widget.onCreateWorldFeed()),
              icon: const Icon(Icons.dynamic_feed_outlined),
              label: Text(AppTheme.glitchText('世界动态')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final item in _StoryExtraFilter.values)
              ChoiceChip(
                label: Text(AppTheme.glitchText(_filterLabel(item))),
                selected: _filter == item,
                onSelected: (_) => setState(() => _filter = item),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          const _InsightEmpty(
            icon: Icons.collections_bookmark_outlined,
            text: '这个分类还没有作品。',
          )
        else
          for (final entry in visible) ...<Widget>[
            _StoryArtifactTile(
              entry: entry,
              onOpen: () => _open(entry),
              onDelete: () => _delete(entry),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  String _filterLabel(_StoryExtraFilter value) {
    return switch (value) {
      _StoryExtraFilter.all => '全部',
      _StoryExtraFilter.fanfic => '同人文',
      _StoryExtraFilter.diary => 'NPC 日记',
      _StoryExtraFilter.world => '世界动态',
      _StoryExtraFilter.legacy => '旧版记录',
    };
  }

  Future<void> _chooseNpcDiary() async {
    final npc = await showDialog<NpcProfile>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(AppTheme.glitchText('选择日记主人')),
        children: <Widget>[
          for (final item in widget.npcs)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(item),
              child: ListTile(
                leading: CharacterAvatar(
                  name: item.name,
                  avatarDataUri: item.avatarDataUri,
                  size: 36,
                ),
                title: Text(AppTheme.glitchText(item.name)),
                subtitle: Text(AppTheme.glitchText(item.lifecycle.label)),
              ),
            ),
        ],
      ),
    );
    if (npc != null && mounted) {
      await widget.onCreateNpcDiary(npc);
    }
  }

  Future<void> _open(_StoryArtifactEntry entry) async {
    if (entry.fanficResult != null) {
      await widget.onOpenFanficResult(entry.fanficResult!);
    } else if (entry.toolResult != null) {
      await widget.onOpenToolResult(entry.toolResult!);
    }
  }

  Future<void> _delete(_StoryArtifactEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTheme.glitchText('删除作品')),
        content: Text(AppTheme.glitchText('确定删除「${entry.title}」吗？')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppTheme.glitchText('删除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final controller = context.read<AppStateController>();
    if (entry.fanficResult != null) {
      await controller.deleteFanficResult(entry.fanficResult!.id);
    } else if (entry.toolResult != null) {
      await controller.deleteToolResult(entry.toolResult!.id);
    }
  }
}

class _StoryArtifactEntry {
  const _StoryArtifactEntry({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.createdAt,
    required this.filter,
    this.fanficResult,
    this.toolResult,
  });

  factory _StoryArtifactEntry.fanfic(FanficResult result) {
    return _StoryArtifactEntry(
      title: result.title,
      subtitle: result.pairingLabel,
      content: result.content,
      createdAt: result.createdAt,
      filter: _StoryExtraFilter.fanfic,
      fanficResult: result,
    );
  }

  factory _StoryArtifactEntry.tool(ToolResult result) {
    final filter = switch (result.toolId) {
      'npc_diary' => _StoryExtraFilter.diary,
      'world_feed' || 'forum_burst' || 'rumor_board' => _StoryExtraFilter.world,
      _ => _StoryExtraFilter.legacy,
    };
    return _StoryArtifactEntry(
      title: result.toolTitle,
      subtitle: switch (filter) {
        _StoryExtraFilter.diary => 'NPC 日记',
        _StoryExtraFilter.world => '世界动态',
        _ => '旧版剧情工具记录',
      },
      content: result.content,
      createdAt: result.createdAt,
      filter: filter,
      toolResult: result,
    );
  }

  final String title;
  final String subtitle;
  final String content;
  final DateTime createdAt;
  final _StoryExtraFilter filter;
  final FanficResult? fanficResult;
  final ToolResult? toolResult;
}

class _StoryArtifactTile extends StatelessWidget {
  const _StoryArtifactTile({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
  });

  final _StoryArtifactEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final time = entry.createdAt.toLocal().toString().split('.').first;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: AppTheme.glassPanel(radius: 18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: <Widget>[
                Icon(Icons.collections_bookmark_outlined,
                    color: AppTheme.activeSoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppTheme.glitchText(entry.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTheme.glitchText('${entry.subtitle} · $time'),
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textWeak,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: AppTheme.glitchText('复制'),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: entry.content),
                  ),
                  icon: const Icon(Icons.content_copy_outlined),
                ),
                IconButton(
                  tooltip: AppTheme.glitchText('删除'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightListCard extends StatelessWidget {
  const _InsightListCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      icon: icon,
      title: title,
      subtitle: '${items.length} 项',
      child: items.isEmpty
          ? Text(
              AppTheme.glitchText(emptyText),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textWeak,
                  ),
            )
          : Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                for (final item in items.take(12))
                  Chip(
                    label: Text(AppTheme.glitchText(item)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFillStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppTheme.activeSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          if (subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              AppTheme.glitchText(subtitle),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textWeak,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InsightKeyValue extends StatelessWidget {
  const _InsightKeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 86,
            child: Text(
              AppTheme.glitchText(label),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textWeak,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              AppTheme.glitchText(value),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightEmpty extends StatelessWidget {
  const _InsightEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 46, color: AppTheme.textWeak),
          const SizedBox(height: 12),
          Text(
            AppTheme.glitchText(text),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
