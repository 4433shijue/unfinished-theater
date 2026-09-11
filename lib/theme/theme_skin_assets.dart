import 'package:flutter/material.dart';

enum ThemeSkinEffectPolicy { full, ambientOnly, none }

enum ThemeSkinDrawerMaterialToken {
  signalNoise,
  occultLeather,
  relayMetal,
  ricePaper,
  rivetedBrass,
  rainGlass,
  paintedPasture,
  vinylLacquer,
}

enum ThemeSkinButtonForm { wide, icon }

enum ThemeSkinButtonVisualState { normal, hover, pressed }

@immutable
class ThemeSkinButtonSpec {
  const ThemeSkinButtonSpec({
    required this.assetRoot,
    required this.assetStem,
    required this.supportsWide,
    required this.supportsIcon,
    required this.foregroundColor,
    required this.disabledForegroundColor,
    required this.focusColor,
    required this.focusGlowColor,
    this.secondaryForegroundColor,
    this.secondaryDisabledForegroundColor,
    this.iconForegroundColor,
    this.iconDisabledForegroundColor,
    this.assetScale = 4,
    this.wideCenterSlice,
    this.hasWideOrnament = false,
    this.wideOrnamentAssetScale,
    this.wideOrnamentMinButtonHeight = 0,
    this.standardWideMinHeight,
    this.wideArtworkOffsetY = 0,
    this.widePressedArtworkOffsetY,
    this.wideBorderRadius = 8,
    this.iconBorderRadius = 10,
  });

  final String assetRoot;
  final String assetStem;
  final bool supportsWide;
  final bool supportsIcon;
  final Color foregroundColor;
  final Color disabledForegroundColor;
  final Color? secondaryForegroundColor;
  final Color? secondaryDisabledForegroundColor;
  final Color? iconForegroundColor;
  final Color? iconDisabledForegroundColor;
  final Color focusColor;
  final Color focusGlowColor;
  final double assetScale;
  final Rect? wideCenterSlice;
  final bool hasWideOrnament;
  final double? wideOrnamentAssetScale;
  final double wideOrnamentMinButtonHeight;
  final double? standardWideMinHeight;
  final double wideArtworkOffsetY;
  final double? widePressedArtworkOffsetY;
  final double wideBorderRadius;
  final double iconBorderRadius;

  double wideArtworkOffsetFor(ThemeSkinButtonVisualState state) {
    if (state == ThemeSkinButtonVisualState.pressed) {
      return widePressedArtworkOffsetY ?? wideArtworkOffsetY;
    }
    return wideArtworkOffsetY;
  }

  WidgetStateProperty<Color?> foregroundProperty({
    required ThemeSkinButtonForm form,
    bool primary = true,
  }) {
    final enabledColor = switch ((form, primary)) {
      (ThemeSkinButtonForm.icon, true) =>
        iconForegroundColor ?? foregroundColor,
      (ThemeSkinButtonForm.icon, false) =>
        secondaryForegroundColor ?? foregroundColor,
      (ThemeSkinButtonForm.wide, true) => foregroundColor,
      (ThemeSkinButtonForm.wide, false) =>
        secondaryForegroundColor ?? foregroundColor,
    };
    final disabledColor = switch ((form, primary)) {
      (ThemeSkinButtonForm.icon, true) =>
        iconDisabledForegroundColor ?? disabledForegroundColor,
      (ThemeSkinButtonForm.icon, false) =>
        secondaryDisabledForegroundColor ?? disabledForegroundColor,
      (ThemeSkinButtonForm.wide, true) => disabledForegroundColor,
      (ThemeSkinButtonForm.wide, false) =>
        secondaryDisabledForegroundColor ?? disabledForegroundColor,
    };
    return WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabledColor;
      }
      return enabledColor;
    });
  }

  String? assetFor({
    required ThemeSkinButtonForm form,
    required bool primary,
    required ThemeSkinButtonVisualState state,
  }) {
    final supported = switch (form) {
      ThemeSkinButtonForm.wide => supportsWide,
      ThemeSkinButtonForm.icon => supportsIcon,
    };
    if (!supported) {
      return null;
    }
    final tone = primary ? 'primary' : 'secondary';
    return '$assetRoot/$assetStem-${form.name}-$tone-${state.name}.png';
  }

  String? wideOrnamentAssetFor({
    required bool primary,
    required ThemeSkinButtonVisualState state,
  }) {
    if (!supportsWide || !hasWideOrnament) {
      return null;
    }
    final tone = primary ? 'primary' : 'secondary';
    return '$assetRoot/$assetStem-wide-$tone-${state.name}-ornament.png';
  }
}

