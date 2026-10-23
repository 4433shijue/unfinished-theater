import 'dart:convert';

import '../models/story_continuity.dart';
import 'message_content_parser.dart';

class StoryContinuityEngine {
  const StoryContinuityEngine._();

  static const patchContract = '''
同时可返回 continuityPatch 对象，所有条目只能依据本轮正史正文，不读取 HTML 番外。
{"facts":[{"key":"稳定的事实主题","text":"已证实的事实","evidence":"正文原句"}],
"knowledge":[{"npcId":"已给出的NPC稳定ID","factKey":"事实主题","level":"witnessed/told/suspected/unknown","evidence":"正文原句"}],
"scene":{"title":"当前场景短标题","participants":["明确在场的人名"],"summary":"本轮已发生事件","openThreads":["未解决事项"],"pendingReply":"尚待玩家回应的内容","evidence":"正文原句"}}
缺乏依据时省略，不把愿望、传闻、提议或推测写成事实。knowledge 只能写有证据的获知过程；私聊只能更新当前 NPC 的知情。
不把资源数值当成叙事事实；固定事实冲突可以提出更新，但不能自行覆盖。所有 evidence 必须是本轮正文的连续原文。
''';

  static StoryContinuityState apply(
      {required StoryContinuityState state,
      required String eventId,
      required List<String> sourceIds,
      required String narrative,
      required Map<String, dynamic> patch,
      required Set<String> npcIds,
      String? privateNpcId,
      Map<String, dynamic> checkpoint = const {},
      DateTime? now}) {
    // A batch/turn can only settle once, even after retries or UI rebuilds.
    if (sourceIds.isEmpty || state.events.any((e) => e['id'] == eventId)) {
      return state;
    }
    final result = state.copy();
    final sequence = state.sequence + 1;
    final text = MessageContentParser.contextTextForModel(narrative);
    bool evidenced(Map<String, dynamic> row) {
      final evidence = row['evidence']?.toString().trim() ?? '';
      return evidence.isNotEmpty && text.contains(evidence);
    }

    final facts = result.facts;
    final conflicts = result.conflicts;
    final conflictedKeys = <String>{};
    for (final row in storyMaps(patch['facts']).take(12)) {
      final key = row['key']?.toString().trim() ?? '';
      final value = row['text']?.toString().trim() ?? '';
      if (key.isEmpty || value.isEmpty || !evidenced(row)) continue;
      final oldIndex = facts.lastIndexWhere((f) =>
          f['key'] == key &&
          f['retired'] != true &&
          f['privateNpcId'] == privateNpcId);
      final old = oldIndex < 0 ? null : facts[oldIndex];
      if (old?['text'] == value) continue;
      final incoming = <String, dynamic>{
        'id': '$eventId/fact/$key',
        'key': key,
        'text': value,
        'sourceIds': sourceIds,
        'eventId': eventId,
        'sequence': sequence,
        'pinned': false,
        'evidence': row['evidence'],
        if (privateNpcId != null) 'privateNpcId': privateNpcId
      };
      if (old?['pinned'] == true) {
        conflictedKeys.add(key);
        final fingerprint = jsonEncode([old!['id'], value]);
        if (!conflicts.any((c) => c['fingerprint'] == fingerprint)) {
          conflicts.add({
            'id': '$eventId/conflict/$key',
            'fingerprint': fingerprint,
            'factId': old['id'],
            'incoming': incoming,
            'resolved': false
          });
        }
      } else {
        if (oldIndex >= 0) {
          facts[oldIndex] = {...facts[oldIndex], 'retired': true};
        }
        facts.add(incoming);
      }
    }
    final knowledge = result.knowledge;
    for (final row in storyMaps(patch['knowledge']).take(30)) {
      final npcId = row['npcId']?.toString() ?? '';
      final key = row['factKey']?.toString() ?? '';
      final level = row['level']?.toString() ?? '';
      if (conflictedKeys.contains(key)) continue;
      if (!npcIds.contains(npcId) ||
          (privateNpcId != null && privateNpcId != npcId) ||
          !const ['witnessed', 'told', 'suspected', 'unknown']
              .contains(level) ||
          !evidenced(row)) {
        continue;
      }
      final factIndex = facts.lastIndexWhere((f) =>
          f['key'] == key &&
          f['retired'] != true &&
          f['needsReview'] != true &&
          (privateNpcId == null ||
              f['privateNpcId'] == null ||
              f['privateNpcId'] == privateNpcId));
      if (factIndex < 0) continue;
      knowledge.removeWhere((k) => k['npcId'] == npcId && k['factKey'] == key);
      knowledge.add({
        ...row,
        'factId': facts[factIndex]['id'],
        'sequence': sequence,
        'eventId': eventId,
        'sourceIds': sourceIds
      });
    }
    final proposedScene = storyMap(patch['scene']);
    var scene = result.scene;
    if (privateNpcId == null) {
      if (scene.isEmpty || scene['closed'] == true) {
        scene = {
          'id': 'scene/$eventId',
          'startMessageId': sourceIds.first,
          'startSequence': sequence,
          'title': '当前场景'
        };
      }
      if (evidenced(proposedScene)) {
        final sources = storyMap(scene['sources']);
        for (final key in ['title', 'summary', 'pendingReply']) {
          if (proposedScene[key] is String &&
              (proposedScene[key] as String).trim().isNotEmpty) {
            scene[key] = proposedScene[key];
            sources[key] = sourceIds.last;
          }
        }
        for (final key in ['participants', 'openThreads']) {
          if (proposedScene[key] is List) {
            scene[key] = storyStrings(proposedScene[key]).take(8).toList();
            sources[key] = sourceIds.last;
          }
        }
        scene['sources'] = sources;
      }
      scene['sourceId'] = sourceIds.last;
      scene['endSequence'] = sequence;
      result.data['scene'] = scene;
    }
    result.data.addAll({
      'sequence': sequence,
      'facts': facts,
      'conflicts': conflicts,
      'knowledge': knowledge,
      'events': [
        ...state.events,
        {
          'id': eventId,
          'sequence': sequence,
          'sourceIds': sourceIds,
          if (privateNpcId != null) 'npcId': privateNpcId,
          'timestamp': (now ?? DateTime.now()).toIso8601String()
        }
      ],
      'checkpoints': {
        ...state.checkpoints,
        eventId: {
          'sequence': sequence,
          'before': state.snapshot(),
          ...checkpoint
        }
      }
    });
    return result;
  }

