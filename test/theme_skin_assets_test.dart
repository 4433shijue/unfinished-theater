import 'dart:ui' as ui;

import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:ai_roleplay_chat/theme/theme_skin_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppTheme.registerRuntimeThemes(const <RuntimeThemeDefinition>[]);
    AppTheme.themeFor(AppThemeVariant.sakura.id);
  });

  test('all preset artwork assets are bundled', () async {
    expect(ThemeSkinAssets.presetThemeIds, hasLength(8));
    final personalityThemeIds = AppThemeVariant.values
        .where((variant) => !variant.isBasicPalette)
        .map((variant) => variant.id);
    expect(
      personalityThemeIds,
      unorderedEquals(ThemeSkinAssets.presetThemeIds),
    );
    final avatarAssets = <String>{};

    for (final themeId in ThemeSkinAssets.presetThemeIds) {
      final spec = ThemeSkinAssets.specFor(themeId);
      expect(spec, isNotNull, reason: themeId);
      expect(spec!.id, themeId);
      expect(spec.artworkOpacity, inInclusiveRange(0, 1));
      expect(spec.scrimOpacity, inInclusiveRange(0, 1));
      expect(spec.motionOpacity, inInclusiveRange(0, 1));
      expect(spec.staticEffectOpacity, inInclusiveRange(0, 1));

      final avatarAsset = ThemeSkinAssets.avatarAssetFor(themeId);
      expect(avatarAsset, isNotNull, reason: themeId);
      expect(avatarAssets.add(avatarAsset!), isTrue, reason: avatarAsset);
      expect(avatarAsset, endsWith('/avatars/avatar.webp'));
      final avatarData = await rootBundle.load(avatarAsset);
      final codec = await ui.instantiateImageCodec(
        avatarData.buffer.asUint8List(
          avatarData.offsetInBytes,
          avatarData.lengthInBytes,
        ),
      );
      expect(codec.frameCount, 1, reason: avatarAsset);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 512, reason: avatarAsset);
      expect(frame.image.height, 512, reason: avatarAsset);
      frame.image.dispose();
      codec.dispose();

      for (final landscape in <bool>[true, false]) {
        final asset = ThemeSkinAssets.backdropAssetFor(
          themeId,
          landscape: landscape,
        );
        expect(asset, isNotNull, reason: themeId);
        final data = await rootBundle.load(asset!);
        expect(data.lengthInBytes, greaterThan(0), reason: asset);
      }
    }
  });

  test('button assets and capabilities follow the preset matrix', () async {
    const capabilities = <String, ({bool wide, bool icon})>{
      ThemeSkinAssets.aprilFoolsThemeId: (wide: true, icon: true),
      ThemeSkinAssets.cthulhuThemeId: (wide: true, icon: true),
      ThemeSkinAssets.riftRelayThemeId: (wide: true, icon: true),
      ThemeSkinAssets.flowerNotFlowerThemeId: (wide: true, icon: true),
      ThemeSkinAssets.mechanicalCityThemeId: (wide: true, icon: true),
      ThemeSkinAssets.rainRadioThemeId: (wide: true, icon: true),
      ThemeSkinAssets.skyPastureThemeId: (wide: true, icon: true),
      ThemeSkinAssets.vinylMemoriesThemeId: (wide: true, icon: true),
    };

    for (final entry in capabilities.entries) {
      final themeId = entry.key;
      expect(
        ThemeSkinAssets.hasWideButtonArtwork(themeId),
        entry.value.wide,
        reason: themeId,
      );
      expect(
        ThemeSkinAssets.hasIconButtonArtwork(themeId),
        entry.value.icon,
        reason: themeId,
      );

      for (final form in ThemeSkinButtonForm.values) {
        final supported = switch (form) {
          ThemeSkinButtonForm.wide => entry.value.wide,
          ThemeSkinButtonForm.icon => entry.value.icon,
        };
        for (final primary in <bool>[true, false]) {
          for (final state in ThemeSkinButtonVisualState.values) {
            final asset = ThemeSkinAssets.buttonAssetFor(
              themeId,
              form: form,
              primary: primary,
              state: state,
            );
            if (!supported) {
              expect(asset, isNull, reason: '$themeId ${form.name}');
              continue;
            }
            expect(asset, isNotNull, reason: '$themeId ${form.name}');
            final data = await rootBundle.load(asset!);
            expect(data.lengthInBytes, greaterThan(0), reason: asset);
          }
        }
      }

      final buttons = ThemeSkinAssets.buttonSpecFor(themeId);
      if (buttons?.hasWideOrnament ?? false) {
        for (final primary in <bool>[true, false]) {
          for (final state in ThemeSkinButtonVisualState.values) {
            final asset = buttons!.wideOrnamentAssetFor(
              primary: primary,
              state: state,
            );
            expect(asset, isNotNull);
            final data = await rootBundle.load(asset!);
            expect(data.lengthInBytes, greaterThan(0), reason: asset);
          }
        }
      }
    }
  });

  test('button specs can resolve foregrounds per tone and disabled state', () {
    const spec = ThemeSkinButtonSpec(
      assetRoot: 'unused',
      assetStem: 'unused',
      supportsWide: true,
      supportsIcon: true,
      foregroundColor: Color(0xFF10141A),
      disabledForegroundColor: Color(0x8510141A),
      secondaryForegroundColor: Color(0xFFD6DBE2),
      secondaryDisabledForegroundColor: Color(0x85D6DBE2),
      iconForegroundColor: Color(0xFF26180F),
      iconDisabledForegroundColor: Color(0x8526180F),
      focusColor: Colors.cyan,
      focusGlowColor: Colors.cyanAccent,
    );

    final primaryWide = spec.foregroundProperty(
      form: ThemeSkinButtonForm.wide,
      primary: true,
    );
    final secondaryWide = spec.foregroundProperty(
      form: ThemeSkinButtonForm.wide,
      primary: false,
    );
    final primaryIcon = spec.foregroundProperty(
      form: ThemeSkinButtonForm.icon,
      primary: true,
    );

    expect(primaryWide.resolve(<WidgetState>{}), const Color(0xFF10141A));
    expect(secondaryWide.resolve(<WidgetState>{}), const Color(0xFFD6DBE2));
    expect(
      secondaryWide.resolve(<WidgetState>{WidgetState.disabled}),
      const Color(0x85D6DBE2),
    );
    expect(primaryIcon.resolve(<WidgetState>{}), const Color(0xFF26180F));
  });

  testWidgets('backdrop selects orientation-specific artwork and alignment',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const themeId = ThemeSkinAssets.rainRadioThemeId;
    tester.view.physicalSize = const Size(1200, 600);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ThemeSkinBackdropArtwork(themeId: themeId),
      ),
    );
    var image = tester.widget<Image>(find.byType(Image));
    expect(
      _assetName(image),
      ThemeSkinAssets.backdropAssetFor(themeId, landscape: true),
    );
    expect(
      image.alignment,
      ThemeSkinAssets.backdropAlignmentFor(themeId, landscape: true),
    );

    tester.view.physicalSize = const Size(600, 1200);
    await tester.pump();
    image = tester.widget<Image>(find.byType(Image));
    expect(
      _assetName(image),
      ThemeSkinAssets.backdropAssetFor(themeId, landscape: false),
    );
    expect(
      image.alignment,
      ThemeSkinAssets.backdropAlignmentFor(themeId, landscape: false),
    );
  });

  testWidgets('themes without artwork do not build a background image',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ThemeSkinBackdropArtwork(themeId: 'sakura'),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(ThemeSkinAssets.specFor('sakura'), isNull);
    expect(ThemeSkinAssets.avatarAssetFor('sakura'), isNull);
  });

  test('preset themes enable only their declared raster capabilities', () {
    const capabilities = <String, ({bool wide, bool icon})>{
      ThemeSkinAssets.aprilFoolsThemeId: (wide: true, icon: true),
      ThemeSkinAssets.cthulhuThemeId: (wide: true, icon: true),
      ThemeSkinAssets.riftRelayThemeId: (wide: true, icon: true),
      ThemeSkinAssets.flowerNotFlowerThemeId: (wide: true, icon: true),
      ThemeSkinAssets.mechanicalCityThemeId: (wide: true, icon: true),
      ThemeSkinAssets.rainRadioThemeId: (wide: true, icon: true),
      ThemeSkinAssets.skyPastureThemeId: (wide: true, icon: true),
      ThemeSkinAssets.vinylMemoriesThemeId: (wide: true, icon: true),
    };

    for (final entry in capabilities.entries) {
      final theme = AppTheme.themeFor(entry.key);
      expect(AppTheme.activePresetThemeId, entry.key);
      expect(AppTheme.usesPresetBackdropArtwork, isTrue, reason: entry.key);
      expect(
        AppTheme.usesRasterWideButtonArtwork,
        entry.value.wide,
        reason: entry.key,
      );
      expect(
        AppTheme.usesRasterIconButtonArtwork,
        entry.value.icon,
        reason: entry.key,
      );
      expect(
        theme.filledButtonTheme.style?.backgroundBuilder != null,
        entry.value.wide,
        reason: entry.key,
      );
      expect(
        theme.outlinedButtonTheme.style?.backgroundBuilder != null,
        entry.value.wide,
        reason: entry.key,
      );
      expect(
        AppTheme.skinIconButtonStyle() != null,
        entry.value.icon,
        reason: entry.key,
      );
      expect(
        AppTheme.skinTonalButtonStyle() != null,
        entry.value.wide,
        reason: entry.key,
      );
      expect(
        AppTheme.shellBackgroundGradient.colors,
        everyElement(Colors.transparent),
        reason: entry.key,
      );
    }

    final mechanicalTheme =
        AppTheme.themeFor(ThemeSkinAssets.mechanicalCityThemeId);
    expect(
      mechanicalTheme.filledButtonTheme.style?.foregroundColor?.resolve(
        <WidgetState>{},
      ),
      const Color(0xFFEAD7B9),
      reason: 'mechanical button text must contrast with its dark leather face',
    );
    expect(
      AppTheme.skinIconButtonStyle(primary: true)
          ?.foregroundColor
          ?.resolve(<WidgetState>{}),
      const Color(0xFF26180F),
      reason: 'mechanical icon text must contrast with its light brass face',
    );
  });

  test('basic and runtime themes never inherit preset raster artwork', () {
    final basic = AppTheme.themeFor(AppThemeVariant.sakura.id);
    expect(AppTheme.usesPresetBackdropArtwork, isFalse);
    expect(AppTheme.usesRasterWideButtonArtwork, isFalse);
    expect(AppTheme.usesRasterIconButtonArtwork, isFalse);
    expect(basic.filledButtonTheme.style?.backgroundBuilder, isNull);
    expect(basic.outlinedButtonTheme.style?.backgroundBuilder, isNull);
    expect(basic.filledButtonTheme.style?.foregroundBuilder, isNull);
    expect(basic.outlinedButtonTheme.style?.foregroundBuilder, isNull);
    expect(AppTheme.skinIconButtonStyle(), isNull);
    expect(AppTheme.skinTonalButtonStyle(), isNull);
    expect(
      AppTheme.shellBackgroundGradient.colors,
      isNot(everyElement(Colors.transparent)),
    );

    AppTheme.registerRuntimeThemes(<RuntimeThemeDefinition>[
      RuntimeThemeDefinition(
        id: 'custom-april',
        label: 'Custom April',
        description: 'Runtime theme',
        baseThemeId: AppThemeVariant.aprilFools.id,
        palette: AppThemeVariant.aprilFools.palette,
      ),
    ]);
    final custom = AppTheme.themeFor('custom-april');
    expect(AppTheme.activePresetThemeId, isNull);
    expect(AppTheme.usesPresetBackdropArtwork, isFalse);
    expect(AppTheme.usesRasterWideButtonArtwork, isFalse);
    expect(AppTheme.usesRasterIconButtonArtwork, isFalse);
    expect(custom.filledButtonTheme.style?.backgroundBuilder, isNull);
    expect(custom.outlinedButtonTheme.style?.backgroundBuilder, isNull);
    expect(custom.filledButtonTheme.style?.foregroundBuilder, isNull);
    expect(custom.outlinedButtonTheme.style?.foregroundBuilder, isNull);
    expect(AppTheme.skinIconButtonStyle(), isNull);
    expect(AppTheme.skinTonalButtonStyle(), isNull);
    expect(
      AppTheme.shellBackgroundGradient.colors,
      isNot(everyElement(Colors.transparent)),
    );
  });

  testWidgets('generic wide button layer switches visual state assets',
      (tester) async {
    for (final themeId in ThemeSkinAssets.presetThemeIds) {
      final states = WidgetStatesController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeFor(themeId),
          home: Center(
            child: SizedBox(
              width: 180,
              height: 52,
              child: FilledButton(
                statesController: states,
                onPressed: () {},
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      );

      final button = find.byType(FilledButton);
      expect(
          _activeButtonAsset(tester, button), contains('wide-primary-normal'));

      states.update(WidgetState.hovered, true);
      await tester.pump();
      expect(
          _activeButtonAsset(tester, button), contains('wide-primary-hover'));

      states.update(WidgetState.pressed, true);
      await tester.pump();
      expect(
        _activeButtonAsset(tester, button),
        contains('wide-primary-pressed'),
      );
      states.dispose();
    }
  });

  testWidgets('generic icon layer keeps button content centered',
      (tester) async {
    for (final themeId in ThemeSkinAssets.presetThemeIds) {
      final states = WidgetStatesController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeFor(themeId),
          home: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FilledButton(
                statesController: states,
                onPressed: () {},
                style: AppTheme.skinFilledIconButtonStyle(
                  base: FilledButton.styleFrom(
                    minimumSize: const Size(44, 46),
                    padding: EdgeInsets.zero,
                  ),
                ),
                child: const Icon(Icons.send_rounded),
              ),
              IconButton.filledTonal(
                style: AppTheme.skinIconButtonStyle(),
                onPressed: () {},
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      );

      final expectedStem = ThemeSkinAssets.buttonSpecFor(themeId)!.assetStem;
      final filledButton = find.byType(FilledButton);
      expect(
        _activeButtonAsset(tester, filledButton),
        contains('$expectedStem-icon-primary-normal'),
      );
      expect(
        _activeButtonAsset(tester, find.byType(IconButton)),
        contains('$expectedStem-icon-secondary-normal'),
      );

      states.update(WidgetState.hovered, true);
      await tester.pump();
      expect(
        _activeButtonAsset(tester, filledButton),
        contains('$expectedStem-icon-primary-hover'),
      );
      states.update(WidgetState.pressed, true);
      await tester.pump();
      expect(
        _activeButtonAsset(tester, filledButton),
        contains('$expectedStem-icon-primary-pressed'),
      );

      final filledIcon = find.descendant(
        of: filledButton,
        matching: find.byIcon(Icons.send_rounded),
      );
      expect(tester.getCenter(filledIcon), tester.getCenter(filledButton));
      states.dispose();
    }
  });

  testWidgets('wide skins center each button content contract', (tester) async {
    for (final themeId in ThemeSkinAssets.presetThemeIds) {
      final theme = AppTheme.themeFor(themeId);
      for (final kind in _WideIconButtonKind.values) {
        final style = kind == _WideIconButtonKind.tonal
            ? AppTheme.skinTonalButtonStyle()
            : null;
        for (final content in _WideButtonContentKind.values) {
          final stem = '$themeId-${kind.name}-${content.name}';
          final buttonKey = ValueKey<String>('$stem-button');
          final labelKey = ValueKey<String>('$stem-label');
          final iconKey = ValueKey<String>('$stem-icon');
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey<String>(stem),
              theme: theme,
              home: Center(
                child: SizedBox(
                  width: 220,
                  height: 56,
                  child: _wideButtonForTest(
                    kind: kind,
                    content: content,
                    buttonKey: buttonKey,
                    labelKey: labelKey,
                    iconKey: iconKey,
                    tonalStyle: style,
                  ),
                ),
              ),
            ),
          );

          final button = find.byKey(buttonKey);
          switch (content) {
            case _WideButtonContentKind.plain:
              final labelCenter = tester.getCenter(find.byKey(labelKey));
              final buttonCenter = tester.getCenter(button);
              expect(
                labelCenter.dx,
                closeTo(buttonCenter.dx, 0.5),
                reason: stem,
              );
              expect(
                labelCenter.dy,
                closeTo(buttonCenter.dy, 0.5),
                reason: stem,
              );
              break;
            case _WideButtonContentKind.iconLabel:
              final groupRect = tester
                  .getRect(find.byKey(iconKey))
                  .expandToInclude(tester.getRect(find.byKey(labelKey)));
              expect(
                groupRect.center.dx,
                closeTo(tester.getCenter(button).dx, 0.5),
                reason: stem,
              );
              expect(
                groupRect.center.dy,
                closeTo(tester.getCenter(button).dy, 0.5),
                reason: stem,
              );
              expect(
                (tester.getCenter(find.byKey(labelKey)).dx -
                        tester.getCenter(button).dx)
                    .abs(),
                greaterThan(1),
                reason: '$stem must center the icon and label together',
              );
              break;
            case _WideButtonContentKind.iconOnly:
              final iconCenter = tester.getCenter(find.byKey(iconKey));
              final buttonCenter = tester.getCenter(button);
              expect(
                iconCenter.dx,
                closeTo(buttonCenter.dx, 0.5),
                reason: stem,
              );
              expect(
                iconCenter.dy,
                closeTo(buttonCenter.dy, 0.5),
                reason: stem,
              );
              break;
          }
          expect(
            _activeButtonAsset(tester, button),
            contains(
              kind == _WideIconButtonKind.filled
                  ? 'wide-primary-normal'
                  : 'wide-secondary-normal',
            ),
            reason: stem,
          );
          expect(tester.takeException(), isNull, reason: stem);
        }
      }
    }
  });

  testWidgets('wide icon labels stay grouped under tight RTL layouts',
      (tester) async {
    const themeId = ThemeSkinAssets.rainRadioThemeId;
    final theme = AppTheme.themeFor(themeId);
    const localBase = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size.zero),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 8),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    for (final textDirection in TextDirection.values) {
      for (final iconAlignment in IconAlignment.values) {
        final suffix = '${textDirection.name}-${iconAlignment.name}';
        final buttonKey = ValueKey<String>('tight-$suffix-button');
        final labelKey = ValueKey<String>('tight-$suffix-label');
        final iconKey = ValueKey<String>('tight-$suffix-icon');
        final style = AppTheme.skinTonalButtonStyle(base: localBase);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey<String>('tight-$suffix'),
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
              child: Directionality(
                textDirection: textDirection,
                child: Center(
                  child: SizedBox(
                    width: 160,
                    height: 34,
                    child: FilledButton.tonalIcon(
                      key: buttonKey,
                      style: style,
                      onPressed: () {},
                      iconAlignment: iconAlignment,
                      icon: Icon(Icons.radio_rounded, key: iconKey, size: 17),
                      label: Text(
                        'Long memory API action',
                        key: labelKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final button = find.byKey(buttonKey);
        final buttonRect = tester.getRect(button);
        final iconRect = tester.getRect(find.byKey(iconKey));
        final labelRect = tester.getRect(find.byKey(labelKey));
        final groupRect = iconRect.expandToInclude(labelRect);
        expect(
          groupRect.center.dx,
          closeTo(buttonRect.center.dx, 0.5),
          reason: suffix,
        );
        expect(
          groupRect.center.dy,
          closeTo(buttonRect.center.dy, 0.5),
          reason: suffix,
        );
        final iconShouldBeLeft = (textDirection == TextDirection.ltr) ==
            (iconAlignment == IconAlignment.start);
        expect(iconRect.center.dx < labelRect.center.dx, iconShouldBeLeft);
        expect(iconRect.left, greaterThanOrEqualTo(buttonRect.left - 0.5));
        expect(iconRect.right, lessThanOrEqualTo(buttonRect.right + 0.5));
        expect(iconRect.top, greaterThanOrEqualTo(buttonRect.top - 0.5));
        expect(iconRect.bottom, lessThanOrEqualTo(buttonRect.bottom + 0.5));
        expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left - 0.5));
        expect(labelRect.right, lessThanOrEqualTo(buttonRect.right + 0.5));
        expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top - 0.5));
        expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom + 0.5));
        expect(tester.getSize(button), const Size(160, 34));
        expect(
          _activeButtonAsset(tester, button),
          contains('wide-secondary-normal'),
          reason: suffix,
        );
        expect(tester.takeException(), isNull, reason: suffix);
      }
    }
  });

  testWidgets('wide skins center compact icon label contents', (tester) async {
    const compactBase = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size.zero),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    for (final themeId in ThemeSkinAssets.presetThemeIds) {
      final theme = AppTheme.themeFor(themeId);
      final tonalStyle = AppTheme.skinTonalButtonStyle(base: compactBase);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<String>('grouped-$themeId'),
          theme: theme,
          home: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  height: 34,
                  child: FilledButton.icon(
                    key: ValueKey<String>('$themeId-grouped-filled-button'),
                    style: compactBase,
                    onPressed: () {},
                    icon: Icon(
                      Icons.savings_outlined,
                      key: ValueKey<String>('$themeId-grouped-filled-icon'),
                      size: 18,
                    ),
                    label: Text(
                      'Toolbar action',
                      key: ValueKey<String>('$themeId-grouped-filled-label'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  height: 34,
                  child: FilledButton.tonalIcon(
                    key: ValueKey<String>('$themeId-grouped-tonal-button'),
                    style: tonalStyle,
                    onPressed: () {},
                    icon: Icon(
                      Icons.map_outlined,
                      key: ValueKey<String>('$themeId-grouped-tonal-icon'),
                      size: 18,
                    ),
                    label: Text(
                      'Toolbar action',
                      key: ValueKey<String>('$themeId-grouped-tonal-label'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  height: 34,
                  child: OutlinedButton.icon(
                    key: ValueKey<String>('$themeId-grouped-outlined-button'),
                    style: compactBase,
                    onPressed: () {},
                    icon: Icon(
                      Icons.event_note_outlined,
                      key: ValueKey<String>('$themeId-grouped-outlined-icon'),
                      size: 18,
                    ),
                    label: Text(
                      'Toolbar action',
                      key: ValueKey<String>('$themeId-grouped-outlined-label'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      for (final kind in _WideIconButtonKind.values) {
        final button = find.byKey(
          ValueKey<String>('$themeId-grouped-${kind.name}-button'),
        );
        final icon = find.byKey(
          ValueKey<String>('$themeId-grouped-${kind.name}-icon'),
        );
        final label = find.byKey(
          ValueKey<String>('$themeId-grouped-${kind.name}-label'),
        );
        final groupRect = tester.getRect(icon).expandToInclude(
              tester.getRect(label),
            );
        expect(
          groupRect.center.dx,
          closeTo(tester.getCenter(button).dx, 0.5),
          reason: '$themeId ${kind.name}',
        );
        expect(
          (tester.getCenter(label).dx - tester.getCenter(button).dx).abs(),
          greaterThan(1),
          reason: '$themeId ${kind.name} should center the group, not label',
        );
        expect(tester.getSize(button).height, 34, reason: themeId);
        expect(
          _activeButtonAsset(tester, button),
          contains(
            kind == _WideIconButtonKind.filled
                ? 'wide-primary-normal'
                : 'wide-secondary-normal',
          ),
          reason: '$themeId ${kind.name}',
        );
      }
      expect(tester.takeException(), isNull, reason: themeId);
    }
  });

  testWidgets('wide grouped contents support intrinsic measurement',
      (tester) async {
    const buttonKey = ValueKey<String>('intrinsic-button');
    const iconKey = ValueKey<String>('intrinsic-icon');
    const labelKey = ValueKey<String>('intrinsic-label');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(ThemeSkinAssets.flowerNotFlowerThemeId),
        home: Center(
          child: IntrinsicWidth(
            child: FilledButton.icon(
              key: buttonKey,
              onPressed: () {},
              icon: const Icon(Icons.local_florist_outlined, key: iconKey),
              label: const Text('Intrinsic label', key: labelKey),
            ),
          ),
        ),
      ),
    );

    final groupRect = tester
        .getRect(find.byKey(iconKey))
        .expandToInclude(tester.getRect(find.byKey(labelKey)));
    expect(
      groupRect.center.dx,
      closeTo(tester.getCenter(find.byKey(buttonKey)).dx, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide skin plain text remains centered', (tester) async {
    for (final themeId in ThemeSkinAssets.presetThemeIds) {
      final buttonKey = ValueKey<String>('$themeId-plain-button');
      final labelKey = ValueKey<String>('$themeId-plain-label');
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<String>('plain-$themeId'),
          theme: AppTheme.themeFor(themeId),
          home: Center(
            child: SizedBox(
              width: 180,
              height: 52,
              child: FilledButton(
                key: buttonKey,
                onPressed: () {},
                child: Text('Label', key: labelKey),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getCenter(find.byKey(labelKey)).dx,
        closeTo(
          tester.getCenter(_activeButtonImage(find.byKey(buttonKey))).dx,
          0.5,
        ),
        reason: themeId,
      );
      expect(tester.takeException(), isNull, reason: themeId);
    }
  });

  testWidgets('wide skins render at the existing 34px compact height',
      (tester) async {
    const fittedOrnamentThemes = <String>{
      ThemeSkinAssets.mechanicalCityThemeId,
      ThemeSkinAssets.rainRadioThemeId,
      ThemeSkinAssets.vinylMemoriesThemeId,
    };
    for (final themeId in ThemeSkinAssets.presetThemeIds) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<String>('compact-$themeId'),
          theme: AppTheme.themeFor(themeId),
          home: Center(
            child: SizedBox(
              width: 120,
              height: 34,
              child: FilledButton(
                key: ValueKey<String>('$themeId-compact-wide'),
                onPressed: () {},
                style: FilledButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Insert'),
              ),
            ),
          ),
        ),
      );

      final button = find.byKey(ValueKey<String>('$themeId-compact-wide'));
      expect(
        find.descendant(of: button, matching: find.byType(Image)),
        findsNWidgets(fittedOrnamentThemes.contains(themeId) ? 3 : 6),
        reason: fittedOrnamentThemes.contains(themeId)
            ? '$themeId should omit ornaments that cannot clear compact text'
            : '$themeId should preload three bases and three ornaments',
      );
      expect(tester.getSize(button), const Size(120, 34));
      expect(tester.takeException(), isNull, reason: themeId);
    }
  });

  testWidgets('fitted wide ornaments stay above standard button labels',
      (tester) async {
    const themeIds = <String>{
      ThemeSkinAssets.mechanicalCityThemeId,
      ThemeSkinAssets.rainRadioThemeId,
      ThemeSkinAssets.vinylMemoriesThemeId,
    };
    for (final themeId in themeIds) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<String>('ornament-$themeId'),
          theme: AppTheme.themeFor(themeId),
          home: Center(
            child: SizedBox(
              width: 180,
              height: themeId == ThemeSkinAssets.vinylMemoriesThemeId ? 52 : 56,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      );

      final button = find.byType(FilledButton);
      final ornament = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              _assetName(widget).endsWith('primary-normal-ornament.png'),
        ),
      );
      final label = find.text('Continue');
      final spec = ThemeSkinAssets.buttonSpecFor(themeId)!;

      expect(ornament, findsOneWidget, reason: themeId);
      expect(
        tester.getSize(ornament).height,
        lessThanOrEqualTo(spec.wideCenterSlice!.top + 1),
        reason: '$themeId ornament should fit inside the fixed top rail',
      );
      expect(
        tester.getRect(ornament).bottom,
        lessThanOrEqualTo(tester.getRect(label).top),
        reason: '$themeId ornament should not enter the label safe area',
      );
      expect(tester.takeException(), isNull, reason: themeId);
    }
  });

  test('mechanical and rain wide geometry stays vertically balanced', () {
    final mechanical = ThemeSkinAssets.buttonSpecFor(
      ThemeSkinAssets.mechanicalCityThemeId,
    )!;
    expect(mechanical.standardWideMinHeight, 56);
    expect(mechanical.wideOrnamentMinButtonHeight, 56);
    for (final state in ThemeSkinButtonVisualState.values) {
      expect(mechanical.wideArtworkOffsetFor(state), -6.4);
    }

    final rain = ThemeSkinAssets.buttonSpecFor(
      ThemeSkinAssets.rainRadioThemeId,
    )!;
    expect(rain.standardWideMinHeight, 56);
    expect(rain.wideOrnamentMinButtonHeight, 56);
    expect(
      rain.wideArtworkOffsetFor(ThemeSkinButtonVisualState.normal),
      -6.2,
    );
    expect(
      rain.wideArtworkOffsetFor(ThemeSkinButtonVisualState.hover),
      -6.2,
    );
    expect(
      rain.wideArtworkOffsetFor(ThemeSkinButtonVisualState.pressed),
      -3.2,
    );
  });

  testWidgets('mechanical and rain standard buttons reserve ornament space',
      (tester) async {
    for (final themeId in <String>{
      ThemeSkinAssets.mechanicalCityThemeId,
      ThemeSkinAssets.rainRadioThemeId,
    }) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<String>('standard-height-$themeId'),
          theme: AppTheme.themeFor(themeId),
          home: Center(
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ),
        ),
      );

      final button = find.byType(FilledButton);
      expect(tester.getSize(button).height, closeTo(56, 0.01));
      expect(
        find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                _assetName(widget).endsWith('primary-normal-ornament.png'),
          ),
        ),
        findsOneWidget,
        reason: themeId,
      );
      expect(tester.takeException(), isNull, reason: themeId);
    }
  });

  testWidgets('wide artwork applies state-specific vertical offsets',
      (tester) async {
    for (final entry in <(String, List<double>)>[
      (
        ThemeSkinAssets.mechanicalCityThemeId,
        const <double>[-6.4, -6.4, -6.4],
      ),
      (
        ThemeSkinAssets.rainRadioThemeId,
        const <double>[-6.2, -6.2, -3.2],
      ),
    ]) {
      final states = WidgetStatesController();
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<String>('offset-${entry.$1}'),
          theme: AppTheme.themeFor(entry.$1),
          home: Center(
            child: SizedBox(
              width: 180,
              height: 56,
              child: FilledButton(
                statesController: states,
                onPressed: () {},
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      );

      final button = find.byType(FilledButton);
      for (var index = 0; index < entry.$2.length; index += 1) {
        if (index == 1) {
          states.update(WidgetState.hovered, true);
        } else if (index == 2) {
          states.update(WidgetState.pressed, true);
        }
        await tester.pump();
        expect(
          tester.getCenter(_activeButtonImage(button)).dy -
              tester.getCenter(button).dy,
          closeTo(entry.$2[index], 0.01),
          reason: '${entry.$1} state $index',
        );
      }
      states.dispose();
      expect(tester.takeException(), isNull, reason: entry.$1);
    }
  });

  testWidgets('skin tonal style uses secondary wide artwork', (tester) async {
    for (final themeId in <String>{
      ThemeSkinAssets.mechanicalCityThemeId,
      ThemeSkinAssets.rainRadioThemeId,
    }) {
      final theme = AppTheme.themeFor(themeId);
      final style = AppTheme.skinTonalButtonStyle();
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<String>('tonal-$themeId'),
          theme: theme,
          home: Center(
            child: FilledButton.tonalIcon(
              style: style,
              onPressed: () {},
              icon: const Icon(
                Icons.cloud_download_outlined,
                key: ValueKey<String>('tonal-icon'),
              ),
              label: const Text(
                'Fetch',
                key: ValueKey<String>('tonal-label'),
              ),
            ),
          ),
        ),
      );

      final button = find.byType(FilledButton);
      expect(
        _activeButtonAsset(tester, button),
        contains('wide-secondary-normal'),
        reason: themeId,
      );
      final groupRect = tester
          .getRect(find.byKey(const ValueKey<String>('tonal-icon')))
          .expandToInclude(
            tester.getRect(find.byKey(const ValueKey<String>('tonal-label'))),
          );
      expect(
        groupRect.center,
        tester.getCenter(button),
        reason: themeId,
      );
      expect(tester.takeException(), isNull, reason: themeId);
    }
  });
}

