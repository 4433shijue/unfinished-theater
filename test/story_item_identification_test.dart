import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gamification.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unknown item can be identified once, persisted, and charged once',
      () async {
    final client = _IdentificationClient(
      response: '{"description":"铜铃内有一片刻痕。","effect":"摇响可定位附近同源铜铃。"}',
    );
    final controller = await _createController(client);
    addTearDown(controller.dispose);
    final initialCoins = controller.gamification.coins;

    expect(await controller.identifyStoryInventoryItem('unknown-bell'), isNull);
    expect(client.requests, 1);
    expect(controller.gamification.coins, initialCoins - 3);
    final item = controller.currentStoryInventory.single;
    expect(item.identified, isTrue);
    expect(item.description, '铜铃内有一片刻痕。');
    expect(item.effect, '摇响可定位附近同源铜铃。');
    expect(controller.gamification.stats['totalItemsIdentified'], 1);
    expect(client.systemPrompt, contains('JSON'));
    expect(client.userPrompt, contains('声音只在旧站台响过'));

    final saved = await LocalStore().loadGameState('identification-world');
    expect(saved.storyInventory.single.identified, isTrue);
    expect(saved.storyInventory.single.effect, item.effect);

    expect(await controller.identifyStoryInventoryItem('unknown-bell'),
        contains('已经鉴定'));
    expect(client.requests, 1);
    expect(controller.gamification.coins, initialCoins - 3);
  });

  for (final entry in <String, String>{
    'non-JSON': '它是一只铜铃。',
    'empty object': '{}',
    'missing effect': '{"description":"铜铃内有刻痕。"}',
    'missing description': '{"effect":"摇响寻找另一只铃。"}',
    'blank effect': '{"description":"铜铃内有刻痕。","effect":"   "}',
    'wrong field type': '{"description":["铜铃"],"effect":"寻找另一只铃。"}',
  }.entries) {
    test('identification refunds and stays unknown for ${entry.key}', () async {
      final client = _IdentificationClient(response: entry.value);
      final controller = await _createController(client);
      addTearDown(controller.dispose);
      final initialCoins = controller.gamification.coins;

      final error = await controller.identifyStoryInventoryItem('unknown-bell');

      expect(error, contains('啥币已退回'));
      expect(client.requests, 1);
      expect(controller.gamification.coins, initialCoins);
      expect(controller.currentStoryInventory.single.identified, isFalse);
      expect(controller.currentStoryInventory.single.description, '一只旧铜铃');
      expect(controller.gamification.stats['totalItemsIdentified'] ?? 0, 0);
      final saved = await LocalStore().loadGameState('identification-world');
      expect(saved.storyInventory.single.identified, isFalse);
    });
  }

  test('failed identification request refunds the price', () async {
    final client = _IdentificationClient(fail: true);
    final controller = await _createController(client);
    addTearDown(controller.dispose);
    final initialCoins = controller.gamification.coins;

    expect(await controller.identifyStoryInventoryItem('unknown-bell'),
        contains('啥币已退回'));
    expect(controller.gamification.coins, initialCoins);
    expect(controller.currentStoryInventory.single.identified, isFalse);
  });

  test('concurrent clicks generate and charge only once', () async {
    final client = _IdentificationClient(
      response: '{"description":"铜铃内有刻痕。","effect":"寻找同源铜铃。"}',
    );
    final controller = await _createController(client);
    addTearDown(controller.dispose);
    final initialCoins = controller.gamification.coins;

    final results = await Future.wait(<Future<String?>>[
      controller.identifyStoryInventoryItem('unknown-bell'),
      controller.identifyStoryInventoryItem('unknown-bell'),
    ]);

    expect(results.first, isNull);
    expect(results.last, contains('正在生成'));
    expect(client.requests, 1);
    expect(controller.gamification.coins, initialCoins - 3);
    expect(controller.gamification.stats['totalItemsIdentified'], 1);
  });

  test('failed charge does not generate or add an unearned refund', () async {
    final store = _FailingChargeStore();
    final client = _IdentificationClient();
    final controller = await _createController(client, store: store);
    addTearDown(controller.dispose);
    final initialCoins = controller.gamification.coins;
    store.failNextSave = true;

    final error = await controller.identifyStoryInventoryItem('unknown-bell');

    expect(error, contains('鉴定失败'));
    expect(error, isNot(contains('已退回')));
    expect(client.requests, 0);
    expect(controller.gamification.coins, initialCoins);
    expect(controller.currentStoryInventory.single.identified, isFalse);
    expect(controller.isSending, isFalse);
  });

  test('failed item save restores unknown state, refunds, and allows retry',
      () async {
    final store = _FailingIdentificationStore();
    final client = _IdentificationClient(
      response: '{"description":"铜铃内有刻痕。","effect":"寻找同源铜铃。"}',
    );
    final controller = await _createController(client, store: store);
    addTearDown(controller.dispose);
    final initialCoins = controller.gamification.coins;
    store.failNextGameStateSave = true;

    expect(await controller.identifyStoryInventoryItem('unknown-bell'),
        contains('啥币已退回'));

    expect(controller.currentStoryInventory.single.identified, isFalse);
    expect(controller.gamification.coins, initialCoins);
    final restored = await LocalStore().loadGameState('identification-world');
    expect(restored.storyInventory.single.identified, isFalse);
    expect(controller.isSending, isFalse);

    expect(await controller.identifyStoryInventoryItem('unknown-bell'), isNull);
    expect(controller.currentStoryInventory.single.identified, isTrue);
    expect(controller.gamification.coins, initialCoins - 3);
    expect(client.requests, 2);
  });

  test('statistics save failure keeps the committed item and price', () async {
    final store = _FailingIdentificationStore();
    final client = _IdentificationClient(
      response: '{"description":"铜铃内有刻痕。","effect":"寻找同源铜铃。"}',
    );
    final controller = await _createController(client, store: store);
    addTearDown(controller.dispose);
    final initialCoins = controller.gamification.coins;
    store.failStatisticsSave = true;

    expect(await controller.identifyStoryInventoryItem('unknown-bell'), isNull);

    expect(controller.currentStoryInventory.single.identified, isTrue);
    expect(controller.gamification.coins, initialCoins - 3);
    final saved = await LocalStore().loadGameState('identification-world');
    expect(saved.storyInventory.single.identified, isTrue);
    expect(await controller.identifyStoryInventoryItem('unknown-bell'),
        contains('已经鉴定'));
    expect(client.requests, 1);
    expect(controller.isSending, isFalse);
  });

  test('insufficient coins do not call the model or mutate the item', () async {
    final client = _IdentificationClient();
    final controller = await _createController(client, coins: 2);
    addTearDown(controller.dispose);
    final initialCoins = controller.gamification.coins;

    expect(await controller.identifyStoryInventoryItem('unknown-bell'),
        contains('钱包'));
    expect(client.requests, 0);
    expect(controller.gamification.coins, initialCoins);
    expect(controller.currentStoryInventory.single.identified, isFalse);
  });
}

