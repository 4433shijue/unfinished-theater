import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models/bubble_style.dart';
import '../models/chat_message.dart';
import '../models/npc_profile.dart';
import '../services/file_download_service.dart';
import '../services/message_content_parser.dart';
import '../theme/app_theme.dart';
import 'character_avatar.dart';
import 'gameplay_turn_feedback.dart';
import 'runnable_code_preview.dart';

class ChatMessageBubble extends StatefulWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.assistantName,
    this.isStreaming = false,
    this.streamingTextEnabled = true,
    this.streamingElapsedSeconds = 0,
    this.onCopy,
    this.onEdit,
    this.onDelete,
    this.onRegenerate,
    this.onBeautifyPanel,
    this.onRepairFormat,
    this.onCreateBranch,
    this.onToggleBookmark,
    this.onChoicesSelected,
    this.onPreviewChoice,
    this.onResetChoices,
    this.onHtmlActionSelected,
    this.npcProfiles = const <NpcProfile>[],
    this.onGroupChatMention,
    this.onGroupChatReply,
    this.equippedFrameId = 'frame_default',
    this.equippedStickerId = 'sticker_none',
    this.customBubbleStyle,
    this.showExportSelection = false,
    this.exportSelected = false,
    this.onToggleExport,
    this.showBatchSelection = false,
    this.batchSelected = false,
    this.onToggleBatchSelection,
    this.onSelectMultiple,
    this.deferHtmlPreview = false,
  });

  final ChatMessage message;
  final String assistantName;
  final bool isStreaming;
  final bool streamingTextEnabled;
  final int streamingElapsedSeconds;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRegenerate;
  final VoidCallback? onBeautifyPanel;
  final VoidCallback? onRepairFormat;
  final VoidCallback? onCreateBranch;
  final VoidCallback? onToggleBookmark;
  final ValueChanged<List<String>>? onChoicesSelected;
  final Future<void> Function(MessageChoice choice)? onPreviewChoice;
  final VoidCallback? onResetChoices;
  final ValueChanged<String>? onHtmlActionSelected;
  final List<NpcProfile> npcProfiles;
  final ValueChanged<GroupChatMessage>? onGroupChatMention;
  final ValueChanged<GroupChatMessage>? onGroupChatReply;
  final String equippedFrameId;
  final String equippedStickerId;
  final BubbleStyleSpec? customBubbleStyle;
  final bool showExportSelection;
  final bool exportSelected;
  final ValueChanged<bool>? onToggleExport;
  final bool showBatchSelection;
  final bool batchSelected;
  final ValueChanged<bool>? onToggleBatchSelection;
  final VoidCallback? onSelectMultiple;
  final bool deferHtmlPreview;

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool _hovered = false;

  bool get _showSelection =>
      widget.showExportSelection || widget.showBatchSelection;

  bool get _selectionValue =>
      widget.showExportSelection ? widget.exportSelected : widget.batchSelected;

  ValueChanged<bool>? get _selectionHandler => widget.showExportSelection
      ? widget.onToggleExport
      : widget.onToggleBatchSelection;

  bool get _shouldHideActions => widget.isStreaming;

  bool get _supportsHoverActions {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == ChatRole.user;
    if (isUser) {
      return _buildUserBubble(context);
    }
    return _buildAssistantFlow(context);
  }

  Widget _buildUserBubble(BuildContext context) {
    final theme = Theme.of(context);
    final userTextColor = AppTheme.isBasicPaletteMode
        ? AppTheme.textMain
        : AppTheme.isPastureMode
            ? const Color(0xFF274C55)
            : AppTheme.isTerminalMode
                ? const Color(0xFFE6EEF4)
                : Colors.white;
    final userTimestampColor = AppTheme.isBasicPaletteMode
        ? AppTheme.textMuted
        : AppTheme.isPastureMode
            ? const Color(0xFF537074)
            : AppTheme.isTerminalMode
                ? const Color(0xFFB8C5CE)
                : Colors.white.withValues(alpha: 0.82);
    final maxBubbleWidth = min(MediaQuery.sizeOf(context).width * 0.82, 780.0);
    final showActions = !_shouldHideActions &&
        !_showSelection &&
        _hovered &&
        _supportsHoverActions;
    final bubbleStyle = _CosmeticBubbleStyle.forFrame(
      widget.equippedFrameId,
      isUser: true,
      selected: _selectionValue,
      customStyle: widget.customBubbleStyle,
    );
    final customTextColor = widget.customBubbleStyle?.textFor(true);

    return Align(
      alignment: Alignment.centerRight,
      child: MouseRegion(
        onEnter: _supportsHoverActions
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: _supportsHoverActions
            ? (_) => setState(() => _hovered = false)
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              gradient: bubbleStyle.gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppTheme.isBasicPaletteMode
                        ? <Color>[
                            Colors.white.withValues(alpha: 0.86),
                            AppTheme.activePrimary.withValues(alpha: 0.18),
                            AppTheme.activeAccent.withValues(alpha: 0.12),
                          ]
                        : <Color>[
                            AppTheme.activePrimary.withValues(alpha: 0.78),
                            AppTheme.activeSecondary.withValues(alpha: 0.50),
                            AppTheme.activeAccent.withValues(alpha: 0.42),
                          ],
                  ),
              borderRadius: bubbleStyle.borderRadius,
              border: Border.all(
                color: bubbleStyle.borderColor,
                width: bubbleStyle.borderWidth,
              ),
              boxShadow: bubbleStyle.shadows,
            ),
            child: InkWell(
              onTap: _showSelection && _selectionHandler != null
                  ? () => _selectionHandler!.call(!_selectionValue)
                  : null,
              onLongPress:
                  _supportsHoverActions ? null : () => _openActionSheet(true),
              borderRadius: bubbleStyle.borderRadius,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: _BubbleFrameArt(
                      frameId: widget.equippedFrameId,
                      borderRadius: bubbleStyle.borderRadius,
                      accentColor: bubbleStyle.borderColor,
                      isUser: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget.message.isBookmarked
                                    ? '${widget.message.role.label} · 书签'
                                    : widget.message.role.label,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: customTextColor ?? userTextColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (showActions) _buildActionBar(isUser: true),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          widget.message.content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.58,
                            color: customTextColor ?? userTextColor,
                          ),
                        ),
                        if (widget.message.bookmarkNote.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _BookmarkNotePill(
                            note: widget.message.bookmarkNote.trim(),
                            color: customTextColor ?? userTextColor,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _FooterRow(
                          timestamp: _footerTimestamp,
                          tokenEstimate: widget.message.tokenEstimate,
                          timestampColor: userTimestampColor,
                          showSelection: _showSelection,
                          selectionValue: _selectionValue,
                          onToggleSelection: _selectionHandler,
                        ),
                      ],
                    ),
                  ),
                  _CosmeticStickerBadge(
                    stickerId: widget.equippedStickerId,
                    alignment: Alignment.topRight,
                  ),
                  if (widget.customBubbleStyle?.decorationText?.isNotEmpty ==
                      true)
                    Positioned(
                      right: 12,
                      top: 10,
                      child: IgnorePointer(
                        child: Text(
                          widget.customBubbleStyle!.decorationText!,
                          style: TextStyle(
                            color: (widget.customBubbleStyle!.accentColor ??
                                    bubbleStyle.borderColor)
                                .withValues(
                              alpha:
                                  widget.customBubbleStyle!.decorationOpacity ??
                                      0.24,
                            ),
                            fontSize:
                                widget.customBubbleStyle!.decorationSize ?? 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _assistantTextBubble({required Widget child}) {
    return _AssistantTextBubble(
      frameId: widget.equippedFrameId,
      stickerId: widget.equippedStickerId,
      customStyle: widget.customBubbleStyle,
      child: child,
    );
  }

  Widget _assistantPlaceholder(BuildContext context) {
    return _assistantTextBubble(
      child: Text(
        widget.isStreaming ? AppTheme.glitchText('正在生成回复...') : '',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.assistantBubbleTextColor,
            ),
      ),
    );
  }

  Widget _buildAssistantFlow(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = MessageContentParser.parseStructured(
      _sanitizedAssistantContent,
      cache: !widget.isStreaming,
    );
    final maxWidth = min(MediaQuery.sizeOf(context).width * 0.92, 860.0);
    final showActions = !_shouldHideActions &&
        !_showSelection &&
        _hovered &&
        _supportsHoverActions;

    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        onEnter: _supportsHoverActions
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: _supportsHoverActions
            ? (_) => setState(() => _hovered = false)
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                _showSelection ? const EdgeInsets.all(10) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: _selectionValue
                  ? Colors.white.withValues(alpha: 0.035)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _selectionValue
                    ? AppTheme.activeSoft.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _showSelection && _selectionHandler != null
                  ? () => _selectionHandler!.call(!_selectionValue)
                  : null,
              onLongPress:
                  _supportsHoverActions ? null : () => _openActionSheet(false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.message.isBookmarked
                              ? '${widget.assistantName} · 书签'
                              : widget.assistantName,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.assistantNameTextColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (showActions) _buildActionBar(isUser: false),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._buildAssistantSegments(context, parsed),
                  GameplayTurnFeedback(
                    message: widget.message,
                    isStreaming: widget.isStreaming,
                  ),
                  if (widget.message.bookmarkNote.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BookmarkNotePill(
                      note: widget.message.bookmarkNote.trim(),
                      color: AppTheme.assistantBubbleTextColor,
                    ),
                  ],
                  if (parsed.choices.isNotEmpty) ...<Widget>[
                    if (parsed.blocks.isNotEmpty) const SizedBox(height: 12),
                    _ChoicePanel(
                      choices: parsed.choices,
                      onChoicesSelected:
                          widget.isStreaming ? null : widget.onChoicesSelected,
                      onPreviewChoice:
                          widget.isStreaming ? null : widget.onPreviewChoice,
                      onResetChoices:
                          widget.isStreaming ? null : widget.onResetChoices,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _FooterRow(
                    timestamp: _footerTimestamp,
                    tokenEstimate: widget.message.tokenEstimate,
                    timestampColor: AppTheme.textWeak,
                    showSelection: _showSelection,
                    selectionValue: _selectionValue,
                    onToggleSelection: _selectionHandler,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAssistantBlocks(
    BuildContext context,
    List<MessageContentBlock> blocks,
  ) {
    final widgets = <Widget>[];
    for (var index = 0; index < blocks.length; index++) {
      widgets.add(_buildAssistantBlock(context, blocks[index]));
      if (index != blocks.length - 1) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        _assistantPlaceholder(context),
      );
    }

    return widgets;
  }

  List<Widget> _buildAssistantSegments(
    BuildContext context,
    ParsedMessageContent parsed,
  ) {
    if (parsed.groupChatMessages.isNotEmpty) {
      return <Widget>[
        _GroupChatMessageFlow(
          messages: parsed.groupChatMessages,
          npcProfiles: widget.npcProfiles,
          onMention: widget.isStreaming ? null : widget.onGroupChatMention,
          onReply: widget.isStreaming ? null : widget.onGroupChatReply,
        ),
        if (parsed.blocks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          ..._buildAssistantBlocks(context, parsed.blocks),
        ],
      ];
    }

    if (parsed.segments.isEmpty) {
      return _buildAssistantBlocks(context, parsed.blocks);
    }

    final widgets = <Widget>[];
    for (var index = 0; index < parsed.segments.length; index++) {
      widgets.addAll(_buildAssistantBlocks(context, parsed.segments[index]));
      if (index != parsed.segments.length - 1) {
        widgets.add(const SizedBox(height: 14));
      }
    }
    return widgets;
  }

  Widget _buildAssistantBlock(BuildContext context, MessageContentBlock block) {
    switch (block.type) {
      case MessageContentBlockType.markdown:
        final textColor = AppTheme.assistantBubbleTextColor;
        final effectiveTextColor =
            widget.customBubbleStyle?.textFor(false) ?? textColor;
        final codeBackground = AppTheme.isLightPaletteMode
            ? AppTheme.activePrimary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.08);
        final codeBlockBackground = AppTheme.isLightPaletteMode
            ? Colors.white.withValues(alpha: 0.70)
            : Colors.black.withValues(alpha: 0.16);
        return _assistantTextBubble(
          child: SelectionArea(
            child: MarkdownBody(
              data: block.content,
              selectable: false,
              softLineBreak: true,
              onTapLink: (_, __, ___) {},
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: effectiveTextColor,
                      height: 1.62,
                    ),
                h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: effectiveTextColor,
                    ),
                h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: effectiveTextColor,
                    ),
                h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: effectiveTextColor,
                    ),
                code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: effectiveTextColor,
                      backgroundColor: codeBackground,
                    ),
                codeblockPadding: const EdgeInsets.all(12),
                codeblockDecoration: BoxDecoration(
                  color: codeBlockBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                blockSpacing: 12,
              ),
            ),
          ),
        );
      case MessageContentBlockType.code:
        return _StandaloneCodeCard(
          title: block.language.trim().isEmpty ? 'code' : block.language,
          code: block.content,
        );
      case MessageContentBlockType.runnablePreview:
        if (widget.isStreaming) {
          return const _PreviewPlaceholder();
        }
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isCompactViewport = screenWidth < 700;
        final assistantFlowWidth = min(screenWidth * 0.92, 860.0);
        final previewRightGutter = isCompactViewport ? 20.0 : 0.0;
        final previewWidth = isCompactViewport
            ? max(220.0, assistantFlowWidth - previewRightGutter - 28)
            : double.infinity;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(right: previewRightGutter),
            child: SizedBox(
              width: previewWidth,
              child: _StandalonePreviewCard(
                document: block.content,
                height:
                    MessageContentParser.estimatePreviewHeight(block.content),
                onAction:
                    widget.isStreaming ? null : widget.onHtmlActionSelected,
                initiallyExpanded: !widget.deferHtmlPreview,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildActionBar({required bool isUser}) {
    final lightPalette = AppTheme.isLightPaletteMode;
    final iconColor = lightPalette ? AppTheme.textMain : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: lightPalette
            ? Colors.white.withValues(alpha: 0.74)
            : Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: lightPalette
              ? AppTheme.activeLine.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: isUser ? 0.2 : 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ActionIcon(
              tooltip: AppTheme.glitchText('复制'),
              icon: Icons.content_copy_outlined,
              onTap: widget.onCopy,
              color: iconColor,
            ),
            _ActionIcon(
              tooltip: AppTheme.glitchText('编辑'),
              icon: Icons.edit_outlined,
              onTap: widget.onEdit,
              color: iconColor,
            ),
            _ActionIcon(
              tooltip: AppTheme.glitchText('创建分支'),
              icon: Icons.call_split_rounded,
              onTap: widget.onCreateBranch,
              color: iconColor,
            ),
            _ActionIcon(
              tooltip: AppTheme.glitchText(
                widget.message.isBookmarked ? '编辑书签' : '加入书签',
              ),
              icon: widget.message.isBookmarked
                  ? Icons.bookmark_added_rounded
                  : Icons.bookmark_add_outlined,
              onTap: widget.onToggleBookmark,
              color: iconColor,
            ),
            if (!isUser)
              _ActionIcon(
                tooltip: AppTheme.glitchText('重新回复'),
                icon: Icons.refresh_rounded,
                onTap: widget.onRegenerate,
                color: iconColor,
              ),
            if (!isUser)
              _ActionIcon(
                tooltip: AppTheme.glitchText('美化成面板'),
                icon: Icons.auto_awesome_rounded,
                onTap: widget.onBeautifyPanel,
                color: iconColor,
              ),
            if (!isUser)
              _ActionIcon(
                tooltip: AppTheme.glitchText('格式说明'),
                icon: Icons.code_rounded,
                onTap: widget.onRepairFormat,
                color: iconColor,
              ),
            _ActionIcon(
              tooltip: AppTheme.glitchText('删除'),
              icon: Icons.delete_outline_rounded,
              onTap: widget.onDelete,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openActionSheet(bool isUser) async {
    if (_shouldHideActions || _showSelection) {
      return;
    }

    final actions = <_MessageAction>[
      _MessageAction(
        label: '复制消息',
        icon: Icons.content_copy_outlined,
        onTap: widget.onCopy,
      ),
      _MessageAction(
        label: '编辑内容',
        icon: Icons.edit_outlined,
        onTap: widget.onEdit,
      ),
      _MessageAction(
        label: '创建剧情分支',
        icon: Icons.call_split_rounded,
        onTap: widget.onCreateBranch,
      ),
      _MessageAction(
        label: widget.message.isBookmarked ? '编辑书签' : '加入书签',
        icon: widget.message.isBookmarked
            ? Icons.bookmark_added_rounded
            : Icons.bookmark_add_outlined,
        onTap: widget.onToggleBookmark,
      ),
      if (!isUser)
        _MessageAction(
          label: '重新回复',
          icon: Icons.refresh_rounded,
          onTap: widget.onRegenerate,
        ),
      if (!isUser)
        _MessageAction(
          label: '美化成互动面板',
          icon: Icons.auto_awesome_rounded,
          onTap: widget.onBeautifyPanel,
        ),
      if (!isUser)
        _MessageAction(
          label: '格式代码说明',
          icon: Icons.code_rounded,
          onTap: widget.onRepairFormat,
        ),
      _MessageAction(
        label: '多选',
        icon: Icons.done_all_rounded,
        onTap: widget.onSelectMultiple,
      ),
      _MessageAction(
        label: '删除消息',
        icon: Icons.delete_outline_rounded,
        onTap: widget.onDelete,
        destructive: true,
      ),
    ].where((action) => action.onTap != null).toList(growable: false);

    if (actions.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final lightPalette = AppTheme.isLightPaletteMode;
        final dialogTextColor = lightPalette ? AppTheme.textMain : Colors.white;
        final closeColor = lightPalette
            ? AppTheme.textMuted
            : Colors.white.withValues(alpha: 0.78);
        final dialogWidth =
            min(MediaQuery.sizeOf(dialogContext).width - 32, 420.0);
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.78,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppTheme.activePalette.panelStart.withValues(alpha: 0.98),
                      AppTheme.activePalette.panelEnd.withValues(alpha: 0.96),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppTheme.activeSoft.withValues(alpha: 0.30),
                  ),
                  boxShadow: AppTheme.neonGlow(alpha: 0.22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                AppTheme.glitchText(isUser ? '消息操作' : '回复操作'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: dialogTextColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: AppTheme.glitchText('关闭'),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: closeColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final action in actions) ...<Widget>[
                          ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            leading: Icon(
                              action.icon,
                              color: action.destructive
                                  ? AppTheme.activeSoft
                                  : dialogTextColor,
                            ),
                            title: Text(
                              AppTheme.glitchText(action.label),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: action.destructive
                                    ? AppTheme.activeSoft
                                    : dialogTextColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              action.onTap?.call();
                            },
                          ),
                          const SizedBox(height: 4),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String get _sanitizedAssistantContent {
    if (!widget.isStreaming) {
      return MessageContentParser.normalizeChoiceBlocks(widget.message.content);
    }

    if (!widget.streamingTextEnabled) {
      return '';
    }

    final text = MessageContentParser.visibleStreamingText(
      widget.message.content,
    );
    final start = text.indexOf('[CHOICES]');
    if (start == -1) {
      return text;
    }
    return text.substring(0, start).trimRight();
  }

  String get _footerTimestamp {
    if (widget.isStreaming) {
      return AppTheme.glitchText('生成中 ${widget.streamingElapsedSeconds}s');
    }
    return _formatTimestamp(widget.message.timestamp);
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

class _BookmarkNotePill extends StatelessWidget {
  const _BookmarkNotePill({
    required this.note,
    required this.color,
  });

  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.activeAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.activeAccent.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.bookmark_added_rounded,
            size: 16,
            color: color.withValues(alpha: 0.86),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppTheme.glitchText(note),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantTextBubble extends StatelessWidget {
  const _AssistantTextBubble({
    required this.child,
    required this.frameId,
    required this.stickerId,
    this.customStyle,
  });

  final Widget child;
  final String frameId;
  final String stickerId;
  final BubbleStyleSpec? customStyle;

  @override
  Widget build(BuildContext context) {
    final bubbleStyle = _CosmeticBubbleStyle.forFrame(
      frameId,
      isUser: false,
      selected: false,
      customStyle: customStyle,
    );
    final bubbleFill = AppTheme.defaultAssistantBubbleGradient;
    return Stack(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: bubbleStyle.gradient ?? bubbleFill,
            borderRadius: bubbleStyle.borderRadius,
            border: Border.all(
              color: bubbleStyle.borderColor,
              width: bubbleStyle.borderWidth,
            ),
            boxShadow: bubbleStyle.shadows,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: _BubbleFrameArt(
                    frameId: frameId,
                    borderRadius: bubbleStyle.borderRadius,
                    accentColor: bubbleStyle.borderColor,
                    isUser: false,
                  ),
                ),
                if (customStyle?.decorationText?.isNotEmpty == true)
                  Positioned(
                    right: 4,
                    top: 0,
                    child: IgnorePointer(
                      child: Text(
                        customStyle!.decorationText!,
                        style: TextStyle(
                          color: (customStyle!.accentColor ??
                                  bubbleStyle.borderColor)
                              .withValues(
                            alpha: customStyle!.decorationOpacity ?? 0.24,
                          ),
                          fontSize: customStyle!.decorationSize ?? 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
        _CosmeticStickerBadge(
          stickerId: stickerId,
          alignment: Alignment.topLeft,
        ),
      ],
    );
  }
}

class BubbleFramePreview extends StatelessWidget {
  const BubbleFramePreview({
    super.key,
    required this.frameId,
    this.customStyle,
    this.isUser = false,
    this.label,
  });

  final String frameId;
  final BubbleStyleSpec? customStyle;
  final bool isUser;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final style = _CosmeticBubbleStyle.forFrame(
      frameId,
      isUser: isUser,
      selected: false,
      customStyle: customStyle,
    );
    final textColor = customStyle?.textFor(isUser) ??
        (isUser ? Colors.white : AppTheme.assistantBubbleTextColor);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72, maxWidth: 330),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: style.gradient ??
              (isUser
                  ? LinearGradient(
                      colors: <Color>[
                        AppTheme.activePrimary.withValues(alpha: 0.76),
                        AppTheme.activeSecondary.withValues(alpha: 0.54),
                      ],
                    )
                  : AppTheme.defaultAssistantBubbleGradient),
          borderRadius: style.borderRadius,
          border: Border.all(
            color: style.borderColor,
            width: style.borderWidth,
          ),
          boxShadow: style.shadows,
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: _BubbleFrameArt(
                frameId: frameId,
                borderRadius: style.borderRadius,
                accentColor: style.borderColor,
                isUser: isUser,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
              child: Text(
                label ?? (isUser ? '我推开门，故事从这里继续。' : '灯光亮起，下一幕正等待你的选择。'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleFrameArt extends StatelessWidget {
  const _BubbleFrameArt({
    required this.frameId,
    required this.borderRadius,
    required this.accentColor,
    required this.isUser,
  });

  static const String _assetRoot = 'assets/bubble_skins';

  final String frameId;
  final BorderRadius borderRadius;
  final Color accentColor;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final usesPaper = switch (frameId) {
      'frame_sticky_note' ||
      'frame_moon_ticket' ||
      'frame_cream_note' ||
      'frame_film_strip' =>
        true,
      _ => false,
    };
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (usesPaper)
              Opacity(
                opacity: isUser ? 0.08 : 0.13,
                child: Image.asset(
                  '$_assetRoot/paper-grain.png',
                  fit: BoxFit.cover,
                  repeat: ImageRepeat.repeat,
                  color: accentColor,
                  colorBlendMode: BlendMode.softLight,
                  filterQuality: FilterQuality.low,
                ),
              ),
            CustomPaint(
              painter: _BubbleFramePainter(
                frameId: frameId,
                color: accentColor,
              ),
            ),
            if (frameId == 'frame_sticky_note')
              Align(
                alignment: const Alignment(0, -1.10),
                child: _TintedBubbleAsset(
                  path: '$_assetRoot/ornament-tape.png',
                  color: accentColor,
                  width: 92,
                  height: 42,
                  opacity: 0.40,
                ),
              ),
            if (frameId == 'frame_cat_paw')
              Align(
                alignment: const Alignment(0.96, 0.92),
                child: _TintedBubbleAsset(
                  path: '$_assetRoot/ornament-paw.png',
                  color: accentColor,
                  width: 58,
                  height: 58,
                  opacity: 0.18,
                ),
              ),
            if (frameId == 'frame_moon_ticket')
              Align(
                alignment: const Alignment(0.96, -0.82),
                child: _TintedBubbleAsset(
                  path: '$_assetRoot/ornament-moon.png',
                  color: accentColor,
                  width: 54,
                  height: 54,
                  opacity: 0.20,
                ),
              ),
            if (frameId == 'frame_whisper_rift')
              Align(
                alignment: const Alignment(1.05, 0),
                child: _TintedBubbleAsset(
                  path: '$_assetRoot/ornament-rift.png',
                  color: accentColor,
                  width: 88,
                  height: 132,
                  opacity: 0.18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TintedBubbleAsset extends StatelessWidget {
  const _TintedBubbleAsset({
    required this.path,
    required this.color,
    required this.width,
    required this.height,
    required this.opacity,
  });

  final String path;
  final Color color;
  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: Image.asset(
          path,
          width: width,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _BubbleFramePainter extends CustomPainter {
  const _BubbleFramePainter({required this.frameId, required this.color});

  final String frameId;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final paint = Paint()
      ..color = color.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    switch (frameId) {
      case 'frame_sticky_note':
        final fold = Path()
          ..moveTo(size.width - 30, size.height)
          ..lineTo(size.width, size.height - 30)
          ..lineTo(size.width, size.height);
        canvas.drawPath(
          fold,
          Paint()
            ..color = color.withValues(alpha: 0.20)
            ..style = PaintingStyle.fill,
        );
        canvas.drawLine(
          Offset(size.width - 30, size.height),
          Offset(size.width, size.height - 30),
          paint,
        );
        break;
      case 'frame_moon_ticket':
      case 'frame_roulette_ticket_stub':
        _drawDashedLine(
          canvas,
          Offset(size.width - 44, 10),
          Offset(size.width - 44, size.height - 10),
          paint,
          dash: 5,
          gap: 5,
        );
        canvas.drawCircle(Offset(0, size.height * 0.5), 8, paint);
        canvas.drawCircle(Offset(size.width, size.height * 0.5), 8, paint);
        break;
      case 'frame_film_strip':
        final holePaint = Paint()
          ..color = color.withValues(alpha: 0.40)
          ..style = PaintingStyle.fill;
        for (double x = 12; x < size.width - 8; x += 22) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 5, 10, 4),
              const Radius.circular(1),
            ),
            holePaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, size.height - 9, 10, 4),
              const Radius.circular(1),
            ),
            holePaint,
          );
        }
        break;
      case 'frame_pixel_quest':
        canvas.drawRect(
          Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
          paint..strokeWidth = 2,
        );
        final blockPaint = Paint()
          ..color = color.withValues(alpha: 0.55)
          ..style = PaintingStyle.fill;
        for (final offset in <Offset>[
          const Offset(4, 4),
          Offset(size.width - 10, 4),
          Offset(4, size.height - 10),
          Offset(size.width - 10, size.height - 10),
        ]) {
          canvas.drawRect(
              Rect.fromLTWH(offset.dx, offset.dy, 6, 6), blockPaint);
        }
        break;
      case 'frame_inbox_burst':
        final stripePaint = Paint()
          ..color = color.withValues(alpha: 0.34)
          ..strokeWidth = 2;
        for (double x = 8; x < size.width; x += 18) {
          canvas.drawLine(Offset(x, 2), Offset(x + 8, 8), stripePaint);
          canvas.drawLine(
            Offset(x, size.height - 2),
            Offset(x + 8, size.height - 8),
            stripePaint,
          );
        }
        break;
      case 'frame_cream_note':
        _drawDashedLine(
          canvas,
          const Offset(14, 9),
          Offset(size.width - 14, 9),
          paint,
          dash: 2,
          gap: 5,
        );
        break;
      case 'frame_bad_luck_charm':
      case 'frame_roulette_debt_stamp':
        final stampPaint = Paint()
          ..color = color.withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.save();
        canvas.translate(size.width - 36, 27);
        canvas.rotate(-0.24);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-24, -12, 48, 24),
            const Radius.circular(3),
          ),
          stampPaint,
        );
        canvas.drawLine(const Offset(-17, 0), const Offset(17, 0), stampPaint);
        canvas.restore();
        break;
      case 'frame_roulette_pity_ring':
        canvas.drawCircle(
          Offset(size.width - 24, size.height * 0.5),
          18,
          paint,
        );
        canvas.drawCircle(
          Offset(size.width - 24, size.height * 0.5),
          12,
          paint,
        );
        break;
      case 'frame_roulette_gold_scratch':
      case 'frame_roulette_static_luck':
        final scratchPaint = Paint()
          ..color = color.withValues(alpha: 0.28)
          ..strokeWidth = 1.4;
        for (double y = 12; y < size.height - 6; y += 13) {
          canvas.drawLine(
            Offset(size.width - 58, y),
            Offset(size.width - 16, y - 7),
            scratchPaint,
          );
        }
        break;
      default:
        break;
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) {
      return;
    }
    final direction = delta / distance;
    for (double offset = 0; offset < distance; offset += dash + gap) {
      canvas.drawLine(
        start + direction * offset,
        start + direction * min(offset + dash, distance),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubbleFramePainter oldDelegate) {
    return oldDelegate.frameId != frameId || oldDelegate.color != color;
  }
}

class _CosmeticBubbleStyle {
  const _CosmeticBubbleStyle({
    required this.borderRadius,
    required this.borderColor,
    required this.borderWidth,
    required this.shadows,
    this.gradient,
  });

  final BorderRadius borderRadius;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> shadows;
  final Gradient? gradient;

  factory _CosmeticBubbleStyle.forFrame(
    String frameId, {
    required bool isUser,
    required bool selected,
    BubbleStyleSpec? customStyle,
  }) {
    final baseShadow = <BoxShadow>[
      BoxShadow(
        color: AppTheme.activePrimary.withValues(alpha: selected ? 0.13 : 0.07),
        blurRadius: selected ? 18 : 12,
        offset: const Offset(0, 8),
      ),
    ];
    if (customStyle != null) {
      final background = customStyle.backgroundFor(isUser) ??
          AppTheme.panel.withValues(alpha: 0.88);
      final borderColor = customStyle.borderFor(isUser) ?? AppTheme.activeLine;
      final shadowColor =
          customStyle.shadowColor ?? borderColor.withValues(alpha: 0.16);
      return _CosmeticBubbleStyle(
        borderRadius: BorderRadius.circular(customStyle.borderRadius ?? 22),
        borderColor: selected ? AppTheme.activeSoft : borderColor,
        borderWidth: selected ? 2.4 : (customStyle.borderWidth ?? 2),
        shadows: <BoxShadow>[
          BoxShadow(
            color: shadowColor.withValues(alpha: selected ? 0.30 : 0.18),
            blurRadius: customStyle.shadowBlur ?? 18,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            background,
            Color.lerp(background, Colors.white, 0.18) ?? background,
          ],
        ),
      );
    }

    if (AppTheme.isBasicPaletteMode && !isUser) {
      return switch (frameId) {
        'frame_sticky_note' => _CosmeticBubbleStyle(
            borderRadius: BorderRadius.circular(18),
            borderColor: AppTheme.activeAccent.withValues(alpha: 0.78),
            borderWidth: 2.4,
            shadows: baseShadow,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.76),
                AppTheme.activeAccent.withValues(alpha: 0.12),
              ],
            ),
          ),
        'frame_cat_paw' => _CosmeticBubbleStyle(
            borderRadius: BorderRadius.circular(30),
            borderColor: AppTheme.activeSoft.withValues(alpha: 0.82),
            borderWidth: 2.6,
            shadows: baseShadow,
            gradient: AppTheme.defaultAssistantBubbleGradient,
          ),
        'frame_moon_ticket' => _CosmeticBubbleStyle(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(28),
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(12),
            ),
            borderColor: AppTheme.activeSecondary.withValues(alpha: 0.78),
            borderWidth: 2.2,
            shadows: baseShadow,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.76),
                AppTheme.activeSecondary.withValues(alpha: 0.12),
              ],
            ),
          ),
        'frame_whisper_rift' => _CosmeticBubbleStyle(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(34),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(34),
            ),
            borderColor: AppTheme.activePrimary.withValues(alpha: 0.84),
            borderWidth: 2.8,
            shadows: baseShadow,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.72),
                AppTheme.activePrimary.withValues(alpha: 0.13),
              ],
            ),
          ),
        'frame_inbox_burst' => _CosmeticBubbleStyle(
            borderRadius: BorderRadius.circular(16),
            borderColor: AppTheme.activeAccent.withValues(alpha: 0.86),
            borderWidth: 2.5,
            shadows: baseShadow,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                AppTheme.activeAccent.withValues(alpha: 0.13),
                Colors.white.withValues(alpha: 0.74),
              ],
            ),
          ),
        'frame_cream_note' => _CosmeticBubbleStyle(
            borderRadius: BorderRadius.circular(26),
            borderColor: const Color(0xFFD6A967).withValues(alpha: 0.70),
            borderWidth: 2.4,
            shadows: baseShadow,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFFFFF3DB).withValues(alpha: 0.64),
                Colors.white.withValues(alpha: 0.72),
              ],
            ),
          ),
        'frame_film_strip' => _CosmeticBubbleStyle(
            borderRadius: BorderRadius.circular(10),
            borderColor: const Color(0xFFC5A76C).withValues(alpha: 0.74),
            borderWidth: 3,
            shadows: baseShadow,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.72),
                const Color(0xFFD8C08E).withValues(alpha: 0.12),
              ],
            ),
          ),
        'frame_pixel_quest' => _CosmeticBubbleStyle(
            borderRadius: BorderRadius.circular(6),
            borderColor: AppTheme.activeSoft.withValues(alpha: 0.86),
            borderWidth: 3.2,
            shadows: baseShadow,
            gradient: AppTheme.defaultAssistantBubbleGradient,
          ),
        'frame_bad_luck_charm' => _CosmeticBubbleStyle(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(26),
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(6),
            ),
            borderColor: const Color(0xFFB85B5B).withValues(alpha: 0.70),
            borderWidth: 2.7,
            shadows: baseShadow,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.74),
                const Color(0xFFFF6B6B).withValues(alpha: 0.10),
              ],
            ),
          ),
        _ => _CosmeticBubbleStyle(
            borderRadius: BorderRadius.circular(22),
            borderColor: selected
                ? AppTheme.activeSoft.withValues(alpha: 0.48)
                : AppTheme.activeLine.withValues(alpha: 0.72),
            borderWidth: 1,
            shadows: baseShadow,
            gradient: AppTheme.defaultAssistantBubbleGradient,
          ),
      };
    }

    if (AppTheme.isFlowerMode ||
        AppTheme.isMechanicalMode ||
        AppTheme.isRainRadioMode ||
        AppTheme.isEldritchMode ||
        AppTheme.isTerminalMode ||
        AppTheme.isPastureMode ||
        AppTheme.isVinylMode) {
      final accent = AppTheme.isFlowerMode
          ? const Color(0xFFA67A7B)
          : AppTheme.isMechanicalMode
              ? const Color(0xFFD8AD62)
              : AppTheme.isRainRadioMode
                  ? const Color(0xFFD7EBF2)
                  : AppTheme.isEldritchMode
                      ? const Color(0xFF9D3832)
                      : AppTheme.isTerminalMode
                          ? const Color(0xFF00D5FF)
                          : AppTheme.isPastureMode
                              ? const Color(0xFF6FAFCD)
                              : const Color(0xFFE0B56F);
      final ink = AppTheme.isFlowerMode
          ? const Color(0xFF7B605E)
          : AppTheme.isMechanicalMode
              ? const Color(0xFFB77B35)
              : AppTheme.isRainRadioMode
                  ? const Color(0xFF9BBDCA)
                  : AppTheme.isEldritchMode
                      ? const Color(0xFFCE8F69)
                      : AppTheme.isTerminalMode
                          ? const Color(0xFFC4CCD6)
                          : AppTheme.isPastureMode
                              ? const Color(0xFF91C58E)
                              : const Color(0xFFFFD796);
      final radius = switch (frameId) {
        'frame_film_strip' => BorderRadius.circular(12),
        'frame_pixel_quest' => BorderRadius.circular(8),
        'frame_bad_luck_charm' => BorderRadius.circular(26),
        'frame_whisper_rift' => const BorderRadius.only(
            topLeft: Radius.circular(34),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(34),
          ),
        'frame_moon_ticket' => const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(28),
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(12),
          ),
        'frame_inbox_burst' => BorderRadius.circular(16),
        'frame_cat_paw' => BorderRadius.circular(30),
        'frame_cream_note' => BorderRadius.circular(26),
        'frame_sticky_note' => BorderRadius.circular(18),
        _ => BorderRadius.circular(22),
      };
      final frameBoost = frameId == 'frame_default' ? 0.0 : 0.24;
      final frameAccent = switch (frameId) {
        'frame_sticky_note' => AppTheme.activeAccent,
        'frame_cat_paw' => AppTheme.activeSoft,
        'frame_moon_ticket' => AppTheme.activeSecondary,
        'frame_whisper_rift' => AppTheme.activePrimary,
        'frame_inbox_burst' => AppTheme.activeAccent,
        'frame_cream_note' => const Color(0xFFD6A967),
        'frame_film_strip' => const Color(0xFFD8C08E),
        'frame_pixel_quest' => AppTheme.activeSoft,
        'frame_bad_luck_charm' => const Color(0xFFFF6B6B),
        _ => ink,
      };
      final assistantGradient = AppTheme.isFlowerMode
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFFFFFCF6).withValues(alpha: 0.94),
                const Color(0xFFF1E7DD).withValues(alpha: 0.88),
              ],
            )
          : AppTheme.isMechanicalMode
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFF2D2217).withValues(alpha: 0.92),
                    const Color(0xFF17110C).withValues(alpha: 0.86),
                  ],
                )
              : AppTheme.isEldritchMode
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        const Color(0xFF1B0607).withValues(alpha: 0.94),
                        const Color(0xFF050000).withValues(alpha: 0.86),
                        const Color(0xFF9D3832).withValues(alpha: 0.12),
                      ],
                    )
                  : AppTheme.isTerminalMode
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            const Color(0xFF1C1F24).withValues(alpha: 0.92),
                            const Color(0xFF050607).withValues(alpha: 0.78),
                            const Color(0xFF00D5FF).withValues(alpha: 0.10),
                          ],
                        )
                      : AppTheme.isPastureMode
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Colors.white.withValues(alpha: 0.90),
                                const Color(0xFFE8F8FF).withValues(alpha: 0.78),
                                const Color(0xFFF6EFC8).withValues(alpha: 0.45),
                              ],
                            )
                          : AppTheme.isVinylMode
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    const Color(0xFFF8E7C8)
                                        .withValues(alpha: 0.96),
                                    const Color(0xFFE6C68E)
                                        .withValues(alpha: 0.84),
                                    const Color(0xFF9B6038)
                                        .withValues(alpha: 0.18),
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    const Color(0xFF173245)
                                        .withValues(alpha: 0.82),
                                    const Color(0xFF0D1B27)
                                        .withValues(alpha: 0.76),
                                  ],
                                );
      final userGradient = AppTheme.isFlowerMode
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFFA67A7B).withValues(alpha: 0.82),
                const Color(0xFFC1ADA8).withValues(alpha: 0.78),
              ],
            )
          : AppTheme.isMechanicalMode
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFFB77B35).withValues(alpha: 0.84),
                    const Color(0xFF6F4329).withValues(alpha: 0.78),
                  ],
                )
              : AppTheme.isEldritchMode
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        const Color(0xFF9D3832).withValues(alpha: 0.52),
                        const Color(0xFFCE8F69).withValues(alpha: 0.22),
                        const Color(0xFF050000).withValues(alpha: 0.54),
                      ],
                    )
                  : AppTheme.isTerminalMode
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            const Color(0xFFC4CCD6).withValues(alpha: 0.24),
                            const Color(0xFF00D5FF).withValues(alpha: 0.16),
                            const Color(0xFF050607).withValues(alpha: 0.58),
                          ],
                        )
                      : AppTheme.isPastureMode
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                const Color(0xFF9CD2E8).withValues(alpha: 0.62),
                                const Color(0xFFF1D783).withValues(alpha: 0.54),
                              ],
                            )
                          : AppTheme.isVinylMode
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    const Color(0xFFE0B56F)
                                        .withValues(alpha: 0.74),
                                    const Color(0xFF9B6038)
                                        .withValues(alpha: 0.78),
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    const Color(0xFF9BBDCA)
                                        .withValues(alpha: 0.72),
                                    const Color(0xFF4E768B)
                                        .withValues(alpha: 0.76),
                                  ],
                                );
      return _CosmeticBubbleStyle(
        borderRadius: radius,
        borderColor: selected
            ? accent.withValues(alpha: 0.90)
            : frameAccent.withValues(alpha: 0.55 + frameBoost),
        borderWidth: frameId == 'frame_default'
            ? 1.2
            : frameId == 'frame_pixel_quest'
                ? 3.2
                : frameId == 'frame_film_strip'
                    ? 3.0
                    : 2.4,
        shadows: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: selected ? 0.16 : 0.07),
            blurRadius: selected ? 16 : 10,
            offset: const Offset(0, 6),
          ),
          if (frameId != 'frame_default')
            BoxShadow(
              color: frameAccent.withValues(alpha: 0.12),
              blurRadius: frameId == 'frame_pixel_quest' ? 0 : 18,
              offset: frameId == 'frame_pixel_quest'
                  ? const Offset(5, 5)
                  : Offset.zero,
            ),
        ],
        gradient: isUser ? userGradient : assistantGradient,
      );
    }

    return switch (frameId) {
      'frame_sticky_note' => _CosmeticBubbleStyle(
          borderRadius: BorderRadius.circular(18),
          borderColor: AppTheme.activeAccent.withValues(alpha: 0.88),
          borderWidth: 2.4,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: AppTheme.activeAccent.withValues(alpha: 0.08),
              blurRadius: 18,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppTheme.activeAccent.withValues(alpha: isUser ? 0.30 : 0.16),
              AppTheme.activePalette.panelEnd.withValues(alpha: 0.88),
            ],
          ),
        ),
      'frame_cat_paw' => _CosmeticBubbleStyle(
          borderRadius: BorderRadius.circular(30),
          borderColor: AppTheme.activeSoft.withValues(alpha: 0.92),
          borderWidth: 2.6,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: AppTheme.activeSoft.withValues(alpha: 0.10),
              blurRadius: 24,
            ),
          ],
        ),
      'frame_moon_ticket' => _CosmeticBubbleStyle(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(28),
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(12),
          ),
          borderColor: AppTheme.activeSecondary.withValues(alpha: 0.86),
          borderWidth: 2.2,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: AppTheme.activeSecondary.withValues(alpha: 0.13),
              blurRadius: 22,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppTheme.activePalette.panelStart.withValues(alpha: 0.94),
              AppTheme.activeSecondary.withValues(alpha: isUser ? 0.26 : 0.12),
            ],
          ),
        ),
      'frame_whisper_rift' => _CosmeticBubbleStyle(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(34),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(34),
          ),
          borderColor: AppTheme.activePrimary.withValues(alpha: 0.95),
          borderWidth: 2.8,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: AppTheme.activePrimary.withValues(alpha: 0.22),
              blurRadius: 28,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppTheme.activePalette.panelStart.withValues(alpha: 0.96),
              AppTheme.activePrimary.withValues(alpha: isUser ? 0.22 : 0.12),
              Colors.black.withValues(alpha: 0.12),
            ],
          ),
        ),
      'frame_inbox_burst' => _CosmeticBubbleStyle(
          borderRadius: BorderRadius.circular(16),
          borderColor: AppTheme.activeAccent.withValues(alpha: 0.96),
          borderWidth: 2.5,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: AppTheme.activeAccent.withValues(alpha: 0.18),
              blurRadius: 26,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              AppTheme.activeAccent.withValues(alpha: isUser ? 0.24 : 0.14),
              AppTheme.activePalette.panelEnd.withValues(alpha: 0.94),
            ],
          ),
        ),
      'frame_cream_note' => _CosmeticBubbleStyle(
          borderRadius: BorderRadius.circular(26),
          borderColor: const Color(0xFFFFD8A8).withValues(alpha: 0.94),
          borderWidth: 2.4,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: const Color(0xFFFFD8A8).withValues(alpha: 0.16),
              blurRadius: 22,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFFFFE9C9).withValues(alpha: isUser ? 0.26 : 0.15),
              AppTheme.activePalette.panelEnd.withValues(alpha: 0.92),
            ],
          ),
        ),
      'frame_film_strip' => _CosmeticBubbleStyle(
          borderRadius: BorderRadius.circular(10),
          borderColor: const Color(0xFFD8C08E).withValues(alpha: 0.9),
          borderWidth: 3,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.16),
              AppTheme.activePalette.panelStart.withValues(alpha: 0.94),
              const Color(0xFFD8C08E).withValues(alpha: isUser ? 0.18 : 0.08),
            ],
          ),
        ),
      'frame_pixel_quest' => _CosmeticBubbleStyle(
          borderRadius: BorderRadius.circular(6),
          borderColor: AppTheme.activeSoft.withValues(alpha: 0.98),
          borderWidth: 3.2,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: AppTheme.activeSoft.withValues(alpha: 0.18),
              blurRadius: 0,
              offset: const Offset(5, 5),
            ),
          ],
        ),
      'frame_bad_luck_charm' => _CosmeticBubbleStyle(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(26),
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(6),
          ),
          borderColor: const Color(0xFFFF6B6B).withValues(alpha: 0.9),
          borderWidth: 2.7,
          shadows: <BoxShadow>[
            ...baseShadow,
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.18),
              blurRadius: 26,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFFFF6B6B).withValues(alpha: isUser ? 0.22 : 0.11),
              AppTheme.activePalette.panelEnd.withValues(alpha: 0.94),
            ],
          ),
        ),
      _ => _CosmeticBubbleStyle(
          borderRadius: BorderRadius.circular(22),
          borderColor: selected
              ? AppTheme.activeSoft.withValues(alpha: 0.48)
              : AppTheme.activeLine.withValues(alpha: isUser ? 0.35 : 0.85),
          borderWidth: 1,
          shadows: baseShadow,
        ),
    };
  }
}

