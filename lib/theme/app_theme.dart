import 'dart:convert';

import 'package:flutter/material.dart';

import 'theme_skin_assets.dart';

class AppThemePalette {
  const AppThemePalette({
    required this.background,
    required this.brand,
    required this.panelStart,
    required this.panelEnd,
    required this.panelHighlightStart,
    required this.panelHighlightEnd,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.soft,
    required this.line,
    required this.glow,
  });

  final List<Color> background;
  final List<Color> brand;
  final Color panelStart;
  final Color panelEnd;
  final Color panelHighlightStart;
  final Color panelHighlightEnd;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color soft;
  final Color line;
  final Color glow;
}

class RuntimeThemeDefinition {
  const RuntimeThemeDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.baseThemeId,
    required this.palette,
    this.radius,
    this.shadowBlur,
    this.backgroundEffect,
    this.fontPreset,
  });

  final String id;
  final String label;
  final String description;
  final String baseThemeId;
  final AppThemePalette palette;
  final double? radius;
  final double? shadowBlur;
  final String? backgroundEffect;
  final String? fontPreset;
}

class AppThemeDescriptor {
  const AppThemeDescriptor({
    required this.id,
    required this.label,
    required this.description,
    required this.baseVariant,
    required this.palette,
    required this.isRuntimeTheme,
    this.backgroundEffect,
  });

  final String id;
  final String label;
  final String description;
  final AppThemeVariant baseVariant;
  final AppThemePalette palette;
  final bool isRuntimeTheme;
  final String? backgroundEffect;
}

enum AppThemeVariant {
  sakura(
    id: 'sakura',
    label: '雾粉紫',
    description: '雾粉、灰紫和浅蓝的低饱和渐变，清透但不刺眼。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFFF7EEF3),
        Color(0xFFF6F1F5),
        Color(0xFFECE7F3),
        Color(0xFFE8EEF6),
      ],
      brand: <Color>[
        Color(0xFFB9899E),
        Color(0xFF9F93BD),
        Color(0xFF8CA8BD),
      ],
      panelStart: Color(0xDFFFFFFF),
      panelEnd: Color(0xC9FFFFFF),
      panelHighlightStart: Color(0xEEEFE3EA),
      panelHighlightEnd: Color(0xE3E8E3F0),
      primary: Color(0xFFB9899E),
      secondary: Color(0xFF9F93BD),
      accent: Color(0xFF8CA8BD),
      soft: Color(0xFFF3E7ED),
      line: Color(0x337A7180),
      glow: Color(0xFFB9899E),
    ),
  ),
  sunset(
    id: 'sunset',
    label: '杏桃日落',
    description: '杏桃、玫瑰灰和麦穗金的暖色渐变，像傍晚软光。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFFF6EADF),
        Color(0xFFF3E6DF),
        Color(0xFFF1E1DF),
        Color(0xFFE8E2D8),
      ],
      brand: <Color>[
        Color(0xFFC28F7C),
        Color(0xFFBD8D92),
        Color(0xFFBDA26F),
      ],
      panelStart: Color(0xDFFFFFFF),
      panelEnd: Color(0xC9FFFFFF),
      panelHighlightStart: Color(0xEEF2DFD8),
      panelHighlightEnd: Color(0xE3EBDADC),
      primary: Color(0xFFC28F7C),
      secondary: Color(0xFFBD8D92),
      accent: Color(0xFFBDA26F),
      soft: Color(0xFFF1DDD3),
      line: Color(0x33806C64),
      glow: Color(0xFFC28F7C),
    ),
  ),
  daybreak(
    id: 'daybreak',
    label: '雾蓝破晓',
    description: '雾蓝、燕麦和淡紫灰交错，保留清晨的轻盈感。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFFE8F0F4),
        Color(0xFFEAF0EE),
        Color(0xFFEDF0E8),
        Color(0xFFF2E7DF),
      ],
      brand: <Color>[
        Color(0xFF7F9DAF),
        Color(0xFFC0A28A),
        Color(0xFFA79AB5),
      ],
      panelStart: Color(0xDFFFFFFF),
      panelEnd: Color(0xC9FFFFFF),
      panelHighlightStart: Color(0xEEDDE9EE),
      panelHighlightEnd: Color(0xE3EDE6DD),
      primary: Color(0xFF7F9DAF),
      secondary: Color(0xFFC0A28A),
      accent: Color(0xFFA79AB5),
      soft: Color(0xFFDDE8EE),
      line: Color(0x33677280),
      glow: Color(0xFF7F9DAF),
    ),
  ),
  mint(
    id: 'mint',
    label: '鼠尾草薄荷',
    description: '鼠尾草绿、粉豆沙和雾青色，清新又安静。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFFE9F1E8),
        Color(0xFFE7EFED),
        Color(0xFFEDF0E5),
        Color(0xFFF2E8EC),
      ],
      brand: <Color>[
        Color(0xFF84A891),
        Color(0xFFC49AAC),
        Color(0xFF86A9A8),
      ],
      panelStart: Color(0xDFFFFFFF),
      panelEnd: Color(0xC9FFFFFF),
      panelHighlightStart: Color(0xEEDBE9DC),
      panelHighlightEnd: Color(0xE3E9DEE4),
      primary: Color(0xFF84A891),
      secondary: Color(0xFFC49AAC),
      accent: Color(0xFF86A9A8),
      soft: Color(0xFFDDEBDC),
      line: Color(0x33687869),
      glow: Color(0xFF84A891),
    ),
  ),
  moonLemon(
    id: 'moon_lemon',
    label: '月柠浅雾',
    description: '浅柠檬、灰紫和雾绿的柔和搭配，明亮但不荧光。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFFF5F0DA),
        Color(0xFFEFE9E4),
        Color(0xFFECE7F0),
        Color(0xFFE8ECE2),
      ],
      brand: <Color>[
        Color(0xFFB7A86F),
        Color(0xFFA99ABD),
        Color(0xFF8FA69C),
      ],
      panelStart: Color(0xDFFFFFFF),
      panelEnd: Color(0xC9FFFFFF),
      panelHighlightStart: Color(0xEEF2EBD1),
      panelHighlightEnd: Color(0xE3E6E0EE),
      primary: Color(0xFFB7A86F),
      secondary: Color(0xFFA99ABD),
      accent: Color(0xFF8FA69C),
      soft: Color(0xFFF0E8C7),
      line: Color(0x337B7560),
      glow: Color(0xFFB7A86F),
    ),
  ),
  forestBerry(
    id: 'forest_berry',
    label: '森林莓晨露',
    description: '莓果粉、晨露绿和一点灰紫的清甜感，和薄荷主题拉开差异。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFFF8E1EA),
        Color(0xFFF4D6E5),
        Color(0xFFE9F3DE),
        Color(0xFFE7E1F0),
      ],
      brand: <Color>[
        Color(0xFFD86F9B),
        Color(0xFF8FBF7C),
        Color(0xFFA889C6),
      ],
      panelStart: Color(0xDFFFFFFF),
      panelEnd: Color(0xC9FFFFFF),
      panelHighlightStart: Color(0xEEF6DCE8),
      panelHighlightEnd: Color(0xE3E3F0D6),
      primary: Color(0xFFD86F9B),
      secondary: Color(0xFF8FBF7C),
      accent: Color(0xFFA889C6),
      soft: Color(0xFFF2D2DF),
      line: Color(0x338A5570),
      glow: Color(0xFFD86F9B),
    ),
  ),
  aprilFools(
    id: 'april_fools',
    label: '愚人节特调',
    description: '？？？',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFF050607),
        Color(0xFF0A0F1A),
        Color(0xFF170708),
        Color(0xFF000000),
      ],
      brand: <Color>[
        Color(0xFFFF3131),
        Color(0xFFB3FF8F),
        Color(0xFFFFCC66),
      ],
      panelStart: Color(0xD0030207),
      panelEnd: Color(0xCC120606),
      panelHighlightStart: Color(0xEA1F0A0A),
      panelHighlightEnd: Color(0xD70C0C0C),
      primary: Color(0xFFFF4444),
      secondary: Color(0xFFB3FF8F),
      accent: Color(0xFFFFCC66),
      soft: Color(0xFFB3FF8F),
      line: Color(0xD6FF6666),
      glow: Color(0xFFFF0000),
    ),
  ),
  cthulhu(
    id: 'cthulhu',
    label: '深渊观测站',
    description: '祂在凝视你。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFF050000),
        Color(0xFF170405),
        Color(0xFF090101),
        Color(0xFF000000),
      ],
      brand: <Color>[
        Color(0xFF9D3832),
        Color(0xFFCE8F69),
        Color(0xFFABC69A),
      ],
      panelStart: Color(0xE6110405),
      panelEnd: Color(0xF51B0607),
      panelHighlightStart: Color(0xF01F0708),
      panelHighlightEnd: Color(0xE40B0203),
      primary: Color(0xFF9D3832),
      secondary: Color(0xFFCE8F69),
      accent: Color(0xFFABC69A),
      soft: Color(0xFFDED1C5),
      line: Color(0x99881F1F),
      glow: Color(0xFF701414),
    ),
  ),
  riftRelay(
    id: 'rift_relay',
    label: '裂隙中转站',
    description: '世界线已接入，宿主请就位。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFF050607),
        Color(0xFF151719),
        Color(0xFF10141A),
        Color(0xFF000000),
      ],
      brand: <Color>[
        Color(0xFFC4CCD6),
        Color(0xFF8AA6B1),
        Color(0xFF00D5FF),
      ],
      panelStart: Color(0xE6131518),
      panelEnd: Color(0xF51C1F24),
      panelHighlightStart: Color(0xEE22272F),
      panelHighlightEnd: Color(0xE40D1014),
      primary: Color(0xFFC4CCD6),
      secondary: Color(0xFF8AA6B1),
      accent: Color(0xFF00D5FF),
      soft: Color(0xFFD6DBE2),
      line: Color(0x75C7CFDB),
      glow: Color(0xFF00D5FF),
    ),
  ),
  flowerNotFlower(
    id: 'flower_not_flower',
    label: '花非花',
    description: '夜半来，天明去。来如春梦几多时，去似朝云无觅处。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFFEEE9E2),
        Color(0xFFF8F4EC),
        Color(0xFFEDE5DC),
        Color(0xFFF6F0E8),
      ],
      brand: <Color>[
        Color(0xFFA67A7B),
        Color(0xFFC1ADA8),
        Color(0xFF778D7A),
      ],
      panelStart: Color(0xEEFFFDF8),
      panelEnd: Color(0xEAF4EDE5),
      panelHighlightStart: Color(0xF8FFFCF6),
      panelHighlightEnd: Color(0xEEECE1D8),
      primary: Color(0xFFA67A7B),
      secondary: Color(0xFFC1ADA8),
      accent: Color(0xFF778D7A),
      soft: Color(0xFF7B605E),
      line: Color(0x50483A32),
      glow: Color(0xFFA67A7B),
    ),
  ),
  mechanicalCity(
    id: 'mechanical_city',
    label: '机械迷城',
    description: '齿轮咬合处，故事开始转动。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFF15100B),
        Color(0xFF2A2119),
        Color(0xFF33251A),
        Color(0xFF0E0B08),
      ],
      brand: <Color>[
        Color(0xFFB77B35),
        Color(0xFFD8AD62),
        Color(0xFF6F4329),
      ],
      panelStart: Color(0xD62A2119),
      panelEnd: Color(0xC91A140F),
      panelHighlightStart: Color(0xDD3A2C1D),
      panelHighlightEnd: Color(0xCC241A12),
      primary: Color(0xFFB77B35),
      secondary: Color(0xFF6F4329),
      accent: Color(0xFFD8AD62),
      soft: Color(0xFFEAD7B9),
      line: Color(0x88C7934B),
      glow: Color(0xFFB77B35),
    ),
  ),
  rainRadio(
    id: 'rain_radio',
    label: '雨巷电台',
    description: '雨声里，有人正调到你的频率。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFF07121A),
        Color(0xFF102333),
        Color(0xFF172C3B),
        Color(0xFF071018),
      ],
      brand: <Color>[
        Color(0xFF9BBDCA),
        Color(0xFF4E768B),
        Color(0xFFD7EBF2),
      ],
      panelStart: Color(0xD6132736),
      panelEnd: Color(0xC90B1823),
      panelHighlightStart: Color(0xDD1B3344),
      panelHighlightEnd: Color(0xCC132331),
      primary: Color(0xFF9BBDCA),
      secondary: Color(0xFF4E768B),
      accent: Color(0xFFD7EBF2),
      soft: Color(0xFFE5F4F8),
      line: Color(0x8892B4C1),
      glow: Color(0xFF9BBDCA),
    ),
  ),
  skyPasture(
    id: 'sky_pasture',
    label: '晴空牧场',
    description: '云影很慢，草坡很亮，今天也适合把故事放出来晒晒太阳。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFFEAF8FF),
        Color(0xFFF9F3DA),
        Color(0xFFDDEFCF),
        Color(0xFFF8FCFF),
      ],
      brand: <Color>[
        Color(0xFF6FAFCD),
        Color(0xFF91C58E),
        Color(0xFFF1C96E),
      ],
      panelStart: Color(0xEEFFFFFF),
      panelEnd: Color(0xDDF4FBFF),
      panelHighlightStart: Color(0xF7FFFFFF),
      panelHighlightEnd: Color(0xEAF6EECF),
      primary: Color(0xFF6FAFCD),
      secondary: Color(0xFF91C58E),
      accent: Color(0xFFF1C96E),
      soft: Color(0xFF2F6F7D),
      line: Color(0x5593B8A5),
      glow: Color(0xFF8FC6E0),
    ),
  ),
  vinylMemories(
    id: 'vinyl_memories',
    label: '黑胶往事',
    description: '唱针落下，旧日咖啡馆的灯重新亮起。',
    palette: AppThemePalette(
      background: <Color>[
        Color(0xFF211409),
        Color(0xFF4A3120),
        Color(0xFF2D1A0F),
        Color(0xFF120A06),
      ],
      brand: <Color>[
        Color(0xFFE0B56F),
        Color(0xFF9B6038),
        Color(0xFFFFD796),
      ],
      panelStart: Color(0xE9472D1A),
      panelEnd: Color(0xF02A190E),
      panelHighlightStart: Color(0xF05A3A22),
      panelHighlightEnd: Color(0xE6352115),
      primary: Color(0xFFE0B56F),
      secondary: Color(0xFF9B6038),
      accent: Color(0xFFFFD796),
      soft: Color(0xFFF8E1B5),
      line: Color(0x88C69354),
      glow: Color(0xFFE0B56F),
    ),
  );

  const AppThemeVariant({
    required this.id,
    required this.label,
    required this.description,
    required this.palette,
  });

  final String id;
  final String label;
  final String description;
  final AppThemePalette palette;

  static AppThemeVariant byId(String? id) {
    for (final variant in values) {
      if (variant.id == id) {
        return variant;
      }
    }
    return AppThemeVariant.sakura;
  }

  static bool hasId(String? id) {
    for (final variant in values) {
      if (variant.id == id) {
        return true;
      }
    }
    return false;
  }

  bool get isSketchy => this == AppThemeVariant.aprilFools;

  bool get isCorrupt => this == AppThemeVariant.aprilFools;

  bool get isEldritch => this == AppThemeVariant.cthulhu;

  bool get isTerminal => this == AppThemeVariant.riftRelay;

  bool get isFlower => this == AppThemeVariant.flowerNotFlower;

  bool get isMechanical => this == AppThemeVariant.mechanicalCity;

  bool get isRainRadio => this == AppThemeVariant.rainRadio;

  bool get isPasture => this == AppThemeVariant.skyPasture;

  bool get isVinyl => this == AppThemeVariant.vinylMemories;

  bool get isBasicPalette =>
      this == AppThemeVariant.sakura ||
      this == AppThemeVariant.sunset ||
      this == AppThemeVariant.daybreak ||
      this == AppThemeVariant.mint ||
      this == AppThemeVariant.moonLemon ||
      this == AppThemeVariant.forestBerry;

  int get unlockCost => this == AppThemeVariant.riftRelay ||
          isFlower ||
          isMechanical ||
          isRainRadio ||
          isPasture ||
          isVinyl
      ? 100
      : 0;
}

