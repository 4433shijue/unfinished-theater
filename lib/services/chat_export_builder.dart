import 'dart:convert';

import 'package:markdown/markdown.dart' as markdown;

import '../models/chat_message.dart';
import 'message_content_parser.dart';

class ChatExportBuilder {
  const ChatExportBuilder._();

  static String buildHtml({
    required String title,
    required String assistantName,
    required List<ChatMessage> messages,
  }) {
    final escapedTitle = const HtmlEscape().convert(title);
    final escapedAssistantName = const HtmlEscape().convert(assistantName);
    final messageHtml = messages.map((message) {
      final isUser = message.role == ChatRole.user;
      final author = isUser ? '你' : assistantName;
      final body = _buildMessageBody(message);

      return '''
<article class="message ${isUser ? 'user' : 'assistant'}">
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
      --bg: linear-gradient(135deg, #fff8ef 0%, #f0f4ff 52%, #eefcff 100%);
      --card: rgba(255, 255, 255, 0.9);
      --text: #263238;
      --muted: #5f6f73;
      --border: rgba(15, 23, 42, 0.08);
      --primary: #0d7c78;
      --primary-soft: #a9ece4;
      --assistant: #ffffff;
      --shadow: 0 18px 40px rgba(15, 23, 42, 0.09);
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      min-height: 100vh;
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      background: var(--bg);
      color: var(--text);
    }

    .page {
      max-width: 1200px;
      margin: 0 auto;
      padding: 32px 20px 48px;
    }

    .header {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 28px;
      padding: 24px 28px;
      box-shadow: var(--shadow);
      margin-bottom: 20px;
      backdrop-filter: blur(12px);
    }

    .header h1 {
      margin: 0 0 10px;
      font-size: 34px;
    }

    .header p {
      margin: 0;
      color: var(--muted);
      font-size: 16px;
    }

    .messages {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .message {
      display: flex;
    }

    .message.user {
      justify-content: flex-end;
    }

    .message.assistant {
      justify-content: flex-start;
    }

    .bubble {
      width: min(760px, 82vw);
      padding: 18px 18px 14px;
      border-radius: 24px;
      border: 1px solid var(--border);
      box-shadow: var(--shadow);
      background: var(--assistant);
    }

    .message.user .bubble {
      background: var(--primary-soft);
      border-color: rgba(13, 124, 120, 0.18);
    }

    .author {
      font-weight: 700;
      color: var(--primary);
      margin-bottom: 10px;
    }

    .message.user .author {
      color: #124d4b;
    }

    .content {
      line-height: 1.7;
      font-size: 16px;
      word-break: break-word;
    }

    .content > *:first-child {
      margin-top: 0;
    }

    .content > *:last-child {
      margin-bottom: 0;
    }

    .content pre {
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      background: rgba(15, 23, 42, 0.05);
      border-radius: 16px;
      padding: 14px;
    }

    .message-block + .message-block {
      margin-top: 14px;
    }

    .code-title,
    .preview-title {
      display: inline-flex;
      align-items: center;
      color: var(--primary);
      font-weight: 700;
      margin-bottom: 8px;
    }

    .code-box {
      border-radius: 18px;
      padding: 14px;
      border: 1px solid rgba(15, 23, 42, 0.08);
      background: rgba(15, 23, 42, 0.05);
      font-family: Consolas, Monaco, monospace;
      white-space: pre-wrap;
    }

    .preview-shell {
      background: rgba(255, 255, 255, 0.96);
      border-radius: 22px;
      border: 1px solid rgba(13, 124, 120, 0.18);
      padding: 10px;
    }

    .preview-frame {
      width: 100%;
      border: 0;
      border-radius: 18px;
      background: #ffffff;
    }

    .meta {
      margin-top: 12px;
      font-size: 13px;
      color: var(--muted);
    }

    @media (max-width: 720px) {
      .page {
        padding: 20px 12px 40px;
      }

      .header {
        padding: 20px;
      }

      .header h1 {
        font-size: 28px;
      }

      .bubble {
        width: 100%;
      }
    }
  </style>
</head>
<body>
  <main class="page">
    <section class="header">
      <h1>$escapedTitle</h1>
      <p>导出角色：$escapedAssistantName · 共 ${messages.length} 条消息</p>
    </section>
    <section class="messages">
      $messageHtml
    </section>
  </main>
</body>
</html>
''';
  }

  static String _buildMessageBody(ChatMessage message) {
    final content = message.content.trim();
    if (content.isEmpty) {
      return '<p><em>空内容</em></p>';
    }

    if (message.role == ChatRole.user) {
      return '<pre>${const HtmlEscape().convert(content)}</pre>';
    }

    final blocks = MessageContentParser.parse(content);
    final htmlBlocks = blocks.map((block) {
      switch (block.type) {
        case MessageContentBlockType.markdown:
          return '<div class="message-block">${markdown.markdownToHtml(block.content)}</div>';
        case MessageContentBlockType.code:
          final title =
              block.language.trim().isEmpty ? 'code' : block.language.trim();
          return '''
<div class="message-block">
  <div class="code-title">$title</div>
  <div class="code-box">${const HtmlEscape().convert(block.content)}</div>
</div>
''';
        case MessageContentBlockType.runnablePreview:
          final height =
              MessageContentParser.estimatePreviewHeight(block.content).round();
          final srcdoc = const HtmlEscape().convert(block.content);
          return '''
<div class="message-block">
  <div class="preview-title">代码实时预览</div>
  <div class="preview-shell">
    <iframe
      class="preview-frame"
      sandbox="allow-scripts allow-forms allow-modals"
      style="height: ${height}px;"
      srcdoc="$srcdoc"></iframe>
  </div>
</div>
''';
      }
    }).join();

    return htmlBlocks;
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
