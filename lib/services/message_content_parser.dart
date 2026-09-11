import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'game_state_parser.dart';
import 'html_sanitizer.dart';

enum MessageContentBlockType {
  markdown,
  code,
  runnablePreview,
}

@immutable
class MessageCodeSnippet {
  const MessageCodeSnippet({
    required this.language,
    required this.code,
  });

  final String language;
  final String code;
}

@immutable
class MessageChoice {
  const MessageChoice({
    required this.index,
    required this.label,
  });

  final String index;
  final String label;
}

@immutable
class MessageContentBlock {
  const MessageContentBlock.markdown(this.content)
      : type = MessageContentBlockType.markdown,
        snippets = const <MessageCodeSnippet>[],
        language = '';

  const MessageContentBlock.code({
    required this.language,
    required this.content,
  })  : type = MessageContentBlockType.code,
        snippets = const <MessageCodeSnippet>[];

  const MessageContentBlock.runnablePreview({
    required this.content,
    required this.snippets,
  })  : type = MessageContentBlockType.runnablePreview,
        language = '';

  final MessageContentBlockType type;
  final String content;
  final String language;
  final List<MessageCodeSnippet> snippets;
}

@immutable
class GroupChatMessage {
  const GroupChatMessage({
    required this.type,
    required this.speaker,
    required this.content,
    this.id = '',
    this.speakerId = '',
    this.replyTo = '',
  });

  final String type;
  final String speaker;
  final String content;
  final String id;
  final String speakerId;
  final String replyTo;

  bool get isNarration => type == 'narration';
}

@immutable
class ParsedMessageContent {
  const ParsedMessageContent({
    required this.blocks,
    required this.choices,
    this.segments = const <List<MessageContentBlock>>[],
    this.groupChatMessages = const <GroupChatMessage>[],
  });

  final List<MessageContentBlock> blocks;
  final List<MessageChoice> choices;
  final List<List<MessageContentBlock>> segments;
  final List<GroupChatMessage> groupChatMessages;
}

class MessageContentParser {
  const MessageContentParser._();

  static const int _maxCacheEntries = 120;
  static const int _maxCacheSourceChars = 1200000;
  static const int _maxCacheableContentLength = 180000;
  static final Map<String, _ParsedMessageCacheEntry> _structuredCache =
      <String, _ParsedMessageCacheEntry>{};
  static int _cachedSourceChars = 0;

  static final RegExp _fencedCodePattern = RegExp(
    r'```([a-zA-Z0-9_+-]*)[ \t]*\r?\n([\s\S]*?)```',
    multiLine: true,
  );

  static final RegExp _choicesPattern = RegExp(
    r'\[CHOICES\]\s*([\s\S]*?)\s*\[/CHOICES\]',
    caseSensitive: false,
  );

  static final RegExp _bubblePattern = RegExp(
    r'\[BUBBLE\]\s*([\s\S]*?)\s*\[/BUBBLE\]',
    caseSensitive: false,
  );

  static final RegExp _groupChatPattern = RegExp(
    r'\[GROUP_CHAT\]\s*([\s\S]*?)\s*\[/GROUP_CHAT\]',
    caseSensitive: false,
  );

  static List<MessageContentBlock> parse(String content) {
    return parseStructured(content).blocks;
  }

  static ParsedMessageContent parseStructured(
    String content, {
    bool cache = true,
  }) {
    if (cache &&
        content.length <= _maxCacheableContentLength &&
        content.trim().isNotEmpty) {
      final fingerprint = _contentFingerprint(content);
      final cacheKey = '${content.length}:$fingerprint';
      final cached = _structuredCache.remove(cacheKey);
      if (cached != null &&
          cached.sourceLength == content.length &&
          cached.sourceHash == fingerprint) {
        _structuredCache[cacheKey] = cached;
        return cached.content;
      }
      final parsed = _parseStructuredUncached(content);
      _rememberParsed(cacheKey, content, fingerprint, parsed);
      return parsed;
    }

    return _parseStructuredUncached(content);
  }

