part of '../npc_chats_screen.dart';

class NpcChatThreadScreen extends StatefulWidget {
  const NpcChatThreadScreen({
    super.key,
    required this.npcId,
  });

  final String npcId;

  @override
  State<NpcChatThreadScreen> createState() => _NpcChatThreadScreenState();
}

class _NpcChatThreadScreenState extends State<NpcChatThreadScreen> {
  late final ScrollController _scrollController;
  int _lastMessageCount = 0;
  bool _selecting = false;
  final Set<String> _selectedMessageIds = <String>{};
  bool _isOpeningNpcTool = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    unawaited(context.read<AppStateController>().loadNpcThread(widget.npcId));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _exitSelecting() {
    _selectedMessageIds.clear();
    setState(() => _selecting = false);
  }

  Future<void> _deleteSelected() async {
    if (_selectedMessageIds.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('批量删除')),
        content: Text(AppTheme.glitchText(
            '确定要删除选中的 ${_selectedMessageIds.length} 条消息吗？')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTheme.glitchText('删除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await context
        .read<AppStateController>()
        .deleteNpcMessages(widget.npcId, _selectedMessageIds);
    _exitSelecting();
  }

  void _toggleMessage(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
      if (_selectedMessageIds.isEmpty) {
        _selecting = false;
      }
    });
  }

