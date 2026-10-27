import 'dart:convert';

import 'npc_profile.dart';

Map<String, dynamic> storyMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> storyMaps(dynamic value) => value is List
    ? value.whereType<Map>().map(storyMap).toList()
    : <Map<String, dynamic>>[];
List<String> storyStrings(dynamic value) => value is List
    ? value.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
    : <String>[];
int storyInt(dynamic value) => value is num ? value.toInt() : 0;

/// Canonical state is scoped to one world (a branch is a separate world).
/// JSON records retain source IDs and event positions, including old revisions.
class StoryContinuityState {
  StoryContinuityState({required this.characterId, Map<String, dynamic>? data})
      : data = data == null
            ? <String, dynamic>{}
            : storyMap(jsonDecode(jsonEncode(data)));

  factory StoryContinuityState.fromJson(Map<String, dynamic> json) =>
      StoryContinuityState(
          characterId: json['characterId']?.toString() ?? '', data: json);

  final String characterId;
  final Map<String, dynamic> data;
  int get sequence => storyInt(data['sequence']);
  List<Map<String, dynamic>> get facts => storyMaps(data['facts']);
  List<Map<String, dynamic>> get conflicts => storyMaps(data['conflicts']);
  List<Map<String, dynamic>> get knowledge => storyMaps(data['knowledge']);
  List<Map<String, dynamic>> get events => storyMaps(data['events']);
  List<Map<String, dynamic>> get chapters => storyMaps(data['chapters']);
  Map<String, dynamic> get scene => storyMap(data['scene']);
  Map<String, dynamic> get directors => storyMap(data['directors']);
  Map<String, dynamic> get reading => storyMap(data['reading']);
  Map<String, dynamic> get revisions => storyMap(data['revisions']);
  Map<String, dynamic> get npcWorlds => storyMap(data['npcWorlds']);
  Map<String, dynamic> get checkpoints => storyMap(data['checkpoints']);
  List<Map<String, dynamic>> get activeFacts => facts
      .where((fact) => fact['retired'] != true && fact['needsReview'] != true)
      .toList();

  StoryContinuityState copy() => StoryContinuityState.fromJson(toJson());
  Map<String, dynamic> toJson() =>
      <String, dynamic>{...data, 'characterId': characterId};
  Map<String, dynamic> snapshot() => <String, dynamic>{...toJson()}
    ..remove('checkpoints')
    ..remove('reading');

  StoryContinuityState atCheckpoint(String eventId, String newWorldId) {
    final checkpoint = storyMap(checkpoints[eventId]);
    final before = storyMap(checkpoint['before']);
    if (before.isEmpty) throw StateError('这段旧剧情没有可靠的回合前快照。');
    final restored =
        StoryContinuityState(characterId: newWorldId, data: before);
    restored.data['checkpoints'] = {
      for (final entry in checkpoints.entries)
        if (storyInt(storyMap(entry.value)['sequence']) <
            storyInt(checkpoint['sequence']))
          entry.key: entry.value,
    };
    return restored;
  }
}

class NpcWorldState {
  NpcWorldState(
      {required this.profile,
      required this.messages,
      this.legacyBaseline = false});
  factory NpcWorldState.fromJson(Map<String, dynamic> json) => NpcWorldState(
        profile: storyMap(json['profile']),
        messages:
            storyMaps(json['messages']).map(NpcChatMessage.fromJson).toList(),
        legacyBaseline: json['legacyBaseline'] == true,
      );
  final Map<String, dynamic> profile;
  final List<NpcChatMessage> messages;
  final bool legacyBaseline;

  NpcProfile project(NpcProfile identity) {
    final values = <String, dynamic>{...identity.toJson()};
    for (final key in runtimeKeys) {
      if (profile.containsKey(key)) values[key] = profile[key];
    }
    return NpcProfile.fromJson(values);
  }

  Map<String, dynamic> toJson() => {
        'profile': {
          for (final key in runtimeKeys)
            if (profile.containsKey(key)) key: profile[key]
        },
        'messages': messages.map((m) => m.toJson()).toList(),
        'legacyBaseline': legacyBaseline,
      };
  static const runtimeKeys = <String>[
    'storyState',
    'name',
    'description',
    'affinity',
    'impression',
    'lifecycle',
    'impressionHistory',
    'bondRoute',
    'giftHistory',
    'runtimeState',
    'npcMemory',
    'relationshipEdges',
    'worldEvents',
  ];
}

enum StoryRewriteMode { polish, plot }

class StoryRewriteTarget {
  const StoryRewriteTarget(
      {required this.messageId,
      required this.content,
      required this.start,
      required this.end,
      this.npcId,
      this.groupIndex});
  final String messageId;
  final String content;
  final int start;
  final int end;
  final String? npcId;
  final int? groupIndex;
  String get selectedText => content.substring(start, end);
}

class StoryRewritePreview {
  const StoryRewritePreview(
      {required this.worldId,
      required this.target,
      required this.replacement,
      required this.mode,
      required this.originalContent,
      required this.nextContent,
      required this.requiresBranch,
      required this.reason,
      this.settlement = const {},
      this.continuityPatch = const {}});
  final String worldId;
  final StoryRewriteTarget target;
  final String replacement;
  final StoryRewriteMode mode;
  final String originalContent;
  final String nextContent;
  final bool requiresBranch;
  final String reason;
  final Map<String, dynamic> settlement;
  final Map<String, dynamic> continuityPatch;
}

/// Visibility defaults to backstage for legacy author material.
class StoryVisibility {
  const StoryVisibility({this.mode = 'narrator', this.npcIds = const []});
  factory StoryVisibility.fromJson(dynamic json) {
    final map = storyMap(json);
    final mode = map['mode']?.toString() ?? 'narrator';
    return StoryVisibility(
        mode: const ['public', 'npcs', 'narrator'].contains(mode)
            ? mode
            : 'narrator',
        npcIds: storyStrings(map['npcIds']));
  }
  final String mode;
  final List<String> npcIds;
  bool allows(String npcId) =>
      mode == 'public' || (mode == 'npcs' && npcIds.contains(npcId));
  Map<String, dynamic> toJson() => {'mode': mode, 'npcIds': npcIds};
}