  static ParsedMessageContent _parseStructuredUncached(String content) {
    final groupMessages = parseGroupChatMessages(content);
    final normalizedContent = _stripOpenGroupChatBlock(
      _stripAssistantMetaNarration(
        GameStateParser.stripStateBlocks(normalizeChoiceBlocks(content))
            .replaceAll(_groupChatPattern, ''),
      ),
    );
    if (normalizedContent.trim().isEmpty) {
      return ParsedMessageContent(
        blocks: <MessageContentBlock>[],
        choices: <MessageChoice>[],
        segments: <List<MessageContentBlock>>[],
        groupChatMessages: groupMessages,
      );
    }

    final extractedChoices = <MessageChoice>[];
    final cleanedContent =
        normalizedContent.replaceAllMapped(_choicesPattern, (match) {
      final block = match.group(1) ?? '';
      extractedChoices.addAll(_parseChoices(block));
      return '';
    });

    final segments = _parseSegments(cleanedContent);
    final blocks = segments.isEmpty
        ? _parseBlocks(cleanedContent)
        : segments.expand((segment) => segment).toList(growable: false);

    return ParsedMessageContent(
      blocks: blocks,
      segments: segments,
      choices: extractedChoices,
      groupChatMessages: groupMessages,
    );
  }

  static void _rememberParsed(
    String cacheKey,
    String source,
    int sourceHash,
    ParsedMessageContent parsed,
  ) {
    if (_structuredCache.containsKey(cacheKey)) {
      final previous = _structuredCache.remove(cacheKey)!;
      _cachedSourceChars -= previous.sourceLength;
    }
    final entry = _ParsedMessageCacheEntry(
      sourceLength: source.length,
      sourceHash: sourceHash,
      content: parsed,
    );
    _structuredCache[cacheKey] = entry;
    _cachedSourceChars += source.length;

    while (_structuredCache.length > _maxCacheEntries ||
        _cachedSourceChars > _maxCacheSourceChars) {
      final oldestKey = _structuredCache.keys.first;
      final oldest = _structuredCache.remove(oldestKey);
      if (oldest == null) {
        break;
      }
      _cachedSourceChars -= oldest.sourceLength;
    }
  }

