import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../services/message_content_parser.dart';
import '../theme/app_theme.dart';
import 'runnable_code_preview.dart';

class HtmlContentView extends StatelessWidget {
  const HtmlContentView({
    super.key,
    required this.content,
    this.isStreaming = false,
  });

  final String content;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final blocks = MessageContentParser.parse(content);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(height: 1.6);

    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          _buildBlock(
            context: context,
            block: blocks[index],
            style: style,
          ),
          if (index != blocks.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildBlock({
    required BuildContext context,
    required MessageContentBlock block,
    required TextStyle? style,
  }) {
    switch (block.type) {
      case MessageContentBlockType.markdown:
        return SelectionArea(
          child: MarkdownBody(
            data: block.content,
            selectable: false,
            softLineBreak: true,
            onTapLink: (_, __, ___) {},
            styleSheet:
                MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: style,
              code: style?.copyWith(
                fontFamily: 'monospace',
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              codeblockPadding: const EdgeInsets.all(12),
              codeblockDecoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
              ),
              blockSpacing: 12,
            ),
          ),
        );
      case MessageContentBlockType.code:
        final language =
            block.language.trim().isEmpty ? 'code' : block.language;
        return _CodeSection(
          title: language,
          code: block.content,
        );
      case MessageContentBlockType.runnablePreview:
        if (isStreaming) {
          return const _PreviewPlaceholder();
        }

        return _RunnableSection(
          document: block.content,
          height: MessageContentParser.estimatePreviewHeight(block.content),
        );
    }
  }
}

class _CodeSection extends StatelessWidget {
  const _CodeSection({
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
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

class _RunnableSection extends StatelessWidget {
  const _RunnableSection({
    required this.document,
    required this.height,
  });

  final String document;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showFullscreen(context),
              icon: const Icon(Icons.fullscreen_rounded, size: 18),
              label: Text(AppTheme.glitchText('全屏查看')),
            ),
          ),
          const SizedBox(height: 8),
          RunnableCodePreview(
            document: document,
            height: height,
          ),
        ],
      ),
    );
  }

  Future<void> _showFullscreen(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        return Dialog.fullscreen(
          backgroundColor: AppTheme.panel,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          AppTheme.glitchText('全屏查看'),
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
                  const SizedBox(height: 8),
                  Expanded(
                    child: RunnableCodePreview(
                      document: document,
                      height: size.height * 0.9,
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