Future<AppStateController> _createController(
  _IdentificationClient client, {
  int coins = 20,
  LocalStore? store,
}) async {
  final character = CharacterProfile(
    id: 'identification-world',
    name: '旧城调查',
    createdAt: DateTime(2026, 9, 20),
    prompt: '调查旧站台留下的声音。',
    modelParams: ModelParams.defaults(),
  );
  final state = GameStateSnapshot.empty(character.id).copyWith(
    storyInventory: const <StoryInventoryItem>[
      StoryInventoryItem(
        id: 'unknown-bell',
        name: '旧铜铃',
        description: '一只旧铜铃',
        source: 'black_market',
        identified: false,
        mysteryHint: '声音只在旧站台响过',
      ),
    ],
  );
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app_settings': jsonEncode(
      AppSettings.initial()
          .copyWith(
            apiUrl: 'https://example.invalid/v1',
            apiKey: 'test-key',
            modelName: 'test-model',
          )
          .toJson(),
    ),
    'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
    'selected_character_id': character.id,
    'game_state_${character.id}': jsonEncode(state.toJson()),
    'gamification_state':
        jsonEncode(GamificationState.initial().copyWith(coins: coins).toJson()),
  });
  final controller = AppStateController(
    store: store ?? LocalStore(),
    apiClient: client,
    memoryService: MemoryService(),
  );
  await controller.initialize();
  return controller;
}

class _FailingChargeStore extends LocalStore {
  bool failNextSave = false;

  @override
  Future<void> saveGamificationState(GamificationState state) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('test persistence failure');
    }
    await super.saveGamificationState(state);
  }
}

class _FailingIdentificationStore extends LocalStore {
  bool failNextGameStateSave = false;
  bool failStatisticsSave = false;

  @override
  Future<void> saveGameState(GameStateSnapshot state) async {
    if (failNextGameStateSave) {
      failNextGameStateSave = false;
      throw StateError('test item save failure');
    }
    await super.saveGameState(state);
  }

  @override
  Future<void> saveGamificationState(GamificationState state) async {
    if (failStatisticsSave && (state.stats['totalItemsIdentified'] ?? 0) > 0) {
      failStatisticsSave = false;
      throw StateError('test statistics save failure');
    }
    await super.saveGamificationState(state);
  }
}

class _IdentificationClient extends LlmApiClient {
  _IdentificationClient({this.response = '', this.fail = false});

  final String response;
  final bool fail;
  int requests = 0;
  String systemPrompt = '';
  String userPrompt = '';

  @override
  Future<String> runUtilityTask({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.45,
    double topP = 0.9,
    int maxTokens = 8192,
    LlmCancellationToken? cancellationToken,
  }) async {
    requests += 1;
    this.systemPrompt = systemPrompt;
    this.userPrompt = userPrompt;
    if (fail) throw const LlmApiException('test model unavailable');
    return response;
  }
}
