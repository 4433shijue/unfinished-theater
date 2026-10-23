/// The single boundary between locally displayed HTML and canonical story data.
/// No state/parser imports: state extraction must call this BEFORE reading tags.
class NarrativeContent {
  const NarrativeContent._();

  /// Parse structural tags only outside HTML, while retaining HTML for display.
  static String transformOutsideHtml(
      String content, String Function(String) transform) {
    final saved = <String, String>{};
    String stash(String value) {
      final key = '\uE000LOCAL_HTML_${saved.length}\uE001';
      saved[key] = value;
      return key;
    }

    var masked = content.replaceAllMapped(
        fences, (m) => isHtmlFence(m) ? stash(m.group(0)!) : m.group(0)!);
    masked = _transformRawHtml(masked, stash);
    var result = transform(masked);
    for (final entry in saved.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static final fences =
      RegExp(r'```([^\n`]*)\r?\n([\s\S]*?)(?:```|$)', caseSensitive: false);
  static final documents = RegExp(
      r'(?:<!doctype[^>]*>\s*)?<html\b[\s\S]*?(?:</html\s*>|$)',
      caseSensitive: false);

  // Handle malformed/raw fragments too: a state tag inside a nested <div>
  // must not escape simply because the model omitted its <html> wrapper.
  static String _transformRawHtml(
      String content, String Function(String) replace) {
    final completeMasked =
        content.replaceAllMapped(documents, (m) => replace(m.group(0)!));
    final tags = RegExp(r'<!--[\s\S]*?-->|<(/?)([a-z][a-z0-9:-]*)\b[^>]*>',
        caseSensitive: false);
    const voidTags = {
      'br',
      'hr',
      'img',
      'input',
      'meta',
      'link',
      'source',
      'area',
      'base',
      'embed',
      'wbr',
      'col',
      'param',
      'track'
    };
    final output = StringBuffer();
    var cursor = 0;
    var start = -1;
    var root = '';
    var depth = 0;
    for (final tag in tags.allMatches(completeMasked)) {
      final name = tag.group(2)?.toLowerCase();
      if (name == null) {
        if (start < 0) {
          output.write(completeMasked.substring(cursor, tag.start));
          output.write(replace(tag.group(0)!));
          cursor = tag.end;
        }
        continue;
      }
      final closing = tag.group(1) == '/';
      if (start < 0) {
        output.write(completeMasked.substring(cursor, tag.start));
        if (closing ||
            voidTags.contains(name) ||
            tag.group(0)!.endsWith('/>')) {
          output.write(replace(tag.group(0)!));
          cursor = tag.end;
          continue;
        }
        start = tag.start;
        root = name;
        depth = 1;
      } else if (name == root) {
        depth += closing ? -1 : 1;
        if (depth == 0) {
          output.write(replace(completeMasked.substring(start, tag.end)));
          cursor = tag.end;
          start = -1;
        }
      }
    }
    if (start >= 0) {
      output.write(replace(completeMasked.substring(start)));
    } else {
      output.write(completeMasked.substring(cursor));
    }
    return output.toString();
  }

  static bool isHtmlFence(Match m) =>
      RegExp(r'^(html|htm)\b', caseSensitive: false)
          .hasMatch((m.group(1) ?? '').trim()) ||
      RegExp(r'^\s*(<!doctype|<html|<head|<body|<style|<div|<section|<article)',
              caseSensitive: false)
          .hasMatch(m.group(2) ?? '');

  /// A same-length mask preserves exact occurrence offsets for text selection.
  static String maskHtmlForSelection(String content) {
    String mask(String html) => '\n' * html.length;
    final fenced = content.replaceAllMapped(
        fences, (m) => isHtmlFence(m) ? mask(m.group(0)!) : m.group(0)!);
    return _transformRawHtml(fenced, mask);
  }

  static String withoutHtml(String content) {
    var result = content.replaceAllMapped(
        fences, (m) => isHtmlFence(m) ? '\n' : m.group(0)!);
    result = _transformRawHtml(result, (_) => '\n');
    // Also discard an unfinished HTML fence while streaming or after cancellation.
    result = result.replaceAll(
        RegExp(r'```(?:html|htm)\b[\s\S]*$', caseSensitive: false), '');
    return result.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static List<String> htmlDocuments(String content) {
    final found = <String>[];
    var rest = content.replaceAllMapped(fences, (m) {
      if (!isHtmlFence(m)) return m.group(0)!;
      found.add(m.group(2)!.trim());
      return '';
    });
    _transformRawHtml(rest, (document) {
      found.add(document.trim());
      return '';
    });
    return found;
  }
}
