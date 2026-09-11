import '../models/chat_message.dart';
import '../models/game_state.dart';
import '../models/map_state.dart';
import '../models/npc_profile.dart';
import '../models/story_systems.dart';
import '../models/world_book.dart';
import 'ai_reply_pipeline.dart';
import 'message_content_parser.dart';

class StoryTimelineEntry {
  const StoryTimelineEntry({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.source,
    this.npcNames = const <String>[],
  });

  final String title;
  final String subtitle;
  final String detail;
  final String source;
  final List<String> npcNames;
}

class MapObjectiveBoard {
  const MapObjectiveBoard({
    required this.mainGoal,
    required this.shortTermGoal,
    required this.currentLocation,
    required this.riskLevel,
    required this.clues,
    required this.relatedNpcs,
    required this.nextActions,
  });

  final String mainGoal;
  final String shortTermGoal;
  final String currentLocation;
  final String riskLevel;
  final List<String> clues;
  final List<String> relatedNpcs;
  final List<String> nextActions;
}

class NpcEnsembleInsight {
  const NpcEnsembleInsight({
    required this.name,
    required this.location,
    required this.mood,
    required this.goal,
    required this.bond,
    required this.recentEvent,
    required this.privateChatState,
  });

  final String name;
  final String location;
  final String mood;
  final String goal;
  final String bond;
  final String recentEvent;
  final String privateChatState;
}

class PromptDiagnosticsSnapshot {
  const PromptDiagnosticsSnapshot({
    required this.estimatedTokens,
    required this.messageCount,
    required this.model,
    required this.worldBookTitles,
    required this.memoryCount,
    required this.staticWorldBookCount,
    required this.triggeredWorldBookCount,
    this.outputTokens,
    this.inputTokens,
    this.cachedInputTokens,
    this.cacheMissInputTokens,
    this.cacheHitRate,
    this.elapsed,
    this.error = '',
    this.paused = false,
    this.cacheEpochId = '',
    this.cacheRolloverReason = '',
    this.stablePrefixDigest = '',
    this.previousPromptTokens,
    this.promptTokenBudget = 0,
    this.usedExactAssistantReplay = false,
    this.fixedOverheadExceedsBudget = false,
  });

  final int estimatedTokens;
  final int messageCount;
  final String model;
  final List<String> worldBookTitles;
  final int memoryCount;
  final int staticWorldBookCount;
  final int triggeredWorldBookCount;
  final int? outputTokens;
  final int? inputTokens;
  final int? cachedInputTokens;
  final int? cacheMissInputTokens;
  final int? cacheHitRate;
  final Duration? elapsed;
  final String error;
  final bool paused;
  final String cacheEpochId;
  final String cacheRolloverReason;
  final String stablePrefixDigest;
  final int? previousPromptTokens;
  final int promptTokenBudget;
  final bool usedExactAssistantReplay;
  final bool fixedOverheadExceedsBudget;
}

class WorldBookPreviewItem {
  const WorldBookPreviewItem({
    required this.title,
    required this.position,
    required this.trigger,
    required this.priority,
    required this.reason,
    required this.active,
  });

  final String title;
  final String position;
  final String trigger;
  final int priority;
  final String reason;
  final bool active;
}

class StoryInsightService {
  const StoryInsightService._();

