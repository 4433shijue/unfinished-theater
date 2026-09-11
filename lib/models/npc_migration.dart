class NpcMigrationMemoryMode {
  const NpcMigrationMemoryMode._();

  static const String full = 'full';
  static const String fragments = 'fragments';
  static const String echo = 'echo';

  static String normalize(String value) {
    return switch (value.trim()) {
      full => full,
      fragments => fragments,
      echo => echo,
      _ => full,
    };
  }

  static bool keepsOldWorldMemory(String value) {
    return normalize(value) != echo;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      fragments => '片段记得：只保留关键片段、梦感和情绪债。',
      echo => '熟悉感：不完整记得旧世界事实，只保留既视感和关系惯性。',
      _ => '完整记得：保留旧世界关键共同经历、印象和情绪债。',
    };
  }

  static String shortLabel(String value) {
    return switch (normalize(value)) {
      fragments => '片段记得',
      echo => '只留熟悉感',
      _ => '完整记得',
    };
  }
}

class NpcFarewellMode {
  const NpcFarewellMode._();

  static const String skip = 'skip';
  static const String aiScene = 'aiScene';
  static const String oneLine = 'oneLine';
  static const String userWritten = 'userWritten';

  static String normalize(String value) {
    return switch (value.trim()) {
      skip => skip,
      aiScene => aiScene,
      oneLine => oneLine,
      userWritten => userWritten,
      _ => skip,
    };
  }

  static String label(String value) {
    return switch (normalize(value)) {
      aiScene => '写一场告别',
      oneLine => '只留一句话',
      userWritten => '我自己写告别',
      _ => '不告别，直接续前缘',
    };
  }
}

class NpcMigrationRelationshipLock {
  const NpcMigrationRelationshipLock._();

  static const String followOldBond = 'followOldBond';
  static const String lover = 'lover';
  static const String bestFriend = 'bestFriend';
  static const String rival = 'rival';
  static const String accomplice = 'accomplice';
  static const String guardian = 'guardian';
  static const String mentor = 'mentor';
  static const String brokenMirror = 'brokenMirror';
  static const String noRomance = 'noRomance';
  static const String naturalChange = 'naturalChange';

  static const List<String> values = <String>[
    followOldBond,
    lover,
    bestFriend,
    rival,
    accomplice,
    guardian,
    mentor,
    brokenMirror,
    noRomance,
    naturalChange,
  ];

  static String normalize(String value) {
    final trimmed = value.trim();
    if (values.contains(trimmed)) {
      return trimmed;
    }
    return followOldBond;
  }

  static String label(String value, {String oldBond = ''}) {
    return switch (normalize(value)) {
      lover => '恋人线',
      bestFriend => '挚友线',
      rival => '宿敌线',
      accomplice => '共犯线',
      guardian => '守护线',
      mentor => '师徒线',
      brokenMirror => '破镜线',
      noRomance => '不要恋爱化',
      naturalChange => '允许自然变化',
      _ => oldBond.trim().isEmpty ? '跟随旧羁绊' : '跟随旧羁绊：${oldBond.trim()}',
    };
  }

  static String shortLabel(String value, {String oldBond = ''}) {
    final labelText = label(value, oldBond: oldBond);
    return labelText.replaceFirst('跟随旧羁绊：', '');
  }

  static String prompt(String value, {String oldBond = ''}) {
    final labelText = label(value, oldBond: oldBond);
    final extra = switch (normalize(value)) {
      noRomance => '禁止把互动写成暧昧、恋人、占有欲或亲密关系。',
      naturalChange => '可以缓慢发展，但不能一开局强行确认关系。',
      followOldBond => '优先尊重旧世界羁绊路线，不要强行改线。',
      _ => '所有任务、前尘回声、开场白都要服务这条关系路线。',
    };
    return '''
【关系路线锁】
用户选择的关系路线：$labelText

硬性要求：
- 后续新世界必须尊重该关系路线。
- $extra
- 不要替用户确认最终关系，关系推进必须留有可选择余地。
'''
        .trim();
  }
}

class NpcMigrationOutputKind {
  const NpcMigrationOutputKind._();

  static const String newWorld = 'newWorld';
  static const String worldBookOnly = 'worldBookOnly';
  static const String roleCardOnly = 'roleCardOnly';

  static const List<String> values = <String>[
    newWorld,
    worldBookOnly,
    roleCardOnly,
  ];

  static String normalize(
    String value, {
    String createdCharacterId = '',
    String sourceCharacterId = '',
  }) {
    final trimmed = value.trim();
    if (values.contains(trimmed)) {
      return trimmed;
    }
    final created = createdCharacterId.trim();
    if (created.isEmpty || created == sourceCharacterId.trim()) {
      return worldBookOnly;
    }
    return newWorld;
  }

  static bool createsCharacter(String value) => normalize(value) == newWorld;

  static String label(String value) {
    return switch (normalize(value)) {
      worldBookOnly => '只保存前尘世界书',
      roleCardOnly => '只整理可复用角色卡',
      _ => '续写你们的新世界',
    };
  }
}

class NpcMigrationArchiveData {
  const NpcMigrationArchiveData({
    this.summary = '',
    this.coreIdentity = '',
    this.appearance = '',
    this.personality = '',
    this.speechStyle = '',
    this.relationshipHistory = '',
    this.keyEvents = const <String>[],
    this.unresolvedThreads = const <String>[],
    this.continuityFacts = const <String>[],
    this.riskNotes = const <String>[],
  });

