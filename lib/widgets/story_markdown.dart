import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/story_markdown_document.dart';
import '../theme/story_text_palette.dart';

/// Content-only renderer: callers keep their existing bubble and selection UI.
class StoryMarkdown extends StatelessWidget {
  const StoryMarkdown(
      {super.key,
      required this.data,
      this.style,
      this.backgrounds,
      this.isStreaming = false});
  final String data;
  final TextStyle? style;
  final List<Color>? backgrounds;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final base = (style ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16));
    final palette =
        StoryTextPalette.resolve(body: base.color, backgrounds: backgrounds);
    final size = base.fontSize ?? 16;
    return _CachedStoryBody(
      data: data,
      streaming: isStreaming,
      builders: {
        StoryMarkdownDocument.dialogueTag: _DialogueBuilder(palette.dialogue),
      },
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: base.copyWith(color: palette.body, height: base.height ?? 1.62),
        h1: base.copyWith(
            color: palette.emphasis,
            fontSize: size * 1.25,
            fontWeight: FontWeight.w700),
        h2: base.copyWith(
            color: palette.emphasis,
            fontSize: size * 1.2,
            fontWeight: FontWeight.w700),
        h3: base.copyWith(
            color: palette.emphasis,
            fontSize: size * 1.15,
            fontWeight: FontWeight.w600),
        h4: base.copyWith(
            color: palette.emphasis,
            fontSize: size * 1.15,
            fontWeight: FontWeight.w600),
        h5: base.copyWith(
            color: palette.emphasis,
            fontSize: size * 1.15,
            fontWeight: FontWeight.w600),
        h6: base.copyWith(
            color: palette.emphasis,
            fontSize: size * 1.15,
            fontWeight: FontWeight.w600),
        strong: TextStyle(
            fontWeight: FontWeight.w700,
            color: palette.emphasis,
            fontSize: size * 1.08),
        em: TextStyle(
            fontStyle: FontStyle.italic,
            color: palette.muted,
            fontSize: size * .95),
        blockquote: base.copyWith(color: palette.body, height: 1.7),
        blockquotePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        blockquoteDecoration: BoxDecoration(
            color: palette.dialogue.withValues(alpha: .05),
            border: Border(
                left: BorderSide(
                    color: palette.dialogue.withValues(alpha: .6), width: 2))),
        code: base.copyWith(
            fontFamily: 'monospace',
            color: palette.body,
            backgroundColor: palette.dialogue.withValues(alpha: .08)),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
            color: palette.dialogue.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12)),
        horizontalRuleDecoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: palette.dialogue.withValues(alpha: .25)))),
        blockSpacing: 12,
      ),
    );
  }
}

class _CachedStoryBody extends StatefulWidget {
  const _CachedStoryBody(
      {required this.data,
      required this.streaming,
      required this.builders,
      required this.styleSheet});
  final String data;
  final bool streaming;
  final Map<String, MarkdownElementBuilder> builders;
  final MarkdownStyleSheet styleSheet;
  @override
  State<_CachedStoryBody> createState() => _CachedStoryBodyState();
}

class _CachedStoryBodyState extends State<_CachedStoryBody>
    implements MarkdownBuilderDelegate {
  final _links = <GestureRecognizer>[];
  void _disposeLinks() {
    for (final link in _links) {
      link.dispose();
    }
    _links.clear();
  }

  @override
  void dispose() {
    _disposeLinks();
    super.dispose();
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final link = TapGestureRecognizer()..onTap = () {};
    _links.add(link);
    return link;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) => TextSpan(
      style: styleSheet.code, text: code.replaceFirst(RegExp(r'\n$'), ''));
  @override
  Widget build(BuildContext context) {
    _disposeLinks();
    final builder = MarkdownBuilder(
        delegate: this,
        selectable: false,
        styleSheet: widget.styleSheet,
        imageDirectory: null,
        imageBuilder: null,
        checkboxBuilder: null,
        bulletBuilder: null,
        builders: widget.builders,
        paddingBuilders: const {},
        listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
        softLineBreak: true,
        fitContent: true);
    final nodes =
        StoryMarkdownDocument.nodes(widget.data, cache: !widget.streaming);
    StoryMarkdownDocument.decorateNodes(nodes);
    final children = builder.build(nodes);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children);
  }
}

class _DialogueBuilder extends MarkdownElementBuilder {
  _DialogueBuilder(this.color);
  final Color color;
  @override
  void visitElementBefore(md.Element element) {
    element.attributes['text'] = element.textContent;
    element.children?.clear();
  }

  @override
  Widget visitElementAfterWithContext(BuildContext context, md.Element element,
          TextStyle? preferredStyle, TextStyle? parentStyle) =>
      Text.rich(TextSpan(
          text: element.attributes['text'],
          style: (parentStyle ?? const TextStyle()).copyWith(color: color)));
}
