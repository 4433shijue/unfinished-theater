import 'dart:convert';
import '../models/npc_profile.dart';
import '../models/npc_runtime.dart';
import '../models/game_state.dart';
import '../models/story_continuity.dart';

class NpcEvolutionEngine {
  const NpcEvolutionEngine._();

  /// Apply only changes recorded by a later event to a restored baseline.
  static dynamic rebaseRecorded(dynamic base, dynamic before, dynamic after,
      [String key = '']) {
    if (jsonEncode(before) == jsonEncode(after)) return base;
    if (before is Map && after is Map) {
      final result = storyMap(base);
      for (final k in {...before.keys, ...after.keys}) {
        if (!after.containsKey(k)) {
          result.remove(k);
          continue;
        }
        if (!before.containsKey(k)) {
          result[k] = after[k];
          continue;
        }
        result[k] =
            rebaseRecorded(result[k], before[k], after[k], k.toString());
      }
      return result;
    }
    if (base is num &&
        before is num &&
        after is num &&
        const ['affinity', 'trust', 'score'].contains(key)) {
      return (base + after - before).clamp(-100, 100);
    }
    if (before is List && after is List) {
      final result = base is List ? [...base] : <dynamic>[];
      String identity(dynamic v) =>
          v is Map && v['id'] != null ? 'id:${v['id']}' : jsonEncode(v);
      final old = {for (final v in before) identity(v): v},
          next = {for (final v in after) identity(v): v};
      result.removeWhere((v) =>
          old.containsKey(identity(v)) && !next.containsKey(identity(v)));
      for (final v in after) {
        final id = identity(v),
            index = result.indexWhere((e) => identity(e) == id);
        if (!old.containsKey(id)) {
          if (index < 0) result.add(v);
        } else if (index >= 0) {
          result[index] = rebaseRecorded(result[index], old[id], v, key);
        }
      }
      return result;
    }
    return after;
  }

  static bool hasEvidence(String reason, String narrative) =>
      reason.trim().isNotEmpty &&
      narrative.contains(reason.trim()) &&
      !RegExp(r'据说|传闻|也许|可能|猜测|假如|如果|打算|计划|准备|试图|似乎').hasMatch(reason);

