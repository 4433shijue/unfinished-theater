import 'dart:convert';

import '../models/game_state.dart';
import 'npc_message_classifier.dart';

class GameStateParser {
  const GameStateParser._();

  static final RegExp stateBlockPattern = RegExp(
    r'\[GAME_STATE\]\s*([\s\S]*?)\s*\[/GAME_STATE\]',
    caseSensitive: false,
  );

  static String stripStateBlocks(String content) {
    var stripped = content.replaceAll(stateBlockPattern, '');
    stripped = stripped.replaceAll(
      RegExp(
        r'\[GAME_STATE\][\s\S]*?(?=\[CHOICES\]|$)',
        caseSensitive: false,
      ),
      '',
    );
    stripped = stripped.replaceAll(
      RegExp(
        r'\[MAP_STATE\]\s*[\s\S]*?\s*\[/MAP_STATE\]',
        caseSensitive: false,
      ),
      '',
    );
    stripped = stripped.replaceAll(
      RegExp(
        r'\[MAP_STATE\][\s\S]*?(?=\[CHOICES\]|$)',
        caseSensitive: false,
      ),
      '',
    );
    stripped = stripped.replaceAll(
      RegExp(
        r'\[THEATER_PATCH\]\s*[\s\S]*?\s*\[/THEATER_PATCH\]',
        caseSensitive: false,
      ),
      '',
    );
    stripped = stripped.replaceAll(
      RegExp(
        r'\[THEATER_PATCH\][\s\S]*?(?=\[CHOICES\]|$)',
        caseSensitive: false,
      ),
      '',
    );
    return _stripLooseStatePanels(stripped).trimRight();
  }

  static final RegExp _looseStateLinePattern = RegExp(
    r'^(?:时间|日期|当前时间|地点|当前位置|状态|主角状态|心情|当前任务|主线任务|任务|人物数据|人物面板|主角资料|主角面板|玩家面板|支线任务|支线|已完成任务|完成任务|背包|道具|物品|剧情物品栏|剧情物品|事件卡|事件|当前事件|事件描述|事件说明|关系网|人际关系|关系记录|重要伏笔|剧情标记|已触发事件|剧情记录|NPC变化|NPC印象|关系变化|NPC更新|NPC档案更新|压力|精力|体力|金钱|声望|好感)\s*[:：=]',
    caseSensitive: false,
  );

  static final RegExp _looseStateCoreLinePattern = RegExp(
    r'^(?:时间|日期|当前时间|地点|当前位置|状态|主角状态|心情|当前任务|主线任务|任务|人物数据|人物面板|主角资料|主角面板|玩家面板|关系网|人际关系|剧情记录)\s*[:：=]',
    caseSensitive: false,
  );

  static String _stripLooseStatePanels(String content) {
    var current = content;
    for (var pass = 0; pass < 3; pass += 1) {
      final panel = _extractLooseStatePanel(current);
      if (panel == null) {
        break;
      }
      final lines = current.split(RegExp(r'\r?\n'));
      final before = lines.take(panel.startLine).join('\n').trimRight();
      final after = lines.skip(panel.endLine).join('\n').trimLeft();
      current = <String>[
        if (before.isNotEmpty) before,
        if (after.isNotEmpty) after,
      ].join('\n\n');
    }
    return current;
  }

  static _LooseStatePanel? _extractLooseStatePanel(String content) {
    if (content.trim().isEmpty) {
      return null;
    }
    final lines = content.split(RegExp(r'\r?\n'));
    for (var start = 0; start < lines.length; start += 1) {
      final first = lines[start].trim();
      if (!_looseStateLinePattern.hasMatch(first)) {
        continue;
      }

      var keyCount = 0;
      var coreKeyCount = 0;
      var end = start;
      for (var index = start; index < lines.length; index += 1) {
        final line = lines[index].trim();
        if (line.isEmpty) {
          if (keyCount >= 3) {
            break;
          }
          continue;
        }
        if (_isStatePanelBoundary(line)) {
          break;
        }
        if (_looseStateLinePattern.hasMatch(line)) {
          keyCount += 1;
          if (_looseStateCoreLinePattern.hasMatch(line)) {
            coreKeyCount += 1;
          }
          end = index + 1;
          continue;
        }
        if (keyCount == 0) {
          break;
        }
        end = index + 1;
      }

      if (keyCount >= 4 || (keyCount >= 3 && coreKeyCount >= 2)) {
        return _LooseStatePanel(startLine: start, endLine: end);
      }
    }
    return null;
  }

