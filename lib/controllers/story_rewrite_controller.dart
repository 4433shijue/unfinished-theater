part of 'app_state_controller.dart';

extension StoryRewriteController on AppStateController {
  GameStateSnapshot _gameStateBeforeMessageIndex(
          String worldId, List<ChatMessage> messages, int index) =>
      _replayGameStateFromHistory(
              worldId,
              DialogueHistory(
                  characterId: worldId,
                  messages:
                      messages.take(index.clamp(0, messages.length)).toList()),
              baselineOverride: _gameplayReplayBaseline(messages, worldId))
          .gameState;

  String _rewriteContent(String worldId, String messageId, String? npcId) {
    if (npcId != null) {
      return npcMessagesFor(npcId)
              .where((m) => m.id == messageId)
              .firstOrNull
              ?.content ??
          '';
    }
    return _historyFor(worldId)
            .messages
            .where((m) => m.id == messageId)
            .firstOrNull
            ?.content ??
        '';
  }

  List<StoryRewriteTarget> storyRewriteTargets(String messageId,
          {String? npcId}) =>
      StoryRewriteService.targets(messageId,
          _rewriteContent(currentContinuity.characterId, messageId, npcId),
          npcId: npcId);

  Map<String, dynamic> rewriteCheckpoint(String messageId, {String? npcId}) {
    final state = currentContinuity;
    final event = state.events
        .where((e) => storyStrings(e['sourceIds']).contains(messageId))
        .firstOrNull;
    return event == null ? {} : storyMap(state.checkpoints[event['id']]);
  }

