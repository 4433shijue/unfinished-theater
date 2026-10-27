import 'package:ai_roleplay_chat/services/gameplay_turn_engine.dart';
import 'package:ai_roleplay_chat/services/game_state_parser.dart';
import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/character_memory.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gamification.dart';
import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/models/npc_story_state.dart';
import 'package:ai_roleplay_chat/models/story_advanced_settings.dart';
import 'package:ai_roleplay_chat/models/story_continuity.dart';
import 'package:ai_roleplay_chat/models/story_opening_draft.dart';
import 'package:ai_roleplay_chat/models/turn_settlement.dart';
import 'package:ai_roleplay_chat/services/npc_evolution_engine.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'story_workflow_test.dart' as fixtures;

StoryOpeningDraft openingDraft({int count = 3}) => StoryOpeningDraft({
      'npcs': [
        for (var i = 1; i <= count; i++)
          {
            'id': 'n$i',
            'name': '人物$i',
            'publicIdentity': '旅人$i',
            'trueIdentity': '密探$i',
            'personality': '认真独立',
            'secret': '只有本人知道的暗号$i',
            'goal': '调查旧城',
            'stance': '谨慎合作',
            'affinity': i * 3,
            'affinityReason': '曾在渡口相识',
            'appeared': i < 3
          }
      ],
      'relationships': [
        {'from': 'n1', 'to': 'n2', 'label': '旧识', 'public': false}
      ],
      'items': [
        {
          'id': 'herb',
          'name': '止血药',
          'quantity': 3,
          'description': '用于包扎',
          'source': '开局携带'
        }
      ],
      'gameplaySystem': {
        'schemaVersion': 3,
        'title': '调查',
        'summary': '追查旧城',
        'coreLoop': '探索与休息',
        'rules': [],
        'variables': [
          for (final key in ['energy', 'money', 'risk', 'progress'])
            {
              'key': key,
              'label': key,
              'group': '资源',
              'type': 'number',
              'authority': 'ai',
              'visibility': 'public',
              'initialValue': 20,
              'min': 0,
              'max': 100,
              'maxDelta': 12,
              'isCore': true,
              'description': '本轮行动影响',
              'playerHint': '行动影响此数值'
            }
        ]
      }
    });
