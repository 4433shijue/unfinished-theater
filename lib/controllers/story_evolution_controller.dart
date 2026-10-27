part of 'app_state_controller.dart';

extension StoryEvolutionController on AppStateController {
  List<NpcProfile> _openingProfiles(String worldId, StoryOpeningDraft draft) {
    final now = DateTime.now();
    final ids = {
      for (final n in draft.npcs) '${n['id']}': '${worldId}_initial_${n['id']}'
    };
    return draft.npcs.map((n) {
      final relations = draft.relationships
          .where((r) => r['from'] == n['id'])
          .map((r) => {
                'targetId': ids[r['to']],
                'label': r['label'],
                'public': r['public'] == true
              })
          .toList();
      final story = NpcStoryState.fromJson({...n, 'relations': relations});
      return NpcProfile(
          id: ids[n['id']]!,
          characterId: worldId,
          name: '${n['name']}',
          createdAt: now,
          updatedAt: now,
          description: story.publicIdentity,
          affinity: (n['affinity'] as num).toInt(),
          impression: story.affinityReason,
          storyState: story,
          sourceType: NpcProfileSource.manual,
          runtimeState: NpcRuntimeState(currentGoal: story.goal),
          relationshipEdges: relations
              .map((r) => RelationshipEdge(
                  targetId: '${r['targetId']}',
                  label: '${r['label']}',
                  score: 0,
                  updatedAt: now))
              .toList());
    }).toList();
  }

  Future<void> _createEvolutionCharacter(CharacterProfile profile) async {
    if (_isSending ||
        _activeNpcReplyingId != null ||
        _storyOperationInProgress) {
      throw StateError('请等待当前回合或人物回复结束，再保存新的文游。');
    }
    final draft = profile.openingDraft;
    final errors =
        draft?.validate(npcCount: profile.advancedSettings.npcCount) ??
            <String>[];
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    final initial =
        draft == null ? <NpcProfile>[] : _openingProfiles(profile.id, draft);
    final shared = {
      for (final n in _npcProfiles.where((n) => n.isBoundTo(profile.id)))
        n.id: n.freshWorld()
    };
    final opening = _resolveOpeningMessage(profile).trim();
    final history = DialogueHistory(characterId: profile.id, messages: [
          if (opening.isNotEmpty)
            ChatMessage(
                id: IdGenerator.message(),
                role: ChatRole.assistant,
                content: opening,
                timestamp: DateTime.now(),
                isSummarized: true)
        ]),
        memory = CharacterMemory.empty(profile.id);
    var state = GameStateSnapshot.empty(profile.id);
    if (draft != null) {
      state = state.copyWith(
          storyInventory: draft.items.map(StoryInventoryItem.fromJson).toList(),
          customVariables: profile.gameplaySystem == null
              ? {}
              : GameplayPatchEngine.initializeValues(
                  profile.gameplaySystem!, {}));
    }
    final continuity = StoryContinuityState(characterId: profile.id, data: {
      'npcWorlds': {
        for (final n in [...shared.values, ...initial])
          n.id: NpcWorldState(profile: n.toJson(), messages: []).toJson()
      },
      'openingBaseline': state.toJson(),
      'npcMigrationVersion': 1
    });
    final characters = [profile, ..._characters],
        npcs = [for (final n in _npcProfiles) shared[n.id] ?? n, ...initial];
    await _store.commitStoryWorkspace(
        state: continuity,
        characters: characters,
        selectedCharacterId: profile.id,
        npcProfiles: npcs,
        history: history,
        memory: memory,
        gameState: state,
        mapState: MapWorldState.empty(profile.id));
    _characters
      ..clear()
      ..addAll(characters);
    _npcProfiles
      ..clear()
      ..addAll(npcs);
    _historyCache[profile.id] = history;
    _memoryCache[profile.id] = memory;
    _gameStateCache[profile.id] = state;
    _mapStateCache[profile.id] = MapWorldState.empty(profile.id);
    _continuityCache[profile.id] = continuity;
    for (final timer in [
      ..._npcExtractionTimers.values,
      ..._npcProactiveTimers.values
    ]) {
      timer.cancel();
    }
    _selectedCharacterId = profile.id;
    _npcMessagesCache.clear();
    _activeTurnDirective = null;
    try {
      await _updateGamification(
          (state) => state
              .incrementStat('totalCharactersCreated')
              .setStatMax('maxActiveCharacters', characters.length),
          notify: false);
    } catch (e) {
      debugPrint('开局已保存，统计更新失败：$e');
    }
    _notifyStoryChanges();
  }