class AppTheme {
  const AppTheme._();

  static const Color night = Color(0xFF120B1E);
  static const Color nightSoft = Color(0xFF1A1430);
  static Color get panel => _activePalette.panelEnd;
  static Color get panelSoft => _activePalette.panelStart;
  static const Color primaryPink = Color(0xFFF06FD3);
  static const Color primaryPurple = Color(0xFFB071EA);
  static const Color secondaryBlue = Color(0xFF7E8CF4);
  static const Color cyanGlow = Color(0xFF78D9F4);
  static const Color blush = Color(0xFFF3C4EC);
  static Color get textMain => isFlowerMode
      ? const Color(0xFF1A1816)
      : isBasicPaletteMode
          ? const Color(0xFF1D1A1C)
          : isPastureMode
              ? const Color(0xFF274C55)
              : isVinylMode
                  ? const Color(0xFFF4E1BE)
                  : isEldritchMode
                      ? const Color(0xFFDED1C5)
                      : isTerminalMode
                          ? const Color(0xFFD6DBE2)
                          : isMechanicalMode
                              ? const Color(0xFFECE4D3)
                              : isRainRadioMode
                                  ? const Color(0xFFEAF4FF)
                                  : const Color(0xFFF6F0FB);
  static Color get textMuted => isFlowerMode
      ? const Color(0xFF625852)
      : isBasicPaletteMode
          ? const Color(0xFF6B6568)
          : isPastureMode
              ? const Color(0xFF537074)
              : isVinylMode
                  ? const Color(0xFFD1B17C)
                  : isEldritchMode
                      ? const Color(0xFFB98F81)
                      : isTerminalMode
                          ? const Color(0xFF9AA4AF)
                          : isMechanicalMode
                              ? const Color(0xFFC9B48D)
                              : isRainRadioMode
                                  ? const Color(0xFFB9CDDC)
                                  : const Color(0xFFC8BEDB);
  static Color get textWeak => isFlowerMode
      ? const Color(0xFF8A7D73)
      : isBasicPaletteMode
          ? const Color(0xFF8B858C)
          : isPastureMode
              ? const Color(0xFF7D8D83)
              : isVinylMode
                  ? const Color(0xFFB58C58)
                  : isEldritchMode
                      ? const Color(0xFF9C6B62)
                      : isTerminalMode
                          ? const Color(0xFF78838F)
                          : isMechanicalMode
                              ? const Color(0xFF8E9A98)
                              : isRainRadioMode
                                  ? const Color(0xFF9FB0C3)
                                  : const Color(0xFF9D90B8);
  static bool get isLightPaletteMode =>
      isFlowerMode || isPastureMode || isBasicPaletteMode;
  static Color get contrastText => isLightPaletteMode ? textMain : Colors.white;
  static Color get contrastTextMuted =>
      isLightPaletteMode ? textMuted : Colors.white.withValues(alpha: 0.82);
  static Color get contrastTextWeak =>
      isLightPaletteMode ? textWeak : Colors.white.withValues(alpha: 0.68);
  static Color get translucentPanelFill => isLightPaletteMode
      ? Colors.black.withValues(alpha: 0.035)
      : Colors.white.withValues(alpha: 0.04);
  static Color get translucentPanelFillStrong => isLightPaletteMode
      ? Colors.black.withValues(alpha: 0.055)
      : Colors.white.withValues(alpha: 0.065);
  static Color get selectedTintText => isLightPaletteMode
      ? textMain
      : isTerminalMode
          ? const Color(0xFFE6EEF4)
          : Colors.white;
  static Color get selectedTintIcon =>
      isLightPaletteMode ? activePrimary : activeSoft;
  static Color get assistantNameTextColor =>
      isLightPaletteMode ? textMain : Colors.white.withValues(alpha: 0.94);
  static Color get assistantBubbleTextColor => isFlowerMode
      ? const Color(0xFF1F1B18)
      : isPastureMode
          ? const Color(0xFF274C55)
          : isVinylMode
              ? const Color(0xFF3D2B1E)
              : isBasicPaletteMode
                  ? const Color(0xFF2C282A)
                  : Colors.white;
  static Color get line => _activePalette.line;

