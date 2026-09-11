import 'dart:convert';
import 'dart:math';

class RunnableHtmlSandbox {
  const RunnableHtmlSandbox._();

  static final RegExp _scriptContainers = RegExp(
    r'<\s*script\b[^>]*>[\s\S]*?<\s*/\s*script\s*>',
    caseSensitive: false,
  );
  static final RegExp _scriptTags = RegExp(
    r'<\s*/?\s*script\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _blockedContainers = RegExp(
    r'<\s*(iframe|object|embed)\b[^>]*>[\s\S]*?<\s*/\s*\1\s*>',
    caseSensitive: false,
  );
  static final RegExp _blockedStandaloneTags = RegExp(
    r'<\s*(iframe|object|embed|base|link|meta)\b[^>]*\/?>',
    caseSensitive: false,
  );
  static final RegExp _formTags = RegExp(
    r'<\s*/?\s*form\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _eventAttributes = RegExp(
    r'''\s+on[a-z0-9_-]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)''',
    caseSensitive: false,
  );
  static final RegExp _activeUrlAttributes = RegExp(
    r'''\s+(href|xlink:href|action|formaction|srcdoc)\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)''',
    caseSensitive: false,
  );
  static final RegExp _sourceAttributes = RegExp(
    r'''\s+(src|poster)\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)''',
    caseSensitive: false,
  );

  static String build({
    required String document,
    required String trustedBridgeScript,
  }) {
    final nonce = _createNonce();
    final content = _removeExecutableContent(document);
    final csp = <String>[
      "default-src 'none'",
      "script-src 'nonce-$nonce'",
      "style-src 'unsafe-inline'",
      'img-src data: blob:',
      'media-src data: blob:',
      'font-src data:',
      "connect-src 'none'",
      "frame-src 'none'",
      "worker-src 'none'",
      "object-src 'none'",
      "base-uri 'none'",
      "form-action 'none'",
      "navigate-to 'none'",
    ].join('; ');

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="$csp">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
$content
<script nonce="$nonce">
$trustedBridgeScript
</script>
</body>
</html>
''';
  }

  static String _removeExecutableContent(String document) {
    var sanitized = document;
    sanitized = sanitized.replaceAll(_scriptContainers, '');
    sanitized = sanitized.replaceAll(_scriptTags, '');
    sanitized = sanitized.replaceAll(_blockedContainers, '');
    sanitized = sanitized.replaceAll(_blockedStandaloneTags, '');
    sanitized = sanitized.replaceAll(_formTags, '');
    sanitized = sanitized.replaceAll(_eventAttributes, '');
    sanitized = sanitized.replaceAll(_activeUrlAttributes, '');
    sanitized = sanitized.replaceAllMapped(_sourceAttributes, (match) {
      final rawValue = match.group(2) ?? '';
      final value = _unwrapAttribute(rawValue).trim().toLowerCase();
      if (value.startsWith('data:image/')) {
        return ' ${match.group(1)}=$rawValue';
      }
      return '';
    });
    return sanitized.trim();
  }

  static String _unwrapAttribute(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static String _createNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