  static int _contentFingerprint(String content) {
    var hash = 0x811c9dc5;
    for (var index = 0; index < content.length; index++) {
      hash ^= content.codeUnitAt(index);
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  static String visibleStreamingText(String content) {
    var text = _stripAssistantMetaNarration(
      GameStateParser.stripStateBlocks(normalizeChoiceBlocks(content))
          .replaceAll(_groupChatPattern, ''),
    );
    text = _stripOpenGroupChatBlock(text);
    text = text.replaceAll(_choicesPattern, '');
    text = text.replaceAll(_fencedCodePattern, '');
    text = text.replaceAll(
      RegExp(r'```[a-zA-Z0-9_+-]*[ \t]*(?:\r?\n)?[\s\S]*$'),
      '',
    );

    final htmlStart = RegExp(
      r'<!doctype|<html\b|<head\b|<body\b|<style\b|<script\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (htmlStart != null) {
      text = text.substring(0, htmlStart.start);
    }

    return text.trimRight();
  }

  static String contextTextForModel(String content) {
    var text = _stripAssistantMetaNarration(
      GameStateParser.stripStateBlocks(normalizeChoiceBlocks(content))
          .replaceAllMapped(_groupChatPattern, _groupChatReplaySummary),
    );
    text = _stripOpenGroupChatBlock(text);
    text = text.replaceAll(_choicesPattern, '');
    text = text.replaceAllMapped(_fencedCodePattern, (match) {
      final language = (match.group(1) ?? '').trim().toLowerCase();
      final code = (match.group(2) ?? '').trim();
      final looksLikeHtml = language == 'html' ||
          language == 'htm' ||
          HtmlSanitizer.looksLikeHtml(code);
      if (looksLikeHtml) {
        return '\n[HTML 面板已在本地保存，历史上下文省略。]\n';
      }
      if (code.length > 1200) {
        return '\n[长代码块已在历史上下文省略。]\n';
      }
      return match.group(0) ?? '';
    });

    final htmlStart = RegExp(
      r'<!doctype|<html\b|<head\b|<body\b|<style\b|<script\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (htmlStart != null) {
      text = text.substring(0, htmlStart.start).trimRight();
      if (text.isNotEmpty) {
        text = '$text\n[HTML 面板已在本地保存，历史上下文省略。]';
      }
    }

    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String _stripOpenGroupChatBlock(String content) {
    final start =
        RegExp(r'\[GROUP_CHAT\]', caseSensitive: false).firstMatch(content);
    if (start == null) {
      return content;
    }
    final end = RegExp(r'\[/GROUP_CHAT\]', caseSensitive: false)
        .firstMatch(content.substring(start.end));
    if (end == null) {
      return content.substring(0, start.start).trimRight();
    }
    return content;
  }

  static String normalizeGroupChatBlocks(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty || _groupChatPattern.hasMatch(trimmed)) {
      return content;
    }

    final decoded = _decodeLooseJson(trimmed);
    if (decoded is Map && _looksLikeGroupChatPayload(decoded)) {
      final encoded = const JsonEncoder.withIndent('  ').convert(decoded);
      return '[GROUP_CHAT]\n$encoded\n[/GROUP_CHAT]';
    }

    return content;
  }

  static List<GroupChatMessage> parseGroupChatMessages(String content) {
    final messages = <GroupChatMessage>[];
    for (final match in _groupChatPattern.allMatches(content)) {
      final block = (match.group(1) ?? '').trim();
      messages.addAll(_parseGroupChatJson(block));
    }
    if (messages.isNotEmpty) {
      return messages;
    }

    final decoded = _decodeLooseJson(content.trim());
    if (decoded is Map && _looksLikeGroupChatPayload(decoded)) {
      return _messagesFromGroupChatPayload(decoded);
    }
    return _parseStreamingGroupChatMessages(content);
  }

  static bool hasGroupChatBlock(String content) {
    return parseGroupChatMessages(content).isNotEmpty;
  }

  static List<GroupChatMessage> _parseGroupChatJson(String block) {
    final decoded = _decodeLooseJson(block);
    if (decoded is! Map) {
      return const <GroupChatMessage>[];
    }
    return _messagesFromGroupChatPayload(decoded);
  }

  static List<GroupChatMessage> _messagesFromGroupChatPayload(Map payload) {
    final rawMessages = payload['messages'] ??
        payload['group_messages'] ??
        payload['groupMessages'];
    if (rawMessages is! List) {
      return const <GroupChatMessage>[];
    }

    final result = <GroupChatMessage>[];
    for (final raw in rawMessages) {
      final message = _groupChatMessageFromRaw(raw);
      if (message != null) {
        result.add(message);
      }
    }
    return result.take(24).toList(growable: false);
  }

  static GroupChatMessage? _groupChatMessageFromRaw(dynamic raw) {
    if (raw is Map) {
      final rawType = (raw['type'] ?? raw['role'] ?? '').toString().trim();
      final speaker = (raw['speaker'] ?? raw['name'] ?? '').toString().trim();
      final content =
          (raw['content'] ?? raw['message'] ?? raw['text']).toString().trim();
      final id = (raw['id'] ?? raw['messageId'] ?? '').toString().trim();
      final speakerId =
          (raw['speakerId'] ?? raw['speaker_id'] ?? '').toString().trim();
      final replyTo =
          (raw['replyTo'] ?? raw['reply_to'] ?? '').toString().trim();
      if (content.isEmpty) {
        return null;
      }
      final normalizedType = rawType.toLowerCase();
      final isNarration = normalizedType == 'narration' ||
          normalizedType == 'narrator' ||
          normalizedType == 'narrative' ||
          rawType == '旁白' ||
          speaker == '旁白';
      return GroupChatMessage(
        type: isNarration ? 'narration' : 'npc',
        speaker: isNarration ? '旁白' : (speaker.isEmpty ? 'NPC' : speaker),
        content: content,
        id: id,
        speakerId: isNarration ? 'narrator' : speakerId,
        replyTo: replyTo,
      );
    }

    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final match = RegExp(r'^([^:：]{1,24})[:：]\s*([\s\S]+)$').firstMatch(text);
    if (match == null) {
      return GroupChatMessage(
        type: 'narration',
        speaker: '旁白',
        content: text,
      );
    }
    final speaker = (match.group(1) ?? '').trim();
    final content = (match.group(2) ?? '').trim();
    if (content.isEmpty) {
      return null;
    }
    final isNarration = speaker == '旁白';
    return GroupChatMessage(
      type: isNarration ? 'narration' : 'npc',
      speaker: isNarration ? '旁白' : speaker,
      content: content,
    );
  }

  static List<GroupChatMessage> _parseStreamingGroupChatMessages(
    String content,
  ) {
    final groupStart = RegExp(
      r'\[GROUP_CHAT\]',
      caseSensitive: false,
    ).firstMatch(content);
    if (groupStart == null) {
      return const <GroupChatMessage>[];
    }

    final groupContent = content.substring(groupStart.end);
    final messagesStart = RegExp(
      r'"messages"\s*:\s*\[',
      caseSensitive: false,
    ).firstMatch(groupContent);
    if (messagesStart == null) {
      return const <GroupChatMessage>[];
    }

    final messages = <GroupChatMessage>[];
    var objectStart = -1;
    var objectDepth = 0;
    var inString = false;
    var escaped = false;

    for (var index = messagesStart.end; index < groupContent.length; index++) {
      final codeUnit = groupContent.codeUnitAt(index);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (codeUnit == 0x5c) {
          escaped = true;
        } else if (codeUnit == 0x22) {
          inString = false;
        }
        continue;
      }

      if (codeUnit == 0x22) {
        inString = true;
        continue;
      }
      if (codeUnit == 0x7b) {
        if (objectDepth == 0) {
          objectStart = index;
        }
        objectDepth += 1;
        continue;
      }
      if (codeUnit != 0x7d || objectDepth == 0) {
        continue;
      }

      objectDepth -= 1;
      if (objectDepth != 0 || objectStart < 0) {
        continue;
      }
      try {
        final raw = jsonDecode(groupContent.substring(objectStart, index + 1));
        final message = _groupChatMessageFromRaw(raw);
        if (message != null) {
          messages.add(message);
        }
      } catch (_) {
        // The current object can still be incomplete while streaming.
      }
      objectStart = -1;
      if (messages.length >= 24) {
        break;
      }
    }
    return messages;
  }

  static dynamic _decodeLooseJson(String value) {
    var cleaned = value.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z0-9_-]*\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }

