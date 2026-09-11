enum CosmeticType {
  title,
  frame,
  sticker,
}

enum CosmeticRewardKind {
  cosmetic,
  title,
}

class MailboxEntry {
  const MailboxEntry({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.description,
    required this.coins,
    required this.createdAt,
    this.claimedAt,
  });

  factory MailboxEntry.fromJson(Map<String, dynamic> json) {
    return MailboxEntry(
      id: json['id']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名邮件',
      description: json['description']?.toString() ?? '',
      coins: _readInt(json['coins']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      claimedAt: DateTime.tryParse(json['claimedAt']?.toString() ?? ''),
    );
  }

  final String id;
  final String sourceId;
  final String title;
  final String description;
  final int coins;
  final DateTime createdAt;
  final DateTime? claimedAt;

  bool get claimed => claimedAt != null;

  MailboxEntry copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? description,
    int? coins,
    DateTime? createdAt,
    DateTime? claimedAt,
  }) {
    return MailboxEntry(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      description: description ?? this.description,
      coins: coins ?? this.coins,
      createdAt: createdAt ?? this.createdAt,
      claimedAt: claimedAt ?? this.claimedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceId': sourceId,
      'title': title,
      'description': description,
      'coins': coins,
      'createdAt': createdAt.toIso8601String(),
      'claimedAt': claimedAt?.toIso8601String(),
    };
  }
}

class CharacterAffinity {
  const CharacterAffinity({
    required this.characterId,
    this.xp = 0,
    this.chatTurns = 0,
  });

  factory CharacterAffinity.fromJson(Map<String, dynamic> json) {
    return CharacterAffinity(
      characterId: json['characterId']?.toString() ?? '',
      xp: _readInt(json['xp']),
      chatTurns: _readInt(json['chatTurns']),
    );
  }

  final String characterId;
  final int xp;
  final int chatTurns;

  int get level => (xp ~/ 30) + 1;

  CharacterAffinity copyWith({
    String? characterId,
    int? xp,
    int? chatTurns,
  }) {
    return CharacterAffinity(
      characterId: characterId ?? this.characterId,
      xp: xp ?? this.xp,
      chatTurns: chatTurns ?? this.chatTurns,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterId': characterId,
      'xp': xp,
      'chatTurns': chatTurns,
    };
  }
}