@immutable
class ThemeSkinSpec {
  const ThemeSkinSpec({
    required this.id,
    required this.avatarAsset,
    required this.backgroundRoot,
    required this.landscapeAlignment,
    required this.portraitAlignment,
    required this.artworkOpacity,
    required this.scrimColor,
    required this.scrimOpacity,
    required this.motionPolicy,
    required this.motionOpacity,
    required this.staticEffectPolicy,
    required this.staticEffectOpacity,
    required this.drawerMaterial,
    this.buttons,
  });

  final String id;
  final String avatarAsset;
  final String backgroundRoot;
  final Alignment landscapeAlignment;
  final Alignment portraitAlignment;
  final double artworkOpacity;
  final Color scrimColor;
  final double scrimOpacity;
  final ThemeSkinEffectPolicy motionPolicy;
  final double motionOpacity;
  final ThemeSkinEffectPolicy staticEffectPolicy;
  final double staticEffectOpacity;
  final ThemeSkinDrawerMaterialToken drawerMaterial;
  final ThemeSkinButtonSpec? buttons;
}

abstract final class ThemeSkinAssets {
  static const String aprilFoolsThemeId = 'april_fools';
  static const String cthulhuThemeId = 'cthulhu';
  static const String riftRelayThemeId = 'rift_relay';
  static const String flowerNotFlowerThemeId = 'flower_not_flower';
  static const String mechanicalCityThemeId = 'mechanical_city';
  static const String rainRadioThemeId = 'rain_radio';
  static const String skyPastureThemeId = 'sky_pasture';
  static const String vinylMemoriesThemeId = 'vinyl_memories';

  static const List<String> presetThemeIds = <String>[
    aprilFoolsThemeId,
    cthulhuThemeId,
    riftRelayThemeId,
    flowerNotFlowerThemeId,
    mechanicalCityThemeId,
    rainRadioThemeId,
    skyPastureThemeId,
    vinylMemoriesThemeId,
  ];

