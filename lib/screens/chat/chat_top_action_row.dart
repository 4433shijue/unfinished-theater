part of '../chat_screen.dart';

class _ChatTopActionRow extends StatefulWidget {
  const _ChatTopActionRow({
    required this.themeId,
    required this.immersiveMode,
    required this.onToggleImmersive,
    required this.coinBalance,
    required this.mailboxUnreadCount,
    required this.npcUnreadCount,
    required this.onOpenGameHub,
    required this.onOpenMailbox,
    required this.onOpenStory,
    required this.onOpenNpcChats,
    required this.onOpenGameState,
    required this.mapModeEnabled,
    required this.largeGroupChatModeEnabled,
    required this.onEnterExport,
    required this.onShareCard,
    required this.onClearHistory,
    required this.compact,
    required this.characterName,
    required this.memoryCount,
    required this.onOpenUserProfile,
  });

  final String themeId;
  final bool immersiveMode;
  final VoidCallback onToggleImmersive;
  final int coinBalance;
  final int mailboxUnreadCount;
  final int npcUnreadCount;
  final VoidCallback onOpenGameHub;
  final VoidCallback onOpenMailbox;
  final VoidCallback onOpenStory;
  final VoidCallback onOpenNpcChats;
  final VoidCallback onOpenGameState;
  final bool mapModeEnabled;
  final bool largeGroupChatModeEnabled;
  final VoidCallback onEnterExport;
  final VoidCallback? onShareCard;
  final VoidCallback? onClearHistory;
  final bool compact;
  final String characterName;
  final int memoryCount;
  final VoidCallback onOpenUserProfile;

  @override
  State<_ChatTopActionRow> createState() => _ChatTopActionRowState();
}

class _ChatTopActionRowState extends State<_ChatTopActionRow> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _MobileChatTopBar(
        themeId: widget.themeId,
        immersiveMode: widget.immersiveMode,
        characterName: widget.characterName,
        memoryCount: widget.memoryCount,
        coinBalance: widget.coinBalance,
        mailboxUnreadCount: widget.mailboxUnreadCount,
        npcUnreadCount: widget.npcUnreadCount,
        mapModeEnabled: widget.mapModeEnabled,
        largeGroupChatModeEnabled: widget.largeGroupChatModeEnabled,
        onToggleImmersive: widget.onToggleImmersive,
        onOpenGameHub: widget.onOpenGameHub,
        onOpenMailbox: widget.onOpenMailbox,
        onOpenStory: widget.onOpenStory,
        onOpenNpcChats: widget.onOpenNpcChats,
        onOpenGameState: widget.onOpenGameState,
        onEnterExport: widget.onEnterExport,
        onShareCard: widget.onShareCard,
        onClearHistory: widget.onClearHistory,
        onOpenUserProfile: widget.onOpenUserProfile,
      );
    }
    final tonalStyle = AppTheme.skinTonalButtonStyle();
    final scroller = Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        primary: false,
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                AppTheme.glitchText(
                  widget.immersiveMode ? '沉浸模式已开启' : '对话视图',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textWeak,
                    ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: widget.onOpenGameHub,
              icon: const Icon(Icons.savings_outlined),
              label:
                  Text(AppTheme.glitchText('小游戏中心 · ${widget.coinBalance}啥币')),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onOpenMailbox,
              icon: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const Icon(Icons.mark_email_unread_outlined),
                  if (widget.mailboxUnreadCount > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              label: Text(
                AppTheme.glitchText(
                  widget.mailboxUnreadCount > 0
                      ? '邮箱 · ${widget.mailboxUnreadCount}'
                      : '邮箱',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onOpenStory,
              icon: const Icon(Icons.auto_stories_outlined),
              label: Text(AppTheme.glitchText('故事')),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onOpenNpcChats,
              icon: const Icon(Icons.sms_outlined),
              label: Text(
                AppTheme.glitchText(
                  widget.npcUnreadCount > 0
                      ? 'NPC私聊 · ${widget.npcUnreadCount}'
                      : 'NPC私聊',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onOpenGameState,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: Text(AppTheme.glitchText('游戏面板')),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              style: tonalStyle,
              onPressed: widget.onToggleImmersive,
              icon: Icon(
                widget.immersiveMode
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
              label: Text(
                AppTheme.glitchText(widget.immersiveMode ? '显示面板' : '隐藏面板'),
              ),
            ),
          ],
        ),
      ),
    );
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent || !_controller.hasClients) {
          return;
        }
        final delta = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
            ? event.scrollDelta.dy
            : event.scrollDelta.dx;
        final nextOffset = (_controller.offset + delta).clamp(
          _controller.position.minScrollExtent,
          _controller.position.maxScrollExtent,
        );
        _controller.jumpTo(nextOffset);
      },
      child: scroller,
    );
  }
}

