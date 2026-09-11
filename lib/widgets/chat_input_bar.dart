import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tutorial_guide.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.isSending,
    required this.canPause,
    required this.hasPendingMessages,
    required this.onSend,
    required this.onLaunch,
    this.draftText,
    this.draftVersion = 0,
    this.leading,
    this.quickActions = const <ChatQuickAction>[],
    this.onQuickActionSelected,
    this.edgeToEdge = false,
    this.tutorialTargetsEnabled = true,
    this.enabled = true,
    this.disabledHint,
  });

  final bool isSending;
  final bool canPause;
  final bool hasPendingMessages;
  final Future<void> Function(String value) onSend;
  final Future<void> Function() onLaunch;
  final String? draftText;
  final int draftVersion;
  final Widget? leading;
  final List<ChatQuickAction> quickActions;
  final ValueChanged<String>? onQuickActionSelected;
  final bool edgeToEdge;
  final bool enabled;
  final String? disabledHint;

  /// 教程定位使用全局 GlobalKey。主聊天与 NPC 私聊等页面可能同时
  /// 存在于导航栈中，若都挂同一组 key 会触发重复 GlobalKey，
  /// 导致后挂载的输入栏被截断。非教程目标页面应关闭定位和动作上报。
  final bool tutorialTargetsEnabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class ChatQuickAction {
  const ChatQuickAction({
    required this.label,
    required this.text,
    required this.icon,
  });

  final String label;
  final String text;
  final IconData icon;
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleTextChanged);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draftVersion != oldWidget.draftVersion &&
        widget.draftText != null) {
      final nextText = widget.draftText!.trim();
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled &&
        _controller.text.trim().isNotEmpty &&
        !widget.isSending;
    final canLaunch = widget.enabled &&
        (widget.canPause || (widget.hasPendingMessages && !widget.isSending));
    final theme = Theme.of(context);
    final uiScale = AppTheme.uiScaleOf(context);
    final iconOnlySend = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final lightPalette = AppTheme.isLightPaletteMode;
    final terminal = AppTheme.isTerminalMode;
    final eldritch = AppTheme.isEldritchMode;
    final actionForeground =
        lightPalette ? const Color(0xFF2F2C33) : Colors.white;
    final radius = terminal
        ? 6.0
        : eldritch
            ? 10.0
            : 18.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final edgeToEdge = widget.edgeToEdge;
        final panelRadius = edgeToEdge ? 0.0 : 22.0;
        final panelDecoration = edgeToEdge
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppTheme.activePalette.panelHighlightStart,
                    AppTheme.activePalette.panelHighlightEnd,
                  ],
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.activeLine),
                  bottom: BorderSide(color: AppTheme.activeLine),
                ),
                boxShadow: AppTheme.neonGlow(alpha: 0.035),
              )
            : AppTheme.glassPanel(highlighted: true, radius: panelRadius);

        return SafeArea(
          top: false,
          minimum: EdgeInsets.only(bottom: edgeToEdge ? 0 : 2 * uiScale),
          child: DecoratedBox(
            decoration: panelDecoration,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                (edgeToEdge ? 12 : (compact ? 10 : 16)) * uiScale,
                (edgeToEdge ? 8 : 9) * uiScale,
                (edgeToEdge ? 12 : (compact ? 7 : 10)) * uiScale,
                (edgeToEdge ? 10 : 9) * uiScale,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.quickActions.isNotEmpty) ...<Widget>[
                    _QuickActionStrip(
                      actions: widget.quickActions,
                      onSelected: widget.onQuickActionSelected,
                    ),
                    SizedBox(height: 9 * uiScale),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.leading != null) ...<Widget>[
                        widget.leading!,
                        SizedBox(width: (compact ? 7 : 10) * uiScale),
                      ],
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: lightPalette
                                ? Colors.white.withValues(alpha: 0.64)
                                : terminal || eldritch
                                    ? AppTheme.activePalette.panelEnd
                                        .withValues(alpha: 0.68)
                                    : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(color: AppTheme.activeLine),
                          ),
                          child: TextField(
                            key: widget.tutorialTargetsEnabled
                                ? TutorialTargetRegistry.keyOf(
                                    TutorialTargetId.chatInput,
                                  )
                                : null,
                            controller: _controller,
                            focusNode: _focusNode,
                            onTap: widget.tutorialTargetsEnabled
                                ? () => TutorialTargetRegistry.report(
                                      TutorialTargetId.chatInput,
                                    )
                                : null,
                            enabled: widget.enabled && !widget.isSending,
                            minLines: 1,
                            maxLines: compact ? 4 : 6,
                            textInputAction: TextInputAction.newline,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: AppTheme.glitchText(
                                !widget.enabled &&
                                        widget.disabledHint
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                    ? widget.disabledHint!.trim()
                                    : compact
                                        ? '输入消息...'
                                        : '输入你的消息，开始和角色对话...',
                              ),
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: (compact ? 11 : 14) * uiScale,
                                vertical: 13 * uiScale,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: (compact ? 7 : 12) * uiScale),
                      compact || iconOnlySend
                          ? FilledButton(
                              key: widget.tutorialTargetsEnabled
                                  ? TutorialTargetRegistry.keyOf(
                                      TutorialTargetId.chatSend,
                                    )
                                  : null,
                              onPressed: canSend ? _submit : null,
                              style: AppTheme.skinFilledIconButtonStyle(
                                base: FilledButton.styleFrom(
                                  backgroundColor:
                                      AppTheme.usesRasterIconButtonArtwork
                                          ? Colors.transparent
                                          : AppTheme.activeAccent,
                                  foregroundColor: actionForeground,
                                  minimumSize: Size(44 * uiScale, 46 * uiScale),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(radius),
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                semanticLabel: '发送消息',
                              ),
                            )
                          : FilledButton.icon(
                              key: widget.tutorialTargetsEnabled
                                  ? TutorialTargetRegistry.keyOf(
                                      TutorialTargetId.chatSend,
                                    )
                                  : null,
                              onPressed: canSend ? _submit : null,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    AppTheme.usesRasterWideButtonArtwork
                                        ? Colors.transparent
                                        : AppTheme.activeAccent,
                                foregroundColor: actionForeground,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 18 * uiScale,
                                  vertical: 18 * uiScale,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.usesRasterWideButtonArtwork
                                        ? 8
                                        : radius,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.send_rounded),
                              label: Text(AppTheme.glitchText('发送')),
                            ),
                      SizedBox(width: 8 * uiScale),
                      Tooltip(
                        message: AppTheme.glitchText(
                          !widget.enabled &&
                                  widget.disabledHint?.trim().isNotEmpty == true
                              ? widget.disabledHint!.trim()
                              : widget.canPause
                                  ? '暂停当前回复'
                                  : '把已经发送的用户消息一起提交给角色回复',
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.actionGradient,
                            borderRadius: BorderRadius.circular(radius),
                            boxShadow: AppTheme.neonGlow(alpha: 0.08),
                          ),
                          child: IconButton(
                            key: widget.tutorialTargetsEnabled
                                ? TutorialTargetRegistry.keyOf(
                                    TutorialTargetId.chatLaunch,
                                  )
                                : null,
                            onPressed: canLaunch ? _launch : null,
                            icon: widget.canPause
                                ? Icon(
                                    Icons.pause_rounded,
                                    color: actionForeground,
                                    semanticLabel: '暂停当前回复',
                                  )
                                : widget.isSending
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: actionForeground,
                                        ),
                                      )
                                    : Icon(
                                        Icons.near_me_rounded,
                                        color: actionForeground,
                                        semanticLabel: '提交并生成回复',
                                      ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (!widget.enabled || text.isEmpty || widget.isSending) {
      return;
    }

    if (widget.tutorialTargetsEnabled) {
      TutorialTargetRegistry.report(TutorialTargetId.chatSend);
    }
    _controller.clear();
    await widget.onSend(text);
  }

  Future<void> _launch() async {
    if (!widget.enabled) {
      return;
    }
    if (widget.tutorialTargetsEnabled) {
      TutorialTargetRegistry.report(TutorialTargetId.chatLaunch);
    }
    await widget.onLaunch();
  }

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}

class _QuickActionStrip extends StatelessWidget {
  const _QuickActionStrip({
    required this.actions,
    required this.onSelected,
  });

  final List<ChatQuickAction> actions;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final radius = AppTheme.isTerminalMode
        ? 6.0
        : AppTheme.isEldritchMode
            ? 10.0
            : 999.0;

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (var index = 0; index < actions.length; index++) ...<Widget>[
              _QuickActionChip(
                action: actions[index],
                radius: radius,
                onSelected: onSelected,
              ),
              if (index != actions.length - 1) const SizedBox(width: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.action,
    required this.radius,
    required this.onSelected,
  });

  final ChatQuickAction action;
  final double radius;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final lightPalette = AppTheme.isLightPaletteMode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onSelected == null ? null : () => onSelected!(action.text),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: lightPalette
                ? AppTheme.activePrimary.withValues(alpha: 0.08)
                : AppTheme.activePalette.panelEnd.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppTheme.activeLine.withValues(alpha: 0.76),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(action.icon, size: 15, color: AppTheme.activeSoft),
              const SizedBox(width: 5),
              Text(
                action.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
