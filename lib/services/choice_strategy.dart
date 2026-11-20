import 'message_content_parser.dart';

/// One contract shared by generation, repair and on-demand option replacement.
class ChoiceStrategy {
  const ChoiceStrategy._();
  static const instruction = '''
【六条不同路线】
A-F 是六个可独立选择的分支入口，意外程度逐级增加，不按风险、收益或成功率排序。
A 顺势推进；B 换一个切入点；C 明显改变行动方向；D 反转当前局面；E 非常规奇招；F 世界内极限荒诞、最出人意料但确实可以尝试的行动。
每个字母的具体路线随场景变化，不固定谁必须谈判、调查或战斗。任意两项在目标、手段、互动对象、预期局面中至少两项明显不同，能引向不同后续场景。同一个行动换语气、力度或近义词不算不同路线。
F 的荒诞来自具体行动、物件妙用、误会或规则借用，不靠突然获得超能力、凭空出现道具、泄露秘密或打破世界观。人物认真回应，代价与后果照常生效；不把它降格为不影响主线的玩笑。
只写下一步要尝试什么，不预定成功、不替玩家执行。每项一到两句，具体、简短，保留玩家自主权。
输出前自行检查六项两两差异和逐级意外程度，重写相似项；不要输出自检过程或分类标签。
用户可以多选。以用户最终输入顺序尝试可衔接的行动；真正互斥时停在取舍处请玩家决定，不能擅自丢掉某项或同时判定全部成功。
''';

  static const multiSelection =
      '用户可组合多个选项，以最终输入顺序为准。可衔接的依次尝试；互斥时停在需要取舍的位置，不替玩家决定，也不同时判定全部成功。';

  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');

  static List<String> issues(List<MessageChoice> choices, {int count = 6}) {
    final issues = <String>[];
    if (choices.length != count ||
        choices.indexed
            .any((e) => e.$2.index != String.fromCharCode(65 + e.$1))) {
      issues.add('需要按顺序提供 $count 个选项');
    }
    final seen = <String>{};
    for (final choice in choices) {
      final normalized = normalize(choice.label);
      if (normalized.isEmpty || !seen.add(normalized)) {
        issues.add('选项有空白或明显重复');
        break;
      }
    }
    return issues;
  }

  static String block(List<MessageChoice> choices) =>
      '[CHOICES]\n${choices.map((c) => '${c.index}|${c.label}').join('\n')}\n[/CHOICES]';
}
