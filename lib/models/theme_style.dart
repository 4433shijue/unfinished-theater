import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'gamification.dart';

class ThemeStyleSpec {
  const ThemeStyleSpec({
    required this.baseThemeId,
    this.background,
    this.brand,
    this.panel,
    this.panelStrong,
    this.panelHighlight,
    this.primary,
    this.secondary,
    this.accent,
    this.soft,
    this.line,
    this.glow,
    this.radius,
    this.shadowBlur,
    this.backgroundEffect,
    this.fontPreset,
  });

  final String baseThemeId;
  final List<Color>? background;
  final List<Color>? brand;
  final Color? panel;
  final Color? panelStrong;
  final Color? panelHighlight;
  final Color? primary;
  final Color? secondary;
  final Color? accent;
  final Color? soft;
  final Color? line;
  final Color? glow;
  final double? radius;
  final double? shadowBlur;
  final String? backgroundEffect;
  final String? fontPreset;

  AppThemePalette applyTo(AppThemePalette base) {
    final resolvedPrimary = primary ?? base.primary;
    final resolvedSecondary = secondary ?? base.secondary;
    final resolvedAccent = accent ?? base.accent;
    final resolvedPanel = panel ?? base.panelEnd;
    final resolvedPanelStrong = panelStrong ?? base.panelStart;
    final resolvedHighlight = panelHighlight ?? base.panelHighlightStart;
    return AppThemePalette(
      background: _ensureGradient(background, base.background),
      brand: _ensureGradient(
        brand,
        <Color>[resolvedPrimary, resolvedSecondary, resolvedAccent],
      ),
      panelStart: resolvedPanelStrong,
      panelEnd: resolvedPanel,
      panelHighlightStart: resolvedHighlight,
      panelHighlightEnd: panelHighlight ?? base.panelHighlightEnd,
      primary: resolvedPrimary,
      secondary: resolvedSecondary,
      accent: resolvedAccent,
      soft: soft ?? base.soft,
      line: line ?? base.line,
      glow: glow ?? accent ?? primary ?? base.glow,
    );
  }

  static ThemeStyleSpec? fromCss(
    String css, {
    required String baseThemeId,
  }) {
    final trimmed = css.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final declarations = <String, String>{};
    final blocks = RegExp(r'([^{]+)\{([^}]*)\}', dotAll: true).allMatches(css);
    for (final block in blocks) {
      final selector = (block.group(1) ?? '').toLowerCase();
      if (!selector.contains('.theme') && !selector.contains(':root')) {
        continue;
      }
      final body = block.group(2) ?? '';
      for (final declaration in body.split(';')) {
        final index = declaration.indexOf(':');
        if (index <= 0) {
          continue;
        }
        final key = declaration.substring(0, index).trim().toLowerCase();
        final value = declaration.substring(index + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          declarations[key] = value;
        }
      }
    }

    Color? color(String key) => _parseColor(declarations[key]);
    List<Color>? gradient(String key) => _parseColorList(declarations[key]);
    double? number(String key) => _parseNumber(declarations[key]);
    String? token(String key) => declarations[key]?.trim();

    return ThemeStyleSpec(
      baseThemeId: baseThemeId,
      background: gradient('--background') ?? gradient('background'),
      brand: gradient('--brand'),
      panel: color('--panel'),
      panelStrong: color('--panel-strong'),
      panelHighlight: color('--panel-highlight'),
      primary: color('--primary'),
      secondary: color('--secondary'),
      accent: color('--accent') ?? color('accent-color'),
      soft: color('--soft'),
      line: color('--line') ?? color('--border'),
      glow: color('--glow'),
      radius: number('--radius') ?? number('border-radius'),
      shadowBlur: _parseShadowBlur(declarations['--shadow']) ??
          _parseShadowBlur(declarations['box-shadow']),
      backgroundEffect: token('--background-effect'),
      fontPreset: token('--font-preset'),
    );
  }

  static ThemeStyleSpec? fromCustom(CustomThemeStyle style) {
    return ThemeStyleSpec.fromCss(
      style.css,
      baseThemeId: style.baseThemeId,
    );
  }
}

const String customThemeCssExample = '''
.theme {
  --background: #f7f1ea, #eef4e8, #f4e8ee, #e8eef6;
  --brand: #8aa38d, #b98f98, #8f9fbd;
  --panel: rgba(255, 252, 246, 0.86);
  --panel-strong: rgba(255, 255, 255, 0.92);
  --panel-highlight: rgba(241, 232, 222, 0.92);
  --primary: #8a9f7d;
  --secondary: #b98f98;
  --accent: #8f9fbd;
  --soft: #dfead9;
  --line: rgba(101, 113, 92, 0.28);
  --glow: #9eb28d;
  --radius: 24px;
  --shadow: 0 18px 42px rgba(83, 78, 60, 0.16);
  --background-effect: cloud;
  --font-preset: system;
}
''';

List<Color> _ensureGradient(List<Color>? value, List<Color> fallback) {
  final source = value == null || value.isEmpty ? fallback : value;
  if (source.length >= 4) {
    return source.take(4).toList(growable: false);
  }
  if (source.length == 3) {
    return <Color>[source[0], source[1], source[2], source[2]];
  }
  if (source.length == 2) {
    return <Color>[source[0], source[1], source[0], source[1]];
  }
  return <Color>[source.first, source.first, source.first, source.first];
}

List<Color>? _parseColorList(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final colors = <Color>[];
  for (final match in RegExp(
    r'#[0-9a-fA-F]{6,8}|rgba?\([^)]*\)',
  ).allMatches(raw)) {
    final color = _parseColor(match.group(0));
    if (color != null) {
      colors.add(color);
    }
  }
  if (colors.isNotEmpty) {
    return colors;
  }
  return null;
}

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

double? _parseNumber(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final match = RegExp(r'-?[0-9]+(?:\.[0-9]+)?').firstMatch(raw);
  return double.tryParse(match?.group(0) ?? '');
}

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

int _clampColor(double? value) => (value ?? 0).clamp(0, 255).round();