  static bool _isStatePanelBoundary(String line) {
    return line.startsWith('```') ||
        RegExp(r'^</?(?:html|head|body|style|script)\b', caseSensitive: false)
            .hasMatch(line) ||
        RegExp(r'^\[/?(?:CHOICES|GAME_STATE|MAP_STATE|THEATER_PATCH|BUBBLE)\]$',
                caseSensitive: false)
            .hasMatch(line) ||
        RegExp(r'^[A-F]\s*[|｜、:：]', caseSensitive: false).hasMatch(line);
  }

  static GameStateSnapshot? parseFromMessage({
    required String characterId,
    required String content,
    required GameStateSnapshot previous,
  }) {
    // Pre-clean: strip CHOICES blocks so GAME_STATE inside them doesn't leak
    final cleanedContent = content
        .replaceAll(RegExp(r'\[CHOICES\][\s\S]*?\[/CHOICES\]'), '')
        .replaceAll(RegExp(r'\[CHOICES\][\s\S]*$'), '');

    final matches = stateBlockPattern.allMatches(cleanedContent).toList();
    if (matches.isEmpty) {
      final looseMatch = RegExp(
        r'\[GAME_STATE\]\s*([\s\S]*?)(?:\[/GAME_STATE\]|\[CHOICES\]|$)',
        caseSensitive: false,
      ).allMatches(cleanedContent).toList();
      if (looseMatch.isNotEmpty) {
        return _parseRawBlock(
          looseMatch.last.group(1)?.trim() ?? '',
          characterId,
          previous,
        );
      }

      final looseStatePanel = _extractLooseStatePanel(cleanedContent);
      if (looseStatePanel != null) {
        final lines = cleanedContent.split(RegExp(r'\r?\n'));
        final rawBlock = lines
            .skip(looseStatePanel.startLine)
            .take(looseStatePanel.endLine - looseStatePanel.startLine)
            .join('\n')
            .trim();
        return _parseRawBlock(rawBlock, characterId, previous);
      }

      // Try the original content too as a fallback
      final fallbackMatches = stateBlockPattern.allMatches(content).toList();
      if (fallbackMatches.isEmpty) {
        final fallbackLooseStatePanel = _extractLooseStatePanel(content);
        if (fallbackLooseStatePanel == null) {
          return null;
        }
        final lines = content.split(RegExp(r'\r?\n'));
        final rawBlock = lines
            .skip(fallbackLooseStatePanel.startLine)
            .take(fallbackLooseStatePanel.endLine -
                fallbackLooseStatePanel.startLine)
            .join('\n')
            .trim();
        return _parseRawBlock(rawBlock, characterId, previous);
      }
      return _parseFromMatches(fallbackMatches, characterId, previous);
    }

    return _parseFromMatches(matches, characterId, previous);
  }

  static GameStateSnapshot? _parseFromMatches(
    List<RegExpMatch> matches,
    String characterId,
    GameStateSnapshot previous,
  ) {
    final rawBlock = matches.last.group(1)?.trim() ?? '';
    return _parseRawBlock(rawBlock, characterId, previous);
  }

