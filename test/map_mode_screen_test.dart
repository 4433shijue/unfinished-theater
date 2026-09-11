import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/map_state.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/screens/map_mode_screen.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/map_turn_engine.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in <Size>[
    const Size(390, 844),
    const Size(667, 375),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    testWidgets('rules map renders without overflow at ${size.width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpRulesMap(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('无向有环图'), findsOneWidget);
      expect(find.text('道路可双向通行'), findsOneWidget);
      expect(find.textContaining('双向道路'), findsOneWidget);
      expect(find.textContaining('3 个独立环路'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('map-graph-board')),
          findsOneWidget);

      final landscapeLayout = size.width >= 640 && size.width > size.height;
      if (landscapeLayout) {
        expect(
          find.byKey(const ValueKey<String>('map-landscape-layout')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey<String>('map-graph-board')),
              )
              .width,
          greaterThan(size.width * 0.5),
        );
        await tester.tap(find.text('计划'));
        await tester.pumpAndSettle();
      }

      if (!landscapeLayout || size.height >= 600) {
        expect(find.text('3/8 AP'), findsOneWidget);
        expect(find.text('临时上限 5 AP'), findsOneWidget);
        expect(find.text('总上限 8 AP'), findsOneWidget);
        expect(find.textContaining('便携口粮'), findsOneWidget);
      } else {
        expect(find.text('下一回合计划'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone map requests landscape and restores portrait on exit',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final platformCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await _pumpRulesMap(tester);
    final enterCall = platformCalls.firstWhere(
      (call) => call.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(
      enterCall.arguments,
      <String>[
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final exitCall = platformCalls.lastWhere(
      (call) => call.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(
      exitCall.arguments,
      <String>['DeviceOrientation.portraitUp'],
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('action choice with location context stays an action',
      (tester) async {
    const size = Size(1440, 900);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpRulesMap(
      tester,
      transform: (state) {
        final otherLocation = state.locations
            .firstWhere((location) => location.id != state.currentLocationId);
        return state.copyWith(
          activeChoices: <MapStoryChoice>[
            MapStoryChoice(
              id: 'inspect_cabinet',
              label: '检查药柜',
              action: '检查药柜',
              locationId: otherLocation.id,
              kind: MapStoryChoiceKind.action,
            ),
          ],
        );
      },
    );

    await tester.tap(find.text('检查药柜').first);
    await tester.pumpAndSettle();

    expect(find.text('行动已加入下一回合计划。'), findsOneWidget);
    expect(find.textContaining('前往 '), findsNothing);

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();
    expect(find.text('检查药柜'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<AppStateController> _pumpRulesMap(
  WidgetTester tester, {
  MapWorldState Function(MapWorldState state)? transform,
}) async {
  final character = CharacterProfile(
    id: 'map-screen-character',
    name: '巡夜人',
    createdAt: DateTime(2026, 8, 8),
    prompt: '调查城市里的异常事件。',
    modelParams: ModelParams.defaults(),
    mapModeEnabled: true,
  );
  const engine = MapTurnEngine();
  final blueprint = engine.fallbackBlueprint(
    characterId: character.id,
    characterName: character.name,
    openingSummary: '从旧城开始调查。',
  );
  var mapState = engine
      .selectBirthLocation(
        blueprint,
        blueprint.spawnCandidates.first.locationId,
      )
      .state;
  mapState = transform?.call(mapState) ?? mapState;

  SharedPreferences.setMockInitialValues(<String, Object>{
    'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
    'selected_character_id': character.id,
    'map_state_${character.id}': jsonEncode(mapState.toJson()),
  });
  final controller = AppStateController(
    store: LocalStore(),
    apiClient: _UnusedLlmApiClient(),
    memoryService: MemoryService(),
  );
  addTearDown(controller.dispose);
  await controller.initialize();

  await tester.pumpWidget(
    ChangeNotifierProvider<AppStateController>.value(
      value: controller,
      child: MaterialApp(
        theme: AppTheme.themeFor(controller.settings.themeId),
        home: const MapModeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _UnusedLlmApiClient extends LlmApiClient {}