class _CosmeticStickerBadge extends StatelessWidget {
  const _CosmeticStickerBadge({
    required this.stickerId,
    required this.alignment,
  });

  final String stickerId;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final glyph = switch (stickerId) {
      'sticker_duck' => '鸭',
      'sticker_crown' => '冠',
      'sticker_ghost' => '幽',
      _ => '',
    };
    if (glyph.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Transform.translate(
            offset:
                alignment.x > 0 ? const Offset(8, -8) : const Offset(-8, -8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.actionGradient,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.34),
                ),
                boxShadow: AppTheme.neonGlow(alpha: 0.10),
              ),
              alignment: Alignment.center,
              child: Text(
                glyph,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandaloneCodeCard extends StatelessWidget {
  const _StandaloneCodeCard({
    required this.title,
    required this.code,
  });

  final String title;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              code,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandalonePreviewCard extends StatefulWidget {
  const _StandalonePreviewCard({
    required this.document,
    required this.height,
    this.onAction,
    this.initiallyExpanded = true,
  });

  final String document;
  final double height;
  final ValueChanged<String>? onAction;
  final bool initiallyExpanded;

  @override
  State<_StandalonePreviewCard> createState() => _StandalonePreviewCardState();
}

class _StandalonePreviewCardState extends State<_StandalonePreviewCard> {
  int _previewVersion = 0;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant _StandalonePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _previewVersion = 0;
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panel.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          _PreviewToolbar(
            onFullscreen: _openFullscreen,
            onToggle: () => setState(() => _expanded = !_expanded),
            expanded: _expanded,
            onReset:
                _expanded ? () => setState(() => _previewVersion += 1) : null,
            onCopy: _copySource,
            onExport: _exportSource,
          ),
          if (_expanded) ...<Widget>[
            const SizedBox(height: 8),
            RunnableCodePreview(
              key: ValueKey<int>(_previewVersion),
              document: widget.document,
              height: widget.height,
              onAction: widget.onAction,
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            _DeferredPreviewHint(
              documentLength: widget.document.length,
              onExpand: () => setState(() => _expanded = true),
              onFullscreen: _openFullscreen,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copySource() async {
    await Clipboard.setData(ClipboardData(text: widget.document));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HTML 源码已复制')),
    );
  }

  Future<void> _exportSource() async {
    final ok = await downloadTextFile(
      filename: 'interactive_panel.html',
      content: widget.document,
      mimeType: 'text/html;charset=utf-8',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'HTML 面板已导出' : '当前平台暂不支持导出')),
    );
  }

  Future<void> _openFullscreen() async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AppTheme.panel,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '互动剧情面板',
                        style: Theme.of(context).textTheme.titleMedium,
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
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: RunnableCodePreview(
                        document: widget.document,
                        height: MediaQuery.sizeOf(context).height * 0.82,
                        onAction: widget.onAction,
                      ),
                    ),
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

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.onFullscreen,
    required this.onToggle,
    required this.expanded,
    required this.onReset,
    required this.onCopy,
    required this.onExport,
  });

