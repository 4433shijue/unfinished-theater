part of 'app_state_controller.dart';

extension StoryComposerController on AppStateController {
  String _composerSurface(String? npcId) => 'composer/${npcId ?? 'main'}';

  void rememberComposerDraft(String worldId, ComposerDraft draft,
      {String? npcId}) {
    _unsavedComposerDrafts['$worldId/${npcId ?? 'main'}'] = draft;
  }

  void rememberPrivateNote(String worldId, String text) {
    _unsavedPrivateNotes[worldId] = text;
  }

  Future<ComposerDraft> loadComposerDraft(String worldId,
          {String? npcId}) async =>
      _unsavedComposerDrafts['$worldId/${npcId ?? 'main'}'] ??
      ComposerDraft.fromJson(storyMap(
          (await _store.loadStoryReading(worldId))[_composerSurface(npcId)]));

  Future<void> saveComposerDraft(String worldId, ComposerDraft draft,
      {String? npcId}) async {
    if (_findCharacter(worldId) == null) return;
    final key = '$worldId/${npcId ?? 'main'}';
    rememberComposerDraft(worldId, draft, npcId: npcId);
    await _store.saveStoryReading(
        worldId, _composerSurface(npcId), draft.toJson());
    if (identical(_unsavedComposerDrafts[key], draft)) {
      _unsavedComposerDrafts.remove(key);
    }
    final state = _continuityCache[worldId];
    if (state != null) {
      state.data['reading'] = {
        ...state.reading,
        _composerSurface(npcId): draft.toJson()
      };
    }
  }

  Future<String> loadPrivateNote(String worldId) async =>
      _unsavedPrivateNotes[worldId] ??
      '${storyMap((await _store.loadStoryReading(worldId))['privateNote'])['text'] ?? ''}';

  Future<void> savePrivateNote(String worldId, String text) async {
    if (_findCharacter(worldId) == null) return;
    rememberPrivateNote(worldId, text);
    await _store.saveStoryReading(worldId, 'privateNote', {'text': text});
    if (_unsavedPrivateNotes[worldId] == text) {
      _unsavedPrivateNotes.remove(worldId);
    }
    final state = _continuityCache[worldId];
    if (state != null) {
      state.data['reading'] = {
        ...state.reading,
        'privateNote': {'text': text}
      };
    }
  }

  Future<void> flushComposerWorkspace(String worldId) async {
    for (final entry in _unsavedComposerDrafts.entries.toList()) {
      if (!entry.key.startsWith('$worldId/')) continue;
      final surface = entry.key.substring(worldId.length + 1);
      await saveComposerDraft(worldId, entry.value,
          npcId: surface == 'main' ? null : surface);
    }
    if (_unsavedPrivateNotes.containsKey(worldId)) {
      await savePrivateNote(worldId, _unsavedPrivateNotes[worldId]!);
    }
  }

  String? quoteSource(StoryQuote quote) {
    if (quote.npcId == null) {
      return _historyCache[quote.worldId]
          ?.messages
          .where((m) => m.id == quote.messageId)
          .firstOrNull
          ?.content;
    }
    final state = _continuityCache[quote.worldId];
    final messages = quote.worldId == _selectedCharacterId
        ? _npcMessagesCache[quote.npcId] ?? const <NpcChatMessage>[]
        : NpcWorldState.fromJson(storyMap(state?.npcWorlds[quote.npcId]))
            .messages;
    return messages.where((m) => m.id == quote.messageId).firstOrNull?.content;
  }

  bool quoteIsCurrent(StoryQuote quote) {
    final source = quoteSource(quote);
    return source != null && StoryQuote.digest(source) == quote.sourceDigest;
  }

