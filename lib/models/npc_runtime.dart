import '../utils/id_generator.dart';
import 'game_state.dart';
import 'npc_profile.dart';
import '../services/npc_message_classifier.dart';

class NpcRuntimeState {
  const NpcRuntimeState({
    this.mood = '',
    this.location = '',
    this.trust = 0,
    this.currentGoal = '',
    this.lastEventId = '',
    this.updatedAt,
  });

  factory NpcRuntimeState.fromJson(Map<String, dynamic> json) {
    return NpcRuntimeState(
      mood: json['mood']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      trust: _readBoundedInt(json['trust'], min: -100, max: 100),
      currentGoal: json['currentGoal']?.toString() ?? '',
      lastEventId: json['lastEventId']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  final String mood;
  final String location;
  final int trust;
  final String currentGoal;
  final String lastEventId;
  final DateTime? updatedAt;

  NpcRuntimeState copyWith({
    String? mood,
    String? location,
    int? trust,
    String? currentGoal,
    String? lastEventId,
    DateTime? updatedAt,
  }) {
    return NpcRuntimeState(
      mood: mood ?? this.mood,
      location: location ?? this.location,
      trust: trust ?? this.trust,
      currentGoal: currentGoal ?? this.currentGoal,
      lastEventId: lastEventId ?? this.lastEventId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mood': mood,
      'location': location,
      'trust': trust,
      'currentGoal': currentGoal,
      'lastEventId': lastEventId,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class NpcMemoryEntry {
  const NpcMemoryEntry({
    required this.id,
    required this.summary,
    required this.createdAt,
    this.weight = 1,
  });

  factory NpcMemoryEntry.fromJson(Map<String, dynamic> json) {
    return NpcMemoryEntry(
      id: json['id']?.toString() ?? '',
      summary: normalizeNpcImpressionText(json['summary']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      weight: _readBoundedInt(json['weight'], min: 1, max: 10),
    );
  }

  final String id;
  final String summary;
  final DateTime createdAt;
  final int weight;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'summary': summary,
      'createdAt': createdAt.toIso8601String(),
      'weight': weight,
    };
  }
}

class RelationshipEdge {
  const RelationshipEdge({
    required this.targetId,
    required this.label,
    required this.score,
    required this.updatedAt,
  });

  factory RelationshipEdge.fromJson(Map<String, dynamic> json) {
    return RelationshipEdge(
      targetId: json['targetId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      score: _readBoundedInt(json['score'], min: -100, max: 100),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String targetId;
  final String label;
  final int score;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetId': targetId,
      'label': label,
      'score': score,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class WorldEvent {
  const WorldEvent({
    required this.id,
    required this.characterId,
    required this.title,
    required this.summary,
    required this.createdAt,
    this.npcIds = const <String>[],
  });

  factory WorldEvent.fromJson(Map<String, dynamic> json) {
    final rawIds = json['npcIds'];
    return WorldEvent(
      id: json['id']?.toString() ?? '',
      characterId: json['characterId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      npcIds: rawIds is List
          ? rawIds.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }

  final String id;
  final String characterId;
  final String title;
  final String summary;
  final DateTime createdAt;
  final List<String> npcIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'title': title,
      'summary': summary,
      'createdAt': createdAt.toIso8601String(),
      'npcIds': npcIds,
    };
  }
}

class NpcRuntimePatch {
  const NpcRuntimePatch({
    required this.profile,
    required this.worldEvent,
  });

  final NpcProfile profile;
  final WorldEvent worldEvent;
}

class NpcRuntimeEngine {
  const NpcRuntimeEngine();

  NpcRuntimePatch applyGameStateUpdate({
    required NpcProfile profile,
    required String characterId,
    required GameStateSnapshot state,
    required GameNpcUpdate update,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final eventSummary = _eventSummary(state, update);
    final event = WorldEvent(
      id: IdGenerator.generic('world_event'),
      characterId: characterId,
      title: state.eventTitle.trim().isEmpty
          ? 'NPC update'
          : state.eventTitle.trim(),
      summary: eventSummary,
      createdAt: timestamp,
      npcIds: <String>[profile.id],
    );
    final runtime = profile.runtimeState.copyWith(
      mood: _inferMood(update.impression, state.status),
      location: state.location.trim().isEmpty
          ? profile.runtimeState.location
          : state.location.trim(),
      currentGoal: state.mainTask.trim().isEmpty
          ? profile.runtimeState.currentGoal
          : state.mainTask.trim(),
      lastEventId: event.id,
      updatedAt: timestamp,
    );
    final memory = NpcMemoryEntry(
      id: IdGenerator.generic('npc_memory'),
      summary: eventSummary,
      createdAt: timestamp,
      weight: update.affinity == null && update.affinityDelta == null ? 2 : 3,
    );
    final edge = RelationshipEdge(
      targetId: 'player',
      label: update.impression.trim().isEmpty
          ? 'recent interaction'
          : update.impression.trim(),
      score: profile.affinity,
      updatedAt: timestamp,
    );
    return NpcRuntimePatch(
      profile: profile.copyWith(
        runtimeState: runtime,
        npcMemory: <NpcMemoryEntry>[
          memory,
          ...profile.npcMemory,
        ].take(30).toList(growable: false),
        relationshipEdges: <RelationshipEdge>[
          edge,
          ...profile.relationshipEdges
              .where((item) => item.targetId != edge.targetId),
        ].take(20).toList(growable: false),
        worldEvents: <WorldEvent>[
          event,
          ...profile.worldEvents,
        ].take(40).toList(growable: false),
        updatedAt: timestamp,
      ),
      worldEvent: event,
    );
  }

  String _eventSummary(GameStateSnapshot state, GameNpcUpdate update) {
    final parts = <String>[
      if (update.impression.trim().isNotEmpty) update.impression.trim(),
      if (NpcMessageClassifier.isDeliverableChatBubble(
        update.proactiveMessage,
      ))
        update.proactiveMessage.trim(),
      if (state.eventDescription.trim().isNotEmpty)
        state.eventDescription.trim(),
      if (state.status.trim().isNotEmpty) state.status.trim(),
    ];
    return parts.isEmpty
        ? 'NPC state changed after the latest turn.'
        : parts.first;
  }

  String _inferMood(String impression, String status) {
    final text = '$impression $status';
    if (text.contains('angry') || text.contains('conflict')) {
      return 'tense';
    }
    if (text.contains('happy') || text.contains('trust')) {
      return 'open';
    }
    return text.trim().isEmpty ? '' : 'focused';
  }
}

int _readBoundedInt(dynamic value, {required int min, required int max}) {
  if (value is num) {
    return value.round().clamp(min, max);
  }
  final parsed = int.tryParse(
    value?.toString().replaceAll(RegExp(r'[^0-9-]'), '') ?? '',
  );
  return (parsed ?? 0).clamp(min, max);
}