  final VoidCallback onFullscreen;
  final VoidCallback onToggle;
  final bool expanded;
  final VoidCallback? onReset;
  final VoidCallback onCopy;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '互动剧情面板',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.activePrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        _PreviewToolButton(
          tooltip: expanded ? '折叠预览' : '展开预览',
          icon:
              expanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
          onTap: onToggle,
        ),
        _PreviewToolButton(
          tooltip: '全屏',
          icon: Icons.open_in_full_rounded,
          onTap: onFullscreen,
        ),
        _PreviewToolButton(
          tooltip: '重置交互',
          icon: Icons.restart_alt_rounded,
          onTap: onReset,
        ),
        _PreviewToolButton(
          tooltip: '复制源码',
          icon: Icons.content_copy_outlined,
          onTap: onCopy,
        ),
        _PreviewToolButton(
          tooltip: '导出 HTML',
          icon: Icons.download_rounded,
          onTap: onExport,
        ),
      ],
    );
  }
}

class _PreviewToolButton extends StatelessWidget {
  const _PreviewToolButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _GroupChatMessageFlow extends StatelessWidget {
  const _GroupChatMessageFlow({
    required this.messages,
    required this.npcProfiles,
    this.onMention,
    this.onReply,
  });

  final List<GroupChatMessage> messages;
  final List<NpcProfile> npcProfiles;
  final ValueChanged<GroupChatMessage>? onMention;
  final ValueChanged<GroupChatMessage>? onReply;

  @override
  Widget build(BuildContext context) {
    final messagesById = <String, GroupChatMessage>{
      for (final message in messages)
        if (message.id.trim().isNotEmpty) message.id.trim(): message,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < messages.length; index++) ...<Widget>[
          _GroupChatBubble(
            message: messages[index],
            npcProfile: _resolveNpcProfile(messages[index]),
            replyTarget: messagesById[messages[index].replyTo.trim()],
            onMention: onMention,
            onReply: onReply,
          ),
          if (index != messages.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }

  NpcProfile? _resolveNpcProfile(GroupChatMessage message) {
    final speakerId = message.speakerId.trim();
    if (speakerId.isNotEmpty && speakerId != 'narrator') {
      for (final profile in npcProfiles) {
        if (profile.id.trim() == speakerId) {
          return profile;
        }
      }
    }

    final speakerName = _normalizeSpeakerName(message.speaker);
    if (speakerName.isEmpty) {
      return null;
    }
    for (final profile in npcProfiles) {
      if (_normalizeSpeakerName(profile.name) == speakerName) {
        return profile;
      }
    }
    return null;
  }

  String _normalizeSpeakerName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

class _GroupChatBubble extends StatelessWidget {
  const _GroupChatBubble({
    required this.message,
    required this.npcProfile,
    required this.replyTarget,
    this.onMention,
    this.onReply,
  });

  final GroupChatMessage message;
  final NpcProfile? npcProfile;
  final GroupChatMessage? replyTarget;
  final ValueChanged<GroupChatMessage>? onMention;
  final ValueChanged<GroupChatMessage>? onReply;

  static const List<Color> _speakerPalette = <Color>[
    Color(0xFF287D8E),
    Color(0xFF9A4E68),
    Color(0xFF8A6A19),
    Color(0xFF4F68A5),
    Color(0xFF3E7E5B),
    Color(0xFF9A583B),
    Color(0xFF7A5798),
  ];

  @override
  Widget build(BuildContext context) {
    final narration = message.isNarration;
    final theme = Theme.of(context);
    final vinyl = AppTheme.isVinylMode;
    final speakerColor = narration
        ? AppTheme.activePrimary
        : _speakerColor(message.speakerId.trim().isNotEmpty
            ? message.speakerId
            : message.speaker);
    final color = vinyl
        ? (narration ? const Color(0xFFF0C06B) : const Color(0xFFFFD58C))
        : speakerColor;
    final fill = vinyl
        ? (narration
            ? const Color(0xFF2A160C).withValues(alpha: 0.88)
            : const Color(0xFF392012).withValues(alpha: 0.92))
        : narration
            ? AppTheme.activePrimary.withValues(alpha: 0.075)
            : speakerColor.withValues(alpha: 0.085);
    final border = vinyl
        ? (narration
            ? const Color(0xFFE0A950).withValues(alpha: 0.82)
            : const Color(0xFFFFC978).withValues(alpha: 0.88))
        : narration
            ? AppTheme.activeLine.withValues(alpha: 0.75)
            : speakerColor.withValues(alpha: 0.42);
    final textColor =
        vinyl ? const Color(0xFFFFE7BE) : AppTheme.assistantBubbleTextColor;
    final radius = AppTheme.isTerminalMode
        ? 8.0
        : AppTheme.isEldritchMode
            ? 10.0
            : 18.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildAvatar(narration: narration, color: color),
        const SizedBox(width: 9),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(MediaQuery.sizeOf(context).width * 0.76, 680.0),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: border),
                boxShadow: vinyl
                    ? <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 8, 8, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            message.speaker,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!narration && onMention != null)
                          _GroupChatActionButton(
                            icon: Icons.alternate_email_rounded,
                            tooltip: '@${message.speaker}',
                            onPressed: () => onMention!(message),
                          ),
                        if (onReply != null)
                          _GroupChatActionButton(
                            icon: Icons.reply_rounded,
                            tooltip: '回复这条消息',
                            onPressed: () => onReply!(message),
                          ),
                      ],
                    ),
                    if (replyTarget != null) ...<Widget>[
                      const SizedBox(height: 5),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(
                            left: BorderSide(color: color, width: 2),
                          ),
                        ),
                        child: Text(
                          '${replyTarget!.speaker}：${_clipReply(replyTarget!.content)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withValues(alpha: 0.78),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    SelectionArea(
                      child: Text(
                        message.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          height: narration ? 1.62 : 1.5,
                          fontWeight:
                              narration ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar({required bool narration, required Color color}) {
    if (!narration) {
      return CharacterAvatar(
        name: message.speaker,
        avatarDataUri: npcProfile?.avatarDataUri ?? '',
        size: 38,
      );
    }
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Icon(Icons.auto_stories_outlined, size: 19, color: color),
    );
  }

  Color _speakerColor(String key) {
    var hash = 0;
    for (final codeUnit in key.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return _speakerPalette[hash % _speakerPalette.length];
  }

  String _clipReply(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return compact.length <= 64 ? compact : '${compact.substring(0, 64)}...';
  }
}

class _GroupChatActionButton extends StatelessWidget {
  const _GroupChatActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 30,
        height: 30,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
        ),
      ),
    );
  }
}