  factory NpcMigrationArchiveData.fromJson(Map<String, dynamic> json) {
    return NpcMigrationArchiveData(
      summary: json['summary']?.toString() ?? '',
      coreIdentity: json['coreIdentity']?.toString() ?? '',
      appearance: json['appearance']?.toString() ?? '',
      personality: json['personality']?.toString() ?? '',
      speechStyle: json['speechStyle']?.toString() ?? '',
      relationshipHistory: json['relationshipHistory']?.toString() ??
          json['relationship']?.toString() ??
          json['bondSummary']?.toString() ??
          '',
      keyEvents: _readStringList(
        json['keyEvents'] ?? json['oldWorldMemories'],
      ),
      unresolvedThreads: _readStringList(json['unresolvedThreads']),
      continuityFacts: _readStringList(json['continuityFacts']),
      riskNotes: _readStringList(json['riskNotes']),
    );
  }

  final String summary;
  final String coreIdentity;
  final String appearance;
  final String personality;
  final String speechStyle;
  final String relationshipHistory;
  final List<String> keyEvents;
  final List<String> unresolvedThreads;
  final List<String> continuityFacts;
  final List<String> riskNotes;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      coreIdentity.trim().isEmpty &&
      appearance.trim().isEmpty &&
      personality.trim().isEmpty &&
      speechStyle.trim().isEmpty &&
      relationshipHistory.trim().isEmpty &&
      keyEvents.isEmpty &&
      unresolvedThreads.isEmpty &&
      continuityFacts.isEmpty &&
      riskNotes.isEmpty;

  NpcMigrationArchiveData copyWith({
    String? summary,
    String? coreIdentity,
    String? appearance,
    String? personality,
    String? speechStyle,
    String? relationshipHistory,
    List<String>? keyEvents,
    List<String>? unresolvedThreads,
    List<String>? continuityFacts,
    List<String>? riskNotes,
  }) {
    return NpcMigrationArchiveData(
      summary: summary ?? this.summary,
      coreIdentity: coreIdentity ?? this.coreIdentity,
      appearance: appearance ?? this.appearance,
      personality: personality ?? this.personality,
      speechStyle: speechStyle ?? this.speechStyle,
      relationshipHistory: relationshipHistory ?? this.relationshipHistory,
      keyEvents: keyEvents ?? this.keyEvents,
      unresolvedThreads: unresolvedThreads ?? this.unresolvedThreads,
      continuityFacts: continuityFacts ?? this.continuityFacts,
      riskNotes: riskNotes ?? this.riskNotes,
    );
  }

  String toDisplayText() {
    final buffer = StringBuffer();
    void writeText(String title, String value) {
      if (value.trim().isEmpty) return;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('【$title】');
      buffer.writeln(value.trim());
    }

    void writeList(String title, List<String> values) {
      final clean = values.where((item) => item.trim().isNotEmpty).toList();
      if (clean.isEmpty) return;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('【$title】');
      for (final item in clean) {
        buffer.writeln('- ${item.trim()}');
      }
    }

    writeText('前尘概述', summary);
    writeText('核心身份', coreIdentity);
    writeText('外貌与辨识点', appearance);
    writeText('性格', personality);
    writeText('说话方式', speechStyle);
    writeText('关系沿革', relationshipHistory);
    writeList('关键事件', keyEvents);
    writeList('未完成的线', unresolvedThreads);
    writeList('必须保持一致的事实', continuityFacts);
    writeList('风险提示', riskNotes);
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'summary': summary,
      'coreIdentity': coreIdentity,
      'appearance': appearance,
      'personality': personality,
      'speechStyle': speechStyle,
      'relationshipHistory': relationshipHistory,
      'keyEvents': keyEvents,
      'unresolvedThreads': unresolvedThreads,
      'continuityFacts': continuityFacts,
      'riskNotes': riskNotes,
    };
  }
}

class NpcMigrationMemoryPolicy {
  const NpcMigrationMemoryPolicy({
    this.mode = NpcMigrationMemoryMode.full,
    this.runtimeFacts = const <String>[],
    this.echoSeeds = const <String>[],
    this.forbiddenRecall = const <String>[],
  });

  factory NpcMigrationMemoryPolicy.fromJson(Map<String, dynamic> json) {
    return NpcMigrationMemoryPolicy(
      mode: NpcMigrationMemoryMode.normalize(json['mode']?.toString() ?? ''),
      runtimeFacts: _readStringList(json['runtimeFacts']),
      echoSeeds: _readStringList(json['echoSeeds']),
      forbiddenRecall: _readStringList(json['forbiddenRecall']),
    );
  }

  final String mode;
  final List<String> runtimeFacts;
  final List<String> echoSeeds;
  final List<String> forbiddenRecall;

  NpcMigrationMemoryPolicy copyWith({
    String? mode,
    List<String>? runtimeFacts,
    List<String>? echoSeeds,
    List<String>? forbiddenRecall,
  }) {
    return NpcMigrationMemoryPolicy(
      mode: mode == null ? this.mode : NpcMigrationMemoryMode.normalize(mode),
      runtimeFacts: runtimeFacts ?? this.runtimeFacts,
      echoSeeds: echoSeeds ?? this.echoSeeds,
      forbiddenRecall: forbiddenRecall ?? this.forbiddenRecall,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': NpcMigrationMemoryMode.normalize(mode),
      'runtimeFacts': runtimeFacts,
      'echoSeeds': echoSeeds,
      'forbiddenRecall': forbiddenRecall,
    };
  }
}

