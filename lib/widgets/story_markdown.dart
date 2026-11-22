import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/story_markdown_document.dart';
import '../theme/story_text_palette.dart';
import '../theme/app_theme.dart';
import 'story_anchored_list.dart';

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
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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
          fontStyle: FontStyle.italic, color: palette.muted, fontSize: size),
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
              top: BorderSide(color: palette.dialogue.withValues(alpha: .25)))),
      blockSpacing: 12,
    );
    return _StoryFlow(
        data: data, palette: palette, sheet: sheet, streaming: isStreaming);
  }
}

// Finalized prose blocks keep their widget identity while only the tail grows.
// Structural Markdown uses the full document so lists, references and fences
// can span blank lines without being split into unrelated blocks.
class _StoryFlow extends StatefulWidget {
  const _StoryFlow(
      {required this.data,
      required this.palette,
      required this.sheet,
      required this.streaming});
  final String data;
  final StoryTextPalette palette;
  final MarkdownStyleSheet sheet;
  final bool streaming;
  @override
  State<_StoryFlow> createState() => _StoryFlowState();
}

class _StoryFlowState extends State<_StoryFlow> {
  final _sealed = <int, (String, Widget)>{};
  MarkdownStyleSheet? _style;
  Color? _ink;
  @override
  Widget build(BuildContext context) {
    if (_style != widget.sheet || _ink != widget.palette.dialogue) {
      _sealed.clear();
      _style = widget.sheet;
      _ink = widget.palette.dialogue;
    }
    final structure = RegExp(
            r'^(?: {4}|\t| {0,3}(?:[-+*] |\d+[.)] |[~\x60]{3}|\[|<|\|))',
            multiLine: true)
        .firstMatch(widget.data);
    final reference =
        RegExp(r'^ {0,3}\[[^\n]+\]:', multiLine: true).hasMatch(widget.data);
    final pieces = <String>[];
    var start = 0;
    if (!reference) {
      for (final gap in RegExp(r'\r?\n[ \t]*\r?\n').allMatches(widget.data)) {
        if (structure != null && gap.start >= structure.start) break;
        pieces.add(widget.data.substring(start, gap.start));
        start = gap.end;
      }
    }
    pieces.add(widget.data.substring(start));
    final children = <Widget>[];
    for (var i = 0; i < pieces.length; i++) {
      final s = pieces[i];
      if (s.trim().isEmpty) continue;
      final sealed = i < pieces.length - 1;
      final cached = _sealed[i];
      final child = sealed && cached?.$1 == s
          ? cached!.$2
          : _CachedStoryBody(
              data: s,
              streaming: widget.streaming && !sealed,
              palette: widget.palette,
              builders: {
                StoryMarkdownDocument.dialogueTag:
                    _DialogueBuilder(widget.palette.dialogue)
              },
              styleSheet: widget.sheet);
      if (sealed) _sealed[i] = (s, child);
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(child);
    }
    _sealed.removeWhere((k, v) => k >= pieces.length - 1);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children);
  }
}

class _CachedStoryBody extends StatefulWidget {
  const _CachedStoryBody(
      {required this.data,
      required this.streaming,
      required this.palette,
      required this.builders,
      required this.styleSheet});
  final String data;
  final bool streaming;
  final StoryTextPalette palette;
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
    final sheet = widget.styleSheet, ink = widget.palette;
    final children = <Widget>[];
    var propIndex = 0;
    Widget render(md.Node node) {
      if (node is md.Element && node.tag == 'hr') {
        final color = ink.dialogue.withValues(alpha: .6);
        return Center(
            child: SizedBox(
                width: 100,
                height: 12,
                child: Center(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(color: color),
                                bottom: AppTheme.isVinylMode
                                    ? BorderSide(color: color)
                                    : BorderSide.none)),
                        child: const SizedBox(width: 100, height: 4)))));
      }
      if (node is md.Element && node.tag == 'blockquote') {
        final kind = StoryMarkdownDocument.propKind(node);
        final line = BorderSide(color: ink.dialogue.withValues(alpha: .65));
        final paper = kind == 'letter' || kind == 'note', sms = kind == 'sms';
        return Container(
            key: kind == null
                ? null
                : ValueKey('story-prop-$kind-${propIndex++}'),
            margin: EdgeInsets.symmetric(horizontal: paper ? 6 : 0),
            padding:
                EdgeInsets.symmetric(horizontal: 12, vertical: sms ? 5 : 8),
            decoration: kind == null
                ? sheet.blockquoteDecoration
                : BoxDecoration(
                    border: paper
                        ? Border(top: line, bottom: line)
                        : sms
                            ? Border.fromBorderSide(line)
                            : Border(left: line.copyWith(width: 3)),
                    borderRadius: sms ? BorderRadius.circular(8) : null),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final child in node.children!) render(child)]));
      }
      const inline = {'strong', 'em', 'del', 'code', 'br', 'a'};
      bool supported(md.Node n) =>
          n is! md.Element ||
          inline.contains(n.tag) && (n.children ?? []).every(supported);
      final styles = {
        'p': sheet.p,
        'h1': sheet.h1,
        'h2': sheet.h2,
        'h3': sheet.h3,
        'h4': sheet.h4,
        'h5': sheet.h5,
        'h6': sheet.h6
      };
      if (node is md.Element &&
          styles.containsKey(node.tag) &&
          node.children!.every(supported)) {
        final run = StoryMarkdownDocument.copyRun(node);
        StoryMarkdownDocument.decorateInline(node);
        InlineSpan span(md.Node n) {
          if (n is! md.Element) return TextSpan(text: n.textContent);
          if (n.tag == 'br') return const TextSpan(text: '\n');
          final style = switch (n.tag) {
            'strong' => sheet.strong,
            'em' => sheet.em,
            'code' => sheet.code,
            'a' => sheet.a,
            'del' => const TextStyle(decoration: TextDecoration.lineThrough),
            StoryMarkdownDocument.dialogueTag => TextStyle(color: ink.dialogue),
            _ => null
          };
          return TextSpan(
              style: style,
              recognizer: n.tag == 'a'
                  ? createLink(n.textContent, n.attributes['href'],
                      n.attributes['title'] ?? '')
                  : null,
              children: n.children?.map(span).toList());
        }

        return StoryReadingParagraph(
            text: run.raw,
            child: _ReadingRun(
                run: run,
                child: Text.rich(TextSpan(
                    style: styles[node.tag],
                    children: node.children!.map(span).toList()))));
      }
      StoryMarkdownDocument.decorateNodes([node]);
      return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: builder.build([node]));
    }

    for (final n in nodes) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(render(n));
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children);
  }
}