  StoryQuote makeStoryQuote(String messageId, String raw, String text,
      {String? npcId}) {
    final worldId = currentCharacter?.id;
    if (worldId == null || text.trim().isEmpty) throw StateError('请先选择一段正文。');
    if (text.length > 2000) throw StateError('引用请控制在 2000 字以内。');
    return StoryQuote(
        worldId: worldId,
        messageId: messageId,
        text: text.trim(),
        sourceDigest: StoryQuote.digest(raw),
        npcId: npcId);
  }

  Map<String, String> npcAddressing(String npcId) =>
      storyMap(storyMap(currentContinuity.data['addressing'])[npcId])
          .map((k, v) => MapEntry(k, '$v'));

  Future<void> saveNpcAddressing(
      String npcId, Map<String, String> values) async {
    if (_isSending ||
        _activeNpcReplyingId != null ||
        _storyOperationInProgress) {
      throw StateError('请等当前回合完成后再修改称呼。');
    }
    final next = currentContinuity.copy();
    next.data['addressing'] = {
      ...storyMap(next.data['addressing']),
      npcId: values
    };
    await _store.commitStoryWorkspace(state: next);
    _continuityCache[next.characterId] = next;
    await _invalidateStoryReplay(next.characterId);
    _notifyStoryChanges();
  }

  String _addressingPrompt(String worldId, {String? npcId}) {
    final all = storyMap(_continuityCache[worldId]?.data['addressing']);
    final lines = <String>[];
    for (final entry in all.entries) {
      if (npcId != null && entry.key != npcId) continue;
      final npc = npcProfileById(entry.key);
      if (npc == null || !npc.isBoundTo(worldId)) continue;
      final v = storyMap(entry.value);
      if ('${v['toNpc'] ?? ''}${v['toPlayer'] ?? ''}'.trim().isEmpty) continue;
      lines.add(
          '${npc.name}（${npc.id}）：玩家称呼TA=${v['toNpc'] ?? ''}；TA称呼玩家=${v['toPlayer'] ?? ''}；使用条件=${v['condition'] ?? ''}');
    }
    return lines.isEmpty
        ? ''
        : '【本世界专属称呼】遵守条件，自然使用，不能据此自动升级关系或让旁人知道私下称呼。\n${lines.join('\n')}';
  }

  Future<void> saveDirectorPhrase(String name, String text,
      {String? previousName}) async {
    final phrases = {..._settings.directorPhrases};
    if (previousName != null) phrases.remove(previousName);
    if (name.trim().isNotEmpty && text.trim().isNotEmpty) {
      phrases[name.trim()] = text.trim();
    }
    await saveSettings(_settings.copyWith(directorPhrases: phrases));
  }

  Future<List<String>> helpExpress(String worldId, ComposerDraft draft,
      {String? npcId}) async {
    if (draft.text.trim().isEmpty) throw StateError('先写下你想表达的意思。');
    if (!_settings.canChat) throw StateError('请先配置 AI 接口。');
    if (worldId != currentCharacter?.id) throw StateError('当前剧本已切换。');
    final character = _findCharacter(worldId)!;
    final user = _findBoundUserProfile(worldId);
    final context = npcId == null
        ? (await _ensureHistory(worldId))
            .messages
            .reversed
            .take(8)
            .toList()
            .reversed
            .map((m) =>
                '${m.role.name}：${MessageContentParser.contextTextForModel(m.content)}')
            .join('\n')
        : (await _ensureNpcMessages(npcId))
            .reversed
            .take(16)
            .toList()
            .reversed
            .map((m) => '${m.role.name}：${m.content}')
            .join('\n');
    final raw = await _apiClient.runUtilityTask(
        settings: _settings,
        systemPrompt:
            '把玩家已经写出的意图表达成两种不同、简短、可编辑的台词或动作。保持原意和人设，不替玩家增加决定、承诺、隐秘知识或亲密行为，不写NPC反应或行动结果。只输出JSON：{"suggestions":["表达一","表达二"]}，每条1-3句。',
        userPrompt:
            '剧本：${character.name}\n玩家：${user?.name ?? ''}\n${user?.persona ?? ''}\n近期已发生对话：\n${_clipPromptText(context, 6000)}\n${draft.quote?.promptContext ?? ''}\n玩家要表达：${draft.text}',
        temperature: 0.85,
        topP: 0.95);
    final suggestions = storyStrings(_decodeStoryObject(raw)['suggestions']);
    if (suggestions.length != 2 ||
        suggestions.any((s) => s.length > 800) ||
        suggestions.toSet().length != 2) {
      throw const FormatException('未得到两种有效表达，原稿已保留。');
    }
    return suggestions;
  }