  static List<StoryTimelineEntry> buildTimeline({
    required List<ChatMessage> messages,
    required GameStateSnapshot gameState,
    required MapWorldState mapState,
    required List<NpcProfile> npcs,
    required List<WorldCalendarEvent> calendarEvents,
  }) {
    final entries = <StoryTimelineEntry>[];
    for (final event in calendarEvents.take(8)) {
      entries.add(
        StoryTimelineEntry(
          title: _fallback(event.title, '世界事件'),
          subtitle: [
            if (event.stage.trim().isNotEmpty) event.stage.trim(),
            if (event.timeLabel.trim().isNotEmpty) event.timeLabel.trim(),
          ].join(' · '),
          detail: event.description.trim(),
          source: '世界事件日历',
        ),
      );
    }
    if (gameState.eventTitle.trim().isNotEmpty ||
        gameState.eventDescription.trim().isNotEmpty) {
      entries.add(
        StoryTimelineEntry(
          title: _fallback(gameState.eventTitle, '当前事件'),
          subtitle: [
            gameState.timeLabel,
            gameState.location,
          ].where((item) => item.trim().isNotEmpty).join(' · '),
          detail: _fallback(
            gameState.eventDescription,
            gameState.plotFlags.take(3).join('；'),
          ),
          source: '当前状态面板',
          npcNames: _npcNamesFromState(gameState),
        ),
      );
    }
    for (final item in mapState.eventLog.take(8)) {
      entries.add(
        StoryTimelineEntry(
          title: item.length > 28 ? '${item.substring(0, 28)}...' : item,
          subtitle: [
            if (mapState.stage.trim().isNotEmpty) mapState.stage.trim(),
            if (mapState.timeLabel.trim().isNotEmpty) mapState.timeLabel.trim(),
          ].join(' · '),
          detail: item,
          source: '地图事件',
          npcNames: _npcNamesFromText(item, npcs),
        ),
      );
    }
    for (final npc in npcs) {
      for (final event in npc.worldEvents.take(2)) {
        entries.add(
          StoryTimelineEntry(
            title: _fallback(event.title, '${npc.name} 的事件'),
            subtitle: event.createdAt.toLocal().toString().split('.').first,
            detail: event.summary,
            source: 'NPC 事件记忆',
            npcNames: <String>[npc.name],
          ),
        );
      }
    }
    if (entries.isEmpty) {
      final recent = messages
          .where((message) => message.role == ChatRole.assistant)
          .toList(growable: false)
          .reversed
          .take(3);
      for (final message in recent) {
        final text = MessageContentParser.assistantReplayPrefixForModel(
          message.content,
          maxChars: 220,
        );
        if (text.trim().isEmpty) {
          continue;
        }
        entries.add(
          StoryTimelineEntry(
            title: '最近剧情',
            subtitle: message.timestamp.toLocal().toString().split('.').first,
            detail: text,
            source: '聊天记录',
          ),
        );
      }
    }
    return entries.take(18).toList(growable: false);
  }