  Future<void> _addOpeningToExisting(
      String worldId, StoryOpeningDraft draft) async {
    final errors = draft.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    final character = _findCharacter(worldId)!;
    final oldProfiles = [..._npcProfiles];
    final oldState = await _ensureGameState(worldId);
    final existing = _npcProfilesForRuntime(worldId);
    final generated = _openingProfiles(worldId, draft);
    final remap = {
      for (final n in generated)
        n.id: existing
                .where((e) => e.id == n.id || e.name == n.name)
                .firstOrNull
                ?.id ??
            n.id
    };
    final additions = generated
        .where((n) =>
            !(draft.data['excluded_npcs'] as List? ?? [])
                .any((id) => n.id == '${worldId}_initial_$id') &&
            !existing.any((e) => e.id == n.id || e.name == n.name))
        .map((n) => n.copyWith(
            storyState: n.storyState.patch({
              'relations': n.storyState.relations
                  .map((r) =>
                      {...r, 'targetId': remap[r['targetId']] ?? r['targetId']})
                  .toList()
            }),
            relationshipEdges: n.relationshipEdges
                .map((e) => RelationshipEdge(
                    targetId: remap[e.targetId] ?? e.targetId,
                    label: e.label,
                    score: e.score,
                    updatedAt: e.updatedAt))
                .toList()))
        .toList();
    final ids = oldState.storyInventory.map((i) => i.id).toSet();
    final system = character.gameplaySystem ??
        (draft.data['includeGameplay'] == false ? null : draft.gameplay);
    final state = oldState.copyWith(
        storyInventory: [
          ...oldState.storyInventory,
          ...draft.items.map(StoryInventoryItem.fromJson).where((i) =>
              !(draft.data['excluded_items'] as List? ?? []).contains(i.id) &&
              !ids.contains(i.id) &&
              !oldState.storyInventory.any((e) => e.name == i.name))
        ],
        customVariables: character.gameplaySystem != null || system == null
            ? oldState.customVariables
            : GameplayPatchEngine.initializeValues(
                system, oldState.customVariables));
    final characters = _characters
        .map((c) => c.id == worldId ? c.copyWith(gameplaySystem: system) : c)
        .toList();
    _npcProfiles.addAll(additions);
    try {
      final continuity = _captureNpcWorld(await _ensureContinuity(worldId));
      await _store.commitStoryWorkspace(
          state: continuity,
          characters: characters,
          npcProfiles: _npcProfiles,
          gameState: state);
      _characters
        ..clear()
        ..addAll(characters);
      _continuityCache[worldId] = continuity;
      _gameStateCache[worldId] = state;
    } catch (_) {
      _npcProfiles
        ..clear()
        ..addAll(oldProfiles);
      rethrow;
    }
  }

  TurnSettlement? get pendingTurnSettlement {
    for (final m in currentHistory.messages.reversed) {
      final s = TurnSettlement.of(m);
      if (s != null && !s.complete) return s;
    }
    return null;
  }

  TurnSettlement? get unreadTurnSettlement {
    for (final m in currentHistory.messages) {
      final s = TurnSettlement.of(m);
      if (s != null && !s.seen) return s;
    }
    return null;
  }

