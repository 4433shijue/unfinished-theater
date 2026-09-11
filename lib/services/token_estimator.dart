class TokenEstimator {
  const TokenEstimator._();

  static int countCompletedText(String text) => estimateText(text);

  static int estimateText(String text) {
    if (text.trim().isEmpty) {
      return 0;
    }

    var tokens = 0;
    var asciiRunes = 0;
    for (final rune in text.runes) {
      if (rune <= 0x7F) {
        asciiRunes += 1;
        continue;
      }
      if (asciiRunes > 0) {
        tokens += (asciiRunes / 4).ceil();
        asciiRunes = 0;
      }
      if (_isCjkRune(rune)) {
        tokens += 1;
      } else if (_isWhitespaceRune(rune)) {
        continue;
      } else {
        tokens += 1;
      }
    }
    if (asciiRunes > 0) {
      tokens += (asciiRunes / 4).ceil();
    }
    return tokens;
  }

  static int estimateChatMessages(Iterable<Map<String, String>> messages) {
    var total = 3;
    for (final message in messages) {
      total += 4;
      total += estimateText(message['role'] ?? '');
      total += estimateText(message['content'] ?? '');
    }
    return total;
  }

  static bool _isWhitespaceRune(int rune) {
    return rune == 0x20 ||
        rune == 0x09 ||
        rune == 0x0A ||
        rune == 0x0D ||
        rune == 0x3000;
  }

  static bool _isCjkRune(int rune) {
    return (rune >= 0x3400 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0x20000 && rune <= 0x2FA1F);
  }
}