  Future<StoryRewritePreview> previewStoryRewrite(StoryRewriteTarget target,
      StoryRewriteMode mode, String direction) async {
    if (_isSending ||
        _activeNpcReplyingId != null ||
        _storyOperationInProgress) {
      throw StateError('请先完成当前生成。');
    }
    if (!_settings.canChat) throw StateError('请先配置 AI 服务。');
    final character = currentCharacter!;
    final worldId = character.id;
    final raw = _rewriteContent(worldId, target.messageId, target.npcId);
    // Validate the selected source range before contacting the provider.
    StoryRewriteService.replace(raw, target, target.selectedText);
    _storyOperationInProgress = true;
    _notifyStoryChanges();
    try {
      final checkpoint =
          rewriteCheckpoint(target.messageId, npcId: target.npcId);
      final historical = StoryContinuityState(
          characterId: worldId, data: storyMap(checkpoint['before']));
      final historicalNpcs = _npcProfiles
          .where((n) => historical.npcWorlds.containsKey(n.id))
          .map((n) =>
              NpcWorldState.fromJson(storyMap(historical.npcWorlds[n.id]))
                  .project(n))
          .toList();
      final turnCharacter = checkpoint['gameplaySystem'] is Map
          ? character.copyWith(
              gameplaySystem: GameplaySystem.fromJson(
                  storyMap(checkpoint['gameplaySystem'])))
          : character;
      final facts =
          StoryContinuityEngine.factsPrompt(historical, npcId: target.npcId);
      final result = _decodeStoryObject(await _apiClient.runUtilityTask(
          settings: _settings,
          systemPrompt:
              '改写用户选中的一段正文。只返回 JSON：{"replacement":"替换文字","preservesFacts":true,"reason":"判断依据"}。'
              '不输出 HTML 或状态协议。润色时不能改变行动、关系、信息归属或已发生事件；无法确定保持事实时 preservesFacts 必须为 false。'
              '不替玩家决定行动、台词或情感。只输出选中部分，不复制上下文。',
          userPrompt:
              '模式：${mode == StoryRewriteMode.polish ? '仅润色' : '改写剧情'}\n要求：$direction\n'
              '人物设定：${target.npcId == null ? character.prompt : npcProfileById(target.npcId!)?.roleCard ?? ''}\n'
              '已知事实：$facts\n正文：${MessageContentParser.contextTextForModel(raw)}\n选中文字：${target.selectedText}',
          temperature: character.modelParams.temperature,
          topP: character.modelParams.topP));
      final replacement = result['replacement']?.toString().trim() ?? '';
      if (replacement.isEmpty) throw StateError('没有生成可用的替换文字。');
      var nextContent = StoryRewriteService.replace(raw, target, replacement);
      var requiresBranch =
          mode == StoryRewriteMode.plot || result['preservesFacts'] != true;
      Map<String, dynamic> settlement = {};
      Map<String, dynamic> patch = {};
      if (target.npcId == null) {
        final history = await _ensureHistory(worldId);
        final index =
            history.messages.indexWhere((m) => m.id == target.messageId);
        final previous = checkpoint['gameState'] is Map
            ? GameStateSnapshot.fromJson(storyMap(checkpoint['gameState']))
            : _gameStateBeforeMessageIndex(worldId, history.messages, index);
        final judged = _decodeStoryObject(await _apiClient.runUtilityTask(
            settings: _settings,
            systemPrompt: TurnStateAdjudicator.buildSystemPrompt(
                gameplayPatchRequired: turnCharacter.gameplaySystem != null),
            userPrompt: TurnStateAdjudicator.buildUserPrompt(
                character: turnCharacter,
                previousState: previous,
                npcProfiles: historicalNpcs,
                latestUserMessage:
                    index > 0 ? history.messages[index - 1].content : '',
                narrativeReply:
                    MessageContentParser.contextTextForModel(nextContent)),
            temperature: 0.12,
            topP: 0.8));
        final adjudication = TurnStateAdjudicator.parse(jsonEncode(judged),
            gameplayPatchRequired: turnCharacter.gameplaySystem != null);
        if (adjudication == null) throw StateError('无法核对改写后的剧情状态，原文未改动。');
        settlement = judged;
        patch = storyMap(judged['continuityPatch']);
        final before = GameStateParser.parseFromMessage(
            characterId: worldId, content: raw, previous: previous);
        final after = GameStateParser.parseFromMessage(
            characterId: worldId,
            content: adjudication.protocolContent,
            previous: previous);
        if (character.mapModeEnabled &&
            before != null &&
            after != null &&
            (before.location != after.location ||
                before.timeLabel != after.timeLabel)) {
          throw StateError('地图时间与地点需要通过场景切换按规则行动。请保留本回合的时间地点，再改写人物回应。');
        }
        if (before == null ||
            after == null ||
            !_rewriteStatesMatch(before, after) ||
            !_rewritePatchesMatch(raw, adjudication.protocolContent)) {
          requiresBranch = true;
        }
        if (requiresBranch) {
          nextContent = ReplyProtocolReconciler.mergeStateBlocks(
              primary: nextContent,
              fallback: adjudication.protocolContent,
              gameplayPatchRequired: turnCharacter.gameplaySystem != null,
              preferFallback: true);
        }
      } else if (requiresBranch) {
        final npc = npcProfileById(target.npcId!)!;
        final judged = _decodeStoryObject(await _apiClient.runUtilityTask(
            settings: _settings,
            systemPrompt:
                '根据私聊正文整理已发生的关系变化，只输出 JSON：{"affinityDelta":0,"impression":"有依据的印象","bondStage":"","bondRoute":""}。'
                '${StoryContinuityEngine.patchContract}\n不将猜测写成事实，不擅自确认恋爱；好感变化范围 -12..12。',
            userPrompt:
                'NPC：${npc.name}，ID：${npc.id}\n已知：$facts\n修改后的整批回复：${_rewriteNpcBatchText(target, nextContent)}',
            temperature: 0.12,
            topP: 0.8));
        if (judged.isEmpty) throw StateError('无法核对私聊变化，原文未改动。');
        settlement = judged;
        patch = storyMap(judged['continuityPatch']);
      }
      return StoryRewritePreview(
          worldId: worldId,
          target: target,
          replacement: replacement,
          mode: mode,
          originalContent: raw,
          nextContent: nextContent,
          requiresBranch: requiresBranch,
          reason: requiresBranch
              ? '这次修改涉及剧情事实或无法确认完全保留事实，将另开 IF 分支。'
              : '仅替换选中文字，保留状态与其余内容。',
          settlement: settlement,
          continuityPatch: patch);
    } finally {
      _storyOperationInProgress = false;
      _notifyStoryChanges();
    }
  }

