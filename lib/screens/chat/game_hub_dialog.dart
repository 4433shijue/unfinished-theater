part of '../chat_screen.dart';

class _GameHubDialog extends StatelessWidget {
  const _GameHubDialog({
    required this.onUseItem,
    required this.onUseStoryItem,
    required this.onDestroyStoryItem,
    required this.onEditStoryItemNote,
  });

  final Future<void> Function(String itemId) onUseItem;
  final Future<void> Function(StoryInventoryItem item) onUseStoryItem;
  final Future<void> Function(StoryInventoryItem item) onDestroyStoryItem;
  final Future<void> Function(String itemName, String currentNote)
      onEditStoryItemNote;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    final maxWidth = compact ? size.width - 16 : 860.0;
    final maxHeight = size.height * (compact ? 0.88 : 0.82);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 28,
        vertical: compact ? 14 : 28,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: DefaultTabController(
            length: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Consumer<AppStateController>(
                        builder: (context, controller, _) {
                          final title = GameCatalog.cosmeticById(
                            controller.gamification.equippedTitleId,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                AppTheme.glitchText('小游戏中心'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppTheme.glitchText(
                                  '${controller.gamification.coins} 啥币 · ${title?.name ?? '平平无奇玩家'}',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textWeak),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: AppTheme.glitchText('关闭'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TabBar(
                  isScrollable: true,
                  tabs: <Widget>[
                    Tab(text: AppTheme.glitchText('今日')),
                    Tab(text: AppTheme.glitchText('商店')),
                    Tab(text: AppTheme.glitchText('唱片机')),
                    Tab(text: AppTheme.glitchText('背包')),
                    Tab(text: AppTheme.glitchText('装扮')),
                    Tab(text: AppTheme.glitchText('成就')),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Consumer<AppStateController>(
                    builder: (context, controller, _) {
                      return TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: <Widget>[
                          _GameHubDailyTab(controller: controller),
                          _GameHubShopTab(controller: controller),
                          _GameHubMusicTab(controller: controller),
                          _GameHubInventoryTab(
                            controller: controller,
                            onUseItem: onUseItem,
                            onUseStoryItem: onUseStoryItem,
                            onDestroyStoryItem: onDestroyStoryItem,
                            onEditStoryItemNote: onEditStoryItemNote,
                          ),
                          _GameHubCosmeticsTab(controller: controller),
                          _GameHubAchievementsTab(controller: controller),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameHubDailyTab extends StatelessWidget {
  const _GameHubDailyTab({required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.gamification.ensureToday();
    final character = controller.currentCharacter;
    final affinity = character == null ? null : state.affinityFor(character.id);

    return ListView(
      children: <Widget>[
        _GameHubCard(
          icon: Icons.savings_outlined,
          title: AppTheme.glitchText('今日啥币'),
          subtitle: AppTheme.glitchText(
              state.canClaimDailyBonus ? '今天还没领，路过可以薅一把。' : '今天已经领过了，明天继续。'),
          trailing: FilledButton.tonal(
            onPressed: state.canClaimDailyBonus
                ? () => _runAction(
                      context,
                      controller.claimDailyBonus,
                      successMessage: '今日啥币已领取，钱包发出了微弱的光。',
                    )
                : null,
            child: Text(AppTheme.glitchText('领取 +6')),
          ),
        ),
        if (character != null && affinity != null) ...<Widget>[
          const SizedBox(height: 12),
          _GameHubCard(
            icon: Icons.favorite_border_rounded,
            title: AppTheme.glitchText('${character.name} 的陪伴等级'),
            subtitle: AppTheme.glitchText(
              'Lv.${affinity.level} · ${affinity.xp} 熟练度 · 已完成 ${affinity.chatTurns} 次正式回复',
            ),
            trailing: _LevelBadge(level: affinity.level),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          AppTheme.glitchText('每日任务'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        for (final task in GameCatalog.dailyTasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DailyTaskTile(
              task: task,
              state: state,
              onClaim: () => _runAction(
                context,
                () => controller.claimDailyTask(task.id),
                successMessage: '任务奖励已领取，啥币到账。',
              ),
            ),
          ),
      ],
    );
  }
}

class _GameHubShopTab extends StatelessWidget {
  const _GameHubShopTab({required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Text(
          AppTheme.glitchText(
            '功能券买完进“功能券背包”，只生成小剧场或工具内容，不干扰主线；自定义商品和神秘小卖部会进入当前角色的“剧情物品栏”。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 12),
        _GameHubCard(
          icon: Icons.edit_note_outlined,
          title: AppTheme.glitchText('自定义商品 · 10啥币'),
          subtitle: AppTheme.glitchText('自己写商品名和用途，买完进入当前角色的剧情物品栏。'),
          trailing: FilledButton.tonal(
            onPressed: controller.gamification.coins >= 10
                ? () async {
                    final draft = await showDialog<_CustomStoryItemDraft>(
                      context: context,
                      builder: (context) => const _CustomStoryItemDialog(),
                    );
                    if (draft == null || !context.mounted) {
                      return;
                    }
                    await _runAction(
                      context,
                      () => controller.buyCustomStoryItem(
                        name: draft.name,
                        effect: draft.effect,
                      ),
                      successMessage: '自定义商品已入库，去剧情物品栏看看。',
                    );
                  }
                : null,
            child: Text(AppTheme.glitchText('定制')),
          ),
        ),
        const SizedBox(height: 10),
        _GameHubCard(
          icon: Icons.storefront_outlined,
          title: AppTheme.glitchText('神秘小卖部'),
          subtitle: AppTheme.glitchText('让老板按当前世界观进五件好货，价格不超过 20 啥币。'),
          trailing: FilledButton.tonal(
            onPressed: controller.isSending
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (context) =>
                          _MysteryShopDialog(controller: controller),
                    ),
            child: Text(AppTheme.glitchText('看看好货')),
          ),
        ),
        const SizedBox(height: 10),
        _GameHubCard(
          icon: Icons.casino_outlined,
          title: AppTheme.glitchText('幸运转转转 · 3啥币/次'),
          subtitle: AppTheme.glitchText(
            '2% 出 100 啥币大奖，15% 谢谢惠顾；限定称号和气泡碎片只能从这里出。',
          ),
          trailing: FilledButton.tonal(
            onPressed: controller.gamification.coins >= 3
                ? () => showDialog<void>(
                      context: context,
                      builder: (context) =>
                          _RouletteDialog(controller: controller),
                    )
                : null,
            child: Text(AppTheme.glitchText('开转')),
          ),
        ),
        const SizedBox(height: 10),
        _GameHubCard(
          icon: Icons.nightlife_outlined,
          title: AppTheme.glitchText('黑心小卖部'),
          subtitle: AppTheme.glitchText(
            '点“看看怪货”才开张；每次看货 10 啥币，怪货价格 50-500 啥币。',
          ),
          trailing: FilledButton.tonal(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => _BlackMarketDialog(controller: controller),
            ),
            child: Text(AppTheme.glitchText('看看怪货')),
          ),
        ),
        if (controller.gamification.stat('currentDebtCoins') > 0) ...<Widget>[
          const SizedBox(height: 10),
          _GameHubCard(
            icon: Icons.receipt_long_outlined,
            title: AppTheme.glitchText(
              '欠老板 ${controller.gamification.stat('currentDebtCoins')} 啥币',
            ),
            subtitle: AppTheme.glitchText('还掉债务之后，老板追债小剧场会少一点点。'),
            trailing: FilledButton.tonal(
              onPressed: controller.gamification.coins > 0
                  ? () => _runAction(
                        context,
                        controller.repayDebt,
                        successMessage: '还债成功，老板的小本本少了一笔。',
                      )
                  : null,
              child: Text(AppTheme.glitchText('还债')),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(AppTheme.glitchText('功能券货架'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final item in GameCatalog.shopItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShopItemTile(
              item: item,
              coins: controller.gamification.coins,
              onBuy: () => _runAction(
                context,
                () => controller.buyShopItem(item.id),
                successMessage: '买到了「${item.name}」，去“背包”里点使用。',
              ),
            ),
          ),
      ],
    );
  }
}

class _GameHubMusicTab extends StatefulWidget {
  const _GameHubMusicTab({required this.controller});

  final AppStateController controller;

  @override
  State<_GameHubMusicTab> createState() => _GameHubMusicTabState();
}

class _GameHubMusicTabState extends State<_GameHubMusicTab> {
  AppStateController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.controller.noteMusicPanelOpened();
  }

  @override
  Widget build(BuildContext context) {
    final music = controller.musicState;
    final tracks = controller.musicTracks;
    final current = music.currentTrack(tracks);
    final usedSlots = tracks.length;
    final totalSlots = music.slotCount;
    return ListView(
      children: <Widget>[
        _MusicNowPlayingCard(
          track: current,
          state: music,
          onToggle: () => _runAction(
            context,
            controller.toggleMusicPlayback,
            successMessage: music.isPlaying ? '音频已暂停。' : '剧场音轨开始播放。',
          ),
          onPrevious: () => _runAction(
            context,
            controller.playPreviousMusicTrack,
            successMessage: '已切到上一段音频。',
          ),
          onNext: () => _runAction(
            context,
            controller.playNextMusicTrack,
            successMessage: '已切到下一段音频。',
          ),
          onLoopChanged: (mode) => _runAction(
            context,
            () => controller.setMusicLoopMode(mode),
            successMessage:
                mode == MusicLoopMode.single ? '已开启单曲循环。' : '已开启歌单循环。',
          ),
          onVolumeChanged: (value) => controller.setMusicVolume(value),
        ),
        const SizedBox(height: 14),
        _MusicLibraryHeader(
          usedSlots: usedSlots,
          totalSlots: totalSlots,
          coins: controller.gamification.coins,
          onUpload: usedSlots < totalSlots
              ? () => _runAction(
                    context,
                    controller.pickAndAddMusicTrack,
                    successMessage: '音频已加入剧场。',
                  )
              : null,
          onUnlock: () => _runAction(
            context,
            controller.unlockMusicSlot,
            successMessage: '新的音频格子已解锁。',
          ),
        ),
        const SizedBox(height: 10),
        if (tracks.isEmpty)
          const _SoftEmptyLine(
            text: '这里不会再内置任何 BGM。上传你自己有权使用的音频后，就能让小剧场有声音。',
          )
        else
          ...tracks.map(
            (track) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MusicTrackTile(
                track: track,
                selected: music.currentTrackId == track.id,
                inPlaylist: music.playlistTrackIds.contains(track.id),
                onPlay: () => _runAction(
                  context,
                  () => controller.playMusicTrack(track.id, source: 'card'),
                  successMessage: '正在播放 ${track.title}。',
                ),
                onAdd: () => _runAction(
                  context,
                  () => controller.addTrackToPlaylist(track.id),
                  successMessage: '${track.title} 已加入歌单。',
                ),
                onRename: () => _renameTrack(context, track),
                onDelete: () => _deleteTrack(context, track),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _MusicQuickSelect(
          tracks: tracks,
          state: music,
          onChanged: (trackId) => _runAction(
            context,
            () => controller.playMusicTrack(trackId, source: 'dropdown'),
            successMessage: '已切换音频。',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppTheme.glitchText('我的歌单'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              AppTheme.glitchText('${music.playlistTrackIds.length} 段'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MusicPlaylistEditor(
          controller: controller,
          state: music,
          tracks: tracks,
        ),
      ],
    );
  }

  Future<void> _renameTrack(BuildContext context, BackgroundTrack track) async {
    final controller = TextEditingController(text: track.title);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTheme.glitchText('重命名音频')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('音频名称'),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(AppTheme.glitchText('保存')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runAction(
      context,
      () => this.controller.renameMusicTrack(track.id, result),
      successMessage: '音频名称已更新。',
    );
  }

  Future<void> _deleteTrack(BuildContext context, BackgroundTrack track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTheme.glitchText('删除音频')),
        content: Text(AppTheme.glitchText('会从本地音频库和歌单里移除 ${track.title}。')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppTheme.glitchText('删除')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runAction(
      context,
      () => controller.deleteMusicTrack(track.id),
      successMessage: '音频已删除。',
    );
  }
}

class _MusicNowPlayingCard extends StatelessWidget {
  const _MusicNowPlayingCard({
    required this.track,
    required this.state,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
    required this.onLoopChanged,
    required this.onVolumeChanged,
  });

  final BackgroundTrack? track;
  final MusicPlaybackState state;
  final VoidCallback onToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<MusicLoopMode> onLoopChanged;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final hasTrack = track != null;
    final title = track?.title ?? '等待上传音频';
    final subtitle = hasTrack
        ? '${track!.displayFormat} · ${_formatBytes(track!.sizeBytes)} · ${state.loopMode == MusicLoopMode.single ? '单曲循环' : '歌单循环'}'
        : '本地音频不会随数据导出，也不会由 App 提供素材';
    final disc = Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: <Color>[
          AppTheme.activePrimary,
          AppTheme.activeSecondary,
          AppTheme.activeAccent,
          AppTheme.activePrimary,
        ]),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.activePrimary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        state.isPlaying ? Icons.graphic_eq_rounded : Icons.album_rounded,
        color: Colors.white,
      ),
    );
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        IconButton.filledTonal(
          style: AppTheme.skinIconButtonStyle(),
          onPressed: hasTrack ? onPrevious : null,
          icon: const Icon(Icons.skip_previous_rounded),
          tooltip: AppTheme.glitchText('上一段'),
        ),
        IconButton.filled(
          style: AppTheme.skinIconButtonStyle(primary: true),
          onPressed: hasTrack ? onToggle : null,
          icon: Icon(
              state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          tooltip: AppTheme.glitchText(state.isPlaying ? '暂停' : '播放'),
        ),
        IconButton.filledTonal(
          style: AppTheme.skinIconButtonStyle(),
          onPressed: hasTrack ? onNext : null,
          icon: const Icon(Icons.skip_next_rounded),
          tooltip: AppTheme.glitchText('下一段'),
        ),
      ],
    );
    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 26),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                disc,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppTheme.glitchText(title),
                        maxLines: compact ? 3 : 2,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        AppTheme.glitchText(subtitle),
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
              child: controls,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  selected: state.loopMode == MusicLoopMode.playlist,
                  label: Text(AppTheme.glitchText('歌单循环')),
                  onSelected: (_) => onLoopChanged(MusicLoopMode.playlist),
                ),
                ChoiceChip(
                  selected: state.loopMode == MusicLoopMode.single,
                  label: Text(AppTheme.glitchText('单曲循环')),
                  onSelected: (_) => onLoopChanged(MusicLoopMode.single),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Icon(Icons.volume_down_rounded),
                Expanded(
                  child: Slider(
                    value: state.volume,
                    onChanged: onVolumeChanged,
                  ),
                ),
                const Icon(Icons.volume_up_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicLibraryHeader extends StatelessWidget {
  const _MusicLibraryHeader({
    required this.usedSlots,
    required this.totalSlots,
    required this.coins,
    required this.onUpload,
    required this.onUnlock,
  });

  final int usedSlots;
  final int totalSlots;
  final int coins;
  final VoidCallback? onUpload;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPanel(radius: 20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              AppTheme.glitchText('本地音频 $usedSlots/$totalSlots'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(AppTheme.glitchText('上传音频')),
            ),
            OutlinedButton.icon(
              onPressed: coins >= MusicCatalog.slotUnlockCost ? onUnlock : null,
              icon: const Icon(Icons.add_box_outlined),
              label: Text(AppTheme.glitchText('30啥币开格')),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicTrackTile extends StatelessWidget {
  const _MusicTrackTile({
    required this.track,
    required this.selected,
    required this.inPlaylist,
    required this.onPlay,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
  });

  final BackgroundTrack track;
  final bool selected;
  final bool inPlaylist;
  final VoidCallback onPlay;
  final VoidCallback onAdd;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: selected, radius: 18),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.activePrimary.withValues(alpha: 0.18),
          child: Icon(
            selected ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
            color: AppTheme.activePrimary,
          ),
        ),
        title: Text(AppTheme.glitchText(track.title), maxLines: 2),
        subtitle: Text(
          AppTheme.glitchText(
              '${track.displayFormat} · ${_formatBytes(track.sizeBytes)}'),
        ),
        trailing: Wrap(
          spacing: 4,
          children: <Widget>[
            IconButton(
              tooltip: AppTheme.glitchText('播放'),
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            IconButton(
              tooltip: AppTheme.glitchText(inPlaylist ? '已在歌单' : '加入歌单'),
              onPressed: inPlaylist ? null : onAdd,
              icon: Icon(inPlaylist
                  ? Icons.playlist_add_check_rounded
                  : Icons.playlist_add_rounded),
            ),
            IconButton(
              tooltip: AppTheme.glitchText('重命名'),
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: AppTheme.glitchText('删除'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicQuickSelect extends StatelessWidget {
  const _MusicQuickSelect({
    required this.tracks,
    required this.state,
    required this.onChanged,
  });

  final List<BackgroundTrack> tracks;
  final MusicPlaybackState state;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPanel(radius: 20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DropdownButtonFormField<String>(
          initialValue: tracks.any((track) => track.id == state.currentTrackId)
              ? state.currentTrackId
              : null,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('快速切换音频'),
          ),
          items: <DropdownMenuItem<String>>[
            for (final track in tracks)
              DropdownMenuItem<String>(
                value: track.id,
                child: Text(
                  AppTheme.glitchText(track.title),
                  maxLines: 2,
                ),
              ),
          ],
          onChanged: tracks.isEmpty
              ? null
              : (value) {
                  if (value != null) {
                    onChanged(value);
                  }
                },
        ),
      ),
    );
  }
}

class _MusicPlaylistEditor extends StatelessWidget {
  const _MusicPlaylistEditor({
    required this.controller,
    required this.state,
    required this.tracks,
  });

  final AppStateController controller;
  final MusicPlaybackState state;
  final List<BackgroundTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final ids = state.playlistTrackIds;
    return DecoratedBox(
      decoration: AppTheme.glassPanel(radius: 22),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ids.isEmpty
            ? const _SoftEmptyLine(text: '歌单是空的，先从上面的音频列表里加入一段。')
            : ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: ids.length,
                onReorder: (oldIndex, newIndex) => _runAction(
                  context,
                  () => controller.reorderMusicPlaylist(oldIndex, newIndex),
                  successMessage: '歌单顺序已调整。',
                ),
                itemBuilder: (context, index) {
                  final track = MusicCatalog.byId(tracks, ids[index]);
                  if (track == null) {
                    return const SizedBox.shrink(key: ValueKey('missing'));
                  }
                  return ListTile(
                    key: ValueKey(track.id),
                    contentPadding: EdgeInsets.zero,
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator_rounded),
                    ),
                    title: Text(AppTheme.glitchText(track.title)),
                    subtitle: Text(AppTheme.glitchText(track.displayFormat)),
                    trailing: Wrap(
                      spacing: 4,
                      children: <Widget>[
                        IconButton(
                          tooltip: AppTheme.glitchText('播放'),
                          onPressed: () => _runAction(
                            context,
                            () => controller.playMusicTrack(track.id),
                            successMessage: '正在播放 ${track.title}。',
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                        IconButton(
                          tooltip: AppTheme.glitchText('移出歌单'),
                          onPressed: () => _runAction(
                            context,
                            () => controller.removeTrackFromPlaylist(track.id),
                            successMessage: '${track.title} 已移出歌单。',
                          ),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

class _GameHubInventoryTab extends StatefulWidget {
  const _GameHubInventoryTab({
    required this.controller,
    required this.onUseItem,
    required this.onUseStoryItem,
    required this.onDestroyStoryItem,
    required this.onEditStoryItemNote,
  });

  final AppStateController controller;
  final Future<void> Function(String itemId) onUseItem;
  final Future<void> Function(StoryInventoryItem item) onUseStoryItem;
  final Future<void> Function(StoryInventoryItem item) onDestroyStoryItem;
  final Future<void> Function(String itemName, String currentNote)
      onEditStoryItemNote;

  @override
  State<_GameHubInventoryTab> createState() => _GameHubInventoryTabState();
}

class _GameHubInventoryTabState extends State<_GameHubInventoryTab> {
  bool _batchMode = false;
  final Set<String> _selectedTickets = <String>{};
  final Set<String> _selectedStoryItems = <String>{};

  AppStateController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.gamification;
    final inventoryEntries = state.inventory.entries
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    final storyItems = controller.currentGameState.storyInventory;
    final selectedCount = _selectedTickets.length + _selectedStoryItems.length;

    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(AppTheme.glitchText('功能券背包'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            FilledButton.tonalIcon(
              onPressed: inventoryEntries.isEmpty && storyItems.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _batchMode = !_batchMode;
                        if (!_batchMode) {
                          _selectedTickets.clear();
                          _selectedStoryItems.clear();
                        }
                      });
                    },
              icon: Icon(_batchMode
                  ? Icons.close_rounded
                  : Icons.checklist_rtl_rounded),
              label: Text(AppTheme.glitchText(_batchMode ? '退出批量' : '批量管理')),
            ),
          ],
        ),
        if (_batchMode) ...<Widget>[
          const SizedBox(height: 10),
          _BatchInventoryBar(
            selectedCount: selectedCount,
            onSelectAll: () {
              setState(() {
                _selectedTickets
                  ..clear()
                  ..addAll(inventoryEntries.map((entry) => entry.key));
                _selectedStoryItems
                  ..clear()
                  ..addAll(storyItems.map((item) => item.id));
              });
            },
            onSelectTickets: () {
              setState(() {
                _selectedTickets
                  ..clear()
                  ..addAll(inventoryEntries.map((entry) => entry.key));
              });
            },
            onSelectStoryItems: () {
              setState(() {
                _selectedStoryItems
                  ..clear()
                  ..addAll(storyItems.map((item) => item.id));
              });
            },
            onClear: () {
              setState(() {
                _selectedTickets.clear();
                _selectedStoryItems.clear();
              });
            },
            onDelete: selectedCount == 0 ? null : _deleteSelectedInventory,
          ),
        ],
        const SizedBox(height: 10),
        if (inventoryEntries.isEmpty)
          const _SoftEmptyLine(text: '背包空空，商店老板正在假装没看见你。')
        else
          for (final entry in inventoryEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SelectableInventoryCard(
                selected: _selectedTickets.contains(entry.key),
                batchMode: _batchMode,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _selectedTickets.add(entry.key);
                    } else {
                      _selectedTickets.remove(entry.key);
                    }
                  });
                },
                child: _InventoryItemTile(
                  item: GameCatalog.shopItemById(entry.key),
                  count: entry.value,
                  onUse: () => widget.onUseItem(entry.key),
                  disabled: _batchMode,
                ),
              ),
            ),
        const SizedBox(height: 18),
        Text(AppTheme.glitchText('剧情物品栏'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (storyItems.length >= 2)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => _SynthesisDialog(controller: controller),
              ),
              icon: const Icon(Icons.science_outlined),
              label: Text(AppTheme.glitchText('道具合成 · 5啥币')),
            ),
          ),
        const SizedBox(height: 10),
        if (storyItems.isEmpty)
          const _SoftEmptyLine(text: '当前剧情还没有沉淀物品，等 AI 更新游戏面板后这里会出现。')
        else
          for (final item in storyItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StoryItemTile(
                item: item,
                note: state.storyItemNotes[item.name] ?? '',
                selected: _selectedStoryItems.contains(item.id),
                batchMode: _batchMode,
                onSelectedChanged: (value) {
                  setState(() {
                    if (value) {
                      _selectedStoryItems.add(item.id);
                    } else {
                      _selectedStoryItems.remove(item.id);
                    }
                  });
                },
                onUse: () => widget.onUseStoryItem(item),
                onDestroy: () => widget.onDestroyStoryItem(item),
                onIdentify: () => _runAction(
                  context,
                  () => controller.identifyStoryInventoryItem(item.id),
                  successMessage: '鉴定完成，这玩意儿终于知道怎么用了。',
                ),
                onEdit: () => widget.onEditStoryItemNote(
                  item.name,
                  state.storyItemNotes[item.name] ?? '',
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _deleteSelectedInventory() async {
    final ticketCount = _selectedTickets.fold<int>(
      0,
      (sum, id) => sum + controller.gamification.inventoryCount(id),
    );
    final storyCount = _selectedStoryItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _StreamingConfirmDialog(
        title: '批量删除背包内容',
        message: '确定删除 $ticketCount 张功能券和 $storyCount 个剧情物品吗？',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    String? error;
    if (_selectedTickets.isNotEmpty) {
      error = await controller.deleteInventoryItems(_selectedTickets);
    }
    if (error == null && _selectedStoryItems.isNotEmpty) {
      error = await controller.destroyStoryInventoryItems(_selectedStoryItems);
    }
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    setState(() {
      _selectedTickets.clear();
      _selectedStoryItems.clear();
      _batchMode = false;
    });
    _showTopNotice(context, '背包已批量整理完成。');
  }
}

class _GameHubCosmeticsTab extends StatelessWidget {
  const _GameHubCosmeticsTab({required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.gamification;
    final currentCharacter = controller.currentCharacter;
    final bindableCharacters = controller.characters;
    final titles = GameCatalog.cosmetics
        .where((item) => item.type == CosmeticType.title)
        .toList(growable: false);
    final frames = GameCatalog.cosmetics
        .where((item) => item.type == CosmeticType.frame)
        .toList(growable: false);
    return ListView(
      children: <Widget>[
        _EquippedCosmeticCard(
          state: state,
          currentCharacterName: currentCharacter?.name,
          currentCharacterFrameId: currentCharacter == null
              ? null
              : state.characterBubbleFrameIds[currentCharacter.id],
        ),
        const SizedBox(height: 10),
        Text(
          AppTheme.glitchText(
            '装扮分成“称号”和“气泡边框”。气泡边框可全局装备，也可以绑定当前角色；自定义气泡格子 50 啥币一个，支持粘贴限定 CSS 子集。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 14),
        Text(AppTheme.glitchText('称号仓库'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final cosmetic in titles)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CosmeticTile(
              cosmetic: cosmetic,
              state: state,
              onBuy: () => _runAction(
                context,
                () => controller.buyCosmetic(cosmetic.id),
                successMessage: '装扮「${cosmetic.name}」已入库，直接在本页点“装备”。',
              ),
              onEquip: () => _runAction(
                context,
                () => controller.equipCosmetic(cosmetic.id),
                successMessage: '已装备「${cosmetic.name}」。',
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(AppTheme.glitchText('气泡边框'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _CustomBubbleCreator(controller: controller),
        const SizedBox(height: 10),
        for (final custom in state.customBubbleStyles)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CustomBubbleTile(
              style: custom,
              state: state,
              currentCharacterId: currentCharacter?.id,
              characters: bindableCharacters,
              onEdit: () => _openCustomBubbleEditor(
                context,
                controller: controller,
                style: custom,
              ),
              onDelete: () => _runAction(
                context,
                () => controller.deleteCustomBubbleStyle(custom.id),
                successMessage: '自定义气泡「${custom.name}」已删除。',
              ),
              onEquip: () => _runAction(
                context,
                () => controller.equipBubbleFrame(custom.id),
                successMessage: '已全局装备「${custom.name}」。',
              ),
              onAssign: () => _openBubbleBindDialog(
                context,
                controller: controller,
                frameId: custom.id,
                frameName: custom.name,
              ),
            ),
          ),
        for (final cosmetic in frames)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CosmeticTile(
              cosmetic: cosmetic,
              state: state,
              characters: bindableCharacters,
              onBuy: () => _runAction(
                context,
                () => controller.buyCosmetic(cosmetic.id),
                successMessage: '边框「${cosmetic.name}」已入库，直接在本页点“装备”。',
              ),
              onEquip: () => _runAction(
                context,
                () => controller.equipBubbleFrame(cosmetic.id),
                successMessage: '已装备「${cosmetic.name}」。',
              ),
              onAssign: () => _openBubbleBindDialog(
                context,
                controller: controller,
                frameId: cosmetic.id,
                frameName: cosmetic.name,
              ),
            ),
          ),
        if (currentCharacter != null &&
            state.characterBubbleFrameIds.containsKey(currentCharacter.id))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton.icon(
              onPressed: () => _runAction(
                context,
                controller.clearCurrentCharacterBubbleFrame,
                successMessage: '当前角色已恢复使用全局气泡。',
              ),
              icon: const Icon(Icons.link_off_rounded),
              label: Text(AppTheme.glitchText('取消当前角色气泡绑定')),
            ),
          ),
      ],
    );
  }
}

class _GameHubAchievementsTab extends StatelessWidget {
  const _GameHubAchievementsTab({required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.gamification;
    return ListView(
      children: <Widget>[
        Text(
          AppTheme.glitchText(
              '已解锁 ${state.unlockedAchievementIds.length}/${GameCatalog.achievements.length}'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final achievement in GameCatalog.achievements)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AchievementTile(
              achievement: achievement,
              state: state,
            ),
          ),
      ],
    );
  }
}

class _GameHubCard extends StatelessWidget {
  const _GameHubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.preview,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? preview;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final content = <Widget>[
      Icon(icon, color: AppTheme.activePrimary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTheme.glitchText(title),
              maxLines: compact ? 3 : 2,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              AppTheme.glitchText(subtitle),
              maxLines: compact ? 6 : 4,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    ];
    return DecoratedBox(
      decoration: AppTheme.glassPanel(radius: 22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: compact && (trailing != null || preview != null)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(children: content),
                  if (preview != null) ...<Widget>[
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: preview!),
                  ],
                  if (trailing != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: trailing!,
                    ),
                  ],
                ],
              )
            : Row(
                children: <Widget>[
                  ...content,
                  if (preview != null) ...<Widget>[
                    const SizedBox(width: 16),
                    SizedBox(width: 260, child: preview!),
                  ],
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
      ),
    );
  }
}

class _DailyTaskTile extends StatelessWidget {
  const _DailyTaskTile({
    required this.task,
    required this.state,
    required this.onClaim,
  });

  final DailyTaskDefinition task;
  final GamificationState state;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final progress = state.dailyStat(task.statKey);
    final done = progress >= task.target;
    final claimed = state.isDailyTaskClaimed(task.id);
    return _GameHubCard(
      icon: done ? Icons.task_alt_rounded : Icons.radio_button_unchecked,
      title: task.name,
      subtitle:
          '${task.description} 进度 ${progress.clamp(0, task.target)}/${task.target} · 奖励 ${task.rewardCoins} 啥币',
      trailing: FilledButton.tonal(
        onPressed: done && !claimed ? onClaim : null,
        child: Text(AppTheme.glitchText(claimed ? '已领' : '领奖')),
      ),
    );
  }
}

class _ShopItemTile extends StatelessWidget {
  const _ShopItemTile({
    required this.item,
    required this.coins,
    required this.onBuy,
  });

  final ShopItemDefinition item;
  final int coins;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return _GameHubCard(
      icon: Icons.local_activity_outlined,
      title: '${item.name} · ${item.cost}啥币',
      subtitle: item.description,
      trailing: FilledButton.tonal(
        onPressed: coins >= item.cost ? onBuy : null,
        child: Text(AppTheme.glitchText('购买')),
      ),
    );
  }
}
