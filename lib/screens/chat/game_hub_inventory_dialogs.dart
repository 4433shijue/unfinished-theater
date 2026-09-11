part of '../chat_screen.dart';

class _CustomStoryItemDraft {
  const _CustomStoryItemDraft({
    required this.name,
    required this.effect,
  });

  final String name;
  final String effect;
}

class _CustomStoryItemDialog extends StatefulWidget {
  const _CustomStoryItemDialog();

  @override
  State<_CustomStoryItemDialog> createState() => _CustomStoryItemDialogState();
}

class _CustomStoryItemDialogState extends State<_CustomStoryItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _effectController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _effectController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppTheme.glitchText('定制剧情商品')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppTheme.glitchText('商品名称'),
                hintText: AppTheme.glitchText('例如：没寄出的信 / 偏心硬币'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _effectController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: AppTheme.glitchText('商品功能'),
                hintText: AppTheme.glitchText('写清楚它在主线里可能造成什么影响。'),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _CustomStoryItemDraft(
                name: _nameController.text.trim(),
                effect: _effectController.text.trim(),
              ),
            );
          },
          child: Text(AppTheme.glitchText('买下')),
        ),
      ],
    );
  }
}

class _SynthesisDialog extends StatefulWidget {
  const _SynthesisDialog({required this.controller});

  final AppStateController controller;

  @override
  State<_SynthesisDialog> createState() => _SynthesisDialogState();
}

class _SynthesisDialogState extends State<_SynthesisDialog> {
  String? _firstId;
  String? _secondId;
  bool _working = false;

  Future<void> _synthesize() async {
    final first = _firstId;
    final second = _secondId;
    if (first == null || second == null || first == second || _working) {
      return;
    }
    setState(() => _working = true);
    final error = await widget.controller.synthesizeStoryInventoryItems(
      firstItemId: first,
      secondItemId: second,
    );
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    _showTopNotice(context, '合成完成，新怪东西已放进剧情物品栏。');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.controller.currentGameState.storyInventory;
    DropdownButtonFormField<String> picker({
      required String label,
      required String? value,
      required ValueChanged<String?> onChanged,
    }) {
      return DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: AppTheme.glitchText(label)),
        items: <DropdownMenuItem<String>>[
          for (final item in items)
            DropdownMenuItem<String>(
              value: item.id,
              child: Text(
                AppTheme.glitchText(item.name),
                maxLines: 3,
              ),
            ),
        ],
        onChanged: _working ? null : onChanged,
      );
    }

    return AlertDialog(
      title: Text(AppTheme.glitchText('道具合成')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              AppTheme.glitchText('花 5 啥币，把两个剧情物品合成一个更怪、更能惹事的新道具。'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            picker(
              label: '道具 A',
              value: _firstId,
              onChanged: (value) => setState(() => _firstId = value),
            ),
            const SizedBox(height: 12),
            picker(
              label: '道具 B',
              value: _secondId,
              onChanged: (value) => setState(() => _secondId = value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: _firstId != null &&
                  _secondId != null &&
                  _firstId != _secondId &&
                  !_working
              ? _synthesize
              : null,
          child: Text(AppTheme.glitchText(_working ? '合成中...' : '开始合成')),
        ),
      ],
    );
  }
}

class _RouletteDialog extends StatefulWidget {
  const _RouletteDialog({required this.controller});

  final AppStateController controller;

  @override
  State<_RouletteDialog> createState() => _RouletteDialogState();
}

class _RouletteDialogState extends State<_RouletteDialog> {
  RouletteSpinResult? _result;
  bool _spinning = false;

