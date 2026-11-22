import 'package:html/parser.dart' as html;
import 'package:markdown/markdown.dart' as md;

/// Formatting has no stored state. The same AST transformation serves Flutter
/// and HTML exports, while the projection retains original UTF-16 offsets.
class StoryMarkdownDocument {
  const StoryMarkdownDocument._();
  static const dialogueTag = 'story-dialogue';
  static const propLabels = {
    '来信': 'letter',
    '纸条': 'note',
    '短信': 'sms',
    '广播': 'broadcast'
  };
  static const exportStyles = '''
    .content .story-prop { margin: .7em .25em; padding: .55em .85em; border: 0; border-inline-start: 2px solid currentColor; background: transparent; }
    .content .story-letter,.content .story-note {border-block: 1px solid currentColor; border-inline-start:0;}
    .content .story-sms {border:1px solid currentColor; border-radius:8px; width:fit-content; max-width:100%; box-sizing:border-box;}
    .content .story-prop p {margin:.25em 0;}
    .content .story-break {border:0; border-top:1px double currentColor; opacity:.55; width:35%; margin:1.2em auto;}
    .content em,.content .story-dialogue {font-size:inherit;}
  ''';

  static String? propKind(md.Element node) {
    if (node.tag != 'blockquote') return null;
    final first = node.children?.firstOrNull;
    if (first is! md.Element || first.tag != 'p') return null;
    final parts = first.children!;
    final label = parts.firstOrNull;
    if (label is! md.Element || label.tag != 'strong') return null;
    if (parts.length == 1 && node.children!.length == 1) return null;
    if (parts.length > 1 &&
        !(parts[1].textContent.startsWith('\n') ||
            (parts[1] is md.Element && (parts[1] as md.Element).tag == 'br'))) {
      return null;
    }
    return propLabels[label.textContent];
  }

  static bool endsInSpokenParagraph(String source) {
    final last = nodes(source).lastOrNull;
    if (last is! md.Element || last.tag != 'p') return false;
    final value = last.textContent.trim();
    return _dialogueMarks(value)
        .pairs
        .any((p) => p.$1 == 0 && p.$2 == value.length - 1);
  }

  static String plainText(String source) =>
      nodes(source).map(plainNode).where((s) => s.isNotEmpty).join('\n\n');

  static String plainNode(md.Node node) {
    if (node is! md.Element) return node.textContent;
    if (node.tag == 'br') return '\n';
    if (node.tag == 'hr') return '';
    final separator = switch (node.tag) {
      'blockquote' || 'ul' || 'ol' || 'table' || 'thead' || 'tbody' => '\n',
      'tr' => '\t',
      _ => ''
    };
    return (node.children ?? []).map(plainNode).join(separator);
  }

  // Offsets are UTF-16 positions in this selectable, never a global text search.
  static StoryCopyRun copyRun(md.Node node) {
    final raw = StringBuffer(), mask = StringBuffer();
    void visit(md.Node n, bool literal) {
      if (n is md.Element && n.tag != 'br') {
        for (final child in n.children ?? <md.Node>[]) {
          visit(child, literal || n.tag == 'code');
        }
      } else {
        final s = plainNode(n);
        raw.write(s);
        mask.write(literal ? '\uFFFC' * s.length : s);
      }
    }

    visit(node, false);
    final text = raw.toString(), marks = _dialogueMarks(mask.toString());
    final visible = [
      for (var i = 0; i < text.length; i++)
        if (!marks.hidden.contains(i)) i
    ];
    return StoryCopyRun(text, visible, marks.pairs);
  }

  static final Map<String, StoryTextProjection> _projections = {};
  static final Map<String, List<md.Node>> _trees = {};

  static List<md.Node> nodes(String source, {bool cache = true}) {
    var tree = _trees.remove(source);
    tree ??= md.Document(
            encodeHtml: false, extensionSet: md.ExtensionSet.gitHubFlavored)
        .parseLines(source.replaceAll('\r\n', '\n').split('\n'));
    if (cache && source.length <= 24000) {
      _trees[source] = tree;
      while (_trees.length > 64) {
        _trees.remove(_trees.keys.first);
      }
    }
    md.Node clone(md.Node node) {
      if (node is md.Element) {
        final copy = md.Element(node.tag, node.children?.map(clone).toList());
        copy.attributes.addAll(node.attributes);
        return copy;
      }
      return md.Text(node.textContent);
    }

    return tree.map(clone).toList();
  }