  Future<void> markSettlementSeen(String turnId) async {
    final history = currentHistory;
    final next = history.copyWith(
        messages: history.messages.map((m) {
      final s = TurnSettlement.of(m);
      if (m.id != turnId || s == null) return m;
      return m.copyWith(gameStateSnapshot: {
        ...?m.gameStateSnapshot,
        'turnSettlement': {...s.toJson(), 'seen': true}
      });
    }).toList());
    await _store.saveDialogueHistory(next);
    _historyCache[history.characterId] = next;
    _notifyStoryChanges();
  }

  Future<DialogueHistory> _commitEvolutionTurn(
      {required CharacterProfile character,
      required DialogueHistory history,
      required GameStateSnapshot before,
      required GameStateSnapshot after,
      required String turnId,
      required StoryContinuityState continuity,
      CharacterMemory? memory,
      GameStateSnapshot? timelineFinal,
      MapWorldState? mapState}) async {
    final message = history.messages.firstWhere((m) => m.id == turnId);
    final originalNpcs = [..._npcProfiles];
    final originalMessages =
        Map<String, List<NpcChatMessage>>.from(_npcMessagesCache);
    var committed = false;
    try {
      final checkpointBefore =
          storyMap(storyMap(continuity.checkpoints[turnId])['before']);
      final worlds = storyMap(checkpointBefore['npcWorlds']);
      if (worlds.isNotEmpty) {
        for (var i = 0; i < _npcProfiles.length; i++) {
          final raw = storyMap(worlds[_npcProfiles[i].id]);
          if (raw.isNotEmpty) {
            _npcProfiles[i] =
                NpcWorldState.fromJson(raw).project(_npcProfiles[i]);
          }
        }
      }
      final priorNpcs = _npcProfilesForRuntime(character.id);
      final checked = NpcEvolutionEngine.validate(
          after,
          MessageContentParser.contextTextForModel(message.content),
          priorNpcs,
          continuity);
      await _applyGameStateNpcUpdates(character.id, checked,
          persist: false, updateGamification: false, sourceTurnId: turnId);
      for (final update in checked.npcUpdates) {
        final index = _npcProfiles.indexWhere((n) =>
            n.id == update.npcId ||
            (n.characterId == character.id && n.name == update.name));
        if (index < 0) continue;
        final npc =
            NpcEvolutionEngine.apply(_npcProfiles[index], update, turnId);

        _npcProfiles[index] = npc;
        if (npc.canSendMessages &&
            npc.storyState.appeared &&
            NpcMessageClassifier.isDeliverableChatBubble(
                update.proactiveMessage)) {
          final batchId = 'npc_turn::$turnId::${npc.id}';
          final messages = _npcMessagesCache[npc.id] ??
              NpcWorldState.fromJson(storyMap(continuity.npcWorlds[npc.id]))
                  .messages;
          if (!messages.any((m) => m.batchId == batchId)) {
            _npcMessagesCache[npc.id] = [
              ...messages,
              NpcChatMessage(
                  id: IdGenerator.message(),
                  npcId: npc.id,
                  role: NpcMessageRole.npc,
                  content: update.proactiveMessage,
                  timestamp: message.timestamp,
                  batchId: batchId)
            ];
          }
        }
      }
      final routines = _pendingRoutineActions.remove(character.id) ?? [];
      final scoped = NpcEvolutionEngine.routines(
          _npcProfilesForRuntime(character.id),
          routines,
          before,
          checked,
          turnId,
          narrative: MessageContentParser.contextTextForModel(message.content));
      for (final npc in scoped) {
        final i = _npcProfiles.indexWhere((n) => n.id == npc.id);
        if (i >= 0) _npcProfiles[i] = npc;
      }
      final receipt = TurnSettlement.compare(
          worldId: character.id,
          turnId: turnId,
          before: before,
          after: checked,
          beforeNpcs: priorNpcs,
          afterNpcs: _npcProfilesForRuntime(character.id),
          beforeMap:
              mapState == null ? null : await _ensureMapState(character.id),
          afterMap: mapState,
          revision: (TurnSettlement.of(message)?.revision ?? 0) + 1);
      var next = history.copyWith(
          messages: history.messages
              .map((m) => m.id == turnId
                  ? m.copyWith(gameStateSnapshot: {
                      ...?m.gameStateSnapshot,
                      ...checked.toJson(),
                      'turnSettlement': receipt.toJson(),
                      'turnSettlementHistory': [
                        ...storyMaps(
                            m.gameStateSnapshot?['turnSettlementHistory']),
                        if (TurnSettlement.of(m)?.complete == true)
                          TurnSettlement.of(m)!.toJson()
                      ]
                    })
                  : m)
              .toList());
      var nextContinuity = _captureNpcWorld(continuity);
      nextContinuity.data['checkpoints'] = {
        ...nextContinuity.checkpoints,
        turnId: {
          ...storyMap(nextContinuity.checkpoints[turnId]),
          'npcAfter': nextContinuity.npcWorlds
        }
      };
      if (timelineFinal != null) {
        final sequence =
            storyInt(storyMap(continuity.checkpoints[turnId])['sequence']);
        var priorState = checked;
        for (final event in continuity.events
            .where((e) => storyInt(e['sequence']) > sequence)) {
          final id = '${event['id']}',
              cp = storyMap(continuity.checkpoints[id]);
          final oldBefore = storyMap(storyMap(cp['before'])['npcWorlds']),
              oldAfter = storyMap(cp['npcAfter']);
          if (oldAfter.isEmpty) continue;
          final beforeNpcs = _npcProfilesForRuntime(character.id),
              beforeWorld = nextContinuity.npcWorlds;
          final worlds = storyMap(NpcEvolutionEngine.rebaseRecorded(
              beforeWorld, oldBefore, oldAfter));
          for (var i = 0; i < _npcProfiles.length; i++) {
            final raw = storyMap(worlds[_npcProfiles[i].id]);
            if (raw.isEmpty) continue;
            final world = NpcWorldState.fromJson(raw);
            _npcProfiles[i] = world.project(_npcProfiles[i]);
            _npcMessagesCache[_npcProfiles[i].id] = world.messages;
          }
          nextContinuity = nextContinuity.copy()..data['npcWorlds'] = worlds;
          nextContinuity.data['checkpoints'] = {
            ...nextContinuity.checkpoints,
            id: {
              ...cp,
              'before': {...storyMap(cp['before']), 'npcWorlds': beforeWorld},
              'npcAfter': worlds
            }
          };
          final later = next.messages.where((m) => m.id == id).firstOrNull;
          if (later?.gameStateSnapshot == null) continue;
          final state = GameStateSnapshot.fromJson(later!.gameStateSnapshot!);
          final receipt = TurnSettlement.compare(
              worldId: character.id,
              turnId: id,
              before: priorState,
              after: state,
              beforeNpcs: beforeNpcs,
              afterNpcs: _npcProfilesForRuntime(character.id),
              revision: (TurnSettlement.of(later)?.revision ?? 0) + 1);
          next = next.copyWith(
              messages: next.messages
                  .map((m) => m.id == id
                      ? m.copyWith(gameStateSnapshot: {
                          ...m.gameStateSnapshot!,
                          'turnSettlement': {...receipt.toJson(), 'seen': true}
                        })
                      : m)
                  .toList());
          priorState = state;
        }
      }
      if (mapState == null) {
        await _store.commitTurnState(
            history: next,
            gameState: timelineFinal ?? checked,
            memory: memory,
            npcProfiles: _npcProfiles,
            continuity: nextContinuity);
      } else {
        await _store.commitStoryWorkspace(
            state: nextContinuity,
            history: next,
            gameState: timelineFinal ?? checked,
            mapState: mapState,
            npcProfiles: _npcProfiles);
        _mapStateCache[character.id] = mapState;
      }
      committed = true;
      _historyCache[character.id] = next;
      _gameStateCache[character.id] = timelineFinal ?? checked;
      _continuityCache[character.id] = nextContinuity;
      return next;
    } finally {
      if (!committed) {
        _npcProfiles
          ..clear()
          ..addAll(originalNpcs);
        _npcMessagesCache
          ..clear()
          ..addAll(originalMessages);
      }
    }
  }

