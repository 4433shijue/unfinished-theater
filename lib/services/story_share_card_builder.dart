import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'message_content_parser.dart';

class StoryShareCardBuilder {
  const StoryShareCardBuilder._();

  static String buildHtml({
    required String title,
    required String assistantName,
    required List<ChatMessage> messages,
    required AppThemePalette palette,
    required String themeLabel,
  }) {
    final escapedTitle = const HtmlEscape().convert(title);
    final escapedAssistantName = const HtmlEscape().convert(assistantName);
    final theme = _ShareTheme.fromPalette(palette);
    final selected = _selectMessages(messages);
    final lead = selected.isEmpty
        ? '这张剧情卡还没有内容。'
        : _plainText(selected.last.content, limit: 96);
    final messageHtml = selected.map((message) {
      final isUser = message.role == ChatRole.user;
      final author = isUser ? '你' : assistantName;
      final body = _messageBody(message);
      return '''
<article class="message ${isUser ? 'user' : 'assistant'}">
  <div class="marker">${isUser ? 'YOU' : 'AI'}</div>
  <div class="bubble">
    <div class="author">${const HtmlEscape().convert(author)}</div>
    <div class="content">$body</div>
    <div class="meta">${_formatTimestamp(message.timestamp)}</div>
  </div>
</article>
''';
    }).join('\n');

    return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$escapedTitle</title>
  <style>
    :root {
      --bg-1: ${theme.bg1};
      --bg-2: ${theme.bg2};
      --bg-3: ${theme.bg3};
      --bg-4: ${theme.bg4};
      --primary: ${theme.primary};
      --secondary: ${theme.secondary};
      --accent: ${theme.accent};
      --soft: ${theme.soft};
      --line: ${theme.line};
      --ink: #252126;
      --muted: #6d6570;
      --paper: rgba(255, 255, 255, 0.88);
      --shadow: rgba(36, 28, 34, 0.12);
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      background:
        linear-gradient(120deg, rgba(255, 255, 255, 0.55), rgba(255, 255, 255, 0.12)),
        linear-gradient(135deg, var(--bg-1), var(--bg-2) 35%, var(--bg-3) 70%, var(--bg-4));
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
    }

    .page {
      width: min(980px, calc(100% - 28px));
      margin: 0 auto;
      padding: 28px 0 42px;
    }

    .card {
      overflow: hidden;
      border: 1px solid var(--line);
      border-radius: 8px;
      background:
        linear-gradient(90deg, rgba(255, 255, 255, 0.68), rgba(255, 255, 255, 0.88)),
        var(--paper);
      box-shadow: 0 24px 72px var(--shadow);
    }

    .masthead {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 18px;
      align-items: end;
      padding: 28px 30px 20px;
      border-bottom: 1px solid var(--line);
    }

    .issue {
      color: var(--primary);
      font-family: Georgia, "Times New Roman", serif;
      font-size: 12px;
      text-transform: uppercase;
    }

    h1 {
      margin: 6px 0 0;
      font-family: Georgia, "Times New Roman", "SimSun", serif;
      font-size: clamp(34px, 7vw, 64px);
      font-weight: 500;
      line-height: 1.02;
      letter-spacing: 0;
    }

    .deck {
      max-width: 44em;
      margin: 12px 0 0;
      color: var(--muted);
      font-family: Georgia, "Times New Roman", "SimSun", serif;
      font-size: 17px;
      line-height: 1.8;
    }

    .badge {
      justify-self: end;
      min-width: 120px;
      padding: 12px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.58);
      color: var(--muted);
      font-size: 12px;
      line-height: 1.6;
      text-align: right;
    }

    .messages {
      display: grid;
      gap: 16px;
      padding: 24px 30px 30px;
    }

    .message {
      display: grid;
      grid-template-columns: 58px minmax(0, 1fr);
      gap: 14px;
      align-items: start;
    }

    .message.user {
      grid-template-columns: minmax(0, 1fr) 58px;
    }

    .message.user .marker {
      order: 2;
    }

    .marker {
      display: grid;
      place-items: center;
      width: 58px;
      height: 58px;
      border-radius: 50%;
      background: linear-gradient(135deg, var(--primary), var(--secondary));
      color: #fff;
      font-size: 12px;
      font-weight: 700;
      box-shadow: 0 12px 26px color-mix(in srgb, var(--primary) 18%, transparent);
    }