  static GameStateSnapshot? _parseRawBlock(
    String rawBlock,
    String characterId,
    GameStateSnapshot previous,
  ) {
    if (rawBlock.isEmpty) {
      return null;
    }

    // Strip leading option-like markers that may leak
    final safeBlock =
        rawBlock.replaceFirst(RegExp(r'^[A-F]\s*[|｜、:：]\s*'), '').trim();
    if (safeBlock.isEmpty) {
      return null;
    }

    final values = <String, dynamic>{};
    values.addAll(_parseJsonLike(safeBlock));
    values.addAll(_parseLooseLines(safeBlock));

    if (values.isEmpty) {
      return null;
    }

    final metrics = <String, int>{...previous.metrics};
    for (final entry in values.entries) {
      final numeric = _readInt(entry.value);
      if (numeric == null) {
        continue;
      }

      final key = _canonicalMetric(entry.key);
      if (key != null) {
        metrics[key] = numeric.clamp(0, key == '金钱' ? 999999 : 100);
      }
    }

    final inventory =
        _readList(values, const <String>['背包', '道具', '物品', 'inventory']) ??
            previous.inventory;
    final parsedStoryInventory = _readList(
          values,
          const <String>['剧情物品栏', '剧情物品', 'storyInventory'],
        ) ??
        const <String>[];
    final storyInventory = _mergeStoryItems(
      previous.storyInventory,
      inventory,
      parsedStoryInventory,
    );

    return previous.copyWith(
      characterId: characterId,
      updatedAt: DateTime.now(),
      location: _readString(values, const <String>['地点', '当前位置', 'location']) ??
          previous.location,
      timeLabel:
          _readString(values, const <String>['时间', '日期', '当前时间', 'time']) ??
              previous.timeLabel,
      status:
          _readString(values, const <String>['状态', '主角状态', '心情', 'status']) ??
              previous.status,
      mainTask: _readString(
            values,
            const <String>['主线任务', '当前任务', '任务', 'mainTask'],
          ) ??
          previous.mainTask,
      profileDetails: _readList(
            values,
            const <String>[
              '人物数据',
              '人物面板',
              '主角资料',
              '主角面板',
              '玩家面板',
              'profileDetails'
            ],
          ) ??
          previous.profileDetails,
      sideTasks: _readList(values, const <String>['支线任务', '支线', 'sideTasks']) ??
          previous.sideTasks,
      completedTasks: _readList(
              values, const <String>['已完成任务', '完成任务', 'completedTasks']) ??
          previous.completedTasks,
      inventory: inventory,
      storyInventory: storyInventory,
      eventTitle: _readString(
            values,
            const <String>['事件卡', '事件', '当前事件', 'event'],
          ) ??
          previous.eventTitle,
      eventDescription: _readString(
            values,
            const <String>['事件描述', '事件说明', 'eventDescription'],
          ) ??
          previous.eventDescription,
      relationshipNotes: _readList(
            values,
            const <String>['关系网', '人际关系', '关系记录', 'relationshipNotes'],
          ) ??
          previous.relationshipNotes,
      plotFlags: _readList(
            values,
            const <String>['重要伏笔', '剧情标记', '已触发事件', '剧情记录', 'plotFlags'],
          ) ??
          previous.plotFlags,
      npcChanges: _readList(
              values, const <String>['NPC变化', 'NPC印象', '关系变化', 'npcChanges']) ??
          previous.npcChanges,
      npcUpdates: _readNpcUpdates(values) ?? const <GameNpcUpdate>[],
      metrics: metrics,
    );
  }

  static List<StoryInventoryItem> _mergeStoryItems(
    List<StoryInventoryItem> existing,
    List<String> inventory,
    List<String> storyInventory,
  ) {
    final result = <StoryInventoryItem>[];
    final seen = <String>{};

    void add(StoryInventoryItem item) {
      final normalized = item.normalized();
      final key = normalized.name.trim().toLowerCase();
      if (key.isEmpty) {
        return;
      }
      if (seen.contains(key)) {
        final index = result.indexWhere(
          (entry) => entry.name.trim().toLowerCase() == key,
        );
        if (index != -1) {
          final current = result[index];
          result[index] = current.copyWith(
            description: normalized.description.trim().isEmpty
                ? current.description
                : normalized.description,
            effect: normalized.effect.trim().isEmpty
                ? current.effect
                : normalized.effect,
            source: normalized.source.trim().isEmpty
                ? current.source
                : normalized.source,
          );
        }
        return;
      }
      seen.add(key);
      result.add(normalized);
    }

    for (final item in existing) {
      add(item);
    }
    for (final name in inventory) {
      add(StoryInventoryItem.fromName(name, source: 'game_state'));
    }
    for (final raw in storyInventory) {
      add(_parseStoryItem(raw));
    }
    return result;
  }

  static StoryInventoryItem _parseStoryItem(String raw) {
    final parts = raw
        .split(RegExp(r'[｜|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return StoryInventoryItem.fromName(raw, source: 'game_state_story');
    }
    final description = parts.length >= 2 ? parts[1] : '';
    final effect = parts.length >= 3
        ? parts.sublist(2).join('｜').replaceFirst(RegExp(r'^用途\s*[:：]\s*'), '')
        : '';
    return StoryInventoryItem.fromName(
      parts.first,
      description: description,
      effect: effect,
      source: 'game_state_story',
    );
  }

  static Map<String, dynamic> _parseJsonLike(String rawBlock) {
    final trimmed = rawBlock.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return const <String, dynamic>{};
    }

    return const <String, dynamic>{};
  }