  // Replay recorded differences, never current/future NPC knowledge, after deletion.
  StoryContinuityState _restoreEvolutionAfterRemoval(
      StoryContinuityState state, Set<String> ids) {
    final events = state.events;
    final first = events
        .indexWhere((e) => storyStrings(e['sourceIds']).any(ids.contains));
    if (first < 0) return state;
    final checkpoint = storyMap(state.checkpoints[events[first]['id']]);
    final baseline = storyMap(storyMap(checkpoint['before'])['npcWorlds']);
    if (baseline.isEmpty) {
      return state; // Old saves have no reliable history to invent.
    }
    var worlds = baseline;
    final checkpoints = state.checkpoints;
    for (var i = first; i < events.length; i++) {
      final event = events[i], cp = storyMap(checkpoints[event['id']]);
      final oldBefore = storyMap(storyMap(cp['before'])['npcWorlds']);
      final oldAfter = cp['npcAfter'] is Map
          ? storyMap(cp['npcAfter'])
          : i + 1 < events.length
              ? storyMap(storyMap(storyMap(
                  checkpoints[events[i + 1]['id']])['before'])['npcWorlds'])
              : state.npcWorlds;
      if (storyStrings(event['sourceIds']).any(ids.contains)) continue;
      final rebasedBefore = worlds;
      worlds = storyMap(
          NpcEvolutionEngine.rebaseRecorded(worlds, oldBefore, oldAfter));
      checkpoints[event['id']] = {
        ...cp,
        'before': {...storyMap(cp['before']), 'npcWorlds': rebasedBefore},
        'npcAfter': worlds
      };
    }
    final next = state.copy()
      ..data['npcWorlds'] = worlds
      ..data['checkpoints'] = checkpoints;
    for (var i = 0; i < _npcProfiles.length; i++) {
      final raw = storyMap(worlds[_npcProfiles[i].id]);
      if (raw.isEmpty) continue;
      final world = NpcWorldState.fromJson(raw);
      _npcProfiles[i] = world.project(_npcProfiles[i]);
      _npcMessagesCache[_npcProfiles[i].id] = world.messages;
    }
    return next;
  }