    .bubble {
      min-width: 0;
      padding: 16px 18px 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.74);
    }

    .message.user .bubble {
      background: color-mix(in srgb, var(--primary) 12%, white);
      border-color: color-mix(in srgb, var(--primary) 42%, var(--line));
    }

    .author {
      margin-bottom: 8px;
      color: var(--primary);
      font-weight: 700;
    }

    .content {
      color: #2c282d;
      font-family: Georgia, "Times New Roman", "SimSun", serif;
      font-size: 16px;
      line-height: 1.9;
      word-break: break-word;
      white-space: pre-wrap;
    }

    .content p {
      margin: 0 0 0.9em;
    }

    .content p:last-child {
      margin-bottom: 0;
    }

    .choice-list {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 8px;
      margin-top: 12px;
    }

    .choice {
      padding: 10px 12px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.62);
      color: var(--muted);
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      font-size: 13px;
      line-height: 1.45;
    }

    .choice b {
      margin-right: 6px;
      color: var(--primary);
      font-family: Georgia, "Times New Roman", serif;
      font-size: 18px;
      font-weight: 500;
    }

    .meta {
      margin-top: 10px;
      color: var(--muted);
      font-size: 12px;
    }

    .footer {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      padding: 14px 30px;
      border-top: 1px solid var(--line);
      color: var(--muted);
      font-size: 12px;
      line-height: 1.5;
    }

    @media (max-width: 680px) {
      .masthead,
      .message,
      .message.user,
      .footer {
        grid-template-columns: 1fr;
      }

      .message.user .marker {
        order: 0;
      }

      .badge {
        justify-self: start;
        text-align: left;
      }

      .choice-list {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <main class="page">
    <section class="card">
      <header class="masthead">
        <div>
          <span class="issue">Story share card · $themeLabel</span>
          <h1>$escapedTitle</h1>
          <p class="deck">${const HtmlEscape().convert(lead)}</p>
        </div>
        <div class="badge">
          <strong>$escapedAssistantName</strong><br>
          ${selected.length} 条消息<br>
          ${_formatTimestamp(DateTime.now())}
        </div>
      </header>
      <section class="messages">
        $messageHtml
      </section>
      <footer class="footer">
        <span>未完剧场 · 剧情分享卡</span>
        <span>保存为 HTML 后可直接打开截图或分享。</span>
      </footer>
    </section>
  </main>
</body>
</html>
''';
  }

  static List<ChatMessage> _selectMessages(List<ChatMessage> messages) {
    if (messages.length <= 8) {
      return messages;
    }
    return messages.sublist(messages.length - 8);
  }

  static String _messageBody(ChatMessage message) {
    final content = message.content.trim();
    if (content.isEmpty) {
      return '<p><em>空内容</em></p>';
    }
    if (message.role == ChatRole.user) {
      return const HtmlEscape().convert(content);
    }
    final parsed = MessageContentParser.parseStructured(content);
    final parts = <String>[];
    for (final block in parsed.blocks) {
      if (block.type == MessageContentBlockType.markdown) {
        parts.add(_paragraphs(_plainText(block.content, limit: 1600)));
      }
    }
    if (parsed.choices.isNotEmpty) {
      final choices = parsed.choices.map((choice) {
        final index = const HtmlEscape().convert(choice.index);
        final label = const HtmlEscape().convert(choice.label);
        return '<div class="choice"><b>$index</b>$label</div>';
      }).join();
      parts.add('<div class="choice-list">$choices</div>');
    }
    if (parts.isEmpty) {
      return _paragraphs(_plainText(content, limit: 1600));
    }
    return parts.join('\n');
  }

  static String _paragraphs(String value) {
    final paragraphs = value
        .split(RegExp(r'\n{2,}'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) => '<p>${const HtmlEscape().convert(part)}</p>');
    return paragraphs.join('\n');
  }

  static String _plainText(String value, {required int limit}) {
    final cleaned = value
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'\[[A-Z_]+\][\s\S]*?\[/[A-Z_]+\]'), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length <= limit) {
      return cleaned;
    }
    return '${cleaned.substring(0, limit).trim()}...';
  }

  static String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

class _ShareTheme {
  const _ShareTheme({
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.bg4,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.soft,
    required this.line,
  });

  factory _ShareTheme.fromPalette(AppThemePalette palette) {
    return _ShareTheme(
      bg1: _hex(palette.background[0]),
      bg2: _hex(palette.background[1]),
      bg3: _hex(palette.background[2]),
      bg4: _hex(palette.background[3]),
      primary: _hex(palette.primary),
      secondary: _hex(palette.secondary),
      accent: _hex(palette.accent),
      soft: _hex(palette.soft),
      line: _rgba(palette.line, fallbackAlpha: 0.22),
    );
  }

  final String bg1;
  final String bg2;
  final String bg3;
  final String bg4;
  final String primary;
  final String secondary;
  final String accent;
  final String soft;
  final String line;

  static String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static String _rgba(Color color, {required double fallbackAlpha}) {
    final argb = color.toARGB32();
    final alpha = ((argb >> 24) & 0xFF) / 255;
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    final effectiveAlpha = alpha <= 0 ? fallbackAlpha : alpha;
    return 'rgba($red, $green, $blue, ${effectiveAlpha.toStringAsFixed(3)})';
  }
}
