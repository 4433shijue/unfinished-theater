import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/gamification.dart';
import 'package:ai_roleplay_chat/models/map_state.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/screens/chat_screen.dart';
import 'package:ai_roleplay_chat/screens/map_mode_screen.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/map_turn_engine.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppTheme.registerRuntimeThemes(const <RuntimeThemeDefinition>[]);
    AppTheme.themeFor(AppThemeVariant.sakura.id);
  });

  testWidgets('phone map entry opens the dedicated map screen', (tester) async {
    tester.view.physicalSize = const Size(1000, 590);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _createController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pumpAndSettle();

    expect(find.byType(MapModeScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop map entry keeps the map bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _createController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pumpAndSettle();

    expect(find.byType(MapModeScreen), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone tool drawer uses preset material and closes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _createController(themeId: 'april_fools');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mobile-tool-material-signal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mobile-tool-drawer-april_fools')),
      findsOneWidget,
    );
    final routeTitle = tester.widget<Semantics>(
      find.byKey(const ValueKey<String>('mobile-tool-route-title')),
    );
    expect(routeTitle.properties.label, '功能菜单');
    expect(routeTitle.properties.header, isTrue);
    expect(routeTitle.properties.namesRoute, isTrue);
    final firstAction = tester.widget<Semantics>(
      find.byKey(const ValueKey<String>('mobile-tool-action-隐藏面板')),
    );
    expect(firstAction.properties.button, isTrue);
    expect(firstAction.properties.enabled, isTrue);
    expect(firstAction.properties.label, '隐藏面板');
    expect(find.byType(ListView), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('mobile-tool-drawer-april_fools')),
      findsNothing,
    );
  });

  testWidgets('basic theme tool drawer stays neutral at large text scale',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _createController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _testApp(controller, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mobile-tool-material-neutral')),
      findsOneWidget,
    );
    final drawer = find.byKey(
      const ValueKey<String>('mobile-tool-drawer-sakura'),
    );
    expect(drawer, findsOneWidget);
    expect(
      find.descendant(of: drawer, matching: find.byType(Scrollable)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime theme based on a preset keeps drawer material neutral',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 8, 11);
    final runtimeTheme = CustomThemeStyle(
      id: 'custom-abyss',
      name: 'Custom Abyss',
      description: 'Runtime theme based on a preset.',
      baseThemeId: AppThemeVariant.cthulhu.id,
      css: '.theme { --primary: #9d3832; }',
      createdAt: now,
      updatedAt: now,
    );
    final controller = await _createController(
      themeId: runtimeTheme.id,
      customThemeStyle: runtimeTheme,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    expect(AppTheme.hasRuntimeTheme(runtimeTheme.id), isTrue);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('mobile-tool-material-neutral')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mobile-tool-material-abyss')),
      findsNothing,
    );
    final routeTitle = tester.widget<Semantics>(
      find.byKey(const ValueKey<String>('mobile-tool-route-title')),
    );
    expect(routeTitle.properties.label, '功能菜单');
    expect(routeTitle.properties.header, isTrue);
    expect(routeTitle.properties.namesRoute, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'narrow drawer scrolls to its last disabled action without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _createController(withMessage: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    final drawer = find.byKey(
      const ValueKey<String>('mobile-tool-drawer-sakura'),
    );
    final drawerScrollables = find.descendant(
      of: drawer,
      matching: find.byType(Scrollable),
    );
    expect(drawerScrollables, findsOneWidget);
    final drawerScrollable = drawerScrollables.first;
    const lastActionKey = ValueKey<String>('mobile-tool-action-清空记录');
    final lastAction = find.byKey(lastActionKey);
    await tester.scrollUntilVisible(
      lastAction,
      240,
      scrollable: drawerScrollable,
    );
    await tester.pumpAndSettle();

    expect(lastAction, findsOneWidget);
    final actionSemantics = tester.widget<Semantics>(lastAction);
    expect(actionSemantics.properties.button, isTrue);
    expect(actionSemantics.properties.enabled, isFalse);
    expect(actionSemantics.properties.label, '清空记录');

    final routeTitle = tester.widget<Semantics>(
      find.byKey(const ValueKey<String>('mobile-tool-route-title')),
    );
    expect(routeTitle.properties.label, '功能菜单');
    expect(routeTitle.properties.header, isTrue);
    expect(routeTitle.properties.namesRoute, isTrue);

    final closeButton = find.byIcon(Icons.close_rounded).last;
    expect(closeButton, findsOneWidget);
    expect(closeButton.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(closeButton).dy, greaterThanOrEqualTo(0));
    expect(
      tester.getBottomRight(closeButton).dy,
      lessThanOrEqualTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chat map basket keeps action locationIds out of travel and preserves order',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = await _createController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_testApp(controller));
      await tester.pumpAndSettle();

      final currentLocationId = controller.currentMapState.currentLocationId;
      final destinationId = controller.currentMapState.locations
          .firstWhere((location) => location.id != currentLocationId)
          .id;

      await tester.tap(find.byIcon(Icons.map_outlined).last);
      await tester.pumpAndSettle();

      for (final label in <String>[
        _clueChoiceLabel,
        _travelChoiceLabel,
        _socialChoiceLabel,
      ]) {
        final choice = find.text(AppTheme.glitchText(label)).first;
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pump();
      }

      final submit = find.text(AppTheme.glitchText('确认并推进'));
      final mapListView = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListView),
      );
      final mapScrollable = find
          .descendant(
            of: mapListView,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        submit,
        500,
        scrollable: mapScrollable,
      );
      final submitButton = find.ancestor(
        of: submit,
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      tester.widget<FilledButton>(submitButton).onPressed!();
      await tester.pumpAndSettle();

      expect(controller.submittedActions, <String>[
        _clueChoiceAction,
        _socialChoiceAction,
      ]);
      expect(controller.submittedLocationIds, <String>[destinationId]);
      expect(
        controller.submittedStructuredActions!
            .map((item) => item['kind'])
            .toList(growable: false),
        <String>['clue', 'location', 'social'],
      );
      expect(
        controller.submittedStructuredActions!
            .map((item) => item['locationId'])
            .toList(growable: false),
        <String>[currentLocationId, destinationId, currentLocationId],
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

const _clueChoiceLabel = '检查青铜门锁';
const _clueChoiceAction = '检查门锁上残留的术式';
const _travelChoiceLabel = '前往下一处地点';
const _socialChoiceLabel = '询问守门人';
const _socialChoiceAction = '询问守门人昨夜的动静';

Future<_CapturingAppStateController> _createController({
  String themeId = 'sakura',
  CustomThemeStyle? customThemeStyle,
  bool withMessage = true,
}) async {
  final character = CharacterProfile(
    id: 'chat-map-entry-character',
    name: '巡夜人',
    createdAt: DateTime(2026, 8, 9),
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
  final initialMapState = engine
      .selectBirthLocation(
        blueprint,
        blueprint.spawnCandidates.first.locationId,
      )
      .state;
  final currentLocationId = initialMapState.currentLocationId;
  final destinationId = initialMapState.locations
      .firstWhere((location) => location.id != currentLocationId)
      .id;
  final mapState = initialMapState.copyWith(
    activeChoices: <MapStoryChoice>[
      MapStoryChoice(
        id: 'choice-clue',
        label: _clueChoiceLabel,
        action: _clueChoiceAction,
        locationId: currentLocationId,
        kind: MapStoryChoiceKind.clue,
      ),
      MapStoryChoice(
        id: 'choice-travel',
        label: _travelChoiceLabel,
        action: '前往下一处地点',
        locationId: destinationId,
        kind: MapStoryChoiceKind.location,
      ),
      MapStoryChoice(
        id: 'choice-social',
        label: _socialChoiceLabel,
        action: _socialChoiceAction,
        locationId: currentLocationId,
        kind: MapStoryChoiceKind.social,
      ),
    ],
  );
  final history = DialogueHistory(
    characterId: character.id,
    messages: withMessage
        ? <ChatMessage>[
            ChatMessage(
              id: 'opening-message',
              role: ChatRole.assistant,
              content: '夜色落下，调查从旧城开始。',
              timestamp: DateTime(2026, 8, 9, 20),
              isSummarized: false,
            ),
          ]
        : const <ChatMessage>[],
  );
  final gamification = customThemeStyle == null
      ? null
      : GamificationState.initial().addCustomThemeStyle(customThemeStyle);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_settings': jsonEncode(
      AppSettings.initial()
          .copyWith(
            apiUrl: 'https://example.invalid/v1',
            apiKey: 'test-key',
            modelName: 'test-model',
            themeId: themeId,
          )
          .toJson(),
    ),
    'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
    'selected_character_id': character.id,
    'history_${character.id}': jsonEncode(history.toJson()),
    'map_state_${character.id}': jsonEncode(mapState.toJson()),
    if (gamification != null)
      'gamification_state': jsonEncode(gamification.toJson()),
  });
  final controller = _CapturingAppStateController(
    store: LocalStore(),
    apiClient: _UnusedLlmApiClient(),
    memoryService: MemoryService(),
  );
  await controller.initialize();
  return controller;
}

Widget _testApp(
  AppStateController controller, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ChangeNotifierProvider<AppStateController>.value(
    value: controller,
    child: MaterialApp(
      theme: AppTheme.themeFor(controller.settings.themeId),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const Scaffold(body: ChatScreen()),
    ),
  );
}

class _UnusedLlmApiClient extends LlmApiClient {}

class _CapturingAppStateController extends AppStateController {
  _CapturingAppStateController({
    required super.store,
    required super.apiClient,
    required super.memoryService,
  });

  List<String>? submittedActions;
  List<String>? submittedLocationIds;
  List<Map<String, dynamic>>? submittedStructuredActions;

  @override
  Future<String?> runMapPlannedRound({
    required List<String> actions,
    required List<String> locationIds,
    required String timeStep,
    List<Map<String, dynamic>> structuredActions =
        const <Map<String, dynamic>>[],
  }) async {
    submittedActions = List<String>.from(actions);
    submittedLocationIds = List<String>.from(locationIds);
    submittedStructuredActions = structuredActions
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    return null;
  }
}
