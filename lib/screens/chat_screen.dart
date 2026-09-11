import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/character_memory.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/background_music.dart';
import '../models/bubble_style.dart';
import '../models/fanfic_blind_box.dart';
import '../models/fanfic_result.dart';
import '../models/game_state.dart';
import '../models/gamification.dart';
import '../models/map_state.dart';
import '../models/npc_profile.dart';
import '../models/story_systems.dart';
import '../models/tool_result.dart';
import '../services/archive_file_picker.dart';
import '../services/chat_export_builder.dart';
import '../services/file_download_service.dart';
import '../services/message_content_parser.dart';
import '../services/npc_message_classifier.dart';
import '../services/story_share_card_builder.dart';
import '../services/story_insight_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_skin_assets.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/character_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/format_helper_dialog.dart';
import '../widgets/html_content_view.dart';
import '../widgets/memory_manager_dialog.dart';
import '../widgets/runnable_code_preview.dart';
import '../widgets/theater_popup.dart';
import 'map_mode_screen.dart';
import 'npc_chats_screen.dart';
import 'npc_migration_archive_screen.dart';

part 'chat/chat_top_action_row.dart';
part 'chat/chat_map_panel.dart';
part 'chat/chat_mailbox.dart';
part 'chat/game_hub_dialog.dart';
part 'chat/game_hub_inventory_dialogs.dart';
part 'chat/chat_dialogs_and_effects.dart';
part 'chat/chat_layout_widgets.dart';
part 'chat/story_insights_dialog.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatBottomEdge extends StatelessWidget {
  const _ChatBottomEdge({
    required this.edgeToEdge,
    required this.screenWidth,
    required this.child,
  });

  final bool edgeToEdge;
  final double screenWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!edgeToEdge) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final widthFactor = contentWidth.isFinite && contentWidth > 0
            ? screenWidth / contentWidth
            : 1.0;
        return FractionallySizedBox(
          alignment: Alignment.bottomCenter,
          widthFactor: widthFactor,
          child: child,
        );
      },
    );
  }
}

