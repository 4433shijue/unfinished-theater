import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/character_memory.dart';
import '../models/character_profile.dart';
import '../models/data_management.dart';
import '../models/dialogue_history.dart';
import '../models/fanfic_result.dart';
import '../models/game_state.dart';
import '../models/gamification.dart';
import '../models/background_music.dart';
import '../models/map_state.dart';
import '../models/npc_migration.dart';
import '../models/npc_profile.dart';
import '../models/prompt_cache.dart';
import '../models/story_systems.dart';
import '../models/tool_result.dart';
import '../models/user_profile.dart';
import '../models/world_book.dart';
import '../utils/id_generator.dart';

class LocalDataCorruptionException implements Exception {
  const LocalDataCorruptionException({
    required this.storageKey,
    required this.message,
  });

  final String storageKey;
  final String message;

  @override
  String toString() => message;
}

class LocalStore {
  static const String _installIdKey = 'install_id';
  static const String _installationMetaKey = 'installation_meta';
  static const String _tutorialSeenKey = 'tutorial_seen';
  static const String _releaseNoticeSeenPrefix = 'release_notice_seen_';
  static const String _settingsKey = 'app_settings';
  static const String _settingsPresetsKey = 'settings_presets';
  static const String _promptCacheMetricsKey = 'prompt_cache_metrics';
  static const String _charactersKey = 'characters';
  static const String _userProfilesKey = 'user_profiles';
  static const String _toolResultsKey = 'tool_results';
  static const String _fanficResultsKey = 'fanfic_results';
  static const String _npcProfilesKey = 'npc_profiles';
  static const String _npcMigrationsKey = 'npc_migrations';
  static const String _worldBooksKey = 'world_books';
  static const String _worldCalendarEventsKey = 'world_calendar_events';
  static const String _gamificationKey = 'gamification_state';
  static const String _musicTracksKey = 'user_music_tracks';
  static const String _musicStateKey = 'user_music_state';
  static const String _saveSnapshotsKey = 'save_snapshots';
  static const String _selectedCharacterKey = 'selected_character_id';
  static const String _quarantinedDataKey = 'quarantined_data_records';
  static const String _turnCommitPrefix = 'turn_commit_';
  static const String _storageBatchPrefix = 'storage_batch_';

  static const List<String> _baseSizeKeys = <String>[
    _settingsKey,
    _settingsPresetsKey,
    _promptCacheMetricsKey,
    _charactersKey,
    _userProfilesKey,
    _toolResultsKey,
    _fanficResultsKey,
    _npcProfilesKey,
    _npcMigrationsKey,
    _worldBooksKey,
    _worldCalendarEventsKey,
    _gamificationKey,
    _musicTracksKey,
    _musicStateKey,
    _saveSnapshotsKey,
    _installationMetaKey,
    _quarantinedDataKey,
  ];

