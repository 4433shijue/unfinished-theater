class HtmlSanitizer {
  const HtmlSanitizer._();

  static final RegExp _htmlTagPattern = RegExp(
    r'<(div|p|span|br|strong|em|b|i|u|code|pre|ul|ol|li|blockquote|h[1-6]|table|thead|tbody|tr|th|td|a|img)\b',
    caseSensitive: false,
  );

  static final RegExp _blockedContainerTags = RegExp(
    r'<\s*(script|iframe|object|embed|form|style|link|meta|base)[^>]*>[\s\S]*?<\s*/\s*\1\s*>',
    caseSensitive: false,
  );

  static final RegExp _blockedStandaloneTags = RegExp(
    r'<\s*(script|iframe|object|embed|form|style|link|meta|base|input|button|textarea|select)[^>]*\/?>',
    caseSensitive: false,
  );

  static final RegExp _eventAttributes = RegExp(
    r"""\s(on\w+)\s*=\s*(".*?"|'.*?'|[^\s>]+)""",
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _inlineStyleAttribute = RegExp(
    r"""\sstyle\s*=\s*(".*?"|'.*?'|[^\s>]+)""",
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _quotedDangerousUrl = RegExp(
    r"""\s(href|src)\s*=\s*("|')\s*(javascript:|data:(?!image/))[^"']*\2""",
    caseSensitive: false,
  );

  static final RegExp _unquotedDangerousUrl = RegExp(
    r'\s(href|src)\s*=\s*(javascript:|data:(?!image/))[^\s>]+',
    caseSensitive: false,
  );

  static final Set<String> _allowedStyleKeys = <String>{
    'background-color',
    'border',
    'border-color',
    'border-radius',
    'color',
    'font-style',
    'font-weight',
    'margin',
    'padding',
    'text-align',
    'text-decoration',
    'white-space',
  };

  static bool looksLikeHtml(String content) {
    return _htmlTagPattern.hasMatch(content);
  }

  static String sanitize(String dirtyHtml) {
    var sanitized = dirtyHtml;
    sanitized = sanitized.replaceAll(_blockedContainerTags, '');
    sanitized = sanitized.replaceAll(_blockedStandaloneTags, '');
    sanitized = sanitized.replaceAll(_eventAttributes, '');
    sanitized = sanitized.replaceAll(_quotedDangerousUrl, '');
    sanitized = sanitized.replaceAll(_unquotedDangerousUrl, '');
    sanitized = sanitized.replaceAllMapped(_inlineStyleAttribute, (match) {
      final rawValue = _unwrapQuotes(match.group(1) ?? '');
      final safeStyle = _sanitizeStyle(rawValue);
      if (safeStyle.isEmpty) {
        return '';
      }

      return ' style="${_escapeAttribute(safeStyle)}"';
    });

    return sanitized.trim();
  }

  static String _sanitizeStyle(String styleValue) {
    final safeDeclarations = <String>[];

    for (final declaration in styleValue.split(';')) {
      final raw = declaration.trim();
      if (raw.isEmpty || !raw.contains(':')) {
        continue;
      }

      final separatorIndex = raw.indexOf(':');
      final key = raw.substring(0, separatorIndex).trim().toLowerCase();
      final value = raw.substring(separatorIndex + 1).trim();
      final loweredValue = value.toLowerCase();

      if (!_allowedStyleKeys.contains(key)) {
        continue;
      }

      if (loweredValue.contains('expression') ||
          loweredValue.contains('javascript:') ||
          loweredValue.contains('url(') ||
          loweredValue.contains('@import')) {
        continue;
      }

      safeDeclarations.add('$key: $value');
    }

    return safeDeclarations.join('; ');
  }

  static String _unwrapQuotes(String value) {
    if (value.length < 2) {
      return value;
    }

    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith('\'') && value.endsWith('\''))) {
      return value.substring(1, value.length - 1);
    }

    return value;
  }

  static String _escapeAttribute(String value) {
    return value.replaceAll('"', '&quot;');
  }
}
