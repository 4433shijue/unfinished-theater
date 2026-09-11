import 'dart:convert';

import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_memory.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/prompt_cache.dart';
import 'package:ai_roleplay_chat/models/simulator_prompt_request.dart';
import 'package:ai_roleplay_chat/models/user_profile.dart';
import 'package:ai_roleplay_chat/models/world_book.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/gameplay_system_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('chat request keeps stable anchor and puts dynamic context in user turn',
      () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings(),
      character: _character(),
      gameState: GameStateSnapshot.empty('char-cache').copyWith(
        location: '雨巷码头',
        mainTask: '观察来客',
      ),
      userProfile: UserProfile(
        id: 'user-a',
        name: '玩家甲',
        createdAt: DateTime(2026, 5, 24),
        persona: '谨慎的旅人。',
      ),
      worldBooks: <WorldBookEntry>[
        _worldBook(
          id: 'front-a',
          title: '前部边界',
          content: '世界边界固定。',
          position: WorldBookInjectionPosition.front,
        ),
        _worldBook(
          id: 'middle-a',
          title: '中部设定',
          content: '长期背景固定。',
          position: WorldBookInjectionPosition.middle,
        ),
        _worldBook(
          id: 'rear-a',
          title: '后部提醒',
          content: '当前地点附近有茶香。',
          position: WorldBookInjectionPosition.rear,
        ),
      ],
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '我推门进去。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: <CharacterMemorySummary>[
        CharacterMemorySummary(
          id: 'mem-a',
          summaryText: '玩家甲曾经帮助过掌柜。',
          relatedMessageIds: const <String>[],
          timestamp: DateTime(2026, 5, 24),
        ),
      ],
    ).drain<void>();

    final messages = capture.messages;
    expect(messages, hasLength(2));
    expect(messages[0]['role'], 'system');
    expect(messages[1]['role'], 'user');

    final staticPrompt = messages[0]['content'] as String;
    expect(staticPrompt, contains('【固定输出协议｜最高优先级】'));
    expect(staticPrompt, contains('世界边界固定。'));
    expect(staticPrompt, contains('长期背景固定。'));
    expect(staticPrompt, isNot(contains('当前地点附近有茶香')));
    expect(staticPrompt, contains('谨慎的旅人'));
    expect(staticPrompt, isNot(contains('雨巷码头')));

    final userTurn = messages[1]['content'] as String;
    expect(userTurn, contains('【本轮上下文快照'));
    expect(userTurn, isNot(contains('谨慎的旅人')));
    expect(userTurn, contains('玩家甲曾经帮助过掌柜'));
    expect(userTurn, contains('当前地点附近有茶香'));
    expect(userTurn, contains('雨巷码头'));
    expect(staticPrompt, contains('【本轮回复格式强制提醒】'));
    expect(staticPrompt, contains('【最终输出格式复核｜生成前最后检查】'));
    expect(userTurn, isNot(contains('【本轮回复格式强制提醒】')));
    expect(userTurn, isNot(contains('【最终输出格式复核｜生成前最后检查】')));
    expect(userTurn, contains('【用户本轮输入】'));
    expect(userTurn, contains('我推门进去。'));
  });

  test('same-priority world books keep stable created-time order', () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings(),
      character: _character(),
      worldBooks: <WorldBookEntry>[
        _worldBook(
          id: 'newer',
          title: '较新创建',
          content: '较新内容。',
          position: WorldBookInjectionPosition.front,
          mode: WorldBookTriggerMode.always,
          createdAt: DateTime(2026, 5, 2),
          updatedAt: DateTime(2026, 5, 2),
        ),
        _worldBook(
          id: 'older',
          title: '较早创建',
          content: '较早内容。',
          position: WorldBookInjectionPosition.front,
          mode: WorldBookTriggerMode.always,
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 24),
        ),
      ],
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    final staticPrompt = capture.messages.first['content'] as String;
    expect(
      staticPrompt.indexOf('较早创建'),
      lessThan(staticPrompt.indexOf('较新创建')),
    );
  });

  test('dynamic world books stay out of stable anchor', () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings(),
      character: _character(),
      worldBooks: <WorldBookEntry>[
        _worldBook(
          id: 'always',
          title: '常驻边界',
          content: '常驻规则内容。',
          position: WorldBookInjectionPosition.front,
          mode: WorldBookTriggerMode.always,
        ),
        _worldBook(
          id: 'triggered',
          title: '茶香触发',
          content: '茶香触发内容。',
          position: WorldBookInjectionPosition.rear,
          mode: WorldBookTriggerMode.keyword,
        ),
      ],
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    final stableAnchor = capture.messages.first['content'] as String;
    final userEnvelope = capture.messages.last['content'] as String;
    expect(stableAnchor, contains('常驻规则内容'));
    expect(stableAnchor, isNot(contains('茶香触发内容')));
    expect(userEnvelope, contains('茶香触发内容'));
  });

  test('assistant history sent to model omits local panels and leaked meta',
      () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings(),
      character: _character(),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 25),
          isSummarized: false,
        ),
        ChatMessage(
          id: 'msg-assistant',
          role: ChatRole.assistant,
          content: '''
他把茶盏推到你手边。

一个完整、自包含、适配手机竖屏浏览的 HTML 状态面板，用于本轮剧情展示：

```html
<html><body><section>状态卡</section></body></html>
```

[GAME_STATE]
时间：夜晚
地点：茶馆
状态：等待
当前任务：继续观察
人物数据：用户：谨慎
关系网：用户 ↔ 掌柜：认识
剧情记录：推门进入
NPC变化：无
NPC更新：无
[/GAME_STATE]

[CHOICES]
A|坐下
B|离开
[/CHOICES]
''',
          timestamp: DateTime(2026, 5, 25),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    final assistantContext = capture.messages.firstWhere(
      (message) => message['role'] == 'assistant',
    )['content'] as String;

    expect(assistantContext, contains('他把茶盏推到你手边'));
    expect(assistantContext, contains('他把茶盏推到你手边'));
    expect(assistantContext, isNot(contains('完整、自包含')));
    expect(assistantContext, isNot(contains('<html>')));
    expect(assistantContext, isNot(contains('[GAME_STATE]')));
    expect(assistantContext, isNot(contains('[CHOICES]')));
  });

  test('prompt replay content is reused without rebuilding context', () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings(),
      character: _character(),
      gameState: GameStateSnapshot.empty('char-cache').copyWith(
        location: '会被 replay 遮住的地点',
      ),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 25),
          isSummarized: false,
          promptReplayContent: '【已保存快照】旧地点\n\n【用户本轮输入】继续。',
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    final userContext = capture.messages.last['content'] as String;
    expect(userContext, '【已保存快照】旧地点\n\n【用户本轮输入】继续。');
    expect(userContext, isNot(contains('会被 replay 遮住的地点')));
  });

  test('builds standard chat messages with cache-friendly replay chain',
      () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final firstUserReplay = client.buildUserPromptReplayContent(
      character: _character(),
      gameState: GameStateSnapshot.empty('char-cache').copyWith(
        location: '第一轮地点',
      ),
      memorySummaries: const <CharacterMemorySummary>[],
      userContent: '第一轮行动。',
    );
    final firstAssistantReplay = client.buildAssistantPromptReplayContent(
        '第一轮正文。\n\n```html\n<html></html>\n```');

    await client.streamChat(
      settings: _settings(),
      character: _character(),
      gameState: GameStateSnapshot.empty('char-cache').copyWith(
        location: '第二轮地点',
      ),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'u1',
          role: ChatRole.user,
          content: '第一轮行动。',
          timestamp: DateTime(2026, 5, 25),
          isSummarized: false,
          promptReplayContent: firstUserReplay,
        ),
        ChatMessage(
          id: 'a1',
          role: ChatRole.assistant,
          content: '第一轮正文。',
          timestamp: DateTime(2026, 5, 25),
          isSummarized: false,
          promptReplayContent: firstAssistantReplay,
        ),
        ChatMessage(
          id: 'u2',
          role: ChatRole.user,
          content: '第二轮行动。',
          timestamp: DateTime(2026, 5, 25),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    expect(capture.messages.map((message) => message['role']), <String>[
      'system',
      'user',
      'assistant',
      'user',
    ]);
    expect(capture.messages[1]['content'], firstUserReplay);
    expect(capture.messages[2]['content'], firstAssistantReplay);
    final latestUser = capture.messages[3]['content'] as String;
    expect(latestUser, contains('第二轮地点'));
    expect(latestUser, contains('【用户本轮输入】'));
    expect(latestUser, contains('第二轮行动。'));
  });

  test('main chat prompt reserves room for light novel length replies',
      () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings(),
      character: _character(),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续写。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    expect(capture.maxTokens, 8192);
    final staticPrompt = capture.messages.first['content'] as String;
    final userTurn = capture.messages.last['content'] as String;
    expect(staticPrompt, contains('【主聊天叙事长度｜轻小说正文】'));
    expect(staticPrompt, contains('硬性下限为 2000 个中文字符'));
    expect(staticPrompt, contains('正式剧情推进时纯文字正文不少于 2000 个中文字符'));
    expect(staticPrompt, contains('HTML、状态块和选项不计入正文长度'));
    expect(userTurn, isNot(contains('正式剧情推进时纯文字正文不少于 2000 个中文字符')));
    expect(userTurn, isNot(contains('HTML、状态块和选项不计入正文长度')));
  });

  test('format repair receives current gameplay paths without engine secrets',
      () async {
    final capture = _CapturingClient(
      responseBody: jsonEncode(<String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'message': <String, dynamic>{'content': '已修复'},
          },
        ],
      }),
    );
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);
    final system = GameplaySystemParser.parse('''
{
  "schemaVersion": 1,
  "title": "茶馆暗潮",
  "summary": "追踪关系与幕后秘密。",
  "coreLoop": "交谈并观察反应。",
  "variables": [
    {
      "key": "关系.掌柜信任",
      "label": "掌柜信任",
      "group": "关系",
      "type": "number",
      "visibility": "public",
      "authority": "ai",
      "initialValue": 20,
      "description": "坦诚或欺骗时变化",
      "min": 0,
      "max": 100,
      "maxDelta": 8
    },
    {
      "key": "幕后.真相种子",
      "label": "真相种子",
      "group": "幕后",
      "type": "number",
      "visibility": "engine",
      "authority": "rule",
      "initialValue": 771,
      "description": "固定秘密"
    },
    {
      "key": "局势.茶馆警觉",
      "label": "茶馆警觉",
      "group": "局势",
      "type": "number",
      "visibility": "fuzzy",
      "authority": "ai",
      "initialValue": 10,
      "description": "公开冲突时变化",
      "min": 0,
      "max": 100,
      "maxDelta": 10,
      "stages": [{"min": 0, "label": "平静"}, {"min": 50, "label": "戒备"}]
    },
    {
      "key": "幕后.追查进度",
      "label": "追查进度",
      "group": "幕后",
      "type": "number",
      "visibility": "director",
      "authority": "ai",
      "initialValue": 0,
      "description": "掌柜暗中追查时变化",
      "min": 0,
      "max": 100,
      "maxDelta": 8
    }
  ],
  "rules": []
}
''');

    await client.repairChatReplyFormat(
      settings: _settings(),
      character: _character().copyWith(gameplaySystem: system),
      originalReply: '掌柜接受了你的解释。',
      latestUserMessage: '我把真相告诉他。',
      gameState: GameStateSnapshot.empty('char-cache').copyWith(
        customVariables: const <String, dynamic>{
          '关系.掌柜信任': 34,
          '幕后.真相种子': 771,
        },
      ),
    );

    final repairPrompt = capture.messages.last['content'] as String;
    expect(repairPrompt, contains('【玩法变量补丁修复上下文】'));
    expect(repairPrompt, contains('关系.掌柜信任 = 34'));
    expect(repairPrompt, contains('authority=ai'));
    expect(repairPrompt, isNot(contains('幕后.真相种子')));
    expect(repairPrompt, isNot(contains('771')));
  });

  test('large group chat prompt replaces html and six-choice protocol',
      () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings(),
      character: _character().copyWith(
        largeGroupChatModeEnabled: true,
        nextStepOptionsEnabled: true,
        segmentedOutputEnabled: true,
      ),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'a1',
          role: ChatRole.assistant,
          content: '''
[GROUP_CHAT]
{"mode":"large_group_chat","messages":[{"type":"narration","speaker":"旁白","content":"上一轮。"}]}
[/GROUP_CHAT]
''',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
        ChatMessage(
          id: 'a2',
          role: ChatRole.assistant,
          content: '''
[GROUP_CHAT]
{"mode":"large_group_chat","messages":[{"type":"narration","speaker":"旁白","content":"又一轮。"}]}
[/GROUP_CHAT]
''',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    final staticPrompt = capture.messages.first['content'] as String;
    final latestUser = capture.messages.last['content'] as String;
    expect(staticPrompt, contains('【大型群聊模式，最高优先级】'));
    expect(staticPrompt, contains('本模式覆盖隐藏协议里关于长篇纯文字正文、HTML 美化框'));
    expect(staticPrompt, contains('旁白 content 不能替任何角色说台词'));
    expect(staticPrompt, contains('NPC content 里不要写'));
    expect(staticPrompt, isNot(contains('隐藏协议固定。')));
    expect(staticPrompt, contains('【大型群聊模式本轮回复格式强制提醒】'));
    expect(staticPrompt, contains('[GROUP_CHAT] JSON 块'));
    expect(latestUser, contains('当前已完成大型群聊回复轮数：2'));
    expect(latestUser, contains('周期性 NPC 主动联系由 App'));
    expect(staticPrompt, contains('旁白 content 不能替角色说话'));
    expect(staticPrompt, contains('NPC content 不能包含动作'));
    expect(latestUser, isNot(contains('【大型群聊模式本轮回复格式强制提醒】')));
    expect(latestUser, isNot(contains('至少一个完整 ```html 代码块')));
    expect(latestUser, isNot(contains('A-F 六个可执行行动')));
  });

  test('stream usage options default on and can be disabled for proxies',
      () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings().copyWith(cacheIsolationId: 'proxy-install-id'),
      character: _character(),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    expect(
      capture.payload['stream_options'],
      <String, dynamic>{'include_usage': true},
    );
    expect(capture.payload.containsKey('user_id'), isFalse);

    await client.streamChat(
      settings: _settings().copyWith(includeStreamUsage: false),
      character: _character(),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user-2',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    expect(capture.payload.containsKey('stream_options'), isFalse);
  });

  test('prompt budget uses unified automatic default of 64K', () {
    final client = LlmApiClient(client: _CapturingClient());
    addTearDown(client.close);

    expect(
      client.promptTokenBudgetFor(
        _settings().copyWith(apiUrl: 'https://api.deepseek.com'),
      ),
      64000,
    );
    expect(client.promptTokenBudgetFor(_settings()), 64000);
    expect(
      client.promptTokenBudgetFor(
        _settings().copyWith(promptTokenBudget: 128000),
      ),
      128000,
    );
  });

  test('deepseek official streaming endpoint requests cache usage by default',
      () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.streamChat(
      settings: _settings().copyWith(
        apiUrl: 'https://api.deepseek.com',
        cacheIsolationId: 'install-cache_123',
      ),
      character: _character(),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    expect(
      capture.payload['stream_options'],
      <String, dynamic>{'include_usage': true},
    );
    expect(capture.payload['user_id'], 'install-cache_123');
  });

  test('DeepSeek replays only exact provider assistant output', () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client
        .streamChat(
          settings: _settings().copyWith(apiUrl: 'https://api.deepseek.com'),
          character: _character(),
          contextMessages: <ChatMessage>[
            ChatMessage(
              id: 'u1',
              role: ChatRole.user,
              content: '继续。',
              timestamp: DateTime(2026, 5, 24),
              isSummarized: false,
              promptReplayContent: '用户快照',
            ),
            ChatMessage(
              id: 'a1',
              role: ChatRole.assistant,
              content: '界面最终文本',
              timestamp: DateTime(2026, 5, 24),
              isSummarized: false,
              promptReplayContent: '压缩回放文本',
              providerReplayContent: '供应商原始逐字文本',
              providerReplayExact: true,
            ),
            ChatMessage(
              id: 'u2',
              role: ChatRole.user,
              content: '下一步。',
              timestamp: DateTime(2026, 5, 24),
              isSummarized: false,
            ),
          ],
          memorySummaries: const <CharacterMemorySummary>[],
          promptCacheEpoch: PromptCacheEpoch(
            id: 'epoch-1',
            startMessageId: 'u1',
            createdAt: DateTime(2026, 5, 24),
          ),
        )
        .drain<void>();

    expect(capture.messages[2]['content'], '供应商原始逐字文本');

    final nonExactCapture = _CapturingClient();
    final nonExactClient = LlmApiClient(client: nonExactCapture);
    addTearDown(nonExactClient.close);
    await nonExactClient.streamChat(
      settings: _settings().copyWith(apiUrl: 'https://api.deepseek.com'),
      character: _character(),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'u1',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
          promptReplayContent: '用户快照',
        ),
        ChatMessage(
          id: 'a1',
          role: ChatRole.assistant,
          content: '界面最终文本',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
          promptReplayContent: '压缩回放文本',
          providerReplayContent: '不可精确回放的修复文本',
          providerReplayExact: false,
        ),
        ChatMessage(
          id: 'u2',
          role: ChatRole.user,
          content: '下一步。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).drain<void>();

    expect(nonExactCapture.messages[2]['content'], '压缩回放文本');
  });

  test('checkpoint stays in trailing envelope and edited memory is pending',
      () async {
    final capture = _CapturingClient();
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final epoch = PromptCacheEpoch(
      id: 'epoch-checkpoint',
      startMessageId: 'msg-user',
      createdAt: DateTime(2026, 5, 24),
      checkpoint: '【冻结前情】掌柜曾在码头留下暗号。',
      injectedMemorySummaryIds: <String>[
        client.memorySummaryVersionKey(
          _memory('mem-a', '掌柜曾在码头留下暗号。'),
        ),
      ],
      injectedWorldBookKeys: const <String>['world-1:deadbeef'],
    );

    await client
        .streamChat(
          settings: _settings(),
          character: _character(),
          gameState: GameStateSnapshot.empty('char-cache').copyWith(
            location: '雨巷码头',
          ),
          contextMessages: <ChatMessage>[
            ChatMessage(
              id: 'msg-user',
              role: ChatRole.user,
              content: '继续。',
              timestamp: DateTime(2026, 5, 24),
              isSummarized: false,
            ),
          ],
          memorySummaries: <CharacterMemorySummary>[
            _memory('mem-a', '掌柜曾在码头留下暗号。'),
            _memory('mem-b', '编辑后的新记忆：暗号是茶香。'),
          ],
          promptCacheEpoch: epoch,
        )
        .drain<void>();

    final staticPrompt = capture.messages.first['content'] as String;
    final userTurn = capture.messages.last['content'] as String;
    // 检查点不在固定前缀里，而是作为本轮快照放在请求尾部。
    expect(staticPrompt, isNot(contains('【剧情阶段检查点')));
    expect(staticPrompt, isNot(contains('掌柜曾在码头留下暗号')));
    expect(userTurn, contains('【剧情阶段检查点'));
    expect(userTurn, contains('掌柜曾在码头留下暗号'));
    // 记忆按 id+内容版本跟踪：编辑后的新内容会被当作 pending 重新注入。
    expect(userTurn, contains('编辑后的新记忆：暗号是茶香。'));

    final pending = client.pendingMemorySummaryIds(
      <CharacterMemorySummary>[
        _memory('mem-a', '编辑后的新记忆：暗号是茶香。'),
      ],
      epoch,
    );
    expect(pending, isNotEmpty);
    expect(
        pending.single,
        client.memorySummaryVersionKey(
          _memory('mem-a', '编辑后的新记忆：暗号是茶香。'),
        ));

    // 内容未变的记忆不会被重复注入。
    final unchangedPending = client.pendingMemorySummaryIds(
      <CharacterMemorySummary>[
        _memory('mem-a', '掌柜曾在码头留下暗号。'),
      ],
      epoch,
    );
    expect(unchangedPending, isEmpty);
  });

  test('runUtilityTask sends explicit max tokens by default', () async {
    final capture = _CapturingClient(
      responseBody: jsonEncode(<String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'message': <String, dynamic>{'content': '结果'},
          },
        ],
      }),
    );
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    await client.runUtilityTask(
      settings: _settings(),
      systemPrompt: '工具提示。',
      userPrompt: '动态输入。',
    );
    expect(capture.payload['max_tokens'], 8192);

    await client.runUtilityTask(
      settings: _settings(),
      systemPrompt: '工具提示。',
      userPrompt: '动态输入。',
      maxTokens: 16384,
    );
    expect(capture.payload['max_tokens'], 16384);
  });

  test('simulator prompt auto-continues when JSON is incomplete', () async {
    const truncated = '''
{"name": "茶馆暗潮", "description": "一座茶馆里的暗流。", "opening": "你推门而入，茶香扑面。", "systemPrompt": "你扮演"
''';
    final capture = _QueueCaptureClient(<String>[
      _sseChunk(truncated),
      _sseChunk(
        '{"name": "茶馆暗潮", "description": "一座茶馆里的暗流。", "opening": "你推门而入，茶香扑面。", "systemPrompt": "你扮演茶馆掌柜沈砚。每天酉时开馆，客人的秘密都藏在茶里。"}',
      ),
    ]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final result = await client.generateSimulatorPrompt(
      settings: _settings(),
      request: SimulatorPromptGenerationRequest(
        roleName: '茶馆',
        simulatorIdea: '茶馆题材的暗流故事。',
      ),
    );

    expect(capture.calls, 2);
    expect(result.name, '茶馆暗潮');
    expect(result.prompt, contains('掌柜沈砚'));
    // JSON 拆包后 prompt 是纯系统提示词正文，不再带标题头。
    expect(result.prompt, isNot(contains('模拟器名称：')));
    expect(result.openingMessage, contains('茶香扑面'));
  });

  test('simulator prompt skips continuation when JSON is complete', () async {
    const complete = '''
{"name": "雨巷电台", "description": "雨夜小巷里的深夜电台。", "opening": "雨声里，电台的灯亮着。", "systemPrompt": "你扮演深夜电台主持人林默。每轮先描述窗外雨声，再推进来电者的故事。"}
''';
    final capture = _QueueCaptureClient(<String>[_sseChunk(complete)]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final result = await client.generateSimulatorPrompt(
      settings: _settings(),
      request: SimulatorPromptGenerationRequest(
        roleName: '电台',
        simulatorIdea: '雨夜电台题材。',
      ),
    );

    expect(capture.calls, 1);
    expect(result.name, '雨巷电台');
    expect(result.prompt, contains('林默'));
    expect(result.prompt, isNot(contains('模拟器名称：')));
    expect(result.openingMessage, contains('雨声'));
  });

  test('simulator prompt falls back to legacy label parsing', () async {
    const legacy = '''
模拟器名称：旧码头

一句话简介：旧码头上的故事。

开场白：
你站在旧码头上。

系统提示词：
你扮演守夜人。
''';
    final capture = _QueueCaptureClient(<String>[
      _sseChunk(legacy),
      _sseChunk('系统提示词：\n你扮演守夜人，潮汐会带来消息。'),
    ]);
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final result = await client.generateSimulatorPrompt(
      settings: _settings(),
      request: SimulatorPromptGenerationRequest(
        roleName: '码头',
        simulatorIdea: '旧码头题材。',
      ),
    );

    expect(capture.calls, 2);
    expect(result.name, '旧码头');
    expect(result.prompt, contains('守夜人'));
  });

  test('streamContent requests and parses cache usage on deepseek endpoint',
      () async {
    final capture = _CapturingClient(
      responseLines: <String>[
        'data: {"choices":[{"delta":{"content":"片段"}}]}',
        'data: {"usage":{"prompt_cache_hit_tokens":20,"prompt_cache_miss_tokens":5}}',
        'data: [DONE]',
      ],
    );
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final chunks = await client
        .streamContent(
          settings: _settings().copyWith(apiUrl: 'https://api.deepseek.com'),
          systemPrompt: '固定工具提示。',
          userPrompt: '动态输入。',
        )
        .toList();

    expect(chunks, <String>['片段']);
    expect(
      capture.payload['stream_options'],
      <String, dynamic>{'include_usage': true},
    );
  });

  test('stream events parse DeepSeek and OpenAI style cache usage', () async {
    final capture = _CapturingClient(
      responseLines: <String>[
        'data: {"choices":[{"delta":{"content":"A"}}]}',
        'data: {"usage":{"prompt_cache_hit_tokens":120,"prompt_cache_miss_tokens":30,"completion_tokens":20}}',
        'data: [DONE]',
      ],
    );
    final client = LlmApiClient(client: capture);
    addTearDown(client.close);

    final events = await client.streamChatEvents(
      settings: _settings().copyWith(includeStreamUsage: true),
      character: _character(),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).toList();

    expect(events.first.delta, 'A');
    final deepSeekUsage = events.last.usage!;
    expect(deepSeekUsage.cachedInputTokens, 120);
    expect(deepSeekUsage.cacheMissInputTokens, 30);
    expect(deepSeekUsage.outputTokens, 20);
    expect(deepSeekUsage.cacheHitRate, 80);

    final openAiCapture = _CapturingClient(
      responseLines: <String>[
        'data: {"usage":{"prompt_tokens":200,"completion_tokens":25,"prompt_tokens_details":{"cached_tokens":64}}}',
        'data: [DONE]',
      ],
    );
    final openAiClient = LlmApiClient(client: openAiCapture);
    addTearDown(openAiClient.close);

    final openAiEvents = await openAiClient.streamChatEvents(
      settings: _settings().copyWith(includeStreamUsage: true),
      character: _character(),
      contextMessages: <ChatMessage>[
        ChatMessage(
          id: 'msg-user',
          role: ChatRole.user,
          content: '继续。',
          timestamp: DateTime(2026, 5, 24),
          isSummarized: false,
        ),
      ],
      memorySummaries: const <CharacterMemorySummary>[],
    ).toList();

    final openAiUsage = openAiEvents.single.usage!;
    expect(openAiUsage.inputTokens, 200);
    expect(openAiUsage.outputTokens, 25);
    expect(openAiUsage.cachedInputTokens, 64);
    expect(openAiUsage.cacheMissInputTokens, 136);
  });
}

AppSettings _settings() {
  return AppSettings.initial().copyWith(
    apiUrl: 'https://example.test',
    apiKey: 'test-key',
    modelName: 'test-model',
  );
}

CharacterProfile _character() {
  return CharacterProfile(
    id: 'char-cache',
    name: '缓存测试角色',
    createdAt: DateTime(2026, 5, 24),
    prompt: '扮演一个茶馆里的说书人。',
    hiddenPrompt: '隐藏协议固定。',
    modelParams: ModelParams.defaults(),
  );
}

WorldBookEntry _worldBook({
  required String id,
  required String title,
  required String content,
  required WorldBookInjectionPosition position,
  WorldBookTriggerMode mode = WorldBookTriggerMode.always,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return WorldBookEntry(
    id: id,
    title: title,
    content: content,
    global: true,
    triggerMode: mode,
    injectionPosition: position,
    priority: 50,
    createdAt: createdAt ?? DateTime(2026, 5, 1),
    updatedAt: updatedAt ?? DateTime(2026, 5, 1),
  );
}

CharacterMemorySummary _memory(String id, String text) {
  return CharacterMemorySummary(
    id: id,
    summaryText: text,
    relatedMessageIds: const <String>[],
    timestamp: DateTime(2026, 5, 24),
  );
}

String _sseChunk(String content) {
  return 'data: ${jsonEncode(<String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'delta': <String, dynamic>{'content': content},
          },
        ],
      })}\n\n';
}

class _QueueCaptureClient extends http.BaseClient {
  _QueueCaptureClient(this.bodies);

  final List<String> bodies;
  int calls = 0;
  final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls += 1;
    if (request is http.Request) {
      payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
    }
    final body = calls - 1 < bodies.length ? bodies[calls - 1] : bodies.last;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: <String, String>{'content-type': 'text/event-stream'},
    );
  }
}

class _CapturingClient extends http.BaseClient {
  _CapturingClient({
    this.responseLines = const <String>['data: [DONE]'],
    this.responseBody,
  });

  final List<String> responseLines;
  final String? responseBody;
  List<Map<String, dynamic>> messages = const <Map<String, dynamic>>[];
  Map<String, dynamic> payload = const <String, dynamic>{};
  int? maxTokens;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      maxTokens = payload['max_tokens'] as int?;
      messages = (payload['messages'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(responseBody ?? '${responseLines.join('\n')}\n\n'),
      ),
      200,
      headers: <String, String>{
        'content-type':
            responseBody == null ? 'text/event-stream' : 'application/json',
      },
    );
  }
}