  static String factsPrompt(StoryContinuityState state, {String? npcId}) {
    final lines = <String>[];
    for (final fact in state.activeFacts) {
      if (npcId == null) {
        lines.add(
            '[${fact['key']}] ${fact['pinned'] == true ? '玩家确认' : '已记录'}：${fact['text']}');
      } else {
        final known = state.knowledge.where((k) =>
            k['npcId'] == npcId &&
            k['factId'] == fact['id'] &&
            k['level'] != 'unknown');
        if (known.isNotEmpty) {
          lines.add(
              '[${fact['key']}] ${known.last['level'] == 'suspected' ? '只是怀疑，不能当成事实' : '已知'}：${fact['text']}');
        }
      }
    }
    return lines.join('\n');
  }

  /// Editing/deleting a source cannot leave its former assertions in prompts.
  /// Keep the records visible for review and sanitize retained branch snapshots.
  static StoryContinuityState invalidateSources(
      StoryContinuityState state, Set<String> ids) {
    final next = state.copy();
    bool affected(dynamic sources) => storyStrings(sources).any(ids.contains);
    final invalidFacts = next.facts
        .where((f) => affected(f['sourceIds']))
        .map((f) => f['id'])
        .toSet();
    next.data['facts'] = next.facts
        .map((f) =>
            invalidFacts.contains(f['id']) ? {...f, 'needsReview': true} : f)
        .toList();
    next.data['knowledge'] = next.knowledge
        .map((k) =>
            invalidFacts.contains(k['factId']) || affected(k['sourceIds'])
                ? {...k, 'level': 'unknown', 'needsReview': true}
                : k)
        .toList();
    Map<String, dynamic> cleanScene(Map<String, dynamic> scene) {
      final sources = storyMap(scene['sources']);
      for (final field in [
        'summary',
        'participants',
        'openThreads',
        'pendingReply'
      ]) {
        if (ids.contains(sources[field] ?? scene['sourceId'])) {
          scene.remove(field);
        }
      }
      if (ids.contains(scene['sourceId'])) scene['needsReview'] = true;
      return scene;
    }

    next.data['scene'] = cleanScene(next.scene);
    next.data['chapters'] = next.chapters.map(cleanScene).toList();
    next.data['checkpoints'] = {
      for (final e in next.checkpoints.entries)
        e.key: {
          ...storyMap(e.value),
          'before': invalidateSources(
                  StoryContinuityState(
                      characterId: state.characterId,
                      data: storyMap(storyMap(e.value)['before'])),
                  ids)
              .snapshot()
        }
    };
    return next;
  }

  static Map<String, String> director(StoryContinuityState state,
      {bool privateChat = false}) {
    final result = <String, String>{};
    for (final scope in privateChat ? ['story'] : ['story', 'scene', 'turn']) {
      for (final entry in storyMap(state.directors[scope]).entries) {
        if (entry.value is String &&
            (entry.value as String).trim().isNotEmpty) {
          result[entry.key] = entry.value;
        }
      }
    }
    return result;
  }

  static String directorPrompt(StoryContinuityState state,
      {bool privateChat = false}) {
    final values = director(state, privateChat: privateChat);
    if (values.isEmpty) return '';
    return '叙事偏好（不改变事实、玩家自主权或状态协议；篇幅偏好优先于默认字数建议）\n${values.entries.map((e) => '${e.key}：${e.value}').join('\n')}';
  }
}