  static AppThemePalette _activePalette = AppThemeVariant.sakura.palette;
  static AppThemeVariant _activeVariant = AppThemeVariant.sakura;
  static RuntimeThemeDefinition? _activeRuntimeTheme;
  static final Map<String, RuntimeThemeDefinition> _runtimeThemes =
      <String, RuntimeThemeDefinition>{};

  static final ThemeData neonTheme = themeFor(AppThemeVariant.sakura.id);

  static AppThemePalette get activePalette => _activePalette;

  static Color get activePrimary => _activePalette.primary;
  static Color get activeSecondary => _activePalette.secondary;
  static Color get activeAccent => _activePalette.accent;
  static Color get activeSoft =>
      isBasicPaletteMode ? _activePalette.primary : _activePalette.soft;
  static Color get activeSubtle => _activePalette.soft;
  static Color get activeLine => _activePalette.line;
  static Color get activeGlow => _activePalette.glow;
  static bool get isCorruptMode => _activeVariant.isCorrupt;
  static bool get isEldritchMode => _activeVariant.isEldritch;
  static bool get isTerminalMode => _activeVariant.isTerminal;
  static bool get isFlowerMode => _activeVariant.isFlower;
  static bool get isMechanicalMode => _activeVariant.isMechanical;
  static bool get isRainRadioMode => _activeVariant.isRainRadio;
  static bool get isPastureMode => _activeVariant.isPasture;
  static bool get isVinylMode => _activeVariant.isVinyl;
  static bool get isBasicPaletteMode => _activeVariant.isBasicPalette;
  static bool get isRuntimeThemeMode => _activeRuntimeTheme != null;
  static String? get activePresetThemeId =>
      _activeRuntimeTheme == null ? _activeVariant.id : null;
  static bool get usesPresetBackdropArtwork {
    final themeId = activePresetThemeId;
    return themeId != null && ThemeSkinAssets.hasBackdrop(themeId);
  }

  static bool get usesRasterWideButtonArtwork {
    final themeId = activePresetThemeId;
    return themeId != null && ThemeSkinAssets.hasWideButtonArtwork(themeId);
  }

  static bool get usesRasterIconButtonArtwork {
    final themeId = activePresetThemeId;
    return themeId != null && ThemeSkinAssets.hasIconButtonArtwork(themeId);
  }

  static bool get usesRasterButtonArtwork =>
      usesRasterWideButtonArtwork || usesRasterIconButtonArtwork;

  static bool hasRuntimeTheme(String id) => _runtimeThemes.containsKey(id);

  static RuntimeThemeDefinition? runtimeThemeById(String id) =>
      _runtimeThemes[id];

  static AppThemeDescriptor describeTheme(String themeId) {
    final runtimeTheme = _runtimeThemes[themeId];
    if (runtimeTheme != null) {
      return AppThemeDescriptor(
        id: runtimeTheme.id,
        label: runtimeTheme.label,
        description: runtimeTheme.description,
        baseVariant: AppThemeVariant.byId(runtimeTheme.baseThemeId),
        palette: runtimeTheme.palette,
        isRuntimeTheme: true,
        backgroundEffect: runtimeTheme.backgroundEffect,
      );
    }

    final variant = AppThemeVariant.byId(themeId);
    return AppThemeDescriptor(
      id: variant.id,
      label: variant.label,
      description: variant.description,
      baseVariant: variant,
      palette: variant.palette,
      isRuntimeTheme: false,
    );
  }

  static void registerRuntimeThemes(Iterable<RuntimeThemeDefinition> themes) {
    _runtimeThemes
      ..clear()
      ..addEntries(themes.map((theme) => MapEntry(theme.id, theme)));
  }

  static ThemeData themeFor(String themeId) {
    final runtimeTheme = _runtimeThemes[themeId];
    if (runtimeTheme != null) {
      final base = AppThemeVariant.byId(runtimeTheme.baseThemeId);
      _activeVariant = base;
      _activeRuntimeTheme = runtimeTheme;
      _activePalette = runtimeTheme.palette;
      return _buildNeonTheme(
        runtimeTheme.palette,
        sketchy: base.isSketchy,
        eldritch: base.isEldritch,
        terminal: base.isTerminal,
        flower: base.isFlower,
        mechanical: base.isMechanical,
        rainRadio: base.isRainRadio,
        pasture: base.isPasture,
        vinyl: base.isVinyl,
        basicPalette: base.isBasicPalette,
      );
    }
    final variant = AppThemeVariant.byId(themeId);
    _activeVariant = variant;
    _activeRuntimeTheme = null;
    _activePalette = variant.palette;
    return _buildNeonTheme(
      variant.palette,
      sketchy: variant.isSketchy,
      eldritch: variant.isEldritch,
      terminal: variant.isTerminal,
      flower: variant.isFlower,
      mechanical: variant.isMechanical,
      rainRadio: variant.isRainRadio,
      pasture: variant.isPasture,
      vinyl: variant.isVinyl,
      basicPalette: variant.isBasicPalette,
      skinThemeId: ThemeSkinAssets.hasBackdrop(variant.id) ? variant.id : null,
    );
  }