  Future<List<QuarantinedDataRecord>> loadQuarantinedDataRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quarantinedDataKey);
    if (raw == null || raw.isEmpty) {
      return const <QuarantinedDataRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <QuarantinedDataRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => QuarantinedDataRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.storageKey.trim().isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (_) {
      return const <QuarantinedDataRecord>[];
    }
  }

  Future<void> deleteQuarantinedDataRecord(String recordId) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await loadQuarantinedDataRecords();
    final next = records.where((item) => item.id != recordId).toList();
    await _setStringChecked(
      prefs,
      _quarantinedDataKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> recoverPendingTurnCommits() async {
    final prefs = await SharedPreferences.getInstance();
    final journalKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_turnCommitPrefix))
        .toList(growable: false);
    for (final key in journalKeys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        await prefs.remove(key);
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException('turn commit journal must be an object');
        }
        await _applyTurnCommit(
          prefs,
          Map<String, dynamic>.from(decoded),
        );
        await prefs.remove(key);
      } on StateError {
        // Keep the journal in place so the next launch can finish the commit.
        rethrow;
      } catch (error) {
        await _quarantineCorruptValue(
          prefs: prefs,
          storageKey: key,
          rawValue: raw,
          error: error,
        );
      }
    }

    final batchKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_storageBatchPrefix))
        .toList(growable: false);
    for (final key in batchKeys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) {
        await prefs.remove(key);
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          throw const FormatException(
              'storage batch journal must be an object');
        }
        await _applyStorageBatch(
          prefs,
          Map<String, dynamic>.from(decoded),
        );
        await prefs.remove(key);
      } on StateError {
        // Keep the journal in place so the next launch can finish the commit.
        rethrow;
      } catch (error) {
        await _quarantineCorruptValue(
          prefs: prefs,
          storageKey: key,
          rawValue: raw,
          error: error,
        );
      }
    }
  }

  Future<void> commitTurnState({
    required DialogueHistory history,
    GameStateSnapshot? gameState,
    CharacterMemory? memory,
    List<NpcProfile>? npcProfiles,
    GamificationState? gamification,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'characterId': history.characterId,
      'createdAt': DateTime.now().toIso8601String(),
      'history': history.toJson(),
      if (gameState != null) 'gameState': gameState.toJson(),
      if (memory != null) 'memory': memory.toJson(),
      if (npcProfiles != null)
        'npcProfiles': npcProfiles.map((item) => item.toJson()).toList(),
      if (gamification != null) 'gamification': gamification.toJson(),
    };
    final journalKey = '$_turnCommitPrefix${history.characterId}';
    await _setStringChecked(prefs, journalKey, jsonEncode(payload));
    await _applyTurnCommit(prefs, payload);
    final removed = await prefs.remove(journalKey);
    if (!removed && prefs.containsKey(journalKey)) {
      throw StateError('无法清除剧情提交日志：$journalKey');
    }
  }

  Future<void> commitArchiveState({
    required AppSettings settings,
    required List<SettingsPreset> settingsPresets,
    required List<CharacterProfile> characters,
    required List<UserProfile> userProfiles,
    required List<ToolResult> toolResults,
    required List<FanficResult> fanficResults,
    required List<NpcProfile> npcProfiles,
    required List<NpcMigrationRecord> npcMigrations,
    required List<WorldBookEntry> worldBooks,
    required List<WorldCalendarEvent> worldCalendarEvents,
    required GamificationState gamification,
    required Map<String, DialogueHistory> histories,
    required Map<String, CharacterMemory> memories,
    required Map<String, GameStateSnapshot> gameStates,
    required Map<String, MapWorldState> mapStates,
    required Map<String, List<NpcChatMessage>> npcMessages,
    required String? selectedCharacterId,
    Iterable<String> deleteCharacterIds = const <String>[],
    Iterable<String> deleteNpcIds = const <String>[],
  }) async {
    final writes = <String, String?>{};
    for (final characterId in deleteCharacterIds) {
      final clean = characterId.trim();
      if (clean.isEmpty) continue;
      writes[_historyKey(clean)] = null;
      writes[_memoryKey(clean)] = null;
      writes[_gameStateKey(clean)] = null;
      writes[_mapStateKey(clean)] = null;
    }
    for (final npcId in deleteNpcIds) {
      final clean = npcId.trim();
      if (clean.isNotEmpty) {
        writes[_npcMessagesKey(clean)] = null;
      }
    }

    writes.addAll(<String, String?>{
      _settingsKey: jsonEncode(settings.toJson()),
      _settingsPresetsKey:
          jsonEncode(settingsPresets.map((item) => item.toJson()).toList()),
      _charactersKey:
          jsonEncode(characters.map((item) => item.toJson()).toList()),
      _userProfilesKey:
          jsonEncode(userProfiles.map((item) => item.toJson()).toList()),
      _toolResultsKey:
          jsonEncode(toolResults.map((item) => item.toJson()).toList()),
      _fanficResultsKey:
          jsonEncode(fanficResults.map((item) => item.toJson()).toList()),
      _npcProfilesKey:
          jsonEncode(npcProfiles.map((item) => item.toJson()).toList()),
      _npcMigrationsKey:
          jsonEncode(npcMigrations.map((item) => item.toJson()).toList()),
      _worldBooksKey:
          jsonEncode(worldBooks.map((item) => item.toJson()).toList()),
      _worldCalendarEventsKey: jsonEncode(
        worldCalendarEvents.map((item) => item.toJson()).toList(),
      ),
      _gamificationKey: jsonEncode(gamification.toJson()),
      _selectedCharacterKey: selectedCharacterId,
    });
    for (final entry in histories.entries) {
      writes[_historyKey(entry.key)] = jsonEncode(entry.value.toJson());
    }
    for (final entry in memories.entries) {
      writes[_memoryKey(entry.key)] = jsonEncode(entry.value.toJson());
    }
    for (final entry in gameStates.entries) {
      writes[_gameStateKey(entry.key)] = jsonEncode(entry.value.toJson());
    }
    for (final entry in mapStates.entries) {
      writes[_mapStateKey(entry.key)] = jsonEncode(entry.value.toJson());
    }
    for (final entry in npcMessages.entries) {
      writes[_npcMessagesKey(entry.key)] = jsonEncode(
        entry.value.map((item) => item.toJson()).toList(),
      );
    }

    await _commitStorageBatch(
      journalName: 'archive_import',
      writes: writes,
    );
  }

  Future<String> loadOrCreateInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      await _touchInstallationMeta(prefs, existing, isNew: false);
      return existing;
    }

    final installId = IdGenerator.installation();
    await _setStringChecked(prefs, _installIdKey, installId);
    await _touchInstallationMeta(prefs, installId, isNew: true);
    return installId;
  }

  Future<Map<String, dynamic>> loadInstallationMeta() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<Map<String, dynamic>>(
      prefs: prefs,
      storageKey: _installationMetaKey,
      fallback: () => <String, dynamic>{},
      parse: (decoded) {
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        throw const FormatException('installation meta must be an object');
      },
    );
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<AppSettings>(
      prefs: prefs,
      storageKey: _settingsKey,
      fallback: AppSettings.initial,
      parse: (decoded) {
        if (decoded is Map<String, dynamic>) {
          return AppSettings.fromJson(decoded);
        }
        if (decoded is Map) {
          return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
        }
        throw const FormatException('settings must be an object');
      },
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await _setStringChecked(
      prefs,
      _settingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<List<PromptCacheMetric>> loadPromptCacheMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<PromptCacheMetric>>(
      prefs: prefs,
      storageKey: _promptCacheMetricsKey,
      fallback: () => const <PromptCacheMetric>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('prompt cache metrics must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) =>
                  PromptCacheMetric.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      },
    );
  }

  Future<void> savePromptCacheMetrics(
    List<PromptCacheMetric> metrics,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = metrics.take(120).map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _promptCacheMetricsKey, jsonEncode(payload));
  }

  Future<List<SettingsPreset>> loadSettingsPresets() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<SettingsPreset>>(
      prefs: prefs,
      storageKey: _settingsPresetsKey,
      fallback: () => const <SettingsPreset>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('settings presets must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) =>
                  SettingsPreset.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
    );
  }

  Future<void> saveSettingsPresets(List<SettingsPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = presets.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _settingsPresetsKey, jsonEncode(payload));
  }

  Future<List<CharacterProfile>> loadCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<CharacterProfile>>(
      prefs: prefs,
      storageKey: _charactersKey,
      fallback: () => const <CharacterProfile>[],
      stopAfterQuarantine: true,
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('characters must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) =>
                  CharacterProfile.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
    );
  }

  Future<void> saveCharacters(List<CharacterProfile> characters) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = characters.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _charactersKey, jsonEncode(payload));
  }

  Future<void> commitGameplaySystem({
    required List<CharacterProfile> characters,
    required GameStateSnapshot gameState,
    required DialogueHistory history,
  }) async {
    await _commitStorageBatch(
      journalName: 'gameplay_${gameState.characterId}',
      writes: <String, String?>{
        _charactersKey:
            jsonEncode(characters.map((item) => item.toJson()).toList()),
        _gameStateKey(gameState.characterId): jsonEncode(gameState.toJson()),
        _historyKey(history.characterId): jsonEncode(history.toJson()),
      },
    );
  }

  Future<List<UserProfile>> loadUserProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<UserProfile>>(
      prefs: prefs,
      storageKey: _userProfilesKey,
      fallback: () => const <UserProfile>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('user profiles must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) => UserProfile.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
    );
  }

  Future<void> saveUserProfiles(List<UserProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = profiles.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _userProfilesKey, jsonEncode(payload));
  }

  Future<List<ToolResult>> loadToolResults() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<ToolResult>>(
      prefs: prefs,
      storageKey: _toolResultsKey,
      fallback: () => const <ToolResult>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('tool results must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) => ToolResult.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
    );
  }

  Future<void> saveToolResults(List<ToolResult> results) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = results.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _toolResultsKey, jsonEncode(payload));
  }

  Future<List<FanficResult>> loadFanficResults() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<FanficResult>>(
      prefs: prefs,
      storageKey: _fanficResultsKey,
      fallback: () => const <FanficResult>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('fanfic results must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) => FanficResult.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
    );
  }

  Future<void> saveFanficResults(List<FanficResult> results) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = results.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _fanficResultsKey, jsonEncode(payload));
  }

  Future<List<NpcProfile>> loadNpcProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<NpcProfile>>(
      prefs: prefs,
      storageKey: _npcProfilesKey,
      fallback: () => const <NpcProfile>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('npc profiles must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) => NpcProfile.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      },
    );
  }

  Future<void> saveNpcProfiles(List<NpcProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = profiles.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _npcProfilesKey, jsonEncode(payload));
  }

  Future<List<NpcMigrationRecord>> loadNpcMigrations() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<NpcMigrationRecord>>(
      prefs: prefs,
      storageKey: _npcMigrationsKey,
      fallback: () => const <NpcMigrationRecord>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('npc migrations must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) =>
                  NpcMigrationRecord.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) =>
                item.id.trim().isNotEmpty && item.archiveText.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
    );
  }

  Future<void> saveNpcMigrations(List<NpcMigrationRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = records.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _npcMigrationsKey, jsonEncode(payload));
  }

  Future<List<WorldBookEntry>> loadWorldBooks() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<WorldBookEntry>>(
      prefs: prefs,
      storageKey: _worldBooksKey,
      fallback: () => <WorldBookEntry>[WorldBookEntry.defaultEntry()],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('world books must be a list');
        }
        final entries = decoded
            .whereType<Map>()
            .map(
              (item) =>
                  WorldBookEntry.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((entry) => entry.content.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return entries.isEmpty
            ? <WorldBookEntry>[WorldBookEntry.defaultEntry()]
            : entries;
      },
    );
  }

  Future<void> saveWorldBooks(List<WorldBookEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = entries.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _worldBooksKey, jsonEncode(payload));
  }

  Future<List<WorldCalendarEvent>> loadWorldCalendarEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<WorldCalendarEvent>>(
      prefs: prefs,
      storageKey: _worldCalendarEventsKey,
      fallback: () => const <WorldCalendarEvent>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('world calendar events must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) =>
                  WorldCalendarEvent.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) =>
                item.characterId.trim().isNotEmpty &&
                item.title.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      },
    );
  }

  Future<void> saveWorldCalendarEvents(
    List<WorldCalendarEvent> events,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = events.map((item) => item.toJson()).toList();
    await _setStringChecked(
      prefs,
      _worldCalendarEventsKey,
      jsonEncode(payload),
    );
  }

  Future<GamificationState> loadGamificationState() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<GamificationState>(
      prefs: prefs,
      storageKey: _gamificationKey,
      fallback: GamificationState.initial,
      parse: (decoded) {
        if (decoded is Map<String, dynamic>) {
          return GamificationState.fromJson(decoded);
        }
        if (decoded is Map) {
          return GamificationState.fromJson(Map<String, dynamic>.from(decoded));
        }
        throw const FormatException('gamification state must be an object');
      },
    );
  }

  Future<void> saveGamificationState(GamificationState state) async {
    final prefs = await SharedPreferences.getInstance();
    await _setStringChecked(
      prefs,
      _gamificationKey,
      jsonEncode(state.toJson()),
    );
  }

  Future<List<BackgroundTrack>> loadMusicTracks() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<BackgroundTrack>>(
      prefs: prefs,
      storageKey: _musicTracksKey,
      fallback: () => const <BackgroundTrack>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('music tracks must be a list');
        }
        return decoded
            .whereType<Map>()
            .map((item) => BackgroundTrack.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.id.trim().isNotEmpty)
            .toList(growable: false);
      },
    );
  }

  Future<void> saveMusicTracks(List<BackgroundTrack> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = tracks.map((track) => track.toJson()).toList();
    await _setStringChecked(prefs, _musicTracksKey, jsonEncode(payload));
  }

  Future<MusicPlaybackState> loadMusicPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<MusicPlaybackState>(
      prefs: prefs,
      storageKey: _musicStateKey,
      fallback: MusicPlaybackState.initial,
      parse: (decoded) {
        if (decoded is Map<String, dynamic>) {
          return MusicPlaybackState.fromJson(decoded);
        }
        if (decoded is Map) {
          return MusicPlaybackState.fromJson(
              Map<String, dynamic>.from(decoded));
        }
        throw const FormatException('music playback state must be an object');
      },
    );
  }

  Future<void> saveMusicPlaybackState(MusicPlaybackState state) async {
    final prefs = await SharedPreferences.getInstance();
    await _setStringChecked(
      prefs,
      _musicStateKey,
      jsonEncode(state.toJson()),
    );
  }

  Future<List<SaveSnapshot>> loadSaveSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadJsonValue<List<SaveSnapshot>>(
      prefs: prefs,
      storageKey: _saveSnapshotsKey,
      fallback: () => const <SaveSnapshot>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('save snapshots must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) => SaveSnapshot.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) =>
                item.id.trim().isNotEmpty &&
                item.characterId.trim().isNotEmpty &&
                item.archiveJson.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
    );
  }

  Future<void> saveSaveSnapshots(List<SaveSnapshot> snapshots) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = snapshots.map((item) => item.toJson()).toList();
    await _setStringChecked(prefs, _saveSnapshotsKey, jsonEncode(payload));
  }

  Future<List<NpcChatMessage>> loadNpcMessages(String npcId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _npcMessagesKey(npcId);
    return _loadJsonValue<List<NpcChatMessage>>(
      prefs: prefs,
      storageKey: key,
      fallback: () => const <NpcChatMessage>[],
      parse: (decoded) {
        if (decoded is! List) {
          throw const FormatException('npc messages must be a list');
        }
        return decoded
            .whereType<Map>()
            .map(
              (item) => NpcChatMessage.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      },
    );
  }

  Future<void> saveNpcMessages(
    String npcId,
    List<NpcChatMessage> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = messages.map((item) => item.toJson()).toList();
    await _setStringChecked(
      prefs,
      _npcMessagesKey(npcId),
      jsonEncode(payload),
    );
  }

  Future<void> deleteNpcMessages(String npcId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_npcMessagesKey(npcId));
  }

  Future<String?> loadSelectedCharacterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedCharacterKey);
  }

  Future<void> saveSelectedCharacterId(String? characterId) async {
    final prefs = await SharedPreferences.getInstance();
    if (characterId == null || characterId.isEmpty) {
      await prefs.remove(_selectedCharacterKey);
      return;
    }

    await _setStringChecked(prefs, _selectedCharacterKey, characterId);
  }

  Future<bool> hasSeenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialSeenKey) ?? false;
  }

  Future<void> setTutorialSeen(bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialSeenKey, seen);
  }

  Future<bool> hasSeenReleaseNotice(String releaseId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_releaseNoticeSeenPrefix$releaseId') ?? false;
  }

  Future<void> setReleaseNoticeSeen(String releaseId, bool seen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_releaseNoticeSeenPrefix$releaseId', seen);
  }

  Future<DialogueHistory> loadDialogueHistory(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _historyKey(characterId);
    return _loadJsonValue<DialogueHistory>(
      prefs: prefs,
      storageKey: key,
      fallback: () => DialogueHistory.empty(characterId),
      parse: (decoded) {
        if (decoded is Map<String, dynamic>) {
          return DialogueHistory.fromJson(decoded).copyWith(
            characterId: characterId,
          );
        }
        if (decoded is Map) {
          return DialogueHistory.fromJson(
            Map<String, dynamic>.from(decoded),
          ).copyWith(characterId: characterId);
        }
        throw const FormatException('dialogue history must be an object');
      },
    );
  }

  Future<void> saveDialogueHistory(DialogueHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    await _setStringChecked(
      prefs,
      _historyKey(history.characterId),
      jsonEncode(history.toJson()),
    );
  }

  Future<CharacterMemory> loadCharacterMemory(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _memoryKey(characterId);
    return _loadJsonValue<CharacterMemory>(
      prefs: prefs,
      storageKey: key,
      fallback: () => CharacterMemory.empty(characterId),
      parse: (decoded) {
        if (decoded is Map<String, dynamic>) {
          return CharacterMemory.fromJson(decoded).copyWith(
            characterId: characterId,
          );
        }
        if (decoded is Map) {
          return CharacterMemory.fromJson(
            Map<String, dynamic>.from(decoded),
          ).copyWith(characterId: characterId);
        }
        throw const FormatException('character memory must be an object');
      },
    );
  }

  Future<GameStateSnapshot> loadGameState(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _gameStateKey(characterId);
    return _loadJsonValue<GameStateSnapshot>(
      prefs: prefs,
      storageKey: key,
      fallback: () => GameStateSnapshot.empty(characterId),
      parse: (decoded) {
        if (decoded is Map<String, dynamic>) {
          return GameStateSnapshot.fromJson(decoded).copyWith(
            characterId: characterId,
          );
        }
        if (decoded is Map) {
          return GameStateSnapshot.fromJson(
            Map<String, dynamic>.from(decoded),
          ).copyWith(characterId: characterId);
        }
        throw const FormatException('game state must be an object');
      },
    );
  }

  Future<void> saveGameState(GameStateSnapshot state) async {
    final prefs = await SharedPreferences.getInstance();
    await _setStringChecked(
      prefs,
      _gameStateKey(state.characterId),
      jsonEncode(state.toJson()),
    );
  }

  Future<MapWorldState> loadMapState(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _mapStateKey(characterId);
    return _loadJsonValue<MapWorldState>(
      prefs: prefs,
      storageKey: key,
      fallback: () => MapWorldState.empty(characterId),
      parse: (decoded) {
        if (decoded is Map<String, dynamic>) {
          final state = MapWorldState.fromJson(decoded);
          return state.characterId.trim().isEmpty
              ? state.copyWith(characterId: characterId)
              : state;
        }
        if (decoded is Map) {
          final state =
              MapWorldState.fromJson(Map<String, dynamic>.from(decoded));
          return state.characterId.trim().isEmpty
              ? state.copyWith(characterId: characterId)
              : state;
        }
        throw const FormatException('map state must be an object');
      },
    );
  }

  Future<void> saveMapState(MapWorldState state) async {
    final prefs = await SharedPreferences.getInstance();
    await _setStringChecked(
      prefs,
      _mapStateKey(state.characterId),
      jsonEncode(state.toJson()),
    );
  }

  Future<void> saveCharacterMemory(CharacterMemory memory) async {
    final prefs = await SharedPreferences.getInstance();
    await _setStringChecked(
      prefs,
      _memoryKey(memory.characterId),
      jsonEncode(memory.toJson()),
    );
  }

  Future<int> estimateStoredBytesForKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(key);
    return _estimatedBytes(value);
  }

  Future<Map<String, int>> estimateStorageBytes({
    required Iterable<String> characterIds,
    required Iterable<String> npcIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, int>{};

    for (final key in _baseSizeKeys) {
      result[key] = _estimatedBytes(prefs.get(key));
    }
    for (final characterId in characterIds) {
      final clean = characterId.trim();
      if (clean.isEmpty) {
        continue;
      }
      result[_historyKey(clean)] =
          _estimatedBytes(prefs.get(_historyKey(clean)));
      result[_memoryKey(clean)] = _estimatedBytes(prefs.get(_memoryKey(clean)));
      result[_gameStateKey(clean)] =
          _estimatedBytes(prefs.get(_gameStateKey(clean)));
      result[_mapStateKey(clean)] =
          _estimatedBytes(prefs.get(_mapStateKey(clean)));
    }
    for (final npcId in npcIds) {
      final clean = npcId.trim();
      if (clean.isEmpty) {
        continue;
      }
      result[_npcMessagesKey(clean)] =
          _estimatedBytes(prefs.get(_npcMessagesKey(clean)));
    }

    return result;
  }

  Future<void> deleteCharacterData(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey(characterId));
    await prefs.remove(_memoryKey(characterId));
    await prefs.remove(_gameStateKey(characterId));
    await prefs.remove(_mapStateKey(characterId));
  }

  Future<T> _loadJsonValue<T>({
    required SharedPreferences prefs,
    required String storageKey,
    required T Function() fallback,
    required T Function(Object? decoded) parse,
    bool stopAfterQuarantine = false,
  }) async {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return fallback();
    }
    try {
      return parse(jsonDecode(raw));
    } catch (error) {
      await _quarantineCorruptValue(
        prefs: prefs,
        storageKey: storageKey,
        rawValue: raw,
        error: error,
      );
      if (stopAfterQuarantine) {
        throw LocalDataCorruptionException(
          storageKey: storageKey,
          message: '本地数据「$storageKey」无法解析，原始内容已隔离保留。请确认后再使用安全数据继续。',
        );
      }
      return fallback();
    }
  }

  Future<void> _quarantineCorruptValue({
    required SharedPreferences prefs,
    required String storageKey,
    required String rawValue,
    required Object error,
  }) async {
    final records = await loadQuarantinedDataRecords();
    final alreadyStored = records.any(
      (item) => item.storageKey == storageKey && item.rawValue == rawValue,
    );
    if (!alreadyStored) {
      final next = <QuarantinedDataRecord>[
        QuarantinedDataRecord(
          storageKey: storageKey,
          rawValue: rawValue,
          error: error.toString(),
        ),
        ...records,
      ];
      await _setStringChecked(
        prefs,
        _quarantinedDataKey,
        jsonEncode(next.map((item) => item.toJson()).toList()),
      );
    }
    final removed = await prefs.remove(storageKey);
    if (!removed && prefs.containsKey(storageKey)) {
      throw LocalDataCorruptionException(
        storageKey: storageKey,
        message: '检测到损坏数据，但无法安全移入隔离区：$storageKey。',
      );
    }
  }

  Future<void> _applyTurnCommit(
    SharedPreferences prefs,
    Map<String, dynamic> payload,
  ) async {
    final characterId = payload['characterId']?.toString().trim() ?? '';
    final rawHistory = payload['history'];
    if (characterId.isEmpty || rawHistory is! Map) {
      throw const FormatException('turn commit is missing character history');
    }
    final history = DialogueHistory.fromJson(
      Map<String, dynamic>.from(rawHistory),
    ).copyWith(characterId: characterId);
    await _setStringChecked(
      prefs,
      _historyKey(characterId),
      jsonEncode(history.toJson()),
    );

    final rawState = payload['gameState'];
    if (rawState is Map) {
      final state = GameStateSnapshot.fromJson(
        Map<String, dynamic>.from(rawState),
      ).copyWith(characterId: characterId);
      await _setStringChecked(
        prefs,
        _gameStateKey(characterId),
        jsonEncode(state.toJson()),
      );
    }

    final rawMemory = payload['memory'];
    if (rawMemory is Map) {
      final memory = CharacterMemory.fromJson(
        Map<String, dynamic>.from(rawMemory),
      ).copyWith(characterId: characterId);
      await _setStringChecked(
        prefs,
        _memoryKey(characterId),
        jsonEncode(memory.toJson()),
      );
    }

    final rawNpcProfiles = payload['npcProfiles'];
    if (rawNpcProfiles is List) {
      final profiles = rawNpcProfiles
          .whereType<Map>()
          .map((item) => NpcProfile.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      await _setStringChecked(
        prefs,
        _npcProfilesKey,
        jsonEncode(profiles.map((item) => item.toJson()).toList()),
      );
    }

    final rawGamification = payload['gamification'];
    if (rawGamification is Map) {
      final gamification = GamificationState.fromJson(
        Map<String, dynamic>.from(rawGamification),
      );
      await _setStringChecked(
        prefs,
        _gamificationKey,
        jsonEncode(gamification.toJson()),
      );
    }
  }

  Future<void> _commitStorageBatch({
    required String journalName,
    required Map<String, String?> writes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final journalKey = '$_storageBatchPrefix$journalName';
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'writes': writes,
    };
    await _setStringChecked(prefs, journalKey, jsonEncode(payload));
    await _applyStorageBatch(prefs, payload);
    final removed = await prefs.remove(journalKey);
    if (!removed && prefs.containsKey(journalKey)) {
      throw StateError('无法清除批量提交日志：$journalKey');
    }
  }

  Future<void> _applyStorageBatch(
    SharedPreferences prefs,
    Map<String, dynamic> payload,
  ) async {
    final rawWrites = payload['writes'];
    if (rawWrites is! Map) {
      throw const FormatException('storage batch is missing writes');
    }
    for (final entry in rawWrites.entries) {
      final key = entry.key.toString();
      if (key.isEmpty || key.startsWith(_storageBatchPrefix)) {
        throw FormatException('invalid storage batch key: $key');
      }
      final value = entry.value;
      if (value == null) {
        final removed = await prefs.remove(key);
        if (!removed && prefs.containsKey(key)) {
          throw StateError('本地存储删除失败：$key');
        }
        continue;
      }
      await _setStringChecked(prefs, key, value.toString());
    }
  }

  Future<void> _setStringChecked(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    final saved = await prefs.setString(key, value);
    if (!saved) {
      throw StateError('本地存储写入失败：$key');
    }
  }

  Future<void> _touchInstallationMeta(
    SharedPreferences prefs,
    String installId, {
    required bool isNew,
  }) async {
    final now = DateTime.now().toIso8601String();
    final current = await loadInstallationMeta();
    final next = <String, dynamic>{
      'installId': installId,
      'createdAt': isNew ? now : (current['createdAt'] ?? now),
      'lastOpenedAt': now,
      'storageDriver': 'shared_preferences',
    };
    await _setStringChecked(prefs, _installationMetaKey, jsonEncode(next));
  }

  String _historyKey(String characterId) => 'history_$characterId';

  String _memoryKey(String characterId) => 'memory_$characterId';

  String _gameStateKey(String characterId) => 'game_state_$characterId';

  String _mapStateKey(String characterId) => 'map_state_$characterId';

  String _npcMessagesKey(String npcId) => 'npc_messages_$npcId';

  int _estimatedBytes(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is String) {
      return value.length * 2;
    }
    if (value is bool || value is int || value is double) {
      return value.toString().length * 2;
    }
    if (value is List<String>) {
      return value.fold<int>(0, (sum, item) => sum + item.length * 2);
    }
    return value.toString().length * 2;
  }
}
