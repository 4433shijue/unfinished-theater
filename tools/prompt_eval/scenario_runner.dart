import 'dart:convert';
import 'dart:io';

import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:ai_roleplay_chat/models/character_memory.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/game_state.dart';
import 'package:ai_roleplay_chat/models/gameplay_system.dart';
import 'package:ai_roleplay_chat/models/gamification.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/models/simulator_prompt_request.dart';
import 'package:ai_roleplay_chat/services/gameplay_patch_engine.dart';
import 'package:ai_roleplay_chat/services/gameplay_system_parser.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:ai_roleplay_chat/services/reply_protocol_validator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'eval_transport.dart';

const _stateBlock = '[GAME_STATE]\n时间：清晨\n地点：电台\n状态：调查中\n当前任务：修复通信\n[/GAME_STATE]';

class PromptEvalRunner {
  PromptEvalRunner(this.config);
  final Map<String, dynamic> config;
  final cases = <Map<String, dynamic>>[];

  Future<Map<String, dynamic>> run() async {
    final fixture = jsonDecode(File('tools/prompt_eval/fixtures/scenarios.json').readAsStringSync()) as Map<String, dynamic>;
    final gameplayJson = jsonDecode(File('tools/prompt_eval/fixtures/gameplay.json').readAsStringSync()) as Map<String, dynamic>;
    final system = GameplaySystemParser.parse(jsonEncode(gameplayJson));
    final live = config['mode'] == 'live';
    final key = live ? Platform.environment['PROMPT_EVAL_API_KEY'] ?? '' : 'synthetic-test-key';
    final endpoint = live ? Platform.environment['PROMPT_EVAL_API_URL'] ?? '' : 'https://example.invalid/v1';
    final model = live ? Platform.environment['PROMPT_EVAL_MODEL'] ?? '' : 'synthetic-model';
    if (live && (key.isEmpty || endpoint.isEmpty || model.isEmpty)) {
      throw StateError('Live evaluation requires explicit PROMPT_EVAL_API_KEY, PROMPT_EVAL_API_URL and PROMPT_EVAL_MODEL');
    }
    final uri = Uri.parse(endpoint);
    if (live && (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasQuery || uri.host.isEmpty)) {
      throw StateError('Evaluation endpoint must be HTTPS without credentials/query');
    }
    final budget = EvalBudget(maxRequests: config['maxRequests'] as int, maxOutputTokens: config['maxOutputTokens'] as int);
    final includeStreamUsage = Platform.environment['PROMPT_EVAL_INCLUDE_STREAM_USAGE'] != '0';
    final useStreaming = Platform.environment['PROMPT_EVAL_STREAM'] != '0';
    final settings = AppSettings.initial().copyWith(apiUrl: endpoint, apiKey: key, modelName: model, includeStreamUsage: includeStreamUsage);
    final fixedTime = DateTime.parse(fixture['fixedTime'] as String);
    final report = <String, dynamic>{
      'schemaVersion': 1,
      'mode': live ? 'live' : 'offline_mock',
      'qualityValidated': false,
      'revision': config['revision'],
      'fixtureHash': config['fixtureHash'],
      'model': model,
      'endpointHost': uri.host,
      'sampling': 'production parameters; no deterministic seed assumed',
      'maxRequests': budget.maxRequests,
      'maxOutputTokens': budget.maxOutputTokens,
      'cases': cases,
    };
    void save() {
      report['requests'] = budget.requests;
      report['reservedOutputTokens'] = budget.reservedOutputTokens;
      report['budgetExhausted'] = budget.exhausted;
      final allRequests = cases.expand((c) => (c['requests'] as List? ?? []).cast<Map<String, dynamic>>()).toList();
      final ordinary = cases.where((c) => c['faultInjected'] != true && c['status'] != 'started').toList();
      final usages = allRequests.where((r) => r['usage'] is Map).map((r) => r['usage'] as Map).toList();
      report['summary'] = {
        'ordinaryInitialPassed': ordinary.where((c) => c['firstPassValid'] == true).length,
        'ordinaryInitialEvaluated': ordinary.length,
        'finalPassed': cases.where((c) => c['finalValid'] == true).length,
        'completedCases': cases.where((c) => c['status'] != 'started').length,
        'networkRequests': allRequests.where((r) => r['source'] == 'live_model').length,
        'injectedFaults': allRequests.where((r) => r['source'] == 'fault_fixture').length,
        'additionalCalls': allRequests.where((r) => r['phase'] == 'additional').length,
        'requestsWithUsage': usages.length,
        'reportedPromptTokens': usages.fold<num>(0, (sum, u) => sum + (u['prompt_tokens'] is num ? u['prompt_tokens'] as num : 0)),
        'reportedCompletionTokens': usages.fold<num>(0, (sum, u) => sum + (u['completion_tokens'] is num ? u['completion_tokens'] as num : 0)),
        'usageComplete': allRequests.isNotEmpty && allRequests.every((r) => r['source'] != 'live_model' || r['usage'] is Map),
        'cost': null,
      };
      final target = File(config['output'] as String);
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    }
    save();
    for (var repeat = 0; repeat < (config['repeats'] as int); repeat++) {
      for (final item in fixture['scenarios'] as List) {
        final scenario = Map<String, dynamic>.from(item as Map);
        final selected = (config['scenarios'] as List?)?.cast<String>() ?? <String>[];
        if (selected.isNotEmpty && !selected.contains(scenario['id'])) continue;
        final mode = scenario['mode'] as String? ?? '';
        final kind = scenario['kind'] as String;
        final character = CharacterProfile(
          id: 'prompt-eval-world', name: fixture['world'] as String,
          createdAt: fixedTime, prompt: fixture['characterPrompt'] as String,
          modelParams: ModelParams.defaults(),
        ).copyWith(mapModeEnabled: mode == 'map', largeGroupChatModeEnabled: mode == 'group',
          nextStepOptionsEnabled: mode != 'no_choices', gameplaySystem: mode == 'gameplay' ? system : null);
        final state = GameStateSnapshot.empty(character.id).copyWith(
          updatedAt: fixedTime, timeLabel: '第一天傍晚', location: '电台', status: '调查中', mainTask: '修复通信',
          customVariables: GameplayPatchEngine.initializeValues(system, const {}),
          storyInventory: const [StoryInventoryItem(id: 'unknown-bell', name: '旧铜铃', description: '一只旧铜铃', identified: false, source: 'black_market', mysteryHint: '声音只在旧站台响过')]);
        final history = <ChatMessage>[
          for (var i = 0; i < (fixture['history'] as List).length; i++)
            ChatMessage(id: 'history-$i', role: fixture['history'][i]['role'] == 'user' ? ChatRole.user : ChatRole.assistant, content: fixture['history'][i]['content'] as String, timestamp: fixedTime, isSummarized: false),
          ChatMessage(id: 'current-input', role: ChatRole.user, content: scenario['input'] as String, timestamp: fixedTime, isSummarized: false),
        ];
        final npcs = [
          NpcProfile(id: 'npc-chen', characterId: character.id, name: '陈放', description: '话少，遇事先动手的修理师。', createdAt: fixedTime, updatedAt: fixedTime),
          NpcProfile(id: 'npc-lin', characterId: character.id, name: '林夏', description: '耐心但会坚持界限的电台值班员。', createdAt: fixedTime, updatedAt: fixedTime),
        ];
        final entry = <String, dynamic>{
          'id': scenario['id'], 'title': scenario['title'], 'kind': kind, 'repeat': repeat,
          'input': scenario['input'], 'history': fixture['history'], 'characterPrompt': fixture['characterPrompt'],
          'checks': scenario['checks'], 'faultInjected': scenario.containsKey('fault'),
          'status': 'started', 'firstPassValid': null, 'finalValid': false,
        };
        cases.add(entry);
        final transport = EvalTransport(
          budget: budget, live: live, delegate: live ? http.Client() : null,
          secret: live ? key : '', allowedHost: uri.host, forceFirstMock: scenario.containsKey('fault'),
          mockReply: (index, payload) => mockReply(scenario, index, gameplayJson), onRecord: save,
        );
        entry['requests'] = transport.records;
        final client = LlmApiClient(client: transport);
        AppStateController? controller;
        String output = '';
        try {
          switch (kind) {
            case 'chat':
              output = useStreaming
                  ? await client.streamChat(settings: settings, character: character, gameState: state,
                      npcProfiles: npcs, contextMessages: history, memorySummaries: const <CharacterMemorySummary>[]).join()
                  : await client.sendChat(settings: settings, character: character, gameState: state,
                      npcProfiles: npcs, contextMessages: history, memorySummaries: const <CharacterMemorySummary>[]);
              // Evaluate the same validator as production. Do not invent a
              // second repair policy or a different narrative prompt here.
            case 'summary':
              output = await client.summarizeConversation(settings: settings, character: character, messages: history.take(history.length - 1).toList());
            case 'simulator':
              final generated = await client.generateSimulatorPrompt(settings: settings,
                request: SimulatorPromptGenerationRequest(roleName: '旧城电台', simulatorIdea: scenario['input'] as String));
              output = jsonEncode({'name': generated.name, 'description': generated.description,
                'opening': generated.openingMessage, 'systemPrompt': generated.prompt});
            case 'gameplay':
              final generated = await client.generateGameplaySystem(settings: settings,
                character: character.copyWith(prompt: '${character.prompt}\n${scenario['input']}'));
              output = jsonEncode(generated.toJson());
            case 'item':
            case 'fanfic':
            case 'npc_card':
              // This runner only executes inside Flutter's test binding and
              // intentionally replaces storage with a disposable fixture.
              // ignore: invalid_use_of_visible_for_testing_member
              SharedPreferences.setMockInitialValues({
                'app_settings': jsonEncode(settings.toJson()), 'characters': jsonEncode([character.toJson()]),
                'selected_character_id': character.id, 'game_state_${character.id}': jsonEncode(state.toJson()),
                'npc_profiles': jsonEncode(npcs.map((e) => e.toJson()).toList()),
                'gamification_state': jsonEncode(GamificationState.initial().copyWith(coins: 100).toJson()),
              });
              controller = AppStateController(store: LocalStore(), apiClient: client, memoryService: MemoryService());
              await controller.initialize();
              if (kind == 'item') {
                final error = await controller.identifyStoryInventoryItem('unknown-bell');
                entry['coinsAfter'] = controller.gamification.coins;
                if (error != null) throw StateError('Production item workflow rejected the result');
                final item = controller.currentStoryInventory.single;
                output = jsonEncode({'description': item.description, 'effect': item.effect});
              } else if (kind == 'fanfic') {
                final error = await controller.generateFanfic(pairingMode: 'npc_npc', firstParticipantId: 'npc-chen', secondParticipantId: 'npc-lin', inspiration: scenario['input'] as String, blindBox: false);
                if (error != null) throw StateError('Production fanfic workflow rejected the result');
                output = controller.lastGeneratedFanficResult!.content;
              } else {
                final result = await controller.buildNpcRoleCardDraft(npcId: 'npc-chen', extraInstruction: scenario['input'] as String);
                if (!result.isSuccess) throw StateError('Production NPC workflow rejected the result');
                // Report the model contract as well as the permissive app parser.
                output = transport.records.last['response'] as String;
              }
            default:
              throw StateError('Unknown fixture kind');
          }
          entry['workflowAccepted'] = true;
          entry['status'] = 'completed';
        } catch (error) {
          entry['workflowAccepted'] = false;
          entry['status'] = budget.exhausted ? 'budget_exhausted' : 'failed';
          entry['errorType'] = error.runtimeType.toString();
        } finally {
          final initial = transport.records.isEmpty ? null : transport.records.first['response'] as String;
          entry['firstPassIssues'] = initial == null ? ['No initial response'] : validate(scenario, initial, system);
          entry['firstPassValid'] = initial != null && (entry['firstPassIssues'] as List).isEmpty;
          entry['finalIssues'] = validate(scenario, output, system);
          entry['finalValid'] = entry['workflowAccepted'] == true && (entry['finalIssues'] as List).isEmpty;
          entry['output'] = transport.redact(output);
          entry['additionalRequests'] = transport.records.length > 1 ? transport.records.length - 1 : 0;
          entry['semanticReview'] = 'pending_human_review';
          controller?.dispose();
          client.close();
          save();
        }
        if (budget.exhausted || transport.records.any((r) => r['status'] == 'transport_error' || r['status'] == 'http_error')) {
          report['stoppedEarly'] = true;
          save();
          return report;
        }
      }
    }
    report['stoppedEarly'] = false;
    save();
    return report;
  }