  static Map<String, String> _parseLooseLines(String rawBlock) {
    final result = <String, String>{};
    String? currentKey;
    final buffer = StringBuffer();

    void flush() {
      if (currentKey == null) {
        return;
      }
      final value = buffer.toString().trim();
      if (value.isNotEmpty) {
        result[currentKey!] = value;
      }
      currentKey = null;
      buffer.clear();
    }

    for (final rawLine in rawBlock.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty ||
          RegExp(r'^\[/?GAME_STATE\]$', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      if (RegExp(r'^\[/?CHOICES\]$', caseSensitive: false).hasMatch(line)) {
        break;
      }
      if (RegExp(r'^[A-F]\s*[|｜、:：]', caseSensitive: false).hasMatch(line)) {
        continue;
      }

      final emptyMatch = RegExp(r'^([^:=：]+?)\s*[:=：]\s*$').firstMatch(line);
      if (emptyMatch != null) {
        flush();
        currentKey = (emptyMatch.group(1) ?? '').trim();
        continue;
      }

      final match = RegExp(r'^([^:=：]+?)\s*[:=：]\s*(.+)$').firstMatch(line);
      if (match != null) {
        flush();
        currentKey = (match.group(1) ?? '').trim();
        buffer.write((match.group(2) ?? '').trim());
        continue;
      }

      if (currentKey != null) {
        buffer.write('\n$line');
      }
    }
    flush();

    return result;
  }

  static String? _readString(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = _findValue(values, key);
      if (value == null) {
        continue;
      }
      if (value is List) {
        final joined = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .join('、');
        if (joined.isNotEmpty) {
          return joined;
        }
      }
      final text = value.toString().trim();
      if (text.isNotEmpty && text != '无') {
        return text;
      }
    }
    return null;
  }

  static List<String>? _readList(
      Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = _findValue(values, key);
      if (value == null) {
        continue;
      }
      final list = value is List
          ? value.map((item) => item.toString().trim()).toList()
          : value
              .toString()
              .split(RegExp(r'[;；、,\n]'))
              .map((item) => item.replaceFirst(RegExp(r'^[-*]\s*'), '').trim())
              .toList();
      final cleaned =
          list.where((item) => item.isNotEmpty && item != '无').toList();
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    return null;
  }

