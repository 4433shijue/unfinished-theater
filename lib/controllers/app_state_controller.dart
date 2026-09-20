import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/preset_characters.dart';
import '../data/release_notes.dart';
import '../models/background_music.dart';
import '../models/app_settings.dart';
import '../models/character_memory.dart';
import '../models/character_profile.dart';
import '../models/chat_message.dart';
import '../models/data_management.dart';
import '../models/dialogue_history.dart';
import '../models/fanfic_result.dart';
import '../models/game_state.dart';
import '../models/gameplay_system.dart';
import '../models/gamification.dart';
import '../models/map_state.dart';
import '../models/npc_migration.dart';
import '../models/npc_profile.dart';
import '../models/npc_runtime.dart';
import '../models/prompt_cache.dart';
import '../models/save_envelope.dart';
import '../models/simulator_prompt_request.dart';
import '../models/story_systems.dart';
import '../models/theme_style.dart';
import '../models/tool_result.dart';
import '../models/user_profile.dart';
import '../models/world_book.dart';
import '../services/ai_reply_pipeline.dart';
import '../services/data_health_service.dart';
import '../services/llm_api_client.dart';
import '../services/game_state_parser.dart';
import '../services/gameplay_patch_engine.dart';
import '../services/gameplay_turn_engine.dart';
import '../services/gameplay_prompt_context.dart';
import '../services/gameplay_system_draft.dart';
import '../services/gameplay_system_parser.dart';
import '../services/local_audio_picker.dart';
import '../services/local_audio_storage.dart';
import '../services/local_store.dart';
import '../services/map_turn_engine.dart';
import '../services/memory_service.dart';
import '../services/message_content_parser.dart';
import '../services/npc_message_classifier.dart';
import '../services/reply_protocol_validator.dart';
import '../services/story_insight_service.dart';
import '../services/token_estimator.dart';
import '../services/turn_state_adjudicator.dart';
import '../theme/app_theme.dart';
import '../utils/id_generator.dart';

class RouletteSpinResult {
  const RouletteSpinResult({
    required this.title,
    required this.description,
    this.rewardLabel = '',
    this.empty = false,
    this.jackpot = false,
  });

  final String title;
  final String description;
  final String rewardLabel;
  final bool empty;
  final bool jackpot;
}

enum GlobalSearchResultType {
  character,
  message,
  bookmark,
  npc,
  worldBook,
  tool,
  fanfic,
  migration,
}

const Set<String> _promptStopWords = <String>{
  'the',
  'and',
  'you',
  'are',
  'with',
  'this',
  'that',
  'from',
  'have',
  'http',
  'https',
  '用户',
  '玩家',
  '角色',
  '当前',
  '剧情',
  '回复',
  '继续',
  '一个',
  '这个',
  '那个',
  '可以',
  '没有',
  '不是',
  '不要',
  '进行',
  '状态',
  '任务',
  '时间',
  '地点',
};

class GlobalSearchResult {
  const GlobalSearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.updatedAt,
    this.characterId,
    this.messageId,
    this.npcId,
    this.worldBookId,
    this.routeHint = '',
  });

  final GlobalSearchResultType type;
  final String title;
  final String subtitle;
  final String preview;
  final DateTime updatedAt;
  final String? characterId;
  final String? messageId;
  final String? npcId;
  final String? worldBookId;
  final String routeHint;

  String get typeLabel => switch (type) {
        GlobalSearchResultType.character => '角色',
        GlobalSearchResultType.message => '聊天',
        GlobalSearchResultType.bookmark => '书签',
        GlobalSearchResultType.npc => 'NPC',
        GlobalSearchResultType.worldBook => '世界书',
        GlobalSearchResultType.tool => '工具',
        GlobalSearchResultType.fanfic => '同人文',
        GlobalSearchResultType.migration => '前尘',
      };
}

class ContinueDashboard {
  const ContinueDashboard({
    required this.characterName,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.currentTask,
    required this.currentStatus,
    required this.unreadNpcCount,
    required this.unclaimedMailCount,
    required this.bookmarkCount,
    required this.memoryCount,
    required this.mapHint,
  });

  final String characterName;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final String currentTask;
  final String currentStatus;
  final int unreadNpcCount;
  final int unclaimedMailCount;
  final int bookmarkCount;
  final int memoryCount;
  final String mapHint;

  bool get hasAnySignal =>
      lastMessagePreview.trim().isNotEmpty ||
      currentTask.trim().isNotEmpty ||
      currentStatus.trim().isNotEmpty ||
      unreadNpcCount > 0 ||
      unclaimedMailCount > 0 ||
      bookmarkCount > 0 ||
      memoryCount > 0 ||
      mapHint.trim().isNotEmpty;
}

class _PreparedChatRequest {
  const _PreparedChatRequest({
    required this.messages,
    required this.epoch,
    required this.gameState,
    required this.userProfile,
    required this.npcProfiles,
    required this.worldBooks,
    required this.runtimeAddendum,
    required this.memorySummaries,
    required this.estimatedTokens,
    required this.promptDiagnostics,
  });

  final List<ChatMessage> messages;
  final PromptCacheEpoch epoch;
  final GameStateSnapshot gameState;
  final UserProfile? userProfile;
  final List<NpcProfile> npcProfiles;
  final List<WorldBookEntry> worldBooks;
  final String runtimeAddendum;
  final List<CharacterMemorySummary> memorySummaries;
  final int estimatedTokens;
  final AiPromptDiagnostics promptDiagnostics;
}

class AppStateController extends ChangeNotifier {
  AppStateController({
    required LocalStore store,
    required LlmApiClient apiClient,
    required MemoryService memoryService,
    AiReplyPipeline? aiReplyPipeline,
  })  : _store = store,
        _apiClient = apiClient,
        _memoryService = memoryService,
        _aiReplyPipeline =
            aiReplyPipeline ?? AiReplyPipeline(client: apiClient) {
    _musicPlayerStateSubscription =
        _musicPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleMusicTrackCompleted();
      }
    });
  }

  final LocalStore _store;
  final LlmApiClient _apiClient;
  final MemoryService _memoryService;
  final AiReplyPipeline _aiReplyPipeline;
  final TokenBudgetPlanner _tokenBudgetPlanner = const TokenBudgetPlanner();
  final NpcRuntimeEngine _npcRuntimeEngine = const NpcRuntimeEngine();
  final MapTurnEngine _mapTurnEngine = const MapTurnEngine();
  final AudioPlayer _musicPlayer = AudioPlayer();

  final List<CharacterProfile> _characters = <CharacterProfile>[];
  final List<UserProfile> _userProfiles = <UserProfile>[];
  final List<ToolResult> _toolResults = <ToolResult>[];
  final List<FanficResult> _fanficResults = <FanficResult>[];
  final List<NpcProfile> _npcProfiles = <NpcProfile>[];
  final List<NpcMigrationRecord> _npcMigrations = <NpcMigrationRecord>[];
  final List<WorldBookEntry> _worldBooks = <WorldBookEntry>[];
  final List<WorldCalendarEvent> _worldCalendarEvents = <WorldCalendarEvent>[];
  final List<SettingsPreset> _settingsPresets = <SettingsPreset>[];
  final List<SaveSnapshot> _saveSnapshots = <SaveSnapshot>[];
  final List<QuarantinedDataRecord> _quarantinedDataRecords =
      <QuarantinedDataRecord>[];
  final List<PromptCacheMetric> _promptCacheMetrics = <PromptCacheMetric>[];
  final List<BackgroundTrack> _musicTracks = <BackgroundTrack>[];
  final Map<String, DialogueHistory> _historyCache =
      <String, DialogueHistory>{};
  final Map<String, CharacterMemory> _memoryCache = <String, CharacterMemory>{};
  final Map<String, GameStateSnapshot> _gameStateCache =
      <String, GameStateSnapshot>{};
  final Map<String, MapWorldState> _mapStateCache = <String, MapWorldState>{};
  final Map<String, List<NpcChatMessage>> _npcMessagesCache =
      <String, List<NpcChatMessage>>{};
  final Map<String, Timer> _summaryTimers = <String, Timer>{};
  final Map<String, Timer> _npcExtractionTimers = <String, Timer>{};
  final Map<String, Timer> _npcProactiveTimers = <String, Timer>{};
  final Set<String> _summarizingCharacterIds = <String>{};
  final Set<String> _extractingNpcCharacterIds = <String>{};
  final Set<String> _generatingNpcProactiveCharacterIds = <String>{};
  final Map<String, int> _lastNpcExtractionMessageCounts = <String, int>{};
  StreamSubscription<PlayerState>? _musicPlayerStateSubscription;

  AppSettings _settings = AppSettings.initial();
  GamificationState _gamification = GamificationState.initial();
  MusicPlaybackState _musicState = MusicPlaybackState.initial();
  String? _selectedCharacterId;
  String? _installId;
  bool _isInitializing = true;
  bool _initializationInFlight = false;
  String _initializationPhase = '准备本地数据';
  Object? _initializationError;
  StackTrace? _initializationStackTrace;
  bool _isSending = false;
  bool _isDataMutationInProgress = false;
  String _npcMigrationBuildStage = '';
  bool _isMapGenerating = false;
  bool _isGameplaySystemGenerating = false;
  bool _cancelCurrentReply = false;
  LlmCancellationToken? _activeReplyCancellation;
  bool _shouldShowTutorial = false;
  bool _shouldShowReleaseNotice = false;
  int _currentTabIndex = 0;
  String? _streamingMessageId;
  String? _lastToolResultId;
  ToolResult? _ephemeralToolResult;
  String? _lastFanficResultId;
  TurnDirective? _activeTurnDirective;
  String? _activeNpcReplyingId;
  String? _pendingNpcLetterNotice;
  int _streamingElapsedSeconds = 0;
  Timer? _streamingElapsedTimer;
  Timer? _musicProgressTimer;
  DateTime? _musicPanelOpenedAt;
  DateTime? _lastMusicPausedAt;
  DateTime? _lastMusicResumeAttemptAt;
  String? _activeMusicPlaybackUri;
  DateTime? _lastStreamingUiUpdateAt;
  final Set<String> _musicRoundTrackIds = <String>{};
  String? _lastRecordedTraceId;

  bool get isInitializing => _isInitializing;

  String get initializationPhase => _initializationPhase;

  bool get hasInitializationError => _initializationError != null;

  String get initializationErrorSummary {
    final error = _initializationError;
    if (error == null) {
      return '';
    }
    if (error is LocalDataCorruptionException) {
      return error.message;
    }
    return '本地数据加载失败（${error.runtimeType}）。';
  }

  String get initializationDiagnostics => <String>[
        '未完剧场数据初始化诊断',
        '版本：$currentSaveAppVersion',
        '阶段：$_initializationPhase',
        '错误类型：${_initializationError.runtimeType}',
        '错误：$_initializationError',
        if (_initializationStackTrace != null) '堆栈：$_initializationStackTrace',
      ].join('\n');

  bool get isSending => _isSending || _isDataMutationInProgress;

  bool get isDataMutationInProgress => _isDataMutationInProgress;
  String get npcMigrationBuildStage => _npcMigrationBuildStage;

  bool get isMapGenerating => _isMapGenerating;

  bool get shouldShowTutorial => _shouldShowTutorial;

  bool get shouldShowReleaseNotice => _shouldShowReleaseNotice;

  bool get hasPendingUserMessages =>
      _hasPendingUserMessages(_historyFor(_selectedCharacterId).messages);

  int get currentTabIndex => _currentTabIndex;

  String? get streamingMessageId => _streamingMessageId;

  int get streamingElapsedSeconds => _streamingElapsedSeconds;

  void cancelCurrentReply() {
    if (!_isSending || _streamingMessageId == null) {
      return;
    }
    _cancelCurrentReply = true;
    _activeReplyCancellation?.cancel();
    notifyListeners();
  }

  AppSettings get settings => _settings;

  GamificationState get gamification => _gamification;

  List<BackgroundTrack> get musicTracks => List.unmodifiable(_musicTracks);

  MusicPlaybackState get musicState => _musicState.normalized(_musicTracks);

  bool ownsMusicTrack(String trackId) =>
      _musicTracks.any((track) => track.id == trackId);

  String get currentBubbleFrameId =>
      _gamification.frameForCharacter(_selectedCharacterId);

  List<SettingsPreset> get settingsPresets =>
      List.unmodifiable(_settingsPresets);

  List<PromptCacheMetric> get currentPromptCacheMetrics {
    final characterId = _selectedCharacterId;
    return List<PromptCacheMetric>.unmodifiable(
      _promptCacheMetrics
          .where((metric) => metric.characterId == characterId)
          .take(20),
    );
  }

  String? get installId => _installId;

  List<CharacterProfile> get characters => List.unmodifiable(
        _characters.where((character) => !character.isStoryBranch),
      );

  List<CharacterProfile> get allCharacters => List.unmodifiable(_characters);

  List<UserProfile> get userProfiles => List.unmodifiable(_userProfiles);

  List<ToolResult> get toolResults => List.unmodifiable(_toolResults);

  List<FanficResult> get fanficResults => List.unmodifiable(_fanficResults);

  List<NpcProfile> get npcProfiles => List.unmodifiable(_npcProfiles);

  List<NpcMigrationRecord> get npcMigrations =>
      List.unmodifiable(_npcMigrations);

  NpcMigrationRecord? get currentNpcMigrationRecord {
    final character = currentCharacter;
    if (character == null || !character.isNpcMigration) {
      return null;
    }
    return npcMigrationForCharacter(character.id);
  }

  List<WorldBookEntry> get worldBooks => List.unmodifiable(_worldBooks);

  DataHealthReport get dataHealthReport => DataHealthService.inspect(
        characters: _characters,
        npcs: _npcProfiles,
        migrations: _npcMigrations,
        worldBooks: _worldBooks,
        snapshots: _saveSnapshots,
        histories: _historyCache.values,
        gameStates: _gameStateCache.values,
        mapStates: _mapStateCache.values,
      );

  PromptDiagnosticsSnapshot? get latestPromptDiagnostics =>
      StoryInsightService.latestPromptDiagnostics(_aiReplyPipeline.traceLogger);

  MapObjectiveBoard get currentMapObjectiveBoard =>
      StoryInsightService.buildMapObjectiveBoard(
        gameState: currentGameState,
        mapState: currentMapState,
      );

  List<NpcEnsembleInsight> get currentNpcEnsemble =>
      StoryInsightService.buildNpcEnsemble(
        npcs: currentWorldNpcProfiles,
        mapState: currentMapState,
      );

  List<StoryTimelineEntry> get currentStoryTimeline =>
      StoryInsightService.buildTimeline(
        messages: currentHistory.messages,
        gameState: currentGameState,
        mapState: currentMapState,
        npcs: currentWorldNpcProfiles,
        calendarEvents: currentWorldCalendarEvents,
      );

  List<WorldBookPreviewItem> get currentWorldBookPreview {
    final character = currentCharacter;
    if (character == null) {
      return const <WorldBookPreviewItem>[];
    }
    return StoryInsightService.previewWorldBooks(
      entries: _worldBooks,
      characterId: character.id,
      rootCharacterId: character.rootCharacterId,
      contextMessages: currentHistory.messages,
      gameState: currentGameState,
      runtimeAddendum: _buildRuntimeAddendum(character.id),
    );
  }

  List<SaveSnapshot> get currentCharacterSaveSnapshots {
    final character = currentCharacter;
    if (character == null) {
      return const <SaveSnapshot>[];
    }
    final rootId = character.rootCharacterId;
    final ids = <String>{
      rootId,
      ..._characters
          .where((item) => item.branchSourceCharacterId == rootId)
          .map((item) => item.id),
    };
    return _saveSnapshots
        .where((snapshot) => ids.contains(snapshot.characterId))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<SaveSnapshot> get recoverableSaveSnapshots =>
      List<SaveSnapshot>.unmodifiable(
        _saveSnapshots.toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  List<QuarantinedDataRecord> get quarantinedDataRecords =>
      List<QuarantinedDataRecord>.unmodifiable(_quarantinedDataRecords);

  bool get hasQuarantinedData => _quarantinedDataRecords.isNotEmpty;

  ContinueDashboard get continueDashboard {
    final character = currentCharacter;
    if (character == null) {
      return const ContinueDashboard(
        characterName: '未选择角色',
        lastMessagePreview: '',
        lastMessageAt: null,
        currentTask: '',
        currentStatus: '',
        unreadNpcCount: 0,
        unclaimedMailCount: 0,
        bookmarkCount: 0,
        memoryCount: 0,
        mapHint: '',
      );
    }
    final history = _historyFor(character.id);
    final lastMessage = history.messages.isEmpty ? null : history.messages.last;
    final state = _gameStateFor(character.id);
    final mapState = _mapStateFor(character.id);
    final mapHint = character.mapModeEnabled
        ? [
            if (mapState.currentLocationName.trim().isNotEmpty)
              mapState.currentLocationName.trim(),
            if (mapState.currentScene.trim().isNotEmpty)
              mapState.currentScene.trim(),
          ].join(' · ')
        : '';

    return ContinueDashboard(
      characterName: character.name,
      lastMessagePreview: _plainPreview(lastMessage?.content ?? '', limit: 96),
      lastMessageAt: lastMessage?.timestamp,
      currentTask: state.mainTask.trim(),
      currentStatus: state.status.trim(),
      unreadNpcCount: _currentNpcUnreadCountFor(character.id),
      unclaimedMailCount: _gamification.unclaimedMailboxCount,
      bookmarkCount:
          history.messages.where((message) => message.isBookmarked).length,
      memoryCount: _memoryFor(character.id).summaries.length,
      mapHint: _plainPreview(mapHint, limit: 96),
    );
  }

  TurnDirective? get activeTurnDirective => _activeTurnDirective;

  List<WorldCalendarEvent> get currentWorldCalendarEvents {
    final characterId = _selectedCharacterId;
    if (characterId == null) {
      return const <WorldCalendarEvent>[];
    }
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    return _worldCalendarEvents
        .where((event) =>
            event.characterId == characterId || event.characterId == rootId)
        .toList(growable: false)
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  }

  bool get isNpcReplying => _activeNpcReplyingId != null;

  bool isNpcReplyingTo(String npcId) => _activeNpcReplyingId == npcId;

  String? get pendingNpcLetterNotice => _pendingNpcLetterNotice;

  List<NpcProfile> get currentCharacterNpcProfiles {
    final characterId = _selectedCharacterId;
    if (characterId == null) {
      return const <NpcProfile>[];
    }
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    final branchCutoff = _npcVisibilityCutoffForCharacter(characterId);
    final profiles = _npcProfiles
        .where((profile) => _isNpcProfileVisibleForCharacter(
              profile,
              characterId,
              rootId,
              branchCutoff: branchCutoff,
            ))
        .toList(growable: false);
    return _dedupeNpcProfilesForDisplay(profiles)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<NpcProfile> get currentWorldNpcProfiles {
    final characterId = _selectedCharacterId;
    if (characterId == null) {
      return const <NpcProfile>[];
    }
    return worldNpcProfilesForCharacter(characterId);
  }

  List<NpcProfile> worldNpcProfilesForCharacter(String characterId) {
    final trimmed = characterId.trim();
    if (trimmed.isEmpty) {
      return const <NpcProfile>[];
    }
    final rootId = _findCharacter(trimmed)?.rootCharacterId ?? trimmed;
    final branchCutoff = _npcVisibilityCutoffForCharacter(trimmed);
    final profiles = _npcProfiles
        .where((profile) => _isNpcProfileVisibleForCharacter(
              profile,
              trimmed,
              rootId,
              branchCutoff: branchCutoff,
            ))
        .toList(growable: false);
    return _dedupeNpcProfilesForDisplay(profiles)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  bool _isNpcProfileVisibleForCharacter(
    NpcProfile profile,
    String characterId,
    String rootId, {
    DateTime? branchCutoff,
  }) {
    if (profile.globalBinding || profile.isBoundTo(characterId)) {
      return true;
    }
    if (profile.characterId == characterId) {
      return true;
    }
    if (characterId == rootId) {
      return profile.characterId == rootId || profile.isBoundTo(rootId);
    }
    final inheritedFromRoot =
        profile.characterId == rootId || profile.isBoundTo(rootId);
    if (!inheritedFromRoot) {
      return false;
    }
    return branchCutoff != null && !profile.createdAt.isAfter(branchCutoff);
  }

  DateTime? _npcVisibilityCutoffForCharacter(String characterId) {
    final character = _findCharacter(characterId);
    if (character == null || !character.isStoryBranch) {
      return null;
    }
    final history = _historyFor(character.id);
    if (history.messages.isEmpty) {
      return null;
    }
    final originId = character.branchOriginMessageId?.trim() ?? '';
    ChatMessage? originMessage;
    if (originId.isNotEmpty) {
      for (final message in history.messages) {
        if (message.id == originId) {
          originMessage = message;
          break;
        }
      }
    }
    originMessage ??= history.messages.last;
    return _npcVisibilityCutoffForMessage(originMessage);
  }

  DateTime _npcVisibilityCutoffForMessage(ChatMessage message) {
    var cutoff = message.timestamp;
    final snapshot = message.gameStateSnapshot;
    if (snapshot != null) {
      try {
        final state = GameStateSnapshot.fromJson(snapshot);
        if (state.updatedAt.isAfter(cutoff)) {
          cutoff = state.updatedAt;
        }
      } catch (_) {
        // Ignore damaged legacy snapshots and fall back to message time.
      }
    }
    return cutoff.add(const Duration(seconds: 5));
  }

  List<NpcProfile> get npcRoleCardLibrary {
    final profiles = _npcProfiles
        .where((profile) => profile.hasReusableRoleCard)
        .toList(growable: false);
    return _dedupeNpcProfilesForDisplay(profiles)
      ..sort((a, b) {
        final bindingOrder =
            (b.companionEnabled ? 1 : 0).compareTo(a.companionEnabled ? 1 : 0);
        if (bindingOrder != 0) {
          return bindingOrder;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  List<StoryInventoryItem> get currentStoryInventory {
    return List.unmodifiable(
        _gameStateFor(_selectedCharacterId).storyInventory);
  }

  List<NpcProfile> get currentCharacterCompanionNpcProfiles {
    final characterId = _selectedCharacterId;
    if (characterId == null) {
      return const <NpcProfile>[];
    }
    return companionNpcProfilesForCharacter(characterId);
  }

  List<NpcProfile> companionNpcProfilesForCharacter(String characterId) {
    final trimmed = characterId.trim();
    if (trimmed.isEmpty) {
      return const <NpcProfile>[];
    }
    final rootId = _findCharacter(trimmed)?.rootCharacterId ?? trimmed;
    return _npcProfiles
        .where((profile) =>
            profile.companionEnabled &&
            (profile.isBoundTo(trimmed) || profile.isBoundTo(rootId)))
        .toList(growable: false)
      ..sort((a, b) {
        final aGlobal = a.globalBinding ? 1 : 0;
        final bGlobal = b.globalBinding ? 1 : 0;
        final globalOrder = bGlobal.compareTo(aGlobal);
        if (globalOrder != 0) {
          return globalOrder;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  List<NpcProfile> _dedupeNpcProfilesForDisplay(List<NpcProfile> profiles) {
    final byKey = <String, NpcProfile>{};
    for (final profile in profiles) {
      final key = _npcDisplayDedupeKey(profile);
      final existing = byKey[key];
      if (existing == null || _preferNpcProfile(profile, existing)) {
        byKey[key] = profile;
      }
    }
    return byKey.values.toList(growable: false);
  }

  bool _preferNpcProfile(NpcProfile candidate, NpcProfile existing) {
    final candidateScore = _npcProfileCompletenessScore(candidate);
    final existingScore = _npcProfileCompletenessScore(existing);
    if (candidateScore != existingScore) {
      return candidateScore > existingScore;
    }
    return candidate.updatedAt.isAfter(existing.updatedAt);
  }

  int _npcProfileCompletenessScore(NpcProfile profile) {
    var score = 0;
    if (profile.hasReusableRoleCard) score += 8;
    if (profile.companionEnabled) score += 4;
    if (profile.globalBinding) score += 2;
    if (profile.description.trim().isNotEmpty) score += 1;
    if (profile.impression.trim().isNotEmpty) score += 1;
    score += profile.boundCharacterIds.length.clamp(0, 3);
    return score;
  }

  String _npcDedupeKey(NpcProfile profile) {
    final name = _normalizeNpcName(profile.name);
    final source = profile.characterId.trim();
    final description = _stableTextFingerprint(profile.description);
    if (description.isNotEmpty) {
      return 'desc|$name|$source|$description';
    }
    final roleCard = _stableTextFingerprint(profile.roleCard);
    if (roleCard.isNotEmpty) {
      return 'card|$name|$source|$roleCard';
    }
    return 'name|$name|$source';
  }

  String _npcDisplayDedupeKey(NpcProfile profile) {
    final name = _normalizeNpcName(profile.name);
    final description = _stableTextFingerprint(profile.description);
    if (description.isNotEmpty) {
      return 'desc|$name|$description';
    }
    final roleCard = _stableTextFingerprint(profile.roleCard);
    if (roleCard.isNotEmpty) {
      return 'card|$name|$roleCard';
    }
    return 'name|$name';
  }

  String _stableTextFingerprint(String value) {
    final normalized =
        value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.length <= 48 ? normalized : normalized.substring(0, 48);
  }

  List<NpcProfile> _npcProfilesForRuntime(String characterId) {
    final trimmed = characterId.trim();
    if (trimmed.isEmpty) {
      return const <NpcProfile>[];
    }
    final rootId = _findCharacter(trimmed)?.rootCharacterId ?? trimmed;
    final branchCutoff = _npcVisibilityCutoffForCharacter(trimmed);
    final profiles = _npcProfiles
        .where((profile) => _isNpcProfileVisibleForCharacter(
              profile,
              trimmed,
              rootId,
              branchCutoff: branchCutoff,
            ))
        .toList(growable: false);
    return _dedupeNpcProfilesForDisplay(profiles)
      ..sort((a, b) {
        final companionOrder =
            (b.companionEnabled ? 1 : 0).compareTo(a.companionEnabled ? 1 : 0);
        if (companionOrder != 0) {
          return companionOrder;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  int get currentNpcUnreadCount {
    final characterId = _selectedCharacterId;
    if (characterId == null) {
      return 0;
    }
    return _currentNpcUnreadCountFor(characterId);
  }

  int _currentNpcUnreadCountFor(String characterId) {
    var count = 0;
    final profiles = worldNpcProfilesForCharacter(characterId);
    for (final profile in profiles) {
      final readAt = _npcThreadReadAt(profile.id, characterId: characterId);
      final messages =
          _npcMessagesCache[profile.id] ?? const <NpcChatMessage>[];
      count += messages
          .where(
            (message) =>
                message.role == NpcMessageRole.npc &&
                message.timestamp.isAfter(readAt),
          )
          .length;
    }
    return count;
  }

  int get mailboxUnreadCount => _gamification.unclaimedMailboxCount;

  List<MailboxEntry> get mailboxEntries => List.unmodifiable(
        _gamification.mailbox,
      );

  bool canUseTheme(String themeId) {
    if (_gamification.customThemeById(themeId) != null) {
      return true;
    }
    final variant = AppThemeVariant.byId(themeId);
    if (variant.id != themeId.trim()) {
      return false;
    }
    return variant.unlockCost <= 0 || _gamification.ownsTheme(variant.id);
  }

  int themeUnlockCost(String themeId) {
    if (_gamification.customThemeById(themeId) != null) {
      return 0;
    }
    final variant = AppThemeVariant.byId(themeId);
    if (variant.id != themeId.trim()) {
      return 0;
    }
    return variant.unlockCost;
  }

  NpcProfile? npcProfileById(String npcId) {
    for (final profile in _npcProfiles) {
      if (profile.id == npcId) {
        return profile;
      }
    }
    return null;
  }

  List<NpcMigrationRecord> npcMigrationsFor(String npcId) {
    return _npcMigrations
        .where((record) => record.sourceNpcId == npcId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  NpcMigrationRecord? npcMigrationById(String? recordId) {
    if (recordId == null || recordId.trim().isEmpty) {
      return null;
    }
    for (final record in _npcMigrations) {
      if (record.id == recordId) {
        return record;
      }
    }
    return null;
  }

  NpcMigrationRecord? npcMigrationForCharacter(String characterId) {
    for (final record in _npcMigrations) {
      if (record.createdCharacterId == characterId) {
        return record;
      }
    }
    final character = _findCharacter(characterId);
    return npcMigrationById(character?.sourceMigrationRecordId);
  }

  List<NpcChatMessage> npcMessagesFor(String npcId) {
    return List.unmodifiable(_npcMessagesCache[npcId] ?? const []);
  }

  int npcUnreadCountFor(String npcId) {
    final profile = npcProfileById(npcId);
    if (profile == null) {
      return 0;
    }
    final readAt = _npcThreadReadAt(npcId, characterId: profile.characterId);
    return (_npcMessagesCache[npcId] ?? const <NpcChatMessage>[])
        .where(
          (message) =>
              message.role == NpcMessageRole.npc &&
              message.timestamp.isAfter(readAt),
        )
        .length;
  }

  bool hasPendingNpcUserMessages(String npcId) {
    return _hasPendingNpcUserMessages(_npcMessagesCache[npcId] ?? const []);
  }

  List<ToolResult> get currentCharacterToolResults {
    final characterId = _selectedCharacterId;
    if (characterId == null) {
      return const <ToolResult>[];
    }
    return _toolResults
        .where((result) => result.characterId == characterId)
        .toList(growable: false);
  }

  ToolResult? get lastGeneratedToolResult {
    final ephemeral = _ephemeralToolResult;
    if (ephemeral != null) {
      return ephemeral;
    }
    final resultId = _lastToolResultId;
    if (resultId == null) {
      return null;
    }
    for (final result in _toolResults) {
      if (result.id == resultId) {
        return result;
      }
    }
    return null;
  }

  List<FanficResult> get currentCharacterFanficResults {
    final characterId = _selectedCharacterId;
    if (characterId == null) {
      return const <FanficResult>[];
    }
    return _fanficResults
        .where((result) => result.characterId == characterId)
        .toList(growable: false);
  }

  FanficResult? get lastGeneratedFanficResult {
    final resultId = _lastFanficResultId;
    if (resultId == null) {
      return null;
    }
    for (final result in _fanficResults) {
      if (result.id == resultId) {
        return result;
      }
    }
    return null;
  }

  String? get selectedCharacterId => _selectedCharacterId;

  CharacterProfile? get currentCharacter =>
      _findCharacter(_selectedCharacterId);

  String characterNameFor(String? characterId) {
    final character = _findCharacter(characterId);
    if (character == null) {
      return '未知世界';
    }
    return character.name.trim().isEmpty ? '未命名世界' : character.name.trim();
  }

  CharacterProfile? get currentRootCharacter {
    final character = currentCharacter;
    if (character == null) {
      return null;
    }
    return _findCharacter(character.rootCharacterId) ?? character;
  }

  UserProfile? get currentBoundUserProfile =>
      _findBoundUserProfile(_selectedCharacterId);

  DialogueHistory get currentHistory => _historyFor(_selectedCharacterId);

  CharacterMemory get currentMemory => _memoryFor(_selectedCharacterId);

  CharacterMemory memoryForCharacter(String characterId) =>
      _memoryFor(characterId);

  GameStateSnapshot get currentGameState => _gameStateFor(_selectedCharacterId);

  GameStateSnapshot gameplayStateFor(String characterId) =>
      _gameStateFor(characterId);

  Map<String, dynamic> gameplayValuesFor(String characterId) =>
      Map<String, dynamic>.unmodifiable(
        _gameStateFor(characterId).customVariables,
      );

  List<String> gameplayVariableChangesFor(
    String characterId, {
    bool playerFacingOnly = false,
  }) =>
      List<String>.unmodifiable(
        playerFacingOnly
            ? _gameStateFor(characterId).gameplayPlayerVariableChanges
            : _gameStateFor(characterId).gameplayVariableChanges,
      );

  List<String> gameplayVariableWarningsFor(String characterId) =>
      List<String>.unmodifiable(
        _gameStateFor(characterId).gameplayVariableWarnings,
      );

  MapWorldState get currentMapState => _mapStateFor(_selectedCharacterId);

  bool isMessageStreaming(String messageId) => _streamingMessageId == messageId;

  List<CharacterProfile> storyBranchesFor(String characterId) {
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    final branches = _characters
        .where((character) => character.branchSourceCharacterId == rootId)
        .toList(growable: false);
    branches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(branches);
  }

  Future<void> initialize() async {
    if (_initializationInFlight) {
      return;
    }
    _initializationInFlight = true;
    _isInitializing = true;
    _initializationError = null;
    _initializationStackTrace = null;
    _initializationPhase = '读取应用设置';
    notifyListeners();

    try {
      await _store.recoverPendingTurnCommits();
      _quarantinedDataRecords
        ..clear()
        ..addAll(await _store.loadQuarantinedDataRecords());
      _installId = await _store.loadOrCreateInstallId();
      _settings = await _store.loadSettings();
      if (_settings.cacheIsolationId.trim().isEmpty &&
          (_installId?.trim().isNotEmpty ?? false)) {
        _settings = _settings.copyWith(cacheIsolationId: _installId!.trim());
        await _store.saveSettings(_settings);
      }
      _settingsPresets
        ..clear()
        ..addAll(await _store.loadSettingsPresets());
      _promptCacheMetrics
        ..clear()
        ..addAll(await _store.loadPromptCacheMetrics());
      _gamification = await _store.loadGamificationState();
      _gamification = _applyAchievementUnlocks(
        _ensureVersionGiftMail(
          _gamification.migrateStickerCosmeticsToMailbox(),
        ),
      );
      _musicTracks
        ..clear()
        ..addAll(await _store.loadMusicTracks());
      _musicState = (await _store.loadMusicPlaybackState())
          .normalized(_musicTracks)
          .copyWith(isPlaying: false);
      await _store.saveMusicPlaybackState(_musicState);
      _registerCustomThemes();
      _shouldShowTutorial = !await _store.hasSeenTutorial();
      _shouldShowReleaseNotice =
          !await _store.hasSeenReleaseNotice(currentReleaseNotes.id);

      _setInitializationPhase('读取角色与世界资料');
      final loadedCharacters = await _store.loadCharacters();
      final normalizedCharacters = _normalizeCharacters(loadedCharacters);
      final loadedUserProfiles = await _store.loadUserProfiles();
      final loadedToolResults = await _store.loadToolResults();
      final loadedFanficResults = await _store.loadFanficResults();
      final loadedNpcProfiles = await _store.loadNpcProfiles();
      final loadedNpcMigrations = await _store.loadNpcMigrations();
      final loadedWorldBooks = await _store.loadWorldBooks();
      final loadedWorldCalendarEvents = await _store.loadWorldCalendarEvents();
      final loadedSaveSnapshots = await _store.loadSaveSnapshots();

      _setInitializationPhase('校验本地存档');
      _characters
        ..clear()
        ..addAll(normalizedCharacters);
      _userProfiles
        ..clear()
        ..addAll(
          _normalizeUserProfiles(loadedUserProfiles, normalizedCharacters),
        );
      _toolResults
        ..clear()
        ..addAll(
          _normalizeToolResults(loadedToolResults, normalizedCharacters),
        );
      _fanficResults
        ..clear()
        ..addAll(
          _normalizeFanficResults(loadedFanficResults, normalizedCharacters),
        );
      _npcProfiles
        ..clear()
        ..addAll(
          _normalizeNpcProfiles(loadedNpcProfiles, normalizedCharacters),
        );
      _npcMigrations
        ..clear()
        ..addAll(
          _normalizeNpcMigrations(
            loadedNpcMigrations,
          ),
        );
      _worldBooks
        ..clear()
        ..addAll(
          _normalizeWorldBooks(loadedWorldBooks, normalizedCharacters),
        );
      _worldCalendarEvents
        ..clear()
        ..addAll(
          _normalizeWorldCalendarEvents(
            loadedWorldCalendarEvents,
            normalizedCharacters,
          ),
        );
      _saveSnapshots
        ..clear()
        ..addAll(
          _normalizeSaveSnapshots(loadedSaveSnapshots, normalizedCharacters),
        );

      if (_characters.isEmpty) {
        _characters.add(buildTutorialDemoCharacter());
        await _store.saveCharacters(_characters);
      } else if (!_characterListsEqual(loadedCharacters, _characters)) {
        await _store.saveCharacters(_characters);
      }
      if (!_userProfileListsEqual(loadedUserProfiles, _userProfiles)) {
        await _store.saveUserProfiles(_userProfiles);
      }
      if (!_toolResultListsEqual(loadedToolResults, _toolResults)) {
        await _store.saveToolResults(_toolResults);
      }
      if (!_fanficResultListsEqual(loadedFanficResults, _fanficResults)) {
        await _store.saveFanficResults(_fanficResults);
      }
      if (!_npcProfileListsEqual(loadedNpcProfiles, _npcProfiles)) {
        await _store.saveNpcProfiles(_npcProfiles);
      }
      if (!_npcMigrationListsEqual(loadedNpcMigrations, _npcMigrations)) {
        await _store.saveNpcMigrations(_npcMigrations);
      }
      if (!_worldBookListsEqual(loadedWorldBooks, _worldBooks)) {
        await _store.saveWorldBooks(_worldBooks);
      }
      if (!_worldCalendarEventListsEqual(
        loadedWorldCalendarEvents,
        _worldCalendarEvents,
      )) {
        await _store.saveWorldCalendarEvents(_worldCalendarEvents);
      }
      if (!_saveSnapshotListsEqual(loadedSaveSnapshots, _saveSnapshots)) {
        await _store.saveSaveSnapshots(_saveSnapshots);
      }

      _setInitializationPhase('恢复上次剧情现场');
      _selectedCharacterId = await _store.loadSelectedCharacterId();
      if (_findCharacter(_selectedCharacterId) == null) {
        _selectedCharacterId = _characters
            .firstWhere(
              (character) => !character.isStoryBranch,
              orElse: () => _characters.first,
            )
            .id;
        await _store.saveSelectedCharacterId(_selectedCharacterId);
      }

      if (_selectedCharacterId != null) {
        await _loadCharacterState(_selectedCharacterId!);
      }

      _setInitializationPhase('完成剧场布景');
      await _updateGamification(
        (state) => state
            .incrementStat('firstOpen')
            .setStatMax('maxActiveCharacters', characters.length),
        notify: false,
      );
      _quarantinedDataRecords
        ..clear()
        ..addAll(await _store.loadQuarantinedDataRecords());
    } catch (error, stackTrace) {
      _initializationError = error;
      _initializationStackTrace = stackTrace;
      try {
        _quarantinedDataRecords
          ..clear()
          ..addAll(await _store.loadQuarantinedDataRecords());
      } catch (_) {
        // Keep the original initialization error as the actionable failure.
      }
    } finally {
      _isInitializing = false;
      _initializationInFlight = false;
      notifyListeners();
    }
  }

  Future<void> retryInitialization() => initialize();

  void _setInitializationPhase(String phase) {
    if (_initializationPhase == phase) {
      return;
    }
    _initializationPhase = phase;
    notifyListeners();
  }

  Future<void> completeTutorial({required bool skipped}) async {
    _shouldShowTutorial = false;
    await _store.setTutorialSeen(true);
    await _updateGamification(
      (state) => state.incrementStat(
        skipped ? 'totalTutorialSkips' : 'totalTutorialCompletions',
      ),
      notify: false,
    );
    notifyListeners();
  }

  Future<void> completeReleaseNotice() async {
    if (!_shouldShowReleaseNotice) {
      await _store.setReleaseNoticeSeen(currentReleaseNotes.id, true);
      return;
    }

    _shouldShowReleaseNotice = false;
    await _store.setReleaseNoticeSeen(currentReleaseNotes.id, true);
    notifyListeners();
  }

  Future<String?> claimMailboxReward(String mailId) async {
    final before = _gamification.coins;
    await _updateGamification((state) => state.claimMailboxEntry(mailId));
    if (_gamification.coins == before) {
      return '这封邮件已经领取过了。';
    }
    return null;
  }

  Future<String?> claimAllMailboxRewards() async {
    final before = _gamification.coins;
    await _updateGamification((state) => state.claimAllMailboxRewards());
    if (_gamification.coins == before) {
      return '邮箱里暂时没有可领取的啥币。';
    }
    return null;
  }

  void consumeNpcLetterNotice() {
    if (_pendingNpcLetterNotice == null) {
      return;
    }
    _pendingNpcLetterNotice = null;
    notifyListeners();
  }

  void setTurnDirective(TurnDirective? directive) {
    _activeTurnDirective = directive == null || directive.isEmpty
        ? null
        : TurnDirective(
            mood: directive.mood.trim(),
            focus: directive.focus.trim(),
            note: directive.note.trim(),
            intensity: directive.intensity.clamp(1, 5),
          );
    notifyListeners();
  }

  void clearTurnDirective() {
    if (_activeTurnDirective == null) {
      return;
    }
    _activeTurnDirective = null;
    notifyListeners();
  }

  Future<List<GlobalSearchResult>> searchEverything(String query) async {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    if (terms.isEmpty) {
      return const <GlobalSearchResult>[];
    }

    var results = <GlobalSearchResult>[];
    bool matches(String value) {
      final lower = value.toLowerCase();
      return terms.every(lower.contains);
    }

    void addIfMatch({
      required GlobalSearchResultType type,
      required String title,
      required String subtitle,
      required String body,
      required DateTime updatedAt,
      String? characterId,
      String? messageId,
      String? npcId,
      String? worldBookId,
      String routeHint = '',
      bool force = false,
    }) {
      final haystack = '$title\n$subtitle\n$body\n$routeHint';
      if (!force && !matches(haystack)) {
        return;
      }
      results.add(
        GlobalSearchResult(
          type: type,
          title: _plainPreview(title, limit: 64),
          subtitle: _plainPreview(subtitle, limit: 84),
          preview: _plainPreview(body, limit: 150),
          updatedAt: updatedAt,
          characterId: characterId,
          messageId: messageId,
          npcId: npcId,
          worldBookId: worldBookId,
          routeHint: routeHint,
        ),
      );
    }

    for (final character in _characters.where((item) => !item.isStoryBranch)) {
      addIfMatch(
        type: GlobalSearchResultType.character,
        title: character.name,
        subtitle: character.description,
        body:
            '${character.prompt}\n${character.hiddenPrompt}\n${character.openingMessage}',
        updatedAt: character.createdAt,
        characterId: character.id,
        routeHint: '角色档案',
      );
    }

    for (final character in _characters) {
      final history = await _ensureHistory(character.id);
      for (final message in history.messages) {
        final forceBookmark = message.isBookmarked &&
            terms.every((term) =>
                '书签 收藏 bookmark'.contains(term) ||
                message.bookmarkNote.toLowerCase().contains(term) ||
                message.content.toLowerCase().contains(term) ||
                character.name.toLowerCase().contains(term));
        addIfMatch(
          type: message.isBookmarked
              ? GlobalSearchResultType.bookmark
              : GlobalSearchResultType.message,
          title: '${message.isBookmarked ? '书签' : '聊天'} · ${character.name}',
          subtitle: [
            message.role.label,
            _formatShortDate(message.timestamp),
            if (message.bookmarkNote.trim().isNotEmpty)
              message.bookmarkNote.trim(),
          ].join(' · '),
          body: message.content,
          updatedAt: message.timestamp,
          characterId: character.id,
          messageId: message.id,
          routeHint: message.isBookmarked ? '消息书签' : '聊天记录',
          force: forceBookmark,
        );
      }
    }

    for (final npc in _npcProfiles) {
      final character = _findCharacter(npc.characterId);
      addIfMatch(
        type: GlobalSearchResultType.npc,
        title: npc.name,
        subtitle: [
          character?.name ?? '未知世界',
          if (npc.companionEnabled) '同行 NPC',
          if (npc.globalBinding) '全局绑定',
          if (npc.bondRoute.stage.trim().isNotEmpty) npc.bondRoute.stage,
        ].join(' · '),
        body:
            '${npc.description}\n${npc.impression}\n${npc.roleCard}\n${npc.bondRoute.route}\n${npc.bondRoute.keywords.join(' ')}',
        updatedAt: npc.updatedAt,
        characterId: npc.characterId,
        npcId: npc.id,
        routeHint: 'NPC 私聊',
      );
      final messages = await _ensureNpcMessages(npc.id);
      for (final message in messages) {
        addIfMatch(
          type: GlobalSearchResultType.npc,
          title: 'NPC 私聊 · ${npc.name}',
          subtitle:
              '${message.role == NpcMessageRole.user ? '你' : npc.name} · ${_formatShortDate(message.timestamp)}',
          body: message.content,
          updatedAt: message.timestamp,
          characterId: npc.characterId,
          npcId: npc.id,
          routeHint: 'NPC 私聊',
        );
      }
    }

    for (final entry in _worldBooks) {
      addIfMatch(
        type: GlobalSearchResultType.worldBook,
        title: entry.title,
        subtitle: [
          if (entry.tags.isNotEmpty) entry.tags.join(' / '),
          if (entry.global) '全局',
          if (entry.boundCharacterIds.isNotEmpty)
            '绑定 ${entry.boundCharacterIds.length} 个角色',
        ].join(' · '),
        body: entry.content,
        updatedAt: entry.updatedAt,
        worldBookId: entry.id,
        routeHint: '世界书',
      );
    }

    for (final result in _toolResults) {
      final character = _findCharacter(result.characterId);
      addIfMatch(
        type: GlobalSearchResultType.tool,
        title: result.toolTitle.trim().isEmpty ? '剧情工具' : result.toolTitle,
        subtitle: character?.name ?? '剧情工具',
        body: result.content,
        updatedAt: result.createdAt,
        characterId: result.characterId,
        routeHint: '剧情工具历史',
      );
    }

    for (final result in _fanficResults) {
      final character = _findCharacter(result.characterId);
      addIfMatch(
        type: GlobalSearchResultType.fanfic,
        title: result.title,
        subtitle: [
          character?.name ?? '同人文',
          result.pairingLabel,
          if (result.inspiration.trim().isNotEmpty) result.inspiration,
        ].join(' · '),
        body: result.content,
        updatedAt: result.createdAt,
        characterId: result.characterId,
        routeHint: '历史同人文',
      );
    }

    for (final record in _npcMigrations) {
      addIfMatch(
        type: GlobalSearchResultType.migration,
        title: record.sourceNpcName,
        subtitle: [
          record.sourceCharacterName,
          record.createdCharacterName,
          NpcMigrationMemoryMode.shortLabel(record.memoryMode),
          NpcMigrationRelationshipLock.shortLabel(record.relationshipLock),
        ].join(' · '),
        body:
            '${record.archiveText}\n${record.sourceDigest}\n${record.worldBookTitle}\n${record.openingMessage}\n${record.farewellOutcome.finalSceneSummary}\n${record.farewellOutcome.relationshipAfterFarewell}\n${record.albumEntries.map((item) => item.content).join('\n')}',
        updatedAt: record.createdAt,
        characterId: record.createdCharacterId,
        npcId: record.sourceNpcId,
        routeHint: '前尘档案馆',
      );
    }

    results = results
        .where(
            (item) => item.preview.trim().isNotEmpty || item.title.isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results.take(80).toList(growable: false);
  }

  Future<void> openSearchResult(GlobalSearchResult result) async {
    final characterId = result.characterId?.trim();
    if (characterId != null &&
        characterId.isNotEmpty &&
        _findCharacter(characterId) != null) {
      await selectCharacter(characterId);
      _currentTabIndex = switch (result.type) {
        GlobalSearchResultType.character => 1,
        GlobalSearchResultType.npc => 2,
        _ => 0,
      };
      notifyListeners();
      return;
    }
    if (result.type == GlobalSearchResultType.worldBook) {
      _currentTabIndex = 1;
    } else if (result.type == GlobalSearchResultType.npc) {
      _currentTabIndex = 2;
    } else {
      _currentTabIndex = 0;
    }
    notifyListeners();
  }

  Future<String?> generateWorldCalendar() async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending) {
      return '当前还有内容正在生成，请稍等。';
    }

    _isSending = true;
    notifyListeners();
    try {
      final history = await _ensureHistory(character.id);
      final memory = await _ensureMemory(character.id);
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: '你是文字游戏的世界事件日历规划助手。只输出 JSON，不要输出解释。',
        userPrompt: '''
请根据当前文字游戏生成 6-10 个后续世界事件日历条目。
这些事件不是立刻发生，而是作为未来剧情可参考的节奏表。
输出 JSON：
{
  "events": [
    {
      "title": "事件标题",
      "timeLabel": "可能发生的时间",
      "stage": "铺垫/发酵/爆发/余波",
      "description": "事件说明"
    }
  ]
}

当前角色：${character.name}
角色设定：
${character.visibleBlurb}

世界书：
${_formatWorldBooksForPrompt(character.id)}

长期记忆：
${memory.summaries.map((item) => '- ${item.summaryText}').take(8).join('\n')}

最近剧情：
${history.messages.reversed.take(12).toList().reversed.map((message) => '${message.role.name}: ${message.content}').join('\n\n')}
''',
        temperature: 0.55,
        topP: 0.9,
      );

      final decoded = _decodeJsonObject(raw);
      final eventsRaw = decoded['events'];
      if (eventsRaw is! List) {
        return '事件日历生成失败：模型没有返回可识别的 events。';
      }
      final nextEvents = eventsRaw
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            return WorldCalendarEvent(
              characterId: character.id,
              title: map['title']?.toString() ?? '',
              timeLabel: map['timeLabel']?.toString() ?? '',
              stage: map['stage']?.toString() ?? '',
              description: map['description']?.toString() ?? '',
            );
          })
          .where((event) =>
              event.title.trim().isNotEmpty &&
              event.description.trim().isNotEmpty)
          .toList(growable: false);
      if (nextEvents.isEmpty) {
        return '事件日历生成失败：没有可保存的事件。';
      }
      _worldCalendarEvents.removeWhere(
        (event) => event.characterId == character.id,
      );
      _worldCalendarEvents.addAll(nextEvents);
      await _store.saveWorldCalendarEvents(_worldCalendarEvents);
      _lastToolResultId = null;
      _ephemeralToolResult = null;
      notifyListeners();
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (error) {
      return '事件日历生成失败：$error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> noteCthulhuGaze() async {
    await _updateGamification(
      (state) => state.incrementStat('totalCthulhuGazes'),
    );
  }

  Future<void> noteCthulhuMenuVisit(int index) async {
    if (_settings.themeId != AppThemeVariant.cthulhu.id ||
        index < 0 ||
        index > 4) {
      return;
    }
    final bit = 1 << index;
    final current = _gamification.stat('cthulhuMenuMask');
    if ((current & bit) == bit) {
      return;
    }
    await _updateGamification(
      (state) => state.setStat('cthulhuMenuMask', current | bit),
    );
  }

  void replayTutorial() {
    if (_shouldShowTutorial) {
      return;
    }

    _shouldShowTutorial = true;
    notifyListeners();
  }

  void setCurrentTabIndex(int index) {
    final safeIndex = index.clamp(0, 4);
    if (_currentTabIndex == safeIndex) {
      return;
    }

    _currentTabIndex = safeIndex;
    notifyListeners();
  }

  Future<void> noteGameHubOpened() async {
    await _updateGamification(
      (state) => state.incrementDailyStat('gameHubOpens'),
    );
  }

  void noteMusicPanelOpened() {
    _musicPanelOpenedAt = DateTime.now();
  }

  Future<String?> pickAndAddMusicTrack() async {
    if (_musicTracks.length >= _musicState.slotCount) {
      return '音频格子已满，可以花 30 啥币解锁新的格子。';
    }
    final file = await pickLocalAudioFileData();
    if (file == null) {
      return null;
    }
    if (file.bytes.isEmpty) {
      return '没有读到音频文件内容，请换一个文件试试。';
    }
    if (file.bytes.length > MusicCatalog.maxAudioFileBytes) {
      return '单个音频不能超过 100MB。';
    }
    final nextTotalBytes =
        _musicTracks.fold<int>(0, (sum, track) => sum + track.sizeBytes) +
            file.bytes.length;
    if (nextTotalBytes > MusicCatalog.maxTotalAudioBytes) {
      return '本地音频总容量不能超过 500MB，请先删除一些旧音频。';
    }

    final draft = BackgroundTrack.create(
      originalName: file.name,
      mimeType: file.mimeType ?? '',
      extension: file.extension ?? _extensionOf(file.name),
      sizeBytes: file.bytes.length,
      storageKey: '',
    );
    final stored = await LocalAudioStorage.saveAudio(
      trackId: draft.id,
      originalName: file.name,
      bytes: file.bytes,
    );
    LocalAudioStorage.releasePlaybackUri(stored.playbackUri);
    final track = draft.copyWith(
      storageKey: stored.storageKey,
      sizeBytes: stored.sizeBytes,
    );
    _musicTracks.add(track);
    _musicState = _musicState
        .copyWith(
          currentTrackId: _musicState.currentTrackId.isEmpty ? track.id : null,
          playlistTrackIds: <String>[
            ..._musicState.playlistTrackIds,
            track.id,
          ],
          isPlaying: false,
        )
        .normalized(_musicTracks);
    await _store.saveMusicTracks(_musicTracks);
    await _store.saveMusicPlaybackState(_musicState);
    await _updateGamification(
      (state) => _withMusicCollectionStats(
        state
            .incrementStat('totalMusicUploads')
            .setStatMax('maxMusicTracksUnlocked', _musicTracks.length),
      ),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> renameMusicTrack(String trackId, String title) async {
    final index = _musicTracks.indexWhere((track) => track.id == trackId);
    if (index < 0) {
      return '没有找到这个音频。';
    }
    _musicTracks[index] = _musicTracks[index].rename(title);
    await _store.saveMusicTracks(_musicTracks);
    notifyListeners();
    return null;
  }

  Future<String?> deleteMusicTrack(String trackId) async {
    final index = _musicTracks.indexWhere((track) => track.id == trackId);
    if (index < 0) {
      return '没有找到这个音频。';
    }
    final track = _musicTracks[index];
    if (_musicState.currentTrackId == track.id && _musicState.isPlaying) {
      await _musicPlayer.stop().timeout(const Duration(seconds: 6));
    }
    await LocalAudioStorage.deleteAudio(track.storageKey);
    _musicTracks.removeAt(index);
    final nextPlaylist = _musicState.playlistTrackIds
        .where((id) => id != track.id)
        .toList(growable: false);
    final nextCurrent = _musicState.currentTrackId == track.id
        ? (nextPlaylist.isEmpty ? '' : nextPlaylist.first)
        : _musicState.currentTrackId;
    _musicState = _musicState
        .copyWith(
          currentTrackId: nextCurrent,
          playlistTrackIds: nextPlaylist,
          isPlaying: false,
        )
        .normalized(_musicTracks);
    _releaseActiveMusicPlaybackUri();
    await _store.saveMusicTracks(_musicTracks);
    await _store.saveMusicPlaybackState(_musicState);
    await _updateGamification(
      (state) => state.incrementStat('totalMusicDeletes'),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> unlockMusicSlot() async {
    if (_gamification.coins < MusicCatalog.slotUnlockCost) {
      final missing = MusicCatalog.slotUnlockCost - _gamification.coins;
      return '啥币不够，还差 $missing 个啥币才能解锁新音频格子。';
    }
    _musicState = _musicState.copyWith(
      slotCount: _musicState.slotCount + 1,
    );
    await _store.saveMusicPlaybackState(_musicState);
    await _updateGamification(
      (state) => state
          .spendCoins(MusicCatalog.slotUnlockCost)
          .incrementStat('totalMusicSlotUnlocks')
          .setStatMax('maxMusicSlots', _musicState.slotCount),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> playMusicTrack(
    String trackId, {
    String source = 'direct',
  }) async {
    final track = MusicCatalog.byId(_musicTracks, trackId);
    if (track == null) {
      return '没有找到这个音频。';
    }
    if (track.storageKey.trim().isEmpty) {
      return '这个音频文件缺失，请重新上传。';
    }
    final playbackUri =
        await LocalAudioStorage.playbackUriFor(track.storageKey);
    if (playbackUri == null || playbackUri.trim().isEmpty) {
      return '本地音频文件缺失，请重新上传。';
    }
    final wasPlaying = _musicState.isPlaying;
    final changed = _musicState.currentTrackId != track.id;
    try {
      await _musicPlayer
          .setVolume(_musicState.volume)
          .timeout(const Duration(seconds: 6));
      await _musicPlayer
          .setUrl(playbackUri)
          .timeout(const Duration(seconds: 12));
      await _musicPlayer.play().timeout(const Duration(seconds: 8));
    } catch (error) {
      LocalAudioStorage.releasePlaybackUri(playbackUri);
      return _formatMusicPlaybackError(error);
    }
    _releaseActiveMusicPlaybackUri();
    _activeMusicPlaybackUri = playbackUri;
    _startMusicProgressTimer();
    _musicState = _musicState
        .copyWith(
          currentTrackId: track.id,
          isPlaying: true,
        )
        .normalized(_musicTracks);
    await _store.saveMusicPlaybackState(_musicState);
    await _updateGamification(
      (state) => _withMusicPlaybackStats(
        state,
        track,
        changed: changed,
        source: source,
        wasPlaying: wasPlaying,
      ),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> toggleMusicPlayback() async {
    if (_musicState.isPlaying) {
      try {
        await _musicPlayer.pause().timeout(const Duration(seconds: 6));
      } catch (error) {
        return _formatMusicPlaybackError(error);
      }
      _lastMusicPausedAt = DateTime.now();
      _musicState = _musicState.copyWith(isPlaying: false);
      await _store.saveMusicPlaybackState(_musicState);
      await _updateGamification(
        (state) => state.incrementStat('totalMusicPauses'),
        notify: false,
      );
      notifyListeners();
      return null;
    }
    if (_musicState.currentTrackId.isEmpty && _musicTracks.isNotEmpty) {
      _musicState = _musicState.copyWith(currentTrackId: _musicTracks.first.id);
    }
    if (_musicState.currentTrackId.isEmpty) {
      return '先上传一个本地音频，再让剧场有声。';
    }
    return playMusicTrack(_musicState.currentTrackId);
  }

  Future<void> openCurtainAndStartMusic() async {}

  Future<void> resumeMusicAfterUserGesture() async {
    if (!_musicState.isPlaying || _isInitializing) {
      return;
    }
    final now = DateTime.now();
    final lastAttempt = _lastMusicResumeAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 2)) {
      return;
    }
    _lastMusicResumeAttemptAt = now;
    try {
      await _musicPlayer.play().timeout(const Duration(seconds: 8));
      _startMusicProgressTimer();
    } catch (_) {
      // Browser autoplay can stay blocked until a trusted user gesture arrives.
    }
  }

  Future<String?> playNextMusicTrack() async {
    final nextId = _nextMusicTrackId();
    if (nextId == null) {
      return '歌单里没有可播放的音频。';
    }
    return playMusicTrack(nextId, source: 'next');
  }

  Future<String?> playPreviousMusicTrack() async {
    final previousId = _previousMusicTrackId();
    if (previousId == null) {
      return '歌单里没有可播放的音频。';
    }
    return playMusicTrack(previousId, source: 'previous');
  }

  Future<String?> setMusicVolume(double value) async {
    final safeVolume = value.clamp(0.0, 1.0);
    try {
      await _musicPlayer
          .setVolume(safeVolume)
          .timeout(const Duration(seconds: 6));
    } catch (error) {
      return _formatMusicPlaybackError(error);
    }
    _musicState = _musicState.copyWith(volume: safeVolume);
    await _store.saveMusicPlaybackState(_musicState);
    notifyListeners();
    return null;
  }

  Future<String?> setMusicLoopMode(MusicLoopMode mode) async {
    _musicState = _musicState.copyWith(loopMode: mode);
    await _store.saveMusicPlaybackState(_musicState);
    await _updateGamification(
      (state) => switch (mode) {
        MusicLoopMode.single => state.incrementStat('totalMusicSingleLoops'),
        MusicLoopMode.playlist =>
          state.incrementStat('totalMusicPlaylistLoops'),
      },
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> addTrackToPlaylist(String trackId) async {
    final track = MusicCatalog.byId(_musicTracks, trackId);
    if (track == null) {
      return '没有找到这个音频。';
    }
    if (_musicState.playlistTrackIds.contains(track.id)) {
      return '这个音频已经在歌单里了。';
    }
    _musicState = _musicState.copyWith(
      playlistTrackIds: <String>[
        ..._musicState.playlistTrackIds,
        track.id,
      ],
    ).normalized(_musicTracks);
    await _store.saveMusicPlaybackState(_musicState);
    await _updateGamification(
      (state) => _withMusicPlaylistStats(
        state.incrementStat('totalMusicPlaylistAdds'),
      ),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> removeTrackFromPlaylist(String trackId) async {
    if (!_musicState.playlistTrackIds.contains(trackId)) {
      return '这个音频不在当前歌单里。';
    }
    if (_musicState.playlistTrackIds.length <= 1) {
      return '歌单里至少要留一个音频。';
    }
    final nextIds = _musicState.playlistTrackIds
        .where((id) => id != trackId)
        .toList(growable: false);
    _musicState = _musicState
        .copyWith(
          playlistTrackIds: nextIds,
          currentTrackId:
              _musicState.currentTrackId == trackId ? nextIds.first : null,
        )
        .normalized(_musicTracks);
    await _store.saveMusicPlaybackState(_musicState);
    await _updateGamification(
      (state) => _withMusicPlaylistStats(
        state.incrementStat('totalMusicPlaylistRemoves'),
      ),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> reorderMusicPlaylist(int oldIndex, int newIndex) async {
    final ids = <String>[..._musicState.playlistTrackIds];
    if (oldIndex < 0 || oldIndex >= ids.length) {
      return '歌单排序位置不对。';
    }
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    targetIndex = targetIndex.clamp(0, ids.length - 1);
    final item = ids.removeAt(oldIndex);
    ids.insert(targetIndex, item);
    _musicState = _musicState.copyWith(playlistTrackIds: ids);
    await _store.saveMusicPlaybackState(_musicState);
    await _updateGamification(
      (state) => _withMusicPlaylistStats(
        state.incrementStat('totalMusicPlaylistReorders'),
      ),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> claimDailyBonus() async {
    if (!_gamification.ensureToday().canClaimDailyBonus) {
      return '今天的啥币已经领过了，明天再来薅。';
    }
    await _updateGamification((state) => state.claimDailyBonus());
    return null;
  }

  Future<String?> claimDailyTask(String taskId) async {
    DailyTaskDefinition? task;
    for (final item in GameCatalog.dailyTasks) {
      if (item.id == taskId) {
        task = item;
        break;
      }
    }
    if (task == null) {
      return '没有找到这个每日任务。';
    }
    final todayState = _gamification.ensureToday();
    if (todayState.isDailyTaskClaimed(task.id)) {
      return '这个任务今天已经领奖了。';
    }
    if (todayState.dailyStat(task.statKey) < task.target) {
      return '任务还没完成，先去整两下。';
    }
    await _updateGamification((state) => state.claimDailyTask(task!));
    return null;
  }

  Future<String?> buyShopItem(String itemId) async {
    final item = GameCatalog.shopItemById(itemId);
    if (item == null) {
      return '没有找到这个商品。';
    }
    if (_gamification.coins < item.cost) {
      return '啥币不够，钱包说它有点为难。';
    }
    await _updateGamification(
      (state) => state
          .spendCoins(item.cost)
          .addInventory(item.id)
          .incrementStat('totalShopPurchases'),
    );
    return null;
  }

  Future<String?> buyCustomStoryItem({
    required String name,
    required String effect,
  }) async {
    final character = currentCharacter;
    final trimmedName = name.trim();
    final trimmedEffect = effect.trim();
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (trimmedName.isEmpty) {
      return '商品名字不能为空，老板说空壳商品不入库。';
    }
    if (trimmedEffect.isEmpty) {
      return '请写一下这个商品能干嘛，不然它只能在背包里发呆。';
    }
    const cost = 10;
    if (_gamification.coins < cost) {
      return '啥币不够，自定义商品固定 10 啥币。';
    }

    await _updateGamification(
      (state) =>
          state.spendCoins(cost).incrementStat('totalStoryShopPurchases'),
      notify: false,
    );
    await _addStoryInventoryItem(
      character.id,
      StoryInventoryItem.fromName(
        trimmedName,
        description: '自定义商品：$trimmedEffect',
        effect: trimmedEffect,
        source: 'custom_shop',
      ),
    );
    notifyListeners();
    return null;
  }

  Future<List<StoryShopOffer>> generateBlackMarketOffers() async {
    final character = currentCharacter;
    if (character == null) {
      throw const LlmApiException('请先选择一个 AI 角色。');
    }
    if (!_settings.canChat) {
      throw const LlmApiException('请先在设置页填好 API 地址、密钥和模型名称。');
    }
    if (_isSending) {
      throw const LlmApiException('当前还有内容正在生成，请稍等。');
    }

    final history = await _ensureHistory(character.id);
    final gameState = await _ensureGameState(character.id);
    final memory = await _ensureMemory(character.id);
    _isSending = true;
    notifyListeners();
    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _blackMarketSystemPrompt,
        userPrompt: _buildBlackMarketPrompt(
          character: character,
          history: history,
          gameState: gameState,
          memory: memory,
        ),
        temperature: 0.92,
        topP: 0.96,
      );
      final offers = _parseStoryShopOffers(
        raw,
        minCost: 50,
        maxCost: 500,
        useFallback: false,
      );
      if (offers.isEmpty) {
        throw const LlmApiException('老板递来的货单太潦草，没看懂；这次不收看货费。');
      }
      await _chargeBlackMarketLookFee();
      await _updateGamification(
        (state) => state.incrementStat('totalBlackMarketRefreshes'),
        notify: false,
      );
      return offers;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> _chargeBlackMarketLookFee() async {
    const fee = 10;
    final missing = max(0, fee - _gamification.coins);
    await _updateGamification(
      (state) {
        var next = state.spendCoins(min(fee, state.coins));
        if (missing > 0) {
          next = next
              .incrementStat('currentDebtCoins', missing)
              .incrementStat('totalDebtTaken', missing);
        }
        return next;
      },
      notify: false,
    );
  }

  Future<String?> buyBlackMarketOffer(
    StoryShopOffer offer, {
    bool useDebt = false,
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    final item = offer.normalized();
    final missing = max(0, item.cost - _gamification.coins);
    if (missing > 0 && !useDebt) {
      return '啥币不够。你可以选择赊账，但老板会记在小本本上。';
    }
    final identified = offer.effect.trim().isNotEmpty;
    await _updateGamification(
      (state) {
        var next = state
            .spendCoins(min(item.cost, state.coins))
            .incrementStat('totalBlackMarketPurchases')
            .incrementStat('totalStoryShopPurchases');
        if (missing > 0) {
          next = next
              .incrementStat('currentDebtCoins', missing)
              .incrementStat('totalDebtTaken', missing);
        }
        return next;
      },
      notify: false,
    );
    await _addStoryInventoryItem(
      character.id,
      StoryInventoryItem.fromName(
        item.name,
        description:
            identified ? item.description : '效果未知：${offer.description}',
        effect: identified ? item.effect : '',
        source: 'black_market',
        identified: identified,
        mysteryHint: identified ? '' : offer.description,
      ),
    );
    notifyListeners();
    return null;
  }

  Future<String?> repayDebt({int? amount}) async {
    final debt = _gamification.stat('currentDebtCoins');
    if (debt <= 0) {
      return '你现在没有欠老板啥币，难得清白。';
    }
    final payment = min(_gamification.coins, min(amount ?? debt, debt));
    if (payment <= 0) {
      return '啥币不够，老板把算盘又往你面前推了推。';
    }
    await _updateGamification(
      (state) => state
          .spendCoins(payment)
          .setStat('currentDebtCoins', max(0, debt - payment))
          .incrementStat('totalDebtRepaid', payment),
    );
    return null;
  }

  Future<RouletteSpinResult> spinLuckyRoulette() async {
    const cost = 3;
    if (_gamification.coins < cost) {
      return const RouletteSpinResult(
        title: '转盘拒绝转动',
        description: '幸运转转转一次 3 啥币，钱包太安静了。',
        empty: true,
      );
    }
    final character = currentCharacter;
    final rng = Random(
      DateTime.now().microsecondsSinceEpoch ^
          _gamification.stat('totalRouletteSpins') ^
          _stableSeed(character?.id ?? 'global'),
    );
    final emptyStreak = _gamification.stat('rouletteEmptyStreak');
    final rarePity = _gamification.stat('rouletteRarePity');
    final forceNonEmpty = emptyStreak >= 9;
    final forceRare = rarePity >= 49;
    final roll = rng.nextInt(100);

    RouletteSpinResult result;
    GamificationState Function(GamificationState state) update =
        (state) => state.spendCoins(cost).incrementStat('totalRouletteSpins');

    if (!forceNonEmpty && !forceRare && roll < 15) {
      result = const RouletteSpinResult(
        title: '谢谢惠顾',
        description: '转盘转完了，老板也笑完了。空奖累计到第 10 次会触发保底不空。',
        empty: true,
      );
      update = (state) => state
          .spendCoins(cost)
          .incrementStat('totalRouletteSpins')
          .incrementStat('totalRouletteEmpty')
          .setStat('rouletteEmptyStreak', emptyStreak + 1)
          .setStat('rouletteRarePity', rarePity + 1);
    } else if (!forceRare && roll < 35) {
      final reward = 1 + rng.nextInt(4);
      result = RouletteSpinResult(
        title: '小奖励',
        description: '转盘吐出一点零碎好运，像老板良心短暂上线。',
        rewardLabel: '+$reward 啥币',
      );
      update = (state) => state
          .spendCoins(cost)
          .addCoins(reward)
          .incrementStat('totalRouletteSpins')
          .setStat('rouletteEmptyStreak', 0)
          .setStat('rouletteRarePity', rarePity + 1);
    } else if (!forceRare && roll < 37) {
      result = const RouletteSpinResult(
        title: '大奖！',
        description: '老板脸色肉眼可见地绿了。恭喜抽到 100 啥币。',
        rewardLabel: '+100 啥币',
        jackpot: true,
      );
      update = (state) => state
          .spendCoins(cost)
          .addCoins(100)
          .incrementStat('totalRouletteSpins')
          .incrementStat('totalRouletteJackpots')
          .setStat('rouletteEmptyStreak', 0)
          .setStat('rouletteRarePity', 0);
    } else if (forceRare || roll < 61) {
      final preferTitle = rng.nextBool();
      final titleIds = GameCatalog.rouletteTitleIds
          .where((id) => !_gamification.ownsCosmetic(id))
          .toList(growable: false);
      final frameIds = GameCatalog.rouletteFrameIds
          .where((id) => !_gamification.ownsCosmetic(id))
          .toList(growable: false);
      final pool = <String>[
        if (preferTitle) ...titleIds else ...frameIds,
        if (preferTitle) ...frameIds else ...titleIds,
      ];
      if (pool.isEmpty) {
        result = const RouletteSpinResult(
          title: '限定已毕业',
          description: '你已经把转盘限定装扮薅空了，老板忍痛补给你 8 啥币。',
          rewardLabel: '+8 啥币',
        );
        update = (state) => state
            .spendCoins(cost)
            .addCoins(8)
            .incrementStat('totalRouletteSpins')
            .setStat('rouletteEmptyStreak', 0)
            .setStat('rouletteRarePity', 0);
      } else {
        final cosmeticId = pool[rng.nextInt(pool.length)];
        final cosmetic = GameCatalog.cosmeticById(cosmeticId);
        result = RouletteSpinResult(
          title: '限定装扮出货',
          description: '转盘咔哒一声，掉出来一件限定收藏。',
          rewardLabel: cosmetic?.name ?? '限定装扮',
        );
        update = (state) => _withRouletteCollectionStats(
              state
                  .spendCoins(cost)
                  .unlockCosmetic(cosmeticId)
                  .incrementStat('totalRouletteSpins')
                  .incrementStat('totalRouletteCosmetics')
                  .setStat('rouletteEmptyStreak', 0)
                  .setStat('rouletteRarePity', 0),
            );
      }
    } else if (roll < 77) {
      final item = _rouletteStoryItem(rng);
      result = RouletteSpinResult(
        title: '怪东西入库',
        description: '转盘吐出一个看起来很能惹事的小物件，已经放进剧情物品栏。',
        rewardLabel: item.name,
      );
      update = (state) => state
          .spendCoins(cost)
          .incrementStat('totalRouletteSpins')
          .incrementStat('totalRouletteStoryItems')
          .setStat('rouletteEmptyStreak', 0)
          .setStat('rouletteRarePity', 0);
      if (character != null) {
        await _addStoryInventoryItem(character.id, item);
      }
    } else if (roll < 90) {
      final ticket =
          GameCatalog.shopItems[rng.nextInt(GameCatalog.shopItems.length)];
      result = RouletteSpinResult(
        title: '功能券掉落',
        description: '转盘吐出一张功能券，老板说这算小赚。',
        rewardLabel: ticket.name,
      );
      update = (state) => state
          .spendCoins(cost)
          .addInventory(ticket.id)
          .incrementStat('totalRouletteSpins')
          .setStat('rouletteEmptyStreak', 0)
          .setStat('rouletteRarePity', rarePity + 1);
    } else {
      final reward = 5 + rng.nextInt(6);
      result = RouletteSpinResult(
        title: '啥币回流',
        description: '转盘把一小把啥币塞回来了，像良心但不多。',
        rewardLabel: '+$reward 啥币',
      );
      update = (state) => state
          .spendCoins(cost)
          .addCoins(reward)
          .incrementStat('totalRouletteSpins')
          .setStat('rouletteEmptyStreak', 0)
          .setStat('rouletteRarePity', rarePity + 1);
    }

    await _updateGamification(update);
    return result;
  }

  Future<String?> identifyStoryInventoryItem(String itemId) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!_settings.canChat) {
      return '鉴定需要调用一次 AI，请先配置 API。';
    }
    if (_isSending) {
      return '当前还有内容正在生成，请稍等。';
    }
    final state = await _ensureGameState(character.id);
    final item = _findStoryInventoryItem(state, itemId);
    if (item == null) {
      return '剧情物品栏里没有找到这个道具。';
    }
    if (!item.identified) {
      return '这个道具效果未知，先花 3 啥币鉴定一下再投入主线比较稳。';
    }
    if (item.identified) {
      return '这个道具已经鉴定过了。';
    }
    const cost = 3;
    if (_gamification.coins < cost) {
      return '鉴定一次 3 啥币，钱包还差一点火候。';
    }

    await _updateGamification((state) => state.spendCoins(cost), notify: false);
    _isSending = true;
    notifyListeners();
    try {
      final history = await _ensureHistory(character.id);
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt:
            '你是文游道具鉴定员。只输出 JSON，不要 Markdown：{"description":"鉴定后的说明","effect":"投入主线后可能造成的剧情影响"}',
        userPrompt: '''
当前模拟器：${character.name}
未知道具：${item.name}
线索：${item.mysteryHint.trim().isEmpty ? item.description : item.mysteryHint}
最近剧情：
${_formatTranscript(history.messages.reversed.take(8).toList().reversed)}

请鉴定这个道具的真实用途。用途要贴合当前世界观，可以有点怪，但不能直接替用户赢下主线。
''',
        temperature: 0.72,
        topP: 0.9,
      );
      final decoded = _decodeJsonObject(raw);
      final description = decoded['description']?.toString().trim();
      final effect = decoded['effect']?.toString().trim();
      final nextItem = item.copyWith(
        description: (description == null || description.isEmpty)
            ? '鉴定完成：${item.description}'
            : description,
        effect: (effect == null || effect.isEmpty) ? '由剧情自然决定用途。' : effect,
        identified: true,
      );
      await _replaceStoryInventoryItem(character.id, nextItem);
      await _updateGamification(
        (state) => state.incrementStat('totalItemsIdentified'),
        notify: false,
      );
      return null;
    } catch (error) {
      await _updateGamification((state) => state.addCoins(cost), notify: false);
      return '鉴定失败，啥币已退回：$error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<String?> synthesizeStoryInventoryItems({
    required String firstItemId,
    required String secondItemId,
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!_settings.canChat) {
      return '道具合成需要调用一次 AI，请先配置 API。';
    }
    if (_isSending) {
      return '当前还有内容正在生成，请稍等。';
    }
    final state = await _ensureGameState(character.id);
    final first = _findStoryInventoryItem(state, firstItemId);
    final second = _findStoryInventoryItem(state, secondItemId);
    if (first == null || second == null || first.id == second.id) {
      return '请选择两个不同的剧情物品来合成。';
    }
    const cost = 5;
    if (_gamification.coins < cost) {
      return '合成一次 5 啥币，炼金台拒绝白嫖。';
    }

    await _updateGamification((state) => state.spendCoins(cost), notify: false);
    _isSending = true;
    notifyListeners();
    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt:
            '你是文游道具合成台。只输出 JSON，不要 Markdown：{"name":"新道具名","description":"说明","effect":"投入主线后的影响"}',
        userPrompt: '''
当前模拟器：${character.name}
道具 A：${first.name}
说明：${first.description}
用途：${first.effect}

道具 B：${second.name}
说明：${second.description}
用途：${second.effect}

请把两个道具合成一个怪但可用的新剧情物品。它要贴合当前世界观，效果可以有趣，但不能直接替用户赢下主线。
''',
        temperature: 0.86,
        topP: 0.95,
      );
      final decoded = _decodeJsonObject(raw);
      final name = decoded['name']?.toString().trim();
      final nextItem = StoryInventoryItem.fromName(
        (name == null || name.isEmpty)
            ? '${first.name}${second.name}混合物'
            : name,
        description: decoded['description']?.toString().trim() ??
            '由「${first.name}」和「${second.name}」合成而来。',
        effect: decoded['effect']?.toString().trim() ?? '由剧情自然决定用途。',
        source: 'synthesis',
      );
      await _removeStoryInventoryItems(
          character.id, <String>{first.id, second.id});
      await _addStoryInventoryItem(character.id, nextItem);
      await _updateGamification(
        (state) => state.incrementStat('totalItemsSynthesized'),
        notify: false,
      );
      return null;
    } catch (error) {
      await _updateGamification((state) => state.addCoins(cost), notify: false);
      return '合成失败，啥币已退回：$error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<List<StoryShopOffer>> generateMysteryShopOffers() async {
    final character = currentCharacter;
    if (character == null) {
      throw const LlmApiException('请先选择一个 AI 角色。');
    }
    if (!_settings.canChat) {
      throw const LlmApiException('请先在设置页填好 API 地址、密钥和模型名称。');
    }
    if (_isSending) {
      throw const LlmApiException('当前还有内容正在生成，请稍等。');
    }

    final history = await _ensureHistory(character.id);
    final gameState = await _ensureGameState(character.id);
    final memory = await _ensureMemory(character.id);
    _isSending = true;
    notifyListeners();
    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _mysteryShopSystemPrompt,
        userPrompt: _buildMysteryShopPrompt(
          character: character,
          history: history,
          gameState: gameState,
          memory: memory,
        ),
        temperature: 0.78,
        topP: 0.95,
      );
      final offers = _parseStoryShopOffers(raw);
      await _updateGamification(
        (state) => state.incrementStat('totalMysteryShopRefreshes'),
        notify: false,
      );
      return offers;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<String?> buyStoryShopOffer(StoryShopOffer offer) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    final item = offer.normalized();
    if (_gamification.coins < item.cost) {
      return '啥币不够，神秘老板把货又收回柜台底下了。';
    }
    await _updateGamification(
      (state) =>
          state.spendCoins(item.cost).incrementStat('totalStoryShopPurchases'),
      notify: false,
    );
    await _addStoryInventoryItem(
      character.id,
      StoryInventoryItem.fromName(
        item.name,
        description: item.description,
        effect: item.effect,
        source: 'mystery_shop',
      ),
    );
    notifyListeners();
    return null;
  }

  Future<String?> buyStoryShopOfferForNpcGift(
    String npcId,
    StoryShopOffer offer, {
    String shopSource = 'mystery_shop',
    bool useDebt = false,
  }) async {
    final character = currentCharacter;
    final npc = npcProfileById(npcId);
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (npc == null) {
      return '没有找到这个 NPC。';
    }
    if (!npc.canSendMessages) {
      return '该 NPC 当前为「${npc.lifecycle.label}」状态，不能收取礼物或变更好感。';
    }
    final item = offer.normalized();
    final missing = max(0, item.cost - _gamification.coins);
    if (missing > 0 && !(useDebt && shopSource == 'black_market')) {
      return shopSource == 'black_market'
          ? '啥币不够。你可以选择赊账，但老板会记在小本本上。'
          : '啥币不够，神秘老板把货又收回柜台底下了。';
    }
    await _updateGamification(
      (state) {
        var next = state
            .spendCoins(min(item.cost, state.coins))
            .incrementStat('totalStoryShopPurchases')
            .incrementStat(shopSource == 'black_market'
                ? 'totalBlackMarketPurchases'
                : 'totalMysteryShopGiftPurchases');
        if (missing > 0) {
          next = next
              .incrementStat('currentDebtCoins', missing)
              .incrementStat('totalDebtTaken', missing);
        }
        return next;
      },
      notify: false,
    );
    final storyItem = StoryInventoryItem.fromName(
      item.name,
      description: item.description,
      effect: item.effect,
      source: shopSource,
      identified: item.effect.trim().isNotEmpty,
      mysteryHint: item.effect.trim().isEmpty ? item.description : '',
    );
    return sendNpcGift(
      npcId: npcId,
      itemId: storyItem.id,
      directItem: storyItem,
      sourceLabel: shopSource == 'black_market' ? '黑心小卖部' : '神秘小卖部',
      consumeExisting: false,
    );
  }

  Future<String?> sendNpcGift({
    required String npcId,
    required String itemId,
    StoryInventoryItem? directItem,
    String sourceLabel = '剧情物品栏',
    bool consumeExisting = true,
  }) async {
    final character = currentCharacter;
    final npc = npcProfileById(npcId);
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (npc == null) {
      return '没有找到这个 NPC。';
    }
    if (!npc.canSendMessages) {
      return '该 NPC 当前为「${npc.lifecycle.label}」状态，不能收取礼物或变更好感。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending || _activeNpcReplyingId != null) {
      return '当前还有内容正在生成，请稍等。';
    }
    final state = await _ensureGameState(character.id);
    final item = directItem ?? _findStoryInventoryItem(state, itemId);
    if (item == null) {
      return '剧情物品栏里没有找到这个道具。';
    }

    _activeNpcReplyingId = npcId;
    notifyListeners();
    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _npcGiftSystemPrompt,
        userPrompt: _buildNpcGiftPrompt(
          character: character,
          npc: npc,
          item: item,
          sourceLabel: sourceLabel,
        ),
        temperature: 0.62,
        topP: 0.9,
      );
      final result = _parseNpcGiftResult(raw, npc, item);
      final now = DateTime.now();
      final giftRecord = NpcGiftRecord(
        id: IdGenerator.generic('npc_gift'),
        itemName: item.name,
        itemDescription: item.description,
        itemEffect: item.effect,
        source: sourceLabel,
        affinityDelta: result.affinityDelta,
        impression: result.impression,
        createdAt: now,
      );
      final entry = NpcImpressionEntry(
        id: IdGenerator.generic('npc_imp'),
        summary: result.impression,
        createdAt: now,
      );
      _applyNpcImpressionPatch(
        npcId,
        entry,
        affinityDelta: result.affinityDelta,
      );
      final npcIndex =
          _npcProfiles.indexWhere((profile) => profile.id == npcId);
      if (npcIndex != -1) {
        final updated = _npcProfiles[npcIndex];
        _npcProfiles[npcIndex] = updated.copyWith(
          giftHistory: <NpcGiftRecord>[
            giftRecord,
            ...updated.giftHistory,
          ].take(40).toList(growable: false),
          updatedAt: now,
        );
      }
      if (consumeExisting && directItem == null) {
        await _removeStoryInventoryItems(character.id, <String>{item.id});
      }
      final messages = await _ensureNpcMessages(npcId);
      final batchId = IdGenerator.generic('npc_gift_batch');
      final nextMessages = <NpcChatMessage>[
        ...messages,
        NpcChatMessage(
          id: IdGenerator.message(),
          npcId: npcId,
          role: NpcMessageRole.user,
          content: '送给${npc.name}：「${item.name}」',
          timestamp: now,
          batchId: batchId,
        ),
        NpcChatMessage(
          id: IdGenerator.message(),
          npcId: npcId,
          role: NpcMessageRole.npc,
          content: result.reply,
          timestamp: now,
          batchId: batchId,
        ),
      ];
      _npcMessagesCache[npcId] = nextMessages;
      await _store.saveNpcMessages(npcId, nextMessages);
      await _store.saveNpcProfiles(_npcProfiles);
      await _updateGamification(
        (state) =>
            state.incrementStat('totalNpcGifts').incrementDailyStat('npcGifts'),
        notify: false,
      );
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (error) {
      return '送礼失败：$error';
    } finally {
      _activeNpcReplyingId = null;
      notifyListeners();
    }
  }

  String _buildNpcGiftPrompt({
    required CharacterProfile character,
    required NpcProfile npc,
    required StoryInventoryItem item,
    required String sourceLabel,
  }) {
    return '''
任务：用户在 NPC 私聊中送礼。请生成 NPC 的即时回应，并判断这份礼物对好感度与印象的影响。

当前模拟器：${character.name}
NPC：${npc.name}
NPC 简介：${npc.description.trim().isEmpty ? '暂无。' : npc.description.trim()}
当前好感：${npc.affinity}
当前印象：${npc.impression.trim().isEmpty ? '暂无明确印象。' : npc.impression.trim()}
羁绊：${npc.bondRoute.stage} · ${npc.bondRoute.route} · ${npc.bondRoute.score}/100

礼物来源：$sourceLabel
礼物名称：${item.name}
礼物说明：${item.description.trim().isEmpty ? '暂无。' : item.description.trim()}
礼物可能效果：${item.effect.trim().isEmpty ? '未知，请结合 NPC 性格自然判断。' : item.effect.trim()}

要求：
1. 只输出 JSON，不要 Markdown。
2. reply 是 NPC 私聊里的回应气泡，可以 80-220 字，像真实聊天或自然短场景，不推进主线。
3. affinityDelta 范围 -10 到 12。普通合适礼物 1-5，特别戳中可以更高，不合适可以为负。
4. impression 要写成自然中文，说明 TA 因这份礼物对用户角色的新印象。

JSON 格式：
{"reply":"NPC回应","affinityDelta":0,"impression":"印象变化"}
''';
  }

  ({String reply, int affinityDelta, String impression}) _parseNpcGiftResult(
    String raw,
    NpcProfile npc,
    StoryInventoryItem item,
  ) {
    final fallbackReply = '${npc.name}收下了「${item.name}」，沉默了一小会儿，像是在重新估量这份心意。';
    try {
      final decoded = _decodeJsonObject(raw);
      final reply = decoded['reply']?.toString().trim();
      final impression =
          normalizeNpcImpressionText(decoded['impression']?.toString() ?? '');
      final rawDelta = decoded['affinityDelta'] ?? decoded['delta'];
      final delta = rawDelta is num
          ? rawDelta.round()
          : int.tryParse(rawDelta?.toString().replaceAll(
                    RegExp(r'[^0-9-]'),
                    '',
                  ) ??
              '');
      return (
        reply: reply == null || reply.isEmpty ? fallbackReply : reply,
        affinityDelta: (delta ?? 2).clamp(-10, 12).toInt(),
        impression: impression.isEmpty
            ? '收到「${item.name}」后，${npc.name}对用户角色多了一点新的在意。'
            : impression,
      );
    } catch (_) {
      final clean = raw.trim();
      return (
        reply: clean.isEmpty ? fallbackReply : clean,
        affinityDelta: 2,
        impression: '收到「${item.name}」后，${npc.name}对用户角色多了一点新的在意。',
      );
    }
  }

  Future<String?> useStoryInventoryItem(
    String itemId, {
    String userNote = '',
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending) {
      return '当前还有回复正在生成，请稍等。';
    }

    final gameState = await _ensureGameState(character.id);
    final item = _findStoryInventoryItem(gameState, itemId);
    if (item == null) {
      return '剧情物品栏里没有找到这个道具。';
    }

    final visibleContent = <String>[
      '你使用了剧情物品「${item.name}」。',
      if (userNote.trim().isNotEmpty) '补充：${userNote.trim()}',
    ].join('\n');
    final instructionContent = '''
你使用了剧情物品「${item.name}」。
道具说明：${item.description.trim().isEmpty ? '暂无说明。' : item.description.trim()}
道具效果：${item.effect.trim().isEmpty ? '请结合当前剧情自然判断。' : item.effect.trim()}
${userNote.trim().isEmpty ? '' : '用户补充：${userNote.trim()}'}

请把这次使用视为当前主线剧情的正式行动：生成一段使用结果，更新游戏面板、剧情记录、NPC 好感度、NPC 印象和六个下一步选项。不要把它写成商店小剧场，也不要说“这不影响主线”。''';

    final currentHistory = await _ensureHistory(character.id);
    final userMessage = ChatMessage(
      id: IdGenerator.message(),
      role: ChatRole.user,
      content: visibleContent.trim(),
      timestamp: DateTime.now(),
      isSummarized: false,
    );
    final placeholder = ChatMessage(
      id: IdGenerator.message(),
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isSummarized: false,
    );
    final nextHistory = currentHistory.copyWith(
      messages: <ChatMessage>[
        ...currentHistory.messages,
        userMessage,
        placeholder,
      ],
    );

    final error = await _streamAssistantReply(
      character: character,
      originalHistory: currentHistory,
      optimisticHistory: nextHistory,
      placeholderMessageId: placeholder.id,
      requestMessages: <ChatMessage>[
        ...currentHistory.messages,
        userMessage.copyWith(
          content: instructionContent.trim(),
          clearPromptReplayContent: true,
        ),
      ],
      invalidatedMessageIds: const <String>{},
    );
    if (error != null) {
      return error;
    }
    await _updateGamification(
      (state) => state
          .incrementStat('totalStoryItemsUsed')
          .incrementDailyStat('storyItemsUsed'),
      notify: false,
    );
    await _maybeGrantNpcReturnGift(character.id, item);
    await _collectSceneCard(
      characterId: character.id,
      sourceItemName: item.name,
      assistantMessageId: placeholder.id,
    );
    return null;
  }

  Future<String?> destroyStoryInventoryItem(String itemId) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    final state = await _ensureGameState(character.id);
    final item = _findStoryInventoryItem(state, itemId);
    if (item == null) {
      return '剧情物品栏里没有找到这个道具。';
    }
    final nextItems = state.storyInventory
        .where((entry) => entry.id != item.id)
        .toList(growable: false);
    final nextInventory = state.inventory
        .where((name) => name.trim() != item.name.trim())
        .toList(growable: false);
    final nextState = state.copyWith(
      updatedAt: DateTime.now(),
      inventory: nextInventory,
      storyInventory: nextItems,
    );
    _gameStateCache[character.id] = nextState;
    await _store.saveGameState(nextState);
    await _updateGamification(
      (state) => state
          .updateStoryItemNote(item.name, '')
          .incrementStat('totalStoryItemsDestroyed'),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> destroyStoryInventoryItems(Iterable<String> itemIds) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    final ids =
        itemIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return '请先选择要删除的剧情物品。';
    }
    final state = await _ensureGameState(character.id);
    final existing = state.storyInventory
        .where((item) => ids.contains(item.id))
        .toList(growable: false);
    if (existing.isEmpty) {
      return '剧情物品栏里没有找到这些道具。';
    }
    await _removeStoryInventoryItems(character.id, ids);
    await _updateGamification(
      (state) {
        var next = state.incrementStat(
          'totalStoryItemsDestroyed',
          existing.length,
        );
        for (final item in existing) {
          next = next.updateStoryItemNote(item.name, '');
        }
        return next;
      },
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<String?> buyCosmetic(String cosmeticId) async {
    final cosmetic = GameCatalog.cosmeticById(cosmeticId);
    if (cosmetic == null) {
      return '没有找到这个装扮。';
    }
    if (_gamification.ownsCosmetic(cosmetic.id)) {
      return '这个装扮已经在衣柜里了。';
    }
    if (_gamification.coins < cosmetic.cost) {
      return '啥币不够，先攒攒再来买。';
    }
    await _updateGamification(
      (state) => state
          .spendCoins(cosmetic.cost)
          .unlockCosmetic(cosmetic.id)
          .incrementStat('totalShopPurchases'),
    );
    return null;
  }

  Future<String?> unlockTheme(String themeId) async {
    final variant = AppThemeVariant.byId(themeId);
    if (variant.id != themeId.trim()) {
      return '没有找到这个主题。';
    }
    if (variant.unlockCost <= 0 || _gamification.ownsTheme(variant.id)) {
      return null;
    }
    if (_gamification.coins < variant.unlockCost) {
      final missing = variant.unlockCost - _gamification.coins;
      return '啥币不够，还差 $missing 个啥币才能解锁。';
    }
    await _updateGamification(
      (state) => state.spendCoins(variant.unlockCost).unlockTheme(variant.id),
    );
    return null;
  }

  Future<String?> buyCustomThemeSlot({
    required String name,
    required String description,
    required String baseThemeId,
    required String css,
  }) async {
    const cost = 200;
    final trimmedName = name.trim();
    final trimmedCss = css.trim();
    final baseVariant = AppThemeVariant.byId(baseThemeId);
    if (trimmedName.isEmpty) {
      return '先给这个自定义主题起个名字。';
    }
    if (trimmedCss.isEmpty) {
      return '主题样式代码不能为空。';
    }
    if (!canUseTheme(baseVariant.id)) {
      return '先解锁底稿主题，再拿它做自定义主题。';
    }
    if (_gamification.coins < cost) {
      return '自定义主题格子需要 200 啥币，钱包还差一点。';
    }
    final style = CustomThemeStyle.create(
      id: IdGenerator.generic('custom_theme'),
      name: trimmedName,
      description: description,
      baseThemeId: baseVariant.id,
      css: trimmedCss,
    );
    await _updateGamification(
      (state) => state
          .spendCoins(cost)
          .addCustomThemeStyle(style)
          .incrementStat('totalShopPurchases'),
    );
    return null;
  }

  Future<String?> updateCustomThemeStyle({
    required String id,
    required String name,
    required String description,
    required String baseThemeId,
    required String css,
  }) async {
    final existing = _gamification.customThemeById(id);
    if (existing == null) {
      return '没有找到这个自定义主题。';
    }
    final trimmedName = name.trim();
    final trimmedCss = css.trim();
    final baseVariant = AppThemeVariant.byId(baseThemeId);
    if (trimmedName.isEmpty) {
      return '主题名字不能为空。';
    }
    if (trimmedCss.isEmpty) {
      return '主题样式代码不能为空。';
    }
    if (!canUseTheme(baseVariant.id)) {
      return '先解锁底稿主题，再拿它做自定义主题。';
    }
    await _updateGamification(
      (state) => state.updateCustomThemeStyle(
        existing.copyWith(
          name: trimmedName,
          description: description.trim(),
          baseThemeId: baseVariant.id,
          css: trimmedCss,
        ),
      ),
    );
    return null;
  }

  Future<String?> deleteCustomThemeStyle(String id) async {
    final style = _gamification.customThemeById(id);
    if (style == null) {
      return '没有找到这个自定义主题。';
    }
    final fallbackThemeId = AppThemeVariant.byId(style.baseThemeId).id;
    await _updateGamification(
      (state) => state.deleteCustomThemeStyle(id),
      notify: false,
    );
    if (_settings.themeId == id) {
      final nextSettings = _settings.copyWith(themeId: fallbackThemeId);
      _settings = nextSettings;
      await _store.saveSettings(nextSettings);
    }
    _registerCustomThemes();
    notifyListeners();
    return null;
  }

  Future<String?> equipCosmetic(String cosmeticId) async {
    final cosmetic = GameCatalog.cosmeticById(cosmeticId);
    if (cosmetic == null) {
      return '没有找到这个装扮。';
    }
    if (!_gamification.ownsCosmetic(cosmetic.id)) {
      return '还没有拥有这个装扮。';
    }
    await _updateGamification(
      (state) {
        var next = state
            .equipCosmetic(cosmetic.id)
            .incrementStat('totalCosmeticsEquipped');
        if (cosmetic.type == CosmeticType.frame &&
            cosmetic.id != 'frame_default') {
          next = next.incrementStat('totalFramesEquipped');
        }
        if (next.equippedTitleId != 'title_plain' &&
            next.equippedFrameId != 'frame_default') {
          next = next.setStatMax('maxFullCosmeticSlots', 1);
        }
        return next;
      },
    );
    return null;
  }

  Future<String?> buyCustomBubbleSlot({
    required String name,
    required String description,
    required String css,
  }) async {
    const cost = 50;
    final trimmedName = name.trim();
    final trimmedCss = css.trim();
    if (trimmedName.isEmpty) {
      return '先给这个自定义气泡起个名字。';
    }
    if (trimmedCss.isEmpty) {
      return 'CSS 样式不能为空，不然气泡会裸奔。';
    }
    if (_gamification.coins < cost) {
      return '自定义气泡格子需要 50 啥币，钱包还差一点。';
    }
    final style = CustomBubbleStyle.create(
      id: IdGenerator.generic('custom_bubble'),
      name: trimmedName,
      description: description.trim(),
      css: trimmedCss,
    );
    await _updateGamification(
      (state) => state
          .spendCoins(cost)
          .addCustomBubbleStyle(style)
          .incrementStat('totalShopPurchases'),
    );
    return null;
  }

  Future<String?> updateCustomBubbleStyle({
    required String id,
    required String name,
    required String description,
    required String css,
  }) async {
    final existing = _gamification.customBubbleById(id);
    if (existing == null) {
      return '没有找到这个自定义气泡。';
    }
    if (name.trim().isEmpty) {
      return '气泡名字不能为空。';
    }
    if (css.trim().isEmpty) {
      return 'CSS 样式不能为空。';
    }
    await _updateGamification(
      (state) => state.updateCustomBubbleStyle(
        existing.copyWith(
          name: name.trim(),
          description: description.trim(),
          css: css.trim(),
        ),
      ),
    );
    return null;
  }

  Future<String?> deleteCustomBubbleStyle(String id) async {
    if (_gamification.customBubbleById(id) == null) {
      return '没有找到这个自定义气泡。';
    }
    await _updateGamification((state) => state.deleteCustomBubbleStyle(id));
    return null;
  }

  Future<String?> equipBubbleFrame(String frameId) async {
    if (!_gamification.ownsFrame(frameId)) {
      return '还没有拥有这个气泡。';
    }
    await _updateGamification(
      (state) {
        var next =
            state.equipFrame(frameId).incrementStat('totalCosmeticsEquipped');
        if (frameId != 'frame_default') {
          next = next.incrementStat('totalFramesEquipped');
        }
        if (frameId.startsWith('custom_bubble_')) {
          next = next.incrementStat('totalCustomBubblesEquipped');
        }
        if (next.equippedTitleId != 'title_plain' &&
            next.equippedFrameId != 'frame_default') {
          next = next.setStatMax('maxFullCosmeticSlots', 1);
        }
        return next;
      },
    );
    return null;
  }

  Future<String?> assignCurrentCharacterBubbleFrame(String frameId) async {
    final character = currentCharacter;
    if (character == null) {
      return '先选择一个角色。';
    }
    return assignCharacterBubbleFrame(
      characterId: character.id,
      frameId: frameId,
    );
  }

  Future<String?> assignCharacterBubbleFrame({
    required String characterId,
    required String frameId,
  }) async {
    CharacterProfile? character;
    for (final item in _characters) {
      if (item.id == characterId) {
        character = item;
        break;
      }
    }
    if (character == null) {
      return '没有找到这个角色。';
    }
    final targetCharacterId = character.id;
    if (!_gamification.ownsFrame(frameId)) {
      return '还没有拥有这个气泡。';
    }
    await _updateGamification(
      (state) => state.assignCharacterBubbleFrame(
        characterId: targetCharacterId,
        frameId: frameId,
      ),
    );
    return null;
  }

  Future<String?> clearCurrentCharacterBubbleFrame() async {
    final character = currentCharacter;
    if (character == null) {
      return '先选择一个角色。';
    }
    return clearCharacterBubbleFrame(character.id);
  }

  Future<String?> clearCharacterBubbleFrame(String characterId) async {
    await _updateGamification(
      (state) => state.clearCharacterBubbleFrame(characterId),
    );
    return null;
  }

  Future<String?> useInventoryItem(String itemId) async {
    final item = GameCatalog.shopItemById(itemId);
    if (item == null) {
      return '没有找到这个道具。';
    }
    if (_gamification.inventoryCount(item.id) <= 0) {
      return '背包里没有这张券。';
    }

    // For theater items, just remove from inventory and let UI handle display
    if (isTheaterEffect(item.effectId)) {
      await _updateGamification(
        (state) => state
            .ensureToday()
            .removeInventory(item.id)
            .incrementStat('totalItemsUsed')
            .incrementDailyStat('itemsUsed'),
      );
      return null;
    }

    final before = _gamification;
    _gamification = _applyAchievementUnlocks(
      _gamification.ensureToday().removeInventory(item.id),
    );
    await _store.saveGamificationState(_gamification);
    notifyListeners();

    final error = item.effectId == 'npc_letter'
        ? await _generateNpcLetter(useDailyFreeLetter: false)
        : await generateConversationToolReply(item.effectId);
    if (error != null) {
      _gamification = before;
      await _store.saveGamificationState(_gamification);
      notifyListeners();
      return error;
    }

    await _updateGamification(
      (state) =>
          state.incrementStat('totalItemsUsed').incrementDailyStat('itemsUsed'),
    );
    return null;
  }

  Future<String?> deleteInventoryItems(Iterable<String> itemIds) async {
    final ids =
        itemIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return '请先选择要删除的功能券。';
    }
    final removedCount = ids.fold<int>(
      0,
      (sum, id) => sum + _gamification.inventoryCount(id),
    );
    if (removedCount <= 0) {
      return '背包里没有这些功能券。';
    }
    await _updateGamification(
      (state) => state
          .removeInventoryItems(ids)
          .incrementStat('totalInventoryTicketsDeleted', removedCount),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  bool isTheaterEffect(String effectId) {
    return switch (effectId) {
      'child_spray' ||
      'beast_ear_potion' ||
      'touch' ||
      'truth_lollipop' ||
      'comedy_stage' ||
      'forum_burst' ||
      'npc_gossip' ||
      'passerby_camera' ||
      'mood_radio' ||
      'rumor_board' ||
      'prophecy_trash' ||
      'dream_fragment' =>
        true,
      _ => false,
    };
  }

  Future<String?> sendDailyNpcLetter() async {
    final todayState = _gamification.ensureToday();
    if (todayState.dailyStat('freeNpcLetters') > 0) {
      return '今天的随机来信已经触发过了。';
    }
    final error = await _generateNpcLetter(useDailyFreeLetter: true);
    if (error != null) {
      return error;
    }
    await _updateGamification(
      (state) => state.incrementDailyStat('freeNpcLetters'),
    );
    return null;
  }

  Future<void> loadCurrentNpcThreads() async {
    for (final profile in currentWorldNpcProfiles) {
      if (!_npcMessagesCache.containsKey(profile.id)) {
        _npcMessagesCache[profile.id] =
            await _store.loadNpcMessages(profile.id);
      }
    }
    notifyListeners();
  }

  Future<void> markNpcInboxRead() async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }
    await loadCurrentNpcThreads();
    await _updateGamification(
      (state) {
        var next = state.markNpcInboxRead(character.id);
        for (final profile in currentWorldNpcProfiles) {
          next = next.markNpcInboxRead(_npcThreadReadKey(profile.id));
        }
        return next;
      },
    );
  }

  Future<void> markNpcThreadRead(String npcId) async {
    final profile = npcProfileById(npcId);
    if (profile == null) {
      return;
    }
    await loadNpcThread(npcId);
    await _updateGamification(
      (state) => state.markNpcInboxRead(_npcThreadReadKey(npcId)),
    );
  }

  Future<void> updateStoryItemNote(String itemName, String note) async {
    await _updateGamification(
      (state) => state.updateStoryItemNote(itemName, note),
    );
  }

  Future<void> noteExportedMessages() async {
    await _updateGamification(
      (state) => state.incrementStat('totalExports'),
    );
  }

  Future<void> saveSettings(AppSettings nextSettings) async {
    final previousThemeId = _settings.themeId;
    final resolvedThemeId = _resolveThemeId(nextSettings.themeId);
    var safeSettings = nextSettings.copyWith(
      themeId: resolvedThemeId,
      cacheIsolationId: nextSettings.cacheIsolationId.trim().isEmpty
          ? (_settings.cacheIsolationId.trim().isEmpty
              ? _installId?.trim() ?? ''
              : _settings.cacheIsolationId)
          : nextSettings.cacheIsolationId.trim(),
    );
    if (!canUseTheme(resolvedThemeId)) {
      safeSettings = safeSettings.copyWith(themeId: previousThemeId);
    }
    _settings = safeSettings;
    await _store.saveSettings(safeSettings);
    if (previousThemeId != safeSettings.themeId) {
      var next = _gamification
          .ensureToday()
          .incrementStat('totalThemeChanges')
          .incrementDailyStat('themeChanges');
      if (safeSettings.themeId == 'cthulhu') {
        next = next.incrementStat('totalCthulhuThemeUses');
      }
      if (safeSettings.themeId == 'april_fools') {
        next = next.incrementStat('totalAprilFoolsThemeUses');
      }
      if (safeSettings.themeId == 'rift_relay') {
        next = next.incrementStat('totalRiftRelayThemeUses');
      }
      if (safeSettings.themeId == 'flower_not_flower') {
        next = next.incrementStat('totalFlowerNotFlowerThemeUses');
      }
      if (safeSettings.themeId == 'mechanical_city') {
        next = next.incrementStat('totalMechanicalCityThemeUses');
      }
      if (safeSettings.themeId == 'rain_radio') {
        next = next.incrementStat('totalRainRadioThemeUses');
      }
      if (safeSettings.themeId == 'sky_pasture') {
        next = next.incrementStat('totalSkyPastureThemeUses');
      }
      if (safeSettings.themeId == 'vinyl_memories') {
        next = next.incrementStat('totalVinylMemoriesThemeUses');
      }
      if (_gamification.customThemeById(safeSettings.themeId) != null) {
        next = next.incrementStat('totalCustomThemesEquipped');
      }
      _gamification = _applyAchievementUnlocks(next);
      await _store.saveGamificationState(_gamification);
    }
    notifyListeners();
  }

  String _resolveThemeId(String themeId) {
    final id = themeId.trim();
    if (_gamification.customThemeById(id) != null) {
      return id;
    }
    return AppThemeVariant.byId(id).id;
  }

  void _registerCustomThemes() {
    AppTheme.registerRuntimeThemes(
      _gamification.customThemeStyles.map((style) {
        final baseVariant = AppThemeVariant.byId(style.baseThemeId);
        final spec = ThemeStyleSpec.fromCustom(style);
        return RuntimeThemeDefinition(
          id: style.id,
          label: style.name,
          description: style.description,
          baseThemeId: baseVariant.id,
          palette: (spec ?? ThemeStyleSpec(baseThemeId: baseVariant.id))
              .applyTo(baseVariant.palette),
          radius: spec?.radius,
          shadowBlur: spec?.shadowBlur,
          backgroundEffect: spec?.backgroundEffect,
          fontPreset: spec?.fontPreset,
        );
      }),
    );
  }

  Future<void> saveSettingsPreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _settingsPresets.removeWhere((preset) => preset.name == trimmed);
    _settingsPresets.insert(
      0,
      SettingsPreset(
        name: trimmed,
        settings: _settings,
      ),
    );
    await _store.saveSettingsPresets(_settingsPresets);
    notifyListeners();
  }

  Future<void> applySettingsPreset(String presetId) async {
    SettingsPreset? preset;
    for (final item in _settingsPresets) {
      if (item.id == presetId) {
        preset = item;
        break;
      }
    }
    if (preset == null) {
      return;
    }

    await saveSettings(preset.settings);
  }

  Future<void> deleteSettingsPreset(String presetId) async {
    final before = _settingsPresets.length;
    _settingsPresets.removeWhere((preset) => preset.id == presetId);
    if (_settingsPresets.length == before) {
      return;
    }

    await _store.saveSettingsPresets(_settingsPresets);
    notifyListeners();
  }

  Future<void> selectCharacter(String characterId) async {
    if (_selectedCharacterId == characterId) {
      return;
    }

    _selectedCharacterId = characterId;
    await _store.saveSelectedCharacterId(characterId);
    await _loadCharacterState(characterId);
    notifyListeners();
  }

  Future<void> createCharacter(CharacterDraft draft) async {
    final profile = CharacterProfile(
      id: IdGenerator.character(),
      name: draft.name.trim(),
      createdAt: DateTime.now(),
      prompt: draft.prompt.trim(),
      hiddenPrompt: _resolveHiddenPrompt(draft.hiddenPrompt),
      description: draft.description.trim(),
      openingMessage: draft.openingMessage.trim(),
      streamingOutputEnabled: draft.streamingOutputEnabled,
      segmentedOutputEnabled: draft.largeGroupChatModeEnabled
          ? false
          : draft.segmentedOutputEnabled,
      nextStepOptionsEnabled: draft.largeGroupChatModeEnabled
          ? false
          : draft.nextStepOptionsEnabled,
      mapModeEnabled:
          draft.largeGroupChatModeEnabled ? false : draft.mapModeEnabled,
      largeGroupChatModeEnabled: draft.largeGroupChatModeEnabled,
      avatarDataUri: draft.avatarDataUri.trim(),
      modelParams: draft.modelParams,
    );

    _characters.insert(0, profile);
    _historyCache[profile.id] = DialogueHistory.empty(profile.id);
    _memoryCache[profile.id] = CharacterMemory.empty(profile.id);
    _gameStateCache[profile.id] = GameStateSnapshot.empty(profile.id);
    _mapStateCache[profile.id] = MapWorldState.empty(profile.id);

    await _store.saveCharacters(_characters);
    await _store.saveDialogueHistory(_historyCache[profile.id]!);
    await _store.saveCharacterMemory(_memoryCache[profile.id]!);
    await _store.saveGameState(_gameStateCache[profile.id]!);
    await _store.saveMapState(_mapStateCache[profile.id]!);

    await _updateGamification(
      (state) => state
          .incrementStat('totalCharactersCreated')
          .setStatMax('maxActiveCharacters', characters.length),
      notify: false,
    );

    await selectCharacter(profile.id);
  }

  Future<NpcMigrationBuildResult> buildNpcMigrationPreview({
    required String npcId,
    required String worldType,
    String outputKind = NpcMigrationOutputKind.newWorld,
    String inspiration = '',
    String narrativeVoice = 'second',
    String memoryMode = NpcMigrationMemoryMode.full,
    NpcFarewellOutcome farewellOutcome = const NpcFarewellOutcome(),
    String relationshipLock = NpcMigrationRelationshipLock.followOldBond,
    bool includeFarewell = true,
    bool generateKeepsake = true,
    bool generateTasks = true,
    bool allowEcho = true,
  }) async {
    final sourceCharacter = currentCharacter;
    if (sourceCharacter == null) {
      return NpcMigrationBuildResult.failure('请先选择一个主模拟器。');
    }
    if (!_settings.canChat) {
      return NpcMigrationBuildResult.failure('请先在设置页填好 API 地址、密钥和模型名称。');
    }
    if (_isSending) {
      return NpcMigrationBuildResult.failure('当前还有内容正在生成，请稍等。');
    }
    final npc = npcProfileById(npcId);
    if (npc == null) {
      return NpcMigrationBuildResult.failure('没有找到这个 NPC。');
    }

    _isSending = true;
    _npcMigrationBuildStage = '正在整理 NPC 生涯快照';
    notifyListeners();
    try {
      final normalizedMemoryMode = NpcMigrationMemoryMode.normalize(memoryMode);
      final normalizedRelationshipLock =
          NpcMigrationRelationshipLock.normalize(relationshipLock);
      final normalizedOutputKind = NpcMigrationOutputKind.normalize(outputKind);
      if (normalizedOutputKind == NpcMigrationOutputKind.roleCardOnly) {
        return NpcMigrationBuildResult.failure('可复用角色卡请使用 NPC 角色卡编辑器整理。');
      }
      final effectiveFarewell =
          includeFarewell ? farewellOutcome : const NpcFarewellOutcome();
      final messages = await _ensureNpcMessages(npc.id);
      final gameState = await _ensureGameState(sourceCharacter.id);
      final sourceSnapshot = _buildNpcMigrationSourceSnapshot(
        sourceCharacter: sourceCharacter,
        npc: npc,
        messages: messages,
        gameState: gameState,
        worldType: worldType,
        inspiration: inspiration,
        narrativeVoice: narrativeVoice,
        memoryMode: normalizedMemoryMode,
        farewellOutcome: effectiveFarewell,
        relationshipLock: normalizedRelationshipLock,
      );
      _npcMigrationBuildStage = '正在生成结构化前尘档案';
      notifyListeners();
      final manifestResult = await _runNpcMigrationStructuredTask(
        stageLabel: '前尘档案',
        systemPrompt: _npcMigrationManifestSystemPrompt,
        userPrompt: _buildNpcMigrationManifestPrompt(
          sourceSnapshot: sourceSnapshot,
          memoryMode: normalizedMemoryMode,
          relationshipLock: normalizedRelationshipLock,
          generateKeepsake: generateKeepsake,
          generateTasks: generateTasks,
        ),
        schemaHint: _npcMigrationManifestSchemaHint,
        validator: _isValidNpcMigrationManifestJson,
        temperature: 0.45,
        topP: 0.9,
      );
      final manifest = _parseNpcMigrationManifest(
        manifestResult.data,
        npc: npc,
        memoryMode: normalizedMemoryMode,
        relationshipLock: normalizedRelationshipLock,
        generateKeepsake: generateKeepsake,
        generateTasks: generateTasks,
        repaired: manifestResult.repaired,
      );

      _npcMigrationBuildStage =
          normalizedOutputKind == NpcMigrationOutputKind.worldBookOnly
              ? '正在生成前尘世界书'
              : '正在生成新世界角色与世界书';
      notifyListeners();
      final bundleResult = await _runNpcMigrationStructuredTask(
        stageLabel: normalizedOutputKind == NpcMigrationOutputKind.worldBookOnly
            ? '前尘世界书'
            : '新世界角色',
        systemPrompt: _npcMigrationBundleSystemPrompt,
        userPrompt: _buildNpcMigrationBundlePrompt(
          manifest: manifest,
          outputKind: normalizedOutputKind,
          worldType: worldType,
          inspiration: inspiration,
          narrativeVoice: narrativeVoice,
          npc: npc,
        ),
        schemaHint: _npcMigrationBundleSchemaHint,
        validator: (data) => _isValidNpcMigrationBundleJson(
          data,
          requireCharacter:
              normalizedOutputKind == NpcMigrationOutputKind.newWorld,
        ),
        temperature: sourceCharacter.modelParams.temperature,
        topP: sourceCharacter.modelParams.topP,
      );
      final worldBookRaw = bundleResult.data['worldBook'];
      final worldBookPayload = _parseNpcMigrationWorldBookPayload(
        jsonEncode(worldBookRaw),
        npc,
        worldType,
        normalizedMemoryMode,
      );
      final createsCharacter =
          normalizedOutputKind == NpcMigrationOutputKind.newWorld;
      final characterRaw = bundleResult.data['character'];
      final payload = createsCharacter
          ? _parseNpcMigrationCharacterPayload(
              jsonEncode(characterRaw),
              npc,
              worldType,
              narrativeVoice,
            )
          : null;
      final now = DateTime.now();
      final prompt = payload == null
          ? ''
          : _composeNpcMigrationPrompt(
              payload: payload,
              npc: npc,
              worldType: worldType,
              narrativeVoice: narrativeVoice,
            );
      final effectiveManifest = bundleResult.repaired
          ? manifest.copyWith(
              qualityWarnings: <String>[
                ...manifest.qualityWarnings,
                '新世界输出经过一次 JSON 格式修复。',
              ],
            )
          : manifest;
      final preview = NpcMigrationPreview(
        id: IdGenerator.generic('npc_migration_preview'),
        sourceCharacterId: sourceCharacter.id,
        sourceCharacterName: sourceCharacter.name,
        sourceNpcId: npc.id,
        sourceNpcName: npc.name,
        worldType: worldType.trim().isEmpty ? '只属于你们的新世界' : worldType.trim(),
        inspiration: inspiration.trim(),
        narrativeVoice: narrativeVoice,
        memoryMode: normalizedMemoryMode,
        outputKind: normalizedOutputKind,
        generatedAt: now,
        archiveText: effectiveManifest.archive.toDisplayText(),
        worldBookTitle: worldBookPayload.title.trim().isEmpty
            ? '你们的前尘 · ${npc.name}'
            : worldBookPayload.title.trim(),
        worldBookContent: _composeNpcMigrationWorldBook(
          manifest: effectiveManifest,
          generatedContent: worldBookPayload.content,
          npcName: npc.name,
          worldType: worldType,
          narrativeVoice: narrativeVoice,
          allowEcho: allowEcho,
        ),
        characterName: payload == null
            ? ''
            : payload.name.trim().isEmpty
                ? npc.name.trim()
                : payload.name.trim(),
        characterDescription: payload == null
            ? ''
            : payload.description.trim().isEmpty
                ? '与「${sourceCharacter.name}」有前尘联系的关键角色。'
                : payload.description.trim(),
        characterPrompt: prompt,
        hiddenPrompt:
            payload == null ? '' : _resolveHiddenPrompt(payload.hiddenPrompt),
        openingMessage: payload == null
            ? ''
            : payload.openingMessage.trim().isEmpty
                ? _fallbackNpcMigrationOpening(npc, worldType, narrativeVoice)
                : payload.openingMessage.trim(),
        sourceDigest: _buildNpcMigrationSourceDigest(
          sourceCharacter: sourceCharacter,
          npc: npc,
          messages: messages,
        ),
        manifest: effectiveManifest,
        farewellOutcome: effectiveFarewell,
        relationshipLock: normalizedRelationshipLock,
        generateKeepsake: generateKeepsake,
        generateTasks: generateTasks,
        allowEcho: allowEcho,
        keepsake: effectiveManifest.keepsake,
        relationshipTasks: effectiveManifest.tasks,
      );
      return NpcMigrationBuildResult.success(preview);
    } on LlmApiException catch (error) {
      return NpcMigrationBuildResult.failure(error.message);
    } catch (error) {
      return NpcMigrationBuildResult.failure('带走 NPC 失败：$error');
    } finally {
      _isSending = false;
      _npcMigrationBuildStage = '';
      notifyListeners();
    }
  }

  Future<NpcFarewellDraftResult> buildNpcFarewellDraft({
    required String npcId,
  }) async {
    final sourceCharacter = currentCharacter;
    if (sourceCharacter == null) {
      return const NpcFarewellDraftResult(error: '请先选择一个主模拟器。');
    }
    if (!_settings.canChat) {
      return const NpcFarewellDraftResult(error: '请先在设置页填好 API 地址、密钥和模型名称。');
    }
    if (_isSending) {
      return const NpcFarewellDraftResult(error: '当前还有内容正在生成，请稍等。');
    }
    final npc = npcProfileById(npcId);
    if (npc == null) {
      return const NpcFarewellDraftResult(error: '没有找到这个 NPC。');
    }

    _isSending = true;
    notifyListeners();
    try {
      final messages = await _ensureNpcMessages(npc.id);
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _npcFarewellDraftSystemPrompt,
        userPrompt: _buildNpcFarewellDraftPrompt(
          sourceCharacter: sourceCharacter,
          npc: npc,
          messages: messages,
        ),
        temperature: 0.62,
        topP: 0.9,
      );
      final draft = _parseNpcFarewellDraft(raw, sourceCharacter, npc);
      return NpcFarewellDraftResult(draft: draft);
    } on LlmApiException catch (error) {
      return NpcFarewellDraftResult(error: error.message);
    } catch (error) {
      return NpcFarewellDraftResult(error: '告别回合生成失败：$error');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<NpcFarewellOutcomeResult> summarizeNpcFarewellOutcome({
    required String npcId,
    required String mode,
    NpcFarewellDraft? draft,
    NpcFarewellChoice? selectedChoice,
    String userFarewellText = '',
  }) async {
    final sourceCharacter = currentCharacter;
    if (sourceCharacter == null) {
      return const NpcFarewellOutcomeResult(error: '请先选择一个主模拟器。');
    }
    final npc = npcProfileById(npcId);
    if (npc == null) {
      return const NpcFarewellOutcomeResult(error: '没有找到这个 NPC。');
    }
    final normalizedMode = NpcFarewellMode.normalize(mode);
    if (normalizedMode == NpcFarewellMode.skip) {
      return const NpcFarewellOutcomeResult(
        outcome: NpcFarewellOutcome(mode: NpcFarewellMode.skip),
      );
    }
    return NpcFarewellOutcomeResult(
      outcome: _fallbackFarewellOutcome(
        npc: npc,
        mode: normalizedMode,
        draft: draft,
        selectedChoice: selectedChoice,
        userFarewellText: userFarewellText,
      ),
    );
  }

  Future<NpcMigrationCommitResult> commitNpcMigrationPreview(
    NpcMigrationPreview preview,
  ) async {
    if (preview.outputKind != NpcMigrationOutputKind.newWorld) {
      return const NpcMigrationCommitResult(error: '这份预览不是可游玩的新世界。');
    }
    final sourceCharacter = _findCharacter(preview.sourceCharacterId);
    final npc = npcProfileById(preview.sourceNpcId);
    if (sourceCharacter == null) {
      return const NpcMigrationCommitResult(error: '源模拟器不存在，无法写入迁徙结果。');
    }
    if (npc == null) {
      return const NpcMigrationCommitResult(error: '源 NPC 不存在，无法写入迁徙结果。');
    }

    final now = DateTime.now();
    final migrationId = IdGenerator.generic('npc_migration');
    final newCharacter = CharacterProfile(
      id: IdGenerator.character(),
      name: preview.characterName.trim().isEmpty
          ? npc.name.trim()
          : preview.characterName.trim(),
      createdAt: now,
      prompt: preview.characterPrompt.trim(),
      hiddenPrompt: _resolveHiddenPrompt(preview.hiddenPrompt),
      description: preview.characterDescription.trim().isEmpty
          ? '与「${sourceCharacter.name}」有前尘联系的关键角色。'
          : preview.characterDescription.trim(),
      openingMessage: preview.openingMessage.trim().isEmpty
          ? _fallbackNpcMigrationOpening(
              npc,
              preview.worldType,
              preview.narrativeVoice,
            )
          : preview.openingMessage.trim(),
      avatarDataUri: npc.avatarDataUri,
      streamingOutputEnabled: true,
      segmentedOutputEnabled: sourceCharacter.segmentedOutputEnabled,
      nextStepOptionsEnabled: true,
      mapModeEnabled: false,
      largeGroupChatModeEnabled: false,
      sourceType: 'npc_migration',
      sourceCharacterId: sourceCharacter.id,
      sourceNpcId: npc.id,
      sourceMigrationRecordId: migrationId,
      modelParams: sourceCharacter.modelParams,
    );
    final companionName = npc.name.trim().isEmpty
        ? preview.sourceNpcName.trim()
        : npc.name.trim();
    final companionDescription = npc.description.trim().isNotEmpty
        ? npc.description.trim()
        : preview.manifest.archive.coreIdentity.trim();
    final roleCard = _composeManualNpcRoleCard(
      npc: npc.copyWith(
        name: companionName,
        description: companionDescription,
        roleCard: preview.archiveText,
      ),
      sourceCharacterName: sourceCharacter.name,
    );
    final companionNpc = NpcProfile(
      id: IdGenerator.generic('npc'),
      characterId: newCharacter.id,
      name: companionName,
      avatarDataUri: npc.avatarDataUri,
      description: companionDescription,
      impression: npc.impression,
      affinity: npc.affinity,
      createdAt: now,
      updatedAt: now,
      sourceType: NpcProfileSource.migrationCard,
      roleCard: roleCard,
      roleCardFinalized: true,
      companionEnabled: true,
      globalBinding: false,
      boundCharacterIds: <String>[newCharacter.id],
      impressionHistory: npc.impressionHistory,
      bondRoute: npc.bondRoute,
    );
    final worldBook = WorldBookEntry(
      title: preview.worldBookTitle.trim().isEmpty
          ? '你们的前尘 · ${npc.name}'
          : preview.worldBookTitle.trim(),
      content: preview.worldBookContent.trim(),
      global: false,
      tags: const <String>['带走NPC'],
      boundCharacterIds: <String>[newCharacter.id],
      triggerMode: WorldBookTriggerMode.always,
      injectionPosition: WorldBookInjectionPosition.rear,
      priority: 85,
    );

    final record = NpcMigrationRecord(
      id: migrationId,
      sourceCharacterId: sourceCharacter.id,
      sourceCharacterName: sourceCharacter.name,
      sourceNpcId: npc.id,
      sourceNpcName: npc.name,
      createdCharacterId: newCharacter.id,
      createdCharacterName: newCharacter.name,
      worldBookId: worldBook.id,
      worldBookTitle: worldBook.title,
      worldType: preview.worldType,
      inspiration: preview.inspiration,
      narrativeVoice: preview.narrativeVoice,
      memoryMode: preview.memoryMode,
      archiveText: preview.archiveText,
      worldBookContent: worldBook.content,
      characterPrompt: newCharacter.prompt,
      openingMessage: newCharacter.openingMessage,
      characterDescription: newCharacter.description,
      sourceDigest: preview.sourceDigest,
      outputKind: preview.outputKind,
      manifest: preview.manifest,
      farewellOutcome: preview.farewellOutcome,
      relationshipLock: preview.relationshipLock,
      keepsake: preview.keepsake,
      relationshipTasks: preview.relationshipTasks,
      albumEntries: _initialNpcMigrationAlbumEntries(preview, now),
      allowEcho: preview.allowEcho,
      createdAt: now,
    );

    final previousCharacters = List<CharacterProfile>.from(_characters);
    final previousWorldBooks = List<WorldBookEntry>.from(_worldBooks);
    final previousNpcProfiles = List<NpcProfile>.from(_npcProfiles);
    final previousMigrations = List<NpcMigrationRecord>.from(_npcMigrations);
    _characters.insert(0, newCharacter);
    _historyCache[newCharacter.id] = DialogueHistory.empty(newCharacter.id);
    _memoryCache[newCharacter.id] = CharacterMemory.empty(newCharacter.id);
    _gameStateCache[newCharacter.id] = GameStateSnapshot.empty(newCharacter.id);
    _mapStateCache[newCharacter.id] = MapWorldState.empty(newCharacter.id);
    _worldBooks.insert(0, worldBook);
    _npcProfiles.insert(0, companionNpc);
    _npcMessagesCache[companionNpc.id] = const <NpcChatMessage>[];
    _npcMigrations.insert(0, record);

    try {
      await _store.saveCharacters(_characters);
      await _store.saveDialogueHistory(_historyCache[newCharacter.id]!);
      await _store.saveCharacterMemory(_memoryCache[newCharacter.id]!);
      await _store.saveGameState(_gameStateCache[newCharacter.id]!);
      await _store.saveMapState(_mapStateCache[newCharacter.id]!);
      await _store.saveWorldBooks(_worldBooks);
      await _store.saveNpcProfiles(_npcProfiles);
      await _store.saveNpcMessages(companionNpc.id, const <NpcChatMessage>[]);
      await _store.saveNpcMigrations(_npcMigrations);
    } catch (error) {
      _characters
        ..clear()
        ..addAll(previousCharacters);
      _worldBooks
        ..clear()
        ..addAll(previousWorldBooks);
      _npcProfiles
        ..clear()
        ..addAll(previousNpcProfiles);
      _npcMigrations
        ..clear()
        ..addAll(previousMigrations);
      _historyCache.remove(newCharacter.id);
      _memoryCache.remove(newCharacter.id);
      _gameStateCache.remove(newCharacter.id);
      _mapStateCache.remove(newCharacter.id);
      _npcMessagesCache.remove(companionNpc.id);
      try {
        await _store.saveCharacters(_characters);
        await _store.saveWorldBooks(_worldBooks);
        await _store.saveNpcProfiles(_npcProfiles);
        await _store.saveNpcMigrations(_npcMigrations);
        await _store.deleteCharacterData(newCharacter.id);
        await _store.deleteNpcMessages(companionNpc.id);
      } catch (_) {}
      notifyListeners();
      return NpcMigrationCommitResult(error: '保存迁徙结果失败，已撤回本次创建：$error');
    }

    try {
      await _updateGamification(
        (state) {
          var next = state
              .incrementStat('totalCharactersCreated')
              .incrementStat('totalNpcMigrations')
              .setStatMax('maxActiveCharacters', characters.length);
          if (NpcMigrationMemoryMode.keepsOldWorldMemory(preview.memoryMode)) {
            next = next.incrementStat('totalNpcMigrationsWithMemory');
          }
          return next;
        },
        notify: false,
      );
    } catch (_) {}
    try {
      await selectCharacter(newCharacter.id);
    } catch (_) {
      notifyListeners();
    }
    return NpcMigrationCommitResult(record: record);
  }

  Future<NpcMigrationCommitResult> commitNpcMigrationWorldBookOnly(
    NpcMigrationPreview preview,
  ) async {
    if (preview.outputKind != NpcMigrationOutputKind.worldBookOnly) {
      return const NpcMigrationCommitResult(error: '这份预览不是独立世界书。');
    }
    final sourceCharacter = _findCharacter(preview.sourceCharacterId);
    final npc = npcProfileById(preview.sourceNpcId);
    if (sourceCharacter == null) {
      return const NpcMigrationCommitResult(error: '源模拟器不存在，无法写入迁徙结果。');
    }
    if (npc == null) {
      return const NpcMigrationCommitResult(error: '源 NPC 不存在，无法写入迁徙结果。');
    }

    final now = DateTime.now();
    final migrationId = IdGenerator.generic('npc_migration');
    final worldBook = WorldBookEntry(
      title: preview.worldBookTitle.trim().isEmpty
          ? '你们的前尘 · ${npc.name}'
          : preview.worldBookTitle.trim(),
      content: preview.worldBookContent.trim(),
      global: false,
      tags: const <String>['带走NPC', '世界观'],
      boundCharacterIds: const <String>[],
      triggerMode: WorldBookTriggerMode.always,
      injectionPosition: WorldBookInjectionPosition.rear,
      priority: 85,
    );
    final record = NpcMigrationRecord(
      id: migrationId,
      sourceCharacterId: sourceCharacter.id,
      sourceCharacterName: sourceCharacter.name,
      sourceNpcId: npc.id,
      sourceNpcName: npc.name,
      createdCharacterId: '',
      createdCharacterName: '',
      worldBookId: worldBook.id,
      worldBookTitle: worldBook.title,
      worldType: preview.worldType,
      inspiration: preview.inspiration,
      narrativeVoice: preview.narrativeVoice,
      memoryMode: preview.memoryMode,
      archiveText: preview.archiveText,
      worldBookContent: worldBook.content,
      characterPrompt: preview.characterPrompt,
      openingMessage: preview.openingMessage,
      characterDescription: preview.characterDescription,
      sourceDigest: preview.sourceDigest,
      outputKind: preview.outputKind,
      manifest: preview.manifest,
      farewellOutcome: preview.farewellOutcome,
      relationshipLock: preview.relationshipLock,
      keepsake: preview.keepsake,
      relationshipTasks: preview.relationshipTasks,
      albumEntries: _initialNpcMigrationAlbumEntries(
        preview,
        now,
        worldBookOnly: true,
      ),
      allowEcho: false,
      createdAt: now,
    );

    final previousWorldBooks = List<WorldBookEntry>.from(_worldBooks);
    final previousMigrations = List<NpcMigrationRecord>.from(_npcMigrations);
    _worldBooks.insert(0, worldBook);
    _npcMigrations.insert(0, record);
    try {
      await _store.saveWorldBooks(_worldBooks);
      await _store.saveNpcMigrations(_npcMigrations);
    } catch (error) {
      _worldBooks
        ..clear()
        ..addAll(previousWorldBooks);
      _npcMigrations
        ..clear()
        ..addAll(previousMigrations);
      try {
        await _store.saveWorldBooks(_worldBooks);
        await _store.saveNpcMigrations(_npcMigrations);
      } catch (_) {}
      notifyListeners();
      return NpcMigrationCommitResult(error: '保存前尘世界书失败，已撤回本次创建：$error');
    }
    try {
      await _updateGamification(
        (state) {
          var next = state.incrementStat('totalNpcMigrationWorldBooks');
          if (NpcMigrationMemoryMode.keepsOldWorldMemory(preview.memoryMode)) {
            next = next.incrementStat('totalNpcMigrationsWithMemory');
          }
          return next;
        },
        notify: false,
      );
    } catch (_) {}
    notifyListeners();
    return NpcMigrationCommitResult(record: record);
  }

  List<NpcMigrationAlbumEntry> _initialNpcMigrationAlbumEntries(
    NpcMigrationPreview preview,
    DateTime now, {
    bool worldBookOnly = false,
  }) {
    final entries = <NpcMigrationAlbumEntry>[];
    if (!preview.farewellOutcome.isEmpty) {
      entries.add(
        NpcMigrationAlbumEntry(
          id: IdGenerator.generic('npc_migration_album'),
          title: '旧世界告别',
          content: _formatFarewellOutcomeText(preview.farewellOutcome),
          sourceType: 'farewell',
          createdAt: now,
        ),
      );
    }
    entries.add(
      NpcMigrationAlbumEntry(
        id: IdGenerator.generic('npc_migration_album'),
        title: worldBookOnly ? '世界观保存成功' : '前尘新世界生成成功',
        content: worldBookOnly
            ? '${preview.sourceNpcName}的前尘世界观已保存为「${preview.worldBookTitle}」，可以绑定到其他世界继续使用。'
            : '${preview.sourceNpcName}与「${preview.worldType}」的前尘已经整理完成，生成了可游玩的新世界「${preview.characterName}」。',
        sourceType: 'migration',
        createdAt: now,
      ),
    );
    if (!preview.keepsake.isEmpty) {
      entries.add(
        NpcMigrationAlbumEntry(
          id: IdGenerator.generic('npc_migration_album'),
          title: '前尘信物：${preview.keepsake.name}',
          content:
              '${preview.keepsake.description}\n${preview.keepsake.emotionalMeaning}',
          sourceType: 'keepsake',
          createdAt: now,
        ),
      );
    }
    return entries;
  }

  Future<String?> triggerNpcMigrationEcho({
    required String recordId,
    required String echoType,
  }) async {
    final index = _npcMigrations.indexWhere((record) => record.id == recordId);
    if (index == -1) {
      return '没有找到这份前尘档案。';
    }
    final record = _npcMigrations[index];
    if (!record.createsCharacter) {
      return '只有已经创建的新世界才能触发前尘回声。';
    }
    final character = _findCharacter(record.createdCharacterId);
    if (character == null) {
      return '对应的新世界角色不存在。';
    }
    if (!record.allowEcho) {
      return '这份档案关闭了前尘回声。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 后再触发前尘回声。';
    }
    if (_isSending || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍后再触发。';
    }
    final history = await _ensureHistory(character.id);
    final recent = history.messages.length > 12
        ? history.messages.sublist(history.messages.length - 12)
        : history.messages;
    final gameState = await _ensureGameState(character.id);
    final directive = _buildNpcMigrationEchoDirective(
      record: record,
      echoType: echoType,
      recentTranscript: _formatTranscript(recent),
      gameState: _formatGameStateForNpcMigration(gameState),
    );
    final requestDirective = TurnDirective(
      mood: '前尘回声',
      focus: echoType,
      note: directive,
      intensity: 4,
    );
    final eventId = IdGenerator.generic('npc_migration_echo');
    final event = NpcMigrationEchoEvent(
      id: eventId,
      echoType: echoType,
      summary: '“$echoType”前尘回声正在生成。',
      directive: directive,
      status: NpcMigrationEchoStatus.pending,
      createdAt: DateTime.now(),
    );
    _npcMigrations[index] = record.copyWith(
      echoEvents: <NpcMigrationEchoEvent>[event, ...record.echoEvents],
    );
    await _store.saveNpcMigrations(_npcMigrations);
    await selectCharacter(character.id);
    final nextHistory = await _ensureHistory(character.id);
    final userMessage = ChatMessage(
      id: IdGenerator.message(),
      role: ChatRole.user,
      content: '【触发前尘回声】$echoType',
      timestamp: DateTime.now(),
      isSummarized: false,
    );
    final placeholder = ChatMessage(
      id: IdGenerator.message(),
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isSummarized: false,
    );
    final currentHistory = nextHistory.copyWith(
      messages: <ChatMessage>[...nextHistory.messages, userMessage],
    );
    final optimisticHistory = currentHistory.copyWith(
      messages: <ChatMessage>[...currentHistory.messages, placeholder],
    );
    _historyCache[character.id] = optimisticHistory;
    await _store.saveDialogueHistory(optimisticHistory);
    notifyListeners();
    final error = await _streamAssistantReply(
      character: character,
      originalHistory: currentHistory,
      optimisticHistory: optimisticHistory,
      placeholderMessageId: placeholder.id,
      requestMessages: currentHistory.messages,
      invalidatedMessageIds: const <String>{},
      requestTurnDirective: requestDirective,
    );
    final latestIndex =
        _npcMigrations.indexWhere((item) => item.id == recordId);
    if (latestIndex != -1) {
      final latest = _npcMigrations[latestIndex];
      final completed = error == null;
      final nextEvents = latest.echoEvents.map((item) {
        if (item.id != eventId) return item;
        return item.copyWith(
          status: completed
              ? NpcMigrationEchoStatus.completed
              : NpcMigrationEchoStatus.failed,
          summary: completed
              ? '“$echoType”前尘回声已经进入新世界剧情。'
              : '“$echoType”前尘回声生成失败，可稍后重试。',
          errorMessage: error ?? '',
        );
      }).toList(growable: false);
      final nextAlbums = completed
          ? <NpcMigrationAlbumEntry>[
              NpcMigrationAlbumEntry(
                id: IdGenerator.generic('npc_migration_album'),
                title: '前尘回声：$echoType',
                content: '“$echoType”前尘回声已经进入新世界剧情。',
                sourceType: 'echo',
                createdAt: DateTime.now(),
              ),
              ...latest.albumEntries,
            ]
          : latest.albumEntries;
      _npcMigrations[latestIndex] = latest.copyWith(
        echoEvents: nextEvents,
        albumEntries: nextAlbums,
      );
      await _store.saveNpcMigrations(_npcMigrations);
      notifyListeners();
    }
    return error;
  }

  Future<String?> reviseNpcMigrationRecord({
    required String recordId,
    required String section,
    required String instruction,
  }) async {
    final index = _npcMigrations.indexWhere((record) => record.id == recordId);
    if (index == -1) {
      return '没有找到这份前尘档案。';
    }
    if (section == '记忆强度' || section == '关系路线') {
      return _updateNpcMigrationRule(
        recordId: recordId,
        section: section,
        value: instruction,
      );
    }
    final record = _npcMigrations[index];
    final oldContent = _npcMigrationSectionContent(record, section);
    if (oldContent.trim().isEmpty) {
      return '这个部分暂时没有可重修内容。';
    }
    if (!_settings.canChat) {
      return 'AI 重修需要先配置 API。';
    }
    if (_isSending) {
      return '当前还有内容正在生成，请稍等。';
    }

    _isSending = true;
    notifyListeners();
    try {
      final basePrompt = '''
用户只要求重修以下部分：
$section

必须保留的事实：
${_protectedNpcMigrationFacts(record)}

原内容：
$oldContent

用户修改要求：
$instruction
''';
      final structuredSchema = switch (section) {
        '旧世界档案' =>
          '{"archive": ${jsonEncode(record.manifest.archive.toJson())}}',
        '关系任务' =>
          '{"tasks": [{"title":"任务名","description":"具体行动条件","stage":"阶段"}]}',
        '前尘信物' =>
          '{"keepsake":{"name":"名称","description":"外观","origin":"来历","emotionalMeaning":"关系意义","useEffectPrompt":"触发方向"}}',
        _ => '',
      };
      late String clean;
      if (structuredSchema.isNotEmpty) {
        final structured = await _runNpcMigrationStructuredTask(
          stageLabel: section,
          systemPrompt:
              '$_npcMigrationRevisionSystemPrompt\n只输出符合目标 schema 的 JSON 对象。',
          userPrompt: '$basePrompt\n\n【目标 schema】\n$structuredSchema',
          schemaHint: structuredSchema,
          validator: (data) => switch (section) {
            '旧世界档案' => data['archive'] is Map,
            '关系任务' => data['tasks'] is List,
            '前尘信物' => data['keepsake'] is Map,
            _ => false,
          },
          temperature: 0.32,
          topP: 0.84,
        );
        clean = jsonEncode(structured.data);
      } else {
        clean = (await _apiClient.runUtilityTask(
          settings: _settings,
          systemPrompt: _npcMigrationRevisionSystemPrompt,
          userPrompt: basePrompt,
          temperature: 0.32,
          topP: 0.84,
        ))
            .trim();
      }
      if (clean.isEmpty) {
        return 'AI 没有返回可用的新内容。';
      }
      var updated = _applyNpcMigrationRevision(record, section, clean);
      if (section == '旧世界档案') {
        final warnings = <String>{
          ...updated.manifest.qualityWarnings,
          '旧世界档案已重修，原 AI 世界补充段已移除，避免新旧设定冲突。',
        }.toList(growable: false);
        updated = updated.copyWith(
          manifest: updated.manifest.copyWith(qualityWarnings: warnings),
        );
        updated = updated.copyWith(
          worldBookContent: _composeNpcMigrationWorldBook(
            manifest: updated.manifest,
            generatedContent: '',
            npcName: record.sourceNpcName,
            worldType: record.worldType,
            narrativeVoice: record.narrativeVoice,
            allowEcho: record.allowEcho,
          ),
        );
      }
      updated = updated.copyWith(
        revisionHistory: <NpcMigrationRevisionEntry>[
          NpcMigrationRevisionEntry(
            id: IdGenerator.generic('npc_migration_revision'),
            section: section,
            oldContent: oldContent,
            newContent: clean,
            instruction: instruction,
            createdAt: DateTime.now(),
          ),
          ...updated.revisionHistory,
        ],
      );
      _npcMigrations[index] = updated;
      await _syncNpcMigrationRevision(updated, section);
      if (section == '旧世界档案') {
        await _syncNpcMigrationRevision(updated, '前尘世界书');
      }
      await _store.saveNpcMigrations(_npcMigrations);
      notifyListeners();
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (error) {
      return '重修失败：$error';
    } finally {
      _isSending = false;
      _npcMigrationBuildStage = '';
      notifyListeners();
    }
  }

  Future<String?> addNpcMigrationAlbumEntry({
    required String recordId,
    required String title,
    required String content,
    String note = '',
  }) async {
    final index = _npcMigrations.indexWhere((record) => record.id == recordId);
    if (index == -1) {
      return '没有找到这份前尘档案。';
    }
    final record = _npcMigrations[index];
    _npcMigrations[index] = record.copyWith(
      albumEntries: <NpcMigrationAlbumEntry>[
        NpcMigrationAlbumEntry(
          id: IdGenerator.generic('npc_migration_album'),
          title: title.trim().isEmpty ? '手动纪念' : title.trim(),
          content: content.trim(),
          note: note.trim(),
          sourceType: 'manual',
          createdAt: DateTime.now(),
        ),
        ...record.albumEntries,
      ],
    );
    await _store.saveNpcMigrations(_npcMigrations);
    notifyListeners();
    return null;
  }

  Future<String?> _updateNpcMigrationRule({
    required String recordId,
    required String section,
    required String value,
  }) async {
    final index = _npcMigrations.indexWhere((record) => record.id == recordId);
    if (index == -1) return '没有找到这份前尘档案。';
    final record = _npcMigrations[index];
    final oldContent = _npcMigrationSectionContent(record, section);
    var manifest = record.manifest;
    var memoryMode = record.memoryMode;
    var relationshipLock = record.relationshipLock;
    if (section == '记忆强度') {
      memoryMode = NpcMigrationMemoryMode.normalize(value);
      var runtimeFacts = manifest.memoryPolicy.runtimeFacts;
      var forbidden = manifest.memoryPolicy.forbiddenRecall
          .where((item) => !item.contains('普通回合不得主动识别'))
          .toList(growable: true);
      if (memoryMode == NpcMigrationMemoryMode.echo) {
        runtimeFacts = const <String>[];
        forbidden.add('普通回合不得主动识别、复述或推断任何具体旧世界事实。');
      } else if (runtimeFacts.isEmpty) {
        runtimeFacts = <String>[
          ...manifest.archive.continuityFacts,
          ...manifest.archive.keyEvents,
        ]
            .take(memoryMode == NpcMigrationMemoryMode.fragments ? 3 : 8)
            .toList(growable: false);
      } else if (memoryMode == NpcMigrationMemoryMode.fragments) {
        runtimeFacts = runtimeFacts.take(5).toList(growable: false);
      }
      manifest = manifest.copyWith(
        memoryPolicy: manifest.memoryPolicy.copyWith(
          mode: memoryMode,
          runtimeFacts: runtimeFacts,
          forbiddenRecall: forbidden,
        ),
      );
    } else {
      relationshipLock = NpcMigrationRelationshipLock.normalize(value);
      manifest = manifest.copyWith(
        relationship: manifest.relationship.copyWith(mode: relationshipLock),
      );
    }
    manifest = manifest.copyWith(
      qualityWarnings: <String>{
        ...manifest.qualityWarnings,
        '迁移规则已修改，原 AI 世界补充段已移除，避免残留设定越权。',
      }.toList(growable: false),
    );
    final worldBookContent = _composeNpcMigrationWorldBook(
      manifest: manifest,
      generatedContent: '',
      npcName: record.sourceNpcName,
      worldType: record.worldType,
      narrativeVoice: record.narrativeVoice,
      allowEcho: record.allowEcho,
    );
    final newContent = section == '记忆强度'
        ? NpcMigrationMemoryMode.label(memoryMode)
        : NpcMigrationRelationshipLock.label(relationshipLock);
    final updated = record.copyWith(
      memoryMode: memoryMode,
      relationshipLock: relationshipLock,
      manifest: manifest,
      worldBookContent: worldBookContent,
      revisionHistory: <NpcMigrationRevisionEntry>[
        NpcMigrationRevisionEntry(
          id: IdGenerator.generic('npc_migration_revision'),
          section: section,
          oldContent: oldContent,
          newContent: newContent,
          instruction: '选择：$newContent',
          createdAt: DateTime.now(),
        ),
        ...record.revisionHistory,
      ],
    );
    _npcMigrations[index] = updated;
    await _syncNpcMigrationRevision(updated, '前尘世界书');
    await _store.saveNpcMigrations(_npcMigrations);
    notifyListeners();
    return null;
  }

  Future<void> deleteNpcMigrationRecord(String recordId) async {
    final before = _npcMigrations.length;
    _npcMigrations.removeWhere((record) => record.id == recordId);
    if (_npcMigrations.length == before) return;
    await _store.saveNpcMigrations(_npcMigrations);
    notifyListeners();
  }

  Future<String?> migrateNpcToCharacter({
    required String npcId,
    required String worldType,
    String inspiration = '',
    String narrativeVoice = 'second',
    bool keepOldWorldMemory = true,
  }) async {
    final previewResult = await buildNpcMigrationPreview(
      npcId: npcId,
      worldType: worldType,
      inspiration: inspiration,
      narrativeVoice: narrativeVoice,
      memoryMode: keepOldWorldMemory
          ? NpcMigrationMemoryMode.full
          : NpcMigrationMemoryMode.echo,
    );
    final preview = previewResult.preview;
    if (preview == null) {
      return previewResult.error ?? '带走 NPC 失败。';
    }
    final commit = await commitNpcMigrationPreview(preview);
    return commit.error;
  }

  Future<String?> createStoryBranchFromMessage({
    required String messageId,
    required String branchName,
  }) async {
    final sourceCharacter = currentCharacter;
    if (sourceCharacter == null) {
      return '请先选择一个角色。';
    }

    final trimmedName = branchName.trim();
    if (trimmedName.isEmpty) {
      return '分支名字不能为空。';
    }

    final rootCharacter =
        _findCharacter(sourceCharacter.rootCharacterId) ?? sourceCharacter;
    final sourceHistory = await _ensureHistory(sourceCharacter.id);
    final originIndex =
        sourceHistory.messages.indexWhere((message) => message.id == messageId);
    if (originIndex == -1) {
      return '没有找到这条消息，暂时没法从这里开分支。';
    }

    final branchId = IdGenerator.character();
    final now = DateTime.now();
    final branch = CharacterProfile(
      id: branchId,
      name: rootCharacter.name,
      createdAt: now,
      prompt: sourceCharacter.prompt,
      description: sourceCharacter.description,
      openingMessage: '',
      hiddenPrompt: sourceCharacter.hiddenPrompt,
      presetId: null,
      isPromptLocked: sourceCharacter.isPromptLocked,
      streamingOutputEnabled: sourceCharacter.streamingOutputEnabled,
      segmentedOutputEnabled: sourceCharacter.segmentedOutputEnabled,
      nextStepOptionsEnabled: sourceCharacter.nextStepOptionsEnabled,
      mapModeEnabled: sourceCharacter.mapModeEnabled,
      largeGroupChatModeEnabled: sourceCharacter.largeGroupChatModeEnabled,
      avatarDataUri: sourceCharacter.avatarDataUri,
      branchSourceCharacterId: rootCharacter.id,
      branchOriginMessageId: messageId,
      branchName: trimmedName,
      gameplaySystem: _gameplaySystemAtMessage(
        _messageWithNearestStateSnapshot(sourceHistory.messages, originIndex) ??
            sourceHistory.messages[originIndex],
        sourceCharacter.gameplaySystem,
      ),
      modelParams: sourceCharacter.modelParams,
    );

    final branchMessages =
        sourceHistory.messages.take(originIndex + 1).toList(growable: false);
    final branchHistory = DialogueHistory(
      characterId: branchId,
      messages: branchMessages,
    );
    final sourceMemory = await _ensureMemory(sourceCharacter.id);
    final branchMessageIds =
        branchMessages.map((message) => message.id).toSet();
    final branchMemory = sourceMemory.copyWith(
      characterId: branchId,
      summaries: sourceMemory.summaries
          .where((summary) =>
              summary.relatedMessageIds.isEmpty ||
              summary.relatedMessageIds.any(branchMessageIds.contains))
          .toList(growable: false),
    );
    final snapshotMessage =
        _messageWithNearestStateSnapshot(branchMessages, originIndex);
    final branchGameState = _gameStateAtBranchPoint(
      branchMessages,
      snapshotMessage: snapshotMessage,
      sourceCharacterId: sourceCharacter.id,
      branchId: branchId,
    );
    final sourceMapState = await _ensureMapState(sourceCharacter.id);
    final branchMapState = _mapStateForBranch(
      sourceMapState,
      branchGameState,
      branchId: branchId,
    );

    _characters.insert(0, branch);
    _historyCache[branchId] = branchHistory;
    _memoryCache[branchId] = branchMemory;
    _gameStateCache[branchId] = branchGameState;
    _mapStateCache[branchId] = branchMapState;

    final sourceNpcProfiles = _npcProfilesForBranchSnapshot(
      sourceCharacterId: sourceCharacter.id,
      rootCharacterId: rootCharacter.id,
      state: branchGameState,
      snapshotMessage: snapshotMessage,
    );
    for (final npc in sourceNpcProfiles) {
      if (npc.hasReusableRoleCard) {
        final index = _npcProfiles.indexWhere((item) => item.id == npc.id);
        if (index != -1) {
          final existing = _npcProfiles[index];
          _npcProfiles[index] = existing.copyWith(
            boundCharacterIds: _mergeNpcBoundCharacterIds(
              existing.boundCharacterIds,
              <String>[branchId],
            ),
            updatedAt: now,
          );
        }
        continue;
      }
      final branchNpcId = IdGenerator.generic('npc');
      final branchNpc = npc.copyWith(
        id: branchNpcId,
        characterId: branchId,
        createdAt: now,
        updatedAt: now,
        globalBinding: false,
        boundCharacterIds: <String>[branchId],
      );
      _npcProfiles.insert(0, branchNpc);
      final npcMessages = await _ensureNpcMessages(npc.id);
      final branchNpcMessages = npcMessages
          .map((message) => message.copyWith(npcId: branchNpcId))
          .toList(growable: false);
      _npcMessagesCache[branchNpcId] = branchNpcMessages;
      await _store.saveNpcMessages(branchNpcId, branchNpcMessages);
    }

    await _store.saveCharacters(_characters);
    await _store.saveDialogueHistory(branchHistory);
    await _store.saveCharacterMemory(branchMemory);
    await _store.saveGameState(branchGameState);
    await _store.saveMapState(branchMapState);
    await _store.saveNpcProfiles(_npcProfiles);
    await selectCharacter(branchId);
    return null;
  }

  Future<void> updateCharacter(String characterId, CharacterDraft draft) async {
    final index = _characters.indexWhere((item) => item.id == characterId);
    if (index == -1) {
      return;
    }

    final original = _characters[index];
    final nextLargeGroupChatModeEnabled = original.largeGroupChatModeEnabled ||
        (!original.mapModeEnabled && draft.largeGroupChatModeEnabled);
    final nextMapModeEnabled = nextLargeGroupChatModeEnabled
        ? false
        : original.mapModeEnabled || draft.mapModeEnabled;
    _characters[index] = original.copyWith(
      name: draft.name.trim(),
      prompt: original.isPromptLocked ? original.prompt : draft.prompt.trim(),
      hiddenPrompt: original.isPromptLocked
          ? original.hiddenPrompt
          : _resolveHiddenPrompt(draft.hiddenPrompt),
      description: draft.description.trim(),
      openingMessage: draft.openingMessage.trim(),
      streamingOutputEnabled: draft.streamingOutputEnabled,
      segmentedOutputEnabled:
          nextLargeGroupChatModeEnabled ? false : draft.segmentedOutputEnabled,
      nextStepOptionsEnabled:
          nextLargeGroupChatModeEnabled ? false : draft.nextStepOptionsEnabled,
      mapModeEnabled: nextMapModeEnabled,
      largeGroupChatModeEnabled: nextLargeGroupChatModeEnabled,
      avatarDataUri: draft.avatarDataUri.trim(),
      modelParams: draft.modelParams,
    );

    await _store.saveCharacters(_characters);
    notifyListeners();
  }

  Future<String?> deleteCharacter(String characterId) async {
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请先停止或等待完成后再删除。';
    }
    if (_isDataMutationInProgress) {
      return '数据正在变更，请稍等。';
    }
    final target = _findCharacter(characterId);
    if (target == null) {
      return null;
    }

    final visibleCharacters =
        _characters.where((character) => !character.isStoryBranch).toList();
    if (!target.isStoryBranch && visibleCharacters.length <= 1) {
      return '至少保留一个角色，避免主界面没有可对话对象。';
    }

    _isDataMutationInProgress = true;
    notifyListeners();
    try {
      if (!target.isStoryBranch) {
        await _createSafetySnapshotForCharacter(
          target.id,
          reason: '删除角色前自动保护',
        );
      }

      final removedCharacterIds = <String>{
        characterId,
        if (!target.isStoryBranch)
          ..._characters
              .where((item) => item.branchSourceCharacterId == characterId)
              .map((item) => item.id),
      };

      _characters.removeWhere((item) => removedCharacterIds.contains(item.id));
      for (var index = 0; index < _userProfiles.length; index++) {
        final profile = _userProfiles[index];
        if (!profile.boundCharacterIds.any(removedCharacterIds.contains)) {
          continue;
        }
        _userProfiles[index] = profile.copyWith(
          boundCharacterIds: profile.boundCharacterIds
              .where((id) => !removedCharacterIds.contains(id))
              .toList(growable: false),
        );
      }
      for (var index = 0; index < _npcProfiles.length; index++) {
        final profile = _npcProfiles[index];
        if (!profile.boundCharacterIds.any(removedCharacterIds.contains)) {
          continue;
        }
        final nextBound = profile.boundCharacterIds
            .where((id) => !removedCharacterIds.contains(id))
            .toList(growable: false);
        _npcProfiles[index] = profile.copyWith(
          boundCharacterIds: nextBound,
          clearBoundCharacterIds: nextBound.isEmpty,
        );
      }
      for (final removedId in removedCharacterIds) {
        _historyCache.remove(removedId);
        _memoryCache.remove(removedId);
        _gameStateCache.remove(removedId);
        _mapStateCache.remove(removedId);
        _lastNpcExtractionMessageCounts.remove(removedId);
      }
      _toolResults.removeWhere(
          (result) => removedCharacterIds.contains(result.characterId));
      _fanficResults.removeWhere(
          (result) => removedCharacterIds.contains(result.characterId));
      _worldCalendarEvents.removeWhere(
        (event) => removedCharacterIds.contains(event.characterId),
      );
      final removedNpcIds = _npcProfiles
          .where((profile) => removedCharacterIds.contains(profile.characterId))
          .map((profile) => profile.id)
          .toList(growable: false);
      _npcProfiles.removeWhere(
        (profile) => removedCharacterIds.contains(profile.characterId),
      );
      for (final npcId in removedNpcIds) {
        _npcMessagesCache.remove(npcId);
        await _store.deleteNpcMessages(npcId);
      }

      await _store.saveCharacters(_characters);
      await _store.saveUserProfiles(_userProfiles);
      await _store.saveToolResults(_toolResults);
      await _store.saveFanficResults(_fanficResults);
      await _store.saveWorldCalendarEvents(_worldCalendarEvents);
      await _store.saveGamificationState(_gamification);
      await _store.saveNpcProfiles(_npcProfiles);
      await _store.saveNpcMigrations(_npcMigrations);
      for (final removedId in removedCharacterIds) {
        await _store.deleteCharacterData(removedId);
      }
      await _updateGamification(
        (state) => state.incrementStat('totalCharactersDeleted'),
        notify: false,
      );

      if (removedCharacterIds.contains(_selectedCharacterId)) {
        final nextVisible = _characters.firstWhere(
          (character) => !character.isStoryBranch,
          orElse: () => _characters.first,
        );
        _selectedCharacterId = nextVisible.id;
        await _store.saveSelectedCharacterId(_selectedCharacterId);
        await _loadCharacterState(_selectedCharacterId!);
      }

      notifyListeners();
      return null;
    } finally {
      _isDataMutationInProgress = false;
      notifyListeners();
    }
  }

  Future<String?> updateMemorySummary(
    String summaryId,
    String summaryText, {
    String? characterId,
  }) async {
    final targetCharacterId = characterId ?? _selectedCharacterId;
    final trimmedId = summaryId.trim();
    final trimmedText = summaryText.trim();
    if (targetCharacterId == null || targetCharacterId.trim().isEmpty) {
      return '请先选择一个角色。';
    }
    if (trimmedId.isEmpty) {
      return '这条记忆缺少编号，暂时不能编辑。';
    }
    if (trimmedText.isEmpty) {
      return '记忆内容不能为空。';
    }

    final memory = await _ensureMemory(targetCharacterId);
    final index =
        memory.summaries.indexWhere((summary) => summary.id == trimmedId);
    if (index < 0) {
      return '没有找到这条长期记忆，可能已经被删除。';
    }

    final updatedSummaries =
        List<CharacterMemorySummary>.from(memory.summaries);
    updatedSummaries[index] = updatedSummaries[index].copyWith(
      summaryText: trimmedText,
    );
    final updatedMemory = memory.copyWith(summaries: updatedSummaries);
    _memoryCache[targetCharacterId] = updatedMemory;
    await _store.saveCharacterMemory(updatedMemory);
    notifyListeners();
    return null;
  }

  Future<String?> addMemorySummary(
    String summaryText, {
    String? characterId,
  }) async {
    final targetCharacterId = characterId ?? _selectedCharacterId;
    final trimmedText = summaryText.trim();
    if (targetCharacterId == null || targetCharacterId.trim().isEmpty) {
      return '请先选择一个角色。';
    }
    if (trimmedText.isEmpty) {
      return '记忆内容不能为空。';
    }

    final memory = await _ensureMemory(targetCharacterId);
    final summary = CharacterMemorySummary(
      id: IdGenerator.generic('memory'),
      summaryText: trimmedText,
      relatedMessageIds: const <String>[],
      timestamp: DateTime.now(),
    );
    final updatedMemory = memory.copyWith(
      summaries: <CharacterMemorySummary>[...memory.summaries, summary],
    );
    _memoryCache[targetCharacterId] = updatedMemory;
    await _store.saveCharacterMemory(updatedMemory);
    notifyListeners();
    return null;
  }

  Future<String?> deleteMemorySummary(
    String summaryId, {
    String? characterId,
  }) async {
    final targetCharacterId = characterId ?? _selectedCharacterId;
    final trimmedId = summaryId.trim();
    if (targetCharacterId == null || targetCharacterId.trim().isEmpty) {
      return '请先选择一个角色。';
    }
    if (trimmedId.isEmpty) {
      return '这条记忆缺少编号，暂时不能删除。';
    }

    final memory = await _ensureMemory(targetCharacterId);
    final updatedSummaries = memory.summaries
        .where((summary) => summary.id != trimmedId)
        .toList(growable: false);
    if (updatedSummaries.length == memory.summaries.length) {
      return '没有找到这条长期记忆，可能已经被删除。';
    }

    final updatedMemory = memory.copyWith(summaries: updatedSummaries);
    _memoryCache[targetCharacterId] = updatedMemory;
    await _store.saveCharacterMemory(updatedMemory);
    notifyListeners();
    return null;
  }

  Future<void> createUserProfile(UserProfileDraft draft) async {
    final profile = UserProfile(
      id: IdGenerator.generic('user'),
      name: draft.name.trim(),
      createdAt: DateTime.now(),
      persona: draft.persona.trim(),
      avatarDataUri: draft.avatarDataUri.trim(),
      gender: draft.gender.trim(),
      description: draft.description.trim(),
      boundCharacterIds: _validBoundCharacterIds(draft.boundCharacterIds),
    );

    _userProfiles.insert(0, profile);
    await _store.saveUserProfiles(_userProfiles);
    notifyListeners();
  }

  Future<void> updateUserProfile(
      String profileId, UserProfileDraft draft) async {
    final index = _userProfiles.indexWhere((item) => item.id == profileId);
    if (index == -1) {
      return;
    }

    final original = _userProfiles[index];
    _userProfiles[index] = original.copyWith(
      name: draft.name.trim(),
      persona: draft.persona.trim(),
      avatarDataUri: draft.avatarDataUri.trim(),
      gender: draft.gender.trim(),
      description: draft.description.trim(),
      boundCharacterIds: _validBoundCharacterIds(draft.boundCharacterIds),
    );

    await _store.saveUserProfiles(_userProfiles);
    notifyListeners();
  }

  Future<void> deleteUserProfile(String profileId) async {
    final before = _userProfiles.length;
    _userProfiles.removeWhere((item) => item.id == profileId);
    if (_userProfiles.length == before) {
      return;
    }

    await _store.saveUserProfiles(_userProfiles);
    notifyListeners();
  }

  Future<void> createNpcProfile(NpcProfileDraft draft) async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }

    final now = DateTime.now();
    final profile = NpcProfile(
      id: IdGenerator.generic('npc'),
      characterId: character.id,
      name: draft.name.trim(),
      avatarDataUri: draft.avatarDataUri.trim(),
      description: draft.description.trim(),
      impression: draft.impression.trim(),
      affinity: draft.affinity,
      lifecycle: draft.lifecycle,
      createdAt: now,
      updatedAt: now,
      sourceType: NpcProfileSource.normalize(draft.sourceType),
      roleCard: draft.roleCard.trim(),
      roleCardFinalized:
          draft.roleCardFinalized || draft.roleCard.trim().isNotEmpty,
      companionEnabled: draft.companionEnabled,
      globalBinding: draft.globalBinding,
      boundCharacterIds: _validNpcBoundCharacterIds(
        draft.boundCharacterIds,
        fallbackCharacterId: character.id,
        global: draft.globalBinding,
      ),
      impressionHistory: draft.impression.trim().isEmpty
          ? const <NpcImpressionEntry>[]
          : <NpcImpressionEntry>[
              NpcImpressionEntry(
                id: IdGenerator.generic('npc_imp'),
                summary: draft.impression.trim(),
                createdAt: now,
              ),
            ],
    );

    _npcProfiles.insert(0, profile);
    _npcMessagesCache[profile.id] = const <NpcChatMessage>[];
    await _store.saveNpcProfiles(_npcProfiles);
    await _store.saveNpcMessages(profile.id, const <NpcChatMessage>[]);
    await _updateGamification(
      (state) => state.incrementStat('totalNpcProfilesCreated'),
      notify: false,
    );
    notifyListeners();
  }

  Future<void> updateNpcProfile(String npcId, NpcProfileDraft draft) async {
    final index = _npcProfiles.indexWhere((item) => item.id == npcId);
    if (index == -1) {
      return;
    }

    final original = _npcProfiles[index];
    final nextImpression = draft.impression.trim();
    _npcProfiles[index] = original.copyWith(
      name: draft.name.trim(),
      avatarDataUri: draft.avatarDataUri.trim(),
      description: draft.description.trim(),
      impression: nextImpression,
      affinity: draft.affinity,
      lifecycle: draft.lifecycle,
      sourceType: NpcProfileSource.normalize(draft.sourceType),
      roleCard: draft.roleCard.trim(),
      roleCardFinalized:
          draft.roleCardFinalized || draft.roleCard.trim().isNotEmpty,
      companionEnabled: draft.companionEnabled,
      globalBinding: draft.globalBinding,
      boundCharacterIds: _validNpcBoundCharacterIds(
        draft.boundCharacterIds,
        fallbackCharacterId: original.characterId,
        global: draft.globalBinding,
      ),
      updatedAt: DateTime.now(),
    );
    await _store.saveNpcProfiles(_npcProfiles);
    notifyListeners();
  }

  Future<String?> updateNpcBindings({
    required String npcId,
    required bool companionEnabled,
    required bool globalBinding,
    required List<String> boundCharacterIds,
  }) async {
    final index = _npcProfiles.indexWhere((item) => item.id == npcId);
    if (index == -1) {
      return '没有找到这个 NPC。';
    }
    final original = _npcProfiles[index];
    if (companionEnabled && !original.hasReusableRoleCard) {
      return '请先点“整理成 NPC 角色卡”，补全干净人设后再绑定到世界。';
    }
    _npcProfiles[index] = original.copyWith(
      companionEnabled: companionEnabled,
      globalBinding: globalBinding,
      boundCharacterIds: _validNpcBoundCharacterIds(
        boundCharacterIds,
        fallbackCharacterId: original.characterId,
        global: globalBinding,
      ),
      updatedAt: DateTime.now(),
    );
    await _store.saveNpcProfiles(_npcProfiles);
    notifyListeners();
    return null;
  }

  Future<String?> convertNpcToRoleCard(String npcId) async {
    final index = _npcProfiles.indexWhere((item) => item.id == npcId);
    if (index == -1) {
      return '没有找到这个 NPC。';
    }
    final npc = _npcProfiles[index];
    final character = _findCharacter(npc.characterId);
    final roleCard = npc.roleCard.trim().isEmpty
        ? _composeManualNpcRoleCard(
            npc: npc,
            sourceCharacterName: character?.name ?? '未知模拟器',
          )
        : npc.roleCard.trim();
    _npcProfiles[index] = npc.copyWith(
      sourceType: NpcProfileSource.manual,
      roleCard: roleCard,
      roleCardFinalized: true,
      companionEnabled: true,
      globalBinding: npc.globalBinding,
      boundCharacterIds: _validNpcBoundCharacterIds(
        npc.boundCharacterIds,
        fallbackCharacterId: npc.characterId,
        global: npc.globalBinding,
      ),
      updatedAt: DateTime.now(),
    );
    await _store.saveNpcProfiles(_npcProfiles);
    notifyListeners();
    return null;
  }

  Future<NpcRoleCardDraftResult> finalizeNpcRoleCard({
    required String npcId,
    String extraInstruction = '',
  }) async {
    final index = _npcProfiles.indexWhere((item) => item.id == npcId);
    if (index == -1) {
      return const NpcRoleCardDraftResult(error: '没有找到这个 NPC。');
    }
    final result = await buildNpcRoleCardDraft(
      npcId: npcId,
      extraInstruction: extraInstruction,
    );
    final draft = result.draft;
    if (result.error != null || draft == null) {
      return result;
    }
    final original = _npcProfiles[index];
    final next = original.copyWith(
      name: draft.name.trim().isEmpty ? original.name : draft.name.trim(),
      description: draft.description.trim(),
      impression: draft.impression.trim(),
      affinity: draft.affinity,
      sourceType: NpcProfileSource.migrationCard,
      roleCard: draft.roleCard.trim(),
      roleCardFinalized: true,
      companionEnabled: true,
      globalBinding: original.globalBinding,
      boundCharacterIds: _validNpcBoundCharacterIds(
        original.boundCharacterIds,
        fallbackCharacterId: original.characterId,
        global: original.globalBinding,
      ),
      updatedAt: DateTime.now(),
    );
    _npcProfiles[index] = next;
    await _store.saveNpcProfiles(_npcProfiles);
    notifyListeners();
    return NpcRoleCardDraftResult(
      draft: draft.copyWith(
        companionEnabled: true,
        globalBinding: next.globalBinding,
        boundCharacterIds: next.boundCharacterIds,
        roleCardFinalized: true,
      ),
    );
  }

  Future<NpcRoleCardDraftResult> buildNpcRoleCardDraft({
    required String npcId,
    String extraInstruction = '',
    void Function(String partial)? onChunk,
  }) async {
    final npc = npcProfileById(npcId);
    if (npc == null) {
      return const NpcRoleCardDraftResult(error: '没有找到这个 NPC。');
    }
    final character = _findCharacter(npc.characterId);
    if (character == null) {
      return const NpcRoleCardDraftResult(error: '源模拟器不存在。');
    }
    if (!_settings.canChat) {
      return const NpcRoleCardDraftResult(error: '请先在设置页填好 API 地址、密钥和模型名称。');
    }
    if (_isSending) {
      return const NpcRoleCardDraftResult(error: '当前还有内容正在生成，请稍等。');
    }

    _isSending = true;
    notifyListeners();
    try {
      final messages = await _ensureNpcMessages(npc.id);
      final history = await _ensureHistory(character.id);
      final buffer = StringBuffer();
      await for (final chunk in _apiClient.streamUtilityTask(
        settings: _settings,
        systemPrompt: _npcRoleCardSystemPrompt,
        userPrompt: _buildNpcRoleCardPrompt(
          character: character,
          npc: npc,
          npcMessages: messages,
          history: history,
          extraInstruction: extraInstruction,
        ),
        temperature: 0.42,
        topP: 0.86,
      )) {
        buffer.write(chunk);
        onChunk?.call(buffer.toString());
      }
      final raw = buffer.toString();
      final draft = _parseNpcRoleCardDraft(
        raw,
        npc: npc,
        character: character,
      );
      return NpcRoleCardDraftResult(draft: draft);
    } on LlmApiException catch (error) {
      return NpcRoleCardDraftResult(error: error.message);
    } catch (error) {
      return NpcRoleCardDraftResult(error: 'NPC 角色卡生成失败：$error');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<NpcRoleCardDraftResult> buildNpcRoleCardDraftFromInspiration({
    required String inspiration,
    void Function(String partial)? onChunk,
  }) async {
    final character = currentCharacter;
    final trimmed = inspiration.trim();
    if (character == null) {
      return const NpcRoleCardDraftResult(error: '请先选择一个源模拟器。');
    }
    if (trimmed.isEmpty) {
      return const NpcRoleCardDraftResult(error: '请先写一点 NPC 信息或角色卡。');
    }
    if (!_settings.canChat) {
      return const NpcRoleCardDraftResult(error: '请先在设置页填好 API 地址、密钥和模型名称。');
    }
    if (_isSending) {
      return const NpcRoleCardDraftResult(error: '当前还有内容正在生成，请稍等。');
    }

    _isSending = true;
    notifyListeners();
    try {
      final history = await _ensureHistory(character.id);
      final tempNpc = NpcProfile(
        id: 'npc_draft',
        characterId: character.id,
        name: '待生成 NPC',
        description: trimmed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        sourceType: NpcProfileSource.manual,
      );
      final buffer = StringBuffer();
      await for (final chunk in _apiClient.streamUtilityTask(
        settings: _settings,
        systemPrompt: _npcRoleCardSystemPrompt,
        userPrompt: _buildNpcRoleCardInspirationPrompt(
          character: character,
          history: history,
          inspiration: trimmed,
        ),
        temperature: 0.58,
        topP: 0.9,
      )) {
        buffer.write(chunk);
        onChunk?.call(buffer.toString());
      }
      final raw = buffer.toString();
      final draft = _parseNpcRoleCardDraft(
        raw,
        npc: tempNpc,
        character: character,
      ).copyWith(
        sourceType: NpcProfileSource.manual,
        companionEnabled: false,
        globalBinding: false,
        boundCharacterIds: const <String>[],
      );
      return NpcRoleCardDraftResult(draft: draft);
    } on LlmApiException catch (error) {
      return NpcRoleCardDraftResult(error: error.message);
    } catch (error) {
      return NpcRoleCardDraftResult(error: 'NPC 角色卡生成失败：$error');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> deleteNpcProfile(String npcId) async {
    final before = _npcProfiles.length;
    _npcProfiles.removeWhere((profile) => profile.id == npcId);
    if (_npcProfiles.length == before) {
      return;
    }

    _npcMessagesCache.remove(npcId);
    await _store.saveNpcProfiles(_npcProfiles);
    await _store.deleteNpcMessages(npcId);
    notifyListeners();
  }

  Future<void> loadNpcThread(String npcId) async {
    if (_npcMessagesCache.containsKey(npcId)) {
      return;
    }
    _npcMessagesCache[npcId] = await _store.loadNpcMessages(npcId);
    notifyListeners();
  }

  Future<String?> queueNpcUserMessage(String npcId, String content) async {
    final profile = npcProfileById(npcId);
    final trimmed = content.trim();

    if (profile == null) {
      return '没有找到这个 NPC。';
    }
    if (!profile.canSendMessages) {
      return '该 NPC 当前为「${profile.lifecycle.label}」状态，私聊已冻结。';
    }
    if (trimmed.isEmpty) {
      return '消息内容不能为空。';
    }
    if (_activeNpcReplyingId != null) {
      return 'NPC 正在回复中，请稍等。';
    }

    final messages = await _ensureNpcMessages(npcId);
    final message = NpcChatMessage(
      id: IdGenerator.message(),
      npcId: npcId,
      role: NpcMessageRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
      batchId: IdGenerator.generic('npc_user_batch'),
    );
    final nextMessages = <NpcChatMessage>[...messages, message];
    _npcMessagesCache[npcId] = nextMessages;
    await _store.saveNpcMessages(npcId, nextMessages);

    _touchNpcProfile(profile);
    await _store.saveNpcProfiles(_npcProfiles);
    notifyListeners();
    return null;
  }

  Future<String?> requestNpcReply(String npcId) async {
    final npc = npcProfileById(npcId);
    final character = _characterForNpcInteraction(npc);
    if (npc == null || character == null) {
      return '没有找到这个 NPC。';
    }
    if (!npc.canSendMessages) {
      return '该 NPC 当前为「${npc.lifecycle.label}」状态，不会再回复消息。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_activeNpcReplyingId != null) {
      return 'NPC 正在回复中，请稍等。';
    }

    final messages = await _ensureNpcMessages(npcId);
    if (!_hasPendingNpcUserMessages(messages)) {
      return '还没有待发送给 NPC 的消息。';
    }

    _activeNpcReplyingId = npcId;
    notifyListeners();

    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _npcChatSystemPrompt,
        userPrompt: _buildNpcChatPrompt(
          character: character,
          npc: npc,
          messages: messages,
        ),
        temperature: character.modelParams.temperature,
        topP: character.modelParams.topP,
      );

      final parsed = _parseNpcReply(raw);
      final now = DateTime.now();
      final batchId = IdGenerator.generic('npc_reply_batch');
      final replies = parsed.messages
          .map(
            (content) => NpcChatMessage(
              id: IdGenerator.message(),
              npcId: npcId,
              role: NpcMessageRole.npc,
              content: content.trim(),
              timestamp: now,
              batchId: batchId,
            ),
          )
          .toList(growable: false);

      final nextMessages = <NpcChatMessage>[...messages, ...replies];
      _npcMessagesCache[npcId] = nextMessages;
      await _store.saveNpcMessages(npcId, nextMessages);

      final impressionEntry = NpcImpressionEntry(
        id: IdGenerator.generic('npc_imp'),
        summary: normalizeNpcImpressionText(parsed.impression).trim().isEmpty
            ? '本次私聊后，${npc.name}对用户角色的态度产生了轻微变化，但模型没有返回明确总结。'
            : normalizeNpcImpressionText(parsed.impression),
        createdAt: now,
      );
      _applyNpcImpressionPatch(
        npcId,
        impressionEntry,
        affinity: parsed.affinity,
        affinityDelta: parsed.affinityDelta,
        bondStage: parsed.bondStage,
        bondRoute: parsed.bondRoute,
      );
      final updatedNpc = npcProfileById(npcId);
      if (updatedNpc != null) {
        await _noteNpcBondScore(updatedNpc.bondRoute.score);
      }
      await _store.saveNpcProfiles(_npcProfiles);
      await _updateGamification(
        (state) => state
            .incrementStat('totalNpcReplies')
            .incrementDailyStat('npcReplies'),
        notify: false,
      );
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (error) {
      return 'NPC 回复失败：$error';
    } finally {
      _activeNpcReplyingId = null;
      notifyListeners();
    }
  }

  Future<void> updateNpcMessageContent(
    String npcId,
    String messageId,
    String nextContent,
  ) async {
    final trimmed = nextContent.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final messages = await _ensureNpcMessages(npcId);
    final messageIndex =
        messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) {
      return;
    }

    final nextMessages = List<NpcChatMessage>.from(messages);
    nextMessages[messageIndex] = nextMessages[messageIndex].copyWith(
      content: trimmed,
    );

    _npcMessagesCache[npcId] = nextMessages;
    await _store.saveNpcMessages(npcId, nextMessages);
    notifyListeners();
  }

  Future<String?> generateNpcInnerVoice(
    String npcId,
    String messageId, {
    bool regenerate = false,
  }) async {
    final npc = npcProfileById(npcId);
    final character = _characterForNpcInteraction(npc);
    if (npc == null || character == null) {
      return '没有找到这个 NPC。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_activeNpcReplyingId != null || _isSending) {
      return '当前还有内容正在生成，请稍等。';
    }
    final messages = await _ensureNpcMessages(npcId);
    final index = messages.indexWhere((message) => message.id == messageId);
    if (index == -1) {
      return '没有找到这条气泡。';
    }
    final target = messages[index];
    if (target.role != NpcMessageRole.npc) {
      return '只能听 NPC 气泡的心声。';
    }
    if (!regenerate && target.innerVoice.trim().isNotEmpty) {
      return null;
    }

    _activeNpcReplyingId = npcId;
    notifyListeners();
    try {
      final recent = messages.length > 12
          ? messages.sublist(messages.length - 12)
          : messages;
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _npcInnerVoiceSystemPrompt,
        userPrompt: '''
当前模拟器：${character.name}
NPC：${npc.name}
NPC 简介：${npc.description.trim().isEmpty ? '暂无。' : npc.description.trim()}
NPC 当前印象：${npc.impression.trim().isEmpty ? '暂无明确印象。' : npc.impression.trim()}

最近私聊：
${_formatNpcTranscript(recent, npcName: npc.name)}

目标气泡：
${target.content}

请生成这条气泡背后的一段心声。
''',
        temperature: 0.68,
        topP: 0.9,
      );
      final innerVoice = raw.trim();
      if (innerVoice.isEmpty) {
        return '模型没有返回可用心声。';
      }
      final nextMessages = List<NpcChatMessage>.from(messages);
      nextMessages[index] = target.copyWith(
        innerVoice: innerVoice,
        innerVoiceGeneratedAt: DateTime.now(),
      );
      _npcMessagesCache[npcId] = nextMessages;
      await _store.saveNpcMessages(npcId, nextMessages);
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (error) {
      return '心声生成失败：$error';
    } finally {
      _activeNpcReplyingId = null;
      notifyListeners();
    }
  }

  Future<void> deleteNpcMessage(String npcId, String messageId) async {
    final messages = await _ensureNpcMessages(npcId);
    final nextMessages = messages
        .where((message) => message.id != messageId)
        .toList(growable: false);
    if (nextMessages.length == messages.length) {
      return;
    }

    _npcMessagesCache[npcId] = nextMessages;
    await _store.saveNpcMessages(npcId, nextMessages);
    notifyListeners();
  }

  Future<void> deleteNpcMessages(
    String npcId,
    Iterable<String> messageIds, {
    bool notify = true,
  }) async {
    final ids =
        messageIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return;
    }

    final messages = await _ensureNpcMessages(npcId);
    final nextMessages = messages
        .where((message) => !ids.contains(message.id))
        .toList(growable: false);
    if (nextMessages.length == messages.length) {
      return;
    }

    _npcMessagesCache[npcId] = nextMessages;
    await _store.saveNpcMessages(npcId, nextMessages);
    if (notify) {
      notifyListeners();
    }
  }

  Future<String?> regenerateNpcReply(
    String npcId, {
    String direction = '',
  }) async {
    final npc = npcProfileById(npcId);
    final character = _characterForNpcInteraction(npc);
    if (npc == null || character == null) {
      return '没有找到这个 NPC。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_activeNpcReplyingId != null) {
      return 'NPC 正在回复中，请稍等。';
    }

    final messages = await _ensureNpcMessages(npcId);

    // Find and remove the last NPC reply batch
    var lastNpcIndex = -1;
    for (var index = messages.length - 1; index >= 0; index--) {
      if (messages[index].role == NpcMessageRole.npc) {
        lastNpcIndex = index;
        break;
      }
    }
    if (lastNpcIndex == -1) {
      return '没有找到可以重新生成的 NPC 回复。';
    }

    final lastNpcBatchId = messages[lastNpcIndex].batchId;
    final trimmedMessages = messages
        .where((message) =>
            message.role != NpcMessageRole.npc ||
            message.batchId != lastNpcBatchId)
        .toList(growable: false);

    _npcMessagesCache[npcId] = trimmedMessages;
    await _store.saveNpcMessages(npcId, trimmedMessages);
    notifyListeners();

    return requestNpcReplyWithDirection(npcId, direction: direction);
  }

  Future<String?> requestNpcReplyWithDirection(
    String npcId, {
    String direction = '',
  }) async {
    final trimmedDirection = direction.trim();
    if (trimmedDirection.isEmpty) {
      return requestNpcReply(npcId);
    }
    final messages = await _ensureNpcMessages(npcId);
    if (!_hasPendingNpcUserMessages(messages)) {
      return '这条回复前面没有可用于重新生成的用户消息。';
    }
    final directive = NpcChatMessage(
      id: IdGenerator.message(),
      npcId: npcId,
      role: NpcMessageRole.user,
      content: '【隐藏重写方向】请按以下方向重新生成上一段 NPC 回复，不要把本提示当作用户发言复述：$trimmedDirection',
      timestamp: DateTime.now(),
      batchId: IdGenerator.generic('npc_regen_hint'),
    );
    _npcMessagesCache[npcId] = <NpcChatMessage>[...messages, directive];
    try {
      return await requestNpcReply(npcId);
    } finally {
      final current = _npcMessagesCache[npcId] ?? const <NpcChatMessage>[];
      final cleaned = current
          .where((message) => message.id != directive.id)
          .toList(growable: false);
      _npcMessagesCache[npcId] = cleaned;
      await _store.saveNpcMessages(npcId, cleaned);
    }
  }

  static String buildNpcExportHtml({
    required String npcName,
    required String characterName,
    required List<NpcChatMessage> messages,
  }) {
    final escapedNpcName = _htmlEscape(npcName);
    final escapedCharacterName = _htmlEscape(characterName);
    final messageHtml = messages.map((message) {
      final isUser = message.role == NpcMessageRole.user;
      final author = isUser ? '你' : escapedNpcName;
      final time = _formatNpcExportTime(message.timestamp);
      return '''
<article class="message ${isUser ? 'user' : 'npc'}">
  <div class="bubble">
    <div class="author">$author</div>
    <div class="content">${_htmlEscape(message.content)}</div>
    <div class="meta">$time</div>
  </div>
</article>
''';
    }).join('\n');

    return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>NPC 私聊记录 · $escapedNpcName</title>
  <style>
    :root {
      --bg: linear-gradient(135deg, #fff8ef 0%, #f0f4ff 52%, #eefcff 100%);
      --card: rgba(255, 255, 255, 0.9);
      --text: #263238;
      --muted: #5f6f73;
      --border: rgba(15, 23, 42, 0.08);
      --primary: #0d7c78;
      --primary-soft: #a9ece4;
      --assistant: #ffffff;
      --shadow: 0 18px 40px rgba(15, 23, 42, 0.09);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      background: var(--bg);
      color: var(--text);
    }
    .page {
      max-width: 1200px;
      margin: 0 auto;
      padding: 32px 20px 48px;
    }
    .header {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 28px;
      padding: 24px 28px;
      box-shadow: var(--shadow);
      margin-bottom: 20px;
    }
    .header h1 { margin: 0 0 10px; font-size: 34px; }
    .header p { margin: 0; color: var(--muted); font-size: 16px; }
    .messages { display: flex; flex-direction: column; gap: 16px; }
    .message { display: flex; }
    .message.user { justify-content: flex-end; }
    .message.npc { justify-content: flex-start; }
    .bubble {
      width: min(760px, 82vw);
      padding: 18px 18px 14px;
      border-radius: 24px;
      border: 1px solid var(--border);
      box-shadow: var(--shadow);
      background: var(--assistant);
    }
    .message.user .bubble {
      background: var(--primary-soft);
      border-color: rgba(13, 124, 120, 0.18);
    }
    .author { font-weight: 700; color: var(--primary); margin-bottom: 10px; }
    .message.user .author { color: #124d4b; }
    .content {
      line-height: 1.7;
      font-size: 16px;
      word-break: break-word;
      white-space: pre-wrap;
    }
    .meta { margin-top: 12px; font-size: 13px; color: var(--muted); }
    @media (max-width: 720px) {
      .page { padding: 20px 12px 40px; }
      .header { padding: 20px; }
      .header h1 { font-size: 28px; }
      .bubble { width: 100%; }
    }
  </style>
</head>
<body>
  <main class="page">
    <section class="header">
      <h1>$escapedNpcName · 私聊记录</h1>
      <p>所属角色：$escapedCharacterName · 共 ${messages.length} 条消息</p>
    </section>
    <section class="messages">
      $messageHtml
    </section>
  </main>
</body>
</html>
''';
  }

  static String _htmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _formatNpcExportTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  Future<void> clearCurrentCharacterHistory() async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }

    await _createSafetySnapshotForCharacter(
      character.id,
      reason: '清空聊天前自动保护',
    );

    final emptyHistory = DialogueHistory.empty(character.id);
    final emptyMemory = CharacterMemory.empty(character.id);
    final emptyGameState = GameStateSnapshot.empty(character.id);
    final emptyMapState = MapWorldState.empty(character.id);
    _historyCache[character.id] = emptyHistory;
    _memoryCache[character.id] = emptyMemory;
    _gameStateCache[character.id] = emptyGameState;
    _mapStateCache[character.id] = emptyMapState;
    _lastNpcExtractionMessageCounts.remove(character.id);
    final npcCleanup = _removeNpcProfilesForCharacterReset(character.id);
    await _store.saveDialogueHistory(emptyHistory);
    await _store.saveCharacterMemory(emptyMemory);
    await _store.saveGameState(emptyGameState);
    await _store.saveMapState(emptyMapState);
    if (npcCleanup.changed) {
      await _store.saveNpcProfiles(_npcProfiles);
      await _store.saveNpcMigrations(_npcMigrations);
      await _store.saveGamificationState(_gamification);
      for (final npcId in npcCleanup.removedNpcIds) {
        await _store.deleteNpcMessages(npcId);
      }
    }
    await _updateGamification(
      (state) => state.incrementStat('totalHistoryClears'),
      notify: false,
    );
    notifyListeners();
  }

  Future<String> exportAllDataArchive({
    bool includeApiSecrets = false,
  }) async {
    return _buildDataArchive(
      scope: 'all',
      characterIds: _characters.map((character) => character.id).toSet(),
      includeApiSecrets: includeApiSecrets,
    );
  }

  Future<String?> exportCharacterDataArchive({
    required String characterId,
    bool includeApiSecrets = false,
  }) async {
    final character = _findCharacter(characterId);
    if (character == null) {
      return null;
    }
    final rootId = character.rootCharacterId;
    final ids = <String>{
      rootId,
      ..._characters
          .where((item) => item.branchSourceCharacterId == rootId)
          .map((item) => item.id),
    };
    return _buildDataArchive(
      scope: 'character',
      characterIds: ids,
      includeApiSecrets: includeApiSecrets,
    );
  }

  Future<String?> importDataArchive(
    String raw, {
    required bool replaceExisting,
  }) async {
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请先停止或等待完成后再导入。';
    }
    if (_isDataMutationInProgress) {
      return '数据正在变更，请稍等。';
    }
    _isDataMutationInProgress = true;
    notifyListeners();
    try {
      Map<String, dynamic> root;
      try {
        root = await _decodeArchiveRoot(raw);
      } catch (_) {
        return '导入失败：这段内容不是有效的 JSON 存档。';
      }
      try {
        root = SaveEnvelopeCodec.unwrapArchive(root).payload;
      } on SaveEnvelopeException catch (error) {
        return '导入已阻止：${error.message}';
      } catch (_) {
        return '导入失败：存档封套解析失败。';
      }

      final rawData = root['data'];
      final data = rawData is Map<String, dynamic>
          ? rawData
          : rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : root;

      List<T> readList<T>(
        String key,
        T Function(Map<String, dynamic>) parse,
      ) {
        final rawItems = data[key];
        if (rawItems is! List) {
          return <T>[];
        }
        return rawItems
            .whereType<Map>()
            .map((item) => parse(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }

      Map<String, Map<String, dynamic>> readMap(String key) {
        final rawMap = data[key];
        if (rawMap is! Map) {
          return const <String, Map<String, dynamic>>{};
        }
        final result = <String, Map<String, dynamic>>{};
        for (final entry in rawMap.entries) {
          final value = entry.value;
          if (value is Map) {
            result[entry.key.toString()] = Map<String, dynamic>.from(value);
          }
        }
        return result;
      }

      final importedCharacters =
          readList('characters', CharacterProfile.fromJson);
      final importedUserProfiles =
          readList('userProfiles', UserProfile.fromJson);
      final importedToolResults = readList('toolResults', ToolResult.fromJson);
      final importedFanficResults =
          readList('fanficResults', FanficResult.fromJson);
      final importedNpcProfiles = readList('npcProfiles', NpcProfile.fromJson);
      final importedNpcMigrations =
          readList('npcMigrations', NpcMigrationRecord.fromJson);
      final importedWorldBooks =
          readList('worldBooks', WorldBookEntry.fromJson);
      final importedWorldCalendarEvents =
          readList('worldCalendarEvents', WorldCalendarEvent.fromJson);
      final importedPresets =
          readList('settingsPresets', SettingsPreset.fromJson);

      final rawSettings = data['settings'];
      final importedSettings = rawSettings is Map
          ? AppSettings.fromJson(Map<String, dynamic>.from(rawSettings))
          : null;
      final rawGamification = data['gamification'];
      final importedGamification = rawGamification is Map
          ? GamificationState.fromJson(
              Map<String, dynamic>.from(rawGamification))
          : null;

      final importedHistories = <String, DialogueHistory>{};
      for (final entry in readMap('histories').entries) {
        final history = DialogueHistory.fromJson(entry.value);
        final safeHistory = history.characterId.trim().isEmpty
            ? history.copyWith(characterId: entry.key)
            : history;
        importedHistories[safeHistory.characterId] = safeHistory;
      }
      final importedMemories = <String, CharacterMemory>{};
      for (final entry in readMap('memories').entries) {
        final memory = CharacterMemory.fromJson(entry.value);
        final safeMemory = memory.characterId.trim().isEmpty
            ? memory.copyWith(characterId: entry.key)
            : memory;
        importedMemories[safeMemory.characterId] = safeMemory;
      }
      final importedGameStates = <String, GameStateSnapshot>{};
      for (final entry in readMap('gameStates').entries) {
        final state = GameStateSnapshot.fromJson(entry.value);
        final safeState = state.characterId.trim().isEmpty
            ? state.copyWith(characterId: entry.key)
            : state;
        importedGameStates[safeState.characterId] = safeState;
      }
      final importedMapStates = <String, MapWorldState>{};
      for (final entry in readMap('mapStates').entries) {
        final state = MapWorldState.fromJson(entry.value);
        final safeState = state.characterId.trim().isEmpty
            ? state.copyWith(characterId: entry.key)
            : state;
        importedMapStates[safeState.characterId] = safeState;
      }
      final importedNpcMessages = <String, List<NpcChatMessage>>{};
      final rawNpcMessages = data['npcMessages'];
      if (rawNpcMessages is Map) {
        for (final entry in rawNpcMessages.entries) {
          final rawMessages = entry.value;
          if (rawMessages is! List) {
            continue;
          }
          importedNpcMessages[entry.key.toString()] = rawMessages
              .whereType<Map>()
              .map(
                (item) =>
                    NpcChatMessage.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false);
        }
      }

      final previousCharacterIds =
          _characters.map((item) => item.id).toList(growable: false);
      final previousNpcIds =
          _npcProfiles.map((item) => item.id).toList(growable: false);
      final previousCharacters = List<CharacterProfile>.of(_characters);
      final previousUserProfiles = List<UserProfile>.of(_userProfiles);
      final previousToolResults = List<ToolResult>.of(_toolResults);
      final previousFanficResults = List<FanficResult>.of(_fanficResults);
      final previousNpcProfiles = List<NpcProfile>.of(_npcProfiles);
      final previousNpcMigrations = List<NpcMigrationRecord>.of(_npcMigrations);
      final previousWorldBooks = List<WorldBookEntry>.of(_worldBooks);
      final previousCalendarEvents =
          List<WorldCalendarEvent>.of(_worldCalendarEvents);
      final previousSettingsPresets = List<SettingsPreset>.of(_settingsPresets);
      final previousHistories = Map<String, DialogueHistory>.of(_historyCache);
      final previousMemories = Map<String, CharacterMemory>.of(_memoryCache);
      final previousGameStates =
          Map<String, GameStateSnapshot>.of(_gameStateCache);
      final previousMapStates = Map<String, MapWorldState>.of(_mapStateCache);
      final previousNpcMessages =
          Map<String, List<NpcChatMessage>>.of(_npcMessagesCache);
      final previousSettings = _settings;
      final previousGamification = _gamification;
      final previousSelectedCharacterId = _selectedCharacterId;

      if (replaceExisting) {
        await _createSafetySnapshotForCharacter(
          _selectedCharacterId,
          reason: '导入覆盖前自动保护',
        );
        _characters
          ..clear()
          ..addAll(importedCharacters);
        _userProfiles
          ..clear()
          ..addAll(importedUserProfiles);
        _toolResults
          ..clear()
          ..addAll(importedToolResults);
        _fanficResults
          ..clear()
          ..addAll(importedFanficResults);
        _npcProfiles
          ..clear()
          ..addAll(importedNpcProfiles);
        _npcMigrations
          ..clear()
          ..addAll(importedNpcMigrations);
        _worldBooks
          ..clear()
          ..addAll(importedWorldBooks.isEmpty
              ? <WorldBookEntry>[WorldBookEntry.defaultEntry()]
              : importedWorldBooks);
        _worldCalendarEvents
          ..clear()
          ..addAll(importedWorldCalendarEvents);
        _settingsPresets
          ..clear()
          ..addAll(importedPresets);
        _historyCache.clear();
        _memoryCache.clear();
        _gameStateCache.clear();
        _mapStateCache.clear();
        _npcMessagesCache.clear();
        if (importedGamification != null) {
          _gamification = _applyAchievementUnlocks(
            _ensureVersionGiftMail(importedGamification),
          );
          _registerCustomThemes();
        }
      } else {
        _upsertById(_characters, importedCharacters, (item) => item.id);
        _upsertById(_userProfiles, importedUserProfiles, (item) => item.id);
        _upsertById(_toolResults, importedToolResults, (item) => item.id);
        _upsertById(_fanficResults, importedFanficResults, (item) => item.id);
        _upsertById(_npcProfiles, importedNpcProfiles, (item) => item.id);
        _upsertById(_npcMigrations, importedNpcMigrations, (item) => item.id);
        _upsertById(_worldBooks, importedWorldBooks, (item) => item.id);
        _upsertById(
          _worldCalendarEvents,
          importedWorldCalendarEvents,
          (item) => item.id,
        );
        _upsertById(_settingsPresets, importedPresets, (item) => item.id);
        if (importedGamification != null) {
          _gamification = _applyAchievementUnlocks(
            _ensureVersionGiftMail(importedGamification),
          );
          _registerCustomThemes();
        }
      }

      _historyCache.addAll(importedHistories);
      _memoryCache.addAll(importedMemories);
      _gameStateCache.addAll(importedGameStates);
      _mapStateCache.addAll(importedMapStates);
      _npcMessagesCache.addAll(importedNpcMessages);

      if (_characters.isEmpty) {
        _characters.add(buildTutorialDemoCharacter());
      }
      _characters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _npcProfiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _npcMigrations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _registerCustomThemes();

      if (importedSettings != null) {
        _settings = importedSettings.copyWith(
          apiKey:
              importedSettings.apiKey.trim().isEmpty ? _settings.apiKey : null,
          memoryApiKey: importedSettings.memoryApiKey.trim().isEmpty
              ? _settings.memoryApiKey
              : null,
          // Importing settings is not consent to send an existing key over HTTP.
          allowInsecureMainApi: false,
          allowInsecureMemoryApi: false,
        );
        if (!canUseTheme(_settings.themeId)) {
          _settings = _settings.copyWith(themeId: AppThemeVariant.sakura.id);
        }
      }

      _gamification = _applyAchievementUnlocks(
        _gamification.ensureToday().incrementStat('totalDataImports'),
      );
      _registerCustomThemes();

      final requestedSelectedId = data['selectedCharacterId']?.toString();
      final nextSelected = _findCharacter(requestedSelectedId) ??
          _characters.firstWhere(
            (character) => !character.isStoryBranch,
            orElse: () => _characters.first,
          );
      _selectedCharacterId = nextSelected.id;
      try {
        await _store.commitArchiveState(
          settings: _settings,
          settingsPresets: _settingsPresets,
          characters: _characters,
          userProfiles: _userProfiles,
          toolResults: _toolResults,
          fanficResults: _fanficResults,
          npcProfiles: _npcProfiles,
          npcMigrations: _npcMigrations,
          worldBooks: _worldBooks,
          worldCalendarEvents: _worldCalendarEvents,
          gamification: _gamification,
          histories: _historyCache,
          memories: _memoryCache,
          gameStates: _gameStateCache,
          mapStates: _mapStateCache,
          npcMessages: _npcMessagesCache,
          selectedCharacterId: _selectedCharacterId,
          deleteCharacterIds:
              replaceExisting ? previousCharacterIds : const <String>[],
          deleteNpcIds: replaceExisting ? previousNpcIds : const <String>[],
        );
      } catch (error) {
        _characters
          ..clear()
          ..addAll(previousCharacters);
        _userProfiles
          ..clear()
          ..addAll(previousUserProfiles);
        _toolResults
          ..clear()
          ..addAll(previousToolResults);
        _fanficResults
          ..clear()
          ..addAll(previousFanficResults);
        _npcProfiles
          ..clear()
          ..addAll(previousNpcProfiles);
        _npcMigrations
          ..clear()
          ..addAll(previousNpcMigrations);
        _worldBooks
          ..clear()
          ..addAll(previousWorldBooks);
        _worldCalendarEvents
          ..clear()
          ..addAll(previousCalendarEvents);
        _settingsPresets
          ..clear()
          ..addAll(previousSettingsPresets);
        _historyCache
          ..clear()
          ..addAll(previousHistories);
        _memoryCache
          ..clear()
          ..addAll(previousMemories);
        _gameStateCache
          ..clear()
          ..addAll(previousGameStates);
        _mapStateCache
          ..clear()
          ..addAll(previousMapStates);
        _npcMessagesCache
          ..clear()
          ..addAll(previousNpcMessages);
        _settings = previousSettings;
        _gamification = previousGamification;
        _selectedCharacterId = previousSelectedCharacterId;
        _registerCustomThemes();
        return '导入写入失败：$error。当前界面已回到导入前状态；若提交日志已写入，下次启动会继续恢复。';
      }
      await _loadCharacterState(_selectedCharacterId!);
      notifyListeners();
      return null;
    } on FormatException catch (error) {
      return '导入失败：存档字段格式不完整（${error.message}）。';
    } catch (error) {
      return '导入失败：无法解析存档内容（$error）。';
    } finally {
      _isDataMutationInProgress = false;
      notifyListeners();
    }
  }

  Future<DataArchivePreview> previewDataArchive(String raw) async {
    Map<String, dynamic> root;
    try {
      root = await _decodeArchiveRoot(raw);
    } catch (_) {
      throw const FormatException('这段内容不是有效的 JSON 存档。');
    }
    final envelope = SaveEnvelopeCodec.unwrapArchive(
      root,
      allowInvalidChecksum: true,
      allowFutureSchema: true,
    );
    root = envelope.payload;

    final rawData = root['data'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : root;

    int listCount(String key) {
      final value = data[key];
      return value is List ? value.length : 0;
    }

    int mapMessageCount(String key) {
      final value = data[key];
      if (value is! Map) {
        return 0;
      }
      var count = 0;
      for (final entry in value.values) {
        if (entry is Map) {
          final messages = entry['messages'];
          if (messages is List) {
            count += messages.length;
          }
        } else if (entry is List) {
          count += entry.length;
        }
      }
      return count;
    }

    final schemaValue = envelope.schemaVersion > 0
        ? envelope.schemaVersion
        : root['schemaVersion'] ?? data['schemaVersion'];
    final schemaVersion = schemaValue is num
        ? schemaValue.round()
        : int.tryParse(schemaValue?.toString() ?? '') ?? 0;
    final exportedAt = DateTime.tryParse(root['exportedAt']?.toString() ?? '');

    return DataArchivePreview(
      schemaVersion: schemaVersion,
      appVersion: envelope.appVersion.isNotEmpty
          ? envelope.appVersion
          : root['appVersion']?.toString() ?? '',
      exportedAt: exportedAt,
      scope: root['scope']?.toString() ?? data['scope']?.toString() ?? '',
      includeApiSecrets: root['includeApiSecrets'] == true,
      characterCount: listCount('characters'),
      historyMessageCount: mapMessageCount('histories'),
      npcCount: listCount('npcProfiles'),
      npcMessageCount: mapMessageCount('npcMessages'),
      npcMigrationCount: listCount('npcMigrations'),
      worldBookCount: listCount('worldBooks'),
      toolResultCount: listCount('toolResults'),
      fanficResultCount: listCount('fanficResults'),
      userProfileCount: listCount('userProfiles'),
      hasSettings: data['settings'] is Map,
      hasGamification: data['gamification'] is Map,
      hasIntegrityChecksum: envelope.isEnvelope,
      checksumValid: envelope.checksumValid,
      schemaSupported: envelope.schemaVersion <= currentSaveSchemaVersion,
    );
  }

  Future<String?> createCurrentCharacterSnapshot(String title) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    final root = _findCharacter(character.rootCharacterId) ?? character;
    final archiveJson = await exportCharacterDataArchive(
      characterId: character.id,
      includeApiSecrets: false,
    );
    if (archiveJson == null) {
      return '当前没有可保存的角色数据。';
    }
    final safeTitle = title.trim().isEmpty
        ? '${root.name} · ${DateTime.now().toLocal().toString().split('.').first}'
        : title.trim();
    _saveSnapshots.insert(
      0,
      SaveSnapshot(
        characterId: root.id,
        characterName: root.name,
        title: safeTitle,
        archiveJson: archiveJson,
      ),
    );
    await _store.saveSaveSnapshots(_saveSnapshots);
    await _updateGamification(
      (state) => state.incrementStat('totalSaveSnapshotsCreated'),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<void> _createSafetySnapshotForCharacter(
    String? characterId, {
    required String reason,
  }) async {
    final cleanId = characterId?.trim();
    if (cleanId == null || cleanId.isEmpty) {
      return;
    }
    final character = _findCharacter(cleanId);
    if (character == null) {
      return;
    }
    final root = _findCharacter(character.rootCharacterId) ?? character;
    final now = DateTime.now().toLocal().toString().split('.').first;
    final archiveJson = await exportCharacterDataArchive(
      characterId: root.id,
      includeApiSecrets: false,
    );
    if (archiveJson == null || archiveJson.trim().isEmpty) {
      return;
    }
    _saveSnapshots.insert(
      0,
      SaveSnapshot(
        characterId: root.id,
        characterName: root.name,
        title: '自动保护 · $reason · $now',
        archiveJson: archiveJson,
      ),
    );
    const maxAutoSnapshots = 12;
    var autoSeen = 0;
    final kept = <SaveSnapshot>[];
    for (final snapshot in _saveSnapshots) {
      if (snapshot.title.startsWith('自动保护 · ')) {
        autoSeen += 1;
        if (autoSeen > maxAutoSnapshots) {
          continue;
        }
      }
      kept.add(snapshot);
    }
    _saveSnapshots
      ..clear()
      ..addAll(kept);
    await _store.saveSaveSnapshots(_saveSnapshots);
    await _updateGamification(
      (state) => state.incrementStat('totalAutoSafetySnapshots'),
      notify: false,
    );
  }

  Future<String?> restoreSaveSnapshot(String snapshotId) async {
    final id = snapshotId.trim();
    SaveSnapshot? snapshot;
    for (final item in _saveSnapshots) {
      if (item.id == id) {
        snapshot = item;
        break;
      }
    }
    if (snapshot == null) {
      return '没有找到这个存档快照。';
    }
    final error = await importDataArchive(
      snapshot.archiveJson,
      replaceExisting: false,
    );
    if (error != null) {
      return error;
    }
    if (_findCharacter(snapshot.characterId) != null) {
      await selectCharacter(snapshot.characterId);
    }
    await _updateGamification(
      (state) => state.incrementStat('totalSaveSnapshotsRestored'),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<void> deleteSaveSnapshot(String snapshotId) async {
    _saveSnapshots.removeWhere((snapshot) => snapshot.id == snapshotId);
    await _store.saveSaveSnapshots(_saveSnapshots);
    notifyListeners();
  }

  Future<DataStorageReport> buildDataStorageReport() async {
    final sizes = await _store.estimateStorageBytes(
      characterIds: _characters.map((character) => character.id),
      npcIds: _npcProfiles.map((npc) => npc.id),
    );
    int bytesForExact(String key) => sizes[key] ?? 0;
    int bytesForPrefix(String prefix) => sizes.entries
        .where((entry) => entry.key.startsWith(prefix))
        .fold<int>(0, (sum, entry) => sum + entry.value);

    final items = <DataStorageReportItem>[
      DataStorageReportItem(
        label: '角色与主聊天',
        bytes: bytesForExact('characters') +
            bytesForPrefix('history_') +
            bytesForPrefix('memory_'),
        description: '角色卡、聊天记录和长期记忆。',
      ),
      DataStorageReportItem(
        label: '游戏状态与地图',
        bytes: bytesForPrefix('game_state_') +
            bytesForPrefix('map_state_') +
            bytesForExact('world_calendar_events'),
        description: '游戏面板、地图主线、日程和剧情状态。',
      ),
      DataStorageReportItem(
        label: 'NPC 私聊',
        bytes: bytesForExact('npc_profiles') + bytesForPrefix('npc_messages_'),
        description: 'NPC 档案、私聊和来信内容。',
      ),
      DataStorageReportItem(
        label: '世界书与用户人设',
        bytes: bytesForExact('world_books') + bytesForExact('user_profiles'),
        description: '世界书、标签、绑定关系和用户人设。',
      ),
      DataStorageReportItem(
        label: '剧情工具与同人文',
        bytes: bytesForExact('tool_results') + bytesForExact('fanfic_results'),
        description: '剧情工具历史与历史同人文。',
      ),
      DataStorageReportItem(
        label: '成就、背包与快照',
        bytes: bytesForExact('gamification_state') +
            bytesForExact('save_snapshots'),
        description: '啥币、成就、功能券背包和本地存档快照。',
      ),
      DataStorageReportItem(
        label: '隔离原文',
        bytes: bytesForExact('quarantined_data_records'),
        description: '无法解析但仍保留在数据保险箱中的原始内容。',
      ),
    ];

    return DataStorageReport(
      totalBytes: sizes.values.fold<int>(0, (sum, bytes) => sum + bytes),
      items: items,
    );
  }

  Future<void> noteDataCleanerRun() async {
    await _updateGamification(
      (state) => state.incrementStat('totalDataCleanerRuns'),
      notify: false,
    );
  }

  Future<void> deleteQuarantinedDataRecord(String recordId) async {
    await _store.deleteQuarantinedDataRecord(recordId);
    _quarantinedDataRecords
      ..clear()
      ..addAll(await _store.loadQuarantinedDataRecords());
    notifyListeners();
  }

  Future<String?> repairDataHealthIssues() async {
    final before = dataHealthReport;
    var changed = false;
    final characterIds = _characters.map((item) => item.id).toSet();
    final fallbackCharacterId = _selectedCharacterId ??
        (_characters.isEmpty ? '' : _characters.first.id);

    for (var index = 0; index < _npcProfiles.length; index += 1) {
      final npc = _npcProfiles[index];
      final validBindings = npc.boundCharacterIds
          .where(characterIds.contains)
          .toList(growable: false);
      final ownerMissing = npc.characterId.trim().isNotEmpty &&
          !characterIds.contains(npc.characterId);
      if (ownerMissing ||
          validBindings.length != npc.boundCharacterIds.length) {
        changed = true;
        _npcProfiles[index] = npc.copyWith(
          characterId: ownerMissing ? fallbackCharacterId : npc.characterId,
          boundCharacterIds: validBindings,
        );
      }
    }

    final repairedWorldBooks = _worldBooks.map((entry) {
      if (entry.global) {
        return entry;
      }
      final validIds = entry.boundCharacterIds
          .where(characterIds.contains)
          .toList(growable: false);
      if (validIds.length != entry.boundCharacterIds.length) {
        changed = true;
        return entry.copyWith(boundCharacterIds: validIds);
      }
      return entry;
    }).toList(growable: false);
    _worldBooks
      ..clear()
      ..addAll(_normalizeWorldBooks(repairedWorldBooks, _characters));

    // Migration records are durable snapshots. Missing live references leave
    // an archive detached instead of deleting the user's history.

    final beforeSnapshotCount = _saveSnapshots.length;
    _saveSnapshots.removeWhere(
      (snapshot) => snapshot.archiveJson.trim().isEmpty,
    );
    changed = changed || beforeSnapshotCount != _saveSnapshots.length;

    final repairedMapStates = <String, MapWorldState>{};
    for (final entry in _mapStateCache.entries) {
      final state = entry.value;
      if (!characterIds.contains(entry.key)) {
        changed = true;
        continue;
      }
      final ids = state.locations.map((location) => location.id).toSet();
      if (state.currentLocationId.trim().isNotEmpty &&
          ids.isNotEmpty &&
          !ids.contains(state.currentLocationId)) {
        changed = true;
        final fallback = state.locations.first;
        repairedMapStates[entry.key] = state.copyWith(
          currentLocationId: fallback.id,
          currentLocationName: fallback.name,
        );
      } else {
        repairedMapStates[entry.key] = state;
      }
    }
    _mapStateCache
      ..clear()
      ..addAll(repairedMapStates);

    if (!changed) {
      return before.isClean ? '数据健康，没有需要修复的问题。' : '没有可自动修复的问题。';
    }

    await _store.saveWorldBooks(_worldBooks);
    await _store.saveNpcProfiles(_npcProfiles);
    await _store.saveNpcMigrations(_npcMigrations);
    await _store.saveSaveSnapshots(_saveSnapshots);
    for (final state in _mapStateCache.values) {
      await _store.saveMapState(state);
    }
    await noteDataCleanerRun();
    notifyListeners();
    final after = dataHealthReport;
    final fixed = (before.repairableCount - after.repairableCount)
        .clamp(0, before.repairableCount);
    return '已自动修复 $fixed 项可修复问题。';
  }

  Future<void> clearCurrentCharacterToolResults() async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }
    final rootId = character.rootCharacterId;
    final ids = <String>{
      rootId,
      ..._characters
          .where((item) => item.branchSourceCharacterId == rootId)
          .map((item) => item.id),
    };
    _toolResults.removeWhere((result) => ids.contains(result.characterId));
    _lastToolResultId = null;
    _ephemeralToolResult = null;
    await _store.saveToolResults(_toolResults);
    notifyListeners();
  }

  Future<void> deleteToolResult(String resultId) async {
    final id = resultId.trim();
    if (id.isEmpty) {
      return;
    }
    _toolResults.removeWhere((result) => result.id == id);
    if (_lastToolResultId == id) {
      _lastToolResultId = null;
    }
    if (_ephemeralToolResult?.id == id) {
      _ephemeralToolResult = null;
    }
    await _store.saveToolResults(_toolResults);
    notifyListeners();
  }

  Future<void> clearCurrentCharacterFanficResults() async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }
    final rootId = character.rootCharacterId;
    final ids = <String>{
      rootId,
      ..._characters
          .where((item) => item.branchSourceCharacterId == rootId)
          .map((item) => item.id),
    };
    _fanficResults.removeWhere((result) => ids.contains(result.characterId));
    _lastFanficResultId = null;
    await _store.saveFanficResults(_fanficResults);
    notifyListeners();
  }

  Future<void> deleteFanficResult(String resultId) async {
    final id = resultId.trim();
    if (id.isEmpty) {
      return;
    }
    _fanficResults.removeWhere((result) => result.id == id);
    if (_lastFanficResultId == id) {
      _lastFanficResultId = null;
    }
    await _store.saveFanficResults(_fanficResults);
    notifyListeners();
  }

  Future<void> clearCurrentCharacterNpcMessages() async {
    for (final profile in currentWorldNpcProfiles) {
      _npcMessagesCache[profile.id] = const <NpcChatMessage>[];
      await _store.saveNpcMessages(profile.id, const <NpcChatMessage>[]);
    }
    notifyListeners();
  }

  Future<void> clearCurrentMapHtmlCache() async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }
    final state = await _ensureMapState(character.id);
    final nextState = state.copyWith(
      updatedAt: DateTime.now(),
      mapHtml: '',
      locations:
          state.locations.map((item) => item.copyWith(html: '')).toList(),
    );
    _mapStateCache[character.id] = nextState;
    await _store.saveMapState(nextState);
    notifyListeners();
  }

  Future<Map<String, dynamic>> _decodeArchiveRoot(String raw) async {
    final decoded = raw.length > 768 * 1024
        ? await compute(_decodeArchiveRootInBackground, raw)
        : _decodeArchiveRootSync(raw);
    return decoded;
  }

  Future<SimulatorPromptGenerationResult> generateSimulatorPrompt(
    SimulatorPromptGenerationRequest request, {
    void Function(String partial)? onChunk,
  }) async {
    if (!_settings.canChat) {
      throw const LlmApiException('请先在设置页填写 API 地址、密钥和模型名称。');
    }

    final result = await _apiClient.generateSimulatorPrompt(
      settings: _settings,
      request: request,
      onChunk: onChunk,
    );
    await _updateGamification(
      (state) {
        var next = state.incrementStat('totalSimulatorPrompts');
        if (request.mode == SimulatorPromptGenerationMode.worldStage) {
          next = next.incrementStat('totalWorldStagePrompts');
        }
        if (request.simulatorIdea.contains('怀旧版开盲盒模式')) {
          next = next.incrementStat('totalClassicBlindBoxes');
        } else if (request.simulatorIdea.contains('开盲盒模式')) {
          next = next.incrementStat('totalBlindBoxes');
        }
        return next;
      },
      notify: false,
    );
    return result;
  }

  Future<GameplaySystem> previewGameplaySystem(String characterId) async {
    if (!_settings.canChat) {
      throw const LlmApiException('请先在设置页填写 API 地址、密钥和模型名称。');
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      throw const LlmApiException('当前还有内容正在生成，请稍等。');
    }
    final character = _findCharacter(characterId);
    if (character == null) {
      throw const LlmApiException('没有找到要生成玩法系统的剧场。');
    }
    _isGameplaySystemGenerating = true;
    notifyListeners();
    try {
      return await _apiClient.generateGameplaySystem(
        settings: _settings,
        character: character,
      );
    } finally {
      _isGameplaySystemGenerating = false;
      notifyListeners();
    }
  }

  Future<void> applyGameplaySystem(
    String characterId,
    GameplaySystem system,
  ) async {
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      throw const LlmApiException('当前还有内容正在生成，请稍等。');
    }
    GameplaySystemParser.validateSystem(system);
    final character = _findCharacter(characterId);
    if (character == null) {
      throw const LlmApiException('剧场已经不存在，无法保存玩法系统。');
    }
    _isGameplaySystemGenerating = true;
    notifyListeners();
    try {
      final state = await _ensureGameState(characterId);
      final history = await _ensureHistory(characterId);
      final previousSystem = character.gameplaySystem;
      if (previousSystem != null) {
        await _createSafetySnapshotForCharacter(
          characterId,
          reason: '调整玩法规则前自动保护',
        );
      }
      final values = previousSystem == null
          ? GameplayPatchEngine.initializeValues(system, state.customVariables)
          : GameplaySystemDraft.preview(
                  current: previousSystem, generated: system)
              .migrateValues(state.customVariables);
      final nextState = state.copyWith(
        updatedAt: DateTime.now(),
        metrics: GameplayPatchEngine.removeClaimedLegacyMetrics(
            system, state.metrics),
        customVariables: values,
        customVariablesRevision: state.customVariablesRevision + 1,
        gameplayRuntime: previousSystem == null
            ? state.gameplayRuntime
            : GameplaySystemDraft.preview(
                    current: previousSystem, generated: system)
                .migrateRuntime(state.gameplayRuntime),
        gameplayVariableChanges: const <String>[],
        gameplayPlayerVariableChanges: const <String>[],
        gameplayVariableWarnings: const <String>[],
      );
      final nextCharacters = _characters
          .map((item) => item.id == characterId
              ? item.copyWith(gameplaySystem: system)
              : item)
          .toList(growable: false);
      final nextHistory = history.copyWith(
        clearPromptCacheEpoch: true,
        messages: history.messages.map((message) {
          if (previousSystem == null ||
              message.role != ChatRole.assistant ||
              message.gameStateSnapshot == null ||
              message.gameStateSnapshot!.containsKey('gameplaySystem')) {
            return message;
          }
          return message.copyWith(gameStateSnapshot: <String, dynamic>{
            ...message.gameStateSnapshot!,
            'gameplaySystem': previousSystem.toJson(),
          });
        }).toList(growable: false),
      );
      await _store.commitGameplaySystem(
        characters: nextCharacters,
        gameState: nextState,
        history: nextHistory,
      );
      _characters
        ..clear()
        ..addAll(nextCharacters);
      _gameStateCache[characterId] = nextState;
      _historyCache[characterId] = nextHistory;
    } finally {
      _isGameplaySystemGenerating = false;
      notifyListeners();
    }
  }

  Future<GameplaySystem> generateGameplaySystem(String characterId) async {
    final system = await previewGameplaySystem(characterId);
    await applyGameplaySystem(characterId, system);
    return system;
  }

  Future<String?> queueUserMessage(String content) async {
    final character = currentCharacter;
    final trimmed = content.trim();

    if (character == null) {
      return '请先创建或选择一个角色。';
    }

    if (trimmed.isEmpty) {
      return '消息内容不能为空。';
    }

    if (_isSending || _isGameplaySystemGenerating) {
      return '上一条消息仍在发送中，请稍等。';
    }

    final currentHistory = await _ensureHistory(character.id);
    final tokenCount = _countCompletedTextTokens(trimmed);
    final userMessage = ChatMessage(
      id: IdGenerator.message(),
      role: ChatRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
      isSummarized: false,
      tokenEstimate: tokenCount,
    );

    final updatedHistory = currentHistory.copyWith(
      messages: <ChatMessage>[...currentHistory.messages, userMessage],
    );
    _historyCache[character.id] = updatedHistory;
    await _store.saveDialogueHistory(updatedHistory);
    await _updateGamification(
      (state) {
        var next = state
            .incrementStat('totalUserMessages')
            .incrementDailyStat('userMessages');
        final hour = DateTime.now().toLocal().hour;
        if (hour >= 0 && hour < 5) {
          next = next.incrementStat('totalLateNightMessages');
        }
        final choiceMarks = RegExp(r'(^|\s|[，。；;])([A-F])\s*[|｜、:：]')
            .allMatches(trimmed)
            .length;
        if (choiceMarks >= 3) {
          next = next.incrementStat('totalMultiChoiceInputs');
        }
        if (RegExp(r'(^|\s|[，。；;])F\s*[|｜、:：]').hasMatch(trimmed) ||
            trimmed.contains('F选项') ||
            trimmed.contains('选择F')) {
          next = next.incrementStat('totalFChoiceInputs');
        }
        return next;
      },
      notify: false,
    );

    notifyListeners();
    return null;
  }

  Future<String?> requestAssistantReply() async {
    final character = currentCharacter;
    if (character == null) {
      return '请先创建或选择一个角色。';
    }

    if (!_settings.canChat) {
      return '请先在设置页填写 API 地址、密钥和模型名称。';
    }

    if (_isDataMutationInProgress) {
      return '数据正在导入或删除，请稍等。';
    }

    if (_isGameplaySystemGenerating) {
      return '玩法系统正在生成，请稍等。';
    }

    if (_isSending) {
      cancelCurrentReply();
      return null;
    }

    final currentHistory = await _ensureHistory(character.id);
    if (!_hasPendingUserMessages(currentHistory.messages)) {
      return '还没有待提交给 AI 的消息。';
    }

    final placeholder = ChatMessage(
      id: IdGenerator.message(),
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isSummarized: false,
    );

    final optimisticHistory = currentHistory.copyWith(
      messages: <ChatMessage>[...currentHistory.messages, placeholder],
    );

    return _streamAssistantReply(
      character: character,
      originalHistory: currentHistory,
      optimisticHistory: optimisticHistory,
      placeholderMessageId: placeholder.id,
      requestMessages: currentHistory.messages,
      invalidatedMessageIds: const <String>{},
    );
  }

  Future<String?> generateInitialMap() async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    if (!character.mapModeEnabled) {
      return '这个角色还没有开启地图主线模式。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍等一下。';
    }
    final state = await _ensureMapState(character.id);
    if (!state.openingResolved &&
        state.openingChoices.isNotEmpty &&
        state.openingSummary.trim().isEmpty) {
      return '请先完成开局设定选择。';
    }

    if (state.isRulesDriven) {
      return '固定地图已经生成，不能在游玩中重建。';
    }

    _isSending = true;
    _isMapGenerating = true;
    notifyListeners();
    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _mapBlueprintSystemPrompt,
        userPrompt: _buildMapBlueprintPrompt(character, state),
        temperature: 0.62,
        topP: 0.9,
      );
      var payload = _decodeJsonObject(raw);
      if (payload['blueprint'] is Map) {
        payload = Map<String, dynamic>.from(payload['blueprint'] as Map);
      } else if (payload.isEmpty) {
        payload = _extractMapStatePayload(raw);
      }
      MapWorldState blueprint;
      if (payload.isEmpty) {
        blueprint = _mapTurnEngine.fallbackBlueprint(
          characterId: character.id,
          characterName: character.name,
          openingSummary: state.openingSummary,
        );
      } else {
        final json = <String, dynamic>{
          ...payload,
          'characterId': character.id,
          'updatedAt': DateTime.now().toIso8601String(),
          'openingResolved': true,
          'openingSummary': state.openingSummary,
        };
        blueprint = _mapTurnEngine.prepareBlueprint(
          MapWorldState.fromJson(json),
          characterName: character.name,
        );
      }
      _mapStateCache[character.id] = blueprint;
      await _store.saveMapState(blueprint);
      await _appendMapMessage(
        characterId: character.id,
        role: ChatRole.assistant,
        content:
            '【固定地图已生成】${blueprint.title}\n地图包含 ${blueprint.locations.length} 个地点和 ${blueprint.edges.length} 条双向道路。选择出生地点后，每回合会先由本地规则结算，再由 AI 续写正式剧情。',
      );
      await _syncGameStateFromRulesMap(character.id, blueprint);
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (_) {
      final fallback = _mapTurnEngine.fallbackBlueprint(
        characterId: character.id,
        characterName: character.name,
        openingSummary: state.openingSummary,
      );
      _mapStateCache[character.id] = fallback;
      await _store.saveMapState(fallback);
      await _appendMapMessage(
        characterId: character.id,
        role: ChatRole.assistant,
        content: '【固定地图已生成】AI 蓝图格式不可用，已启用本地保底地图。',
      );
      await _syncGameStateFromRulesMap(character.id, fallback);
      return null;
    } finally {
      _isSending = false;
      _isMapGenerating = false;
      notifyListeners();
    }
  }

  Future<String?> regenerateMainMap() async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    if (!character.mapModeEnabled) {
      return '这个角色还没有开启地图主线模式。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍等一下。';
    }

    final state = await _ensureMapState(character.id);
    if (state.isRulesDriven) {
      return '新版地图在首次生成后永久固定；可以创建剧情分支体验另一张地图。';
    }
    return _runMapTask(
      character: character,
      actionTitle: '重新生成主线地图',
      userFacingAction: '重新生成主线地图',
      replaceMapHtml: true,
      allowLocationReset: true,
      userPrompt: _buildMapTaskPrompt(
        character: character,
        task: '重新生成大地图',
        instruction:
            '用户确认重建地图。请基于已有聊天记录、GAME_STATE、角色设定和世界书重新生成 6-7 个大地点，并重建线索分布。不要删除聊天事实；如需调整地点结构，请把变化写成主线重新梳理后的地图，不要把旧事实抹掉。',
      ),
    );
  }

  Future<String?> generateMapOpeningChoices() async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    if (!character.mapModeEnabled) {
      return '这个角色还没有开启地图主线模式。';
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍等一下。';
    }
    final choices = _localMapOpeningChoices(character);
    final state = await _ensureMapState(character.id);
    final nextState = state.copyWith(
      openingChoices: choices,
      openingResolved: false,
      openingSummary: '',
      updatedAt: DateTime.now(),
    );
    _mapStateCache[character.id] = nextState;
    await _store.saveMapState(nextState);
    notifyListeners();
    return null;
  }

  Future<String?> applyMapOpeningChoices(Set<String> choiceIds) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    final state = await _ensureMapState(character.id);
    final ids =
        choiceIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return '至少选择一个开局设定。';
    }
    final selected = state.openingChoices
        .where((choice) => ids.contains(choice.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      return '没有找到选中的开局设定。';
    }
    final summary = selected.map((choice) {
      final prompt =
          choice.prompt.trim().isEmpty ? choice.description : choice.prompt;
      return '【${choice.category}】${choice.label}：$prompt';
    }).join('\n');
    final nextState = state.copyWith(
      openingResolved: true,
      openingSummary: summary,
      updatedAt: DateTime.now(),
    );
    _mapStateCache[character.id] = nextState;
    await _store.saveMapState(nextState);
    await _appendMapMessage(
      characterId: character.id,
      role: ChatRole.user,
      content: '地图主线开局设定：\n$summary',
    );
    notifyListeners();
    return null;
  }

  MapRouteResult mapRouteTo(
    String locationId, {
    MapRouteMode mode = MapRouteMode.leastActionPoints,
  }) {
    return _mapTurnEngine.findRoute(
      currentMapState,
      locationId,
      mode: mode,
    );
  }

  int? mapTravelCost(String locationId) {
    final route = mapRouteTo(locationId);
    return route.isReachable ? route.totalActionPointCost : null;
  }

  Future<String?> selectMapBirthLocation(String locationId) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    final state = await _ensureMapState(character.id);
    final result = _mapTurnEngine.selectBirthLocation(state, locationId);
    if (!result.isSuccess) {
      return result.error;
    }
    final location = <String, MapLocationNode>{
      for (final item in result.state.locations) item.id: item,
    }[locationId];
    return _runRulesMapNarrativeTask(
      character: character,
      previous: state,
      result: result,
      actionTitle: '选择出生地点',
      userFacingAction: '选择出生地点：${location?.name ?? locationId}',
      actionPlan: <String, dynamic>{
        'mode': 'select_birth_location',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'kind': 'location',
            'locationId': locationId,
            'label': location?.name ?? locationId,
          },
        ],
      },
    );
  }

  Future<String?> useMapItem(String itemId) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    final state = await _ensureMapState(character.id);
    final result = _mapTurnEngine.useItem(state, itemId);
    if (!result.isSuccess) {
      return result.error;
    }
    final item = <String, MapInventoryItem>{
      for (final entry in state.mapInventory) entry.id: entry,
    }[itemId];
    return _runRulesMapNarrativeTask(
      character: character,
      previous: state,
      result: result,
      actionTitle: '使用地图道具',
      userFacingAction: '使用地图道具：${item?.name ?? itemId}',
      actionPlan: <String, dynamic>{
        'mode': 'use_map_item',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'kind': 'item',
            'itemId': itemId,
            'label': item?.name ?? itemId,
          },
        ],
      },
    );
  }

  Future<String?> upgradeCurrentMapToRules() async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    final state = await _ensureMapState(character.id);
    if (state.isEmpty) {
      return '当前没有可以升级的旧地图。';
    }
    if (state.isRulesDriven) {
      return '当前地图已经使用新版规则。';
    }
    final upgraded = _mapTurnEngine.prepareBlueprint(
      state,
      characterName: character.name,
    );
    return _applyRulesMapResult(
      character: character,
      result: MapEngineResult(
        state: upgraded,
        logs: const <String>[
          '旧地图已经在本地转换为固定无向有环图。',
          '请选择出生地点后开始新版回合。',
        ],
      ),
      userAction: '升级旧地图规则',
    );
  }

  Future<String?> openMapLocation(String locationId) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    if (!character.mapModeEnabled) {
      return '这个角色还没有开启地图主线模式。';
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍等一下。';
    }

    final state = await _ensureMapState(character.id);
    if (state.isRulesDriven) {
      final result = _mapTurnEngine.resolvePlannedRound(
        state,
        actions: const <String>[],
        locationIds: <String>[locationId],
        timeStep: '下一回合',
      );
      if (!result.isSuccess) {
        return result.error;
      }
      final destination = <String, MapLocationNode>{
        for (final item in state.locations) item.id: item,
      }[locationId];
      return _runRulesMapNarrativeTask(
        character: character,
        previous: state,
        result: result,
        actionTitle: '前往地图地点',
        userFacingAction: '前往地图地点：${destination?.name ?? locationId}',
        actionPlan: <String, dynamic>{
          'mode': 'travel',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'location',
              'locationId': locationId,
              'label': destination?.name ?? locationId,
            },
          ],
        },
      );
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    final normalizedId = locationId.trim();
    MapLocationNode? location;
    for (final item in state.locations) {
      if (item.id == normalizedId) {
        location = item;
        break;
      }
    }
    if (location == null) {
      return '没有找到这个地点，试试重新生成地图。';
    }

    final currentScene = location.scene.trim().isNotEmpty
        ? location.scene.trim()
        : location.description.trim();
    final nextState = state.copyWith(
      currentLocationId: location.id,
      currentLocationName: location.name,
      currentScene: currentScene.isNotEmpty ? currentScene : state.currentScene,
      locations: _markCurrentMapLocation(state.locations, location.id),
      updatedAt: DateTime.now(),
    );
    _mapStateCache[character.id] = nextState;
    await _store.saveMapState(nextState);
    notifyListeners();
    return null;
  }

  Future<String?> runMapFreeAction(String action) async {
    final character = currentCharacter;
    final trimmed = action.trim();
    if (character == null) {
      return '请先选择一个角色。';
    }
    if (!character.mapModeEnabled) {
      return '这个角色还没有开启地图主线模式。';
    }
    if (trimmed.isEmpty) {
      return '先写一下你想在当前位置做什么。';
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍等一下。';
    }

    final state = await _ensureMapState(character.id);
    if (state.isRulesDriven) {
      final result = _mapTurnEngine.resolvePlannedRound(
        state,
        actions: <String>[trimmed],
        locationIds: const <String>[],
        timeStep: '下一回合',
      );
      if (!result.isSuccess) {
        return result.error;
      }
      return _runRulesMapNarrativeTask(
        character: character,
        previous: state,
        result: result,
        actionTitle: '地点行动',
        userFacingAction: trimmed,
        actionPlan: <String, dynamic>{
          'mode': 'free_action',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'action',
              'action': trimmed,
              'label': trimmed,
            },
          ],
        },
      );
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }

    await _appendMapMessage(
      characterId: character.id,
      role: ChatRole.user,
      content: trimmed,
    );

    return _runMapTask(
      character: character,
      actionTitle: '地点行动',
      userFacingAction: trimmed,
      locationHtmlTargetId: state.currentLocationId,
      userPrompt: _buildMapTaskPrompt(
        character: character,
        task: '玩家自由行动',
        instruction:
            '玩家在当前地图地点执行行动：「$trimmed」。请根据当前地点、NPC关系、世界书和事件记录生成行动结果。结果必须影响当前主线状态，可以更新地点 HTML、当前场景、事件记录、NPC 印象、任务、线索或背包。必须给出新的 3-5 个 activeChoices，让用户在地图页内继续点下去。',
      ),
    );
  }

  Future<String?> advanceMapTime(String step) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    if (!character.mapModeEnabled) {
      return '这个角色还没有开启地图主线模式。';
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍等一下。';
    }

    final state = await _ensureMapState(character.id);
    if (state.isRulesDriven) {
      final result = _mapTurnEngine.finishRound(state, step);
      return _runRulesMapNarrativeTask(
        character: character,
        previous: state,
        result: result,
        actionTitle: '时间推进',
        userFacingAction: '时间推进：$step',
        actionPlan: <String, dynamic>{
          'mode': 'advance_time',
          'timeStep': step,
          'items': const <Map<String, dynamic>>[],
        },
      );
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }

    await _appendMapMessage(
      characterId: character.id,
      role: ChatRole.user,
      content: '时间推进：$step',
    );

    return _runMapTask(
      character: character,
      actionTitle: '时间推进',
      userFacingAction: '时间推进：$step',
      locationHtmlTargetId: state.currentLocationId,
      userPrompt: _buildMapTaskPrompt(
        character: character,
        task: '时间推进',
        instruction:
            '请将地图主线时间推进「$step」。推进后要更新当前时间、当前地点氛围、可能发生的事件、NPC 位置与动向、任务、线索、背包变化和 activeChoices。不要把它写成支线预告，这就是当前主线。',
      ),
    );
  }

  Future<String?> runMapPlannedRound({
    required List<String> actions,
    required List<String> locationIds,
    required String timeStep,
    List<Map<String, dynamic>> structuredActions =
        const <Map<String, dynamic>>[],
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    if (!character.mapModeEnabled) {
      return '这个角色还没有开启地图主线模式。';
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍等一下。';
    }

    final state = await _ensureMapState(character.id);
    final safeActions = actions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final safeLocationIds = locationIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final locationsById = <String, MapLocationNode>{
      for (final location in state.locations) location.id: location,
    };
    final selectedLocations = safeLocationIds
        .map((id) => locationsById[id])
        .whereType<MapLocationNode>()
        .toList(growable: false);
    final selectedLocationNames = selectedLocations
        .map((location) => location.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final structuredPlan = _normalizeMapActionPlan(
      rawItems: structuredActions,
      fallbackActions: safeActions,
      selectedLocations: selectedLocations,
      timeStep: timeStep,
    );
    final step = timeStep.trim().isEmpty ? '下一回合' : timeStep.trim();

    if (state.isRulesDriven) {
      final routeMode = _mapRouteModeFromPlan(structuredActions);
      final result = _mapTurnEngine.resolvePlannedRound(
        state,
        actions: safeActions,
        locationIds: safeLocationIds,
        timeStep: step,
        routeMode: routeMode,
        structuredActions: structuredActions,
      );
      if (!result.isSuccess) {
        return result.error;
      }
      final summaryParts = <String>[
        '地图主线推进：$step',
        if (selectedLocationNames.isNotEmpty)
          '计划地点：${selectedLocationNames.join('、')}',
        if (safeActions.isNotEmpty) '计划行动：${safeActions.join('；')}',
        if (selectedLocationNames.isEmpty && safeActions.isEmpty)
          '没有指定行动，让时间按当前局势自然推进。',
      ];
      return _runRulesMapNarrativeTask(
        character: character,
        previous: state,
        result: result,
        actionTitle: '地图下一回合',
        userFacingAction: summaryParts.join('\n'),
        actionPlan: structuredPlan,
        originalStructuredActions: structuredActions,
      );
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }

    final summaryParts = <String>[
      '地图主线推进：$step',
      if (selectedLocationNames.isNotEmpty)
        '计划地点：${selectedLocationNames.join('、')}',
      if (safeActions.isNotEmpty) '计划行动：${safeActions.join('；')}',
      if (selectedLocationNames.isEmpty && safeActions.isEmpty)
        '没有指定行动，请 AI 按当前地图状态自然安排下一段主线。',
    ];
    final userFacingAction = summaryParts.join('\n');

    await _appendMapMessage(
      characterId: character.id,
      role: ChatRole.user,
      content: userFacingAction,
    );

    final fixedTime = step == '下一回合'
        ? '用户没有指定固定跨度，请根据剧情节奏灵活判断经过了多久，可以是片刻、半小时、数小时或一个小阶段。'
        : '用户指定时间跨度为「$step」，请在这个时间范围内尽量完成用户选择的地点与行动。';
    final planText = '''
时间推进：$step
$fixedTime

用户选择的地点：
${selectedLocationNames.isEmpty ? '无。' : selectedLocationNames.map((name) => '- $name').join('\n')}

用户选择的行动：
${safeActions.isEmpty ? '无。' : safeActions.map((action) => '- $action').join('\n')}

【结构化行动计划 JSON】
${const JsonEncoder.withIndent('  ').convert(structuredPlan)}

执行规则：
1. 这是地图主线的正式下一回合，不是预演，不是旁支。
2. 如果用户同时选择多个地点或行动，请按合理路线整合，不要机械逐条罗列。
3. 如果计划之间有冲突，请在剧情里自然取舍，并说明角色实际完成了什么。
4. 必须更新当前时间、当前位置、事件记录、地点 HTML，以及可能变化的 NPC 印象、任务、背包或游戏面板。
5. 继续输出可交互 HTML，并在 [MAP_STATE] JSON 中写回最新地图状态。
6. activeChoices 必须是用户下一步能直接点击的短行动，避免空泛预告。
7. 优先读取“结构化行动计划 JSON”，不要只靠自然语言猜测用户意图；如果 JSON 与上方文字冲突，以 JSON 为准。
''';

    return _runMapTask(
      character: character,
      actionTitle: '地图下一回合',
      userFacingAction: userFacingAction,
      locationHtmlTargetId: state.currentLocationId,
      userPrompt: _buildMapTaskPrompt(
        character: character,
        task: '地图主线下一回合',
        instruction: planText,
      ),
    );
  }

  Future<String?> regenerateCurrentMapLocation() async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    final state = await _ensureMapState(character.id);
    if (state.isRulesDriven) {
      return '新版地图地点属于固定蓝图，不能在游玩中重新生成。';
    }
    final locationId = state.currentLocationId.trim();
    if (locationId.isEmpty) {
      return '还没有当前地点，先生成地图或进入一个地点。';
    }
    final locationName = state.currentLocationName.trim().isEmpty
        ? '当前地点'
        : state.currentLocationName.trim();
    return _runMapTask(
      character: character,
      actionTitle: '重生成地点',
      userFacingAction: '重生成地点：$locationName',
      locationHtmlTargetId: locationId,
      userPrompt: _buildMapTaskPrompt(
        character: character,
        task: '重生成当前地点',
        instruction:
            '请在不推翻主线事实的前提下，重新生成当前地点「$locationName」的可视化 HTML、地点事件、当前场景和可交互按钮。保留已经发生过的重要事件，只优化当前展示和可互动内容，并刷新 activeChoices。',
      ),
    );
  }

  Map<String, dynamic> _normalizeMapActionPlan({
    required List<Map<String, dynamic>> rawItems,
    required List<String> fallbackActions,
    required List<MapLocationNode> selectedLocations,
    required String timeStep,
  }) {
    final plannedItems = <Map<String, dynamic>>[];
    final representedLocationIds = <String>{};
    final representedActions = <String>{};
    for (final raw in rawItems) {
      final label = raw['label']?.toString().trim() ?? '';
      final action = raw['action']?.toString().trim() ??
          raw['actionText']?.toString().trim() ??
          '';
      final locationId = raw['locationId']?.toString().trim() ?? '';
      final kind = raw['kind']?.toString().trim() ?? 'action';
      if (label.isEmpty && action.isEmpty && locationId.isEmpty) {
        continue;
      }
      plannedItems.add(<String, dynamic>{
        'kind': kind.isEmpty ? 'action' : kind,
        'label': label.isEmpty ? action : label,
        'action': action.isEmpty ? label : action,
        if (locationId.isNotEmpty) 'locationId': locationId,
        if ((raw['locationName']?.toString().trim() ?? '').isNotEmpty)
          'locationName': raw['locationName'].toString().trim(),
        if ((raw['riskLevel']?.toString().trim() ?? '').isNotEmpty)
          'riskLevel': raw['riskLevel'].toString().trim(),
        if ((raw['timeCost']?.toString().trim() ?? '').isNotEmpty)
          'timeCost': raw['timeCost'].toString().trim(),
        if ((raw['routeMode']?.toString().trim() ?? '').isNotEmpty)
          'routeMode': raw['routeMode'].toString().trim(),
      });
      if (locationId.isNotEmpty) {
        representedLocationIds.add(locationId);
      }
      if (action.isNotEmpty || label.isNotEmpty) {
        representedActions.add(action.isEmpty ? label : action);
      }
    }
    for (final location in selectedLocations) {
      if (!representedLocationIds.add(location.id)) {
        continue;
      }
      plannedItems.add(<String, dynamic>{
        'kind': 'location',
        'label': '前往 ${location.name}',
        'action': '前往地点：${location.name}',
        'locationId': location.id,
        'locationName': location.name,
        if (location.riskLevel.trim().isNotEmpty)
          'riskLevel': location.riskLevel.trim(),
        if (location.timeCost.trim().isNotEmpty)
          'timeCost': location.timeCost.trim(),
      });
    }
    for (final action in fallbackActions) {
      if (!representedActions.add(action)) {
        continue;
      }
      plannedItems.add(<String, dynamic>{
        'kind': 'action',
        'label': action,
        'action': action,
      });
    }
    return <String, dynamic>{
      'mode': 'map_action_plan',
      'timeStep': timeStep.trim().isEmpty ? '下一回合' : timeStep.trim(),
      'items': plannedItems,
      'rules': <String>[
        '按合理路线整合多地点和多行动',
        '冲突行动要在剧情里自然取舍',
        '输出 MAP_STATE 时写回真实执行结果，不要照抄计划',
      ],
    };
  }

  MapRouteMode _mapRouteModeFromPlan(
    List<Map<String, dynamic>> structuredActions,
  ) {
    for (final item in structuredActions) {
      switch (item['routeMode']?.toString()) {
        case 'safest':
          return MapRouteMode.safest;
        case 'fastest':
          return MapRouteMode.fastest;
        case 'leastActionPoints':
          return MapRouteMode.leastActionPoints;
      }
    }
    return MapRouteMode.leastActionPoints;
  }

  Future<String?> handleMapHtmlAction(String action) async {
    final trimmed = action.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final locationMatch = RegExp(
      r'^(?:map:location:|location:|地点[:：])\s*([^|｜]+)(?:[|｜](.+))?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (locationMatch != null) {
      return openMapLocation(locationMatch.group(1)?.trim() ?? '');
    }

    final timeMatch = RegExp(
      r'^(?:map:time:|time:|时间[:：])\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (timeMatch != null) {
      return advanceMapTime(timeMatch.group(1)?.trim() ?? '下一阶段');
    }

    return runMapFreeAction(trimmed);
  }

  Future<String?> enterMapMomentInChat() async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个角色。';
    }
    if (!character.mapModeEnabled) {
      return '这个角色还没有开启地图主线模式。';
    }
    final state = await _ensureMapState(character.id);
    if (state.isEmpty) {
      return '还没有可带入聊天的地图主线。';
    }
    final scene = state.activeScene.trim();
    final choices = state.activeChoices
        .take(5)
        .map((choice) => '- ${choice.label}')
        .join('\n');
    final content = '''
【地图主线同步到聊天】
当前阶段：${state.stage.trim().isEmpty ? '未定' : state.stage.trim()}
当前目标：${state.mainGoal.trim().isEmpty ? '未定' : state.mainGoal.trim()}
当前时间：${state.timeLabel.trim().isEmpty ? '未定' : state.timeLabel.trim()}
当前位置：${state.currentLocationName.trim().isEmpty ? '未定' : state.currentLocationName.trim()}

当前场景：
${scene.isEmpty ? '暂无场景正文。' : scene}

可继续选择：
${choices.trim().isEmpty ? '暂无。' : choices}
''';
    await _appendMapMessage(
      characterId: character.id,
      role: ChatRole.user,
      content: content,
    );
    _currentTabIndex = 0;
    notifyListeners();
    return null;
  }

  Future<String?> _runRulesMapNarrativeTask({
    required CharacterProfile character,
    required MapWorldState previous,
    required MapEngineResult result,
    required String actionTitle,
    required String userFacingAction,
    required Map<String, dynamic> actionPlan,
    List<Map<String, dynamic>> originalStructuredActions =
        const <Map<String, dynamic>>[],
  }) async {
    if (!result.isSuccess) {
      return result.error;
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。规则回合尚未提交。';
    }
    if (_isSending || _isMapGenerating || _isGameplaySystemGenerating) {
      return '当前还有内容正在生成，请稍等一下。';
    }

    _isSending = true;
    _isMapGenerating = true;
    notifyListeners();

    try {
      final settled = result.state;
      final userPrompt = _buildRulesMapNarrativePrompt(
        character: character,
        previous: previous,
        settled: settled,
        actionTitle: actionTitle,
        actionPlan: actionPlan,
        originalStructuredActions: originalStructuredActions,
        localLogs: result.logs,
      );
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _mapSystemPrompt,
        userPrompt: userPrompt,
        temperature: character.modelParams.temperature,
        topP: character.modelParams.topP,
      );
      final resultText = raw.trim();
      if (resultText.isEmpty) {
        throw const LlmApiException('模型返回了空的地图剧情。');
      }

      final repairedResult = await _repairMapResultIfNeeded(
        character: character,
        previous: settled,
        originalResult: resultText,
        originalPrompt: userPrompt,
        allowLocationReset: false,
        minimumNarrativeChineseCharacters: 2000,
      );
      final nextMapState = _mergeRulesMapNarrative(
        characterId: character.id,
        settled: settled,
        rawContent: repairedResult,
      );

      final previousGameState = await _ensureGameState(character.id);
      final parsedGameState = GameStateParser.parseFromMessage(
        characterId: character.id,
        content: repairedResult,
        previous: previousGameState,
      );
      if (parsedGameState == null) {
        throw const LlmApiException(
          '模型没有返回可解析的 GAME_STATE，规则回合未提交。',
        );
      }
      final gameplayTurnId = IdGenerator.message();
      var narrativeGameState = previousGameState;
      if (character.gameplaySystem != null) {
        narrativeGameState = _applyGameplayPatchToState(
          character: character,
          previousState: previousGameState,
          state: _mergeGameStateWithRulesMap(previousGameState, nextMapState),
          turnId: gameplayTurnId,
          content: repairedResult,
          patchExpected: true,
        );
      }
      narrativeGameState = narrativeGameState.copyWith(
        profileDetails: parsedGameState.profileDetails,
        relationshipNotes: parsedGameState.relationshipNotes,
        npcChanges: parsedGameState.npcChanges,
        npcUpdates: parsedGameState.npcUpdates,
      );
      final nextGameState = _mergeGameStateWithRulesMap(
        narrativeGameState,
        nextMapState,
      );

      final visibleContent = _stripMapStateBlock(repairedResult).trim();
      if (visibleContent.isEmpty) {
        throw const LlmApiException('模型没有返回可阅读的地图主线剧情。');
      }

      final previousHistory = await _ensureHistory(character.id);
      final messageTime = DateTime.now();
      final userMessage = ChatMessage(
        id: IdGenerator.message(),
        role: ChatRole.user,
        content: '【地图行动】$userFacingAction',
        timestamp: messageTime,
        isSummarized: false,
        tokenEstimate: _countCompletedTextTokens(userFacingAction),
      );
      final assistantContent = '【地图主线｜$actionTitle】\n$visibleContent';
      final assistantMessage = ChatMessage(
        id: gameplayTurnId,
        role: ChatRole.assistant,
        gameStateSnapshot: _gameplaySnapshot(
            nextGameState, character.gameplaySystem,
            previousState: previousGameState),
        content: assistantContent,
        timestamp: messageTime.add(const Duration(microseconds: 1)),
        isSummarized: false,
        tokenEstimate: _countCompletedTextTokens(assistantContent),
      );
      final nextHistory = previousHistory.copyWith(
        messages: <ChatMessage>[
          ...previousHistory.messages,
          userMessage,
          assistantMessage,
        ],
      );

      final commitError = await _commitRulesMapNarrative(
        characterId: character.id,
        mapState: nextMapState,
        gameState: nextGameState,
        history: nextHistory,
      );
      return commitError;
    } on LlmApiException catch (error) {
      return 'AI 叙事失败，本回合未提交：${error.message}';
    } catch (error) {
      return 'AI 叙事失败，本回合未提交：$error';
    } finally {
      _isSending = false;
      _isMapGenerating = false;
      notifyListeners();
    }
  }

  Future<String?> _commitRulesMapNarrative({
    required String characterId,
    required MapWorldState mapState,
    required GameStateSnapshot gameState,
    required DialogueHistory history,
  }) async {
    Object? mapPersistError;
    var mapPersisted = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _store.saveMapState(mapState);
        mapPersisted = true;
        break;
      } catch (error) {
        mapPersistError = error;
      }
    }
    if (!mapPersisted) {
      return '地图状态保存失败，本回合未提交：$mapPersistError';
    }

    // The durable map write is the commit point. Later failures must not make
    // the caller retry and resolve the same map turn twice.
    _mapStateCache[characterId] = mapState;
    _gameStateCache[characterId] = gameState;
    _historyCache[characterId] = history;

    final failures = <String>[];

    Future<void> persistWithRetry(
      String label,
      Future<void> Function() persist,
    ) async {
      Object? lastError;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await persist();
          return;
        } catch (error) {
          lastError = error;
        }
      }
      failures.add('$label: $lastError');
    }

    await persistWithRetry('游戏状态', () => _store.saveGameState(gameState));
    await persistWithRetry('地图剧情记录', () => _store.saveDialogueHistory(history));

    try {
      await _applyGameStateNpcUpdates(characterId, gameState);
    } catch (error) {
      failures.add('NPC 叙事更新: $error');
    }
    try {
      _scheduleSummarization(characterId);
    } catch (error) {
      failures.add('剧情摘要调度: $error');
    }
    try {
      await _updateGamification(
        (gamification) => gamification.incrementStat('totalMapModeActions'),
        notify: false,
      );
    } catch (error) {
      failures.add('地图行动统计: $error');
    }

    if (failures.isNotEmpty) {
      debugPrint('规则地图回合已提交，但部分持久化失败：${failures.join(' | ')}');
    }
    return null;
  }

  String _buildRulesMapNarrativePrompt({
    required CharacterProfile character,
    required MapWorldState previous,
    required MapWorldState settled,
    required String actionTitle,
    required Map<String, dynamic> actionPlan,
    required List<Map<String, dynamic>> originalStructuredActions,
    required List<String> localLogs,
  }) {
    const encoder = JsonEncoder.withIndent('  ');
    final originalOrder = originalStructuredActions.isEmpty
        ? '未提供额外结构化条目；以“用户行动计划 JSON”的 items 顺序为准。'
        : encoder.convert(originalStructuredActions);
    final logs = localLogs.isEmpty
        ? '- 本地规则没有产生额外日志。'
        : localLogs.map((item) => '- $item').join('\n');
    return _buildMapTaskPrompt(
      character: character,
      task: '新版规则地图 AI 叙事：$actionTitle',
      instruction: '''
这是一次已经由 App 本地规则引擎完成确定性结算的正式地图回合。你只负责把结算事实写成连续、沉浸的主线剧情，并补充允许由叙事层维护的展示字段。

叙事硬性要求：
1. 先输出不少于 2000 个中文字符的正式连续剧情正文，不要写成“结算说明”、规则日志、摘要列表或系统播报。
2. 正文必须具体呈现场景变化、人物反应、NPC 对话和本轮行动造成的后果，并与最近聊天、角色设定和世界书连续。
3. 不得替用户追加其没有选择的关键决定，不得把未执行的行动写成已经发生。
4. 正文之后必须输出完整 [GAME_STATE] 和 [MAP_STATE]；不要输出 [CHOICES]。下一步行动只写进 activeChoices。

规则权威边界：
1. “本地结算后 MAP_STATE”是唯一权威结果。不得改写 schemaVersion、seed、turnNumber、行动力、行动力上限、危机时钟、背包、状态效果、任务、世界事件、NPC agent、出生点、当前位置、时间、阶段或主线目标。
2. 不得新增、删除、重排或改写地点和道路；地点的 id/name/parentId/x/y/tags/actions/status/riskLevel/timeCost 必须沿用结算后状态。
3. 你可以更新 currentScene、地点的 description/scene/npcs/clues/nextActions、activeChoices、eventSummary，以及既有可见 NPC 的 status/intent/lastSeen。其他字段即使输出也会被 App 丢弃。
4. [MAP_STATE] 仍须输出完整 locations 和 npcPositions，固定字段应原样复制“本地结算后 MAP_STATE”，避免叙事与地图 UI 冲突。
5. [GAME_STATE] 只接受人物资料、关系备注、NPC 叙事更新，以及剧场已声明的 [THEATER_PATCH]。资源、任务、背包、剧情标记、指标等必须沿用结算前状态，AI 对它们的改动会被丢弃。

用户行动计划 JSON（items 保留用户原始顺序）：
${encoder.convert(actionPlan)}

原始 structuredActions（如有，数组顺序就是行动篮子顺序）：
$originalOrder

本地规则结算日志（只能作为剧情事实，不要原样逐条播报）：
$logs

结算前 MAP_STATE：
${encoder.convert(previous.toJson())}

本地结算后 MAP_STATE（权威）：
${encoder.convert(settled.toJson())}
''',
    );
  }

  MapWorldState _mergeRulesMapNarrative({
    required String characterId,
    required MapWorldState settled,
    required String rawContent,
  }) {
    final narrated = _mergeMapResult(
      characterId: characterId,
      previous: settled,
      rawContent: rawContent,
      locationHtmlTargetId: settled.currentLocationId,
      allowLocationReset: false,
    );
    final narratedLocations = <String, MapLocationNode>{
      for (final location in narrated.locations) location.id: location,
    };
    final lockedLocations = settled.locations.map((locked) {
      final incoming = narratedLocations[locked.id];
      if (incoming == null) {
        return locked;
      }
      return locked.copyWith(
        description: incoming.description,
        scene: incoming.scene,
        npcs: incoming.npcs,
        clues: incoming.clues,
        nextActions: incoming.nextActions,
      );
    }).toList(growable: false);

    final narratedNpcById = <String, MapNpcPosition>{
      for (final npc in narrated.npcPositions)
        if (npc.id.trim().isNotEmpty) npc.id.trim(): npc,
    };
    final narratedNpcByName = <String, MapNpcPosition>{
      for (final npc in narrated.npcPositions)
        if (npc.name.trim().isNotEmpty) npc.name.trim(): npc,
    };
    final lockedNpcPositions = settled.npcPositions.map((locked) {
      final incoming = narratedNpcById[locked.id.trim()] ??
          narratedNpcByName[locked.name.trim()];
      if (incoming == null) {
        return locked;
      }
      return locked.copyWith(
        status: incoming.status.trim().isEmpty
            ? locked.status
            : incoming.status.trim(),
        intent: incoming.intent.trim().isEmpty
            ? locked.intent
            : incoming.intent.trim(),
        lastSeen: incoming.lastSeen.trim().isEmpty
            ? locked.lastSeen
            : incoming.lastSeen.trim(),
      );
    }).toList(growable: false);
    final safeChoices = _sanitizeRulesMapChoices(
      settled: settled,
      locations: lockedLocations,
      narrated: narrated.activeChoices,
    );

    return settled.copyWith(
      updatedAt: DateTime.now(),
      currentScene: narrated.currentScene,
      locations: lockedLocations,
      activeChoices: safeChoices,
      discoveredClues: narrated.discoveredClues,
      npcPositions: lockedNpcPositions,
      npcMovements: narrated.npcMovements,
      eventSummary: narrated.eventSummary,
      eventLog: narrated.eventLog,
    );
  }

  List<MapStoryChoice> _sanitizeRulesMapChoices({
    required MapWorldState settled,
    required List<MapLocationNode> locations,
    required List<MapStoryChoice> narrated,
  }) {
    final locationsById = <String, MapLocationNode>{
      for (final location in locations) location.id: location,
    };
    final result = <MapStoryChoice>[];
    final seen = <String>{};
    final seenLocationIds = <String>{};

    bool addChoice(MapStoryChoice choice) {
      final key = choice.id.trim().isNotEmpty
          ? choice.id.trim()
          : '${choice.kind.name}|${choice.action.trim()}';
      if (key.isEmpty || !seen.add(key) || result.length >= 5) {
        return false;
      }
      result.add(choice);
      return true;
    }

    void addSanitized(MapStoryChoice choice) {
      final locationId = choice.locationId.trim();
      if (choice.kind == MapStoryChoiceKind.location) {
        final location = locationsById[locationId];
        if (location == null ||
            locationId == settled.currentLocationId ||
            location.status == MapLocationStatus.hidden ||
            location.status == MapLocationStatus.locked) {
          return;
        }
        final route = _mapTurnEngine.findRoute(settled, locationId);
        if (route.isReachable &&
            !seenLocationIds.contains(locationId) &&
            addChoice(choice.copyWith(locationId: locationId))) {
          seenLocationIds.add(locationId);
        }
        return;
      }
      if (locationId.isEmpty) {
        addChoice(choice);
        return;
      }
      addChoice(choice.copyWith(locationId: settled.currentLocationId));
    }

    for (final choice in narrated) {
      addSanitized(choice);
    }
    if (result.length < 3) {
      for (final choice in settled.activeChoices) {
        addSanitized(choice);
      }
    }
    if (result.length < 3) {
      for (final choice
          in _choicesFromLocations(locations, settled.currentLocationId)) {
        addSanitized(choice);
      }
    }
    if (result.length < 3) {
      final locationName = settled.currentLocationName.trim().isEmpty
          ? '当前地点'
          : settled.currentLocationName.trim();
      for (final choice in <MapStoryChoice>[
        MapStoryChoice(
          id: 'local_inspect_${settled.currentLocationId}',
          label: '调查$locationName的异常',
          action: '仔细调查$locationName里值得追查的痕迹',
          locationId: settled.currentLocationId,
          kind: MapStoryChoiceKind.clue,
          riskLevel: '低',
          timeCost: '1 AP',
        ),
        MapStoryChoice(
          id: 'local_social_${settled.currentLocationId}',
          label: '询问$locationName的相关人物',
          action: '向$locationName的相关人物确认当前情况',
          locationId: settled.currentLocationId,
          kind: MapStoryChoiceKind.social,
          riskLevel: '低',
          timeCost: '1 AP',
        ),
        MapStoryChoice(
          id: 'local_rest_${settled.currentLocationId}',
          label: '休整并整理线索',
          action: '在$locationName休整并整理已知线索',
          locationId: settled.currentLocationId,
          kind: MapStoryChoiceKind.rest,
          riskLevel: '低',
          timeCost: '1 AP',
        ),
      ]) {
        addSanitized(choice);
      }
    }
    return result;
  }

  Future<String?> _applyRulesMapResult({
    required CharacterProfile character,
    required MapEngineResult result,
    required String userAction,
  }) async {
    if (!result.isSuccess) {
      return result.error;
    }
    final state = result.state;
    _mapStateCache[character.id] = state;
    await _store.saveMapState(state);
    await _appendMapMessage(
      characterId: character.id,
      role: ChatRole.user,
      content: '【地图行动】$userAction',
    );
    if (result.logs.isNotEmpty) {
      await _appendMapMessage(
        characterId: character.id,
        role: ChatRole.assistant,
        content: '【本地回合结算】\n${result.logs.map((item) => '- $item').join('\n')}',
      );
    }
    await _syncGameStateFromRulesMap(character.id, state);
    await _updateGamification(
      (gamification) => gamification.incrementStat('totalMapModeActions'),
      notify: false,
    );
    notifyListeners();
    return null;
  }

  Future<void> _syncGameStateFromRulesMap(
    String characterId,
    MapWorldState mapState,
  ) async {
    final previous = await _ensureGameState(characterId);
    final next = _mergeGameStateWithRulesMap(previous, mapState);
    _gameStateCache[characterId] = next;
    await _store.saveGameState(next);
  }

  GameStateSnapshot _mergeGameStateWithRulesMap(
    GameStateSnapshot previous,
    MapWorldState mapState,
  ) {
    final mapItems = mapState.mapInventory
        .where((item) => item.quantity > 0)
        .map((item) => '${item.name}×${item.quantity}')
        .toList(growable: false);
    final activeQuests = mapState.quests
        .where((quest) => quest.status == MapQuestStatus.active)
        .map((quest) => '${quest.title}（${quest.progress}/${quest.total}）')
        .toList(growable: false);
    final completedQuests = mapState.quests
        .where((quest) => quest.status == MapQuestStatus.completed)
        .map((quest) => quest.title)
        .toList(growable: false);
    return previous.copyWith(
      updatedAt: DateTime.now(),
      location: mapState.currentLocationName,
      timeLabel: mapState.timeLabel,
      status:
          '地图回合 ${mapState.turnNumber}｜行动力 ${mapState.currentActionPoints}/${mapState.maxActionPoints}（临时上限 ${mapState.temporaryActionPointLimit}）｜危机 ${mapState.threatClock}/${mapState.threatLimit}',
      mainTask: mapState.mainGoal,
      sideTasks: activeQuests,
      completedTasks: <String>{
        ...previous.completedTasks,
        ...completedQuests,
      }.toList(growable: false),
      inventory:
          <String>{...previous.inventory, ...mapItems}.toList(growable: false),
      eventTitle: mapState.eventSummary,
      eventDescription: mapState.currentScene,
      plotFlags: <String>{...previous.plotFlags, ...mapState.facts}
          .take(40)
          .toList(growable: false),
      npcChanges: <String>{
        ...previous.npcChanges,
        ...mapState.npcPositions.map(
          (npc) =>
              '${npc.name}：${npc.locationName}｜${npc.status}｜${npc.intent}',
        ),
      }.toList(growable: false),
    );
  }

  List<MapOpeningChoice> _localMapOpeningChoices(
    CharacterProfile character,
  ) {
    return <MapOpeningChoice>[
      MapOpeningChoice(
        id: 'origin_local',
        category: '身份',
        label: '本地居民',
        description: '熟悉一部分道路和生活规则',
        prompt: '玩家是本地居民，对常用道路和公开势力有基础认知。',
      ),
      MapOpeningChoice(
        id: 'origin_outsider',
        category: '身份',
        label: '外来访客',
        description: '情报较少，但没有旧关系负担',
        prompt: '玩家是刚抵达此地的外来访客，没有固定阵营。',
      ),
      MapOpeningChoice(
        id: 'origin_runner',
        category: '身份',
        label: '跑图人',
        description: '擅长规划路线和寻找捷径',
        prompt: '玩家擅长移动与路线判断，地图应提供可解锁捷径。',
      ),
      MapOpeningChoice(
        id: 'goal_truth',
        category: '目标',
        label: '追查真相',
        description: '以调查和线索链为主',
        prompt: '主线围绕逐步拼合真相展开，至少准备三段线索链。',
      ),
      MapOpeningChoice(
        id: 'goal_rescue',
        category: '目标',
        label: '寻找失踪者',
        description: 'NPC 会留下位置与行动痕迹',
        prompt: '主线目标是寻找失踪者，NPC位置与最后已知情报很重要。',
      ),
      MapOpeningChoice(
        id: 'goal_survive',
        category: '目标',
        label: '撑过危机',
        description: '更强调危机时钟和资源',
        prompt: '主线强调限时危机、道路变化和资源取舍。',
      ),
      MapOpeningChoice(
        id: 'edge_supply',
        category: '优势',
        label: '额外补给',
        description: '开局获得更多恢复类道具',
        prompt: '初始道具应多给一份便携口粮或等价恢复道具。',
      ),
      MapOpeningChoice(
        id: 'edge_contact',
        category: '优势',
        label: '可靠联系人',
        description: '开局掌握一名 NPC 的可信情报',
        prompt: '安排一名与玩家关系较好的联系人，并给出其日程和目标。',
      ),
      MapOpeningChoice(
        id: 'edge_intel',
        category: '优势',
        label: '道路情报',
        description: '更早看见道路风险和封锁条件',
        prompt: '多数初始道路应公开风险和消耗，隐藏道路仍需后续发现。',
      ),
      MapOpeningChoice(
        id: 'risk_hunter',
        category: '风格',
        label: '高风险高收益',
        description: '危险路线会提供更直接的奖励',
        prompt: '提供短而危险的路线，危险事件同时可能带来关键收益。',
      ),
      MapOpeningChoice(
        id: 'risk_social',
        category: '风格',
        label: '关系优先',
        description: '交涉能够改变道路和任务条件',
        prompt: '让 NPC 关系能够解锁道路、情报或替代任务方案。',
      ),
      MapOpeningChoice(
        id: 'risk_steady',
        category: '风格',
        label: '稳健调查',
        description: '路线更长，但可预判风险',
        prompt: '提供较长但低风险的路线和可靠的情报获取方式。',
      ),
    ];
  }

  String _buildMapBlueprintPrompt(
    CharacterProfile character,
    MapWorldState state,
  ) {
    final userProfile = _findBoundUserProfile(character.id);
    final knownNpcs = _npcProfilesForRuntime(character.id)
        .take(12)
        .map((npc) => '- ${npc.name}：${npc.description}')
        .join('\n');
    return '''
请为“${character.name}”生成一张一次生成后永久固定的回合制地图蓝图。

角色设定：
${character.prompt}

玩家角色：
${userProfile == null ? '未绑定，按第二人称玩家处理。' : '${userProfile.name}｜${userProfile.persona}｜${userProfile.description}'}

开局选择：
${state.openingSummary.trim().isEmpty ? '没有额外选择。' : state.openingSummary}

世界书：
${_formatWorldBooksForPrompt(character.id)}

已知 NPC：
${knownNpcs.trim().isEmpty ? '暂无，可生成 3-6 名地图 NPC。' : knownNpcs}

只输出一个 JSON 对象，不要 Markdown、HTML、GAME_STATE、MAP_STATE、解释或正文。要求：
1. locations 必须有 8-10 个固定地点，每项包含 id/name/description/scene/status/riskLevel/timeCost/x/y/tags/actions。
2. x/y 是 0.08-0.92 的画布比例坐标，地点之间不要重叠。
3. actions 每个地点 2-4 个，字段为 id/label/description/kind/actionPointCost/riskLevel/requiredItemId/clue/rewardItemId/oneShot；actionPointCost 只能是 1 或 2。
4. edges 是无向边，只写一次 fromId/toId；所有地点必须连通，每点度数 2-4，至少两个环；边包含 id/fromId/toId/actionPointCost/riskLevel/timeCost/tags/requiredItemId/blocked/discovered。
5. 普通移动 1 AP，困难道路 2 AP。基础行动力 3，临时上限 5，总上限 8；回合自然恢复不能超过 5，恢复道具可以临时突破但不能超过 8。
6. spawnCandidates 必须有 3 个，分别使用 safe/social/danger 风格，且不能选择 hidden/locked 地点。
7. npcAgents 生成 3-6 名 NPC，包含 id/name/trueLocationId/homeLocationId/goalLocationId/goal/traits/scheduleLocationIds/knowledge/relation/riskTolerance/status/intent。
8. quests 生成 2-4 条任务，包含 id/title/description/targetLocationIds/progress/total/deadlineTurn/status。
9. worldEvents 生成 8-12 个一次性事件，包含 id/title/narrative/locationId/kind/triggerTurn/weight/clue/rewardItemId/threatDelta/blockEdgeId/resolved。
10. mapInventory 只生成白名单类型 restoreActionPoints/moveDiscount/camp/key/intel；普通恢复量为 1-2，稀有恢复道具可为 3-5，用于临时突破 5 AP，但绝不能超过 8 AP 总上限。
11. 所有运行时效果只使用上述结构化字段，绝对不能输出代码或自定义脚本。

JSON 顶层字段：
title, stage, mainGoal, locations, edges, spawnCandidates, mapInventory, quests, worldEvents, npcAgents, facts, threatLimit。
''';
  }

  static const String _mapBlueprintSystemPrompt = '''
你是回合制地图的世界蓝图设计器。你只负责一次性生成固定世界数据，不负责后续回合叙事或状态更新。
必须输出严格 JSON。地图必须是连通的无向有环图，所有地点、道路、NPC、任务和事件在首次生成后永久固定。
不要输出 HTML、Markdown、自然语言前言、GAME_STATE 或 MAP_STATE 标签。
''';

  Future<String?> generateConversationToolReply(
    String toolId, {
    String userRequest = '',
    String resultTitle = '',
    bool persistResult = true,
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending) {
      return '当前还有回复正在生成，请稍等。';
    }

    final history = await _ensureHistory(character.id);
    if (history.messages.isEmpty) {
      return '当前还没有聊天记录，无法生成这个辅助内容。';
    }

    final spec = _utilitySpec(toolId);
    if (spec == null) {
      return '没有找到这个 AI 工具。';
    }

    _isSending = true;
    _lastToolResultId = null;
    _ephemeralToolResult = null;
    notifyListeners();

    try {
      final memory = await _ensureMemory(character.id);
      final gameState = await _ensureGameState(character.id);
      final npcProfiles = worldNpcProfilesForCharacter(character.id);
      final result = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _utilitySystemPrompt,
        userPrompt: _buildUtilityPrompt(
          spec: spec,
          character: character,
          history: history,
          memory: memory,
          gameState: gameState,
          npcProfiles: npcProfiles,
          userRequest: userRequest,
        ),
        temperature: spec.temperature,
        topP: 0.9,
      );

      final toolResult = ToolResult(
        id: IdGenerator.generic('tool'),
        characterId: character.id,
        toolId: toolId,
        toolTitle: resultTitle.trim().isEmpty ? spec.title : resultTitle.trim(),
        content: result.trim(),
        createdAt: DateTime.now(),
      );
      if (persistResult) {
        _toolResults.insert(0, toolResult);
        _lastToolResultId = toolResult.id;
        await _store.saveToolResults(_toolResults);
        await _updateGamification(
          (state) => state.incrementStat('totalToolResults'),
          notify: false,
        );
      } else {
        _ephemeralToolResult = toolResult;
      }
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (error) {
      return 'AI 工具生成失败：$error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<String?> generateFanfic({
    required String pairingMode,
    required String firstParticipantId,
    String? secondParticipantId,
    required String inspiration,
    required bool blindBox,
    void Function(String partial)? onChunk,
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending) {
      return '当前还有回复正在生成，请稍等。';
    }

    const cost = 10;
    if (_gamification.coins < cost) {
      return '同人文生成一次 10 啥币，钱包还差一点灵感。';
    }
    if (pairingMode != 'user_npc' && pairingMode != 'npc_npc') {
      return '请选择同人文主角关系。';
    }

    final firstNpc = npcProfileById(firstParticipantId);
    if (firstNpc == null ||
        !(firstNpc.characterId == character.id ||
            firstNpc.isBoundTo(character.id) ||
            firstNpc.isBoundTo(character.rootCharacterId))) {
      return '请先选择一个 NPC。';
    }

    final userMode = pairingMode == 'user_npc';
    NpcProfile? secondNpc;
    if (!userMode) {
      final targetId = secondParticipantId?.trim() ?? '';
      if (targetId.isEmpty || targetId == firstNpc.id) {
        return 'NPC 和 NPC 同人文需要选择两个不同 NPC。';
      }
      secondNpc = npcProfileById(targetId);
      if (secondNpc == null ||
          !(secondNpc.characterId == character.id ||
              secondNpc.isBoundTo(character.id) ||
              secondNpc.isBoundTo(character.rootCharacterId))) {
        return '请为同人文选择有效的第二个 NPC。';
      }
    }

    final userProfile = _findBoundUserProfile(character.id);
    if (userMode && userProfile == null) {
      return '请先在用户页创建并绑定一个用户角色。';
    }

    final trimmedInspiration = inspiration.trim();
    if (trimmedInspiration.isEmpty) {
      return '请填写同人文灵感，或直接点开盲盒生成。';
    }

    await _updateGamification((state) => state.spendCoins(cost), notify: false);
    _isSending = true;
    _lastFanficResultId = null;
    notifyListeners();

    try {
      final history = await _ensureHistory(character.id);
      final memory = await _ensureMemory(character.id);
      final gameState = await _ensureGameState(character.id);
      final prompt = _buildFanficPrompt(
        character: character,
        history: history,
        memory: memory,
        gameState: gameState,
        userProfile: userMode ? userProfile : null,
        firstNpc: firstNpc,
        secondNpc: secondNpc,
        inspiration: trimmedInspiration,
        blindBox: blindBox,
      );

      final buffer = StringBuffer();
      await for (final chunk in _apiClient.streamUtilityTask(
        settings: _settings,
        systemPrompt: _fanficSystemPrompt,
        userPrompt: prompt,
        temperature: 0.82,
        topP: 0.92,
      )) {
        buffer.write(chunk);
        onChunk?.call(buffer.toString());
      }
      var trimmedContent = buffer.toString().trim();
      if (trimmedContent.isEmpty) {
        throw const LlmApiException('模型返回了空同人文。');
      }

      // 完整性兜底：标题缺失或正文明显过短时，自动续写一次。
      if (_extractFanficGeneratedTitle(trimmedContent).isEmpty ||
          trimmedContent.length < 800) {
        final continuation = StringBuffer();
        try {
          await for (final chunk in _apiClient.streamUtilityTask(
            settings: _settings,
            systemPrompt: _fanficSystemPrompt,
            userPrompt: _buildFanficContinuationPrompt(trimmedContent),
            temperature: 0.7,
            topP: 0.9,
          )) {
            continuation.write(chunk);
          }
        } catch (_) {
          // 续写失败不阻塞主流程，保留已生成的部分。
        }
        final extra = continuation.toString().trim();
        if (extra.isNotEmpty) {
          trimmedContent = '$trimmedContent\n\n$extra';
          onChunk?.call(trimmedContent);
        }
      }

      final pairingLabel = userMode
          ? '${userProfile!.name} × ${firstNpc.name}'
          : '${firstNpc.name} × ${secondNpc!.name}';
      final generatedTitle = _extractFanficGeneratedTitle(trimmedContent);
      final result = FanficResult(
        id: IdGenerator.generic('fanfic'),
        characterId: character.id,
        title: generatedTitle.trim().isEmpty
            ? _fanficTitle(pairingLabel, trimmedInspiration, blindBox: blindBox)
            : generatedTitle,
        pairingLabel: pairingLabel,
        inspiration: trimmedInspiration,
        content: trimmedContent,
        createdAt: DateTime.now(),
        blindBox: blindBox,
      );
      _fanficResults.insert(0, result);
      _lastFanficResultId = result.id;
      await _store.saveFanficResults(_fanficResults);
      await _updateGamification(
        (state) {
          var next = state
              .incrementStat('totalFanficResults')
              .incrementStat(
                  userMode ? 'totalFanficUserNpc' : 'totalFanficNpcNpc')
              .setStatMax('maxFanficLength', trimmedContent.runes.length);
          if (blindBox) {
            next = next.incrementStat('totalFanficBlindBoxes');
          }
          return next;
        },
        notify: false,
      );
      return null;
    } on LlmApiException catch (error) {
      await _updateGamification((state) => state.addCoins(cost), notify: false);
      return error.message;
    } catch (error) {
      await _updateGamification((state) => state.addCoins(cost), notify: false);
      return '同人文生成失败，啥币已退回：$error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<String?> beautifyMessageAsPanel(String messageId) async {
    return _transformAssistantMessage(
      messageId: messageId,
      title: '美化成互动面板',
      replaceOriginal: false,
      instruction:
          '把目标回复改造成一个手机优先、可交互、可独立滚动的 HTML 剧情面板。保留原剧情信息，不新增重大剧情。输出一个完整 ```html 代码块```。可点击按钮必须带 data-prompt 或 data-action，按钮文本要能作为用户下一步行动。',
    );
  }

  Future<String?> repairMessageFormat(String messageId) async {
    return _transformAssistantMessage(
      messageId: messageId,
      title: '修复回复格式',
      replaceOriginal: true,
      instruction:
          '修复目标回复的格式错误：补全 Markdown、HTML 代码块、[BUBBLE] 或 [CHOICES] 结构。不要改变剧情事实，不要大幅改写内容。如果存在 HTML，请输出完整可运行文档；如果有可点击按钮，请使用 data-prompt 或 data-action。',
    );
  }

  Future<String?> regenerateAssistantMessage(
    String messageId, {
    String direction = '',
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先创建或选择一个角色。';
    }

    if (!_settings.canChat) {
      return '请先在设置页填写 API 地址、密钥和模型名称。';
    }

    if (_isSending) {
      return '当前还有一条回复在生成，请稍等。';
    }

    final history = await _ensureHistory(character.id);
    final messageIndex =
        history.messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) {
      return '没有找到要重新生成的消息。';
    }

    final targetMessage = history.messages[messageIndex];
    if (targetMessage.role != ChatRole.assistant) {
      return '只有 AI 回复可以重新生成。';
    }

    final requestSeedMessages = history.messages.sublist(0, messageIndex);
    if (!_hasPendingUserMessages(requestSeedMessages)) {
      return '这条回复前面没有可用于重新生成的用户消息。';
    }

    final turnSystem =
        _gameplaySystemAtMessage(targetMessage, character.gameplaySystem);
    final turnCharacter = turnSystem == null
        ? character
        : character.copyWith(gameplaySystem: turnSystem);
    final beforeTarget = _replayGameStateFromHistory(
      character.id,
      history.copyWith(messages: requestSeedMessages),
      baselineOverride: _gameplayReplayBaseline(history.messages, character.id),
      finalSystemOverride: turnSystem,
    ).gameState;

    final replacedMessages = List<ChatMessage>.from(history.messages);
    replacedMessages[messageIndex] = targetMessage.copyWith(
      content: '',
      isSummarized: false,
      timestamp: DateTime.now(),
    );

    final trimmedDirection = direction.trim();
    final requestMessages = trimmedDirection.isEmpty
        ? requestSeedMessages
        : <ChatMessage>[
            ...requestSeedMessages,
            ChatMessage(
              id: IdGenerator.generic('regen_hint'),
              role: ChatRole.user,
              content:
                  '【隐藏重写方向】请按以下方向重新生成上一条 AI 回复，不要把本提示写进正文：$trimmedDirection',
              timestamp: DateTime.now(),
              isSummarized: false,
            ),
          ];

    return _streamAssistantReply(
      character: turnCharacter,
      originalHistory: history,
      optimisticHistory: history.copyWith(messages: replacedMessages),
      placeholderMessageId: targetMessage.id,
      requestMessages: requestMessages,
      invalidatedMessageIds: <String>{targetMessage.id},
      gameStateOverride: beforeTarget,
      // 不强制重置缓存阶段：重生成请求的前缀与上一轮完全相同，
      // 保留 epoch 可以让这条请求直接命中服务端上下文缓存；
      // 目标消息在窗口锚点之前时，_planChatRequestMessages 会
      // 自然以 missing_epoch_anchor 触发换代。
      cacheResetReason: '',
    );
  }

  Future<void> updateMessageContent(
      String messageId, String nextContent) async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }

    final trimmed =
        MessageContentParser.normalizeChoiceBlocks(nextContent).trim();
    if (trimmed.isEmpty) {
      return;
    }

    final history = await _ensureHistory(character.id);
    final messageIndex =
        history.messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) {
      return;
    }

    final updatedMessages = List<ChatMessage>.from(history.messages);
    final tokenCount = _countCompletedTextTokens(trimmed);
    updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
      content: trimmed,
      isSummarized: false,
      tokenEstimate: tokenCount,
      promptReplayContent: updatedMessages[messageIndex].role == ChatRole.user
          ? null
          : _apiClient.buildAssistantPromptReplayContent(trimmed),
      clearPromptReplayContent:
          updatedMessages[messageIndex].role == ChatRole.user,
      providerReplayContent:
          updatedMessages[messageIndex].role == ChatRole.assistant
              ? trimmed
              : null,
      clearProviderReplayContent:
          updatedMessages[messageIndex].role == ChatRole.user,
      providerReplayExact: false,
    );

    final invalidated = await _invalidateSummariesForMessageIds(
      characterId: character.id,
      history: history.copyWith(
        messages: updatedMessages,
        clearPromptCacheEpoch: true,
      ),
      changedMessageIds: <String>{messageId},
    );

    _historyCache[character.id] = invalidated.history;
    _memoryCache[character.id] = invalidated.memory;
    await _store.saveDialogueHistory(invalidated.history);
    await _store.saveCharacterMemory(invalidated.memory);
    if (updatedMessages[messageIndex].role == ChatRole.assistant) {
      final reconciled = await _rebuildTimelineStateFromHistory(
        characterId: character.id,
        history: invalidated.history,
      );
      _historyCache[character.id] = reconciled.history;
      await _store.saveDialogueHistory(reconciled.history);
    }
    notifyListeners();
  }

  Future<void> updateMessageBookmark(
    String messageId, {
    required bool bookmarked,
    String note = '',
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }

    final history = await _ensureHistory(character.id);
    final messageIndex =
        history.messages.indexWhere((message) => message.id == messageId);
    if (messageIndex == -1) {
      return;
    }

    final updatedMessages = List<ChatMessage>.from(history.messages);
    updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
      isBookmarked: bookmarked,
      bookmarkNote: bookmarked ? note.trim() : '',
    );
    final updatedHistory = history.copyWith(messages: updatedMessages);
    _historyCache[character.id] = updatedHistory;
    await _store.saveDialogueHistory(updatedHistory);
    await _updateGamification(
      (state) => state
          .incrementStat(
              bookmarked ? 'totalMessageBookmarks' : 'totalMessageUnbookmarks')
          .setStatMax(
            'maxCurrentBookmarks',
            updatedMessages.where((message) => message.isBookmarked).length,
          ),
      notify: false,
    );
    notifyListeners();
  }

  Future<void> deleteMessage(String messageId) async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }

    final history = await _ensureHistory(character.id);
    final exists = history.messages.any((message) => message.id == messageId);
    if (!exists) {
      return;
    }

    await _createSafetySnapshotForCharacter(
      character.id,
      reason: '删除消息前自动保护',
    );

    final updatedHistory = history.copyWith(
      messages: history.messages
          .where((message) => message.id != messageId)
          .toList(growable: false),
      clearPromptCacheEpoch: true,
    );

    final invalidated = await _invalidateSummariesForMessageIds(
      characterId: character.id,
      history: updatedHistory,
      changedMessageIds: <String>{messageId},
    );

    _historyCache[character.id] = invalidated.history;
    _memoryCache[character.id] = invalidated.memory;
    await _store.saveDialogueHistory(invalidated.history);
    await _store.saveCharacterMemory(invalidated.memory);
    final reconciled = await _rebuildTimelineStateFromHistory(
      characterId: character.id,
      history: invalidated.history,
    );
    _historyCache[character.id] = reconciled.history;
    await _store.saveDialogueHistory(reconciled.history);
    notifyListeners();
  }

  Future<void> deleteMessages(Iterable<String> messageIds) async {
    final character = currentCharacter;
    if (character == null) {
      return;
    }

    final ids =
        messageIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return;
    }

    final history = await _ensureHistory(character.id);
    final remainingMessages = history.messages
        .where((message) => !ids.contains(message.id))
        .toList(growable: false);

    if (remainingMessages.length == history.messages.length) {
      return;
    }

    await _createSafetySnapshotForCharacter(
      character.id,
      reason: '批量删除消息前自动保护',
    );

    final updatedHistory = history.copyWith(
      messages: remainingMessages,
      clearPromptCacheEpoch: true,
    );
    final invalidated = await _invalidateSummariesForMessageIds(
      characterId: character.id,
      history: updatedHistory,
      changedMessageIds: ids,
    );

    _historyCache[character.id] = invalidated.history;
    _memoryCache[character.id] = invalidated.memory;
    await _store.saveDialogueHistory(invalidated.history);
    await _store.saveCharacterMemory(invalidated.memory);
    final reconciled = await _rebuildTimelineStateFromHistory(
      characterId: character.id,
      history: invalidated.history,
    );
    _historyCache[character.id] = reconciled.history;
    await _store.saveDialogueHistory(reconciled.history);
    notifyListeners();
  }

  Future<String?> _transformAssistantMessage({
    required String messageId,
    required String title,
    required bool replaceOriginal,
    required String instruction,
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending) {
      return '当前还有回复正在生成，请稍等。';
    }

    final history = await _ensureHistory(character.id);
    final targetIndex =
        history.messages.indexWhere((message) => message.id == messageId);
    if (targetIndex == -1) {
      return '没有找到要处理的回复。';
    }
    final target = history.messages[targetIndex];
    if (target.role != ChatRole.assistant) {
      return '只能处理 AI 回复。';
    }

    _isSending = true;
    ChatMessage workingMessage;
    DialogueHistory workingHistory;
    if (replaceOriginal) {
      workingMessage = target.copyWith(
        content: '正在$title...',
        isSummarized: false,
      );
      final messages = List<ChatMessage>.from(history.messages);
      messages[targetIndex] = workingMessage;
      workingHistory = history.copyWith(
        messages: messages,
        clearPromptCacheEpoch: true,
      );
    } else {
      workingMessage = ChatMessage(
        id: IdGenerator.message(),
        role: ChatRole.assistant,
        content: '正在$title...',
        timestamp: DateTime.now(),
        isSummarized: false,
      );
      workingHistory = history.copyWith(
        messages: <ChatMessage>[...history.messages, workingMessage],
        clearPromptCacheEpoch: true,
      );
    }

    _historyCache[character.id] = workingHistory;
    _startStreamingSession(workingMessage.id);
    notifyListeners();

    var committed = false;
    try {
      final result = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _utilitySystemPrompt,
        userPrompt: '''
任务：$title

$instruction

当前 AI 角色：${character.name}
角色可见简介：
${character.visibleBlurb}

目标回复：
${target.content}
''',
        temperature: 0.42,
        topP: 0.9,
      );

      final formatted =
          MessageContentParser.normalizeChoiceBlocks(result).trim();
      final normalizedResult = replaceOriginal
          ? ReplyProtocolReconciler.mergeStateBlocks(
              primary: formatted,
              fallback: target.content,
              gameplayPatchRequired:
                  _gameplaySystemAtMessage(target, character.gameplaySystem) !=
                          null ||
                      GameplayPatchParser.parseResult(target.content).found,
            )
          : GameStateParser.stripStateBlocks(formatted).trim();
      if (normalizedResult.isEmpty) {
        throw const LlmApiException('没有生成可显示的格式修复结果。');
      }
      var finalHistory = _replaceMessageContent(
        _historyCache[character.id]!,
        workingMessage.id,
        normalizedResult,
        gameStateSnapshot: replaceOriginal ? target.gameStateSnapshot : null,
        tokenCount: _countCompletedTextTokens(normalizedResult),
        promptReplayContent:
            _apiClient.buildAssistantPromptReplayContent(normalizedResult),
        providerReplayContent: normalizedResult,
        providerReplayExact: false,
      );
      _TimelineReplayResult? repairedTimeline;
      CharacterMemory? repairedMemory;
      if (replaceOriginal) {
        final invalidated = await _invalidateSummariesForMessageIds(
          characterId: character.id,
          history: finalHistory,
          changedMessageIds: {target.id},
        );
        repairedMemory = invalidated.memory;
        repairedTimeline =
            _replayGameStateFromHistory(character.id, invalidated.history);
        finalHistory = repairedTimeline.history;
      }
      await _store.commitTurnState(
        history: finalHistory,
        gameState: repairedTimeline?.gameState,
        memory: repairedMemory,
      );
      committed = true;
      _historyCache[character.id] = finalHistory;
      if (repairedMemory != null) _memoryCache[character.id] = repairedMemory;
      if (repairedTimeline != null) {
        _gameStateCache[character.id] = repairedTimeline.gameState;
        await _rebuildTimelineAutoNpcs(
          characterId: character.id,
          states: repairedTimeline.states,
        );
      }
      return null;
    } on LlmApiException catch (error) {
      if (committed) return '$title 已保存，但后续资料更新失败：${error.message}';
      _historyCache[character.id] = history;
      return error.message;
    } catch (error) {
      if (committed) return '$title 已保存，但后续资料更新失败：$error';
      _historyCache[character.id] = history;
      return '$title 失败：$error';
    } finally {
      _isSending = false;
      _stopStreamingSession();
      notifyListeners();
    }
  }

  String? theaterTitle(String toolId) {
    return _utilitySpec(toolId)?.title;
  }

  Future<void> generateTheaterStream({
    required String toolId,
    required void Function(String chunk) onChunk,
    String userRequest = '',
  }) async {
    final character = currentCharacter;
    if (character == null) {
      throw const LlmApiException('请先选择一个 AI 角色。');
    }
    if (!_settings.canChat) {
      throw const LlmApiException('请先在设置页填好 API 地址、密钥和模型名称。');
    }

    final spec = _utilitySpec(toolId);
    if (spec == null) {
      throw const LlmApiException('没有找到这个小剧场道具。');
    }

    final history = await _ensureHistory(character.id);
    final memory = await _ensureMemory(character.id);
    final gameState = await _ensureGameState(character.id);

    final userPrompt = _buildUtilityPrompt(
      spec: spec,
      character: character,
      history: history,
      memory: memory,
      gameState: gameState,
      userRequest: userRequest,
    );

    _isSending = true;
    notifyListeners();
    final buffer = StringBuffer();
    try {
      await for (final chunk in _apiClient.streamContent(
        settings: _settings,
        systemPrompt: _utilitySystemPrompt,
        userPrompt: userPrompt,
        temperature: spec.temperature,
        topP: 0.9,
        maxTokens: 4096,
      )) {
        buffer.write(chunk);
        onChunk(chunk);
      }

      final content = buffer.toString().trim();
      if (content.isNotEmpty) {
        final toolResult = ToolResult(
          id: IdGenerator.generic('tool'),
          characterId: character.id,
          toolId: toolId,
          toolTitle: spec.title,
          content: content,
          createdAt: DateTime.now(),
        );
        _toolResults.insert(0, toolResult);
        _lastToolResultId = toolResult.id;
        await _store.saveToolResults(_toolResults);
        await _updateGamification(
          (state) => state.incrementStat('totalToolResults'),
          notify: false,
        );
      }
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  _ConversationUtilitySpec? _utilitySpec(String toolId) {
    return switch (toolId) {
      'recap' => const _ConversationUtilitySpec(
          title: '上集提要',
          temperature: 0.35,
          instruction:
              '根据最近聊天记录生成一段“上集提要”。要像电视剧前情回顾，简洁但有氛围，列出当前时间线、主角状态、最近关键事件和接下来最值得关注的问题。',
        ),
      'relationship' => const _ConversationUtilitySpec(
          title: '人物关系图',
          temperature: 0.45,
          instruction:
              '从聊天记录中提取人物、身份、关系、好感变化和潜在线索，生成一个完整 ```html 代码块```。HTML 要手机优先，包含可展开人物卡、关系线说明和当前关系总结。',
        ),
      'cover' => const _ConversationUtilitySpec(
          title: '剧情存档封面',
          temperature: 0.48,
          instruction:
              '为当前剧情生成一个完整 ```html 代码块``` 作为存档封面，包含标题、当前章节、主角状态、最近大事件、当前目标和继续游玩的提示。',
        ),
      'foreshadow' => const _ConversationUtilitySpec(
          title: '伏笔本',
          temperature: 0.38,
          instruction:
              '根据聊天记录整理一个“伏笔本”。不要剧透未来，只记录已经出现但值得留意的细节、人物态度、未解决问题和可能的后续方向。可以用 Markdown，也可以用 HTML 面板。',
        ),
      'branch_preview' => const _ConversationUtilitySpec(
          title: '分支预演',
          temperature: 0.4,
          instruction:
              '分析最近一次 AI 回复底部的选项，预演每个选项可能带来的短期后果。不要推进正式剧情，不要替用户做选择，只帮用户理解风险、收益和风格差异。',
        ),
      'npc_diary' => const _ConversationUtilitySpec(
          title: 'NPC 日记',
          temperature: 0.64,
          instruction:
              '根据当前剧情、NPC 档案和私聊印象，选择 1-3 个最相关 NPC，生成他们不会直接告诉用户的日记、备忘或内心独白。内容独立保存为工具记录，不推进主线，不生成 [CHOICES]，可用 Markdown 或 HTML 美化。',
        ),
      'world_feed' ||
      'forum_burst' ||
      'rumor_board' =>
        const _ConversationUtilitySpec(
          title: '世界动态',
          temperature: 0.72,
          instruction:
              '根据当前剧情生成世界观内的信息流，可使用朋友圈、论坛热帖、公告栏或小道消息等版式。包含多条不同来源的动态、评论和合理误读，不能把未经证实的传闻写成事实。内容独立保存，不推进主线，不生成 [CHOICES]，优先用完整 HTML 做成可滚动信息流。',
        ),
      'inspiration_dice' => const _ConversationUtilitySpec(
          title: '灵感骰子',
          temperature: 0.72,
          instruction:
              '根据当前剧情和用户角色状态，生成 6 个下一步行动灵感。A-C 要稳妥推进剧情，D-F 要逐步更出人意料但仍符合世界观。不要推进正式剧情，只给行动建议。',
        ),
      'dream_fragment' => const _ConversationUtilitySpec(
          title: '梦境碎片',
          temperature: 0.78,
          instruction:
              '根据当前剧情生成一段梦境、番外、回忆或心理片段小剧场。要有氛围和人物情绪，正文不少于 2000 字。不要生成互动按钮，不要输出 [CHOICES]，不要反复向用户强调“不推进主线”。',
        ),
      'comedy_stage' => const _ConversationUtilitySpec(
          title: '吐槽小剧场',
          temperature: 0.78,
          instruction:
              '根据当前剧情生成一段吐槽小剧场。可以让旁白、路人、NPC 或系统面板吐槽当前局面，语气要轻松有梗，正文不少于 2000 字。不要生成互动按钮，不要输出 [CHOICES]，不要反复向用户强调“不推进主线”。',
        ),
      'npc_gossip' => const _ConversationUtilitySpec(
          title: 'NPC 八卦小报',
          temperature: 0.76,
          instruction:
              '根据当前剧情和 NPC 关系生成一份八卦小报小剧场。内容可以是传闻、误会、微妙关系观察和吃瓜评论，正文不少于 2000 字，但不能强行确认未发生事实。优先输出完整 ```html 代码块```，不要生成互动按钮，不要输出 [CHOICES]。',
        ),
      'passerby_camera' => const _ConversationUtilitySpec(
          title: '路人视角镜头',
          temperature: 0.7,
          instruction:
              '选一个符合当前世界观的路人视角，写 TA 看到主角或当前事件的小剧场，正文不少于 2000 字。不替主角做决定，只补充旁观感和氛围。不要生成互动按钮，不要输出 [CHOICES]。',
        ),
      'mood_radio' => const _ConversationUtilitySpec(
          title: '今日电台',
          temperature: 0.74,
          instruction:
              '把当前剧情氛围整理成一段“今日电台”小剧场。包含天气、情绪、人物状态和假装正经的播音腔吐槽，正文不少于 2000 字。可以用 Markdown 或 HTML。不要生成互动按钮，不要输出 [CHOICES]。',
        ),
      'prophecy_trash' => const _ConversationUtilitySpec(
          title: '离谱预言垃圾桶',
          temperature: 0.86,
          instruction:
              '生成一段很会胡说但有趣的“离谱预言”小剧场。它可以给玩家提供脑洞和笑点，正文不少于 2000 字，但必须保持不可靠、半开玩笑的气质。不要生成互动按钮，不要输出 [CHOICES]。',
        ),
      // ── 小剧场道具 ──
      'child_spray' => const _ConversationUtilitySpec(
          title: '变小孩喷雾',
          temperature: 0.68,
          instruction:
              '根据用户描述，把指定 NPC 变成小孩，生成一段不低于 2000 字的纯文字剧情小剧场。要包含 NPC 变成小孩后的外貌、行为、对话和心理变化，带温馨或搞笑氛围。不要生成 HTML，不要生成互动按钮，不要输出 [CHOICES]，不要反复向用户强调“不推进主线”。',
        ),
      'beast_ear_potion' => const _ConversationUtilitySpec(
          title: '兽耳魔药',
          temperature: 0.7,
          instruction:
              '根据用户描述，让指定 NPC 长出兽耳，生成一段不低于 2000 字的纯文字剧情小剧场。要包含 NPC 长出兽耳后的反应、对话、互动场景。如果用户指定了耳朵类型就用指定的，否则由 AI 自由发挥适合该 NPC 的动物耳朵。不要生成 HTML，不要生成互动按钮，不要输出 [CHOICES]，不要反复向用户强调“不推进主线”。',
        ),
      'touch' => const _ConversationUtilitySpec(
          title: '摸一摸',
          temperature: 0.62,
          instruction:
              '根据用户指定的 NPC、触碰部位和可选的一句话，生成一段不低于 2000 字的温情感性纯文字小剧场。要细腻描写触碰的场景、NPC 的反应和双方的互动，氛围要柔软自然。不要生成 HTML，不要生成互动按钮，不要输出 [CHOICES]，不要反复向用户强调“不推进主线”。',
        ),
      'truth_lollipop' => const _ConversationUtilitySpec(
          title: '真心话棒棒糖',
          temperature: 0.65,
          instruction:
              '让指定 NPC 对用户角色说一段真心话。生成一段不低于 2000 字的纯文字小剧场，包含 NPC 说真心话时的场景、表情、语气和心理活动，以及用户角色的反应。内容要真诚有温度。不要生成 HTML，不要生成互动按钮，不要输出 [CHOICES]，不要反复向用户强调“不推进主线”。',
        ),
      _ => null,
    };
  }

  String _buildUtilityPrompt({
    required _ConversationUtilitySpec spec,
    required CharacterProfile character,
    required DialogueHistory history,
    required CharacterMemory memory,
    GameStateSnapshot? gameState,
    List<NpcProfile> npcProfiles = const <NpcProfile>[],
    String userRequest = '',
  }) {
    final recentMessages = history.messages.length > 24
        ? history.messages.sublist(history.messages.length - 24)
        : history.messages;
    final transcript = _formatTranscript(recentMessages);
    final memories = memory.summaries.reversed
        .take(_settings.memoryContextItems <= 0
            ? memory.summaries.length
            : _settings.memoryContextItems)
        .map((summary) => '- ${summary.summaryText}')
        .join('\n');
    final worldBooks = _formatWorldBooksForPrompt(character.id);
    final npcFacts = npcProfiles
        .map(
          (npc) =>
              '- ${npc.name}（ID：${npc.id}）｜好感 ${npc.affinity}｜生命周期 ${npc.lifecycle.label}｜羁绊 ${npc.bondRoute.stage} · ${npc.bondRoute.route}｜印象：${npc.impression.trim().isEmpty ? '暂无' : npc.impression.trim()}',
        )
        .join('\n');

    return '''
任务：${spec.title}

${spec.instruction}

当前 AI 角色：${character.name}
角色简介：
${character.visibleBlurb}

当前游戏面板：
${gameState == null || gameState.isEmpty ? '暂无。' : _formatGameStateForPrompt(gameState)}

当前 NPC 档案（好感与生命周期以这里为准）：
${npcFacts.trim().isEmpty ? '暂无。' : npcFacts}

世界书：
$worldBooks

用户本次补充要求：
${userRequest.trim().isEmpty ? '无。' : userRequest.trim()}

长期记忆：
${memories.trim().isEmpty ? '暂无。' : memories}

最近聊天记录：
$transcript
''';
  }

  String _buildFanficPrompt({
    required CharacterProfile character,
    required DialogueHistory history,
    required CharacterMemory memory,
    required GameStateSnapshot gameState,
    required UserProfile? userProfile,
    required NpcProfile firstNpc,
    required NpcProfile? secondNpc,
    required String inspiration,
    required bool blindBox,
  }) {
    final recentMessages = history.messages.length > 24
        ? history.messages.sublist(history.messages.length - 24)
        : history.messages;
    final memories = memory.summaries.reversed
        .take(_settings.memoryContextItems <= 0
            ? memory.summaries.length
            : _settings.memoryContextItems)
        .map((summary) => '- ${summary.summaryText}')
        .join('\n');
    final worldBooks = _formatWorldBooksForPrompt(character.id);
    final pairing = secondNpc == null
        ? '用户角色「${userProfile?.name ?? '用户'}」 × NPC「${firstNpc.name}」'
        : 'NPC「${firstNpc.name}」 × NPC「${secondNpc.name}」';

    String formatNpc(NpcProfile npc) {
      return '''
NPC：${npc.name}
简介：${npc.description.trim().isEmpty ? '暂无。' : npc.description.trim()}
当前印象：${npc.impression.trim().isEmpty ? '暂无。' : npc.impression.trim()}
好感度：${npc.affinity}
''';
    }

    final inspirationText = inspiration.trim();

    return '''
任务：生成独立同人文

费用状态：用户已支付 10 啥币。
灵感来源：${blindBox ? '开盲盒随机灵感（应用本地已抽定）' : '用户自填灵感'}
本篇核心灵感（最高优先级）：$inspirationText
配对/主角：$pairing

优先级规则：
1. “本篇核心灵感”是本篇同人文的核心设定、题材和走向，优先级最高，必须严格遵循。
2. 下方主线资料只能作为人物关系、性格、称呼、相处张力和既有印象参考。
3. 如果本篇核心灵感与主线世界观、地点、任务、门派、体系或时间线冲突，必须服从本篇核心灵感。
4. 禁止默认续写当前主线，禁止默认沿用当前地点、任务、世界观规则或正在发生的事件，除非本篇核心灵感明确要求。
5. 这是独立番外，不写入主线剧情，不更新游戏面板，不替用户推进正式回合。

当前 AI 角色/模拟器：${character.name}
角色简介：
${character.visibleBlurb}

${userProfile == null ? '' : '''
用户角色：
姓名：${userProfile.name}
性别：${userProfile.gender.trim().isEmpty ? '未填写' : userProfile.gender.trim()}
简介：${userProfile.description.trim().isEmpty ? '暂无。' : userProfile.description.trim()}
人设：
${userProfile.persona.trim().isEmpty ? '暂无。' : userProfile.persona.trim()}
'''}

参与 NPC：
${formatNpc(firstNpc)}
${secondNpc == null ? '' : formatNpc(secondNpc)}

主线关系参考（当前游戏面板，仅用于关系和状态参考）：
${gameState.isEmpty ? '暂无。' : _formatGameStateForPrompt(gameState)}

原模拟器资料参考（世界书，仅用于称呼、设定口吻和关系背景参考）：
${worldBooks.trim().isEmpty ? '暂无。' : worldBooks}

角色性格参考（长期记忆，仅用于人物性格和相处张力参考）：
${memories.trim().isEmpty ? '暂无。' : memories}

最近互动节选（只参考互动语气，不能接着主线写）：
${_formatTranscript(recentMessages)}

写作要求：
1. 生成一篇完整同人文，正文至少 3000 字，并在开头给出一个同人文标题，格式为“标题：XXX”。
2. 只输出标题、正文，不要生成 HTML，不要生成互动按钮，不要输出 [CHOICES]、[GAME_STATE] 或 JSON。
3. 必须围绕“本篇核心灵感”展开，把它当作本篇故事的题材、设定入口和核心冲突来源。
4. 主线剧情、当前游戏面板、世界书、长期记忆、最近聊天记录只能降低权重作为参考资料，不能覆盖本篇核心灵感。
5. 如果用户灵感很短或来自盲盒，就围绕它扩写成完整故事，不要另选题材。
''';
  }

  String _fanficTitle(
    String pairingLabel,
    String inspiration, {
    bool blindBox = false,
  }) {
    final cleanInspiration = inspiration.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (blindBox && cleanInspiration.isEmpty) {
      return '$pairingLabel · 盲盒番外';
    }
    final shortInspiration = cleanInspiration.length > 18
        ? '${cleanInspiration.substring(0, 18)}...'
        : cleanInspiration;
    return '$pairingLabel · $shortInspiration';
  }

  String _buildFanficContinuationPrompt(String partial) {
    return '''
上一轮生成的同人文可能不完整（缺少标题或正文过短）。
请直接从断点继续补全正文，格式要求与之前一致：开头给出标题（标题：XXX），只输出标题和正文，不要重复已有内容，不要解释。

【已有内容】
$partial
''';
  }

  String _extractFanficGeneratedTitle(String content) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6);
    for (final line in lines) {
      final match = RegExp(r'^(?:标题|《?题名》?)\s*[：:]\s*(.+)$').firstMatch(line);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value.replaceAll(RegExp(r'^《|》$'), '').trim();
      }
      if (line.startsWith('《') && line.endsWith('》') && line.length <= 32) {
        return line.substring(1, line.length - 1).trim();
      }
    }
    return '';
  }

  String _formatGameStateForPrompt(GameStateSnapshot state) {
    final parts = <String>[
      if (state.timeLabel.trim().isNotEmpty) '时间：${state.timeLabel.trim()}',
      if (state.location.trim().isNotEmpty) '地点：${state.location.trim()}',
      if (state.status.trim().isNotEmpty) '状态：${state.status.trim()}',
      if (state.mainTask.trim().isNotEmpty) '当前任务：${state.mainTask.trim()}',
      if (state.profileDetails.isNotEmpty)
        '人物数据：${state.profileDetails.join('；')}',
      if (state.inventory.isNotEmpty) '背包：${state.inventory.join('；')}',
      if (state.storyInventory.isNotEmpty)
        '剧情物品栏：${state.storyInventory.map((item) {
          final detail = <String>[
            item.name,
            if (item.description.trim().isNotEmpty) item.description.trim(),
            if (item.effect.trim().isNotEmpty) '用途：${item.effect.trim()}',
          ].join('｜');
          return detail;
        }).join('；')}',
      if (state.relationshipNotes.isNotEmpty)
        '关系网：${state.relationshipNotes.join('；')}',
      if (state.npcChanges.isNotEmpty) 'NPC变化：${state.npcChanges.join('；')}',
    ];
    return parts.isEmpty ? '暂无。' : parts.join('\n');
  }

  Future<void> _addStoryInventoryItem(
    String characterId,
    StoryInventoryItem item,
  ) async {
    final normalized = item.normalized();
    if (normalized.name.trim().isEmpty) {
      return;
    }
    final state = await _ensureGameState(characterId);
    final items = <StoryInventoryItem>[...state.storyInventory];
    final index = items.indexWhere((entry) =>
        entry.id == normalized.id ||
        entry.name.trim().toLowerCase() ==
            normalized.name.trim().toLowerCase());
    if (index == -1) {
      items.add(normalized);
    } else {
      final current = items[index];
      items[index] = current.copyWith(
        description: normalized.description.trim().isEmpty
            ? current.description
            : normalized.description,
        effect: normalized.effect.trim().isEmpty
            ? current.effect
            : normalized.effect,
        source: normalized.source.trim().isEmpty
            ? current.source
            : normalized.source,
        identified: normalized.identified,
        mysteryHint: normalized.mysteryHint.trim().isEmpty
            ? current.mysteryHint
            : normalized.mysteryHint,
      );
    }
    final names = <String>[
      ...state.inventory,
      normalized.name,
    ]
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final nextState = state.copyWith(
      updatedAt: DateTime.now(),
      inventory: names,
      storyInventory: items,
    );
    _gameStateCache[characterId] = nextState;
    await _store.saveGameState(nextState);
  }

  Future<void> _replaceStoryInventoryItem(
    String characterId,
    StoryInventoryItem item,
  ) async {
    final normalized = item.normalized();
    final state = await _ensureGameState(characterId);
    final items = <StoryInventoryItem>[...state.storyInventory];
    final index = items.indexWhere(
      (entry) =>
          entry.id == normalized.id ||
          entry.name.trim().toLowerCase() ==
              normalized.name.trim().toLowerCase(),
    );
    if (index == -1) {
      items.add(normalized);
    } else {
      items[index] = normalized;
    }
    final nextState = state.copyWith(
      updatedAt: DateTime.now(),
      inventory: items
          .map((entry) => entry.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList(growable: false),
      storyInventory: items,
    );
    _gameStateCache[characterId] = nextState;
    await _store.saveGameState(nextState);
  }

  Future<void> _removeStoryInventoryItems(
    String characterId,
    Set<String> itemIds,
  ) async {
    if (itemIds.isEmpty) {
      return;
    }
    final state = await _ensureGameState(characterId);
    final items = state.storyInventory
        .where((item) => !itemIds.contains(item.id))
        .toList(growable: false);
    final nextState = state.copyWith(
      updatedAt: DateTime.now(),
      inventory: items
          .map((entry) => entry.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList(growable: false),
      storyInventory: items,
    );
    _gameStateCache[characterId] = nextState;
    await _store.saveGameState(nextState);
  }

  Future<void> _maybeGrantNpcReturnGift(
    String characterId,
    StoryInventoryItem usedItem,
  ) async {
    final npcs = _npcProfiles
        .where((profile) => profile.characterId == characterId)
        .toList(growable: false);
    if (npcs.isEmpty) {
      return;
    }
    final seed = DateTime.now().microsecondsSinceEpoch ^
        _stableSeed(
            '${usedItem.id}_${_gamification.stat('totalStoryItemsUsed')}');
    final rng = Random(seed);
    if (rng.nextInt(100) >= 24) {
      return;
    }
    final npc = npcs[rng.nextInt(npcs.length)];
    final gifts = <String>[
      '${npc.name}塞来的折角便签',
      '${npc.name}悄悄递来的小糖',
      '${npc.name}保存很久的旧票根',
      '${npc.name}说“先别问”的小物件',
    ];
    final giftName = gifts[rng.nextInt(gifts.length)];
    await _addStoryInventoryItem(
      characterId,
      StoryInventoryItem.fromName(
        giftName,
        description: 'NPC 回礼：${npc.name}因为「${usedItem.name}」的影响送来的东西。',
        effect: '投入主线后围绕 ${npc.name} 触发一段回应、印象变化或小线索。',
        source: 'npc_return_gift',
      ),
    );
    await _updateGamification(
      (state) => state.incrementStat('totalNpcGiftsReceived'),
      notify: false,
    );
  }

  Future<void> _collectSceneCard({
    required String characterId,
    required String sourceItemName,
    required String assistantMessageId,
  }) async {
    final history = await _ensureHistory(characterId);
    ChatMessage? message;
    for (final entry in history.messages) {
      if (entry.id == assistantMessageId) {
        message = entry;
        break;
      }
    }
    final content = message?.content.trim() ?? '';
    if (content.isEmpty) {
      return;
    }
    final toolResult = ToolResult(
      id: IdGenerator.generic('scene'),
      characterId: characterId,
      toolId: 'scene_card',
      toolTitle: '名场面收藏',
      content: '来源道具：$sourceItemName\n\n$content',
      createdAt: DateTime.now(),
    );
    _toolResults.insert(0, toolResult);
    _lastToolResultId = toolResult.id;
    await _store.saveToolResults(_toolResults);
    await _updateGamification(
      (state) => state.incrementStat('totalSceneCardsCollected'),
      notify: false,
    );
  }

  StoryInventoryItem? _findStoryInventoryItem(
    GameStateSnapshot state,
    String itemId,
  ) {
    final target = itemId.trim();
    if (target.isEmpty) {
      return null;
    }
    for (final item in state.storyInventory) {
      if (item.id == target || item.name.trim() == target) {
        return item;
      }
    }
    for (final name in state.inventory) {
      if (name.trim() == target) {
        return StoryInventoryItem.fromName(name, source: 'legacy_inventory');
      }
    }
    return null;
  }

  String _buildMysteryShopPrompt({
    required CharacterProfile character,
    required DialogueHistory history,
    required GameStateSnapshot gameState,
    required CharacterMemory memory,
  }) {
    final recentMessages = history.messages.length > 12
        ? history.messages.sublist(history.messages.length - 12)
        : history.messages;
    final memories = memory.summaries.reversed
        .take(6)
        .map((summary) => '- ${summary.summaryText}')
        .join('\n');
    return '''
当前模拟器：${character.name}
角色简介：
${character.visibleBlurb}

当前游戏面板：
${gameState.isEmpty ? '暂无。' : _formatGameStateForPrompt(gameState)}

长期记忆：
${memories.trim().isEmpty ? '暂无。' : memories}

最近主线记录：
${_formatTranscript(recentMessages)}

请为当前世界生成 5 件“神秘小卖部”剧情商品。
要求：
1. 每件商品必须属于当前文游世界，能在主线中使用并产生剧情影响。
2. 单价 1-20 啥币，价格要有差异，不要全部同价。
3. 商品可以影响 NPC 好感度、剧情线索、资源、地点事件、主角状态或后续选项，但不要直接替用户赢下主线。
4. 不要生成小剧场券、功能券、装扮或纯装饰品；这里卖的是会进入“剧情物品栏”的世界内物品。

只输出 JSON，不要 Markdown，不要解释：
{
  "items": [
    {"name":"商品名","description":"商品说明","effect":"使用后可能造成的剧情影响","cost":12}
  ]
}
''';
  }

  String _buildBlackMarketPrompt({
    required CharacterProfile character,
    required DialogueHistory history,
    required GameStateSnapshot gameState,
    required CharacterMemory memory,
  }) {
    final recentMessages = history.messages.length > 16
        ? history.messages.sublist(history.messages.length - 16)
        : history.messages;
    final memories = memory.summaries.reversed
        .take(8)
        .map((summary) => '- ${summary.summaryText}')
        .join('\n');
    return '''
当前模拟器：${character.name}
角色简介：
${character.visibleBlurb}

当前游戏面板：
${gameState.isEmpty ? '暂无。' : _formatGameStateForPrompt(gameState)}

长期记忆：
${memories.trim().isEmpty ? '暂无。' : memories}

最近主线记录：
${_formatTranscript(recentMessages)}

请为当前世界生成 5 件“黑心小卖部”怪货。
要求：
1. 这些商品必须明显区别于“神秘小卖部”的普通好货，要更稀有、更古怪、更昂贵，也更像老板从剧情缝隙里摸出来的压箱底东西。
2. 单价必须在 50-500 啥币之间，最便宜不得低于 50，最贵可以接近 500，价格要有梯度。
3. 商品必须能进入剧情物品栏，未来可被用户主动使用，并对主线、NPC 好感度、NPC 印象、资源、地点事件、主角状态或后续选择产生影响。
4. 可以有风险、代价、未知副作用或条件限制，但不要直接替用户赢下主线，也不要生成纯 UI 装饰、称号、气泡边框、功能券、小剧场券。
5. 至少 2 件商品可以是“效果未知”的怪货：effect 留空，description 写清楚可疑感和线索感，方便后续鉴定。

只输出 JSON，不要 Markdown，不要解释：
{
  "items": [
    {"name":"怪货名","description":"怪货说明","effect":"使用后可能造成的剧情影响或留空","cost":88}
  ]
}
''';
  }

  List<StoryShopOffer> _parseStoryShopOffers(
    String raw, {
    int minCost = 1,
    int maxCost = 20,
    bool useFallback = true,
  }) {
    final cleaned = _stripJsonFence(raw.trim());
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

    final rawItems = decoded is Map
        ? (decoded['items'] ?? decoded['goods'] ?? decoded['offers'])
        : decoded is List
            ? decoded
            : null;
    if (rawItems is List) {
      final offers = rawItems
          .whereType<Map>()
          .map((item) => _clampStoryShopOfferCost(
                StoryShopOffer.fromJson(Map<String, dynamic>.from(item)),
                minCost: minCost,
                maxCost: maxCost,
              ))
          .where((item) => item.name.trim().isNotEmpty)
          .take(5)
          .toList(growable: false);
      if (offers.isNotEmpty) {
        return offers;
      }
    }
    return useFallback ? _fallbackStoryShopOffers() : const <StoryShopOffer>[];
  }

  StoryShopOffer _clampStoryShopOfferCost(
    StoryShopOffer offer, {
    required int minCost,
    required int maxCost,
  }) {
    final normalized = offer.normalized();
    return StoryShopOffer(
      id: normalized.id,
      name: normalized.name,
      description: normalized.description,
      effect: normalized.effect,
      cost: normalized.cost.clamp(minCost, maxCost).toInt(),
    );
  }

  List<StoryShopOffer> _fallbackStoryShopOffers() {
    return const <StoryShopOffer>[
      StoryShopOffer(
        id: 'fallback_weathered_key',
        name: '生锈的小钥匙',
        description: '看起来属于某个被遗忘的抽屉，可能打开一段旧线索。',
        effect: '使用后触发一个与当前地点或 NPC 过去有关的小事件。',
        cost: 8,
      ),
      StoryShopOffer(
        id: 'fallback_unsent_letter',
        name: '没寄出的信',
        description: '信封没有署名，纸角被揉过很多次。',
        effect: '使用后让一个 NPC 的印象产生变化，并暴露一条关系线索。',
        cost: 11,
      ),
      StoryShopOffer(
        id: 'fallback_lucky_coin',
        name: '偏心硬币',
        description: '抛起来总像是会落向你想要的一面。',
        effect: '使用后让下一次选择获得一点意外助力，但可能引出小麻烦。',
        cost: 13,
      ),
      StoryShopOffer(
        id: 'fallback_blank_ticket',
        name: '空白入场券',
        description: '票面没有地点，只有一行快褪色的小字。',
        effect: '使用后解锁一个临时地点、聚会或私下会面机会。',
        cost: 15,
      ),
      StoryShopOffer(
        id: 'fallback_warm_candy',
        name: '还带体温的糖',
        description: '像是刚从谁的口袋里拿出来，糖纸皱得很认真。',
        effect: '使用后可缓和一次紧张对话，略微提升相关 NPC 好感度。',
        cost: 6,
      ),
    ];
  }

  String _formatTranscript(Iterable<ChatMessage> messages) {
    return messages.map((message) {
      final speaker = message.role == ChatRole.user ? '用户' : 'AI';
      return '$speaker：${message.content}';
    }).join('\n\n');
  }

  String _buildNpcExtractionPrompt({
    required CharacterProfile character,
    required DialogueHistory history,
  }) {
    final recentMessages = history.messages.length > 18
        ? history.messages.sublist(history.messages.length - 18)
        : history.messages;
    final existingNpcs = _npcProfiles
        .where((profile) => profile.characterId == character.id)
        .map((profile) {
      final impression = profile.impression.trim();
      final description = profile.description.trim();
      return '- ${profile.name}：${description.isEmpty ? '暂无简介' : description}；好感度：${profile.affinity}；印象：${impression.isEmpty ? '暂无' : impression}';
    }).join('\n');

    return '''
当前模拟器：${character.name}
角色简介：
${character.visibleBlurb}

已有 NPC：
${existingNpcs.trim().isEmpty ? '暂无。' : existingNpcs}

最近主线聊天：
${_formatTranscript(recentMessages)}

请从最近主线聊天中提取已经实际出现、被提及且可能继续参与剧情的 NPC。
不要提取用户本人、AI 叙述者、泛称群体、无姓名路人、纯物品或地点。
如果 NPC 没有明确姓名，可以用剧情里稳定出现的称呼，例如“同桌”“班主任”“便利店店员”，但不要编造一堆无根据角色。
''';
  }

  List<_ExtractedNpcProfile> _parseExtractedNpcProfiles(String raw) {
    final cleaned = _stripJsonFence(raw.trim());
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

    if (decoded is! Map) {
      return const <_ExtractedNpcProfile>[];
    }

    final rawNpcs = decoded['npcs'];
    if (rawNpcs is! List) {
      return const <_ExtractedNpcProfile>[];
    }

    return rawNpcs
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return _ExtractedNpcProfile(
            name: map['name']?.toString().trim() ?? '',
            description: map['description']?.toString().trim() ?? '',
            affinity: _readBoundedAffinity(
                  map['affinity'] ?? map['favorability'] ?? map['好感度'],
                ) ??
                0,
            impression: map['impression']?.toString().trim() ?? '',
          );
        })
        .where((profile) => profile.name.isNotEmpty)
        .take(5)
        .toList(growable: false);
  }

  bool _mergeExtractedNpcProfiles(
    String characterId,
    List<_ExtractedNpcProfile> extracted,
  ) {
    var changed = false;
    final now = DateTime.now();
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    final branchCutoff = _npcVisibilityCutoffForCharacter(characterId);
    final existingNames = <String, int>{};
    for (var index = 0; index < _npcProfiles.length; index++) {
      final profile = _npcProfiles[index];
      if (_isNpcProfileVisibleForCharacter(
        profile,
        characterId,
        rootId,
        branchCutoff: branchCutoff,
      )) {
        existingNames[_normalizeNpcName(profile.name)] = index;
      }
    }

    for (final item in extracted) {
      final normalizedName = _normalizeNpcName(item.name);
      if (normalizedName.isEmpty) {
        continue;
      }

      final existingIndex = existingNames[normalizedName];
      if (existingIndex == null) {
        final impressionHistory = item.impression.isEmpty
            ? const <NpcImpressionEntry>[]
            : <NpcImpressionEntry>[
                NpcImpressionEntry(
                  id: IdGenerator.generic('npc_imp'),
                  summary: item.impression,
                  createdAt: now,
                ),
              ];
        final profile = NpcProfile(
          id: IdGenerator.generic('npc'),
          characterId: characterId,
          name: item.name,
          description: item.description,
          affinity: item.affinity,
          impression: item.impression,
          createdAt: now,
          updatedAt: now,
          sourceType: NpcProfileSource.auto,
          companionEnabled: false,
          boundCharacterIds: <String>[characterId],
          impressionHistory: impressionHistory,
        );
        _npcProfiles.add(profile);
        _npcMessagesCache[profile.id] = const <NpcChatMessage>[];
        existingNames[normalizedName] = _npcProfiles.length - 1;
        changed = true;
        continue;
      }

      final current = _npcProfiles[existingIndex];
      var next = current;
      if (!current.globalBinding &&
          !current.isBoundTo(characterId) &&
          current.characterId != characterId) {
        next = next.copyWith(
          boundCharacterIds: _mergeNpcBoundCharacterIds(
            current.boundCharacterIds,
            <String>[characterId],
          ),
          updatedAt: now,
        );
        changed = true;
      }
      final shouldFillDescription =
          next.description.trim().isEmpty && item.description.isNotEmpty;
      final shouldFillImpression =
          next.impression.trim().isEmpty && item.impression.isNotEmpty;
      final shouldUpdateAffinity = next.affinity == 0 && item.affinity != 0;
      if (!shouldFillDescription &&
          !shouldFillImpression &&
          !shouldUpdateAffinity) {
        continue;
      }

      _npcProfiles[existingIndex] = next.copyWith(
        description: shouldFillDescription ? item.description : null,
        affinity: shouldUpdateAffinity ? item.affinity : null,
        impression: shouldFillImpression ? item.impression : null,
        updatedAt: now,
        impressionHistory: shouldFillImpression
            ? <NpcImpressionEntry>[
                NpcImpressionEntry(
                  id: IdGenerator.generic('npc_imp'),
                  summary: item.impression,
                  createdAt: now,
                ),
                ...next.impressionHistory,
              ].take(30).toList(growable: false)
            : null,
      );
      changed = true;
    }

    return changed;
  }

  String _normalizeNpcName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  String _buildNpcChatPrompt({
    required CharacterProfile character,
    required NpcProfile npc,
    required List<NpcChatMessage> messages,
  }) {
    final userProfile = _findBoundUserProfile(character.id);
    final pendingMessages = _trailingNpcUserMessages(messages);
    final npcTranscript = _formatNpcTranscript(
      messages.length > 36 ? messages.sublist(messages.length - 36) : messages,
      npcName: npc.name,
    );
    final mainMessages = _historyCache[character.id]?.messages ?? const [];
    final mainTranscript = _formatTranscript(
      mainMessages.length > 12
          ? mainMessages.sublist(mainMessages.length - 12)
          : mainMessages,
    );
    final worldBooks = _formatWorldBooksForPrompt(character.id);
    final roleCard = npc.roleCard.trim();

    return '''
当前主模拟器：${character.name}
模拟器可见简介：
${character.visibleBlurb}

世界书：
$worldBooks

当前用户角色：
${userProfile == null ? '用户暂未创建或绑定用户角色，请按普通玩家处理。' : '${userProfile.name}\n${userProfile.persona}\n${userProfile.description}'}

当前 NPC：
姓名：${npc.name}
简介：${npc.description.trim().isEmpty ? '暂无。' : npc.description.trim()}
角色卡：${roleCard.isEmpty ? '暂无完整角色卡，请根据简介、印象和私聊保持一致。' : roleCard}
档案来源：${NpcProfileSource.label(npc.sourceType)}
当前好感度：${npc.affinity}
当前印象：${npc.impression.trim().isEmpty ? '暂无明确印象。' : npc.impression.trim()}
当前羁绊路线：
阶段：${npc.bondRoute.stage}
路线倾向：${npc.bondRoute.route}
羁绊进度：${npc.bondRoute.score}/100
最近羁绊事件：${npc.bondRoute.latestEvent.trim().isEmpty ? '暂无。' : npc.bondRoute.latestEvent.trim()}

最近主线片段，仅用于理解世界状态，不要直接推进主线：
${mainTranscript.trim().isEmpty ? '暂无主线记录。' : mainTranscript}

NPC 私聊历史：
${npcTranscript.trim().isEmpty ? '暂无。' : npcTranscript}

本次用户连续发来的消息：
${pendingMessages.map((message) => '- ${message.content}').join('\n')}

请生成 NPC 对本次消息的手机聊天式回复，并更新 NPC 对用户角色的印象。
印象更新要求：
- impressionPatch.summary 必须直接写简体中文自然句，不要输出 summary:、affinityDelta:、attitude: 这种英文标签。
- 如果要表达好感变化、当前态度、关系变化，请放在 JSON 字段里，不要把英文键名混进 summary。
- 关系判断要参考羁绊路线，不要把所有关系都写成恋爱；可以是恋人、挚友、宿敌、共犯、守护、师徒、破镜或未知。
- impressionPatch.bondStage 必须从“初见/熟悉/信任/牵绊/分岔/深羁绊”中选一个；impressionPatch.bondRoute 必须从“恋人线/挚友线/宿敌线/共犯线/守护线/师徒线/破镜线/未知线”中选一个。
''';
  }

  List<NpcChatMessage> _trailingNpcUserMessages(List<NpcChatMessage> messages) {
    final pending = <NpcChatMessage>[];
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      if (message.role != NpcMessageRole.user) {
        break;
      }
      pending.insert(0, message);
    }
    return pending;
  }

  String _formatNpcTranscript(
    Iterable<NpcChatMessage> messages, {
    required String npcName,
  }) {
    return messages.map((message) {
      final speaker = message.role == NpcMessageRole.user ? '用户角色' : npcName;
      return '$speaker：${message.content}';
    }).join('\n');
  }

  _ParsedNpcReply _parseNpcReply(String raw) {
    final cleaned = _stripJsonFence(raw.trim());
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
      final messagesSource = decoded['messages'] ?? decoded['bubbles'];
      final messages = messagesSource is List
          ? _normalizeNpcBubbleMessages(
              messagesSource.map((item) => item.toString()),
            )
          : _normalizeNpcBubbleMessages(<String>[cleaned]);
      return _ParsedNpcReply(
        messages: messages,
        impression: _extractNpcImpressionText(decoded),
        affinity: _extractNpcAffinityValue(decoded),
        affinityDelta: _extractNpcAffinityDelta(decoded),
        bondStage: _extractNpcBondStage(decoded),
        bondRoute: _extractNpcBondRoute(decoded),
      );
    }

    return _ParsedNpcReply(
      messages: _normalizeNpcBubbleMessages(<String>[cleaned]),
      impression: '',
      affinity: null,
      affinityDelta: null,
      bondStage: null,
      bondRoute: null,
    );
  }

  String _stripJsonFence(String value) {
    var next = value.trim();
    if (next.startsWith('```')) {
      next = next.replaceFirst(RegExp(r'^```[a-zA-Z0-9_-]*\s*'), '');
      next = next.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return next.trim();
  }

  List<String> _normalizeNpcBubbleMessages(Iterable<String> source) {
    final rawItems = source
        .map((item) => item.trim())
        .where(NpcMessageClassifier.isDeliverableChatBubble)
        .toList(growable: true);

    if (rawItems.isEmpty) {
      return const <String>['我看到了。', '等我想一下怎么回你。'];
    }

    if (rawItems.length == 1) {
      rawItems
        ..clear()
        ..addAll(_splitNpcBubbleText(source.first));
    }

    if (rawItems.length > 5) {
      final head = rawItems.take(4).toList(growable: true);
      head.add(rawItems.skip(4).join('\n'));
      return head;
    }

    return rawItems.take(5).toList(growable: false);
  }

  List<String> _splitNpcBubbleText(String value) {
    final normalized = value
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n{2,}|\n|(?<=[。！？!?])'))
        .map((item) => item.trim())
        .where(NpcMessageClassifier.isDeliverableChatBubble)
        .toList(growable: false);
    if (normalized.length >= 2) {
      return normalized.take(5).toList(growable: false);
    }
    return <String>[value.trim()];
  }

  String _extractNpcImpressionText(Map<dynamic, dynamic> decoded) {
    final patch = decoded['impressionPatch'] ?? decoded['impression'];
    if (patch is String) {
      return patch.trim();
    }
    if (patch is Map) {
      final parts = <String>[];
      for (final entry in patch.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          parts.add('$key：${value.map((item) => item.toString()).join('、')}');
        } else if (value != null) {
          parts.add('$key：${value.toString()}');
        }
      }
      return parts.join('\n').trim();
    }
    return '';
  }

  int? _extractNpcAffinityValue(Map<dynamic, dynamic> decoded) {
    final patch = decoded['impressionPatch'];
    final direct = decoded['affinity'] ??
        decoded['currentAffinity'] ??
        decoded['favorability'] ??
        decoded['好感度'];
    if (direct != null) {
      return _readBoundedAffinity(direct);
    }
    if (patch is Map) {
      return _readBoundedAffinity(
        patch['affinity'] ??
            patch['currentAffinity'] ??
            patch['favorability'] ??
            patch['好感度'],
      );
    }
    return null;
  }

  int? _extractNpcAffinityDelta(Map<dynamic, dynamic> decoded) {
    final patch = decoded['impressionPatch'];
    final direct = decoded['affinityDelta'] ??
        decoded['favorabilityDelta'] ??
        decoded['relationshipDelta'] ??
        decoded['好感变化'] ??
        decoded['好感度变化'];
    if (direct != null) {
      return _readBoundedAffinityDelta(direct);
    }
    if (patch is Map) {
      return _readBoundedAffinityDelta(
        patch['affinityDelta'] ??
            patch['favorabilityDelta'] ??
            patch['relationshipDelta'] ??
            patch['好感变化'] ??
            patch['好感度变化'],
      );
    }
    return null;
  }

  String? _extractNpcBondStage(Map<dynamic, dynamic> decoded) {
    final patch = decoded['impressionPatch'];
    final direct = decoded['bondStage'] ??
        decoded['stage'] ??
        decoded['羁绊阶段'] ??
        decoded['关系阶段'];
    if (direct != null) {
      return _normalizeNpcBondStage(direct.toString());
    }
    if (patch is Map) {
      return _normalizeNpcBondStage(
        (patch['bondStage'] ?? patch['stage'] ?? patch['羁绊阶段'] ?? patch['关系阶段'])
            ?.toString(),
      );
    }
    return null;
  }

  String? _extractNpcBondRoute(Map<dynamic, dynamic> decoded) {
    final patch = decoded['impressionPatch'];
    final direct = decoded['bondRoute'] ??
        decoded['route'] ??
        decoded['路线倾向'] ??
        decoded['关系路线'];
    if (direct != null) {
      return _normalizeNpcBondRoute(direct.toString());
    }
    if (patch is Map) {
      return _normalizeNpcBondRoute(
        (patch['bondRoute'] ?? patch['route'] ?? patch['路线倾向'] ?? patch['关系路线'])
            ?.toString(),
      );
    }
    return null;
  }

  String? _normalizeNpcBondStage(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    const stages = <String>['初见', '熟悉', '信任', '牵绊', '分岔', '深羁绊'];
    for (final stage in stages) {
      if (text.contains(stage)) {
        return stage;
      }
    }
    return null;
  }

  String? _normalizeNpcBondRoute(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    const routes = <String>[
      '恋人线',
      '挚友线',
      '宿敌线',
      '共犯线',
      '守护线',
      '师徒线',
      '破镜线',
      '未知线',
    ];
    for (final route in routes) {
      if (text.contains(route.replaceAll('线', '')) || text.contains(route)) {
        return route;
      }
    }
    return null;
  }

  int? _readBoundedAffinity(dynamic value) {
    if (value == null) {
      return null;
    }
    final parsed = value is num
        ? value.round()
        : int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9-]'), ''));
    return parsed?.clamp(-100, 100).toInt();
  }

  int? _readBoundedAffinityDelta(dynamic value) {
    if (value == null) {
      return null;
    }
    final parsed = value is num
        ? value.round()
        : int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9-]'), ''));
    return parsed?.clamp(-30, 30).toInt();
  }

  String _composeManualNpcRoleCard({
    required NpcProfile npc,
    required String sourceCharacterName,
  }) {
    final buffer = StringBuffer()
      ..writeln('姓名：${npc.name.trim().isEmpty ? '未命名 NPC' : npc.name.trim()}')
      ..writeln('来源：$sourceCharacterName')
      ..writeln(
          '身份与简介：${npc.description.trim().isEmpty ? '暂无明确简介，请根据后续剧情自然补全。' : npc.description.trim()}')
      ..writeln(
          '当前印象：${npc.impression.trim().isEmpty ? '暂无明确印象。' : npc.impression.trim()}')
      ..writeln('好感度：${npc.affinity}')
      ..writeln(
          '羁绊：${npc.bondRoute.stage} · ${npc.bondRoute.route} · ${npc.bondRoute.score}/100');
    if (npc.bondRoute.latestEvent.trim().isNotEmpty) {
      buffer.writeln('最近羁绊节点：${npc.bondRoute.latestEvent.trim()}');
    }
    buffer
      ..writeln()
      ..writeln(
          '跨世界行动规则：这个 NPC 作为绑定 NPC 进入其他模拟器时，是玩家身边的另一个重要角色。TA 会根据自己的性格、目标、情绪和关系判断自主行动、提出建议、推动支线、与世界互动，但不能替玩家做决定，不能替玩家说话，不能代替玩家完成关键选择。');
    return buffer.toString().trim();
  }

  String _buildNpcRoleCardPrompt({
    required CharacterProfile character,
    required NpcProfile npc,
    required List<NpcChatMessage> npcMessages,
    required DialogueHistory history,
    required String extraInstruction,
  }) {
    final recentMain = history.messages.length > 18
        ? history.messages.sublist(history.messages.length - 18)
        : history.messages;
    final npcTranscript = _formatNpcTranscript(
      npcMessages.length > 36
          ? npcMessages.sublist(npcMessages.length - 36)
          : npcMessages,
      npcName: npc.name,
    );
    return '''
请把以下 NPC 整理成可复用的 NPC 角色卡。只补全干净人设，不生成新世界，不推进剧情，不写告别。

源模拟器：${character.name}
源模拟器简介：
${character.visibleBlurb}

NPC 基础档案：
姓名：${npc.name}
简介：${npc.description.trim().isEmpty ? '暂无。' : npc.description.trim()}
当前印象：${npc.impression.trim().isEmpty ? '暂无。' : npc.impression.trim()}
好感度：${npc.affinity}
羁绊阶段：${npc.bondRoute.stage}
羁绊路线：${npc.bondRoute.route}
羁绊进度：${npc.bondRoute.score}/100
最近羁绊节点：${npc.bondRoute.latestEvent.trim().isEmpty ? '暂无。' : npc.bondRoute.latestEvent.trim()}

最近主线剧情：
${_formatTranscript(recentMain).trim().isEmpty ? '暂无。' : _formatTranscript(recentMain)}

NPC 私聊：
${npcTranscript.trim().isEmpty ? '暂无。' : npcTranscript}

额外要求：
${extraInstruction.trim().isEmpty ? '无。' : extraInstruction.trim()}

角色卡只保留这些内容：
1. 姓名/称呼。
2. 一句话简介。
3. 外貌气质。
4. 性格底色。
5. 说话风格。
6. 行动倾向。
7. 与玩家互动边界。
8. 跨世界适配规则。
9. 需要保持一致的核心事实。

必须去掉或泛化这些原世界强绑定内容：
原世界世界观、当前剧情事件、学校/朝代/地点等强绑定背景、原世界任务线。
''';
  }

  String _buildNpcRoleCardInspirationPrompt({
    required CharacterProfile character,
    required DialogueHistory history,
    required String inspiration,
  }) {
    final recentMain = history.messages.length > 12
        ? history.messages.sublist(history.messages.length - 12)
        : history.messages;
    final transcript = _formatTranscript(recentMain);
    final worldBooks = _formatWorldBooksForPrompt(character.id);
    return '''
用户正在当前模拟器里创建一个新 NPC。请根据“用户填写的信息”生成一张可保存、可私聊、可后续整理绑定的 NPC 角色卡。

注意：这里的“角色卡”是人物设定，不是新世界观，不是文游模拟器，不要生成开场白、状态面板、行动选项、任务系统或剧情流程。

当前模拟器：${character.name}
当前模拟器简介：
${character.visibleBlurb}

世界书/长期设定：
${worldBooks.trim().isEmpty ? '暂无。' : worldBooks}

最近主线剧情，仅用于判断世界气质，不要强行续写：
${transcript.trim().isEmpty ? '暂无。' : transcript}

用户填写的信息：
$inspiration

请输出 JSON。要求：
1. name 如果用户没有指定，就生成一个自然、好记、适合当前世界的名字。
2. description 是 80 字以内的一句话简介。
3. roleCard 只写人物设定：身份、外貌气质、性格底色、说话风格、行动倾向、与玩家互动边界、稳定事实和跨世界适配规则。
4. impression 写 TA 初见或当前对玩家角色的印象，不要假装已经发生大量剧情。
5. affinity 根据灵感判断，范围 -100 到 100。
6. 如果用户已经写了角色卡，优先尊重原文，把它润色、补齐缺失字段，不要改掉核心人设。
''';
  }

  NpcProfileDraft _parseNpcRoleCardDraft(
    String raw, {
    required NpcProfile npc,
    required CharacterProfile character,
  }) {
    var name = npc.name.trim();
    var description = npc.description.trim();
    var roleCard = '';
    var impression = npc.impression.trim();
    var affinity = npc.affinity;

    try {
      final decoded = _decodeJsonObject(raw);
      name = decoded['name']?.toString().trim().isNotEmpty == true
          ? decoded['name'].toString().trim()
          : name;
      description = decoded['description']?.toString().trim().isNotEmpty == true
          ? decoded['description'].toString().trim()
          : description;
      roleCard = decoded['roleCard']?.toString().trim() ??
          decoded['card']?.toString().trim() ??
          decoded['profile']?.toString().trim() ??
          '';
      impression = decoded['impression']?.toString().trim().isNotEmpty == true
          ? normalizeNpcImpressionText(decoded['impression'].toString())
          : impression;
      affinity = _readBoundedAffinity(decoded['affinity']) ?? affinity;
    } catch (_) {
      roleCard = _stripJsonFence(raw).trim();
    }

    if (roleCard.isEmpty) {
      roleCard = _composeManualNpcRoleCard(
        npc: npc,
        sourceCharacterName: character.name,
      );
    }

    return NpcProfileDraft(
      name: name.isEmpty ? npc.name : name,
      avatarDataUri: npc.avatarDataUri,
      description: description,
      impression: impression,
      affinity: affinity,
      lifecycle: npc.lifecycle,
      sourceType: NpcProfileSource.migrationCard,
      roleCard: roleCard,
      roleCardFinalized: true,
      companionEnabled: false,
      globalBinding: false,
      boundCharacterIds: const <String>[],
    );
  }

  void _touchNpcProfile(NpcProfile profile) {
    final index = _npcProfiles.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      return;
    }
    _npcProfiles[index] = profile.copyWith(updatedAt: DateTime.now());
  }

  void _applyNpcImpressionPatch(
    String npcId,
    NpcImpressionEntry impressionEntry, {
    int? affinity,
    int? affinityDelta,
    String? bondStage,
    String? bondRoute,
  }) {
    final index = _npcProfiles.indexWhere((profile) => profile.id == npcId);
    if (index == -1) {
      return;
    }

    final current = _npcProfiles[index];
    if (!current.canChangeAffinity) {
      return;
    }
    final nextAffinity = affinity ??
        (current.affinity + (affinityDelta ?? 0)).clamp(-100, 100).toInt();
    final cleanSummary = normalizeNpcImpressionText(impressionEntry.summary);
    final cleanEntry = NpcImpressionEntry(
      id: impressionEntry.id,
      summary: cleanSummary,
      createdAt: impressionEntry.createdAt,
    );
    _npcProfiles[index] = current.copyWith(
      impression: cleanSummary,
      affinity: nextAffinity,
      updatedAt: impressionEntry.createdAt,
      bondRoute: _advanceNpcBondRoute(
        current.bondRoute,
        impression: cleanSummary,
        affinity: nextAffinity,
        affinityDelta: affinityDelta ?? (nextAffinity - current.affinity),
        explicitStage: bondStage,
        explicitRoute: bondRoute,
        createdAt: impressionEntry.createdAt,
      ),
      impressionHistory: <NpcImpressionEntry>[
        cleanEntry,
        ...current.impressionHistory,
      ].take(30).toList(growable: false),
    );
  }

  NpcBondRoute _advanceNpcBondRoute(
    NpcBondRoute current, {
    required String impression,
    required int affinity,
    required DateTime createdAt,
    int? affinityDelta,
    String? explicitStage,
    String? explicitRoute,
  }) {
    final cleanImpression = normalizeNpcImpressionText(impression);
    final positiveDelta = (affinityDelta ?? 0).clamp(0, 30).toInt();
    final baseScore = current.score == 0 && affinity > 0
        ? affinity.clamp(0, 100).toInt()
        : current.score;
    final narrativeBonus = cleanImpression.isEmpty ? 0 : 3;
    final nextScore =
        (baseScore + positiveDelta + narrativeBonus).clamp(0, 100).toInt();
    final nextStage = explicitStage?.trim().isNotEmpty == true
        ? explicitStage!.trim()
        : NpcBondRoute.stageForScore(nextScore);
    final inferredRoute = NpcBondRoute.inferRoute(
      cleanImpression,
      fallback: current.route.trim().isEmpty ? '未知线' : current.route,
    );
    final nextRoute = explicitRoute?.trim().isNotEmpty == true
        ? explicitRoute!.trim()
        : inferredRoute;
    final mergedKeywords = <String>{
      ...current.keywords,
      ...NpcBondRoute.inferKeywords(cleanImpression),
    }.take(8).toList(growable: false);
    final eventSummary =
        cleanImpression.trim().isEmpty ? '关系有了细微变化。' : cleanImpression.trim();
    final shouldAddEvent = eventSummary.isNotEmpty &&
        (current.events.isEmpty ||
            current.events.first.summary.trim() != eventSummary);

    return current.copyWith(
      score: nextScore,
      stage: nextStage,
      route: nextRoute,
      latestEvent: eventSummary,
      keywords: mergedKeywords,
      updatedAt: createdAt,
      events: shouldAddEvent
          ? <NpcBondEvent>[
              NpcBondEvent(
                id: IdGenerator.generic('npc_bond'),
                summary: eventSummary,
                stage: nextStage,
                route: nextRoute,
                scoreDelta: positiveDelta + narrativeBonus,
                createdAt: createdAt,
              ),
              ...current.events,
            ].take(20).toList(growable: false)
          : current.events,
    );
  }

  static const String _npcExtractionSystemPrompt = '''
你是文字游戏 App 的 NPC 档案提取器。你只负责从主线聊天文本中提取 NPC 档案，不要推进剧情，不要创作新剧情。

你必须只输出一个 JSON 对象，不要使用 Markdown，不要解释。
JSON 格式：
{
  "npcs": [
    {
      "name": "NPC 名字或稳定称呼",
      "description": "身份、人设、性格、和主角/用户角色的关系，80-180字",
      "affinity": 0,
      "impression": "这个 NPC 目前对主角/用户角色的印象，40-120字"
    }
  ]
}

只提取最近剧情中已经实际出现或明确被提及、后续可能继续参与剧情的人物。
不要提取用户本人、AI 叙述者、班级/社团/家人这种泛称群体、纯物品、地点、系统面板或一次性无名路人。
affinity 是 NPC 对用户角色的好感度，范围 -100 到 100；impression 是自然语言印象，两者必须分开。
最多返回 6 个 NPC。没有合适 NPC 时返回 {"npcs":[]}。
''';

  static const String _npcChatSystemPrompt = '''
你是文字游戏 App 的 NPC 私聊引擎。你只扮演指定 NPC 和用户角色进行手机聊天，不推进主线回合，不改变考试、时间线、重大事件和世界设定。

你必须只输出一个 JSON 对象，不要使用 Markdown，不要解释。
JSON 格式：
{
  "messages": ["NPC 第1个气泡", "NPC 第2个气泡"],
    "impressionPatch": {
      "summary": "本次私聊后 NPC 对用户角色的核心印象变化，只写简体中文自然句，不要带英文标签",
      "affinityDelta": 0,
      "bondStage": "初见/熟悉/信任/牵绊/分岔/深羁绊 之一",
      "bondRoute": "恋人线/挚友线/宿敌线/共犯线/守护线/师徒线/破镜线/未知线 之一",
      "attitude": "当前态度",
      "relationshipShift": "关系变化",
    "rememberedDetails": ["NPC 记住的细节"],
    "futureInfluence": "后续主线中可以自然影响的互动倾向"
  }
}

messages 必须是 2-5 条，每条都要像真实手机聊天气泡：短、自然、带停顿感，可以有补充、迟疑、轻微情绪，但不要写大段旁白。
affinityDelta 是本次私聊造成的好感变化，范围 -30 到 30，普通聊天通常在 -3 到 5 之间；summary 是自然语言印象，不要把好感度和印象混成一个字段。
bondStage 必须按关系深度选择固定阶段：初见、熟悉、信任、牵绊、分岔、深羁绊；bondRoute 必须按主要关系倾向选择固定路线，不确定就用未知线，不要自造名称。
summary 里禁止出现 summary、affinityDelta、attitude、relationshipShift、rememberedDetails、futureInfluence 等英文键名；这些内容只能放在 JSON 对应字段里。
impressionPatch 会被系统保存并影响后续主线。
''';

  static const String _npcInnerVoiceSystemPrompt = '''
你是文字游戏 App 的 NPC 心声生成器。
你只负责补出某一条 NPC 私聊气泡背后的内心活动，不推进主线，不替用户行动。

输出要求：
- 只输出一段中文文本，不要 JSON，不要 Markdown，不要标题。
- 80-220 字，像用户偷听到 TA 此刻心里真正闪过的念头。
- 心声可以和表面话语有反差，但不能推翻 NPC 已有人设和关系。
- 不要写“作为 NPC”“用户点击了心声”之类打破沉浸的话。
''';

  static const String _npcGiftSystemPrompt = '''
你是文字游戏 App 的 NPC 送礼反馈引擎。
你只处理用户给 NPC 送礼后的私聊反馈、好感变化和印象变化，不推进主线回合。
''';

  static const String _npcLetterSystemPrompt = '''
你是文字游戏 App 的 NPC 主动来信生成器。你只负责让指定 NPC 主动给用户角色发手机聊天消息，不推进主线回合，不改变重大剧情事实。

你必须只输出一个 JSON 对象，不要使用 Markdown，不要解释。
JSON 格式：
{
  "messages": ["NPC 主动消息第1个气泡", "NPC 主动消息第2个气泡"]
}

messages 必须是 1-3 条，每条都要像真实手机聊天气泡：自然、短、带一点人物性格和当前印象。
不要写旁白，不要写舞台说明，不要替用户回复。
不要输出“等待回复中”“明日将主动找对方”“邀请信已传递”等状态句；如果没有合适话语，也要改成 NPC 会真正发出的简短聊天。
''';

  static const String _utilitySystemPrompt = '''
你是一个服务于 AI 角色扮演文字游戏 App 的辅助生成器。
你只负责整理、转换、修复和美化既有内容，不要擅自改变已经发生的剧情事实。
如果任务要求输出 HTML：
1. 必须输出完整可运行的单文件 HTML，放在 ```html 代码块中。
2. 不能引用外部 CSS、JS、图片或字体。
3. 页面必须适配手机屏幕，内部内容可以独立滚动。
4. 可以使用 CSS 和少量原生 JS 做折叠、标签页、状态切换等交互。
5. 如果生成可点击行动按钮，按钮必须写 data-prompt 或 data-action，值就是点击后要填入用户输入框的行动文本。
6. 不要解释代码怎么用，直接给用户可阅读或可渲染的内容。
''';

  static const String _fanficSystemPrompt = '''
你是一个服务于 AI 角色扮演文字游戏 App 的同人文生成器。
你会根据用户指定的角色关系和本篇灵感，生成一篇独立保存的同人文。
最高优先级：用户自填灵感或应用本地盲盒抽中的灵感，是本篇核心设定、题材和走向，必须严格遵循。
主线剧情、当前游戏面板、世界书、长期记忆、最近聊天记录，只能作为人物关系、性格、称呼和相处张力参考。
如果本篇灵感和主线世界观、地点、任务、门派、体系或时间线冲突，必须服从本篇灵感。
禁止默认续写当前主线；禁止默认沿用当前地点、任务、世界观规则或正在发生的事件，除非本篇灵感明确要求。
必须输出可直接阅读的中文正文，不要输出 HTML、JSON、代码块、互动按钮、[CHOICES]、[GAME_STATE]。
正文至少 3000 字。不要把生成结果写成剧情工具说明，不要询问用户是否继续，直接完成作品。
''';

  static const String _mysteryShopSystemPrompt = '''
你是文字游戏 App 的“神秘小卖部老板”。
你的任务是根据当前模拟器世界观、主线剧情、NPC 关系和游戏面板，生成能进入剧情物品栏的世界内商品。

你必须只输出 JSON 对象，不要 Markdown，不要解释，不要寒暄。
不要生成小剧场券、工具券、装扮、贴纸、称号或纯 UI 装饰。
商品必须能被用户在主线中使用，使用后可以影响剧情、NPC 好感度、NPC 印象、资源、线索、地点或状态。
''';

  static const String _blackMarketSystemPrompt = '''
你是文字游戏 App 的“黑心小卖部老板”。
你的任务是根据当前模拟器世界观、主线剧情、NPC 关系和游戏面板，生成高价、稀有、古怪、带一点风险感的世界内怪货。

你必须只输出 JSON 对象，不要 Markdown，不要解释，不要寒暄。
商品必须区别于神秘小卖部：不要便宜日用品，不要普通剧情小道具，不要功能券，不要装扮，不要称号，不要纯 UI 装饰。
商品价格必须在 50-500 啥币之间；如果商品效果未知，可以让 effect 为空，但 description 必须写出足够明确的可疑感、用途暗示或代价线索。
''';

  Future<String?> _runMapTask({
    required CharacterProfile character,
    required String actionTitle,
    required String userFacingAction,
    required String userPrompt,
    String? locationHtmlTargetId,
    bool replaceMapHtml = false,
    bool allowLocationReset = false,
  }) async {
    _isSending = true;
    _isMapGenerating = true;
    notifyListeners();

    try {
      final previous = await _ensureMapState(character.id);
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _mapSystemPrompt,
        userPrompt: userPrompt,
        temperature: character.modelParams.temperature,
        topP: character.modelParams.topP,
      );
      final result = raw.trim();
      if (result.isEmpty) {
        throw const LlmApiException('模型返回了空地图内容。');
      }

      final repairedResult = await _repairMapResultIfNeeded(
        character: character,
        previous: previous,
        originalResult: result,
        originalPrompt: userPrompt,
        allowLocationReset: allowLocationReset || previous.locations.isEmpty,
      );
      final nextState = _mergeMapResult(
        characterId: character.id,
        previous: previous,
        rawContent: repairedResult,
        locationHtmlTargetId: locationHtmlTargetId,
        replaceMapHtml: replaceMapHtml || previous.isEmpty,
        allowLocationReset: allowLocationReset || previous.locations.isEmpty,
      );
      _mapStateCache[character.id] = nextState;
      await _store.saveMapState(nextState);

      final visibleContent = _stripMapStateBlock(repairedResult).trim();
      await _appendMapMessage(
        characterId: character.id,
        role: ChatRole.assistant,
        content: visibleContent.isEmpty
            ? '【地图主线】$actionTitle 已更新。'
            : '【地图主线｜$actionTitle】\n行动：$userFacingAction\n\n$visibleContent',
      );
      await _updateGameStateFromMessage(
        character.id,
        repairedResult,
        gameplayPatchExpected: character.gameplaySystem != null,
        turnId: _historyFor(character.id).messages.last.id,
      );
      await _applyMapMovementNpcMessages(character.id, nextState);
      _scheduleSummarization(character.id);
      _scheduleNpcExtraction(character.id);
      await _updateGamification(
        (state) => state.incrementStat('totalMapModeActions'),
        notify: false,
      );
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (error) {
      return '地图生成失败：$error';
    } finally {
      _isSending = false;
      _isMapGenerating = false;
      notifyListeners();
    }
  }

  Future<void> _appendMapMessage({
    required String characterId,
    required ChatRole role,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final history = await _ensureHistory(characterId);
    final message = ChatMessage(
      id: IdGenerator.message(),
      role: role,
      content: trimmed,
      timestamp: DateTime.now(),
      isSummarized: false,
      tokenEstimate: _countCompletedTextTokens(trimmed),
    );
    final nextHistory = history.copyWith(
      messages: <ChatMessage>[...history.messages, message],
    );
    _historyCache[characterId] = nextHistory;
    await _store.saveDialogueHistory(nextHistory);
  }

  String _buildMapTaskPrompt({
    required CharacterProfile character,
    required String task,
    required String instruction,
  }) {
    final state = _mapStateFor(character.id);
    final history = _historyFor(character.id);
    final memory = _memoryFor(character.id);
    final gameState = _gameStateFor(character.id);
    final userProfile = _findBoundUserProfile(character.id);
    final npcProfiles =
        _npcProfilesForRuntime(character.id).take(20).map((npc) {
      final impression =
          npc.impression.trim().isEmpty ? '暂无明确印象' : npc.impression.trim();
      final role = npc.companionEnabled ? '绑定同行NPC' : '剧情NPC';
      final card =
          npc.roleCard.trim().isEmpty ? '' : '；角色卡：${npc.roleCard.trim()}';
      return '- [$role] ${npc.name}：${npc.description}；对宿主印象：$impression$card';
    }).join('\n');

    final recentMessages = history.messages
        .take(history.messages.length)
        .toList(growable: false)
        .reversed
        .take(10)
        .toList(growable: false)
        .reversed
        .map((message) =>
            '${message.role == ChatRole.user ? '用户' : character.name}：${message.content}')
        .join('\n\n');
    final memories = memory.summaries
        .take(8)
        .map((summary) => '- ${summary.summaryText}')
        .join('\n');
    final openingSummary = state.openingSummary.trim();
    final worldCalendar = _formatWorldCalendarForPrompt(character.id);
    final gameplayPrompt = character.gameplaySystem == null
        ? ''
        : _formatGameplaySystemForPrompt(
            character.gameplaySystem!,
            gameState,
          );

    return '''
【地图输出协议｜最高优先级】
以下内容是 App 的地图模式协议。地图任务必须同时输出主聊天可读长剧情、[GAME_STATE]${character.gameplaySystem == null ? '' : '、[THEATER_PATCH]'} 和 [MAP_STATE]，不要输出 [CHOICES]。
每次地图任务必须输出：长剧情正文 -> 可选完整 ```html 代码块``` -> [GAME_STATE] 状态块${character.gameplaySystem == null ? '' : ' -> [THEATER_PATCH] 变量补丁'} -> [MAP_STATE] JSON 块。
HTML 里的地点、时间和行动按钮必须使用 data-map-location、data-location-name、data-action 或 data-prompt，方便前端识别。
地图页会直接读取 [MAP_STATE] 里的 currentScene、activeChoices、locations、discoveredClues、npcPositions 和 npcMovements 展示主线，所以这些字段必须认真填写，不能只依赖 HTML。
如果当前地图状态已有地点列表，locations 必须沿用旧 id/name，不能新增、删除、改名或替换大地点；只更新地点状态、NPC、线索、最近场景、推荐行动、风险和时间成本。
如果当前地图状态暂无地点，第一次生成必须给 6-7 个大地点。
activeChoices 必须是 3-5 个能直接执行的短行动，不能写“继续探索”“观察周围”“推进剧情”这种空泛项。
[MAP_STATE].eventSummary 必须用一句简体中文概括本轮真实发生的事件，地图事件日志会优先使用它，不要把整段正文塞进去。
用户可见文本规则：地点名、按钮文案、线索、NPC 动向、currentLocationName、locations.name、locations.description、locations.scene、activeChoices.label、activeChoices.action 必须使用简体中文；英文或拼音 id 只允许放在 id/currentLocationId/locationId 等后台字段里，不能展示给用户。
[GAME_STATE] 规则：地图模式的 [GAME_STATE] 必须接近普通文游状态面板，至少包含时间、地点、状态、当前任务、人物数据、剧情物品栏、关系网、剧情记录、NPC变化、NPC更新。不能只写时间、地点、状态和任务。
NPC 更新规则：使用「npcId：已建档 NPC 的稳定 ID｜名字：...｜简介：...｜好感变化：-12 到 12｜印象：...｜生命周期：active/away/missing/dead/archived｜生命周期原因：...｜主动消息：本轮真实私聊原话」。已有 NPC 不得重写绝对好感；没有真实消息时主动消息留空。不要只写进 [MAP_STATE].npcMovements。

$gameplayPrompt

【用户可见角色设定｜地图主线核心】
当前 AI 角色：${character.name}
${character.prompt}

【世界书约束｜长期稳定补充】
${_formatWorldBooksForPrompt(character.id)}

【地图开局设定】
${openingSummary.isEmpty ? '暂无，按角色设定自然生成。' : openingSummary}

【世界事件日历】
${worldCalendar.trim().isEmpty ? '暂无。' : worldCalendar}

任务类型：$task

本次要求：
$instruction

绑定用户角色：
${userProfile == null ? '暂无绑定用户角色。' : '姓名：${userProfile.name}\n性别：${userProfile.gender}\n人设：${userProfile.persona}\n补充：${userProfile.description}'}

当前地图状态：
${_describeMapState(state)}

当前游戏面板状态：
时间：${gameState.timeLabel}
地点：${gameState.location}
状态：${gameState.status}
当前任务：${gameState.mainTask}
背包：${gameState.inventory.join('、')}

已知 NPC：
${npcProfiles.trim().isEmpty ? '暂无。' : npcProfiles}

长期记忆：
${memories.trim().isEmpty ? '暂无。' : memories}

最近主线记录：
${recentMessages.trim().isEmpty ? '暂无。' : recentMessages}
''';
  }

  MapWorldState _mergeMapResult({
    required String characterId,
    required MapWorldState previous,
    required String rawContent,
    String? locationHtmlTargetId,
    bool replaceMapHtml = false,
    bool allowLocationReset = false,
  }) {
    final now = DateTime.now();
    final html = _extractFirstHtmlDocument(rawContent);
    final statePayload = _extractMapStatePayload(rawContent);
    final payloadLocations = _locationsFromPayload(statePayload);
    final htmlLocations = _locationsFromHtml(html);
    final mergedLocations = _mergeMapLocations(
      previous.locations,
      <MapLocationNode>[...payloadLocations, ...htmlLocations],
      lockExisting: !allowLocationReset && previous.locations.isNotEmpty,
    );

    final title = _readString(statePayload, 'title').trim().isNotEmpty
        ? _readString(statePayload, 'title')
        : previous.title;
    final timeLabel = _readString(statePayload, 'timeLabel').trim().isNotEmpty
        ? _readString(statePayload, 'timeLabel')
        : previous.timeLabel;
    final stage = _readString(statePayload, 'stage').trim().isNotEmpty
        ? _readString(statePayload, 'stage')
        : previous.stage;
    final mainGoal = _readString(statePayload, 'mainGoal').trim().isNotEmpty
        ? _readString(statePayload, 'mainGoal')
        : previous.mainGoal;
    final currentScene =
        _readString(statePayload, 'currentScene').trim().isNotEmpty
            ? _readString(statePayload, 'currentScene')
            : previous.currentScene;
    final payloadChoices = _choicesFromPayload(statePayload);
    final discoveredClues = _mergeStringLists(
      previous.discoveredClues,
      _stringListFromPayload(statePayload, 'discoveredClues'),
      maxItems: 24,
      incomingFirst: true,
    );
    final npcMovements = _mergeStringLists(
      previous.npcMovements,
      _stringListFromPayload(statePayload, 'npcMovements'),
      maxItems: 16,
      incomingFirst: true,
    );
    final npcPositions = _mergeNpcPositions(
      previous.npcPositions,
      _npcPositionsFromPayload(statePayload, mergedLocations),
    );
    final eventSummary = _mapEventSummaryFromPayload(
      statePayload,
      rawContent,
    );
    var currentLocationId =
        _readString(statePayload, 'currentLocationId').trim();
    var currentLocationName =
        _readString(statePayload, 'currentLocationName').trim();
    if (currentLocationId.isEmpty && locationHtmlTargetId != null) {
      currentLocationId = locationHtmlTargetId.trim();
    }
    if (currentLocationId.isEmpty && mergedLocations.isNotEmpty) {
      currentLocationId = mergedLocations.first.id;
    }
    if (currentLocationName.isEmpty && currentLocationId.isNotEmpty) {
      for (final location in mergedLocations) {
        if (location.id == currentLocationId) {
          currentLocationName = location.name;
          break;
        }
      }
    }
    if (_isLikelyBackendMapId(currentLocationName) &&
        currentLocationId.isNotEmpty) {
      for (final location in mergedLocations) {
        if (location.id == currentLocationId) {
          currentLocationName = location.name;
          break;
        }
      }
    }
    currentLocationName = _visibleMapText(
      currentLocationName,
      fallback: currentLocationId.isEmpty ? '' : '未命名地点',
    );

    final targetLocationId = locationHtmlTargetId?.trim();
    final nextLocations = mergedLocations.map((location) {
      var nextStatus = location.status;
      if (currentLocationId.isNotEmpty && location.id == currentLocationId) {
        nextStatus = MapLocationStatus.current;
      } else if (location.status == MapLocationStatus.current) {
        nextStatus = location.hasGeneratedContent
            ? MapLocationStatus.explored
            : MapLocationStatus.available;
      }
      if (targetLocationId != null &&
          targetLocationId.isNotEmpty &&
          location.id == targetLocationId &&
          html.trim().isNotEmpty) {
        return location.copyWith(
          html: html,
          scene: currentScene.trim().isNotEmpty
              ? currentScene.trim()
              : location.scene,
          status: nextStatus,
          generatedAt: now,
        );
      }
      return location.copyWith(status: nextStatus);
    }).toList(growable: false);

    final nextEventLog = <String>[
      if (eventSummary.isNotEmpty)
        eventSummary.length > 600
            ? '${eventSummary.substring(0, 600)}...'
            : eventSummary,
      ...previous.eventLog,
    ].take(24).toList(growable: false);

    return previous.copyWith(
      characterId: characterId,
      updatedAt: now,
      title: title.trim().isEmpty ? '交互地图' : title.trim(),
      timeLabel: timeLabel.trim(),
      stage: stage.trim(),
      mainGoal: mainGoal.trim(),
      currentScene: currentScene.trim(),
      currentLocationId: currentLocationId,
      currentLocationName: currentLocationName,
      mapHtml:
          replaceMapHtml && html.trim().isNotEmpty ? html : previous.mapHtml,
      locations: nextLocations,
      activeChoices: payloadChoices.isEmpty
          ? _choicesFromLocations(nextLocations, currentLocationId)
          : payloadChoices,
      discoveredClues: discoveredClues,
      npcPositions: npcPositions,
      npcMovements: npcMovements,
      eventSummary: eventSummary,
      eventLog: nextEventLog,
    );
  }

  Future<String> _repairMapResultIfNeeded({
    required CharacterProfile character,
    required MapWorldState previous,
    required String originalResult,
    required String originalPrompt,
    required bool allowLocationReset,
    int minimumNarrativeChineseCharacters = 0,
  }) async {
    final firstValidation = _validateMapResult(
      previous: previous,
      rawContent: originalResult,
      allowLocationReset: allowLocationReset,
      gameplayPatchRequired: character.gameplaySystem != null,
      minimumNarrativeChineseCharacters: minimumNarrativeChineseCharacters,
    );
    if (firstValidation.isValid) {
      return originalResult;
    }

    final repaired = await _apiClient.runUtilityTask(
      settings: _settings,
      systemPrompt: _mapRepairSystemPrompt,
      userPrompt: _buildMapRepairPrompt(
        character: character,
        previous: previous,
        originalPrompt: originalPrompt,
        originalResult: originalResult,
        validation: firstValidation,
        allowLocationReset: allowLocationReset,
      ),
      temperature: 0.12,
      topP: 0.8,
    );
    final repairedResult = repaired.trim();
    final repairedValidation = _validateMapResult(
      previous: previous,
      rawContent: repairedResult,
      allowLocationReset: allowLocationReset,
      gameplayPatchRequired: character.gameplaySystem != null,
      minimumNarrativeChineseCharacters: minimumNarrativeChineseCharacters,
    );
    if (repairedValidation.isValid) {
      return repairedResult;
    }

    throw LlmApiException(
      '地图生成失败：模型输出格式不完整，已保留旧地图和行动篮子。缺失：${repairedValidation.issues.join('、')}',
    );
  }

  _MapResultValidation _validateMapResult({
    required MapWorldState previous,
    required String rawContent,
    required bool allowLocationReset,
    required bool gameplayPatchRequired,
    int minimumNarrativeChineseCharacters = 0,
  }) {
    final issues = <String>[];
    if (minimumNarrativeChineseCharacters > 0) {
      final narrative = GameStateParser.stripStateBlocks(
        _stripMapStateBlock(rawContent),
      ).replaceAll(
        RegExp(r'```html[\s\S]*?```', caseSensitive: false),
        '',
      );
      final chineseCharacterCount =
          RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff]').allMatches(narrative).length;
      if (chineseCharacterCount < minimumNarrativeChineseCharacters) {
        issues.add(
          '正式剧情正文至少 $minimumNarrativeChineseCharacters 个中文字符'
          '（当前 $chineseCharacterCount）',
        );
      }
    }
    if (!RegExp(
      r'\[GAME_STATE\]\s*[\s\S]*?\s*\[/GAME_STATE\]',
      caseSensitive: false,
    ).hasMatch(rawContent)) {
      issues.add('GAME_STATE');
    }
    if (RegExp(r'\[CHOICES\]', caseSensitive: false).hasMatch(rawContent)) {
      issues.add('unexpected_CHOICES');
    }
    if (gameplayPatchRequired) {
      final patch = GameplayPatchParser.parseResult(rawContent);
      if (!patch.found) {
        issues.add('THEATER_PATCH');
      } else if (!patch.isValid) {
        issues.add(patch.error ?? 'THEATER_PATCH JSON');
      }
    }
    final payload = _extractMapStatePayload(rawContent);
    if (payload.isEmpty) {
      issues.add('MAP_STATE JSON');
      return _MapResultValidation(issues);
    }

    for (final key in <String>[
      'currentLocationId',
      'mainGoal',
      'currentScene',
      'locations',
      'activeChoices',
      'npcPositions',
      'eventSummary',
    ]) {
      final value = payload[key];
      if (value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty)) {
        issues.add(key);
      }
    }

    final locations = _locationsFromPayload(payload);
    for (final location in locations) {
      if (!_hasCjkText(location.name)) {
        issues.add('location_name_not_chinese:${location.id}');
      }
    }
    if (allowLocationReset || previous.locations.isEmpty) {
      if (locations.length < 6 || locations.length > 7) {
        issues.add('6-7个大地点');
      }
    } else {
      final incomingById = <String, MapLocationNode>{
        for (final location in locations)
          if (location.id.trim().isNotEmpty) location.id: location,
      };
      for (final locked in previous.locations) {
        final incoming = incomingById[locked.id];
        if (incoming == null) {
          continue;
        }
        if (incoming.name.trim() != locked.name.trim()) {
          issues.add('地点改名：${locked.name}');
        }
      }
    }

    final currentLocationId = _readString(payload, 'currentLocationId').trim();
    if (currentLocationId.isNotEmpty && locations.isNotEmpty) {
      final ids = locations.map((location) => location.id).toSet();
      if (!ids.contains(currentLocationId) &&
          previous.locations
              .where((location) => location.id == currentLocationId)
              .isEmpty) {
        issues.add('currentLocationId不在地点表');
      }
    }

    final choices = _choicesFromPayload(payload);
    if (choices.length < 3 || choices.length > 5) {
      issues.add('3-5 activeChoices');
    }
    for (final choice in choices) {
      if (_isVagueMapAction(choice.action) || _isVagueMapAction(choice.label)) {
        issues.add('activeChoice_not_actionable:${choice.label}');
        break;
      }
    }

    return _MapResultValidation(issues);
  }

  String _buildMapRepairPrompt({
    required CharacterProfile character,
    required MapWorldState previous,
    required String originalPrompt,
    required String originalResult,
    required _MapResultValidation validation,
    required bool allowLocationReset,
  }) {
    final lockedLocations = previous.locations
        .map((location) => '${location.id}｜${location.name}')
        .join('\n');
    return '''
请只修复地图模式输出格式，不改剧情事实，不新增没发生过的情节。

修复目标：
1. 保留原回复中的用户可读正文和 HTML。
2. 补齐或修正末尾 [MAP_STATE] JSON。
3. [MAP_STATE] 必须包含 currentLocationId/mainGoal/currentScene/locations/activeChoices/npcPositions/eventSummary。
4. activeChoices 给 3-5 个具体下一步行动，不要写“继续探索/观察周围/推进剧情”。
5. 同时保留或补齐 [GAME_STATE]；如果原文没有，则按原剧情事实补一个最小可解析状态块。
6. ${character.gameplaySystem == null ? '当前剧场没有玩法变量，不要新增 [THEATER_PATCH]。' : '保留或补齐 [THEATER_PATCH]，放在 [GAME_STATE] 和 [MAP_STATE] 之间；没有变化时输出 {"ops":[]}。'}
7. currentLocationName、locations.name、locations.description、locations.scene、activeChoices.label/action 必须是用户可见中文。
8. 不要输出解释，不要用 Markdown 包裹 [MAP_STATE] 或 [THEATER_PATCH]。

${allowLocationReset ? '本次允许重建大地点，但必须生成 6-7 个大地点。' : '本次不允许新增、删除、改名或替换大地点；必须沿用下列 id/name，缺失地点要补回：\n$lockedLocations'}

格式问题：
${validation.issues.map((issue) => '- $issue').join('\n')}

原任务提示：
$originalPrompt

当前角色：${character.name}

原始输出：
$originalResult
''';
  }

  List<MapLocationNode> _mergeMapLocations(
    List<MapLocationNode> existing,
    List<MapLocationNode> incoming, {
    required bool lockExisting,
  }) {
    final byId = <String, MapLocationNode>{
      for (final item in existing)
        if (item.id.trim().isNotEmpty) item.id: item,
    };
    final existingOrder = existing
        .map((item) => item.id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    for (final raw in incoming) {
      final id = raw.id.trim();
      if (id.isEmpty) {
        continue;
      }
      final previous = byId[id];
      if (lockExisting && previous == null) {
        continue;
      }
      byId[id] = raw.copyWith(
        id: id,
        name: lockExisting && previous != null
            ? previous.name
            : raw.name.trim().isEmpty
                ? (previous?.name ?? id)
                : raw.name,
        description: raw.description.trim().isEmpty
            ? (previous?.description ?? '')
            : raw.description,
        html: raw.html.trim().isEmpty ? (previous?.html ?? '') : raw.html,
        scene: raw.scene.trim().isEmpty ? (previous?.scene ?? '') : raw.scene,
        status: raw.status == MapLocationStatus.locked &&
                previous != null &&
                previous.status != MapLocationStatus.locked
            ? previous.status
            : raw.status,
        npcs:
            raw.npcs.isEmpty ? (previous?.npcs ?? const <String>[]) : raw.npcs,
        clues: raw.clues.isEmpty
            ? (previous?.clues ?? const <String>[])
            : raw.clues,
        nextActions: raw.nextActions.isEmpty
            ? (previous?.nextActions ?? const <String>[])
            : raw.nextActions,
        riskLevel: raw.riskLevel.trim().isEmpty
            ? (previous?.riskLevel ?? '')
            : raw.riskLevel,
        timeCost: raw.timeCost.trim().isEmpty
            ? (previous?.timeCost ?? '')
            : raw.timeCost,
        generatedAt: raw.generatedAt.millisecondsSinceEpoch == 0
            ? (previous?.generatedAt ?? raw.generatedAt)
            : raw.generatedAt,
      );
    }
    if (!lockExisting) {
      return byId.values.toList(growable: false);
    }
    return existingOrder
        .map((id) => byId[id])
        .whereType<MapLocationNode>()
        .toList(growable: false);
  }

  Map<String, dynamic> _extractMapStatePayload(String rawContent) {
    final match = RegExp(
      r'\[MAP_STATE\]([\s\S]*?)\[/MAP_STATE\]',
      caseSensitive: false,
    ).firstMatch(rawContent);
    if (match == null) {
      return const <String, dynamic>{};
    }
    var jsonText = (match.group(1) ?? '').trim();
    jsonText = jsonText
        .replaceAll(RegExp(r'^```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```$'), '')
        .trim();
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return const <String, dynamic>{};
    }
    return const <String, dynamic>{};
  }

  String _stripMapStateBlock(String rawContent) {
    return rawContent.replaceAll(
      RegExp(r'\[MAP_STATE\][\s\S]*?\[/MAP_STATE\]', caseSensitive: false),
      '',
    );
  }

  String _extractFirstHtmlDocument(String rawContent) {
    final fenced = RegExp(
      r'```html\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(rawContent);
    if (fenced != null) {
      return (fenced.group(1) ?? '').trim();
    }
    final shell = RegExp(
      r'<!doctype[\s\S]*?</html>|<html[\s\S]*?</html>',
      caseSensitive: false,
    ).firstMatch(rawContent);
    if (shell != null) {
      return shell.group(0)?.trim() ?? '';
    }
    return '';
  }

  List<MapLocationNode> _locationsFromPayload(Map<String, dynamic> payload) {
    final rawLocations = payload['locations'];
    if (rawLocations is! List) {
      return const <MapLocationNode>[];
    }
    return rawLocations
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final rawId = map['id']?.toString() ?? map['name']?.toString() ?? '';
          final id = _safeMapLocationId(rawId);
          final rawName = map['name']?.toString() ?? rawId;
          return MapLocationNode(
            id: id,
            name: _visibleMapText(rawName, fallback: '未命名地点'),
            parentId: map['parentId']?.toString() ?? '',
            description: map['description']?.toString() ?? '',
            scene: map['scene']?.toString() ?? '',
            status: MapLocationStatus.fromJson(map['status']),
            npcs: _stringListFromDynamic(map['npcs']),
            clues: _stringListFromDynamic(map['clues']),
            nextActions: _stringListFromDynamic(map['nextActions']),
            riskLevel:
                map['riskLevel']?.toString() ?? map['risk']?.toString() ?? '',
            timeCost:
                map['timeCost']?.toString() ?? map['cost']?.toString() ?? '',
          );
        })
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<MapLocationNode> _locationsFromHtml(String html) {
    if (html.trim().isEmpty) {
      return const <MapLocationNode>[];
    }
    final locations = <MapLocationNode>[];
    final attrPattern = RegExp(
      r'''data-map-location=["']([^"']+)["'][^>]*(?:data-location-name=["']([^"']+)["'])?''',
      caseSensitive: false,
    );
    for (final match in attrPattern.allMatches(html)) {
      final id = _safeMapLocationId(match.group(1) ?? '');
      if (id.isEmpty) {
        continue;
      }
      locations.add(
        MapLocationNode(
          id: id,
          name: _visibleMapText(
            match.group(2) ?? '',
            fallback: '未命名地点',
          ),
        ),
      );
    }
    final actionPattern = RegExp(
      r'''data-(?:action|prompt)=["']map:location:([^"'|｜]+)(?:[|｜]([^"']+))?["']''',
      caseSensitive: false,
    );
    for (final match in actionPattern.allMatches(html)) {
      final id = _safeMapLocationId(match.group(1) ?? '');
      if (id.isEmpty) {
        continue;
      }
      locations.add(
        MapLocationNode(
          id: id,
          name: _visibleMapText(
            match.group(2) ?? '',
            fallback: '未命名地点',
          ),
        ),
      );
    }
    return locations;
  }

  String _visibleMapText(String raw, {required String fallback}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _isLikelyBackendMapId(trimmed)) {
      return fallback;
    }
    return trimmed;
  }

  bool _hasCjkText(String raw) => RegExp(r'[\u4e00-\u9fa5]').hasMatch(raw);

  bool _isLikelyBackendMapId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmed)) {
      return false;
    }
    return RegExp(r'^[A-Za-z][A-Za-z0-9_\-\s]{1,48}$').hasMatch(trimmed);
  }

  bool _isVagueMapAction(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'[\s。！？!?,，、；;：:]+'), '');
    if (normalized.isEmpty) {
      return true;
    }
    const vagueActions = <String>{
      '继续',
      '继续行动',
      '继续探索',
      '继续观察',
      '观察周围',
      '看看情况',
      '等待',
      '随便看看',
      '下一步',
      '推进剧情',
      '自由行动',
    };
    return vagueActions.contains(normalized);
  }

  String _mapEventSummaryFromPayload(
    Map<String, dynamic> payload,
    String rawContent,
  ) {
    final direct = _readString(payload, 'eventSummary').trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final rawLog = payload['eventLog'];
    if (rawLog is List) {
      for (final item in rawLog) {
        final text = item.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return GameStateParser.stripStateBlocks(
      _stripMapStateBlock(rawContent),
    )
        .replaceAll(RegExp(r'```html[\s\S]*?```', caseSensitive: false), '')
        .trim();
  }

  String _safeMapLocationId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = trimmed
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\u4e00-\u9fa5]'), '');
    if (normalized.isEmpty) {
      return 'loc_${trimmed.hashCode.abs()}';
    }
    return normalized.length > 40 ? normalized.substring(0, 40) : normalized;
  }

  String _readString(Map<String, dynamic> map, String key) {
    return map[key]?.toString() ?? '';
  }

  List<String> _stringListFromPayload(
    Map<String, dynamic> payload,
    String key,
  ) {
    return _stringListFromDynamic(payload[key]);
  }

  List<String> _stringListFromDynamic(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _mergeStringLists(
    List<String> previous,
    List<String> incoming, {
    required int maxItems,
    bool incomingFirst = false,
  }) {
    final result = <String>[];
    final seen = <String>{};
    final source = incomingFirst
        ? <String>[...incoming, ...previous]
        : <String>[...previous, ...incoming];
    for (final item in source) {
      final trimmed = item.trim();
      final key = _normalizeMapIntelKey(trimmed);
      if (trimmed.isEmpty || key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      result.add(trimmed);
    }
    if (result.length <= maxItems) {
      return result;
    }
    return incomingFirst
        ? result.take(maxItems).toList(growable: false)
        : result.sublist(result.length - maxItems);
  }

  String _normalizeMapIntelKey(String value) {
    var normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[#*•·，,。.!！?？:：;；\s]+'), '')
        .replaceAll(RegExp(r'[“”"「」『』《》【】\[\]（）()]+'), '');
    normalized = normalized
        .replaceAll('可能', '')
        .replaceAll('似乎', '')
        .replaceAll('大概', '')
        .replaceAll('预计', '')
        .replaceAll('当前', '')
        .replaceAll('正在', '')
        .replaceAll('已经', '')
        .replaceAll('存在', '')
        .replaceAll('保留部分', '保留')
        .replaceAll('特殊', '');
    return normalized.length > 36 ? normalized.substring(0, 36) : normalized;
  }

  List<MapStoryChoice> _choicesFromPayload(Map<String, dynamic> payload) {
    final rawChoices = payload['activeChoices'];
    if (rawChoices is! List) {
      return const <MapStoryChoice>[];
    }
    return rawChoices
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final raw = MapStoryChoice.fromJson(map);
          final id = raw.id.trim().isEmpty
              ? _safeMapLocationId(raw.label)
              : _safeMapLocationId(raw.id);
          final label = _visibleMapText(
            raw.label,
            fallback: _visibleMapText(raw.action, fallback: '继续行动'),
          );
          final action = _visibleMapText(raw.action, fallback: label);
          return raw.copyWith(
            id: id,
            label: label,
            action: action,
            locationId: raw.locationId.trim().isEmpty
                ? ''
                : _safeMapLocationId(raw.locationId),
            riskLevel: raw.riskLevel.trim(),
            timeCost: raw.timeCost.trim(),
          );
        })
        .where((item) => item.label.trim().isNotEmpty)
        .take(8)
        .toList(growable: false);
  }

  List<MapNpcPosition> _npcPositionsFromPayload(
    Map<String, dynamic> payload,
    List<MapLocationNode> locations,
  ) {
    final rawPositions = payload['npcPositions'];
    final locationNamesById = <String, String>{
      for (final location in locations) location.id: location.name,
    };
    if (rawPositions is List) {
      return rawPositions
          .whereType<Map>()
          .map((item) {
            final raw =
                MapNpcPosition.fromJson(Map<String, dynamic>.from(item));
            final locationId = raw.locationId.trim().isEmpty
                ? ''
                : _safeMapLocationId(raw.locationId);
            final locationName = raw.locationName.trim().isNotEmpty
                ? _visibleMapText(
                    raw.locationName,
                    fallback: locationNamesById[locationId] ?? '未命名地点',
                  )
                : (locationNamesById[locationId] ?? '');
            final id = raw.id.trim().isNotEmpty
                ? _safeMapLocationId(raw.id)
                : _safeMapLocationId(raw.name);
            return raw.copyWith(
              id: id,
              locationId: locationId,
              locationName: locationName,
            );
          })
          .where((item) => item.name.trim().isNotEmpty)
          .take(30)
          .toList(growable: false);
    }

    final fallback = <MapNpcPosition>[];
    final seen = <String>{};
    for (final location in locations) {
      for (final npc in location.npcs) {
        final name = npc.trim();
        if (name.isEmpty || seen.contains(name)) {
          continue;
        }
        seen.add(name);
        fallback.add(
          MapNpcPosition(
            id: _safeMapLocationId(name),
            name: name,
            locationId: location.id,
            locationName: location.name,
            status: location.status == MapLocationStatus.current
                ? '同处当前位置'
                : '最近在此出现',
          ),
        );
      }
    }
    return fallback.take(30).toList(growable: false);
  }

  List<MapNpcPosition> _mergeNpcPositions(
    List<MapNpcPosition> previous,
    List<MapNpcPosition> incoming,
  ) {
    if (incoming.isEmpty) {
      return previous;
    }
    final byKey = <String, MapNpcPosition>{
      for (final item in previous)
        if (item.name.trim().isNotEmpty) item.name.trim(): item,
    };
    for (final raw in incoming) {
      final key = raw.name.trim();
      if (key.isEmpty) {
        continue;
      }
      final old = byKey[key];
      byKey[key] = raw.copyWith(
        id: raw.id.trim().isEmpty
            ? (old?.id ?? _safeMapLocationId(raw.name))
            : raw.id,
        locationId: raw.locationId.trim().isEmpty
            ? (old?.locationId ?? '')
            : raw.locationId,
        locationName: raw.locationName.trim().isEmpty
            ? (old?.locationName ?? '')
            : raw.locationName,
        status: raw.status.trim().isEmpty ? (old?.status ?? '') : raw.status,
        intent: raw.intent.trim().isEmpty ? (old?.intent ?? '') : raw.intent,
        lastSeen:
            raw.lastSeen.trim().isEmpty ? (old?.lastSeen ?? '') : raw.lastSeen,
      );
    }
    return byKey.values.take(30).toList(growable: false);
  }

  List<MapStoryChoice> _choicesFromLocations(
    List<MapLocationNode> locations,
    String currentLocationId,
  ) {
    final choices = <MapStoryChoice>[];
    for (final location in locations) {
      if (location.id == currentLocationId ||
          location.status == MapLocationStatus.hidden) {
        continue;
      }
      if (location.status == MapLocationStatus.locked &&
          !location.hasGeneratedContent) {
        continue;
      }
      final locationName = _visibleMapText(
        location.name,
        fallback: '未命名地点',
      );
      choices.add(
        MapStoryChoice(
          id: 'go_${location.id}',
          label: '前往$locationName',
          action: '前往地点：$locationName',
          locationId: location.id,
          kind: MapStoryChoiceKind.location,
          riskLevel: location.riskLevel,
          timeCost: location.timeCost,
        ),
      );
    }
    return choices.take(5).toList(growable: false);
  }

  List<MapLocationNode> _markCurrentMapLocation(
    List<MapLocationNode> locations,
    String currentLocationId,
  ) {
    final id = currentLocationId.trim();
    if (id.isEmpty) {
      return locations;
    }
    return locations.map((location) {
      if (location.id == id) {
        return location.copyWith(status: MapLocationStatus.current);
      }
      if (location.status == MapLocationStatus.current) {
        return location.copyWith(
          status: location.hasGeneratedContent
              ? MapLocationStatus.explored
              : MapLocationStatus.available,
        );
      }
      return location;
    }).toList(growable: false);
  }

  String _describeMapState(MapWorldState state) {
    if (state.isEmpty) {
      return '暂无地图。';
    }
    final locations = state.locations
        .map((location) =>
            '- ${location.id}｜${location.name}｜${location.status.name}｜${location.description}'
            '${location.scene.trim().isEmpty ? '' : '｜场景：${location.scene.trim()}'}'
            '${location.clues.isEmpty ? '' : '｜线索：${location.clues.join('、')}'}'
            '${location.npcs.isEmpty ? '' : '｜NPC：${location.npcs.join('、')}'}'
            '${location.riskLevel.trim().isEmpty ? '' : '｜风险：${location.riskLevel.trim()}'}'
            '${location.timeCost.trim().isEmpty ? '' : '｜成本：${location.timeCost.trim()}'}')
        .join('\n');
    final choices = state.activeChoices.isEmpty
        ? '暂无。'
        : state.activeChoices
            .map((choice) =>
                '- ${choice.kind.name}｜${choice.label}｜${choice.action}'
                '${choice.riskLevel.trim().isEmpty ? '' : '｜风险：${choice.riskLevel.trim()}'}'
                '${choice.timeCost.trim().isEmpty ? '' : '｜成本：${choice.timeCost.trim()}'}')
            .join('\n');
    final events =
        state.eventLog.isEmpty ? '暂无。' : state.eventLog.take(8).join('\n---\n');
    return '''
地图标题：${state.title}
当前时间：${state.timeLabel}
主线阶段：${state.stage}
主线目标：${state.mainGoal}
当前位置：${state.currentLocationName}（${state.currentLocationId}）
当前场景：${state.activeScene}
地点列表：
$locations
已发现线索：${state.discoveredClues.isEmpty ? '暂无。' : state.discoveredClues.join('；')}
NPC 动向：${state.npcMovements.isEmpty ? '暂无。' : state.npcMovements.join('；')}
NPC 位置：${state.npcPositions.isEmpty ? '暂无。' : state.npcPositions.map((npc) => '${npc.name}@${npc.locationName.trim().isEmpty ? npc.locationId : npc.locationName}${npc.status.trim().isEmpty ? '' : '｜${npc.status}'}${npc.intent.trim().isEmpty ? '' : '｜意图：${npc.intent}'}').join('；')}
当前可选行动：
$choices
近期地图事件：
$events
''';
  }

  static const String _mapSystemPrompt = '''
你是一个“地图主线模式”引擎，负责把文字游戏世界转换成可点击、可推进、可长期保存的互动地图。

核心原则：
1. 地图模式不是支线。只要角色启用地图模式，地点探索、时间推进、地点行动就是主线剧情本身。
2. 用户主要在聊天里阅读长剧情；地图只是组织地点和行动篮子。不要把输出写成纯按钮游戏。
3. 不要和既有聊天记录、NPC印象、背包、任务、世界书冲突。如果必须变更状态，要在输出中交代原因。
4. 第一次生成地图时必须生成 6-7 个“大地点”。大地点 id/name 之后长期锁定。
5. 如果提示中已有地点列表，后续输出必须沿用所有旧地点 id/name，不能新增、删除、改名、替换大地点；只能更新 status、description、scene、npcs、clues、nextActions、riskLevel、timeCost。
6. 新版规则地图每次先由 App 本地引擎确定性结算，再由你根据结算前后状态生成正式主线叙事。activeChoices 和 nextActions 都应是可加入行动篮子的明确计划，如“前往旧图书馆调查借阅记录”“找林夏确认监控时间”。
7. 每次输出必须包含可阅读的长剧情正文，接着可以包含一个可渲染的单文件 HTML。HTML 要适配手机屏幕，不引用外部资源。
8. 输出末尾必须同时给 App 独立 [GAME_STATE] 和 [MAP_STATE]。不要放进 HTML 里，也不要放进 Markdown 代码块里。
9. [MAP_STATE] 是地图 UI 主数据。必须包含 currentLocationId、mainGoal、currentScene、locations、activeChoices、npcPositions、eventSummary。
10. activeChoices 必须是 3-5 个能直接放入行动篮子的行动，不要写“继续探索”这种空泛选项；每个选项要有 kind、label、action、riskLevel、timeCost。
11. npcPositions 必须列出当前重要 NPC 的最近位置或已知位置，每项包含 id/name/locationId/locationName/status/intent/lastSeen；不确定时写“最后已知”，不要留空。
12. 用户可见地点名必须是简体中文。后台 id 可以是英文、拼音或 snake_case，但 currentLocationName、locations.name、locationName、按钮文案和正文里不能显示英文地点 id。
13. [GAME_STATE] 必须完整覆盖普通文游状态面板字段：时间、地点、状态、当前任务、人物数据、剧情物品栏、关系网、剧情记录、NPC变化、NPC更新。
14. NPC 主动联系必须写入 [GAME_STATE] 的 NPC更新｜主动消息；[MAP_STATE].npcMovements 只做摘要展示，不能替代私聊触发。
15. discoveredClues 和 npcMovements 只输出本轮新增或仍然关键的精简条目，不要重复改写旧线索，不要把历史动向整段重列。
16. eventSummary 必须是一句简体中文事件摘要，概括本轮真实发生了什么，供地图事件日志使用。
17. 如果提示提供“本地结算后 MAP_STATE”，它是规则权威结果。你不得改写拓扑、当前位置、回合、行动力、任务、危机、背包、世界事件或 NPC agent，只能在提示明确允许的叙事字段中补充内容。

输出结构：
先写给用户看的主线长剧情正文。
然后可选输出 ```html ... ``` 完整 HTML。
然后输出 [GAME_STATE] 状态块。
[GAME_STATE] 示例字段：
时间：当前时间
地点：简体中文地点名
状态：用户当前状态
当前任务：当前主线目标
人物数据：用户/NPC 的关键状态
剧情物品栏：物品名｜说明｜用途
关系网：人物关系变化
剧情记录：本轮重要事实
NPC变化：NPC名字：好感/印象/位置变化
NPC更新：npcId：稳定ID｜名字：NPC名字｜简介：身份与关系｜好感变化：本轮增量｜印象：自然语言印象｜生命周期：active/away/missing/dead/archived｜生命周期原因：正文事实｜主动消息：本轮真实私聊原话
最后输出：
[MAP_STATE]
{
  "title": "地图标题",
  "timeLabel": "当前时间",
  "stage": "序章/调查/危机/反转/终局等当前阶段",
  "mainGoal": "当前主线目标",
  "currentLocationId": "后台位置id，可用英文或拼音",
  "currentLocationName": "用户可见的简体中文当前位置名",
  "currentScene": "当前地点正在发生的主线正文，用户不退出地图也能直接阅读",
  "locations": [
    {
      "id": "location_id",
      "name": "简体中文地点名",
      "description": "简体中文地点说明",
      "parentId": "",
      "status": "locked/available/current/explored/hidden",
      "scene": "该地点最近一次场景摘要",
      "npcs": ["此处相关NPC"],
      "clues": ["此处线索"],
      "nextActions": ["该地点可做的短行动"],
      "riskLevel": "低/中/高或具体风险",
      "timeCost": "片刻/一小时/半天或具体时间成本"
    }
  ],
  "activeChoices": [
    {
      "id": "short_id",
      "kind": "action/location/clue/social/danger/rest",
      "label": "按钮上显示的简体中文短句",
      "action": "点击后要执行的简体中文具体行动文本",
      "locationId": "如果是前往地点则填地点id，否则留空",
      "riskLevel": "低/中/高或具体风险",
      "timeCost": "片刻/一小时/半天或具体时间成本"
    }
  ],
  "discoveredClues": ["已经明确发现的线索"],
  "npcPositions": [
    {
      "id": "npc_id",
      "name": "NPC名字",
      "locationId": "所在或最后已知地点id",
      "locationName": "地点名",
      "status": "等待/调查中/失联/同行/敌对/最后已知等",
      "intent": "TA 接下来可能想做什么",
      "lastSeen": "刚刚/昨夜/一小时前等"
    }
  ],
  "npcMovements": ["NPC 当前动向或位置变化"],
  "eventSummary": "本次发生的重要事件一句话摘要",
  "eventLog": ["本次发生的重要事件一句话"]
}
[/MAP_STATE]
''';

  static const String _mapRepairSystemPrompt = '''
你是地图模式格式修复器。你的任务只修格式，不改剧情事实。
必须输出完整修复后的回复：用户可读正文、可选 HTML、[GAME_STATE]、原任务要求的 [THEATER_PATCH]、[MAP_STATE]。
不要解释修复过程，不要输出 Markdown 代码块包裹 JSON，不要新增或改名已锁定大地点。
用户可见地点名、按钮、线索和动向必须是简体中文；英文 id 只能留在 id/currentLocationId/locationId 字段。
[GAME_STATE] 必须包含时间、地点、状态、当前任务、人物数据、剧情物品栏、关系网、剧情记录、NPC变化、NPC更新。
如果出现 NPC 主动联系或搭话，必须放入 [GAME_STATE] 的 NPC更新｜主动消息，不要只保留在 [MAP_STATE].npcMovements。
''';

  Future<String?> _streamAssistantReply({
    required CharacterProfile character,
    required DialogueHistory originalHistory,
    required DialogueHistory optimisticHistory,
    required String placeholderMessageId,
    required List<ChatMessage> requestMessages,
    required Set<String> invalidatedMessageIds,
    String cacheResetReason = '',
    TurnDirective? requestTurnDirective,
    GameStateSnapshot? gameStateOverride,
  }) async {
    if (_isDataMutationInProgress) {
      return '数据正在导入或删除，请稍等。';
    }
    if (_isGameplaySystemGenerating) {
      return '玩法系统正在生成，请稍等。';
    }
    _isSending = true;
    _cancelCurrentReply = false;
    late _PreparedChatRequest prepared;
    late DialogueHistory replayOriginalHistory;
    late DialogueHistory replayOptimisticHistory;
    var finalEpoch = originalHistory.promptCacheEpoch;
    var turnCommitted = false;
    try {
      prepared = await _planChatRequestMessages(
        character: character,
        messages: requestMessages,
        forcedRolloverReason: cacheResetReason,
        requestTurnDirective: requestTurnDirective,
        gameStateOverride: gameStateOverride,
      );
      finalEpoch = prepared.epoch;
      final cacheOriginalHistory = originalHistory.copyWith(
        promptCacheEpoch: prepared.epoch,
      );
      final cacheOptimisticHistory = optimisticHistory.copyWith(
        promptCacheEpoch: prepared.epoch,
      );
      replayOriginalHistory = _withPromptReplaySnapshots(
        cacheOriginalHistory,
        prepared.messages,
      );
      replayOptimisticHistory = _withPromptReplaySnapshots(
        cacheOptimisticHistory,
        prepared.messages,
      );
    } catch (error) {
      _isSending = false;
      _cancelCurrentReply = false;
      notifyListeners();
      return '准备上下文失败：$error';
    }
    final replyCancellation = LlmCancellationToken();
    _activeReplyCancellation = replyCancellation;
    _historyCache[character.id] = replayOptimisticHistory;
    _startStreamingSession(placeholderMessageId);
    notifyListeners();

    try {
      final buffer = StringBuffer();
      final replayRequestMessages = prepared.messages;
      final context = AiRequestContext(
        character: character,
        gameState: prepared.gameState,
        userProfile: prepared.userProfile,
        npcProfiles: prepared.npcProfiles,
        worldBooks: prepared.worldBooks,
        runtimeAddendum: prepared.runtimeAddendum,
        contextMessages: replayRequestMessages,
        memorySummaries: prepared.memorySummaries,
        estimatedTokens: prepared.estimatedTokens,
        promptDiagnostics: prepared.promptDiagnostics,
        promptCacheEpoch: prepared.epoch,
      );

      await for (final chunk in _aiReplyPipeline.streamReply(
        settings: _settings,
        context: context,
        shouldPause: () => _cancelCurrentReply,
        cancellationToken: replyCancellation,
      )) {
        buffer.write(chunk);
        _historyCache[character.id] = _replaceMessageContent(
          _historyCache[character.id] ?? replayOptimisticHistory,
          placeholderMessageId,
          buffer.toString(),
          clearTokenCount: true,
        );
        if (_shouldFlushStreamingUi(buffer.length)) {
          notifyListeners();
        }
      }
      notifyListeners();

      final rawProviderContent = buffer.toString();
      final normalizedStreamContent = character.largeGroupChatModeEnabled
          ? MessageContentParser.normalizeGroupChatBlocks(buffer.toString())
              .trim()
          : MessageContentParser.normalizeChoiceBlocks(buffer.toString())
              .trim();
      var finalContent = normalizedStreamContent;
      if (finalContent.isEmpty) {
        if (_cancelCurrentReply) {
          _historyCache[character.id] = replayOriginalHistory;
          await _store.saveDialogueHistory(replayOriginalHistory);
          return null;
        }
        throw const LlmApiException('模型返回了空内容。');
      }
      if (_cancelCurrentReply) {
        finalContent = '$finalContent\n\n（回复已暂停）';
      } else {
        finalContent = await _adjudicateAssistantTurnState(
          character: character,
          content: finalContent,
          requestMessages: replayRequestMessages,
          previousGameState: prepared.gameState,
          npcProfiles: prepared.npcProfiles,
          cancellationToken: replyCancellation,
        );
        if (_cancelCurrentReply) {
          finalContent = '$finalContent\n\n（回复已暂停）';
        } else {
          finalContent = await _repairAssistantReplyFormatIfNeeded(
            character: character,
            content: finalContent,
            requestMessages: replayRequestMessages,
            previousGameState: prepared.gameState,
            cancellationToken: replyCancellation,
          );
          if (_cancelCurrentReply) {
            finalContent = '$finalContent\n\n（回复已暂停）';
          }
        }
      }

      final providerReplayExact = !_cancelCurrentReply &&
          finalContent == normalizedStreamContent &&
          rawProviderContent.isNotEmpty;
      final providerReplayContent =
          providerReplayExact ? rawProviderContent : finalContent;

      final finalTokenCount = _assistantReplyOutputTokenCount();
      var finalHistory = _replaceMessageContent(
        _historyCache[character.id] ?? replayOptimisticHistory,
        placeholderMessageId,
        finalContent,
        tokenCount: finalTokenCount,
        clearTokenCount: finalTokenCount == null,
        promptReplayContent: _apiClient.buildAssistantPromptReplayContent(
          finalContent,
        ),
        providerReplayContent: providerReplayContent,
        providerReplayExact: providerReplayExact,
      );

      var parsedGameState = _cancelCurrentReply
          ? null
          : GameStateParser.parseFromMessage(
              characterId: character.id,
              content: finalContent,
              previous: prepared.gameState,
            );
      if (!_cancelCurrentReply && character.gameplaySystem != null) {
        parsedGameState = _applyGameplayPatchToState(
          character: character,
          previousState: prepared.gameState,
          state: parsedGameState ?? prepared.gameState,
          turnId: placeholderMessageId,
          content: finalContent,
          patchExpected: true,
        );
      }
      if (parsedGameState != null) {
        finalHistory = _replaceMessageContent(
          finalHistory,
          placeholderMessageId,
          finalContent,
          gameStateSnapshot: _gameplaySnapshot(
              parsedGameState, character.gameplaySystem,
              previousState: prepared.gameState),
          tokenCount: finalTokenCount,
          clearTokenCount: finalTokenCount == null,
          promptReplayContent: _apiClient.buildAssistantPromptReplayContent(
            finalContent,
          ),
          providerReplayContent: providerReplayContent,
          providerReplayExact: providerReplayExact,
        );
      }

      final latestUsage = _aiReplyPipeline.traceLogger.latest?.cacheUsage;
      finalEpoch = prepared.epoch.copyWith(
        previousPromptTokens:
            latestUsage?.inputTokens ?? prepared.estimatedTokens,
      );
      finalHistory = finalHistory.copyWith(promptCacheEpoch: finalEpoch);

      final invalidatedIds = <String>{
        if (invalidatedMessageIds.isNotEmpty) ...invalidatedMessageIds,
      };
      CharacterMemory? invalidatedMemory;
      if (invalidatedIds.isNotEmpty) {
        final invalidated = await _invalidateSummariesForMessageIds(
          characterId: character.id,
          history: finalHistory,
          changedMessageIds: invalidatedIds,
        );
        finalHistory = invalidated.history;
        _memoryCache[character.id] = invalidated.memory;
        invalidatedMemory = invalidated.memory;
      }

      _TimelineReplayResult? repairedTimeline;
      if (invalidatedIds.isNotEmpty && !_cancelCurrentReply) {
        repairedTimeline =
            _replayGameStateFromHistory(character.id, finalHistory);
        finalHistory = repairedTimeline.history;
        parsedGameState = repairedTimeline.gameState;
      }

      _historyCache[character.id] = finalHistory;
      if (parsedGameState != null) {
        _gameStateCache[character.id] = parsedGameState;
      }
      await _store.commitTurnState(
        history: finalHistory,
        gameState: parsedGameState,
        memory: invalidatedMemory,
      );
      turnCommitted = true;
      if (repairedTimeline != null) {
        await _rebuildTimelineAutoNpcs(
          characterId: character.id,
          states: repairedTimeline.states,
        );
      } else if (!_cancelCurrentReply && parsedGameState != null) {
        final deliveredNpcMessages = await _applyGameStateNpcUpdates(
          character.id,
          parsedGameState,
          emitProactiveMessages: true,
          sourceTurnId: placeholderMessageId,
        );
        if (deliveredNpcMessages == 0) {
          _scheduleAmbientNpcMessage(
            character.id,
            sourceTurnId: placeholderMessageId,
          );
        }
      }
      if (!_cancelCurrentReply) {
        _scheduleSummarization(character.id);
        _scheduleNpcExtraction(character.id);
        await _updateGamification(
          (state) => state
              .incrementStat('totalAssistantReplies')
              .incrementDailyStat('assistantReplies')
              .addCompanionXp(character.id, 10)
              .setStatMax(
                'hiddenMusicReplyBackground',
                _musicState.isPlaying ? 1 : 0,
              ),
          notify: false,
        );
      }
      return null;
    } on LlmApiException catch (error) {
      if (!turnCommitted) {
        _historyCache[character.id] = replayOriginalHistory;
        await _store.saveDialogueHistory(replayOriginalHistory);
        return error.message;
      }
      return '回复已经保存，但后续资料更新失败：${error.message}';
    } catch (error) {
      if (!turnCommitted) {
        _historyCache[character.id] = replayOriginalHistory;
        await _store.saveDialogueHistory(replayOriginalHistory);
        return '发送失败：$error';
      }
      return '回复已经保存，但后续资料更新失败：$error';
    } finally {
      if (requestTurnDirective == null) {
        _activeTurnDirective = null;
      }
      _isSending = false;
      _cancelCurrentReply = false;
      if (identical(_activeReplyCancellation, replyCancellation)) {
        _activeReplyCancellation = null;
      }
      _stopStreamingSession();
      notifyListeners();
      try {
        await _recordLatestPromptCacheMetric(
          characterId: character.id,
          epoch: finalEpoch ?? prepared.epoch,
        );
      } catch (_) {
        // Optional diagnostics must never keep the composer locked.
      }
    }
  }

  DialogueHistory _withPromptReplaySnapshots(
    DialogueHistory history,
    List<ChatMessage> requestMessages,
  ) {
    final replayById = <String, String>{};
    for (final message in requestMessages) {
      final replay = message.promptReplayContent?.trim();
      if (replay != null && replay.isNotEmpty) {
        replayById[message.id] = replay;
      }
    }
    if (replayById.isEmpty) {
      return history;
    }
    return history.copyWith(
      messages: history.messages.map((message) {
        final replay = replayById[message.id];
        if (replay == null) {
          return message;
        }
        return message.copyWith(promptReplayContent: replay);
      }).toList(growable: false),
    );
  }

  int? _assistantReplyOutputTokenCount() =>
      _aiReplyPipeline.traceLogger.latest?.cacheUsage?.outputTokens;

  Future<void> _recordLatestPromptCacheMetric({
    required String characterId,
    required PromptCacheEpoch epoch,
  }) async {
    final entry = _aiReplyPipeline.traceLogger.latest;
    if (entry == null || entry.id == _lastRecordedTraceId) {
      return;
    }
    _lastRecordedTraceId = entry.id;
    final usage = entry.cacheUsage;
    final uri = Uri.tryParse(_settings.effectiveApiUrl.trim());
    final metric = PromptCacheMetric(
      id: entry.id,
      characterId: characterId,
      recordedAt: entry.completedAt ?? DateTime.now(),
      model: entry.model,
      endpointHost: uri?.host ?? '',
      cacheEpochId: epoch.id,
      rolloverReason: entry.promptDiagnostics.cacheRolloverReason,
      stablePrefixDigest: entry.promptDiagnostics.stablePrefixDigest,
      estimatedPromptTokens: entry.estimatedTokens,
      messageCount: entry.messageCount,
      usedExactAssistantReplay:
          entry.promptDiagnostics.usedExactAssistantReplay,
      previousPromptTokens: entry.promptDiagnostics.previousPromptTokens,
      inputTokens: usage?.inputTokens,
      outputTokens: usage?.outputTokens,
      cacheHitTokens: usage?.cachedInputTokens,
      cacheMissTokens: usage?.cacheMissInputTokens,
      elapsedMilliseconds: entry.elapsed?.inMilliseconds,
      error: entry.error,
    );
    _promptCacheMetrics.insert(0, metric);
    if (_promptCacheMetrics.length > 120) {
      _promptCacheMetrics.removeRange(120, _promptCacheMetrics.length);
    }
    await _store.savePromptCacheMetrics(_promptCacheMetrics);
  }

  DialogueHistory _replaceMessageContent(
    DialogueHistory history,
    String messageId,
    String content, {
    Map<String, dynamic>? gameStateSnapshot,
    int? tokenCount,
    bool clearTokenCount = false,
    String? promptReplayContent,
    String? providerReplayContent,
    bool? providerReplayExact,
  }) {
    final hasGameStateSnapshot = gameStateSnapshot != null;
    return history.copyWith(
      messages: history.messages
          .map(
            (message) => message.id == messageId
                ? message.copyWith(
                    content: content,
                    isSummarized: false,
                    gameStateSnapshot: gameStateSnapshot,
                    clearGameStateSnapshot: !hasGameStateSnapshot,
                    tokenEstimate: tokenCount,
                    clearTokenEstimate: clearTokenCount,
                    promptReplayContent: promptReplayContent,
                    clearPromptReplayContent:
                        promptReplayContent?.trim().isEmpty ?? false,
                    providerReplayContent: providerReplayContent,
                    clearProviderReplayContent:
                        providerReplayContent?.isEmpty ?? false,
                    providerReplayExact: providerReplayExact,
                  )
                : message,
          )
          .toList(growable: false),
    );
  }

  Future<String> _adjudicateAssistantTurnState({
    required CharacterProfile character,
    required String content,
    required List<ChatMessage> requestMessages,
    required GameStateSnapshot previousGameState,
    required List<NpcProfile> npcProfiles,
    required LlmCancellationToken cancellationToken,
  }) async {
    if (character.isTutorialDemo) {
      return content;
    }
    var latestUserMessage = '';
    for (var index = requestMessages.length - 1; index >= 0; index--) {
      if (requestMessages[index].role == ChatRole.user) {
        latestUserMessage = requestMessages[index].content;
        break;
      }
    }
    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: TurnStateAdjudicator.buildSystemPrompt(
          gameplayPatchRequired: character.gameplaySystem != null,
        ),
        userPrompt: TurnStateAdjudicator.buildUserPrompt(
          character: character,
          previousState: previousGameState,
          npcProfiles: npcProfiles,
          latestUserMessage: latestUserMessage,
          narrativeReply: GameStateParser.stripStateBlocks(content),
        ),
        temperature: 0.12,
        topP: 0.8,
        cancellationToken: cancellationToken,
      );
      final adjudication = TurnStateAdjudicator.parse(
        raw,
        gameplayPatchRequired: character.gameplaySystem != null,
      );
      if (adjudication == null) {
        return content;
      }
      return ReplyProtocolReconciler.mergeStateBlocks(
        primary: content,
        fallback: adjudication.protocolContent,
        gameplayPatchRequired: character.gameplaySystem != null,
        preferFallback: true,
      );
    } catch (_) {
      // The original reply still goes through the established repair path.
      return content;
    }
  }

  Future<String> _repairAssistantReplyFormatIfNeeded({
    required CharacterProfile character,
    required String content,
    required List<ChatMessage> requestMessages,
    required GameStateSnapshot previousGameState,
    required LlmCancellationToken cancellationToken,
  }) async {
    final normalized = character.largeGroupChatModeEnabled
        ? MessageContentParser.normalizeGroupChatBlocks(content).trim()
        : MessageContentParser.normalizeChoiceBlocks(content).trim();
    final validation = _validateAssistantReplyFormat(
      normalized,
      choicesEnabled: character.nextStepOptionsEnabled,
      largeGroupChatMode: character.largeGroupChatModeEnabled,
      gameplayPatchRequired: character.gameplaySystem != null,
      expectedChoiceCount: character.preferredChoiceCount,
      htmlRequired: character.requiresHtmlPanel,
    );
    if (validation.isValid) {
      return normalized;
    }

    var repaired = normalized;
    try {
      var latestUserMessage = '';
      for (var index = requestMessages.length - 1; index >= 0; index--) {
        final message = requestMessages[index];
        if (message.role == ChatRole.user) {
          latestUserMessage = message.content;
          break;
        }
      }
      final repairResult = await _apiClient.repairChatReplyFormat(
        settings: _settings,
        character: character,
        originalReply: normalized,
        latestUserMessage: latestUserMessage,
        gameState: previousGameState,
        cancellationToken: cancellationToken,
      );
      final repairNormalized = character.largeGroupChatModeEnabled
          ? MessageContentParser.normalizeGroupChatBlocks(repairResult).trim()
          : MessageContentParser.normalizeChoiceBlocks(repairResult).trim();
      final originalWithRepairedState =
          ReplyProtocolReconciler.mergeStateBlocks(
        primary: normalized,
        fallback: repairNormalized,
        gameplayPatchRequired: character.gameplaySystem != null,
      );
      if (_validateAssistantReplyFormat(
        originalWithRepairedState,
        choicesEnabled: character.nextStepOptionsEnabled,
        largeGroupChatMode: character.largeGroupChatModeEnabled,
        gameplayPatchRequired: character.gameplaySystem != null,
        expectedChoiceCount: character.preferredChoiceCount,
        htmlRequired: character.requiresHtmlPanel,
      ).isValid) {
        return originalWithRepairedState;
      }
      final repairWithOriginalState = ReplyProtocolReconciler.mergeStateBlocks(
        primary: repairNormalized,
        fallback: normalized,
        gameplayPatchRequired: character.gameplaySystem != null,
      );
      if (_validateAssistantReplyFormat(
        repairWithOriginalState,
        choicesEnabled: character.nextStepOptionsEnabled,
        largeGroupChatMode: character.largeGroupChatModeEnabled,
        gameplayPatchRequired: character.gameplaySystem != null,
        expectedChoiceCount: character.preferredChoiceCount,
        htmlRequired: character.requiresHtmlPanel,
      ).isValid) {
        return repairWithOriginalState;
      }
      if (originalWithRepairedState.isNotEmpty) {
        repaired = originalWithRepairedState;
      } else if (repairWithOriginalState.isNotEmpty) {
        repaired = repairWithOriginalState;
      }
    } catch (_) {
      // Format repair is a best-effort fallback. If it fails, use local guards.
    }

    return _applyLocalFormatFallbacks(
      content: repaired,
      choicesEnabled: character.nextStepOptionsEnabled,
      largeGroupChatMode: character.largeGroupChatModeEnabled,
      gameplayPatchRequired: character.gameplaySystem != null,
      previousGameState: previousGameState,
      expectedChoiceCount: character.preferredChoiceCount,
      htmlRequired: character.requiresHtmlPanel,
    );
  }

  _ReplyFormatValidation _validateAssistantReplyFormat(
    String content, {
    required bool choicesEnabled,
    required bool largeGroupChatMode,
    required bool gameplayPatchRequired,
    required int expectedChoiceCount,
    required bool htmlRequired,
  }) {
    final mode = largeGroupChatMode
        ? ReplyProtocolMode.largeGroupChat
        : ReplyProtocolMode.standard;
    final validation = ReplyProtocolValidator.validate(
      content: content,
      mode: mode,
      choicesEnabled: choicesEnabled,
      gameplayPatchRequired: gameplayPatchRequired,
      expectedChoiceCount: expectedChoiceCount,
      htmlRequired: htmlRequired,
    );
    return _ReplyFormatValidation(validation.issues);
  }

  String _applyLocalFormatFallbacks({
    required String content,
    required bool choicesEnabled,
    required bool largeGroupChatMode,
    required bool gameplayPatchRequired,
    required GameStateSnapshot previousGameState,
    required int expectedChoiceCount,
    required bool htmlRequired,
  }) {
    if (largeGroupChatMode) {
      return _applyLargeGroupChatLocalFallbacks(
        content: content,
        previousGameState: previousGameState,
        gameplayPatchRequired: gameplayPatchRequired,
      );
    }

    var result = MessageContentParser.normalizeChoiceBlocks(content).trim();
    if (result.isEmpty) {
      result = '本轮内容生成时没有返回可展示正文。';
    }

    if (htmlRequired &&
        !RegExp(r'```html[\s\S]*?```', caseSensitive: false).hasMatch(result)) {
      result = '$result\n\n${_buildFallbackHtmlBlock(previousGameState)}';
    }

    if (!RegExp(
      r'\[GAME_STATE\]\s*[\s\S]*?\s*\[/GAME_STATE\]',
      caseSensitive: false,
    ).hasMatch(result)) {
      result = result
          .replaceAll(
            RegExp(
              r'\[GAME_STATE\][\s\S]*?(?=\[CHOICES\]|$)',
              caseSensitive: false,
            ),
            '',
          )
          .trimRight();
      result = '$result\n\n${_buildFallbackGameStateBlock(previousGameState)}';
    }

    final parsed = MessageContentParser.parseStructured(result, cache: false);
    if (choicesEnabled &&
        (parsed.choices.length != expectedChoiceCount ||
            !_hasExpectedChoiceIndexes(
              parsed.choices,
              expectedChoiceCount,
            ))) {
      result = result.replaceAll(
        RegExp(r'\[CHOICES\][\s\S]*?\[/CHOICES\]', caseSensitive: false),
        '',
      );
      result = '${result.trimRight()}\n\n'
          '${_buildFallbackChoicesBlock(expectedChoiceCount)}';
    } else if (!choicesEnabled && parsed.choices.isNotEmpty) {
      result = result.replaceAll(
        RegExp(r'\[CHOICES\][\s\S]*?\[/CHOICES\]', caseSensitive: false),
        '',
      );
    }

    result = MessageContentParser.normalizeChoiceBlocks(result).trim();
    return gameplayPatchRequired ? _ensureGameplayPatchBlock(result) : result;
  }

  String _applyLargeGroupChatLocalFallbacks({
    required String content,
    required GameStateSnapshot previousGameState,
    required bool gameplayPatchRequired,
  }) {
    var result = MessageContentParser.normalizeGroupChatBlocks(content).trim();
    if (result.isEmpty) {
      result =
          '[GROUP_CHAT]\n{"mode":"large_group_chat","messages":[{"type":"narration","speaker":"旁白","content":"本轮内容生成时没有返回可展示的群聊消息。"}]}\n[/GROUP_CHAT]';
    }

    result = result
        .replaceAll(
          RegExp(r'```html[\s\S]*?```', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\[CHOICES\][\s\S]*?\[/CHOICES\]', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\[BUBBLE\]|\[/BUBBLE\]', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\[MAP_STATE\][\s\S]*?\[/MAP_STATE\]', caseSensitive: false),
          '',
        )
        .trim();

    if (!MessageContentParser.hasGroupChatBlock(result)) {
      final visible = MessageContentParser.visibleStreamingText(result).trim();
      final fallbackContent =
          visible.isEmpty ? '本轮剧情继续推进，但模型没有按大型群聊格式返回消息。' : visible;
      final encoded = jsonEncode(<String, dynamic>{
        'mode': 'large_group_chat',
        'messages': <Map<String, String>>[
          <String, String>{
            'type': 'narration',
            'speaker': '旁白',
            'content': fallbackContent,
          },
        ],
      });
      result = '[GROUP_CHAT]\n$encoded\n[/GROUP_CHAT]\n\n$result';
    }

    if (!RegExp(
      r'\[GAME_STATE\]\s*[\s\S]*?\s*\[/GAME_STATE\]',
      caseSensitive: false,
    ).hasMatch(result)) {
      result = result
          .replaceAll(
            RegExp(
              r'\[GAME_STATE\][\s\S]*$',
              caseSensitive: false,
            ),
            '',
          )
          .trimRight();
      result = '$result\n\n${_buildFallbackGameStateBlock(previousGameState)}';
    }

    result = MessageContentParser.normalizeGroupChatBlocks(result).trim();
    return gameplayPatchRequired ? _ensureGameplayPatchBlock(result) : result;
  }

  String _ensureGameplayPatchBlock(String content) {
    final parsed = GameplayPatchParser.parseResult(content);
    if (parsed.isValid) {
      return content;
    }
    var result = content
        .replaceAll(GameplayPatchParser.blockPattern, '')
        .replaceAll(
          RegExp(
            r'\[THEATER_PATCH\][\s\S]*?(?=\[CHOICES\]|\[MAP_STATE\]|$)',
            caseSensitive: false,
          ),
          '',
        )
        .trimRight();
    const fallback = '[THEATER_PATCH]\n{"ops":[]}\n[/THEATER_PATCH]';
    final boundary = RegExp(
      r'\[(?:CHOICES|MAP_STATE)\]',
      caseSensitive: false,
    ).firstMatch(result);
    if (boundary == null) {
      return '$result\n\n$fallback'.trim();
    }
    final before = result.substring(0, boundary.start).trimRight();
    final after = result.substring(boundary.start).trimLeft();
    return '$before\n\n$fallback\n\n$after'.trim();
  }

  bool _hasExpectedChoiceIndexes(
    List<MessageChoice> choices,
    int expectedChoiceCount,
  ) {
    final expectedIndexes = List<String>.generate(
      expectedChoiceCount,
      (index) => String.fromCharCode(65 + index),
      growable: false,
    );
    final actualIndexes = choices
        .map((choice) => choice.index.trim().toUpperCase())
        .toList(growable: false);
    return actualIndexes.length == expectedIndexes.length &&
        !actualIndexes.asMap().entries.any(
              (entry) => entry.value != expectedIndexes[entry.key],
            );
  }

  String _buildFallbackHtmlBlock(GameStateSnapshot state) {
    final time =
        state.timeLabel.trim().isEmpty ? '当前回合' : state.timeLabel.trim();
    final location =
        state.location.trim().isEmpty ? '当前位置' : state.location.trim();
    final task =
        state.mainTask.trim().isEmpty ? '等待下一步行动' : state.mainTask.trim();

    return '''
```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { margin: 0; font-family: system-ui, "Microsoft YaHei", sans-serif; background: #f7f7f8; color: #222; }
    .card { padding: 16px; border: 1px solid #dedee3; background: #fff; border-radius: 8px; }
    h2 { margin: 0 0 10px; font-size: 18px; }
    p { margin: 8px 0; line-height: 1.6; }
  </style>
</head>
<body>
  <section class="card">
    <h2>回合状态</h2>
    <p>时间：$time</p>
    <p>地点：$location</p>
    <p>当前任务：$task</p>
  </section>
</body>
</html>
```
''';
  }

  String _buildFallbackGameStateBlock(GameStateSnapshot state) {
    final time =
        state.timeLabel.trim().isEmpty ? '当前回合' : state.timeLabel.trim();
    final location =
        state.location.trim().isEmpty ? '当前位置' : state.location.trim();
    final status = state.status.trim().isEmpty ? '等待玩家行动' : state.status.trim();
    final task =
        state.mainTask.trim().isEmpty ? '继续推进当前剧情' : state.mainTask.trim();
    final profile = state.profileDetails.isEmpty
        ? '沿用上一轮人物数据'
        : state.profileDetails.join('；');
    final relations = state.relationshipNotes.isEmpty
        ? '沿用上一轮关系网'
        : state.relationshipNotes.join('；');
    final records = state.plotFlags.isEmpty
        ? '本轮回复格式由 App 自动补全，剧情事实以正文为准'
        : state.plotFlags.join('；');
    final npcChanges =
        state.npcChanges.isEmpty ? '暂无明确变化' : state.npcChanges.join('；');
    return '''
[GAME_STATE]
时间：$time
地点：$location
状态：$status
当前任务：$task
人物数据：$profile
关系网：$relations
剧情记录：$records
NPC变化：$npcChanges
NPC更新：无
[/GAME_STATE]
''';
  }

  String _buildFallbackChoicesBlock(int expectedChoiceCount) {
    if (expectedChoiceCount == 3) {
      return '''
[CHOICES]
A|继续当前体验，看看刚才的选择会带来什么变化。
B|换一条体验路线，认识另一个最常用的功能。
C|先自由探索，我想按自己的方式试试看。
[/CHOICES]
''';
    }
    return '''
[CHOICES]
A|继续观察当前局面，寻找最自然的推进方式。
B|询问最近的关键人物，确认接下来该做什么。
C|检查当前地点和随身物品，整理可用线索。
D|换一个角度回顾刚才的异常细节。
E|主动接近一个相关人物，试探对方的态度。
F|做一个意外但仍合理的行动，打破当前僵局。
[/CHOICES]
''';
  }

  ChatMessage? _messageWithNearestStateSnapshot(
    List<ChatMessage> messages,
    int originIndex,
  ) {
    if (messages.isEmpty) {
      return null;
    }
    final start = originIndex.clamp(0, messages.length - 1);
    for (var index = start; index >= 0; index--) {
      final message = messages[index];
      if (message.gameStateSnapshot != null) {
        return message;
      }
    }
    return null;
  }

  List<NpcProfile> _npcProfilesForBranchSnapshot({
    required String sourceCharacterId,
    required String rootCharacterId,
    required GameStateSnapshot state,
    required ChatMessage? snapshotMessage,
  }) {
    final stateNames = _npcNamesFromGameState(state);
    final stateHasNpcSignals =
        stateNames.isNotEmpty || state.npcChanges.isNotEmpty;
    final cutoff = snapshotMessage?.timestamp;
    final sourceIds = <String>{sourceCharacterId, rootCharacterId};

    return _npcProfiles.where((profile) {
      if (!sourceIds.contains(profile.characterId)) {
        return false;
      }
      if (cutoff != null && profile.createdAt.isAfter(cutoff)) {
        return false;
      }
      if (profile.hasReusableRoleCard) {
        return true;
      }
      if (!stateHasNpcSignals) {
        return cutoff == null || !profile.createdAt.isAfter(cutoff);
      }
      final normalizedName = _normalizeNpcName(profile.name);
      if (normalizedName.isEmpty) {
        return false;
      }
      return stateNames.contains(normalizedName);
    }).toList(growable: false);
  }

  Set<String> _npcNamesFromGameState(GameStateSnapshot state) {
    final names = <String>{};

    void collectFromText(String value) {
      final text = value.trim();
      if (text.isEmpty || text == '无') {
        return;
      }
      for (final profile in _npcProfiles) {
        final normalized = _normalizeNpcName(profile.name);
        if (normalized.isEmpty) {
          continue;
        }
        if (text.contains(profile.name.trim())) {
          names.add(normalized);
        }
      }
      final match = RegExp(r'^(?:NPC\s*)?([^:：｜|，,；;（）()]+)').firstMatch(text);
      final guessed = match?.group(1)?.trim() ?? '';
      if (guessed.isNotEmpty && guessed.length <= 16) {
        names.add(_normalizeNpcName(guessed));
      }
    }

    for (final update in state.npcUpdates) {
      final normalized = _normalizeNpcName(update.name);
      if (normalized.isNotEmpty) {
        names.add(normalized);
      }
    }
    for (final value in <String>[
      ...state.npcChanges,
      ...state.relationshipNotes,
      ...state.profileDetails,
    ]) {
      collectFromText(value);
    }
    return names;
  }

  MapWorldState _mapStateForBranch(
    MapWorldState source,
    GameStateSnapshot state, {
    required String branchId,
  }) {
    if (source.isEmpty || state.isEmpty) {
      return MapWorldState.empty(branchId);
    }

    final stateText = <String>[
      state.location,
      state.timeLabel,
      state.mainTask,
      state.status,
      state.eventTitle,
      state.eventDescription,
      ...state.plotFlags,
    ].where((item) => item.trim().isNotEmpty).join('\n');
    final currentName = source.currentLocationName.trim();
    final currentKnown = currentName.isEmpty || stateText.contains(currentName);
    if (!currentKnown) {
      return MapWorldState.empty(branchId);
    }
    return source.copyWith(characterId: branchId);
  }

  GameStateSnapshot _gameStateFromMessageSnapshot(
    ChatMessage? message, {
    required GameStateSnapshot fallback,
    required String branchId,
  }) {
    final snapshot = message?.gameStateSnapshot;
    if (snapshot == null) {
      return fallback.copyWith(characterId: branchId);
    }
    try {
      return GameStateSnapshot.fromJson(snapshot).copyWith(
        characterId: branchId,
      );
    } catch (_) {
      return fallback.copyWith(characterId: branchId);
    }
  }

  GameStateSnapshot _gameStateAtBranchPoint(
    List<ChatMessage> messages, {
    required ChatMessage? snapshotMessage,
    required String sourceCharacterId,
    required String branchId,
  }) {
    final emptyFallback = GameStateSnapshot.empty(branchId);
    if (snapshotMessage != null) {
      return _gameStateFromMessageSnapshot(
        snapshotMessage,
        fallback: emptyFallback,
        branchId: branchId,
      );
    }

    final character = _findCharacter(sourceCharacterId);
    final baseline = _gameplayReplayBaseline(messages, sourceCharacterId);
    var state = baseline.state;
    GameplaySystem? replaySystem = baseline.system;
    var parsedAny = false;
    for (final message in messages) {
      if (message.role != ChatRole.assistant) {
        continue;
      }
      final turnSystem =
          _gameplaySystemAtMessage(message, character?.gameplaySystem);
      if (turnSystem != null) {
        state = _gameplayStateForDefinition(state, replaySystem, turnSystem);
        replaySystem = turnSystem;
      }
      var parsed = GameStateParser.parseFromMessage(
        characterId: sourceCharacterId,
        content: message.content,
        previous: state,
      );
      final patch = GameplayPatchParser.parseResult(message.content);
      if (character?.gameplaySystem != null && patch.found) {
        parsed = _applyGameplayPatchToState(
          character: character!,
          previousState: state,
          state: parsed ?? state,
          turnId: message.id,
          systemOverride:
              _gameplaySystemAtMessage(message, character.gameplaySystem!),
          content: message.content,
          patchExpected: false,
        );
      }
      if (parsed == null) {
        continue;
      }
      state = parsed;
      parsedAny = true;
    }
    if (!parsedAny) {
      return emptyFallback;
    }
    return state.copyWith(characterId: branchId);
  }

  Future<({DialogueHistory history, CharacterMemory memory})>
      _invalidateSummariesForMessageIds({
    required String characterId,
    required DialogueHistory history,
    required Set<String> changedMessageIds,
  }) async {
    final memory = await _ensureMemory(characterId);
    if (changedMessageIds.isEmpty || memory.summaries.isEmpty) {
      return (history: history, memory: memory);
    }

    final impactedSummaries = memory.summaries
        .where(
          (summary) =>
              summary.relatedMessageIds.any(changedMessageIds.contains),
        )
        .toList();

    if (impactedSummaries.isEmpty) {
      return (history: history, memory: memory);
    }

    final impactedMessageIds = impactedSummaries
        .expand((summary) => summary.relatedMessageIds)
        .toSet();

    final updatedHistory = history.copyWith(
      messages: history.messages
          .map(
            (message) => impactedMessageIds.contains(message.id)
                ? message.copyWith(isSummarized: false)
                : message,
          )
          .toList(growable: false),
    );

    final impactedSummaryIds =
        impactedSummaries.map((summary) => summary.id).toSet();

    final updatedMemory = memory.copyWith(
      summaries: memory.summaries
          .where((summary) => !impactedSummaryIds.contains(summary.id))
          .toList(growable: false),
    );

    return (history: updatedHistory, memory: updatedMemory);
  }

  void _startStreamingSession(String messageId) {
    _streamingElapsedTimer?.cancel();
    _streamingMessageId = messageId;
    _streamingElapsedSeconds = 0;
    _lastStreamingUiUpdateAt = null;
    _streamingElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _streamingElapsedSeconds += 1;
      notifyListeners();
    });
  }

  void _stopStreamingSession() {
    _streamingElapsedTimer?.cancel();
    _streamingElapsedTimer = null;
    _streamingMessageId = null;
    _streamingElapsedSeconds = 0;
    _lastStreamingUiUpdateAt = null;
  }

  bool _shouldFlushStreamingUi(int bufferedLength) {
    if (bufferedLength <= 0) {
      return false;
    }
    final now = DateTime.now();
    final last = _lastStreamingUiUpdateAt;
    final interval = _settings.mobilePowerSaveMode
        ? const Duration(milliseconds: 180)
        : const Duration(milliseconds: 40);
    if (last == null ||
        now.difference(last) >= interval) {
      _lastStreamingUiUpdateAt = now;
      return true;
    }
    return false;
  }

  void _scheduleSummarization(String characterId) {
    _summaryTimers[characterId]?.cancel();
    _summaryTimers[characterId] = Timer(
      const Duration(seconds: 4),
      () => unawaited(_runSummarizationWhenIdle(characterId)),
    );
  }

  void _scheduleNpcExtraction(String characterId) {
    if (!_settings.canChat) {
      return;
    }
    _npcExtractionTimers[characterId]?.cancel();
    _npcExtractionTimers[characterId] = Timer(
      const Duration(seconds: 3),
      () => unawaited(_runNpcExtractionWhenIdle(characterId)),
    );
  }

  Future<void> _runSummarizationWhenIdle(String characterId) async {
    if (_isSending) {
      _scheduleSummarization(characterId);
      return;
    }

    if (_summarizingCharacterIds.contains(characterId) || !_settings.canChat) {
      return;
    }

    _summaryTimers.remove(characterId)?.cancel();

    final character = _findCharacter(characterId);
    if (character == null) {
      return;
    }

    _summarizingCharacterIds.add(characterId);
    try {
      final history = await _ensureHistory(characterId);
      final memory = await _ensureMemory(characterId);
      final result = await _memoryService.maybeSummarize(
        settings: _settings,
        character: character,
        history: history,
        memory: memory,
        apiClient: _apiClient,
      );

      if (result == null) {
        return;
      }

      final currentHistory = await _ensureHistory(characterId);
      final currentMemory = await _ensureMemory(characterId);
      final rebased = result.rebaseOnto(
        currentHistory: currentHistory,
        currentMemory: currentMemory,
      );
      if (rebased.summarizedMessageIds.isEmpty) {
        return;
      }
      _historyCache[characterId] = rebased.history;
      _memoryCache[characterId] = rebased.memory;
      await _store.commitTurnState(
        history: rebased.history,
        memory: rebased.memory,
      );
      notifyListeners();
    } catch (_) {
      return;
    } finally {
      _summarizingCharacterIds.remove(characterId);
    }
  }

  Future<void> _runNpcExtractionWhenIdle(String characterId) async {
    if (_isSending) {
      _scheduleNpcExtraction(characterId);
      return;
    }

    if (_extractingNpcCharacterIds.contains(characterId) ||
        !_settings.canChat) {
      return;
    }

    _npcExtractionTimers.remove(characterId)?.cancel();

    final character = _findCharacter(characterId);
    if (character == null) {
      return;
    }

    _extractingNpcCharacterIds.add(characterId);
    try {
      final history = await _ensureHistory(characterId);
      if (history.messages.length < 2) {
        return;
      }
      if (!_shouldRunNpcExtraction(characterId, history)) {
        return;
      }

      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _npcExtractionSystemPrompt,
        userPrompt: _buildNpcExtractionPrompt(
          character: character,
          history: history,
        ),
        temperature: 0.25,
        topP: 0.85,
      );

      final extracted = _parseExtractedNpcProfiles(raw);
      if (extracted.isEmpty) {
        return;
      }

      final beforeCount = _npcProfiles.length;
      final changed = _mergeExtractedNpcProfiles(character.id, extracted);
      if (!changed) {
        return;
      }

      await _store.saveNpcProfiles(_npcProfiles);
      final createdCount = _npcProfiles.length - beforeCount;
      if (createdCount > 0) {
        await _updateGamification(
          (state) => state.incrementStat(
            'totalNpcProfilesCreated',
            createdCount,
          ),
          notify: false,
        );
      }
      notifyListeners();
    } catch (_) {
      return;
    } finally {
      _extractingNpcCharacterIds.remove(characterId);
    }
  }

  @visibleForTesting
  Future<void> debugRunNpcExtractionForTest(String characterId) {
    return _runNpcExtractionWhenIdle(characterId);
  }

  bool _shouldRunNpcExtraction(String characterId, DialogueHistory history) {
    final assistantMessages = history.messages
        .where((message) => message.role == ChatRole.assistant)
        .length;
    if (assistantMessages <= 0) {
      return false;
    }
    final lastCount = _lastNpcExtractionMessageCounts[characterId] ?? 0;
    if (assistantMessages - lastCount < 3) {
      return false;
    }
    final latest = history.messages.lastWhere(
      (message) => message.role == ChatRole.assistant,
      orElse: () => history.messages.last,
    );
    if (!_hasNpcExtractionSignal(latest.content)) {
      return false;
    }
    _lastNpcExtractionMessageCounts[characterId] = assistantMessages;
    return true;
  }

  bool _hasNpcExtractionSignal(String content) {
    if (content.trim().isEmpty) {
      return false;
    }
    final stateText = GameStateParser.stateBlockPattern
            .firstMatch(content)
            ?.group(1)
            ?.trim() ??
        '';
    if (stateText.contains('NPC更新') ||
        stateText.contains('NPC 更新') ||
        stateText.contains('NPC变化') ||
        stateText.contains('NPC 变化')) {
      return true;
    }
    return RegExp(
      r'(NPC|同桌|老师|班主任|店员|老板|医生|护士|警察|队长|少女|少年|男人|女人|女孩|男孩|学姐|学长|学妹|学弟|前辈|后辈|朋友|同伴)',
      caseSensitive: false,
    ).hasMatch(content);
  }

  Future<void> _loadCharacterState(String characterId) async {
    _historyCache[characterId] = await _store.loadDialogueHistory(characterId);
    _memoryCache[characterId] = await _store.loadCharacterMemory(characterId);
    var gameState = await _store.loadGameState(characterId);
    final gameplaySystem = _findCharacter(characterId)?.gameplaySystem;
    if (gameplaySystem != null) {
      final initialized = GameplayPatchEngine.initializeValues(
        gameplaySystem,
        gameState.customVariables,
      );
      final ownedMetrics = GameplayPatchEngine.removeClaimedLegacyMetrics(
        gameplaySystem,
        gameState.metrics,
      );
      if (jsonEncode(initialized) != jsonEncode(gameState.customVariables) ||
          !mapEquals(ownedMetrics, gameState.metrics)) {
        gameState = gameState.copyWith(
          metrics: ownedMetrics,
          customVariables: initialized,
        );
        await _store.saveGameState(gameState);
      }
    }
    _gameStateCache[characterId] = gameState;
    _mapStateCache[characterId] = await _store.loadMapState(characterId);
    await _ensureOpeningMessage(characterId);
  }

  Future<void> _ensureOpeningMessage(String characterId) async {
    final character = _findCharacter(characterId);
    if (character == null) {
      return;
    }

    final opening = _resolveOpeningMessage(character).trim();
    if (opening.isEmpty) {
      return;
    }

    final history = _historyCache[characterId] ??
        await _store.loadDialogueHistory(characterId);
    if (_shouldRefreshLegacyTutorialOpening(character, history)) {
      final legacyOpening = history.messages.single;
      final nextHistory = history.copyWith(messages: <ChatMessage>[
        legacyOpening.copyWith(
          content: opening,
          isSummarized: true,
          clearGameStateSnapshot: true,
          clearTokenEstimate: true,
          clearPromptReplayContent: true,
        ),
      ]);
      _historyCache[characterId] = nextHistory;
      await _store.saveDialogueHistory(nextHistory);
      return;
    }
    if (history.messages.isNotEmpty) {
      _historyCache[characterId] = history;
      return;
    }

    final openingMessage = ChatMessage(
      id: IdGenerator.message(),
      role: ChatRole.assistant,
      content: opening,
      timestamp: DateTime.now(),
      isSummarized: true,
    );
    final nextHistory = history.copyWith(messages: <ChatMessage>[
      openingMessage,
    ]);
    _historyCache[characterId] = nextHistory;
    await _store.saveDialogueHistory(nextHistory);
  }

  bool _shouldRefreshLegacyTutorialOpening(
    CharacterProfile character,
    DialogueHistory history,
  ) {
    if (!character.isTutorialDemo || history.messages.length != 1) {
      return false;
    }
    final message = history.messages.single;
    if (message.role != ChatRole.assistant || message.isBookmarked) {
      return false;
    }
    final content = message.content;
    return content.contains(legacyTutorialDemoName) ||
        (content.contains('NPC1') &&
            content.contains('NPC2') &&
            content.contains('NPC3'));
  }

  String _resolveOpeningMessage(CharacterProfile character) {
    final raw = character.openingMessage.trim();
    if (raw.isEmpty) {
      return '';
    }

    final userProfile = _findBoundUserProfile(character.id);
    final userName = userProfile?.name.trim();
    return raw
        .replaceAll(
            '{user}', userName == null || userName.isEmpty ? '你' : userName)
        .replaceAll(
            '{用户}', userName == null || userName.isEmpty ? '你' : userName)
        .replaceAll(
            '{player}', userName == null || userName.isEmpty ? '玩家' : userName);
  }

  Future<DialogueHistory> _ensureHistory(String characterId) async {
    if (_historyCache.containsKey(characterId)) {
      return _historyCache[characterId]!;
    }

    final history = await _store.loadDialogueHistory(characterId);
    _historyCache[characterId] = history;
    return history;
  }

  Future<CharacterMemory> _ensureMemory(String characterId) async {
    if (_memoryCache.containsKey(characterId)) {
      return _memoryCache[characterId]!;
    }

    final memory = await _store.loadCharacterMemory(characterId);
    _memoryCache[characterId] = memory;
    return memory;
  }

  Future<GameStateSnapshot> _ensureGameState(String characterId) async {
    if (_gameStateCache.containsKey(characterId)) {
      return _gameStateCache[characterId]!;
    }

    final state = await _store.loadGameState(characterId);
    _gameStateCache[characterId] = state;
    return state;
  }

  Future<MapWorldState> _ensureMapState(String characterId) async {
    if (_mapStateCache.containsKey(characterId)) {
      return _mapStateCache[characterId]!;
    }

    final state = await _store.loadMapState(characterId);
    _mapStateCache[characterId] = state;
    return state;
  }

  Future<void> _updateGameStateFromMessage(
    String characterId,
    String content, {
    bool gameplayPatchExpected = false,
    String? turnId,
  }) async {
    final previous = await _ensureGameState(characterId);
    var parsed = GameStateParser.parseFromMessage(
      characterId: characterId,
      content: content,
      previous: previous,
    );
    final character = _findCharacter(characterId);
    final patch = GameplayPatchParser.parseResult(content);
    if (character?.gameplaySystem != null &&
        (patch.found || gameplayPatchExpected)) {
      parsed = _applyGameplayPatchToState(
        character: character!,
        previousState: previous,
        state: parsed ?? previous,
        turnId: turnId,
        content: content,
        patchExpected: gameplayPatchExpected,
      );
    }
    if (parsed == null) {
      return;
    }

    _gameStateCache[characterId] = parsed;
    await _store.saveGameState(parsed);
    if (turnId != null) {
      final history = await _ensureHistory(characterId);
      final updated = history.copyWith(
          messages: history.messages
              .map((message) => message.id == turnId
                  ? message.copyWith(
                      gameStateSnapshot: _gameplaySnapshot(
                          parsed!, character?.gameplaySystem,
                          previousState: previous))
                  : message)
              .toList(growable: false));
      _historyCache[characterId] = updated;
      await _store.saveDialogueHistory(updated);
    }
    await _applyGameStateNpcUpdates(characterId, parsed);
  }

  Future<_TimelineRebuildResult> _rebuildTimelineStateFromHistory({
    required String characterId,
    required DialogueHistory history,
  }) async {
    final replay = _replayGameStateFromHistory(characterId, history);
    _gameStateCache[characterId] = replay.gameState;
    await _store.saveGameState(replay.gameState);
    await _rebuildTimelineAutoNpcs(
      characterId: characterId,
      states: replay.states,
    );
    return _TimelineRebuildResult(
      history: replay.history,
      gameState: replay.gameState,
    );
  }

  _TimelineReplayResult _replayGameStateFromHistory(
    String characterId,
    DialogueHistory history, {
    ({GameStateSnapshot state, GameplaySystem? system})? baselineOverride,
    GameplaySystem? finalSystemOverride,
  }) {
    final character = _findCharacter(characterId);
    final fallbackSystem = finalSystemOverride ?? character?.gameplaySystem;
    final baseline = baselineOverride ??
        _gameplayReplayBaseline(history.messages, characterId);
    var state = baseline.state;
    GameplaySystem? replaySystem = baseline.system;
    final states = <GameStateSnapshot>[];
    var changed = false;
    final messages = <ChatMessage>[];
    for (final message in history.messages) {
      if (message.role != ChatRole.assistant) {
        if (message.gameStateSnapshot != null) {
          changed = true;
          messages.add(message.copyWith(clearGameStateSnapshot: true));
        } else {
          messages.add(message);
        }
        continue;
      }
      final turnSystem = _gameplaySystemAtMessage(message, fallbackSystem);
      if (turnSystem != null) {
        state = _gameplayStateForDefinition(state, replaySystem, turnSystem);
        replaySystem = turnSystem;
      }
      var parsed = GameStateParser.parseFromMessage(
        characterId: characterId,
        content: message.content,
        previous: state,
      );
      final patch = GameplayPatchParser.parseResult(message.content);
      if (character?.gameplaySystem != null && patch.found) {
        parsed = _applyGameplayPatchToState(
          character: character!,
          previousState: state,
          state: parsed ?? state,
          turnId: message.id,
          systemOverride: _gameplaySystemAtMessage(message, fallbackSystem),
          content: message.content,
          patchExpected: false,
        );
      }
      if (parsed == null) {
        if (message.gameStateSnapshot != null) {
          changed = true;
          messages.add(message.copyWith(clearGameStateSnapshot: true));
        } else {
          messages.add(message);
        }
        continue;
      }
      state = _withStableReplayTimestamp(parsed, message);
      states.add(state);
      final snapshot = _gameplaySnapshot(
          state,
          character == null
              ? null
              : _gameplaySystemAtMessage(message, fallbackSystem),
          baseline: message.gameStateSnapshot?['gameplayBaseline']);
      if (jsonEncode(message.gameStateSnapshot) != jsonEncode(snapshot)) {
        changed = true;
      }
      messages.add(message.copyWith(gameStateSnapshot: snapshot));
    }
    final currentSystem = fallbackSystem;
    if (currentSystem != null) {
      state = _gameplayStateForDefinition(state, replaySystem, currentSystem);
    }
    return _TimelineReplayResult(
      history: changed ? history.copyWith(messages: messages) : history,
      gameState: state,
      states: states,
    );
  }

  GameStateSnapshot _withStableReplayTimestamp(
    GameStateSnapshot parsed,
    ChatMessage message,
  ) {
    final snapshot = message.gameStateSnapshot;
    if (snapshot != null) {
      try {
        final existing = GameStateSnapshot.fromJson(snapshot);
        if (existing.updatedAt
            .isAfter(DateTime.fromMillisecondsSinceEpoch(0))) {
          return parsed.copyWith(updatedAt: existing.updatedAt);
        }
      } catch (_) {
        // Damaged legacy snapshot; use the message timestamp below.
      }
    }
    return parsed.copyWith(updatedAt: message.timestamp);
  }

  GameStateSnapshot _applyGameplayPatchToState({
    required CharacterProfile character,
    required GameStateSnapshot previousState,
    required GameStateSnapshot state,
    required String content,
    required bool patchExpected,
    String? turnId,
    GameplaySystem? systemOverride,
  }) {
    final system = systemOverride ?? character.gameplaySystem;
    if (system == null) return state;
    return GameplayTurnEngine.apply(
      system: system,
      previousState: previousState,
      narrativeState: state,
      content: content,
      patchExpected: patchExpected,
      turnId: turnId,
    );
  }

  GameStateSnapshot _gameplayStateForDefinition(
    GameStateSnapshot state,
    GameplaySystem? before,
    GameplaySystem after,
  ) {
    if (before != null &&
        jsonEncode(before.toJson()) == jsonEncode(after.toJson())) {
      return state;
    }
    return state.copyWith(
      customVariables: before == null
          ? after.initialValues()
          : GameplaySystemDraft.preview(current: before, generated: after)
              .migrateValues(state.customVariables),
      gameplayRuntime: before == null
          ? state.gameplayRuntime
          : GameplaySystemDraft.preview(current: before, generated: after)
              .migrateRuntime(state.gameplayRuntime),
    );
  }

  Map<String, dynamic> _gameplaySnapshot(
    GameStateSnapshot state,
    GameplaySystem? system, {
    GameStateSnapshot? previousState,
    dynamic baseline,
  }) {
    if (baseline == null && previousState != null && system != null) {
      final messages = _historyFor(state.characterId).messages;
      for (final message in messages) {
        final saved = message.gameStateSnapshot?['gameplayBaseline'];
        if (saved is Map) {
          baseline = saved;
          break;
        }
      }
      if (baseline == null &&
          !messages.any((message) =>
              message.role == ChatRole.assistant &&
              message.gameStateSnapshot != null)) {
        baseline = {'state': previousState.toJson(), 'system': system.toJson()};
      }
    }
    return {
      ...state.toJson(),
      if (system != null) 'gameplaySystem': system.toJson(),
      if (baseline is Map) 'gameplayBaseline': baseline,
    };
  }

  ({GameStateSnapshot state, GameplaySystem? system}) _gameplayReplayBaseline(
    List<ChatMessage> messages,
    String characterId,
  ) {
    for (final message in messages) {
      final baseline = message.gameStateSnapshot?['gameplayBaseline'];
      if (baseline is! Map ||
          baseline['state'] is! Map ||
          baseline['system'] is! Map) {
        continue;
      }
      try {
        return (
          state: GameStateSnapshot.fromJson(
                  Map<String, dynamic>.from(baseline['state'] as Map))
              .copyWith(characterId: characterId),
          system: GameplaySystem.fromJson(
              Map<String, dynamic>.from(baseline['system'] as Map)),
        );
      } catch (_) {
        // Legacy histories can be replayed from their declared initial values.
      }
    }
    return (state: GameStateSnapshot.empty(characterId), system: null);
  }

  GameplaySystem? _gameplaySystemAtMessage(
      ChatMessage message, GameplaySystem? fallback) {
    final raw = message.gameStateSnapshot?['gameplaySystem'];
    if (raw is Map) {
      try {
        return GameplaySystem.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        // Old or damaged metadata still uses the existing compatibility path.
      }
    }
    return fallback;
  }

  Future<void> _rebuildTimelineAutoNpcs({
    required String characterId,
    required List<GameStateSnapshot> states,
  }) async {
    final protectedNpcIds = <String>{};
    final nextProfiles = <NpcProfile>[];
    var changed = false;
    for (final profile in _npcProfiles) {
      if (!_canTimelineReplayUpdateNpc(profile, characterId)) {
        protectedNpcIds.add(profile.id);
        nextProfiles.add(profile);
        continue;
      }
      final messages = await _ensureNpcMessages(profile.id);
      if (messages.isNotEmpty) {
        protectedNpcIds.add(profile.id);
        nextProfiles.add(profile);
        continue;
      }
      changed = true;
    }
    if (!changed && states.isEmpty) {
      return;
    }
    _npcProfiles
      ..clear()
      ..addAll(nextProfiles);
    for (final state in states) {
      await _applyGameStateNpcUpdates(
        characterId,
        state,
        includeProtectedProfiles: false,
        protectedNpcIds: protectedNpcIds,
        persist: false,
        updateGamification: false,
      );
    }
    _npcProfiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _store.saveNpcProfiles(_npcProfiles);
  }

  bool _canTimelineReplayUpdateNpc(NpcProfile profile, String characterId) {
    if (profile.sourceType != NpcProfileSource.auto ||
        profile.globalBinding ||
        profile.companionEnabled ||
        profile.hasReusableRoleCard ||
        profile.giftHistory.isNotEmpty) {
      return false;
    }
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    return profile.characterId == characterId ||
        profile.isBoundTo(characterId) ||
        (characterId == rootId && profile.characterId == rootId);
  }

  Future<int> _applyGameStateNpcUpdates(
    String characterId,
    GameStateSnapshot state, {
    bool includeProtectedProfiles = true,
    Set<String> protectedNpcIds = const <String>{},
    bool persist = true,
    bool updateGamification = true,
    bool emitProactiveMessages = false,
    String sourceTurnId = '',
  }) async {
    if (state.npcUpdates.isEmpty) {
      return 0;
    }

    var profilesChanged = false;
    var newNpcCount = 0;
    var deliveredMessageCount = 0;
    final deliveredNpcNames = <String>[];
    final now = _effectiveGameStateTimestamp(state);
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    final branchCutoff = _npcVisibilityCutoffForCharacter(characterId);
    final existingNames = <String, int>{};
    final existingIds = <String, int>{};
    final processedNpcIds = <String>{};
    final protectedNames = <String>{};
    for (var index = 0; index < _npcProfiles.length; index++) {
      final profile = _npcProfiles[index];
      if (!_isNpcProfileVisibleForCharacter(
        profile,
        characterId,
        rootId,
        branchCutoff: branchCutoff,
      )) {
        continue;
      }
      final normalizedName = _normalizeNpcName(profile.name);
      if (!includeProtectedProfiles &&
          (protectedNpcIds.contains(profile.id) ||
              !_canTimelineReplayUpdateNpc(profile, characterId))) {
        if (normalizedName.isNotEmpty) {
          protectedNames.add(normalizedName);
        }
        continue;
      }
      if (normalizedName.isNotEmpty) {
        existingNames[normalizedName] = index;
      }
      existingIds[profile.id] = index;
    }

    for (final update in state.npcUpdates) {
      final requestedId = update.npcId.trim();
      var index = requestedId.isEmpty ? null : existingIds[requestedId];
      final requestedName = update.name.trim();
      if (index == null && requestedName.isNotEmpty) {
        index = existingNames[_normalizeNpcName(requestedName)];
      }
      final name = requestedName.isNotEmpty
          ? requestedName
          : index == null
              ? ''
              : _npcProfiles[index].name.trim();
      if (name.isEmpty) {
        continue;
      }

      final normalizedName = _normalizeNpcName(name);
      var createdNew = false;
      if (index == null) {
        if (!includeProtectedProfiles &&
            protectedNames.contains(normalizedName)) {
          continue;
        }
        final impressionHistory = update.impression.trim().isEmpty
            ? const <NpcImpressionEntry>[]
            : <NpcImpressionEntry>[
                NpcImpressionEntry(
                  id: IdGenerator.generic('npc_imp'),
                  summary: normalizeNpcImpressionText(update.impression),
                  createdAt: now,
                ),
              ];
        final initialLifecycle =
            NpcLifecycleX.tryFromValue(update.lifecycle) ?? NpcLifecycle.active;
        final initialAffinity = initialLifecycle.allowsRelationshipChanges
            ? (update.affinity ?? update.affinityDelta ?? 0)
                .clamp(-100, 100)
                .toInt()
            : 0;
        final initialBond = _advanceNpcBondRoute(
          const NpcBondRoute(),
          impression: update.impression,
          affinity: initialAffinity,
          affinityDelta: initialAffinity,
          createdAt: now,
        );
        final profile = NpcProfile(
          id: IdGenerator.generic('npc'),
          characterId: characterId,
          name: name,
          description: update.description.trim(),
          impression: normalizeNpcImpressionText(update.impression),
          affinity: initialAffinity,
          lifecycle: initialLifecycle,
          createdAt: now,
          updatedAt: now,
          sourceType: NpcProfileSource.auto,
          companionEnabled: false,
          boundCharacterIds: <String>[characterId],
          impressionHistory: impressionHistory,
          bondRoute: initialBond,
        );
        _npcProfiles.add(profile);
        _npcMessagesCache[profile.id] = const <NpcChatMessage>[];
        existingNames[normalizedName] = _npcProfiles.length - 1;
        existingIds[profile.id] = _npcProfiles.length - 1;
        index = _npcProfiles.length - 1;
        createdNew = true;
        profilesChanged = true;
        newNpcCount += 1;
      }

      if (!processedNpcIds.add(_npcProfiles[index].id)) {
        continue;
      }

      final current = _npcProfiles[index];
      var next = current;
      final description = update.description.trim();
      final impression = normalizeNpcImpressionText(update.impression);
      final requestedLifecycle = NpcLifecycleX.tryFromValue(update.lifecycle);

      if (requestedLifecycle != null && requestedLifecycle != next.lifecycle) {
        final requiresReturnReason =
            !next.lifecycle.allowsMessages && requestedLifecycle.allowsMessages;
        if (!requiresReturnReason || update.lifecycleReason.trim().isNotEmpty) {
          next = next.copyWith(
            lifecycle: requestedLifecycle,
            updatedAt: now,
          );
          profilesChanged = true;
        }
      }

      int? resolvedAffinity;
      int? resolvedAffinityDelta;
      if (!createdNew && next.canChangeAffinity) {
        if (update.affinityDelta != null) {
          resolvedAffinityDelta = update.affinityDelta!.clamp(-12, 12).toInt();
        } else if (update.affinity != null) {
          resolvedAffinityDelta =
              (update.affinity! - current.affinity).clamp(-12, 12).toInt();
        }
        if (resolvedAffinityDelta != null) {
          resolvedAffinity = (current.affinity + resolvedAffinityDelta)
              .clamp(-100, 100)
              .toInt();
        }
      }

      if (description.isNotEmpty &&
          description != '无' &&
          description != current.description.trim()) {
        next = next.copyWith(description: description, updatedAt: now);
        profilesChanged = true;
      }

      if (!createdNew &&
          next.canChangeAffinity &&
          impression.isNotEmpty &&
          impression != '无' &&
          impression != current.impression.trim()) {
        next = next.copyWith(
          impression: impression,
          updatedAt: now,
          impressionHistory: <NpcImpressionEntry>[
            NpcImpressionEntry(
              id: IdGenerator.generic('npc_imp'),
              summary: impression,
              createdAt: now,
            ),
            ...next.impressionHistory,
          ].take(30).toList(growable: false),
        );
        profilesChanged = true;
      }

      if (resolvedAffinity != null && resolvedAffinity != current.affinity) {
        next = next.copyWith(affinity: resolvedAffinity, updatedAt: now);
        profilesChanged = true;
      }

      if (!next.globalBinding &&
          !next.isBoundTo(characterId) &&
          next.characterId != characterId) {
        next = next.copyWith(
          boundCharacterIds: _mergeNpcBoundCharacterIds(
            next.boundCharacterIds,
            <String>[characterId],
          ),
          updatedAt: now,
        );
        profilesChanged = true;
      }

      if (!createdNew &&
          next.canChangeAffinity &&
          (impression.isNotEmpty || resolvedAffinity != null)) {
        next = next.copyWith(
          bondRoute: _advanceNpcBondRoute(
            next.bondRoute,
            impression: impression,
            affinity: resolvedAffinity ?? next.affinity,
            affinityDelta: resolvedAffinityDelta,
            createdAt: now,
          ),
          updatedAt: now,
        );
        profilesChanged = true;
      }

      if (next.canChangeAffinity) {
        next = _npcRuntimeEngine
            .applyGameStateUpdate(
              profile: next,
              characterId: characterId,
              state: state,
              update: update,
              now: now,
            )
            .profile;
        profilesChanged = true;
      }

      _npcProfiles[index] = next;

      final proactiveMessage = update.proactiveMessage.trim();
      if (persist &&
          emitProactiveMessages &&
          next.canSendMessages &&
          NpcMessageClassifier.isDeliverableChatBubble(proactiveMessage)) {
        final turnKey = sourceTurnId.trim().isEmpty
            ? state.updatedAt.microsecondsSinceEpoch.toString()
            : sourceTurnId.trim();
        final batchId = 'npc_turn::$turnKey::${next.id}';
        final messages = await _ensureNpcMessages(next.id);
        final alreadyDelivered = messages.any(
          (message) =>
              message.batchId == batchId ||
              (message.role == NpcMessageRole.npc &&
                  message.content.trim() == proactiveMessage &&
                  now.difference(message.timestamp).abs() <
                      const Duration(minutes: 2)),
        );
        if (!alreadyDelivered) {
          final nextMessages = <NpcChatMessage>[
            ...messages,
            NpcChatMessage(
              id: IdGenerator.message(),
              npcId: next.id,
              role: NpcMessageRole.npc,
              content: proactiveMessage,
              timestamp: now,
              batchId: batchId,
            ),
          ];
          _npcMessagesCache[next.id] = nextMessages;
          await _store.saveNpcMessages(next.id, nextMessages);
          deliveredMessageCount += 1;
          deliveredNpcNames.add(next.name);
        }
      }
    }

    if (profilesChanged) {
      _npcProfiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (persist) {
        await _store.saveNpcProfiles(_npcProfiles);
      }
      final maxBondScore = _npcProfiles
          .where((profile) => profile.characterId == characterId)
          .fold<int>(
              0, (value, profile) => max(value, profile.bondRoute.score));
      if (maxBondScore > 0) {
        await _noteNpcBondScore(maxBondScore);
      }
    }
    if ((newNpcCount > 0 || deliveredMessageCount > 0) && updateGamification) {
      await _updateGamification(
        (state) {
          var next = state;
          if (newNpcCount > 0) {
            next = next.incrementStat('totalNpcProfilesCreated', newNpcCount);
          }
          if (deliveredMessageCount > 0) {
            next = next.incrementStat(
              'totalNpcProactiveMessages',
              deliveredMessageCount,
            );
          }
          next = next.setStatMax('maxNpcUnreadMessages', currentNpcUnreadCount);
          return next;
        },
        notify: false,
      );
    }
    if (deliveredNpcNames.isNotEmpty) {
      final names = deliveredNpcNames.toSet().take(2).join('、');
      _pendingNpcLetterNotice = '$names 给你发来了新消息。';
    }
    return deliveredMessageCount;
  }

  void _scheduleAmbientNpcMessage(
    String characterId, {
    required String sourceTurnId,
  }) {
    if (!_settings.canChat || sourceTurnId.trim().isEmpty) {
      return;
    }
    final timerKey = '$characterId::${sourceTurnId.trim()}';
    _npcProactiveTimers[timerKey]?.cancel();
    _npcProactiveTimers[timerKey] = Timer(
      const Duration(seconds: 2),
      () => unawaited(
        _runAmbientNpcMessageWhenIdle(
          characterId,
          sourceTurnId: sourceTurnId,
        ),
      ),
    );
  }

  Future<void> _runAmbientNpcMessageWhenIdle(
    String characterId, {
    required String sourceTurnId,
  }) async {
    if (_isSending ||
        _isMapGenerating ||
        _isGameplaySystemGenerating ||
        _activeNpcReplyingId != null) {
      _scheduleAmbientNpcMessage(
        characterId,
        sourceTurnId: sourceTurnId,
      );
      return;
    }
    final timerKey = '$characterId::${sourceTurnId.trim()}';
    _npcProactiveTimers.remove(timerKey)?.cancel();
    if (_generatingNpcProactiveCharacterIds.contains(characterId) ||
        !_settings.canChat) {
      return;
    }

    final character = _findCharacter(characterId);
    if (character == null) {
      return;
    }
    final history = await _ensureHistory(characterId);
    final assistantTurns = history.messages
        .where((message) =>
            message.role == ChatRole.assistant &&
            message.content.trim().isNotEmpty)
        .length;
    if (assistantTurns == 0 || assistantTurns % 3 != 0) {
      return;
    }

    final gameState = await _ensureGameState(characterId);
    final currentUpdateIds = gameState.npcUpdates
        .map((update) => update.npcId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final currentUpdateNames = gameState.npcUpdates
        .map((update) => _normalizeNpcName(update.name))
        .where((name) => name.isNotEmpty)
        .toSet();
    final candidates = worldNpcProfilesForCharacter(characterId)
        .where((profile) => profile.canSendMessages)
        .map((profile) {
      var score = profile.affinity;
      if (profile.companionEnabled) score += 80;
      if (currentUpdateIds.contains(profile.id) ||
          currentUpdateNames.contains(_normalizeNpcName(profile.name))) {
        score += 160;
      }
      return (profile: profile, score: score);
    }).toList(growable: false)
      ..sort((left, right) {
        final scoreOrder = right.score.compareTo(left.score);
        return scoreOrder != 0
            ? scoreOrder
            : right.profile.updatedAt.compareTo(left.profile.updatedAt);
      });

    NpcProfile? selected;
    List<NpcChatMessage> selectedMessages = const <NpcChatMessage>[];
    final ambientBatchId = 'npc_ambient::$sourceTurnId';
    for (final candidate in candidates) {
      final messages = await _ensureNpcMessages(candidate.profile.id);
      if (messages.any((message) => message.batchId == ambientBatchId)) {
        return;
      }
      if (messages.isNotEmpty && messages.last.role == NpcMessageRole.npc) {
        continue;
      }
      selected = candidate.profile;
      selectedMessages = messages;
      break;
    }
    if (selected == null) {
      return;
    }
    final selectedNpc = selected;

    _generatingNpcProactiveCharacterIds.add(characterId);
    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _npcLetterSystemPrompt,
        userPrompt: _buildNpcLetterPrompt(
          character: character,
          npc: selectedNpc,
          history: history,
          messages: selectedMessages,
          useDailyFreeLetter: false,
          sourceLabel: '主线回合后自然联系',
        ),
        temperature: 0.68,
        topP: 0.92,
      );
      final bubbles = _parseNpcLetterMessages(raw).take(3).toList();
      final latestProfile = npcProfileById(selectedNpc.id);
      if (bubbles.isEmpty ||
          latestProfile == null ||
          !latestProfile.canSendMessages) {
        return;
      }
      final messages = await _ensureNpcMessages(selectedNpc.id);
      if (messages.any((message) => message.batchId == ambientBatchId) ||
          (messages.isNotEmpty && messages.last.role == NpcMessageRole.npc)) {
        return;
      }
      final now = DateTime.now();
      final nextMessages = <NpcChatMessage>[
        ...messages,
        ...bubbles.map(
          (content) => NpcChatMessage(
            id: IdGenerator.message(),
            npcId: selectedNpc.id,
            role: NpcMessageRole.npc,
            content: content,
            timestamp: now,
            batchId: ambientBatchId,
          ),
        ),
      ];
      _npcMessagesCache[selectedNpc.id] = nextMessages;
      await _store.saveNpcMessages(selectedNpc.id, nextMessages);
      _touchNpcProfile(latestProfile);
      await _store.saveNpcProfiles(_npcProfiles);
      await _updateGamification(
        (state) => state
            .incrementStat('totalNpcProactiveMessages', bubbles.length)
            .setStatMax('maxNpcUnreadMessages', currentNpcUnreadCount),
        notify: false,
      );
      _pendingNpcLetterNotice = '${selectedNpc.name} 给你发来了新消息。';
      notifyListeners();
    } catch (_) {
      // Ambient contact is optional and never invalidates the committed turn.
    } finally {
      _generatingNpcProactiveCharacterIds.remove(characterId);
    }
  }

  @visibleForTesting
  Future<void> debugRunAmbientNpcMessageForTest(
    String characterId, {
    required String sourceTurnId,
  }) {
    return _runAmbientNpcMessageWhenIdle(
      characterId,
      sourceTurnId: sourceTurnId,
    );
  }

  Future<void> _applyMapMovementNpcMessages(
    String characterId,
    MapWorldState state,
  ) async {
    final candidates = state.npcMovements
        .map(_mapMovementToNpcMessageDraft)
        .whereType<_MapNpcMessageDraft>()
        .toList(growable: false);
    if (candidates.isEmpty) {
      return;
    }

    var savedAny = false;
    for (final draft in candidates) {
      final npcIndex = _findVisibleNpcIndexByName(characterId, draft.name);
      if (npcIndex == -1) {
        continue;
      }
      final npc = _npcProfiles[npcIndex];
      if (!npc.canSendMessages) {
        continue;
      }
      final messages = await _ensureNpcMessages(npc.id);
      if (messages.any((message) =>
          message.role == NpcMessageRole.npc &&
          message.content.trim() == draft.message)) {
        continue;
      }
      final now = DateTime.now();
      final batchId = IdGenerator.generic('map_npc_batch');
      final nextMessages = <NpcChatMessage>[
        ...messages,
        NpcChatMessage(
          id: IdGenerator.message(),
          npcId: npc.id,
          role: NpcMessageRole.npc,
          content: draft.message,
          timestamp: now,
          batchId: batchId,
        ),
      ];
      _npcMessagesCache[npc.id] = nextMessages;
      await _store.saveNpcMessages(npc.id, nextMessages);
      _npcProfiles[npcIndex] = npc.copyWith(updatedAt: now);
      savedAny = true;
    }

    if (savedAny) {
      _npcProfiles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _store.saveNpcProfiles(_npcProfiles);
      await _updateGamification(
        (state) =>
            state.setStatMax('maxNpcUnreadMessages', currentNpcUnreadCount),
        notify: false,
      );
    }
  }

  int _findVisibleNpcIndexByName(String characterId, String name) {
    final normalized = _normalizeNpcName(name);
    if (normalized.isEmpty) {
      return -1;
    }
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    final branchCutoff = _npcVisibilityCutoffForCharacter(characterId);
    for (var index = 0; index < _npcProfiles.length; index++) {
      final profile = _npcProfiles[index];
      if (!_isNpcProfileVisibleForCharacter(
        profile,
        characterId,
        rootId,
        branchCutoff: branchCutoff,
      )) {
        continue;
      }
      if (_normalizeNpcName(profile.name) == normalized) {
        return index;
      }
    }
    return -1;
  }

  _MapNpcMessageDraft? _mapMovementToNpcMessageDraft(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    final hasActiveContact = RegExp(
      r'(主动|向你|对你|联系你|发来|喊你|叫住你|搭话|私聊|来信|发消息|传讯|呼叫)',
    ).hasMatch(text);
    if (!hasActiveContact) {
      return null;
    }
    final bracketMatch = RegExp(r'【([^】]+)】').firstMatch(text);
    final nameMatch = RegExp(
      r'^(?:NPC[:：])?\s*([^【\[:：\s，,]{1,12}?)(?=(?:正在|停在|停留在|位于|在|向你|对你|发来|主动|[:：，,]))',
    ).firstMatch(text);
    final name = (bracketMatch?.group(1) ?? nameMatch?.group(1) ?? '').trim();
    var message = text;
    if (bracketMatch != null) {
      message = text.substring(bracketMatch.end);
    } else if (nameMatch != null) {
      message = text.substring(nameMatch.end);
    }
    message = message.replaceFirst(RegExp(r'^[：:，,\s]+'), '').trim();
    final directMessage = RegExp(
      r'(?:主动(?:向你|对你)?(?:搭话|喊话|联系你|发消息)?|向你(?:搭话|喊话|说)|对你(?:说|喊话)|发来(?:消息|私信)?)[：:]\s*(.+)$',
    ).firstMatch(message);
    if (directMessage != null) {
      message = directMessage.group(1)?.trim() ?? message;
    } else {
      message = message
          .replaceFirst(
            RegExp(r'^(?:正在|停在|停留在|位于|在)[^，,。；;：:]{0,30}[，,]?\s*'),
            '',
          )
          .replaceFirst(
            RegExp(r'^主动(?:向你|对你)?(?:搭话|喊话|联系你|发消息)?[：:，,]?\s*'),
            '',
          )
          .trim();
    }
    if (name.isEmpty ||
        !NpcMessageClassifier.isDeliverableChatBubble(message)) {
      return null;
    }
    return _MapNpcMessageDraft(name: name, message: message);
  }

  DateTime _effectiveGameStateTimestamp(GameStateSnapshot state) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return state.updatedAt.isAfter(epoch) ? state.updatedAt : DateTime.now();
  }

  Future<List<NpcChatMessage>> _ensureNpcMessages(String npcId) async {
    if (_npcMessagesCache.containsKey(npcId)) {
      return _npcMessagesCache[npcId]!;
    }

    final messages = await _store.loadNpcMessages(npcId);
    _npcMessagesCache[npcId] = messages;
    return messages;
  }

  DateTime _npcThreadReadAt(String npcId, {String? characterId}) {
    final raw = _gamification.npcInboxReadAt[_npcThreadReadKey(npcId)] ??
        (characterId == null
            ? null
            : _gamification.npcInboxReadAt[characterId]);
    return DateTime.tryParse(raw ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _npcThreadReadKey(String npcId) => 'npc_thread::$npcId';

  Future<String?> _generateNpcLetter({
    required bool useDailyFreeLetter,
  }) async {
    final character = currentCharacter;
    if (character == null) {
      return '请先选择一个 AI 角色。';
    }
    if (!_settings.canChat) {
      return '请先在设置页填好 API 地址、密钥和模型名称。';
    }
    if (_isSending) {
      return '当前还有回复正在生成，请稍等。';
    }

    await loadCurrentNpcThreads();
    final npcs = currentWorldNpcProfiles
        .where((profile) => profile.canSendMessages)
        .toList(growable: false);
    if (npcs.isEmpty) {
      return '当前角色还没有 NPC，先推进剧情或手动创建一个 NPC。';
    }

    final localNpcs = npcs
        .where((profile) => profile.characterId == character.id)
        .toList(growable: false);
    final pool = localNpcs.isEmpty ? npcs : localNpcs;
    final npc = pool[Random().nextInt(pool.length)];
    final history = await _ensureHistory(character.id);
    final npcMessages = await _ensureNpcMessages(npc.id);
    _isSending = true;
    notifyListeners();
    try {
      final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt: _npcLetterSystemPrompt,
        userPrompt: _buildNpcLetterPrompt(
          character: character,
          npc: npc,
          history: history,
          messages: npcMessages,
          useDailyFreeLetter: useDailyFreeLetter,
        ),
        temperature: 0.72,
        topP: 0.95,
      );

      final letters = _parseNpcLetterMessages(raw);
      if (letters.isEmpty) {
        return 'NPC 来信生成失败：模型没有返回可保存的消息。';
      }

      final now = DateTime.now();
      final batchId = IdGenerator.generic('npc_letter_batch');
      final nextMessages = <NpcChatMessage>[
        ...npcMessages,
        ...letters.map(
          (content) => NpcChatMessage(
            id: IdGenerator.message(),
            npcId: npc.id,
            role: NpcMessageRole.npc,
            content: content,
            timestamp: now,
            batchId: batchId,
          ),
        ),
      ];
      _npcMessagesCache[npc.id] = nextMessages;
      await _store.saveNpcMessages(npc.id, nextMessages);
      _touchNpcProfile(npc);
      await _store.saveNpcProfiles(_npcProfiles);
      await _updateGamification(
        (state) => state
            .incrementStat('totalNpcLetters')
            .setStatMax('maxNpcUnreadMessages', currentNpcUnreadCount),
        notify: false,
      );
      _pendingNpcLetterNotice = '${npc.name} 给你发来了新消息。';
      return null;
    } on LlmApiException catch (error) {
      return error.message;
    } catch (error) {
      return 'NPC 来信生成失败：$error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  String _buildNpcLetterPrompt({
    required CharacterProfile character,
    required NpcProfile npc,
    required DialogueHistory history,
    required List<NpcChatMessage> messages,
    required bool useDailyFreeLetter,
    String sourceLabel = '',
  }) {
    final recentMessages = history.messages.length > 16
        ? history.messages.sublist(history.messages.length - 16)
        : history.messages;
    final transcript = _formatTranscript(recentMessages);
    final npcTranscript = _formatNpcTranscript(
      messages.length > 12 ? messages.sublist(messages.length - 12) : messages,
      npcName: npc.name,
    );
    final worldBooks = _formatWorldBooksForPrompt(character.id);

    return '''
任务：生成一封 NPC 主动来信。
来源：${sourceLabel.trim().isNotEmpty ? sourceLabel.trim() : useDailyFreeLetter ? '每日随机来信' : 'NPC 来信券'}

当前 AI 角色：${character.name}
角色简介：
${character.visibleBlurb}

世界书：
$worldBooks

来信 NPC：
姓名：${npc.name}
简介：${npc.description.trim().isEmpty ? '暂无。' : npc.description.trim()}
角色卡：${npc.roleCard.trim().isEmpty ? '暂无完整角色卡。' : npc.roleCard.trim()}
当前印象：${npc.impression.trim().isEmpty ? '暂无明确印象。' : npc.impression.trim()}
生命周期：${npc.lifecycle.label}

主线最近剧情：
$transcript

NPC 私聊最近记录：
${npcTranscript.trim().isEmpty ? '暂无。' : npcTranscript}

请让这个 NPC 主动发来 1-3 条手机聊天气泡。必须自然、短一点、像真的临时想起用户角色。
不要推进主线回合，不要制造重大事件，不要写旁白。不要写“等待回复中”“明日将收到来信”“计划表白”等状态，只能写 NPC 真的会发出的聊天原话。
''';
  }

  List<String> _parseNpcLetterMessages(String raw) {
    final cleaned = _stripJsonFence(raw).trim();
    if (cleaned.isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) {
        final messages = decoded['messages'] ?? decoded['letters'];
        if (messages is List) {
          return _normalizeNpcBubbleMessages(
            messages.map((item) => item.toString()),
          );
        }
        final message = decoded['message'] ?? decoded['content'];
        if (message != null) {
          return _normalizeNpcBubbleMessages(<String>[message.toString()]);
        }
      }
    } catch (_) {
      return _normalizeNpcBubbleMessages(<String>[cleaned]);
    }
    return _normalizeNpcBubbleMessages(<String>[cleaned]);
  }

  static const String _npcRoleCardSystemPrompt = '''
你是中文文字游戏 App 的 NPC 角色卡整理员。
你的任务是把一个 NPC 整理成“可复用 NPC 角色卡”，只补全干净人设，不是生成新剧情、新世界、告别信或任务线。

只输出 JSON，不要 Markdown，不要解释。
JSON 格式：
{
  "name": "NPC名字",
  "description": "一句话简介，80字以内",
  "roleCard": "完整角色卡，只包含：姓名/称呼、一句话简介、外貌气质、性格底色、说话风格、行动倾向、与玩家互动边界、跨世界适配规则、需要保持一致的核心事实，500-1000字",
  "impression": "TA当前对玩家角色的印象，100-220字",
  "affinity": 0
}

要求：
- 角色卡必须让 NPC 能作为“另一个主角/同行者/重要角色”在别的世界自主行动。
- 必须明确：玩家只操控玩家自己的角色；这个 NPC 自己行动、表达意见、推动支线，但不能替玩家做决定。
- 可以合理补全人设细节，但不能推翻已有关系和性格。
- 明确去掉或泛化原世界专属内容：原世界世界观、当前剧情事件、学校/朝代/地点等强绑定背景、原世界任务线。
- 输出必须是简体中文。
''';

  static const String _npcMigrationManifestSchemaHint = '''
{
  "schemaVersion": 1,
  "archive": {
    "summary": "前尘概述",
    "coreIdentity": "NPC核心身份",
    "appearance": "外貌与辨识点",
    "personality": "性格底色与矛盾点",
    "speechStyle": "说话风格",
    "relationshipHistory": "关系如何发展到现在",
    "keyEvents": ["关键共同经历"],
    "unresolvedThreads": ["未完成的约定或冲突"],
    "continuityFacts": ["绝不能改写的事实"],
    "riskNotes": ["容易写崩的注意点"]
  },
  "memoryPolicy": {
    "mode": "full/fragments/echo",
    "runtimeFacts": ["普通回合允许知道的事实"],
    "echoSeeds": ["只能由前尘回声触发的单个片段"],
    "forbiddenRecall": ["普通回合禁止主动说出的信息"]
  },
  "relationship": {
    "mode": "关系路线枚举",
    "startingState": "新世界初始关系",
    "hardConstraints": ["关系硬约束"],
    "goals": ["可长期推进的关系目标"]
  },
  "keepsake": {
    "name": "信物名",
    "description": "外观",
    "origin": "来历",
    "emotionalMeaning": "关系意义",
    "useEffectPrompt": "触发方向"
  },
  "tasks": [
    {"title": "任务名", "description": "具体行动条件", "stage": "阶段"}
  ]
}
''';

  static const String _npcMigrationManifestSystemPrompt = '''
你是文字游戏 App 的 NPC 迁徙档案整理器。根据输入的结构化生涯快照，生成唯一可信的 MigrationManifest。

只输出一个可解析的 JSON 对象，不要 Markdown 围栏、解释、注释或额外文字。
字段名和层级必须严格遵守用户提供的 JSON schema。

规则：
- 只依据快照整理和谨慎补全，不得推翻已有 NPC 身份、性格、关系和明确事件。
- memoryPolicy.mode 与 relationship.mode 必须原样使用用户指定的枚举值。
- full 模式可在 runtimeFacts 保留筛选后的关键事实。
- fragments 模式的 runtimeFacts 只能有 3-5 条不完整、带不确定感的片段。
- echo 模式的 runtimeFacts 必须为空；具体旧世界事实只能放进 echoSeeds。
- echoSeeds 每项只描述一个片段，方便程序每次只注入一条。
- tasks 最多 5 项，不要生成 id、时间和 completed。
- 不要把 App 功能词写进设定；全部内容使用简体中文。
''';

  static const String _npcMigrationBundleSchemaHint = '''
{
  "schemaVersion": 1,
  "worldBook": {
    "title": "世界书标题",
    "content": "只含长期世界规则、允许记住的事实和互动边界"
  },
  "character": {
    "name": "新模拟器名称",
    "description": "40-80字简介",
    "openingMessage": "首次进入时的完整开场白",
    "hiddenPrompt": "可为空",
    "sections": {
      "simulatorOverview": "新世界与模拟器定位",
      "npcProfile": "NPC身份、外貌、性格和说话方式",
      "userRelationship": "新世界初始关系与互动张力",
      "coreLoop": "长期互动循环",
      "stateSystem": "状态、事件、任务和关系进展维度",
      "styleRules": "叙事视角与文风",
      "firstRoundRules": "第一回合边界"
    }
  }
}
''';

  static const String _npcMigrationBundleSystemPrompt = '''
你是中文文字游戏的世界书和角色设定生成器。

只输出一个可解析的 JSON 对象，不要 Markdown 围栏、解释、注释或额外文字。字段名和层级必须严格遵守用户提供的 JSON schema。

规则：
- 世界书只写长期世界规则、程序允许提供的记忆事实和关系边界，不重复整张角色卡。
- 角色 sections 只写身份、语气、行为、关系互动和玩法，不复制世界书，不重复 App 的输出协议。
- 如果 outputKind 是 worldBookOnly，character 必须为 null。
- 如果 outputKind 是 newWorld，character 必须完整；openingMessage 包含可阅读正文、简短 HTML 状态卡、[GAME_STATE] 和 [CHOICES]。
- 不得补写输入中没有提供的旧世界事实，不得提及“迁徙功能”“被用户带走”“旧 App 世界”。
- 全部内容使用简体中文。
''';

  static const String _npcMigrationJsonRepairSystemPrompt = '''
你是 JSON 修复器。根据解析失败的模型输出和目标 schema，只修复 JSON 结构、字段类型与缺失的必填容器。
不得新增原文没有表达的剧情事实。只输出一个可解析的 JSON 对象，不要 Markdown、解释或注释。
''';

  static const String _npcFarewellDraftSystemPrompt = '''
你是中文文字游戏 App 的“旧世界告别回合”导演。

你的任务不是把 NPC 迁徙到新世界，而是生成“迁徙前最后一场旧世界告别”。
这场告别必须尊重已有剧情、NPC 印象、羁绊路线和用户与 NPC 的关系。

只输出 JSON，不要 Markdown，不要解释。

JSON 格式：
{
  "title": "告别场景标题",
  "narrative": "一段可阅读的告别剧情，800-1400字",
  "htmlPanel": "一个简短 HTML 状态卡，展示地点、情绪、关系张力和旧世界倒计时",
  "choices": [
    {
      "id": "A",
      "label": "用户看到的行动选项",
      "actionPrompt": "用户选择后要写入迁徙档案的行动含义",
      "emotionalTag": "不舍/释然/私奔/未说出口/约定/决裂/守护等"
    }
  ],
  "emotionalSummary": "这场告别的情绪总结，100-180字",
  "continuityFacts": ["后续迁徙必须记住的事实"]
}

要求：
- 不要替用户做最终决定。
- 不要把 NPC 写崩。
- 不要强行恋爱化，关系类型必须参考羁绊路线。
- 告别可以温柔、痛苦、克制、仓促或决绝，但必须有可选择余地。
- 所有内容必须是简体中文。
''';

  static const String _npcMigrationRevisionSystemPrompt = '''
你是 NPC 迁徙档案重修助手。

用户只要求重修指定部分。

要求：
- 不要改动未要求改动的事实。
- 不要推翻源 NPC。
- 不要改变关系路线，除非用户明确要求。
- 输出新内容本身，不要解释。
''';

  String _buildNpcMigrationSourceSnapshot({
    required CharacterProfile sourceCharacter,
    required NpcProfile npc,
    required List<NpcChatMessage> messages,
    required GameStateSnapshot gameState,
    required String worldType,
    required String inspiration,
    required String narrativeVoice,
    required String memoryMode,
    required NpcFarewellOutcome farewellOutcome,
    required String relationshipLock,
  }) {
    final mainHistory = _historyCache[sourceCharacter.id];
    final selectedMain = _selectNpcMigrationMainMessages(
      mainHistory?.messages ?? const <ChatMessage>[],
      npcName: npc.name,
    );
    final selectedPrivate = _selectNpcMigrationPrivateMessages(messages);
    final npcJson = Map<String, dynamic>.from(npc.toJson())
      ..remove('avatarDataUri');
    final sourceWorldBooks = _worldBooksForCharacter(
      sourceCharacter.id,
      contextMessages: selectedMain,
      gameState: gameState,
      runtimeAddendum: '',
    )
        .take(4)
        .map(
          (entry) => <String, dynamic>{
            'title': entry.title,
            'content': _clipPromptText(entry.content, 2400),
          },
        )
        .toList(growable: false);
    final snapshot = <String, dynamic>{
      'schemaVersion': 1,
      'sourceWorld': <String, dynamic>{
        'id': sourceCharacter.id,
        'name': sourceCharacter.name,
        'summary': sourceCharacter.visibleBlurb,
        'currentGameState': gameState.toJson(),
        'relevantWorldBooks': sourceWorldBooks,
      },
      'npc': npcJson,
      'selectedMainScenes': selectedMain
          .map(
            (message) => <String, dynamic>{
              'role': message.role.name,
              'content': _clipPromptText(message.content, 1600),
              'timestamp': message.timestamp.toIso8601String(),
            },
          )
          .toList(growable: false),
      'selectedPrivateMessages': selectedPrivate
          .map(
            (message) => <String, dynamic>{
              'role': message.role.name,
              'content': _clipPromptText(message.content, 1200),
              'timestamp': message.timestamp.toIso8601String(),
            },
          )
          .toList(growable: false),
      'farewellOutcome': farewellOutcome.toJson(),
      'userPlan': <String, dynamic>{
        'worldType': worldType.trim().isEmpty ? '只属于你们的新世界' : worldType.trim(),
        'inspiration': inspiration.trim(),
        'narrativeVoice': narrativeVoice,
        'memoryMode': NpcMigrationMemoryMode.normalize(memoryMode),
        'relationshipMode':
            NpcMigrationRelationshipLock.normalize(relationshipLock),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(snapshot);
  }

  List<ChatMessage> _selectNpcMigrationMainMessages(
    List<ChatMessage> messages, {
    required String npcName,
  }) {
    if (messages.isEmpty) return const <ChatMessage>[];
    final selected = <String, ChatMessage>{};
    for (final message in messages.take(4)) {
      selected[message.id] = message;
    }
    final normalizedName = npcName.trim().toLowerCase();
    if (normalizedName.isNotEmpty) {
      for (final message in messages.reversed) {
        if (message.content.toLowerCase().contains(normalizedName)) {
          selected[message.id] = message;
        }
        if (selected.length >= 16) break;
      }
    }
    for (final message in messages.reversed.take(12)) {
      selected[message.id] = message;
    }
    final result = selected.values.toList(growable: false)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result.length <= 20 ? result : result.sublist(result.length - 20);
  }

  List<NpcChatMessage> _selectNpcMigrationPrivateMessages(
    List<NpcChatMessage> messages,
  ) {
    if (messages.length <= 20) return List<NpcChatMessage>.from(messages);
    final selected = <String, NpcChatMessage>{};
    for (final message in messages.take(4)) {
      selected[message.id] = message;
    }
    for (final message in messages.reversed.take(16)) {
      selected[message.id] = message;
    }
    return selected.values.toList(growable: false)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  String _buildNpcMigrationManifestPrompt({
    required String sourceSnapshot,
    required String memoryMode,
    required String relationshipLock,
    required bool generateKeepsake,
    required bool generateTasks,
  }) {
    return '''
【目标 JSON schema】
$_npcMigrationManifestSchemaHint

【用户锁定选项】
memoryPolicy.mode=${NpcMigrationMemoryMode.normalize(memoryMode)}
relationship.mode=${NpcMigrationRelationshipLock.normalize(relationshipLock)}
generateKeepsake=$generateKeepsake
generateTasks=$generateTasks

若 generateKeepsake=false，keepsake 返回空字段对象。
若 generateTasks=false，tasks 返回空数组。

【NPC 生涯快照】
$sourceSnapshot
''';
  }

  Future<_NpcMigrationJsonResult> _runNpcMigrationStructuredTask({
    required String stageLabel,
    required String systemPrompt,
    required String userPrompt,
    required String schemaHint,
    required bool Function(Map<String, dynamic>) validator,
    required double temperature,
    required double topP,
  }) async {
    final raw = await _apiClient.runUtilityTask(
      settings: _settings,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      topP: topP,
    );
    final decoded = _decodeJsonObject(raw);
    if (decoded.isNotEmpty && validator(decoded)) {
      return _NpcMigrationJsonResult(data: decoded);
    }
    _npcMigrationBuildStage = '$stageLabel返回格式异常，正在修复 JSON';
    notifyListeners();
    final repairedRaw = await _apiClient.runUtilityTask(
      settings: _settings,
      systemPrompt: _npcMigrationJsonRepairSystemPrompt,
      userPrompt: '''
【目标 schema】
$schemaHint

【原始输出】
$raw
''',
      temperature: 0.12,
      topP: 0.75,
    );
    final repaired = _decodeJsonObject(repairedRaw);
    if (repaired.isEmpty || !validator(repaired)) {
      throw FormatException('$stageLabel没有返回符合 schema 的 JSON，请重试。');
    }
    return _NpcMigrationJsonResult(data: repaired, repaired: true);
  }

  bool _isValidNpcMigrationManifestJson(Map<String, dynamic> data) {
    final archive = data['archive'];
    final memory = data['memoryPolicy'];
    final relationship = data['relationship'];
    final keepsake = data['keepsake'];
    final tasks = data['tasks'];
    if (archive is! Map ||
        memory is! Map ||
        relationship is! Map ||
        keepsake is! Map ||
        tasks is! List) {
      return false;
    }
    const archiveTextKeys = <String>[
      'summary',
      'coreIdentity',
      'appearance',
      'personality',
      'speechStyle',
      'relationshipHistory',
    ];
    const archiveListKeys = <String>[
      'keyEvents',
      'unresolvedThreads',
      'continuityFacts',
      'riskNotes',
    ];
    const memoryListKeys = <String>[
      'runtimeFacts',
      'echoSeeds',
      'forbiddenRecall',
    ];
    const relationshipListKeys = <String>['hardConstraints', 'goals'];
    const keepsakeTextKeys = <String>[
      'name',
      'description',
      'origin',
      'emotionalMeaning',
      'useEffectPrompt',
    ];
    return archiveTextKeys.every((key) => archive[key] is String) &&
        archiveListKeys.every((key) => archive[key] is List) &&
        memory['mode'] is String &&
        memoryListKeys.every((key) => memory[key] is List) &&
        relationship['mode'] is String &&
        relationship['startingState'] is String &&
        relationshipListKeys.every((key) => relationship[key] is List) &&
        keepsakeTextKeys.every((key) => keepsake[key] is String) &&
        tasks.every(
          (task) =>
              task is Map &&
              task['title'] is String &&
              task['description'] is String &&
              task['stage'] is String,
        );
  }

  bool _isValidNpcMigrationBundleJson(
    Map<String, dynamic> data, {
    required bool requireCharacter,
  }) {
    final worldBook = data['worldBook'];
    if (worldBook is! Map ||
        worldBook['title'] is! String ||
        worldBook['content'] is! String ||
        (worldBook['content']?.toString().trim().isEmpty ?? true)) {
      return false;
    }
    if (!requireCharacter) {
      return data.containsKey('character') && data['character'] == null;
    }
    final character = data['character'];
    if (character is! Map ||
        character['name'] is! String ||
        character['description'] is! String ||
        character['openingMessage'] is! String ||
        character['hiddenPrompt'] is! String ||
        (character['name']?.toString().trim().isEmpty ?? true)) {
      return false;
    }
    final sections = character['sections'];
    if (sections is! Map) return false;
    const sectionKeys = <String>[
      'simulatorOverview',
      'npcProfile',
      'userRelationship',
      'coreLoop',
      'stateSystem',
      'styleRules',
      'firstRoundRules',
    ];
    return sectionKeys.every((key) => sections[key] is String);
  }

  NpcMigrationManifest _parseNpcMigrationManifest(
    Map<String, dynamic> data, {
    required NpcProfile npc,
    required String memoryMode,
    required String relationshipLock,
    required bool generateKeepsake,
    required bool generateTasks,
    required bool repaired,
  }) {
    final parsed = NpcMigrationManifest.fromJson(data);
    final warnings = <String>[
      if (repaired) '前尘档案经过一次 JSON 格式修复。',
    ];
    var archive = parsed.archive;
    if (archive.summary.trim().isEmpty) {
      warnings.add('前尘概述使用了本地保底内容。');
      archive = archive.copyWith(
        summary: npc.impression.trim().isEmpty
            ? '${npc.name}与用户在旧世界有尚待延续的关系。'
            : npc.impression.trim(),
      );
    }
    if (archive.coreIdentity.trim().isEmpty) {
      warnings.add('核心身份使用了 NPC 现有简介。');
      archive = archive.copyWith(
        coreIdentity: npc.description.trim().isEmpty
            ? '${npc.name}是旧世界中与用户关系密切的重要人物。'
            : npc.description.trim(),
      );
    }

    final normalizedMemory = NpcMigrationMemoryMode.normalize(memoryMode);
    var runtimeFacts = parsed.memoryPolicy.runtimeFacts
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    var echoSeeds = parsed.memoryPolicy.echoSeeds
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    final forbidden = parsed.memoryPolicy.forbiddenRecall
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: true);
    if (normalizedMemory == NpcMigrationMemoryMode.echo) {
      runtimeFacts = const <String>[];
      if (!forbidden.any((item) => item.contains('旧世界'))) {
        forbidden.add('普通回合不得主动识别、复述或推断任何具体旧世界事实。');
      }
    } else if (normalizedMemory == NpcMigrationMemoryMode.fragments) {
      runtimeFacts = runtimeFacts.take(5).toList(growable: false);
    } else {
      runtimeFacts = runtimeFacts.take(10).toList(growable: false);
    }
    if (runtimeFacts.isEmpty &&
        normalizedMemory != NpcMigrationMemoryMode.echo) {
      runtimeFacts = <String>[
        ...archive.continuityFacts,
        ...archive.keyEvents,
      ]
          .take(normalizedMemory == NpcMigrationMemoryMode.fragments ? 3 : 8)
          .toList();
      if (runtimeFacts.isEmpty) {
        warnings.add('没有提取到可用于普通回合的明确记忆事实。');
      }
    }
    if (echoSeeds.isEmpty) {
      echoSeeds = <String>[
        ...archive.keyEvents,
        ...archive.unresolvedThreads,
      ].take(6).toList(growable: false);
    }

    final normalizedRelationship =
        NpcMigrationRelationshipLock.normalize(relationshipLock);
    final tasks = generateTasks
        ? parsed.tasks
            .where((task) => task.title.trim().isNotEmpty)
            .take(5)
            .map(
              (task) => task.copyWith(
                id: IdGenerator.generic('npc_migration_task'),
                completed: false,
              ),
            )
            .toList(growable: false)
        : const <NpcMigrationTask>[];
    return parsed.copyWith(
      schemaVersion: 1,
      archive: archive,
      memoryPolicy: parsed.memoryPolicy.copyWith(
        mode: normalizedMemory,
        runtimeFacts: runtimeFacts,
        echoSeeds: echoSeeds,
        forbiddenRecall: forbidden,
      ),
      relationship: parsed.relationship.copyWith(mode: normalizedRelationship),
      keepsake:
          generateKeepsake ? parsed.keepsake : const NpcMigrationKeepsake(),
      tasks: tasks,
      qualityWarnings: warnings,
    );
  }

  String _buildNpcMigrationBundlePrompt({
    required NpcMigrationManifest manifest,
    required String outputKind,
    required String worldType,
    required String inspiration,
    required String narrativeVoice,
    required NpcProfile npc,
  }) {
    final runtimeManifest = _npcMigrationRuntimeView(manifest);
    return '''
【目标 JSON schema】
$_npcMigrationBundleSchemaHint

outputKind=${NpcMigrationOutputKind.normalize(outputKind)}
NPC=${npc.name}
新世界=${worldType.trim().isEmpty ? '只属于你们的新世界' : worldType.trim()}
用户灵感=${inspiration.trim().isEmpty ? '无' : inspiration.trim()}
叙事人称=${_npcMigrationNarrativeVoiceLabel(narrativeVoice)}

【运行时允许使用的 manifest】
${const JsonEncoder.withIndent('  ').convert(runtimeManifest)}
''';
  }

  Map<String, dynamic> _npcMigrationRuntimeView(
    NpcMigrationManifest manifest,
  ) {
    final mode = NpcMigrationMemoryMode.normalize(manifest.memoryPolicy.mode);
    final archive = manifest.archive;
    return <String, dynamic>{
      'stableNpc': <String, dynamic>{
        'coreIdentity': archive.coreIdentity,
        'appearance': archive.appearance,
        'personality': archive.personality,
        'speechStyle': archive.speechStyle,
      },
      if (mode == NpcMigrationMemoryMode.full)
        'oldWorldArchive': <String, dynamic>{
          'summary': archive.summary,
          'relationshipHistory': archive.relationshipHistory,
          'keyEvents': archive.keyEvents,
          'unresolvedThreads': archive.unresolvedThreads,
          'continuityFacts': archive.continuityFacts,
        },
      'memoryPolicy': <String, dynamic>{
        'mode': mode,
        'runtimeFacts': manifest.memoryPolicy.runtimeFacts,
        'forbiddenRecall': manifest.memoryPolicy.forbiddenRecall,
      },
      'relationship': manifest.relationship.toJson(),
      if (mode != NpcMigrationMemoryMode.echo && !manifest.keepsake.isEmpty)
        'keepsake': mode == NpcMigrationMemoryMode.full
            ? manifest.keepsake.toJson()
            : <String, dynamic>{
                'name': manifest.keepsake.name,
                'description': manifest.keepsake.description,
                'emotionalMeaning': manifest.keepsake.emotionalMeaning,
              },
      if (mode != NpcMigrationMemoryMode.echo)
        'relationshipTasks':
            manifest.tasks.map((item) => item.toJson()).toList(),
    };
  }

  String _composeNpcMigrationWorldBook({
    required NpcMigrationManifest manifest,
    required String generatedContent,
    required String npcName,
    required String worldType,
    required String narrativeVoice,
    required bool allowEcho,
  }) {
    final memory = manifest.memoryPolicy;
    final relationship = manifest.relationship;
    final buffer = StringBuffer()
      ..writeln('【新世界】')
      ..writeln(worldType.trim().isEmpty ? '只属于你们的新世界。' : worldType.trim())
      ..writeln()
      ..writeln('【稳定角色】')
      ..writeln('$npcName：${manifest.archive.coreIdentity}')
      ..writeln()
      ..writeln('【叙事人称】')
      ..writeln(_npcMigrationNarrativeVoiceLabel(narrativeVoice))
      ..writeln()
      ..writeln('【记忆边界】')
      ..writeln(NpcMigrationMemoryMode.label(memory.mode));
    for (final fact in memory.runtimeFacts) {
      buffer.writeln('- 允许记得：$fact');
    }
    for (final rule in memory.forbiddenRecall) {
      buffer.writeln('- 禁止：$rule');
    }
    buffer
      ..writeln()
      ..writeln('【关系边界】')
      ..writeln(NpcMigrationRelationshipLock.prompt(relationship.mode));
    if (relationship.startingState.trim().isNotEmpty) {
      buffer.writeln('开局关系：${relationship.startingState.trim()}');
    }
    for (final rule in relationship.hardConstraints) {
      buffer.writeln('- $rule');
    }
    buffer
      ..writeln()
      ..writeln('【前尘回声】')
      ..writeln(allowEcho
          ? '只有收到本轮专用的前尘回声指令时，才能使用指令提供的单个旧世界片段。平时不得自行读取或补全回声内容。'
          : '关闭前尘回声，不得主动触发或补写旧世界片段。');
    if (generatedContent.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('【世界运行规则】')
        ..writeln(generatedContent.trim());
    }
    return buffer.toString().trim();
  }

  String _buildNpcMigrationSourceDigest({
    required CharacterProfile sourceCharacter,
    required NpcProfile npc,
    required List<NpcChatMessage> messages,
  }) {
    final mainHistory = _historyCache[sourceCharacter.id];
    final recentMain = mainHistory == null
        ? ''
        : _formatTranscript(
            mainHistory.messages.length > 8
                ? mainHistory.messages.sublist(mainHistory.messages.length - 8)
                : mainHistory.messages,
          );
    final recentNpc = _formatNpcTranscript(
      messages.length > 8 ? messages.sublist(messages.length - 8) : messages,
      npcName: npc.name,
    );
    final bond = npc.bondRoute;
    return '''
来源模拟器：${sourceCharacter.name}
前尘关联对象：${npc.name}
当前印象：${npc.impression.trim().isEmpty ? '暂无明确印象。' : npc.impression.trim()}
羁绊路线：${bond.stage} · ${bond.route} · ${bond.score}/100
最近节点：${bond.latestEvent.trim().isEmpty ? '暂无。' : bond.latestEvent.trim()}

最近主线片段：
${recentMain.trim().isEmpty ? '暂无。' : recentMain}

最近私聊片段：
${recentNpc.trim().isEmpty ? '暂无。' : recentNpc}
'''
        .trim();
  }

  String _buildNpcFarewellDraftPrompt({
    required CharacterProfile sourceCharacter,
    required NpcProfile npc,
    required List<NpcChatMessage> messages,
  }) {
    final mainHistory = _historyCache[sourceCharacter.id];
    final recentMain = mainHistory == null
        ? ''
        : _formatTranscript(
            mainHistory.messages.length > 20
                ? mainHistory.messages.sublist(mainHistory.messages.length - 20)
                : mainHistory.messages,
          );
    final recentNpc = _formatNpcTranscript(
      messages.length > 30 ? messages.sublist(messages.length - 30) : messages,
      npcName: npc.name,
    );
    final bond = npc.bondRoute;
    return '''
源模拟器：${sourceCharacter.name}
源模拟器简介：
${sourceCharacter.visibleBlurb}

目标 NPC：
姓名：${npc.name}
简介：${npc.description.trim().isEmpty ? '暂无。' : npc.description.trim()}
好感度：${npc.affinity}
印象：${npc.impression.trim().isEmpty ? '暂无明确印象。' : npc.impression.trim()}

羁绊路线：
阶段：${bond.stage}
路线倾向：${bond.route}
进度：${bond.score}/100
关键词：${bond.keywords.isEmpty ? '暂无。' : bond.keywords.join('、')}
最近节点：${bond.latestEvent.trim().isEmpty ? '暂无。' : bond.latestEvent.trim()}

最近主线片段：
${recentMain.trim().isEmpty ? '暂无。' : recentMain}

NPC 私聊片段：
${recentNpc.trim().isEmpty ? '暂无。' : recentNpc}

请生成迁徙前最后一场“旧世界告别回合”。这不是最终迁徙，不要替用户决定是否带走，只给一个可选择的告别现场。
''';
  }

  _NpcMigrationWorldBookPayload _parseNpcMigrationWorldBookPayload(
    String raw,
    NpcProfile npc,
    String worldType,
    String memoryMode,
  ) {
    final decoded = _decodeJsonObject(raw);
    if (decoded.isEmpty) {
      return _NpcMigrationWorldBookPayload(
        title: '你们的前尘 · ${npc.name}',
        content: _fallbackNpcMigrationWorldBookText(
          npc,
          worldType,
          memoryMode,
        ),
      );
    }
    final content = decoded['content']?.toString().trim() ?? '';
    return _NpcMigrationWorldBookPayload(
      title: decoded['title']?.toString().trim().isEmpty == false
          ? decoded['title'].toString().trim()
          : '你们的前尘 · ${npc.name}',
      content: content.isEmpty
          ? _fallbackNpcMigrationWorldBookText(
              npc,
              worldType,
              memoryMode,
            )
          : content,
    );
  }

  _NpcMigrationCharacterPayload _parseNpcMigrationCharacterPayload(
    String raw,
    NpcProfile npc,
    String worldType,
    String narrativeVoice,
  ) {
    final decoded = _decodeJsonObject(raw);
    if (decoded.isEmpty) {
      return _NpcMigrationCharacterPayload.fallback(
        npc,
        worldType,
        narrativeVoice,
      );
    }
    final sectionsRaw = decoded['sections'];
    final sections = sectionsRaw is Map
        ? Map<String, dynamic>.from(sectionsRaw)
        : const <String, dynamic>{};
    return _NpcMigrationCharacterPayload(
      name: decoded['name']?.toString() ?? npc.name,
      description: decoded['description']?.toString() ?? '',
      prompt: '',
      hiddenPrompt: decoded['hiddenPrompt']?.toString() ?? '',
      openingMessage: decoded['openingMessage']?.toString() ?? '',
      simulatorOverview: sections['simulatorOverview']?.toString() ?? '',
      npcProfile: sections['npcProfile']?.toString() ?? '',
      userRelationship: sections['userRelationship']?.toString() ?? '',
      coreLoop: sections['coreLoop']?.toString() ?? '',
      stateSystem: sections['stateSystem']?.toString() ?? '',
      htmlRules: sections['htmlRules']?.toString() ?? '',
      choiceRules: sections['choiceRules']?.toString() ?? '',
      styleRules: sections['styleRules']?.toString() ?? '',
      firstRoundRules: sections['firstRoundRules']?.toString() ?? '',
    ).withFallback(npc, worldType, narrativeVoice);
  }

  NpcFarewellDraft _parseNpcFarewellDraft(
    String raw,
    CharacterProfile sourceCharacter,
    NpcProfile npc,
  ) {
    final decoded = _decodeJsonObject(raw);
    final choices = _readObjectListFromMap(
      decoded['choices'],
      NpcFarewellChoice.fromJson,
    );
    final draft = NpcFarewellDraft(
      id: IdGenerator.generic('npc_farewell'),
      sourceCharacterId: sourceCharacter.id,
      npcId: npc.id,
      title: decoded['title']?.toString() ?? '',
      narrative: decoded['narrative']?.toString() ?? '',
      htmlPanel: decoded['htmlPanel']?.toString() ?? '',
      choices: choices.isEmpty
          ? <NpcFarewellChoice>[
              const NpcFarewellChoice(
                id: 'A',
                label: '把没说完的话说出口',
                actionPrompt: '用户选择在旧世界最后一刻坦白最重要的话。',
                emotionalTag: '未说出口',
              ),
              const NpcFarewellChoice(
                id: 'B',
                label: '只留下一个约定',
                actionPrompt: '用户不解释全部情绪，只和 NPC 留下新世界再见的约定。',
                emotionalTag: '约定',
              ),
              const NpcFarewellChoice(
                id: 'C',
                label: '安静地带 TA 离开',
                actionPrompt: '用户选择克制告别，不再让旧世界拖住两个人。',
                emotionalTag: '克制',
              ),
            ]
          : choices,
      emotionalSummary: decoded['emotionalSummary']?.toString() ?? '',
      createdAt: DateTime.now(),
    );
    if (!draft.isEmpty) {
      return draft;
    }
    return NpcFarewellDraft(
      id: IdGenerator.generic('npc_farewell'),
      sourceCharacterId: sourceCharacter.id,
      npcId: npc.id,
      title: '旧世界最后一幕',
      narrative:
          '旧世界的声音在远处慢慢退去，${npc.name}站在你面前，像是已经意识到这一次分别和以往都不一样。你们还有话可以说，也可以什么都不说，只把选择留给下一步。',
      choices: const <NpcFarewellChoice>[
        NpcFarewellChoice(
          id: 'A',
          label: '说出最后一句话',
          actionPrompt: '用户选择亲口留下旧世界最后一句告别。',
          emotionalTag: '不舍',
        ),
        NpcFarewellChoice(
          id: 'B',
          label: '伸手带 TA 离开',
          actionPrompt: '用户选择不再解释，用行动带 NPC 离开旧世界。',
          emotionalTag: '守护',
        ),
      ],
      emotionalSummary: '这是一场克制的旧世界告别，重点不在于结束，而在于把选择权交还给用户。',
      createdAt: DateTime.now(),
    );
  }

  NpcFarewellOutcome _fallbackFarewellOutcome({
    required NpcProfile npc,
    required String mode,
    NpcFarewellDraft? draft,
    NpcFarewellChoice? selectedChoice,
    required String userFarewellText,
  }) {
    final summary = _fallbackFarewellSummary(
      npc: npc,
      draft: draft,
      selectedChoice: selectedChoice,
      userFarewellText: userFarewellText,
    );
    return NpcFarewellOutcome(
      mode: mode,
      userFarewellText: userFarewellText.trim(),
      selectedChoiceLabel: selectedChoice?.label ?? '',
      finalSceneSummary: summary,
      relationshipAfterFarewell:
          '这场告别没有替两人的未来下定论，但确认了${npc.name}与用户之间的前尘仍会影响新世界。后续应保留这份张力，让关系在新世界继续生长。',
      continuityFacts: <String>[
        '${npc.name}经历过旧世界告别，不能像完全陌生人一样对待用户。',
        if (selectedChoice != null) selectedChoice.actionPrompt,
        if (userFarewellText.trim().isNotEmpty)
          '用户留下过告别文字：${userFarewellText.trim()}',
      ],
      forbiddenChanges: const <String>['不要抹除旧世界告别。', '不要替用户强行确认最终关系。'],
      emotionalKeywords: <String>[
        if (selectedChoice != null) selectedChoice.emotionalTag,
        '前尘',
        '告别',
      ],
    );
  }

  String _formatFarewellOutcomeText(NpcFarewellOutcome outcome) {
    if (outcome.isEmpty) {
      return '用户选择不告别，直接续前缘。后续不要强行补写一场旧世界告别。';
    }
    final buffer = StringBuffer()
      ..writeln('告别模式：${NpcFarewellMode.label(outcome.mode)}');
    if (outcome.userFarewellText.trim().isNotEmpty) {
      buffer.writeln('用户告别文字：${outcome.userFarewellText.trim()}');
    }
    if (outcome.selectedChoiceLabel.trim().isNotEmpty) {
      buffer.writeln('用户选择：${outcome.selectedChoiceLabel.trim()}');
    }
    if (outcome.finalSceneSummary.trim().isNotEmpty) {
      buffer.writeln('最后一幕：${outcome.finalSceneSummary.trim()}');
    }
    if (outcome.relationshipAfterFarewell.trim().isNotEmpty) {
      buffer.writeln('告别后的关系：${outcome.relationshipAfterFarewell.trim()}');
    }
    if (outcome.continuityFacts.isNotEmpty) {
      buffer.writeln('必须记住：${outcome.continuityFacts.join('；')}');
    }
    if (outcome.forbiddenChanges.isNotEmpty) {
      buffer.writeln('禁止改写：${outcome.forbiddenChanges.join('；')}');
    }
    if (outcome.emotionalKeywords.isNotEmpty) {
      buffer.writeln('情绪关键词：${outcome.emotionalKeywords.join('、')}');
    }
    return buffer.toString().trim();
  }

  String _buildNpcMigrationEchoDirective({
    required NpcMigrationRecord record,
    required String echoType,
    required String recentTranscript,
    required String gameState,
  }) {
    final seeds = record.manifest.memoryPolicy.echoSeeds.isNotEmpty
        ? record.manifest.memoryPolicy.echoSeeds
        : record.manifest.archive.keyEvents;
    final selectedSeed = seeds.isEmpty
        ? '只表现难以解释的熟悉感，不补写具体旧世界事实。'
        : seeds[_stableSeed('${record.id}|$echoType') % seeds.length];
    return '''
【前尘回声事件】
本轮请触发一次与旧世界相关的回声，但不要打断当前主线。

回声类型：$echoType
本轮唯一允许显现的前尘片段：
$selectedSeed

当前关系路线：
${NpcMigrationRelationshipLock.label(record.relationshipLock)}

当前剧情状态：
${gameState.trim().isEmpty ? '暂无。' : gameState.trim()}

最近聊天：
${recentTranscript.trim().isEmpty ? '暂无。' : recentTranscript.trim()}

要求：
- 回声必须自然融入当前场景。
- 只能使用上面这一条前尘片段，不要补充、复述或推断其他旧世界事实。
- 可以通过梦、物品、台词、场景相似、情绪反应触发。
- 回声要推进用户和 NPC 的关系，而不是变成设定说明。
- 回复仍必须遵守当前角色输出协议。
''';
  }

  String _formatGameStateForNpcMigration(GameStateSnapshot state) {
    if (state.isEmpty) {
      return '暂无。';
    }
    final buffer = StringBuffer();
    if (state.timeLabel.trim().isNotEmpty) {
      buffer.writeln('时间：${state.timeLabel}');
    }
    if (state.location.trim().isNotEmpty) {
      buffer.writeln('地点：${state.location}');
    }
    if (state.status.trim().isNotEmpty) {
      buffer.writeln('状态：${state.status}');
    }
    if (state.mainTask.trim().isNotEmpty) {
      buffer.writeln('当前任务：${state.mainTask}');
    }
    if (state.relationshipNotes.isNotEmpty) {
      buffer.writeln('关系记录：${state.relationshipNotes.join('；')}');
    }
    if (state.plotFlags.isNotEmpty) {
      buffer.writeln('剧情标记：${state.plotFlags.join('；')}');
    }
    if (state.storyInventory.isNotEmpty) {
      buffer.writeln(
        '剧情物品：${state.storyInventory.map((item) => item.name).join('、')}',
      );
    } else if (state.inventory.isNotEmpty) {
      buffer.writeln('物品：${state.inventory.join('、')}');
    }
    return buffer.toString().trim();
  }

  String _npcMigrationSectionContent(
    NpcMigrationRecord record,
    String section,
  ) {
    return switch (section) {
      '旧世界档案' => record.archiveText,
      '前尘世界书' => record.worldBookContent,
      '新角色卡' => record.characterPrompt,
      '开场白' => record.openingMessage,
      '关系任务' => record.relationshipTasks
          .map((task) => '${task.title}｜${task.stage}\n${task.description}')
          .join('\n\n'),
      '前尘信物' => record.keepsake.isEmpty
          ? ''
          : '名称：${record.keepsake.name}\n外观与来历：${record.keepsake.description}\n来源：${record.keepsake.origin}\n关系意义：${record.keepsake.emotionalMeaning}\n触发方向：${record.keepsake.useEffectPrompt}',
      '记忆强度' => NpcMigrationMemoryMode.label(record.memoryMode),
      '关系路线' => NpcMigrationRelationshipLock.label(record.relationshipLock),
      _ => record.archiveText,
    };
  }

  String _protectedNpcMigrationFacts(NpcMigrationRecord record) {
    return '''
来源模拟器：${record.sourceCharacterName}
来源 NPC：${record.sourceNpcName}
新世界角色：${record.createdCharacterName}
新世界类型：${record.worldType}
记忆强度：${NpcMigrationMemoryMode.label(record.memoryMode)}
关系路线：${NpcMigrationRelationshipLock.label(record.relationshipLock)}
旧世界告别：${_formatFarewellOutcomeText(record.farewellOutcome)}
''';
  }

  NpcMigrationRecord _applyNpcMigrationRevision(
    NpcMigrationRecord record,
    String section,
    String newContent,
  ) {
    final structured = _decodeJsonObject(newContent);
    return switch (section) {
      '旧世界档案' => () {
          final raw = structured['archive'];
          final archive = raw is Map
              ? NpcMigrationArchiveData.fromJson(
                  Map<String, dynamic>.from(raw),
                )
              : record.manifest.archive;
          final manifest = record.manifest.copyWith(archive: archive);
          return record.copyWith(
            archiveText: archive.toDisplayText(),
            manifest: manifest,
          );
        }(),
      '前尘世界书' => record.copyWith(worldBookContent: newContent),
      '新角色卡' => record.copyWith(characterPrompt: newContent),
      '开场白' => record.copyWith(openingMessage: newContent),
      '关系任务' => () {
          final tasks = _readObjectListFromMap(
            structured['tasks'],
            NpcMigrationTask.fromJson,
          )
              .where((task) => task.title.trim().isNotEmpty)
              .take(5)
              .map(
                (task) => task.copyWith(
                  id: IdGenerator.generic('npc_migration_task'),
                  completed: false,
                ),
              )
              .toList(growable: false);
          return record.copyWith(
            relationshipTasks: tasks,
            manifest: record.manifest.copyWith(tasks: tasks),
          );
        }(),
      '前尘信物' => () {
          final raw = structured['keepsake'];
          final keepsake = raw is Map
              ? NpcMigrationKeepsake.fromJson(Map<String, dynamic>.from(raw))
              : record.keepsake;
          return record.copyWith(
            keepsake: keepsake,
            manifest: record.manifest.copyWith(keepsake: keepsake),
          );
        }(),
      _ => record.copyWith(archiveText: newContent),
    };
  }

  Future<void> _syncNpcMigrationRevision(
    NpcMigrationRecord record,
    String section,
  ) async {
    if (section == '前尘世界书') {
      final index =
          _worldBooks.indexWhere((entry) => entry.id == record.worldBookId);
      if (index != -1) {
        final entry = _worldBooks[index];
        _worldBooks[index] = entry.copyWith(content: record.worldBookContent);
        await _store.saveWorldBooks(_worldBooks);
      }
    }
    if (record.createsCharacter && (section == '新角色卡' || section == '开场白')) {
      final index = _characters
          .indexWhere((item) => item.id == record.createdCharacterId);
      if (index != -1) {
        final character = _characters[index];
        _characters[index] = character.copyWith(
          prompt: section == '新角色卡' ? record.characterPrompt : null,
          openingMessage: section == '开场白' ? record.openingMessage : null,
        );
        await _store.saveCharacters(_characters);
      }
    }
  }

  String _fallbackFarewellSummary({
    required NpcProfile npc,
    NpcFarewellDraft? draft,
    NpcFarewellChoice? selectedChoice,
    required String userFarewellText,
  }) {
    final choice =
        selectedChoice == null ? '' : '用户选择了“${selectedChoice.label}”。';
    final userText = userFarewellText.trim().isEmpty
        ? ''
        : '用户留下的话是：“${userFarewellText.trim()}”。';
    final scene = draft == null || draft.title.trim().isEmpty
        ? '旧世界最后一幕'
        : draft.title.trim();
    return '$scene 中，用户与${npc.name}完成了迁徙前的告别。$choice$userText 这段经历会作为新世界的前尘事实保存。';
  }

  List<T> _readObjectListFromMap<T>(
    dynamic value,
    T Function(Map<String, dynamic>) reader,
  ) {
    if (value is! List) {
      return <T>[];
    }
    return value
        .whereType<Map>()
        .map((item) => reader(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  String _composeNpcMigrationPrompt({
    required _NpcMigrationCharacterPayload payload,
    required NpcProfile npc,
    required String worldType,
    required String narrativeVoice,
  }) {
    final title = payload.name.trim().isEmpty ? npc.name : payload.name.trim();
    final buffer = StringBuffer()
      ..writeln('模拟器名称：$title')
      ..writeln()
      ..writeln('【核心定位】')
      ..writeln('这是一个围绕玩家与「${npc.name}」展开的双人文游模拟器。')
      ..writeln(
          '新世界类型：${worldType.trim().isEmpty ? '只属于你们的新世界' : worldType.trim()}。')
      ..writeln('叙事人称：${_npcMigrationNarrativeVoiceLabel(narrativeVoice)}。')
      ..writeln()
      ..writeln('【模拟器总设定 / 新世界背景】')
      ..writeln(payload.simulatorOverview)
      ..writeln()
      ..writeln('【NPC 完整角色设定】')
      ..writeln(payload.npcProfile)
      ..writeln()
      ..writeln('【玩家与 NPC 的关系】')
      ..writeln(payload.userRelationship)
      ..writeln()
      ..writeln('【核心玩法循环】')
      ..writeln(payload.coreLoop)
      ..writeln()
      ..writeln('【状态、任务与长期进展】')
      ..writeln(payload.stateSystem)
      ..writeln()
      ..writeln('【叙事与文风规则】')
      ..writeln(payload.styleRules)
      ..writeln()
      ..writeln('【第一回合规则】')
      ..writeln(payload.firstRoundRules)
      ..writeln()
      ..writeln(
          '输出格式由 App 的全局运行协议统一管理。这里不要重复 HTML、GAME_STATE 或 CHOICES 格式说明，也不要复制绑定世界书。');
    return buffer.toString().trim();
  }

  String _fallbackNpcMigrationOpening(
    NpcProfile npc,
    String worldType,
    String narrativeVoice,
  ) {
    final place = worldType.trim().isEmpty ? '这个新世界' : worldType.trim();
    final voice = _npcMigrationNarrativeVoiceLabel(narrativeVoice);
    return '''
门合上的声音很轻，像旧世界终于把最后一阵风留在身后。

${npc.name}站在$place的第一束光里，回头看向你。那些没说完的话、没来得及确认的眼神，都像被重新放回掌心。

```html
<!doctype html>
<html lang="zh-CN">
<meta charset="utf-8">
<style>
body{margin:0;font-family:system-ui,"Microsoft YaHei",sans-serif;background:linear-gradient(135deg,#f8f5ef,#edf4ef);color:#2f3038}
.card{padding:18px;border:1px solid rgba(96,118,100,.28);border-radius:18px;background:rgba(255,255,255,.78)}
h3{margin:0 0 10px;font-size:18px}.tag{display:inline-block;margin:4px 6px 0 0;padding:5px 10px;border-radius:999px;background:#e1eee3;color:#607664;font-weight:700}
</style>
<div class="card">
<h3>你们的新世界</h3>
<p>地点：$place</p>
<p>叙事：$voice</p>
<span class="tag">只属于你们</span><span class="tag">前尘延续</span><span class="tag">文游开局</span>
</div>
</html>
```

[GAME_STATE]
时间：新世界第一天
地点：$place
状态：刚刚抵达，旧世界的余温仍在
当前任务：确认你和${npc.name}在新世界的第一步
人物数据：用户：刚抵达新世界；${npc.name}：仍在适应新世界
剧情物品栏：
关系网：用户 ↔ ${npc.name}：前尘未尽，关系待续
剧情记录：你和${npc.name}从旧世界的余温里抵达$place，新的关系尚未落定。
NPC变化：${npc.name}：好感度 ${npc.affinity}，印象：${npc.impression.trim().isEmpty ? '对用户有强烈熟悉感，愿意继续靠近。' : npc.impression.trim()}
NPC更新：${npc.name}｜简介：与旧世界有前尘联系的关键角色｜好感度：${npc.affinity}｜印象：${npc.impression.trim().isEmpty ? '对用户有强烈熟悉感，愿意继续靠近。' : npc.impression.trim()}｜主动消息：无
[/GAME_STATE]

[CHOICES]
A|我先确认${npc.name}有没有完整记得旧世界的事。
B|我带${npc.name}熟悉这个新世界的住处。
C|我问 TA 现在最想做什么。
D|我先不追问，只陪 TA 安静待一会儿。
[/CHOICES]
''';
  }

  String _fallbackNpcMigrationWorldBookText(
    NpcProfile npc,
    String worldType,
    String memoryMode,
  ) {
    final bond = npc.bondRoute;
    return '''
【新世界规则】
这里是你与${npc.name}延续前尘的独立世界，故事主体只围绕二人展开。

【前尘记忆】
${NpcMigrationMemoryMode.label(memoryMode)}

【羁绊状态】
阶段：${bond.stage}
路线倾向：${bond.route}
进度：${bond.score}/100
最近节点：${bond.latestEvent.trim().isEmpty ? '暂无。' : bond.latestEvent.trim()}

【连续性要求】
保持${npc.name}的原始性格、说话习惯、对用户的印象和既有关系张力，不要改成陌生人。
新世界类型：${worldType.trim().isEmpty ? '只属于你们的新世界' : worldType.trim()}。
''';
  }

  String _npcMigrationNarrativeVoiceLabel(String value) {
    return switch (value.trim()) {
      'first' => '第一人称：以“我”的视角推进，用户像亲自写下这段新生活。',
      'third' => '第三人称：以小说旁白视角推进，旁观用户与 NPC 的关系发展。',
      _ => '第二人称：以“你”为核心推进，最适合沉浸式文游体验。',
    };
  }

  Future<void> _updateGamification(
    GamificationState Function(GamificationState state) update, {
    bool notify = true,
  }) async {
    final next = _applyAchievementUnlocks(update(_gamification.ensureToday()));
    _gamification = next;
    _registerCustomThemes();
    await _store.saveGamificationState(_gamification);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _noteNpcBondScore(int score) async {
    await _updateGamification(
      (state) => state.setStatMax('maxNpcBondScore', score),
      notify: false,
    );
  }

  Future<String> _buildDataArchive({
    required String scope,
    required Set<String> characterIds,
    required bool includeApiSecrets,
  }) async {
    final safeCharacterIds = characterIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && _findCharacter(id) != null)
        .toSet();
    final selectedIds = scope == 'all'
        ? _characters.map((item) => item.id).toSet()
        : safeCharacterIds;
    final histories = <String, dynamic>{};
    final memories = <String, dynamic>{};
    final gameStates = <String, dynamic>{};
    final mapStates = <String, dynamic>{};

    for (final characterId in selectedIds) {
      histories[characterId] = (await _ensureHistory(characterId)).toJson();
      memories[characterId] = (await _ensureMemory(characterId)).toJson();
      gameStates[characterId] = (await _ensureGameState(characterId)).toJson();
      mapStates[characterId] = (await _ensureMapState(characterId)).toJson();
    }

    final selectedNpcProfiles = _npcProfiles
        .where((profile) =>
            selectedIds.contains(profile.characterId) ||
            profile.globalBinding ||
            profile.boundCharacterIds.any(selectedIds.contains))
        .toList(growable: false);
    final selectedNpcIds =
        selectedNpcProfiles.map((profile) => profile.id).toSet();
    final selectedNpcMigrations = _npcMigrations
        .where((record) =>
            selectedNpcIds.contains(record.sourceNpcId) ||
            selectedIds.contains(record.createdCharacterId))
        .toList(growable: false);
    final npcMessages = <String, dynamic>{};
    for (final npc in selectedNpcProfiles) {
      npcMessages[npc.id] = (await _ensureNpcMessages(npc.id))
          .map((item) => item.toJson())
          .toList();
    }

    final selectedUserProfiles = scope == 'all'
        ? _userProfiles
        : _userProfiles
            .where(
              (profile) => profile.boundCharacterIds.any(selectedIds.contains),
            )
            .toList(growable: false);
    final selectedWorldBooks = scope == 'all'
        ? _worldBooks
        : _worldBooks
            .where(
              (entry) =>
                  entry.global ||
                  entry.boundCharacterIds.any(selectedIds.contains),
            )
            .toList(growable: false);
    final selectedWorldCalendarEvents = _worldCalendarEvents
        .where((event) => selectedIds.contains(event.characterId))
        .toList(growable: false);

    final settingsForExport = includeApiSecrets
        ? _settings
        : _settings.copyWith(
            apiKey: '',
            memoryApiKey: '',
            experienceMode: false,
          );
    final legacyRoot = <String, dynamic>{
      'schemaVersion': currentSaveSchemaVersion,
      'appVersion': currentSaveAppVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'scope': scope,
      'includeApiSecrets': includeApiSecrets,
      'data': <String, dynamic>{
        'settings': settingsForExport.toJson(),
        'settingsPresets': _settingsPresets.map((item) {
          if (includeApiSecrets) {
            return item.toJson();
          }
          return SettingsPreset(
            id: item.id,
            name: item.name,
            createdAt: item.createdAt,
            settings: item.settings.copyWith(
              apiKey: '',
              memoryApiKey: '',
              experienceMode: false,
            ),
          ).toJson();
        }).toList(),
        'selectedCharacterId': selectedIds.contains(_selectedCharacterId)
            ? _selectedCharacterId
            : selectedIds.isEmpty
                ? null
                : selectedIds.first,
        'characters': _characters
            .where((character) => selectedIds.contains(character.id))
            .map((character) => character.toJson())
            .toList(),
        'histories': histories,
        'memories': memories,
        'gameStates': gameStates,
        'mapStates': mapStates,
        'npcProfiles':
            selectedNpcProfiles.map((item) => item.toJson()).toList(),
        'npcMigrations':
            selectedNpcMigrations.map((item) => item.toJson()).toList(),
        'npcMessages': npcMessages,
        'toolResults': _toolResults
            .where((result) => selectedIds.contains(result.characterId))
            .map((result) => result.toJson())
            .toList(),
        'fanficResults': _fanficResults
            .where((result) => selectedIds.contains(result.characterId))
            .map((result) => result.toJson())
            .toList(),
        'userProfiles':
            selectedUserProfiles.map((item) => item.toJson()).toList(),
        'worldBooks': selectedWorldBooks.map((item) => item.toJson()).toList(),
        'worldCalendarEvents':
            selectedWorldCalendarEvents.map((item) => item.toJson()).toList(),
        'gamification': scope == 'all' ? _gamification.toJson() : null,
      },
    };

    final payload = SaveEnvelopeCodec.wrapArchive(legacyRoot: legacyRoot);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  void _upsertById<T>(
    List<T> target,
    Iterable<T> incoming,
    String Function(T item) idOf,
  ) {
    for (final item in incoming) {
      final id = idOf(item).trim();
      if (id.isEmpty) {
        continue;
      }
      final index = target.indexWhere((existing) => idOf(existing) == id);
      if (index == -1) {
        target.add(item);
      } else {
        target[index] = item;
      }
    }
  }

  GamificationState _ensureVersionGiftMail(GamificationState state) {
    var next = _removeLegacyVersionGiftMail(state);
    for (final gift in _versionGiftMailSpecs) {
      if (next.hasMailboxSource(gift.sourceId)) {
        continue;
      }
      next = next.addMailboxReward(
        sourceId: gift.sourceId,
        title: gift.title,
        description: gift.description,
        coins: gift.coins,
      );
    }
    return next;
  }

  GamificationState _removeLegacyVersionGiftMail(GamificationState state) {
    final filtered = state.mailbox
        .where((entry) => !entry.sourceId.startsWith('version_gift_'))
        .toList(growable: false);
    if (filtered.length == state.mailbox.length) {
      return state;
    }
    return state.copyWith(mailbox: filtered);
  }

  GamificationState _applyAchievementUnlocks(GamificationState state) {
    var next = state.ensureToday();
    for (final achievement in GameCatalog.achievements) {
      if (!next.hasAchievement(achievement.id) &&
          achievement.isUnlockedBy(next)) {
        next = next.unlockAchievement(achievement);
      }
    }
    return next;
  }

  GamificationState _withRouletteCollectionStats(GamificationState state) {
    final titleCount = GameCatalog.rouletteTitleIds
        .where((id) => state.ownsCosmetic(id))
        .length;
    final frameCount = GameCatalog.rouletteFrameIds
        .where((id) => state.ownsCosmetic(id))
        .length;
    return state
        .setStatMax('maxRouletteTitlesOwned', titleCount)
        .setStatMax('maxRouletteFramesOwned', frameCount);
  }

  GamificationState _withMusicCollectionStats(GamificationState state) {
    return state.setStatMax('maxMusicTracksUnlocked', _musicTracks.length);
  }

  GamificationState _withMusicPlaylistStats(GamificationState state) {
    final playlistCount = _musicState.playlistTrackIds.length;
    var next = state.setStatMax('maxMusicPlaylistSize', playlistCount);
    if (_musicTracks.isNotEmpty && playlistCount >= _musicTracks.length) {
      next = next.setStatMax('maxMusicPlaylistFull', 1);
    }
    if (playlistCount == 1 && _musicState.loopMode == MusicLoopMode.single) {
      next = next.setStatMax('hiddenMusicPrivatePlaylist', 1);
    }
    return next;
  }

  GamificationState _withMusicPlaybackStats(
    GamificationState state,
    BackgroundTrack track, {
    required bool changed,
    required String source,
    required bool wasPlaying,
  }) {
    var next = state
        .incrementStat('totalMusicPlays')
        .incrementDailyStat('musicPlays')
        .incrementStat('musicPlayed_${track.id}')
        .setStatMax('maxBasicMusicPlayed', _musicTracks.length);
    if (changed) {
      next = next
          .incrementStat('totalMusicSwitches')
          .incrementDailyStat('musicSwitches');
    }
    if (source == 'dropdown') {
      next = next.incrementStat('totalMusicDropdownSwitches');
    } else if (source == 'card') {
      next = next.incrementStat('totalMusicCardSwitches');
    }
    final openedAt = _musicPanelOpenedAt;
    if (openedAt != null &&
        DateTime.now().difference(openedAt) <= const Duration(seconds: 5)) {
      next = next.setStatMax('hiddenMusicFastPlay', 1);
    }
    final pausedAt = _lastMusicPausedAt;
    if (!wasPlaying &&
        pausedAt != null &&
        DateTime.now().difference(pausedAt) <= const Duration(minutes: 1)) {
      next = next.setStatMax('hiddenMusicPauseResume', 1);
    }
    if (pausedAt != null &&
        DateTime.now().difference(pausedAt) <= const Duration(minutes: 5)) {
      next = next.setStatMax('hiddenMusicQuietFail', 1);
    }
    _musicRoundTrackIds.add(track.id);
    final knownIds = _musicTracks.map((item) => item.id).toSet();
    if (knownIds.isNotEmpty && _musicRoundTrackIds.containsAll(knownIds)) {
      next = next
          .incrementStat('totalMusicPlaylistRounds')
          .setStatMax('hiddenMusicAllUnlockedDay', 1);
      _musicRoundTrackIds.clear();
    }
    return _withMusicPlaylistStats(next);
  }

  String _formatMusicPlaybackError(Object error) {
    final text = error.toString();
    if (error is TimeoutException || text.contains('TimeoutException')) {
      return '本地音频加载超时，稍后点播放键再试；不影响聊天和存档。';
    }
    if (text.contains('MissingPluginException') ||
        text.contains('No implementation found')) {
      return '音频插件没有加载成功，请刷新页面后再试。';
    }
    if (text.contains('NotAllowedError') ||
        text.contains('play() failed') ||
        text.contains('user') && text.contains('gesture')) {
      return '浏览器拦截了自动播放，点一下播放键或页面任意位置后会继续播放。';
    }
    return '本地音频播放失败：$error';
  }

  void _startMusicProgressTimer() {
    _musicProgressTimer ??=
        Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!_musicState.isPlaying) {
        return;
      }
      await _updateGamification(
        (state) => state.incrementStat('totalMusicMinutes'),
        notify: false,
      );
    });
  }

  Future<void> _handleMusicTrackCompleted() async {
    if (!_musicState.isPlaying) {
      return;
    }
    final nextId = _nextMusicTrackId();
    if (nextId == null) {
      _musicState = _musicState.copyWith(isPlaying: false);
      await _store.saveMusicPlaybackState(_musicState);
      _releaseActiveMusicPlaybackUri();
      notifyListeners();
      return;
    }
    await playMusicTrack(nextId, source: 'auto');
  }

  String? _nextMusicTrackId() {
    final knownIds = _musicTracks.map((track) => track.id).toSet();
    final ids = _musicState.playlistTrackIds
        .where(knownIds.contains)
        .toList(growable: false);
    if (ids.isEmpty) {
      return null;
    }
    if (_musicState.loopMode == MusicLoopMode.single) {
      return _musicState.currentTrackId.isEmpty
          ? ids.first
          : _musicState.currentTrackId;
    }
    final index = ids.indexOf(_musicState.currentTrackId);
    if (index == -1) {
      return ids.first;
    }
    return ids[(index + 1) % ids.length];
  }

  String? _previousMusicTrackId() {
    final knownIds = _musicTracks.map((track) => track.id).toSet();
    final ids = _musicState.playlistTrackIds
        .where(knownIds.contains)
        .toList(growable: false);
    if (ids.isEmpty) {
      return null;
    }
    if (_musicState.loopMode == MusicLoopMode.single) {
      return _musicState.currentTrackId.isEmpty
          ? ids.first
          : _musicState.currentTrackId;
    }
    final index = ids.indexOf(_musicState.currentTrackId);
    if (index == -1) {
      return ids.first;
    }
    return ids[(index - 1 + ids.length) % ids.length];
  }

  void _releaseActiveMusicPlaybackUri() {
    final uri = _activeMusicPlaybackUri;
    if (uri == null || uri.isEmpty) {
      return;
    }
    LocalAudioStorage.releasePlaybackUri(uri);
    _activeMusicPlaybackUri = null;
  }

  String _extensionOf(String name) {
    final clean = name.trim();
    final dotIndex = clean.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= clean.length - 1) {
      return '';
    }
    return clean.substring(dotIndex + 1).toLowerCase();
  }

  String _plainPreview(String value, {int limit = 120}) {
    final cleaned = value
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'\[[A-Z_]+\][\s\S]*?\[/[A-Z_]+\]'), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length <= limit) {
      return cleaned;
    }
    return '${cleaned.substring(0, limit).trim()}...';
  }

  String _formatShortDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  StoryInventoryItem _rouletteStoryItem(Random rng) {
    final templates = <StoryInventoryItem>[
      StoryInventoryItem.fromName(
        '老板掉出来的备用钥匙',
        description: '转盘限定怪东西：不知道能打开哪扇门。',
        effect: '',
        source: 'roulette',
        identified: false,
        mysteryHint: '钥匙齿纹很浅，像是临时复制的。',
      ),
      StoryInventoryItem.fromName(
        '写着“别拆”的信封',
        description: '转盘限定怪东西：它越说别拆，越像非拆不可。',
        effect: '',
        source: 'roulette',
        identified: false,
        mysteryHint: '信封背面有一枚很淡的指印。',
      ),
      StoryInventoryItem.fromName(
        '迟到也能理直气壮的闹钟',
        description: '转盘限定怪东西：秒针走得很有自己的节奏。',
        effect: '投入主线后让一次错过、迟到或拖延变成可展开的小事件。',
        source: 'roulette',
      ),
      StoryInventoryItem.fromName(
        ' NPC 看了会沉默的便签',
        description: '转盘限定怪东西：上面空空如也，但存在感很强。',
        effect: '投入主线后让一个 NPC 产生短暂动摇，并更新印象。',
        source: 'roulette',
      ),
      StoryInventoryItem.fromName(
        '好像用过一次的好运符',
        description: '转盘限定怪东西：好运还剩一点点，可能也只剩一点点。',
        effect: '投入主线后给下一次行动一点助力，同时制造轻微副作用。',
        source: 'roulette',
      ),
    ];
    return templates[rng.nextInt(templates.length)];
  }

  int _stableSeed(String value) {
    var hash = 0x811c9dc5;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    final cleaned = _stripJsonFence(raw.trim());
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final decoded = jsonDecode(cleaned.substring(start, end + 1));
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
    }
    return const <String, dynamic>{};
  }

  List<CharacterMemorySummary> _selectMemorySummaries(
    List<CharacterMemorySummary> summaries, {
    List<ChatMessage> contextMessages = const <ChatMessage>[],
    GameStateSnapshot? gameState,
  }) {
    if (_settings.memoryContextItems <= 0) {
      return summaries;
    }

    if (summaries.length <= _settings.memoryContextItems) {
      return summaries;
    }

    final limit = _settings.memoryContextItems;
    final recentCount = limit <= 2 ? limit : min(2, limit);
    final selected = <CharacterMemorySummary>[];
    final selectedIds = <String>{};

    void addSummary(CharacterMemorySummary summary) {
      if (selected.length >= limit || !selectedIds.add(summary.id)) {
        return;
      }
      selected.add(summary);
    }

    for (final summary in summaries.reversed.take(recentCount)) {
      addSummary(summary);
    }

    final keywords = _keywordsForContext(
      contextMessages: contextMessages,
      gameState: gameState,
    );
    if (selected.length < limit && keywords.isNotEmpty) {
      final ranked = summaries
          .where((summary) => !selectedIds.contains(summary.id))
          .map(
            (summary) => (
              summary: summary,
              score: _textRelevanceScore(summary.summaryText, keywords),
            ),
          )
          .where((item) => item.score > 0)
          .toList(growable: false)
        ..sort((a, b) {
          final score = b.score.compareTo(a.score);
          if (score != 0) {
            return score;
          }
          return b.summary.timestamp.compareTo(a.summary.timestamp);
        });
      for (final item in ranked) {
        addSummary(item.summary);
      }
    }

    if (selected.length < limit) {
      for (final summary in summaries.reversed) {
        addSummary(summary);
        if (selected.length >= limit) {
          break;
        }
      }
    }

    return selected..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  CharacterProfile? _findCharacter(String? characterId) {
    if (characterId == null) {
      return null;
    }

    for (final character in _characters) {
      if (character.id == characterId) {
        return character;
      }
    }

    return null;
  }

  CharacterProfile? _characterForNpcInteraction(NpcProfile? npc) {
    if (npc == null) {
      return null;
    }
    final selectedId = _selectedCharacterId;
    if (selectedId != null) {
      final selected = _findCharacter(selectedId);
      final rootId = selected?.rootCharacterId ?? selectedId;
      if (npc.isBoundTo(selectedId) || npc.isBoundTo(rootId)) {
        return selected;
      }
    }
    return _findCharacter(npc.characterId);
  }

  UserProfile? _findBoundUserProfile(String? characterId) {
    if (characterId == null) {
      return null;
    }

    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    for (final profile in _userProfiles) {
      if (profile.isBoundTo(characterId) || profile.isBoundTo(rootId)) {
        return profile;
      }
    }
    return null;
  }

  List<WorldBookEntry> _worldBooksForCharacter(
    String characterId, {
    List<ChatMessage> contextMessages = const <ChatMessage>[],
    GameStateSnapshot? gameState,
    String runtimeAddendum = '',
  }) {
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    final keywords = _keywordsForContext(
      contextMessages: contextMessages,
      gameState: gameState,
      extraText: runtimeAddendum,
    );
    final haystack = _contextHaystack(
      contextMessages: contextMessages,
      gameState: gameState,
      extraText: runtimeAddendum,
    );
    return _worldBooks
        .where((entry) =>
            (entry.appliesTo(characterId) || entry.appliesTo(rootId)) &&
            entry.content.trim().isNotEmpty &&
            _worldBookMatchesContext(
              entry,
              keywords: keywords,
              haystack: haystack,
            ))
        .toList(growable: false);
  }

  String _formatWorldBooksForPrompt(String characterId) {
    final entries = _worldBooksForCharacter(characterId);
    if (entries.isEmpty) {
      return '暂无。';
    }
    return entries.take(12).map((entry) {
      final title = entry.title.trim().isEmpty ? '未命名世界书' : entry.title.trim();
      return '【$title】\n${entry.content.trim()}';
    }).join('\n\n');
  }

  bool _worldBookMatchesContext(
    WorldBookEntry entry, {
    required Set<String> keywords,
    required String haystack,
  }) {
    switch (entry.triggerMode) {
      case WorldBookTriggerMode.always:
        return true;
      case WorldBookTriggerMode.keyword:
        final entryKeywords = entry.keywords
            .map((keyword) => keyword.trim().toLowerCase())
            .where((keyword) => keyword.isNotEmpty)
            .toList(growable: false);
        if (entryKeywords.isEmpty) {
          return true;
        }
        return entryKeywords.any(
          (keyword) => haystack.contains(keyword) || keywords.contains(keyword),
        );
      case WorldBookTriggerMode.regex:
        final pattern = entry.regexPattern.trim();
        if (pattern.isEmpty) {
          return true;
        }
        try {
          return RegExp(pattern, caseSensitive: false).hasMatch(haystack);
        } catch (_) {
          return false;
        }
    }
  }

  String _contextHaystack({
    required List<ChatMessage> contextMessages,
    GameStateSnapshot? gameState,
    String extraText = '',
  }) {
    final parts = <String>[
      ...contextMessages.reversed.take(8).map((message) => message.content),
      if (gameState != null && !gameState.isEmpty)
        _formatGameStateForPrompt(gameState),
      extraText,
    ];
    return parts.join('\n').toLowerCase();
  }

  Set<String> _keywordsForContext({
    required List<ChatMessage> contextMessages,
    GameStateSnapshot? gameState,
    String extraText = '',
  }) {
    final haystack = _contextHaystack(
      contextMessages: contextMessages,
      gameState: gameState,
      extraText: extraText,
    );
    final matches = RegExp(r'[\p{L}\p{N}_]{2,}', unicode: true)
        .allMatches(haystack)
        .map((match) => match.group(0)?.toLowerCase() ?? '')
        .where((word) => word.length >= 2 && !_promptStopWords.contains(word))
        .toSet();
    return matches;
  }

  int _textRelevanceScore(String text, Set<String> keywords) {
    if (keywords.isEmpty) {
      return 0;
    }
    final normalized = text.toLowerCase();
    var score = 0;
    for (final keyword in keywords) {
      if (keyword.length < 2) {
        continue;
      }
      if (normalized.contains(keyword)) {
        score += keyword.length >= 4 ? 2 : 1;
      }
    }
    return score;
  }

  AiPromptDiagnostics _buildPromptDiagnostics({
    required List<WorldBookEntry> worldBooks,
    required List<CharacterMemorySummary> memorySummaries,
    PromptCacheEpoch? cacheEpoch,
    int promptTokenBudget = 0,
    bool usedExactAssistantReplay = false,
    bool fixedOverheadExceedsBudget = false,
  }) {
    final titles = worldBooks
        .map((entry) =>
            entry.title.trim().isEmpty ? '未命名世界书' : entry.title.trim())
        .take(12)
        .toList(growable: false);
    return AiPromptDiagnostics(
      worldBookTitles: titles,
      memoryCount: memorySummaries.length,
      staticWorldBookCount: worldBooks
          .where((entry) => entry.triggerMode == WorldBookTriggerMode.always)
          .length,
      triggeredWorldBookCount: worldBooks
          .where((entry) => entry.triggerMode != WorldBookTriggerMode.always)
          .length,
      cacheEpochId: cacheEpoch?.id ?? '',
      cacheRolloverReason: cacheEpoch?.rolloverReason ?? '',
      stablePrefixDigest: cacheEpoch?.stablePrefixDigest ?? '',
      previousPromptTokens: cacheEpoch?.previousPromptTokens,
      promptTokenBudget: promptTokenBudget,
      usedExactAssistantReplay: usedExactAssistantReplay,
      fixedOverheadExceedsBudget: fixedOverheadExceedsBudget,
    );
  }

  String _formatWorldCalendarForPrompt(String characterId) {
    final rootId = _findCharacter(characterId)?.rootCharacterId ?? characterId;
    final events = _worldCalendarEvents
        .where((event) =>
            event.characterId == characterId || event.characterId == rootId)
        .take(12)
        .toList(growable: false);
    if (events.isEmpty) {
      return '';
    }
    return events.map((event) {
      final stage = event.stage.trim().isEmpty ? '未标记' : event.stage.trim();
      final time =
          event.timeLabel.trim().isEmpty ? '时间未定' : event.timeLabel.trim();
      return '- [$stage][$time] ${event.title.trim()}：${event.description.trim()}';
    }).join('\n');
  }

  String _buildRuntimeAddendum(
    String characterId, {
    TurnDirective? directiveOverride,
    GameStateSnapshot? gameStateOverride,
    GameplaySystem? gameplaySystemOverride,
  }) {
    final parts = <String>[];
    final directive = directiveOverride ?? _activeTurnDirective;
    if (directive != null && !directive.isEmpty) {
      parts.add('【剧情导演台】\n${directive.toPrompt()}');
    }
    final calendar = _formatWorldCalendarForPrompt(characterId);
    if (calendar.trim().isNotEmpty) {
      parts.add(
        '【世界事件日历】\n以下是本地保存的未来事件节奏表。请自然参考它来埋伏笔、推进或回收事件，但不要机械复述给用户：\n$calendar',
      );
    }
    final character = _findCharacter(characterId);
    final gameplaySystem = gameplaySystemOverride ?? character?.gameplaySystem;
    if (gameplaySystem != null) {
      parts.add(
        _formatGameplaySystemForPrompt(
          gameplaySystem,
          gameStateOverride ?? _gameStateFor(characterId),
        ),
      );
    }
    return parts.join('\n\n').trim();
  }

  String _formatGameplaySystemForPrompt(
    GameplaySystem system,
    GameStateSnapshot state,
  ) =>
      GameplayPromptContext.narrative(system: system, state: state);

  DialogueHistory _historyFor(String? characterId) {
    if (characterId == null) {
      return DialogueHistory.empty('');
    }

    return _historyCache[characterId] ?? DialogueHistory.empty(characterId);
  }

  CharacterMemory _memoryFor(String? characterId) {
    if (characterId == null) {
      return CharacterMemory.empty('');
    }

    return _memoryCache[characterId] ?? CharacterMemory.empty(characterId);
  }

  GameStateSnapshot _gameStateFor(String? characterId) {
    if (characterId == null) {
      return GameStateSnapshot.empty('');
    }

    return _gameStateCache[characterId] ?? GameStateSnapshot.empty(characterId);
  }

  MapWorldState _mapStateFor(String? characterId) {
    if (characterId == null) {
      return MapWorldState.empty('');
    }

    return _mapStateCache[characterId] ?? MapWorldState.empty(characterId);
  }

  bool _hasPendingUserMessages(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return false;
    }

    return messages.last.role == ChatRole.user;
  }

  List<ChatMessage> _ensureLatestUserPromptReplay({
    required CharacterProfile character,
    required List<ChatMessage> messages,
    required GameStateSnapshot gameState,
    required UserProfile? userProfile,
    required List<NpcProfile> npcProfiles,
    required List<WorldBookEntry> worldBooks,
    required String runtimeAddendum,
    required List<CharacterMemorySummary> memorySummaries,
    PromptCacheEpoch? promptCacheEpoch,
    bool forceRebuild = false,
  }) {
    if (messages.isEmpty) {
      return messages;
    }
    var latestUserIndex = -1;
    for (var index = messages.length - 1; index >= 0; index -= 1) {
      if (messages[index].role == ChatRole.user) {
        latestUserIndex = index;
        break;
      }
    }
    if (latestUserIndex == -1) {
      return messages;
    }
    final latestUser = messages[latestUserIndex];
    if (!forceRebuild &&
        (latestUser.promptReplayContent?.trim().isNotEmpty ?? false)) {
      return messages;
    }
    final replay = _apiClient.buildUserPromptReplayContent(
      character: character,
      gameState: gameState,
      userProfile: userProfile,
      npcProfiles: npcProfiles,
      worldBooks: worldBooks,
      runtimeAddendum: runtimeAddendum,
      contextMessages: messages,
      memorySummaries: memorySummaries,
      userContent: latestUser.content,
      promptCacheEpoch: promptCacheEpoch,
    );
    final next = List<ChatMessage>.from(messages);
    next[latestUserIndex] = latestUser.copyWith(
      promptReplayContent: replay,
    );
    return next;
  }

  int _estimateChatRequestTokensWithState({
    required CharacterProfile character,
    required List<ChatMessage> requestMessages,
    required CharacterMemory memory,
    required GameStateSnapshot gameState,
    required String runtimeAddendum,
    List<WorldBookEntry>? worldBooks,
    List<CharacterMemorySummary>? memorySummaries,
    PromptCacheEpoch? promptCacheEpoch,
    bool? preferExactAssistantReplay,
  }) {
    return _apiClient.estimateChatRequestTokens(
      character: character,
      gameState: gameState,
      userProfile: _findBoundUserProfile(character.id),
      npcProfiles: _npcProfilesForRuntime(character.id),
      worldBooks: worldBooks ??
          _worldBooksForCharacter(
            character.id,
            contextMessages: requestMessages,
            gameState: gameState,
            runtimeAddendum: runtimeAddendum,
          ),
      runtimeAddendum: runtimeAddendum,
      contextMessages: requestMessages,
      memorySummaries: memorySummaries ??
          _selectMemorySummaries(
            memory.summaries,
            contextMessages: requestMessages,
            gameState: gameState,
          ),
      promptCacheEpoch: promptCacheEpoch,
      preferExactAssistantReplay: preferExactAssistantReplay ??
          _apiClient.prefersExactAssistantReplay(_settings),
    );
  }

  Future<_PreparedChatRequest> _planChatRequestMessages({
    required CharacterProfile character,
    required List<ChatMessage> messages,
    String forcedRolloverReason = '',
    TurnDirective? requestTurnDirective,
    GameStateSnapshot? gameStateOverride,
  }) async {
    final memory = await _ensureMemory(character.id);
    final gameState = gameStateOverride ?? await _ensureGameState(character.id);
    final runtimeAddendum = _buildRuntimeAddendum(
      character.id,
      directiveOverride: requestTurnDirective,
      gameStateOverride: gameState,
      gameplaySystemOverride: character.gameplaySystem,
    );
    final userProfile = _findBoundUserProfile(character.id);
    final npcProfiles = _npcProfilesForRuntime(character.id);
    final preferExactAssistantReplay =
        _apiClient.prefersExactAssistantReplay(_settings);
    final promptTokenBudget = _apiClient.promptTokenBudgetFor(_settings);
    final initialWorldBooks = _worldBooksForCharacter(
      character.id,
      contextMessages: messages,
      gameState: gameState,
      runtimeAddendum: runtimeAddendum,
    );
    final initialMemorySummaries = _selectMemorySummaries(
      memory.summaries,
      contextMessages: messages,
      gameState: gameState,
    );
    final stablePrefixDigest = _apiClient.buildStablePrefixDigest(
      character: character,
      userProfile: userProfile,
      npcProfiles: npcProfiles,
      worldBooks: initialWorldBooks,
    );
    final storedEpoch = _historyCache[character.id]?.promptCacheEpoch;
    final normalizedMessages = _startOnUserBoundary(messages);
    var selected = normalizedMessages;
    var epoch = storedEpoch;
    var rolloverReason = 'warm_append';

    if (forcedRolloverReason.trim().isNotEmpty) {
      epoch = null;
      rolloverReason = forcedRolloverReason.trim();
    }

    if (epoch != null) {
      final startIndex = normalizedMessages.indexWhere(
        (message) => message.id == epoch!.startMessageId,
      );
      if (startIndex == -1) {
        rolloverReason = 'missing_epoch_anchor';
        epoch = null;
      } else if (epoch.stablePrefixDigest != stablePrefixDigest) {
        rolloverReason = 'stable_prefix_changed';
        epoch = null;
      } else {
        selected = normalizedMessages.sublist(startIndex);
      }
    } else if (forcedRolloverReason.trim().isEmpty) {
      rolloverReason = storedEpoch == null ? 'initial' : rolloverReason;
    }

    int estimate(
      List<ChatMessage> candidate,
      PromptCacheEpoch? candidateEpoch,
      List<WorldBookEntry> candidateWorldBooks,
      List<CharacterMemorySummary> candidateMemorySummaries,
    ) {
      return _estimateChatRequestTokensWithState(
        character: character,
        requestMessages: candidate,
        memory: memory,
        gameState: gameState,
        runtimeAddendum: runtimeAddendum,
        worldBooks: candidateWorldBooks,
        memorySummaries: candidateMemorySummaries,
        promptCacheEpoch: candidateEpoch,
        preferExactAssistantReplay: preferExactAssistantReplay,
      );
    }

    List<WorldBookEntry> worldBooksForWindow(List<ChatMessage> window) {
      return _worldBooksForCharacter(
        character.id,
        contextMessages: window,
        gameState: gameState,
        runtimeAddendum: runtimeAddendum,
      );
    }

    List<CharacterMemorySummary> memorySummariesForWindow(
      List<ChatMessage> window,
    ) {
      return _selectMemorySummaries(
        memory.summaries,
        contextMessages: window,
        gameState: gameState,
      );
    }

    final messageLimit = character.modelParams.contextLength;
    final exceedsMessageLimit =
        messageLimit > 0 && selected.length > messageLimit;
    final exceedsTokenBudget = estimate(
          selected,
          epoch,
          initialWorldBooks,
          initialMemorySummaries,
        ) >
        promptTokenBudget;
    final needsRollover = epoch == null ||
        exceedsMessageLimit ||
        exceedsTokenBudget ||
        rolloverReason == 'stable_prefix_changed' ||
        rolloverReason == 'missing_epoch_anchor';

    var epochId = storedEpoch?.id ?? '';
    var rolloverCount = storedEpoch?.rolloverCount ?? 0;
    if (needsRollover) {
      if (exceedsTokenBudget) {
        rolloverReason = 'token_budget';
      } else if (exceedsMessageLimit) {
        rolloverReason = 'message_limit';
      }
      final targetMessages = messageLimit <= 0
          ? normalizedMessages.length
          : max(1, (messageLimit * 0.4).floor());
      selected = _tailOnCompleteTurnBoundary(
        normalizedMessages,
        targetMessages,
      );
      epochId = IdGenerator.generic('cache_epoch');
      rolloverCount = (storedEpoch?.rolloverCount ?? -1) + 1;

      final rolloverBudget = (promptTokenBudget * 0.65).round();
      selected = _tokenBudgetPlanner.trimContext(
        messages: selected,
        maxPromptTokens: rolloverBudget,
        estimate: (candidate) {
          final candidateWorldBooks = worldBooksForWindow(candidate);
          final candidateMemorySummaries = memorySummariesForWindow(candidate);
          final candidateEpoch = _buildPromptCacheEpoch(
            id: epochId,
            selected: candidate,
            allMessages: normalizedMessages,
            previousEpoch: storedEpoch,
            gameState: gameState,
            memorySummaries: candidateMemorySummaries,
            worldBooks: candidateWorldBooks,
            stablePrefixDigest: stablePrefixDigest,
            rolloverCount: rolloverCount,
            rolloverReason: rolloverReason,
          );
          return estimate(
            candidate,
            candidateEpoch,
            candidateWorldBooks,
            candidateMemorySummaries,
          );
        },
      );
    }

    final worldBooks = worldBooksForWindow(selected);
    final memorySummaries = memorySummariesForWindow(selected);
    final PromptCacheEpoch activeEpoch;
    if (needsRollover) {
      activeEpoch = _buildPromptCacheEpoch(
        id: epochId,
        selected: selected,
        allMessages: normalizedMessages,
        previousEpoch: storedEpoch,
        gameState: gameState,
        memorySummaries: memorySummaries,
        worldBooks: worldBooks,
        stablePrefixDigest: stablePrefixDigest,
        rolloverCount: rolloverCount,
        rolloverReason: rolloverReason,
      );
    } else {
      // needsRollover 在 epoch 为空时必为 true，走到这里 epoch 一定非空。
      activeEpoch = epoch.copyWith(rolloverReason: 'warm_append');
    }
    final replayMessages = _ensureLatestUserPromptReplay(
      character: character,
      messages: selected,
      gameState: gameState,
      userProfile: userProfile,
      npcProfiles: npcProfiles,
      worldBooks: worldBooks,
      runtimeAddendum: runtimeAddendum,
      memorySummaries: memorySummaries,
      promptCacheEpoch: activeEpoch,
      forceRebuild: forcedRolloverReason.trim().isNotEmpty,
    );
    final injectedMemoryIds = <String>{
      ...activeEpoch.injectedMemorySummaryIds,
      ..._apiClient.pendingMemorySummaryIds(memorySummaries, activeEpoch),
    }.toList(growable: false)
      ..sort();
    final injectedWorldBookKeys = <String>{
      ...activeEpoch.injectedWorldBookKeys,
      ..._apiClient.pendingWorldBookKeys(worldBooks, activeEpoch),
    }.toList(growable: false)
      ..sort();
    final mergedEpoch = activeEpoch.copyWith(
      injectedMemorySummaryIds: injectedMemoryIds,
      injectedWorldBookKeys: injectedWorldBookKeys,
    );

    final estimatedTokens = _estimateChatRequestTokensWithState(
      character: character,
      requestMessages: replayMessages,
      memory: memory,
      gameState: gameState,
      runtimeAddendum: runtimeAddendum,
      worldBooks: worldBooks,
      memorySummaries: memorySummaries,
      promptCacheEpoch: mergedEpoch,
      preferExactAssistantReplay: preferExactAssistantReplay,
    );
    // 消息窗口已经按预算裁剪过，若仍超预算，说明固定上下文（协议、
    // 检查点、世界书、记忆、状态面板）本身过大，缓存阶段无法稳定工作。
    final fixedOverheadExceedsBudget = estimatedTokens > promptTokenBudget;
    final diagnostics = _buildPromptDiagnostics(
      worldBooks: worldBooks,
      memorySummaries: memorySummaries,
      cacheEpoch: mergedEpoch,
      promptTokenBudget: promptTokenBudget,
      usedExactAssistantReplay: preferExactAssistantReplay,
      fixedOverheadExceedsBudget: fixedOverheadExceedsBudget,
    );
    return _PreparedChatRequest(
      messages: replayMessages,
      epoch: mergedEpoch,
      gameState: gameState,
      userProfile: userProfile,
      npcProfiles: npcProfiles,
      worldBooks: worldBooks,
      runtimeAddendum: runtimeAddendum,
      memorySummaries: memorySummaries,
      estimatedTokens: estimatedTokens,
      promptDiagnostics: diagnostics,
    );
  }

  List<ChatMessage> _startOnUserBoundary(List<ChatMessage> messages) {
    if (messages.isEmpty || messages.first.role == ChatRole.user) {
      return List<ChatMessage>.from(messages);
    }
    final firstUser = messages.indexWhere(
      (message) => message.role == ChatRole.user,
    );
    if (firstUser == -1) {
      return messages.isEmpty
          ? const <ChatMessage>[]
          : <ChatMessage>[messages.last];
    }
    return messages.sublist(firstUser);
  }

  List<ChatMessage> _tailOnCompleteTurnBoundary(
    List<ChatMessage> messages,
    int targetMessages,
  ) {
    if (messages.length <= targetMessages) {
      return List<ChatMessage>.from(messages);
    }
    var start = messages.length - (targetMessages < 1 ? 1 : targetMessages);
    if (start < 0) {
      start = 0;
    }
    while (start < messages.length - 1 &&
        messages[start].role == ChatRole.assistant) {
      start += 1;
    }
    return messages.sublist(start);
  }

  PromptCacheEpoch _buildPromptCacheEpoch({
    required String id,
    required List<ChatMessage> selected,
    required List<ChatMessage> allMessages,
    required PromptCacheEpoch? previousEpoch,
    required GameStateSnapshot gameState,
    required List<CharacterMemorySummary> memorySummaries,
    required List<WorldBookEntry> worldBooks,
    required String stablePrefixDigest,
    required int rolloverCount,
    required String rolloverReason,
  }) {
    final selectedStartId = selected.isEmpty ? '' : selected.first.id;
    final selectedStartIndex = allMessages.indexWhere(
      (message) => message.id == selectedStartId,
    );
    final removed = selectedStartIndex <= 0
        ? const <ChatMessage>[]
        : allMessages.sublist(0, selectedStartIndex);
    // 检查点实际嵌入的子集：记忆取最新的 8 条（按时间升序排列时取末尾），
    // 动态世界书按当前列表顺序取前 6 本。injected 列表必须只包含这些
    // 真正进入前缀的内容，否则超出上限的记忆/世界书会在整个缓存阶段里
    // 被误判为「已注入」而从提示词中消失。
    final checkpointMemories = memorySummaries.length <= 8
        ? memorySummaries
        : memorySummaries.sublist(memorySummaries.length - 8);
    final dynamicWorldBooks = worldBooks
        .where(
          (entry) =>
              entry.triggerMode != WorldBookTriggerMode.always ||
              entry.injectionPosition == WorldBookInjectionPosition.rear,
        )
        .toList(growable: false);
    final checkpointWorldBooks =
        dynamicWorldBooks.take(6).toList(growable: false);
    final checkpoint = _buildPromptCacheCheckpoint(
      previousCheckpoint: previousEpoch?.checkpoint ?? '',
      removedMessages: removed,
      gameState: gameState,
      checkpointMemories: checkpointMemories,
      checkpointWorldBooks: checkpointWorldBooks,
    );
    final injectedMemoryKeys = checkpointMemories
        .map(_apiClient.memorySummaryVersionKey)
        .toList(growable: false)
      ..sort();
    final injectedWorldBookKeys = checkpointWorldBooks
        .map(_apiClient.worldBookVersionKey)
        .toList(growable: false)
      ..sort();
    return PromptCacheEpoch(
      id: id,
      startMessageId: selectedStartId,
      createdAt: DateTime.now(),
      checkpoint: checkpoint,
      rolloverCount: rolloverCount,
      rolloverReason: rolloverReason,
      stablePrefixDigest: stablePrefixDigest,
      injectedMemorySummaryIds: injectedMemoryKeys,
      injectedWorldBookKeys: injectedWorldBookKeys,
    );
  }

  String _buildPromptCacheCheckpoint({
    required String previousCheckpoint,
    required List<ChatMessage> removedMessages,
    required GameStateSnapshot gameState,
    required List<CharacterMemorySummary> checkpointMemories,
    required List<WorldBookEntry> checkpointWorldBooks,
  }) {
    final buffer = StringBuffer()
      ..writeln('这是早于当前消息窗口的冻结前情，只用于保持剧情连续；靠后的本轮状态优先。');
    if (previousCheckpoint.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('前一阶段检查点：')
        ..writeln(_clipPromptText(previousCheckpoint, 1800));
    }
    if (checkpointMemories.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('长期记忆：');
      for (final summary in checkpointMemories) {
        buffer.writeln('- ${_clipPromptText(summary.summaryText, 360)}');
      }
    }
    if (checkpointWorldBooks.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('阶段相关世界资料：');
      for (final entry in checkpointWorldBooks) {
        buffer.writeln(
          '- ${entry.title.trim().isEmpty ? '未命名世界书' : entry.title.trim()}：${_clipPromptText(entry.content, 320)}',
        );
      }
    }
    if (removedMessages.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('最近被压缩的对话：');
      for (final message
          in removedMessages.reversed.take(8).toList().reversed) {
        final content = message.role == ChatRole.assistant
            ? MessageContentParser.assistantReplayPrefixForModel(
                message.content,
                maxChars: 700,
              )
            : message.content;
        buffer.writeln(
          '- ${message.role == ChatRole.user ? '用户' : '角色'}：${_clipPromptText(content, 700)}',
        );
      }
    }
    if (!gameState.isEmpty) {
      buffer
        ..writeln()
        ..writeln('换代时状态：')
        ..writeln(_clipPromptText(_formatGameStateForPrompt(gameState), 1200));
    }
    return _clipPromptText(buffer.toString().trim(), 6000);
  }

  String _clipPromptText(String value, int maxChars) {
    final normalized = value.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars).trimRight()}\n[检查点内容已截断]';
  }

  int _countCompletedTextTokens(String text) =>
      TokenEstimator.countCompletedText(text);

  bool _hasPendingNpcUserMessages(List<NpcChatMessage> messages) {
    if (messages.isEmpty) {
      return false;
    }

    return messages.last.role == NpcMessageRole.user;
  }

  List<CharacterProfile> _normalizeCharacters(List<CharacterProfile> source) {
    if (source.isEmpty) {
      return const <CharacterProfile>[];
    }

    return source.map((character) {
      if (shouldNormalizeToTutorialDemo(character)) {
        return normalizeTutorialDemoCharacter(character);
      }
      if (!character.isPromptLocked &&
          shouldRefreshSimulatorRuntimePrompt(character.hiddenPrompt)) {
        return character.copyWith(hiddenPrompt: simulatorRuntimeProtocolPrompt);
      }
      return character;
    }).toList(growable: false);
  }

  List<UserProfile> _normalizeUserProfiles(
    List<UserProfile> source,
    List<CharacterProfile> characters,
  ) {
    if (source.isEmpty) {
      return const <UserProfile>[];
    }

    final characterIds = characters.map((character) => character.id).toSet();
    return source
        .map(
          (profile) => profile.copyWith(
            boundCharacterIds: profile.boundCharacterIds
                .where(characterIds.contains)
                .toSet()
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  List<ToolResult> _normalizeToolResults(
    List<ToolResult> source,
    List<CharacterProfile> characters,
  ) {
    if (source.isEmpty) {
      return const <ToolResult>[];
    }

    final characterIds = characters.map((character) => character.id).toSet();
    return source
        .where((result) => characterIds.contains(result.characterId))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<FanficResult> _normalizeFanficResults(
    List<FanficResult> source,
    List<CharacterProfile> characters,
  ) {
    if (source.isEmpty) {
      return const <FanficResult>[];
    }

    final characterIds = characters.map((character) => character.id).toSet();
    return source
        .where((result) => characterIds.contains(result.characterId))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<NpcProfile> _normalizeNpcProfiles(
    List<NpcProfile> source,
    List<CharacterProfile> characters,
  ) {
    if (source.isEmpty) {
      return const <NpcProfile>[];
    }

    final characterIds = characters.map((character) => character.id).toSet();
    final byKey = <String, NpcProfile>{};
    for (final profile in source.where((item) => item.id.trim().isNotEmpty)) {
      final boundIds = profile.boundCharacterIds
          .where(characterIds.contains)
          .toSet()
          .toList(growable: false);
      final characterId = characterIds.contains(profile.characterId)
          ? profile.characterId
          : boundIds.isNotEmpty
              ? boundIds.first
              : profile.characterId;
      final valid = characterIds.contains(characterId) || profile.globalBinding;
      if (!valid) {
        continue;
      }
      final normalized = profile.copyWith(
        characterId: characterId,
        boundCharacterIds: profile.globalBinding
            ? const <String>[]
            : (boundIds.isEmpty && characterIds.contains(characterId)
                ? <String>[characterId]
                : boundIds),
      );
      final key = _npcDedupeKey(normalized);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = normalized;
        continue;
      }
      byKey[key] = _mergeDuplicateNpcProfile(existing, normalized);
    }

    return byKey.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  NpcProfile _mergeDuplicateNpcProfile(
    NpcProfile left,
    NpcProfile right,
  ) {
    final primary = _preferNpcProfile(right, left) ? right : left;
    final secondary = identical(primary, right) ? left : right;
    final latest = left.updatedAt.isAfter(right.updatedAt)
        ? left.updatedAt
        : right.updatedAt;
    final mergedBoundIds = _mergeNpcBoundCharacterIds(
      left.boundCharacterIds,
      right.boundCharacterIds,
    );
    return primary.copyWith(
      description: primary.description.trim().isNotEmpty
          ? primary.description
          : secondary.description,
      impression: primary.impression.trim().isNotEmpty
          ? primary.impression
          : secondary.impression,
      roleCard: primary.roleCard.trim().isNotEmpty
          ? primary.roleCard
          : secondary.roleCard,
      roleCardFinalized:
          primary.roleCardFinalized || secondary.roleCardFinalized,
      companionEnabled: primary.companionEnabled || secondary.companionEnabled,
      globalBinding: primary.globalBinding || secondary.globalBinding,
      boundCharacterIds: primary.globalBinding || secondary.globalBinding
          ? const <String>[]
          : mergedBoundIds,
      impressionHistory: <NpcImpressionEntry>[
        ...primary.impressionHistory,
        ...secondary.impressionHistory,
      ].take(30).toList(growable: false),
      giftHistory: <NpcGiftRecord>[
        ...primary.giftHistory,
        ...secondary.giftHistory,
      ].take(50).toList(growable: false),
      updatedAt: latest,
    );
  }

  List<String> _mergeNpcBoundCharacterIds(
    List<String> left,
    List<String> right,
  ) {
    return <String>{...left, ...right}
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  List<NpcMigrationRecord> _normalizeNpcMigrations(
    List<NpcMigrationRecord> source,
  ) {
    if (source.isEmpty) {
      return const <NpcMigrationRecord>[];
    }

    return source
        .where((record) =>
            record.id.trim().isNotEmpty &&
            record.sourceNpcName.trim().isNotEmpty &&
            record.archiveText.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<WorldBookEntry> _normalizeWorldBooks(
    List<WorldBookEntry> source,
    List<CharacterProfile> characters,
  ) {
    final characterIds = characters.map((character) => character.id).toSet();
    final entriesById = <String, WorldBookEntry>{};

    for (final entry in source) {
      final content = entry.content.trim();
      if (entry.id.trim().isEmpty || content.isEmpty) {
        continue;
      }
      final defaultEntry = WorldBookEntry.defaultEntry();
      if (entry.id == defaultEntry.id &&
          content == legacyDefaultWorldBookContent.trim()) {
        entriesById[entry.id] = defaultEntry;
        continue;
      }

      final boundCharacterIds = entry.boundCharacterIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty && characterIds.contains(id))
          .toSet()
          .toList(growable: false);
      entriesById[entry.id] = entry.copyWith(
        title: entry.title.trim().isEmpty ? '未命名世界书' : entry.title.trim(),
        content: content,
        tags: _normalizeWorldBookTags(entry.tags),
        boundCharacterIds: boundCharacterIds,
        updatedAt: entry.updatedAt,
      );
    }

    entriesById.putIfAbsent(
      WorldBookEntry.defaultEntry().id,
      WorldBookEntry.defaultEntry,
    );

    return entriesById.values.toList(growable: false)
      ..sort((a, b) {
        if (a.id == WorldBookEntry.defaultEntry().id) {
          return -1;
        }
        if (b.id == WorldBookEntry.defaultEntry().id) {
          return 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  List<WorldCalendarEvent> _normalizeWorldCalendarEvents(
    List<WorldCalendarEvent> source,
    List<CharacterProfile> characters,
  ) {
    if (source.isEmpty) {
      return const <WorldCalendarEvent>[];
    }
    final characterIds = characters.map((character) => character.id).toSet();
    return source
        .where((event) =>
            event.id.trim().isNotEmpty &&
            event.characterId.trim().isNotEmpty &&
            characterIds.contains(event.characterId) &&
            event.title.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  }

  List<SaveSnapshot> _normalizeSaveSnapshots(
    List<SaveSnapshot> source,
    List<CharacterProfile> characters,
  ) {
    if (source.isEmpty) {
      return const <SaveSnapshot>[];
    }
    return source
        .where((snapshot) =>
            snapshot.id.trim().isNotEmpty &&
            snapshot.characterId.trim().isNotEmpty &&
            snapshot.archiveJson.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> createWorldBook(WorldBookDraft draft) async {
    final entry = WorldBookEntry(
      title: draft.title.trim(),
      content: draft.content.trim(),
      global: draft.global,
      tags: _normalizeWorldBookTags(draft.tags),
      boundCharacterIds: _validBoundCharacterIds(draft.boundCharacterIds),
      triggerMode: draft.triggerMode,
      keywords: _normalizeWorldBookTags(draft.keywords),
      regexPattern: draft.regexPattern.trim(),
      injectionPosition: draft.injectionPosition,
      priority: draft.priority.clamp(0, 100),
    );
    _worldBooks.insert(0, entry);
    await _store.saveWorldBooks(_worldBooks);
    await _updateGamification(
      (state) => state.incrementStat('totalWorldBooksCreated'),
      notify: false,
    );
    notifyListeners();
  }

  Future<void> updateWorldBook(String entryId, WorldBookDraft draft) async {
    final index = _worldBooks.indexWhere((entry) => entry.id == entryId);
    if (index == -1) return;
    _worldBooks[index] = _worldBooks[index].copyWith(
      title: draft.title.trim(),
      content: draft.content.trim(),
      global: draft.global,
      tags: _normalizeWorldBookTags(draft.tags),
      boundCharacterIds: _validBoundCharacterIds(draft.boundCharacterIds),
      triggerMode: draft.triggerMode,
      keywords: _normalizeWorldBookTags(draft.keywords),
      regexPattern: draft.regexPattern.trim(),
      injectionPosition: draft.injectionPosition,
      priority: draft.priority.clamp(0, 100),
    );
    await _store.saveWorldBooks(_worldBooks);
    await _updateGamification(
      (state) => state.incrementStat('totalWorldBookBulkBinds'),
      notify: false,
    );
    notifyListeners();
  }

  Future<void> deleteWorldBook(String entryId) async {
    _worldBooks.removeWhere((entry) => entry.id == entryId);
    await _store.saveWorldBooks(_worldBooks);
    await _updateGamification(
      (state) => state.incrementStat('totalWorldBookBulkBinds'),
      notify: false,
    );
    notifyListeners();
  }

  Future<void> deleteWorldBooks(Iterable<String> entryIds) async {
    final ids = entryIds
        .where((id) => id != WorldBookEntry.defaultEntry().id)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) {
      return;
    }
    _worldBooks.removeWhere((entry) => ids.contains(entry.id));
    await _store.saveWorldBooks(_worldBooks);
    notifyListeners();
  }

  Future<void> bulkBindWorldBooks({
    required Iterable<String> entryIds,
    required Iterable<String> characterIds,
  }) async {
    final ids =
        entryIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    final targets = _validBoundCharacterIds(characterIds.toList()).toSet();
    if (ids.isEmpty || targets.isEmpty) {
      return;
    }
    for (var i = 0; i < _worldBooks.length; i++) {
      final entry = _worldBooks[i];
      if (!ids.contains(entry.id)) {
        continue;
      }
      final nextBound = <String>{
        ...entry.boundCharacterIds,
        ...targets,
      }.toList(growable: false);
      _worldBooks[i] = entry.copyWith(
        global: false,
        boundCharacterIds: nextBound,
      );
    }
    await _store.saveWorldBooks(_worldBooks);
    notifyListeners();
  }

  Future<void> bulkSetWorldBookGlobal({
    required Iterable<String> entryIds,
    required bool global,
  }) async {
    final ids =
        entryIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return;
    }
    for (var i = 0; i < _worldBooks.length; i++) {
      final entry = _worldBooks[i];
      if (!ids.contains(entry.id)) {
        continue;
      }
      _worldBooks[i] = entry.copyWith(
        global: global,
        boundCharacterIds: global ? const <String>[] : entry.boundCharacterIds,
      );
    }
    await _store.saveWorldBooks(_worldBooks);
    notifyListeners();
  }

  List<String> _normalizeWorldBookTags(List<String> source) {
    return source
        .expand((tag) => tag.split(RegExp(r'[,，、\s]+')))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _validBoundCharacterIds(List<String> source) {
    final characterIds = _characters.map((character) => character.id).toSet();
    return source
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && characterIds.contains(id))
        .toSet()
        .toList(growable: false);
  }

  List<String> _validNpcBoundCharacterIds(
    List<String> source, {
    required String fallbackCharacterId,
    required bool global,
  }) {
    if (global) {
      return const <String>[];
    }
    final ids = _validBoundCharacterIds(source);
    if (ids.isNotEmpty) {
      return ids;
    }
    final fallback = fallbackCharacterId.trim();
    if (fallback.isNotEmpty && _findCharacter(fallback) != null) {
      return <String>[fallback];
    }
    return const <String>[];
  }

  _NpcCleanupResult _removeNpcProfilesForCharacterReset(String characterId) {
    final targetId = characterId.trim();
    if (targetId.isEmpty) {
      return const _NpcCleanupResult();
    }
    final removedIds = <String>[];
    var changed = false;
    for (var index = _npcProfiles.length - 1; index >= 0; index--) {
      final profile = _npcProfiles[index];
      if (_shouldRemoveNpcForCharacterReset(profile, targetId)) {
        removedIds.add(profile.id);
        _npcMessagesCache.remove(profile.id);
        _npcProfiles.removeAt(index);
        changed = true;
        continue;
      }
      if (profile.globalBinding ||
          !profile.boundCharacterIds.contains(targetId)) {
        continue;
      }
      final nextBound = profile.boundCharacterIds
          .where((id) => id != targetId)
          .toList(growable: false);
      _npcProfiles[index] = profile.copyWith(
        boundCharacterIds: nextBound,
        clearBoundCharacterIds: nextBound.isEmpty,
        updatedAt: DateTime.now(),
      );
      changed = true;
    }
    final nextInbox = Map<String, String>.from(_gamification.npcInboxReadAt)
      ..remove(targetId);
    for (final npcId in removedIds) {
      nextInbox.remove(_npcThreadReadKey(npcId));
    }
    if (nextInbox.length != _gamification.npcInboxReadAt.length) {
      _gamification = _gamification.copyWith(npcInboxReadAt: nextInbox);
      changed = true;
    }
    return _NpcCleanupResult(
      removedNpcIds: removedIds,
      changed: changed,
    );
  }

  bool _shouldRemoveNpcForCharacterReset(
      NpcProfile profile, String characterId) {
    if (profile.globalBinding) {
      return false;
    }
    final bound = profile.boundCharacterIds.toSet();
    if (profile.characterId == characterId) {
      return profile.sourceType != NpcProfileSource.migrationCard ||
          bound.isEmpty ||
          bound.length == 1 && bound.contains(characterId);
    }
    return bound.length == 1 && bound.contains(characterId);
  }

  String _resolveHiddenPrompt(String hiddenPrompt) {
    final trimmed = hiddenPrompt.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return simulatorRuntimeProtocolPrompt;
  }

  bool _characterListsEqual(
    List<CharacterProfile> left,
    List<CharacterProfile> right,
  ) {
    final leftJson = jsonEncode(
      left.map((character) => character.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((character) => character.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  bool _userProfileListsEqual(
    List<UserProfile> left,
    List<UserProfile> right,
  ) {
    final leftJson = jsonEncode(
      left.map((profile) => profile.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((profile) => profile.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  bool _toolResultListsEqual(
    List<ToolResult> left,
    List<ToolResult> right,
  ) {
    final leftJson = jsonEncode(
      left.map((result) => result.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((result) => result.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  bool _fanficResultListsEqual(
    List<FanficResult> left,
    List<FanficResult> right,
  ) {
    final leftJson = jsonEncode(
      left.map((result) => result.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((result) => result.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  bool _npcProfileListsEqual(
    List<NpcProfile> left,
    List<NpcProfile> right,
  ) {
    final leftJson = jsonEncode(
      left.map((profile) => profile.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((profile) => profile.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  bool _npcMigrationListsEqual(
    List<NpcMigrationRecord> left,
    List<NpcMigrationRecord> right,
  ) {
    final leftJson = jsonEncode(
      left.map((record) => record.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((record) => record.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  bool _worldBookListsEqual(
    List<WorldBookEntry> left,
    List<WorldBookEntry> right,
  ) {
    final leftJson = jsonEncode(
      left.map((entry) => entry.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((entry) => entry.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  bool _worldCalendarEventListsEqual(
    List<WorldCalendarEvent> left,
    List<WorldCalendarEvent> right,
  ) {
    final leftJson = jsonEncode(
      left.map((event) => event.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((event) => event.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  bool _saveSnapshotListsEqual(
    List<SaveSnapshot> left,
    List<SaveSnapshot> right,
  ) {
    final leftJson = jsonEncode(
      left.map((snapshot) => snapshot.toJson()).toList(growable: false),
    );
    final rightJson = jsonEncode(
      right.map((snapshot) => snapshot.toJson()).toList(growable: false),
    );
    return leftJson == rightJson;
  }

  @override
  void dispose() {
    _activeReplyCancellation?.cancel();
    for (final timer in _summaryTimers.values) {
      timer.cancel();
    }
    for (final timer in _npcExtractionTimers.values) {
      timer.cancel();
    }
    for (final timer in _npcProactiveTimers.values) {
      timer.cancel();
    }
    _streamingElapsedTimer?.cancel();
    _musicProgressTimer?.cancel();
    _musicPlayerStateSubscription?.cancel();
    _musicPlayer.dispose();
    super.dispose();
  }
}

class _VersionGiftMailSpec {
  const _VersionGiftMailSpec({
    required this.sourceId,
    required this.title,
    required this.description,
    required this.coins,
  });

  final String sourceId;
  final String title;
  final String description;
  final int coins;
}

const List<_VersionGiftMailSpec> _versionGiftMailSpecs = <_VersionGiftMailSpec>[
  _VersionGiftMailSpec(
    sourceId: 'official_launch_fund_v1_0',
    title: '正式版启动资金',
    description: '正式版 1.0 入场礼，送你 200 啥币，已经放进邮箱。',
    coins: 200,
  ),
];

class _ConversationUtilitySpec {
  const _ConversationUtilitySpec({
    required this.title,
    required this.instruction,
    required this.temperature,
  });

  final String title;
  final String instruction;
  final double temperature;
}

class _ReplyFormatValidation {
  const _ReplyFormatValidation(this.missing);

  final List<String> missing;

  bool get isValid => missing.isEmpty;
}

class _MapResultValidation {
  const _MapResultValidation(this.issues);

  final List<String> issues;

  bool get isValid => issues.isEmpty;
}

class _MapNpcMessageDraft {
  const _MapNpcMessageDraft({
    required this.name,
    required this.message,
  });

  final String name;
  final String message;
}

class _ParsedNpcReply {
  const _ParsedNpcReply({
    required this.messages,
    required this.impression,
    this.affinity,
    this.affinityDelta,
    this.bondStage,
    this.bondRoute,
  });

  final List<String> messages;
  final String impression;
  final int? affinity;
  final int? affinityDelta;
  final String? bondStage;
  final String? bondRoute;
}

class _ExtractedNpcProfile {
  const _ExtractedNpcProfile({
    required this.name,
    required this.description,
    required this.affinity,
    required this.impression,
  });

  final String name;
  final String description;
  final int affinity;
  final String impression;
}

class _TimelineReplayResult {
  const _TimelineReplayResult({
    required this.history,
    required this.gameState,
    required this.states,
  });

  final DialogueHistory history;
  final GameStateSnapshot gameState;
  final List<GameStateSnapshot> states;
}

class _TimelineRebuildResult {
  const _TimelineRebuildResult({
    required this.history,
    required this.gameState,
  });

  final DialogueHistory history;
  final GameStateSnapshot gameState;
}

class _NpcCleanupResult {
  const _NpcCleanupResult({
    this.removedNpcIds = const <String>[],
    this.changed = false,
  });

  final List<String> removedNpcIds;
  final bool changed;
}

Map<String, dynamic> _decodeArchiveRootSync(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  throw const FormatException('Archive root must be a JSON object.');
}

Map<String, dynamic> _decodeArchiveRootInBackground(String raw) {
  return _decodeArchiveRootSync(raw);
}

class _NpcMigrationJsonResult {
  const _NpcMigrationJsonResult({
    required this.data,
    this.repaired = false,
  });

  final Map<String, dynamic> data;
  final bool repaired;
}

class _NpcMigrationWorldBookPayload {
  const _NpcMigrationWorldBookPayload({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;
}

class _NpcMigrationCharacterPayload {
  const _NpcMigrationCharacterPayload({
    required this.name,
    required this.description,
    required this.prompt,
    required this.hiddenPrompt,
    required this.openingMessage,
    required this.simulatorOverview,
    required this.npcProfile,
    required this.userRelationship,
    required this.coreLoop,
    required this.stateSystem,
    required this.htmlRules,
    required this.choiceRules,
    required this.styleRules,
    required this.firstRoundRules,
  });

  factory _NpcMigrationCharacterPayload.fallback(
    NpcProfile npc,
    String worldType,
    String narrativeVoice,
  ) {
    final place = worldType.trim().isEmpty ? '只属于你们的新世界' : worldType.trim();
    final voice = switch (narrativeVoice.trim()) {
      'first' => '第一人称',
      'third' => '第三人称',
      _ => '第二人称',
    };
    return _NpcMigrationCharacterPayload(
      name: '与${npc.name}的新世界',
      description: '围绕你和${npc.name}延续前尘关系展开的双人文游模拟器。',
      prompt: '',
      hiddenPrompt: '',
      openingMessage: '',
      simulatorOverview: '新世界地点为$place，故事从你与${npc.name}重新确认彼此关系开始。',
      npcProfile: npc.description.trim().isEmpty
          ? '${npc.name}与旧世界有前尘联系，需要根据旧印象补全外貌、性格和语气。'
          : npc.description.trim(),
      userRelationship: npc.impression.trim().isEmpty
          ? '${npc.name}对用户保留强烈熟悉感，愿意在新世界继续靠近。'
          : npc.impression.trim(),
      coreLoop: '每回合围绕二人的相处、关系推进、日常事件、旧世界回声和新世界任务展开。',
      stateSystem: '长期维护时间、地点、当前任务、关系进展、回忆碎片、情绪状态、重要物品和剧情记录。',
      htmlRules: '每回合至少输出一个手机适配 HTML 面板，用于展示状态卡、关系卡、任务板、回忆碎片或事件卡。',
      choiceRules: '每回合底部输出 3-6 个行动选项，选项必须是用户下一步可执行的行为。',
      styleRules: '叙事采用$voice。故事主体只围绕玩家与${npc.name}展开，其他角色只能作为背景或推动关系的配角。',
      firstRoundRules: '第一回合展示抵达新世界后的场景，让用户决定如何确认关系和下一步行动，不替用户做选择。',
    );
  }

  final String name;
  final String description;
  final String prompt;
  final String hiddenPrompt;
  final String openingMessage;
  final String simulatorOverview;
  final String npcProfile;
  final String userRelationship;
  final String coreLoop;
  final String stateSystem;
  final String htmlRules;
  final String choiceRules;
  final String styleRules;
  final String firstRoundRules;

  _NpcMigrationCharacterPayload withFallback(
    NpcProfile npc,
    String worldType,
    String narrativeVoice,
  ) {
    final fallback = _NpcMigrationCharacterPayload.fallback(
      npc,
      worldType,
      narrativeVoice,
    );
    return _NpcMigrationCharacterPayload(
      name: name.trim().isEmpty ? fallback.name : name,
      description:
          description.trim().isEmpty ? fallback.description : description,
      prompt: prompt,
      hiddenPrompt: hiddenPrompt,
      openingMessage: openingMessage,
      simulatorOverview: simulatorOverview.trim().isEmpty
          ? fallback.simulatorOverview
          : simulatorOverview,
      npcProfile: npcProfile.trim().isEmpty ? fallback.npcProfile : npcProfile,
      userRelationship: userRelationship.trim().isEmpty
          ? fallback.userRelationship
          : userRelationship,
      coreLoop: coreLoop.trim().isEmpty ? fallback.coreLoop : coreLoop,
      stateSystem:
          stateSystem.trim().isEmpty ? fallback.stateSystem : stateSystem,
      htmlRules: htmlRules.trim().isEmpty ? fallback.htmlRules : htmlRules,
      choiceRules:
          choiceRules.trim().isEmpty ? fallback.choiceRules : choiceRules,
      styleRules: styleRules.trim().isEmpty ? fallback.styleRules : styleRules,
      firstRoundRules: firstRoundRules.trim().isEmpty
          ? fallback.firstRoundRules
          : firstRoundRules,
    );
  }
}