class NpcMigrationRelationshipPlan {
  const NpcMigrationRelationshipPlan({
    this.mode = NpcMigrationRelationshipLock.followOldBond,
    this.startingState = '',
    this.hardConstraints = const <String>[],
    this.goals = const <String>[],
  });

  factory NpcMigrationRelationshipPlan.fromJson(Map<String, dynamic> json) {
    return NpcMigrationRelationshipPlan(
      mode: NpcMigrationRelationshipLock.normalize(
        json['mode']?.toString() ?? '',
      ),
      startingState: json['startingState']?.toString() ?? '',
      hardConstraints: _readStringList(json['hardConstraints']),
      goals: _readStringList(json['goals']),
    );
  }

  final String mode;
  final String startingState;
  final List<String> hardConstraints;
  final List<String> goals;

  NpcMigrationRelationshipPlan copyWith({
    String? mode,
    String? startingState,
    List<String>? hardConstraints,
    List<String>? goals,
  }) {
    return NpcMigrationRelationshipPlan(
      mode: mode == null
          ? this.mode
          : NpcMigrationRelationshipLock.normalize(mode),
      startingState: startingState ?? this.startingState,
      hardConstraints: hardConstraints ?? this.hardConstraints,
      goals: goals ?? this.goals,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': NpcMigrationRelationshipLock.normalize(mode),
      'startingState': startingState,
      'hardConstraints': hardConstraints,
      'goals': goals,
    };
  }
}

class NpcMigrationManifest {
  const NpcMigrationManifest({
    this.schemaVersion = 1,
    this.archive = const NpcMigrationArchiveData(),
    this.memoryPolicy = const NpcMigrationMemoryPolicy(),
    this.relationship = const NpcMigrationRelationshipPlan(),
    this.keepsake = const NpcMigrationKeepsake(),
    this.tasks = const <NpcMigrationTask>[],
    this.qualityWarnings = const <String>[],
  });

  factory NpcMigrationManifest.fromJson(Map<String, dynamic> json) {
    return NpcMigrationManifest(
      schemaVersion: _readInt(json['schemaVersion'], fallback: 1),
      archive: _readObject(
        json['archive'],
        NpcMigrationArchiveData.fromJson,
        const NpcMigrationArchiveData(),
      ),
      memoryPolicy: _readObject(
        json['memoryPolicy'],
        NpcMigrationMemoryPolicy.fromJson,
        const NpcMigrationMemoryPolicy(),
      ),
      relationship: _readObject(
        json['relationship'],
        NpcMigrationRelationshipPlan.fromJson,
        const NpcMigrationRelationshipPlan(),
      ),
      keepsake: _readObject(
        json['keepsake'],
        NpcMigrationKeepsake.fromJson,
        const NpcMigrationKeepsake(),
      ),
      tasks: _readObjectList(json['tasks'], NpcMigrationTask.fromJson),
      qualityWarnings: _readStringList(json['qualityWarnings']),
    );
  }

  factory NpcMigrationManifest.fromLegacy({
    required String archiveText,
    required String memoryMode,
    required String relationshipLock,
    required NpcMigrationKeepsake keepsake,
    required List<NpcMigrationTask> tasks,
  }) {
    return NpcMigrationManifest(
      archive: NpcMigrationArchiveData(summary: archiveText),
      memoryPolicy: NpcMigrationMemoryPolicy(mode: memoryMode),
      relationship: NpcMigrationRelationshipPlan(mode: relationshipLock),
      keepsake: keepsake,
      tasks: tasks,
      qualityWarnings: const <String>['旧档案已兼容载入，部分结构化字段可能为空。'],
    );
  }

  final int schemaVersion;
  final NpcMigrationArchiveData archive;
  final NpcMigrationMemoryPolicy memoryPolicy;
  final NpcMigrationRelationshipPlan relationship;
  final NpcMigrationKeepsake keepsake;
  final List<NpcMigrationTask> tasks;
  final List<String> qualityWarnings;

  NpcMigrationManifest copyWith({
    int? schemaVersion,
    NpcMigrationArchiveData? archive,
    NpcMigrationMemoryPolicy? memoryPolicy,
    NpcMigrationRelationshipPlan? relationship,
    NpcMigrationKeepsake? keepsake,
    List<NpcMigrationTask>? tasks,
    List<String>? qualityWarnings,
  }) {
    return NpcMigrationManifest(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      archive: archive ?? this.archive,
      memoryPolicy: memoryPolicy ?? this.memoryPolicy,
      relationship: relationship ?? this.relationship,
      keepsake: keepsake ?? this.keepsake,
      tasks: tasks ?? this.tasks,
      qualityWarnings: qualityWarnings ?? this.qualityWarnings,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'archive': archive.toJson(),
      'memoryPolicy': memoryPolicy.toJson(),
      'relationship': relationship.toJson(),
      'keepsake': keepsake.toJson(),
      'tasks': tasks.map((item) => item.toJson()).toList(),
      'qualityWarnings': qualityWarnings,
    };
  }
}