class _DirectorInputButton extends StatelessWidget {
  const _DirectorInputButton({
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    return Tooltip(
      message: AppTheme.glitchText(active ? '本轮导演指令已设置' : '设置下一回合导演指令'),
      child: SizedBox.square(
        dimension: 46 * uiScale,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: IconButton.filledTonal(
                onPressed: onPressed,
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
            if (active)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.panel, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  late final ScrollController _scrollController;
  int _lastMessageCount = 0;
  bool _isImmersiveMode = false;
  bool _isExportMode = false;
  final Set<String> _selectedExportIds = <String>{};
  bool _isBatchSelectionMode = false;
  final Set<String> _selectedMessageIds = <String>{};
  String? _draftText;
  int _draftVersion = 0;
  final List<_MapBasketItem> _mapBasket = <_MapBasketItem>[];
  Offset? _mapOrbOffset;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final character = controller.currentCharacter;
    final history = controller.currentHistory;
    final memory = controller.currentMemory;
    final gameState = controller.currentGameState;
    final size = MediaQuery.sizeOf(context);
    final uiScale = AppTheme.uiScaleOf(context);
    final compactLayout = size.width < 700 || size.height < 860;
    final denseVerticalLayout = !compactLayout && size.height < 1080;
    final ultraCompact =
        compactLayout && (size.height < 760 || size.width < 390);
    final mobileEdgeToEdge = size.width < 640;
    final horizontalPadding =
        (mobileEdgeToEdge ? (ultraCompact ? 10.0 : 12.0) : 20.0) * uiScale;
    final themeDescriptor = AppTheme.describeTheme(controller.settings.themeId);

    if (character == null) {
      return EmptyState(
        icon: Icons.theater_comedy_outlined,
        title: '还没有可用角色',
        description: '先去角色页创建一个角色，然后就能开始对话了。',
        actionLabel: '前往角色页',
        onAction: () =>
            context.read<AppStateController>().setCurrentTabIndex(1),
      );
    }

    final visibleMessageIds =
        history.messages.map((message) => message.id).toSet();
    final selectedExportIds =
        _selectedExportIds.where(visibleMessageIds.contains).toSet();
    final selectedMessageIds =
        _selectedMessageIds.where(visibleMessageIds.contains).toSet();
    final rootCharacter = controller.currentRootCharacter ?? character;
    final storyBranches = controller.storyBranchesFor(rootCharacter.id);

    _scrollToBottomIfNeeded(
      currentCount: history.messages.length,
      isSending: controller.isSending,
    );
    _scheduleNpcLetterNotice(controller);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        (compactLayout ? (ultraCompact ? 6 : 10) : 16) * uiScale,
        horizontalPadding,
        10 * uiScale,
      ),
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              _ChatTopActionRow(
                themeId:
                    themeDescriptor.isRuntimeTheme ? '' : themeDescriptor.id,
                immersiveMode: _isImmersiveMode,
                onToggleImmersive: _toggleImmersiveMode,
                coinBalance: controller.gamification.coins,
                mailboxUnreadCount: controller.mailboxUnreadCount,
                npcUnreadCount: controller.currentNpcUnreadCount,
                onOpenGameHub: _showGameHubDialog,
                onOpenMailbox: _showMailboxDialog,
                onOpenStory: () => showStoryInsightsDialog(
                  context,
                  onCreateFanfic: _showFanficDialog,
                  onCreateNpcDiary: _createNpcDiary,
                  onCreateWorldFeed: _createWorldFeed,
                  onOpenToolResult: _showToolResultSheet,
                  onOpenFanficResult: _showFanficResultSheet,
                ),
                onOpenNpcChats: _openNpcChats,
                onOpenGameState: () => _showGameStateDialog(gameState),
                mapModeEnabled: character.mapModeEnabled,
                largeGroupChatModeEnabled: character.largeGroupChatModeEnabled,
                onEnterExport: () {
                  setState(() {
                    _isBatchSelectionMode = false;
                    _selectedMessageIds.clear();
                    _isExportMode = true;
                    _selectedExportIds.clear();
                  });
                },
                onShareCard: history.messages.isEmpty
                    ? null
                    : () => _shareStoryCard(
                          character: character,
                          messages: history.messages,
                        ),
                onClearHistory:
                    history.messages.isEmpty ? null : _confirmClearHistory,
                compact: compactLayout,
                characterName: character.name,
                memoryCount: memory.summaries.length,
                onOpenUserProfile: () =>
                    context.read<AppStateController>().setCurrentTabIndex(3),
              ),
              SizedBox(height: (compactLayout ? 6 : 10) * uiScale),
              if (!_isImmersiveMode) ...<Widget>[
                if (compactLayout)
                  _MobileChatHeader(
                    character: character,
                    memoryCount: memory.summaries.length,
                    gameState: gameState,
                    onOpenDetails: () => _showCompactDetailsSheet(
                      controller: controller,
                      character: character,
                      memory: memory,
                    ),
                    onOpenStoryInfo: () => _showStoryInfoSheet(
                      controller: controller,
                      character: character,
                      memory: memory,
                      gameState: gameState,
                    ),
                  )
                else
                  _DesktopChatOverviewCard(
                    character: character,
                    memory: memory,
                    memoryContextItems: controller.settings.memoryContextItems,
                    availableCharacters: controller.characters,
                    onSelectCharacter:
                        context.read<AppStateController>().selectCharacter,
                    onManageCharacters: () => context
                        .read<AppStateController>()
                        .setCurrentTabIndex(1),
                    onViewMemory: () => showMemoryManagerDialog(context),
                  ),
                if (!controller.settings.canChat) ...<Widget>[
                  SizedBox(
                    height: (compactLayout ? (ultraCompact ? 8 : 10) : 16) *
                        uiScale,
                  ),
                  _SetupBanner(
                    compact: compactLayout,
                    onTap: () => context
                        .read<AppStateController>()
                        .setCurrentTabIndex(4),
                  ),
                ],
                if (controller.continueDashboard.hasAnySignal) ...<Widget>[
                  SizedBox(
                    height: (compactLayout ? (ultraCompact ? 8 : 10) : 14) *
                        uiScale,
                  ),
                  _ContinueDashboardCard(
                    dashboard: controller.continueDashboard,
                    compact: compactLayout || denseVerticalLayout,
                    onOpenBookmarks: () =>
                        _showBookmarksDialog(history.messages),
                    onOpenNpc: _openNpcChats,
                    onOpenMailbox: _showMailboxDialog,
                    onScrollBottom: _scrollToBottom,
                    onOpenMap: character.mapModeEnabled ? _openMapMode : null,
                  ),
                ],
                SizedBox(
                  height:
                      (compactLayout ? (ultraCompact ? 8 : 10) : 16) * uiScale,
                ),
                if (!compactLayout || _isExportMode)
                  _ChatToolbar(
                    exportMode: _isExportMode,
                    selectedCount: selectedExportIds.length,
                    compact: compactLayout,
                    ultraCompact: ultraCompact,
                    onEnterExport: () {
                      setState(() {
                        _isBatchSelectionMode = false;
                        _selectedMessageIds.clear();
                        _isExportMode = true;
                        _selectedExportIds.clear();
                      });
                    },
                    onCancelExport: () {
                      setState(() {
                        _isExportMode = false;
                        _selectedExportIds.clear();
                      });
                    },
                    onExport: selectedExportIds.isEmpty
                        ? null
                        : () => _exportMessages(
                              character: character,
                              messages: history.messages
                                  .where((message) =>
                                      selectedExportIds.contains(message.id))
                                  .toList(growable: false),
                            ),
                    onShareCard: history.messages.isEmpty
                        ? null
                        : () => _shareStoryCard(
                              character: character,
                              messages: history.messages,
                            ),
                    onClearHistory:
                        history.messages.isEmpty ? null : _confirmClearHistory,
                  ),
                if (storyBranches.isNotEmpty ||
                    character.isStoryBranch) ...<Widget>[
                  SizedBox(height: (compactLayout ? 8 : 10) * uiScale),
                  _StoryBranchBar(
                    rootCharacter: rootCharacter,
                    currentCharacter: character,
                    branches: storyBranches,
                    onSelect: (characterId) => context
                        .read<AppStateController>()
                        .selectCharacter(characterId),
                    onDelete: _confirmDeleteStoryBranch,
                  ),
                ],
                SizedBox(
                  height:
                      (compactLayout ? (ultraCompact ? 8 : 10) : 14) * uiScale,
                ),
                if (compactLayout) ...<Widget>[
                  _MobileStagePromptBar(
                    gameState: gameState,
                    onOpenStoryInfo: () => _showStoryInfoSheet(
                      controller: controller,
                      character: character,
                      memory: memory,
                      gameState: gameState,
                    ),
                  ),
                  SizedBox(height: (ultraCompact ? 8 : 10) * uiScale),
                ],
              ],
              Expanded(
                child: _PremiumChatFrame(
                  themeDescriptor: themeDescriptor,
                  child: history.messages.isEmpty
                      ? EmptyState(
                          icon: Icons.forum_outlined,
                          title: '还没有对话记录',
                          description: '输入第一条消息开始互动，角色会把重要内容沉淀到长期记忆里。',
                        )
                      : Stack(
                          children: <Widget>[
                            ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(bottom: 76),
                              itemCount: history.messages.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final message = history.messages[index];
                                final deferHtmlPreview = message.role ==
                                        ChatRole.assistant &&
                                    index < history.messages.length - 3 &&
                                    !controller.isMessageStreaming(message.id);
                                return ChatMessageBubble(
                                  message: message,
                                  assistantName: character.name,
                                  isStreaming:
                                      controller.isMessageStreaming(message.id),
                                  streamingTextEnabled:
                                      character.streamingOutputEnabled,
                                  streamingElapsedSeconds:
                                      controller.streamingElapsedSeconds,
                                  showExportSelection: _isExportMode,
                                  exportSelected:
                                      selectedExportIds.contains(message.id),
                                  onToggleExport: (value) {
                                    setState(() {
                                      if (value) {
                                        _selectedExportIds.add(message.id);
                                      } else {
                                        _selectedExportIds.remove(message.id);
                                      }
                                    });
                                  },
                                  showBatchSelection: _isBatchSelectionMode,
                                  batchSelected:
                                      selectedMessageIds.contains(message.id),
                                  onToggleBatchSelection: (value) =>
                                      _toggleBatchSelection(message.id, value),
                                  onSelectMultiple: () =>
                                      _enterBatchSelection(message.id),
                                  onCopy: () => _copyMessage(message),
                                  onEdit: () => _editMessage(message),
                                  onCreateBranch: () =>
                                      _createStoryBranchFromMessage(message),
                                  onToggleBookmark: () =>
                                      _editBookmark(message),
                                  onDelete: () => _confirmDelete(message),
                                  onRegenerate:
                                      message.role == ChatRole.assistant
                                          ? () => _regenerateMessage(message.id)
                                          : null,
                                  onBeautifyPanel: message.role ==
                                              ChatRole.assistant &&
                                          !character.largeGroupChatModeEnabled
                                      ? () =>
                                          _beautifyMessageAsPanel(message.id)
                                      : null,
                                  onRepairFormat:
                                      message.role == ChatRole.assistant
                                          ? () => _openFormatTool(message)
                                          : null,
                                  onChoicesSelected:
                                      message.role == ChatRole.assistant
                                          ? _fillInputWithChoices
                                          : null,
                                  onPreviewChoice:
                                      message.role == ChatRole.assistant
                                          ? (choice) =>
                                              _previewChoice(message, choice)
                                          : null,
                                  onResetChoices:
                                      message.role == ChatRole.assistant
                                          ? _resetDraftInput
                                          : null,
                                  onHtmlActionSelected:
                                      message.role == ChatRole.assistant
                                          ? _fillInputWithText
                                          : null,
                                  npcProfiles:
                                      controller.currentCharacterNpcProfiles,
                                  onGroupChatMention:
                                      character.largeGroupChatModeEnabled
                                          ? _mentionGroupChatSpeaker
                                          : null,
                                  onGroupChatReply:
                                      character.largeGroupChatModeEnabled
                                          ? _replyToGroupChatMessage
                                          : null,
                                  equippedFrameId:
                                      controller.currentBubbleFrameId,
                                  equippedStickerId:
                                      controller.gamification.equippedStickerId,
                                  customBubbleStyle: BubbleStyleSpec.fromCustom(
                                    controller.gamification.customBubbleStyles,
                                    controller.currentBubbleFrameId,
                                  ),
                                  deferHtmlPreview: deferHtmlPreview,
                                );
                              },
                            ),
                            Positioned(
                              right: 6,
                              bottom: 14,
                              child: _ChatScrollButtons(
                                onTop: _scrollToTop,
                                onBottom: _scrollToBottom,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(
                  height:
                      (compactLayout ? (ultraCompact ? 8 : 10) : 18) * uiScale),
              _ChatBottomEdge(
                edgeToEdge: mobileEdgeToEdge,
                screenWidth: size.width,
                child: _isBatchSelectionMode
                    ? _BatchSelectionBar(
                        selectedCount: selectedMessageIds.length,
                        compact: compactLayout,
                        ultraCompact: ultraCompact,
                        onCancel: _cancelBatchSelection,
                        onDelete: selectedMessageIds.isEmpty
                            ? null
                            : _confirmBatchDelete,
                      )
                    : _isExportMode
                        ? _ExportHintBar(
                            selectedCount: selectedExportIds.length,
                            compact: compactLayout,
                            ultraCompact: ultraCompact,
                            onCancel: () {
                              setState(() {
                                _isExportMode = false;
                                _selectedExportIds.clear();
                              });
                            },
                            onExport: selectedExportIds.isEmpty
                                ? null
                                : () => _exportMessages(
                                      character: character,
                                      messages: history.messages
                                          .where((message) => selectedExportIds
                                              .contains(message.id))
                                          .toList(growable: false),
                                    ),
                            onShareCard: selectedExportIds.isEmpty
                                ? null
                                : () => _shareStoryCard(
                                      character: character,
                                      messages: history.messages
                                          .where((message) => selectedExportIds
                                              .contains(message.id))
                                          .toList(growable: false),
                                    ),
                          )
                        : character.mapModeEnabled
                            ? _MapModeQuickActionBar(
                                basketCount: _mapBasket.length,
                                isBusy: controller.isMapGenerating,
                                onAdd: _addMapBasketItem,
                                onOpenMap: _openMapMode,
                              )
                            : ChatInputBar(
                                edgeToEdge: mobileEdgeToEdge,
                                leading: _DirectorInputButton(
                                  active:
                                      controller.activeTurnDirective != null,
                                  onPressed: _showDirectorDialog,
                                ),
                                isSending: controller.isSending,
                                canPause: controller.streamingMessageId != null,
                                hasPendingMessages:
                                    controller.hasPendingUserMessages,
                                draftText: _draftText,
                                draftVersion: _draftVersion,
                                quickActions: ultraCompact
                                    ? const <ChatQuickAction>[]
                                    : character.largeGroupChatModeEnabled
                                        ? _groupChatQuickActions(
                                            controller
                                                .currentCharacterNpcProfiles,
                                            gameState,
                                          )
                                        : compactLayout
                                            ? _stageQuickActions
                                            : const <ChatQuickAction>[],
                                onQuickActionSelected: _fillInputWithText,
                                onSend: (value) async {
                                  final appState =
                                      context.read<AppStateController>();
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final error =
                                      await appState.queueUserMessage(value);
                                  if (!mounted || error == null) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                },
                                onLaunch: () async {
                                  final appState =
                                      context.read<AppStateController>();
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final error =
                                      await appState.requestAssistantReply();
                                  if (!mounted || error == null) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                },
                              ),
              ),
            ],
          ),
          if (character.mapModeEnabled)
            _FloatingMapOrb(
              state: controller.currentMapState,
              basketCount: _mapBasket.length,
              isBusy: controller.isMapGenerating,
              initialOffset: _mapOrbOffset,
              onOffsetChanged: (offset) => _mapOrbOffset = offset,
              onTap: _openMapMode,
            ),
        ],
      ),
    );
  }

  void _toggleImmersiveMode() {
    setState(() {
      _isImmersiveMode = !_isImmersiveMode;
      if (_isImmersiveMode) {
        _isExportMode = false;
        _selectedExportIds.clear();
        _isBatchSelectionMode = false;
        _selectedMessageIds.clear();
      }
    });
  }

  void _enterBatchSelection(String messageId) {
    setState(() {
      _isImmersiveMode = false;
      _isExportMode = false;
      _selectedExportIds.clear();
      _isBatchSelectionMode = true;
      _selectedMessageIds.add(messageId);
    });
  }

  void _toggleBatchSelection(String messageId, bool value) {
    setState(() {
      if (value) {
        _selectedMessageIds.add(messageId);
      } else {
        _selectedMessageIds.remove(messageId);
      }

      if (_selectedMessageIds.isEmpty) {
        _isBatchSelectionMode = false;
      }
    });
  }

  void _cancelBatchSelection() {
    setState(() {
      _isBatchSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _createStoryBranchFromMessage(ChatMessage message) async {
    final branchName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _StoryBranchNameDialog(),
    );
    if (branchName == null || !mounted) {
      return;
    }
    final error =
        await context.read<AppStateController>().createStoryBranchFromMessage(
              messageId: message.id,
              branchName: branchName,
            );
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    setState(() {
      _isExportMode = false;
      _selectedExportIds.clear();
      _isBatchSelectionMode = false;
      _selectedMessageIds.clear();
    });
    _showTopNotice(context, '剧情分支已创建，已进入新的可能性。');
  }

  Future<void> _editBookmark(ChatMessage message) async {
    final result = await showDialog<_BookmarkDraft>(
      context: context,
      builder: (_) => _BookmarkDialog(message: message),
    );
    if (!mounted || result == null) {
      return;
    }
    await context.read<AppStateController>().updateMessageBookmark(
          message.id,
          bookmarked: result.bookmarked,
          note: result.note,
        );
    if (!mounted) {
      return;
    }
    _showTopNotice(context, result.bookmarked ? '已加入消息书签。' : '已取消消息书签。');
  }

  Future<void> _showBookmarksDialog(List<ChatMessage> messages) async {
    final bookmarks = messages
        .where((message) => message.isBookmarked)
        .toList(growable: false)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (bookmarks.isEmpty) {
      _showTopNotice(context, '当前角色还没有消息书签。');
      return;
    }
    final target = await showDialog<ChatMessage>(
      context: context,
      builder: (_) => _BookmarksDialog(bookmarks: bookmarks),
    );
    if (!mounted || target == null) {
      return;
    }
    final index = messages.indexWhere((message) => message.id == target.id);
    if (index < 0 || !_scrollController.hasClients) {
      return;
    }
    final estimatedOffset = (index * 150.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      estimatedOffset,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _confirmDeleteStoryBranch(CharacterProfile branch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _StreamingConfirmDialog(
        title: '删除剧情分支',
        message:
            '真的要删掉「${branch.branchName.trim().isEmpty ? '未命名分支' : branch.branchName.trim()}」这条 if 线吗？主线和其他分支不会受影响。',
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final error = await context.read<AppStateController>().deleteCharacter(
          branch.id,
        );
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    _showTopNotice(context, '这条剧情分支已经删除。');
  }

  void _scheduleNpcLetterNotice(AppStateController controller) {
    final notice = controller.pendingNpcLetterNotice;
    if (notice == null || notice.trim().isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller.pendingNpcLetterNotice != notice) {
        return;
      }
      _showTopNotice(context, notice);
      context.read<AppStateController>().consumeNpcLetterNotice();
    });
  }

  Future<void> _openNpcChats() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NpcChatsScreen(),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _openCurrentMigrationArchive() async {
    final record = context.read<AppStateController>().currentNpcMigrationRecord;
    if (record == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NpcMigrationArchiveScreen(
          initialRecordId: record.id,
          createdCharacterId: record.createdCharacterId,
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _triggerCurrentMigrationEcho() async {
    final controller = context.read<AppStateController>();
    final record = controller.currentNpcMigrationRecord;
    if (record == null) {
      return;
    }
    final error = await controller.triggerNpcMigrationEcho(
      recordId: record.id,
      echoType: '随机回声',
    );
    if (!mounted) {
      return;
    }
    _showTopNotice(context, error ?? '前尘回声已触发。', isError: error != null);
  }

  Future<void> _openMapMode() async {
    if (MediaQuery.sizeOf(context).shortestSide < 600) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const MapModeScreen(),
        ),
      );
      if (mounted) {
        setState(() {});
      }
      return;
    }
    _showMapOverlay(context.read<AppStateController>().currentMapState);
  }

  Future<void> _showMapOverlay(MapWorldState state) async {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 700;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.44),
      builder: (sheetContext) {
        final heightFactor = compact ? 0.88 : 0.82;
        return Align(
          alignment: compact ? Alignment.bottomCenter : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: compact ? 1 : 0.54,
            heightFactor: heightFactor,
            child: _ChatMapPanel(
              basket: _mapBasket,
              onAdd: _addMapBasketItem,
              onRemove: _removeMapBasketItem,
              onClear: _clearMapBasket,
              onMove: _moveMapBasketItem,
              onSubmit: _submitMapBasket,
              onGenerate: _generateMapFromChat,
              onRegenerate: _confirmRegenerateMainMap,
            ),
          ),
        );
      },
    );
  }

  void _addMapBasketItem(_MapBasketItem item) {
    final normalized = item.normalizedKey;
    if (normalized.isEmpty) {
      return;
    }
    setState(() {
      final rulesDriven =
          context.read<AppStateController>().currentMapState.isRulesDriven;
      if (rulesDriven && item.kind == _MapBasketItemKind.location) {
        _mapBasket.removeWhere(
          (entry) => entry.kind == _MapBasketItemKind.location,
        );
      }
      if (!_mapBasket.any((entry) => entry.normalizedKey == normalized)) {
        _mapBasket.add(item);
      }
    });
    _showTopNotice(context, '已加入行动篮子。');
  }

  void _removeMapBasketItem(int index) {
    if (index < 0 || index >= _mapBasket.length) {
      return;
    }
    setState(() => _mapBasket.removeAt(index));
  }

  void _clearMapBasket() {
    if (_mapBasket.isEmpty) {
      return;
    }
    setState(_mapBasket.clear);
  }

  void _moveMapBasketItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _mapBasket.length ||
        newIndex < 0 ||
        newIndex >= _mapBasket.length ||
        oldIndex == newIndex) {
      return;
    }
    setState(() {
      final item = _mapBasket.removeAt(oldIndex);
      _mapBasket.insert(newIndex, item);
    });
  }

