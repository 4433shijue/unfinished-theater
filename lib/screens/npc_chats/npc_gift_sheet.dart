part of '../npc_chats_screen.dart';

class _NpcGiftSheet extends StatefulWidget {
  const _NpcGiftSheet({
    required this.npc,
    required this.onGiftInventoryItem,
    required this.onGiftShopOffer,
  });

  final NpcProfile npc;
  final Future<void> Function(StoryInventoryItem item) onGiftInventoryItem;
  final Future<void> Function(
    StoryShopOffer offer, {
    required String source,
    bool useDebt,
  }) onGiftShopOffer;

  @override
  State<_NpcGiftSheet> createState() => _NpcGiftSheetState();
}

class _NpcGiftSheetState extends State<_NpcGiftSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Future<List<StoryShopOffer>>? _mysteryOffersFuture;
  Future<List<StoryShopOffer>>? _blackMarketOffersFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final inventory = controller.currentStoryInventory;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppTheme.glitchText('送给 ${widget.npc.name}'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              TabBar(
                controller: _tabController,
                tabs: <Widget>[
                  Tab(text: AppTheme.glitchText('背包')),
                  Tab(text: AppTheme.glitchText('神秘小卖部')),
                  Tab(text: AppTheme.glitchText('黑心小卖部')),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildInventoryTab(inventory, scrollController),
                    _buildShopTab(
                      context,
                      scrollController,
                      source: 'mystery_shop',
                      offersFuture: _mysteryOffersFuture,
                      onLoad: () {
                        setState(() {
                          _mysteryOffersFuture = context
                              .read<AppStateController>()
                              .generateMysteryShopOffers();
                        });
                      },
                    ),
                    _buildShopTab(
                      context,
                      scrollController,
                      source: 'black_market',
                      offersFuture: _blackMarketOffersFuture,
                      onLoad: () {
                        setState(() {
                          _blackMarketOffersFuture = context
                              .read<AppStateController>()
                              .generateBlackMarketOffers();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInventoryTab(
    List<StoryInventoryItem> inventory,
    ScrollController scrollController,
  ) {
    if (inventory.isEmpty) {
      return ListView(
        controller: scrollController,
        children: <Widget>[
          const SizedBox(height: 32),
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: AppTheme.glitchText('背包里还没有剧情道具'),
            description: AppTheme.glitchText('可以切到小卖部买一件剧情道具直接送出。'),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: scrollController,
      itemCount: inventory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = inventory[index];
        return _GiftItemTile(
          title: item.name,
          subtitle: _storyItemSubtitle(item),
          trailing: FilledButton.icon(
            onPressed: () => widget.onGiftInventoryItem(item),
            icon: const Icon(Icons.card_giftcard_rounded),
            label: Text(AppTheme.glitchText('赠送')),
          ),
        );
      },
    );
  }

  Widget _buildShopTab(
    BuildContext context,
    ScrollController scrollController, {
    required String source,
    required Future<List<StoryShopOffer>>? offersFuture,
    required VoidCallback onLoad,
  }) {
    final isBlackMarket = source == 'black_market';
    if (offersFuture == null) {
      return ListView(
        controller: scrollController,
        children: <Widget>[
          const SizedBox(height: 28),
          Center(
            child: FilledButton.icon(
              onPressed: onLoad,
              icon: const Icon(Icons.storefront_rounded),
              label: Text(AppTheme.glitchText(
                isBlackMarket ? '看看黑心货单' : '刷新今日货架',
              )),
            ),
          ),
        ],
      );
    }
    return FutureBuilder<List<StoryShopOffer>>(
      future: offersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            controller: scrollController,
            children: <Widget>[
              Text(
                snapshot.error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppTheme.glitchText('重试')),
              ),
            ],
          );
        }
        final offers = snapshot.data ?? const <StoryShopOffer>[];
        return ListView.separated(
          controller: scrollController,
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final offer = offers[index];
            return _GiftItemTile(
              title: '${offer.name} · ${offer.cost} 啥币',
              subtitle: '${offer.description}\n${offer.effect}',
              trailing: Wrap(
                spacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => widget.onGiftShopOffer(
                      offer,
                      source: source,
                    ),
                    icon: const Icon(Icons.card_giftcard_rounded),
                    label: Text(AppTheme.glitchText('购买赠送')),
                  ),
                  if (isBlackMarket)
                    OutlinedButton(
                      onPressed: () => widget.onGiftShopOffer(
                        offer,
                        source: source,
                        useDebt: true,
                      ),
                      child: Text(AppTheme.glitchText('赊账送')),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _storyItemSubtitle(StoryInventoryItem item) {
    final parts = <String>[
      if (item.description.trim().isNotEmpty) item.description.trim(),
      if (item.effect.trim().isNotEmpty) item.effect.trim(),
      if (item.source.trim().isNotEmpty) '来源：${item.source}',
    ];
    return parts.isEmpty ? '暂无说明。' : parts.join('\n');
  }
}

class _GiftItemTile extends StatelessWidget {
  const _GiftItemTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPanel(radius: 18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.contrastText,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle.trim().isEmpty ? '暂无说明。' : subtitle.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }
}

// ─── Bubble ──────────────────────────────────────────────────────────────────
