import 'dart:convert';

import '../models/gameplay_system.dart';

class GameplaySystemParser {
  const GameplaySystemParser._();

  static GameplaySystem parse(String raw) {
    var normalized = raw.trim();
    normalized = normalized
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    final start = normalized.indexOf('{');
    final end = normalized.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('AI 没有返回玩法系统 JSON。');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(normalized.substring(start, end + 1));
    } catch (_) {
      throw const FormatException('玩法系统 JSON 无法解析，请重新生成。');
    }
    if (decoded is! Map) {
      throw const FormatException('玩法系统必须是一个 JSON 对象。');
    }

    final system = GameplaySystem.fromJson(Map<String, dynamic>.from(decoded));
    if (!system.isUsable) {
      throw const FormatException('AI 生成的有效变量不足，请重新生成。');
    }
    if (system.playerFacingVariableCount < 2) {
      throw const FormatException('玩法系统缺少玩家可见变量，请重新生成。');
    }
    return system;
  }
}
