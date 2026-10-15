import 'package:flutter/material.dart';
import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/inline_theater_settings.dart';
import 'package:ai_roleplay_chat/widgets/chat_message_bubble.dart';
import 'package:ai_roleplay_chat/widgets/inline_theater_settings_editor.dart';

void main() => runApp(const MaterialApp(home: _Harness()));

class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  var _complete = false;
  var _settings = const InlineTheaterSettings();
  var _actions = 0;
  var _older = false;

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: ListView(children: [
        Wrap(children: [
          TextButton(
              onPressed: () => setState(() => _complete = true),
              child: const Text('收到完整番外')),
          TextButton(
              onPressed: () => setState(() => _older = !_older),
              child: const Text('切换历史折叠')),
          Text('主线输入次数：$_actions'),
        ]),
        ChatMessageBubble(
            key: ValueKey(_older),
            assistantName: '雨夜',
            isStreaming: !_older,
            deferHtmlPreview: _older,
            onHtmlActionSelected: (_) => setState(() => _actions++),
            message: ChatMessage(
                id: 'qa',
                role: ChatRole.assistant,
                timestamp: DateTime(2026),
                isSummarized: false,
                inlineTheaterThemeId: 'backstageChat',
                content: _complete
                    ? '雨停了。两个人还站在屋檐下。\n\n```html\n${InlineTheaterTheme.backstageChat.exampleHtml}\n```\n[GAME_STATE]\n'
                    : '雨停了。两个人还站在屋檐下。\n\n```html\n<html')),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
                child: InlineTheaterSettingsEditor(
                    value: _settings,
                    onChanged: (v) => setState(() => _settings = v)))),
      ])));
}