class NpcMigrationPreview {
  const NpcMigrationPreview({
    required this.id,
    required this.sourceCharacterId,
    required this.sourceCharacterName,
    required this.sourceNpcId,
    required this.sourceNpcName,
    required this.worldType,
    required this.inspiration,
    required this.narrativeVoice,
    required this.memoryMode,
    required this.outputKind,
    required this.generatedAt,
    required this.archiveText,
    required this.worldBookTitle,
    required this.worldBookContent,
    required this.characterName,
    required this.characterDescription,
    required this.characterPrompt,
    required this.hiddenPrompt,
    required this.openingMessage,
    required this.sourceDigest,
    required this.manifest,
    this.farewellOutcome = const NpcFarewellOutcome(),
    this.relationshipLock = NpcMigrationRelationshipLock.followOldBond,
    this.generateKeepsake = true,
    this.generateTasks = true,
    this.allowEcho = true,
    this.keepsake = const NpcMigrationKeepsake(),
    this.relationshipTasks = const <NpcMigrationTask>[],
  });

  final String id;
  final String sourceCharacterId;
  final String sourceCharacterName;
  final String sourceNpcId;
  final String sourceNpcName;
  final String worldType;
  final String inspiration;
  final String narrativeVoice;
  final String memoryMode;
  final String outputKind;
  final DateTime generatedAt;
  final String archiveText;
  final String worldBookTitle;
  final String worldBookContent;
  final String characterName;
  final String characterDescription;
  final String characterPrompt;
  final String hiddenPrompt;
  final String openingMessage;
  final String sourceDigest;
  final NpcMigrationManifest manifest;
  final NpcFarewellOutcome farewellOutcome;
  final String relationshipLock;
  final bool generateKeepsake;
  final bool generateTasks;
  final bool allowEcho;
  final NpcMigrationKeepsake keepsake;
  final List<NpcMigrationTask> relationshipTasks;

  NpcMigrationPreview copyWith({
    String? id,
    String? sourceCharacterId,
    String? sourceCharacterName,
    String? sourceNpcId,
    String? sourceNpcName,
    String? worldType,
    String? inspiration,
    String? narrativeVoice,
    String? memoryMode,
    String? outputKind,
    DateTime? generatedAt,
    String? archiveText,
    String? worldBookTitle,
    String? worldBookContent,
    String? characterName,
    String? characterDescription,
    String? characterPrompt,
    String? hiddenPrompt,
    String? openingMessage,
    String? sourceDigest,
    NpcMigrationManifest? manifest,
    NpcFarewellOutcome? farewellOutcome,
    String? relationshipLock,
    bool? generateKeepsake,
    bool? generateTasks,
    bool? allowEcho,
    NpcMigrationKeepsake? keepsake,
    List<NpcMigrationTask>? relationshipTasks,
  }) {
    return NpcMigrationPreview(
      id: id ?? this.id,
      sourceCharacterId: sourceCharacterId ?? this.sourceCharacterId,
      sourceCharacterName: sourceCharacterName ?? this.sourceCharacterName,
      sourceNpcId: sourceNpcId ?? this.sourceNpcId,
      sourceNpcName: sourceNpcName ?? this.sourceNpcName,
      worldType: worldType ?? this.worldType,
      inspiration: inspiration ?? this.inspiration,
      narrativeVoice: narrativeVoice ?? this.narrativeVoice,
      memoryMode: memoryMode ?? this.memoryMode,
      outputKind: outputKind ?? this.outputKind,
      generatedAt: generatedAt ?? this.generatedAt,
      archiveText: archiveText ?? this.archiveText,
      worldBookTitle: worldBookTitle ?? this.worldBookTitle,
      worldBookContent: worldBookContent ?? this.worldBookContent,
      characterName: characterName ?? this.characterName,
      characterDescription: characterDescription ?? this.characterDescription,
      characterPrompt: characterPrompt ?? this.characterPrompt,
      hiddenPrompt: hiddenPrompt ?? this.hiddenPrompt,
      openingMessage: openingMessage ?? this.openingMessage,
      sourceDigest: sourceDigest ?? this.sourceDigest,
      manifest: manifest ?? this.manifest,
      farewellOutcome: farewellOutcome ?? this.farewellOutcome,
      relationshipLock: relationshipLock ?? this.relationshipLock,
      generateKeepsake: generateKeepsake ?? this.generateKeepsake,
      generateTasks: generateTasks ?? this.generateTasks,
      allowEcho: allowEcho ?? this.allowEcho,
      keepsake: keepsake ?? this.keepsake,
      relationshipTasks: relationshipTasks ?? this.relationshipTasks,
    );
  }
}

class NpcMigrationBuildResult {
  const NpcMigrationBuildResult._({
    this.preview,
    this.error,
  });

  factory NpcMigrationBuildResult.success(NpcMigrationPreview preview) {
    return NpcMigrationBuildResult._(preview: preview);
  }

  factory NpcMigrationBuildResult.failure(String error) {
    return NpcMigrationBuildResult._(error: error);
  }

  final NpcMigrationPreview? preview;
  final String? error;

  bool get isSuccess => preview != null && error == null;
}

class NpcMigrationCommitResult {
  const NpcMigrationCommitResult({
    this.record,
    this.error,
  });

  final NpcMigrationRecord? record;
  final String? error;

  bool get isSuccess => record != null && error == null;
}

class NpcFarewellDraftResult {
  const NpcFarewellDraftResult({
    this.draft,
    this.error,
  });

  final NpcFarewellDraft? draft;
  final String? error;