  static List<String> validate(Map<String, dynamic> scenario, String text, GameplaySystem system) {
    if (text.trim().isEmpty) return ['Empty response'];
    final kind = scenario['kind'];
    try {
      if (kind == 'chat') {
        final mode = scenario['mode'];
        final issues = ReplyProtocolValidator.validate(content: text,
          mode: mode == 'group' ? ReplyProtocolMode.largeGroupChat : mode == 'map' ? ReplyProtocolMode.map : ReplyProtocolMode.standard,
          choicesEnabled: mode != 'no_choices', gameplayPatchRequired: mode == 'gameplay', htmlRequired: mode != 'map' && mode != 'group').issues.toList();
        if (mode == 'map') {
          final match = RegExp(r'\[MAP_STATE\]([\s\S]*?)\[/MAP_STATE\]').firstMatch(text);
          if (match != null && jsonDecode(match.group(1)!) is! Map) issues.add('MAP_STATE must be an object');
        }
        if (mode == 'gameplay') {
          final patch = GameplayPatchParser.parseResult(text);
          if (patch.isValid) issues.addAll(GameplayPatchEngine.applyAiPatch(system: system, currentValues: const {}, operations: patch.operations).rejections);
          if (scenario['id'] == 'hidden_variables' && text.contains('暗潮代号7391')) issues.add('Director secret leaked into output');
        }
        return issues;
      }
      if (kind == 'gameplay') {
        GameplaySystemParser.parse(text);
        return [];
      }
      if (kind == 'simulator' || kind == 'item' || kind == 'npc_card') {
        final object = jsonDecode(text);
        if (object is! Map) return ['Expected a JSON object'];
        final fields = kind == 'simulator' ? ['name', 'description', 'opening', 'systemPrompt'] : kind == 'item' ? ['description', 'effect'] : ['name', 'description', 'roleCard', 'impression'];
        final issues = [for (final key in fields) if (object[key] is! String || (object[key] as String).trim().isEmpty) 'Missing nonempty string: $key'];
        if (kind == 'npc_card' && (object['affinity'] is! num || (object['affinity'] as num).abs() > 100)) issues.add('Invalid affinity');
        return issues;
      }
      if (kind == 'fanfic' && text.runes.length < 3000) return ['Fanfic shorter than production 3000-character target'];
      return [];
    } catch (_) {
      return ['Invalid JSON or production parser rejected the content'];
    }
  }

