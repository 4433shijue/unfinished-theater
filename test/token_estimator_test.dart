import 'package:ai_roleplay_chat/services/token_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimates plain text without counting whitespace-only input', () {
    expect(TokenEstimator.estimateText('   \n\t'), 0);
    expect(TokenEstimator.estimateText('hello world'), greaterThan(0));
    expect(TokenEstimator.estimateText('你好，世界'), greaterThanOrEqualTo(4));
  });

  test('estimates chat message overhead', () {
    final contentTokens = TokenEstimator.estimateText('user') +
        TokenEstimator.estimateText('hello');

    final total = TokenEstimator.estimateChatMessages(<Map<String, String>>[
      <String, String>{'role': 'user', 'content': 'hello'},
    ]);

    expect(total, contentTokens + 7);
  });
}
