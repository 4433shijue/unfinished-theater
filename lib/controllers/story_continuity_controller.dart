part of 'app_state_controller.dart';

// These methods are part of the controller library; state transitions remain
// centralized here instead of being performed by UI widgets.
extension StoryContinuityController on AppStateController {
  dynamic _remapStoryIds(dynamic value, Map<String, String> ids) {
    if (value is String) return ids[value] ?? value;
    if (value is List) return value.map((v) => _remapStoryIds(v, ids)).toList();
    if (value is Map) {
      return {
        for (final e in value.entries)
          ids[e.key] ??
              e.key
                  .toString()
                  .split('/')
                  .map((part) => ids[part] ?? part)
                  .join('/'): _remapStoryIds(e.value, ids)
      };
    }
    return value;
  }

  StoryContinuityState _continuityAtMessage(
      StoryContinuityState state, String messageId, String branchId) {
    final event = state.events
        .where((e) => storyStrings(e['sourceIds']).contains(messageId))
        .firstOrNull;
    if (event == null) return StoryContinuityState(characterId: branchId);
    final sequence = storyInt(event['sequence']);
    final later = state.events
        .where((e) => storyInt(e['sequence']) > sequence)
        .firstOrNull;
    final snapshot = later == null
        ? state.snapshot()
        : storyMap(storyMap(state.checkpoints[later['id']])['before']);
    final result = StoryContinuityState(characterId: branchId, data: snapshot);
    result.data['checkpoints'] = {
      for (final entry in state.checkpoints.entries)
        if (storyInt(storyMap(entry.value)['sequence']) <= sequence)
          entry.key: entry.value
    };
    return result;
  }

  StoryContinuityState get currentContinuity =>
      _continuityCache[_selectedCharacterId] ??
      StoryContinuityState(characterId: _selectedCharacterId ?? '');
  bool get storyOperationInProgress => _storyOperationInProgress;