  static String mockReply(Map<String, dynamic> scenario, int index, Map<String, dynamic> gameplay) {
    if (index == 0) {
      switch (scenario['fault']) {
        case 'missing_simulator_fields': return '{"name":"旧城电台"}';
        case 'invalid_gameplay_json': return '{"variables":[';
        case 'short_fanfic': return '标题：雨夜修车\n陈放推开门，林夏还握着那把扳手。';
      }
    }
    switch (scenario['kind']) {
      case 'summary': return '玩家答应明早为林夏送备用电池，尚未兑现。\n陈放说北门可能封闭，但消息未证实。';
      case 'simulator': return jsonEncode({'name':'旧城电台','description':'涨潮时通话的旧城。','opening':'林夏把值班表递来，等你决定先检查哪里。','systemPrompt':'在潮汐通信世界中推进人物行动，玩家自行决定自己的选择。'});
      case 'gameplay': return jsonEncode(gameplay);
      case 'item': return '{"description":"铜铃内刻着站台标记。","effect":"摇响后可辨别同源铜铃的位置。"}';
      case 'npc_card': return '{"name":"陈放","description":"话少的修理师。","roleCard":"陈放遇事先检查工具再开口，只控制自己的行动，不代替玩家选择。","impression":"刚认识的送信人，还需要通过行动了解。","affinity":0}';
      case 'fanfic': return List.filled(260, '林夏把钥匙放到桌边，两人接着修好了松动的车链。').join();
      default:
        final mode = scenario['mode'];
        if (mode == 'group') return '[GROUP_CHAT]\n{"mode":"large_group_chat","messages":[{"id":"m1","speakerId":"npc-chen","speaker":"陈放","type":"npc","replyTo":"","content":"我去看北门。"},{"id":"m2","speakerId":"npc-lin","speaker":"林夏","type":"npc","replyTo":"m1","content":"我留在电台。"}]}\n[/GROUP_CHAT]\n$_stateBlock';
        if (mode == 'map') return '林夏指了指地图，北门是否封闭尚待确认。\n$_stateBlock\n[MAP_STATE]\n{"currentLocationId":"radio","locations":[{"id":"radio","name":"电台"}],"activeChoices":[]}\n[/MAP_STATE]';
        return '陈放放下工具，抬头听你说完。\n```html\n<div>电台值班记录</div>\n```\n$_stateBlock${mode == 'gameplay' ? '\n[THEATER_PATCH]\n{"ops":[]}\n[/THEATER_PATCH]' : ''}${mode == 'no_choices' ? '' : '\n[CHOICES]\nA|询问信号\nB|查看电池\nC|等待回复\nD|检查地图\nE|整理工具\nF|继续交谈\n[/CHOICES]'}';
    }
  }
}