CharacterDraft characterDraft({StoryOpeningDraft? opening}) => CharacterDraft(
    name: '旧城夜行',
    prompt: '调查旧城，不替玩家行动。',
    openingMessage: '渡口有人向你招手。',
    openingDraft: opening ?? openingDraft(),
    advancedSettings: const StoryAdvancedSettings(
        length: 'short', instructions: '  请不要替我说话。\n保留我的选择。  '),
    inlineTheaterSettings: const InlineTheaterSettings(enabled: false),
    nextStepOptionsEnabled: false,
    modelParams: ModelParams.defaults());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'advanced settings preserve verbatim constraints and configurable length',
      () {
    final settings = characterDraft().advancedSettings;
    final restored = StoryAdvancedSettings.fromJson(settings.toJson());
    expect(restored.instructions, settings.instructions);
    expect(restored.minimumCharacters, 600);
    final profile = CharacterProfile(
        id: 'w',
        name: '世界',
        createdAt: DateTime.now(),
        prompt: '长文旧规则',
        advancedSettings: settings,
        modelParams: ModelParams.defaults());
    expect(profile.fullSystemPrompt, contains('600-1000'));
    expect(profile.fullSystemPrompt, isNot(contains('硬性下限为 2000')));
    expect(
        CharacterProfile.fromJson(profile.toJson())
            .advancedSettings
            .instructions,
        settings.instructions);
  });
  test(
      'opening accepts 3 and 6 actors and rejects invalid ids/counts/references',
      () {
    expect(openingDraft().validate(), isEmpty);
    expect(openingDraft(count: 6).validate(npcCount: 6), isEmpty);
    expect(openingDraft(count: 2).validate(), isNotEmpty);
    final invalid = openingDraft().toJson();
    (invalid['npcs'] as List)[1]['id'] = 'n1';
    expect(StoryOpeningDraft(invalid).validate(), isNotEmpty);
    final broken = openingDraft().toJson();
    (broken['relationships'] as List)[0]['to'] = 'missing';
    expect(StoryOpeningDraft(broken).validate(), isNotEmpty);
  });
  test('identity revelation preserves id, aliases, and private truth', () {
    final npc = actor();
    final update = GameNpcUpdate(name: npc.name, npcId: npc.id, storyPatch: {
      'name': '沈舟',
      'revealSecret': true,
      'evidence': '他承认自己是密探。'
    });
    final next = NpcEvolutionEngine.apply(npc, update, 'turn1');
    expect(next.id, npc.id);
    expect(next.storyState.publicIdentity, '密探');
    expect(next.storyState.aliases, contains('阿澈'));
    expect(next.storyState.secretRevealed, isTrue);
    expect(npc.storyState.secretRevealed, isFalse);
    final fresh = NpcProfile.fromJson(next.toJson()).freshWorld();
    expect(fresh.name, npc.name);
    expect(fresh.description, npc.description);
    expect(fresh.storyState.secretRevealed, isFalse);
    expect(fresh.affinity, 0);
    final receipt = TurnSettlement.compare(
        worldId: 'world',
        turnId: 'turn1',
        before: GameStateSnapshot.empty('world'),
        after: GameStateSnapshot.empty('world'),
        beforeNpcs: [npc],
        afterNpcs: [next]);
    expect(
        receipt.entries.any((e) =>
            e['category'] == '称呼' && e['before'] == '阿澈' && e['after'] == '沈舟'),
        isTrue);

    expect(
        NpcWorldState(profile: next.toJson(), messages: []).project(npc).name,
        '沈舟');
  });
  test('rumor and future intent cannot kill an actor or reveal identity', () {
    final npc = actor();
    final state = GameStateSnapshot.empty('world').copyWith(npcUpdates: [
      GameNpcUpdate(
          name: npc.name,
          npcId: npc.id,
          lifecycle: 'dead',
          lifecycleReason: '听说他可能已经死了。',
          storyPatch: {'revealSecret': true, 'evidence': '他准备坦白。'})
    ]);
    final checked = NpcEvolutionEngine.validate(state, '听说他可能已经死了。他准备坦白。',
        [npc], StoryContinuityState(characterId: 'world'));
    expect(checked.npcUpdates.single.lifecycle, isEmpty);
    expect(checked.npcUpdates.single.storyPatch, isEmpty);
  });
  test(
      'routine actions require elapsed story time and allow at most two different actors',
      () {
    final npcs = [actor(), actor('b'), actor('c')];
    final before = GameStateSnapshot.empty('world').copyWith(timeLabel: '早晨');
    final actions = [
      for (final n in npcs)
        {
          'npcId': n.id,
          'type': 'work',
          'summary': '整理调查笔记',
          'reason': '已经过半天',
          'timeEvidence': '过了半天。'
        }
    ];
    expect(
        NpcEvolutionEngine.routines(npcs, actions, before, before, 't',
                narrative: '过了半天。')
            .every((n) => n.storyState.changes.isEmpty),
        isTrue);
    final after = before.copyWith(timeLabel: '午后');
    final changed = NpcEvolutionEngine.routines(
        npcs, actions, before, after, 't',
        narrative: '过了半天。');
    expect(changed.where((n) => n.storyState.lastRoutineTurn == 't'),
        hasLength(2));
    expect(
        NpcEvolutionEngine.routines(changed, actions, before, after, 't',
                narrative: '过了半天。')
            .first
            .storyState
            .changes,
        hasLength(1));
    expect(
        TurnSettlement.compare(
                worldId: 'world',
                turnId: 't',
                before: before,
                after: after,
                beforeNpcs: npcs,
                afterNpcs: changed)
            .entries,
        isEmpty);
  });
  test(
      'inventory receipt compares quantities and never includes unrevealed secrets',
      () {
    final before = GameStateSnapshot.empty('world').copyWith(storyInventory: [
      const StoryInventoryItem(id: 'h', name: '止血药', quantity: 3)
    ]);
    final after = before.copyWith(storyInventory: [
      const StoryInventoryItem(id: 'h', name: '止血药', quantity: 2)
    ]);
    final result = TurnSettlement.compare(
        worldId: 'world',
        turnId: 't',
        before: before,
        after: after,
        beforeNpcs: [actor()],
        afterNpcs: [actor()]);
    expect(result.entries.single['delta'], -1);
    expect(jsonEncode(result.toJson()), isNot(contains('暗号884')));
    expect(
        StoryInventoryItem.fromJson(before.storyInventory.single.toJson())
            .quantity,
        3);
  });
  test(
      'creating a world atomically persists opening and hides unintroduced actors',
      () async {
    final c = await fixtures.fixture(EvolutionClient());
    await c.createCharacter(characterDraft());
    expect(c.currentWorldNpcProfiles, hasLength(2));
    expect(c.currentGameState.storyInventory.single.quantity, 3);
    expect(c.currentGameState.customVariables['energy'], 20);
    final saved =
        await LocalStore().loadStoryContinuity(c.currentCharacter!.id);
    expect(saved.npcWorlds, hasLength(3));
    expect(c.currentCharacter!.advancedSettings.length, 'short');
    final hidden = c.npcProfiles.firstWhere((n) => n.name == '人物3');
    expect(hidden.storyState.secret, '只有本人知道的暗号3');
    final reopened = await LocalStore().loadCharacters();
    expect(reopened.first.advancedSettings.instructions,
        characterDraft().advancedSettings.instructions);
  });
  test(
      'structured inventory settles remaining quantities and empty inventory without resurrecting items',
      () {
    final before = GameStateSnapshot.empty('world').copyWith(inventory: [
      '药'
    ], storyInventory: [
      const StoryInventoryItem(id: 'h', name: '药', quantity: 3)
    ]);
    final after = GameStateParser.parseFromMessage(
        characterId: 'world',
        previous: before,
        content:
            '[GAME_STATE]{"时间":"午后","剧情物品栏":[{"id":"h","name":"药","quantity":2}]}[/GAME_STATE]')!;
    expect(after.storyInventory.single.quantity, 2);
    final empty = GameStateParser.parseFromMessage(
        characterId: 'world',
        previous: after,
        content: '[GAME_STATE]{"时间":"夜晚","剧情物品栏":[]}[/GAME_STATE]')!;
    expect(empty.storyInventory, isEmpty);
    expect(empty.inventory, isEmpty);
    expect(GameStateSnapshot.fromJson(empty.toJson()).storyInventory, isEmpty);
  });
  test(
      'promise deadlines require an explicit narrative quote and are never guessed',
      () {
    final system = openingDraft().gameplay!;
    final before = GameStateSnapshot.empty('world');
    GameStateSnapshot settle(String deadline, String narrative) =>
        GameplayTurnEngine.apply(
            system: system,
            previousState: before,
            narrativeState: before,
            turnId: 't',
            content: '$narrative [THEATER_PATCH]${jsonEncode({
                  'ops': [],
                  'threads': [
                    {
                      'op': 'open',
                      'id': 'letter',
                      'title': '送信',
                      'description': '把信交给船夫',
                      'reason': '接受送信的约定',
                      'deadline': deadline,
                      'dueTurn': 50
                    }
                  ]
                })}[/THEATER_PATCH]');
    final explicit = settle('2回合内', '他答应在2回合内送信。');
    expect(explicit.gameplayRuntime.threads.single.dueTurn, 3);
    final unknown = settle('明晚', '他答应明晚送信。');
    expect(unknown.gameplayRuntime.threads.single.deadline, '明晚');
    expect(unknown.gameplayRuntime.threads.single.dueTurn, isNull);
    expect(settle('2回合内', '他答应送信。').gameplayRuntime.threads.single.dueTurn,
        isNull);
  });
  test('major backstage suggestions become private leads, not death facts', () {
    final npc = actor();
    final before = GameStateSnapshot.empty('world').copyWith(timeLabel: '早晨');
    final after = NpcEvolutionEngine.routines([
      npc
    ], [
      {
        'npcId': npc.id,
        'type': 'lead',
        'summary': '有人准备背叛',
        'reason': '调查引起怀疑',
        'timeEvidence': '过了半天。'
      }
    ], before, before.copyWith(timeLabel: '午后'), 't', narrative: '过了半天。')
        .single;
    expect(after.lifecycle, NpcLifecycle.active);
    expect(after.storyState.pendingEvents, hasLength(1));
    expect(jsonEncode(after.storyState.publicData), isNot(contains('背叛')));
  });
  test('failed creation leaves no partial world or actors', () async {
    final store = fixtures.FailingStore();
    final c = await fixtures.fixture(EvolutionClient(), store: store);
    final previous = c.characters.length, actors = c.npcProfiles.length;
    store.fail = true;
    await expectLater(c.createCharacter(characterDraft()), throwsStateError);
    expect(c.characters.length, previous);
    expect(c.npcProfiles.length, actors);
  });
  test(
      'successful turn stores NPC updates and receipt together; repeats do not reapply',
      () async {
    final api = EvolutionClient();
    final c = await fixtures.fixture(api);
    final old = c.npcProfileById('a')!.affinity;
    await c.queueUserMessage('帮助阿澈');
    expect(await c.requestAssistantReply(), isNull);
    expect(c.npcProfileById('a')!.affinity, old + 5);
    final message = c.currentHistory.messages.last;
    final receipt = TurnSettlement.of(message)!;
    expect(receipt.complete, isTrue);
    expect(receipt.entries.any((e) => e['category'] == '好感' && e['delta'] == 5),
        isTrue);
    final saved = await LocalStore().loadStoryContinuity('world');
    expect(
        NpcWorldState.fromJson(storyMap(saved.npcWorlds['a']))
            .profile['affinity'],
        old + 5);
    await c.retryTurnSettlement(message.id);
    expect(c.npcProfileById('a')!.affinity, old + 5);
    await c.markSettlementSeen(message.id);
    expect(c.unreadTurnSettlement, isNull);
  });
  test('settled turns do not launch a second NPC extraction', () async {
    final api = EvolutionClient();
    final c = await fixtures.fixture(api);
    for (var i = 0; i < 3; i++) {
      await c.queueUserMessage('帮助同伴阿澈');
      expect(await c.requestAssistantReply(), isNull);
    }
    final calls = api.requests.length;
    await c.debugRunNpcExtractionForTest('world');
    expect(api.requests.length, calls);
  });
  test('failed adjudication keeps prose and retry settles exactly once',
      () async {
    final api = EvolutionClient()..failJudge = true;
    final c = await fixtures.fixture(api);
    final old = c.npcProfileById('a')!.affinity;
    await c.queueUserMessage('帮助阿澈');
    expect(await c.requestAssistantReply(), contains('结算未完成'));
    final message = c.currentHistory.messages.last;
    expect(message.content, contains('阿澈向你道谢'));
    expect(c.pendingTurnSettlement, isNotNull);
    expect(c.npcProfileById('a')!.affinity, old);
    expect(await c.queueUserMessage('继续'), contains('上一回合'));
    api.failJudge = false;
    expect(await c.retryTurnSettlement(message.id), isNull);
    expect(c.npcProfileById('a')!.affinity, old + 5);
    expect(c.pendingTurnSettlement, isNull);
  });
  test('deleting a completed turn restores NPC affinity and story identity',
      () async {
    final c = await fixtures.fixture(EvolutionClient());
    final old = c.npcProfileById('a')!;
    await c.queueUserMessage('帮忙');
    await c.requestAssistantReply();
    final id = c.currentHistory.messages.last.id;
    expect(c.npcProfileById('a')!.affinity, old.affinity + 5);
    await c.deleteMessage(id);
    expect(c.npcProfileById('a')!.affinity, old.affinity);
    expect(c.npcProfileById('a')!.storyState.stance, old.storyState.stance);
    expect(c.unreadTurnSettlement, isNull);
    await c.selectCharacter('other');
    await c.selectCharacter('world');
    expect(c.npcProfileById('a')!.affinity, old.affinity);
  });
  test('deleting an earlier turn replays only retained NPC differences',
      () async {
    final c = await fixtures.fixture(EvolutionClient());
    final old = c.npcProfileById('a')!.affinity;
    await c.queueUserMessage('帮忙');
    await c.requestAssistantReply();
    final first = c.currentHistory.messages.last.id;
    await c.queueUserMessage('再帮忙');
    await c.requestAssistantReply();
    expect(c.npcProfileById('a')!.affinity, old + 10);
    await c.deleteMessage(first);
    expect(c.npcProfileById('a')!.affinity, old + 5);
  });
  test('a plot rewrite settles NPC state and receipt in its own branch',
      () async {
    final c = await fixtures.fixture(EvolutionClient());
    final old = c.npcProfileById('a')!.affinity;
    await c.queueUserMessage('帮忙');
    await c.requestAssistantReply();
    final target = c.currentHistory.messages.last;
    await c.queueUserMessage('再帮忙');
    await c.requestAssistantReply();
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(target.id).first, StoryRewriteMode.plot, '调整回应');
    await c.applyStoryRewrite(preview, branchName: '另一个回应');
    expect(TurnSettlement.of(c.currentHistory.messages.last), isNotNull);
    expect(c.npcProfileById('a')!.affinity, old + 5);
    await c.selectCharacter('world');
    expect(c.npcProfileById('a')!.affinity, old + 10);
  });
  test('dead actors cannot acquire trust or new relationship changes', () {
    final dead = actor().copyWith(lifecycle: NpcLifecycle.dead);
    final next = NpcEvolutionEngine.apply(
        dead,
        GameNpcUpdate(name: dead.name, storyPatch: {
          'trustDelta': 10,
          'stance': '热情',
          'relations': [
            {'targetId': 'b', 'label': '朋友', 'public': true}
          ]
        }),
        't');
    expect(next.runtimeState.trust, dead.runtimeState.trust);
    expect(next.storyState.relations, isEmpty);
    expect(next.storyState.stance, isEmpty);
  });
  test(
      'failed atomic save preserves original NPC state and leaves a retryable turn',
      () async {
    final store = FailingTurnStore();
    final c = await fixtures.fixture(EvolutionClient(), store: store);
    final old = c.npcProfileById('a')!.affinity;
    store.failTurn = true;
    await c.queueUserMessage('帮助阿澈');
    expect(await c.requestAssistantReply(), contains('结算未完成'));
    expect(c.npcProfileById('a')!.affinity, old);
    expect(c.pendingTurnSettlement, isNotNull);
    store.failTurn = false;
    expect(
        await c.retryTurnSettlement(c.currentHistory.messages.last.id), isNull);
    expect(c.npcProfileById('a')!.affinity, old + 5);
  });
}