  Map<String, dynamic> _decodeStoryObject(String raw) {
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start < 0 || end < start) return {};
      return storyMap(jsonDecode(raw.substring(start, end + 1)));
    } catch (_) {
      return {};
    }
  }

  Future<StoryContinuityState> _ensureContinuity(String worldId) async {
    if (_continuityCache.containsKey(worldId)) {
      return _continuityCache[worldId]!;
    }
    final state = await _store.loadStoryContinuity(worldId);
    state.data['reading'] = {
      ...state.reading,
      ...await _store.loadStoryReading(worldId)
    };
    _continuityCache[worldId] = state;
    return state;
  }

  Future<void> _activateStoryWorld(String worldId) async {
    for (final character in _characters) {
      await _ensureContinuity(character.id);
    }
    final upgradingLegacy =
        !_continuityCache.values.any((s) => s.data['npcMigrationVersion'] == 1);
    // Seed every legacy world before projecting one of them onto the active
    // runtime, so visiting worlds in a different order cannot change baselines.
    for (final character in _characters) {
      final state = await _ensureContinuity(character.id);
      if (state.data['npcMigrationVersion'] == 1) continue;
      final worlds = state.npcWorlds;
      final archives = storyMap(state.data['legacyNpcArchives']);
      final baselines = storyMap(state.data['legacyNpcBaselines']);
      for (final npc in _npcProfiles.where((n) => n.isBoundTo(character.id))) {
        final messages = upgradingLegacy && npc.characterId == character.id
            ? await _store.loadNpcMessages(npc.id)
            : <NpcChatMessage>[];
        final mixed =
            npc.globalBinding || npc.boundCharacterIds.toSet().length > 1;
        if (mixed && messages.isNotEmpty) {
          archives[npc.id] = messages.map((m) => m.toJson()).toList();
        }
        var baseline = upgradingLegacy || npc.characterId == character.id
            ? npc
            : npc.copyWith(
                affinity: 0,
                lifecycle: NpcLifecycle.active,
                impression: '',
                impressionHistory: [],
                bondRoute: const NpcBondRoute(),
                giftHistory: [],
                npcMemory: [],
                worldEvents: [],
                relationshipEdges: [],
                runtimeState: const NpcRuntimeState());
        if (upgradingLegacy) {
          baselines[npc.id] = baseline.toJson();
        }
        if (upgradingLegacy && mixed) {
          baseline = baseline.copyWith(
              impression: '',
              impressionHistory: [],
              npcMemory: [],
              worldEvents: [],
              relationshipEdges: [],
              giftHistory: [],
              runtimeState: const NpcRuntimeState(),
              bondRoute: NpcBondRoute(
                  score: baseline.bondRoute.score,
                  stage: baseline.bondRoute.stage,
                  route: baseline.bondRoute.route));
        }
        worlds[npc.id] = NpcWorldState(
                profile: baseline.toJson(),
                messages: mixed ? [] : messages,
                legacyBaseline: upgradingLegacy)
            .toJson();
      }
      final next = state.copy()
        ..data.addAll({
          'npcWorlds': worlds,
          'legacyNpcArchives': archives,
          'legacyNpcBaselines': baselines,
          'npcMigrationVersion': 1
        });
      await _store.commitStoryWorkspace(state: next);
      _continuityCache[character.id] = next;
    }
    var state = await _ensureContinuity(worldId);
    final worlds = state.npcWorlds;
    var added = false;
    for (final npc in _npcProfiles.where((n) => n.isBoundTo(worldId))) {
      if (worlds.containsKey(npc.id)) continue;
      if (state.data['npcScopeLocked'] == true && npc.characterId != worldId) {
        continue;
      }
      final baseline = npc.characterId == worldId
          ? npc
          : npc.copyWith(
              affinity: 0,
              lifecycle: NpcLifecycle.active,
              impression: '',
              impressionHistory: [],
              bondRoute: const NpcBondRoute(),
              giftHistory: [],
              npcMemory: [],
              worldEvents: [],
              relationshipEdges: [],
              runtimeState: const NpcRuntimeState());
      worlds[npc.id] =
          NpcWorldState(profile: baseline.toJson(), messages: []).toJson();
      added = true;
    }
    if (added) {
      state = state.copy()..data['npcWorlds'] = worlds;
      await _store.commitStoryWorkspace(state: state);
      _continuityCache[worldId] = state;
    }
    _npcMessagesCache.clear();
    for (var i = 0; i < _npcProfiles.length; i++) {
      final raw = storyMap(state.npcWorlds[_npcProfiles[i].id]);
      if (raw.isEmpty) continue;
      final world = NpcWorldState.fromJson(raw);
      _npcProfiles[i] = world.project(_npcProfiles[i]);
      _npcMessagesCache[_npcProfiles[i].id] = world.messages;
    }
    _activeTurnDirective = null;
  }

  StoryContinuityState _captureNpcWorld(StoryContinuityState state) {
    final next = state.copy();
    final worlds = next.npcWorlds;
    for (final npc in _npcProfilesForRuntime(state.characterId)) {
      final previous = storyMap(worlds[npc.id]);
      worlds[npc.id] = NpcWorldState(
              profile: npc.toJson(),
              messages: _npcMessagesCache[npc.id] ??
                  NpcWorldState.fromJson(previous).messages,
              legacyBaseline: previous['legacyBaseline'] == true)
          .toJson();
    }
    next.data['npcWorlds'] = worlds;
    return next;
  }

  Future<void> _persistNpcWorldProfiles() async {
    final id = _selectedCharacterId;
    if (id == null) {
      await _store.saveNpcProfiles(_npcProfiles);
      return;
    }
    final next = _captureNpcWorld(await _ensureContinuity(id));
    await _store.commitStoryWorkspace(state: next, npcProfiles: _npcProfiles);
    _continuityCache[id] = next;
  }

  Future<void> _saveNpcWorldMessages(
      String npcId, List<NpcChatMessage> messages) async {
    final npc = npcProfileById(npcId);
    if (npc == null) return;
    final id = _characterForNpcInteraction(npc)?.id;
    if (id == null) {
      await _store.saveNpcMessages(npcId, messages);
      return;
    }
    final state = await _ensureContinuity(id);
    var next = state.copy();
    final oldIds = NpcWorldState.fromJson(storyMap(state.npcWorlds[npcId]))
        .messages
        .map((m) => m.id)
        .toSet();
    final batches = <String, List<NpcChatMessage>>{};
    for (final message in messages) {
      if (message.role != NpcMessageRole.npc || oldIds.contains(message.id)) {
        continue;
      }
      final batchId = message.batchId.isEmpty ? message.id : message.batchId;
      batches.putIfAbsent(batchId, () => []).add(message);
    }
    // Proactive letters also have a historical baseline for later IF rewrites.
    for (final batch in batches.entries) {
      next = StoryContinuityEngine.apply(
          state: next,
          eventId: batch.key,
          sourceIds: batch.value.map((m) => m.id).toList(),
          narrative: batch.value.map((m) => m.content).join('\n'),
          patch: {},
          npcIds: {npcId},
          privateNpcId: npcId,
          checkpoint: {
            'gameState': (await _ensureGameState(id)).toJson(),
            'mainMessageIds':
                (await _ensureHistory(id)).messages.map((m) => m.id).toList(),
            'gameplaySystem': _findCharacter(id)?.gameplaySystem?.toJson(),
            'mapState': (await _ensureMapState(id)).toJson()
          });
    }
    final worlds = next.npcWorlds;
    worlds[npcId] = NpcWorldState(
            profile: npc.toJson(),
            messages: messages,
            legacyBaseline: storyMap(worlds[npcId])['legacyBaseline'] == true)
        .toJson();
    next.data['npcWorlds'] = worlds;
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[id] = next;
  }

  Future<StoryContinuityState> _continuityForCompletedTurn(
      String worldId,
      String messageId,
      String content,
      GameStateSnapshot previousState,
      Map<String, dynamic> patch) async {
    final state = _captureNpcWorld(await _ensureContinuity(worldId));
    final existing =
        state.events.where((e) => e['id'] == messageId).firstOrNull;
    if (existing != null) {
      final checkpoint = storyMap(state.checkpoints[messageId]);
      final before = StoryContinuityState(
          characterId: worldId, data: storyMap(checkpoint['before']));
      final revised = StoryContinuityEngine.apply(
          state: before,
          eventId: messageId,
          sourceIds: [messageId],
          narrative: content,
          patch: patch,
          npcIds: before.npcWorlds.keys.toSet(),
          checkpoint: checkpoint);
      final next = StoryContinuityEngine.invalidateSources(state, {messageId});
      next.data['facts'] = [
        ...next.facts.where((f) => f['eventId'] != messageId),
        ...revised.facts.where((f) => f['eventId'] == messageId)
      ];
      next.data['knowledge'] = [
        ...next.knowledge.where((k) => k['eventId'] != messageId),
        ...revised.knowledge.where((k) => k['eventId'] == messageId)
      ];
      next.data['conflicts'] = [
        ...next.conflicts,
        ...revised.conflicts.where((c) => !next.conflicts
            .any((old) => old['fingerprint'] == c['fingerprint']))
      ];
      if (next.scene['sourceId'] == messageId) {
        next.data['scene'] = revised.scene;
      }
      return next;
    }
    final next = StoryContinuityEngine.apply(
        state: state,
        eventId: messageId,
        sourceIds: [messageId],
        narrative: content,
        patch: patch,
        npcIds: _npcProfilesForRuntime(worldId).map((n) => n.id).toSet(),
        checkpoint: {
          'gameState': previousState.toJson(),
          'mainMessageIds':
              (_historyCache[worldId]?.messages ?? <ChatMessage>[])
                  .takeWhile((m) => m.id != messageId)
                  .map((m) => m.id)
                  .toList(),
          'gameplaySystem': _findCharacter(worldId)?.gameplaySystem?.toJson(),
          'mapState': (await _ensureMapState(worldId)).toJson()
        });
    next.data['mapState'] = (await _ensureMapState(worldId)).toJson();
    final directors = next.directors..remove('turn');
    next.data['directors'] = directors;
    if (_closingStoryScene) {
      final scene = {...next.scene, 'closed': true, 'endMessageId': messageId};
      next.data['scene'] = scene;
      next.data['chapters'] = [
        ...next.chapters.where((c) => c['id'] != scene['id']),
        scene
      ];
      next.data['directors'] = directors..remove('scene');
    }
    return next;
  }

  Future<void> _invalidateContinuitySources(
      String worldId, Set<String> ids) async {
    final next = StoryContinuityEngine.invalidateSources(
        await _ensureContinuity(worldId), ids);
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[worldId] = next;
  }

  StoryContinuityState _storyContext(String worldId) =>
      _storyContextOverride?.characterId == worldId
          ? _storyContextOverride!
          : _continuityCache[worldId] ??
              StoryContinuityState(characterId: worldId);

  String _npcKnownContext(String worldId, String npcId) =>
      StoryContinuityEngine.factsPrompt(_storyContext(worldId), npcId: npcId);

  String _visibleWorldBooksForNpc(String worldId, String npcId) => _worldBooks
      .where((book) => book.appliesTo(worldId) && book.visibility.allows(npcId))
      .map((book) => '${book.title}\n${book.content}')
      .join('\n\n');

  String _npcKnowledgePrompt(StoryContinuityState state) => '【人物知情边界】\n'
      '叙述者掌握全局不代表角色知道。未列出的秘密不可作为该角色的已知事实；怀疑必须保持不确定。\n'
      '${_npcProfilesForRuntime(state.characterId).map((n) => '${n.name}（${n.id}）：\n${StoryContinuityEngine.factsPrompt(state, npcId: n.id)}').join('\n')}';

  Future<void> saveDirectorPreferences(
      String scope, Map<String, String> values) async {
    if (!const ['turn', 'scene', 'story'].contains(scope)) {
      throw ArgumentError('scope');
    }
    final next = currentContinuity.copy();
    final directors = next.directors;
    directors[scope] = {
      for (final e in values.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim()
    };
    next.data['directors'] = directors;
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[next.characterId] = next;
    _notifyStoryChanges();
  }

  Future<void> rememberStoryFact(
      {required String text,
      required List<String> sourceIds,
      String? npcId,
      String? key}) async {
    if (text.trim().isEmpty) return;
    final next = currentContinuity.copy();
    final id = IdGenerator.generic('fact');
    next.data['facts'] = [
      ...next.facts,
      {
        'id': id,
        'key': key ?? id,
        'text': text.trim(),
        'pinned': true,
        'sourceIds': sourceIds,
        'sequence': next.sequence,
        if (npcId != null) 'privateNpcId': npcId
      }
    ];
    if (npcId != null) {
      next.data['knowledge'] = [
        ...next.knowledge,
        {
          'npcId': npcId,
          'factId': id,
          'factKey': key ?? id,
          'level': 'told',
          'sequence': next.sequence,
          'sourceIds': sourceIds
        }
      ];
    }
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[next.characterId] = next;
    await _invalidateStoryReplay(next.characterId);
    _notifyStoryChanges();
  }

  Future<void> setFactPinned(String factId, bool pinned) async {
    final next = currentContinuity.copy();
    next.data['facts'] = next.facts
        .map((f) => f['id'] == factId ? {...f, 'pinned': pinned} : f)
        .toList();
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[next.characterId] = next;
    _notifyStoryChanges();
  }

  List<String> factCorrectionImpact(String factId) {
    final fact =
        currentContinuity.facts.where((f) => f['id'] == factId).firstOrNull;
    if (fact == null) return [];
    final sourceIds = storyStrings(fact['sourceIds']).toSet();
    final summaries = currentMemory.summaries
        .where((s) => s.relatedMessageIds.any(sourceIds.contains))
        .toList();
    final knowledge = currentContinuity.knowledge
        .where((k) => k['factId'] == factId)
        .toList();
    const labels = {
      'witnessed': '亲见',
      'told': '被告知',
      'suspected': '怀疑',
      'unknown': '未知'
    };
    return [
      '关联长期记忆 ${summaries.length} 条',
      ...summaries.map((s) => '• ${s.summaryText}'),
      '关联知情记录 ${knowledge.length} 条',
      ...knowledge.map((k) =>
          '• ${npcProfileById(k['npcId'].toString())?.name ?? '已移除人物'} · ${labels[k['level']] ?? '未知'}'),
      '原聊天正文保留'
    ];
  }

  Future<void> correctStoryFact(String factId, String text,
      {required bool historical, String? conflictId}) async {
    if (text.trim().isEmpty) return;
    final next = currentContinuity.copy();
    final facts = next.facts;
    final index = facts.indexWhere((f) => f['id'] == factId);
    if (index < 0) throw StateError('这条事实已经不存在。');
    final old = facts[index];
    final newId = IdGenerator.generic('fact');
    facts[index] = {...old, 'retired': true};
    facts.add({
      ...old,
      'id': newId,
      'text': text.trim(),
      'retired': false,
      'sequence': historical ? old['sequence'] : next.sequence,
      'supersedes': factId,
      'historicalCorrection': historical,
      'needsReview': false
    });
    if (historical) {
      next.data['checkpoints'] = {
        for (final entry in next.checkpoints.entries)
          entry.key: {
            ...storyMap(entry.value),
            'before': _correctHistoricalSnapshot(
                storyMap(storyMap(entry.value)['before']), factId, facts.last)
          }
      };
    }
    next.data['facts'] = facts;
    next.data['knowledge'] = next.knowledge
        .map((k) => k['factId'] == factId
            ? {...k, 'factId': newId, if (!historical) 'level': 'unknown'}
            : k)
        .toList();
    next.data['conflicts'] = next.conflicts
        .map((c) => c['id'] == conflictId ? {...c, 'resolved': true} : c)
        .toList();
    final history = await _ensureHistory(next.characterId);
    final invalidated = await _invalidateSummariesForMessageIds(
        characterId: next.characterId,
        history: history.copyWith(clearPromptCacheEpoch: true),
        changedMessageIds: storyStrings(old['sourceIds']).toSet());
    await _store.commitStoryWorkspace(
        state: next, history: invalidated.history, memory: invalidated.memory);
    _continuityCache[next.characterId] = next;
    _historyCache[next.characterId] = invalidated.history;
    _memoryCache[next.characterId] = invalidated.memory;
    _notifyStoryChanges();
  }

  Map<String, dynamic> _correctHistoricalSnapshot(Map<String, dynamic> snapshot,
      String oldId, Map<String, dynamic> replacement) {
    final facts = storyMaps(snapshot['facts']);
    if (!facts.any((f) => f['id'] == oldId)) return snapshot;
    return {
      ...snapshot,
      'facts': [
        ...facts.map((f) => f['id'] == oldId ? {...f, 'retired': true} : f),
        replacement
      ],
      'knowledge': storyMaps(snapshot['knowledge'])
          .map((k) =>
              k['factId'] == oldId ? {...k, 'factId': replacement['id']} : k)
          .toList()
    };
  }

  Future<void> dismissFactConflict(String id) async {
    final next = currentContinuity.copy();
    next.data['conflicts'] = next.conflicts
        .map((c) => c['id'] == id ? {...c, 'resolved': true} : c)
        .toList();
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[next.characterId] = next;
    _notifyStoryChanges();
  }

  Future<void> setNpcKnowledge(
      String npcId, String factId, String level) async {
    if (!const ['witnessed', 'told', 'suspected', 'unknown'].contains(level)) {
      return;
    }
    final next = currentContinuity.copy();
    final fact = next.activeFacts.where((f) => f['id'] == factId).firstOrNull;
    if (fact == null) return;
    final knowledge = next.knowledge
      ..removeWhere((k) => k['npcId'] == npcId && k['factId'] == factId);
    knowledge.add({
      'npcId': npcId,
      'factId': factId,
      'factKey': fact['key'],
      'level': level,
      'sequence': next.sequence,
      'sourceIds': fact['sourceIds'],
      'playerConfirmed': true
    });
    next.data['knowledge'] = knowledge;
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[next.characterId] = next;
    await _invalidateStoryReplay(next.characterId);
    _notifyStoryChanges();
  }

  Future<void> _invalidateStoryReplay(String worldId) async {
    final history =
        (await _ensureHistory(worldId)).copyWith(clearPromptCacheEpoch: true);
    await _store.saveDialogueHistory(history);
    _historyCache[worldId] = history;
  }

  Future<void> saveReadingPosition(
      String surface, String messageId, double fraction,
      {bool leaving = false, String? worldId}) async {
    final id = worldId ?? currentContinuity.characterId;
    final current = await _ensureContinuity(id);
    final ids = surface == 'main'
        ? (await _ensureHistory(id)).messages.map((m) => m.id).toList()
        : NpcWorldState.fromJson(
                storyMap(current.npcWorlds[surface.replaceFirst('npc/', '')]))
            .messages
            .map((m) => m.id)
            .toList();
    final index = ids.indexOf(messageId);
    final record = <String, dynamic>{
      'messageId': messageId,
      'fraction': fraction.clamp(0.0, 1.0),
      'index': index,
      if (index > 0) 'previousId': ids[index - 1],
      if (index >= 0 && index + 1 < ids.length) 'nextId': ids[index + 1],
      'updatedAt': DateTime.now().toIso8601String(),
      if (leaving) 'leftAt': DateTime.now().toIso8601String()
    };
    await _store.saveStoryReading(id, surface, record);
    final latest = await _ensureContinuity(id);
    latest.data['reading'] = {...latest.reading, surface: record};
  }

  Future<void> renameStoryChapter(String id, String title) async {
    if (title.trim().isEmpty) return;
    final next = currentContinuity.copy();
    next.data['chapters'] = next.chapters
        .map((c) => c['id'] == id ? {...c, 'title': title.trim()} : c)
        .toList();
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[next.characterId] = next;
    _notifyStoryChanges();
  }

  Future<void> reopenStoryScene() async {
    final next = currentContinuity.copy();
    final scene = next.scene;
    if (scene.isEmpty) return;
    next.data['scene'] = {...scene, 'closed': false};
    next.data['chapters'] =
        next.chapters.where((c) => c['id'] != scene['id']).toList();
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[next.characterId] = next;
    _notifyStoryChanges();
  }

  Future<String?> closeStoryScene() async {
    if (_isSending || _activeNpcReplyingId != null || hasPendingUserMessages) {
      return '请先完成当前回合。';
    }
    if (currentContinuity.scene['closed'] == true) return '这一章已经结束，可以进入下一场。';
    final oldDirectors = currentContinuity.directors;
    await saveDirectorPreferences('turn', {
      '篇幅': '本次收尾约200—400字，优先于默认长篇要求',
      '导演补充': '为当前场景补写自然的收尾，可开放结束；不替玩家作决定，不强行解决冲突，不开启下一场。'
    });
    final queued = await queueUserMessage('【场景收尾】请让这一场自然收束。');
    if (queued != null) {
      final restored = currentContinuity.copy()
        ..data['directors'] = oldDirectors;
      await _store.commitStoryWorkspace(state: restored);
      _continuityCache[restored.characterId] = restored;
      return queued;
    }
    final queuedId = currentHistory.messages.last.id;
    final count = currentContinuity.sequence;
    String? error;
    _closingStoryScene = true;
    try {
      error = await requestAssistantReply();
    } finally {
      _closingStoryScene = false;
    }
    if (error != null || currentContinuity.sequence == count) {
      final restored = currentContinuity.copy()
        ..data['directors'] = oldDirectors;
      final history = await _ensureHistory(restored.characterId);
      final cleaned = history.copyWith(
          messages: history.messages.where((m) => m.id != queuedId).toList(),
          clearPromptCacheEpoch: true);
      await _store.commitStoryWorkspace(state: restored, history: cleaned);
      _continuityCache[restored.characterId] = restored;
      _historyCache[restored.characterId] = cleaned;
      _notifyStoryChanges();
      return error ?? '收尾未完成，当前场景仍开放。';
    }

    return null;
  }

  Future<String?> enterNextStoryScene(
      {String time = '', String location = ''}) async {
    if (_isSending || _activeNpcReplyingId != null || hasPendingUserMessages) {
      return '请先完成当前回合。';
    }
    if (currentContinuity.scene['closed'] != true) return '请先收尾当前场景，或继续在这里演。';
    if (currentCharacter?.mapModeEnabled == true) {
      if (location.trim().isNotEmpty && time.trim().isNotEmpty) {
        return '地图模式每次选择移动或推进时间；先完成其中一项，再进行下一项。';
      }
      if (location.trim().isNotEmpty) return openMapLocation(location.trim());
      if (time.trim().isNotEmpty) return advanceMapTime(time.trim());
      return runMapFreeAction('进入下一场，继续当前位置的剧情，不替玩家作决定。');
    }
    final error = await queueUserMessage(
        '【进入下一场】${time.isEmpty ? '延续当前时间' : time}；${location.isEmpty ? '继续当前位置' : '尝试前往$location'}。遵守世界规则和行动成本，不能绕过障碍或擅自替我完成关键行动。');
    return error ?? await requestAssistantReply();
  }
}