  bool get choicesRefreshing => _choicesRefreshing;
  bool canRefreshChoices(ChatMessage message) {
    final c = currentCharacter;
    return c != null &&
        !c.mapModeEnabled &&
        !c.largeGroupChatModeEnabled &&
        !c.isTutorialDemo &&
        c.nextStepOptionsEnabled &&
        !_isSending &&
        !_choicesRefreshing &&
        !_storyOperationInProgress &&
        pendingTurnSettlement == null &&
        currentHistory.messages.lastOrNull?.id == message.id &&
        message.role == ChatRole.assistant;
  }

  Future<void> refreshChoices(String messageId) async {
    final character = currentCharacter;
    final message =
        currentHistory.messages.where((m) => m.id == messageId).firstOrNull;
    if (character == null || message == null || !canRefreshChoices(message)) {
      throw StateError('只能为当前最新且已完成的普通剧情换选项。');
    }
    if (!_settings.canChat) throw StateError('请先配置 AI 接口。');
    final worldId = character.id;
    final digest = StoryQuote.digest(message.content);
    _choicesRefreshing = true;
    _notifyStoryChanges();
    try {
      final publicState =
          GameStateSnapshot.fromJson(message.gameStateSnapshot ?? {});
      final raw = await _apiClient.runUtilityTask(
          settings: _settings,
          systemPrompt:
              '${ChoiceStrategy.instruction}\n只生成下一步选项，不续写或重新结算剧情。遵守剧本设定，但设定中的未公开秘密不能成为玩家行动的依据，只使用正文中玩家可知的信息。只输出[CHOICES]块，正好六行A|行动到F|行动；不使用代码围栏。',
          userPrompt:
              '当前剧本：${character.name}\n剧本设定与世界规则：${_clipPromptText(character.prompt, 6000)}\n地点：${publicState.location}\n公开任务：${publicState.mainTask}\n当前已经完成的正文：\n${MessageContentParser.contextTextForModel(message.content)}\n请换一组六条明显不同的新路线。旧选项供避免重复：\n${MessageContentParser.parseStructured(message.displayContent).choices.map((c) => c.label).join('\n')}',
          temperature: 0.95,
          topP: 0.95);
      final choices =
          MessageContentParser.parseStructured(raw, cache: false).choices;
      if (!RegExp(r'^\s*\[CHOICES\][\s\S]*\[/CHOICES\]\s*$',
                  caseSensitive: false)
              .hasMatch(raw) ||
          ChoiceStrategy.issues(choices).isNotEmpty) {
        throw const FormatException('新选项不完整或有重复，原选项已保留。');
      }
      final latest = await _ensureHistory(worldId);
      if (currentCharacter?.id != worldId ||
          _isSending ||
          _storyOperationInProgress ||
          latest.messages.lastOrNull?.id != messageId ||
          StoryQuote.digest(latest.messages.last.content) != digest) {
        throw StateError('剧情已变化，本次结果未替换。');
      }
      final next = latest.copyWith(messages: [
        ...latest.messages.take(latest.messages.length - 1),
        latest.messages.last.copyWith(
            choiceOverride: ChoiceStrategy.block(choices),
            choiceSourceDigest: digest),
      ]);
      await _store.saveDialogueHistory(next);
      _historyCache[worldId] = next;
    } finally {
      _choicesRefreshing = false;
      _notifyStoryChanges();
    }
  }
}