    try {
      return jsonDecode(cleaned);
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          return jsonDecode(cleaned.substring(start, end + 1));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  static bool _looksLikeGroupChatPayload(Map payload) {
    final mode = payload['mode']?.toString().trim();
    final rawMessages = payload['messages'] ??
        payload['group_messages'] ??
        payload['groupMessages'];
    return rawMessages is List &&
        (mode == 'large_group_chat' ||
            payload.containsKey('group_messages') ||
            payload.containsKey('groupMessages') ||
            rawMessages.any((item) =>
                item is Map &&
                (item.containsKey('speaker') || item.containsKey('content'))));
  }

  static String _groupChatReplaySummary(Match match) {
    final messages = _parseGroupChatJson((match.group(1) ?? '').trim());
    if (messages.isEmpty) {
      return '\n[大型群聊消息流已在本地保存，历史上下文省略。]\n';
    }
    final summary = messages
        .take(12)
        .map((message) => '${message.speaker}：${message.content}')
        .join('\n');
    return '\n[上一轮大型群聊消息流摘要]\n$summary\n';
  }

  static String assistantReplayPrefixForModel(
    String content, {
    int maxChars = 3600,
  }) {
    var text = visibleStreamingText(content).trim();
    if (text.isEmpty) {
      text = contextTextForModel(content);
    }
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (text.length <= maxChars) {
      return text;
    }
    final clipped = text.substring(0, maxChars);
    final paragraphBreak = clipped.lastIndexOf('\n\n');
    if (paragraphBreak >= 800) {
      return '${clipped.substring(0, paragraphBreak).trimRight()}\n\n[正文后段已省略]';
    }
    final sentenceBreak = RegExp(r'[。！？!?]\s*')
        .allMatches(clipped)
        .map((match) => match.end)
        .lastWhere((end) => end >= 800, orElse: () => -1);
    if (sentenceBreak >= 800) {
      return '${clipped.substring(0, sentenceBreak).trimRight()}\n\n[正文后段已省略]';
    }
    return '${clipped.trimRight()}\n\n[正文后段已省略]';
  }

  static String normalizeChoiceBlocks(String content) {
    if (content.trim().isEmpty) {
      return content;
    }

    final tagged = _normalizeTaggedChoiceBlock(content);
    if (tagged != null) {
      return tagged;
    }

    final trailing = _normalizeTrailingChoiceLines(content);
    return trailing ?? content;
  }

  static String _stripAssistantMetaNarration(String content) {
    if (content.trim().isEmpty) {
      return content;
    }
    final paragraphs = content.split(RegExp(r'\n{2,}'));
    final kept = <String>[];
    for (final paragraph in paragraphs) {
      final lines = paragraph.split(RegExp(r'\r?\n'));
      final filteredLines = lines
          .where((line) => !_looksLikeAssistantMetaNarration(line))
          .toList(growable: false);
      final filtered = filteredLines.join('\n').trim();
      if (filtered.isNotEmpty && !_looksLikeAssistantMetaNarration(filtered)) {
        kept.add(filtered);
      }
    }
    return kept.join('\n\n').trimRight();
  }

  static bool _looksLikeAssistantMetaNarration(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty || compact.length > 220) {
      return false;
    }
    final hasHtmlWord =
        RegExp(r'HTML|html|代码块|```', caseSensitive: false).hasMatch(compact);
    if (!hasHtmlWord) {
      return false;
    }
    var hits = 0;
    for (final marker in const <String>[
      '自包含',
      '手机竖屏',
      '适配手机',
      '状态面板',
      '互动剧情面板',
      '可视化面板',
      '用于本轮',
      '用于展示',
      '剧情展示',
      '完整文档',
      '浏览',
    ]) {
      if (compact.contains(marker)) {
        hits += 1;
      }
    }
    return hits >= 2;
  }

