import '../models/app_settings.dart';
import '../models/character_memory.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/game_state.dart';
import '../models/npc_profile.dart';
import '../models/prompt_cache.dart';
import '../models/user_profile.dart';
import '../models/world_book.dart';
import 'llm_api_client.dart';

class AiRequestContext {
  const AiRequestContext({
    required this.character,
    required this.gameState,
    required this.userProfile,
    required this.npcProfiles,
    required this.worldBooks,
    required this.runtimeAddendum,
    required this.contextMessages,
    required this.memorySummaries,
    required this.estimatedTokens,
    this.promptDiagnostics = const AiPromptDiagnostics(),
    this.promptCacheEpoch,
  });

  final CharacterProfile character;
  final GameStateSnapshot gameState;
  final UserProfile? userProfile;
  final List<NpcProfile> npcProfiles;
  final List<WorldBookEntry> worldBooks;
  final String runtimeAddendum;
  final List<ChatMessage> contextMessages;
  final List<CharacterMemorySummary> memorySummaries;
  final int estimatedTokens;
  final AiPromptDiagnostics promptDiagnostics;
  final PromptCacheEpoch? promptCacheEpoch;
}

class AiPromptDiagnostics {
  const AiPromptDiagnostics({
    this.worldBookTitles = const <String>[],
    this.memoryCount = 0,
    this.staticWorldBookCount = 0,
    this.triggeredWorldBookCount = 0,
    this.cacheEpochId = '',
    this.cacheRolloverReason = '',
    this.stablePrefixDigest = '',
    this.previousPromptTokens,
    this.promptTokenBudget = 0,
    this.usedExactAssistantReplay = false,
    this.fixedOverheadExceedsBudget = false,
  });

  final List<String> worldBookTitles;
  final int memoryCount;
  final int staticWorldBookCount;
  final int triggeredWorldBookCount;
  final String cacheEpochId;
  final String cacheRolloverReason;
  final String stablePrefixDigest;
  final int? previousPromptTokens;
  final int promptTokenBudget;
  final bool usedExactAssistantReplay;
  final bool fixedOverheadExceedsBudget;
}

class TokenBudgetPlanner {
  const TokenBudgetPlanner();

  List<ChatMessage> trimContext({
    required List<ChatMessage> messages,
    required int Function(List<ChatMessage> messages) estimate,
    required int maxPromptTokens,
  }) {
    if (messages.length <= 1) {
      return messages;
    }

    var selected = List<ChatMessage>.from(messages);
    final budget = maxPromptTokens.clamp(1200, 500000);
    while (selected.length > 1 && estimate(selected) > budget) {
      selected = _dropOldestCompleteTurn(selected);
    }
    return selected;
  }

  List<ChatMessage> _dropOldestCompleteTurn(List<ChatMessage> messages) {
    if (messages.length <= 1) {
      return messages;
    }
    var nextStart = 1;
    if (messages.first.role == ChatRole.user &&
        messages.length > 1 &&
        messages[1].role == ChatRole.assistant) {
      nextStart = 2;
    }
    while (nextStart < messages.length - 1 &&
        messages[nextStart].role == ChatRole.assistant) {
      nextStart += 1;
    }
    return messages.sublist(nextStart);
  }
}

class AiTraceEntry {
  AiTraceEntry({
    required this.id,
    required this.startedAt,
    required this.estimatedTokens,
    required this.messageCount,
    required this.model,
    this.completedAt,
    this.chunkCount = 0,
    this.error = '',
    this.paused = false,
    this.cacheUsage,
    this.promptDiagnostics = const AiPromptDiagnostics(),
  });

  final String id;
  final DateTime startedAt;
  final int estimatedTokens;
  final int messageCount;
  final String model;
  DateTime? completedAt;
  int chunkCount;
  String error;
  bool paused;
  PromptCacheUsage? cacheUsage;
  AiPromptDiagnostics promptDiagnostics;

  Duration? get elapsed => completedAt?.difference(startedAt);
}

class AiTraceLogger {
  AiTraceLogger({this.maxEntries = 30});

  final int maxEntries;
  final List<AiTraceEntry> _entries = <AiTraceEntry>[];

  List<AiTraceEntry> get entries => List.unmodifiable(_entries);
  AiTraceEntry? get latest => _entries.isEmpty ? null : _entries.first;

  AiTraceEntry start({
    required int estimatedTokens,
    required int messageCount,
    required String model,
    AiPromptDiagnostics promptDiagnostics = const AiPromptDiagnostics(),
  }) {
    final entry = AiTraceEntry(
      id: 'trace_${DateTime.now().microsecondsSinceEpoch}',
      startedAt: DateTime.now(),
      estimatedTokens: estimatedTokens,
      messageCount: messageCount,
      model: model,
      promptDiagnostics: promptDiagnostics,
    );
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    return entry;
  }

  void markChunk(AiTraceEntry entry) {
    entry.chunkCount += 1;
  }

  void markUsage(AiTraceEntry entry, PromptCacheUsage usage) {
    entry.cacheUsage = usage;
  }

  void complete(AiTraceEntry entry) {
    entry.completedAt = DateTime.now();
  }

  void pause(AiTraceEntry entry) {
    entry.paused = true;
    entry.completedAt = DateTime.now();
  }

  void fail(AiTraceEntry entry, Object error) {
    entry.error = error.toString();
    entry.completedAt = DateTime.now();
  }
}

class AiReplyPipeline {
  AiReplyPipeline({
    required LlmApiClient client,
    AiTraceLogger? traceLogger,
  })  : _client = client,
        traceLogger = traceLogger ?? AiTraceLogger();

  final LlmApiClient _client;
  final AiTraceLogger traceLogger;

  Stream<String> streamReply({
    required AppSettings settings,
    required AiRequestContext context,
    required bool Function() shouldPause,
    LlmCancellationToken? cancellationToken,
  }) async* {
    final requestCancellation = cancellationToken ?? LlmCancellationToken();
    final trace = traceLogger.start(
      estimatedTokens: context.estimatedTokens,
      messageCount: context.contextMessages.length,
      model: settings.effectiveModelName.trim(),
      promptDiagnostics: context.promptDiagnostics,
    );
    try {
      await for (final event in _client.streamChatEvents(
        settings: settings,
        character: context.character,
        gameState: context.gameState,
        userProfile: context.userProfile,
        npcProfiles: context.npcProfiles,
        worldBooks: context.worldBooks,
        runtimeAddendum: context.runtimeAddendum,
        contextMessages: context.contextMessages,
        memorySummaries: context.memorySummaries,
        promptCacheEpoch: context.promptCacheEpoch,
        cancellationToken: requestCancellation,
      )) {
        final usage = event.usage;
        if (usage != null) {
          traceLogger.markUsage(trace, usage);
          continue;
        }
        final chunk = event.delta;
        if (chunk.isEmpty) {
          continue;
        }
        if (shouldPause()) {
          requestCancellation.cancel();
          traceLogger.pause(trace);
          break;
        }
        traceLogger.markChunk(trace);
        yield chunk;
      }
      if (!trace.paused && trace.error.isEmpty) {
        traceLogger.complete(trace);
      }
    } on LlmRequestCancelledException {
      traceLogger.pause(trace);
    } catch (error) {
      traceLogger.fail(trace, error);
      rethrow;
    }
  }
}
