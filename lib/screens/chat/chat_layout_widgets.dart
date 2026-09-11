part of '../chat_screen.dart';

class _MobileChatHeader extends StatelessWidget {
  const _MobileChatHeader({
    required this.character,
    required this.memoryCount,
    required this.gameState,
    required this.onOpenDetails,
    required this.onOpenStoryInfo,
  });

  final CharacterProfile character;
  final int memoryCount;
  final GameStateSnapshot gameState;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenStoryInfo;

  @override
  Widget build(BuildContext context) {
    final location = gameState.location.trim();
    final time = gameState.timeLabel.trim();
    final status = gameState.status.trim();
    final sceneTitle =
        location.isEmpty ? AppTheme.glitchText('剧情舞台') : location;
    final sceneSubtitle = gameState.mainTask.trim().isNotEmpty
        ? gameState.mainTask.trim()
        : gameState.eventTitle.trim().isNotEmpty
            ? gameState.eventTitle.trim()
            : character.name;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppTheme.activePrimary.withValues(
              alpha: AppTheme.isLightPaletteMode ? 0.13 : 0.22,
            ),
            AppTheme.activeSecondary.withValues(
              alpha: AppTheme.isLightPaletteMode ? 0.09 : 0.16,
            ),
            AppTheme.panel.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.isTerminalMode ? 8 : 24),
        border: Border.all(color: AppTheme.activeLine),
        boxShadow: AppTheme.neonGlow(alpha: 0.06),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CharacterAvatar(
                  name: character.name,
                  avatarDataUri: character.avatarDataUri,
                  selected: true,
                  size: 46,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.theater_comedy_outlined,
                            size: 15,
                            color: AppTheme.activeSoft,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              AppTheme.glitchText('剧情舞台'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppTheme.textWeak,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sceneTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textMain,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sceneSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              height: 1.25,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  style: AppTheme.skinIconButtonStyle(),
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.switch_account_rounded),
                  tooltip: AppTheme.glitchText('角色详情'),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  style: AppTheme.skinIconButtonStyle(primary: true),
                  onPressed: onOpenStoryInfo,
                  icon: const Icon(Icons.menu_book_rounded),
                  tooltip: AppTheme.glitchText('剧情信息'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                _StageScenePill(
                  icon: Icons.schedule_rounded,
                  label: time.isEmpty ? '时间待定' : time,
                ),
                _StageScenePill(
                  icon: Icons.place_outlined,
                  label: location.isEmpty ? '地点待定' : location,
                ),
                _StageScenePill(
                  icon: Icons.auto_stories_outlined,
                  label: status.isEmpty ? '记忆 $memoryCount 条' : status,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StageScenePill extends StatelessWidget {
  const _StageScenePill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFillStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.activeLine.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.activeSoft),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryInfoSheet extends StatelessWidget {
  const _StoryInfoSheet({
    required this.character,
    required this.memory,
    required this.gameState,
    required this.npcs,
    required this.onOpenGameState,
    required this.onOpenMemory,
    required this.onOpenNpc,
  });

  final CharacterProfile character;
  final CharacterMemory memory;
  final GameStateSnapshot gameState;
  final List<NpcProfile> npcs;
  final VoidCallback onOpenGameState;
  final VoidCallback onOpenMemory;
  final VoidCallback onOpenNpc;

  @override
  Widget build(BuildContext context) {
    final hasMemory = memory.summaries.isNotEmpty;
    final visibleNpcs = npcs.take(4).toList(growable: false);
    final statusLine = gameState.status.trim().isNotEmpty
        ? gameState.status.trim()
        : gameState.eventDescription.trim().isNotEmpty
            ? gameState.eventDescription.trim()
            : '当前剧情还在等待下一轮沉淀。';

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppTheme.glitchText('剧情信息'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.contrastText,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            IconButton.filledTonal(
              style: AppTheme.skinIconButtonStyle(),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: AppTheme.glitchText('关闭'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _StoryInfoCard(
                  icon: Icons.local_activity_outlined,
                  title: '当前剧情',
                  child: Text(
                    statusLine,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.55,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                _StoryInfoCard(
                  icon: Icons.person_pin_circle_outlined,
                  title: '在场角色',
                  actionLabel: 'NPC',
                  onAction: onOpenNpc,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _StoryInfoChip(
                        label: character.name,
                        icon: Icons.person_outline_rounded,
                      ),
                      for (final npc in visibleNpcs)
                        _StoryInfoChip(
                          label: npc.name,
                          icon: Icons.face_retouching_natural_outlined,
                        ),
                      if (visibleNpcs.isEmpty)
                        _StoryInfoChip(
                          label: '暂无可见 NPC',
                          icon: Icons.group_outlined,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _StoryInfoCard(
                  icon: Icons.timeline_rounded,
                  title: '关系与数值',
                  child: gameState.metrics.isEmpty
                      ? Text(
                          '暂时还没有数值变化。关系、好感或压力值会在剧情推进后显示在这里。',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textMuted,
                                    height: 1.55,
                                  ),
                        )
                      : Column(
                          children: gameState.metrics.entries
                              .take(4)
                              .map(
                                (entry) => _StoryMetricRow(
                                  label: entry.key,
                                  value: entry.value,
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: 10),
                _StoryInfoCard(
                  icon: Icons.psychology_alt_outlined,
                  title: '最近记忆',
                  actionLabel: '查看',
                  onAction: onOpenMemory,
                  child: Text(
                    hasMemory
                        ? memory.summaries.last.summaryText
                        : '还没有长期记忆。剧情聊到一定长度后会自动生成。',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.55,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                _StoryInfoCard(
                  icon: Icons.dashboard_customize_outlined,
                  title: '游戏面板',
                  actionLabel: '展开',
                  onAction: onOpenGameState,
                  child: _GameStatePanel(
                    state: gameState,
                    compact: true,
                    ultraCompact: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryInfoCard extends StatelessWidget {
  const _StoryInfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(AppTheme.isTerminalMode ? 8 : 18),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textMain,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StoryInfoChip extends StatelessWidget {
  const _StoryInfoChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(
          alpha: AppTheme.isLightPaletteMode ? 0.08 : 0.14,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppTheme.activeSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryMetricRow extends StatelessWidget {
  const _StoryMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final percent = value.clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 74,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: percent / 100,
                backgroundColor: AppTheme.translucentPanelFillStrong,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.activeSoft,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textWeak,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _MobileStagePromptBar extends StatelessWidget {
  const _MobileStagePromptBar({
    required this.gameState,
    required this.onOpenStoryInfo,
  });

  final GameStateSnapshot gameState;
  final VoidCallback onOpenStoryInfo;

  @override
  Widget build(BuildContext context) {
    final label = gameState.mainTask.trim().isNotEmpty
        ? gameState.mainTask.trim()
        : gameState.eventTitle.trim().isNotEmpty
            ? gameState.eventTitle.trim()
            : gameState.location.trim().isNotEmpty
                ? '当前场景：${gameState.location.trim()}'
                : '剧情信息会随着对话自动沉淀';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenStoryInfo,
        borderRadius: BorderRadius.circular(AppTheme.isTerminalMode ? 8 : 18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.translucentPanelFill,
            borderRadius:
                BorderRadius.circular(AppTheme.isTerminalMode ? 8 : 18),
            border: Border.all(
              color: AppTheme.activeLine.withValues(alpha: 0.70),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.local_activity_outlined,
                size: 17,
                color: AppTheme.activeSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_less_rounded,
                size: 18,
                color: AppTheme.textWeak,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameStatePanel extends StatelessWidget {
  const _GameStatePanel({
    required this.state,
    required this.compact,
    required this.ultraCompact,
    this.expanded = false,
  });

  final GameStateSnapshot state;
  final bool compact;
  final bool ultraCompact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final maxLines = expanded ? null : (ultraCompact ? 3 : 4);
    return Container(
      width: double.infinity,
      decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
      child: Padding(
        padding: EdgeInsets.all(compact ? 13 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.dashboard_customize_outlined,
                  color: AppTheme.activeSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTheme.glitchText('游戏状态面板'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            if (state.timeLabel.trim().isNotEmpty ||
                state.location.trim().isNotEmpty ||
                state.status.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxPillWidth = (constraints.maxWidth < 420
                          ? constraints.maxWidth
                          : constraints.maxWidth * 0.66)
                      .clamp(160.0, constraints.maxWidth)
                      .toDouble();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (state.timeLabel.trim().isNotEmpty)
                        _GameStatePill(
                          icon: Icons.schedule_rounded,
                          label: state.timeLabel,
                          maxWidth: maxPillWidth,
                        ),
                      if (state.location.trim().isNotEmpty)
                        _GameStatePill(
                          icon: Icons.place_outlined,
                          label: state.location,
                          maxWidth: maxPillWidth,
                        ),
                      if (state.status.trim().isNotEmpty)
                        _GameStatePill(
                          icon: Icons.favorite_border_rounded,
                          label: state.status,
                          maxWidth: maxPillWidth,
                        ),
                    ],
                  );
                },
              ),
            ],
            if (!expanded && state.hasNarrativeState) ...<Widget>[
              const SizedBox(height: 12),
              _GameStateLine(
                icon: Icons.flag_outlined,
                title: '当前任务',
                text: state.mainTask.trim().isEmpty
                    ? (state.eventTitle.trim().isEmpty
                        ? '本轮状态已更新。'
                        : state.eventTitle)
                    : state.mainTask,
                maxLines: maxLines,
              ),
            ],
            if (!state.hasNarrativeState) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                AppTheme.glitchText(
                  '当前还没有可展示的游戏状态。等角色正式推进一轮剧情后，这里会自动沉淀人物数据、任务、事件和 NPC 印象。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.6,
                    ),
              ),
            ],
            if (expanded) ...<Widget>[
              if (state.metrics.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.metrics.entries
                      .take(8)
                      .map(
                        (entry) => _GameMetricChip(
                          label: entry.key,
                          value: entry.value,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (state.profileDetails.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _buildListSection(
                  context,
                  icon: Icons.badge_outlined,
                  title: '人物数据',
                  items: state.profileDetails,
                ),
              ],
              if (state.mainTask.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _GameStateLine(
                  icon: Icons.flag_outlined,
                  title: '当前任务',
                  text: state.mainTask,
                  maxLines: maxLines,
                ),
              ],
              if (state.sideTasks.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _buildListSection(
                  context,
                  icon: Icons.route_outlined,
                  title: '支线任务',
                  items: state.sideTasks,
                ),
              ],
              if (state.completedTasks.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _buildListSection(
                  context,
                  icon: Icons.task_alt_rounded,
                  title: '已完成',
                  items: state.completedTasks,
                ),
              ],
              if (state.eventTitle.trim().isNotEmpty ||
                  state.eventDescription.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _GameStateLine(
                  icon: Icons.style_outlined,
                  title: state.eventTitle.trim().isEmpty
                      ? '事件卡'
                      : state.eventTitle,
                  text: state.eventDescription.trim().isEmpty
                      ? '本轮触发了新事件。'
                      : state.eventDescription,
                  maxLines: maxLines,
                ),
              ],
              if (state.inventory.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _buildListSection(
                  context,
                  icon: Icons.inventory_2_outlined,
                  title: '背包与资源',
                  items: state.inventory,
                ),
              ],
              if (state.relationshipNotes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _buildListSection(
                  context,
                  icon: Icons.account_tree_outlined,
                  title: '关系网',
                  items: state.relationshipNotes,
                ),
              ],
              if (state.npcChanges.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _buildListSection(
                  context,
                  icon: Icons.groups_2_outlined,
                  title: 'NPC 印象',
                  items: state.npcChanges,
                ),
              ],
              if (state.npcUpdates.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _buildListSection(
                  context,
                  icon: Icons.mark_chat_unread_outlined,
                  title: 'NPC 主动动态',
                  items: _npcUpdateItems,
                ),
              ],
              if (state.plotFlags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _buildListSection(
                  context,
                  icon: Icons.auto_stories_outlined,
                  title: '剧情记录',
                  items: state.plotFlags,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    final visibleItems =
        expanded ? items : items.take(3).toList(growable: false);
    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 17, color: AppTheme.activeSoft),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppTheme.glitchText(title),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.contrastText,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              for (final item in visibleItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $item',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.45,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> get _npcUpdateItems {
    return state.npcUpdates.map((update) {
      final parts = <String>[update.name];
      if (update.affinity != null) {
        parts.add('好感度：${update.affinity}');
      }
      if (update.impression.trim().isNotEmpty) {
        parts.add('印象：${update.impression.trim()}');
      }
      if (NpcMessageClassifier.isDeliverableChatBubble(
        update.proactiveMessage,
      )) {
        parts.add('主动消息：${update.proactiveMessage.trim()}');
      }
      return parts.join('｜');
    }).toList(growable: false);
  }
}

class _GameStatePill extends StatelessWidget {
  const _GameStatePill({
    required this.icon,
    required this.label,
    required this.maxWidth,
  });

  final IconData icon;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.activePrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.activeLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: AppTheme.activeSoft),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameMetricChip extends StatelessWidget {
  const _GameMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final percent = value.clamp(0, 100);
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$label $value',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: percent / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.activeSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameStateLine extends StatelessWidget {
  const _GameStateLine({
    required this.icon,
    required this.title,
    required this.text,
    required this.maxLines,
  });

  final IconData icon;
  final String title;
  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppTheme.activeSoft),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            maxLines: maxLines,
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
              children: <InlineSpan>[
                TextSpan(
                  text: '${AppTheme.glitchText(title)}：',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactChatDetailsSheet extends StatelessWidget {
  const _CompactChatDetailsSheet({
    required this.character,
    required this.memory,
    required this.memoryContextItems,
    required this.availableCharacters,
    required this.onSelectCharacter,
    required this.onManageCharacters,
    required this.onViewMemory,
  });

  final CharacterProfile character;
  final CharacterMemory memory;
  final int memoryContextItems;
  final List<CharacterProfile> availableCharacters;
  final ValueChanged<String> onSelectCharacter;
  final VoidCallback onManageCharacters;
  final VoidCallback onViewMemory;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppTheme.glitchText('角色详情'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.contrastText,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: character.isStoryBranch
              ? character.rootCharacterId
              : character.id,
          decoration: InputDecoration(labelText: AppTheme.glitchText('当前角色')),
          items: availableCharacters
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(item.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onSelectCharacter(value);
            }
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: onManageCharacters,
              child: Text(AppTheme.glitchText('管理角色')),
            ),
            FilledButton.tonal(
              onPressed: onViewMemory,
              child: Text(AppTheme.glitchText('查看长期记忆')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          character.visibleBlurb,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        if (character.isPromptLocked) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            AppTheme.glitchText('这是系统预设角色，底层提示词已锁定，不会在前台显示。'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _MetricChip(
              label:
                  'Temperature ${character.modelParams.temperature.toStringAsFixed(2)}',
            ),
            _MetricChip(
              label: 'Top P ${character.modelParams.topP.toStringAsFixed(2)}',
            ),
            _MetricChip(
              label: character.modelParams.contextLength <= 0
                  ? '上下文不限'
                  : '上下文 ${character.modelParams.contextLength} 条',
            ),
            _MetricChip(
              label: memoryContextItems <= 0
                  ? '长期记忆注入不限'
                  : '长期记忆注入 $memoryContextItems 条',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.translucentPanelFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.activeLine),
          ),
          child: Text(
            memory.summaries.isEmpty
                ? AppTheme.glitchText('目前还没有长期记忆总结。')
                : AppTheme.glitchText(
                    '当前已有 ${memory.summaries.length} 条长期记忆总结。'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ),
      ],
    );
  }
}

class _DesktopChatOverviewCard extends StatelessWidget {
  const _DesktopChatOverviewCard({
    required this.character,
    required this.memory,
    required this.memoryContextItems,
    required this.availableCharacters,
    required this.onSelectCharacter,
    required this.onManageCharacters,
    required this.onViewMemory,
  });

  final CharacterProfile character;
  final CharacterMemory memory;
  final int memoryContextItems;
  final List<CharacterProfile> availableCharacters;
  final ValueChanged<String> onSelectCharacter;
  final VoidCallback onManageCharacters;
  final VoidCallback onViewMemory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final mainCard = Container(
          decoration: AppTheme.glassPanel(highlighted: true),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CharacterAvatar(
                      name: character.name,
                      avatarDataUri: character.avatarDataUri,
                      selected: true,
                      size: 54,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        character.name,
                        maxLines: compact ? 2 : 1,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (compact) ...<Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: character.isStoryBranch
                        ? character.rootCharacterId
                        : character.id,
                    decoration:
                        InputDecoration(labelText: AppTheme.glitchText('当前角色')),
                    items: availableCharacters
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onSelectCharacter(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: onManageCharacters,
                      child: Text(AppTheme.glitchText('管理角色')),
                    ),
                  ),
                ] else
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: character.isStoryBranch
                              ? character.rootCharacterId
                              : character.id,
                          decoration: InputDecoration(
                            labelText: AppTheme.glitchText('当前角色'),
                          ),
                          items: availableCharacters
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              onSelectCharacter(value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: onManageCharacters,
                        child: Text(AppTheme.glitchText('管理角色')),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                Text(
                  character.visibleBlurb,
                  maxLines: compact ? 6 : 4,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MetricChip(
                      label:
                          'Temperature ${character.modelParams.temperature.toStringAsFixed(2)}',
                    ),
                    _MetricChip(
                      label:
                          'Top P ${character.modelParams.topP.toStringAsFixed(2)}',
                    ),
                    _MetricChip(
                      label: character.modelParams.contextLength <= 0
                          ? '上下文不限'
                          : '上下文 ${character.modelParams.contextLength} 条',
                    ),
                    _MetricChip(
                      label: memoryContextItems <= 0
                          ? '长期记忆注入不限'
                          : '长期记忆注入 $memoryContextItems 条',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        final memoryCard = Container(
          decoration: AppTheme.glassPanel(),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('长期记忆'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  memory.summaries.isEmpty
                      ? AppTheme.glitchText('目前还没有总结，聊到一定消息量后会自动生成。')
                      : AppTheme.glitchText(
                          '当前已沉淀 ${memory.summaries.length} 条长期记忆。'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: onViewMemory,
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text(AppTheme.glitchText('查看长期记忆')),
                  ),
                ),
              ],
            ),
          ),
        );

        if (compact) {
          return Column(
            children: <Widget>[
              mainCard,
              const SizedBox(height: 12),
              memoryCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 7, child: mainCard),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: memoryCard),
          ],
        );
      },
    );
  }
}

class _StoryBranchBar extends StatelessWidget {
  const _StoryBranchBar({
    required this.rootCharacter,
    required this.currentCharacter,
    required this.branches,
    required this.onSelect,
    required this.onDelete,
  });

  final CharacterProfile rootCharacter;
  final CharacterProfile currentCharacter;
  final List<CharacterProfile> branches;
  final ValueChanged<String> onSelect;
  final ValueChanged<CharacterProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panel.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _BranchChip(
              label: AppTheme.glitchText('主线'),
              selected: !currentCharacter.isStoryBranch,
              onTap: () => onSelect(rootCharacter.id),
            ),
            const SizedBox(width: 8),
            for (final branch in branches) ...<Widget>[
              _BranchChip(
                label: branch.branchName.trim().isEmpty
                    ? AppTheme.glitchText('未命名分支')
                    : branch.branchName.trim(),
                selected: currentCharacter.id == branch.id,
                onTap: () => onSelect(branch.id),
                onDelete: () => onDelete(branch),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              AppTheme.glitchText('分支不会影响主线'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textWeak,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.activeAccent
                  .withValues(alpha: AppTheme.isLightPaletteMode ? 0.16 : 0.28)
              : AppTheme.translucentPanelFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.activeGlow : AppTheme.activeLine,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? AppTheme.selectedTintText
                        : AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (onDelete != null) ...<Widget>[
              const SizedBox(width: 6),
              InkResponse(
                radius: 16,
                onTap: onDelete,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: selected
                      ? AppTheme.selectedTintText.withValues(alpha: 0.9)
                      : AppTheme.textWeak,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoryBranchNameDialog extends StatefulWidget {
  const _StoryBranchNameDialog();

  @override
  State<_StoryBranchNameDialog> createState() => _StoryBranchNameDialogState();
}

class _StoryBranchNameDialogState extends State<_StoryBranchNameDialog> {
  static const String _prompt = '你打算给这个分支取名为：';
  late final TextEditingController _controller;
  Timer? _timer;
  int _visibleChars = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _timer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_visibleChars >= _prompt.length) {
        timer.cancel();
        return;
      }
      setState(() => _visibleChars += 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visiblePrompt =
        _prompt.substring(0, _visibleChars.clamp(0, _prompt.length));
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.activeGlow, width: 1.4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppTheme.activeAccent.withValues(alpha: 0.24),
                blurRadius: 38,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppTheme.glitchText('创建剧情分支'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.contrastText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                visiblePrompt,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppTheme.glitchText('例如：雨夜留下 / 转去天台 / 另一个答案'),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppTheme.glitchText('取消')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.call_split_rounded),
                    label: Text(AppTheme.glitchText('创建分支')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }
}

class _ChatToolbar extends StatelessWidget {
  const _ChatToolbar({
    required this.exportMode,
    required this.selectedCount,
    required this.compact,
    required this.ultraCompact,
    required this.onEnterExport,
    required this.onCancelExport,
    required this.onExport,
    required this.onShareCard,
    required this.onClearHistory,
  });

  final bool exportMode;
  final int selectedCount;
  final bool compact;
  final bool ultraCompact;
  final VoidCallback onEnterExport;
  final VoidCallback onCancelExport;
  final VoidCallback? onExport;
  final VoidCallback? onShareCard;
  final VoidCallback? onClearHistory;

  @override
  Widget build(BuildContext context) {
    final helperText = exportMode
        ? '导出模式已开启，点击消息即可勾选。'
        : compact
            ? '长按消息可复制、编辑、重新回复、删除，或进入多选模式。'
            : '网页端可悬停操作，手机端可长按消息进行复制、编辑、重新回复、删除或多选。';
    final tonalStyle = AppTheme.skinTonalButtonStyle();

    return Container(
      width: double.infinity,
      decoration: AppTheme.glassPanel(radius: 24),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? (ultraCompact ? 10 : 12) : 16,
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!ultraCompact) ...<Widget>[
                    Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!exportMode) ...<Widget>[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: onClearHistory,
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: Text(ultraCompact ? '清空' : '清空记录'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onShareCard,
                            icon: const Icon(Icons.photo_size_select_large),
                            label: Text(ultraCompact ? '分享卡' : '剧情分享卡'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: exportMode
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              OutlinedButton(
                                onPressed: onCancelExport,
                                child: const Text('取消'),
                              ),
                              FilledButton.icon(
                                onPressed: onExport,
                                icon: const Icon(Icons.ios_share_outlined),
                                label: Text('导出 $selectedCount 条'),
                              ),
                              FilledButton.tonalIcon(
                                style: tonalStyle,
                                onPressed: onShareCard,
                                icon: const Icon(Icons.photo_size_select_large),
                                label: Text(
                                  ultraCompact ? '分享卡' : '生成分享卡',
                                ),
                              ),
                            ],
                          )
                        : FilledButton.tonalIcon(
                            style: tonalStyle,
                            onPressed: onEnterExport,
                            icon: const Icon(Icons.ios_share_outlined),
                            label: Text(ultraCompact ? '导出记录' : '导出消息记录'),
                          ),
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!exportMode) ...<Widget>[
                    OutlinedButton.icon(
                      onPressed: onClearHistory,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('清空当前记录'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onShareCard,
                      icon: const Icon(Icons.photo_size_select_large),
                      label: const Text('剧情分享卡'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (exportMode) ...<Widget>[
                    OutlinedButton(
                      onPressed: onCancelExport,
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.ios_share_outlined),
                      label: Text('导出 $selectedCount 条'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: onShareCard,
                      icon: const Icon(Icons.photo_size_select_large),
                      label: const Text('生成分享卡'),
                    ),
                  ] else
                    FilledButton.tonalIcon(
                      onPressed: onEnterExport,
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('导出消息记录'),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ContinueDashboardCard extends StatelessWidget {
  const _ContinueDashboardCard({
    required this.dashboard,
    required this.compact,
    required this.onOpenBookmarks,
    required this.onOpenNpc,
    required this.onOpenMailbox,
    required this.onScrollBottom,
    this.onOpenMap,
  });

  final ContinueDashboard dashboard;
  final bool compact;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenNpc;
  final VoidCallback onOpenMailbox;
  final VoidCallback onScrollBottom;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (dashboard.unreadNpcCount > 0)
        _DashboardChip(
          icon: Icons.forum_outlined,
          label: 'NPC ${dashboard.unreadNpcCount}',
          onTap: onOpenNpc,
        ),
      if (dashboard.unclaimedMailCount > 0)
        _DashboardChip(
          icon: Icons.mail_outline_rounded,
          label: '邮箱 ${dashboard.unclaimedMailCount}',
          onTap: onOpenMailbox,
        ),
      if (dashboard.bookmarkCount > 0)
        _DashboardChip(
          icon: Icons.bookmark_added_rounded,
          label: '书签 ${dashboard.bookmarkCount}',
          onTap: onOpenBookmarks,
        ),
      if (dashboard.mapHint.trim().isNotEmpty && onOpenMap != null)
        _DashboardChip(
          icon: Icons.map_outlined,
          label: '地图',
          onTap: onOpenMap!,
        ),
    ];

    if (compact) {
      final summary = dashboard.currentTask.trim().isNotEmpty
          ? dashboard.currentTask.trim()
          : dashboard.lastMessagePreview.trim();
      final signalCount = dashboard.unreadNpcCount +
          dashboard.unclaimedMailCount +
          dashboard.bookmarkCount +
          (dashboard.mapHint.trim().isNotEmpty && onOpenMap != null ? 1 : 0);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onScrollBottom,
          child: Ink(
            decoration: BoxDecoration(
              color: AppTheme.isLightPaletteMode
                  ? Colors.white.withValues(alpha: 0.42)
                  : Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: <Widget>[
                  Icon(Icons.history_rounded, color: AppTheme.activeSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          AppTheme.glitchText('继续上次剧情'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        if (summary.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            AppTheme.glitchText(summary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (signalCount > 0) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.activePrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        AppTheme.glitchText('$signalCount'),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppTheme.activePrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                  ],
                  Icon(
                    Icons.south_rounded,
                    color: AppTheme.textWeak,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.history_rounded, color: AppTheme.activeSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTheme.glitchText('继续上次剧情'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onScrollBottom,
                  icon: const Icon(Icons.south_rounded, size: 18),
                  label: const Text('回到最新'),
                ),
              ],
            ),
            if (dashboard.currentTask.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText('当前任务：${dashboard.currentTask}'),
                maxLines: compact ? 4 : 3,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (dashboard.lastMessagePreview.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                AppTheme.glitchText('上次停在：${dashboard.lastMessagePreview}'),
                maxLines: compact ? 4 : 3,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
            if (chips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardChip extends StatelessWidget {
  const _DashboardChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppTheme.activePrimary),
      label: Text(AppTheme.glitchText(label)),
      onPressed: onTap,
      backgroundColor: AppTheme.activePrimary.withValues(alpha: 0.08),
      side: BorderSide(color: AppTheme.activeLine),
    );
  }
}

class _ExportHintBar extends StatelessWidget {
  const _ExportHintBar({
    required this.selectedCount,
    required this.compact,
    required this.ultraCompact,
    required this.onCancel,
    required this.onExport,
    required this.onShareCard,
  });

  final int selectedCount;
  final bool compact;
  final bool ultraCompact;
  final VoidCallback onCancel;
  final VoidCallback? onExport;
  final VoidCallback? onShareCard;

  @override
  Widget build(BuildContext context) {
    final helperText = selectedCount == 0
        ? '请选择想导出的消息。'
        : '已选择 $selectedCount 条消息，可导出 HTML，也可生成剧情分享卡。';

    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? (ultraCompact ? 10 : 12) : 14,
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!ultraCompact) ...<Widget>[
                    Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('取消'),
                        ),
                        FilledButton.icon(
                          onPressed: onExport,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('导出'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: onShareCard,
                          icon: const Icon(Icons.photo_size_select_large),
                          label: const Text('分享卡'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('导出'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: onShareCard,
                    icon: const Icon(Icons.photo_size_select_large),
                    label: const Text('分享卡'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BatchSelectionBar extends StatelessWidget {
  const _BatchSelectionBar({
    required this.selectedCount,
    required this.compact,
    required this.ultraCompact,
    required this.onCancel,
    required this.onDelete,
  });

  final int selectedCount;
  final bool compact;
  final bool ultraCompact;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final helperText = selectedCount == 0
        ? '请点击要批量删除的消息。'
        : '已选中 $selectedCount 条消息，确认后会同时从聊天记录和本地缓存中删除。';

    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? (ultraCompact ? 10 : 12) : 14,
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!ultraCompact) ...<Widget>[
                    Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('取消'),
                        ),
                        FilledButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('批量删除'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('批量删除'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
      ),
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({
    required this.compact,
    required this.onTap,
  });

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = compact
        ? '还没有配置 API，去设置页填好接口、密钥和模型后就能聊天。'
        : '还没有配置 API。去设置页填好兼容 OpenAI 的接口地址、密钥和模型名称，就能开始聊天。';

    return Container(
      decoration: AppTheme.glassPanel(radius: 26),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.key_outlined, color: AppTheme.activeSoft),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: onTap,
                    child: const Text('去设置'),
                  ),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Icon(Icons.key_outlined, color: AppTheme.activeSoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: onTap,
                  child: const Text('去设置'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MessageEditorDialog extends StatefulWidget {
  const _MessageEditorDialog({required this.message});

  final ChatMessage message;

  @override
  State<_MessageEditorDialog> createState() => _MessageEditorDialogState();
}

class _MessageEditorDialogState extends State<_MessageEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == ChatRole.user;
    return AlertDialog(
      title: Text(isUser ? '编辑你的消息' : '编辑角色回复'),
      content: SizedBox(
        width: 680,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
          minLines: 8,
          decoration: const InputDecoration(
            hintText: '输入修改后的内容',
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _BookmarkDraft {
  const _BookmarkDraft({
    required this.bookmarked,
    required this.note,
  });

  final bool bookmarked;
  final String note;
}

class _BookmarkDialog extends StatefulWidget {
  const _BookmarkDialog({required this.message});

  final ChatMessage message;

  @override
  State<_BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<_BookmarkDialog> {
  late final TextEditingController _noteController;
  late bool _bookmarked;

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.message.isBookmarked;
    _noteController =
        TextEditingController(text: widget.message.bookmarkNote.trim());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppTheme.glitchText(_bookmarked ? '编辑消息书签' : '加入消息书签')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTheme.glitchText(
                widget.message.content.length > 120
                    ? '${widget.message.content.substring(0, 120)}...'
                    : widget.message.content,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '书签备注',
                hintText: '例如：第一次告白 / 关键选择 / 伏笔',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.message.isBookmarked)
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              const _BookmarkDraft(bookmarked: false, note: ''),
            ),
            child: const Text('取消书签'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _BookmarkDraft(
              bookmarked: true,
              note: _noteController.text.trim(),
            ),
          ),
          child: const Text('保存书签'),
        ),
      ],
    );
  }
}

class _BookmarksDialog extends StatelessWidget {
  const _BookmarksDialog({required this.bookmarks});

  final List<ChatMessage> bookmarks;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppTheme.glitchText('消息书签')),
      content: SizedBox(
        width: 620,
        height: 460,
        child: ListView.separated(
          itemCount: bookmarks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final message = bookmarks[index];
            final note = message.bookmarkNote.trim();
            final preview = message.content.length > 150
                ? '${message.content.substring(0, 150)}...'
                : message.content;
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.activeLine),
              ),
              leading: const Icon(Icons.bookmark_added_rounded),
              title: Text(
                AppTheme.glitchText(note.isEmpty ? message.role.label : note),
              ),
              subtitle: Text(
                AppTheme.glitchText(preview),
                maxLines: 5,
              ),
              onTap: () => Navigator.of(context).pop(message),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _StreamingConfirmDialog extends StatefulWidget {
  const _StreamingConfirmDialog({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  State<_StreamingConfirmDialog> createState() =>
      _StreamingConfirmDialogState();
}

class _StreamingConfirmDialogState extends State<_StreamingConfirmDialog> {
  Timer? _timer;
  String _visibleText = '';
  int _cursor = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 42), (timer) {
      if (_cursor >= widget.message.length) {
        timer.cancel();
        return;
      }

      setState(() {
        _cursor += 1;
        _visibleText = widget.message.substring(0, _cursor);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Text(
          _visibleText,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('否'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('是'),
        ),
      ],
    );
  }
}