enum _WideIconButtonKind { filled, tonal, outlined }

enum _WideButtonContentKind { plain, iconLabel, iconOnly }

Widget _wideButtonForTest({
  required _WideIconButtonKind kind,
  required _WideButtonContentKind content,
  required Key buttonKey,
  required Key labelKey,
  required Key iconKey,
  required ButtonStyle? tonalStyle,
}) {
  return switch ((kind, content)) {
    (_WideIconButtonKind.filled, _WideButtonContentKind.plain) => FilledButton(
        key: buttonKey,
        onPressed: () {},
        child: Text('Label', key: labelKey),
      ),
    (_WideIconButtonKind.filled, _WideButtonContentKind.iconLabel) =>
      FilledButton.icon(
        key: buttonKey,
        onPressed: () {},
        icon: Icon(Icons.add_rounded, key: iconKey),
        label: Text('Label', key: labelKey),
      ),
    (_WideIconButtonKind.filled, _WideButtonContentKind.iconOnly) =>
      FilledButton(
        key: buttonKey,
        onPressed: () {},
        child: Icon(Icons.add_rounded, key: iconKey),
      ),
    (_WideIconButtonKind.tonal, _WideButtonContentKind.plain) =>
      FilledButton.tonal(
        key: buttonKey,
        style: tonalStyle,
        onPressed: () {},
        child: Text('Label', key: labelKey),
      ),
    (_WideIconButtonKind.tonal, _WideButtonContentKind.iconLabel) =>
      FilledButton.tonalIcon(
        key: buttonKey,
        style: tonalStyle,
        onPressed: () {},
        icon: Icon(Icons.add_rounded, key: iconKey),
        label: Text('Label', key: labelKey),
      ),
    (_WideIconButtonKind.tonal, _WideButtonContentKind.iconOnly) =>
      FilledButton.tonal(
        key: buttonKey,
        style: tonalStyle,
        onPressed: () {},
        child: Icon(Icons.add_rounded, key: iconKey),
      ),
    (_WideIconButtonKind.outlined, _WideButtonContentKind.plain) =>
      OutlinedButton(
        key: buttonKey,
        onPressed: () {},
        child: Text('Label', key: labelKey),
      ),
    (_WideIconButtonKind.outlined, _WideButtonContentKind.iconLabel) =>
      OutlinedButton.icon(
        key: buttonKey,
        onPressed: () {},
        icon: Icon(Icons.add_rounded, key: iconKey),
        label: Text('Label', key: labelKey),
      ),
    (_WideIconButtonKind.outlined, _WideButtonContentKind.iconOnly) =>
      OutlinedButton(
        key: buttonKey,
        onPressed: () {},
        child: Icon(Icons.add_rounded, key: iconKey),
      ),
  };
}

Finder _activeButtonImage(Finder button) {
  final activeOpacity = find.descendant(
    of: button,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Opacity && widget.opacity == 1 && widget.child is Image,
    ),
  );
  expect(activeOpacity, findsOneWidget);
  return find.descendant(of: activeOpacity, matching: find.byType(Image));
}

String _activeButtonAsset(WidgetTester tester, Finder button) {
  final active = tester
      .widgetList<Opacity>(
        find.descendant(of: button, matching: find.byType(Opacity)),
      )
      .where((opacity) => opacity.opacity == 1 && opacity.child is Image)
      .single;
  return _assetName(active.child! as Image);
}

String _assetName(Image image) {
  final provider = image.image;
  if (provider is AssetImage) {
    return provider.assetName;
  }
  if (provider is ExactAssetImage) {
    return provider.assetName;
  }
  throw StateError('Expected an asset image, got ${provider.runtimeType}.');
}