  static String buildRunnableDocument(
    List<MessageCodeSnippet> snippets, {
    String? fallbackHtml,
  }) {
    final htmlSnippets = <String>[];
    final cssSnippets = <String>[];
    final jsSnippets = <String>[];

    for (final snippet in snippets) {
      final language = snippet.language.trim().toLowerCase();
      final code = snippet.code.trim();
      if (code.isEmpty) {
        continue;
      }

      if (language == 'css') {
        cssSnippets.add(code);
        continue;
      }

      if (language == 'js' || language == 'javascript') {
        jsSnippets.add(code);
        continue;
      }

      if (language == 'html' ||
          language == 'htm' ||
          language.isEmpty ||
          HtmlSanitizer.looksLikeHtml(code)) {
        htmlSnippets.add(code);
      }
    }

    final rawHtml = htmlSnippets.isEmpty
        ? (fallbackHtml?.trim() ?? '')
        : htmlSnippets.join('\n\n');
    final css = cssSnippets.join('\n\n');
    final js = jsSnippets.join('\n\n');

    if (rawHtml.isEmpty) {
      return '';
    }

    final hasDocumentShell = RegExp(
      r'<!doctype|<html\b|<head\b|<body\b',
      caseSensitive: false,
    ).hasMatch(rawHtml);

    if (hasDocumentShell) {
      var document = rawHtml;

      if (css.isNotEmpty) {
        final styleTag = '<style>\n$css\n</style>';
        if (RegExp(r'</head>', caseSensitive: false).hasMatch(document)) {
          document = document.replaceFirst(
            RegExp(r'</head>', caseSensitive: false),
            '$styleTag\n</head>',
          );
        } else {
          document = '$styleTag\n$document';
        }
      }

      if (js.isNotEmpty) {
        final scriptTag = '<script>\n$js\n</script>';
        if (RegExp(r'</body>', caseSensitive: false).hasMatch(document)) {
          document = document.replaceFirst(
            RegExp(r'</body>', caseSensitive: false),
            '$scriptTag\n</body>',
          );
        } else {
          document = '$document\n$scriptTag';
        }
      }

      return document;
    }

    return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      min-height: 100%;
      background: #ffffff;
    }
    $css
  </style>
</head>
<body>
$rawHtml
  ${js.isNotEmpty ? '<script>\n$js\n</script>' : ''}
</body>
</html>
''';
  }

  static double estimatePreviewHeight(String document) {
    final lowered = document.toLowerCase();
    if (lowered.contains('max-width: 480px') ||
        lowered.contains('viewport') ||
        lowered.contains('status-bar') ||
        lowered.contains('mobile')) {
      return 720;
    }

    if (document.length > 5000) {
      return 680;
    }

    if (document.length > 2400) {
      return 560;
    }

    return 420;
  }

  static List<MessageChoice> _parseChoices(String rawBlock) {
    return _parseChoicesLoose(rawBlock);
  }

  static String? _normalizeTaggedChoiceBlock(String content) {
    final startMatch = RegExp(
      r'\[CHOICES\]',
      caseSensitive: false,
    ).firstMatch(content);
    if (startMatch == null) {
      return null;
    }

    final before = content.substring(0, startMatch.start).trimRight();
    final afterStart = content.substring(startMatch.end);
    final endMatch = RegExp(
      r'\[/?CHOICES\]',
      caseSensitive: false,
    ).firstMatch(afterStart);
    final rawBlock =
        endMatch == null ? afterStart : afterStart.substring(0, endMatch.start);
    final tail =
        endMatch == null ? '' : afterStart.substring(endMatch.end).trimRight();
    final choices = _parseChoicesLoose(rawBlock);
    if (choices.isEmpty) {
      return content;
    }

    final normalized = _joinNormalizedChoices(before, choices);
    return tail.isEmpty ? normalized : '$normalized\n\n$tail';
  }

  static String? _normalizeTrailingChoiceLines(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    var firstChoiceLine = -1;
    for (var index = 0; index < lines.length; index++) {
      if (_letterChoiceLinePattern.hasMatch(lines[index].trim())) {
        firstChoiceLine = index;
        break;
      }
    }

    if (firstChoiceLine == -1) {
      return null;
    }

    final before = lines.take(firstChoiceLine).join('\n').trimRight();
    final rawBlock = lines.skip(firstChoiceLine).join('\n');
    final choices = _parseChoicesLoose(rawBlock);
    if (choices.length < 2) {
      return null;
    }

    return _joinNormalizedChoices(before, choices);
  }

  static String _joinNormalizedChoices(
    String before,
    List<MessageChoice> choices,
  ) {
    final normalizedChoices =
        choices.map((choice) => '${choice.index}|${choice.label}').join('\n');
    final prefix = before.trim().isEmpty ? '' : '${before.trimRight()}\n\n';
    return '$prefix[CHOICES]\n$normalizedChoices\n[/CHOICES]';
  }

  static final RegExp _choiceLinePattern = RegExp(
    r'^([A-Fa-f]|[1-6])\s*(?:[|｜:：.．、\)\）-]|\s+)\s*(.+)$',
    caseSensitive: false,
  );

  static final RegExp _letterChoiceLinePattern = RegExp(
    r'^([A-Fa-f])\s*(?:[|｜:：.．、\)\）-]|\s+)\s*(.+)$',
    caseSensitive: false,
  );

  static List<MessageChoice> _parseChoicesLoose(String rawBlock) {
    final choices = <MessageChoice>[];
    for (final rawLine in rawBlock.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty ||
          RegExp(r'^\[/?CHOICES\]$', caseSensitive: false).hasMatch(line)) {
        continue;
      }

      final match = _choiceLinePattern.firstMatch(line);
      if (match == null) {
        if (choices.isNotEmpty) {
          final previous = choices.removeLast();
          choices.add(
            MessageChoice(
              index: previous.index,
              label: '${previous.label} $line'.trim(),
            ),
          );
        }
        continue;
      }

      final index = (match.group(1) ?? '').trim().toUpperCase();
      final label = (match.group(2) ?? '').trim();
      final isSupportedMarker = RegExp(r'^[A-F1-6]$').hasMatch(index);
      if (!isSupportedMarker || label.isEmpty) {
        continue;
      }

      choices.add(MessageChoice(index: index, label: label));
    }

    return choices;
  }

  static List<List<MessageContentBlock>> _parseSegments(String content) {
    final matches = _bubblePattern.allMatches(content).toList();
    if (matches.isEmpty) {
      return const <List<MessageContentBlock>>[];
    }

    final segments = <List<MessageContentBlock>>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        final leading = content.substring(cursor, match.start).trim();
        if (leading.isNotEmpty) {
          final leadingBlocks = _parseBlocks(leading);
          if (leadingBlocks.isNotEmpty) {
            segments.add(leadingBlocks);
          }
        }
      }

      final bubbleContent = (match.group(1) ?? '').trim();
      if (bubbleContent.isNotEmpty) {
        final blocks = _parseBlocks(bubbleContent);
        if (blocks.isNotEmpty) {
          segments.add(blocks);
        }
      }
      cursor = match.end;
    }

    if (cursor < content.length) {
      final trailing = content.substring(cursor).trim();
      if (trailing.isNotEmpty) {
        final trailingBlocks = _parseBlocks(trailing);
        if (trailingBlocks.isNotEmpty) {
          segments.add(trailingBlocks);
        }
      }
    }

    return segments;
  }

  static List<MessageContentBlock> _parseBlocks(String content) {
    if (content.trim().isEmpty) {
      return const <MessageContentBlock>[];
    }

    final matches = _fencedCodePattern.allMatches(content).toList();
    if (matches.isEmpty) {
      if (HtmlSanitizer.looksLikeHtml(content)) {
        return <MessageContentBlock>[
          MessageContentBlock.runnablePreview(
            content: buildRunnableDocument(
              const <MessageCodeSnippet>[
                MessageCodeSnippet(language: 'html', code: ''),
              ],
              fallbackHtml: content,
            ),
            snippets: <MessageCodeSnippet>[
              MessageCodeSnippet(language: 'html', code: content),
            ],
          ),
        ];
      }

      return <MessageContentBlock>[
        MessageContentBlock.markdown(content.trim())
      ];
    }

    final blocks = <MessageContentBlock>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        final text = content.substring(cursor, match.start);
        if (text.trim().isNotEmpty) {
          blocks.add(MessageContentBlock.markdown(text.trim()));
        }
      }

      final language = (match.group(1) ?? '').trim().toLowerCase();
      final code = (match.group(2) ?? '').trim();
      if (code.isNotEmpty) {
        blocks.add(
          MessageContentBlock.code(
            language: language,
            content: code,
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < content.length) {
      final trailing = content.substring(cursor);
      if (trailing.trim().isNotEmpty) {
        blocks.add(MessageContentBlock.markdown(trailing.trim()));
      }
    }

    return _mergeRunnableBlocks(blocks);
  }

  static List<MessageContentBlock> _mergeRunnableBlocks(
    List<MessageContentBlock> blocks,
  ) {
    final merged = <MessageContentBlock>[];
    var index = 0;

    while (index < blocks.length) {
      final block = blocks[index];
      if (block.type != MessageContentBlockType.code) {
        merged.add(block);
        index += 1;
        continue;
      }

      final group = <MessageCodeSnippet>[];
      var cursor = index;
      while (cursor < blocks.length &&
          blocks[cursor].type == MessageContentBlockType.code) {
        final candidate = blocks[cursor];
        group.add(
          MessageCodeSnippet(
            language: candidate.language,
            code: candidate.content,
          ),
        );
        cursor += 1;
      }

      final hasRunnableHtml = group.any(
        (snippet) =>
            snippet.language == 'html' ||
            snippet.language == 'htm' ||
            HtmlSanitizer.looksLikeHtml(snippet.code),
      );

      if (hasRunnableHtml) {
        final document = buildRunnableDocument(group);
        if (document.isNotEmpty) {
          merged.add(
            MessageContentBlock.runnablePreview(
              content: document,
              snippets: group,
            ),
          );
        }
      } else {
        for (final snippet in group) {
          merged.add(
            MessageContentBlock.code(
              language: snippet.language,
              content: snippet.code,
            ),
          );
        }
      }

      index = cursor;
    }

    return merged;
  }
}

class _ParsedMessageCacheEntry {
  const _ParsedMessageCacheEntry({
    required this.sourceLength,
    required this.sourceHash,
    required this.content,
  });

  final int sourceLength;
  final int sourceHash;
  final ParsedMessageContent content;
}
