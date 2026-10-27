import 'map_state.dart';
import 'chat_message.dart';
import 'game_state.dart';
import 'npc_profile.dart';

class TurnSettlement {
  const TurnSettlement(
      {required this.worldId,
      required this.turnId,
      this.revision = 1,
      this.status = 'complete',
      this.entries = const [],
      this.error = '',
      this.seen = false});
  factory TurnSettlement.fromJson(Map<String, dynamic> j) => TurnSettlement(
      worldId: '${j['worldId'] ?? ''}',
      turnId: '${j['turnId'] ?? ''}',
      revision: j['revision'] is int ? j['revision'] as int : 1,
      status: '${j['status'] ?? 'complete'}',
      error: '${j['error'] ?? ''}',
      seen: j['seen'] == true,
      entries: (j['entries'] is List ? j['entries'] as List : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList());
  static TurnSettlement? of(ChatMessage message) {
    final raw = message.gameStateSnapshot?['turnSettlement'];
    return raw is Map
        ? TurnSettlement.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  final String worldId, turnId, status, error;
  final int revision;
  final bool seen;
  final List<Map<String, dynamic>> entries;
  bool get complete => status == 'complete';
  Map<String, dynamic> toJson() => {
        'worldId': worldId,
        'turnId': turnId,
        'revision': revision,
        'status': status,
        'entries': entries,
        'error': error,
        'seen': seen
      };

  static String threadLabel(String value) => switch (value) {
        'open' => '进行中',
        'resolved' => '已兑现',
        'broken' => '已失约',
        _ => value
      };
  static TurnSettlement compare(
      {required String worldId,
      required String turnId,
      required GameStateSnapshot before,
      required GameStateSnapshot after,
      required List<NpcProfile> beforeNpcs,
      required List<NpcProfile> afterNpcs,
      int revision = 1,
      MapWorldState? beforeMap,
      MapWorldState? afterMap}) {
    final entries = <Map<String, dynamic>>[];
    void add(String kind, String id, String label, dynamic old, dynamic next,
        String reason) {
      if ('$old' == '$next') return;
      entries.add({
        'category': kind,
        'objectId': id,
        'label': label,
        'before': old,
        'after': next,
        if (old is num && next is num) 'delta': next - old,
        'reason': reason,
        'source': turnId,
        'visibility': 'public'
      });
    }

    if (after.gameplayVariableRecords.isNotEmpty) {
      for (final record
          in after.gameplayVariableRecords.where((r) => r.playerVisible)) {
        entries.add({
          'category': '玩法',
          'objectId': record.path,
          'label': record.label,
          'before': record.playerBefore,
          'after': record.playerAfter,
          if (record.visibility.name == 'public' &&
              record.before is num &&
              record.after is num)
            'delta': (record.after as num) - (record.before as num),
          'reason': record.steps
              .where((step) => step.playerVisible)
              .map((step) => step.playerReason)
              .where((v) => v.isNotEmpty)
              .join('；'),
          'source': turnId,
          'visibility': 'public'
        });
      }
    } else {
      for (final text in after.gameplayPlayerVariableChanges) {
        entries.add({
          'category': '玩法',
          'objectId': 'variable',
          'label': text,
          'source': turnId,
          'visibility': 'public'
        });
      }
    }
    for (final key in {...before.metrics.keys, ...after.metrics.keys}) {
      add('状态', key, key, before.metrics[key] ?? 0, after.metrics[key] ?? 0,
          '本轮行动结算');
    }
    if (beforeMap != null && afterMap != null) {
      add('地图资源', 'map/ap', '行动力', beforeMap.currentActionPoints,
          afterMap.currentActionPoints, '地图规则结算');
      add('地图资源', 'map/threat', '危机', beforeMap.threatClock,
          afterMap.threatClock, '地图规则结算');
      final old = {for (final i in beforeMap.mapInventory) i.id: i},
          next = {for (final i in afterMap.mapInventory) i.id: i};
      for (final id in {...old.keys, ...next.keys}) {
        add('物品', 'map/$id', (next[id] ?? old[id]!).name,
            old[id]?.quantity ?? 0, next[id]?.quantity ?? 0, '地图行动');
      }
    }
    final oldItems = {for (final i in before.storyInventory) i.id: i};
    final newItems = {for (final i in after.storyInventory) i.id: i};
    for (final id in {...oldItems.keys, ...newItems.keys}) {
      final item = newItems[id] ?? oldItems[id]!;
      add(
          '物品',
          id,
          item.name,
          oldItems[id]?.quantity ?? 0,
          newItems[id]?.quantity ?? 0,
          (newItems[id]?.quantity ?? 0) > (oldItems[id]?.quantity ?? 0)
              ? (item.source.isEmpty ? '本轮获得' : item.source)
              : '本轮消耗或失去');
    }
    final olds = {for (final n in beforeNpcs) n.id: n};
    for (final n in afterNpcs.where((n) => n.storyState.appeared)) {
      final old = olds[n.id];
      if (old == null || !old.storyState.appeared) {
        add(
            '人物',
            n.id,
            n.name,
            '尚未登场',
            n.storyState.publicIdentity.isEmpty
                ? '已经登场'
                : n.storyState.publicIdentity,
            '本轮相遇');
      }
      if (old == null) continue;
      final update = after.npcUpdates
          .where((u) => u.npcId == n.id || u.name == n.name)
          .firstOrNull;
      add('好感', n.id, '${n.name}好感', old.affinity, n.affinity,
          update?.impression ?? n.impression);
      add('信任', n.id, '${n.name}信任', old.runtimeState.trust,
          n.runtimeState.trust, update?.impression ?? n.impression);
      add('人物状态', n.id, n.name, old.lifecycle.label, n.lifecycle.label,
          update?.lifecycleReason ?? '本轮剧情确认');
      add('身份', n.id, n.name, old.storyState.publicIdentity,
          n.storyState.publicIdentity, '本轮确认的身份');
      add('关系', n.id, '${n.name}的印象', old.impression, n.impression, '本轮互动');
      final reason = '${update?.storyPatch['evidence'] ?? '本轮剧情确认'}';
      add('称呼', n.id, old.name, old.name, n.name, reason);
      add('立场', n.id, '${n.name}的立场', old.storyState.stance,
          n.storyState.stance, reason);
      final oldRelations = {
        for (final r
            in old.storyState.relations.where((r) => r['public'] == true))
          r['targetId']: r
      };
      for (final relation
          in n.storyState.relations.where((r) => r['public'] == true)) {
        final target = afterNpcs
            .where((p) => p.id == relation['targetId'] && p.storyState.appeared)
            .firstOrNull;
        if (target == null) continue;
        add(
            '人物关系',
            '${n.id}/${target.id}',
            '${n.name}与${target.name}',
            oldRelations[target.id]?['label'] ?? '尚未知晓',
            relation['label'],
            reason);
      }

      for (final change in n.storyState.changes
          .where((c) => c['turnId'] == turnId && c['public'] == true)) {
        entries.add({
          'category': '人物事件',
          'objectId': n.id,
          'label': n.name,
          'after': change['summary'],
          'reason': change['reason'],
          'source': turnId,
          'visibility': 'public'
        });
      }
    }
    add('任务', 'main', '当前任务', before.mainTask, after.mainTask, '本轮任务进展');
    for (final task in after.completedTasks
        .where((t) => !before.completedTasks.contains(t))) {
      add('任务', task, task, '进行中', '已完成', '本轮完成');
    }
    for (final task
        in after.sideTasks.where((t) => !before.sideTasks.contains(t))) {
      add('任务', task, task, '', '已接取', '本轮新增');
    }
    for (final note in after.relationshipNotes
        .where((t) => !before.relationshipNotes.contains(t))) {
      add('关系', note, note, '', '已记录', '本轮关系变化');
    }
    for (final flag
        in after.plotFlags.where((t) => !before.plotFlags.contains(t))) {
      add('事件', flag, flag, '', '已记录', '本轮公开事件');
    }
    if (after.eventTitle.isNotEmpty &&
        (after.eventTitle != before.eventTitle ||
            after.eventDescription != before.eventDescription)) {
      add('事件', 'event', after.eventTitle, '', after.eventDescription, '本轮发生');
    }
    final oldThreads = {
      for (final t in before.gameplayRuntime.threads) t.id: t
    };
    for (final t
        in after.gameplayRuntime.threads.where((t) => t.isPlayerFacing)) {
      final old = oldThreads[t.id];
      add(
          '承诺与伏笔',
          t.id,
          t.title,
          old == null ? '' : threadLabel(old.status.name),
          threadLabel(t.status.name),
          t.reason);
      if (old == null && t.deadline.isNotEmpty) {
        add('期限', t.id, t.title, '', t.deadline, '已确认的约定期限');
      }
      if (t.dueTurn != null &&
          t.status.name == 'open' &&
          t.dueTurn! - after.gameplayRuntime.turn <= 1 &&
          before.gameplayRuntime.turn < t.dueTurn! &&
          (before.gameplayRuntime.turn < t.dueTurn! - 1 ||
              after.gameplayRuntime.turn >= t.dueTurn!)) {
        add(
            '期限',
            t.id,
            t.title,
            '',
            t.dueTurn! <= after.gameplayRuntime.turn ? '已到期，结果待确认' : '约定即将到期',
            '约定回合 ${t.dueTurn}');
      }
    }
    return TurnSettlement(
        worldId: worldId, turnId: turnId, revision: revision, entries: entries);
  }
}
