import 'dart:convert';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/tool_result.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _secret = '番外限定：两人已经在月球结婚';
const _body = '主线正文：两人仍在茶馆等雨，谁也没有离开。';
const _state = '[GAME_STATE]\n时间：今晚\n地点：茶馆\n状态：等待\n当前任务：等雨停\n[/GAME_STATE]';
CharacterProfile _role() => CharacterProfile(
    id: 'inline-test',
    name: '雨夜',
    createdAt: DateTime(2026),
    prompt: '在茶馆等雨。',
    nextStepOptionsEnabled: false,
    modelParams: ModelParams.defaults());
AppSettings _settings() => AppSettings.initial().copyWith(
    apiUrl: 'https://example.invalid/v1',
    apiKey: 'test-key',
    modelName: 'test-model',
    autoSummaryMinMessages: 100);

Future<AppStateController> _controller(_Provider provider,
    {List<ToolResult> records = const [], CharacterProfile? role}) async {
  role ??= _role();
  SharedPreferences.setMockInitialValues({
    'app_settings': jsonEncode(_settings().toJson()),
    'characters': jsonEncode([role.toJson()]),
    'selected_character_id': role.id,
    'tool_results': jsonEncode(records.map((r) => r.toJson()).toList())
  });
  final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: provider),
      memoryService: MemoryService());
  await controller.initialize();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'automatic rounds rotate themes; regenerating a past round keeps its theme',
      () async {
    final provider = _Provider();
    final controller = await _controller(provider);
    addTearDown(controller.dispose);
    await controller.queueUserMessage('等雨停。');
    expect(await controller.requestAssistantReply(), isNull);
    final first = controller.currentHistory.messages.last;
    expect(first.inlineTheaterThemeId, 'backstageChat');
    expect(first.content, contains(_secret));
    expect(first.promptReplayContent, isNot(contains(_secret)));
    await controller.queueUserMessage('继续等。');
    expect(await controller.requestAssistantReply(), isNull);
    expect(controller.currentHistory.messages.last.inlineTheaterThemeId,
        'innerVoice');
    expect(provider.themes, ['backstageChat', 'innerVoice']);
    for (final request in provider.chatRequests) {
      for (final message in (request['messages'] as List)
          .where((m) => m['role'] == 'assistant')) {
        expect(message['content'], isNot(contains(_secret)));
      }
    }
    expect(provider.adjudications.every((p) => !p.contains(_secret)), isTrue);
    expect(controller.currentGameState.location, '茶馆');
    expect(await controller.regenerateAssistantMessage(first.id), isNull);
    expect(provider.themes.last, 'backstageChat');
    expect(
        controller.currentHistory.messages
            .firstWhere((m) => m.id == first.id)
            .inlineTheaterThemeId,
        'backstageChat');
    expect(provider.repairs, 0);
  });

  test(
      'branch, restart and archive retain custom settings and mainline history',
      () async {
    const settings = InlineTheaterSettings(
        mode: InlineTheaterMode.single,
        themeIds: ['objects'],
        customPrompt: '只用桌上的小物件。');
    final provider = _Provider();
    final controller = await _controller(provider,
        role: _role().copyWith(inlineTheaterSettings: settings));
    addTearDown(controller.dispose);
    await controller.queueUserMessage('看桌子。');
    expect(await controller.requestAssistantReply(), isNull);
    final reply = controller.currentHistory.messages.last;
    expect(reply.inlineTheaterThemeId, 'objects');
    expect(
        await controller.createStoryBranchFromMessage(
            messageId: reply.id, branchName: '雨停之前'),
        isNull);
    expect(controller.currentCharacter!.inlineTheaterSettings.toJson(),
        settings.toJson());
    expect(controller.currentHistory.messages.last.id, reply.id);
    final archive =
        await controller.exportAllDataArchive(includeApiSecrets: false);
    expect(await controller.importDataArchive(archive, replaceExisting: true),
        isNull);
    final restarted = AppStateController(
        store: LocalStore(),
        apiClient: LlmApiClient(client: _Provider()),
        memoryService: MemoryService());
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.currentCharacter!.inlineTheaterSettings.toJson(),
        settings.toJson());
    expect(restarted.currentHistory.messages.last.content, contains(_body));
    expect(
        restarted.currentHistory.messages.last.inlineTheaterThemeId, 'objects');
  });

  for (final repairFails in [false, true]) {
    test(
        'invalid panel is repaired once, preserving original prose (failure=$repairFails)',
        () async {
      final provider = _Provider(badInitial: true, badRepair: repairFails);
      final controller = await _controller(provider);
      addTearDown(controller.dispose);
      await controller.queueUserMessage('看雨。');
      expect(await controller.requestAssistantReply(), isNull);
      final reply = controller.currentHistory.messages.last.content;
      expect(provider.repairs, 1);
      expect(reply, contains(_body));
      expect(reply, isNot(contains('修复模型乱改的正文')));
      expect(reply, isNot(contains('血量：999')));
      expect(controller.currentGameState.location, '茶馆');
      expect(
          reply,
          repairFails
              ? contains('本回合彩蛋未生成')
              : contains('data-inline-theater="backstageChat"'));
    });
  }

  test('startup and import delete only the retired standalone artifacts',
      () async {
    ToolResult record(String id, {bool legacyFlag = false}) => ToolResult(
        id: id,
        characterId: _role().id,
        toolId: id,
        toolTitle: id,
        content: '保留或迁移的内容',
        createdAt: DateTime(2026),
        interactiveTheater: legacyFlag);
    final controller = await _controller(_Provider(), records: [
      record('interactive_theater'),
      record('legacy-flag', legacyFlag: true),
      record('npc_diary')
    ]);
    addTearDown(controller.dispose);
    expect(controller.toolResults.map((r) => r.toolId), ['npc_diary']);
    final persisted = await LocalStore().loadToolResults();
    expect(persisted.map((r) => r.toolId), ['npc_diary']);
    final archive = jsonDecode(
            await controller.exportAllDataArchive(includeApiSecrets: false))
        as Map<String, dynamic>;
    final payload = archive['data'] is Map ? archive['data'] as Map : archive;
    payload['toolResults'] = [
      record('interactive_theater').toJson(),
      record('legacy-flag', legacyFlag: true).toJson(),
      record('npc_diary').toJson()
    ];
    // Import unwrapped data so any checksum of the original envelope is not reused.
    expect(
        await controller.importDataArchive(jsonEncode(payload),
            replaceExisting: true),
        isNull);
    expect(controller.toolResults.map((r) => r.toolId), ['npc_diary']);
    expect(controller.currentCharacter?.inlineTheaterSettings.themeIds,
        ['backstageChat', 'innerVoice', 'whatIf']);
  });

  test(
      'exact provider replay, cached replay and memory requests all omit extras',
      () async {
    final provider = _Provider();
    final client = LlmApiClient(client: provider);
    addTearDown(client.close);
    final doc = InlineTheaterTheme.innerVoice.exampleHtml
        .replaceFirst('</body>', '<p>$_secret</p></body>');
    for (final exact in [false, true]) {
      final assistant = ChatMessage(
          id: 'assistant',
          role: ChatRole.assistant,
          content: '$_body\n```html\n$doc\n```',
          timestamp: DateTime(2026),
          isSummarized: false,
          promptReplayContent: '$_body\n```html\n$doc\n```',
          providerReplayContent: '$_body\n```html\n$doc\n```',
          providerReplayExact: exact);
      final input = ChatMessage(
          id: 'user',
          role: ChatRole.user,
          content: '继续',
          timestamp: DateTime(2026),
          isSummarized: false);
      await client.streamChat(
          settings: _settings().copyWith(
              apiUrl: exact
                  ? 'https://api.deepseek.com'
                  : 'https://example.invalid'),
          character: _role(),
          contextMessages: [assistant, input],
          memorySummaries: []).drain<void>();
      final messages = provider.chatRequests.last['messages'] as List;
      expect(messages.where((m) => m['role'] == 'assistant').single['content'],
          isNot(contains(_secret)));
      await client.summarizeConversation(
          settings: _settings(),
          character: _role(),
          messages: [assistant, input]);
      expect(provider.lastPayload.toString(), isNot(contains(_secret)));
    }
  });
}