  static MapObjectiveBoard buildMapObjectiveBoard({
    required GameStateSnapshot gameState,
    required MapWorldState mapState,
  }) {
    final currentLocation = _fallback(
      mapState.currentLocationName,
      _fallback(gameState.location, '当前位置未定'),
    );
    final currentNode = mapState.currentLocation;
    final clues = <String>[
      ...mapState.discoveredClues.take(8),
      ...?currentNode?.clues.take(4),
    ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false);
    final npcs = <String>[
      ...mapState.npcPositions
          .where((npc) =>
              npc.locationId == mapState.currentLocationId ||
              npc.locationName == mapState.currentLocationName)
          .map((npc) => npc.name),
      ...?currentNode?.npcs,
    ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false);
    final nextActions = mapState.activeChoices
        .map((choice) => choice.label.trim().isEmpty
            ? choice.action.trim()
            : choice.label.trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList(growable: false);
    return MapObjectiveBoard(
      mainGoal:
          _fallback(mapState.mainGoal, _fallback(gameState.mainTask, '暂无主线目标')),
      shortTermGoal: _fallback(mapState.eventSummary,
          _fallback(mapState.currentScene, gameState.status)),
      currentLocation: currentLocation,
      riskLevel: _fallback(currentNode?.riskLevel ?? '', '风险未标注'),
      clues: clues,
      relatedNpcs: npcs,
      nextActions: nextActions,
    );
  }

  static List<NpcEnsembleInsight> buildNpcEnsemble({
    required List<NpcProfile> npcs,
    required MapWorldState mapState,
  }) {
    final mapPositions = <String, MapNpcPosition>{
      for (final position in mapState.npcPositions)
        position.name.trim().toLowerCase(): position,
    };
    return npcs
        .map((npc) {
          final position = mapPositions[npc.name.trim().toLowerCase()];
          final runtime = npc.runtimeState;
          final recentEvent = npc.worldEvents.isNotEmpty
              ? npc.worldEvents.first.summary
              : npc.npcMemory.isNotEmpty
                  ? npc.npcMemory.first.summary
                  : npc.impression;
          return NpcEnsembleInsight(
            name: npc.name,
            location: _fallback(
              position?.locationName ?? '',
              _fallback(runtime.location, '位置未定'),
            ),
            mood: _fallback(runtime.mood, '状态未明'),
            goal: _fallback(
              position?.intent ?? '',
              _fallback(runtime.currentGoal, '暂无明确目标'),
            ),
            bond:
                '${npc.bondRoute.stage} · ${npc.bondRoute.route} · ${npc.bondRoute.score}/100',
            recentEvent: _fallback(recentEvent, '暂无近期事件'),
            privateChatState: npc.runtimeState.lastEventId.trim().isNotEmpty ||
                    recentEvent.trim().isNotEmpty
                ? '有近期互动记录'
                : '无待触发私聊',
          );
        })
        .take(24)
        .toList(growable: false);
  }

  static PromptDiagnosticsSnapshot? latestPromptDiagnostics(
    AiTraceLogger traceLogger,
  ) {
    final entry = traceLogger.latest;
    if (entry == null) {
      return null;
    }
    final usage = entry.cacheUsage;
    return PromptDiagnosticsSnapshot(
      estimatedTokens: entry.estimatedTokens,
      messageCount: entry.messageCount,
      model: entry.model,
      worldBookTitles: entry.promptDiagnostics.worldBookTitles,
      memoryCount: entry.promptDiagnostics.memoryCount,
      staticWorldBookCount: entry.promptDiagnostics.staticWorldBookCount,
      triggeredWorldBookCount: entry.promptDiagnostics.triggeredWorldBookCount,
      outputTokens: usage?.outputTokens,
      inputTokens: usage?.inputTokens,
      cachedInputTokens: usage?.cachedInputTokens,
      cacheMissInputTokens: usage?.cacheMissInputTokens,
      cacheHitRate: usage?.cacheHitRate,
      elapsed: entry.elapsed,
      error: entry.error,
      paused: entry.paused,
      cacheEpochId: entry.promptDiagnostics.cacheEpochId,
      cacheRolloverReason: entry.promptDiagnostics.cacheRolloverReason,
      stablePrefixDigest: entry.promptDiagnostics.stablePrefixDigest,
      previousPromptTokens: entry.promptDiagnostics.previousPromptTokens,
      promptTokenBudget: entry.promptDiagnostics.promptTokenBudget,
      usedExactAssistantReplay:
          entry.promptDiagnostics.usedExactAssistantReplay,
      fixedOverheadExceedsBudget:
          entry.promptDiagnostics.fixedOverheadExceedsBudget,
    );
  }

  static List<WorldBookPreviewItem> previewWorldBooks({
    required List<WorldBookEntry> entries,
    required String characterId,
    required String rootCharacterId,
    required List<ChatMessage> contextMessages,
    required GameStateSnapshot gameState,
    required String runtimeAddendum,
  }) {
    final haystack = <String>[
      ...contextMessages.reversed.take(8).map((message) => message.content),
      gameState.location,
      gameState.timeLabel,
      gameState.status,
      gameState.mainTask,
      gameState.eventTitle,
      gameState.eventDescription,
      ...gameState.plotFlags,
      runtimeAddendum,
    ].join('\n').toLowerCase();
    return entries
        .where((entry) =>
            entry.content.trim().isNotEmpty &&
            (entry.appliesTo(characterId) || entry.appliesTo(rootCharacterId)))
        .map((entry) {
      final reason = _worldBookReason(entry, haystack);
      return WorldBookPreviewItem(
        title: _fallback(entry.title, '未命名世界书'),
        position: entry.injectionPosition.label,
        trigger: entry.triggerMode.label,
        priority: entry.priority,
        reason: reason.reason,
        active: reason.active,
      );
    }).toList(growable: false)
      ..sort((a, b) {
        if (a.active != b.active) {
          return a.active ? -1 : 1;
        }
        return b.priority.compareTo(a.priority);
      });
  }

  static ({bool active, String reason}) _worldBookReason(
    WorldBookEntry entry,
    String haystack,
  ) {
    switch (entry.triggerMode) {
      case WorldBookTriggerMode.always:
        return (active: true, reason: '常驻条目，本轮固定注入');
      case WorldBookTriggerMode.keyword:
        if (entry.keywords.isEmpty) {
          return (active: true, reason: '未设置关键词，按常驻处理');
        }
        for (final keyword in entry.keywords) {
          final clean = keyword.trim().toLowerCase();
          if (clean.isNotEmpty && haystack.contains(clean)) {
            return (active: true, reason: '命中关键词：$keyword');
          }
        }
        return (active: false, reason: '未命中关键词');
      case WorldBookTriggerMode.regex:
        final pattern = entry.regexPattern.trim();
        if (pattern.isEmpty) {
          return (active: true, reason: '未设置正则，按常驻处理');
        }
        try {
          final matched =
              RegExp(pattern, caseSensitive: false).hasMatch(haystack);
          return (
            active: matched,
            reason: matched ? '正则命中：$pattern' : '正则未命中',
          );
        } catch (_) {
          return (active: false, reason: '正则表达式无效');
        }
    }
  }

  static String _fallback(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  static List<String> _npcNamesFromState(GameStateSnapshot state) {
    return state.npcUpdates
        .map((update) => update.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _npcNamesFromText(String text, List<NpcProfile> npcs) {
    return npcs
        .where((npc) => npc.name.trim().isNotEmpty && text.contains(npc.name))
        .map((npc) => npc.name)
        .toList(growable: false);
  }
}