class _DeferredPreviewHint extends StatelessWidget {
  const _DeferredPreviewHint({
    required this.documentLength,
    required this.onExpand,
    required this.onFullscreen,
  });

  final int documentLength;
  final VoidCallback onExpand;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.activeLine.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTheme.glitchText('HTML 美化框已折叠'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppTheme.glitchText(
              '这段面板约 ${_formatPreviewSize(documentLength)}，展开时才会渲染，长聊天会更顺。',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: onExpand,
                icon: const Icon(Icons.unfold_more_rounded, size: 18),
                label: Text(AppTheme.glitchText('展开')),
              ),
              OutlinedButton.icon(
                onPressed: onFullscreen,
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: Text(AppTheme.glitchText('全屏查看')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatPreviewSize(int chars) {
    if (chars >= 1000000) {
      return '${(chars / 1000000).toStringAsFixed(1)}M 字符';
    }
    if (chars >= 1000) {
      return '${(chars / 1000).toStringAsFixed(1)}K 字符';
    }
    return '$chars 字符';
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '预览会在回复生成完成后自动显示。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _ChoicePanel extends StatefulWidget {
  const _ChoicePanel({
    required this.choices,
    required this.onChoicesSelected,
    required this.onPreviewChoice,
    required this.onResetChoices,
  });

  final List<MessageChoice> choices;
  final ValueChanged<List<String>>? onChoicesSelected;
  final Future<void> Function(MessageChoice choice)? onPreviewChoice;
  final VoidCallback? onResetChoices;

  @override
  State<_ChoicePanel> createState() => _ChoicePanelState();
}

class _ChoicePanelState extends State<_ChoicePanel> {
  final Set<String> _selectedIndexes = <String>{};
  bool _expanded = true;

  bool get _enabled => widget.onChoicesSelected != null;

  @override
  Widget build(BuildContext context) {
    final lightPalette = AppTheme.isBasicPaletteMode || AppTheme.isFlowerMode;
    final themedDark = AppTheme.isEldritchMode || AppTheme.isTerminalMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: lightPalette
            ? AppTheme.activePrimary.withValues(alpha: 0.055)
            : themedDark
                ? AppTheme.activePalette.panelEnd.withValues(alpha: 0.78)
                : AppTheme.activePrimary.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(
          AppTheme.isTerminalMode
              ? 6
              : AppTheme.isEldritchMode
                  ? 10
                  : 20,
        ),
        border: Border.all(
          color: AppTheme.activeLine.withValues(
            alpha: lightPalette
                ? 0.9
                : themedDark
                    ? 0.72
                    : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '下一步选项',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textMain,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (_selectedIndexes.isNotEmpty)
                TextButton.icon(
                  onPressed: _enabled ? _reset : null,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('重置'),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(_expanded ? '收起' : '展开'),
              ),
            ],
          ),
          if (_expanded) ...<Widget>[
            const SizedBox(height: 12),
            for (var index = 0;
                index < widget.choices.length;
                index++) ...<Widget>[
              _ChoiceButton(
                choice: widget.choices[index],
                selected:
                    _selectedIndexes.contains(widget.choices[index].index),
                onTap: !_enabled ? null : () => _toggle(widget.choices[index]),
                onPreview: widget.onPreviewChoice == null
                    ? null
                    : () => widget.onPreviewChoice!(widget.choices[index]),
              ),
              if (index != widget.choices.length - 1) const SizedBox(height: 9),
            ],
          ],
        ],
      ),
    );
  }

  void _toggle(MessageChoice choice) {
    setState(() {
      if (_selectedIndexes.contains(choice.index)) {
        _selectedIndexes.remove(choice.index);
      } else {
        _selectedIndexes.add(choice.index);
      }
    });
    widget.onChoicesSelected?.call(_selectedLabels());
  }

  void _reset() {
    setState(() => _selectedIndexes.clear());
    widget.onResetChoices?.call();
  }

  List<String> _selectedLabels() {
    return widget.choices
        .where((choice) => _selectedIndexes.contains(choice.index))
        .map((choice) => choice.label)
        .toList(growable: false);
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.choice,
    required this.selected,
    required this.onTap,
    required this.onPreview,
  });

