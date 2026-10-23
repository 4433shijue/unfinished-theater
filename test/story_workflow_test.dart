import 'dart:convert';
import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/character_memory.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/models/map_state.dart';
import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/models/story_continuity.dart';
import 'package:ai_roleplay_chat/models/world_book.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'mixed legacy archives are readable without leaking into private requests',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api, legacySecrets: true, globalNpc: true);
    expect(
        storyMaps(storyMap(c.currentContinuity.data['legacyNpcArchives'])['a'])
            .single['content'],
        contains('741'));
    expect(
        storyMap(storyMap(c.currentContinuity.data['legacyNpcBaselines'])['a'])[
            'impression'],
        contains('742'));
    await c.queueNpcUserMessage('a', '你好');
    await c.requestNpcReply('a');
    expect(api.requests.last, isNot(contains('741')));
    expect(api.requests.last, isNot(contains('742')));
    expect(api.requests.last, isNot(contains('743')));
    await c.createCharacter(CharacterDraft(
        name: '新世界', prompt: '独立剧情', modelParams: ModelParams.defaults()));
    expect(c.npcProfileById('a')!.affinity, 0);
    expect(c.npcMessagesFor('a'), isEmpty);
    await c.selectCharacter('world');
    expect(c.npcProfileById('a')!.affinity, 12);
  });
  test(
      'plot rewrite settles resource changes once from the historical baseline',
      () async {
    final api = ScriptedClient()
      ..operations = [
        {'op': 'inc', 'path': 'money', 'value': -2, 'reason': '支付费用'}
      ];
    final system = GameplaySystem.fromJson({
      'variables': [
        {
          'key': 'money',
          'label': '金币',
          'group': '资源',
          'type': 'number',
          'authority': 'ai',
          'visibility': 'public',
          'initialValue': 20,
          'min': 0,
          'max': 100
        }
      ]
    });
    final c = await fixture(api, system: system);
    await c.queueUserMessage('支付一次');
    expect(await c.requestAssistantReply(), isNull);
    final target = c.currentHistory.messages.last;
    expect(c.currentGameState.customVariables['money'], 18);
    await c.queueUserMessage('再支付一次');
    expect(await c.requestAssistantReply(), isNull);
    expect(c.currentGameState.customVariables['money'], 16);
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(target.id).first, StoryRewriteMode.plot, '改变对话');
    await c.applyStoryRewrite(preview, branchName: '只付一次');
    expect(c.currentGameState.customVariables['money'], 18);
    expect(c.currentGameState.gameplayRuntime.turn, 1);
    await c.selectCharacter('world');
    expect(c.currentGameState.customVariables['money'], 16);
  });
  test('proactive NPC letters also save a rewrite checkpoint', () async {
    final c = await fixture(ScriptedClient());
    expect(await c.sendDailyNpcLetter(), isNull);
    final event = c.currentContinuity.events.single;
    final npcId =
        event['npcId']?.toString() ?? event['privateNpcId']?.toString();
    expect(c.currentContinuity.checkpoints[event['id']], isNotNull);
    expect(storyStrings(event['sourceIds']), hasLength(1));
    expect(npcId, isNotNull);
  });
  test('ordinary branch remaps private fact ownership and rewrite version keys',
      () async {
    final c = await fixture(ScriptedClient(), reusable: false);
    await c.queueNpcUserMessage('a', '你好');
    await c.requestNpcReply('a');
    final message = c.npcMessagesFor('a')[1];
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(message.id, npcId: 'a').single,
        StoryRewriteMode.polish,
        '润色');
    await c.applyStoryRewrite(preview);
    await c.rememberStoryFact(
        text: '私聊已确认的约定', sourceIds: [message.id], npcId: 'a');
    await c.queueUserMessage('继续');
    await c.requestAssistantReply();
    expect(
        await c.createStoryBranchFromMessage(
            messageId: c.currentHistory.messages.last.id, branchName: '复制分支'),
        isNull);
    final npc = c.currentWorldNpcProfiles.firstWhere((n) => n.name == '阿澈');
    expect(npc.id, isNot('a'));
    expect(c.currentContinuity.revisions.containsKey('${npc.id}/${message.id}'),
        true);
    expect(c.currentContinuity.facts.last['privateNpcId'], npc.id);
    expect(c.npcMessagesFor(npc.id).any((m) => m.id == message.id), true);
  });
  test(
      'private requests exclude other NPC secrets, backstage lore and future worlds',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api);
    await c.rememberStoryFact(text: 'A的暗号是雪松731', sourceIds: [], npcId: 'a');
    await c.saveDirectorPreferences('story', {'剧情节奏': '慢一点'});
    await c.queueNpcUserMessage('b', '晚上好');
    expect(await c.requestNpcReply('b'), isNull);
    final request = api.requests.last;
    expect(request, isNot(contains('雪松731')));
    expect(request, isNot(contains('后台密令884')));
    expect(request, contains('城门公开告示'));
    expect(request, contains('慢一点'));
    await c.selectCharacter('other');
    expect(c.npcMessagesFor('b'), isEmpty);
    expect(c.npcProfileById('b')!.affinity, 10);
    await c.selectCharacter('world');
    expect(c.npcMessagesFor('b'), hasLength(3));
    expect(c.npcProfileById('b')!.affinity, 12);
  });
  test(
      'NPC polish previews do not mutate, versions restore and stale previews fail',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api);
    await c.queueNpcUserMessage('a', '你好');
    await c.requestNpcReply('a');
    final target = c.npcMessagesFor('a')[1];
    final before = c.npcProfileById('a')!.affinity;
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(target.id, npcId: 'a').single,
        StoryRewriteMode.polish,
        '换个表达');
    expect(c.npcMessagesFor('a')[1].content, target.content);
    expect(preview.requiresBranch, false);
    await c.applyStoryRewrite(preview);
    expect(c.npcMessagesFor('a')[1].content, '换一种说法。');
    expect(c.npcProfileById('a')!.affinity, before);
    final versions = storyMaps(c.currentContinuity.revisions['a/${target.id}']);
    expect(versions, hasLength(2));
    await expectLater(c.applyStoryRewrite(preview), throwsStateError);
    await c.switchStoryRevision(target.id, versions.first['id'], npcId: 'a');
    expect(c.npcMessagesFor('a')[1].content, target.content);
  });
  test(
      'NPC plot rewrite restores batch baseline, keeps sibling bubbles and original world',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api);
    await c.queueNpcUserMessage('a', '第一问');
    await c.requestNpcReply('a');
    final target = c.npcMessagesFor('a')[1];
    final sibling = c.npcMessagesFor('a')[2].content;
    await c.queueNpcUserMessage('a', '未来暗号900');
    await c.requestNpcReply('a');
    expect(c.npcProfileById('a')!.affinity, 14);
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(target.id, npcId: 'a').single,
        StoryRewriteMode.plot,
        '改为坦诚告知');
    expect(api.requests[api.requests.length - 2], isNot(contains('未来暗号900')));
    await c.applyStoryRewrite(preview, branchName: '私聊 IF');
    expect(c.currentCharacter!.id, isNot('world'));
    expect(c.npcMessagesFor('a'), hasLength(3));
    expect(c.npcMessagesFor('a').last.content, sibling);
    expect(c.npcProfileById('a')!.affinity, 14); // before=10, settlement=4
    await c.selectCharacter('world');
    expect(c.npcMessagesFor('a'), hasLength(6));
    expect(c.npcMessagesFor('a')[1].content, target.content);
    expect(c.npcProfileById('a')!.affinity, 14);
  });
  test(
      'main rewrite truncates main and private future and replays only the changed turn',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api);
    await c.queueUserMessage('第一回合');
    expect(await c.requestAssistantReply(), isNull);
    final target = c.currentHistory.messages.last;
    await c.queueNpcUserMessage('a', '未来私聊暗号');
    await c.requestNpcReply('a');
    await c.rememberStoryFact(text: '未来才知道的结局777', sourceIds: [], npcId: 'a');
    await c.queueUserMessage('第二回合');
    expect(await c.requestAssistantReply(), isNull);
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(target.id).first, StoryRewriteMode.plot, '换个走向');
    expect(api.requests[api.requests.length - 2], isNot(contains('结局777')));
    await c.applyStoryRewrite(preview, branchName: '新走向');
    expect(c.currentHistory.messages, hasLength(2));
    expect(c.npcMessagesFor('a'), isEmpty);
    expect(c.currentContinuity.facts.any((f) => f['text'] == '未来才知道的结局777'),
        false);
    await c.selectCharacter('world');
    expect(c.currentHistory.messages, hasLength(4));
    expect(c.npcMessagesFor('a'), hasLength(3));
  });
  test(
      'main polish and version changes keep settlement and invalidate source summaries',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api);
    await c.queueUserMessage('第一回合');
    await c.requestAssistantReply();
    final target = c.currentHistory.messages.last;
    final state = c.currentGameState.toJson();
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(target.id).first, StoryRewriteMode.polish, '润色');
    expect(preview.requiresBranch, false);
    await c.applyStoryRewrite(preview);
    expect(c.currentGameState.toJson(), state);
    expect(c.currentHistory.messages.last.gameStateSnapshot,
        target.gameStateSnapshot);
    final revisions =
        storyMaps(c.currentContinuity.revisions['main/${target.id}']);
    await c.switchStoryRevision(target.id, revisions.first['id']);
    expect(c.currentHistory.messages.last.content, target.content);
  });
  test(
      'director failure retains scopes; successful closing is atomic and reopening removes chapter',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api);
    await c.saveDirectorPreferences('story', {'篇幅': '短一点'});
    await c.saveDirectorPreferences('scene', {'剧情节奏': '缓慢'});
    await c.saveDirectorPreferences('turn', {'对话比重': '多一些'});
    api.fail = true;
    expect(await c.closeStoryScene(), isNotNull);
    expect(c.currentContinuity.directors['turn'], {'对话比重': '多一些'});
    expect(c.currentContinuity.scene['closed'], isNot(true));
    expect(c.hasPendingUserMessages, false);
    api.fail = false;
    expect(await c.closeStoryScene(), isNull);
    expect(c.currentContinuity.scene['closed'], true);
    expect(c.currentContinuity.chapters, hasLength(1));
    expect(c.currentContinuity.directors.keys, contains('story'));
    expect(c.currentContinuity.directors.keys, isNot(contains('scene')));
    expect(c.currentContinuity.directors.keys, isNot(contains('turn')));
    expect(c.currentGameState.location, '港口');
    await c.reopenStoryScene();
    expect(c.currentContinuity.chapters, isEmpty);
    expect(c.currentContinuity.scene['closed'], false);
  });
  test('polish save failure retains exact original and revision list',
      () async {
    final store = FailingStore();
    final api = ScriptedClient();
    final c = await fixture(api, store: store);
    await c.queueNpcUserMessage('a', '你好');
    await c.requestNpcReply('a');
    final target = c.npcMessagesFor('a')[1];
    final preview = await c.previewStoryRewrite(
        c.storyRewriteTargets(target.id, npcId: 'a').first,
        StoryRewriteMode.polish,
        '润色');
    store.fail = true;
    await expectLater(c.applyStoryRewrite(preview), throwsStateError);
    expect(c.npcMessagesFor('a')[1].content, target.content);
    expect(c.currentContinuity.revisions, isEmpty);
    store.fail = false;
  });
  test(
      'export import retains world isolation, chapters, facts, versions and reading',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api);
    await c.closeStoryScene();
    await c.rememberStoryFact(
        text: '确认事实', sourceIds: [c.currentHistory.messages.last.id]);
    await c.saveReadingPosition('main', c.currentHistory.messages.last.id, 0.4,
        leaving: true);
    final exported = await c.exportAllDataArchive();
    expect(jsonDecode(exported)['schemaVersion'], 3);
    await c.setFactPinned(c.currentContinuity.facts.last['id'], false);
    expect(await c.importDataArchive(exported, replaceExisting: true), isNull);
    expect(c.currentContinuity.facts.last['pinned'], true);
    expect(c.currentContinuity.chapters, hasLength(1));
    expect(storyMap(c.currentContinuity.reading['main'])['fraction'], 0.4);
    final single =
        jsonDecode((await c.exportCharacterDataArchive(characterId: 'world'))!)
            as Map<String, dynamic>;
    final payload = storyMap(storyMap(single['payload'])['data']);
    expect(storyMap(payload['continuity']).keys, ['world']);
    expect(await c.createCurrentCharacterSnapshot('连续性快照'), isNull);
    final snapshotId = c.recoverableSaveSnapshots.first.id;
    await c.setFactPinned(c.currentContinuity.facts.last['id'], false);
    expect(await c.restoreSaveSnapshot(snapshotId), isNull);
    expect(c.currentContinuity.facts.last['pinned'], true);
    expect(c.currentContinuity.chapters, hasLength(1));
  });
  test('deleted source becomes pending verification and stops NPC injection',
      () async {
    final api = ScriptedClient();
    final c = await fixture(api);
    await c.queueNpcUserMessage('a', '告诉你暗号');
    await c.requestNpcReply('a');
    final id = c.npcMessagesFor('a')[1].id;
    await c.rememberStoryFact(text: '删除后不应注入550', sourceIds: [id], npcId: 'a');
    await c.deleteNpcMessage('a', id);
    expect(c.currentContinuity.facts.last['needsReview'], true);
    await c.queueNpcUserMessage('a', '继续');
    await c.requestNpcReply('a');
    expect(api.requests.last, isNot(contains('删除后不应注入550')));
  });
}

