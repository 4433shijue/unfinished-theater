import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/services/game_state_parser.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/message_content_parser.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/services/npc_message_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('filters state-like proactive messages out of NPC chat content', () {
    expect(
      NpcMessageClassifier.isDeliverableChatBubble('无（邀请信已传递，等待回复中）'),
      isFalse,
    );
    expect(
      NpcMessageClassifier.isDeliverableChatBubble('明日将收到苏青的信'),
      isFalse,
    );
    expect(
      NpcMessageClassifier.isDeliverableChatBubble('你明天有空吗？我想和你谈谈。'),
      isTrue,
    );
    expect(
      NpcMessageClassifier.isDeliverableChatBubble('你现在状态怎么样？'),
      isTrue,
    );
    expect(
      NpcMessageClassifier.isDeliverableChatBubble('状态：等待苏青回复'),
      isFalse,
    );
  });

  test('keeps NPC changes as panel text and parses NPC updates as profiles',
      () {
    final parsed = GameStateParser.parseFromMessage(
      characterId: 'char-1',
      previous: GameStateSnapshot.empty('char-1'),
      content: '''
[GAME_STATE]
时间：夜晚
地点：教室
状态：刚收到信
当前任务：等待回信
人物数据：用户：紧张
关系网：用户 ↔ 楚玄清：旧识
剧情记录：邀请信已传递
NPC变化：楚玄清：邀请信已传递，等待回复中
NPC更新：楚玄清｜简介：沉稳的同班同学｜好感度：12｜印象：对用户的邀请有些在意｜主动消息：无（邀请信已传递，等待回复中）
[/GAME_STATE]
''',
    );

    expect(parsed, isNotNull);
    expect(parsed!.npcChanges.single, contains('等待回复中'));
    expect(parsed.npcUpdates, hasLength(1));
    expect(parsed.npcUpdates.single.name, '楚玄清');
    expect(parsed.npcUpdates.single.proactiveMessage, isEmpty);
  });

  test('does not treat NPC private triggers as profile updates', () {
    final parsed = GameStateParser.parseFromMessage(
      characterId: 'char-1',
      previous: GameStateSnapshot.empty('char-1'),
      content: '''
[GAME_STATE]
时间：夜晚
地点：走廊
状态：等待
当前任务：观察后续
人物数据：用户：停在门口
关系网：楚玄清：旧识
剧情记录：邀请信已传递
NPC私聊触发：楚玄清｜主动消息：明日将主动找苏青
NPC变化：楚玄清：明日将主动找苏青
[/GAME_STATE]
''',
    );

    expect(parsed, isNotNull);
    expect(parsed!.npcChanges.single, contains('明日将主动找苏青'));
    expect(parsed.npcUpdates, isEmpty);
  });

  test('parses json NPC updates with Chinese keys', () {
    final parsed = GameStateParser.parseFromMessage(
      characterId: 'char-1',
      previous: GameStateSnapshot.empty('char-1'),
      content: '''
[GAME_STATE]
{
  "时间": "夜晚",
  "地点": "教室",
  "状态": "刚收到信",
  "当前任务": "等待回信",
  "人物数据": ["用户：紧张"],
  "关系网": ["用户 ↔ 楚玄清：旧识"],
  "剧情记录": ["邀请信已传递"],
  "NPC更新": [
    {
      "姓名": "楚玄清",
      "简介": "沉稳的同班同学",
      "好感度": 12,
      "印象": "对用户的邀请有些在意",
      "主动消息": "明日将收到苏青的信"
    }
  ]
}
[/GAME_STATE]
''',
    );

    expect(parsed, isNotNull);
    expect(parsed!.npcUpdates, hasLength(1));
    expect(parsed.npcUpdates.single.name, '楚玄清');
    expect(parsed.npcUpdates.single.description, '沉稳的同班同学');
    expect(parsed.npcUpdates.single.impression, '对用户的邀请有些在意');
    expect(parsed.npcUpdates.single.affinity, 12);
    expect(parsed.npcUpdates.single.proactiveMessage, isEmpty);
  });

  test('strips loose state panels from visible story text', () {
    const content = '''
他把伞沿压低，雨水顺着石阶往下淌。

时间：黄昏
地点：碧落峰
状态：猫身形态，妖力32/100
当前任务：恢复妖力至60%以上
人物数据：咪咪｜猫妖化形｜妖力32/100｜体力61/100
支线任务：无
背包：空
事件卡：猫影示弱
事件描述：叶凡对猫形态更包容
''';

    final parsed = MessageContentParser.parseStructured(content);
    final visible = parsed.blocks.map((block) => block.content).join('\n');

    expect(visible, contains('他把伞沿压低'));
    expect(visible, isNot(contains('时间：黄昏')));
    expect(visible, isNot(contains('人物数据：咪咪')));
  });

  test('parses loose state panels as game state fallback', () {
    final parsed = GameStateParser.parseFromMessage(
      characterId: 'char-loose-state',
      previous: GameStateSnapshot.empty('char-loose-state'),
      content: '''
剧情正文。

时间：黄昏
地点：碧落峰
状态：猫身形态，妖力32/100
当前任务：恢复妖力至60%以上
人物数据：咪咪｜猫妖化形｜妖力32/100｜体力61/100
事件卡：猫影示弱
事件描述：叶凡对猫形态更包容
''',
    );

    expect(parsed, isNotNull);
    expect(parsed!.timeLabel, '黄昏');
    expect(parsed.location, '碧落峰');
    expect(parsed.mainTask, '恢复妖力至60%以上');
    expect(parsed.eventTitle, '猫影示弱');
  });

  test('keeps ordinary prose that only mentions one state-like label', () {
    const content = '她低声提醒你：时间：今晚之前都不要回头。随后又把灯按灭。';

    final parsed = MessageContentParser.parseStructured(content);
    final visible = parsed.blocks.map((block) => block.content).join('\n');

    expect(visible, contains('时间：今晚之前都不要回头'));
  });

  test('strips assistant implementation narration before visible rendering',
      () {
    const content = '''
你一枚固本培元丹。

一个完整、自包含、适配手机竖屏浏览的 HTML 状态面板，用于本轮剧情展示：

```html
<html><body><section>状态卡</section></body></html>
```
''';

    final parsed = MessageContentParser.parseStructured(content);
    final visible = parsed.blocks.map((block) => block.content).join('\n');

    expect(visible, contains('你一枚固本培元丹'));
    expect(visible, isNot(contains('完整、自包含')));
    expect(parsed.blocks.any((block) => block.type.name == 'runnablePreview'),
        isTrue);
  });

  test('parses large group chat block into speaker bubbles', () {
    const content = '''
[GROUP_CHAT]
{
  "mode": "large_group_chat",
  "messages": [
    {"type": "narration", "speaker": "旁白", "content": "雨声压低，所有人同时看向门口。"},
    {"type": "npc", "speaker": "林夏", "content": "你刚才听见了吗？"},
    {"type": "npc", "speaker": "周珩", "content": "别出声，先等它过去。"}
  ]
}
[/GROUP_CHAT]

[GAME_STATE]
时间：夜晚
地点：旧楼
状态：众人警觉
当前任务：确认门外声源
人物数据：你：清醒
关系网：林夏：紧张；周珩：戒备
剧情记录：门外出现异常声响
NPC变化：林夏：更加紧张
NPC更新：林夏｜简介：当前场景 NPC｜好感度：10｜印象：信任用户但很害怕｜主动消息：无
[/GAME_STATE]
''';

    final parsed = MessageContentParser.parseStructured(content);

    expect(parsed.groupChatMessages, hasLength(3));
    expect(parsed.groupChatMessages.first.isNarration, isTrue);
    expect(parsed.groupChatMessages[1].speaker, '林夏');
    expect(parsed.groupChatMessages[1].content, '你刚才听见了吗？');
    expect(parsed.blocks, isEmpty);
  });

  test('parses group chat identity and reply metadata', () {
    const content = '''
[GROUP_CHAT]
{"mode":"large_group_chat","messages":[{"id":"msg_1","type":"narration","speakerId":"narrator","speaker":"旁白","replyTo":"","content":"门锁响了一声。"},{"id":"msg_2","type":"npc","speakerId":"npc-linxia","speaker":"林夏","replyTo":"msg_1","content":"我去看看。"}]}
[/GROUP_CHAT]
''';

    final messages = MessageContentParser.parseGroupChatMessages(content);

    expect(messages, hasLength(2));
    expect(messages.first.id, 'msg_1');
    expect(messages.first.speakerId, 'narrator');
    expect(messages.last.id, 'msg_2');
    expect(messages.last.speakerId, 'npc-linxia');
    expect(messages.last.replyTo, 'msg_1');
  });

  test('reveals completed group chat messages from an open stream', () {
    const partialContent = '''
[GROUP_CHAT]
{"mode":"large_group_chat","messages":[
  {"id":"msg_1","type":"narration","speakerId":"narrator","speaker":"旁白","replyTo":"","content":"门上写着\\"不要进入\\"，锁芯随即转动。"},
  {"id":"msg_2","type":"npc","speakerId":"npc-linxia","speaker":"林夏","replyTo":"msg_1","content":"我觉得
''';

    final parsed = MessageContentParser.parseStructured(
      partialContent,
      cache: false,
    );

    expect(parsed.groupChatMessages, hasLength(1));
    expect(parsed.groupChatMessages.single.id, 'msg_1');
    expect(parsed.groupChatMessages.single.content, contains('不要进入'));
    expect(parsed.blocks, isEmpty);
  });

  test('large group chat history replay keeps summary and strips state', () {
    const content = '''
[GROUP_CHAT]
{"mode":"large_group_chat","messages":[{"type":"narration","speaker":"旁白","content":"灯闪了一下。"},{"type":"npc","speaker":"林夏","content":"别回头。"}]}
[/GROUP_CHAT]

[GAME_STATE]
时间：夜晚
地点：旧楼
状态：警觉
当前任务：离开走廊
人物数据：你：清醒
关系网：林夏：同伴
剧情记录：灯闪烁
NPC变化：无
NPC更新：无
[/GAME_STATE]
''';

    final replay = MessageContentParser.assistantReplayPrefixForModel(content);

    expect(replay, contains('[上一轮大型群聊消息流摘要]'));
    expect(replay, contains('旁白：灯闪了一下。'));
    expect(replay, contains('林夏：别回头。'));
    expect(replay, isNot(contains('[GROUP_CHAT]')));
    expect(replay, isNot(contains('[GAME_STATE]')));
  });

  test('large group chat treats narrator aliases as narration', () {
    const content = '''
[GROUP_CHAT]
{
  "mode": "large_group_chat",
  "messages": [
    {"type": "narrator", "speaker": "镜头", "content": "灯光压低，所有人都停了下来。"},
    {"type": "旁白", "content": "门外传来一声轻响。"}
  ]
}
[/GROUP_CHAT]
''';

    final messages = MessageContentParser.parseGroupChatMessages(content);

    expect(messages, hasLength(2));
    expect(messages.every((message) => message.isNarration), isTrue);
    expect(messages.first.speaker, '旁白');
    expect(messages.last.content, '门外传来一声轻响。');
  });

  test('shows bound NPCs in current world list after initialization', () async {
    final root = _character('root', '主线');
    final branch = _character(
      'branch',
      '分支',
      branchSourceCharacterId: root.id,
    );
    final npc = NpcProfile(
      id: 'npc-1',
      characterId: 'other-world',
      name: '楚玄清',
      description: '跨分支绑定 NPC',
      createdAt: DateTime(2026, 5, 22),
      updatedAt: DateTime(2026, 5, 22),
      boundCharacterIds: <String>[branch.id],
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(AppSettings.initial().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[
        root.toJson(),
        branch.toJson(),
      ]),
      'selected_character_id': branch.id,
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[npc.toJson()]),
    });

    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.currentWorldNpcProfiles.map((item) => item.name), [
      '楚玄清',
    ]);
  });

  test('deleting latest assistant reply rolls game state and NPC back',
      () async {
    final character = _character('char-rollback', '回滚世界');
    final firstState = _state(
      character.id,
      time: '第一天',
      location: '教室',
      task: '等待回信',
      npcName: '楚玄清',
      impression: '对用户有些在意',
      affinity: 12,
      updatedAt: DateTime(2026, 5, 22, 10),
    );
    final secondState = _state(
      character.id,
      time: '第二天',
      location: '天台',
      task: '确认约定',
      npcName: '楚玄清',
      impression: '开始信任用户',
      affinity: 35,
      updatedAt: DateTime(2026, 5, 22, 11),
    );
    final latestMessage = _assistantMessage(
      'a2',
      secondState,
      DateTime(2026, 5, 22, 11),
    );
    final history = DialogueHistory(
      characterId: character.id,
      messages: <ChatMessage>[
        _assistantMessage('a1', firstState, DateTime(2026, 5, 22, 10)),
        latestMessage,
      ],
    );
    final npc = NpcProfile(
      id: 'npc-rollback',
      characterId: character.id,
      name: '楚玄清',
      description: '沉稳的同班同学',
      impression: '开始信任用户',
      affinity: 35,
      createdAt: DateTime(2026, 5, 22, 10),
      updatedAt: DateTime(2026, 5, 22, 11),
      sourceType: NpcProfileSource.auto,
      boundCharacterIds: <String>[character.id],
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(AppSettings.initial().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(history.toJson()),
      'game_state_${character.id}': jsonEncode(secondState.toJson()),
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[npc.toJson()]),
    });

    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.deleteMessage(latestMessage.id);

    expect(controller.currentGameState.timeLabel, '第一天');
    expect(controller.currentGameState.location, '教室');
    expect(controller.currentWorldNpcProfiles, hasLength(1));
    expect(controller.currentWorldNpcProfiles.single.impression, '对用户有些在意');
    expect(controller.currentWorldNpcProfiles.single.affinity, 12);
  });

  test('deleting only assistant reply removes NPC created by that turn',
      () async {
    final character = _character('char-delete-new-npc', '新 NPC 世界');
    final state = _state(
      character.id,
      time: '第一天',
      location: '走廊',
      task: '遇见新同学',
      npcName: '林夏',
      impression: '觉得用户很突然',
      affinity: 5,
      updatedAt: DateTime(2026, 5, 22, 10),
    );
    final message = _assistantMessage('a1', state, DateTime(2026, 5, 22, 10));
    final history = DialogueHistory(
      characterId: character.id,
      messages: <ChatMessage>[message],
    );
    final npc = NpcProfile(
      id: 'npc-new',
      characterId: character.id,
      name: '林夏',
      impression: '觉得用户很突然',
      affinity: 5,
      createdAt: DateTime(2026, 5, 22, 10),
      updatedAt: DateTime(2026, 5, 22, 10),
      sourceType: NpcProfileSource.auto,
      boundCharacterIds: <String>[character.id],
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(AppSettings.initial().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[character.toJson()]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(history.toJson()),
      'game_state_${character.id}': jsonEncode(state.toJson()),
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[npc.toJson()]),
    });

    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.deleteMessage(message.id);

    expect(controller.currentGameState.isEmpty, isTrue);
    expect(controller.currentWorldNpcProfiles, isEmpty);
  });

  test('story branch does not inherit root NPCs created after branch point',
      () async {
    final root = _character('root-future', '主线');
    final branch = _character(
      'branch-future',
      '旧分支',
      branchSourceCharacterId: root.id,
      branchOriginMessageId: 'origin',
    );
    final originState = _state(
      branch.id,
      time: '第一天',
      location: '教室',
      task: '分支点',
      npcName: '楚玄清',
      impression: '已经认识用户',
      affinity: 10,
      updatedAt: DateTime(2026, 5, 22, 10),
    );
    final branchHistory = DialogueHistory(
      characterId: branch.id,
      messages: <ChatMessage>[
        _assistantMessage('origin', originState, DateTime(2026, 5, 22, 10)),
      ],
    );
    final oldNpc = NpcProfile(
      id: 'npc-old',
      characterId: root.id,
      name: '楚玄清',
      impression: '已经认识用户',
      affinity: 10,
      createdAt: DateTime(2026, 5, 22, 10),
      updatedAt: DateTime(2026, 5, 22, 10),
      sourceType: NpcProfileSource.auto,
      boundCharacterIds: <String>[root.id],
    );
    final futureNpc = NpcProfile(
      id: 'npc-future',
      characterId: root.id,
      name: '苏青',
      impression: '未来才认识用户',
      affinity: 20,
      createdAt: DateTime(2026, 5, 22, 11),
      updatedAt: DateTime(2026, 5, 22, 11),
      sourceType: NpcProfileSource.auto,
      boundCharacterIds: <String>[root.id],
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(AppSettings.initial().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[
        root.toJson(),
        branch.toJson(),
      ]),
      'selected_character_id': branch.id,
      'history_${branch.id}': jsonEncode(branchHistory.toJson()),
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[
        oldNpc.toJson(),
        futureNpc.toJson(),
      ]),
    });

    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(
      controller.currentWorldNpcProfiles.map((item) => item.name),
      ['楚玄清'],
    );
  });

  test('clearing character history also removes local NPCs only', () async {
    final character = _character('char-clear', '倒带世界');
    final otherCharacter = _character('other-char', '其他文游');
    final localNpc = NpcProfile(
      id: 'npc-local',
      characterId: character.id,
      name: '林若薇',
      description: '本周目生成的 NPC',
      createdAt: DateTime(2026, 5, 25, 10),
      updatedAt: DateTime(2026, 5, 25, 10),
      boundCharacterIds: <String>[character.id],
    );
    final globalNpc = NpcProfile(
      id: 'npc-global',
      characterId: 'library',
      name: '跨世界角色卡',
      description: '不该被清空聊天记录删掉',
      createdAt: DateTime(2026, 5, 25, 10),
      updatedAt: DateTime(2026, 5, 25, 10),
      globalBinding: true,
      boundCharacterIds: const <String>[],
      roleCard: '可复用角色卡',
      roleCardFinalized: true,
    );
    final sharedNpc = NpcProfile(
      id: 'npc-shared',
      characterId: otherCharacter.id,
      name: '共享 NPC',
      description: '绑定到多个模拟器，只移除当前绑定',
      createdAt: DateTime(2026, 5, 25, 10),
      updatedAt: DateTime(2026, 5, 25, 10),
      boundCharacterIds: <String>[character.id, 'other-char'],
      roleCard: '共享角色卡',
      roleCardFinalized: true,
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_settings': jsonEncode(AppSettings.initial().toJson()),
      'characters': jsonEncode(<Map<String, dynamic>>[
        character.toJson(),
        otherCharacter.toJson(),
      ]),
      'selected_character_id': character.id,
      'history_${character.id}': jsonEncode(
        DialogueHistory(
          characterId: character.id,
          messages: <ChatMessage>[
            ChatMessage(
              id: 'm1',
              role: ChatRole.user,
              content: '你好',
              timestamp: DateTime(2026, 5, 25, 10),
              isSummarized: false,
            ),
          ],
        ).toJson(),
      ),
      'npc_profiles': jsonEncode(<Map<String, dynamic>>[
        localNpc.toJson(),
        globalNpc.toJson(),
        sharedNpc.toJson(),
      ]),
      'npc_messages_${localNpc.id}': jsonEncode(<Map<String, dynamic>>[
        NpcChatMessage(
          id: 'nm1',
          npcId: localNpc.id,
          role: NpcMessageRole.npc,
          content: '旧周目消息',
          timestamp: DateTime(2026, 5, 25, 10),
          batchId: 'batch-local',
        ).toJson(),
      ]),
    });

    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.clearCurrentCharacterHistory();

    expect(controller.npcProfiles.map((item) => item.id),
        isNot(contains('npc-local')));
    expect(
        controller.npcProfiles.map((item) => item.id), contains('npc-global'));
    final remainingShared = controller.npcProfileById('npc-shared');
    expect(remainingShared, isNotNull);
    expect(remainingShared!.boundCharacterIds, <String>['other-char']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('npc_messages_${localNpc.id}'), isNull);
  });
}