  Future<void> _deleteEvolutionMessages(String worldId, Set<String> ids) async {
    await _createSafetySnapshotForCharacter(worldId, reason: '删除回合前自动保护');
    final original = await _ensureHistory(worldId);
    final originalNpcs = [..._npcProfiles],
        originalMessages =
            Map<String, List<NpcChatMessage>>.from(_npcMessagesCache);
    var committed = false;
    try {
      final invalidated = await _invalidateSummariesForMessageIds(
          characterId: worldId,
          history: original.copyWith(
              messages:
                  original.messages.where((m) => !ids.contains(m.id)).toList(),
              clearPromptCacheEpoch: true),
          changedMessageIds: ids);
      final replay = _replayGameStateFromHistory(worldId, invalidated.history);
      var continuity =
          _restoreEvolutionAfterRemoval(await _ensureContinuity(worldId), ids);
      continuity = StoryContinuityEngine.invalidateSources(continuity, ids);
      var previous = GameStateSnapshot.fromJson(
          storyMap(continuity.data['openingBaseline']));
      final messages = <ChatMessage>[];
      for (final m in replay.history.messages) {
        final receipt = TurnSettlement.of(m),
            cp = storyMap(continuity.checkpoints[m.id]);
        if (receipt == null ||
            !receipt.complete ||
            m.gameStateSnapshot == null) {
          messages.add(m);
          continue;
        }
        final after = GameStateSnapshot.fromJson(m.gameStateSnapshot!);
        List<NpcProfile> actors(dynamic raw) => storyMap(raw)
            .values
            .map((v) => NpcProfile.fromJson(storyMap(storyMap(v)['profile'])))
            .toList();
        final beforeWorld = storyMap(storyMap(cp['before'])['npcWorlds']),
            afterWorld = storyMap(cp['npcAfter']);
        if (beforeWorld.isEmpty || afterWorld.isEmpty) {
          messages.add(m);
          previous = after;
          continue;
        }
        final next = TurnSettlement.compare(
            worldId: worldId,
            turnId: m.id,
            before: previous,
            after: after,
            beforeNpcs: actors(beforeWorld),
            afterNpcs: actors(afterWorld),
            revision: receipt.revision + 1);
        messages.add(m.copyWith(gameStateSnapshot: {
          ...m.gameStateSnapshot!,
          'turnSettlement': {...next.toJson(), 'seen': true}
        }));
        previous = after;
      }
      final history = replay.history.copyWith(messages: messages);
      final latestPending = original.messages
          .where((m) =>
              ids.contains(m.id) && TurnSettlement.of(m)?.complete == false)
          .lastOrNull;
      final gameState = latestPending != null &&
              original.messages.last.id == latestPending.id
          ? GameStateSnapshot.fromJson(
              storyMap(latestPending.gameStateSnapshot?['settlementBefore']))
          : replay.gameState;
      MapWorldState? mapState;
      final removedEvents = (await _ensureContinuity(worldId))
          .events
          .where((e) => storyStrings(e['sourceIds']).any(ids.contains))
          .toList();
      if (_findCharacter(worldId)?.mapModeEnabled == true &&
          removedEvents.isNotEmpty) {
        final events = (await _ensureContinuity(worldId)).events;
        final lastRemaining = events
            .where((e) =>
                e['privateNpcId'] == null &&
                !storyStrings(e['sourceIds']).any(ids.contains))
            .lastOrNull;
        final cp = storyMap(continuity
            .checkpoints[lastRemaining?['id'] ?? removedEvents.first['id']]);
        final raw = lastRemaining == null
            ? cp['mapState']
            : (cp['mapAfter'] ?? storyMap(cp['before'])['mapState']);
        if (raw is Map) mapState = MapWorldState.fromJson(storyMap(raw));
      }
      await _store.commitStoryWorkspace(
          state: continuity,
          history: history,
          memory: invalidated.memory,
          gameState: gameState,
          mapState: mapState,
          npcProfiles: _npcProfiles);
      committed = true;
      _historyCache[worldId] = history;
      _memoryCache[worldId] = invalidated.memory;
      _gameStateCache[worldId] = gameState;
      _continuityCache[worldId] = continuity;
      if (mapState != null) _mapStateCache[worldId] = mapState;
      _notifyStoryChanges();
    } finally {
      if (!committed) {
        _npcProfiles
          ..clear()
          ..addAll(originalNpcs);
        _npcMessagesCache
          ..clear()
          ..addAll(originalMessages);
      }
    }
  }

