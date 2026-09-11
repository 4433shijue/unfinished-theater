import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../theme/app_theme.dart';

class TheaterPopup {
  const TheaterPopup._();

  /// Shows a centered streaming theater popup for shop item effects.
  /// Returns null on success, or an error string.
  static Future<String?> show({
    required BuildContext context,
    required String toolId,
    String userRequest = '',
  }) async {
    final controller = context.read<AppStateController>();
    final character = controller.currentCharacter;
    final settings = controller.settings;

    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (controller.isSending) {
      return '当前还有回复正在生成，请稍等。';
    }

    final title = controller.theaterTitle(toolId);
    if (title == null) {
      return '没有找到这个小剧场道具。';
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;

    final buffer = StringBuffer();
    var errorMessage = '';
    var disposed = false;

    Future<void> generate() async {
      try {
        await controller.generateTheaterStream(
          toolId: toolId,
          userRequest: userRequest,
          onChunk: (chunk) {
            if (disposed) {
              return;
            }
            buffer.write(chunk);
            entry.markNeedsBuild();
          },
        );
      } catch (e) {
        errorMessage = e.toString();
        if (!disposed) {
          entry.markNeedsBuild();
        }
      }
    }

    entry = OverlayEntry(
      builder: (context) => _TheaterOverlay(
        title: title,
        buffer: buffer,
        error: errorMessage,
        onClose: () {
          disposed = true;
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    overlay.insert(entry);

    // Start generation
    await generate();

    // If no error, auto-close after a few seconds or let user close manually
    if (errorMessage.isEmpty && !disposed && entry.mounted) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    if (disposed) {
      return null;
    }
    if (errorMessage.isNotEmpty) {
      entry.remove();
      return errorMessage;
    }
    return null;
  }
}

class _TheaterOverlay extends StatefulWidget {
  const _TheaterOverlay({
    required this.title,
    required this.buffer,
    required this.error,
    required this.onClose,
  });

  final String title;
  final StringBuffer buffer;
  final String error;
  final VoidCallback onClose;

  @override
  State<_TheaterOverlay> createState() => _TheaterOverlayState();
}

class _TheaterOverlayState extends State<_TheaterOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController.forward();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.buffer.toString();
    final hasError = widget.error.isNotEmpty;
    final hasContent = text.trim().isNotEmpty;

    return FadeTransition(
      opacity: _fadeController,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: GestureDetector(
          // Tap on backdrop to close only when content is done and no error
          onTap: hasContent && !hasError ? widget.onClose : null,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap-through
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 620,
                ),
                child: DecoratedBox(
                  decoration: AppTheme.glassPanel(
                    highlighted: true,
                    radius: 28,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Decorative header
                        _TheaterHeader(title: widget.title),
                        const SizedBox(height: 14),
                        // Decorative divider
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.activePrimary.withValues(alpha: 0.7),
                                AppTheme.activeSecondary.withValues(alpha: 0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Content area
                        Flexible(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (hasContent)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      // Decorative sparkle
                                      _DecorativeSparkleLine(
                                        color: AppTheme.activeSoft,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        text,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(height: 1.8),
                                      ),
                                      const SizedBox(height: 10),
                                      _DecorativeSparkleLine(
                                        color: AppTheme.activeSecondary,
                                        reverse: true,
                                      ),
                                    ],
                                  )
                                else if (hasError)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(Icons.error_outline_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        widget.error,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: AppTheme.activeSoft,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        AppTheme.glitchText('商店老板努力中...'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                // Streaming indicator
                                if (!hasError && !hasContent) ...<Widget>[
                                  const SizedBox(height: 16),
                                  _streamingDots(),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (hasContent || hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: <Widget>[
                                if (hasContent)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _showFullscreen(context, text),
                                    icon: const Icon(Icons.fullscreen_rounded,
                                        size: 18),
                                    label: Text(AppTheme.glitchText('全屏查看')),
                                  ),
                                FilledButton.icon(
                                  onPressed: widget.onClose,
                                  icon:
                                      const Icon(Icons.close_rounded, size: 18),
                                  label: Text(AppTheme.glitchText('关闭')),
                                ),
                              ],
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
      ),
    );
  }

  Widget _streamingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: Duration(milliseconds: 600 + (index * 200)),
            builder: (context, value, _) {
              return Container(
                width: 10 * value,
                height: 10 * value,
                decoration: BoxDecoration(
                  color: AppTheme.activeSoft.withValues(alpha: value),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showFullscreen(BuildContext context, String text) async {
    await showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: AppTheme.panel,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          AppTheme.glitchText(widget.title),
                          style: Theme.of(context).textTheme.titleLarge,
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
                  Expanded(
                    child: DecoratedBox(
                      decoration: AppTheme.glassPanel(radius: 22),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            text,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.85),
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
}

class _TheaterHeader extends StatelessWidget {
  const _TheaterHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.auto_awesome_rounded, color: AppTheme.activeSoft, size: 24),
        const SizedBox(width: 10),
        Text(
          AppTheme.glitchText(title),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.activeSoft,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.auto_awesome_rounded,
            color: AppTheme.activeSecondary, size: 24),
      ],
    );
  }
}

class _DecorativeSparkleLine extends StatelessWidget {
  const _DecorativeSparkleLine({
    required this.color,
    this.reverse = false,
  });

  final Color color;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.15, end: 0.55),
            duration: Duration(milliseconds: 400 + (index * 120)),
            builder: (context, value, _) {
              return Container(
                height: 1.4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: reverse ? value : 0.15),
                      color.withValues(alpha: reverse ? 0.15 : value),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