  final MessageChoice choice;
  final bool selected;
  final VoidCallback? onTap;
  final Future<void> Function()? onPreview;

  @override
  Widget build(BuildContext context) {
    final lightPalette = AppTheme.isBasicPaletteMode || AppTheme.isFlowerMode;
    final themedDark = AppTheme.isEldritchMode || AppTheme.isTerminalMode;
    final titleColor = selected ? AppTheme.activePrimary : AppTheme.textMain;
    final bodyColor = selected ? AppTheme.textMain : AppTheme.textMuted;
    final iconColor = selected ? AppTheme.activePrimary : AppTheme.textWeak;
    final radius = AppTheme.isTerminalMode
        ? 6.0
        : AppTheme.isEldritchMode
            ? 10.0
            : 16.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                selected
                    ? AppTheme.activePrimary.withValues(
                        alpha: lightPalette
                            ? 0.16
                            : themedDark
                                ? 0.24
                                : 0.20,
                      )
                    : AppTheme.activePrimary.withValues(
                        alpha: lightPalette
                            ? 0.07
                            : themedDark
                                ? 0.10
                                : 0.08,
                      ),
                selected
                    ? AppTheme.activeSecondary.withValues(
                        alpha: lightPalette
                            ? 0.12
                            : themedDark
                                ? 0.18
                                : 0.16,
                      )
                    : AppTheme.activeSecondary.withValues(
                        alpha: lightPalette
                            ? 0.05
                            : themedDark
                                ? 0.08
                                : 0.06,
                      ),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? AppTheme.activePrimary.withValues(alpha: 0.56)
                  : AppTheme.activeLine
                      .withValues(alpha: lightPalette ? 0.85 : 0.72),
            ),
            boxShadow: selected ? AppTheme.neonGlow(alpha: 0.05) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.activePrimary.withValues(
                            alpha: lightPalette ? 0.18 : 0.24,
                          )
                        : AppTheme.activePrimary.withValues(
                            alpha: lightPalette ? 0.08 : 0.10,
                          ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    choice.index,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    choice.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: bodyColor,
                          fontWeight:
                              lightPalette ? FontWeight.w700 : FontWeight.w500,
                          height: 1.5,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: AppTheme.glitchText('预演这个选项'),
                  onPressed: onPreview == null
                      ? null
                      : () async {
                          await onPreview!();
                        },
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.route_outlined,
                    color: iconColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: iconColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({
    required this.timestamp,
    required this.tokenEstimate,
    required this.timestampColor,
    required this.showSelection,
    required this.selectionValue,
    required this.onToggleSelection,
  });

  final String timestamp;
  final int? tokenEstimate;
  final Color timestampColor;
  final bool showSelection;
  final bool selectionValue;
  final ValueChanged<bool>? onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            tokenEstimate == null
                ? timestamp
                : '$timestamp · ${_formatTokenEstimate(tokenEstimate!)} tokens',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: timestampColor,
                ),
          ),
        ),
        if (showSelection)
          Checkbox(
            value: selectionValue,
            onChanged: (value) {
              if (value == null || onToggleSelection == null) {
                return;
              }
              onToggleSelection!(value);
            },
          ),
      ],
    );
  }

  String _formatTokenEstimate(int value) {
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    }
    return value.toString();
  }
}

class _MessageAction {
  const _MessageAction({
    required this.label,
    required this.icon,
    this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
