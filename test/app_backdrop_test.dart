import 'dart:ui' as ui;

import 'package:ai_roleplay_chat/screens/home_shell.dart';
import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:ai_roleplay_chat/theme/theme_skin_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _BackdropExpectation = ({
  String themeId,
  String effect,
  ThemeSkinEffectPolicy motionPolicy,
  double motionOpacity,
  ThemeSkinEffectPolicy staticPolicy,
  double staticOpacity,
});

const _presetExpectations = <_BackdropExpectation>[
  (
    themeId: ThemeSkinAssets.aprilFoolsThemeId,
    effect: 'corrupt',
    motionPolicy: ThemeSkinEffectPolicy.none,
    motionOpacity: 0,
    staticPolicy: ThemeSkinEffectPolicy.ambientOnly,
    staticOpacity: 0.22,
  ),
  (
    themeId: ThemeSkinAssets.cthulhuThemeId,
    effect: 'eldritch',
    motionPolicy: ThemeSkinEffectPolicy.ambientOnly,
    motionOpacity: 0.12,
    staticPolicy: ThemeSkinEffectPolicy.ambientOnly,
    staticOpacity: 0.16,
  ),
  (
    themeId: ThemeSkinAssets.riftRelayThemeId,
    effect: 'terminal',
    motionPolicy: ThemeSkinEffectPolicy.ambientOnly,
    motionOpacity: 0.20,
    staticPolicy: ThemeSkinEffectPolicy.none,
    staticOpacity: 0,
  ),
  (
    themeId: ThemeSkinAssets.flowerNotFlowerThemeId,
    effect: 'flower',
    motionPolicy: ThemeSkinEffectPolicy.ambientOnly,
    motionOpacity: 0.14,
    staticPolicy: ThemeSkinEffectPolicy.none,
    staticOpacity: 0,
  ),
  (
    themeId: ThemeSkinAssets.mechanicalCityThemeId,
    effect: 'mechanical',
    motionPolicy: ThemeSkinEffectPolicy.none,
    motionOpacity: 0,
    staticPolicy: ThemeSkinEffectPolicy.none,
    staticOpacity: 0,
  ),
  (
    themeId: ThemeSkinAssets.rainRadioThemeId,
    effect: 'rainRadio',
    motionPolicy: ThemeSkinEffectPolicy.ambientOnly,
    motionOpacity: 0.16,
    staticPolicy: ThemeSkinEffectPolicy.none,
    staticOpacity: 0,
  ),
  (
    themeId: ThemeSkinAssets.skyPastureThemeId,
    effect: 'pasture',
    motionPolicy: ThemeSkinEffectPolicy.full,
    motionOpacity: 0.36,
    staticPolicy: ThemeSkinEffectPolicy.none,
    staticOpacity: 0,
  ),
  (
    themeId: ThemeSkinAssets.vinylMemoriesThemeId,
    effect: 'vinyl',
    motionPolicy: ThemeSkinEffectPolicy.none,
    motionOpacity: 0,
    staticPolicy: ThemeSkinEffectPolicy.none,
    staticOpacity: 0,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppTheme.registerRuntimeThemes(const <RuntimeThemeDefinition>[]);
    AppTheme.themeFor(AppThemeVariant.sakura.id);
  });

  testWidgets('preset specs drive backdrop layers and opacities',
      (tester) async {
    for (final expected in _presetExpectations) {
      final spec = ThemeSkinAssets.specFor(expected.themeId)!;
      expect(spec.motionPolicy, expected.motionPolicy,
          reason: expected.themeId);
      expect(spec.motionOpacity, expected.motionOpacity,
          reason: expected.themeId);
      expect(spec.staticEffectPolicy, expected.staticPolicy,
          reason: expected.themeId);
      expect(spec.staticEffectOpacity, expected.staticOpacity,
          reason: expected.themeId);

      await _pumpBackdrop(tester, expected.themeId);

      final artwork = find.byType(ThemeSkinBackdropArtwork);
      expect(artwork, findsOneWidget, reason: expected.themeId);
      expect(
        find.ancestor(of: artwork, matching: find.byType(Opacity)),
        findsNothing,
        reason: '${expected.themeId} must not wrap artwork in another opacity',
      );
      final artworkOpacity = find.descendant(
        of: artwork,
        matching: find.byType(Opacity),
      );
      expect(artworkOpacity, findsOneWidget, reason: expected.themeId);
      expect(
        tester.widget<Opacity>(artworkOpacity).opacity,
        spec.artworkOpacity,
        reason: '${expected.themeId} must not multiply artwork opacity',
      );

      final scrim = tester.widget<ColoredBox>(
        find.byKey(ValueKey<String>('backdrop-scrim-${expected.themeId}')),
      );
      expect(
        scrim.color,
        spec.scrimColor.withValues(alpha: spec.scrimOpacity),
        reason: expected.themeId,
      );

      final motionLayers = _opacityLayers(tester, 'backdrop-motion-');
      if (expected.motionPolicy == ThemeSkinEffectPolicy.none) {
        expect(motionLayers, isEmpty, reason: expected.themeId);
      } else {
        expect(motionLayers, hasLength(1), reason: expected.themeId);
        expect(motionLayers.single.opacity, expected.motionOpacity,
            reason: expected.themeId);
        expect(
          find.byKey(
            ValueKey<String>(
              'backdrop-motion-paint-${expected.effect}-${expected.motionPolicy.name}',
            ),
          ),
          findsOneWidget,
          reason: expected.themeId,
        );
      }

      final staticLayers = _opacityLayers(tester, 'backdrop-static-');
      if (expected.staticPolicy == ThemeSkinEffectPolicy.none) {
        expect(staticLayers, isEmpty, reason: expected.themeId);
      } else {
        expect(staticLayers, hasLength(1), reason: expected.themeId);
        expect(staticLayers.single.opacity, expected.staticOpacity,
            reason: expected.themeId);
        expect(
          find.byKey(
            ValueKey<String>(
              'backdrop-static-paint-${expected.effect}-${expected.staticPolicy.name}',
            ),
          ),
          findsOneWidget,
          reason: expected.themeId,
        );
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduce motion removes motion but keeps static ambience',
      (tester) async {
    for (final themeId in <String>[
      ThemeSkinAssets.cthulhuThemeId,
      ThemeSkinAssets.skyPastureThemeId,
    ]) {
      await _pumpBackdrop(tester, themeId, reduceMotion: true);

      expect(_opacityLayers(tester, 'backdrop-motion-'), isEmpty,
          reason: themeId);
      final staticLayers = _opacityLayers(tester, 'backdrop-static-');
      if (themeId == ThemeSkinAssets.cthulhuThemeId) {
        expect(staticLayers, hasLength(1), reason: themeId);
        expect(staticLayers.single.opacity, 0.16, reason: themeId);
      } else {
        expect(staticLayers, isEmpty, reason: themeId);
      }
    }
  });

  testWidgets('basic and runtime backdrops retain the legacy full policy',
      (tester) async {
    await _pumpBackdrop(tester, AppThemeVariant.sakura.id);
    expect(find.byType(ThemeSkinBackdropArtwork), findsNothing);
    expect(find.byKey(const ValueKey<String>('backdrop-generic-overlay')),
        findsOneWidget);
    expect(_opacityLayers(tester, 'backdrop-motion-'), isEmpty);
    expect(_opacityLayers(tester, 'backdrop-static-'), isEmpty);

    const runtimeId = 'runtime-eldritch-full';
    AppTheme.registerRuntimeThemes(<RuntimeThemeDefinition>[
      RuntimeThemeDefinition(
        id: runtimeId,
        label: 'Runtime Eldritch',
        description: 'Test theme',
        baseThemeId: ThemeSkinAssets.cthulhuThemeId,
        palette: AppThemeVariant.cthulhu.palette,
        backgroundEffect: 'cthulhu',
      ),
    ]);
    await _pumpBackdrop(tester, runtimeId);

    expect(find.byType(ThemeSkinBackdropArtwork), findsNothing);
    expect(find.byKey(const ValueKey<String>('backdrop-generic-overlay')),
        findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('backdrop-motion-eldritch-full'),
            ),
          )
          .opacity,
      1,
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('backdrop-static-eldritch-full'),
            ),
          )
          .opacity,
      1,
    );
    expect(
      find.byKey(
        const ValueKey<String>('backdrop-motion-paint-eldritch-full'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('backdrop-static-paint-eldritch-full'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ambient motion painters remove full-only paint operations',
      (tester) async {
    const cases = <({
      String presetId,
      String runtimeId,
      String effect,
      String token,
      List<({Symbol method, int ambient, int full})> counts,
    })>[
      (
        presetId: ThemeSkinAssets.cthulhuThemeId,
        runtimeId: 'runtime-eldritch',
        effect: 'eldritch',
        token: 'cthulhu',
        counts: <({Symbol method, int ambient, int full})>[
          (method: #drawPath, ambient: 0, full: 4),
        ],
      ),
      (
        presetId: ThemeSkinAssets.riftRelayThemeId,
        runtimeId: 'runtime-terminal',
        effect: 'terminal',
        token: 'rift',
        counts: <({Symbol method, int ambient, int full})>[
          (method: #drawRect, ambient: 0, full: 2),
        ],
      ),
      (
        presetId: ThemeSkinAssets.flowerNotFlowerThemeId,
        runtimeId: 'runtime-flower',
        effect: 'flower',
        token: 'flower',
        counts: <({Symbol method, int ambient, int full})>[
          (method: #drawCircle, ambient: 12, full: 0),
          (method: #drawOval, ambient: 6, full: 5),
        ],
      ),
      (
        presetId: ThemeSkinAssets.rainRadioThemeId,
        runtimeId: 'runtime-rain',
        effect: 'rainRadio',
        token: 'rain',
        counts: <({Symbol method, int ambient, int full})>[
          (method: #drawLine, ambient: 54, full: 150),
        ],
      ),
    ];

    AppTheme.registerRuntimeThemes(
      cases.map((entry) {
        final variant = AppThemeVariant.byId(entry.presetId);
        return RuntimeThemeDefinition(
          id: entry.runtimeId,
          label: entry.runtimeId,
          description: 'Test theme',
          baseThemeId: entry.presetId,
          palette: variant.palette,
          backgroundEffect: entry.token,
        );
      }),
    );

    for (final entry in cases) {
      await _pumpBackdrop(tester, entry.presetId);
      final ambientPainter = _motionPainter(
        tester,
        'backdrop-motion-paint-${entry.effect}-ambientOnly',
      );

      await _pumpBackdrop(tester, entry.runtimeId);
      final fullPainter = _motionPainter(
        tester,
        'backdrop-motion-paint-${entry.effect}-full',
      );

      for (final count in entry.counts) {
        expect(
          _paintCallback(ambientPainter),
          paintsExactlyCountTimes(count.method, count.ambient),
          reason: '${entry.effect} ambient ${count.method}',
        );
        expect(
          _paintCallback(fullPainter),
          paintsExactlyCountTimes(count.method, count.full),
          reason: '${entry.effect} full ${count.method}',
        );
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('eldritch static ambience omits the sigil and tentacle',
      (tester) async {
    await _pumpBackdrop(tester, ThemeSkinAssets.cthulhuThemeId);
    final ambientPainter = tester
        .widget<CustomPaint>(
          find.byKey(
            const ValueKey<String>(
              'backdrop-static-paint-eldritch-ambientOnly',
            ),
          ),
        )
        .painter!;

    const runtimeId = 'runtime-static-eldritch';
    AppTheme.registerRuntimeThemes(<RuntimeThemeDefinition>[
      RuntimeThemeDefinition(
        id: runtimeId,
        label: 'Runtime Eldritch',
        description: 'Test theme',
        baseThemeId: ThemeSkinAssets.cthulhuThemeId,
        palette: AppThemeVariant.cthulhu.palette,
        backgroundEffect: 'cthulhu',
      ),
    ]);
    await _pumpBackdrop(tester, runtimeId);
    final fullPainter = tester
        .widget<CustomPaint>(
          find.byKey(
            const ValueKey<String>('backdrop-static-paint-eldritch-full'),
          ),
        )
        .painter!;

    expect(
      _paintCallback(ambientPainter),
      paintsExactlyCountTimes(#drawLine, 0),
    );
    expect(
      _paintCallback(ambientPainter),
      paintsExactlyCountTimes(#drawPath, 0),
    );
    expect(
      _paintCallback(fullPainter),
      paintsExactlyCountTimes(#drawLine, 7),
    );
    expect(
      _paintCallback(fullPainter),
      paintsExactlyCountTimes(#drawPath, 1),
    );
  });
}

Future<void> _pumpBackdrop(
  WidgetTester tester,
  String themeId, {
  bool reduceMotion = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: AppBackdrop(
        themeId: themeId,
        reduceMotion: reduceMotion,
      ),
    ),
  );
}

List<Opacity> _opacityLayers(WidgetTester tester, String keyPrefix) {
  return tester.widgetList<Opacity>(
    find.byWidgetPredicate((widget) {
      final key = widget.key;
      return widget is Opacity &&
          key is ValueKey<String> &&
          key.value.startsWith(keyPrefix);
    }),
  ).toList();
}

CustomPainter _motionPainter(WidgetTester tester, String key) {
  final boundary = find.byKey(ValueKey<String>(key));
  return tester
      .widget<CustomPaint>(
        find.descendant(of: boundary, matching: find.byType(CustomPaint)),
      )
      .painter!;
}

void Function(ui.Canvas) _paintCallback(CustomPainter painter) {
  return (canvas) {
    painter.paint(canvas, const Size(240, 180));
  };
}