  static GameStateSnapshot validate(GameStateSnapshot state, String narrative,
      List<NpcProfile> profiles, StoryContinuityState continuity) {
    final updates = <GameNpcUpdate>[];
    for (final u in state.npcUpdates) {
      final raw = u.toJson();
      final npc = profiles
          .where((n) =>
              n.id == u.npcId ||
              n.name == u.name ||
              n.storyState.aliases.contains(u.name))
          .firstOrNull;
      if (npc != null) raw['npcId'] = npc.id;
      final lifecycle = NpcLifecycleX.tryFromValue(u.lifecycle);
      if (lifecycle != null && npc?.lifecycle != lifecycle) {
        final reason = u.lifecycleReason;
        final specific = switch (lifecycle) {
          NpcLifecycle.dead =>
            RegExp(r'死去|死亡|去世|断气|咽气|身亡|遇难|杀死').hasMatch(reason) &&
                !RegExp(r'没有|并未|未曾|没死|假死|险些|差点').hasMatch(reason),
          NpcLifecycle.missing => RegExp(r'失踪|失联|不知所踪|下落不明').hasMatch(reason),
          NpcLifecycle.active ||
          NpcLifecycle.away =>
            npc?.canSendMessages != false ||
                RegExp(r'复活|苏醒|还活着|恢复联络|重新出现|找到了|回来了').hasMatch(reason),
          _ => true,
        };
        if (!hasEvidence(reason, narrative) || !specific) raw['lifecycle'] = '';
      }
      final patch = Map<String, dynamic>.from(u.storyPatch);
      final reason = '${patch['evidence'] ?? ''}';
      if (patch.isNotEmpty && !hasEvidence(reason, narrative)) patch.clear();
      if (patch['name'] is String &&
          !narrative.contains(patch['name'] as String)) {
        patch.remove('name');
      }
      if (patch['publicIdentity'] is String &&
          !narrative.contains(patch['publicIdentity'] as String)) {
        patch.remove('publicIdentity');
      }
      if (patch['revealSecret'] == true &&
          npc != null &&
          ![npc.storyState.trueIdentity, npc.storyState.secret]
              .any((v) => v.isNotEmpty && narrative.contains(v))) {
        patch.remove('revealSecret');
      }
      if (npc != null &&
          (patch.containsKey('publicIdentity') ||
              patch['revealSecret'] == true ||
              patch.containsKey('name') ||
              (raw['lifecycle'] != '' &&
                  lifecycle != null &&
                  lifecycle != npc.lifecycle))) {
        final conflicts = continuity.activeFacts
            .where((f) =>
                f['pinned'] == true &&
                ('${f['npcId'] ?? ''}' == npc.id ||
                    '${f['key'] ?? ''}'.contains(npc.id) ||
                    '${f['text'] ?? ''}'.contains(npc.name)) &&
                !'${f['text'] ?? ''}'.contains(
                    '${patch['publicIdentity'] ?? patch['name'] ?? '__no_identity__'}'))
            .toList();
        if (conflicts.isNotEmpty) {
          final pending = continuity.conflicts;
          pending.add({
            'id': 'npc_${npc.id}_${state.updatedAt.microsecondsSinceEpoch}',
            'fingerprint': 'npc_${npc.id}_$reason',
            'key': 'npc.${npc.id}',
            'oldValue': npc.storyState.publicIdentity,
            'proposedValue': patch['publicIdentity'] ?? patch['name'],
            'npcUpdate': {
              ...raw,
              'storyPatch': Map<String, dynamic>.from(patch)
            },
            'npcId': npc.id,
            'factId': conflicts.first['id'],
            'resolved': false,
            'incoming': {
              'id': 'npc_${npc.id}/fact',
              'key': conflicts.first['key'],
              'text': '${patch['publicIdentity'] ?? patch['name'] ?? reason}',
              'evidence': reason,
              'sourceIds': [],
              'pinned': false
            },
            'reason': reason,
            'needsReview': true
          });
          continuity.data['conflicts'] = pending;
          patch.remove('publicIdentity');
          patch.remove('name');
          patch.remove('revealSecret');
          raw['lifecycle'] = '';
        }
      }
      if (patch['relations'] is List) {
        patch['relations'] = storyMaps(patch['relations'])
            .where((r) => profiles.any((n) => n.id == r['targetId']))
            .toList();
      }
      if (npc != null &&
          !npc.storyState.secretRevealed &&
          patch['revealSecret'] != true &&
          [npc.storyState.trueIdentity, npc.storyState.secret]
              .where((v) => v.isNotEmpty)
              .any((v) => '${raw['description'] ?? ''}'.contains(v))) {
        raw['description'] = '';
      }
      raw['storyPatch'] = patch;
      updates.add(GameNpcUpdate.fromJson(raw));
    }
    return state.copyWith(npcUpdates: updates);
  }