NpcProfile actor([String id = 'a']) => NpcProfile(
    id: id,
    characterId: 'world',
    name: id == 'a' ? '阿澈' : id,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    storyState: const NpcStoryState(
        publicIdentity: '旅人', trueIdentity: '密探', secret: '暗号884', goal: '调查'));

class EvolutionClient extends fixtures.ScriptedClient {
  bool failJudge = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    final text =
        (payload['messages'] as List).map((m) => m['content']).join('\n');
    if (!text.contains('结算文字游戏本轮已经发生') && payload['stream'] != true) {
      return super.send(request);
    }
    final judgment = text.contains('结算文字游戏本轮已经发生');
    final content = judgment
        ? (failJudge
            ? 'invalid'
            : jsonEncode({
                ...fixtures.judgment,
                'gameState': {
                  ...fixtures.judgment['gameState'] as Map,
                  'NPC更新': [
                    {
                      'npcId': 'a',
                      'name': '阿澈',
                      'affinityDelta': 5,
                      'impression': '你帮忙整理了信件',
                      'storyPatch': {'evidence': '阿澈向你道谢。', 'stance': '愿意合作'}
                    }
                  ]
                }
              }))
        : '灯亮了。阿澈向你道谢。\n${failJudge ? '' : fixtures.protocol}';
    final body = payload['stream'] == true
        ? 'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': content}
                  }
                ]
              })}\n\ndata: [DONE]\n\n'
        : jsonEncode({
            'choices': [
              {
                'message': {'content': content}
              }
            ]
          });
    requests.add(text);
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200,
        headers: {
          'content-type': payload['stream'] == true
              ? 'text/event-stream'
              : 'application/json'
        });
  }
}

class FailingTurnStore extends LocalStore {
  bool failTurn = false;
  @override
  Future<void> commitTurnState(
      {required DialogueHistory history,
      GameStateSnapshot? gameState,
      CharacterMemory? memory,
      List<NpcProfile>? npcProfiles,
      GamificationState? gamification,
      StoryContinuityState? continuity}) {
    if (failTurn) throw StateError('simulated atomic save failure');
    return super.commitTurnState(
        history: history,
        gameState: gameState,
        memory: memory,
        npcProfiles: npcProfiles,
        gamification: gamification,
        continuity: continuity);
  }
}