  static const Map<String, ThemeSkinSpec> _specs = <String, ThemeSkinSpec>{
    aprilFoolsThemeId: ThemeSkinSpec(
      id: aprilFoolsThemeId,
      avatarAsset: 'assets/theme_skins/april_fools/avatars/avatar.webp',
      backgroundRoot: 'assets/theme_skins/april_fools/backgrounds',
      landscapeAlignment: Alignment.center,
      portraitAlignment: Alignment.center,
      artworkOpacity: 0.94,
      scrimColor: Color(0xFF050607),
      scrimOpacity: 0.12,
      motionPolicy: ThemeSkinEffectPolicy.none,
      motionOpacity: 0,
      staticEffectPolicy: ThemeSkinEffectPolicy.ambientOnly,
      staticEffectOpacity: 0.22,
      drawerMaterial: ThemeSkinDrawerMaterialToken.signalNoise,
      buttons: ThemeSkinButtonSpec(
        assetRoot: 'assets/theme_skins/april_fools/buttons',
        assetStem: 'april-fools',
        supportsWide: true,
        supportsIcon: true,
        foregroundColor: Color(0xFF171B22),
        disabledForegroundColor: Color(0x85171B22),
        focusColor: Color(0xFFB3FF8F),
        focusGlowColor: Color(0x66FF4444),
        wideCenterSlice: Rect.fromLTRB(44, 12, 75, 38),
        hasWideOrnament: true,
        wideBorderRadius: 6,
        iconBorderRadius: 8,
      ),
    ),
    cthulhuThemeId: ThemeSkinSpec(
      id: cthulhuThemeId,
      avatarAsset: 'assets/theme_skins/cthulhu/avatars/avatar.webp',
      backgroundRoot: 'assets/theme_skins/cthulhu/backgrounds',
      landscapeAlignment: Alignment.center,
      portraitAlignment: Alignment.center,
      artworkOpacity: 0.92,
      scrimColor: Color(0xFF050000),
      scrimOpacity: 0.16,
      motionPolicy: ThemeSkinEffectPolicy.ambientOnly,
      motionOpacity: 0.12,
      staticEffectPolicy: ThemeSkinEffectPolicy.ambientOnly,
      staticEffectOpacity: 0.16,
      drawerMaterial: ThemeSkinDrawerMaterialToken.occultLeather,
      buttons: ThemeSkinButtonSpec(
        assetRoot: 'assets/theme_skins/cthulhu/buttons',
        assetStem: 'cthulhu',
        supportsWide: true,
        supportsIcon: true,
        foregroundColor: Color(0xFFDED1C5),
        disabledForegroundColor: Color(0x85DED1C5),
        focusColor: Color(0xFFABC69A),
        focusGlowColor: Color(0x66701414),
        wideCenterSlice: Rect.fromLTRB(30, 12, 92.5, 42),
        hasWideOrnament: true,
        wideBorderRadius: 8,
        iconBorderRadius: 8,
      ),
    ),
    riftRelayThemeId: ThemeSkinSpec(
      id: riftRelayThemeId,
      avatarAsset: 'assets/theme_skins/rift_relay/avatars/avatar.webp',
      backgroundRoot: 'assets/theme_skins/rift_relay/backgrounds',
      landscapeAlignment: Alignment.center,
      portraitAlignment: Alignment.center,
      artworkOpacity: 0.96,
      scrimColor: Color(0xFF061116),
      scrimOpacity: 0.10,
      motionPolicy: ThemeSkinEffectPolicy.ambientOnly,
      motionOpacity: 0.20,
      staticEffectPolicy: ThemeSkinEffectPolicy.none,
      staticEffectOpacity: 0,
      drawerMaterial: ThemeSkinDrawerMaterialToken.relayMetal,
      buttons: ThemeSkinButtonSpec(
        assetRoot: 'assets/theme_skins/rift_relay/buttons',
        assetStem: 'rift-relay',
        supportsWide: true,
        supportsIcon: true,
        foregroundColor: Color(0xFF10141A),
        disabledForegroundColor: Color(0x8510141A),
        secondaryForegroundColor: Color(0xFFD6DBE2),
        secondaryDisabledForegroundColor: Color(0x85D6DBE2),
        focusColor: Color(0xFF00D5FF),
        focusGlowColor: Color(0x6600D5FF),
        wideCenterSlice: Rect.fromLTRB(35, 10, 83, 36),
        hasWideOrnament: true,
        wideBorderRadius: 4,
        iconBorderRadius: 6,
      ),
    ),
    flowerNotFlowerThemeId: ThemeSkinSpec(
      id: flowerNotFlowerThemeId,
      avatarAsset: 'assets/theme_skins/flower_not_flower/avatars/avatar.webp',
      backgroundRoot: 'assets/theme_skins/flower_not_flower/backgrounds',
      landscapeAlignment: Alignment.center,
      portraitAlignment: Alignment.center,
      artworkOpacity: 0.96,
      scrimColor: Color(0xFFF7F1E8),
      scrimOpacity: 0.08,
      motionPolicy: ThemeSkinEffectPolicy.ambientOnly,
      motionOpacity: 0.14,
      staticEffectPolicy: ThemeSkinEffectPolicy.none,
      staticEffectOpacity: 0,
      drawerMaterial: ThemeSkinDrawerMaterialToken.ricePaper,
      buttons: ThemeSkinButtonSpec(
        assetRoot: 'assets/theme_skins/flower_not_flower/buttons',
        assetStem: 'flower-not-flower',
        supportsWide: true,
        supportsIcon: true,
        foregroundColor: Color(0xFF4A3835),
        disabledForegroundColor: Color(0x854A3835),
        focusColor: Color(0xFFA67A7B),
        focusGlowColor: Color(0x66C1ADA8),
        wideCenterSlice: Rect.fromLTRB(44, 12, 78, 36),
        hasWideOrnament: true,
      ),
    ),
    mechanicalCityThemeId: ThemeSkinSpec(
      id: mechanicalCityThemeId,
      avatarAsset: 'assets/theme_skins/mechanical_city/avatars/avatar.webp',
      backgroundRoot: 'assets/theme_skins/mechanical_city/backgrounds',
      landscapeAlignment: Alignment.center,
      portraitAlignment: Alignment.center,
      artworkOpacity: 0.90,
      scrimColor: Color(0xFF0E0B08),
      scrimOpacity: 0.13,
      motionPolicy: ThemeSkinEffectPolicy.none,
      motionOpacity: 0,
      staticEffectPolicy: ThemeSkinEffectPolicy.none,
      staticEffectOpacity: 0,
      drawerMaterial: ThemeSkinDrawerMaterialToken.rivetedBrass,
      buttons: ThemeSkinButtonSpec(
        assetRoot: 'assets/theme_skins/mechanical_city/buttons',
        assetStem: 'mechanical-city',
        supportsWide: true,
        supportsIcon: true,
        foregroundColor: Color(0xFFEAD7B9),
        disabledForegroundColor: Color(0x85EAD7B9),
        iconForegroundColor: Color(0xFF26180F),
        iconDisabledForegroundColor: Color(0x8526180F),
        focusColor: Color(0xFFD8AD62),
        focusGlowColor: Color(0x66B77B35),
        wideCenterSlice: Rect.fromLTRB(44, 12, 78, 36),
        hasWideOrnament: true,
        wideOrnamentAssetScale: 6.5,
        wideOrnamentMinButtonHeight: 56,
        standardWideMinHeight: 56,
        wideArtworkOffsetY: -6.4,
        wideBorderRadius: 6,
        iconBorderRadius: 8,
      ),
    ),
    rainRadioThemeId: ThemeSkinSpec(
      id: rainRadioThemeId,
      avatarAsset: 'assets/theme_skins/rain_radio/avatars/avatar.webp',
      backgroundRoot: 'assets/theme_skins/rain_radio/backgrounds',
      landscapeAlignment: Alignment.bottomCenter,
      portraitAlignment: Alignment.bottomCenter,
      artworkOpacity: 0.94,
      scrimColor: Color(0xFF061520),
      scrimOpacity: 0.10,
      motionPolicy: ThemeSkinEffectPolicy.ambientOnly,
      motionOpacity: 0.16,
      staticEffectPolicy: ThemeSkinEffectPolicy.none,
      staticEffectOpacity: 0,
      drawerMaterial: ThemeSkinDrawerMaterialToken.rainGlass,
      buttons: ThemeSkinButtonSpec(
        assetRoot: 'assets/theme_skins/rain_radio/buttons',
        assetStem: 'rain-radio',
        supportsWide: true,
        supportsIcon: true,
        foregroundColor: Color(0xFF07121A),
        disabledForegroundColor: Color(0x8507121A),
        secondaryForegroundColor: Color(0xFFE5F4F8),
        secondaryDisabledForegroundColor: Color(0x85E5F4F8),
        focusColor: Color(0xFFD7EBF2),
        focusGlowColor: Color(0x669BBDCA),
        wideCenterSlice: Rect.fromLTRB(30, 12, 91, 64),
        hasWideOrnament: true,
        wideOrnamentAssetScale: 9,
        wideOrnamentMinButtonHeight: 56,
        standardWideMinHeight: 56,
        wideArtworkOffsetY: -6.2,
        widePressedArtworkOffsetY: -3.2,
        wideBorderRadius: 12,
        iconBorderRadius: 12,
      ),
    ),
    skyPastureThemeId: ThemeSkinSpec(
      id: skyPastureThemeId,
      avatarAsset: 'assets/theme_skins/sky_pasture/avatars/avatar.webp',
      backgroundRoot: 'assets/theme_skins/sky_pasture/backgrounds',
      landscapeAlignment: Alignment.bottomCenter,
      portraitAlignment: Alignment.bottomCenter,
      artworkOpacity: 1,
      scrimColor: Color(0xFF2F6F7D),
      scrimOpacity: 0.09,
      motionPolicy: ThemeSkinEffectPolicy.full,
      motionOpacity: 0.36,
      staticEffectPolicy: ThemeSkinEffectPolicy.none,
      staticEffectOpacity: 0,
      drawerMaterial: ThemeSkinDrawerMaterialToken.paintedPasture,
      buttons: ThemeSkinButtonSpec(
        assetRoot: 'assets/theme_skins/sky_pasture/buttons',
        assetStem: 'sky-pasture',
        supportsWide: true,
        supportsIcon: true,
        foregroundColor: Color(0xFF274C55),
        disabledForegroundColor: Color(0x947D8D83),
        focusColor: Color(0xFF2F6F7D),
        focusGlowColor: Color(0x558FC6E0),
        wideCenterSlice: Rect.fromLTRB(13, 11, 80, 37),
        hasWideOrnament: true,
      ),
    ),
    vinylMemoriesThemeId: ThemeSkinSpec(
      id: vinylMemoriesThemeId,
      avatarAsset: 'assets/theme_skins/vinyl_memories/avatars/avatar.webp',
      backgroundRoot: 'assets/theme_skins/vinyl_memories/backgrounds',
      landscapeAlignment: Alignment.center,
      portraitAlignment: Alignment.center,
      artworkOpacity: 0.90,
      scrimColor: Color(0xFF120A06),
      scrimOpacity: 0.14,
      motionPolicy: ThemeSkinEffectPolicy.none,
      motionOpacity: 0,
      staticEffectPolicy: ThemeSkinEffectPolicy.none,
      staticEffectOpacity: 0,
      drawerMaterial: ThemeSkinDrawerMaterialToken.vinylLacquer,
      buttons: ThemeSkinButtonSpec(
        assetRoot: 'assets/theme_skins/vinyl_memories/buttons',
        assetStem: 'vinyl-memories',
        supportsWide: true,
        supportsIcon: true,
        foregroundColor: Color(0xFF211409),
        disabledForegroundColor: Color(0x85211409),
        secondaryForegroundColor: Color(0xFFF8E1B5),
        secondaryDisabledForegroundColor: Color(0x85F8E1B5),
        focusColor: Color(0xFFFFD796),
        focusGlowColor: Color(0x66E0B56F),
        wideCenterSlice: Rect.fromLTRB(35, 13, 86, 37),
        hasWideOrnament: true,
        wideOrnamentAssetScale: 6,
        wideOrnamentMinButtonHeight: 48,
        wideBorderRadius: 6,
        iconBorderRadius: 8,
      ),
    ),
  };