  bool get isSuccess => draft != null && error == null;
}

class NpcFarewellOutcomeResult {
  const NpcFarewellOutcomeResult({
    this.outcome,
    this.error,
  });

  final NpcFarewellOutcome? outcome;
  final String? error;

  bool get isSuccess => outcome != null && error == null;
}

class NpcFarewellDraft {
  const NpcFarewellDraft({
    this.id = '',
    this.sourceCharacterId = '',
    this.npcId = '',
    this.title = '',
    this.narrative = '',
    this.htmlPanel = '',
    this.choices = const <NpcFarewellChoice>[],
    this.emotionalSummary = '',
    this.createdAt,
  });

  factory NpcFarewellDraft.fromJson(Map<String, dynamic> json) {
    return NpcFarewellDraft(
      id: json['id']?.toString() ?? '',
      sourceCharacterId: json['sourceCharacterId']?.toString() ?? '',
      npcId: json['npcId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      narrative: json['narrative']?.toString() ?? '',
      htmlPanel: json['htmlPanel']?.toString() ?? '',
      choices: _readObjectList(
        json['choices'],
        NpcFarewellChoice.fromJson,
      ),
      emotionalSummary: json['emotionalSummary']?.toString() ?? '',
      createdAt: _readDate(json['createdAt']),
    );
  }

  final String id;
  final String sourceCharacterId;
  final String npcId;
  final String title;
  final String narrative;
  final String htmlPanel;
  final List<NpcFarewellChoice> choices;
  final String emotionalSummary;
  final DateTime? createdAt;

  bool get isEmpty =>
      title.trim().isEmpty &&
      narrative.trim().isEmpty &&
      choices.isEmpty &&
      emotionalSummary.trim().isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceCharacterId': sourceCharacterId,
      'npcId': npcId,
      'title': title,
      'narrative': narrative,
      'htmlPanel': htmlPanel,
      'choices': choices.map((item) => item.toJson()).toList(),
      'emotionalSummary': emotionalSummary,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class NpcFarewellChoice {
  const NpcFarewellChoice({
    this.id = '',
    this.label = '',
    this.actionPrompt = '',
    this.emotionalTag = '',
  });

  factory NpcFarewellChoice.fromJson(Map<String, dynamic> json) {
    return NpcFarewellChoice(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      actionPrompt: json['actionPrompt']?.toString() ?? '',
      emotionalTag: json['emotionalTag']?.toString() ?? '',
    );
  }

  final String id;
  final String label;
  final String actionPrompt;
  final String emotionalTag;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'actionPrompt': actionPrompt,
      'emotionalTag': emotionalTag,
    };
  }
}

class NpcFarewellOutcome {
  const NpcFarewellOutcome({
    this.mode = NpcFarewellMode.skip,
    this.userFarewellText = '',
    this.selectedChoiceLabel = '',
    this.finalSceneSummary = '',
    this.relationshipAfterFarewell = '',
    this.continuityFacts = const <String>[],
    this.forbiddenChanges = const <String>[],
    this.emotionalKeywords = const <String>[],
  });

  factory NpcFarewellOutcome.fromJson(Map<String, dynamic> json) {
    return NpcFarewellOutcome(
      mode: NpcFarewellMode.normalize(json['mode']?.toString() ?? ''),
      userFarewellText: json['userFarewellText']?.toString() ?? '',
      selectedChoiceLabel: json['selectedChoiceLabel']?.toString() ?? '',
      finalSceneSummary: json['finalSceneSummary']?.toString() ?? '',
      relationshipAfterFarewell:
          json['relationshipAfterFarewell']?.toString() ?? '',
      continuityFacts: _readStringList(json['continuityFacts']),
      forbiddenChanges: _readStringList(json['forbiddenChanges']),
      emotionalKeywords: _readStringList(json['emotionalKeywords']),
    );
  }

  final String mode;
  final String userFarewellText;
  final String selectedChoiceLabel;
  final String finalSceneSummary;
  final String relationshipAfterFarewell;
  final List<String> continuityFacts;
  final List<String> forbiddenChanges;
  final List<String> emotionalKeywords;

  bool get hasFarewell =>
      NpcFarewellMode.normalize(mode) != NpcFarewellMode.skip;

  bool get isEmpty =>
      !hasFarewell &&
      userFarewellText.trim().isEmpty &&
      finalSceneSummary.trim().isEmpty &&
      relationshipAfterFarewell.trim().isEmpty &&
      continuityFacts.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': NpcFarewellMode.normalize(mode),
      'userFarewellText': userFarewellText,
      'selectedChoiceLabel': selectedChoiceLabel,
      'finalSceneSummary': finalSceneSummary,
      'relationshipAfterFarewell': relationshipAfterFarewell,
      'continuityFacts': continuityFacts,
      'forbiddenChanges': forbiddenChanges,
      'emotionalKeywords': emotionalKeywords,
    };
  }
}

class NpcMigrationKeepsake {
  const NpcMigrationKeepsake({
    this.name = '',
    this.description = '',
    this.origin = '',
    this.emotionalMeaning = '',
    this.useEffectPrompt = '',
  });

  factory NpcMigrationKeepsake.fromJson(Map<String, dynamic> json) {
    return NpcMigrationKeepsake(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      emotionalMeaning: json['emotionalMeaning']?.toString() ?? '',
      useEffectPrompt: json['useEffectPrompt']?.toString() ?? '',
    );
  }

