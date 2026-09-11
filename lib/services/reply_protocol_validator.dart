import '../models/game_state.dart';
import 'game_state_parser.dart';
import 'gameplay_patch_engine.dart';
import 'message_content_parser.dart';

enum ReplyProtocolMode {
  standard,
  map,
  largeGroupChat,
}

class ReplyProtocolValidationResult {
  const ReplyProtocolValidationResult(this.issues);

  final List<String> issues;

  bool get isValid => issues.isEmpty;
}

class ReplyProtocolValidator {
  const ReplyProtocolValidator._();

  static ReplyProtocolValidationResult validate({
    required String content,
    required ReplyProtocolMode mode,
    bool choicesEnabled = true,
    bool gameplayPatchRequired = false,
    int expectedChoiceCount = 6,
    bool htmlRequired = true,
  }) {
    final issues = <String>[];
    final hasGameState = GameStateParser.stateBlockPattern.hasMatch(content);
    final hasUsableGameState =
        ReplyProtocolReconciler.hasUsableGameState(content);
    final parsed = MessageContentParser.parseStructured(content, cache: false);
    if (gameplayPatchRequired) {
      final patch = GameplayPatchParser.parseResult(content);
      if (!patch.found) {
        issues.add('缺少 [THEATER_PATCH] 变量补丁');
      } else if (!patch.isValid) {
        issues.add(patch.error ?? '[THEATER_PATCH] 变量补丁格式错误');
      } else if (hasGameState &&
          _lastPatchStart(content) < _lastGameStateEnd(content)) {
        issues.add('[THEATER_PATCH] 必须位于 [GAME_STATE] 之后');
      }
    }

    switch (mode) {
      case ReplyProtocolMode.largeGroupChat:
        if (!MessageContentParser.hasGroupChatBlock(content)) {
          issues.add('缺少 [GROUP_CHAT] 群聊 JSON 块');
        }
        _validateGameState(issues, hasGameState, hasUsableGameState);
        if (_htmlPattern.hasMatch(content)) {
          issues.add('群聊模式不应输出 HTML 美化框');
        }
        if (parsed.choices.isNotEmpty) {
          issues.add('群聊模式不应输出六选项');
        }
        if (_mapStatePattern.hasMatch(content)) {
          issues.add('群聊模式不应输出 [MAP_STATE]');
        }
        issues.addAll(_validateGroupChatMessages(parsed.groupChatMessages));
      case ReplyProtocolMode.map:
        _validateGameState(issues, hasGameState, hasUsableGameState);
        if (!_mapStatePattern.hasMatch(content)) {
          issues.add('缺少 [MAP_STATE] 地图 JSON 块');
        }
        if (parsed.choices.isNotEmpty || _choicesPattern.hasMatch(content)) {
          issues.add('地图模式不应输出 [CHOICES]');
        }
      case ReplyProtocolMode.standard:
        if (htmlRequired && !_htmlPattern.hasMatch(content)) {
          issues.add('缺少 HTML 美化框');
        }
        _validateGameState(issues, hasGameState, hasUsableGameState);
        if (choicesEnabled) {
          if (parsed.choices.length != expectedChoiceCount) {
            issues.add('下一步选项不是 $expectedChoiceCount 个');
          }
          if (!_hasExpectedChoiceIndexes(
            parsed.choices,
            expectedChoiceCount,
          )) {
            final lastIndex = String.fromCharCode(64 + expectedChoiceCount);
            issues.add('下一步选项必须按 A-$lastIndex 排列');
          }
        } else if (parsed.choices.isNotEmpty) {
          issues.add('当前关闭下一步选项，不应输出 [CHOICES]');
        }
    }

    return ReplyProtocolValidationResult(
      issues.toSet().toList(growable: false),
    );
  }

  static const Set<String> _narratorAliases = <String>{
    '旁白',
    '叙述',
    '叙述者',
    'narrator',
    'narration',
  };

  static final RegExp _htmlPattern = RegExp(
    r'```html[\s\S]*?```|<!doctype|<html\b',
    caseSensitive: false,
  );

  static final RegExp _mapStatePattern = RegExp(
    r'\[MAP_STATE\]\s*[\s\S]*?\s*\[/MAP_STATE\]',
    caseSensitive: false,
  );

  static final RegExp _choicesPattern = RegExp(
    r'\[CHOICES\]',
    caseSensitive: false,
  );

  static void _validateGameState(
    List<String> issues,
    bool hasGameState,
    bool hasUsableGameState,
  ) {
    if (!hasGameState) {
      issues.add('缺少 [GAME_STATE] 状态面板');
    } else if (!hasUsableGameState) {
      issues.add('[GAME_STATE] 没有可解析的状态字段');
    }
  }

  static int _lastGameStateEnd(String content) {
    final matches = GameStateParser.stateBlockPattern.allMatches(content);
    return matches.isEmpty ? -1 : matches.last.end;
  }

  static int _lastPatchStart(String content) {
    final matches = GameplayPatchParser.blockPattern.allMatches(content);
    return matches.isEmpty ? -1 : matches.last.start;
  }

