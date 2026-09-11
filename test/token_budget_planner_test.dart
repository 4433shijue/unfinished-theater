import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/services/ai_reply_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('token planner removes the oldest complete turn', () {
    final messages = <ChatMessage>[
      _message('u1', ChatRole.user),
      _message('a1', ChatRole.assistant),
      _message('u2', ChatRole.user),
      _message('a2', ChatRole.assistant),
      _message('u3', ChatRole.user),
    ];

    final selected = const TokenBudgetPlanner().trimContext(
      messages: messages,
      maxPromptTokens: 1200,
      estimate: (candidate) => candidate.length > 3 ? 1600 : 1000,
    );

    expect(selected.map((message) => message.id), <String>['u2', 'a2', 'u3']);
    expect(selected.first.role, ChatRole.user);
    expect(selected.last.id, 'u3');
  });
}

ChatMessage _message(String id, ChatRole role) {
  return ChatMessage(
    id: id,
    role: role,
    content: id,
    timestamp: DateTime(2026, 8, 8),
    isSummarized: false,
  );
}