  final String name;
  final String description;
  final String origin;
  final String emotionalMeaning;
  final String useEffectPrompt;

  bool get isEmpty =>
      name.trim().isEmpty &&
      description.trim().isEmpty &&
      origin.trim().isEmpty &&
      emotionalMeaning.trim().isEmpty &&
      useEffectPrompt.trim().isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'origin': origin,
      'emotionalMeaning': emotionalMeaning,
      'useEffectPrompt': useEffectPrompt,
    };
  }
}

class NpcMigrationTask {
  const NpcMigrationTask({
    this.id = '',
    this.title = '',
    this.description = '',
    this.stage = '',
    this.completed = false,
  });

  factory NpcMigrationTask.fromJson(Map<String, dynamic> json) {
    return NpcMigrationTask(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      completed: json['completed'] == true,
    );
  }

  final String id;
  final String title;
  final String description;
  final String stage;
  final bool completed;

  NpcMigrationTask copyWith({
    String? id,
    String? title,
    String? description,
    String? stage,
    bool? completed,
  }) {
    return NpcMigrationTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      stage: stage ?? this.stage,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'stage': stage,
      'completed': completed,
    };
  }
}

class NpcMigrationEchoStatus {
  const NpcMigrationEchoStatus._();

  static const String pending = 'pending';
  static const String completed = 'completed';
  static const String failed = 'failed';

  static String normalize(String value) {
    return switch (value.trim()) {
      pending => pending,
      failed => failed,
      _ => completed,
    };
  }

  static String label(String value) {
    return switch (normalize(value)) {
      pending => '生成中',
      failed => '生成失败',
      _ => '已完成',
    };
  }
}

class NpcMigrationEchoEvent {
  const NpcMigrationEchoEvent({
    this.id = '',
    this.echoType = '',
    this.summary = '',
    this.directive = '',
    this.status = NpcMigrationEchoStatus.completed,
    this.errorMessage = '',
    this.createdAt,
  });

  factory NpcMigrationEchoEvent.fromJson(Map<String, dynamic> json) {
    return NpcMigrationEchoEvent(
      id: json['id']?.toString() ?? '',
      echoType: json['echoType']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      directive: json['directive']?.toString() ?? '',
      status: NpcMigrationEchoStatus.normalize(
        json['status']?.toString() ?? '',
      ),
      errorMessage: json['errorMessage']?.toString() ?? '',
      createdAt: _readDate(json['createdAt']),
    );
  }

  final String id;
  final String echoType;
  final String summary;
  final String directive;
  final String status;
  final String errorMessage;
  final DateTime? createdAt;