  static List<String> _validateGroupChatMessages(
    List<GroupChatMessage> messages,
  ) {
    final issues = <String>[];
    if (messages.isEmpty) {
      return issues;
    }
    for (final message in messages) {
      final speaker = message.speaker.trim();
      final content = message.content.trim();
      if (content.isEmpty) {
        issues.add('群聊存在空气泡');
        continue;
      }
      if (message.isNarration) {
        if (!_narratorAliases.contains(speaker.toLowerCase()) &&
            !_narratorAliases.contains(speaker)) {
          issues.add('旁白气泡 speaker 应为旁白');
        }
        if (RegExp(r'^[^：:\n]{1,16}[：:]').hasMatch(content)) {
          issues.add('旁白气泡疑似替角色说话');
        }
      } else {
        if (speaker.isEmpty || _narratorAliases.contains(speaker)) {
          issues.add('NPC 气泡缺少有效角色名');
        }
        if (_looksLikeActionNarration(content)) {
          issues.add('NPC 气泡疑似混入动作或旁白描写');
        }
      }
    }
    return issues;
  }

  static bool _looksLikeActionNarration(String content) {
    final compact = content.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'[（(].{0,24}[）)]').hasMatch(compact)) {
      return true;
    }
    for (final marker in const <String>[
      '他说',
      '她说',
      '笑了笑',
      '低头',
      '抬头',
      '转身',
      '看向',
      '沉默',
      '走到',
      '靠近',
      '离开',
      '伸手',
    ]) {
      if (compact.contains(marker)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasExpectedChoiceIndexes(
    List<MessageChoice> choices,
    int expectedChoiceCount,
  ) {
    final expected = List<String>.generate(
      expectedChoiceCount,
      (index) => String.fromCharCode(65 + index),
      growable: false,
    );
    final actual = choices
        .map((choice) => choice.index.trim().toUpperCase())
        .toList(growable: false);
    if (actual.length != expected.length) {
      return false;
    }
    for (var index = 0; index < expected.length; index += 1) {
      if (actual[index] != expected[index]) {
        return false;
      }
    }
    return true;
  }
}

class ReplyProtocolReconciler {
  const ReplyProtocolReconciler._();

  static bool hasUsableGameState(String content) =>
      _lastUsableGameStateBlock(content) != null;

  static String mergeStateBlocks({
    required String primary,
    required String fallback,
    required bool gameplayPatchRequired,
    bool preferFallback = false,
  }) {
    final gameStateBlock = preferFallback
        ? _lastUsableGameStateBlock(fallback) ??
            _lastUsableGameStateBlock(primary)
        : _lastUsableGameStateBlock(primary) ??
            _lastUsableGameStateBlock(fallback);
    final gameplayPatchBlock = gameplayPatchRequired
        ? preferFallback
            ? _lastValidGameplayPatchBlock(fallback) ??
                _lastValidGameplayPatchBlock(primary)
            : _lastValidGameplayPatchBlock(primary) ??
                _lastValidGameplayPatchBlock(fallback)
        : null;
    var result = _removeStateBlocks(primary);
    final blocks = <String>[
      if (gameStateBlock != null) gameStateBlock,
      if (gameplayPatchBlock != null) gameplayPatchBlock,
    ];
    if (blocks.isEmpty) {
      return result;
    }

    final stateText = blocks.join('\n\n');
    final boundary = RegExp(
      r'\[(?:CHOICES|MAP_STATE)\]',
      caseSensitive: false,
    ).firstMatch(result);
    if (boundary == null) {
      return '${result.trimRight()}\n\n$stateText'.trim();
    }
    final before = result.substring(0, boundary.start).trimRight();
    final after = result.substring(boundary.start).trimLeft();
    return '$before\n\n$stateText\n\n$after'.trim();
  }

  static String? _lastUsableGameStateBlock(String content) {
    final matches =
        GameStateParser.stateBlockPattern.allMatches(content).toList();
    for (final match in matches.reversed) {
      final block = match.group(0)?.trim() ?? '';
      final parsed = GameStateParser.parseFromMessage(
        characterId: 'protocol_validation',
        content: block,
        previous: GameStateSnapshot.empty('protocol_validation'),
      );
      if (parsed?.hasNarrativeState ?? false) {
        return block;
      }
    }
    return null;
  }

  static String? _lastValidGameplayPatchBlock(String content) {
    final matches =
        GameplayPatchParser.blockPattern.allMatches(content).toList();
    for (final match in matches.reversed) {
      final block = match.group(0)?.trim() ?? '';
      if (GameplayPatchParser.parseResult(block).isValid) {
        return block;
      }
    }
    return null;
  }

  static String _removeStateBlocks(String content) {
    return content
        .replaceAll(GameStateParser.stateBlockPattern, '')
        .replaceAll(GameplayPatchParser.blockPattern, '')
        .replaceAll(
          RegExp(
            r'\[GAME_STATE\][\s\S]*?(?=\[(?:THEATER_PATCH|CHOICES|MAP_STATE)\]|$)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\[THEATER_PATCH\][\s\S]*?(?=\[(?:GAME_STATE|CHOICES|MAP_STATE)\]|$)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }
}