  String _rewriteNpcBatchText(StoryRewriteTarget target, String replacement) {
    final event = currentContinuity.events
        .where((e) => storyStrings(e['sourceIds']).contains(target.messageId))
        .firstOrNull;
    if (event == null) return replacement;
    return npcMessagesFor(target.npcId!)
        .where((m) => storyStrings(event['sourceIds']).contains(m.id))
        .map((m) => m.id == target.messageId ? replacement : m.content)
        .join('\n');
  }

  bool _rewriteStatesMatch(GameStateSnapshot a, GameStateSnapshot b) =>
      a.timeLabel == b.timeLabel &&
      a.location == b.location &&
      a.status == b.status &&
      a.mainTask == b.mainTask &&
      mapEquals(a.metrics, b.metrics) &&
      jsonEncode(a.storyInventory.map((i) => i.toJson()).toList()) ==
          jsonEncode(b.storyInventory.map((i) => i.toJson()).toList()) &&
      listEquals(a.relationshipNotes, b.relationshipNotes) &&
      listEquals(a.plotFlags, b.plotFlags) &&
      listEquals(a.profileDetails, b.profileDetails) &&
      jsonEncode(a.npcUpdates.map((n) => n.toJson()).toList()) ==
          jsonEncode(b.npcUpdates.map((n) => n.toJson()).toList());

  bool _rewritePatchesMatch(String a, String b) {
    final first = GameplayPatchParser.parseResult(a);
    final second = GameplayPatchParser.parseResult(b);
    List<dynamic> values(GameplayPatchParseResult p) => [
          for (final op in p.operations) [op.type.name, op.path, op.value],
          for (final t in p.threads) t.toJson()
        ];
    return first.error == null &&
        second.error == null &&
        jsonEncode(values(first)) == jsonEncode(values(second));
  }

  Future<void> applyStoryRewrite(StoryRewritePreview preview,
      {String branchName = '',
      int? legacyAffinity,
      Map<String, int> legacyAffinities = const {}}) async {
    if (_isSending ||
        _activeNpcReplyingId != null ||
        _storyOperationInProgress) {
      throw StateError('请先完成当前生成。');
    }
    if (_selectedCharacterId != preview.worldId ||
        _rewriteContent(preview.worldId, preview.target.messageId,
                preview.target.npcId) !=
            preview.originalContent) {
      throw StateError('原文或剧本已变化，请重新选择并生成。');
    }
    _storyOperationInProgress = true;
    _notifyStoryChanges();
    try {
      if (preview.requiresBranch) {
        await _applyRewriteBranch(preview,
            branchName: branchName,
            legacyAffinity: legacyAffinity,
            legacyAffinities: legacyAffinities);
      } else {
        await _applyPolish(preview.target.messageId, preview.nextContent,
            npcId: preview.target.npcId);
      }
    } finally {
      _storyOperationInProgress = false;
      _notifyStoryChanges();
    }
  }

  Future<void> _applyPolish(String messageId, String text,
      {String? npcId, bool recordVersion = true}) async {
    final next = currentContinuity.copy();
    final old = _rewriteContent(next.characterId, messageId, npcId);
    final key = '${npcId ?? 'main'}/$messageId';
    final versions = next.revisions;
    final list = storyMaps(versions[key]);
    if (recordVersion) {
      if (list.isEmpty) {
        list.add({
          'id': IdGenerator.generic('revision'),
          'content': old,
          'createdAt': DateTime.now().toIso8601String()
        });
      }
      list.add({
        'id': IdGenerator.generic('revision'),
        'content': text,
        'createdAt': DateTime.now().toIso8601String()
      });
    }
    versions[key] = list;
    next.data['revisions'] = versions;
    if (npcId != null) {
      final world = NpcWorldState.fromJson(storyMap(next.npcWorlds[npcId]));
      final messages = npcMessagesFor(npcId)
          .map((m) =>
              m.id == messageId ? m.copyWith(content: text, innerVoice: '') : m)
          .toList();
      next.data['npcWorlds'] = {
        ...next.npcWorlds,
        npcId:
            NpcWorldState(profile: world.profile, messages: messages).toJson()
      };
      await _store.commitStoryWorkspace(state: next);
      _npcMessagesCache[npcId] = messages;
    } else {
      final history = await _ensureHistory(next.characterId);
      final updated = history.copyWith(
          clearPromptCacheEpoch: true,
          messages: history.messages
              .map((m) => m.id == messageId
                  ? m.copyWith(
                      content: text,
                      isSummarized: false,
                      clearPromptReplayContent: true,
                      clearProviderReplayContent: true,
                      providerReplayExact: false,
                      clearTokenEstimate: true)
                  : m)
              .toList());
      final invalidated = await _invalidateSummariesForMessageIds(
          characterId: next.characterId,
          history: updated,
          changedMessageIds: {messageId});
      await _store.commitStoryWorkspace(
          state: next,
          history: invalidated.history,
          memory: invalidated.memory);
      _historyCache[next.characterId] = invalidated.history;
      _memoryCache[next.characterId] = invalidated.memory;
    }
    _continuityCache[next.characterId] = next;
  }

