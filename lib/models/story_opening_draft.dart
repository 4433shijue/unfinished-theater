import 'dart:convert';
import 'gameplay_system.dart';
import '../services/gameplay_system_parser.dart';

class StoryOpeningDraft {
  StoryOpeningDraft(Map<String, dynamic> data)
      : data = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  final Map<String, dynamic> data;
  factory StoryOpeningDraft.fromJson(Map<String, dynamic> json) =>
      StoryOpeningDraft(json);
  List<Map<String, dynamic>> list(String key) =>
      (data[key] is List ? data[key] as List : const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
  List<Map<String, dynamic>> get npcs => list('npcs');
  List<Map<String, dynamic>> get relationships => list('relationships');
  List<Map<String, dynamic>> get items => list('items');
  GameplaySystem? get gameplay => data['gameplaySystem'] is Map
      ? GameplaySystem.fromJson(
          Map<String, dynamic>.from(data['gameplaySystem'] as Map))
      : null;
  Map<String, dynamic> toJson() =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
  List<String> validate({int npcCount = 0}) {
    final errors = <String>[];
    if (npcs.length < 3 ||
        npcs.length > 6 ||
        (npcCount != 0 && npcs.length != npcCount)) {
      errors.add('初始人物须为${npcCount == 0 ? '3—6' : npcCount}名。');
    }
    final ids = <String>{}, names = <String>{};
    for (final n in npcs) {
      final name = '${n['name'] ?? ''}'.trim(), id = '${n['id'] ?? ''}'.trim();
      if (id.isEmpty || !ids.add(id)) errors.add('人物 ID 缺失或重复。');
      if (name.isEmpty || !names.add(name)) errors.add('人物姓名缺失或重复。');
      for (final key in [
        'publicIdentity',
        'personality',
        'goal',
        'affinityReason'
      ]) {
        if ('${n[key] ?? ''}'.trim().isEmpty) {
          errors.add('$name 缺少${const {
            'publicIdentity': '公开身份',
            'personality': '性格',
            'goal': '目标',
            'affinityReason': '初始好感原因'
          }[key]}。');
        }
      }
      if (n['affinity'] is! num || (n['affinity'] as num).abs() > 100) {
        errors.add('$name 的初始好感应在 -100 到 100 之间。');
      }
      if (n['appeared'] is! bool) errors.add('$name 缺少初始登场状态。');
    }
    for (final r in relationships) {
      if (!ids.contains(r['from']) ||
          !ids.contains(r['to']) ||
          r['from'] == r['to'] ||
          '${r['label'] ?? ''}'.trim().isEmpty) {
        errors.add('人物关系引用无效。');
      }
    }
    final itemIds = <String>{};
    for (final item in items) {
      if ('${item['id'] ?? ''}'.isEmpty ||
          !itemIds.add('${item['id']}') ||
          '${item['name'] ?? ''}'.trim().isEmpty ||
          (item['quantity'] is! int) ||
          (item['quantity'] as int) < 1) {
        errors.add('初始物品须有唯一 ID、名称和正整数数量。');
      }
    }
    try {
      if (gameplay == null) {
        errors.add('缺少初始玩法。');
      } else {
        GameplaySystemParser.validateSystem(gameplay!);
      }
    } on FormatException catch (e) {
      errors.add(e.message);
    }
    return errors.toSet().toList();
  }
}
