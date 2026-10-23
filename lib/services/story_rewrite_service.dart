import 'narrative_content.dart';
import 'dart:convert';
import '../models/story_continuity.dart';

class StoryRewriteService {
  const StoryRewriteService._();
  static List<StoryRewriteTarget> targets(String messageId, String raw,
      {String? npcId}) {
    final masked = NarrativeContent.maskHtmlForSelection(raw);
    final group = RegExp(r'\[GROUP_CHAT\]\s*([\s\S]*?)\s*\[/GROUP_CHAT\]',
            caseSensitive: false)
        .firstMatch(masked);
    if (group != null) {
      try {
        final decoded = jsonDecode(group.group(1)!);
        final rows = decoded is List ? decoded : storyMap(decoded)['messages'];
        if (rows is List) {
          return [
            for (var i = 0; i < rows.length; i++)
              if (storyMap(rows[i])['content'] is String &&
                  NarrativeContent.htmlDocuments(storyMap(rows[i])['content'])
                      .isEmpty)
                StoryRewriteTarget(
                    messageId: messageId,
                    content: storyMap(rows[i])['content'],
                    start: 0,
                    end: (storyMap(rows[i])['content'] as String).length,
                    groupIndex: i,
                    npcId: npcId)
          ];
        }
      } catch (_) {
        return [];
      }
    }
    final blocked = RegExp(
        r'\[(GAME_STATE|THEATER_PATCH|MAP_STATE|CHOICES)\][\s\S]*?\[/\1\]|```[\s\S]*?```|<!doctype[\s\S]*?</html>|<html[\s\S]*?</html>|\[/?BUBBLE\]',
        caseSensitive: false);
    final intervals = blocked.allMatches(masked).toList();
    final result = <StoryRewriteTarget>[];
    var offset = 0;
    void add(int end) {
      final text = masked.substring(offset, end);
      for (final match
          in RegExp(r'[^\r\n]+(?:\r?\n(?!\r?\n)[^\r\n]+)*').allMatches(text)) {
        final value = match.group(0)!;
        if (value.trim().isEmpty) continue;
        result.add(StoryRewriteTarget(
            messageId: messageId,
            content: raw,
            start: offset + match.start,
            end: offset + match.end,
            npcId: npcId));
      }
    }

    for (final match in intervals) {
      add(match.start);
      offset = match.end;
    }
    add(raw.length);
    return result;
  }

  static String replace(
      String raw, StoryRewriteTarget target, String replacement) {
    if (target.start < 0 ||
        target.end <= target.start ||
        target.end > target.content.length) {
      throw StateError('所选文字已失效。');
    }
    if (NarrativeContent.htmlDocuments(replacement).isNotEmpty ||
        RegExp(r'\[/?(?:GAME_STATE|THEATER_PATCH|MAP_STATE|CHOICES|BUBBLE|GROUP_CHAT)\]|```|<html|<!doctype',
                caseSensitive: false)
            .hasMatch(replacement)) {
      throw StateError('改写结果包含正文以外的结构，请重新生成。');
    }
    if (target.groupIndex == null) {
      if (raw != target.content) throw StateError('原文已变化，请重新选择。');
      return raw.replaceRange(target.start, target.end, replacement);
    }
    final group = RegExp(r'\[GROUP_CHAT\]\s*([\s\S]*?)\s*\[/GROUP_CHAT\]',
            caseSensitive: false)
        .firstMatch(raw);
    if (group == null) throw StateError('群聊原文已变化。');
    final decoded = jsonDecode(group.group(1)!);
    final rows = decoded is List ? decoded : storyMap(decoded)['messages'];
    if (rows is! List || target.groupIndex! >= rows.length) {
      throw StateError('这条群聊已经不存在。');
    }
    final row = storyMap(rows[target.groupIndex!]);
    if (row['content'] != target.content) throw StateError('原文已变化，请重新选择。');
    row['content'] =
        target.content.replaceRange(target.start, target.end, replacement);
    rows[target.groupIndex!] = row;
    return raw.replaceRange(group.start, group.end,
        '[GROUP_CHAT]\n${jsonEncode(decoded)}\n[/GROUP_CHAT]');
  }
}