class _ReadingRun extends StatefulWidget {
  const _ReadingRun({required this.run, required this.child});
  final StoryCopyRun run;
  final Widget child;
  @override
  State<_ReadingRun> createState() => _ReadingRunState();
}

class _ReadingRunState extends State<_ReadingRun> {
  final notifier = SelectionListenerNotifier();
  (String, String)? get selected {
    if (!notifier.registered) return null;
    final range = notifier.selection.range;
    if (range == null) return null;
    final a = range.startOffset, b = range.endOffset;
    final from = a < b ? a : b, to = a < b ? b : a, r = widget.run;
    if (from < 0 || to > r.visible.length || from == to) return null;
    return (
      String.fromCharCodes(r.visible.sublist(from, to).map(r.raw.codeUnitAt)),
      r.slice(from, to)
    );
  }

  @override
  Widget build(BuildContext context) =>
      SelectionListener(selectionNotifier: notifier, child: widget.child);
  @override
  void dispose() {
    notifier.dispose();
    super.dispose();
  }
}

class StorySelectionArea extends StatefulWidget {
  const StorySelectionArea(
      {super.key,
      required this.child,
      this.onChanged,
      this.onQuote,
      this.onRewrite,
      this.onExcerpt});
  final Widget child;
  final ValueChanged<String?>? onChanged;
  final VoidCallback? onQuote, onRewrite;
  final ValueChanged<String>? onExcerpt;
  @override
  State<StorySelectionArea> createState() => _StorySelectionAreaState();
}

class _StorySelectionAreaState extends State<StorySelectionArea> {
  String visible = '';
  String copied() {
    final selected = <(String, String)>[];
    void visit(Element e) {
      if (e is StatefulElement && e.state is _ReadingRunState) {
        final pair = (e.state as _ReadingRunState).selected;
        if (pair != null) selected.add(pair);
      } else {
        e.visitChildren(visit);
      }
    }

    context.visitChildElements(visit);
    // Flutter concatenates selected paragraphs without separators. Only replace
    // text when all selected runs are accounted for, never search for a match.
    if (selected.isNotEmpty && selected.map((r) => r.$1).join() == visible) {
      return selected.map((r) => r.$2).join('\n\n');
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) => Actions(
          actions: {
            CopySelectionTextIntent:
                CallbackAction<CopySelectionTextIntent>(onInvoke: (_) {
              if (visible.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: copied()));
              }
              return null;
            })
          },
          child: SelectionArea(
              onSelectionChanged: (s) {
                visible = s?.plainText ?? '';
                widget.onChanged?.call(s?.plainText);
              },
              contextMenuBuilder: (context, region) =>
                  AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: region.contextMenuAnchors,
                      buttonItems: [
                        for (final item in region.contextMenuButtonItems)
                          if (item.type == ContextMenuButtonType.copy)
                            ContextMenuButtonItem(
                                type: item.type,
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: copied()));
                                  region.hideToolbar();
                                })
                          else
                            item,
                        if (widget.onExcerpt != null && visible.isNotEmpty)
                          ContextMenuButtonItem(
                              label: '摘进书签',
                              onPressed: () {
                                final s = copied();
                                region.hideToolbar();
                                widget.onExcerpt!(s);
                              }),
                        if (widget.onQuote != null)
                          ContextMenuButtonItem(
                              label: '接这句',
                              onPressed: () {
                                region.hideToolbar();
                                widget.onQuote!();
                              }),
                        if (widget.onRewrite != null)
                          ContextMenuButtonItem(
                              label: '局部改写',
                              onPressed: () {
                                region.hideToolbar();
                                widget.onRewrite!();
                              }),
                      ]),
              child: widget.child));
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
