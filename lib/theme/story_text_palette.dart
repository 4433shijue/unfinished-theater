import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// A skin hue adapted to the surface carrying the text, not the theme's name.
class StoryTextPalette {
  const StoryTextPalette(
      {required this.body,
      required this.dialogue,
      required this.emphasis,
      required this.muted,
      required this.background});
  final Color body, dialogue, emphasis, muted, background;

  factory StoryTextPalette.resolve(
      {Color? body,
      List<Color>? backgrounds,
      Color? primary,
      Color? underlay}) {
    final backdrop = opaque(
        underlay ?? AppTheme.panel, AppTheme.activePalette.background.first);
    final surfaces = (backgrounds == null || backgrounds.isEmpty
            ? <Color>[AppTheme.panel]
            : backgrounds)
        .map((c) => opaque(c, backdrop))
        .toList();
    final base = primary ?? AppTheme.activePrimary;
    final dialogue = readable(base, surfaces);
    final normal = body ?? AppTheme.assistantBubbleTextColor;
    return StoryTextPalette(
        body: surfaces.every((bg) => contrast(normal, bg) >= 4.5)
            ? normal
            : readable(normal, surfaces),
        dialogue: dialogue,
        emphasis: readable(base, surfaces),
        muted: readable(Color.lerp(normal, surfaces.first, .22)!, surfaces),
        background: surfaces.first);
  }

  static Color opaque(Color color, Color background) =>
      Color.alphaBlend(color, background.withValues(alpha: 1))
          .withValues(alpha: 1);

  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (math.max(x, y) + .05) / (math.min(x, y) + .05);
  }

  static Color readable(Color seed, List<Color> surfaces) {
    double score(Color color) =>
        surfaces.map((bg) => contrast(color, bg)).reduce(math.min);
    final hsl = HSLColor.fromColor(seed.withValues(alpha: 1));
    final light =
        surfaces.map((c) => c.computeLuminance()).reduce((a, b) => a + b) /
                surfaces.length >
            .35;
    // Maintain hue/saturation. The initial shift gives pastel skins a distinct
    // dialogue color even when the primary just meets the readability target.
    final start =
        light ? math.min(hsl.lightness, .35) : math.max(hsl.lightness, .76);
    var best = hsl.withLightness(start).toColor();
    var bestScore = score(best);
    for (var i = 0; i <= 100; i++) {
      final l = light ? start * (1 - i / 100) : start + (1 - start) * i / 100;
      final candidate = hsl.withLightness(l).toColor();
      final candidateScore = score(candidate);
      if (candidateScore >= 4.5) return candidate;
      if (candidateScore > bestScore) {
        best = candidate;
        bestScore = candidateScore;
      }
    }
    // Mixed custom gradients may have no single 4.5:1 solution. Choose the
    // strongest minimum contrast and retain the hue; never make text invisible.
    for (var i = 0; i <= 100; i++) {
      final candidate = hsl.withLightness(i / 100).toColor();
      final candidateScore = score(candidate);
      if (candidateScore > bestScore) {
        best = candidate;
        bestScore = candidateScore;
      }
    }
    return best;
  }

  Map<String, String> get css => {
        'text': hex(body),
        'dialogue': hex(dialogue),
        'emphasis': hex(emphasis),
        'muted': hex(muted),
        'surface': hex(background),
      };
  static String hex(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
}