  static NpcProfile apply(NpcProfile npc, GameNpcUpdate update, String turnId) {
    final p = Map<String, dynamic>.from(update.storyPatch);
    if (!npc.canChangeAffinity) {
      p.remove('trustDelta');
      p.remove('relations');
      p.remove('stance');
    }
    if (p.isEmpty) return npc;
    final values = <String, dynamic>{};
    for (final key in ['publicIdentity', 'faction', 'goal', 'stance']) {
      if (p[key] is String && (p[key] as String).trim().isNotEmpty) {
        values[key] = p[key];
      }
    }
    if (p['appeared'] == true) values['appeared'] = true;
    if (p['revealSecret'] == true) {
      values['secretRevealed'] = true;
      if (npc.storyState.trueIdentity.isNotEmpty) {
        values['publicIdentity'] = npc.storyState.trueIdentity;
      }
    }
    var name = npc.name;
    if (p['name'] is String &&
        (p['name'] as String).trim().isNotEmpty &&
        p['name'] != name) {
      values['aliases'] = {...npc.storyState.aliases, name}.toList();
      name = p['name'] as String;
    }
    if (p['relations'] is List) {
      final relations = [...npc.storyState.relations];
      for (final r in storyMaps(p['relations'])) {
        if (r['targetId'] is! String || r['label'] is! String) continue;
        relations.removeWhere((old) => old['targetId'] == r['targetId']);
        relations.add({
          'targetId': r['targetId'],
          'label': r['label'],
          'public': r['public'] == true
        });
      }
      values['relations'] = relations;
    }
    values['changes'] = [
      ...npc.storyState.changes,
      {
        'turnId': turnId,
        'summary': p['evidence'],
        'reason': p['evidence'],
        'public': true
      }
    ];
    final trustDelta = p['trustDelta'] is num
        ? (p['trustDelta'] as num).toInt().clamp(-12, 12)
        : 0;
    return npc.copyWith(
        name: name,
        storyState: npc.storyState.patch(values),
        description: values['publicIdentity'] as String?,
        runtimeState: npc.runtimeState.copyWith(
            trust: (npc.runtimeState.trust + trustDelta).clamp(-100, 100),
            currentGoal: values['goal'] as String?));
  }

  static List<NpcProfile> routines(
      List<NpcProfile> npcs,
      List<Map<String, dynamic>> actions,
      GameStateSnapshot before,
      GameStateSnapshot after,
      String turnId,
      {required String narrative}) {
    if (before.timeLabel.isEmpty ||
        before.timeLabel == after.timeLabel ||
        after.timeLabel.isEmpty) {
      return npcs;
    }
    final result = [...npcs];
    final touched = <String>{};
    for (final action in actions) {
      if (touched.length >= 2) break;
      final index = result.indexWhere((n) => n.id == action['npcId']);
      if (index < 0) continue;
      final npc = result[index];
      if (!npc.canSendMessages ||
          touched.contains(npc.id) ||
          npc.storyState.lastRoutineTurn == turnId) {
        continue;
      }
      final timeEvidence = '${action['timeEvidence'] ?? ''}';
      if (!hasEvidence(timeEvidence, narrative) ||
          !RegExp(r'过了|随后|次日|翌日|第二天|入夜|到了|时辰|分钟|小时|半天|日后')
              .hasMatch(timeEvidence)) {
        continue;
      }
      if (!const ['move', 'work', 'investigate', 'relationship', 'lead']
          .contains(action['type'])) {
        continue;
      }
      final summary = '${action['summary'] ?? ''}',
          reason = '${action['reason'] ?? ''}';
      if (summary.isEmpty || reason.isEmpty) continue;
      if (action['type'] == 'lead' ||
          RegExp(r'死亡|死去|杀死|背叛|叛变|真实身份|揭露|复活').hasMatch(summary)) {
        result[index] = npc.copyWith(
            storyState: npc.storyState.patch({
          'lastRoutineTurn': turnId,
          'pendingEvents': [
            ...npc.storyState.pendingEvents,
            {
              'turnId': turnId,
              'summary': summary,
              'reason': reason,
              'status': 'awaitingNarrative'
            }
          ]
        }));
        touched.add(npc.id);
        continue;
      }
      final story = npc.storyState.patch({
        'lastRoutineTurn': turnId,
        'goalProgress': summary,
        'changes': [
          ...npc.storyState.changes,
          {
            'turnId': turnId,
            'summary': summary,
            'reason': reason,
            'public': false
          }
        ]
      });
      var runtime = npc.runtimeState;
      if (action['type'] == 'move' && action['location'] is String) {
        runtime = runtime.copyWith(location: action['location'] as String);
      }
      result[index] =
          npc.copyWith(storyState: story, runtimeState: runtime, worldEvents: [
        ...npc.worldEvents,
        WorldEvent(
            id: 'routine_${turnId}_${npc.id}',
            characterId: after.characterId,
            title: '日常进展',
            summary: summary,
            createdAt: after.updatedAt,
            npcIds: [npc.id])
      ]);
      touched.add(npc.id);
    }
    return result;
  }
}