class CustomBubbleStyle {
  const CustomBubbleStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.css,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomBubbleStyle.create({
    required String id,
    required String name,
    required String description,
    required String css,
  }) {
    final now = DateTime.now();
    return CustomBubbleStyle(
      id: id,
      name: name.trim().isEmpty ? '未命名气泡' : name.trim(),
      description: description.trim(),
      css: css.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory CustomBubbleStyle.fromJson(Map<String, dynamic> json) {
    return CustomBubbleStyle(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名气泡',
      description: json['description']?.toString() ?? '',
      css: json['css']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String name;
  final String description;
  final String css;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomBubbleStyle copyWith({
    String? name,
    String? description,
    String? css,
  }) {
    return CustomBubbleStyle(
      id: id,
      name: name?.trim().isEmpty == true ? '未命名气泡' : name ?? this.name,
      description: description ?? this.description,
      css: css ?? this.css,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'css': css,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class CustomThemeStyle {
  const CustomThemeStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.baseThemeId,
    required this.css,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomThemeStyle.create({
    required String id,
    required String name,
    required String description,
    required String baseThemeId,
    required String css,
  }) {
    final now = DateTime.now();
    return CustomThemeStyle(
      id: id,
      name: name.trim().isEmpty ? '未命名主题' : name.trim(),
      description: description.trim(),
      baseThemeId: baseThemeId.trim(),
      css: css.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory CustomThemeStyle.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return CustomThemeStyle(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名主题',
      description: json['description']?.toString() ?? '',
      baseThemeId: json['baseThemeId']?.toString() ?? 'sakura',
      css: json['css']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }

  final String id;
  final String name;
  final String description;
  final String baseThemeId;
  final String css;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomThemeStyle copyWith({
    String? name,
    String? description,
    String? baseThemeId,
    String? css,
  }) {
    return CustomThemeStyle(
      id: id,
      name: name?.trim().isEmpty == true ? '未命名主题' : name ?? this.name,
      description: description ?? this.description,
      baseThemeId: baseThemeId ?? this.baseThemeId,
      css: css ?? this.css,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'baseThemeId': baseThemeId,
      'css': css,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class GamificationState {
  const GamificationState({
    required this.coins,
    required this.stats,
    required this.dailyStatsDate,
    required this.dailyStats,
    required this.claimedDailyTaskIds,
    required this.lastDailyClaimDate,
    required this.unlockedAchievementIds,
    required this.inventory,
    required this.ownedCosmeticIds,
    required this.equippedTitleId,
    required this.equippedFrameId,
    required this.equippedStickerId,
    required this.characterAffinities,
    required this.storyItemNotes,
    required this.npcInboxReadAt,
    required this.mailbox,
    required this.unlockedThemeIds,
    required this.customBubbleStyles,
    required this.customThemeStyles,
    required this.characterBubbleFrameIds,
    required this.musicUnlockedTrackIds,
    required this.musicPlaylistTrackIds,
    required this.musicCurrentTrackId,
    required this.musicLoopMode,
    required this.musicVolume,
    required this.musicIsPlaying,
  });

  factory GamificationState.initial() {
    return GamificationState(
      coins: 0,
      stats: const <String, int>{},
      dailyStatsDate: _todayKey(DateTime.now()),
      dailyStats: const <String, int>{},
      claimedDailyTaskIds: const <String>[],
      lastDailyClaimDate: '',
      unlockedAchievementIds: const <String>[],
      inventory: const <String, int>{},
      ownedCosmeticIds: const <String>[
        'title_plain',
        'frame_default',
        'sticker_none',
      ],
      equippedTitleId: 'title_plain',
      equippedFrameId: 'frame_default',
      equippedStickerId: 'sticker_none',
      characterAffinities: const <String, CharacterAffinity>{},
      storyItemNotes: const <String, String>{},
      npcInboxReadAt: const <String, String>{},
      mailbox: const <MailboxEntry>[],
      unlockedThemeIds: const <String>[],
      customBubbleStyles: const <CustomBubbleStyle>[],
      customThemeStyles: const <CustomThemeStyle>[],
      characterBubbleFrameIds: const <String, String>{},
      musicUnlockedTrackIds: const <String>[],
      musicPlaylistTrackIds: const <String>[],
      musicCurrentTrackId: '',
      musicLoopMode: 'playlist',
      musicVolume: 0.72,
      musicIsPlaying: false,
    );
  }

  factory GamificationState.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'];
    final rawDailyStats = json['dailyStats'];
    final rawInventory = json['inventory'];
    final rawAffinities = json['characterAffinities'];
    final rawNotes = json['storyItemNotes'];
    final rawNpcInboxReadAt = json['npcInboxReadAt'];
    final rawMailbox = json['mailbox'];
    final rawCustomBubbleStyles = json['customBubbleStyles'];
    final rawCustomThemeStyles = json['customThemeStyles'];
    final rawCharacterBubbleFrameIds = json['characterBubbleFrameIds'];
    final musicUnlocked = _normalizeMusicTrackIds(
      _readStringList(json['musicUnlockedTrackIds']),
      includeDefaults: false,
    );
    final musicPlaylist = _normalizeMusicTrackIds(
      _readStringList(json['musicPlaylistTrackIds'])
          .where((id) => musicUnlocked.contains(id)),
      includeDefaults: false,
    );
    final musicCurrent = json['musicCurrentTrackId']?.toString() ?? '';
    final rawMusicVolume = json['musicVolume'];

    return GamificationState(
      coins: _readInt(json['coins']),
      stats: _readIntMap(rawStats),
      dailyStatsDate:
          json['dailyStatsDate']?.toString() ?? _todayKey(DateTime.now()),
      dailyStats: _readIntMap(rawDailyStats),
      claimedDailyTaskIds: _readStringList(json['claimedDailyTaskIds']),
      lastDailyClaimDate: json['lastDailyClaimDate']?.toString() ?? '',
      unlockedAchievementIds: _readStringList(json['unlockedAchievementIds']),
      inventory: _readIntMap(rawInventory),
      ownedCosmeticIds: _readStringList(json['ownedCosmeticIds']).isEmpty
          ? const <String>['title_plain', 'frame_default', 'sticker_none']
          : _readStringList(json['ownedCosmeticIds']),
      equippedTitleId: json['equippedTitleId']?.toString() ?? 'title_plain',
      equippedFrameId: json['equippedFrameId']?.toString() ?? 'frame_default',
      equippedStickerId:
          json['equippedStickerId']?.toString() ?? 'sticker_none',
      characterAffinities:
          rawAffinities is Map ? _readAffinityMap(rawAffinities) : const {},
      storyItemNotes: rawNotes is Map ? _readStringMap(rawNotes) : const {},
      npcInboxReadAt: rawNpcInboxReadAt is Map
          ? _readStringMap(rawNpcInboxReadAt)
          : const {},
      mailbox: rawMailbox is List
          ? rawMailbox
              .whereType<Map>()
              .map((item) => MailboxEntry.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <MailboxEntry>[],
      unlockedThemeIds: _readStringList(json['unlockedThemeIds']),
      customBubbleStyles: rawCustomBubbleStyles is List
          ? rawCustomBubbleStyles
              .whereType<Map>()
              .map((item) => CustomBubbleStyle.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.id.trim().isNotEmpty)
              .toList(growable: false)
          : const <CustomBubbleStyle>[],
      customThemeStyles: rawCustomThemeStyles is List
          ? rawCustomThemeStyles
              .whereType<Map>()
              .map((item) => CustomThemeStyle.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.id.trim().isNotEmpty)
              .toList(growable: false)
          : const <CustomThemeStyle>[],
      characterBubbleFrameIds: rawCharacterBubbleFrameIds is Map
          ? _readStringMap(rawCharacterBubbleFrameIds)
          : const <String, String>{},
      musicUnlockedTrackIds: musicUnlocked,
      musicPlaylistTrackIds: musicPlaylist,
      musicCurrentTrackId:
          musicUnlocked.contains(musicCurrent) ? musicCurrent : '',
      musicLoopMode:
          json['musicLoopMode']?.toString() == 'single' ? 'single' : 'playlist',
      musicVolume: rawMusicVolume is num
          ? rawMusicVolume.toDouble().clamp(0.0, 1.0)
          : 0.72,
      musicIsPlaying: false,
    ).ensureToday();
  }

  final int coins;
  final Map<String, int> stats;
  final String dailyStatsDate;
  final Map<String, int> dailyStats;
  final List<String> claimedDailyTaskIds;
  final String lastDailyClaimDate;
  final List<String> unlockedAchievementIds;
  final Map<String, int> inventory;
  final List<String> ownedCosmeticIds;
  final String equippedTitleId;
  final String equippedFrameId;
  final String equippedStickerId;
  final Map<String, CharacterAffinity> characterAffinities;
  final Map<String, String> storyItemNotes;
  final Map<String, String> npcInboxReadAt;
  final List<MailboxEntry> mailbox;
  final List<String> unlockedThemeIds;
  final List<CustomBubbleStyle> customBubbleStyles;
  final List<CustomThemeStyle> customThemeStyles;
  final Map<String, String> characterBubbleFrameIds;
  final List<String> musicUnlockedTrackIds;
  final List<String> musicPlaylistTrackIds;
  final String musicCurrentTrackId;
  final String musicLoopMode;
  final double musicVolume;
  final bool musicIsPlaying;

  bool get canClaimDailyBonus => lastDailyClaimDate != todayKey;

  String get todayKey => _todayKey(DateTime.now());

  int get unclaimedMailboxCount =>
      mailbox.where((entry) => !entry.claimed && entry.coins > 0).length;

  int stat(String key) => stats[key] ?? 0;

  int dailyStat(String key) => ensureToday().dailyStats[key] ?? 0;

  int inventoryCount(String itemId) => inventory[itemId] ?? 0;

  bool ownsCosmetic(String cosmeticId) => ownedCosmeticIds.contains(cosmeticId);

  bool ownsTheme(String themeId) => unlockedThemeIds.contains(themeId);

  bool ownsMusicTrack(String trackId) =>
      musicUnlockedTrackIds.contains(trackId);

  bool ownsThemeStyle(String themeId) =>
      ownsTheme(themeId) || customThemeStyles.any((item) => item.id == themeId);

  bool ownsFrame(String frameId) =>
      ownsCosmetic(frameId) ||
      customBubbleStyles.any((item) => item.id == frameId);

  CustomBubbleStyle? customBubbleById(String id) {
    for (final item in customBubbleStyles) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  CustomThemeStyle? customThemeById(String id) {
    for (final item in customThemeStyles) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  String frameForCharacter(String? characterId) {
    final scoped =
        characterId == null ? null : characterBubbleFrameIds[characterId];
    if (scoped != null && ownsFrame(scoped)) {
      return scoped;
    }
    if (ownsFrame(equippedFrameId)) {
      return equippedFrameId;
    }
    return 'frame_default';
  }

  bool hasAchievement(String achievementId) =>
      unlockedAchievementIds.contains(achievementId);

  bool isDailyTaskClaimed(String taskId) =>
      claimedDailyTaskIds.contains(_dailyClaimKey(taskId));

  bool hasMailboxSource(String sourceId) =>
      mailbox.any((entry) => entry.sourceId == sourceId);

  CharacterAffinity affinityFor(String characterId) {
    return characterAffinities[characterId] ??
        CharacterAffinity(characterId: characterId);
  }

  GamificationState ensureToday() {
    final today = _todayKey(DateTime.now());
    if (dailyStatsDate == today) {
      return this;
    }
    return copyWith(
      dailyStatsDate: today,
      dailyStats: const <String, int>{},
      claimedDailyTaskIds: const <String>[],
    );
  }

  GamificationState addCoins(int amount) {
    if (amount <= 0) {
      return this;
    }
    return copyWith(coins: coins + amount);
  }

  GamificationState spendCoins(int amount) {
    return copyWith(coins: (coins - amount).clamp(0, 999999));
  }

  GamificationState incrementStat(String key, [int amount = 1]) {
    if (key.trim().isEmpty || amount == 0) {
      return this;
    }
    final next = Map<String, int>.from(stats);
    next[key] = (next[key] ?? 0) + amount;
    return copyWith(stats: next);
  }

  GamificationState setStatMax(String key, int value) {
    final current = stat(key);
    if (value <= current) {
      return this;
    }
    final next = Map<String, int>.from(stats);
    next[key] = value;
    return copyWith(stats: next);
  }

  GamificationState setStat(String key, int value) {
    if (key.trim().isEmpty) {
      return this;
    }
    final next = Map<String, int>.from(stats);
    next[key] = value;
    return copyWith(stats: next);
  }

  GamificationState incrementDailyStat(String key, [int amount = 1]) {
    final todayState = ensureToday();
    if (key.trim().isEmpty || amount == 0) {
      return todayState;
    }
    final next = Map<String, int>.from(todayState.dailyStats);
    next[key] = (next[key] ?? 0) + amount;
    return todayState.copyWith(dailyStats: next);
  }

  GamificationState claimDailyBonus({
    int coins = 6,
  }) {
    final todayState = ensureToday();
    if (!todayState.canClaimDailyBonus) {
      return todayState;
    }
    return todayState
        .copyWith(lastDailyClaimDate: todayState.todayKey)
        .addCoins(coins)
        .incrementStat('totalDailyClaims')
        .incrementDailyStat('dailyClaims');
  }

  GamificationState claimDailyTask(DailyTaskDefinition task) {
    final todayState = ensureToday();
    if (todayState.isDailyTaskClaimed(task.id)) {
      return todayState;
    }
    final nextClaims = <String>[
      ...todayState.claimedDailyTaskIds,
      todayState._dailyClaimKey(task.id),
    ];
    return todayState
        .copyWith(claimedDailyTaskIds: nextClaims)
        .addCoins(task.rewardCoins)
        .incrementStat('totalDailyTasksClaimed');
  }

  GamificationState addMailboxReward({
    required String sourceId,
    required String title,
    required String description,
    required int coins,
  }) {
    final trimmedSource = sourceId.trim();
    if (trimmedSource.isEmpty ||
        coins <= 0 ||
        hasMailboxSource(trimmedSource)) {
      return this;
    }
    final now = DateTime.now();
    final next = <MailboxEntry>[
      MailboxEntry(
        id: 'mail_${now.microsecondsSinceEpoch}_${mailbox.length}',
        sourceId: trimmedSource,
        title: title.trim().isEmpty ? '系统邮件' : title.trim(),
        description: description.trim(),
        coins: coins,
        createdAt: now,
      ),
      ...mailbox,
    ];
    return copyWith(mailbox: next).setStatMax('maxMailboxEntries', next.length);
  }

  GamificationState claimMailboxEntry(String entryId) {
    final index = mailbox.indexWhere((entry) => entry.id == entryId);
    if (index == -1 || mailbox[index].claimed || mailbox[index].coins <= 0) {
      return this;
    }
    final now = DateTime.now();
    final nextMailbox = <MailboxEntry>[...mailbox];
    nextMailbox[index] = nextMailbox[index].copyWith(claimedAt: now);
    return copyWith(mailbox: nextMailbox)
        .addCoins(mailbox[index].coins)
        .incrementStat('totalMailboxClaims');
  }

  GamificationState claimAllMailboxRewards() {
    var total = 0;
    final now = DateTime.now();
    final nextMailbox = mailbox.map((entry) {
      if (entry.claimed || entry.coins <= 0) {
        return entry;
      }
      total += entry.coins;
      return entry.copyWith(claimedAt: now);
    }).toList(growable: false);
    if (total <= 0) {
      return this;
    }
    return copyWith(mailbox: nextMailbox)
        .addCoins(total)
        .incrementStat('totalMailboxClaims');
  }

  GamificationState addInventory(String itemId, [int amount = 1]) {
    if (itemId.trim().isEmpty || amount <= 0) {
      return this;
    }
    final next = Map<String, int>.from(inventory);
    next[itemId] = (next[itemId] ?? 0) + amount;
    return copyWith(inventory: next).setStatMax(
        'maxInventoryItems', next.values.fold<int>(0, (a, b) => a + b));
  }

  GamificationState removeInventory(String itemId, [int amount = 1]) {
    if (itemId.trim().isEmpty || amount <= 0) {
      return this;
    }
    final current = inventory[itemId] ?? 0;
    if (current <= 0) {
      return this;
    }
    final next = Map<String, int>.from(inventory);
    final remaining = current - amount;
    if (remaining <= 0) {
      next.remove(itemId);
    } else {
      next[itemId] = remaining;
    }
    return copyWith(inventory: next);
  }

  GamificationState removeInventoryItems(Iterable<String> itemIds) {
    final ids =
        itemIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return this;
    }
    final next = Map<String, int>.from(inventory)
      ..removeWhere((id, _) => ids.contains(id));
    return copyWith(inventory: next);
  }

  GamificationState unlockAchievement(AchievementDefinition achievement) {
    if (hasAchievement(achievement.id)) {
      return this;
    }
    var next = copyWith(
      unlockedAchievementIds: <String>[
        ...unlockedAchievementIds,
        achievement.id,
      ],
    ).addMailboxReward(
      sourceId: 'achievement_${achievement.id}',
      title: '成就奖励：${achievement.name}',
      description: '你解锁了「${achievement.name}」，奖励已送达邮箱。',
      coins: achievement.rewardCoins,
    );

    if (achievement.rewardCosmeticId != null) {
      next = next.unlockCosmetic(achievement.rewardCosmeticId!);
    }
    if (achievement.rewardTitleId != null) {
      next = next.unlockCosmetic(achievement.rewardTitleId!);
    }
    return next.setStatMax(
        'maxAchievements', next.unlockedAchievementIds.length);
  }

  GamificationState unlockCosmetic(String cosmeticId) {
    if (ownsCosmetic(cosmeticId)) {
      return this;
    }
    final next = copyWith(
      ownedCosmeticIds: <String>[...ownedCosmeticIds, cosmeticId],
    );
    final framesOwned = next.ownedCosmeticIds.where((id) {
      final cosmetic = GameCatalog.cosmeticById(id);
      return cosmetic?.type == CosmeticType.frame && id != 'frame_default';
    }).length;
    return next.setStatMax('maxFramesUnlocked', framesOwned);
  }

  GamificationState unlockTheme(String themeId) {
    final trimmed = themeId.trim();
    if (trimmed.isEmpty || ownsTheme(trimmed)) {
      return this;
    }
    return copyWith(
      unlockedThemeIds: <String>[...unlockedThemeIds, trimmed],
    ).incrementStat('totalThemeUnlocks');
  }

  GamificationState unlockMusicTrack(String trackId, {int cost = 70}) {
    final cleanId = trackId.trim();
    if (cleanId.isEmpty || ownsMusicTrack(cleanId)) {
      return this;
    }
    return copyWith(
      coins: (coins - cost).clamp(0, 999999),
      musicUnlockedTrackIds: <String>[...musicUnlockedTrackIds, cleanId],
      musicPlaylistTrackIds: <String>{
        ...musicPlaylistTrackIds,
        cleanId,
      }.toList(growable: false),
    )
        .incrementStat('totalMusicUnlocks')
        .setStatMax('maxMusicTracksUnlocked', musicUnlockedTrackIds.length + 1);
  }

  GamificationState setMusicPlayback({
    String? currentTrackId,
    bool? isPlaying,
    String? loopMode,
    double? volume,
  }) {
    return copyWith(
      musicCurrentTrackId: currentTrackId ?? musicCurrentTrackId,
      musicIsPlaying: isPlaying ?? musicIsPlaying,
      musicLoopMode: loopMode ?? musicLoopMode,
      musicVolume: volume ?? musicVolume,
    );
  }

  GamificationState setMusicPlaylist(List<String> trackIds) {
    final cleanIds = _normalizeMusicTrackIds(
      trackIds.where(ownsMusicTrack),
      includeDefaults: false,
    );
    final nextPlaylist = cleanIds;
    return copyWith(
      musicPlaylistTrackIds: nextPlaylist,
      musicCurrentTrackId:
          nextPlaylist.contains(musicCurrentTrackId) ? musicCurrentTrackId : '',
    ).setStatMax('maxMusicPlaylistSize', nextPlaylist.length);
  }

  GamificationState addCustomBubbleStyle(CustomBubbleStyle style) {
    final cleanId = style.id.trim();
    if (cleanId.isEmpty || customBubbleById(cleanId) != null) {
      return this;
    }
    return copyWith(
      customBubbleStyles: <CustomBubbleStyle>[...customBubbleStyles, style],
      equippedFrameId: cleanId,
    )
        .incrementStat('totalCustomBubbleSlots')
        .incrementStat('totalCustomBubblesSaved')
        .setStatMax('maxCustomBubbleSlots', customBubbleStyles.length + 1);
  }

  GamificationState updateCustomBubbleStyle(CustomBubbleStyle style) {
    final nextStyles = <CustomBubbleStyle>[];
    var found = false;
    for (final item in customBubbleStyles) {
      if (item.id == style.id) {
        nextStyles.add(style);
        found = true;
      } else {
        nextStyles.add(item);
      }
    }
    if (!found) {
      return this;
    }
    return copyWith(customBubbleStyles: nextStyles)
        .incrementStat('totalCustomBubblesEdited')
        .incrementStat('totalCustomBubblesSaved');
  }

  GamificationState deleteCustomBubbleStyle(String id) {
    final cleanId = id.trim();
    if (cleanId.isEmpty || customBubbleById(cleanId) == null) {
      return this;
    }
    final nextScoped = Map<String, String>.from(characterBubbleFrameIds)
      ..removeWhere((_, value) => value == cleanId);
    return copyWith(
      customBubbleStyles: customBubbleStyles
          .where((item) => item.id != cleanId)
          .toList(growable: false),
      characterBubbleFrameIds: nextScoped,
      equippedFrameId:
          equippedFrameId == cleanId ? 'frame_default' : equippedFrameId,
    ).incrementStat('totalCustomBubblesDeleted');
  }

  GamificationState addCustomThemeStyle(CustomThemeStyle style) {
    final cleanId = style.id.trim();
    if (cleanId.isEmpty || customThemeById(cleanId) != null) {
      return this;
    }
    return copyWith(
      customThemeStyles: <CustomThemeStyle>[...customThemeStyles, style],
    )
        .incrementStat('totalCustomThemeSlots')
        .incrementStat('totalCustomThemesSaved')
        .setStatMax('maxCustomThemeSlots', customThemeStyles.length + 1);
  }

  GamificationState updateCustomThemeStyle(CustomThemeStyle style) {
    final nextStyles = <CustomThemeStyle>[];
    var found = false;
    for (final item in customThemeStyles) {
      if (item.id == style.id) {
        nextStyles.add(style);
        found = true;
      } else {
        nextStyles.add(item);
      }
    }
    if (!found) {
      return this;
    }
    return copyWith(customThemeStyles: nextStyles)
        .incrementStat('totalCustomThemesEdited')
        .incrementStat('totalCustomThemesSaved');
  }

  GamificationState deleteCustomThemeStyle(String id) {
    final cleanId = id.trim();
    if (cleanId.isEmpty || customThemeById(cleanId) == null) {
      return this;
    }
    return copyWith(
      customThemeStyles: customThemeStyles
          .where((item) => item.id != cleanId)
          .toList(growable: false),
    ).incrementStat('totalCustomThemesDeleted');
  }

  GamificationState equipCosmetic(String cosmeticId) {
    final cosmetic = GameCatalog.cosmeticById(cosmeticId);
    if (cosmetic == null || !ownsCosmetic(cosmeticId)) {
      return this;
    }
    return switch (cosmetic.type) {
      CosmeticType.title => copyWith(equippedTitleId: cosmeticId),
      CosmeticType.frame => copyWith(equippedFrameId: cosmeticId),
      CosmeticType.sticker => copyWith(equippedStickerId: cosmeticId),
    };
  }

  GamificationState equipFrame(String frameId) {
    final cleanId = frameId.trim();
    if (cleanId.isEmpty || !ownsFrame(cleanId)) {
      return this;
    }
    return copyWith(equippedFrameId: cleanId);
  }

  GamificationState assignCharacterBubbleFrame({
    required String characterId,
    required String frameId,
  }) {
    final cleanCharacterId = characterId.trim();
    final cleanFrameId = frameId.trim();
    if (cleanCharacterId.isEmpty || !ownsFrame(cleanFrameId)) {
      return this;
    }
    final next = Map<String, String>.from(characterBubbleFrameIds);
    if (cleanFrameId == equippedFrameId) {
      next.remove(cleanCharacterId);
    } else {
      next[cleanCharacterId] = cleanFrameId;
    }
    return copyWith(characterBubbleFrameIds: next)
        .incrementStat('totalCharacterBubbleAssignments');
  }

  GamificationState clearCharacterBubbleFrame(String characterId) {
    final cleanCharacterId = characterId.trim();
    if (cleanCharacterId.isEmpty ||
        !characterBubbleFrameIds.containsKey(cleanCharacterId)) {
      return this;
    }
    final next = Map<String, String>.from(characterBubbleFrameIds)
      ..remove(cleanCharacterId);
    return copyWith(characterBubbleFrameIds: next);
  }

  GamificationState migrateStickerCosmeticsToMailbox() {
    const migrationKey = 'sticker_refund_v153_addon';
    if (stat(migrationKey) > 0) {
      return this;
    }
    const stickerRefunds = <String, int>{
      'sticker_duck': 8,
      'sticker_crown': 9,
      'sticker_ghost': 9,
    };
    var refund = 0;
    final nextOwned = <String>[];
    for (final cosmeticId in ownedCosmeticIds) {
      if (cosmeticId == 'sticker_none') {
        continue;
      }
      final stickerRefund = stickerRefunds[cosmeticId];
      if (stickerRefund != null) {
        refund += stickerRefund;
        continue;
      }
      nextOwned.add(cosmeticId);
    }
    var next = copyWith(
      ownedCosmeticIds: <String>{
        'title_plain',
        'frame_default',
        ...nextOwned,
      }.toList(growable: false),
      equippedStickerId: 'sticker_none',
    ).incrementStat(migrationKey);
    if (refund > 0) {
      next = next.addMailboxReward(
        sourceId: migrationKey,
        title: '贴纸下架返还',
        description: '贴纸装扮已经合并下架，你购买过的贴纸已按原价返还成啥币。',
        coins: refund,
      );
    }
    return next;
  }

  GamificationState addCompanionXp(String characterId, int xp) {
    if (characterId.trim().isEmpty || xp <= 0) {
      return this;
    }
    final current = affinityFor(characterId);
    final nextAffinity = current.copyWith(
      xp: current.xp + xp,
      chatTurns: current.chatTurns + 1,
    );
    final nextMap = Map<String, CharacterAffinity>.from(characterAffinities);
    nextMap[characterId] = nextAffinity;
    return copyWith(characterAffinities: nextMap)
        .setStatMax('maxCompanionLevel', nextAffinity.level);
  }

  GamificationState updateStoryItemNote(String itemName, String note) {
    final key = itemName.trim();
    if (key.isEmpty) {
      return this;
    }
    final next = Map<String, String>.from(storyItemNotes);
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      next.remove(key);
    } else {
      next[key] = trimmedNote;
    }
    return copyWith(storyItemNotes: next).incrementStat('totalStoryItemNotes');
  }

  GamificationState markNpcInboxRead(String characterId) {
    if (characterId.trim().isEmpty) {
      return this;
    }
    final next = Map<String, String>.from(npcInboxReadAt);
    next[characterId] = DateTime.now().toIso8601String();
    return copyWith(npcInboxReadAt: next).incrementDailyStat('npcInboxOpens');
  }

  GamificationState copyWith({
    int? coins,
    Map<String, int>? stats,
    String? dailyStatsDate,
    Map<String, int>? dailyStats,
    List<String>? claimedDailyTaskIds,
    String? lastDailyClaimDate,
    List<String>? unlockedAchievementIds,
    Map<String, int>? inventory,
    List<String>? ownedCosmeticIds,
    String? equippedTitleId,
    String? equippedFrameId,
    String? equippedStickerId,
    Map<String, CharacterAffinity>? characterAffinities,
    Map<String, String>? storyItemNotes,
    Map<String, String>? npcInboxReadAt,
    List<MailboxEntry>? mailbox,
    List<String>? unlockedThemeIds,
    List<CustomBubbleStyle>? customBubbleStyles,
    List<CustomThemeStyle>? customThemeStyles,
    Map<String, String>? characterBubbleFrameIds,
    List<String>? musicUnlockedTrackIds,
    List<String>? musicPlaylistTrackIds,
    String? musicCurrentTrackId,
    String? musicLoopMode,
    double? musicVolume,
    bool? musicIsPlaying,
  }) {
    return GamificationState(
      coins: coins ?? this.coins,
      stats: stats ?? this.stats,
      dailyStatsDate: dailyStatsDate ?? this.dailyStatsDate,
      dailyStats: dailyStats ?? this.dailyStats,
      claimedDailyTaskIds: claimedDailyTaskIds ?? this.claimedDailyTaskIds,
      lastDailyClaimDate: lastDailyClaimDate ?? this.lastDailyClaimDate,
      unlockedAchievementIds:
          unlockedAchievementIds ?? this.unlockedAchievementIds,
      inventory: inventory ?? this.inventory,
      ownedCosmeticIds: ownedCosmeticIds ?? this.ownedCosmeticIds,
      equippedTitleId: equippedTitleId ?? this.equippedTitleId,
      equippedFrameId: equippedFrameId ?? this.equippedFrameId,
      equippedStickerId: equippedStickerId ?? this.equippedStickerId,
      characterAffinities: characterAffinities ?? this.characterAffinities,
      storyItemNotes: storyItemNotes ?? this.storyItemNotes,
      npcInboxReadAt: npcInboxReadAt ?? this.npcInboxReadAt,
      mailbox: mailbox ?? this.mailbox,
      unlockedThemeIds: unlockedThemeIds ?? this.unlockedThemeIds,
      customBubbleStyles: customBubbleStyles ?? this.customBubbleStyles,
      customThemeStyles: customThemeStyles ?? this.customThemeStyles,
      characterBubbleFrameIds:
          characterBubbleFrameIds ?? this.characterBubbleFrameIds,
      musicUnlockedTrackIds:
          musicUnlockedTrackIds ?? this.musicUnlockedTrackIds,
      musicPlaylistTrackIds:
          musicPlaylistTrackIds ?? this.musicPlaylistTrackIds,
      musicCurrentTrackId: musicCurrentTrackId ?? this.musicCurrentTrackId,
      musicLoopMode: musicLoopMode ?? this.musicLoopMode,
      musicVolume: musicVolume ?? this.musicVolume,
      musicIsPlaying: musicIsPlaying ?? this.musicIsPlaying,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'coins': coins,
      'stats': stats,
      'dailyStatsDate': dailyStatsDate,
      'dailyStats': dailyStats,
      'claimedDailyTaskIds': claimedDailyTaskIds,
      'lastDailyClaimDate': lastDailyClaimDate,
      'unlockedAchievementIds': unlockedAchievementIds,
      'inventory': inventory,
      'ownedCosmeticIds': ownedCosmeticIds,
      'equippedTitleId': equippedTitleId,
      'equippedFrameId': equippedFrameId,
      'equippedStickerId': equippedStickerId,
      'characterAffinities': characterAffinities.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'storyItemNotes': storyItemNotes,
      'npcInboxReadAt': npcInboxReadAt,
      'mailbox': mailbox.map((entry) => entry.toJson()).toList(),
      'unlockedThemeIds': unlockedThemeIds,
      'customBubbleStyles':
          customBubbleStyles.map((style) => style.toJson()).toList(),
      'customThemeStyles':
          customThemeStyles.map((style) => style.toJson()).toList(),
      'characterBubbleFrameIds': characterBubbleFrameIds,
      'musicUnlockedTrackIds': musicUnlockedTrackIds,
      'musicPlaylistTrackIds': musicPlaylistTrackIds,
      'musicCurrentTrackId': musicCurrentTrackId,
      'musicLoopMode': musicLoopMode,
      'musicVolume': musicVolume,
      'musicIsPlaying': musicIsPlaying,
    };
  }

  String _dailyClaimKey(String taskId) => '$todayKey::$taskId';

  static String _todayKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class DailyTaskDefinition {
  const DailyTaskDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.statKey,
    required this.target,
    required this.rewardCoins,
  });

  final String id;
  final String name;
  final String description;
  final String statKey;
  final int target;
  final int rewardCoins;
}

class ShopItemDefinition {
  const ShopItemDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.effectId,
  });

  final String id;
  final String name;
  final String description;
  final int cost;
  final String effectId;
}

class CosmeticDefinition {
  const CosmeticDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.cost = 0,
    this.defaultOwned = false,
  });

  final String id;
  final String name;
  final String description;
  final CosmeticType type;
  final int cost;
  final bool defaultOwned;
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.unlockText,
    required this.statKey,
    required this.threshold,
    required this.rewardCoins,
    this.rewardTitleId,
    this.rewardCosmeticId,
    this.hidden = false,
  });

  final String id;
  final String name;
  final String unlockText;
  final String statKey;
  final int threshold;
  final int rewardCoins;
  final String? rewardTitleId;
  final String? rewardCosmeticId;
  final bool hidden;

  bool isUnlockedBy(GamificationState state) {
    return state.stat(statKey) >= threshold;
  }
}

class GameCatalog {
  const GameCatalog._();

  static const List<String> rouletteTitleIds = <String>[
    'title_roulette_legal_lucky',
    'title_roulette_shop_relative',
    'title_roulette_pity_cultist',
    'title_roulette_empty_champion',
    'title_roulette_coin_medium',
  ];

  static const List<String> rouletteFrameIds = <String>[
    'frame_roulette_ticket_stub',
    'frame_roulette_gold_scratch',
    'frame_roulette_pity_ring',
    'frame_roulette_debt_stamp',
    'frame_roulette_static_luck',
  ];

  static const List<DailyTaskDefinition> dailyTasks = <DailyTaskDefinition>[
    DailyTaskDefinition(
      id: 'send_message',
      name: '今日开麦',
      description: '发送 1 条消息。',
      statKey: 'userMessages',
      target: 1,
      rewardCoins: 3,
    ),
    DailyTaskDefinition(
      id: 'assistant_reply',
      name: '让角色营业',
      description: '触发 1 次 AI 回复。',
      statKey: 'assistantReplies',
      target: 1,
      rewardCoins: 5,
    ),
    DailyTaskDefinition(
      id: 'open_hub',
      name: '逛逛小铺',
      description: '打开 1 次小游戏中心。',
      statKey: 'gameHubOpens',
      target: 1,
      rewardCoins: 2,
    ),
    DailyTaskDefinition(
      id: 'npc_inbox',
      name: '查收纸条',
      description: '打开 1 次 NPC 来信箱。',
      statKey: 'npcInboxOpens',
      target: 1,
      rewardCoins: 3,
    ),
    DailyTaskDefinition(
      id: 'use_item',
      name: '道具不要吃灰',
      description: '使用 1 张背包里的功能券。',
      statKey: 'itemsUsed',
      target: 1,
      rewardCoins: 4,
    ),
  ];

  static const List<ShopItemDefinition> shopItems = <ShopItemDefinition>[
    ShopItemDefinition(
      id: 'ticket_comedy_stage',
      name: '吐槽小剧场券',
      description: '生成一段不推进主线的角色吐槽、路人吐槽或旁白拆台小剧场。',
      cost: 6,
      effectId: 'comedy_stage',
    ),
    ShopItemDefinition(
      id: 'ticket_forum_burst',
      name: '论坛热帖券',
      description: '生成当前世界观里的论坛热帖、评论区和围观群众发言。',
      cost: 7,
      effectId: 'forum_burst',
    ),
    ShopItemDefinition(
      id: 'ticket_npc_gossip',
      name: 'NPC 八卦小报',
      description: '用八卦小报口吻整理 NPC 之间的传闻、误会和暗流。',
      cost: 8,
      effectId: 'npc_gossip',
    ),
    ShopItemDefinition(
      id: 'ticket_passerby_camera',
      name: '路人视角镜头',
      description: '从某个路人、同学、宫人或围观者视角看一眼当前剧情。',
      cost: 6,
      effectId: 'passerby_camera',
    ),
    ShopItemDefinition(
      id: 'ticket_mood_radio',
      name: '今日电台券',
      description: '生成一段像广播电台一样的当前剧情情绪播报。',
      cost: 7,
      effectId: 'mood_radio',
    ),
    ShopItemDefinition(
      id: 'ticket_rumor_board',
      name: '谣言公告栏',
      description: '生成当前世界里的谣言、误读、半真半假的公告栏。',
      cost: 6,
      effectId: 'rumor_board',
    ),
    ShopItemDefinition(
      id: 'ticket_prophecy_trash',
      name: '离谱预言垃圾桶',
      description: '生成一段看似预言其实很不靠谱的趣味分支脑洞。',
      cost: 8,
      effectId: 'prophecy_trash',
    ),
    ShopItemDefinition(
      id: 'ticket_npc_letter',
      name: 'NPC 来信券',
      description: '让一个已出现的 NPC 主动发来一段私聊消息，记录保存在来信箱。',
      cost: 6,
      effectId: 'npc_letter',
    ),
    ShopItemDefinition(
      id: 'ticket_child_spray',
      name: '变小孩喷雾',
      description: '指定 NPC 变成你描述的小孩模样。不推进主线，只生成一段趣味小剧场。',
      cost: 6,
      effectId: 'child_spray',
    ),
    ShopItemDefinition(
      id: 'ticket_beast_ear_potion',
      name: '兽耳魔药',
      description: '指定 NPC 长出兽耳。你可以填写耳朵类型，也可以让 AI 自由发挥。',
      cost: 6,
      effectId: 'beast_ear_potion',
    ),
    ShopItemDefinition(
      id: 'ticket_touch',
      name: '摸一摸',
      description: '指定 NPC、触碰部位，可选一句话。不推进主线，只生成一段温情的互动小剧场。',
      cost: 7,
      effectId: 'touch',
    ),
    ShopItemDefinition(
      id: 'ticket_truth_lollipop',
      name: '真心话棒棒糖',
      description: '指定 NPC 对你说的真心话。不推进主线，只生成一段小剧场对白。',
      cost: 7,
      effectId: 'truth_lollipop',
    ),
  ];

  static const List<ShopItemDefinition> legacyShopItems = <ShopItemDefinition>[
    ShopItemDefinition(
      id: 'ticket_recap',
      name: '前情回顾券',
      description: '旧版道具：整理最近剧情，生成电视剧式上集提要。',
      cost: 6,
      effectId: 'recap',
    ),
    ShopItemDefinition(
      id: 'ticket_branch_preview',
      name: '预演券',
      description: '旧版道具：不推进剧情，分析下一步选项的可能影响。',
      cost: 7,
      effectId: 'branch_preview',
    ),
    ShopItemDefinition(
      id: 'ticket_foreshadow',
      name: '伏笔放大镜',
      description: '旧版道具：整理已经出现但值得留意的伏笔和暗线。',
      cost: 6,
      effectId: 'foreshadow',
    ),
    ShopItemDefinition(
      id: 'ticket_relationship',
      name: '关系雷达',
      description: '旧版道具：生成 NPC 关系、态度和好感线索图。',
      cost: 7,
      effectId: 'relationship',
    ),
    ShopItemDefinition(
      id: 'ticket_inspiration_dice',
      name: '灵感骰子',
      description: '旧版道具：不知道下一步干嘛时，摇出一组行动建议。',
      cost: 5,
      effectId: 'inspiration_dice',
    ),
    ShopItemDefinition(
      id: 'ticket_dream_fragment',
      name: '梦境碎片',
      description: '旧版道具：生成一段不推进主线的梦境、番外或心理片段。',
      cost: 8,
      effectId: 'dream_fragment',
    ),
    ShopItemDefinition(
      id: 'ticket_archive_cover',
      name: '存档胶片',
      description: '旧版道具：生成当前剧情的可视化存档封面。',
      cost: 6,
      effectId: 'cover',
    ),
  ];

  static const List<ShopItemDefinition> allShopItems = <ShopItemDefinition>[
    ...shopItems,
    ...legacyShopItems,
  ];

  static const List<CosmeticDefinition> cosmetics = <CosmeticDefinition>[
    CosmeticDefinition(
      id: 'title_plain',
      name: '平平无奇玩家',
      description: '默认称号，朴素但可靠。',
      type: CosmeticType.title,
      defaultOwned: true,
    ),
    CosmeticDefinition(
      id: 'frame_default',
      name: '默认边框',
      description: '什么也不抢戏。',
      type: CosmeticType.frame,
      defaultOwned: true,
    ),
    CosmeticDefinition(
      id: 'sticker_none',
      name: '无贴纸',
      description: '旧版占位：贴纸系统已下架。',
      type: CosmeticType.sticker,
      defaultOwned: true,
    ),
    CosmeticDefinition(
      id: 'title_court_newbie',
      name: '宫里来新人了',
      description: '首次打开就能拿到的小牌牌。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_every_home',
      name: '端水大师预备役',
      description: '给每个角色一个家，也给自己一点忙碌。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_fleeting',
      name: '来也匆匆去也匆匆',
      description: '角色来了，角色又走了。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_npc_whisperer',
      name: '小窗社交恐怖分子',
      description: 'NPC 私聊常驻人口。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_tool_foreman',
      name: '工具箱包工头',
      description: '哪里需要工具，哪里就有你。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_poor_but_happy',
      name: '精致穷鬼',
      description: '啥币花完，快乐留下。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_companion',
      name: '这不是陪伴是什么',
      description: '和角色的熟练度已经很像一回事了。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_abyss_watched',
      name: '祂看见我了',
      description: '深渊主题初体验纪念称号。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_glitch_artist',
      name: '乱码修仙大成',
      description: '看得懂看不懂都先装作看懂。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_shop_regular',
      name: '老板，还是老样子',
      description: '买得多了，商店老板都眼熟你。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_full_drip',
      name: '全身上下都是戏',
      description: '称号和边框都得整上，仪式感不能少。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_old_school',
      name: '经典永不过时',
      description: '怀旧玩法也能玩到上头。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_gaze_once',
      name: '被祂看过一眼',
      description: '别紧张，祂可能只是路过。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_night_shift',
      name: '夜班造梦员',
      description: '凌晨还在开剧情的人，精神状态值得存档。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_f_option',
      name: 'F 选项信徒',
      description: '不走寻常路，专挑命运的门缝钻。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_frame_collector',
      name: '边框收藏家',
      description: '气泡没换衣服就像出门没带灵魂。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_flower_dream',
      name: '夜半来，天明去',
      description: '来似春梦，去似朝云。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_sky_rancher',
      name: '云朵牧场主',
      description: '晴空牧场第一次装扮纪念称号。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_vinyl_listener',
      name: '黑胶收藏家',
      description: '黑胶往事第一次装扮纪念称号。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_fanfic_writer',
      name: '三千字起步选手',
      description: '写同人文，主打一个字数先把气势撑起来。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_blind_box_author',
      name: '梗从天降接住了',
      description: '灵感盲盒砸下来，也能写成一篇。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_archive_keeper',
      name: '存档保命派',
      description: '命运可以重开，快照必须先存。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_cleanup_master',
      name: '本地清洁大师',
      description: '该留的故事留下，该扫的缓存扫掉。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_worldbook_librarian',
      name: '世界书管理员',
      description: '一本一本绑好，世界线终于不乱跑了。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_achievement_mountain',
      name: '成就山登顶游客',
      description: '成就墙已经开始需要承重测试。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_npc_migrator',
      name: '我带你走',
      description: '旧世界关门前，至少还有人牵住了手。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_bond_keeper',
      name: '关系不是数字',
      description: '好感会涨，羁绊会长出方向。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_theme_tailor',
      name: '主题裁缝',
      description: '别人换衣服，你直接给整个剧场量体裁衣。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_theater_tuner',
      name: '剧场调音师',
      description: '每个主题都得有自己的出场音乐。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_pocket_record_cabinet',
      name: '随身唱片柜',
      description: '歌都在你这儿，谁还敢说剧场安静。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_resident_listener',
      name: '常驻听众',
      description: '音乐不是背景，是你留在剧场里的呼吸声。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_roulette_legal_lucky',
      name: '合法欧皇（试用版）',
      description: '转盘限定称号：欧气很亮，但老板说只给试用。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_roulette_shop_relative',
      name: '奸商远房亲戚',
      description: '转盘限定称号：和老板没有血缘，但钱包很像。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_roulette_pity_cultist',
      name: '保底教虔诚信徒',
      description: '转盘限定称号：信保底，得安慰。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_roulette_empty_champion',
      name: '谢谢惠顾冠军',
      description: '转盘限定称号：空奖也是奖，至少心态练出来了。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'title_roulette_coin_medium',
      name: '啥币听诊器',
      description: '转盘限定称号：能听见钱包发出很轻的叹气声。',
      type: CosmeticType.title,
    ),
    CosmeticDefinition(
      id: 'frame_sticky_note',
      name: '便签边框',
      description: '像把故事贴在桌角。',
      type: CosmeticType.frame,
      cost: 10,
    ),
    CosmeticDefinition(
      id: 'frame_cat_paw',
      name: '猫爪页角',
      description: '角落里偷偷踩了一脚。',
      type: CosmeticType.frame,
      cost: 12,
    ),
    CosmeticDefinition(
      id: 'frame_moon_ticket',
      name: '月光票根',
      description: '像半夜看完一场小电影。',
      type: CosmeticType.frame,
      cost: 14,
    ),
    CosmeticDefinition(
      id: 'frame_whisper_rift',
      name: '低语裂隙',
      description: '边缘像被谁从梦里轻轻撕开。',
      type: CosmeticType.frame,
      cost: 18,
    ),
    CosmeticDefinition(
      id: 'frame_inbox_burst',
      name: '信箱爆炸',
      description: '邮戳、虚线、纸片感，像刚被 NPC 消息轰炸。',
      type: CosmeticType.frame,
      cost: 16,
    ),
    CosmeticDefinition(
      id: 'frame_cream_note',
      name: '奶油便签',
      description: '低饱和手帐感，软乎乎但不幼稚。',
      type: CosmeticType.frame,
      cost: 13,
    ),
    CosmeticDefinition(
      id: 'frame_film_strip',
      name: '旧电影胶片',
      description: '像把对白塞进一卷深夜胶片。',
      type: CosmeticType.frame,
      cost: 17,
    ),
    CosmeticDefinition(
      id: 'frame_pixel_quest',
      name: '像素冒险',
      description: '小游戏味很足，仿佛下一秒就要掉落宝箱。',
      type: CosmeticType.frame,
      cost: 15,
    ),
    CosmeticDefinition(
      id: 'frame_bad_luck_charm',
      name: '霉运退散符',
      description: '不一定真能退散，但看起来很努力。',
      type: CosmeticType.frame,
      cost: 16,
    ),
    CosmeticDefinition(
      id: 'frame_roulette_ticket_stub',
      name: '转盘票根碎片',
      description: '转盘限定边框：像刚从命运售票口撕下来。',
      type: CosmeticType.frame,
    ),
    CosmeticDefinition(
      id: 'frame_roulette_gold_scratch',
      name: '金粉刮刮乐碎片',
      description: '转盘限定边框：中奖没有，闪粉管够。',
      type: CosmeticType.frame,
    ),
    CosmeticDefinition(
      id: 'frame_roulette_pity_ring',
      name: '保底光环碎片',
      description: '转盘限定边框：越抽不到，越像被安慰。',
      type: CosmeticType.frame,
    ),
    CosmeticDefinition(
      id: 'frame_roulette_debt_stamp',
      name: '欠条印章碎片',
      description: '转盘限定边框：老板盖章，命运背书。',
      type: CosmeticType.frame,
    ),
    CosmeticDefinition(
      id: 'frame_roulette_static_luck',
      name: '好运雪花屏碎片',
      description: '转盘限定边框：信号不好，但好运正在加载。',
      type: CosmeticType.frame,
    ),
  ];

  static const List<AchievementDefinition> achievements =
      <AchievementDefinition>[
    AchievementDefinition(
      id: 'tutorial_good_baby',
      name: '乖宝宝',
      unlockText: '打开新手教程并且不跳过，一条条完整看完。',
      statKey: 'totalTutorialCompletions',
      threshold: 1,
      rewardCoins: 20,
    ),
    AchievementDefinition(
      id: 'tutorial_bad_baby',
      name: '坏宝宝',
      unlockText: '直接跳过新手教程。',
      statKey: 'totalTutorialSkips',
      threshold: 1,
      rewardCoins: 20,
    ),
    AchievementDefinition(
      id: 'first_open',
      name: '宫里来新人了',
      unlockText: '第一次打开这个小程序。',
      statKey: 'firstOpen',
      threshold: 1,
      rewardCoins: 10,
      rewardTitleId: 'title_court_newbie',
    ),
    AchievementDefinition(
      id: 'first_message',
      name: '开麦，朕要说话',
      unlockText: '发送第一条用户消息。',
      statKey: 'totalUserMessages',
      threshold: 1,
      rewardCoins: 5,
    ),
    AchievementDefinition(
      id: 'first_reply',
      name: '第一只回音怪',
      unlockText: '成功获得第一条 AI 回复。',
      statKey: 'totalAssistantReplies',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'messages_20',
      name: '话匣子拧开了',
      unlockText: '累计发送 20 条消息。',
      statKey: 'totalUserMessages',
      threshold: 20,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'messages_100',
      name: '本宫今日话很多',
      unlockText: '累计发送 100 条消息。',
      statKey: 'totalUserMessages',
      threshold: 100,
      rewardCoins: 25,
    ),
    AchievementDefinition(
      id: 'created_1',
      name: '今天也在捏人',
      unlockText: '创建第一个 AI 角色。',
      statKey: 'totalCharactersCreated',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'active_10',
      name: '我只是想给每个人一个家',
      unlockText: '同时拥有 10 个及以上 AI 角色。',
      statKey: 'maxActiveCharacters',
      threshold: 10,
      rewardCoins: 20,
      rewardTitleId: 'title_every_home',
    ),
    AchievementDefinition(
      id: 'deleted_10',
      name: '来也匆匆去也匆匆？',
      unlockText: '累计删除角色超过 10 个。',
      statKey: 'totalCharactersDeleted',
      threshold: 10,
      rewardCoins: 20,
      rewardTitleId: 'title_fleeting',
    ),
    AchievementDefinition(
      id: 'npc_1',
      name: '隔壁有人敲门',
      unlockText: '创建或自动识别第一个 NPC。',
      statKey: 'totalNpcProfilesCreated',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'npc_5',
      name: '人脉这不就来了吗',
      unlockText: '累计创建或识别 5 个 NPC。',
      statKey: 'totalNpcProfilesCreated',
      threshold: 5,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'npc_reply_1',
      name: '小窗已读不回？不存在的',
      unlockText: '完成第一次 NPC 私聊回复。',
      statKey: 'totalNpcReplies',
      threshold: 1,
      rewardCoins: 8,
      rewardTitleId: 'title_npc_whisperer',
    ),
    AchievementDefinition(
      id: 'npc_letters_1',
      name: '突然收到一张纸条',
      unlockText: '收到第一封 NPC 主动来信。',
      statKey: 'totalNpcLetters',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'tool_1',
      name: '工具箱第一次上工',
      unlockText: '生成第一条剧情工具结果。',
      statKey: 'totalToolResults',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'tools_10',
      name: '工具箱包工头',
      unlockText: '累计生成 10 条剧情工具结果。',
      statKey: 'totalToolResults',
      threshold: 10,
      rewardCoins: 18,
      rewardTitleId: 'title_tool_foreman',
    ),
    AchievementDefinition(
      id: 'shop_1',
      name: '啥币花出去了，心疼但爽',
      unlockText: '第一次在商店购买道具或装扮。',
      statKey: 'totalShopPurchases',
      threshold: 1,
      rewardCoins: 5,
      rewardTitleId: 'title_poor_but_happy',
    ),
    AchievementDefinition(
      id: 'items_used_5',
      name: '道具不是买来吃灰的',
      unlockText: '累计使用 5 次背包道具。',
      statKey: 'totalItemsUsed',
      threshold: 5,
      rewardCoins: 16,
    ),
    AchievementDefinition(
      id: 'daily_1',
      name: '今日份营业',
      unlockText: '领取第一次每日啥币。',
      statKey: 'totalDailyClaims',
      threshold: 1,
      rewardCoins: 5,
    ),
    AchievementDefinition(
      id: 'daily_7',
      name: '七天没跑路',
      unlockText: '累计领取 7 次每日啥币。',
      statKey: 'totalDailyClaims',
      threshold: 7,
      rewardCoins: 20,
    ),
    AchievementDefinition(
      id: 'clear_1',
      name: '清空也是一种重开',
      unlockText: '首次清空当前角色聊天记录。',
      statKey: 'totalHistoryClears',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'export_1',
      name: '把故事装进小盒子',
      unlockText: '首次导出聊天记录。',
      statKey: 'totalExports',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'sim_prompt_1',
      name: '文游开炉',
      unlockText: '首次使用“AI 帮你写”生成模拟器提示词。',
      statKey: 'totalSimulatorPrompts',
      threshold: 1,
      rewardCoins: 10,
    ),
    AchievementDefinition(
      id: 'cosmetic_1',
      name: '换衣服也算更新',
      unlockText: '首次装备称号或气泡边框。',
      statKey: 'totalCosmeticsEquipped',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'companion_3',
      name: '你俩开始熟了',
      unlockText: '任意 AI 角色陪伴等级达到 3 级。',
      statKey: 'maxCompanionLevel',
      threshold: 3,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'companion_6',
      name: '这不是陪伴是什么',
      unlockText: '任意 AI 角色陪伴等级达到 6 级。',
      statKey: 'maxCompanionLevel',
      threshold: 6,
      rewardCoins: 28,
      rewardTitleId: 'title_companion',
    ),
    AchievementDefinition(
      id: 'story_note_1',
      name: '背包物品贴便签',
      unlockText: '给剧情背包里的物品写下第一条备注。',
      statKey: 'totalStoryItemNotes',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'inventory_5',
      name: '背包鼓起来了',
      unlockText: '背包里的功能券累计达到 5 张。',
      statKey: 'maxInventoryItems',
      threshold: 5,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'theme_cthulhu',
      name: '深渊盯上我了',
      unlockText: '切换到“深渊观测站”主题一次。',
      statKey: 'totalCthulhuThemeUses',
      threshold: 1,
      rewardCoins: 8,
      rewardTitleId: 'title_abyss_watched',
    ),
    AchievementDefinition(
      id: 'theme_april',
      name: '乱码也是一种艺术',
      unlockText: '切换到“愚人节特调”主题一次。',
      statKey: 'totalAprilFoolsThemeUses',
      threshold: 1,
      rewardCoins: 8,
      rewardTitleId: 'title_glitch_artist',
    ),
    AchievementDefinition(
      id: 'theme_flower_not_flower',
      name: '花非花，梦非梦',
      unlockText: '切换到“花非花”主题一次。',
      statKey: 'totalFlowerNotFlowerThemeUses',
      threshold: 1,
      rewardCoins: 12,
      rewardTitleId: 'title_flower_dream',
    ),
    AchievementDefinition(
      id: 'theme_rift_relay',
      name: '裂隙打卡成功',
      unlockText: '切换到“裂隙中转站”主题一次。',
      statKey: 'totalRiftRelayThemeUses',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'theme_mechanical_city',
      name: '齿轮转我也转',
      unlockText: '切换到“机械迷城”主题一次。',
      statKey: 'totalMechanicalCityThemeUses',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'theme_rain_radio',
      name: '雨声调频成功',
      unlockText: '切换到“雨巷电台”主题一次。',
      statKey: 'totalRainRadioThemeUses',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'theme_sky_pasture',
      name: '今天开始放牧云朵',
      unlockText: '购买后第一次装扮“晴空牧场”。',
      statKey: 'totalSkyPastureThemeUses',
      threshold: 1,
      rewardCoins: 20,
      rewardTitleId: 'title_sky_rancher',
    ),
    AchievementDefinition(
      id: 'theme_vinyl_memories',
      name: '唱针落下，钱包轻响',
      unlockText: '购买后第一次装扮“黑胶往事”。',
      statKey: 'totalVinylMemoriesThemeUses',
      threshold: 1,
      rewardCoins: 20,
      rewardTitleId: 'title_vinyl_listener',
    ),
    AchievementDefinition(
      id: 'blind_box_new',
      name: '盲盒成精了',
      unlockText: '使用一次创新版开盲盒生成模拟器。',
      statKey: 'totalBlindBoxes',
      threshold: 1,
      rewardCoins: 10,
    ),
    AchievementDefinition(
      id: 'blind_box_classic',
      name: '老板，来点旧梦',
      unlockText: '使用一次“开盲盒（怀旧版）”。',
      statKey: 'totalClassicBlindBoxes',
      threshold: 1,
      rewardCoins: 10,
      rewardTitleId: 'title_old_school',
    ),
    AchievementDefinition(
      id: 'frame_equipped_1',
      name: '边框也是门面',
      unlockText: '装备第一款非默认边框。',
      statKey: 'totalFramesEquipped',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'frames_unlocked_3',
      name: '衣柜里开始有边框味了',
      unlockText: '累计解锁 3 款气泡边框。',
      statKey: 'maxFramesUnlocked',
      threshold: 3,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'custom_bubble_slot_1',
      name: '装修队进场',
      unlockText: '购买并保存第一个自定义气泡格子。',
      statKey: 'totalCustomBubbleSlots',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'custom_bubble_equipped_1',
      name: '这边框有点东西',
      unlockText: '第一次装备自定义气泡。',
      statKey: 'totalCustomBubblesEquipped',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'custom_bubble_assign_1',
      name: '给 TA 单独穿上',
      unlockText: '第一次给当前角色绑定专属气泡。',
      statKey: 'totalCharacterBubbleAssignments',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'custom_bubble_saved_3',
      name: 'CSS 玄学大师',
      unlockText: '累计保存 3 次自定义气泡。',
      statKey: 'totalCustomBubblesSaved',
      threshold: 3,
      rewardCoins: 18,
    ),
    AchievementDefinition(
      id: 'custom_theme_slot_1',
      name: '装修队接到大单',
      unlockText: '购买并保存第一个自定义主题格子。',
      statKey: 'totalCustomThemeSlots',
      threshold: 1,
      rewardCoins: 20,
      rewardTitleId: 'title_theme_tailor',
    ),
    AchievementDefinition(
      id: 'custom_theme_equipped_1',
      name: '这屋终于像我家了',
      unlockText: '第一次装备自定义主题。',
      statKey: 'totalCustomThemesEquipped',
      threshold: 1,
      rewardCoins: 20,
    ),
    AchievementDefinition(
      id: 'custom_theme_saved_3',
      name: '调色盘开始发烫',
      unlockText: '累计保存 3 次自定义主题。',
      statKey: 'totalCustomThemesSaved',
      threshold: 3,
      rewardCoins: 28,
    ),
    AchievementDefinition(
      id: 'custom_theme_edited_5',
      name: '改到像亲生的',
      unlockText: '累计编辑 5 次自定义主题。',
      statKey: 'totalCustomThemesEdited',
      threshold: 5,
      rewardCoins: 35,
    ),
    AchievementDefinition(
      id: 'full_cosmetic_set',
      name: '全身上下都是戏',
      unlockText: '同时装备非默认称号和非默认边框。',
      statKey: 'maxFullCosmeticSlots',
      threshold: 1,
      rewardCoins: 16,
      rewardTitleId: 'title_full_drip',
    ),
    AchievementDefinition(
      id: 'shop_10',
      name: '商店老板认识我',
      unlockText: '累计购买 10 次商店道具或装扮。',
      statKey: 'totalShopPurchases',
      threshold: 10,
      rewardCoins: 20,
      rewardTitleId: 'title_shop_regular',
    ),
    AchievementDefinition(
      id: 'daily_30',
      name: '来都来了',
      unlockText: '累计领取 30 次每日啥币。',
      statKey: 'totalDailyClaims',
      threshold: 30,
      rewardCoins: 40,
    ),
    AchievementDefinition(
      id: 'npc_letters_10',
      name: '低语收藏家',
      unlockText: '累计收到 10 封 NPC 主动来信。',
      statKey: 'totalNpcLetters',
      threshold: 10,
      rewardCoins: 22,
    ),
    AchievementDefinition(
      id: 'exports_5',
      name: '我宣布这段封神',
      unlockText: '累计导出 5 次聊天记录。',
      statKey: 'totalExports',
      threshold: 5,
      rewardCoins: 18,
    ),
    AchievementDefinition(
      id: 'tools_25',
      name: '工具箱住户',
      unlockText: '累计生成 25 条剧情工具或商店工具结果。',
      statKey: 'totalToolResults',
      threshold: 25,
      rewardCoins: 30,
    ),
    AchievementDefinition(
      id: 'items_used_20',
      name: '券不是券，是生活方式',
      unlockText: '累计使用 20 次背包功能券。',
      statKey: 'totalItemsUsed',
      threshold: 20,
      rewardCoins: 30,
    ),
    AchievementDefinition(
      id: 'achievements_10',
      name: '成就它自己成就了',
      unlockText: '累计解锁 10 个成就。',
      statKey: 'maxAchievements',
      threshold: 10,
      rewardCoins: 25,
    ),
    AchievementDefinition(
      id: 'messages_300',
      name: '嘴比剧情还长',
      unlockText: '累计发送 300 条消息。',
      statKey: 'totalUserMessages',
      threshold: 300,
      rewardCoins: 40,
    ),
    AchievementDefinition(
      id: 'replies_50',
      name: '回音壁包年用户',
      unlockText: '累计获得 50 条 AI 回复。',
      statKey: 'totalAssistantReplies',
      threshold: 50,
      rewardCoins: 35,
    ),
    AchievementDefinition(
      id: 'characters_5',
      name: '五口之家启动',
      unlockText: '累计创建 5 个 AI 角色。',
      statKey: 'totalCharactersCreated',
      threshold: 5,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'characters_20',
      name: '角色户口本爆页了',
      unlockText: '累计创建 20 个 AI 角色。',
      statKey: 'totalCharactersCreated',
      threshold: 20,
      rewardCoins: 35,
    ),
    AchievementDefinition(
      id: 'npc_10',
      name: 'NPC 开始排队进群',
      unlockText: '累计创建或识别 10 个 NPC。',
      statKey: 'totalNpcProfilesCreated',
      threshold: 10,
      rewardCoins: 22,
    ),
    AchievementDefinition(
      id: 'npc_reply_50',
      name: '小窗聊到发烫',
      unlockText: '累计完成 50 次 NPC 私聊回复。',
      statKey: 'totalNpcReplies',
      threshold: 50,
      rewardCoins: 40,
    ),
    AchievementDefinition(
      id: 'npc_letters_25',
      name: '信箱长出第二层',
      unlockText: '累计收到 25 封 NPC 主动来信。',
      statKey: 'totalNpcLetters',
      threshold: 25,
      rewardCoins: 38,
    ),
    AchievementDefinition(
      id: 'sim_prompt_5',
      name: '模拟器批发商',
      unlockText: '累计使用“AI 帮你写”生成 5 份模拟器提示词。',
      statKey: 'totalSimulatorPrompts',
      threshold: 5,
      rewardCoins: 25,
    ),
    AchievementDefinition(
      id: 'blind_box_5',
      name: '盲盒有点上头',
      unlockText: '累计使用创新版开盲盒 5 次。',
      statKey: 'totalBlindBoxes',
      threshold: 5,
      rewardCoins: 25,
    ),
    AchievementDefinition(
      id: 'classic_blind_box_5',
      name: '旧梦回收站站长',
      unlockText: '累计使用怀旧版开盲盒 5 次。',
      statKey: 'totalClassicBlindBoxes',
      threshold: 5,
      rewardCoins: 25,
    ),
    AchievementDefinition(
      id: 'theme_changes_10',
      name: '装修队常驻嘉宾',
      unlockText: '累计切换主题 10 次。',
      statKey: 'totalThemeChanges',
      threshold: 10,
      rewardCoins: 18,
    ),
    AchievementDefinition(
      id: 'theme_unlocks_3',
      name: '主题钱包受害者',
      unlockText: '累计解锁 3 个付费主题。',
      statKey: 'totalThemeUnlocks',
      threshold: 3,
      rewardCoins: 24,
    ),
    AchievementDefinition(
      id: 'theme_unlocks_6',
      name: '装修预算是什么，可以吃吗',
      unlockText: '累计解锁 6 个付费主题。',
      statKey: 'totalThemeUnlocks',
      threshold: 6,
      rewardCoins: 45,
    ),
    AchievementDefinition(
      id: 'mailbox_claims_10',
      name: '邮箱薅羊毛科代表',
      unlockText: '累计领取 10 次邮箱奖励。',
      statKey: 'totalMailboxClaims',
      threshold: 10,
      rewardCoins: 20,
    ),
    AchievementDefinition(
      id: 'daily_tasks_30',
      name: '每日任务打卡机器',
      unlockText: '累计完成并领取 30 次每日任务。',
      statKey: 'totalDailyTasksClaimed',
      threshold: 30,
      rewardCoins: 30,
    ),
    AchievementDefinition(
      id: 'achievements_30',
      name: '成就墙贴满了',
      unlockText: '累计解锁 30 个成就。',
      statKey: 'maxAchievements',
      threshold: 30,
      rewardCoins: 60,
    ),
    AchievementDefinition(
      id: 'achievements_60',
      name: '成就山登顶游客',
      unlockText: '累计解锁 60 个成就。',
      statKey: 'maxAchievements',
      threshold: 60,
      rewardCoins: 100,
      rewardTitleId: 'title_achievement_mountain',
    ),
    AchievementDefinition(
      id: 'roulette_first_spin',
      name: '转起来，别停',
      unlockText: '第一次玩“幸运转转转”。',
      statKey: 'totalRouletteSpins',
      threshold: 1,
      rewardCoins: 3,
    ),
    AchievementDefinition(
      id: 'roulette_10',
      name: '这不是上头，是热身',
      unlockText: '累计转盘 10 次。',
      statKey: 'totalRouletteSpins',
      threshold: 10,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'roulette_50',
      name: '保底是我的心理医生',
      unlockText: '累计转盘 50 次。',
      statKey: 'totalRouletteSpins',
      threshold: 50,
      rewardCoins: 35,
    ),
    AchievementDefinition(
      id: 'roulette_jackpot',
      name: '老板脸绿了',
      unlockText: '在幸运转转转里抽到 100 啥币大奖。',
      statKey: 'totalRouletteJackpots',
      threshold: 1,
      rewardCoins: 20,
    ),
    AchievementDefinition(
      id: 'black_market_1',
      name: '夜半小铺已开门',
      unlockText: '第一次在黑心小卖部买东西。',
      statKey: 'totalBlackMarketPurchases',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'black_market_10',
      name: '老板说你是熟人价',
      unlockText: '累计在黑心小卖部购买 10 次。',
      statKey: 'totalBlackMarketPurchases',
      threshold: 10,
      rewardCoins: 24,
    ),
    AchievementDefinition(
      id: 'debt_1',
      name: '先赊着，明天一定还',
      unlockText: '第一次向黑心小卖部赊账。',
      statKey: 'totalDebtTaken',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'identify_1',
      name: '这玩意儿真有用啊？',
      unlockText: '第一次鉴定未知道具。',
      statKey: 'totalItemsIdentified',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'synthesis_1',
      name: '炼金术士下岗再就业',
      unlockText: '第一次合成剧情道具。',
      statKey: 'totalItemsSynthesized',
      threshold: 1,
      rewardCoins: 10,
    ),
    AchievementDefinition(
      id: 'npc_gift_1',
      name: '他真的有在回礼',
      unlockText: '第一次收到 NPC 回礼。',
      statKey: 'totalNpcGiftsReceived',
      threshold: 1,
      rewardCoins: 10,
    ),
    AchievementDefinition(
      id: 'scene_card_1',
      name: '名场面管理员',
      unlockText: '第一次收藏道具触发的高光剧情。',
      statKey: 'totalSceneCardsCollected',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'fanfic_1',
      name: '同人文开张大吉',
      unlockText: '第一次生成同人文。',
      statKey: 'totalFanficResults',
      threshold: 1,
      rewardCoins: 12,
      rewardTitleId: 'title_fanfic_writer',
    ),
    AchievementDefinition(
      id: 'fanfic_5',
      name: '这对我先磕为敬',
      unlockText: '累计生成 5 篇同人文。',
      statKey: 'totalFanficResults',
      threshold: 5,
      rewardCoins: 30,
    ),
    AchievementDefinition(
      id: 'fanfic_20',
      name: '番外工厂夜班主管',
      unlockText: '累计生成 20 篇同人文。',
      statKey: 'totalFanficResults',
      threshold: 20,
      rewardCoins: 80,
    ),
    AchievementDefinition(
      id: 'fanfic_blind_box_1',
      name: '梗从天降接住了',
      unlockText: '第一次使用同人文灵感盲盒。',
      statKey: 'totalFanficBlindBoxes',
      threshold: 1,
      rewardCoins: 15,
      rewardTitleId: 'title_blind_box_author',
    ),
    AchievementDefinition(
      id: 'fanfic_user_npc_3',
      name: '我和 TA 的三行情诗变三千字',
      unlockText: '累计生成 3 篇用户 × NPC 同人文。',
      statKey: 'totalFanficUserNpc',
      threshold: 3,
      rewardCoins: 24,
    ),
    AchievementDefinition(
      id: 'fanfic_npc_npc_3',
      name: 'NPC 自己把门焊上了',
      unlockText: '累计生成 3 篇 NPC × NPC 同人文。',
      statKey: 'totalFanficNpcNpc',
      threshold: 3,
      rewardCoins: 24,
    ),
    AchievementDefinition(
      id: 'fanfic_long_3000',
      name: '三千字只是热身',
      unlockText: '单篇同人文长度达到 3000 字以上。',
      statKey: 'maxFanficLength',
      threshold: 3000,
      rewardCoins: 30,
    ),
    AchievementDefinition(
      id: 'save_snapshot_1',
      name: '先存档再作死',
      unlockText: '第一次创建本地存档快照。',
      statKey: 'totalSaveSnapshotsCreated',
      threshold: 1,
      rewardCoins: 12,
      rewardTitleId: 'title_archive_keeper',
    ),
    AchievementDefinition(
      id: 'save_snapshot_5',
      name: '命运备份狂',
      unlockText: '累计创建 5 个本地存档快照。',
      statKey: 'totalSaveSnapshotsCreated',
      threshold: 5,
      rewardCoins: 35,
    ),
    AchievementDefinition(
      id: 'save_restore_1',
      name: '撤回人生重开一局',
      unlockText: '第一次恢复本地存档快照。',
      statKey: 'totalSaveSnapshotsRestored',
      threshold: 1,
      rewardCoins: 15,
    ),
    AchievementDefinition(
      id: 'import_archive_1',
      name: '外来存档已抵达',
      unlockText: '第一次成功导入数据存档。',
      statKey: 'totalDataImports',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'data_cleaner_1',
      name: '本地清洁大师',
      unlockText: '第一次使用数据清理器完成清理。',
      statKey: 'totalDataCleanerRuns',
      threshold: 1,
      rewardCoins: 12,
      rewardTitleId: 'title_cleanup_master',
    ),
    AchievementDefinition(
      id: 'worldbook_1',
      name: '世界书第一页',
      unlockText: '第一次创建世界书条目。',
      statKey: 'totalWorldBooksCreated',
      threshold: 1,
      rewardCoins: 10,
    ),
    AchievementDefinition(
      id: 'worldbook_bulk_1',
      name: '世界书管理员',
      unlockText: '第一次批量绑定或批量设定世界书。',
      statKey: 'totalWorldBookBulkBinds',
      threshold: 1,
      rewardCoins: 18,
      rewardTitleId: 'title_worldbook_librarian',
    ),
    AchievementDefinition(
      id: 'npc_migration_1',
      name: '我带你走',
      unlockText: '第一次把 NPC 带离旧世界，生成独立角色。',
      statKey: 'totalNpcMigrations',
      threshold: 1,
      rewardCoins: 30,
      rewardTitleId: 'title_npc_migrator',
    ),
    AchievementDefinition(
      id: 'npc_migration_5',
      name: '舍不得就别舍得',
      unlockText: '累计带走 5 个 NPC。',
      statKey: 'totalNpcMigrations',
      threshold: 5,
      rewardCoins: 80,
    ),
    AchievementDefinition(
      id: 'npc_bond_40',
      name: '关系不是数字',
      unlockText: '任意 NPC 羁绊进度达到 40。',
      statKey: 'maxNpcBondScore',
      threshold: 40,
      rewardCoins: 20,
      rewardTitleId: 'title_bond_keeper',
    ),
    AchievementDefinition(
      id: 'npc_bond_80',
      name: '这次真的牵住了',
      unlockText: '任意 NPC 羁绊进度达到 80。',
      statKey: 'maxNpcBondScore',
      threshold: 80,
      rewardCoins: 60,
    ),
    AchievementDefinition(
      id: 'music_play_1',
      name: '剧场先来点声',
      unlockText: '第一次播放背景音乐。',
      statKey: 'totalMusicPlays',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'music_pause_1',
      name: '暂停也是一种态度',
      unlockText: '第一次暂停背景音乐。',
      statKey: 'totalMusicPauses',
      threshold: 1,
      rewardCoins: 5,
    ),
    AchievementDefinition(
      id: 'music_switch_1',
      name: '切歌比翻脸快',
      unlockText: '第一次切换背景音乐。',
      statKey: 'totalMusicSwitches',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'music_dropdown_1',
      name: '下拉列表很好使',
      unlockText: '第一次用下拉列表切歌。',
      statKey: 'totalMusicDropdownSwitches',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'music_card_1',
      name: '卡片滑得很熟练',
      unlockText: '第一次用滑动卡片切歌。',
      statKey: 'totalMusicCardSwitches',
      threshold: 1,
      rewardCoins: 8,
    ),
    AchievementDefinition(
      id: 'music_basic_6',
      name: '六色开场白',
      unlockText: '播放过六首基础主题曲。',
      statKey: 'maxBasicMusicPlayed',
      threshold: 6,
      rewardCoins: 18,
    ),
    AchievementDefinition(
      id: 'music_unlock_1',
      name: '这首我买了',
      unlockText: '第一次解锁付费背景音乐。',
      statKey: 'totalMusicUnlocks',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'music_unlock_3',
      name: '耳朵开始氪金',
      unlockText: '累计解锁 3 首付费背景音乐。',
      statKey: 'totalMusicUnlocks',
      threshold: 3,
      rewardCoins: 24,
    ),
    AchievementDefinition(
      id: 'music_unlock_8',
      name: '主题曲收藏家',
      unlockText: '累计解锁 8 首付费背景音乐。',
      statKey: 'totalMusicUnlocks',
      threshold: 8,
      rewardCoins: 45,
      rewardTitleId: 'title_theater_tuner',
    ),
    AchievementDefinition(
      id: 'music_unlock_all',
      name: '全曲库制霸',
      unlockText: '解锁全部背景音乐。',
      statKey: 'maxMusicTracksUnlocked',
      threshold: 14,
      rewardCoins: 80,
      rewardTitleId: 'title_pocket_record_cabinet',
    ),
    AchievementDefinition(
      id: 'music_playlist_add_1',
      name: '歌单开张',
      unlockText: '第一次把歌曲加入歌单。',
      statKey: 'totalMusicPlaylistAdds',
      threshold: 1,
      rewardCoins: 10,
    ),
    AchievementDefinition(
      id: 'music_playlist_remove_1',
      name: '这首先别唱',
      unlockText: '第一次从歌单删除歌曲。',
      statKey: 'totalMusicPlaylistRemoves',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'music_playlist_reorder_1',
      name: '顺序必须听我的',
      unlockText: '第一次拖动排序歌单。',
      statKey: 'totalMusicPlaylistReorders',
      threshold: 1,
      rewardCoins: 12,
    ),
    AchievementDefinition(
      id: 'music_playlist_5',
      name: '五首刚刚好',
      unlockText: '歌单内达到 5 首歌曲。',
      statKey: 'maxMusicPlaylistSize',
      threshold: 5,
      rewardCoins: 18,
    ),
    AchievementDefinition(
      id: 'music_playlist_10',
      name: '一整晚不用换',
      unlockText: '歌单内达到 10 首歌曲。',
      statKey: 'maxMusicPlaylistSize',
      threshold: 10,
      rewardCoins: 35,
    ),
    AchievementDefinition(
      id: 'music_playlist_full',
      name: '全塞进去再说',
      unlockText: '歌单内达到全部已解锁歌曲。',
      statKey: 'maxMusicPlaylistFull',
      threshold: 1,
      rewardCoins: 45,
    ),
    AchievementDefinition(
      id: 'music_loop_playlist',
      name: '循环开始了',
      unlockText: '第一次开启歌单循环。',
      statKey: 'totalMusicPlaylistLoops',
      threshold: 1,
      rewardCoins: 10,
    ),
    AchievementDefinition(
      id: 'music_loop_single',
      name: '单曲执念',
      unlockText: '第一次开启单曲循环。',
      statKey: 'totalMusicSingleLoops',
      threshold: 1,
      rewardCoins: 10,
    ),
    AchievementDefinition(
      id: 'music_playlist_round',
      name: '听完一轮才算数',
      unlockText: '完整播放一轮歌单。',
      statKey: 'totalMusicPlaylistRounds',
      threshold: 1,
      rewardCoins: 30,
    ),
    AchievementDefinition(
      id: 'music_minutes_30',
      name: '背景音常驻嘉宾',
      unlockText: '累计播放 30 分钟背景音乐。',
      statKey: 'totalMusicMinutes',
      threshold: 30,
      rewardCoins: 20,
    ),
    AchievementDefinition(
      id: 'music_minutes_120',
      name: '今天耳朵加班',
      unlockText: '累计播放 120 分钟背景音乐。',
      statKey: 'totalMusicMinutes',
      threshold: 120,
      rewardCoins: 45,
    ),
    AchievementDefinition(
      id: 'music_minutes_500',
      name: '剧场有自己的 BGM',
      unlockText: '累计播放 500 分钟背景音乐。',
      statKey: 'totalMusicMinutes',
      threshold: 500,
      rewardCoins: 100,
      rewardTitleId: 'title_resident_listener',
    ),
    AchievementDefinition(
      id: 'music_track_lavender',
      name: '紫雾落座',
      unlockText: '播放 ???? 1。',
      statKey: 'musicPlayed_lavender_mist',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'music_track_peach',
      name: '日落续杯',
      unlockText: '播放 ???? 2。',
      statKey: 'musicPlayed_peach_dusk',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'music_track_daybreak',
      name: '破晓调亮',
      unlockText: '播放 ???? 3。',
      statKey: 'musicPlayed_blue_dawn_haze',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'music_track_mint',
      name: '薄荷醒神',
      unlockText: '播放 ???? 4。',
      statKey: 'musicPlayed_sage_mint_breeze',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'music_track_moon_lemon',
      name: '月柠轻响',
      unlockText: '播放 ???? 5。',
      statKey: 'musicPlayed_moonlit_lemon_fog',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'music_track_forest',
      name: '晨露入场',
      unlockText: '播放 ???? 6。',
      statKey: 'musicPlayed_berry_dew_morning',
      threshold: 1,
      rewardCoins: 6,
    ),
    AchievementDefinition(
      id: 'music_track_abyss',
      name: '深渊开始低声说话',
      unlockText: '解锁并播放 ????。',
      statKey: 'musicPlayed_abyss_observatory',
      threshold: 1,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'music_track_rift',
      name: '裂隙准点发车',
      unlockText: '解锁并播放 ????。',
      statKey: 'musicPlayed_rift_transit',
      threshold: 1,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'music_track_flower',
      name: '纸上花影动了一下',
      unlockText: '解锁并播放 ????。',
      statKey: 'musicPlayed_not_flowers',
      threshold: 1,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'music_track_mechanical',
      name: '齿轮懂点节拍',
      unlockText: '解锁并播放 ????。',
      statKey: 'musicPlayed_clockwork_machinarium',
      threshold: 1,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'music_track_rain',
      name: '雨夜调频成功',
      unlockText: '解锁并播放 ????。',
      statKey: 'musicPlayed_rain_alley_radio',
      threshold: 1,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'music_track_pasture',
      name: '云朵也会哼歌',
      unlockText: '解锁并播放 ????。',
      statKey: 'musicPlayed_pasture_under_blue_skies',
      threshold: 1,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'music_track_vinyl',
      name: '唱针落下',
      unlockText: '解锁并播放 ????。',
      statKey: 'musicPlayed_vinyl_memories',
      threshold: 1,
      rewardCoins: 14,
    ),
    AchievementDefinition(
      id: 'hidden_npc_migration_memory',
      name: '旧世界的回音',
      unlockText: '带走 NPC 时保留旧世界记忆。',
      statKey: 'totalNpcMigrationsWithMemory',
      threshold: 1,
      rewardCoins: 35,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_roulette_all_titles',
      name: '转盘称号毕业生',
      unlockText: '集齐全部 5 个转盘限定称号。',
      statKey: 'maxRouletteTitlesOwned',
      threshold: 5,
      rewardCoins: 80,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_roulette_all_frames',
      name: '碎片拼成了钱包的形状',
      unlockText: '集齐全部 5 个转盘限定气泡碎片边框。',
      statKey: 'maxRouletteFramesOwned',
      threshold: 5,
      rewardCoins: 80,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_cthulhu_gaze_1',
      name: '祂刚刚眨眼了',
      unlockText: '首次触发克苏鲁凝视悬浮窗。',
      statKey: 'totalCthulhuGazes',
      threshold: 1,
      rewardCoins: 10,
      rewardTitleId: 'title_gaze_once',
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_cthulhu_gaze_5',
      name: '别回头',
      unlockText: '克苏鲁凝视悬浮窗累计出现 5 次。',
      statKey: 'totalCthulhuGazes',
      threshold: 5,
      rewardCoins: 18,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_cthulhu_gaze_15',
      name: '我说这不是幻觉',
      unlockText: '克苏鲁凝视悬浮窗累计出现 15 次。',
      statKey: 'totalCthulhuGazes',
      threshold: 15,
      rewardCoins: 30,
      rewardCosmeticId: 'frame_whisper_rift',
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_late_night',
      name: '夜深了还在写命运',
      unlockText: '凌晨时段发送消息。',
      statKey: 'totalLateNightMessages',
      threshold: 1,
      rewardCoins: 15,
      rewardTitleId: 'title_night_shift',
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_npc_unread_3',
      name: '怎么全都来找我',
      unlockText: '同时拥有 3 条及以上未读 NPC 来信。',
      statKey: 'maxNpcUnreadMessages',
      threshold: 3,
      rewardCoins: 25,
      rewardCosmeticId: 'frame_inbox_burst',
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_npc_reply_20',
      name: '这条线我追定了',
      unlockText: '累计完成 20 次 NPC 私聊回复。',
      statKey: 'totalNpcReplies',
      threshold: 20,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_mail_claim',
      name: '邮箱里真的有东西',
      unlockText: '首次领取邮箱奖励。',
      statKey: 'totalMailboxClaims',
      threshold: 1,
      rewardCoins: 12,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_multi_choice',
      name: '选项恐惧症晚期',
      unlockText: '一次输入里插入 3 个以上选项。',
      statKey: 'totalMultiChoiceInputs',
      threshold: 1,
      rewardCoins: 18,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_f_choice',
      name: '这把我要逆天改命',
      unlockText: '选择过 F 选项累计 5 次。',
      statKey: 'totalFChoiceInputs',
      threshold: 5,
      rewardCoins: 30,
      rewardTitleId: 'title_f_option',
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_shop_20',
      name: '买它不是因为需要',
      unlockText: '商店购买累计 20 次。',
      statKey: 'totalShopPurchases',
      threshold: 20,
      rewardCoins: 35,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_frame_10',
      name: '我全都要',
      unlockText: '解锁 10 个气泡边框。',
      statKey: 'maxFramesUnlocked',
      threshold: 10,
      rewardCoins: 50,
      rewardTitleId: 'title_frame_collector',
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_daily_3',
      name: '今天也被盯上了',
      unlockText: '累计领取每日福利 3 次。',
      statKey: 'totalDailyClaims',
      threshold: 3,
      rewardCoins: 20,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_fanfic_blind_box_10',
      name: '盲盒梗王已上线',
      unlockText: '同人文灵感盲盒累计使用 10 次。',
      statKey: 'totalFanficBlindBoxes',
      threshold: 10,
      rewardCoins: 60,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_fanfic_long_8000',
      name: '这不是番外，这是砖头',
      unlockText: '单篇同人文长度达到 8000 字以上。',
      statKey: 'maxFanficLength',
      threshold: 8000,
      rewardCoins: 80,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_theme_collector',
      name: '我忠实的信徒。',
      unlockText: '在深渊观测站主题下走遍全部主菜单。',
      statKey: 'cthulhuMenuMask',
      threshold: 31,
      rewardCoins: 100,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_fast_play',
      name: '嘴上说不听，手很诚实',
      unlockText: '打开音乐面板后 5 秒内点播放。',
      statKey: 'hiddenMusicFastPlay',
      threshold: 1,
      rewardCoins: 12,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_pause_resume',
      name: '关掉又打开，欲擒故纵',
      unlockText: '1 分钟内暂停又继续同一首歌。',
      statKey: 'hiddenMusicPauseResume',
      threshold: 1,
      rewardCoins: 12,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_rain_night',
      name: '夜雨正合适',
      unlockText: '深夜时段播放 ????。',
      statKey: 'hiddenMusicRainNight',
      threshold: 1,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_vinyl_theme',
      name: '黑胶要配黑胶',
      unlockText: '当前主题为黑胶往事时播放 ????。',
      statKey: 'hiddenMusicTheme_vinyl_memories',
      threshold: 1,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_abyss_theme',
      name: '深渊声卡已连接',
      unlockText: '当前主题为深渊观测站时播放 ????。',
      statKey: 'hiddenMusicTheme_cthulhu',
      threshold: 1,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_rift_theme',
      name: '裂隙信号满格',
      unlockText: '当前主题为裂隙中转站时播放 ????。',
      statKey: 'hiddenMusicTheme_rift_relay',
      threshold: 1,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_flower_theme',
      name: '花影落在歌单里',
      unlockText: '当前主题为花非花时播放 ????。',
      statKey: 'hiddenMusicTheme_flower_not_flower',
      threshold: 1,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_mechanical_theme',
      name: '齿轮没白转',
      unlockText: '当前主题为机械迷城时播放 ????。',
      statKey: 'hiddenMusicTheme_mechanical_city',
      threshold: 1,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_rain_theme',
      name: '今日频道有雨',
      unlockText: '当前主题为雨巷电台时播放 ????。',
      statKey: 'hiddenMusicTheme_rain_radio',
      threshold: 1,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_pasture_theme',
      name: '云层开了声',
      unlockText: '当前主题为晴空牧场时播放 ????。',
      statKey: 'hiddenMusicTheme_sky_pasture',
      threshold: 1,
      rewardCoins: 25,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_private_playlist',
      name: '这歌单有点私人',
      unlockText: '创建一个只包含 1 首歌的歌单并循环播放。',
      statKey: 'hiddenMusicPrivatePlaylist',
      threshold: 1,
      rewardCoins: 20,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_all_day',
      name: '我全都要听一遍',
      unlockText: '24 小时内播放过全部已解锁歌曲。',
      statKey: 'hiddenMusicAllUnlockedDay',
      threshold: 1,
      rewardCoins: 60,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_switch_30',
      name: '调音台被你摸热了',
      unlockText: '单日切歌 30 次。',
      statKey: 'musicSwitches',
      threshold: 30,
      rewardCoins: 35,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_quiet_fail',
      name: '安静五分钟失败',
      unlockText: '暂停后 5 分钟内再次播放。',
      statKey: 'hiddenMusicQuietFail',
      threshold: 1,
      rewardCoins: 15,
      hidden: true,
    ),
    AchievementDefinition(
      id: 'hidden_music_reply_background',
      name: '真正的后台演员',
      unlockText: '音乐播放时完成一次聊天回复。',
      statKey: 'hiddenMusicReplyBackground',
      threshold: 1,
      rewardCoins: 20,
      hidden: true,
    ),
  ];

  static ShopItemDefinition? shopItemById(String id) {
    for (final item in allShopItems) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  static ShopItemDefinition? shopItemByEffectId(String effectId) {
    for (final item in allShopItems) {
      if (item.effectId == effectId) {
        return item;
      }
    }
    return null;
  }

  static CosmeticDefinition? cosmeticById(String id) {
    for (final item in cosmetics) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}

const List<String> _defaultMusicTrackIds = <String>[
  'lavender_mist',
  'peach_dusk',
  'blue_dawn_haze',
  'sage_mint_breeze',
  'moonlit_lemon_fog',
  'berry_dew_morning',
];

const Set<String> _allMusicTrackIds = <String>{
  'lavender_mist',
  'peach_dusk',
  'blue_dawn_haze',
  'sage_mint_breeze',
  'moonlit_lemon_fog',
  'berry_dew_morning',
  'april_glitch_parade',
  'abyss_observatory',
  'rift_transit',
  'not_flowers',
  'clockwork_machinarium',
  'rain_alley_radio',
  'pasture_under_blue_skies',
  'vinyl_memories',
};

List<String> _normalizeMusicTrackIds(
  Iterable<String> ids, {
  required bool includeDefaults,
}) {
  final result = <String>[
    if (includeDefaults) ..._defaultMusicTrackIds,
  ];
  for (final raw in ids) {
    final clean = raw.trim();
    if (_allMusicTrackIds.contains(clean) && !result.contains(clean)) {
      result.add(clean);
    }
  }
  return result;
}

int _readInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, int> _readIntMap(dynamic value) {
  if (value is! Map) {
    return const <String, int>{};
  }
  final result = <String, int>{};
  for (final entry in value.entries) {
    final key = entry.key.toString();
    if (key.trim().isEmpty) {
      continue;
    }
    result[key] = _readInt(entry.value);
  }
  return result;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, String> _readStringMap(Map<dynamic, dynamic> value) {
  final result = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) {
      continue;
    }
    result[key] = entry.value.toString();
  }
  return result;
}

Map<String, CharacterAffinity> _readAffinityMap(Map<dynamic, dynamic> value) {
  final result = <String, CharacterAffinity>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    final raw = entry.value;
    if (key.isEmpty || raw is! Map) {
      continue;
    }
    result[key] = CharacterAffinity.fromJson(Map<String, dynamic>.from(raw));
  }
  return result;
}