  static StoryTextProjection projection(String source) {
    final cached = _projections.remove(source);
    if (cached != null) {
      _projections[source] = cached;
      return cached;
    }
    final result = StoryTextProjection.parse(source);
    // Do not retain megabytes of cancelled streams / long conversations.
    if (source.length <= 24000) {
      _projections[source] = result;
      while (_projections.length > 64) {
        _projections.remove(_projections.keys.first);
      }
    }
    return result;
  }

  static _DialogueMarks _dialogueMarks(String text) {
    const pairs = {'“': '”', '「': '」', '『': '』', '"': '"'};
    final ranges = <(int, int)>[];
    final hidden = <int>{};
    final delimiters = <(int, int)>[];
    final stack = <int>[];
    var start = -1;
    void finishUnclosed(int boundary) {
      if (start < 0) return;
      final lineEnd = text.indexOf(RegExp(r'[\r\n]'), start);
      final end = lineEnd < 0 || lineEnd > boundary ? boundary : lineEnd;
      ranges.add((start, end));
      if (text[start] == '“') hidden.add(start);
      start = -1;
      stack.clear();
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '\n' && i + 1 < text.length && text[i + 1] == '\n') {
        finishUnclosed(i);
      } else if (stack.isNotEmpty && c == pairs[text[stack.last]]) {
        final opening = stack.removeLast();
        if (c == '”' || c == '"') {
          hidden
            ..add(opening)
            ..add(i);
          delimiters.add((opening, i));
        }
        if (stack.isEmpty) {
          ranges.add((start, i + 1));
          start = -1;
        }
      } else if (pairs.containsKey(c)) {
        if (stack.isEmpty) start = i;
        stack.add(i);
      }
    }
    // A streaming or malformed quote is bounded by its paragraph.
    finishUnclosed(text.length);
    return _DialogueMarks(ranges, hidden, delimiters);
  }

  /// Called on a block before Markdown's normal renderer visits its children.
  /// Only inline text nodes are decorated; images, code and link destinations
  /// retain their native semantics and nested Markdown remains intact.
  static void decorateInline(md.Element block, {bool encoded = false}) {
    final text = StringBuffer();
    final offsets = <md.Text, int>{};
    final entityWidths = <int, int>{};
    const blocks = {
      'p',
      'li',
      'ul',
      'ol',
      'blockquote',
      'table',
      'tr',
      'td',
      'th',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'pre'
    };
    void collect(List<md.Node>? nodes) {
      for (final node in nodes ?? <md.Node>[]) {
        if (node is md.Text) {
          offsets[node] = text.length;
          // Keep encoded-source offsets while recognizing escaped quote glyphs
          // in HTML exports. Flutter nodes already contain decoded text.
          text.write(encoded
              ? node.text.replaceAllMapped(
                  RegExp(r'&(?:quot|ldquo|rdquo|#34|#x22);'), (m) {
                  final glyph = html.parseFragment(m[0]!).text ?? m[0]!;
                  entityWidths[offsets[node]! + m.start] = m[0]!.length;
                  return glyph.padRight(m[0]!.length, '\u200B');
                })
              : node.text);
        }
        if (node is md.Element) {
          if (blocks.contains(node.tag)) {
            text.write('\n');
            continue;
          }
          if (node.tag == 'code' ||
              node.tag == 'img' ||
              node.tag == dialogueTag) {
            text.write('\uFFFC');
            continue;
          }
          if (node.tag == 'br') {
            text.write('\n');
            continue;
          }
          collect(node.children);
        }
      }
    }

    collect(block.children);
    final combined = text.toString();
    final marks = _dialogueMarks(combined);
    final ranges = marks.ranges;
    final hidden = <int>{
      for (final i in marks.hidden)
        for (var j = 0; j < (entityWidths[i] ?? 1); j++) i + j
    };
    if (ranges.isEmpty) return;
    void replace(List<md.Node>? nodes) {
      if (nodes == null) return;
      final result = <md.Node>[];
      for (final node in nodes) {
        if (node is md.Text && offsets.containsKey(node)) {
          final base = offsets[node]!;
          var cursor = 0;
          for (final range in ranges) {
            final from = (range.$1 - base).clamp(0, node.text.length);
            final to = (range.$2 + (entityWidths[range.$2 - 1] ?? 1) - 1 - base)
                .clamp(0, node.text.length);
            if (to <= from) continue;
            if (cursor < from) {
              result.add(md.Text(node.text.substring(cursor, from)));
            }
            final speech = String.fromCharCodes([
              for (var i = from; i < to; i++)
                if (!hidden.contains(base + i)) node.text.codeUnitAt(i)
            ]);
            if (speech.isNotEmpty) {
              result.add(md.Element.text(dialogueTag, speech));
            }
            cursor = to;
          }
          if (cursor < node.text.length) {
            result.add(md.Text(node.text.substring(cursor)));
          }
        } else {
          if (node is md.Element &&
              !blocks.contains(node.tag) &&
              !{'code', 'img', dialogueTag}.contains(node.tag)) {
            replace(node.children);
          }
          result.add(node);
        }
      }
      nodes
        ..clear()
        ..addAll(result);
    }

    replace(block.children);
  }

  static String toHtml(String source) {
    final nodes = md.Document(
            encodeHtml: true, extensionSet: md.ExtensionSet.gitHubFlavored)
        .parseLines(source.replaceAll('\r\n', '\n').split('\n'));
    decorateNodes(nodes, encoded: true);
    return md
        .renderToHtml(nodes)
        .replaceAll('<$dialogueTag ', '<span ')
        .replaceAll('</$dialogueTag>', '</span>');
  }

  static void decorateNodes(List<md.Node> nodes, {bool encoded = false}) {
    void walk(md.Node node) {
      if (node is! md.Element) return;
      final kind = propKind(node);
      if (kind != null) node.attributes['class'] = 'story-prop story-$kind';
      if (node.tag == 'hr') node.attributes['class'] = 'story-break';
      if ({'p', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'td', 'th'}
          .contains(node.tag)) {
        decorateInline(node, encoded: encoded);
      }
      for (final child in node.children ?? <md.Node>[]) {
        walk(child);
      }
      if (node.tag == dialogueTag) node.attributes['class'] = 'story-dialogue';
    }

    for (final node in nodes) {
      walk(node);
    }
  }
}