final date = DateTime.utc(2026, 10, 23);
const protocol =
    '[GAME_STATE]\n时间：黄昏\n地点：港口\n状态：警觉\n当前任务：调查\n人物数据：无\n剧情物品栏：无\n关系网：无\n剧情记录：无\nNPC变化：无\nNPC更新：无\n[/GAME_STATE]';
final judgment = {
  'gameState': {
    '时间': '黄昏',
    '地点': '港口',
    '状态': '警觉',
    '当前任务': '调查',
    '人物数据': <String>[],
    '剧情物品栏': <String>[],
    '关系网': <String>[],
    '剧情记录': <String>[],
    'NPC变化': <String>[],
    'NPC更新': <String>[]
  },
  'gameplayPatch': {'ops': <dynamic>[]},
  'continuityPatch': {
    'scene': {
      'title': '港口的黄昏',
      'summary': '灯亮了。',
      'evidence': '灯亮了。',
      'participants': ['阿澈'],
      'openThreads': ['还没拆开的信'],
      'pendingReply': '要读信吗'
    }
  }
};
Future<AppStateController> fixture(ScriptedClient api,
    {LocalStore? store,
    GameplaySystem? system,
    bool legacySecrets = false,
    bool globalNpc = false,
    bool reusable = true}) async {
  final worlds = [
    for (final id in ['world', 'other'])
      CharacterProfile(
          id: id,
          name: id,
          createdAt: date,
          prompt: '尊重玩家自主权。',
          gameplaySystem: system,
          modelParams: ModelParams.defaults(),
          nextStepOptionsEnabled: false,
          inlineTheaterSettings: const InlineTheaterSettings(enabled: false))
  ];
  final npcs = [
    for (final id in ['a', 'b'])
      NpcProfile(
          id: id,
          characterId: 'world',
          name: id == 'a' ? '阿澈' : '白鹭',
          roleCard: reusable ? '有界限、有独立判断的朋友。' : '',
          sourceType: NpcProfileSource.manual,
          roleCardFinalized: reusable,
          affinity: 10,
          globalBinding: globalNpc,
          impression: legacySecrets ? '旧混合印象暗号742' : '',
          bondRoute:
              NpcBondRoute(latestEvent: legacySecrets ? '旧混合羁绊暗号743' : ''),
          boundCharacterIds: ['world', 'other'],
          createdAt: date,
          updatedAt: date)
  ];
  SharedPreferences.setMockInitialValues({
    'app_settings': jsonEncode(AppSettings.initial()
        .copyWith(
            apiUrl: 'https://example.test',
            apiKey: 'test-key',
            modelName: 'test-model')
        .toJson()),
    'characters': jsonEncode(worlds.map((c) => c.toJson()).toList()),
    'selected_character_id': 'world',
    'npc_profiles': jsonEncode(npcs.map((n) => n.toJson()).toList()),
    if (legacySecrets)
      'npc_messages_a': jsonEncode([
        NpcChatMessage(
                id: 'legacy-a',
                batchId: 'legacy-batch',
                npcId: 'a',
                role: NpcMessageRole.npc,
                content: '旧混合私聊暗号741',
                timestamp: date)
            .toJson()
      ]),
    'world_books': jsonEncode([
      WorldBookEntry(
              title: '公开',
              content: '城门公开告示',
              global: true,
              visibility: const StoryVisibility(mode: 'public'))
          .toJson(),
      WorldBookEntry(title: '幕后', content: '后台密令884', global: true).toJson()
    ]),
    'game_state_world': jsonEncode(GameStateSnapshot.empty('world')
        .copyWith(timeLabel: '黄昏', location: '港口', status: '警觉', mainTask: '调查')
        .toJson())
  });
  final c = AppStateController(
      store: store ?? LocalStore(),
      apiClient: LlmApiClient(client: api),
      memoryService: MemoryService());
  addTearDown(c.dispose);
  await c.initialize();
  return c;
}