  Future<void> _editMessage(NpcChatMessage message) async {
    final controller = TextEditingController(text: message.content);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('编辑消息')),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 2,
          decoration: InputDecoration(
            hintText: AppTheme.glitchText('输入新内容...'),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(AppTheme.glitchText('保存')),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) {
      return;
    }
    await context
        .read<AppStateController>()
        .updateNpcMessageContent(widget.npcId, message.id, result);
  }

  Future<void> _deleteMessage(NpcChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('删除消息')),
        content: Text(AppTheme.glitchText('确定要删除这条消息吗？')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTheme.glitchText('删除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await context
        .read<AppStateController>()
        .deleteNpcMessage(widget.npcId, message.id);
  }

  Future<void> _regenerateNpcReply() async {
    final messenger = ScaffoldMessenger.of(context);
    final direction = await _askRegenerateDirection();
    if (!mounted || direction == null) {
      return;
    }
    final error = await context
        .read<AppStateController>()
        .regenerateNpcReply(widget.npcId, direction: direction);
    if (!mounted || error == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  Future<String?> _askRegenerateDirection() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('重新回复')),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('重写方向（可留空）'),
            hintText: AppTheme.glitchText('例如：更克制一点 / 更主动一点 / 增加误会感'),
            alignLabelWithHint: true,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(AppTheme.glitchText('重新生成')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportThread(
    NpcProfile npc,
    AppStateController controller,
  ) async {
    final messages = controller.npcMessagesFor(widget.npcId);
    if (messages.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('还没有消息可以导出。'))),
      );
      return;
    }

    final character = controller.currentCharacter;
    final htmlContent = AppStateController.buildNpcExportHtml(
      npcName: npc.name,
      characterName: character?.name ?? '未知角色',
      messages: messages,
    );

    try {
      // Native: save to temp file and share
      final dir = await getTemporaryDirectory();
      final file = io.File(
          '${dir.path}/npc_chat_${npc.name}_${DateTime.now().millisecondsSinceEpoch}.html');
      await file.writeAsString(htmlContent);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: '${npc.name} 私聊记录',
          subject: '${npc.name} 私聊记录',
        ),
      );
    } catch (_) {
      // Web fallback: share as text
      try {
        await SharePlus.instance.share(
          ShareParams(
            text: htmlContent.substring(0, htmlContent.length.clamp(0, 8000)),
            title: '${npc.name} 私聊记录',
            subject: '${npc.name} 私聊记录',
          ),
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTheme.glitchText('导出失败，请稍后重试。'))),
        );
      }
    }
  }

  bool _hasNpcReply(List<NpcChatMessage> messages) {
    for (var index = messages.length - 1; index >= 0; index--) {
      if (messages[index].role == NpcMessageRole.npc) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final npc = controller.npcProfileById(widget.npcId);
    if (npc == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.shellBackgroundGradient),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                _NpcChatTopBar(
                  title: AppTheme.glitchText('NPC 私聊'),
                  subtitle: AppTheme.glitchText('角色不存在'),
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: EmptyState(
                    icon: Icons.person_off_outlined,
                    title: AppTheme.glitchText('NPC 不存在'),
                    description: AppTheme.glitchText('这个 NPC 可能已经被删除。'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final messages = controller.npcMessagesFor(widget.npcId);
    _scrollToBottomIfNeeded(messages.length);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.shellBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Column(
              children: <Widget>[
                _NpcChatTopBar(
                  title: npc.name,
                  subtitle: _selecting
                      ? AppTheme.glitchText(
                          '已选择 ${_selectedMessageIds.length} 条')
                      : AppTheme.glitchText('只沉淀印象，不推进主线'),
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: _selecting
                      ? <Widget>[
                          _NpcTopIconButton(
                            tooltip: '删除选中',
                            onPressed: _selectedMessageIds.isNotEmpty
                                ? _deleteSelected
                                : null,
                            icon: Icons.delete_outline_rounded,
                          ),
                          TextButton(
                            onPressed: _exitSelecting,
                            child: Text(AppTheme.glitchText('取消')),
                          ),
                        ]
                      : <Widget>[
                          _NpcTopIconButton(
                            tooltip: '选择消息',
                            onPressed: messages.isEmpty
                                ? null
                                : () => setState(() => _selecting = true),
                            icon: Icons.checklist_outlined,
                          ),
                          _NpcTopIconButton(
                            tooltip: '重新回复',
                            onPressed: _hasNpcReply(messages) &&
                                    !controller.isNpcReplyingTo(widget.npcId)
                                ? _regenerateNpcReply
                                : null,
                            icon: Icons.replay_rounded,
                          ),
                          _NpcTopIconButton(
                            tooltip: '导出记录',
                            onPressed: messages.isEmpty
                                ? null
                                : () => _exportThread(npc, controller),
                            icon: Icons.file_download_outlined,
                          ),
                          _NpcTopIconButton(
                            tooltip: '查看印象',
                            onPressed: () => _showImpressionSheet(npc),
                            icon: Icons.psychology_alt_outlined,
                          ),
                        ],
                ),
                const SizedBox(height: 8),
                _NpcThreadHeader(npc: npc),
                const SizedBox(height: 12),
                Expanded(
                  child: messages.isEmpty
                      ? EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: AppTheme.glitchText('还没有私聊记录'),
                          description: AppTheme.glitchText(
                              '先像手机聊天一样发送一两条气泡，再点小飞机让 NPC 回复。私聊不会推进主线。'),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: messages.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final selected =
                                _selectedMessageIds.contains(message.id);
                            return _NpcMessageBubble(
                              message: message,
                              npcName: npc.name,
                              frameId: controller.currentBubbleFrameId,
                              customStyle: BubbleStyleSpec.fromCustom(
                                controller.gamification.customBubbleStyles,
                                controller.currentBubbleFrameId,
                              ),
                              selected: selected,
                              selecting: _selecting,
                              onTap: _selecting
                                  ? () => _toggleMessage(message.id)
                                  : null,
                              onLongPress: _selecting
                                  ? null
                                  : () => _showMessageMenu(message),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                ChatInputBar(
                  isSending: controller.isNpcReplyingTo(widget.npcId),
                  canPause: false,
                  hasPendingMessages:
                      controller.hasPendingNpcUserMessages(widget.npcId),
                  enabled: npc.canSendMessages,
                  disabledHint: '${npc.lifecycle.label}状态下，私聊与好感已冻结',
                  // 主聊天常驻导航栈，只允许它持有全局教程目标。
                  tutorialTargetsEnabled: false,
                  leading: Tooltip(
                    message: AppTheme.glitchText('NPC 互动'),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.activeAccent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.activeLine),
                      ),
                      child: IconButton(
                        onPressed: !npc.canSendMessages ||
                                controller.isNpcReplyingTo(widget.npcId) ||
                                _isOpeningNpcTool
                            ? null
                            : () => _showNpcToolMenu(npc, messages),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
                  onSend: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final error = await context
                        .read<AppStateController>()
                        .queueNpcUserMessage(widget.npcId, value);
                    if (!mounted || error == null) {
                      return;
                    }
                    messenger.showSnackBar(SnackBar(content: Text(error)));
                  },
                  onLaunch: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final error = await context
                        .read<AppStateController>()
                        .requestNpcReply(widget.npcId);
                    if (!mounted || error == null) {
                      return;
                    }
                    messenger.showSnackBar(SnackBar(content: Text(error)));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageMenu(NpcChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (message.role == NpcMessageRole.npc)
                  ListTile(
                    leading: const Icon(Icons.hearing_rounded),
                    title: Text(AppTheme.glitchText(
                      message.innerVoice.trim().isEmpty ? '听这句心声' : '重新生成心声',
                    )),
                    onTap: () {
                      Navigator.of(context).pop();
                      _generateInnerVoice(message);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(AppTheme.glitchText('编辑')),
                  onTap: () {
                    Navigator.of(context).pop();
                    _editMessage(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: Text(AppTheme.glitchText('复制')),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppTheme.glitchText('已复制'))),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.checklist_outlined),
                  title: Text(AppTheme.glitchText('多选')),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selecting = true;
                      _selectedMessageIds.add(message.id);
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(AppTheme.glitchText('删除'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteMessage(message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNpcToolMenu(
    NpcProfile npc,
    List<NpcChatMessage> messages,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.card_giftcard_rounded),
                  title: Text(AppTheme.glitchText('礼物')),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showGiftSheet(npc);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.touch_app_outlined),
                  title: Text(AppTheme.glitchText('长按 NPC 气泡听心声')),
                  subtitle: Text(AppTheme.glitchText('可以指定任意一条 NPC 消息。')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateInnerVoice(NpcChatMessage message) async {
    final regenerate = message.innerVoice.trim().isNotEmpty;
    setState(() => _isOpeningNpcTool = true);
    final messenger = ScaffoldMessenger.of(context);
    final error =
        await context.read<AppStateController>().generateNpcInnerVoice(
              widget.npcId,
              message.id,
              regenerate: regenerate,
            );
    if (!mounted) {
      return;
    }
    setState(() => _isOpeningNpcTool = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    NpcChatMessage? updated;
    for (final item
        in context.read<AppStateController>().npcMessagesFor(widget.npcId)) {
      if (item.id == message.id) {
        updated = item;
        break;
      }
    }
    if (updated?.innerVoice.trim().isNotEmpty == true && mounted) {
      await _showInnerVoiceDialog(updated!);
    }
  }

  Future<void> _showInnerVoiceDialog(NpcChatMessage message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('TA 的心声')),
        content: SingleChildScrollView(
          child: Text(message.innerVoice.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppTheme.glitchText('关闭')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _generateInnerVoice(message);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppTheme.glitchText('重新生成')),
          ),
        ],
      ),
    );
  }

  Future<void> _showGiftSheet(NpcProfile npc) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.panel,
      builder: (context) => _NpcGiftSheet(
        npc: npc,
        onGiftInventoryItem: _sendInventoryGift,
        onGiftShopOffer: _sendShopGift,
      ),
    );
  }

  Future<void> _sendInventoryGift(StoryInventoryItem item) async {
    Navigator.of(context).maybePop();
    setState(() => _isOpeningNpcTool = true);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<AppStateController>().sendNpcGift(
          npcId: widget.npcId,
          itemId: item.id,
        );
    if (!mounted) {
      return;
    }
    setState(() => _isOpeningNpcTool = false);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? '礼物已送出。')),
    );
  }

  Future<void> _sendShopGift(
    StoryShopOffer offer, {
    required String source,
    bool useDebt = false,
  }) async {
    Navigator.of(context).maybePop();
    setState(() => _isOpeningNpcTool = true);
    final messenger = ScaffoldMessenger.of(context);
    final error =
        await context.read<AppStateController>().buyStoryShopOfferForNpcGift(
              widget.npcId,
              offer,
              shopSource: source,
              useDebt: useDebt,
            );
    if (!mounted) {
      return;
    }
    setState(() => _isOpeningNpcTool = false);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? '礼物已买下并送给 TA。')),
    );
  }

  void _scrollToBottomIfNeeded(int messageCount) {
    if (messageCount == _lastMessageCount) {
      return;
    }
    _lastMessageCount = messageCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showImpressionSheet(NpcProfile npc) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.panel,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('${npc.name} 的印象'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _NpcInfoPill(
                  icon: Icons.favorite_border_rounded,
                  text: '当前好感度 ${npc.affinity}',
                ),
                _NpcInfoPill(
                  icon: Icons.route_outlined,
                  text: _formatNpcBondLabel(
                    npc.bondRoute,
                    includeScore: true,
                  ),
                ),
                const SizedBox(height: 12),
                _NpcImpressionDeltaCard(npc: npc),
                const SizedBox(height: 18),
                _NpcBondPanel(npc: npc),
                const SizedBox(height: 18),
                Text(
                  AppTheme.glitchText('印象历史'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (npc.impressionHistory.isEmpty)
                  Text(
                    AppTheme.glitchText('暂无历史。'),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  for (final entry in npc.impressionHistory.take(20))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DecoratedBox(
                        decoration: AppTheme.glassPanel(radius: 18),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(entry.summary),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NpcChatTopBar extends StatelessWidget {
  const _NpcChatTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    final light = AppTheme.isLightPaletteMode;
    final overlayStyle =
        light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            light ? Brightness.dark : Brightness.light,
      ),
      child: ClipRRect(
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
                horizontal: 4 * uiScale,
                vertical: 5 * uiScale,
              ),
              child: Row(
                children: <Widget>[
                  _NpcTopIconButton(
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: Icons.arrow_back_rounded,
                  ),
                  SizedBox(width: 6 * uiScale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.textMain,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                    height: 1.18,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 4 * uiScale),
                  for (final action in actions) action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NpcTopIconButton extends StatelessWidget {
  const _NpcTopIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    return Tooltip(
      message: AppTheme.glitchText(tooltip),
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 21 * uiScale,
        style: AppTheme.skinIconButtonStyle(
          base: IconButton.styleFrom(
            backgroundColor: AppTheme.activePrimary.withValues(
              alpha: AppTheme.isLightPaletteMode ? 0.08 : 0.13,
            ),
            foregroundColor: AppTheme.isLightPaletteMode
                ? AppTheme.activePrimary
                : AppTheme.activeSoft,
            disabledForegroundColor: AppTheme.textWeak.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14 * uiScale),
            ),
          ),
        ),
        constraints: BoxConstraints.tightFor(
          width: 40 * uiScale,
          height: 40 * uiScale,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