class StoryCopyRun {
  const StoryCopyRun(this.raw, this.visible, this.pairs);
  final String raw;
  final List<int> visible;
  final List<(int, int)> pairs;
  String slice(int from, int to) {
    if (from < 0 || to > visible.length || from >= to) return '';
    final retain = visible.sublist(from, to).toSet();
    final left = from == 0 ? -1 : visible[from - 1];
    final right = to == visible.length ? raw.length : visible[to];
    for (final (a, b) in pairs) {
      if (a > left && b < right && a < visible[to - 1] && b > visible[from]) {
        retain
          ..add(a)
          ..add(b);
      }
    }
    return String.fromCharCodes((retain.toList()..sort()).map(raw.codeUnitAt));
  }
}

class _DialogueMarks {
  const _DialogueMarks(this.ranges, this.hidden, this.pairs);
  final List<(int, int)> ranges, pairs;
  final Set<int> hidden;
}

class StorySourceRange {
  const StorySourceRange(this.start, this.end);
  final int start, end;
}

class _FormatRange {
  const _FormatRange(this.start, this.end, this.marker, {String? closingMarker})
      : closingMarker = closingMarker ?? marker;
  final int start, end;
  final String marker, closingMarker;
  int get innerStart => start + marker.length;
  int get innerEnd => end - closingMarker.length;
}

class StoryTextProjection {
  StoryTextProjection._(
      this.source, this.text, this.starts, this.ends, this._formats);
  final String source, text;
  final List<int> starts, ends;
  final List<_FormatRange> _formats;