  Future<void> _submitMapBasket(String timeStep) async {
    final items = List<_MapBasketItem>.from(_mapBasket);
    final actions = items
        .where((item) => item.kind != _MapBasketItemKind.location)
        .map((item) => item.actionText)
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    final locationIds = items
        .where(
          (item) =>
              item.kind == _MapBasketItemKind.location &&
              item.locationId.trim().isNotEmpty,
        )
        .map((item) => item.locationId.trim())
        .toList(growable: false);
    final error = await context.read<AppStateController>().runMapPlannedRound(
          actions: actions,
          locationIds: locationIds,
          timeStep: timeStep,
          structuredActions:
              items.map((item) => item.toPlanJson()).toList(growable: false),
        );
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    setState(_mapBasket.clear);
    Navigator.of(context).maybePop();
    _showTopNotice(context, '地图主线已推进，本地结算与 AI 叙事已完成。');
  }

  Future<void> _generateMapFromChat() async {
    final error = await context.read<AppStateController>().generateInitialMap();
    if (!mounted) {
      return;
    }
    _showTopNotice(
      context,
      error ?? '地图开局已生成，悬浮地图可以开始用了。',
      isError: error != null,
    );
  }

  Future<void> _confirmRegenerateMainMap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _StreamingConfirmDialog(
        title: '重新生成地图',
        message: '这会重建大地点和线索分布，但不会删除聊天记录。确认继续吗？',
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final error = await context.read<AppStateController>().regenerateMainMap();
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    setState(_mapBasket.clear);
    _showTopNotice(context, '地图已重新生成，旧聊天记录仍然保留。');
  }