class _MobileChatTopBar extends StatelessWidget {
  const _MobileChatTopBar({
    required this.themeId,
    required this.immersiveMode,
    required this.characterName,
    required this.memoryCount,
    required this.coinBalance,
    required this.mailboxUnreadCount,
    required this.npcUnreadCount,
    required this.mapModeEnabled,
    required this.largeGroupChatModeEnabled,
    required this.onToggleImmersive,
    required this.onOpenGameHub,
    required this.onOpenMailbox,
    required this.onOpenStory,
    required this.onOpenNpcChats,
    required this.onOpenGameState,
    required this.onEnterExport,
    required this.onShareCard,
    required this.onClearHistory,
    required this.onOpenUserProfile,
  });

  final String themeId;
  final bool immersiveMode;
  final String characterName;
  final int memoryCount;
  final int coinBalance;
  final int mailboxUnreadCount;
  final int npcUnreadCount;
  final bool mapModeEnabled;
  final bool largeGroupChatModeEnabled;
  final VoidCallback onToggleImmersive;
  final VoidCallback onOpenGameHub;
  final VoidCallback onOpenMailbox;
  final VoidCallback onOpenStory;
  final VoidCallback onOpenNpcChats;
  final VoidCallback onOpenGameState;
  final VoidCallback onEnterExport;
  final VoidCallback? onShareCard;
  final VoidCallback? onClearHistory;
  final VoidCallback onOpenUserProfile;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    final modeLabel = largeGroupChatModeEnabled
        ? '大型群聊'
        : mapModeEnabled
            ? '地图主线'
            : immersiveMode
                ? '沉浸中'
                : '功能已收起';
    final light = AppTheme.isLightPaletteMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18 * uiScale),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withValues(alpha: 0.34)
                : Colors.black.withValues(alpha: 0.13),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6 * uiScale,
              vertical: 5 * uiScale,
            ),
            child: Row(
              children: <Widget>[
                _TopIconButton(
                  tooltip: '功能菜单',
                  icon: Icons.menu_rounded,
                  onPressed: () => _showMobileToolMenu(context),
                ),
                SizedBox(width: 8 * uiScale),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        AppTheme.glitchText(characterName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      SizedBox(height: 1 * uiScale),
                      Text(
                        AppTheme.glitchText('$modeLabel · 长期记忆 $memoryCount'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              height: 1.18,
                            ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8 * uiScale),
                _TopIconButton(
                  tooltip: '用户',
                  icon: Icons.account_circle_outlined,
                  onPressed: onOpenUserProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMobileToolMenu(BuildContext context) async {
    final actions = <_MobileToolAction>[
      _MobileToolAction(
        icon: immersiveMode
            ? Icons.visibility_rounded
            : Icons.visibility_off_rounded,
        title: immersiveMode ? '显示面板' : '隐藏面板',
        subtitle: immersiveMode ? '退出沉浸显示辅助区域' : '进入更少干扰的对话视图',
        onTap: onToggleImmersive,
        highlighted: immersiveMode,
      ),
      _MobileToolAction(
        icon: Icons.savings_outlined,
        title: '小游戏中心',
        subtitle: '$coinBalance 啥币',
        onTap: onOpenGameHub,
      ),
      _MobileToolAction(
        icon: Icons.mark_email_unread_outlined,
        title: mailboxUnreadCount > 0 ? '邮箱 · $mailboxUnreadCount' : '邮箱',
        subtitle: mailboxUnreadCount > 0 ? '有待领取或未读消息' : '查看来信和奖励',
        onTap: onOpenMailbox,
        badgeCount: mailboxUnreadCount,
      ),
      _MobileToolAction(
        icon: Icons.auto_stories_outlined,
        title: '故事',
        subtitle: '概览、人物、线索和番外作品',
        onTap: onOpenStory,
      ),
      _MobileToolAction(
        icon: Icons.sms_outlined,
        title: npcUnreadCount > 0 ? 'NPC私聊 · $npcUnreadCount' : 'NPC私聊',
        subtitle: npcUnreadCount > 0 ? '有 NPC 私聊未读' : '私聊与 NPC 来信',
        onTap: onOpenNpcChats,
        badgeCount: npcUnreadCount,
      ),
      _MobileToolAction(
        icon: Icons.dashboard_customize_outlined,
        title: '游戏面板',
        subtitle: '状态、任务与玩法模式',
        onTap: onOpenGameState,
      ),
      _MobileToolAction(
        icon: Icons.ios_share_outlined,
        title: '导出消息记录',
        subtitle: '进入消息勾选导出模式',
        onTap: onEnterExport,
      ),
      _MobileToolAction(
        icon: Icons.photo_size_select_large,
        title: '剧情分享卡',
        subtitle: onShareCard == null ? '当前还没有可分享的消息' : '生成当前剧情分享卡',
        onTap: onShareCard,
      ),
      _MobileToolAction(
        icon: Icons.cleaning_services_outlined,
        title: '清空记录',
        subtitle: onClearHistory == null ? '当前还没有聊天记录' : '清空当前对话记录',
        onTap: onClearHistory,
      ),
    ];

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: _MobileToolMenuDrawer(
            themeId: themeId,
            actions: actions,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    return Tooltip(
      message: AppTheme.glitchText(tooltip),
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 22 * uiScale,
        style: AppTheme.skinIconButtonStyle(
          base: IconButton.styleFrom(
            backgroundColor: AppTheme.activePrimary.withValues(
              alpha: AppTheme.isLightPaletteMode ? 0.08 : 0.13,
            ),
            foregroundColor: AppTheme.isLightPaletteMode
                ? AppTheme.activePrimary
                : AppTheme.activeSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14 * uiScale),
            ),
          ),
        ),
        constraints: BoxConstraints.tightFor(
          width: 42 * uiScale,
          height: 42 * uiScale,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _MobileToolMenuDrawer extends StatelessWidget {
  const _MobileToolMenuDrawer({
    required this.themeId,
    required this.actions,
  });

  final String themeId;
  final List<_MobileToolAction> actions;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    final width = math.min(MediaQuery.sizeOf(context).width * 0.86, 360.0);
    final skin = _ToolDrawerSkin.forTheme(themeId);
    final drawerRadius = BorderRadius.horizontal(
      right: Radius.circular(skin.drawerRadius * uiScale),
    );
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: ValueKey<String>('mobile-tool-drawer-$themeId'),
          width: width,
          height: double.infinity,
          decoration: BoxDecoration(
            color: skin.panelColor,
            borderRadius: drawerRadius,
            border: Border(
              right: BorderSide(
                color: skin.borderColor,
                width: skin.borderWidth,
              ),
            ),
            boxShadow: skin.shadow,
          ),
          child: ClipRRect(
            borderRadius: drawerRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: skin.blurSigma,
                sigmaY: skin.blurSigma,
              ),
              child: CustomPaint(
                key: ValueKey<String>(
                  'mobile-tool-material-${skin.motif.name}',
                ),
                painter: _ToolDrawerMaterialPainter(
                  motif: skin.motif,
                  primary: skin.motifPrimary,
                  secondary: skin.motifSecondary,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16 * uiScale,
                    16 * uiScale,
                    14 * uiScale,
                    14 * uiScale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 34 * uiScale,
                            height: 34 * uiScale,
                            decoration: BoxDecoration(
                              color: skin.iconSurface,
                              borderRadius: BorderRadius.circular(
                                skin.tileRadius * uiScale,
                              ),
                              border: Border.all(
                                color: skin.borderColor.withValues(alpha: 0.72),
                              ),
                            ),
                            child: Icon(
                              Icons.widgets_outlined,
                              size: 19 * uiScale,
                              color: skin.iconColor,
                            ),
                          ),
                          SizedBox(width: 10 * uiScale),
                          Expanded(
                            child: Semantics(
                              key: const ValueKey<String>(
                                'mobile-tool-route-title',
                              ),
                              label: '功能菜单',
                              header: true,
                              namesRoute: true,
                              child: ExcludeSemantics(
                                child: Text(
                                  AppTheme.glitchText('功能菜单'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            style: AppTheme.skinIconButtonStyle(),
                            tooltip: AppTheme.glitchText('关闭'),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: 10 * uiScale,
                          bottom: 12 * uiScale,
                        ),
                        child: Divider(
                          height: 1,
                          color: skin.borderColor.withValues(alpha: 0.58),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: actions.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: 7 * uiScale),
                          itemBuilder: (context, index) {
                            final action = actions[index];
                            return _MobileToolActionTile(
                              action: action,
                              skin: skin,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileToolActionTile extends StatelessWidget {
  const _MobileToolActionTile({
    required this.action,
    required this.skin,
  });

  final _MobileToolAction action;
  final _ToolDrawerSkin skin;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    final color = action.highlighted ? skin.highlightSurface : skin.tileSurface;
    final radius = BorderRadius.circular(skin.tileRadius);
    final VoidCallback? handleTap = enabled
        ? () {
            Navigator.of(context).pop();
            action.onTap?.call();
          }
        : null;
    final semanticHint = action.badgeCount > 0
        ? '${action.subtitle}，${action.badgeCount} 条未读'
        : action.subtitle;
    return Semantics(
      key: ValueKey<String>('mobile-tool-action-${action.title}'),
      button: true,
      enabled: enabled,
      label: action.title,
      hint: semanticHint,
      onTap: handleTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: handleTap,
            child: Ink(
              decoration: BoxDecoration(
                color: enabled ? color : AppTheme.panel.withValues(alpha: 0.35),
                borderRadius: radius,
                border: Border.all(
                  color: action.highlighted
                      ? skin.borderColor
                      : skin.borderColor.withValues(alpha: 0.52),
                  width: skin.tileBorderWidth,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: skin.iconSurface,
                            borderRadius: BorderRadius.circular(
                              skin.iconRadius,
                            ),
                            border: Border.all(
                              color: skin.borderColor.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Icon(
                            action.icon,
                            color: enabled ? skin.iconColor : AppTheme.textWeak,
                          ),
                        ),
                        if (action.badgeCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppTheme.glitchText(action.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: enabled ? null : AppTheme.textWeak,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            AppTheme.glitchText(action.subtitle),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textMuted,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: enabled ? AppTheme.textWeak : AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ToolDrawerMotif {
  neutral,
  signal,
  abyss,
  relay,
  paper,
  brass,
  rain,
  pasture,
  vinyl,
}

class _ToolDrawerSkin {
  const _ToolDrawerSkin({
    required this.motif,
    required this.panelColor,
    required this.borderColor,
    required this.motifPrimary,
    required this.motifSecondary,
    required this.tileSurface,
    required this.highlightSurface,
    required this.iconSurface,
    required this.iconColor,
    required this.drawerRadius,
    required this.tileRadius,
    required this.iconRadius,
    required this.borderWidth,
    required this.tileBorderWidth,
    required this.blurSigma,
    required this.shadow,
  });

  factory _ToolDrawerSkin.forTheme(String themeId) {
    final material = ThemeSkinAssets.specFor(themeId)?.drawerMaterial;
    final fallback = _ToolDrawerSkin(
      motif: _ToolDrawerMotif.neutral,
      panelColor: AppTheme.panel.withValues(alpha: 0.97),
      borderColor: AppTheme.activeLine,
      motifPrimary: AppTheme.activePrimary.withValues(alpha: 0.22),
      motifSecondary: AppTheme.activeSecondary.withValues(alpha: 0.18),
      tileSurface: AppTheme.activeSecondary.withValues(alpha: 0.07),
      highlightSurface: AppTheme.activePrimary.withValues(alpha: 0.14),
      iconSurface: AppTheme.activePrimary.withValues(alpha: 0.11),
      iconColor: AppTheme.activePrimary,
      drawerRadius: 12,
      tileRadius: 8,
      iconRadius: 8,
      borderWidth: 1,
      tileBorderWidth: 1,
      blurSigma: 14,
      shadow: AppTheme.neonGlow(alpha: 0.10),
    );
    return switch (material) {
      ThemeSkinDrawerMaterialToken.signalNoise => _ToolDrawerSkin(
          motif: _ToolDrawerMotif.signal,
          panelColor: const Color(0xFF080B0B).withValues(alpha: 0.97),
          borderColor: const Color(0xFFFF3B36),
          motifPrimary: const Color(0xFFFF3B36).withValues(alpha: 0.42),
          motifSecondary: const Color(0xFFB3FF8F).withValues(alpha: 0.30),
          tileSurface: const Color(0xFF121817).withValues(alpha: 0.92),
          highlightSurface: const Color(0xFF381313).withValues(alpha: 0.94),
          iconSurface: const Color(0xFF171D19),
          iconColor: const Color(0xFFB3FF8F),
          drawerRadius: 2,
          tileRadius: 2,
          iconRadius: 2,
          borderWidth: 2,
          tileBorderWidth: 1,
          blurSigma: 4,
          shadow: const <BoxShadow>[
            BoxShadow(color: Color(0x44FF3131), blurRadius: 12),
          ],
        ),
      ThemeSkinDrawerMaterialToken.occultLeather => _ToolDrawerSkin(
          motif: _ToolDrawerMotif.abyss,
          panelColor: const Color(0xFF100706).withValues(alpha: 0.97),
          borderColor: const Color(0xFF9D6A50),
          motifPrimary: const Color(0xFF701414).withValues(alpha: 0.34),
          motifSecondary: const Color(0xFFABC69A).withValues(alpha: 0.18),
          tileSurface: const Color(0xFF1A0C0B).withValues(alpha: 0.90),
          highlightSurface: const Color(0xFF321110).withValues(alpha: 0.94),
          iconSurface: const Color(0xFF271311),
          iconColor: const Color(0xFFD0A889),
          drawerRadius: 8,
          tileRadius: 6,
          iconRadius: 6,
          borderWidth: 1.5,
          tileBorderWidth: 1,
          blurSigma: 10,
          shadow: const <BoxShadow>[
            BoxShadow(color: Color(0x33000000), blurRadius: 18),
          ],
        ),
      ThemeSkinDrawerMaterialToken.relayMetal => _ToolDrawerSkin(
          motif: _ToolDrawerMotif.relay,
          panelColor: const Color(0xFF0B0F12).withValues(alpha: 0.96),
          borderColor: const Color(0xFF00D5FF),
          motifPrimary: const Color(0xFF00D5FF).withValues(alpha: 0.30),
          motifSecondary: const Color(0xFFC4CCD6).withValues(alpha: 0.16),
          tileSurface: const Color(0xFF141A1E).withValues(alpha: 0.92),
          highlightSurface: const Color(0xFF0D2830).withValues(alpha: 0.95),
          iconSurface: const Color(0xFF17252B),
          iconColor: const Color(0xFF8EDFF0),
          drawerRadius: 4,
          tileRadius: 3,
          iconRadius: 3,
          borderWidth: 1.5,
          tileBorderWidth: 1,
          blurSigma: 8,
          shadow: const <BoxShadow>[
            BoxShadow(color: Color(0x3300D5FF), blurRadius: 14),
          ],
        ),
      ThemeSkinDrawerMaterialToken.ricePaper => _ToolDrawerSkin(
          motif: _ToolDrawerMotif.paper,
          panelColor: const Color(0xFFF4EEE7).withValues(alpha: 0.96),
          borderColor: const Color(0xFFA67A7B),
          motifPrimary: const Color(0xFFA67A7B).withValues(alpha: 0.24),
          motifSecondary: const Color(0xFF778D7A).withValues(alpha: 0.18),
          tileSurface: const Color(0xFFF8F4EC).withValues(alpha: 0.92),
          highlightSurface: const Color(0xFFEAD9D5).withValues(alpha: 0.94),
          iconSurface: const Color(0xFFE8DDD5),
          iconColor: const Color(0xFF7B605E),
          drawerRadius: 8,
          tileRadius: 6,
          iconRadius: 6,
          borderWidth: 1,
          tileBorderWidth: 1,
          blurSigma: 9,
          shadow: const <BoxShadow>[
            BoxShadow(color: Color(0x221E1513), blurRadius: 14),
          ],
        ),
      ThemeSkinDrawerMaterialToken.rivetedBrass => _ToolDrawerSkin(
          motif: _ToolDrawerMotif.brass,
          panelColor: const Color(0xFF17110C).withValues(alpha: 0.97),
          borderColor: const Color(0xFFB77B35),
          motifPrimary: const Color(0xFFD8AD62).withValues(alpha: 0.28),
          motifSecondary: const Color(0xFF6F4329).withValues(alpha: 0.34),
          tileSurface: const Color(0xFF241A12).withValues(alpha: 0.94),
          highlightSurface: const Color(0xFF3A2818).withValues(alpha: 0.96),
          iconSurface: const Color(0xFF312316),
          iconColor: const Color(0xFFD8AD62),
          drawerRadius: 3,
          tileRadius: 3,
          iconRadius: 3,
          borderWidth: 2,
          tileBorderWidth: 1,
          blurSigma: 6,
          shadow: const <BoxShadow>[
            BoxShadow(color: Color(0x33000000), blurRadius: 16),
          ],
        ),
      ThemeSkinDrawerMaterialToken.rainGlass => _ToolDrawerSkin(
          motif: _ToolDrawerMotif.rain,
          panelColor: const Color(0xFF102333).withValues(alpha: 0.90),
          borderColor: const Color(0xFF9BBDCA),
          motifPrimary: const Color(0xFFD7EBF2).withValues(alpha: 0.22),
          motifSecondary: const Color(0xFF4E768B).withValues(alpha: 0.24),
          tileSurface: const Color(0xFF172C3B).withValues(alpha: 0.78),
          highlightSurface: const Color(0xFF25485B).withValues(alpha: 0.84),
          iconSurface: const Color(0xFF203C4D),
          iconColor: const Color(0xFFD7EBF2),
          drawerRadius: 8,
          tileRadius: 8,
          iconRadius: 8,
          borderWidth: 1,
          tileBorderWidth: 1,
          blurSigma: 18,
          shadow: const <BoxShadow>[
            BoxShadow(color: Color(0x33071A28), blurRadius: 20),
          ],
        ),
      ThemeSkinDrawerMaterialToken.paintedPasture => _ToolDrawerSkin(
          motif: _ToolDrawerMotif.pasture,
          panelColor: const Color(0xFFEFF8F8).withValues(alpha: 0.94),
          borderColor: const Color(0xFF6FAE91),
          motifPrimary: const Color(0xFF67B8D5).withValues(alpha: 0.20),
          motifSecondary: const Color(0xFF88B66D).withValues(alpha: 0.20),
          tileSurface: const Color(0xFFF5FBFA).withValues(alpha: 0.88),
          highlightSurface: const Color(0xFFE4F4EB).withValues(alpha: 0.92),
          iconSurface: const Color(0xFFDCEFF4),
          iconColor: const Color(0xFF31758A),
          drawerRadius: 8,
          tileRadius: 8,
          iconRadius: 8,
          borderWidth: 1,
          tileBorderWidth: 1,
          blurSigma: 14,
          shadow: const <BoxShadow>[
            BoxShadow(color: Color(0x2267B8D5), blurRadius: 16),
          ],
        ),
      ThemeSkinDrawerMaterialToken.vinylLacquer => _ToolDrawerSkin(
          motif: _ToolDrawerMotif.vinyl,
          panelColor: const Color(0xFF211409).withValues(alpha: 0.96),
          borderColor: const Color(0xFFE0B56F),
          motifPrimary: const Color(0xFFE0B56F).withValues(alpha: 0.24),
          motifSecondary: const Color(0xFF9B6038).withValues(alpha: 0.24),
          tileSurface: const Color(0xFF2D1A0F).withValues(alpha: 0.92),
          highlightSurface: const Color(0xFF4A2B19).withValues(alpha: 0.94),
          iconSurface: const Color(0xFF3A2417),
          iconColor: const Color(0xFFFFD796),
          drawerRadius: 5,
          tileRadius: 5,
          iconRadius: 5,
          borderWidth: 1.5,
          tileBorderWidth: 1,
          blurSigma: 8,
          shadow: const <BoxShadow>[
            BoxShadow(color: Color(0x44000000), blurRadius: 18),
          ],
        ),
      _ => fallback,
    };
  }

  final _ToolDrawerMotif motif;
  final Color panelColor;
  final Color borderColor;
  final Color motifPrimary;
  final Color motifSecondary;
  final Color tileSurface;
  final Color highlightSurface;
  final Color iconSurface;
  final Color iconColor;
  final double drawerRadius;
  final double tileRadius;
  final double iconRadius;
  final double borderWidth;
  final double tileBorderWidth;
  final double blurSigma;
  final List<BoxShadow> shadow;
}

class _ToolDrawerMaterialPainter extends CustomPainter {
  const _ToolDrawerMaterialPainter({
    required this.motif,
    required this.primary,
    required this.secondary,
  });

  final _ToolDrawerMotif motif;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final primaryPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final secondaryPaint = Paint()
      ..color = secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    switch (motif) {
      case _ToolDrawerMotif.signal:
        for (var index = 0, y = 8.0; y < size.height; index++, y += 7) {
          canvas.drawLine(
            Offset(size.width - 18, y),
            Offset(size.width, y),
            index.isEven ? primaryPaint : secondaryPaint,
          );
        }
        canvas.drawLine(
          const Offset(5, 0),
          Offset(5, size.height),
          secondaryPaint,
        );
      case _ToolDrawerMotif.abyss:
        final center = Offset(size.width - 12, 58);
        for (final radius in <double>[18, 29, 42]) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            math.pi * 0.55,
            math.pi * 1.25,
            false,
            radius == 29 ? secondaryPaint : primaryPaint,
          );
        }
      case _ToolDrawerMotif.relay:
        final path = Path()
          ..moveTo(size.width - 2, 24)
          ..lineTo(size.width - 24, 24)
          ..lineTo(size.width - 42, 42)
          ..lineTo(size.width - 42, 86);
        canvas.drawPath(path, primaryPaint);
        for (final y in <double>[112, 196, 280]) {
          canvas.drawCircle(Offset(size.width - 7, y), 2.5, secondaryPaint);
        }
      case _ToolDrawerMotif.paper:
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(size.width - 17 - i * 9, 26 + i * 7);
          canvas.rotate(-0.45 + i * 0.22);
          canvas.drawOval(
            const Rect.fromLTWH(-7, -3, 14, 6),
            i.isEven ? primaryPaint : secondaryPaint,
          );
          canvas.restore();
        }
      case _ToolDrawerMotif.brass:
        final rivet = Paint()..color = primary;
        for (var y = 18.0; y < size.height; y += 46) {
          canvas.drawCircle(Offset(size.width - 7, y), 2.2, rivet);
        }
        canvas.drawLine(const Offset(7, 0), Offset(7, size.height),
            secondaryPaint..strokeWidth = 1.5);
      case _ToolDrawerMotif.rain:
        for (var i = 0; i < 14; i++) {
          final y = 16.0 + i * 48;
          canvas.drawLine(
            Offset(size.width - 14, y),
            Offset(size.width - 7, y + 23),
            i.isEven ? primaryPaint : secondaryPaint,
          );
        }
      case _ToolDrawerMotif.pasture:
        canvas.drawArc(
          Rect.fromLTWH(size.width - 72, 18, 58, 24),
          math.pi,
          math.pi,
          false,
          primaryPaint,
        );
        final grass = Path()
          ..moveTo(0, size.height - 18)
          ..quadraticBezierTo(42, size.height - 34, 88, size.height - 17)
          ..quadraticBezierTo(132, size.height, 178, size.height - 20);
        canvas.drawPath(grass, secondaryPaint);
      case _ToolDrawerMotif.vinyl:
        final center = Offset(2, size.height - 30);
        for (final radius in <double>[22, 31, 40]) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            -math.pi / 2,
            math.pi,
            false,
            radius == 31 ? primaryPaint : secondaryPaint,
          );
        }
        canvas.drawLine(
          Offset(size.width - 5, 10),
          Offset(size.width - 5, size.height - 10),
          primaryPaint,
        );
      case _ToolDrawerMotif.neutral:
        canvas.drawLine(
          Offset(size.width - 5, 12),
          Offset(size.width - 5, size.height - 12),
          primaryPaint,
        );
    }
  }

  @override
  bool shouldRepaint(_ToolDrawerMaterialPainter oldDelegate) {
    return oldDelegate.motif != motif ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}

class _MobileToolAction {
  const _MobileToolAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final int badgeCount;
  final bool highlighted;
}
