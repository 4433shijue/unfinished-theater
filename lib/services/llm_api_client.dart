import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../data/gameplay_system_prompt.dart';
import '../data/simulator_prompt_generator.dart';
import '../models/app_settings.dart';
import '../models/character_memory.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/game_state.dart';
import '../models/gameplay_system.dart';
import '../models/npc_profile.dart';
import '../models/prompt_cache.dart';
import '../models/simulator_prompt_request.dart';
import '../models/user_profile.dart';
import '../models/world_book.dart';
import '../utils/api_endpoint_resolver.dart';
import 'message_content_parser.dart';
import 'gameplay_system_parser.dart';
import 'token_estimator.dart';

class LlmApiException implements Exception {
  const LlmApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LlmRequestCancelledException extends LlmApiException {
  const LlmRequestCancelledException() : super('请求已取消。');
}

class LlmCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const LlmRequestCancelledException();
    }
  }
}

class PromptCacheUsage {
  const PromptCacheUsage({
    this.inputTokens,
    this.outputTokens,
    this.cachedInputTokens,
    this.cacheMissInputTokens,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? cachedInputTokens;
  final int? cacheMissInputTokens;

  bool get hasCacheData =>
      cachedInputTokens != null || cacheMissInputTokens != null;

  int? get cacheTotalTokens {
    if (!hasCacheData) {
      return null;
    }
    return (cachedInputTokens ?? 0) + (cacheMissInputTokens ?? 0);
  }

  int? get cacheHitRate {
    final total = cacheTotalTokens;
    if (total == null || total == 0) {
      return null;
    }
    return ((cachedInputTokens ?? 0) * 100 / total).round();
  }
}

class ChatStreamEvent {
  const ChatStreamEvent._({this.delta = '', this.usage});

  const ChatStreamEvent.delta(String delta)
      : this._(
          delta: delta,
        );

  const ChatStreamEvent.usage(PromptCacheUsage usage)
      : this._(
          usage: usage,
        );

  final String delta;
  final PromptCacheUsage? usage;
}

class LlmApiClient {
  LlmApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const int _mainChatMaxOutputTokens = 8192;

  final http.Client _client;

  void close() {
    _client.close();
  }

  bool prefersExactAssistantReplay(AppSettings settings) {
    final uri = ApiEndpointResolver.chatCompletions(
      settings.effectiveApiUrl.trim(),
      allowInsecureHttp: settings.allowInsecureMainApi,
    );
    return _isDeepSeekOfficialEndpoint(uri);
  }

  int promptTokenBudgetFor(AppSettings settings) {
    if (settings.promptTokenBudget > 0) {
      return settings.promptTokenBudget.clamp(4000, 500000);
    }
    // 自动预算统一为 64K，与 DeepSeek 官方接口一致：
    // 长对话的缓存收益更大。模型上下文偏小或中转站容易报错时，
    // 可在设置页手动选择更小的预算。
    return 64000;
  }

  String buildStablePrefixDigest({
    required CharacterProfile character,
    UserProfile? userProfile,
    List<NpcProfile> npcProfiles = const <NpcProfile>[],
    List<WorldBookEntry> worldBooks = const <WorldBookEntry>[],
  }) {
    final prefix = _buildStaticSystemPrompt(
      character,
      _stableAnchorWorldBooks(worldBooks),
      userProfile,
      npcProfiles,
    );
    return _stableDigest(prefix);
  }

  List<String> pendingMemorySummaryIds(
    List<CharacterMemorySummary> summaries,
    PromptCacheEpoch? epoch,
  ) {
    final injected =
        epoch?.injectedMemorySummaryIds.toSet() ?? const <String>{};
    return summaries
        .where(
          (summary) => !injected.contains(memorySummaryVersionKey(summary)),
        )
        .map(memorySummaryVersionKey)
        .toList(growable: false);
  }

  List<String> pendingWorldBookKeys(
    List<WorldBookEntry> entries,
    PromptCacheEpoch? epoch,
  ) {
    final injected = epoch?.injectedWorldBookKeys.toSet() ?? const <String>{};
    return _promptEnvelopeWorldBooks(entries)
        .map(worldBookVersionKey)
        .where((key) => !injected.contains(key))
        .toList(growable: false);
  }

  String worldBookVersionKey(WorldBookEntry entry) {
    return '${entry.id}:${_stableDigest(<String>[
      entry.title,
      entry.content,
      entry.triggerMode.name,
      entry.injectionPosition.name,
      entry.priority.toString(),
    ].join('\n'))}';
  }

  /// 记忆摘要的版本键：内容变化（编辑）后键会改变，
  /// 使已注入的旧键失效，warm 阶段也能把新内容重新注入。
  String memorySummaryVersionKey(CharacterMemorySummary summary) {
    return '${summary.id}:${_stableDigest(summary.summaryText.trim())}';
  }

  int estimateChatRequestTokens({
    required CharacterProfile character,
    GameStateSnapshot? gameState,
    UserProfile? userProfile,
    List<NpcProfile> npcProfiles = const <NpcProfile>[],
    List<WorldBookEntry> worldBooks = const <WorldBookEntry>[],
    String runtimeAddendum = '',
    required List<ChatMessage> contextMessages,
    required List<CharacterMemorySummary> memorySummaries,
    PromptCacheEpoch? promptCacheEpoch,
    bool preferExactAssistantReplay = false,
  }) {
    final messages = _buildRequestMessages(
      character: character,
      gameState: gameState,
      userProfile: userProfile,
      npcProfiles: npcProfiles,
      worldBooks: worldBooks,
      contextMessages: contextMessages,
      runtimeAddendum: runtimeAddendum,
      memorySummaries: memorySummaries,
      promptCacheEpoch: promptCacheEpoch,
      preferExactAssistantReplay: preferExactAssistantReplay,
    );
    var total = 0;
    for (final message in messages) {
      total += 4;
      total += TokenEstimator.estimateText(message['role'] ?? '');
      total += TokenEstimator.estimateText(message['content'] ?? '');
    }
    return total + 3;
  }

  Future<String> sendChat({
    required AppSettings settings,
    required CharacterProfile character,
    GameStateSnapshot? gameState,
    UserProfile? userProfile,
    List<NpcProfile> npcProfiles = const <NpcProfile>[],
    List<WorldBookEntry> worldBooks = const <WorldBookEntry>[],
    String runtimeAddendum = '',
    required List<ChatMessage> contextMessages,
    required List<CharacterMemorySummary> memorySummaries,
    PromptCacheEpoch? promptCacheEpoch,
  }) async {
    final uri = ApiEndpointResolver.chatCompletions(
      settings.effectiveApiUrl.trim(),
      allowInsecureHttp: settings.allowInsecureMainApi,
    );
    final requestMessages = _buildRequestMessages(
      character: character,
      gameState: gameState,
      userProfile: userProfile,
      npcProfiles: npcProfiles,
      worldBooks: worldBooks,
      contextMessages: contextMessages,
      runtimeAddendum: runtimeAddendum,
      memorySummaries: memorySummaries,
      promptCacheEpoch: promptCacheEpoch,
      preferExactAssistantReplay: _isDeepSeekOfficialEndpoint(uri),
    );

    return _postChatCompletion(
      settings: settings,
      messages: requestMessages,
      temperature: character.modelParams.temperature,
      topP: character.modelParams.topP,
      maxTokens: _mainChatMaxOutputTokens,
    );
  }

  Stream<String> streamChat({
    required AppSettings settings,
    required CharacterProfile character,
    GameStateSnapshot? gameState,
    UserProfile? userProfile,
    List<NpcProfile> npcProfiles = const <NpcProfile>[],
    List<WorldBookEntry> worldBooks = const <WorldBookEntry>[],
    String runtimeAddendum = '',
    required List<ChatMessage> contextMessages,
    required List<CharacterMemorySummary> memorySummaries,
    PromptCacheEpoch? promptCacheEpoch,
    LlmCancellationToken? cancellationToken,
  }) {
    return streamChatEvents(
      settings: settings,
      character: character,
      gameState: gameState,
      userProfile: userProfile,
      npcProfiles: npcProfiles,
      worldBooks: worldBooks,
      runtimeAddendum: runtimeAddendum,
      contextMessages: contextMessages,
      memorySummaries: memorySummaries,
      promptCacheEpoch: promptCacheEpoch,
      cancellationToken: cancellationToken,
    ).where((event) => event.delta.isNotEmpty).map((event) => event.delta);
  }

  Stream<ChatStreamEvent> streamChatEvents({
    required AppSettings settings,
    required CharacterProfile character,
    GameStateSnapshot? gameState,
    UserProfile? userProfile,
    List<NpcProfile> npcProfiles = const <NpcProfile>[],
    List<WorldBookEntry> worldBooks = const <WorldBookEntry>[],
    String runtimeAddendum = '',
    required List<ChatMessage> contextMessages,
    required List<CharacterMemorySummary> memorySummaries,
    PromptCacheEpoch? promptCacheEpoch,
    LlmCancellationToken? cancellationToken,
  }) async* {
    cancellationToken?.throwIfCancelled();
    final requestStartedAt = DateTime.now();
    final uri = ApiEndpointResolver.chatCompletions(
      settings.effectiveApiUrl.trim(),
      allowInsecureHttp: settings.allowInsecureMainApi,
    );
    final includeUsage =
        settings.includeStreamUsage || _isDeepSeekOfficialEndpoint(uri);
    final preferExactAssistantReplay = _isDeepSeekOfficialEndpoint(uri);
    final payload = <String, dynamic>{
      'model': settings.effectiveModelName.trim(),
      'messages': _buildRequestMessages(
        character: character,
        gameState: gameState,
        userProfile: userProfile,
        npcProfiles: npcProfiles,
        worldBooks: worldBooks,
        contextMessages: contextMessages,
        runtimeAddendum: runtimeAddendum,
        memorySummaries: memorySummaries,
        promptCacheEpoch: promptCacheEpoch,
        preferExactAssistantReplay: preferExactAssistantReplay,
      ),
      'temperature': character.modelParams.temperature,
      'top_p': character.modelParams.topP,
      'max_tokens': _mainChatMaxOutputTokens,
      'stream': true,
      if (includeUsage)
        'stream_options': const <String, dynamic>{
          'include_usage': true,
        },
    };
    _addProviderRequestFields(payload, settings: settings, uri: uri);

    final http.Request request = (cancellationToken == null
        ? http.Request('POST', uri)
        : http.AbortableRequest(
            'POST',
            uri,
            abortTrigger: cancellationToken.whenCancelled,
          ))
      ..headers.addAll(_buildHeaders(settings))
      ..body = jsonEncode(payload);

    late http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(
            _effectiveTimeout(settings),
          );
    } on http.RequestAbortedException {
      throw const LlmRequestCancelledException();
    } catch (error) {
      throw LlmApiException('请求失败：$error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      dynamic decoded;
      try {
        decoded = jsonDecode(errorBody);
      } catch (_) {
        decoded = null;
      }

      throw LlmApiException(
        _extractErrorMessage(decoded) ??
            '接口返回错误：${response.statusCode} ${response.reasonPhrase ?? ''}'
                .trim(),
      );
    }

    final lineStream =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    try {
      await for (final rawLine in lineStream.timeout(
        _effectiveTimeout(settings),
      )) {
        cancellationToken?.throwIfCancelled();
        final payloadText = _ssePayload(rawLine);
        if (payloadText == null) {
          continue;
        }
        if (payloadText.isEmpty) {
          continue;
        }

        if (payloadText == '[DONE]') {
          break;
        }

        dynamic decoded;
        try {
          decoded = jsonDecode(payloadText);
        } catch (_) {
          continue;
        }

        final usage = _extractPromptCacheUsage(decoded);
        if (usage != null) {
          _logPromptCacheUsage(
            usage,
            startedAt: requestStartedAt,
            model: settings.effectiveModelName.trim(),
            requestType: 'chat_stream',
          );
          yield ChatStreamEvent.usage(usage);
        }

        final delta = _extractDeltaContent(decoded);
        if (delta.isNotEmpty) {
          yield ChatStreamEvent.delta(delta);
        }
      }
    } on http.RequestAbortedException {
      throw const LlmRequestCancelledException();
    } on TimeoutException {
      throw const LlmApiException('流式响应超时，请检查接口速度或适当调大请求超时。');
    }
  }

  Future<String> summarizeConversation({
    required AppSettings settings,
    required CharacterProfile character,
    required List<ChatMessage> messages,
  }) async {
    final transcript = messages.map((message) {
      final speaker = message.role == ChatRole.user ? '用户' : character.name;
      return '$speaker: ${message.content}';
    }).join('\n');

    return _postChatCompletion(
      settings: settings,
      messages: <Map<String, String>>[
        {
          'role': 'system',
          'content':
              '你是一个长期记忆整理助手。请提炼对未来对话有帮助的事实上下文，输出 1-3 条简洁要点，不要添加编号，不要复述无意义寒暄。',
        },
        {
          'role': 'user',
          'content': '角色设定：${character.prompt}\n\n请总结以下对话：\n$transcript',
        },
      ],
      temperature: 0.2,
      topP: 0.8,
    );
  }

  Future<List<String>> fetchModels({
    required AppSettings settings,
  }) async {
    final decoded = await _getJson(
      uri: ApiEndpointResolver.models(
        settings.effectiveApiUrl.trim(),
        allowInsecureHttp: settings.allowInsecureMainApi,
      ),
      settings: settings,
    );

    if (decoded is! Map) {
      throw const LlmApiException('模型列表返回格式不正确。');
    }

    final data = decoded['data'];
    if (data is! List) {
      throw const LlmApiException('模型列表中没有找到 data 字段。');
    }

    final models = data
        .whereType<Map>()
        .map((item) => item['id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (models.isEmpty) {
      throw const LlmApiException('接口返回成功，但没有可用模型。');
    }

    return models;
  }

  Future<SimulatorPromptGenerationResult> generateSimulatorPrompt({
    required AppSettings settings,
    required SimulatorPromptGenerationRequest request,
    void Function(String partial)? onChunk,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in streamUtilityTask(
      settings: settings,
      systemPrompt: simulatorPromptGeneratorSystemPrompt,
      userPrompt: buildSimulatorPromptGeneratorUserPrompt(request),
      temperature: 0.7,
      topP: 0.9,
    )) {
      buffer.write(chunk);
      onChunk?.call(buffer.toString());
    }

    var combined = buffer.toString();
    var parsed = _parseSimulatorJson(combined);

    // JSON 解析失败（截断、缺字段、格式损坏）时自动续写一次，
    // 续写结果按 key 合并，不会让用户只拿到半份提示词。
    if (parsed == null) {
      final continuation = StringBuffer();
      try {
        await for (final chunk in streamUtilityTask(
          settings: settings,
          systemPrompt: simulatorPromptGeneratorSystemPrompt,
          userPrompt: _buildSimulatorJsonContinuationPrompt(combined),
          temperature: 0.5,
          topP: 0.9,
        )) {
          continuation.write(chunk);
        }
      } catch (_) {
        // 续写失败不阻塞主流程，保留已生成的部分。
      }
      final continued = continuation.toString().trim();
      if (continued.isNotEmpty) {
        final merged = _mergeSimulatorJson(combined, continued);
        if (merged != null) {
          combined = merged;
          parsed = _parseSimulatorJson(merged);
          onChunk?.call(merged);
        }
      }
    }

    if (parsed != null) {
      return SimulatorPromptGenerationResult(
        name: parsed.name,
        prompt: parsed.systemPrompt,
        openingMessage: parsed.opening,
        description: request.shortDescription.trim().isNotEmpty
            ? request.shortDescription.trim()
            : parsed.description,
      );
    }

    // 老式标签兜底：兼容按「模拟器名称：…」格式输出的旧模型。
    final normalized = _normalizeGeneratedPrompt(combined);
    final generatedDescription = _extractGeneratedSectionFromEnd(
      normalized,
      const <String>['一句话简介', '简介'],
    );
    final generatedOpening =
        _extractGeneratedSectionFromEnd(normalized, const <String>['开场白']);
    final generatedSystemPrompt = _extractGeneratedSectionFromEnd(
      normalized,
      const <String>['系统提示词', '完整系统提示词', '提示词正文'],
    );
    final generatedName =
        _extractGeneratedSectionFromEnd(normalized, const <String>['模拟器名称']);

    return SimulatorPromptGenerationResult(
      name: generatedName ?? '',
      prompt: _composeGeneratedPrompt(
        generatedName: generatedName,
        generatedSystemPrompt: generatedSystemPrompt,
        fallback: normalized,
      ),
      openingMessage: generatedOpening ?? '',
      description: request.shortDescription.trim().isNotEmpty
          ? request.shortDescription.trim()
          : (generatedDescription ?? request.simulatorIdea.trim()),
    );
  }

  /// 尝试把模型输出解析成 {name, description, opening, systemPrompt}。
  /// 兼容 ```json 围栏和前后多余文本；字段缺失视为解析失败。
  ({String name, String description, String opening, String systemPrompt})?
      _parseSimulatorJson(String raw) {
    final map = _decodeSimulatorJsonMap(raw);
    if (map == null) {
      return null;
    }
    final name = map['name']?.toString().trim() ?? '';
    final description = map['description']?.toString().trim() ?? '';
    final opening = map['opening']?.toString().trim() ?? '';
    final systemPrompt =
        (map['systemPrompt']?.toString().trim() ?? '').isNotEmpty
            ? map['systemPrompt'].toString().trim()
            : (map['system_prompt']?.toString().trim() ?? '').isNotEmpty
                ? map['system_prompt'].toString().trim()
                : (map['prompt']?.toString().trim() ?? '');
    if (name.isEmpty &&
        description.isEmpty &&
        opening.isEmpty &&
        systemPrompt.isEmpty) {
      return null;
    }
    return (
      name: name,
      description: description,
      opening: opening,
      systemPrompt: systemPrompt,
    );
  }

  Map<String, dynamic>? _decodeSimulatorJsonMap(String raw) {
    final cleaned = _stripCodeFences(raw.trim());
    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          decoded = jsonDecode(cleaned.substring(start, end + 1));
        } catch (_) {
          decoded = null;
        }
      }
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  String _stripCodeFences(String value) {
    var next = value.trim();
    if (next.startsWith('```')) {
      final firstLineBreak = next.indexOf('\n');
      if (firstLineBreak >= 0) {
        next = next.substring(firstLineBreak + 1);
      }
    }
    if (next.endsWith('```')) {
      next = next.substring(0, next.length - 3);
    }
    return next.trim();
  }

  String _buildSimulatorJsonContinuationPrompt(String partial) {
    return '''
上一轮返回的不是完整 JSON（缺少字段、被截断或格式损坏）。
请基于已有内容补全，只输出一个完整可解析的 JSON 对象，键名固定为：
{"name": "...", "description": "...", "opening": "...", "systemPrompt": "..."}
不要重复拼凑无意义文本，不要解释，不要 Markdown 围栏。

【已有内容】
$partial
''';
  }

  /// 按 key 合并两段 JSON：续写结果里非空的字段覆盖原文，
  /// 原文保留续写没给到的字段。任一结果都无法解析时返回 null。
  String? _mergeSimulatorJson(String original, String continuation) {
    final originalMap = _decodeSimulatorJsonMap(original);
    final continuationMap = _decodeSimulatorJsonMap(continuation);
    if (continuationMap == null || continuationMap.isEmpty) {
      return null;
    }
    final merged = <String, dynamic>{
      if (originalMap != null) ...originalMap,
      ...continuationMap,
    };
    return jsonEncode(merged);
  }

  Future<GameplaySystem> generateGameplaySystem({
    required AppSettings settings,
    required CharacterProfile character,
  }) async {
    final raw = await _postChatCompletion(
      settings: settings,
      requestType: 'gameplay_system',
      messages: <Map<String, String>>[
        const <String, String>{
          'role': 'system',
          'content': gameplaySystemGeneratorPrompt,
        },
        <String, String>{
          'role': 'user',
          'content': buildGameplaySystemGeneratorUserPrompt(character),
        },
      ],
      temperature: 0.55,
      topP: 0.9,
      maxTokens: 8192,
    );
    try {
      return GameplaySystemParser.parse(raw);
    } on FormatException catch (firstError) {
      // 解析失败兜底：带原始输出自动修复一次；仍失败时把错误和原文
      // 片段一起抛出，用户至少知道模型生成了什么。
      final repaired = await _repairGameplaySystemJson(
        settings: settings,
        raw: raw,
        parseError: firstError,
      );
      try {
        return GameplaySystemParser.parse(repaired);
      } on FormatException catch (secondError) {
        throw FormatException(
          '${secondError.message}（模型原始输出开头：${_clipPromptSnippet(repaired)}）',
        );
      }
    }
  }

  Future<String> _repairGameplaySystemJson({
    required AppSettings settings,
    required String raw,
    required FormatException parseError,
  }) async {
    try {
      return await runUtilityTask(
        settings: settings,
        systemPrompt: '你是 App 的 JSON 修复器。用户会给你一段 AI 生成的玩法系统 JSON 文本和解析错误。'
            '请修复格式问题（截断的引号、多余的逗号、围栏等），只输出一个可解析的 JSON 对象，'
            '不要输出任何解释或 Markdown 围栏。',
        userPrompt: '【解析错误】${parseError.message}\n\n【原始输出】\n$raw',
        temperature: 0.15,
        topP: 0.8,
        maxTokens: 8192,
      );
    } catch (_) {
      // 修复请求本身失败时退回原文，让外层解析逻辑统一处理。
      return raw;
    }
  }

  String _clipPromptSnippet(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 160) {
      return normalized;
    }
    return '${normalized.substring(0, 160)}…';
  }

  Future<String> runUtilityTask({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.45,
    double topP = 0.9,
    int maxTokens = 8192,
    LlmCancellationToken? cancellationToken,
  }) {
    return _postChatCompletion(
      settings: settings,
      requestType: 'utility',
      messages: <Map<String, String>>[
        <String, String>{
          'role': 'system',
          'content': systemPrompt,
        },
        <String, String>{
          'role': 'user',
          'content': userPrompt,
        },
      ],
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      cancellationToken: cancellationToken,
    );
  }

  /// 流式版工具调用：长文本生成（帮你写、角色卡、同人文）逐字返回，
  /// 中途截断也能看到已生成的部分。
  Stream<String> streamUtilityTask({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.45,
    double topP = 0.9,
    int maxTokens = 8192,
  }) {
    return streamContent(
      settings: settings,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
    );
  }

  Future<String> repairChatReplyFormat({
    required AppSettings settings,
    required CharacterProfile character,
    required String originalReply,
    required String latestUserMessage,
    GameStateSnapshot? gameState,
    LlmCancellationToken? cancellationToken,
  }) {
    return _postChatCompletion(
      settings: settings,
      requestType: 'format_repair',
      messages: <Map<String, String>>[
        <String, String>{
          'role': 'system',
          'content': _buildRepairSystemPrompt(character),
        },
        <String, String>{
          'role': 'user',
          'content': _buildRepairUserPrompt(
            character: character,
            originalReply: originalReply,
            latestUserMessage: latestUserMessage,
            gameState: gameState,
          ),
        },
      ],
      temperature: 0.15,
      topP: 0.8,
      cancellationToken: cancellationToken,
    );
  }

  String _buildRepairSystemPrompt(CharacterProfile character) {
    if (character.largeGroupChatModeEnabled) {
      return _buildLargeGroupChatRepairSystemPrompt(
        gameplayPatchRequired: character.gameplaySystem != null,
      );
    }

    final lastChoice = String.fromCharCode(
      64 + character.preferredChoiceCount,
    );
    final choicesInstruction = character.nextStepOptionsEnabled
        ? '最后必须输出一个 [CHOICES] 选项块，正好 ${character.preferredChoiceCount} 行：A|行动文本 到 $lastChoice|行动文本。'
        : '当前角色关闭下一步选项，禁止输出 [CHOICES]。';
    final htmlInstruction = character.requiresHtmlPanel
        ? '2. 至少有一个完整 ```html 代码块```；如果原文没有 HTML，补一个简短状态卡。'
        : '2. HTML 资料卡为可选项；原文没有时不要为了格式强行补充。';
    final gameplayInstruction = character.gameplaySystem == null
        ? ''
        : '''
6. 必须保留或补齐独立 [THEATER_PATCH] JSON 块，并放在 [GAME_STATE] 之后、[CHOICES] 之前。逐项核对原回复事实与变量更新条件；已触发的变化必须写入 ops，确实没有变化时才输出 {"ops":[]}，不得凭空编造变化。''';

    return '''
你是 App 回复格式修复器，只修复格式，不改剧情事实，不继续扩写新剧情。
输出必须保留原回复已有的正文、HTML 和设定信息；若原回复缺少结构，只补齐缺失结构。

必须满足：
1. 至少保留一段用户可读正文。
$htmlInstruction
3. 必须输出独立 [GAME_STATE] 状态块，且 [GAME_STATE] 不得写进 HTML、Markdown 代码块、[BUBBLE] 或选项文本。
4. [GAME_STATE] 至少包含：时间、地点、状态、当前任务、人物数据、关系网、剧情记录、NPC变化、NPC更新。
5. NPC变化只写状态面板可读变化；NPC更新使用「npcId：已建档 NPC 的稳定 ID｜名字：...｜简介：...｜好感变化：-12 到 12｜印象：...｜生命周期：active/away/missing/dead/archived｜生命周期原因：...｜主动消息：本轮真实发出的私聊原话」。已有 NPC 只写好感增量，不得重写绝对好感；没有真实私聊时主动消息留空。“等待回复、明日将联系、计划表白”等状态不是消息。
${gameplayInstruction.trim()}
7. $choicesInstruction

只输出修复后的完整回复，不要解释修复过程。''';
  }

  String _buildLargeGroupChatRepairSystemPrompt({
    required bool gameplayPatchRequired,
  }) {
    final gameplayInstruction = gameplayPatchRequired
        ? '3. 必须保留或补齐独立 [THEATER_PATCH] JSON 块；逐项核对原回复事实，已触发的变化必须写入 ops，确实没有变化时才输出 {"ops":[]}。'
        : '';
    return '''
你是 App 大型群聊模式回复格式修复器，只修复格式，不改剧情事实，不继续扩写新剧情。

必须满足：
1. 输出只包含 [GROUP_CHAT] JSON 块、[GAME_STATE] 状态块${gameplayPatchRequired ? '和 [THEATER_PATCH] 变量补丁' : ''}，不要输出 HTML、Markdown 代码块、[BUBBLE]、[CHOICES] 或 [MAP_STATE]。
2. [GROUP_CHAT] 必须是可解析 JSON，格式为 {"mode":"large_group_chat","messages":[...]}。
$gameplayInstruction
3. 保留原文已经发生的消息数量，不要仅为凑数扩写剧情；过渡场景允许 2-4 条，普通交流 4-7 条，高潮场景 8-12 条。
4. 每条消息必须包含 id、type、speakerId、speaker、replyTo、content。旧回复缺少可推断字段时可以补齐，但不得改变台词事实。
5. type 只能是 narration 或 npc；旁白 speaker 固定为「旁白」。
6. 旁白 content 只保留动作、环境、神态、心理、沉默和剧情推进；如果旁白里出现「角色名：台词」或引号台词，必须拆成对应 NPC 气泡。
7. NPC 气泡只能保留台词；动作、神态、心理、环境、括号动作和剧情推进都必须转入旁白气泡。
8. NPC content 不能包含「他说/她说/笑了笑/低头/转身/（沉默）」等叙述，只保留角色亲口说的话。
9. [GAME_STATE] 至少包含：时间、地点、状态、当前任务、人物数据、关系网、剧情记录、NPC变化、NPC更新。
10. [GAME_STATE] 的 NPC更新只记录本轮正文中实际发生的私聊；使用稳定 npcId 和好感变化，不得重复写绝对好感。定时主动私聊由 App 在回合提交后独立调度。

只输出修复后的完整回复，不要解释修复过程。''';
  }

  String _buildRepairUserPrompt({
    required CharacterProfile character,
    required String originalReply,
    required String latestUserMessage,
    GameStateSnapshot? gameState,
  }) {
    final stateText = gameState != null && !gameState.isEmpty
        ? _formatGameState(gameState)
        : '';
    final gameplayContext = _buildGameplayRepairContext(
      character,
      gameState,
    );

    return '''
【最近用户输入】
$latestUserMessage

${stateText.isEmpty ? '' : '【修复时可参考的上一轮状态】\n$stateText\n'}
${gameplayContext.isEmpty ? '' : '$gameplayContext\n'}
【需要修复格式的模型原始回复】
$originalReply
''';
  }

  String _buildGameplayRepairContext(
    CharacterProfile character,
    GameStateSnapshot? gameState,
  ) {
    final system = character.gameplaySystem;
    if (system == null) {
      return '';
    }
    final currentValues =
        gameState?.customVariables ?? const <String, dynamic>{};
    final visibleVariables = system.variables.where(
      (variable) => variable.visibility != GameplayVariableVisibility.engine,
    );
    final buffer = StringBuffer()
      ..writeln('【玩法变量补丁修复上下文】')
      ..writeln('只根据原始回复中已经发生的事实判断变量变化，不得新增剧情。')
      ..writeln('若某个变量的更新条件已被本轮事实触发，必须输出对应操作；只有确实没有变化时才输出 {"ops":[]}。')
      ..writeln('可用变量：');
    for (final variable in visibleVariables) {
      final currentValue = variable.normalizeValue(
        currentValues.containsKey(variable.key)
            ? currentValues[variable.key]
            : variable.initialValue,
      );
      buffer.writeln(
        '- ${variable.key} = ${jsonEncode(currentValue)}｜authority=${variable.authority.name}｜type=${variable.type.name}｜maxDelta=${variable.maxDelta ?? '无'}｜${variable.description}',
      );
    }
    buffer
      ..writeln('只允许修改 authority=ai 的已声明路径。')
      ..writeln('操作只允许 set、inc、append、remove。');
    return buffer.toString().trim();
  }

  Future<void> testConnection({
    required AppSettings settings,
  }) async {
    if (settings.effectiveModelName.trim().isEmpty) {
      throw const LlmApiException('测试连接前请先填写模型名称。');
    }

    await _postJson(
      uri: ApiEndpointResolver.chatCompletions(
        settings.effectiveApiUrl.trim(),
        allowInsecureHttp: settings.allowInsecureMainApi,
      ),
      settings: settings,
      payload: <String, dynamic>{
        'model': settings.effectiveModelName.trim(),
        'messages': const <Map<String, String>>[
          {
            'role': 'user',
            'content': 'ping',
          },
        ],
        'temperature': 0,
        'top_p': 1,
        'max_tokens': 1,
      },
    );
  }

  List<Map<String, String>> _buildRequestMessages({
    required CharacterProfile character,
    GameStateSnapshot? gameState,
    UserProfile? userProfile,
    required List<NpcProfile> npcProfiles,
    required List<WorldBookEntry> worldBooks,
    required List<ChatMessage> contextMessages,
    String runtimeAddendum = '',
    required List<CharacterMemorySummary> memorySummaries,
    PromptCacheEpoch? promptCacheEpoch,
    bool preferExactAssistantReplay = false,
  }) {
    final stableWorldBooks = _stableAnchorWorldBooks(worldBooks);
    final dynamicWorldBooks = _promptEnvelopeWorldBooks(worldBooks);
    final staticPrefix = _buildStaticSystemPrompt(
      character,
      stableWorldBooks,
      userProfile,
      npcProfiles,
    );
    final currentEnvelope = _buildPromptEnvelope(
      character,
      gameState,
      userProfile,
      memorySummaries,
      npcProfiles,
      dynamicWorldBooks,
      runtimeAddendum,
      contextMessages,
      promptCacheEpoch,
    );
    var currentEnvelopeUsed = false;
    return <Map<String, String>>[
      {
        'role': 'system',
        'content': staticPrefix,
      },
      for (var index = 0; index < contextMessages.length; index += 1)
        <String, String>{
          'role': contextMessages[index].role.name,
          'content': _contextMessageContentForRequest(
            contextMessages[index],
            isLatestUserMessage: _isLatestUserMessage(contextMessages, index),
            currentEnvelope: currentEnvelope,
            useCurrentEnvelope: () => currentEnvelopeUsed = true,
            preferExactAssistantReplay: preferExactAssistantReplay,
          ),
        },
      if (!currentEnvelopeUsed && currentEnvelope.trim().isNotEmpty)
        <String, String>{
          'role': 'user',
          'content': currentEnvelope,
        },
    ];
  }

  bool _isLatestUserMessage(List<ChatMessage> messages, int index) {
    if (messages[index].role != ChatRole.user) {
      return false;
    }
    for (var cursor = index + 1; cursor < messages.length; cursor += 1) {
      if (messages[cursor].role == ChatRole.user) {
        return false;
      }
    }
    return true;
  }

  String _contextMessageContentForRequest(
    ChatMessage message, {
    required bool isLatestUserMessage,
    required String currentEnvelope,
    required void Function() useCurrentEnvelope,
    required bool preferExactAssistantReplay,
  }) {
    final trimmed = message.content.trim();
    if (message.role == ChatRole.assistant &&
        preferExactAssistantReplay &&
        message.providerReplayExact) {
      final providerReplay = message.providerReplayContent;
      if (providerReplay != null && providerReplay.isNotEmpty) {
        return providerReplay;
      }
    }
    final replay = message.promptReplayContent?.trim();
    if (replay != null && replay.isNotEmpty) {
      if (isLatestUserMessage) {
        useCurrentEnvelope();
      }
      return replay;
    }
    if (message.role != ChatRole.assistant) {
      if (isLatestUserMessage && currentEnvelope.trim().isNotEmpty) {
        useCurrentEnvelope();
        return _mergeEnvelopeWithUserContent(currentEnvelope, trimmed);
      }
      return trimmed;
    }
    final replayPrefix = MessageContentParser.assistantReplayPrefixForModel(
      trimmed,
    );
    final sanitized = replayPrefix.isNotEmpty
        ? replayPrefix
        : MessageContentParser.contextTextForModel(trimmed);
    if (sanitized.isNotEmpty) {
      return sanitized;
    }
    return '（上一条回复主要是结构化状态或可视化面板，已由 App 本地保存。）';
  }

  String buildUserPromptReplayContent({
    required CharacterProfile character,
    GameStateSnapshot? gameState,
    UserProfile? userProfile,
    List<NpcProfile> npcProfiles = const <NpcProfile>[],
    List<WorldBookEntry> worldBooks = const <WorldBookEntry>[],
    String runtimeAddendum = '',
    List<ChatMessage> contextMessages = const <ChatMessage>[],
    required List<CharacterMemorySummary> memorySummaries,
    required String userContent,
    PromptCacheEpoch? promptCacheEpoch,
  }) {
    final dynamicWorldBooks = _promptEnvelopeWorldBooks(worldBooks);
    final envelope = _buildPromptEnvelope(
      character,
      gameState,
      userProfile,
      memorySummaries,
      npcProfiles,
      dynamicWorldBooks,
      runtimeAddendum,
      contextMessages,
      promptCacheEpoch,
    );
    return _mergeEnvelopeWithUserContent(envelope, userContent);
  }

  String buildAssistantPromptReplayContent(String content) {
    return MessageContentParser.assistantReplayPrefixForModel(content);
  }

  List<WorldBookEntry> _stableAnchorWorldBooks(List<WorldBookEntry> entries) {
    return entries
        .where((entry) =>
            entry.triggerMode == WorldBookTriggerMode.always &&
            entry.injectionPosition != WorldBookInjectionPosition.rear)
        .toList(growable: false);
  }

  List<WorldBookEntry> _promptEnvelopeWorldBooks(List<WorldBookEntry> entries) {
    return entries
        .where((entry) =>
            entry.triggerMode != WorldBookTriggerMode.always ||
            entry.injectionPosition == WorldBookInjectionPosition.rear)
        .toList(growable: false);
  }

  String _mergeEnvelopeWithUserContent(String envelope, String userContent) {
    final trimmedEnvelope = envelope.trim();
    final trimmedUserContent = userContent.trim();
    if (trimmedEnvelope.isEmpty) {
      return trimmedUserContent;
    }
    if (trimmedUserContent.isEmpty) {
      return trimmedEnvelope;
    }
    return '$trimmedEnvelope\n\n【用户本轮输入】\n$trimmedUserContent';
  }

  Future<String> _postChatCompletion({
    required AppSettings settings,
    String requestType = 'chat',
    required List<Map<String, String>> messages,
    required double temperature,
    required double topP,
    int? maxTokens,
    LlmCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final requestStartedAt = DateTime.now();
    final payload = <String, dynamic>{
      'model': settings.effectiveModelName.trim(),
      'messages': messages,
      'temperature': temperature,
      'top_p': topP,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };

    final decoded = await _postJson(
      uri: ApiEndpointResolver.chatCompletions(
        settings.effectiveApiUrl.trim(),
        allowInsecureHttp: settings.allowInsecureMainApi,
      ),
      settings: settings,
      payload: payload,
      cancellationToken: cancellationToken,
    );

    _logPromptCacheUsage(
      _extractPromptCacheUsage(decoded),
      startedAt: requestStartedAt,
      model: settings.effectiveModelName.trim(),
      requestType: requestType,
    );

    final content = _extractMessageContent(decoded);
    if (content.isEmpty) {
      throw const LlmApiException('模型返回了空内容。');
    }

    return content;
  }

  Future<dynamic> _postJson({
    required Uri uri,
    required AppSettings settings,
    required Map<String, dynamic> payload,
    LlmCancellationToken? cancellationToken,
  }) {
    final providerPayload = Map<String, dynamic>.from(payload);
    _addProviderRequestFields(
      providerPayload,
      settings: settings,
      uri: uri,
    );
    if (cancellationToken != null) {
      return _sendAbortablePost(
        uri: uri,
        settings: settings,
        payload: providerPayload,
        cancellationToken: cancellationToken,
      );
    }
    return _sendRequest(
      settings: settings,
      request: () => _client.post(
        uri,
        headers: _buildHeaders(settings),
        body: jsonEncode(providerPayload),
      ),
    );
  }

  Future<dynamic> _sendAbortablePost({
    required Uri uri,
    required AppSettings settings,
    required Map<String, dynamic> payload,
    required LlmCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final request = http.AbortableRequest(
      'POST',
      uri,
      abortTrigger: cancellationToken.whenCancelled,
    )
      ..headers.addAll(_buildHeaders(settings))
      ..body = jsonEncode(payload);

    late http.Response response;
    try {
      final streamed = await _client.send(request).timeout(
            _effectiveTimeout(settings),
          );
      response = await http.Response.fromStream(streamed).timeout(
            _effectiveTimeout(settings),
          );
      cancellationToken.throwIfCancelled();
    } on http.RequestAbortedException {
      throw const LlmRequestCancelledException();
    } on LlmRequestCancelledException {
      rethrow;
    } catch (error) {
      throw LlmApiException('请求失败：$error');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmApiException(
        _extractErrorMessage(decoded) ??
            '接口返回错误：${response.statusCode} ${response.reasonPhrase ?? ''}'
                .trim(),
      );
    }
    return decoded;
  }

  Future<dynamic> _getJson({
    required Uri uri,
    required AppSettings settings,
  }) {
    return _sendRequest(
      settings: settings,
      request: () => _client.get(
        uri,
        headers: _buildHeaders(settings),
      ),
    );
  }

  Future<dynamic> _sendRequest({
    required AppSettings settings,
    required Future<http.Response> Function() request,
  }) async {
    late http.Response response;
    try {
      response = await request().timeout(
        _effectiveTimeout(settings),
      );
    } catch (error) {
      throw LlmApiException('请求失败：$error');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmApiException(
        _extractErrorMessage(decoded) ??
            '接口返回错误：${response.statusCode} ${response.reasonPhrase ?? ''}'
                .trim(),
      );
    }

    return decoded;
  }

  Stream<String> streamContent({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    double topP = 0.9,
    int maxTokens = 4096,
  }) async* {
    final requestStartedAt = DateTime.now();
    final uri = ApiEndpointResolver.chatCompletions(
      settings.effectiveApiUrl.trim(),
      allowInsecureHttp: settings.allowInsecureMainApi,
    );
    final includeUsage =
        settings.includeStreamUsage || _isDeepSeekOfficialEndpoint(uri);
    final payload = <String, dynamic>{
      'model': settings.effectiveModelName.trim(),
      'messages': <Map<String, String>>[
        <String, String>{'role': 'system', 'content': systemPrompt},
        <String, String>{'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxTokens,
      'stream': true,
      if (includeUsage)
        'stream_options': const <String, dynamic>{
          'include_usage': true,
        },
    };
    _addProviderRequestFields(payload, settings: settings, uri: uri);

    final headers = _buildHeaders(settings);
    final request = http.Request('POST', uri);
    request.headers.addAll(headers);
    request.body = jsonEncode(payload);

    late http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request).timeout(
            _effectiveTimeout(settings),
          );
    } on TimeoutException {
      throw const LlmApiException('连接接口超时，请检查网络或调大请求超时。');
    } catch (error) {
      throw LlmApiException('请求失败：$error');
    }
    _checkStatus(streamedResponse);

    try {
      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(_effectiveTimeout(settings))) {
        final data = _ssePayload(chunk);
        if (data == null || data.isEmpty) {
          continue;
        }
        if (data == '[DONE]') {
          break;
        }
        try {
          final decoded = jsonDecode(data);
          final usage = _extractPromptCacheUsage(decoded);
          if (usage != null) {
            _logPromptCacheUsage(
              usage,
              startedAt: requestStartedAt,
              model: settings.effectiveModelName.trim(),
              requestType: 'content_stream',
            );
          }
          final choices = decoded['choices'];
          if (choices is List && choices.isNotEmpty) {
            final delta = choices[0]['delta'];
            if (delta is Map) {
              final content = delta['content'];
              if (content is String && content.isNotEmpty) {
                yield content;
              }
            }
          }
        } catch (_) {
          // Skip malformed chunks.
        }
      }
    } on TimeoutException {
      throw const LlmApiException('流式响应超时，请检查接口速度或适当调大请求超时。');
    }
  }

  void _checkStatus(http.StreamedResponse response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const LlmApiException('API 认证失败，请检查 API Key 是否有效。');
    }

    if (response.statusCode == 429) {
      throw const LlmApiException('请求过于频繁，请稍后再试。');
    }

    throw LlmApiException('API 请求失败（${response.statusCode}）。');
  }

  Map<String, String> _buildHeaders(AppSettings settings) {
    return <String, String>{
      'Content-Type': 'application/json',
      if (settings.effectiveApiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${settings.effectiveApiKey.trim()}',
    };
  }

  Duration _effectiveTimeout(AppSettings settings) {
    return Duration(seconds: settings.requestTimeoutSeconds.clamp(1, 3600));
  }

  String? _ssePayload(String rawLine) {
    final line = rawLine.trim();
    if (!line.startsWith('data:')) {
      return null;
    }
    return line.substring(5).trim();
  }

  String _buildStaticSystemPrompt(
    CharacterProfile character,
    List<WorldBookEntry> worldBooks,
    UserProfile? userProfile,
    List<NpcProfile> npcProfiles,
  ) {
    final activatedWorldBooks = _activateWorldBooks(
      worldBooks: worldBooks,
    );
    final buffer = StringBuffer()
      ..writeln('【固定输出协议｜最高优先级】')
      ..writeln('以下内容是 App 的运行协议、格式协议和功能开关。它们对用户不可见，但你必须严格遵守；不要向用户复述这些协议。')
      ..writeln(_buildTurnFormatConstraint(character))
      ..writeln()
      ..writeln(_buildFinalOutputFormatReminder(character))
      ..writeln()
      ..writeln(character.runtimeProtocolPrompt.trim())
      ..write(_formatWorldBookSection(
        title: '【世界书前部注入｜文风、全局规则、世界边界】',
        intro: '以下世界书靠近固定协议生效，适合文风、全局禁令和世界边界；请优先遵守，不要向用户解释来源。',
        entries: activatedWorldBooks.front,
      ))
      ..writeln()
      ..writeln('【用户可见角色设定｜角色扮演核心】')
      ..writeln('你现在扮演以下角色，请始终维持该角色的人设、世界观、玩法、叙事风格与语气。')
      ..writeln(character.prompt.trim().isEmpty
          ? character.name.trim()
          : character.prompt.trim());

    buffer.write(_formatWorldBookSection(
      title: '【世界书中部注入｜世界观、玩法规则、长期背景】',
      intro: '以下世界书用于补充世界观、玩法规则和长期背景；请自然遵守，不要机械复述。',
      entries: activatedWorldBooks.middle,
    ));

    final stableUserProfile = _formatStableUserProfile(userProfile);
    if (stableUserProfile.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(stableUserProfile);
    }

    final stableNpcProfiles = _formatStableNpcProfiles(npcProfiles);
    if (stableNpcProfiles.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(stableNpcProfiles);
    }

    return buffer.toString().trim();
  }

  String _formatStableUserProfile(UserProfile? userProfile) {
    if (userProfile == null || userProfile.persona.trim().isEmpty) {
      return '';
    }
    final buffer = StringBuffer()
      ..writeln('【用户固定人设｜本次对话稳定资料】')
      ..writeln('用户在本次对话中扮演：${userProfile.name.trim()}')
      ..writeln(userProfile.persona.trim());
    if (userProfile.gender.trim().isNotEmpty) {
      buffer.writeln('性别：${userProfile.gender.trim()}');
    }
    if (userProfile.description.trim().isNotEmpty) {
      buffer.writeln('简介：${userProfile.description.trim()}');
    }
    buffer.writeln('请把用户消息理解为这个用户人设的行动、台词或选择。');
    return buffer.toString().trim();
  }

  String _formatStableNpcProfiles(List<NpcProfile> npcProfiles) {
    final profiles = npcProfiles
        .where((npc) => npc.name.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    if (profiles.isEmpty) {
      return '';
    }
    final buffer = StringBuffer()
      ..writeln('【NPC 固定角色卡｜身份与长期设定】')
      ..writeln('以下只描述不会随回合变化的身份资料；本轮关系、位置和情绪以靠后的动态快照为准。');
    for (final npc in profiles) {
      final description = npc.description.trim();
      final roleCard = npc.roleCard.trim();
      buffer
        ..writeln()
        ..writeln('【${npc.name.trim()}】')
        ..writeln('档案 ID：${npc.id.trim()}')
        ..writeln(description.isEmpty ? '简介：暂无。' : '简介：$description')
        ..writeln(
          '绑定范围：${npc.globalBinding ? '全局绑定' : '当前/指定模拟器绑定'}；${npc.companionEnabled ? '同行主角' : '场景 NPC'}。',
        );
      if (roleCard.isNotEmpty) {
        buffer.writeln('角色卡：$roleCard');
      }
    }
    return buffer.toString().trim();
  }

  String _buildPromptEnvelope(
    CharacterProfile character,
    GameStateSnapshot? gameState,
    UserProfile? userProfile,
    List<CharacterMemorySummary> memorySummaries,
    List<NpcProfile> npcProfiles,
    List<WorldBookEntry> worldBooks,
    String runtimeAddendum,
    List<ChatMessage> contextMessages,
    PromptCacheEpoch? promptCacheEpoch,
  ) {
    final injectedMemoryKeys =
        promptCacheEpoch?.injectedMemorySummaryIds.toSet() ?? const <String>{};
    final pendingMemorySummaries = memorySummaries
        .where(
          (summary) =>
              !injectedMemoryKeys.contains(memorySummaryVersionKey(summary)),
        )
        .toList(growable: false);
    final injectedWorldBookKeys =
        promptCacheEpoch?.injectedWorldBookKeys.toSet() ?? const <String>{};
    final pendingWorldBooks = worldBooks
        .where(
          (entry) =>
              !injectedWorldBookKeys.contains(worldBookVersionKey(entry)),
        )
        .toList(growable: false);
    final activatedWorldBooks = _activateWorldBooks(
      worldBooks: pendingWorldBooks,
    );
    final body = StringBuffer();
    // 检查点放在快照最前部：它只在换代时变化，是「早于窗口的冻结前情」，
    // 放在请求尾部能让换代前的稳定前缀和窗口历史继续命中缓存。
    final checkpoint = promptCacheEpoch?.checkpoint.trim() ?? '';
    if (checkpoint.isNotEmpty) {
      body
        ..writeln()
        ..writeln('【剧情阶段检查点｜本缓存阶段固定前情】')
        ..writeln(checkpoint);
    }
    final effectiveNpcProfiles = character.largeGroupChatModeEnabled
        ? _selectLargeGroupChatNpcProfiles(
            npcProfiles: npcProfiles,
            gameState: gameState,
            contextMessages: contextMessages,
          )
        : npcProfiles;

    if (pendingMemorySummaries.isNotEmpty) {
      body
        ..writeln()
        ..writeln('以下是这位角色对用户的长期记忆，请自然地参考：');

      for (final summary in pendingMemorySummaries) {
        body.writeln('- ${summary.summaryText.trim()}');
      }
    }

    final companionProfiles = effectiveNpcProfiles
        .where((npc) => npc.companionEnabled && npc.name.trim().isNotEmpty)
        .toList(growable: false);
    if (companionProfiles.isNotEmpty) {
      body
        ..writeln()
        ..writeln('【绑定 NPC 角色卡｜另一个主角】')
        ..writeln(
            '以下 NPC 由用户创建或从旧世界带走，并已绑定到当前模拟器。它们不是玩家操控角色，而是会随剧情自主行动的同行者/重要角色。')
        ..writeln(
            '硬性规则：玩家只操控当前用户人设；绑定 NPC 必须保持自己的人设、目标、情绪和行动判断，可以主动推动支线、提出建议、与环境互动，但绝不能替玩家做决定、替玩家说话或代替玩家完成关键选择。')
        ..writeln(
            '回合推进时要让绑定 NPC 自然出现在正文、关系网、NPC变化或地图动向里；没有合适戏份时可以低调陪场，不要机械刷存在感。');

      for (final npc in companionProfiles) {
        final impression = npc.impression.trim();
        final bond = npc.bondRoute;
        body
          ..writeln()
          ..writeln('【${npc.name.trim()}】')
          ..writeln(
            '本轮关系状态：好感度 ${npc.affinity}；羁绊 ${bond.stage} · ${bond.route} · ${bond.score}/100；生命周期 ${npc.lifecycle.label}',
          );
        if (impression.isNotEmpty) {
          body.writeln('对玩家当前印象：$impression');
        }
        final runtime = npc.runtimeState;
        if (runtime.location.trim().isNotEmpty ||
            runtime.mood.trim().isNotEmpty ||
            runtime.currentGoal.trim().isNotEmpty) {
          body.writeln(
            '当前动态：位置 ${runtime.location.trim().isEmpty ? '未知' : runtime.location.trim()}；情绪 ${runtime.mood.trim().isEmpty ? '未记录' : runtime.mood.trim()}；目标 ${runtime.currentGoal.trim().isEmpty ? '未记录' : runtime.currentGoal.trim()}',
          );
        }
      }
    }

    final impressionProfiles = effectiveNpcProfiles
        .where((npc) =>
            !npc.companionEnabled &&
            npc.name.trim().isNotEmpty &&
            (character.largeGroupChatModeEnabled ||
                npc.description.trim().isNotEmpty ||
                npc.impression.trim().isNotEmpty ||
                npc.affinity != 0))
        .toList(growable: false);
    if (impressionProfiles.isNotEmpty) {
      body
        ..writeln()
        ..writeln('【NPC 档案与私聊印象】')
        ..writeln('以下信息来自 NPC 档案和独立私聊；请把它作为人物态度、关系倾向和后续互动自然性参考，不要机械复述给用户。');

      for (final npc in impressionProfiles) {
        final impression = npc.impression.trim();
        final bond = npc.bondRoute;
        final runtime = npc.runtimeState;
        body.writeln(
          '- ${npc.name.trim()}（ID：${npc.id.trim()}）：好感度 ${npc.affinity}；羁绊 ${bond.stage} · ${bond.route} · ${bond.score}/100；生命周期：${npc.lifecycle.label}；印象：${impression.isEmpty ? '暂无明确印象' : impression}；位置：${runtime.location.trim().isEmpty ? '未知' : runtime.location.trim()}；情绪：${runtime.mood.trim().isEmpty ? '未记录' : runtime.mood.trim()}；当前目标：${runtime.currentGoal.trim().isEmpty ? '未记录' : runtime.currentGoal.trim()}',
        );
      }
    }

    body.write(_formatWorldBookSection(
      title: '【世界书后部注入｜当前地点、NPC、道具、关键事实】',
      intro: '以下世界书与本轮上下文更贴近，适合提醒当前地点、NPC、道具或不要遗忘的关键事实。',
      entries: activatedWorldBooks.rear,
    ));

    if (gameState != null && !gameState.isEmpty) {
      body
        ..writeln()
        ..writeln('【当前游戏状态存档｜本轮动态资料】')
        ..writeln('以下是 App 本地保存的结构化状态，请自然参考，并在本轮结束后输出新的 [GAME_STATE]。')
        ..writeln(_formatGameState(gameState));
    }

    if (runtimeAddendum.trim().isNotEmpty) {
      body
        ..writeln()
        ..writeln('【本轮临时资料与导演指令｜本轮动态资料】')
        ..writeln(runtimeAddendum.trim());
    }

    final modeAddendum = _buildModeSpecificRuntimeAddendum(
      character,
      contextMessages,
    );
    if (modeAddendum.trim().isNotEmpty) {
      body
        ..writeln()
        ..writeln(modeAddendum.trim());
    }

    final trimmed = body.toString().trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return '''
【本轮上下文快照｜供模型参考，不要向用户复述】
$trimmed
【/本轮上下文快照】''';
  }

  List<NpcProfile> _selectLargeGroupChatNpcProfiles({
    required List<NpcProfile> npcProfiles,
    required GameStateSnapshot? gameState,
    required List<ChatMessage> contextMessages,
  }) {
    if (npcProfiles.length <= 10) {
      return npcProfiles;
    }

    final currentLocation = gameState?.location.trim().toLowerCase() ?? '';
    final recentContext = contextMessages.reversed
        .take(6)
        .map((message) => MessageContentParser.contextTextForModel(
              message.content,
            ))
        .join('\n')
        .toLowerCase();
    final now = DateTime.now();
    final ranked = npcProfiles.map((npc) {
      var score = 0;
      final name = npc.name.trim().toLowerCase();
      final location = npc.runtimeState.location.trim().toLowerCase();
      if (npc.companionEnabled) score += 240;
      if (name.isNotEmpty && recentContext.contains(name)) score += 160;
      if (currentLocation.isNotEmpty && location.isNotEmpty) {
        if (location == currentLocation) {
          score += 180;
        } else if (location.contains(currentLocation) ||
            currentLocation.contains(location)) {
          score += 120;
        }
      }
      final age = now.difference(npc.updatedAt).inDays;
      if (age <= 1) {
        score += 40;
      } else if (age <= 7) {
        score += 20;
      }
      if (npc.runtimeState.currentGoal.trim().isNotEmpty) score += 12;
      return (npc: npc, score: score);
    }).toList(growable: false)
      ..sort((a, b) {
        final scoreOrder = b.score.compareTo(a.score);
        if (scoreOrder != 0) return scoreOrder;
        return b.npc.updatedAt.compareTo(a.npc.updatedAt);
      });
    return ranked.take(10).map((item) => item.npc).toList(growable: false);
  }

  String _buildModeSpecificRuntimeAddendum(
    CharacterProfile character,
    List<ChatMessage> contextMessages,
  ) {
    if (!character.largeGroupChatModeEnabled) {
      return '';
    }

    final assistantTurns = contextMessages
        .where((message) =>
            message.role == ChatRole.assistant &&
            MessageContentParser.hasGroupChatBlock(message.content))
        .length;
    return '''
【大型群聊模式本轮节奏提示】
当前已完成大型群聊回复轮数：$assistantTurns。
主线只需自然推进群聊；NPC更新仅记录正文中已经实际发生的联系，不要为了定时任务凭空制造私聊。
周期性 NPC 主动联系由 App 在本轮提交后独立生成和投递。
无论是否触发私聊，群聊消息仍必须完整推进当前主线。''';
  }

  String _buildTurnFormatConstraint(CharacterProfile character) {
    if (character.largeGroupChatModeEnabled) {
      return _buildLargeGroupChatTurnFormatConstraint(
        gameplayPatchRequired: character.gameplaySystem != null,
      );
    }
    if (character.isTutorialDemo) {
      return '''
【第一次开幕本轮提醒】
1. 用户可见正文保持 300-600 个中文字符，只推进当前体验目标，不写功能清单或开发说明。
2. 资料卡按需输出；没有明显对比信息时不要生成 HTML。
3. 必须维护独立 [GAME_STATE]，但不要在正文里解释内部标签。
4. 最后只输出 A-C 三个上下文相关行动，其中一项允许自由探索、换路线或返回导览。
5. 不输出 D-F，不使用 NPC1/NPC2/NPC3，不主动提及 HTML、JSON、Token、CORS、缓存或提示词协议。
''';
    }

    final gameplayBlock = character.gameplaySystem == null
        ? ''
        : '''
4. [THEATER_PATCH]：独立 JSON 变量补丁，必须放在 [GAME_STATE] 之后、[CHOICES] 之前；逐项核对本轮事实，已触发的变化必须写入 ops，确实没有变量变化时才输出 {"ops":[]}。''';
    final choicesBlock = character.nextStepOptionsEnabled
        ? '''
5. [CHOICES]：最后输出，正好 A-F 六个可执行行动；不要把正文、HTML、[GAME_STATE] 或 [THEATER_PATCH] 混进选项。'''
        : '''
5. 当前角色关闭“下一步选项”，不要输出 [CHOICES]，也不要在正文里伪装 A/B/C/D/E/F 选项。''';

    return '''
【本轮回复格式强制提醒】
本轮仍按 App 格式完成，禁止只输出纯文本：
1. 剧情正文：继续当前主线，不解释规则；正式剧情推进时纯文字正文不少于 2000 个中文字符，目标 2200-3200 个中文字符。
2. HTML：至少一个完整 ```html 代码块（放什么内容、怎么写，按隐藏协议执行）。
3. [GAME_STATE]：独立状态块，放在选项之前，不得写进 HTML、代码块、[BUBBLE] 或选项文字。
   - 至少包含：时间、地点、状态、当前任务、人物数据、关系网、剧情记录、NPC变化、NPC更新。
   - NPC变化只写面板文字；NPC更新使用稳定 npcId、名字、好感变化、印象、生命周期、生命周期原因和本轮真实主动消息。已有 NPC 禁止重写绝对好感。
   - “等待回复、明日将联系、计划表白、信已传递”等状态不能写成 NPC 私聊气泡。

$gameplayBlock
$choicesBlock''';
  }

  String _buildLargeGroupChatTurnFormatConstraint({
    required bool gameplayPatchRequired,
  }) {
    final gameplayRequirement = gameplayPatchRequired
        ? '3. [THEATER_PATCH] 变量补丁：合法 JSON；已触发的变化必须写入 ops，确实没有变化时才输出 {"ops":[]}。'
        : '';
    return '''
【大型群聊模式本轮回复格式强制提醒】
本轮处于不可回退的大型群聊模式，禁止只输出纯文本，禁止输出 HTML 美化框，禁止输出 [CHOICES] 六选项，禁止输出 [BUBBLE]，禁止输出 [MAP_STATE]。

必须输出且只输出：
1. [GROUP_CHAT] JSON 块：包含 mode 和 messages。
2. [GAME_STATE] 状态块：沿用现有状态面板格式。
$gameplayRequirement

[GROUP_CHAT] 要求：
- 每条消息使用本轮唯一且递增的 id；已建档 NPC 使用档案中的 speakerId，旁白 speakerId 为 narrator；replyTo 只引用本轮已有消息 id，没有明确回复对象时为空。
- 过渡、等待或安静场景 2-4 条，普通交流 4-7 条，多人争执、高潮或突发事件 8-12 条；不要为了凑数量制造废话。
- 一旦需要玩家表态、回答或执行关键行动，就停在清晰的回应点，不要让 NPC 自己把冲突聊完。
- 只允许当前场景内 NPC 发言。
- 旁白负责所有动作、环境、神态、心理、沉默、靠近、离开、递物、攻击、防御、剧情推进和长段剧情。
- 旁白 content 不能替角色说话，不能写「角色名：台词」或带引号台词；有人开口时必须拆成对应 NPC 气泡。
- NPC 气泡只能写该 NPC 亲口说出的话，不得混入动作、神态、心理、环境、括号动作或旁白说明。
- NPC content 不能包含动作、表情、心理、旁白句、括号动作或“他说/她说”这类叙述，只能是可以直接显示在聊天气泡里的原话。
- 不要机械轮流发言，根据剧情选择真正需要说话的人。

[GAME_STATE] 要求：
- 至少包含：时间、地点、状态、当前任务、人物数据、关系网、剧情记录、NPC变化、NPC更新。
- NPC更新格式：「npcId：...｜名字：...｜简介：...｜好感变化：...｜印象：...｜生命周期：...｜生命周期原因：...｜主动消息：本轮真实私聊原话」。
- NPC 好感以档案为唯一事实源；missing/dead/archived NPC 不得改变好感或发送消息。周期性主动私聊由 App 独立调度。''';
  }

  String _buildFinalOutputFormatReminder(CharacterProfile character) {
    if (character.isTutorialDemo) {
      return '''
【第一次开幕最终检查】
输出顺序：300-600 字体验正文 → 可选简短资料卡 → [GAME_STATE] → [CHOICES]。
[CHOICES] 必须且只能包含 A、B、C 三项；不要输出 D-F。
不要把内部标签、格式名称或技术术语写进用户可见正文。
''';
    }
    final buffer = StringBuffer()
      ..writeln('【最终输出格式复核｜生成前最后检查】')
      ..writeln('如果本轮是角色扮演、文游、模拟器、剧情推进，或用户正在和角色互动，禁止只输出一段纯文字后结束。');
    if (character.gameplaySystem != null) {
      buffer.writeln(
          '玩法系统已启用：[GAME_STATE] 与 [THEATER_PATCH] 必须在同一条回复中成对出现、分别完整闭合；状态面板不能代替变量补丁，变量补丁也不能代替状态面板。');
    }

    if (character.largeGroupChatModeEnabled) {
      buffer
        ..writeln(
            '当前角色启用了大型群聊模式。必须输出独立 [GROUP_CHAT] JSON 块和独立 [GAME_STATE] 状态块。')
        ..writeln('不要输出 HTML、[CHOICES]、[BUBBLE] 或 [MAP_STATE]。')
        ..writeln(
            '[GROUP_CHAT] 不得写进 Markdown 代码块；[GAME_STATE] 不得写进 JSON、Markdown 代码块或群聊消息里。')
        ..writeln('旁白只写描写和剧情推进；角色气泡只写该角色亲口台词。旁白里不要夹角色台词，角色气泡里不要夹动作描写。')
        ..writeln(character.gameplaySystem == null
            ? '最终顺序：[GROUP_CHAT] → [GAME_STATE]。'
            : '最终顺序：[GROUP_CHAT] → [GAME_STATE] → [THEATER_PATCH]；没有变量变化时 ops 为空。');
      return buffer.toString().trim();
    }

    if (character.mapModeEnabled) {
      buffer
        ..writeln(
            '当前角色启用了地图主线模式。必须输出：可阅读长剧情、独立 [GAME_STATE] 状态块、独立 [MAP_STATE] JSON 块。纯文字剧情正文不少于 2000 个中文字符。')
        ..writeln('不要输出 [CHOICES]；下一步行动写入 [MAP_STATE].activeChoices，供行动篮子使用。')
        ..writeln(
            '[GAME_STATE] 和 [MAP_STATE] 不得写进 HTML、Markdown 代码块、[BUBBLE] 或选项文本里。')
        ..writeln(character.gameplaySystem == null
            ? '最终顺序：正文 → 可选HTML代码块 → 可选[BUBBLE]段落 → [GAME_STATE] → [MAP_STATE]。'
            : '最终顺序：正文 → 可选HTML代码块 → 可选[BUBBLE]段落 → [GAME_STATE] → [THEATER_PATCH] → [MAP_STATE]。');
      return buffer.toString().trim();
    }

    buffer
      ..writeln('按隐藏协议完整输出：可阅读正文 → ```html 代码块 → 独立 [GAME_STATE] 状态块。')
      ..writeln('正文先按轻小说写足，不少于 2000 个中文字符；HTML、状态块和选项不计入正文长度。')
      ..writeln('[GAME_STATE] 不得写进 HTML、Markdown 代码块、[BUBBLE] 或选项文本里。');

    if (character.nextStepOptionsEnabled) {
      buffer
        ..writeln('最后必须输出一个且只能输出一个 [CHOICES] 选项块，格式为 A|行动文本 到 F|行动文本。')
        ..writeln(character.gameplaySystem == null
            ? '最终顺序：正文 → HTML代码块 → 可选[BUBBLE]段落 → [GAME_STATE] → [CHOICES]。'
            : '最终顺序：正文 → HTML代码块 → 可选[BUBBLE]段落 → [GAME_STATE] → [THEATER_PATCH] → [CHOICES]。');
    } else {
      buffer
        ..writeln('当前角色关闭下一步选项，所以不要输出 [CHOICES]。')
        ..writeln(character.gameplaySystem == null
            ? '最终顺序：正文 → HTML代码块 → 可选[BUBBLE]段落 → [GAME_STATE]。'
            : '最终顺序：正文 → HTML代码块 → 可选[BUBBLE]段落 → [GAME_STATE] → [THEATER_PATCH]。');
    }

    return buffer.toString().trim();
  }

  _ActivatedWorldBookGroups _activateWorldBooks({
    required List<WorldBookEntry> worldBooks,
  }) {
    final activated = <WorldBookEntry>[];

    for (final entry in worldBooks) {
      if (entry.content.trim().isEmpty) {
        continue;
      }
      activated.add(entry);
    }

    activated.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) {
        return priority;
      }
      final created = a.createdAt.compareTo(b.createdAt);
      if (created != 0) {
        return created;
      }
      return a.id.compareTo(b.id);
    });

    return _ActivatedWorldBookGroups(
      front: _entriesForPosition(
        activated,
        WorldBookInjectionPosition.front,
      ),
      middle: _entriesForPosition(
        activated,
        WorldBookInjectionPosition.middle,
      ),
      rear: _entriesForPosition(
        activated,
        WorldBookInjectionPosition.rear,
      ),
    );
  }

  List<WorldBookEntry> _entriesForPosition(
    List<WorldBookEntry> entries,
    WorldBookInjectionPosition position,
  ) {
    return entries
        .where((entry) => entry.injectionPosition == position)
        .take(8)
        .toList(growable: false);
  }

  String _formatWorldBookSection({
    required String title,
    required String intro,
    required List<WorldBookEntry> entries,
  }) {
    if (entries.isEmpty) {
      return '';
    }

    final buffer = StringBuffer()
      ..writeln()
      ..writeln(title)
      ..writeln(intro);

    for (final entry in entries) {
      final title = entry.title.trim().isEmpty ? '未命名世界书' : entry.title.trim();
      buffer
        ..writeln()
        ..writeln('【$title】')
        ..writeln(entry.content.trim());
    }

    return buffer.toString();
  }

  String _formatGameState(GameStateSnapshot state) {
    final buffer = StringBuffer();
    if (state.timeLabel.trim().isNotEmpty) {
      buffer.writeln('时间：${state.timeLabel.trim()}');
    }
    if (state.location.trim().isNotEmpty) {
      buffer.writeln('地点：${state.location.trim()}');
    }
    if (state.status.trim().isNotEmpty) {
      buffer.writeln('状态：${state.status.trim()}');
    }
    if (state.mainTask.trim().isNotEmpty) {
      buffer.writeln('当前任务：${state.mainTask.trim()}');
    }
    if (state.profileDetails.isNotEmpty) {
      buffer.writeln('人物数据：${state.profileDetails.join('；')}');
    }
    if (state.sideTasks.isNotEmpty) {
      buffer.writeln('支线任务：${state.sideTasks.join('；')}');
    }
    if (state.completedTasks.isNotEmpty) {
      buffer.writeln('已完成任务：${state.completedTasks.join('；')}');
    }
    if (state.inventory.isNotEmpty) {
      buffer.writeln('背包：${state.inventory.join('；')}');
    }
    if (state.storyInventory.isNotEmpty) {
      buffer.writeln(
        '剧情物品栏：${state.storyInventory.map((item) {
          final parts = <String>[
            item.name,
            if (item.description.trim().isNotEmpty) item.description.trim(),
            if (item.effect.trim().isNotEmpty) '用途：${item.effect.trim()}',
          ];
          return parts.join('｜');
        }).join('；')}',
      );
    }
    if (state.eventTitle.trim().isNotEmpty) {
      buffer.writeln('事件卡：${state.eventTitle.trim()}');
    }
    if (state.eventDescription.trim().isNotEmpty) {
      buffer.writeln('事件描述：${state.eventDescription.trim()}');
    }
    if (state.relationshipNotes.isNotEmpty) {
      buffer.writeln('关系网：${state.relationshipNotes.join('；')}');
    }
    if (state.plotFlags.isNotEmpty) {
      buffer.writeln('剧情记录：${state.plotFlags.join('；')}');
    }
    if (state.metrics.isNotEmpty) {
      for (final entry in state.metrics.entries) {
        buffer.writeln('${entry.key}：${entry.value}');
      }
    }
    if (state.npcChanges.isNotEmpty) {
      buffer.writeln('NPC变化：${state.npcChanges.join('；')}');
    }
    if (state.npcUpdates.isNotEmpty) {
      buffer.writeln('NPC更新：无（上一轮更新已结算，当前关系以 NPC 档案为准）');
    }
    return buffer.toString().trim();
  }

  String _extractMessageContent(dynamic decoded) {
    if (decoded is! Map) {
      return '';
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }

    final first = choices.first;
    if (first is! Map) {
      return '';
    }

    final message = first['message'];
    if (message is Map) {
      return _readContentField(message['content']);
    }

    final text = first['text'];
    if (text is String) {
      return text.trim();
    }

    return '';
  }

  String _extractDeltaContent(dynamic decoded) {
    if (decoded is! Map) {
      return '';
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }

    final first = choices.first;
    if (first is! Map) {
      return '';
    }

    final delta = first['delta'];
    if (delta is Map) {
      final content = _readContentField(delta['content'], trim: false);
      if (content.isNotEmpty) {
        return content;
      }
    }

    final text = first['text'];
    if (text is String) {
      return text;
    }

    return '';
  }

  String _readContentField(dynamic content, {bool trim = true}) {
    if (content is String) {
      return trim ? content.trim() : content;
    }

    if (content is! List) {
      return '';
    }

    final parts = <String>[];
    for (final item in content) {
      if (item is! Map) {
        continue;
      }

      final text = item['text'];
      if (text is String && text.trim().isNotEmpty) {
        parts.add(trim ? text.trim() : text);
        continue;
      }

      if (text is Map && text['value'] is String) {
        final value = text['value'] as String;
        parts.add(trim ? value.trim() : value);
      }
    }

    final joined = trim ? parts.join('\n') : parts.join();
    return trim ? joined.trim() : joined;
  }

  void _logPromptCacheUsage(
    PromptCacheUsage? usage, {
    required DateTime startedAt,
    required String model,
    required String requestType,
  }) {
    if (usage == null || !usage.hasCacheData) {
      return;
    }

    final hitTokens = usage.cachedInputTokens ?? 0;
    final missTokens = usage.cacheMissInputTokens ?? 0;
    final hitRate = usage.cacheHitRate ?? 0;
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    // Printed only when providers expose cache usage, useful for release QA.
    // ignore: avoid_print
    print(
      'LLM prompt cache: hit=$hitTokens miss=$missTokens '
      'rate=$hitRate% type=$requestType model=$model elapsed=${elapsedMs}ms',
    );
  }

  bool _isDeepSeekOfficialEndpoint(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'api.deepseek.com' || host.endsWith('.deepseek.com');
  }

  void _addProviderRequestFields(
    Map<String, dynamic> payload, {
    required AppSettings settings,
    required Uri uri,
  }) {
    if (!_isDeepSeekOfficialEndpoint(uri)) {
      return;
    }
    var userId = settings.cacheIsolationId.trim().replaceAll(
          RegExp(r'[^a-zA-Z0-9\-_]'),
          '_',
        );
    if (userId.length > 512) {
      userId = userId.substring(0, 512);
    }
    if (userId.isNotEmpty) {
      payload['user_id'] = userId;
    }
  }

  String _stableDigest(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  PromptCacheUsage? _extractPromptCacheUsage(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    final usage = decoded['usage'];
    if (usage is! Map) {
      return null;
    }

    final inputTokens = _readUsageInt(
      usage['prompt_tokens'] ??
          usage['input_tokens'] ??
          usage['inputTokens'] ??
          usage['promptTokens'],
    );
    final outputTokens = _readUsageInt(
      usage['completion_tokens'] ??
          usage['output_tokens'] ??
          usage['completionTokens'] ??
          usage['outputTokens'],
    );
    final directHit = _readUsageInt(
      usage['prompt_cache_hit_tokens'] ??
          usage['promptCacheHitTokens'] ??
          usage['cache_hit_tokens'],
    );
    final directMiss = _readUsageInt(
      usage['prompt_cache_miss_tokens'] ??
          usage['promptCacheMissTokens'] ??
          usage['cache_miss_tokens'],
    );

    int? nestedCached;
    final promptDetails =
        usage['prompt_tokens_details'] ?? usage['promptTokensDetails'];
    if (promptDetails is Map) {
      nestedCached = _readUsageInt(
        promptDetails['cached_tokens'] ?? promptDetails['cachedTokens'],
      );
    }
    final inputDetails =
        usage['input_tokens_details'] ?? usage['inputTokensDetails'];
    if (nestedCached == null && inputDetails is Map) {
      nestedCached = _readUsageInt(
        inputDetails['cached_tokens'] ?? inputDetails['cachedTokens'],
      );
    }

    final cachedTokens = directHit ?? nestedCached;
    final missTokens = directMiss ??
        (inputTokens != null && cachedTokens != null
            ? math.max(0, inputTokens - cachedTokens)
            : null);

    if (inputTokens == null &&
        outputTokens == null &&
        cachedTokens == null &&
        missTokens == null) {
      return null;
    }

    return PromptCacheUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cachedInputTokens: cachedTokens,
      cacheMissInputTokens: missTokens,
    );
  }

  int? _readUsageInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String? _extractErrorMessage(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }

    final error = decoded['error'];
    if (error is Map && error['message'] is String) {
      return (error['message'] as String).trim();
    }

    if (decoded['message'] is String) {
      return (decoded['message'] as String).trim();
    }

    return null;
  }

  String _normalizeGeneratedPrompt(String content) {
    var normalized = content.trim();

    if (normalized.startsWith('```')) {
      normalized = normalized.replaceFirst(
        RegExp(r'^```[a-zA-Z0-9_-]*\s*'),
        '',
      );
      normalized = normalized.replaceFirst(RegExp(r'\s*```$'), '');
    }

    return normalized.trim();
  }

  String _composeGeneratedPrompt({
    required String? generatedName,
    required String? generatedSystemPrompt,
    required String fallback,
  }) {
    final prompt = generatedSystemPrompt?.trim();
    if (prompt == null || prompt.isEmpty) {
      return fallback.trim();
    }

    final name = generatedName?.trim();
    if (name == null || name.isEmpty) {
      return prompt;
    }

    return '模拟器名称：$name\n\n$prompt';
  }

  /// 与 [_extractGeneratedSectionFromEnd] 相同，但取最后一个匹配段。
  /// 用于「原文 + 续写」合并后的结果：续写段落会覆盖被截断的旧段落，
  /// 避免截断残片被当成最终内容。
  String? _extractGeneratedSectionFromEnd(
    String content,
    List<String> labels,
  ) {
    final matches = <({String label, int start, int end})>[];
    for (final label in labels) {
      final pattern = RegExp(
        r'(^|\n)\s*' + RegExp.escape(label) + r'\s*[：:]\s*',
        multiLine: true,
      );
      for (final match in pattern.allMatches(content)) {
        matches.add((label: label, start: match.start, end: match.end));
      }
    }

    if (matches.isEmpty) {
      return null;
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    final target = matches.last;
    final allLabels = const <String>[
      '模拟器名称',
      '一句话简介',
      '简介',
      '开场白',
      '系统提示词',
      '完整系统提示词',
      '提示词正文',
    ];
    final nextPattern = RegExp(
      r'\n\s*(?:' + allLabels.map(RegExp.escape).join('|') + r')\s*[：:]\s*',
      multiLine: true,
    );
    final remainder = content.substring(target.end);
    final next = nextPattern.firstMatch(remainder);
    final value = next == null
        ? remainder.trim()
        : remainder.substring(0, next.start).trim();
    return value.isEmpty ? null : value;
  }
}

class _ActivatedWorldBookGroups {
  const _ActivatedWorldBookGroups({
    required this.front,
    required this.middle,
    required this.rear,
  });

  final List<WorldBookEntry> front;
  final List<WorldBookEntry> middle;
  final List<WorldBookEntry> rear;
}