  Future<void> _showGameHubDialog() async {
    final appState = context.read<AppStateController>();
    await appState.noteGameHubOpened();
    await appState.loadCurrentNpcThreads();
    if (!mounted) {
      return;
    }
    RunnableCodePreviewInteractionGuard.pushBlock();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _GameHubDialog(
          onUseItem: (itemId) => _useGameHubItem(dialogContext, itemId),
          onUseStoryItem: (item) => _useStoryInventoryItem(dialogContext, item),
          onDestroyStoryItem: _destroyStoryInventoryItem,
          onEditStoryItemNote: _editStoryItemNote,
        ),
      );
    } finally {
      RunnableCodePreviewInteractionGuard.popBlock();
    }
  }

  Future<void> _showMailboxDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _MailboxDialog(),
    );
  }

  Future<void> _useGameHubItem(
    BuildContext dialogContext,
    String itemId,
  ) async {
    final appState = context.read<AppStateController>();
    final item = GameCatalog.shopItemById(itemId);
    String theaterRequest = '';
    if (item != null && _needsTheaterRequest(item.effectId)) {
      final request = await showDialog<String>(
        context: context,
        builder: (context) => _TheaterRequestDialog(
          item: item,
          npcs: appState.currentCharacterNpcProfiles,
        ),
      );
      if (request == null || !mounted) {
        return;
      }
      theaterRequest = request;
    }

    final error = await _withTopLoading(
      context,
      AppTheme.glitchText('商店老板努力中...'),
      () => appState.useInventoryItem(itemId),
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }

    // 剧场道具：弹出流式小剧场窗口
    if (item != null && appState.isTheaterEffect(item.effectId)) {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).maybePop();
      }
      final theaterError = await TheaterPopup.show(
        context: context,
        toolId: item.effectId,
        userRequest: theaterRequest,
      );
      if (!mounted) {
        return;
      }
      if (theaterError != null) {
        _showTopNotice(context, theaterError, isError: true);
      }
      return;
    }

    _showTopNotice(
      context,
      item?.effectId == 'npc_letter'
          ? 'NPC 来信已送达，去来信箱或 NPC 私聊查看。'
          : '商店老板交货了，结果已保存到历史记录。',
    );
    final result = appState.lastGeneratedToolResult;
    if (result != null && mounted) {
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).maybePop();
      }
      await _showToolResultSheet(result);
    }
  }

  bool _needsTheaterRequest(String effectId) {
    return switch (effectId) {
      'child_spray' ||
      'beast_ear_potion' ||
      'touch' ||
      'truth_lollipop' =>
        true,
      _ => false,
    };
  }

  Future<void> _editStoryItemNote(String itemName, String currentNote) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _StoryItemNoteDialog(
        itemName: itemName,
        initialNote: currentNote,
      ),
    );
    if (note == null || !mounted) {
      return;
    }
    await context.read<AppStateController>().updateStoryItemNote(
          itemName,
          note,
        );
  }

  Future<void> _openFormatTool(ChatMessage message) async {
    final next = await FormatHelperDialog.edit(
      context,
      initialText: message.content,
    );
    if (next == null || !mounted) {
      return;
    }
    final trimmed = next.trim();
    if (trimmed.isEmpty) {
      _showTopNotice(context, '内容不能为空。', isError: true);
      return;
    }
    await context.read<AppStateController>().updateMessageContent(
          message.id,
          trimmed,
        );
    if (!mounted) {
      return;
    }
    _showTopNotice(context, '格式已保存，游戏面板也会重新读取。');
  }

  void _showCompactDetailsSheet({
    required AppStateController controller,
    required CharacterProfile character,
    required CharacterMemory memory,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.panel,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _CompactChatDetailsSheet(
              character: character,
              memory: memory,
              memoryContextItems: controller.settings.memoryContextItems,
              availableCharacters: controller.characters,
              onSelectCharacter: (characterId) {
                Navigator.of(sheetContext).pop();
                unawaited(
                  context
                      .read<AppStateController>()
                      .selectCharacter(characterId),
                );
              },
              onManageCharacters: () {
                Navigator.of(sheetContext).pop();
                context.read<AppStateController>().setCurrentTabIndex(1);
              },
              onViewMemory: () {
                Navigator.of(sheetContext).pop();
                showMemoryManagerDialog(context);
              },
            ),
          ),
        );
      },
    );
  }

  void _showStoryInfoSheet({
    required AppStateController controller,
    required CharacterProfile character,
    required CharacterMemory memory,
    required GameStateSnapshot gameState,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.panel,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.74;
        return SafeArea(
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _StoryInfoSheet(
                character: character,
                memory: memory,
                gameState: gameState,
                npcs: controller.currentCharacterNpcProfiles,
                onOpenGameState: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showGameStateDialog(gameState));
                },
                onOpenMemory: () {
                  Navigator.of(sheetContext).pop();
                  showMemoryManagerDialog(context);
                },
                onOpenNpc: () {
                  Navigator.of(sheetContext).pop();
                  _openNpcChats();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _useStoryInventoryItem(
    BuildContext dialogContext,
    StoryInventoryItem item,
  ) async {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).maybePop();
    }
    final error =
        await context.read<AppStateController>().useStoryInventoryItem(item.id);
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showTopNotice(context, error, isError: true);
      return;
    }
    _showTopNotice(context, '剧情物品已投入主线，看看它把故事搅成什么样了。');
  }

  Future<void> _destroyStoryInventoryItem(StoryInventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _StreamingConfirmDialog(
        title: '丢掉剧情物品',
        message: '真的要把「${item.name}」从剧情物品栏里丢掉吗？',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final error = await context
        .read<AppStateController>()
        .destroyStoryInventoryItem(item.id);
    if (!mounted) {
      return;
    }
    _showTopNotice(
      context,
      error ?? '剧情物品已销毁，背包终于少了一点点人生重量。',
      isError: error != null,
    );
  }

  Future<void> _showGameStateDialog(GameStateSnapshot state) async {
    final character = context.read<AppStateController>().currentCharacter;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final compact = size.width < 640;
        final maxWidth = compact ? size.width - 16 : 760.0;
        final maxHeight = size.height * (compact ? 0.86 : 0.78);
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 28,
            vertical: compact ? 14 : 32,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Container(
              decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
              padding: EdgeInsets.all(compact ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '游戏面板',
                          style: Theme.of(dialogContext)
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
                  if (character?.mapModeEnabled == true ||
                      character?.largeGroupChatModeEnabled == true) ...<Widget>[
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if (character?.mapModeEnabled == true)
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _openMapMode();
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: Text(AppTheme.glitchText('打开地图主线')),
                          ),
                        if (character?.largeGroupChatModeEnabled == true)
                          Chip(
                            avatar: const Icon(Icons.forum_outlined, size: 18),
                            label: Text(AppTheme.glitchText('大型群聊模式')),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _GameStatePanel(
                        state: state,
                        compact: compact,
                        ultraCompact: false,
                        expanded: true,
                      ),
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

  Future<void> _copyMessage(ChatMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('消息内容已复制。')),
    );
  }

  Future<void> _editMessage(ChatMessage message) async {
    final nextContent = await showDialog<String>(
      context: context,
      builder: (context) => _MessageEditorDialog(message: message),
    );

    if (!mounted || nextContent == null) {
      return;
    }

    await context.read<AppStateController>().updateMessageContent(
          message.id,
          nextContent,
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('消息已更新。')),
    );
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _StreamingConfirmDialog(
        title: '删除消息',
        message: '真的要删掉这条消息吗？',
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await context.read<AppStateController>().deleteMessage(message.id);
    setState(() {
      _selectedExportIds.remove(message.id);
      _selectedMessageIds.remove(message.id);
      if (_selectedMessageIds.isEmpty) {
        _isBatchSelectionMode = false;
      }
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('消息已删除。')),
    );
  }

  Future<void> _confirmBatchDelete() async {
    final selectedIds = _selectedMessageIds.toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _StreamingConfirmDialog(
        title: '批量删除',
        message: '真的要删掉这些消息吗？',
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await context.read<AppStateController>().deleteMessages(selectedIds);
    setState(() {
      _selectedExportIds.removeAll(selectedIds);
      _selectedMessageIds.clear();
      _isBatchSelectionMode = false;
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已批量删除选中的消息。')),
    );
  }

  Future<void> _confirmClearHistory() async {
    final character = context.read<AppStateController>().currentCharacter;
    if (character == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _StreamingConfirmDialog(
        title: '清空聊天记录',
        message: '真的要清空“${character.name}”的全部聊天记录吗？这会同时清空这个角色的长期记忆。',
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await context.read<AppStateController>().clearCurrentCharacterHistory();
    setState(() {
      _selectedExportIds.clear();
      _selectedMessageIds.clear();
      _isExportMode = false;
      _isBatchSelectionMode = false;
    });

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('当前角色聊天记录已清空。')),
    );
  }

  Future<void> _regenerateMessage(String messageId) async {
    final direction = await _askRegenerateDirection();
    if (!mounted || direction == null) {
      return;
    }
    final error =
        await context.read<AppStateController>().regenerateAssistantMessage(
              messageId,
              direction: direction,
            );

    if (!mounted || error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<String?> _askRegenerateDirection() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新回复'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '重写方向（可留空）',
            hintText: '例如：更暧昧一点 / 节奏更快 / 不要推进主线太多',
            alignLabelWithHint: true,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
  }

  void _fillInputWithChoices(List<String> choices) {
    setState(() {
      _draftText = choices.join('\n');
      _draftVersion += 1;
    });
  }

  void _resetDraftInput() {
    setState(() {
      _draftText = '';
      _draftVersion += 1;
    });
  }

  void _fillInputWithText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    setState(() {
      _draftText = trimmed;
      _draftVersion += 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已填入输入框，点发送或小飞机继续')),
    );
  }

  void _mentionGroupChatSpeaker(GroupChatMessage message) {
    _fillInputWithText('@${message.speaker}：');
  }

  void _replyToGroupChatMessage(GroupChatMessage message) {
    final compact = message.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    final excerpt =
        compact.length <= 48 ? compact : '${compact.substring(0, 48)}...';
    final target = message.isNarration ? '刚才的旁白' : '@${message.speaker}';
    _fillInputWithText('回复$target「$excerpt」：');
  }

  List<ChatQuickAction> _groupChatQuickActions(
    List<NpcProfile> profiles,
    GameStateSnapshot gameState,
  ) {
    final location = gameState.location.trim().toLowerCase();
    final ranked =
        profiles.where((profile) => profile.name.trim().isNotEmpty).map(
      (profile) {
        final npcLocation = profile.runtimeState.location.trim().toLowerCase();
        var score = profile.companionEnabled ? 80 : 0;
        if (location.isNotEmpty && npcLocation.isNotEmpty) {
          if (location == npcLocation) {
            score += 120;
          } else if (location.contains(npcLocation) ||
              npcLocation.contains(location)) {
            score += 80;
          }
        }
        return (profile: profile, score: score);
      },
    ).toList(growable: false)
          ..sort((a, b) {
            final scoreOrder = b.score.compareTo(a.score);
            if (scoreOrder != 0) return scoreOrder;
            return b.profile.updatedAt.compareTo(a.profile.updatedAt);
          });

    return <ChatQuickAction>[
      const ChatQuickAction(
        label: '继续',
        text: '继续。',
        icon: Icons.play_arrow_rounded,
      ),
      ...ranked.take(5).map(
            (item) => ChatQuickAction(
              label: '@${item.profile.name.trim()}',
              text: '@${item.profile.name.trim()}：',
              icon: Icons.alternate_email_rounded,
            ),
          ),
    ];
  }

  static const List<ChatQuickAction> _stageQuickActions = <ChatQuickAction>[
    ChatQuickAction(
      label: '继续',
      text: '继续。',
      icon: Icons.play_arrow_rounded,
    ),
    ChatQuickAction(
      label: '追问',
      text: '我看着对方，继续追问下去。',
      icon: Icons.help_outline_rounded,
    ),
    ChatQuickAction(
      label: '靠近',
      text: '我向对方走近一步。',
      icon: Icons.near_me_outlined,
    ),
    ChatQuickAction(
      label: '观察',
      text: '我先没有说话，而是仔细观察眼前的变化。',
      icon: Icons.visibility_outlined,
    ),
    ChatQuickAction(
      label: '沉默',
      text: '我沉默下来，等对方自己开口。',
      icon: Icons.more_horiz_rounded,
    ),
    ChatQuickAction(
      label: '转移话题',
      text: '我避开这个问题，换了一个更安全的话题。',
      icon: Icons.alt_route_rounded,
    ),
  ];

  Future<void> _beautifyMessageAsPanel(String messageId) async {
    final error = await context
        .read<AppStateController>()
        .beautifyMessageAsPanel(messageId);
    if (!mounted || error == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _runConversationTool(String toolId) async {
    Navigator.of(context).maybePop();
    final appState = context.read<AppStateController>();
    final error = await appState.generateConversationToolReply(toolId);
    if (!mounted || error == null) {
      final result = appState.lastGeneratedToolResult;
      if (mounted && result != null) {
        await _showToolResultSheet(result);
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _createNpcDiary(NpcProfile npc) async {
    await _runStoryArtifactTool(
      'npc_diary',
      resultTitle: 'NPC 日记 · ${npc.name}',
      userRequest: '''
只写 NPC「${npc.name}」（ID：${npc.id}）的私人日记或内心独白。
必须尊重该 NPC 当前生命周期、好感、羁绊与最近经历；不要改写其他 NPC 的档案，不推进主聊天。
''',
    );
  }

  Future<void> _createWorldFeed() {
    return _runStoryArtifactTool(
      'world_feed',
      resultTitle: '世界动态',
    );
  }

  Future<void> _runStoryArtifactTool(
    String toolId, {
    String userRequest = '',
    String resultTitle = '',
    bool persistResult = true,
  }) async {
    final appState = context.read<AppStateController>();
    final error = await appState.generateConversationToolReply(
      toolId,
      userRequest: userRequest,
      resultTitle: resultTitle,
      persistResult: persistResult,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText(error))),
      );
      return;
    }
    final result = appState.lastGeneratedToolResult;
    if (result != null) {
      await _showToolResultSheet(result);
    }
  }

  Future<void> _previewChoice(
    ChatMessage message,
    MessageChoice choice,
  ) {
    return _runStoryArtifactTool(
      'branch_preview',
      resultTitle: '选项预演 · ${choice.index}',
      persistResult: false,
      userRequest: '''
只预演下面这一个选项，不要比较其他选项：
${choice.index}. ${choice.label}

来源回复 ID：${message.id}
说明它最可能产生的近期结果、风险和叙事风格；不得把预演写入正式剧情，也不得假定玩家已经选择。
''',
    );
  }

  Future<void> _showToolResultSheet(ToolResult result) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final compact = size.width < 640;
        final maxWidth = compact ? size.width - 24 : 760.0;
        final maxHeight = size.height * (compact ? 0.84 : 0.78);
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 28,
            vertical: compact ? 18 : 32,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Container(
              decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 18,
                compact ? 14 : 18,
                compact ? 14 : 18,
                compact ? 14 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              result.toolTitle,
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppTheme.contrastText,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppTheme.glitchText(
                                '工具生成记录 · ${_formatLocalTime(result.createdAt)}',
                              ),
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textWeak),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: AppTheme.glitchText('关闭'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton(
                        tooltip: '复制',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: result.content),
                          );
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('工具结果已复制')),
                          );
                        },
                        icon: const Icon(Icons.content_copy_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: AppTheme.glassPanel(radius: 24),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: HtmlContentView(content: result.content),
                      ),
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

  Future<void> _showDirectorDialog() async {
    final moodController = TextEditingController();
    final focusController = TextEditingController();
    final noteController = TextEditingController();
    var intensity = 2.0;
    final existing = context.read<AppStateController>().activeTurnDirective;
    if (existing != null) {
      moodController.text = existing.mood;
      focusController.text = existing.focus;
      noteController.text = existing.note;
      intensity = existing.intensity.toDouble();
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.panel,
              title: Text(AppTheme.glitchText('剧情导演台')),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppTheme.glitchText(
                          '这里写的是“本轮临时指令”，只影响下一次 AI 回复，不会写进角色提示词。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: moodController,
                        decoration: InputDecoration(
                          labelText: AppTheme.glitchText('本轮氛围'),
                          hintText: AppTheme.glitchText('例如：轻松、暧昧、压迫、日常烟火气'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: focusController,
                        decoration: InputDecoration(
                          labelText: AppTheme.glitchText('镜头重点'),
                          hintText: AppTheme.glitchText('例如：多写 NPC 反应、重视内心戏'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: AppTheme.glitchText('导演补充'),
                          hintText: AppTheme.glitchText('想让下一回合特别注意什么，就塞这里。'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(AppTheme.glitchText('指令强度：${intensity.round()}/5')),
                      Slider(
                        value: intensity,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        onChanged: (value) =>
                            setDialogState(() => intensity = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    context.read<AppStateController>().clearTurnDirective();
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(AppTheme.glitchText('清空')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(AppTheme.glitchText('取消')),
                ),
                FilledButton(
                  onPressed: () {
                    context.read<AppStateController>().setTurnDirective(
                          TurnDirective(
                            mood: moodController.text,
                            focus: focusController.text,
                            note: noteController.text,
                            intensity: intensity.round(),
                          ),
                        );
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(AppTheme.glitchText('应用到下一回合')),
                ),
              ],
            );
          },
        );
      },
    );
    moodController.dispose();
    focusController.dispose();
    noteController.dispose();
  }

  // ignore: unused_element
  Future<void> _showWorldCalendarDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
              child: Consumer<AppStateController>(
                builder: (context, controller, _) {
                  final events = controller.currentWorldCalendarEvents;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppTheme.glitchText('世界事件日历'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Text(
                        AppTheme.glitchText(
                          '这是未来剧情的节奏表，会被注入后续回复作为伏笔参考。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: controller.isSending
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final error =
                                    await controller.generateWorldCalendar();
                                if (!mounted || error == null) {
                                  return;
                                }
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(AppTheme.glitchText(error)),
                                  ),
                                );
                              },
                        icon: controller.isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(AppTheme.glitchText(
                          controller.isSending ? '生成中...' : '生成/刷新事件日历',
                        )),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: events.isEmpty
                            ? Center(
                                child: Text(
                                  AppTheme.glitchText('还没有事件日历，点上面按钮生成一份。'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppTheme.textMuted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: events.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final event = events[index];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: AppTheme.glassPanel(radius: 18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          AppTheme.glitchText(event.title),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: AppTheme.activeSoft,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppTheme.glitchText(
                                            '${event.timeLabel} · ${event.stage}',
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppTheme.textWeak,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          AppTheme.glitchText(
                                            event.description,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _showAiToolsSheet() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final compact = size.width < 640;
        final maxWidth = compact ? size.width - 24 : 720.0;
        final maxHeight = size.height * (compact ? 0.82 : 0.76);
        final toolHistory = dialogContext
            .watch<AppStateController>()
            .currentCharacterToolResults;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 28,
            vertical: compact ? 18 : 32,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Container(
              decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
              padding: EdgeInsets.all(compact ? 14 : 18),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 0, 10),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppTheme.glitchText('剧情工具箱'),
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .titleMedium
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
                    ),
                    _AiToolTile(
                      icon: Icons.history_edu_rounded,
                      title: '生成上集提要',
                      subtitle: '把最近剧情整理成电视剧前情回顾。',
                      onTap: () => _runConversationTool('recap'),
                    ),
                    _AiToolTile(
                      icon: Icons.account_tree_outlined,
                      title: '生成人物关系图',
                      subtitle: '自动提取 NPC、关系变化和好感线索。',
                      onTap: () => _runConversationTool('relationship'),
                    ),
                    _AiToolTile(
                      icon: Icons.bookmark_added_outlined,
                      title: '生成剧情存档封面',
                      subtitle: '生成当前剧情的可视化存档卡。',
                      onTap: () => _runConversationTool('cover'),
                    ),
                    _AiToolTile(
                      icon: Icons.lightbulb_outline_rounded,
                      title: '整理伏笔本',
                      subtitle: '记录已出现但值得留意的细节。',
                      onTap: () => _runConversationTool('foreshadow'),
                    ),
                    _AiToolTile(
                      icon: Icons.route_outlined,
                      title: '预演选项后果',
                      subtitle: '不推进剧情，只分析选项可能影响。',
                      onTap: () => _runConversationTool('branch_preview'),
                    ),
                    _AiToolTile(
                      icon: Icons.edit_note_rounded,
                      title: '生成 NPC 日记',
                      subtitle: '独立生成 NPC 的内心独白，不塞进主聊天。',
                      onTap: () => _runConversationTool('npc_diary'),
                    ),
                    _AiToolTile(
                      icon: Icons.dynamic_feed_outlined,
                      title: '生成世界论坛',
                      subtitle: '生成朋友圈/论坛/公告栏信息流，可回看历史。',
                      onTap: () => _runConversationTool('world_feed'),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        AppTheme.glitchText('历史生成记录'),
                        style: Theme.of(dialogContext)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: AppTheme.activeSoft,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (toolHistory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        child: Text(
                          AppTheme.glitchText('当前角色还没有工具箱生成记录。'),
                          style: Theme.of(dialogContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.textWeak,
                              ),
                        ),
                      )
                    else
                      for (final result in toolHistory.take(12))
                        _ToolHistoryTile(
                          result: result,
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _showToolResultSheet(result);
                          },
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFanficDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _FanficDialog(
        onGenerate: _runFanfic,
        onOpenResult: _showFanficResultSheet,
      ),
    );
  }

  Future<void> _runFanfic(_FanficDraft draft) async {
    Navigator.of(context).maybePop();
    final appState = context.read<AppStateController>();
    final liveText = ValueNotifier<String>('');
    BuildContext? dialogContextHolder;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        dialogContextHolder = dialogContext;
        return _FanficGeneratingDialog(liveText: liveText);
      },
    );
    final error = await appState.generateFanfic(
      pairingMode: draft.pairingMode,
      firstParticipantId: draft.firstNpcId,
      secondParticipantId: draft.secondNpcId,
      inspiration: draft.inspiration,
      blindBox: draft.blindBox,
      onChunk: (partial) => liveText.value = partial,
    );
    final holder = dialogContextHolder;
    if (holder != null && holder.mounted && Navigator.of(holder).canPop()) {
      Navigator.of(holder).pop();
    }
    if (!mounted) {
      return;
    }
    if (error == null) {
      final result = appState.lastGeneratedFanficResult;
      if (result != null) {
        await _showFanficResultSheet(result);
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _showFanficResultSheet(FanficResult result) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final compact = size.width < 640;
        final maxWidth = compact ? size.width - 24 : 820.0;
        final maxHeight = size.height * (compact ? 0.86 : 0.8);
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 28,
            vertical: compact ? 18 : 32,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Container(
              decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
              padding: EdgeInsets.all(compact ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppTheme.glitchText(result.title),
                              maxLines: 2,
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppTheme.textMain,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppTheme.glitchText(
                                '${result.pairingLabel} · ${_formatLocalTime(result.createdAt)}',
                              ),
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: AppTheme.glitchText('关闭'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MetricChip(
                        label: result.blindBox
                            ? AppTheme.glitchText('开盲盒')
                            : AppTheme.glitchText('自填灵感'),
                      ),
                      _MetricChip(
                        label: AppTheme.glitchText(result.inspiration),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.panel.withValues(alpha: 0.56),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.activeLine),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          result.content,
                          style: Theme.of(dialogContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppTheme.textMain,
                                height: 1.7,
                              ),
                        ),
                      ),
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

  String _formatLocalTime(DateTime value) {
    final local = value.toLocal();
    return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportMessages({
    required CharacterProfile character,
    required List<ChatMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return;
    }

    final title =
        '${character.name} 对话记录 ${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-')}';
    final html = ChatExportBuilder.buildHtml(
      title: title,
      assistantName: character.name,
      messages: messages,
    );

    final downloaded = await downloadTextFile(
      filename: '${character.name}_chat_export.html',
      content: html,
      mimeType: 'text/html;charset=utf-8',
    );

    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppStateController>();

    if (downloaded) {
      await appState.noteExportedMessages();
      if (!mounted) {
        return;
      }
      setState(() {
        _isExportMode = false;
        _selectedExportIds.clear();
      });
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          downloaded ? '导出成功，HTML 已开始下载或拉起分享。' : '当前平台暂不支持直接导出文件。',
        ),
      ),
    );
  }

  Future<void> _shareStoryCard({
    required CharacterProfile character,
    required List<ChatMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return;
    }

    final controller = context.read<AppStateController>();
    final themeDescriptor = AppTheme.describeTheme(controller.settings.themeId);
    final title = '${character.name} 剧情分享卡';
    final html = StoryShareCardBuilder.buildHtml(
      title: title,
      assistantName: character.name,
      messages: messages,
      palette: AppTheme.activePalette,
      themeLabel: themeDescriptor.label,
    );

    final downloaded = await downloadTextFile(
      filename: '${character.name}_story_card.html',
      content: html,
      mimeType: 'text/html;charset=utf-8',
    );

    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (downloaded) {
      await controller.noteExportedMessages();
      if (!mounted) {
        return;
      }
      setState(() {
        _isExportMode = false;
        _selectedExportIds.clear();
      });
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          downloaded ? '剧情分享卡已生成，可打开后截图或分享。' : '当前平台暂不支持生成剧情分享卡。',
        ),
      ),
    );
  }

  void _scrollToBottomIfNeeded({
    required int currentCount,
    required bool isSending,
  }) {
    final countChanged = currentCount != _lastMessageCount;
    _lastMessageCount = currentCount;

    if (!countChanged && !isSending) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final target = _scrollController.position.maxScrollExtent;
      if (countChanged) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      _scrollController.jumpTo(target);
    });
  }
}