class ScriptedClient extends http.BaseClient {
  final requests = <String>[];
  bool fail = false;
  List<Map<String, dynamic>> operations = [];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    final text =
        (payload['messages'] as List).map((m) => m['content']).join('\n');
    requests.add(text);
    if (fail) {
      return http.StreamedResponse(
          Stream.value(utf8.encode('unavailable')), 400);
    }
    String content;
    if (text.contains('改写用户选中的一段正文')) {
      content = jsonEncode({'replacement': '换一种说法。', 'preservesFacts': true});
    } else if (text.contains('根据私聊正文整理')) {
      content = jsonEncode({'affinityDelta': 4, 'impression': '愿意坦诚交流'});
    } else if (text.contains('结算文字游戏本轮已经发生')) {
      content = jsonEncode({
        ...judgment,
        'gameplayPatch': {'ops': operations}
      });
    } else if (text.contains('任务：生成一封 NPC 主动来信')) {
      content = jsonEncode({
        'messages': ['来信：晚上见。']
      });
    } else if (text.contains('请生成 NPC 对本次消息')) {
      content = jsonEncode({
        'messages': ['我听见了。', '我们慢慢说。'],
        'impressionPatch': {'summary': '认真倾听', 'affinityDelta': 2}
      });
    } else if (payload['stream'] == true) {
      content = '灯亮了。\n\n他停下来等你回应。\n$protocol';
    } else {
      content = '{}';
    }
    final response = payload['stream'] == true
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
    return http.StreamedResponse(Stream.value(utf8.encode(response)), 200,
        headers: {
          'content-type': payload['stream'] == true
              ? 'text/event-stream'
              : 'application/json'
        });
  }
}

class FailingStore extends LocalStore {
  bool fail = false;
  @override
  Future<void> commitStoryWorkspace(
      {required StoryContinuityState state,
      DialogueHistory? history,
      CharacterMemory? memory,
      GameStateSnapshot? gameState,
      MapWorldState? mapState,
      List<NpcProfile>? npcProfiles,
      List<CharacterProfile>? characters,
      String? selectedCharacterId}) {
    if (fail) throw StateError('simulated disk failure');
    return super.commitStoryWorkspace(
        state: state,
        history: history,
        memory: memory,
        gameState: gameState,
        mapState: mapState,
        npcProfiles: npcProfiles,
        characters: characters,
        selectedCharacterId: selectedCharacterId);
  }
}