  NpcMigrationEchoEvent copyWith({
    String? id,
    String? echoType,
    String? summary,
    String? directive,
    String? status,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return NpcMigrationEchoEvent(
      id: id ?? this.id,
      echoType: echoType ?? this.echoType,
      summary: summary ?? this.summary,
      directive: directive ?? this.directive,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'echoType': echoType,
      'summary': summary,
      'directive': directive,
      'status': NpcMigrationEchoStatus.normalize(status),
      'errorMessage': errorMessage,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class NpcMigrationAlbumEntry {
  const NpcMigrationAlbumEntry({
    this.id = '',
    this.title = '',
    this.content = '',
    this.sourceType = '',
    this.note = '',
    this.createdAt,
  });

  factory NpcMigrationAlbumEntry.fromJson(Map<String, dynamic> json) {
    return NpcMigrationAlbumEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      sourceType: json['sourceType']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdAt: _readDate(json['createdAt']),
    );
  }

  final String id;
  final String title;
  final String content;
  final String sourceType;
  final String note;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'sourceType': sourceType,
      'note': note,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class NpcMigrationRevisionEntry {
  const NpcMigrationRevisionEntry({
    this.id = '',
    this.section = '',
    this.oldContent = '',
    this.newContent = '',
    this.instruction = '',
    this.createdAt,
  });

  factory NpcMigrationRevisionEntry.fromJson(Map<String, dynamic> json) {
    return NpcMigrationRevisionEntry(
      id: json['id']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      oldContent: json['oldContent']?.toString() ?? '',
      newContent: json['newContent']?.toString() ?? '',
      instruction: json['instruction']?.toString() ?? '',
      createdAt: _readDate(json['createdAt']),
    );
  }

  final String id;
  final String section;
  final String oldContent;
  final String newContent;
  final String instruction;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'section': section,
      'oldContent': oldContent,
      'newContent': newContent,
      'instruction': instruction,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class NpcMigrationRecord {
  NpcMigrationRecord({
    String? id,
    required this.sourceCharacterId,
    required this.sourceCharacterName,
    required this.sourceNpcId,
    required this.sourceNpcName,
    required this.createdCharacterId,
    required this.createdCharacterName,
    required this.worldBookId,
    required this.worldBookTitle,
    required this.worldType,
    required this.inspiration,
    required this.narrativeVoice,
    required this.memoryMode,
    required this.archiveText,
    required this.worldBookContent,
    required this.characterPrompt,
    required this.openingMessage,
    required this.characterDescription,
    required this.sourceDigest,
    this.outputKind = NpcMigrationOutputKind.newWorld,
    this.manifest = const NpcMigrationManifest(),
    this.farewellOutcome = const NpcFarewellOutcome(),
    this.relationshipLock = NpcMigrationRelationshipLock.followOldBond,
    this.keepsake = const NpcMigrationKeepsake(),
    this.relationshipTasks = const <NpcMigrationTask>[],
    this.echoEvents = const <NpcMigrationEchoEvent>[],
    this.albumEntries = const <NpcMigrationAlbumEntry>[],
    this.revisionHistory = const <NpcMigrationRevisionEntry>[],
    this.parentMigrationId,
    this.allowEcho = true,
    DateTime? createdAt,
  })  : id = id ?? '',
        createdAt = createdAt ?? DateTime.now();

  factory NpcMigrationRecord.fromJson(Map<String, dynamic> json) {
    final manifest = _readMigrationManifest(json);
    return NpcMigrationRecord(
      id: json['id']?.toString(),
      sourceCharacterId: json['sourceCharacterId']?.toString() ?? '',
      sourceCharacterName: json['sourceCharacterName']?.toString() ?? '',
      sourceNpcId: json['sourceNpcId']?.toString() ?? '',
      sourceNpcName: json['sourceNpcName']?.toString() ?? '',
      createdCharacterId: json['createdCharacterId']?.toString() ?? '',
      createdCharacterName: json['createdCharacterName']?.toString() ?? '',
      worldBookId: json['worldBookId']?.toString() ?? '',
      worldBookTitle: json['worldBookTitle']?.toString() ?? '',
      worldType: json['worldType']?.toString() ?? '',
      inspiration: json['inspiration']?.toString() ?? '',
      narrativeVoice: json['narrativeVoice']?.toString() ?? 'second',
      memoryMode: manifest.memoryPolicy.mode,
      archiveText: (json['archiveText']?.toString().trim().isNotEmpty ?? false)
          ? json['archiveText'].toString()
          : manifest.archive.toDisplayText(),
      worldBookContent: json['worldBookContent']?.toString() ?? '',
      characterPrompt: json['characterPrompt']?.toString() ?? '',
      openingMessage: json['openingMessage']?.toString() ?? '',
      characterDescription: json['characterDescription']?.toString() ?? '',
      sourceDigest: json['sourceDigest']?.toString() ?? '',
      outputKind: NpcMigrationOutputKind.normalize(
        json['outputKind']?.toString() ?? '',
        createdCharacterId: json['createdCharacterId']?.toString() ?? '',
        sourceCharacterId: json['sourceCharacterId']?.toString() ?? '',
      ),
      manifest: manifest,
      farewellOutcome: _readObject(
        json['farewellOutcome'],
        NpcFarewellOutcome.fromJson,
        const NpcFarewellOutcome(),
      ),
      relationshipLock: manifest.relationship.mode,
      keepsake: manifest.keepsake,
      relationshipTasks: manifest.tasks,
      echoEvents: _readObjectList(
        json['echoEvents'],
        NpcMigrationEchoEvent.fromJson,
      ),
      albumEntries: _readObjectList(
        json['albumEntries'],
        NpcMigrationAlbumEntry.fromJson,
      ),
      revisionHistory: _readObjectList(
        json['revisionHistory'],
        NpcMigrationRevisionEntry.fromJson,
      ),
      parentMigrationId: json['parentMigrationId']?.toString(),
      allowEcho: json['allowEcho'] != false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String sourceCharacterId;
  final String sourceCharacterName;
  final String sourceNpcId;
  final String sourceNpcName;
  final String createdCharacterId;
  final String createdCharacterName;
  final String worldBookId;
  final String worldBookTitle;
  final String worldType;
  final String inspiration;
  final String narrativeVoice;
  final String memoryMode;
  final String archiveText;
  final String worldBookContent;
  final String characterPrompt;
  final String openingMessage;
  final String characterDescription;
  final String sourceDigest;
  final String outputKind;
  final NpcMigrationManifest manifest;
  final NpcFarewellOutcome farewellOutcome;
  final String relationshipLock;
  final NpcMigrationKeepsake keepsake;
  final List<NpcMigrationTask> relationshipTasks;
  final List<NpcMigrationEchoEvent> echoEvents;
  final List<NpcMigrationAlbumEntry> albumEntries;
  final List<NpcMigrationRevisionEntry> revisionHistory;
  final String? parentMigrationId;
  final bool allowEcho;
  final DateTime createdAt;

  bool get createsCharacter =>
      NpcMigrationOutputKind.createsCharacter(outputKind) &&
      createdCharacterId.trim().isNotEmpty;

  String get branchTitle {
    final parts = <String>[
      NpcMigrationOutputKind.label(outputKind),
      if (outputKind == NpcMigrationOutputKind.newWorld)
        worldType.trim().isEmpty ? '新世界' : worldType.trim(),
      NpcMigrationMemoryMode.shortLabel(memoryMode),
      NpcMigrationRelationshipLock.shortLabel(relationshipLock),
    ].where((item) => item.trim().isNotEmpty);
    return parts.join(' · ');
  }

  NpcMigrationRecord copyWith({
    String? id,
    String? sourceCharacterId,
    String? sourceCharacterName,
    String? sourceNpcId,
    String? sourceNpcName,
    String? createdCharacterId,
    String? createdCharacterName,
    String? worldBookId,
    String? worldBookTitle,
    String? worldType,
    String? inspiration,
    String? narrativeVoice,
    String? memoryMode,
    String? archiveText,
    String? worldBookContent,
    String? characterPrompt,
    String? openingMessage,
    String? characterDescription,
    String? sourceDigest,
    String? outputKind,
    NpcMigrationManifest? manifest,
    NpcFarewellOutcome? farewellOutcome,
    String? relationshipLock,
    NpcMigrationKeepsake? keepsake,
    List<NpcMigrationTask>? relationshipTasks,
    List<NpcMigrationEchoEvent>? echoEvents,
    List<NpcMigrationAlbumEntry>? albumEntries,
    List<NpcMigrationRevisionEntry>? revisionHistory,
    String? parentMigrationId,
    bool? allowEcho,
    DateTime? createdAt,
  }) {
    return NpcMigrationRecord(
      id: id ?? this.id,
      sourceCharacterId: sourceCharacterId ?? this.sourceCharacterId,
      sourceCharacterName: sourceCharacterName ?? this.sourceCharacterName,
      sourceNpcId: sourceNpcId ?? this.sourceNpcId,
      sourceNpcName: sourceNpcName ?? this.sourceNpcName,
      createdCharacterId: createdCharacterId ?? this.createdCharacterId,
      createdCharacterName: createdCharacterName ?? this.createdCharacterName,
      worldBookId: worldBookId ?? this.worldBookId,
      worldBookTitle: worldBookTitle ?? this.worldBookTitle,
      worldType: worldType ?? this.worldType,
      inspiration: inspiration ?? this.inspiration,
      narrativeVoice: narrativeVoice ?? this.narrativeVoice,
      memoryMode: memoryMode ?? this.memoryMode,
      archiveText: archiveText ?? this.archiveText,
      worldBookContent: worldBookContent ?? this.worldBookContent,
      characterPrompt: characterPrompt ?? this.characterPrompt,
      openingMessage: openingMessage ?? this.openingMessage,
      characterDescription: characterDescription ?? this.characterDescription,
      sourceDigest: sourceDigest ?? this.sourceDigest,
      outputKind: outputKind ?? this.outputKind,
      manifest: manifest ?? this.manifest,
      farewellOutcome: farewellOutcome ?? this.farewellOutcome,
      relationshipLock: relationshipLock ?? this.relationshipLock,
      keepsake: keepsake ?? this.keepsake,
      relationshipTasks: relationshipTasks ?? this.relationshipTasks,
      echoEvents: echoEvents ?? this.echoEvents,
      albumEntries: albumEntries ?? this.albumEntries,
      revisionHistory: revisionHistory ?? this.revisionHistory,
      parentMigrationId: parentMigrationId ?? this.parentMigrationId,
      allowEcho: allowEcho ?? this.allowEcho,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceCharacterId': sourceCharacterId,
      'sourceCharacterName': sourceCharacterName,
      'sourceNpcId': sourceNpcId,
      'sourceNpcName': sourceNpcName,
      'createdCharacterId': createdCharacterId,
      'createdCharacterName': createdCharacterName,
      'worldBookId': worldBookId,
      'worldBookTitle': worldBookTitle,
      'worldType': worldType,
      'inspiration': inspiration,
      'narrativeVoice': narrativeVoice,
      'memoryMode': memoryMode,
      'archiveText': archiveText,
      'worldBookContent': worldBookContent,
      'characterPrompt': characterPrompt,
      'openingMessage': openingMessage,
      'characterDescription': characterDescription,
      'sourceDigest': sourceDigest,
      'outputKind': NpcMigrationOutputKind.normalize(outputKind),
      'manifest': manifest.toJson(),
      'farewellOutcome': farewellOutcome.toJson(),
      'relationshipLock': relationshipLock,
      'keepsake': keepsake.toJson(),
      'relationshipTasks':
          relationshipTasks.map((item) => item.toJson()).toList(),
      'echoEvents': echoEvents.map((item) => item.toJson()).toList(),
      'albumEntries': albumEntries.map((item) => item.toJson()).toList(),
      'revisionHistory': revisionHistory.map((item) => item.toJson()).toList(),
      'parentMigrationId': parentMigrationId,
      'allowEcho': allowEcho,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

NpcMigrationManifest _readMigrationManifest(Map<String, dynamic> json) {
  final raw = json['manifest'];
  if (raw is Map) {
    final manifest = NpcMigrationManifest.fromJson(
      Map<String, dynamic>.from(raw),
    );
    if (!manifest.archive.isEmpty) {
      return manifest;
    }
  }
  return NpcMigrationManifest.fromLegacy(
    archiveText: json['archiveText']?.toString() ?? '',
    memoryMode: json['memoryMode']?.toString() ?? '',
    relationshipLock: json['relationshipLock']?.toString() ?? '',
    keepsake: _readObject(
      json['keepsake'],
      NpcMigrationKeepsake.fromJson,
      const NpcMigrationKeepsake(),
    ),
    tasks: _readObjectList(
      json['relationshipTasks'],
      NpcMigrationTask.fromJson,
    ),
  );
}

int _readInt(dynamic value, {required int fallback}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return const <String>[];
  }
  return text
      .split(RegExp(r'[\n；;]+'))
      .map((item) => item.replaceFirst(RegExp(r'^[-*•\d.、\s]+'), '').trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

T _readObject<T>(
  dynamic value,
  T Function(Map<String, dynamic>) reader,
  T fallback,
) {
  if (value is Map) {
    return reader(Map<String, dynamic>.from(value));
  }
  return fallback;
}

List<T> _readObjectList<T>(
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

DateTime? _readDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '');
}