  factory StoryTextProjection.parse(String source) {
    final text = StringBuffer();
    final starts = <int>[], ends = <int>[];
    final formats = <_FormatRange>[];
    final codeOffsets = <int>{};
    void emit(String value, int start, int end) {
      text.write(value);
      for (var i = 0; i < value.length; i++) {
        starts.add(start);
        ends.add(end);
      }
    }

    void scan(int from, int until) {
      var i = from;
      while (i < until) {
        final c = source[i];
        if (i == 0 || source[i - 1] == '\n') {
          final prefix =
              RegExp(r'^(?: {0,3}#{1,6}\s+|\s*>\s?| {0,3}(?:[-+*]|\d+[.)])\s+)')
                  .firstMatch(source.substring(i, until));
          if (prefix != null) {
            i += prefix.end;
            continue;
          }
        }
        if (c == '\\' &&
            i + 1 < until &&
            RegExp(r'[!"#$%&\x27()*+,\-./:;<=>?@\[\]\\^_`{|}~]')
                .hasMatch(source[i + 1])) {
          emit(source[i + 1], i, i + 2);
          i += 2;
          continue;
        }
        if (c == '&') {
          final entity = RegExp(r'^&(?:#\d+|#x[0-9a-fA-F]+|[A-Za-z]+);')
              .firstMatch(source.substring(i, until));
          if (entity != null) {
            final decoded = html.parseFragment(entity.group(0)!).text ?? '';
            emit(decoded, i, i + entity.end);
            i += entity.end;
            continue;
          }
        }
        if (c == '`') {
          final marker =
              RegExp(r'^`+').firstMatch(source.substring(i, until))!.group(0)!;
          final end = source.indexOf(marker, i + marker.length);
          if (end >= 0 && end < until) {
            formats.add(_FormatRange(i, end + marker.length, marker));
            for (var j = i + marker.length; j < end; j++) {
              codeOffsets.add(text.length);
              emit(source[j], j, j + 1);
            }
            i = end + marker.length;
            continue;
          }
        }
        if (c == '[' || (c == '!' && i + 1 < until && source[i + 1] == '[')) {
          final label = c == '!' ? i + 2 : i + 1;
          final close = source.indexOf(']', label);
          if (close >= label && close + 1 < until && source[close + 1] == '(') {
            var depth = 1, end = close + 2;
            while (end < until && depth > 0) {
              if (source[end] == '(') depth++;
              if (source[end] == ')') depth--;
              end++;
            }
            if (depth == 0) {
              if (c != '!') {
                formats.add(_FormatRange(i, end, '[',
                    closingMarker: source.substring(close, end)));
                scan(label, close);
              }
              i = end;
              continue;
            }
          }
        }
        var matched = false;
        for (final marker in ['***', '___', '**', '__', '~~', '*', '_']) {
          if (!source.startsWith(marker, i)) continue;
          if (marker.contains('_') &&
              i > from &&
              RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(source[i - 1])) {
            continue;
          }
          final close = source.indexOf(marker, i + marker.length);
          if (close > i + marker.length &&
              close + marker.length <= until &&
              !source.substring(i + marker.length, close).contains('\n\n')) {
            formats.add(_FormatRange(i, close + marker.length, marker));
            scan(i + marker.length, close);
            i = close + marker.length;
            matched = true;
            break;
          }
        }
        if (matched) continue;
        if (c != '\r') emit(c, i, i + 1);
        i++;
      }
    }

    scan(0, source.length);
    final projected = text.toString();
    final marks = StoryMarkdownDocument._dialogueMarks(codeOffsets.isEmpty
        ? projected
        : String.fromCharCodes([
            for (var i = 0; i < projected.length; i++)
              codeOffsets.contains(i) ? 0xfffc : projected.codeUnitAt(i)
          ]));
    if (marks.hidden.isEmpty) {
      return StoryTextProjection._(source, projected, starts, ends, formats);
    }
    for (final (left, right) in marks.pairs) {
      formats.add(_FormatRange(
          starts[left], ends[right], source.substring(starts[left], ends[left]),
          closingMarker: source.substring(starts[right], ends[right])));
    }
    formats.sort((a, b) => a.start.compareTo(b.start));
    final visible = [
      for (var i = 0; i < projected.length; i++)
        if (!marks.hidden.contains(i)) i
    ];
    return StoryTextProjection._(
        source,
        String.fromCharCodes(visible.map(projected.codeUnitAt)),
        [for (final i in visible) starts[i]],
        [for (final i in visible) ends[i]],
        formats);
  }

  List<StorySourceRange> occurrences(String selection) {
    if (selection.isEmpty) return [];
    final found = <StorySourceRange>[];
    var offset = text.indexOf(selection);
    while (offset >= 0) {
      var start = starts[offset], end = ends[offset + selection.length - 1];
      // Include boundary delimiters when no unselected text would remain inside.
      for (final format in _formats.reversed) {
        if (start == format.innerStart && end > format.innerEnd) {
          start = format.start;
        }
        if (end == format.innerEnd && start < format.innerStart) {
          end = format.end;
        }
      }
      found.add(StorySourceRange(start, end));
      offset = text.indexOf(selection, offset + selection.length);
    }
    return found;
  }

  String balancedReplacement(int start, int end, String replacement) {
    final atStart = _formats
        .where((f) => f.innerStart <= start && start < f.innerEnd)
        .toList();
    final atEnd =
        _formats.where((f) => f.innerStart < end && end <= f.innerEnd).toList();
    final close = atStart
        .where((f) => !atEnd.contains(f))
        .toList()
        .reversed
        .map((f) => f.closingMarker)
        .join();
    final reopen =
        atEnd.where((f) => !atStart.contains(f)).map((f) => f.marker).join();
    return '$close$replacement$reopen';
  }
}