  static ThemeData highContrastThemeFor(String themeId) {
    final base = themeFor(themeId);
    final dark = base.brightness == Brightness.dark;
    final foreground = dark ? Colors.white : Colors.black;
    final background = dark ? Colors.black : Colors.white;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surface: background,
        onSurface: foreground,
        outline: foreground,
        outlineVariant: foreground.withValues(alpha: 0.72),
      ),
      dividerColor: foreground.withValues(alpha: 0.78),
      focusColor: base.colorScheme.primary.withValues(alpha: 0.55),
      textTheme: base.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
    );
  }

  static String glitchText(String text) {
    if (isEldritchMode) {
      return _eldritchText(text);
    }
    if (isTerminalMode) {
      return _terminalText(text);
    }
    if (isFlowerMode) {
      return _flowerText(text);
    }
    if (isMechanicalMode) {
      return _mechanicalText(text);
    }
    if (isRainRadioMode) {
      return _rainRadioText(text);
    }
    if (isPastureMode) {
      return _pastureText(text);
    }
    if (isVinylMode) {
      return _vinylText(text);
    }
    if (!isCorruptMode || text.trim().isEmpty) {
      return text;
    }
    try {
      final corrupted = latin1.decode(utf8.encode(text), allowInvalid: true);
      if (corrupted == text) {
        return 'ERR::$text::0x${text.length.toRadixString(16).padLeft(2, '0')}';
      }
      return corrupted;
    } catch (_) {
      return text;
    }
  }

  static String _mappedText(String text, Map<String, String> exact) {
    if (text.trim().isEmpty) {
      return text;
    }
    return exact[text] ?? text;
  }

  static String _eldritchText(String text) {
    const exact = <String, String>{
      '对话': '低语',
      '角色': '化身',
      '用户': '调查员',
      '设置': '仪式设定',
      '故事控制台': '低语回廊',
      '角色档案': '化身名录',
      '用户人设': '调查员手册',
      '应用设置': '仪式设定',
      '小游戏中心': '深渊市集',
      '剧情工具箱': '仪式工具箱',
      '同人文': '异闻手稿',
      '地图主线': '迷雾航路',
      '进入地图': '进入迷雾航路',
      '打开地图': '展开迷雾图',
      '下一回合': '下一次低语',
      '显示面板': '显影封印',
      '隐藏面板': '隐匿封印',
      '对话视图': '低语视域',
      '世界书': '禁忌典籍',
      '羁绊路线': '命运刻痕',
      '带 TA 走': '带离深渊',
      '保留旧世界记忆': '保留旧日回声',
      '新世界类型': '新封印形态',
      '商店': '献祭所',
      '装扮': '外壳仪式',
      '成就': '禁忌刻痕',
      '来信箱': '低语信匣',
      '邮箱': '低语信匣',
      '功能券背包': '仪式券匣',
      '功能券货架': '仪式券货架',
      '剧情物品栏': '遗物栏',
      '发送': '投递低语',
      '复制': '拓印',
      '编辑': '篡改',
      '删除': '抹除',
      '保存': '封存',
      '取消': '退离',
      '关闭': '合上封印',
      '拉取模型': '召来模型',
      '测试连接': '试探回声',
      '保存 API 设置': '封存祭坛接口',
      '保存记忆策略': '封存记忆仪式',
      '保存显示与交互': '封存显影仪式',
      '保存预设': '封存仪式预设',
      '输入消息...': '写下低语...',
      '输入你的消息，开始和角色对话...': '写下低语，向深渊递交...',
      '重新回复': '重铸回响',
      '创建分支': '另开裂隙',
      '创建剧情分支': '另开剧情裂隙',
      '格式说明': '符文注解',
      '格式代码说明': '符文注解',
      '消息操作': '低语操作',
      '回复操作': '回声操作',
      '复制消息': '拓印低语',
      '编辑内容': '篡改内容',
      '删除消息': '抹除低语',
      '多选': '批量标记',
      '本地保存': '本地封存',
    };
    return _mappedText(text, exact);
  }

  static String _terminalText(String text) {
    const exact = <String, String>{
      '对话': '中转频道',
      '角色': '访客档案',
      '用户': '宿主',
      '设置': '控制台',
      '故事控制台': '裂隙控制台',
      '角色档案': '访客名册',
      '用户人设': '宿主档案',
      '应用设置': '中转站设置',
      '小游戏中心': '补给终端',
      '剧情工具箱': '剧情工具台',
      '同人文': '支线档案',
      '地图主线': '世界线地图',
      '进入地图': '进入世界线地图',
      '打开地图': '展开世界线地图',
      '下一回合': '推进节点',
      '显示面板': '展开面板',
      '隐藏面板': '收起面板',
      '对话视图': '通讯视窗',
      '世界书': '世界线档案',
      '羁绊路线': '羁绊链路',
      '带 TA 走': '迁移访客',
      '保留旧世界记忆': '保留旧节点记忆',
      '新世界类型': '新世界线类型',
      '商店': '补给站',
      '装扮': '外观模块',
      '成就': '节点勋章',
      '来信箱': '信号收件箱',
      '邮箱': '信号收件箱',
      '功能券背包': '通行券夹',
      '功能券货架': '通行券货架',
      '剧情物品栏': '节点物资栏',
      '发送': '发送信号',
      '复制': '复制日志',
      '编辑': '改写日志',
      '删除': '清除记录',
      '保存': '写入节点',
      '取消': '撤销操作',
      '关闭': '关闭端口',
      '拉取模型': '同步模型',
      '测试连接': '测试链路',
      '保存 API 设置': '保存接口参数',
      '保存记忆策略': '保存记忆策略',
      '保存显示与交互': '保存显示协议',
      '保存预设': '保存终端预设',
      '输入消息...': '输入信号...',
      '输入你的消息，开始和角色对话...': '输入信号，接入当前访客...',
      '重新回复': '重新同步',
      '创建分支': '创建支线节点',
      '创建剧情分支': '创建剧情节点',
      '格式说明': '协议说明',
      '格式代码说明': '协议说明',
      '消息操作': '信号操作',
      '回复操作': '回传操作',
      '复制消息': '复制信号',
      '编辑内容': '编辑信号',
      '删除消息': '删除信号',
      '多选': '批量选择',
      '本地保存': '本地节点',
    };
    return _mappedText(text, exact);
  }

  static String _flowerText(String text) {
    const exact = <String, String>{
      '对话': '夜谈',
      '角色': '花笺',
      '用户': '入梦人',
      '设置': '小铺设定',
      '故事控制台': '夜半小铺',
      '角色档案': '花笺名录',
      '用户人设': '入梦人手记',
      '应用设置': '小铺设定',
      '小游戏中心': '夜半小铺',
      '剧情工具箱': '纸笺工具箱',
      '同人文': '梦中别卷',
      '地图主线': '花径主线',
      '进入地图': '走入花径',
      '打开地图': '展开花径图',
      '下一回合': '下一段梦',
      '显示面板': '展开花笺',
      '隐藏面板': '收起花笺',
      '对话视图': '夜谈视图',
      '世界书': '花事笺',
      '羁绊路线': '缘分花径',
      '带 TA 走': '携 TA 入梦',
      '保留旧世界记忆': '留住旧梦',
      '新世界类型': '新梦境',
      '商店': '夜半小铺',
      '装扮': '花笺装裱',
      '成就': '花签',
      '来信箱': '云信匣',
      '邮箱': '云信匣',
      '功能券背包': '花签匣',
      '功能券货架': '花签货架',
      '剧情物品栏': '旧物格',
      '发送': '递出花笺',
      '复制': '誊抄',
      '编辑': '添改',
      '删除': '拂去',
      '保存': '收进笺中',
      '取消': '暂且搁笔',
      '关闭': '合上窗',
      '拉取模型': '请来笔墨',
      '测试连接': '试一声回音',
      '保存 API 设置': '收好笔墨设定',
      '保存记忆策略': '收好旧梦策略',
      '保存显示与交互': '收好小铺样式',
      '保存预设': '收好常用设定',
      '输入消息...': '写下夜谈...',
      '输入你的消息，开始和角色对话...': '写下一句，夜半小铺亮起灯...',
      '重新回复': '重写回笺',
      '创建分支': '另起一页',
      '创建剧情分支': '另起一页剧情',
      '格式说明': '笺注说明',
      '格式代码说明': '笺注说明',
      '消息操作': '花笺操作',
      '回复操作': '回笺操作',
      '复制消息': '誊抄消息',
      '编辑内容': '添改内容',
      '删除消息': '拂去消息',
      '多选': '多选花笺',
      '本地保存': '本地留存',
    };
    return _mappedText(text, exact);
  }

  static String _mechanicalText(String text) {
    const exact = <String, String>{
      '对话': '通讯舱',
      '角色': '机芯',
      '用户': '操作员',
      '设置': '控制台',
      '故事控制台': '齿轮控制台',
      '角色档案': '机芯档案',
      '用户人设': '操作员档案',
      '应用设置': '控制台设置',
      '小游戏中心': '零件市集',
      '剧情工具箱': '剧情工具台',
      '同人文': '副本蓝图',
      '地图主线': '城区蓝图',
      '进入地图': '进入城区蓝图',
      '打开地图': '展开城区蓝图',
      '下一回合': '下一轮齿动',
      '显示面板': '展开仪表',
      '隐藏面板': '收起仪表',
      '对话视图': '通讯视窗',
      '世界书': '工程档案',
      '羁绊路线': '羁绊齿轨',
      '带 TA 走': '转移机芯',
      '保留旧世界记忆': '保留旧齿轮记忆',
      '新世界类型': '新城区蓝图',
      '商店': '零件铺',
      '装扮': '外壳涂装',
      '成就': '功勋铭牌',
      '来信箱': '管道邮差',
      '邮箱': '管道邮差',
      '功能券背包': '工票夹',
      '功能券货架': '工票货架',
      '剧情物品栏': '剧情零件箱',
      '发送': '发出电报',
      '复制': '拓印',
      '编辑': '校改',
      '删除': '拆除',
      '保存': '锁紧',
      '取消': '撤回',
      '关闭': '关舱',
      '拉取模型': '同步机芯',
      '测试连接': '试转齿轮',
      '保存 API 设置': '保存接口齿轮',
      '保存记忆策略': '保存记忆齿轮',
      '保存显示与交互': '保存仪表样式',
      '保存预设': '保存齿轮预设',
      '输入消息...': '输入电报...',
      '输入你的消息，开始和角色对话...': '输入电报，启动当前机芯...',
      '重新回复': '重新回传',
      '创建分支': '另接一条齿轨',
      '创建剧情分支': '另接剧情齿轨',
      '格式说明': '规程说明',
      '格式代码说明': '规程说明',
      '消息操作': '电报操作',
      '回复操作': '回传操作',
      '复制消息': '拓印电报',
      '编辑内容': '校改内容',
      '删除消息': '拆除电报',
      '多选': '批量装订',
      '本地保存': '本地锁存',
    };
    return _mappedText(text, exact);
  }

  static String _rainRadioText(String text) {
    const exact = <String, String>{
      '对话': '雨频',
      '角色': '来信人',
      '用户': '听众',
      '设置': '调频台',
      '故事控制台': '雨夜播音室',
      '角色档案': '来信人档案',
      '用户人设': '听众资料',
      '应用设置': '调频台',
      '小游戏中心': '雨夜小卖亭',
      '剧情工具箱': '导播工具箱',
      '同人文': '雨夜同人稿',
      '地图主线': '城市雨图',
      '进入地图': '走进雨图',
      '打开地图': '展开雨图',
      '下一回合': '下一段播报',
      '显示面板': '拉开雨窗',
      '隐藏面板': '合上雨窗',
      '对话视图': '收听视图',
      '世界书': '城市频谱',
      '羁绊路线': '同频轨迹',
      '带 TA 走': '带 TA 离台',
      '保留旧世界记忆': '保留旧频率',
      '新世界类型': '新雨夜频段',
      '商店': '雨夜小铺',
      '装扮': '伞面花纹',
      '成就': '电台徽章',
      '来信箱': '留声信箱',
      '邮箱': '雨邮信箱',
      '功能券背包': '节目券夹',
      '功能券货架': '节目券货架',
      '剧情物品栏': '雨夜物件格',
      '发送': '发出电波',
      '复制': '录下',
      '编辑': '重录',
      '删除': '抹掉',
      '保存': '存进磁带',
      '取消': '先算了',
      '关闭': '关掉收音机',
      '拉取模型': '搜索频段',
      '测试连接': '试播一声',
      '保存 API 设置': '保存电波接口',
      '保存记忆策略': '保存回声策略',
      '保存显示与交互': '保存雨窗旋钮',
      '保存预设': '保存常用频段',
      '输入消息...': '写下雨声...',
      '输入你的消息，开始和角色对话...': '写下一句，雨夜电台开始收听...',
      '重新回复': '重播回音',
      '创建分支': '另录一盘磁带',
      '创建剧情分支': '另录剧情磁带',
      '格式说明': '播报格式',
      '格式代码说明': '播报格式',
      '消息操作': '电波操作',
      '回复操作': '回音操作',
      '复制消息': '录下电波',
      '编辑内容': '重录内容',
      '删除消息': '抹掉电波',
      '多选': '多选电波',
      '本地保存': '本地录音',
    };
    return _mappedText(text, exact);
  }

  static String _pastureText(String text) {
    const exact = <String, String>{
      '对话': '牧语',
      '角色': '伙伴',
      '用户': '牧场主',
      '设置': '小屋设置',
      '故事控制台': '晴风草坡',
      '角色档案': '伙伴名册',
      '用户人设': '牧场主手记',
      '应用设置': '小屋设置',
      '小游戏中心': '晴空集市',
      '剧情工具箱': '牧场工具棚',
      '同人文': '晴空小故事',
      '地图主线': '云影地图',
      '进入地图': '走上云影小路',
      '打开地图': '展开云影地图',
      '下一回合': '下一阵晴风',
      '显示面板': '打开木栅栏',
      '隐藏面板': '合上木栅栏',
      '对话视图': '牧场视图',
      '世界书': '田野札记',
      '羁绊路线': '同行小路',
      '带 TA 走': '牵 TA 去新草坡',
      '保留旧世界记忆': '留住旧风声',
      '新世界类型': '新牧场',
      '商店': '晴空小铺',
      '装扮': '牧场装扮',
      '成就': '星星贴纸',
      '来信箱': '云朵信箱',
      '邮箱': '云朵信箱',
      '功能券背包': '野餐券篮',
      '功能券货架': '野餐券架',
      '剧情物品栏': '小背篓',
      '发送': '放飞纸飞机',
      '复制': '摘一份',
      '编辑': '修剪',
      '删除': '收进草堆',
      '保存': '晒进本子',
      '取消': '先歇会儿',
      '关闭': '关上小窗',
      '拉取模型': '喊来牧场帮手',
      '测试连接': '听听风声',
      '保存 API 设置': '保存风车接口',
      '保存记忆策略': '保存草坡记忆',
      '保存显示与交互': '保存牧场样式',
      '保存预设': '保存常用小屋',
      '输入消息...': '写下晴风...',
      '输入你的消息，开始和角色对话...': '写下一句，故事在草坡上醒来...',
      '重新回复': '再吹一阵风',
      '创建分支': '另开一条小路',
      '创建剧情分支': '另开剧情小路',
      '格式说明': '田野说明',
      '格式代码说明': '田野说明',
      '消息操作': '牧语操作',
      '回复操作': '回风操作',
      '复制消息': '摘下牧语',
      '编辑内容': '修剪内容',
      '删除消息': '收起牧语',
      '多选': '批量采摘',
      '本地保存': '本地晒干',
    };
    return _mappedText(text, exact);
  }

  static String _vinylText(String text) {
    const exact = <String, String>{
      '对话': '播放',
      '角色': '唱片架',
      '用户': '听众',
      '设置': '调音台',
      '故事控制台': '黑胶唱机',
      '角色档案': '唱片内页',
      '用户人设': '听众手札',
      '应用设置': '调音台',
      '小游戏中心': '旧货唱片行',
      '剧情工具箱': '调音工具箱',
      '同人文': 'B 面番外',
      '地图主线': '旧城声轨',
      '进入地图': '落针旧城声轨',
      '打开地图': '展开旧城声轨',
      '下一回合': '下一圈唱片',
      '显示面板': '抬起防尘盖',
      '隐藏面板': '合上防尘盖',
      '对话视图': '收听视图',
      '世界书': '唱片说明书',
      '羁绊路线': '双人声轨',
      '带 TA 走': '带 TA 换面',
      '保留旧世界记忆': '保留旧曲记忆',
      '新世界类型': '新唱片场景',
      '商店': '唱片柜台',
      '装扮': '封套收藏',
      '成就': '金曲榜',
      '来信箱': '唱片邮槽',
      '邮箱': '唱片邮槽',
      '功能券背包': '试听券夹',
      '功能券货架': '试听券货架',
      '剧情物品栏': '旧物陈列',
      '发送': '按下播放键',
      '复制': '翻录',
      '编辑': '重混',
      '删除': '划掉音轨',
      '保存': '收入封套',
      '取消': '先停针',
      '关闭': '收起唱机',
      '拉取模型': '换一张唱片',
      '测试连接': '试放一小节',
      '保存 API 设置': '保存唱针接口',
      '保存记忆策略': '保存旧曲记忆',
      '保存显示与交互': '保存唱机旋钮',
      '保存预设': '保存常听唱片',
      '输入消息...': '写下歌词...',
      '输入你的消息，开始和角色对话...': '写下一句，唱针开始回放...',
      '重新回复': '重新落针',
      '创建分支': '刻一条 B 面',
      '创建剧情分支': '刻一段支线音轨',
      '格式说明': '唱片说明',
      '格式代码说明': '唱片说明',
      '消息操作': '音轨操作',
      '回复操作': '回放操作',
      '复制消息': '翻录音轨',
      '编辑内容': '重混内容',
      '删除消息': '划掉音轨',
      '多选': '多选音轨',
      '本地保存': '本地珍藏',
    };
    return _mappedText(text, exact);
  }

  static double uiScaleOf(BuildContext context) {
    final scale = MediaQuery.maybeTextScalerOf(context)?.scale(1) ?? 1;
    return scale.clamp(0.82, 1.25).toDouble();
  }

  static double scaled(BuildContext context, double base) {
    return base * uiScaleOf(context);
  }

  static ButtonStyle? skinIconButtonStyle({
    ButtonStyle? base,
    bool primary = false,
  }) {
    final themeId = activePresetThemeId;
    final buttons =
        themeId == null ? null : ThemeSkinAssets.buttonSpecFor(themeId);
    if (themeId == null || buttons == null || !buttons.supportsIcon) {
      return base;
    }
    return (base ?? const ButtonStyle()).copyWith(
      foregroundColor: buttons.foregroundProperty(
        form: ThemeSkinButtonForm.icon,
        primary: primary,
      ),
      iconColor: buttons.foregroundProperty(
        form: ThemeSkinButtonForm.icon,
        primary: primary,
      ),
      backgroundColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      elevation: const WidgetStatePropertyAll<double>(0),
      side: const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(buttons.iconBorderRadius),
          ),
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      animationDuration: const Duration(milliseconds: 90),
      backgroundBuilder: ThemeSkinAssets.iconButtonLayerFor(
        themeId,
        primary: primary,
      ),
    );
  }

  static ButtonStyle? skinFilledIconButtonStyle({
    ButtonStyle? base,
    bool primary = true,
  }) {
    final themeId = activePresetThemeId;
    final buttons =
        themeId == null ? null : ThemeSkinAssets.buttonSpecFor(themeId);
    if (themeId == null || buttons == null || !buttons.supportsIcon) {
      if (buttons?.supportsWide == true) {
        final nativeBackground = activePrimary;
        final nativeForeground =
            isMechanicalMode ? const Color(0xFF0C0C0C) : textMain;
        final interactionColor = isMechanicalMode ? Colors.white : Colors.black;
        final fallbackBackground = WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.disabled)
              ? nativeBackground.withValues(alpha: 0.38)
              : nativeBackground,
        );
        final fallbackForeground = WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.disabled)
              ? nativeForeground.withValues(alpha: 0.38)
              : nativeForeground,
        );
        final fallbackOverlay = WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.pressed)) {
              return interactionColor.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return interactionColor.withValues(alpha: 0.08);
            }
            return Colors.transparent;
          },
        );
        return (base ?? const ButtonStyle()).copyWith(
          backgroundColor: base?.backgroundColor ?? fallbackBackground,
          foregroundColor: base?.foregroundColor ?? fallbackForeground,
          iconColor: base?.iconColor ?? fallbackForeground,
          overlayColor: base?.overlayColor ?? fallbackOverlay,
          splashFactory: base?.splashFactory ?? InkRipple.splashFactory,
          backgroundBuilder: (context, states, child) =>
              child ?? const SizedBox.shrink(),
        );
      }
      return base;
    }
    return (base ?? const ButtonStyle()).copyWith(
      minimumSize:
          base?.minimumSize ?? const WidgetStatePropertyAll<Size>(Size(64, 40)),
      foregroundColor: buttons.foregroundProperty(
        form: ThemeSkinButtonForm.icon,
        primary: primary,
      ),
      iconColor: buttons.foregroundProperty(
        form: ThemeSkinButtonForm.icon,
        primary: primary,
      ),
      backgroundColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      elevation: const WidgetStatePropertyAll<double>(0),
      side: const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(buttons.iconBorderRadius),
          ),
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      animationDuration: const Duration(milliseconds: 90),
      backgroundBuilder: ThemeSkinAssets.iconButtonLayerFor(
        themeId,
        primary: primary,
      ),
    );
  }

  static ButtonStyle? skinTonalButtonStyle({ButtonStyle? base}) {
    final themeId = activePresetThemeId;
    final buttons =
        themeId == null ? null : ThemeSkinAssets.buttonSpecFor(themeId);
    if (themeId == null || buttons == null || !buttons.supportsWide) {
      return base;
    }
    final foreground = buttons.foregroundProperty(
      form: ThemeSkinButtonForm.wide,
      primary: false,
    );
    return (base ?? const ButtonStyle()).copyWith(
      foregroundColor: foreground,
      iconColor: foreground,
      backgroundBuilder: ThemeSkinAssets.wideButtonLayerFor(
        themeId,
        secondary: true,
      ),
    );
  }

  static LinearGradient get shellBackgroundGradient {
    if (usesPresetBackdropArtwork) {
      return const LinearGradient(
        colors: <Color>[
          Colors.transparent,
          Colors.transparent,
          Colors.transparent,
          Colors.transparent,
        ],
        stops: <double>[0, 0.38, 0.72, 1],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: _activePalette.background,
      stops: const <double>[0, 0.38, 0.72, 1],
    );
  }

  static LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _activePalette.brand,
      );

  static LinearGradient get actionGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          _activePalette.primary,
          _activePalette.secondary,
        ],
      );

  static LinearGradient get defaultAssistantBubbleGradient {
    if (isBasicPaletteMode) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.72),
          Colors.white.withValues(alpha: 0.58),
        ],
      );
    }
    if (isFlowerMode) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFFFFFCF6).withValues(alpha: 0.94),
          const Color(0xFFF1E7DD).withValues(alpha: 0.88),
        ],
      );
    }
    if (isPastureMode) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.88),
          const Color(0xFFE8F8FF).withValues(alpha: 0.78),
          const Color(0xFFF8F0CE).withValues(alpha: 0.46),
        ],
      );
    }
    if (isVinylMode) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFFF8E7C8).withValues(alpha: 0.96),
          const Color(0xFFE6C68E).withValues(alpha: 0.84),
          const Color(0xFF9B6038).withValues(alpha: 0.18),
        ],
      );
    }
    if (isEldritchMode) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFF1B0607).withValues(alpha: 0.94),
          const Color(0xFF050000).withValues(alpha: 0.86),
          const Color(0xFF9D3832).withValues(alpha: 0.12),
        ],
      );
    }
    if (isTerminalMode) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFF1C1F24).withValues(alpha: 0.92),
          const Color(0xFF050607).withValues(alpha: 0.78),
          const Color(0xFF00D5FF).withValues(alpha: 0.10),
        ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        _activePalette.panelStart,
        _activePalette.panelEnd,
      ],
    );
  }

  static BoxDecoration glassPanel({
    bool highlighted = false,
    double radius = 24,
  }) {
    final palette = _activePalette;
    final sketchy = palette == AppThemeVariant.aprilFools.palette;
    final eldritch = palette == AppThemeVariant.cthulhu.palette;
    final terminal = palette == AppThemeVariant.riftRelay.palette;
    final flower = palette == AppThemeVariant.flowerNotFlower.palette;
    final mechanical = palette == AppThemeVariant.mechanicalCity.palette;
    final rainRadio = palette == AppThemeVariant.rainRadio.palette;
    final pasture = palette == AppThemeVariant.skyPasture.palette;
    final vinyl = palette == AppThemeVariant.vinylMemories.palette;
    final basic = isBasicPaletteMode;
    final basicRadius = radius > 8 ? 8.0 : radius;
    final premiumRound = rainRadio || pasture;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: highlighted
            ? <Color>[
                palette.panelHighlightStart,
                palette.panelHighlightEnd,
              ]
            : <Color>[
                palette.panelStart,
                palette.panelEnd,
              ],
      ),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(
          flower
              ? radius * 0.72
              : basic
                  ? basicRadius
                  : eldritch
                      ? radius * 0.18
                      : terminal
                          ? radius * 0.22
                          : mechanical
                              ? radius * 0.34
                              : premiumRound
                                  ? radius * 1.18
                                  : vinyl
                                      ? radius * 0.46
                                      : (sketchy ? radius * 1.15 : radius),
        ),
        topRight: Radius.circular(
          flower
              ? radius * 0.18
              : basic
                  ? basicRadius
                  : eldritch
                      ? radius * 0.92
                      : terminal
                          ? radius * 0.22
                          : mechanical
                              ? radius * 0.88
                              : premiumRound
                                  ? radius * 1.18
                                  : vinyl
                                      ? radius * 0.12
                                      : (sketchy ? radius * 0.24 : radius),
        ),
        bottomLeft: Radius.circular(
          flower
              ? radius * 0.18
              : basic
                  ? basicRadius
                  : eldritch
                      ? radius * 0.92
                      : terminal
                          ? radius * 0.22
                          : mechanical
                              ? radius * 0.88
                              : premiumRound
                                  ? radius * 1.18
                                  : vinyl
                                      ? radius * 0.12
                                      : (sketchy ? radius * 0.32 : radius),
        ),
        bottomRight: Radius.circular(
          flower
              ? radius * 0.72
              : basic
                  ? basicRadius
                  : eldritch
                      ? radius * 0.18
                      : terminal
                          ? radius * 0.22
                          : mechanical
                              ? radius * 0.34
                              : premiumRound
                                  ? radius * 1.18
                                  : vinyl
                                      ? radius * 0.46
                                      : (sketchy ? radius * 1.35 : radius),
        ),
      ),
      border: Border.all(
        color: basic
            ? palette.line.withValues(alpha: highlighted ? 1 : 0.86)
            : eldritch
                ? palette.line.withValues(alpha: highlighted ? 0.98 : 0.72)
                : flower
                    ? palette.line.withValues(alpha: highlighted ? 0.72 : 0.42)
                    : terminal
                        ? (highlighted ? palette.accent : palette.line)
                            .withValues(alpha: highlighted ? 0.82 : 0.62)
                        : mechanical
                            ? palette.line
                                .withValues(alpha: highlighted ? 0.94 : 0.7)
                            : rainRadio
                                ? palette.line.withValues(
                                    alpha: highlighted ? 0.72 : 0.48)
                                : pasture
                                    ? palette.line.withValues(
                                        alpha: highlighted ? 0.72 : 0.48)
                                    : vinyl
                                        ? palette.line.withValues(
                                            alpha: highlighted ? 0.9 : 0.62)
                                        : sketchy
                                            ? palette.line.withValues(
                                                alpha:
                                                    highlighted ? 0.95 : 0.72)
                                            : (highlighted
                                                ? palette.soft
                                                    .withValues(alpha: 0.26)
                                                : palette.line
                                                    .withValues(alpha: 0.78)),
        width: sketchy
            ? 2
            : (eldritch
                ? 1.8
                : terminal
                    ? 1.4
                    : (flower || mechanical || pasture || vinyl ? 1.2 : 1)),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: basic
              ? Colors.black.withValues(alpha: highlighted ? 0.10 : 0.07)
              : eldritch
                  ? Colors.black.withValues(alpha: highlighted ? 0.62 : 0.42)
                  : flower
                      ? palette.glow
                          .withValues(alpha: highlighted ? 0.08 : 0.035)
                      : terminal
                          ? Colors.black
                              .withValues(alpha: highlighted ? 0.48 : 0.32)
                          : mechanical
                              ? Colors.black
                                  .withValues(alpha: highlighted ? 0.52 : 0.34)
                              : rainRadio
                                  ? palette.glow.withValues(
                                      alpha: highlighted ? 0.13 : 0.07)
                                  : pasture
                                      ? palette.glow.withValues(
                                          alpha: highlighted ? 0.14 : 0.08)
                                      : vinyl
                                          ? Colors.black.withValues(
                                              alpha: highlighted ? 0.46 : 0.28)
                                          : sketchy
                                              ? palette.glow.withValues(
                                                  alpha:
                                                      highlighted ? 0.42 : 0.25)
                                              : palette.glow.withValues(
                                                  alpha: highlighted
                                                      ? 0.08
                                                      : 0.04),
          blurRadius: basic
              ? (highlighted ? 28 : 20)
              : eldritch
                  ? (highlighted ? 34 : 20)
                  : flower
                      ? (highlighted ? 18 : 10)
                      : terminal
                          ? (highlighted ? 32 : 18)
                          : mechanical
                              ? (highlighted ? 22 : 14)
                              : rainRadio
                                  ? (highlighted ? 30 : 18)
                                  : pasture
                                      ? (highlighted ? 22 : 14)
                                      : vinyl
                                          ? (highlighted ? 24 : 16)
                                          : sketchy
                                              ? (highlighted ? 28 : 16)
                                              : (highlighted ? 18 : 12),
          offset: basic
              ? const Offset(0, 14)
              : eldritch
                  ? const Offset(0, 12)
                  : flower
                      ? const Offset(0, 8)
                      : terminal
                          ? const Offset(0, 16)
                          : mechanical
                              ? const Offset(6, 8)
                              : rainRadio
                                  ? const Offset(0, 12)
                                  : pasture
                                      ? const Offset(0, 8)
                                      : vinyl
                                          ? const Offset(4, 8)
                                          : sketchy
                                              ? const Offset(5, 5)
                                              : const Offset(0, 10),
        ),
        if (sketchy)
          BoxShadow(
            color: palette.secondary.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(-3, -2),
          ),
        if (eldritch)
          BoxShadow(
            color: palette.glow.withValues(alpha: highlighted ? 0.28 : 0.16),
            blurRadius: highlighted ? 34 : 20,
          ),
        if (terminal)
          BoxShadow(
            color: palette.glow.withValues(alpha: highlighted ? 0.20 : 0.10),
            blurRadius: highlighted ? 24 : 14,
          ),
        if (mechanical)
          BoxShadow(
            color: palette.accent.withValues(alpha: highlighted ? 0.14 : 0.08),
            blurRadius: highlighted ? 18 : 10,
            offset: const Offset(-2, -2),
          ),
        if (rainRadio)
          BoxShadow(
            color:
                palette.secondary.withValues(alpha: highlighted ? 0.14 : 0.08),
            blurRadius: highlighted ? 20 : 12,
          ),
        if (pasture)
          BoxShadow(
            color: Colors.white.withValues(alpha: highlighted ? 0.54 : 0.34),
            blurRadius: 12,
            offset: const Offset(-2, -2),
          ),
        if (vinyl)
          BoxShadow(
            color: palette.accent.withValues(alpha: highlighted ? 0.16 : 0.08),
            blurRadius: highlighted ? 18 : 10,
            offset: const Offset(-1, -1),
          ),
        if (flower)
          BoxShadow(
            color: Colors.white.withValues(alpha: highlighted ? 0.48 : 0.28),
            blurRadius: 8,
            offset: const Offset(-1, -1),
          ),
      ],
    );
  }

  static List<BoxShadow> neonGlow({
    Color? color,
    double alpha = 0.08,
  }) {
    return <BoxShadow>[
      BoxShadow(
        color: (_activePalette == AppThemeVariant.aprilFools.palette
                ? Colors.black
                : _activePalette == AppThemeVariant.cthulhu.palette
                    ? const Color(0xFFAB5240)
                    : _activePalette == AppThemeVariant.riftRelay.palette
                        ? const Color(0xFF7E9EA8)
                        : _activePalette ==
                                AppThemeVariant.flowerNotFlower.palette
                            ? const Color(0xFF8B1616)
                            : _activePalette ==
                                    AppThemeVariant.mechanicalCity.palette
                                ? const Color(0xFFB9894C)
                                : _activePalette ==
                                        AppThemeVariant.rainRadio.palette
                                    ? const Color(0xFF8BBFD8)
                                    : _activePalette ==
                                            AppThemeVariant.skyPasture.palette
                                        ? const Color(0xFF8FC6E0)
                                        : _activePalette ==
                                                AppThemeVariant
                                                    .vinylMemories.palette
                                            ? const Color(0xFFE0B56F)
                                            : (color ?? _activePalette.glow))
            .withValues(alpha: alpha),
        blurRadius: _activePalette == AppThemeVariant.aprilFools.palette
            ? 24
            : _activePalette == AppThemeVariant.cthulhu.palette
                ? 26
                : _activePalette == AppThemeVariant.riftRelay.palette
                    ? 22
                    : _activePalette == AppThemeVariant.flowerNotFlower.palette
                        ? 14
                        : _activePalette ==
                                AppThemeVariant.mechanicalCity.palette
                            ? 16
                            : _activePalette ==
                                    AppThemeVariant.rainRadio.palette
                                ? 20
                                : _activePalette ==
                                        AppThemeVariant.skyPasture.palette
                                    ? 16
                                    : _activePalette ==
                                            AppThemeVariant
                                                .vinylMemories.palette
                                        ? 18
                                        : 18,
        offset: _activePalette == AppThemeVariant.aprilFools.palette
            ? const Offset(4, 4)
            : _activePalette == AppThemeVariant.cthulhu.palette
                ? const Offset(0, 6)
                : _activePalette == AppThemeVariant.riftRelay.palette
                    ? const Offset(0, 8)
                    : _activePalette == AppThemeVariant.flowerNotFlower.palette
                        ? const Offset(0, 4)
                        : _activePalette ==
                                AppThemeVariant.mechanicalCity.palette
                            ? const Offset(4, 6)
                            : _activePalette ==
                                    AppThemeVariant.rainRadio.palette
                                ? const Offset(0, 6)
                                : _activePalette ==
                                        AppThemeVariant.skyPasture.palette
                                    ? const Offset(0, 4)
                                    : _activePalette ==
                                            AppThemeVariant
                                                .vinylMemories.palette
                                        ? const Offset(3, 5)
                                        : Offset.zero,
      ),
    ];
  }

  static ThemeData _buildNeonTheme(
    AppThemePalette palette, {
    bool sketchy = false,
    bool eldritch = false,
    bool terminal = false,
    bool flower = false,
    bool mechanical = false,
    bool rainRadio = false,
    bool pasture = false,
    bool vinyl = false,
    bool basicPalette = false,
    String? skinThemeId,
  }) {
    final skinButtons =
        skinThemeId == null ? null : ThemeSkinAssets.buttonSpecFor(skinThemeId);
    final rasterWideButtonSkin = skinButtons?.supportsWide ?? false;
    final rasterWideButtonPrimaryForeground = skinButtons?.foregroundProperty(
      form: ThemeSkinButtonForm.wide,
      primary: true,
    );
    final rasterWideButtonSecondaryForeground = skinButtons?.foregroundProperty(
      form: ThemeSkinButtonForm.wide,
      primary: false,
    );
    final rasterWideButtonRadius = skinButtons?.wideBorderRadius ?? 8;
    final lightSurface = flower || pasture || basicPalette;
    final baseScheme = lightSurface
        ? ColorScheme.light(
            primary: palette.primary,
            onPrimary: basicPalette ? textMain : Colors.white,
            secondary: palette.accent,
            onSecondary: basicPalette ? textMain : Colors.white,
            tertiary: palette.secondary,
            onTertiary: const Color(0xFF1A1816),
            error: const Color(0xFF8B1616),
            onError: Colors.white,
            surface: palette.panelStart,
            onSurface: textMain,
            onSurfaceVariant: textMuted,
            outline: palette.line.withValues(alpha: 0.95),
            outlineVariant: palette.line.withValues(alpha: 0.65),
            primaryContainer: palette.panelHighlightStart,
            onPrimaryContainer: textMain,
            secondaryContainer: palette.panelEnd,
            onSecondaryContainer: textMain,
            tertiaryContainer: palette.panelHighlightEnd,
            onTertiaryContainer: textMain,
            surfaceContainerHighest: palette.panelEnd,
          )
        : ColorScheme.dark(
            primary: palette.primary,
            onPrimary: eldritch
                ? Colors.white
                : sketchy || terminal || mechanical || vinyl
                    ? const Color(0xFF0C0C0C)
                    : Colors.white,
            secondary: palette.accent,
            onSecondary: const Color(0xFF091117),
            tertiary: palette.secondary,
            onTertiary: Colors.white,
            error: sketchy
                ? const Color(0xFFFF2222)
                : eldritch
                    ? const Color(0xFFC45B4B)
                    : const Color(0xFFFF8AA6),
            onError: Colors.white,
            surface: palette.panelStart,
            onSurface: textMain,
            onSurfaceVariant: textMuted,
            outline: palette.line.withValues(alpha: 0.95),
            outlineVariant: palette.line.withValues(alpha: 0.65),
            primaryContainer: palette.panelHighlightStart,
            onPrimaryContainer: textMain,
            secondaryContainer: palette.panelEnd,
            onSecondaryContainer: textMain,
            tertiaryContainer: palette.panelHighlightEnd,
            onTertiaryContainer: textMain,
            surfaceContainerHighest: palette.panelEnd,
          );

    final fontFamily = sketchy
        ? 'monospace'
        : eldritch
            ? 'AbyssSerif'
            : terminal
                ? 'RiftCombat'
                : flower
                    ? 'FlowerWenDingKai'
                    : mechanical
                        ? 'monospace'
                        : rainRadio
                            ? 'serif'
                            : pasture
                                ? 'PastureXiaolai'
                                : vinyl
                                    ? 'AbyssSerif'
                                    : null;
    final mainText = sketchy
        ? const Color(0xFFB3FF8F)
        : eldritch
            ? const Color(0xFFDED1C5)
            : terminal
                ? const Color(0xFFD6DBE2)
                : flower
                    ? const Color(0xFF1F1B18)
                    : mechanical
                        ? const Color(0xFFECE4D3)
                        : rainRadio
                            ? const Color(0xFFEAF4FF)
                            : pasture
                                ? const Color(0xFF274C55)
                                : vinyl
                                    ? const Color(0xFFF4E1BE)
                                    : textMain;
    final mutedText = sketchy
        ? const Color(0xFFFFCC88)
        : eldritch
            ? const Color(0xFFB98F81)
            : terminal
                ? const Color(0xFF9AA4AF)
                : flower
                    ? const Color(0xFF625852)
                    : mechanical
                        ? const Color(0xFFC9B48D)
                        : rainRadio
                            ? const Color(0xFFB9CDDC)
                            : pasture
                                ? const Color(0xFF537074)
                                : vinyl
                                    ? const Color(0xFFD1B17C)
                                    : textMuted;
    final weakText = sketchy
        ? const Color(0xFFFF6666)
        : eldritch
            ? const Color(0xFF9C6B62)
            : terminal
                ? const Color(0xFF78838F)
                : flower
                    ? const Color(0xFF8A7D73)
                    : mechanical
                        ? const Color(0xFF8E9A98)
                        : rainRadio
                            ? const Color(0xFF9FB0C3)
                            : pasture
                                ? const Color(0xFF7D8D83)
                                : vinyl
                                    ? const Color(0xFFB58C58)
                                    : textWeak;
    final displayFontFamily = eldritch
        ? 'AbyssLogo'
        : (vinyl
            ? 'VinylWenkai'
            : basicPalette
                ? 'AbyssSerif'
                : fontFamily);
    final bodyFontFamily = basicPalette ? 'AbyssSerif' : fontFamily;
    final subheadFontFamily = basicPalette ? displayFontFamily : fontFamily;

    final textBase = lightSurface
        ? Typography.blackMountainView
        : Typography.whiteMountainView;
    final textTheme = textBase.copyWith(
      headlineSmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: sketchy
            ? -0.8
            : eldritch
                ? 2.2
                : terminal
                    ? 1.4
                    : mechanical
                        ? 1.0
                        : rainRadio || pasture || vinyl
                            ? 0.6
                            : 0.2,
        color: mainText,
        fontFamily: displayFontFamily,
        shadows: sketchy
            ? const <Shadow>[
                Shadow(
                    color: Color(0xFFFF0000),
                    offset: Offset(2, 0),
                    blurRadius: 0),
                Shadow(
                    color: Color(0xFF00FFFF),
                    offset: Offset(-1, 0),
                    blurRadius: 0),
              ]
            : eldritch
                ? const <Shadow>[
                    Shadow(
                      color: Color(0xFF7A211B),
                      offset: Offset(0, 0),
                      blurRadius: 8,
                    ),
                  ]
                : terminal
                    ? const <Shadow>[
                        Shadow(
                          color: Color(0x557E9EA8),
                          offset: Offset(0, 0),
                          blurRadius: 8,
                        ),
                      ]
                    : mechanical
                        ? const <Shadow>[
                            Shadow(
                              color: Color(0x66B9894C),
                              offset: Offset(1, 1),
                              blurRadius: 4,
                            ),
                          ]
                        : rainRadio || pasture || vinyl
                            ? const <Shadow>[
                                Shadow(
                                  color: Color(0x558BBFD8),
                                  offset: Offset(0, 0),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
      ),
      headlineMedium: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        letterSpacing: sketchy
            ? -1.2
            : eldritch
                ? 3.0
                : terminal
                    ? 1.8
                    : mechanical
                        ? 1.2
                        : rainRadio || pasture || vinyl
                            ? 0.7
                            : 0.2,
        color: mainText,
        fontFamily: displayFontFamily,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: sketchy
            ? -0.5
            : eldritch
                ? 1.2
                : terminal
                    ? 1.0
                    : mechanical
                        ? 0.8
                        : rainRadio || pasture || vinyl
                            ? 0.4
                            : 0.2,
        color: mainText,
        fontFamily: displayFontFamily,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: mainText,
        fontFamily: subheadFontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.65,
        color: mainText,
        fontFamily: bodyFontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.58,
        color: mainText,
        fontFamily: bodyFontFamily,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: weakText,
        fontFamily: fontFamily,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: mainText,
        fontFamily: fontFamily,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: weakText,
        fontFamily: fontFamily,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: lightSurface ? Brightness.light : Brightness.dark,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      dividerColor: palette.line,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: mainText,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: mainText,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          fontFamily: fontFamily,
        ),
      ),
      iconTheme: IconThemeData(color: mutedText),
      cardTheme: CardThemeData(
        color: palette.panelStart,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(basicPalette ? 8 : 22),
          side: BorderSide(color: palette.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.panelEnd,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(basicPalette ? 8 : 24),
          side: BorderSide(color: palette.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.panelHighlightStart,
        contentTextStyle: TextStyle(color: mainText, fontFamily: fontFamily),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(basicPalette ? 8 : 14),
          side: BorderSide(color: palette.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface
            ? Colors.black.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.055),
        labelStyle: TextStyle(color: mutedText, fontFamily: fontFamily),
        hintStyle: TextStyle(color: weakText, fontFamily: fontFamily),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(basicPalette ? 8 : 18),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(basicPalette ? 8 : 18),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(basicPalette ? 8 : 18),
          borderSide: BorderSide(
            color: palette.soft.withValues(alpha: 0.8),
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(basicPalette ? 8 : 18),
          borderSide: const BorderSide(color: Color(0xFFFF8AA6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: skinButtons?.standardWideMinHeight == null
              ? null
              : WidgetStatePropertyAll(
                  Size(64, skinButtons!.standardWideMinHeight!),
                ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          foregroundColor: rasterWideButtonSkin
              ? rasterWideButtonPrimaryForeground
              : WidgetStatePropertyAll(
                  eldritch
                      ? Colors.white
                      : sketchy || terminal || vinyl
                          ? const Color(0xFF1B1D22)
                          : basicPalette || pasture
                              ? textMain
                              : Colors.white,
                ),
          backgroundColor: WidgetStatePropertyAll(
            rasterWideButtonSkin ? Colors.transparent : palette.primary,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(
                  rasterWideButtonSkin
                      ? rasterWideButtonRadius
                      : eldritch
                          ? 26
                          : (basicPalette ? 8 : (sketchy ? 14 : 18)),
                ),
                topRight: Radius.circular(
                  rasterWideButtonSkin
                      ? rasterWideButtonRadius
                      : eldritch
                          ? 8
                          : terminal
                              ? 10
                              : (basicPalette ? 8 : (sketchy ? 14 : 18)),
                ),
                bottomLeft: Radius.circular(
                  rasterWideButtonSkin
                      ? rasterWideButtonRadius
                      : eldritch
                          ? 8
                          : terminal
                              ? 10
                              : (basicPalette ? 8 : (sketchy ? 14 : 18)),
                ),
                bottomRight: Radius.circular(
                  rasterWideButtonSkin
                      ? rasterWideButtonRadius
                      : eldritch
                          ? 26
                          : terminal
                              ? 18
                              : (basicPalette ? 8 : (sketchy ? 14 : 18)),
                ),
              ),
              side: !rasterWideButtonSkin &&
                      (sketchy || eldritch || terminal || vinyl)
                  ? BorderSide(
                      color: palette.soft.withValues(alpha: 0.84),
                      width: 1.5,
                    )
                  : BorderSide.none,
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: WidgetStatePropertyAll(
            rasterWideButtonSkin
                ? Colors.transparent
                : palette.primary.withValues(alpha: 0.32),
          ),
          overlayColor: WidgetStatePropertyAll(
            rasterWideButtonSkin
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
          splashFactory: rasterWideButtonSkin ? NoSplash.splashFactory : null,
          animationDuration:
              rasterWideButtonSkin ? const Duration(milliseconds: 90) : null,
          alignment: rasterWideButtonSkin ? Alignment.center : null,
          backgroundBuilder: rasterWideButtonSkin
              ? ThemeSkinAssets.wideButtonLayerFor(
                  skinThemeId!,
                  secondary: false,
                )
              : null,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: skinButtons?.standardWideMinHeight == null
              ? null
              : WidgetStatePropertyAll(
                  Size(64, skinButtons!.standardWideMinHeight!),
                ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          foregroundColor: rasterWideButtonSkin
              ? rasterWideButtonSecondaryForeground
              : WidgetStatePropertyAll(mainText),
          side: WidgetStatePropertyAll(
            rasterWideButtonSkin
                ? BorderSide.none
                : BorderSide(color: palette.line),
          ),
          backgroundColor: WidgetStatePropertyAll(
            rasterWideButtonSkin
                ? Colors.transparent
                : terminal || eldritch || vinyl
                    ? palette.panelEnd.withValues(alpha: 0.62)
                    : Colors.white.withValues(alpha: 0.02),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                rasterWideButtonSkin
                    ? rasterWideButtonRadius
                    : terminal
                        ? 6
                        : eldritch
                            ? 10
                            : vinyl
                                ? 8
                                : basicPalette
                                    ? 8
                                    : 18,
              ),
            ),
          ),
          overlayColor: WidgetStatePropertyAll(
            rasterWideButtonSkin
                ? Colors.transparent
                : palette.primary.withValues(alpha: 0.08),
          ),
          splashFactory: rasterWideButtonSkin ? NoSplash.splashFactory : null,
          animationDuration:
              rasterWideButtonSkin ? const Duration(milliseconds: 90) : null,
          alignment: rasterWideButtonSkin ? Alignment.center : null,
          backgroundBuilder: rasterWideButtonSkin
              ? ThemeSkinAssets.wideButtonLayerFor(
                  skinThemeId!,
                  secondary: true,
                )
              : null,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(mutedText),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return palette.secondary.withValues(alpha: 0.12);
            }
            return Colors.transparent;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                terminal
                    ? 6
                    : eldritch
                        ? 10
                        : vinyl
                            ? 8
                            : basicPalette
                                ? 8
                                : 16,
              ),
            ),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 82,
        backgroundColor: lightSurface
            ? Colors.white.withValues(alpha: 0.42)
            : Colors.black.withValues(alpha: 0.28),
        indicatorColor: palette.secondary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected) ? mainText : weakText,
            fontWeight: FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color:
                states.contains(WidgetState.selected) ? palette.soft : weakText,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        selectedIconTheme: IconThemeData(color: palette.soft),
        unselectedIconTheme: IconThemeData(color: weakText),
        selectedLabelTextStyle: TextStyle(
          color: mainText,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: weakText,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        indicatorColor: palette.secondary.withValues(alpha: 0.16),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primary;
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.soft,
        inactiveTrackColor: lightSurface
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.1),
        thumbColor: palette.primary,
        overlayColor: palette.primary.withValues(alpha: 0.12),
        valueIndicatorColor: palette.secondary,
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.soft,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.soft,
        selectionColor: palette.secondary.withValues(alpha: 0.28),
        selectionHandleColor: palette.soft,
      ),
    );
  }
}
