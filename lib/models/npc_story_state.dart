class NpcStoryState {
  const NpcStoryState(
      {this.publicIdentity = '',
      this.trueIdentity = '',
      this.personality = '',
      this.secret = '',
      this.secretRevealed = false,
      this.appeared = true,
      this.faction = '',
      this.goal = '',
      this.stance = '',
      this.affinityReason = '',
      this.aliases = const [],
      this.changes = const [],
      this.relations = const [],
      this.pendingEvents = const [],
      this.goalProgress = '',
      this.lastRoutineTurn = ''});
  factory NpcStoryState.fromJson(Map<String, dynamic> j) => NpcStoryState(
      publicIdentity: '${j['publicIdentity'] ?? ''}',
      trueIdentity: '${j['trueIdentity'] ?? ''}',
      personality: '${j['personality'] ?? ''}',
      secret: '${j['secret'] ?? ''}',
      secretRevealed: j['secretRevealed'] == true,
      appeared: j['appeared'] != false,
      faction: '${j['faction'] ?? ''}',
      goal: '${j['goal'] ?? ''}',
      stance: '${j['stance'] ?? ''}',
      affinityReason: '${j['affinityReason'] ?? ''}',
      lastRoutineTurn: '${j['lastRoutineTurn'] ?? ''}',
      aliases: (j['aliases'] is List ? j['aliases'] as List : const [])
          .whereType<String>()
          .toList(),
      changes: maps(j['changes']),
      relations: maps(j['relations']),
      pendingEvents: maps(j['pendingEvents']),
      goalProgress: '${j['goalProgress'] ?? ''}');
  static List<Map<String, dynamic>> maps(dynamic value) =>
      (value is List ? value : const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
  final String publicIdentity,
      trueIdentity,
      personality,
      secret,
      faction,
      goal,
      stance,
      affinityReason,
      lastRoutineTurn,
      goalProgress;
  final bool secretRevealed, appeared;
  final List<String> aliases;
  final List<Map<String, dynamic>> changes, relations, pendingEvents;
  Map<String, dynamic> toJson() => {
        'publicIdentity': publicIdentity,
        'trueIdentity': trueIdentity,
        'personality': personality,
        'secret': secret,
        'secretRevealed': secretRevealed,
        'appeared': appeared,
        'faction': faction,
        'goal': goal,
        'stance': stance,
        'affinityReason': affinityReason,
        'aliases': aliases,
        'changes': changes,
        'pendingEvents': pendingEvents,
        'goalProgress': goalProgress,
        'relations': relations,
        'lastRoutineTurn': lastRoutineTurn
      };
  NpcStoryState patch(Map<String, dynamic> update) =>
      NpcStoryState.fromJson({...toJson(), ...update});
  Map<String, dynamic> get publicData => {
        '身份': publicIdentity,
        '性格': personality,
        '立场': stance,
        if (secretRevealed) '已揭露秘密': secret,
        '关系': relations.where((r) => r['public'] == true).toList(),
        '变化': changes.where((r) => r['public'] == true).toList()
      };
}