  Future<void> switchStoryRevision(String messageId, String revisionId,
      {String? npcId}) async {
    if (_isSending ||
        _activeNpcReplyingId != null ||
        _storyOperationInProgress) {
      throw StateError('请先完成当前生成。');
    }
    final revision =
        storyMaps(currentContinuity.revisions['${npcId ?? 'main'}/$messageId'])
            .where((r) => r['id'] == revisionId)
            .firstOrNull;
    if (revision == null) throw StateError('这个版本已经不存在。');
    await _applyPolish(messageId, revision['content'] as String,
        npcId: npcId, recordVersion: false);
    _notifyStoryChanges();
  }

  Future<void> _applyRewriteBranch(StoryRewritePreview preview,
      {required String branchName,
      int? legacyAffinity,
      Map<String, int> legacyAffinities = const {}}) async {
    final source = currentCharacter!;
    final history = await _ensureHistory(source.id);
    final state = currentContinuity;
    final event = state.events
        .where((e) =>
            storyStrings(e['sourceIds']).contains(preview.target.messageId))
        .firstOrNull;
    final checkpoint = event == null
        ? <String, dynamic>{}
        : storyMap(state.checkpoints[event['id']]);
    final missingNpcs = preview.target.npcId == null
        ? _npcProfilesForRuntime(source.id)
        : [npcProfileById(preview.target.npcId!)!];
    if (checkpoint.isEmpty &&
        missingNpcs.any((n) => !(legacyAffinities.containsKey(n.id) ||
            (n.id == preview.target.npcId && legacyAffinity != null)))) {
      throw StateError('旧记录缺少快照，请填写各人物在分支起点的好感。未知经历、印象和羁绊将留空。');
    }
    final branchId = IdGenerator.character();
    var next = event == null
        ? StoryContinuityState(characterId: branchId)
        : state.atCheckpoint(event['id'].toString(), branchId);
    if (checkpoint.isEmpty) {
      next.data['npcWorlds'] = {
        for (final n in missingNpcs)
          n.id: NpcWorldState(
              profile: n
                  .copyWith(
                      affinity: (legacyAffinities[n.id] ?? legacyAffinity ?? 0)
                          .clamp(-100, 100),
                      impression: '',
                      impressionHistory: [],
                      lifecycle: NpcLifecycle.active,
                      bondRoute: const NpcBondRoute(),
                      giftHistory: [],
                      npcMemory: [],
                      worldEvents: [],
                      relationshipEdges: [],
                      runtimeState: const NpcRuntimeState())
                  .toJson(),
              messages: []).toJson()
      };
    }
    final targetIndex =
        history.messages.indexWhere((m) => m.id == preview.target.messageId);
    final allowed = storyStrings(checkpoint['mainMessageIds']).toSet();
    var messages = checkpoint.isNotEmpty
        ? history.messages.where((m) => allowed.contains(m.id)).toList()
        : targetIndex >= 0
            ? history.messages.take(targetIndex).toList()
            : <ChatMessage>[];
    var before = checkpoint['gameState'] is Map
        ? GameStateSnapshot.fromJson(storyMap(checkpoint['gameState']))
            .copyWith(characterId: branchId)
        : _gameStateBeforeMessageIndex(
                source.id, history.messages, targetIndex < 0 ? 0 : targetIndex)
            .copyWith(characterId: branchId);
    final branch = source.copyWith(
        id: branchId,
        gameplaySystem: checkpoint['gameplaySystem'] is Map
            ? GameplaySystem.fromJson(storyMap(checkpoint['gameplaySystem']))
            : source.gameplaySystem,
        name: source.name,
        openingMessage: '',
        branchSourceCharacterId: source.rootCharacterId,
        branchOriginMessageId: preview.target.messageId,
        branchName: branchName.trim().isEmpty
            ? '精修 IF ${DateTime.now().millisecondsSinceEpoch}'
            : branchName.trim());
    final finalId = IdGenerator.message();
    if (preview.target.npcId == null) {
      var settled = GameStateParser.parseFromMessage(
              characterId: branchId,
              content: preview.nextContent,
              previous: before) ??
          before;
      if (branch.gameplaySystem != null) {
        settled = _applyGameplayPatchToState(
            character: branch,
            previousState: before,
            state: settled,
            turnId: finalId,
            content: preview.nextContent,
            patchExpected: true);
      }
      if (branch.mapModeEnabled && checkpoint['mapAfter'] is Map) {
        settled = _mergeGameStateWithRulesMap(
            settled,
            MapWorldState.fromJson(storyMap(checkpoint['mapAfter']))
                .copyWith(characterId: branchId));
      }
      messages.add(ChatMessage(
          id: finalId,
          role: ChatRole.assistant,
          content: preview.nextContent,
          timestamp: DateTime.now(),
          isSummarized: false,
          gameStateSnapshot: _gameplaySnapshot(settled, branch.gameplaySystem,
              previousState: before)));
      next = StoryContinuityEngine.apply(
          state: next,
          eventId: finalId,
          sourceIds: [finalId],
          narrative: preview.nextContent,
          patch: preview.continuityPatch,
          npcIds: next.npcWorlds.keys.toSet(),
          checkpoint: {
            'gameState': before.toJson(),
            'mainMessageIds':
                messages.take(messages.length - 1).map((m) => m.id).toList(),
            'gameplaySystem': branch.gameplaySystem?.toJson(),
            'mapState': checkpoint['mapState']
          });
      before = settled;
    } else {
      final npcId = preview.target.npcId!;
      final npc = npcProfileById(npcId)!;
      var world = NpcWorldState.fromJson(storyMap(next.npcWorlds[npcId]));
      if (checkpoint.isEmpty) {
        final priorMessages = npcMessagesFor(npcId)
            .takeWhile((m) => m.id != preview.target.messageId)
            .toList();
        world = NpcWorldState(
            profile: npc
                .copyWith(
                    affinity: (legacyAffinities[npcId] ?? legacyAffinity ?? 0)
                        .clamp(-100, 100),
                    impression: '',
                    impressionHistory: [],
                    giftHistory: [],
                    runtimeState: const NpcRuntimeState(),
                    lifecycle: NpcLifecycle.active,
                    npcMemory: [],
                    worldEvents: [],
                    relationshipEdges: [],
                    bondRoute: const NpcBondRoute())
                .toJson(),
            messages: priorMessages);
      }
      final originalBatch = event == null
          ? <NpcChatMessage>[]
          : npcMessagesFor(npcId)
              .where((m) => storyStrings(event['sourceIds']).contains(m.id))
              .toList();
      final batch = originalBatch.isEmpty
          ? [
              NpcChatMessage(
                  id: finalId,
                  npcId: npcId,
                  role: NpcMessageRole.npc,
                  content: preview.nextContent,
                  timestamp: DateTime.now(),
                  batchId: finalId)
            ]
          : originalBatch
              .map((m) => m.copyWith(
                  id: m.id == preview.target.messageId
                      ? finalId
                      : IdGenerator.message(),
                  content: m.id == preview.target.messageId
                      ? preview.nextContent
                      : m.content,
                  innerVoice: '',
                  batchId: finalId))
              .toList();
      final originalProfiles = List<NpcProfile>.from(_npcProfiles);
      late Map<String, dynamic> updatedProfile;
      try {
        final index = _npcProfiles.indexWhere((n) => n.id == npcId);
        _npcProfiles[index] = world.project(npc);
        _applyNpcImpressionPatch(
            npcId,
            NpcImpressionEntry(
                id: IdGenerator.generic('npc_imp'),
                summary: preview.settlement['impression']?.toString() ?? '',
                createdAt: DateTime.now()),
            affinityDelta:
                storyInt(preview.settlement['affinityDelta']).clamp(-12, 12),
            bondStage: preview.settlement['bondStage']?.toString(),
            bondRoute: preview.settlement['bondRoute']?.toString());
        updatedProfile = _npcProfiles[index].toJson();
      } finally {
        _npcProfiles
          ..clear()
          ..addAll(originalProfiles);
      }
      next = StoryContinuityEngine.apply(
          state: next,
          eventId: finalId,
          sourceIds: batch.map((m) => m.id).toList(),
          narrative: batch.map((m) => m.content).join('\n'),
          patch: preview.continuityPatch,
          npcIds: {npcId},
          privateNpcId: npcId,
          checkpoint: {
            'gameState': before.toJson(),
            'mainMessageIds': messages.map((m) => m.id).toList(),
            'gameplaySystem': branch.gameplaySystem?.toJson(),
            'mapState': checkpoint['mapState']
          });
      next.data['npcWorlds'] = {
        ...next.npcWorlds,
        npcId: NpcWorldState(
            profile: updatedProfile,
            messages: [...world.messages, ...batch]).toJson()
      };
    }
    next.data['npcMigrationVersion'] = 1;
    next.data['npcScopeLocked'] = true;
    final branchHistory = DialogueHistory(
        characterId: branchId,
        messages: messages
            .map((m) => m.copyWith(
                isSummarized: false,
                clearPromptReplayContent: true,
                clearProviderReplayContent: true,
                providerReplayExact: false))
            .toList());
    final branchMemory = CharacterMemory.empty(branchId);
    var profiles = _npcProfiles
        .map((n) => next.npcWorlds.containsKey(n.id)
            ? n.copyWith(
                boundCharacterIds:
                    {...n.boundCharacterIds, n.characterId, branchId}.toList())
            : n)
        .toList();
    if (preview.target.npcId == null) {
      final originalProfiles = List<NpcProfile>.from(_npcProfiles);
      final originalMessages =
          Map<String, List<NpcChatMessage>>.from(_npcMessagesCache);
      final originalSelected = _selectedCharacterId;
      try {
        _characters.insert(0, branch);
        _selectedCharacterId = branchId;
        _npcProfiles
          ..clear()
          ..addAll(profiles.map((n) {
            final raw = storyMap(next.npcWorlds[n.id]);
            return raw.isEmpty ? n : NpcWorldState.fromJson(raw).project(n);
          }));
        _npcMessagesCache
          ..clear()
          ..addAll({
            for (final e in next.npcWorlds.entries)
              e.key: NpcWorldState.fromJson(storyMap(e.value)).messages
          });
        await _applyGameStateNpcUpdates(branchId, before,
            persist: false,
            updateGamification: false,
            emitProactiveMessages: false);
        next = _captureNpcWorld(next);
        profiles = List<NpcProfile>.from(_npcProfiles);
      } finally {
        _characters.removeWhere((c) => c.id == branchId);
        _selectedCharacterId = originalSelected;
        _npcProfiles
          ..clear()
          ..addAll(originalProfiles);
        _npcMessagesCache
          ..clear()
          ..addAll(originalMessages);
      }
    }
    final branchMap = _mapStateForBranch(
        (checkpoint['mapAfter'] ?? checkpoint['mapState']) is Map
            ? MapWorldState.fromJson(
                storyMap(checkpoint['mapAfter'] ?? checkpoint['mapState']))
            : MapWorldState.empty(source.id),
        before,
        branchId: branchId);
    await _store.commitStoryWorkspace(
        state: next,
        history: branchHistory,
        memory: branchMemory,
        gameState: before,
        mapState: branchMap,
        npcProfiles: profiles,
        characters: [branch, ..._characters],
        selectedCharacterId: branchId);
    _characters.insert(0, branch);
    _npcProfiles
      ..clear()
      ..addAll(profiles);
    _continuityCache[branchId] = next;
    _historyCache[branchId] = branchHistory;
    _memoryCache[branchId] = branchMemory;
    _gameStateCache[branchId] = before;
    _mapStateCache[branchId] = branchMap;
    _selectedCharacterId = branchId;
    await _activateStoryWorld(branchId);
  }
}