class _Provider extends http.BaseClient {
  _Provider({this.badInitial = false, this.badRepair = false});
  final bool badInitial;
  final bool badRepair;
  final List<String> themes = [];
  final List<String> adjudications = [];
  final List<Map<String, dynamic>> chatRequests = [];
  Map<String, dynamic> lastPayload = {};
  int repairs = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    lastPayload = payload;
    final messages = payload['messages'] as List;
    final system = messages.first['content'].toString();
    final all = messages.map((m) => m['content']).join('\n');
    final selected =
        RegExp(r'本轮唯一主题ID：([a-zA-Z]+)').allMatches(all).lastOrNull?.group(1) ??
            'backstageChat';
    final theme = InlineTheaterTheme.values
            .where((t) => t.name == selected)
            .firstOrNull ??
        InlineTheaterTheme.backstageChat;
    String reply({required bool bad, String body = _body}) =>
        '$body\n```html\n${bad ? '<html><body><h2>状态面板</h2><p>血量：999</p></body></html>' : theme.exampleHtml.replaceFirst('</body>', '<p>$_secret</p></body>')}\n```\n$_state';
    String response;
    if (payload['stream'] == true) {
      themes.add(selected);
      chatRequests.add(payload);
      response = 'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': reply(bad: badInitial)}
              }
            ]
          })}\n\ndata: [DONE]\n\n';
      return http.StreamedResponse(Stream.value(utf8.encode(response)), 200,
          headers: {'content-type': 'text/event-stream'});
    }
    var content = '{}';
    if (system.contains('结算文字游戏本轮')) {
      adjudications.add(all);
      content = jsonEncode({
        'gameState': {'时间': '今晚', '地点': '茶馆', '状态': '等待', '当前任务': '等雨停'},
        'gameplayPatch': {'ops': []}
      });
    } else if (system.contains('修复 App 回复')) {
      repairs++;
      content = reply(bad: badRepair, body: '修复模型乱改的正文');
    }
    response = jsonEncode({
      'choices': [
        {
          'message': {'content': content}
        }
      ]
    });
    return http.StreamedResponse(Stream.value(utf8.encode(response)), 200,
        headers: {'content-type': 'application/json'});
  }
}