  Future<void> _savePendingSettlement(
      CharacterProfile character,
      DialogueHistory history,
      String turnId,
      String reason,
      GameStateSnapshot before,
      {MapWorldState? mapCandidate,
      GameStateSnapshot? stateCandidate}) async {
    final pending = TurnSettlement(
        worldId: character.id,
        turnId: turnId,
        status: 'pending',
        error: reason);
    final next = history.copyWith(
        messages: history.messages
            .map((m) => m.id == turnId
                ? m.copyWith(gameStateSnapshot: {
                    ..._withoutGameplayTurnReceipts(before)
                        .copyWith(
                            gameplayVariableHistoryVersion:
                                before.gameplayVariableHistoryVersion)
                        .toJson(),
                    'turnSettlement': pending.toJson(),
                    'settlementBefore': before.toJson(),
                    if (mapCandidate != null)
                      'settlementMapCandidate': mapCandidate.toJson(),
                    if (stateCandidate != null)
                      'settlementStateCandidate': stateCandidate.toJson()
                  })
                : m)
            .toList());
    await _store.saveDialogueHistory(next);
    _historyCache[character.id] = next;
    _gameStateCache[character.id] = _withoutGameplayTurnReceipts(before)
        .copyWith(
            gameplayVariableHistoryVersion:
                before.gameplayVariableHistoryVersion);
  }