  static ThemeSkinSpec? specFor(String themeId) => _specs[themeId];

  static ThemeSkinButtonSpec? buttonSpecFor(String themeId) =>
      _specs[themeId]?.buttons;

  static bool hasBackdrop(String themeId) => _specs.containsKey(themeId);

  static bool hasWideButtonArtwork(String themeId) =>
      _specs[themeId]?.buttons?.supportsWide ?? false;

  static bool hasIconButtonArtwork(String themeId) =>
      _specs[themeId]?.buttons?.supportsIcon ?? false;

  static String? avatarAssetFor(String themeId) => _specs[themeId]?.avatarAsset;

  static String? backdropAssetFor(
    String themeId, {
    required bool landscape,
  }) {
    final spec = _specs[themeId];
    if (spec == null) {
      return null;
    }
    final orientation = landscape ? 'landscape' : 'portrait';
    return '${spec.backgroundRoot}/$orientation.webp';
  }

  static Alignment backdropAlignmentFor(
    String themeId, {
    required bool landscape,
  }) {
    final spec = _specs[themeId];
    if (spec == null) {
      return Alignment.center;
    }
    return landscape ? spec.landscapeAlignment : spec.portraitAlignment;
  }

  static String? buttonAssetFor(
    String themeId, {
    required ThemeSkinButtonForm form,
    required bool primary,
    required ThemeSkinButtonVisualState state,
  }) {
    return _specs[themeId]?.buttons?.assetFor(
          form: form,
          primary: primary,
          state: state,
        );
  }

