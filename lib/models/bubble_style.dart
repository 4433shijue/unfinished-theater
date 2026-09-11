import 'package:flutter/material.dart';

import 'gamification.dart';

class BubbleStyleSpec {
  const BubbleStyleSpec({
    this.backgroundColor,
    this.userBackgroundColor,
    this.assistantBackgroundColor,
    this.borderColor,
    this.userBorderColor,
    this.assistantBorderColor,
    this.textColor,
    this.userTextColor,
    this.assistantTextColor,
    this.accentColor,
    this.borderWidth,
    this.borderRadius,
    this.shadowBlur,
    this.shadowColor,
    this.decorationText,
    this.decorationOpacity,
    this.decorationSize,
  });

  final Color? backgroundColor;
  final Color? userBackgroundColor;
  final Color? assistantBackgroundColor;
  final Color? borderColor;
  final Color? userBorderColor;
  final Color? assistantBorderColor;
  final Color? textColor;
  final Color? userTextColor;
  final Color? assistantTextColor;
  final Color? accentColor;
  final double? borderWidth;
  final double? borderRadius;
  final double? shadowBlur;
  final Color? shadowColor;
  final String? decorationText;
  final double? decorationOpacity;
  final double? decorationSize;

  Color? backgroundFor(bool isUser) => isUser
      ? userBackgroundColor ?? backgroundColor
      : assistantBackgroundColor ?? backgroundColor;

  Color? borderFor(bool isUser) => isUser
      ? userBorderColor ?? borderColor
      : assistantBorderColor ?? borderColor;

  Color? textFor(bool isUser) =>
      isUser ? userTextColor ?? textColor : assistantTextColor ?? textColor;

  static BubbleStyleSpec? fromCss(String css) {
    final trimmed = css.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final declarations = <String, String>{};
    final blocks = RegExp(r'([^{]+)\{([^}]*)\}', dotAll: true).allMatches(css);
    for (final block in blocks) {
      final selector = (block.group(1) ?? '').toLowerCase();
      final body = block.group(2) ?? '';
      final prefix = selector.contains('.user')
          ? 'user.'
          : selector.contains('.assistant')
              ? 'assistant.'
              : '';
      for (final declaration in body.split(';')) {
        final index = declaration.indexOf(':');
        if (index <= 0) {
          continue;
        }
        final key = declaration.substring(0, index).trim().toLowerCase();
        final value = declaration.substring(index + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          declarations['$prefix$key'] = value;
        }
      }
    }

    Color? color(String key) => _parseColor(declarations[key]);
    double? number(String key) => _parseNumber(declarations[key]);
    String? content(String key) => _parseContent(declarations[key]);

    return BubbleStyleSpec(
      backgroundColor: color('background-color') ?? color('background'),
      userBackgroundColor:
          color('user.background-color') ?? color('user.background'),
      assistantBackgroundColor:
          color('assistant.background-color') ?? color('assistant.background'),
      borderColor:
          color('border-color') ?? _parseBorderColor(declarations['border']),
      userBorderColor: color('user.border-color') ??
          _parseBorderColor(declarations['user.border']),
      assistantBorderColor: color('assistant.border-color') ??
          _parseBorderColor(declarations['assistant.border']),
      textColor: color('color'),
      userTextColor: color('user.color'),
      assistantTextColor: color('assistant.color'),
      accentColor: color('--accent') ?? color('accent-color'),
      borderWidth:
          number('border-width') ?? _parseBorderWidth(declarations['border']),
      borderRadius: number('border-radius'),
      shadowBlur: _parseShadowBlur(declarations['box-shadow']),
      shadowColor: _parseShadowColor(declarations['box-shadow']),
      decorationText: content('content') ??
          content('--decoration') ??
          content('decoration'),
      decorationOpacity: number('opacity') ?? number('--decoration-opacity'),
      decorationSize: number('font-size') ?? number('--decoration-size'),
    );
  }

  static BubbleStyleSpec? fromCustom(
    List<CustomBubbleStyle> styles,
    String frameId,
  ) {
    for (final style in styles) {
      if (style.id == frameId) {
        return BubbleStyleSpec.fromCss(style.css);
      }
    }
    return null;
  }
}

const String customBubbleCssExample = '''
.bubble {
  background-color: #fff8ec;
  border: 2.4px solid #c9965b;
  border-radius: 24px;
  color: #32251f;
  box-shadow: 0 14px 30px rgba(124, 86, 48, 0.18);
  --decoration: "✦";
  --decoration-opacity: 0.28;
  --decoration-size: 30px;
}

.bubble.assistant {
  background-color: #fffaf2;
  border-color: #d5a86e;
}

.bubble.user {
  background-color: #f1d7ad;
  border-color: #b87b45;
  color: #2d211c;
}
''';

Color? _parseColor(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final hex = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})').firstMatch(raw);
  if (hex != null) {
    final token = hex.group(1)!;
    final value = int.tryParse(token, radix: 16);
    if (value == null) {
      return null;
    }
    return token.length == 6 ? Color(0xFF000000 | value) : Color(value);
  }
  final rgba = RegExp(
    r'rgba?\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)(?:\s*,\s*([0-9.]+))?\s*\)',
  ).firstMatch(raw);
  if (rgba != null) {
    final r = _clampColor(double.tryParse(rgba.group(1) ?? ''));
    final g = _clampColor(double.tryParse(rgba.group(2) ?? ''));
    final b = _clampColor(double.tryParse(rgba.group(3) ?? ''));
    final a = ((double.tryParse(rgba.group(4) ?? '1') ?? 1).clamp(0, 1) * 255)
        .round();
    return Color.fromARGB(a, r, g, b);
  }
  return switch (raw.toLowerCase()) {
    'white' => Colors.white,
    'black' => Colors.black,
    'transparent' => Colors.transparent,
    _ => null,
  };
}

Color? _parseBorderColor(String? value) => _parseColor(value);

Color? _parseShadowColor(String? value) => _parseColor(value);

double? _parseNumber(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final match = RegExp(r'-?[0-9]+(?:\.[0-9]+)?').firstMatch(raw);
  return double.tryParse(match?.group(0) ?? '');
}

double? _parseBorderWidth(String? value) => _parseNumber(value);

double? _parseShadowBlur(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final numbers = RegExp(r'-?[0-9]+(?:\.[0-9]+)?')
      .allMatches(value)
      .map((item) => double.tryParse(item.group(0) ?? '') ?? 0)
      .toList(growable: false);
  if (numbers.length >= 3) {
    return numbers[2];
  }
  return null;
}

String? _parseContent(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final startsWithQuote = raw.startsWith('"') || raw.startsWith("'");
  final endsWithQuote = raw.endsWith('"') || raw.endsWith("'");
  if (startsWithQuote && endsWithQuote && raw.length >= 2) {
    return raw.substring(1, raw.length - 1).trim();
  }
  return raw;
}

int _clampColor(double? value) => (value ?? 0).clamp(0, 255).round();