  static List<GameNpcUpdate>? _readNpcUpdates(Map<String, dynamic> values) {
    for (final key in const <String>[
      'NPC更新',
      'NPC档案更新',
      'npcUpdates',
    ]) {
      final value = _findValue(values, key);
      if (value == null) {
        continue;
      }

      final parsed = <GameNpcUpdate>[];
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            final update =
                GameNpcUpdate.fromJson(Map<String, dynamic>.from(item));
            if (!update.isEmpty) {
              parsed.add(update);
            }
            continue;
          }
          final update = _parseNpcUpdateLine(item.toString());
          if (update != null) {
            parsed.add(update);
          }
        }
      } else {
        parsed.addAll(_parseNpcUpdateBlock(value.toString()));
      }

      if (parsed.isNotEmpty) {
        return parsed.take(12).toList(growable: false);
      }
    }
    return null;
  }

  static List<GameNpcUpdate> _parseNpcUpdateBlock(String value) {
    final lines = value
        .split(RegExp(r'\r?\n|；(?=\s*[^；|｜]+[:：=])'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line != '无')
        .toList(growable: false);

    final updates = <GameNpcUpdate>[];
    for (final line in lines) {
      final parsed = _parseNpcUpdateLine(line);
      if (parsed != null) {
        updates.add(parsed);
      }
    }
    return updates;
  }

  static GameNpcUpdate? _parseNpcUpdateLine(String value) {
    final raw = value
        .replaceFirst(RegExp(r'^[-*]\s*'), '')
        .replaceFirst(RegExp(r'^NPC\s*[:：=]\s*', caseSensitive: false), '')
        .trim();
    if (raw.isEmpty || raw == '无') {
      return null;
    }

    var name = '';
    var npcId = '';
    var description = '';
    var impression = '';
    int? affinity;
    int? affinityDelta;
    var lifecycle = '';
    var lifecycleReason = '';
    var proactiveMessage = '';

    final segments =
        raw.split(RegExp(r'[|｜]')).map((item) => item.trim()).where(
              (item) => item.isNotEmpty,
            );

    for (final segment in segments) {
      final field = RegExp(r'^([^:=：]+?)\s*[:=：]\s*(.+)$').firstMatch(segment);
      if (field == null) {
        if (name.isEmpty) {
          name = segment;
        }
        continue;
      }

      final key = _canonicalKey(field.group(1) ?? '');
      final text = (field.group(2) ?? '').trim();
      if (text.isEmpty) {
        continue;
      }

      if (key == '姓名' ||
          key == '名字' ||
          key == 'npc' ||
          key == 'name' ||
          key == '角色') {
        name = text;
      } else if (key == 'npcid' || key == 'id' || key == '角色id') {
        npcId = text;
      } else if (key.contains('简介') ||
          key.contains('人设') ||
          key.contains('描述') ||
          key == 'description') {
        description = text;
      } else if (key.contains('印象') ||
          key.contains('态度') ||
          key.contains('关系') ||
          key == 'impression') {
        impression = text;
      } else if (key.contains('好感变化') ||
          key == 'affinitydelta' ||
          key == 'favorabilitydelta') {
        affinityDelta = _readInt(text)?.clamp(-12, 12);
      } else if (key.contains('好感') ||
          key == 'affinity' ||
          key == 'favorability') {
        affinity = _readInt(text)?.clamp(-100, 100);
      } else if (key == '生命周期' ||
          key == '生命状态' ||
          key == 'lifecycle' ||
          key == 'lifestate') {
        lifecycle = text;
      } else if (key == '生命周期原因' || key == '状态原因' || key == 'lifecyclereason') {
        lifecycleReason = text;
      } else if (key.contains('主动消息') ||
          key.contains('私聊消息') ||
          key.contains('消息') ||
          key == 'message' ||
          key == 'proactivemessage') {
        proactiveMessage =
            NpcMessageClassifier.isDeliverableChatBubble(text) ? text : '';
      } else if (name.isEmpty) {
        name = (field.group(1) ?? '').trim();
        impression = text;
      }
    }

    if (name.isEmpty) {
      final match = RegExp(r'^([^:：=]+?)\s*[:：=]\s*(.+)$').firstMatch(raw);
      if (match != null) {
        name = (match.group(1) ?? '').trim();
        impression = (match.group(2) ?? '').trim();
      }
    }

    if (name.isEmpty) {
      return null;
    }

    return GameNpcUpdate(
      name: name,
      npcId: npcId,
      description: description,
      impression: impression,
      affinity: affinity,
      affinityDelta: affinityDelta,
      lifecycle: lifecycle,
      lifecycleReason: lifecycleReason,
      proactiveMessage: proactiveMessage,
    );
  }

  static dynamic _findValue(Map<String, dynamic> values, String key) {
    final canonical = _canonicalKey(key);
    for (final entry in values.entries) {
      if (_canonicalKey(entry.key) == canonical) {
        return entry.value;
      }
    }
    return null;
  }

  static String _canonicalKey(Object key) {
    return key.toString().toLowerCase().replaceAll(RegExp(r'[\s_：:|｜-]'), '');
  }

  static int? _readInt(dynamic value) {
    if (value is num) {
      return value.round();
    }
    final match = RegExp(r'-?\d+').firstMatch(value.toString());
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static String? _canonicalMetric(String key) {
    final canonical = _canonicalKey(key);
    if (canonical.contains('压力') || canonical == 'stress') {
      return '压力';
    }
    if (canonical.contains('精力') || canonical.contains('体力')) {
      return '精力';
    }
    if (canonical.contains('金钱') ||
        canonical.contains('钱') ||
        canonical.contains('零花钱') ||
        canonical == 'money') {
      return '金钱';
    }
    if (canonical.contains('声望')) {
      return '声望';
    }
    if (canonical.contains('好感')) {
      return '好感';
    }
    return null;
  }
}

class _LooseStatePanel {
  const _LooseStatePanel({
    required this.startLine,
    required this.endLine,
  });

  final int startLine;
  final int endLine;
}