  Future<void> _spin() async {
    if (_spinning) {
      return;
    }
    setState(() => _spinning = true);
    final result = await widget.controller.spinLuckyRoulette();
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _spinning = false;
    });
    _showTopNotice(
      context,
      result.empty ? result.title : '${result.title}：${result.rewardLabel}',
      isError: result.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.gamification;
    final emptyStreak = state.stat('rouletteEmptyStreak');
    final rarePity = state.stat('rouletteRarePity');
    return AlertDialog(
      title: Text(AppTheme.glitchText('幸运转转转')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTheme.glitchText(
                '3 啥币一次。大奖 2%，谢谢惠顾 15%，连续 10 次空奖保底不空；50 次未出稀有会强制掉限定或稀有奖励。',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              AppTheme.glitchText(
                  '当前：${state.coins} 啥币 · 空奖 $emptyStreak/10 · 稀有保底 $rarePity/50'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassPanel(radius: 22),
              child: Row(
                children: <Widget>[
                  Icon(
                    _result?.jackpot == true
                        ? Icons.emoji_events_outlined
                        : Icons.auto_awesome_outlined,
                    color: AppTheme.activeSoft,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppTheme.glitchText(
                        _result == null
                            ? '转盘正在柜台后面发出可疑的咔哒声。'
                            : '${_result!.title}\n${_result!.description}\n${_result!.rewardLabel}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _spinning ? null : () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('收手')),
        ),
        FilledButton(
          onPressed: _spinning || state.coins < 3 ? null : _spin,
          child: Text(AppTheme.glitchText(_spinning ? '转动中...' : '转一次')),
        ),
      ],
    );
  }
}

class _BlackMarketDialog extends StatefulWidget {
  const _BlackMarketDialog({required this.controller});

  final AppStateController controller;

  @override
  State<_BlackMarketDialog> createState() => _BlackMarketDialogState();
}

class _BlackMarketDialogState extends State<_BlackMarketDialog> {
  List<StoryShopOffer> _offers = const <StoryShopOffer>[];
  final Set<String> _boughtIds = <String>{};
  bool _isLoading = false;
  String? _error;

  Future<void> _generateOffers() async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final offers = await widget.controller.generateBlackMarketOffers();
      if (!mounted) {
        return;
      }
      setState(() {
        _offers = offers;
        _boughtIds.clear();
      });
      _showTopNotice(context, '老板收了 10 啥币看货费，怪货已经摆上柜台。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
      _showTopNotice(context, '老板翻箱倒柜失败了：$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _buy(StoryShopOffer offer, {required bool useDebt}) async {
    final error =
        await widget.controller.buyBlackMarketOffer(offer, useDebt: useDebt);
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    setState(() => _boughtIds.add(offer.id));
    _showTopNotice(context, '买到「${offer.name}」了，已经塞进剧情物品栏。');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    final coins = widget.controller.gamification.coins;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 24,
        vertical: compact ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? size.width * 0.96 : 620,
          maxHeight: compact ? size.height * 0.92 : 720,
        ),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppTheme.glitchText('黑心小卖部'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: compact ? double.infinity : 390,
                    child: Text(
                      AppTheme.glitchText(
                        '每次看货或重开货单收 10 啥币；怪货 50-500 啥币，部分效果未知。啥币不够买货时可以赊账。',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textMuted, height: 1.45),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isLoading ? null : _generateOffers,
                    icon: _isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textMain,
                            ),
                          )
                        : const Icon(Icons.auto_fix_high_rounded),
                    label: Text(AppTheme.glitchText(
                      _offers.isEmpty ? '看看怪货' : '重开货单 · 10啥币',
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading && _offers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            CircularProgressIndicator(
                              color: AppTheme.activeSoft,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              AppTheme.glitchText('黑心老板努力翻暗柜中...'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : _offers.isEmpty
                        ? Center(
                            child: Text(
                              AppTheme.glitchText(
                                _error == null
                                    ? '柜台还是空的，点“看看怪货”让老板开箱。'
                                    : '刚才没翻出能看的货：$_error',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          )
                        : ListView(
                            children: <Widget>[
                              for (final offer in _offers)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _GameHubCard(
                                    icon: offer.effect.trim().isEmpty
                                        ? Icons.help_outline_rounded
                                        : Icons.shopping_bag_outlined,
                                    title: '${offer.name} · ${offer.cost}啥币',
                                    subtitle: offer.effect.trim().isEmpty
                                        ? '${offer.description}\n效果：未知，买完需要鉴定。'
                                        : '${offer.description}\n用途：${offer.effect}',
                                    trailing: FilledButton.tonal(
                                      onPressed: _boughtIds.contains(offer.id)
                                          ? null
                                          : () => _buy(
                                                offer,
                                                useDebt: coins < offer.cost,
                                              ),
                                      child: Text(AppTheme.glitchText(
                                        _boughtIds.contains(offer.id)
                                            ? '已买'
                                            : coins >= offer.cost
                                                ? '购买'
                                                : '赊账',
                                      )),
                                    ),
                                  ),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MysteryShopDialog extends StatefulWidget {
  const _MysteryShopDialog({required this.controller});

  final AppStateController controller;

  @override
  State<_MysteryShopDialog> createState() => _MysteryShopDialogState();
}

class _MysteryShopDialogState extends State<_MysteryShopDialog> {
  late final Future<List<StoryShopOffer>> _offersFuture;
  final Set<String> _boughtIds = <String>{};

  @override
  void initState() {
    super.initState();
    _offersFuture = widget.controller.generateMysteryShopOffers();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 24,
        vertical: compact ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? size.width * 0.96 : 620,
          maxHeight: compact ? size.height * 0.92 : 720,
        ),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppTheme.glitchText('神秘小卖部'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<StoryShopOffer>>(
                  future: _offersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            CircularProgressIndicator(
                              color: AppTheme.activeSoft,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              AppTheme.glitchText('商店老板努力中...'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          AppTheme.glitchText('老板翻箱倒柜失败了：${snapshot.error}'),
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      );
                    }
                    final offers = snapshot.data ?? const <StoryShopOffer>[];
                    return ListView(
                      children: <Widget>[
                        for (final offer in offers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _GameHubCard(
                              icon: Icons.shopping_bag_outlined,
                              title: '${offer.name} · ${offer.cost}啥币',
                              subtitle:
                                  '${offer.description}\n用途：${offer.effect}',
                              trailing: FilledButton.tonal(
                                onPressed: _boughtIds.contains(offer.id) ||
                                        widget.controller.gamification.coins <
                                            offer.cost
                                    ? null
                                    : () => _buyOffer(offer),
                                child: Text(AppTheme.glitchText(
                                  _boughtIds.contains(offer.id) ? '已买' : '购买',
                                )),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyOffer(StoryShopOffer offer) async {
    final error = await widget.controller.buyStoryShopOffer(offer);
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    setState(() => _boughtIds.add(offer.id));
    _showTopNotice(context, '买到「${offer.name}」了，已经放进剧情物品栏。');
  }
}

class _InventoryItemTile extends StatelessWidget {
  const _InventoryItemTile({
    required this.item,
    required this.count,
    required this.onUse,
    this.disabled = false,
  });

  final ShopItemDefinition? item;
  final int count;
  final VoidCallback onUse;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final title = item?.name ?? '未知道具';
    final description = item?.description ?? '这个道具来自旧版本，暂时无法识别。';
    return _GameHubCard(
      icon: Icons.inventory_2_outlined,
      title: '$title × $count',
      subtitle: description,
      trailing: FilledButton.tonal(
        onPressed: item == null || disabled ? null : onUse,
        child: Text(AppTheme.glitchText('使用')),
      ),
    );
  }
}

class _SelectableInventoryCard extends StatelessWidget {
  const _SelectableInventoryCard({
    required this.selected,
    required this.batchMode,
    required this.onChanged,
    required this.child,
  });

  final bool selected;
  final bool batchMode;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!batchMode) {
      return child;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 8),
          child: Checkbox(
            value: selected,
            onChanged: (value) => onChanged(value ?? false),
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onChanged(!selected),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _BatchInventoryBar extends StatelessWidget {
  const _BatchInventoryBar({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onSelectTickets,
    required this.onSelectStoryItems,
    required this.onClear,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectTickets;
  final VoidCallback onSelectStoryItems;
  final VoidCallback onClear;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            AppTheme.glitchText('已选 $selectedCount 项'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          OutlinedButton.icon(
            onPressed: onSelectAll,
            icon: const Icon(Icons.select_all_rounded),
            label: Text(AppTheme.glitchText('全选')),
          ),
          OutlinedButton.icon(
            onPressed: onSelectTickets,
            icon: const Icon(Icons.local_activity_outlined),
            label: Text(AppTheme.glitchText('全选功能券')),
          ),
          OutlinedButton.icon(
            onPressed: onSelectStoryItems,
            icon: const Icon(Icons.backpack_outlined),
            label: Text(AppTheme.glitchText('全选剧情物品')),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
            label: Text(AppTheme.glitchText('清空选择')),
          ),
          FilledButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(AppTheme.glitchText('删除所选')),
          ),
        ],
      ),
    );
  }
}

class _StoryItemTile extends StatelessWidget {
  const _StoryItemTile({
    required this.item,
    required this.note,
    required this.selected,
    required this.batchMode,
    required this.onSelectedChanged,
    required this.onUse,
    required this.onDestroy,
    required this.onIdentify,
    required this.onEdit,
  });

  final StoryInventoryItem item;
  final String note;
  final bool selected;
  final bool batchMode;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onUse;
  final VoidCallback onDestroy;
  final VoidCallback onIdentify;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (!item.identified) '状态：未鉴定 · 需要 3 啥币',
      if (item.description.trim().isNotEmpty) item.description.trim(),
      if (item.identified && item.effect.trim().isNotEmpty)
        '用途：${item.effect.trim()}',
      if (!item.identified && item.mysteryHint.trim().isNotEmpty)
        '线索：${item.mysteryHint.trim()}',
      if (note.trim().isNotEmpty) '备注：$note',
    ].join('\n');
    final card = _GameHubCard(
      icon: Icons.backpack_outlined,
      title: item.name,
      subtitle: details.trim().isEmpty ? '还没有说明，像一件命运感很强的无名小玩意。' : details,
      trailing: batchMode
          ? Checkbox(
              value: selected,
              onChanged: (value) => onSelectedChanged(value ?? false),
            )
          : Wrap(
              spacing: 4,
              children: <Widget>[
                IconButton(
                  tooltip: AppTheme.glitchText('投入主线'),
                  onPressed: item.identified ? onUse : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                if (!item.identified)
                  IconButton(
                    tooltip: AppTheme.glitchText('鉴定'),
                    onPressed: onIdentify,
                    icon: const Icon(Icons.manage_search_rounded),
                  ),
                IconButton(
                  tooltip: AppTheme.glitchText('编辑备注'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_note_outlined),
                ),
                IconButton(
                  tooltip: AppTheme.glitchText('销毁'),
                  onPressed: onDestroy,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
    );
    if (!batchMode) {
      return card;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => onSelectedChanged(!selected),
      child: card,
    );
  }
}

class _EquippedCosmeticCard extends StatelessWidget {
  const _EquippedCosmeticCard({
    required this.state,
    required this.currentCharacterName,
    required this.currentCharacterFrameId,
  });

  final GamificationState state;
  final String? currentCharacterName;
  final String? currentCharacterFrameId;

  @override
  Widget build(BuildContext context) {
    final title = GameCatalog.cosmeticById(state.equippedTitleId);
    final frameName = _frameDisplayName(state, state.equippedFrameId);
    final scopedName = currentCharacterFrameId == null
        ? null
        : _frameDisplayName(state, currentCharacterFrameId!);
    return _GameHubCard(
      icon: Icons.auto_awesome_outlined,
      title: '当前装扮',
      subtitle: [
        '${title?.name ?? '平平无奇玩家'} · 全局气泡：$frameName',
        if (currentCharacterName != null && scopedName != null)
          '$currentCharacterName 专用气泡：$scopedName',
      ].join('\n'),
    );
  }
}

class _CosmeticTile extends StatelessWidget {
  const _CosmeticTile({
    required this.cosmetic,
    required this.state,
    this.characters = const <CharacterProfile>[],
    required this.onBuy,
    required this.onEquip,
    this.onAssign,
  });

  final CosmeticDefinition cosmetic;
  final GamificationState state;
  final List<CharacterProfile> characters;
  final VoidCallback onBuy;
  final VoidCallback onEquip;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final owned = state.ownsCosmetic(cosmetic.id);
    final equipped = state.equippedTitleId == cosmetic.id ||
        state.equippedFrameId == cosmetic.id;
    final typeLabel = switch (cosmetic.type) {
      CosmeticType.title => '称号',
      CosmeticType.frame => '边框',
      CosmeticType.sticker => '旧贴纸',
    };
    final unlockHint =
        cosmetic.id.contains('_roulette_') ? '幸运转转转限定获取' : '成就或默认解锁';
    return _GameHubCard(
      icon: owned ? Icons.check_circle_outline : Icons.lock_outline_rounded,
      title: '$typeLabel · ${cosmetic.name}',
      subtitle: cosmetic.cost <= 0
          ? '${cosmetic.description} · $unlockHint'
          : '${cosmetic.description} · ${cosmetic.cost}啥币',
      preview: cosmetic.type == CosmeticType.frame
          ? BubbleFramePreview(
              frameId: cosmetic.id,
              label: cosmetic.description,
            )
          : null,
      trailing: owned
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: equipped ? null : onEquip,
                  child: Text(AppTheme.glitchText(equipped ? '已全局' : '全局')),
                ),
                if (cosmetic.type == CosmeticType.frame && onAssign != null)
                  OutlinedButton(
                    onPressed: characters.isEmpty ? null : onAssign,
                    child: Text(AppTheme.glitchText('绑角色')),
                  ),
              ],
            )
          : FilledButton.tonal(
              onPressed: cosmetic.cost > 0 && state.coins >= cosmetic.cost
                  ? onBuy
                  : null,
              child: Text(AppTheme.glitchText('购买')),
            ),
    );
  }
}

String _frameDisplayName(GamificationState state, String frameId) {
  final custom = state.customBubbleById(frameId);
  if (custom != null) {
    return custom.name;
  }
  return GameCatalog.cosmeticById(frameId)?.name ?? '默认边框';
}

Future<void> _openBubbleBindDialog(
  BuildContext context, {
  required AppStateController controller,
  required String frameId,
  required String frameName,
}) async {
  final characters = controller.characters;
  if (characters.isEmpty) {
    _showTopNotice(context, '先创建一个角色再绑定气泡。', isError: true);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final state = controller.gamification;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('绑定「$frameName」给谁？'),
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  AppTheme.glitchText('角色专属气泡会优先于全局气泡，NPC 私聊也会一起穿上。'),
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: characters.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final character = characters[index];
                      final boundFrame =
                          state.characterBubbleFrameIds[character.id];
                      final selected = boundFrame == frameId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CharacterAvatar(
                          name: character.name,
                          avatarDataUri: character.avatarDataUri,
                          size: 42,
                        ),
                        title: Text(AppTheme.glitchText(character.name)),
                        subtitle: Text(
                          selected
                              ? '当前已绑定'
                              : boundFrame == null
                                  ? '现在使用全局气泡'
                                  : '现在绑定：${_frameDisplayName(state, boundFrame)}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: <Widget>[
                            if (boundFrame != null)
                              TextButton(
                                onPressed: () async {
                                  final error = await controller
                                      .clearCharacterBubbleFrame(character.id);
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  if (error != null) {
                                    _showTopNotice(
                                      sheetContext,
                                      error,
                                      isError: true,
                                    );
                                    return;
                                  }
                                  Navigator.of(sheetContext).pop();
                                  _showTopNotice(
                                    context,
                                    '已取消「${character.name}」的专属气泡。',
                                  );
                                },
                                child: Text(AppTheme.glitchText('取消')),
                              ),
                            FilledButton.tonal(
                              onPressed: selected
                                  ? null
                                  : () async {
                                      final error = await controller
                                          .assignCharacterBubbleFrame(
                                        characterId: character.id,
                                        frameId: frameId,
                                      );
                                      if (!sheetContext.mounted) {
                                        return;
                                      }
                                      if (error != null) {
                                        _showTopNotice(
                                          sheetContext,
                                          error,
                                          isError: true,
                                        );
                                        return;
                                      }
                                      Navigator.of(sheetContext).pop();
                                      _showTopNotice(
                                        context,
                                        '「${character.name}」已绑定「$frameName」。',
                                      );
                                    },
                              child: Text(
                                AppTheme.glitchText(selected ? '已绑定' : '绑定'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CustomBubbleCreator extends StatelessWidget {
  const _CustomBubbleCreator({required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    return _GameHubCard(
      icon: Icons.css_outlined,
      title: '自定义气泡格子',
      subtitle: '50 啥币买一个格子。可以复制示例 CSS，自己改，或者丢给别的 AI 生成一份新的气泡样式。',
      trailing: FilledButton.tonalIcon(
        onPressed: controller.gamification.coins >= 50
            ? () => _openCustomBubbleEditor(context, controller: controller)
            : null,
        icon: const Icon(Icons.add_rounded),
        label: Text(AppTheme.glitchText('50啥币开格')),
      ),
    );
  }
}

class _CustomBubbleTile extends StatelessWidget {
  const _CustomBubbleTile({
    required this.style,
    required this.state,
    required this.currentCharacterId,
    required this.characters,
    required this.onEdit,
    required this.onDelete,
    required this.onEquip,
    required this.onAssign,
  });

  final CustomBubbleStyle style;
  final GamificationState state;
  final String? currentCharacterId;
  final List<CharacterProfile> characters;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEquip;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final equipped = state.equippedFrameId == style.id;
    final assigned = currentCharacterId != null &&
        state.characterBubbleFrameIds[currentCharacterId] == style.id;
    return _GameHubCard(
      icon: Icons.bubble_chart_outlined,
      title: '自定义气泡 · ${style.name}',
      subtitle: style.description.trim().isEmpty
          ? '用户自制款，风格说明还没写，但气势已经摆出来了。'
          : style.description,
      preview: BubbleFramePreview(
        frameId: style.id,
        customStyle: BubbleStyleSpec.fromCss(style.css),
        label: '实时预览 · ${style.name}',
      ),
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          IconButton(
            tooltip: AppTheme.glitchText('编辑'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: AppTheme.glitchText('删除'),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          FilledButton.tonal(
            onPressed: equipped ? null : onEquip,
            child: Text(AppTheme.glitchText(equipped ? '已全局' : '全局')),
          ),
          OutlinedButton(
            onPressed: characters.isEmpty ? null : onAssign,
            child: Text(AppTheme.glitchText(assigned ? '当前已绑' : '绑角色')),
          ),
        ],
      ),
    );
  }
}

Future<void> _openCustomBubbleEditor(
  BuildContext context, {
  required AppStateController controller,
  CustomBubbleStyle? style,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _CustomBubbleEditorDialog(
      controller: controller,
      style: style,
    ),
  );
}

class _CustomBubbleEditorDialog extends StatefulWidget {
  const _CustomBubbleEditorDialog({
    required this.controller,
    this.style,
  });

  final AppStateController controller;
  final CustomBubbleStyle? style;

  @override
  State<_CustomBubbleEditorDialog> createState() =>
      _CustomBubbleEditorDialogState();
}

class _CustomBubbleEditorDialogState extends State<_CustomBubbleEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cssController;
  bool _saving = false;
  bool _pickingCss = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.style?.name ?? '我的自定义气泡',
    );
    _descriptionController = TextEditingController(
      text: widget.style?.description ?? '自己写的气泡，当然要自己最满意。',
    );
    _cssController = TextEditingController(
      text: widget.style?.css ?? customBubbleCssExample,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cssController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = BubbleStyleSpec.fromCss(_cssController.text);
    return AlertDialog(
      title: Text(
        AppTheme.glitchText(widget.style == null ? '购买自定义气泡格子' : '编辑自定义气泡'),
      ),
      content: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width * 0.92, 760),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                AppTheme.glitchText(
                  '支持 CSS 子集：background-color、border、border-color、border-width、border-radius、color、box-shadow、content/--decoration。可写 .bubble、.bubble.assistant、.bubble.user。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '气泡名字'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '气泡介绍'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _cssController,
                minLines: 8,
                maxLines: 14,
                style: const TextStyle(fontFamily: 'monospace'),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'CSS 样式'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: customBubbleCssExample),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      _showTopNotice(context, '示例 CSS 已复制。');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(AppTheme.glitchText('复制示例')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickingCss ? null : _pickCssFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                        AppTheme.glitchText(_pickingCss ? '读取中' : '导入CSS')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _cssController.text = customBubbleCssExample,
                    ),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(AppTheme.glitchText('填入示例')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(AppTheme.glitchText('实时预览'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _CustomBubblePreview(style: parsed),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            AppTheme.glitchText(widget.style == null ? '支付50啥币并保存' : '保存修改'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = widget.style == null
        ? await widget.controller.buyCustomBubbleSlot(
            name: _nameController.text,
            description: _descriptionController.text,
            css: _cssController.text,
          )
        : await widget.controller.updateCustomBubbleStyle(
            id: widget.style!.id,
            name: _nameController.text,
            description: _descriptionController.text,
            css: _cssController.text,
          );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    final message = widget.style == null ? '自定义气泡已入库。' : '自定义气泡已保存。';
    Navigator.of(context).pop();
    final parentContext = context;
    if (parentContext.mounted) {
      _showTopNotice(parentContext, message);
    }
  }

  Future<void> _pickCssFile() async {
    setState(() => _pickingCss = true);
    try {
      final file = await pickArchiveFileData(
        allowedExtensions: const <String>['css', 'txt'],
        webAccept: '.css,.txt,text/css,text/plain',
      );
      if (!mounted) {
        return;
      }
      if (file == null) {
        _showTopNotice(context, '没有选择 CSS 文件。');
        return;
      }
      final content = utf8.decode(file.bytes, allowMalformed: true).trim();
      if (content.isEmpty) {
        _showTopNotice(context, '这个 CSS 文件是空的。', isError: true);
        return;
      }
      setState(() => _cssController.text = content);
      _showTopNotice(context, '已导入 ${file.name}。');
    } catch (error) {
      if (mounted) {
        _showTopNotice(context, '读取 CSS 失败：$error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _pickingCss = false);
      }
    }
  }
}

class _CustomBubblePreview extends StatelessWidget {
  const _CustomBubblePreview({required this.style});

  final BubbleStyleSpec? style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPanel(radius: 18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _previewBubble(context, 'AI', '这是一条 AI 气泡，负责检查文字还清不清楚。', false),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _previewBubble(context, '你', '这是一条用户气泡，看看边框够不够明显。', true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewBubble(
    BuildContext context,
    String label,
    String text,
    bool isUser,
  ) {
    final background = style?.backgroundFor(isUser) ??
        (isUser
            ? AppTheme.activePrimary.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.75));
    final borderColor = style?.borderFor(isUser) ?? AppTheme.activeLine;
    final textColor = style?.textFor(isUser) ?? AppTheme.textMain;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(style?.borderRadius ?? 22),
          border: Border.all(
            color: borderColor,
            width: style?.borderWidth ?? 2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color:
                  (style?.shadowColor ?? borderColor).withValues(alpha: 0.16),
              blurRadius: style?.shadowBlur ?? 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            if (style?.decorationText?.isNotEmpty == true)
              Positioned(
                right: 12,
                top: 8,
                child: Text(
                  style!.decorationText!,
                  style: TextStyle(
                    color: (style!.accentColor ?? borderColor).withValues(
                      alpha: style!.decorationOpacity ?? 0.24,
                    ),
                    fontSize: style!.decorationSize ?? 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                          )),
                  const SizedBox(height: 6),
                  Text(text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            height: 1.5,
                          )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.state,
  });

  final AchievementDefinition achievement;
  final GamificationState state;

  @override
  Widget build(BuildContext context) {
    final unlocked = state.hasAchievement(achievement.id);
    final hiddenLocked = achievement.hidden && !unlocked;
    final progress = state.stat(achievement.statKey);
    final rewardTitle = achievement.rewardTitleId == null
        ? null
        : GameCatalog.cosmeticById(achievement.rewardTitleId!);
    final rewardCosmetic = achievement.rewardCosmeticId == null
        ? null
        : GameCatalog.cosmeticById(achievement.rewardCosmeticId!);
    final unlockedColor = AppTheme.activePrimary;
    final rewards = <String>[
      '${achievement.rewardCoins}啥币',
      if (rewardTitle != null) '称号「${rewardTitle.name}」',
      if (rewardCosmetic != null) '装扮「${rewardCosmetic.name}」',
    ].join(' + ');

    return _GameHubCard(
      icon: unlocked ? Icons.emoji_events_outlined : Icons.lock_clock_outlined,
      title: hiddenLocked
          ? '？？？'
          : achievement.hidden
              ? '隐藏 · ${achievement.name}'
              : achievement.name,
      subtitle: hiddenLocked
          ? '？？？\n待解锁 · 奖励 ???'
          : '${achievement.unlockText}\n进度 ${progress.clamp(0, achievement.threshold)}/${achievement.threshold} · 奖励 $rewards',
      trailing: Text(
        AppTheme.glitchText(
          unlocked ? (achievement.hidden ? '隐藏已解锁' : '已解锁') : '未解锁',
        ),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: unlocked ? unlockedColor : AppTheme.textWeak,
              fontWeight: unlocked ? FontWeight.w900 : FontWeight.w700,
            ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppTheme.actionGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppTheme.glitchText('Lv.$level'),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.selectedTintText,
            ),
      ),
    );
  }
}

class _SoftEmptyLine extends StatelessWidget {
  const _SoftEmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        AppTheme.glitchText(text),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textWeak,
            ),
      ),
    );
  }
}