  Future<String?> retryTurnSettlement(String turnId) async {
    if (_isSending) return '请等待当前操作完成。';
    final character = currentCharacter;
    final history = currentHistory;
    final message = history.messages.where((m) => m.id == turnId).firstOrNull;
    if (character == null ||
        message == null ||
        TurnSettlement.of(message)?.complete != false) {
      return '没有待结算回合。';
    }
    final before = GameStateSnapshot.fromJson(
        storyMap(message.gameStateSnapshot?['settlementBefore']));
    _isSending = true;
    _notifyStoryChanges();
    try {
      final mapCandidate = message.gameStateSnapshot?['settlementMapCandidate']
              is Map
          ? MapWorldState.fromJson(
              storyMap(message.gameStateSnapshot!['settlementMapCandidate']))
          : null;
      final stateCandidate = message
              .gameStateSnapshot?['settlementStateCandidate'] is Map
          ? GameStateSnapshot.fromJson(
              storyMap(message.gameStateSnapshot!['settlementStateCandidate']))
          : null;
      if (mapCandidate != null && stateCandidate != null) {
        final continuity = await _continuityForCompletedTurn(
            character.id, turnId, message.content, before, {});
        await _commitEvolutionTurn(
            character: character,
            history: history,
            before: before,
            after: stateCandidate,
            turnId: turnId,
            continuity: continuity,
            mapState: mapCandidate);
        return null;
      }
      _settlementFailures.remove(character.id);
      final content = await _adjudicateAssistantTurnState(
          character: character,
          content: message.content,
          requestMessages:
              history.messages.takeWhile((m) => m.id != turnId).toList(),
          previousGameState: before,
          npcProfiles: _npcProfilesForRuntime(character.id),
          cancellationToken: LlmCancellationToken());
      if (_settlementFailures.containsKey(character.id)) {
        return _settlementFailures[character.id];
      }
      var after = GameStateParser.parseFromMessage(
          characterId: character.id, content: content, previous: before);
      if (after == null) return '结算结果仍不完整，请稍后重试。';
      if (character.gameplaySystem != null) {
        after = _applyGameplayPatchToState(
            character: character,
            previousState: before,
            state: after,
            turnId: turnId,
            content: content,
            patchExpected: true);
      }
      if (character.gameplaySystem != null &&
          !GameplayPatchParser.parseResult(content).isValid) {
        return '玩法结算仍不完整。';
      }
      if (mapCandidate != null) {
        after = _mergeGameStateWithRulesMap(after, mapCandidate);
      }
      final next = history.copyWith(
          messages: history.messages
              .map((m) => m.id == turnId
                  ? m.copyWith(
                      content: content,
                      promptReplayContent:
                          _apiClient.buildAssistantPromptReplayContent(content),
                      providerReplayExact: false)
                  : m)
              .toList());
      final continuity = await _continuityForCompletedTurn(
          character.id,
          turnId,
          content,
          before,
          _pendingContinuityPatches.remove(character.id) ?? {});
      await _commitEvolutionTurn(
          character: character,
          history: next,
          before: before,
          after: after,
          turnId: turnId,
          continuity: continuity,
          mapState: mapCandidate);
      return null;
    } catch (e) {
      return '结算未完成：$e';
    } finally {
      _isSending = false;
      _notifyStoryChanges();
    }
  }
}