CharacterProfile _character(
  String id,
  String name, {
  String? branchSourceCharacterId,
  String? branchOriginMessageId,
}) {
  return CharacterProfile(
    id: id,
    name: name,
    createdAt: DateTime(2026, 5, 22),
    prompt: '$name prompt',
    modelParams: ModelParams.defaults(),
    branchSourceCharacterId: branchSourceCharacterId,
    branchOriginMessageId: branchOriginMessageId,
  );
}

ChatMessage _assistantMessage(
  String id,
  GameStateSnapshot state,
  DateTime timestamp,
) {
  return ChatMessage(
    id: id,
    role: ChatRole.assistant,
    content: _stateContent(state),
    timestamp: timestamp,
    isSummarized: false,
    gameStateSnapshot: state.toJson(),
  );
}

GameStateSnapshot _state(
  String characterId, {
  required String time,
  required String location,
  required String task,
  required String npcName,
  required String impression,
  required int affinity,
  required DateTime updatedAt,
}) {
  return GameStateSnapshot(
    characterId: characterId,
    updatedAt: updatedAt,
    timeLabel: time,
    location: location,
    status: '推进中',
    mainTask: task,
    npcUpdates: <GameNpcUpdate>[
      GameNpcUpdate(
        name: npcName,
        description: '沉稳的同班同学',
        impression: impression,
        affinity: affinity,
      ),
    ],
  );
}

String _stateContent(GameStateSnapshot state) {
  final update = state.npcUpdates.single;
  return '''
剧情正文。

[GAME_STATE]
时间：${state.timeLabel}
地点：${state.location}
状态：${state.status}
当前任务：${state.mainTask}
人物数据：用户：正常
关系网：用户 ↔ ${update.name}：认识
剧情记录：${state.mainTask}
NPC变化：${update.name}：${update.impression}
NPC更新：${update.name}｜简介：${update.description}｜好感度：${update.affinity}｜印象：${update.impression}｜主动消息：无
[/GAME_STATE]
''';
}