  static ButtonLayerBuilder? wideButtonLayerFor(
    String themeId, {
    required bool secondary,
  }) {
    final buttons = _specs[themeId]?.buttons;
    if (buttons == null || !buttons.supportsWide) {
      return null;
    }
    return (context, states, child) => _ThemeSkinButtonLayer(
          spec: buttons,
          states: states,
          primary: !secondary,
          compact: false,
          child: child,
        );
  }

  static ButtonLayerBuilder? iconButtonLayerFor(
    String themeId, {
    required bool primary,
  }) {
    final buttons = _specs[themeId]?.buttons;
    if (buttons == null || !buttons.supportsIcon) {
      return null;
    }
    return (context, states, child) => _ThemeSkinButtonLayer(
          spec: buttons,
          states: states,
          primary: primary,
          compact: true,
          child: child,
        );
  }
}

class ThemeSkinBackdropArtwork extends StatelessWidget {
  const ThemeSkinBackdropArtwork({
    super.key,
    required this.themeId,
  });

  final String themeId;

  @override
  Widget build(BuildContext context) {
    final spec = ThemeSkinAssets.specFor(themeId);
    if (spec == null) {
      return const SizedBox.expand();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth >= constraints.maxHeight;
        final asset = ThemeSkinAssets.backdropAssetFor(
          themeId,
          landscape: landscape,
        )!;
        return Opacity(
          opacity: spec.artworkOpacity,
          child: Image.asset(
            asset,
            key: ValueKey<String>(asset),
            fit: BoxFit.cover,
            alignment: ThemeSkinAssets.backdropAlignmentFor(
              themeId,
              landscape: landscape,
            ),
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _ThemeSkinButtonLayer extends StatelessWidget {
  const _ThemeSkinButtonLayer({
    required this.spec,
    required this.states,
    required this.primary,
    required this.compact,
    required this.child,
  });

  final ThemeSkinButtonSpec spec;
  final Set<WidgetState> states;
  final bool primary;
  final bool compact;
  final Widget? child;

  ThemeSkinButtonVisualState get _visualState {
    if (states.contains(WidgetState.pressed)) {
      return ThemeSkinButtonVisualState.pressed;
    }
    if (states.contains(WidgetState.hovered)) {
      return ThemeSkinButtonVisualState.hover;
    }
    return ThemeSkinButtonVisualState.normal;
  }

  @override
  Widget build(BuildContext context) {
    final disabled = states.contains(WidgetState.disabled);
    final focused = states.contains(WidgetState.focused);
    final visualState =
        disabled ? ThemeSkinButtonVisualState.normal : _visualState;
    final form = compact ? ThemeSkinButtonForm.icon : ThemeSkinButtonForm.wide;
    return Stack(
      fit: StackFit.loose,
      alignment: Alignment.center,
      children: <Widget>[
        for (final state in ThemeSkinButtonVisualState.values)
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(
                0,
                compact ? 0 : spec.wideArtworkOffsetFor(state),
              ),
              child: Opacity(
                opacity: visualState == state ? (disabled ? 0.46 : 1) : 0,
                child: Image.asset(
                  spec.assetFor(
                    form: form,
                    primary: primary,
                    state: state,
                  )!,
                  scale: spec.assetScale,
                  fit: BoxFit.fill,
                  centerSlice: compact ? null : spec.wideCenterSlice,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        if (!compact && spec.hasWideOrnament)
          for (final state in ThemeSkinButtonVisualState.values)
            Positioned.fill(
              child: Opacity(
                opacity: visualState == state ? (disabled ? 0.46 : 1) : 0,
                child: _ThemeSkinWideButtonOrnament(
                  asset: spec.wideOrnamentAssetFor(
                    primary: primary,
                    state: state,
                  )!,
                  scale: spec.wideOrnamentAssetScale ?? spec.assetScale,
                  minButtonHeight: spec.wideOrnamentMinButtonHeight,
                ),
              ),
            ),
        if (child != null) child!,
        if (focused)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    compact ? spec.iconBorderRadius : spec.wideBorderRadius,
                  ),
                  border: Border.all(
                    color: spec.focusColor,
                    width: 2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: spec.focusGlowColor,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ThemeSkinWideButtonOrnament extends StatelessWidget {
  const _ThemeSkinWideButtonOrnament({
    required this.asset,
    required this.scale,
    required this.minButtonHeight,
  });

  final String asset;
  final double scale;
  final double minButtonHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight + 0.01 < minButtonHeight) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topCenter,
          child: Image.asset(
            asset,
            scale: scale,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
        );
      },
    );
  }
}
