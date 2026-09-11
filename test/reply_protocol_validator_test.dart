import 'package:flutter_test/flutter_test.dart';

import 'package:ai_roleplay_chat/services/reply_protocol_validator.dart';

void main() {
  group('ReplyProtocolValidator', () {
    test('accepts large group chat without html or choices', () {
      const content = '''
[GROUP_CHAT]
{
  "mode": "large_group_chat",
  "messages": [
    {"speaker":"旁白","type":"narration","content":"雨声压低了走廊里的脚步，所有人的视线都聚向门口。"},
    {"speaker":"林澈","type":"npc","content":"你刚才听见了吗？"},
    {"speaker":"沈微","type":"npc","content":"别出声，门外有人。"},
    {"speaker":"旁白","type":"narration","content":"灯光闪了一下，墙上的影子被拉得很长。"}
  ]
}
[/GROUP_CHAT]

[GAME_STATE]
时间：深夜
地点：旧楼
状态：紧张
当前任务：确认门外是谁
[/GAME_STATE]
''';

      final result = ReplyProtocolValidator.validate(
        content: content,
        mode: ReplyProtocolMode.largeGroupChat,
      );

      expect(result.issues, isEmpty);
    });

    test('flags choices and html in large group chat', () {
      const content = '''
```html
<div>漂亮框</div>
```
[GROUP_CHAT]
{"mode":"large_group_chat","messages":[{"speaker":"林澈","type":"npc","content":"走吧。"}]}
[/GROUP_CHAT]
[CHOICES]
A｜继续
[/CHOICES]
''';

      final result = ReplyProtocolValidator.validate(
        content: content,
        mode: ReplyProtocolMode.largeGroupChat,
      );

      expect(result.issues.join('\n'), contains('HTML'));
      expect(result.issues.join('\n'), contains('六选项'));
      expect(result.issues.join('\n'), contains('[GAME_STATE]'));
    });

    test('accepts a quiet two-message group chat turn', () {
      const content = '''
[GROUP_CHAT]
{"mode":"large_group_chat","messages":[{"id":"msg_1","speakerId":"narrator","replyTo":"","speaker":"旁白","type":"narration","content":"雨停了。"},{"id":"msg_2","speakerId":"npc-linxia","replyTo":"msg_1","speaker":"林夏","type":"npc","content":"走吧。"}]}
[/GROUP_CHAT]
[GAME_STATE]
时间：清晨
地点：屋檐下
状态：平静
当前任务：回家
[/GAME_STATE]
''';

      final result = ReplyProtocolValidator.validate(
        content: content,
        mode: ReplyProtocolMode.largeGroupChat,
      );

      expect(result.issues, isEmpty);
    });

    test('accepts map mode with game state and map state only', () {
      const content = '''
这一轮你抵达了天台。

[GAME_STATE]
时间：傍晚
地点：天台
状态：调查中
当前任务：寻找线索
[/GAME_STATE]

[MAP_STATE]
{"currentLocationId":"roof","locations":[{"id":"roof","name":"天台"}],"activeChoices":[]}
[/MAP_STATE]
''';

      final result = ReplyProtocolValidator.validate(
        content: content,
        mode: ReplyProtocolMode.map,
      );

      expect(result.issues, isEmpty);
    });

    test('accepts the compact tutorial protocol without html', () {
      const content = '''
幕灯把三张票推到你面前，等你决定先从哪里开始。

[GAME_STATE]
时间：第一次开幕
地点：前厅
状态：选择中
当前任务：选择体验路线
[/GAME_STATE]

[CHOICES]
A|直接进入故事。
B|创建自己的剧场。
C|看看故事如何记住选择。
[/CHOICES]
''';

      final result = ReplyProtocolValidator.validate(
        content: content,
        mode: ReplyProtocolMode.standard,
        expectedChoiceCount: 3,
        htmlRequired: false,
      );

      expect(result.issues, isEmpty);
    });

    test('requires a valid gameplay patch when a system is active', () {
      const withoutPatch = '''
剧情继续推进。
```html
<div>旧楼的紧张气氛仍未散去。</div>
```
[GAME_STATE]
时间：深夜
地点：旧楼
状态：紧张
当前任务：离开旧楼
[/GAME_STATE]
''';
      const malformedPatch = '''
$withoutPatch
[THEATER_PATCH]
{"ops":
[/THEATER_PATCH]
''';
      const validPatch = '''
$withoutPatch
[THEATER_PATCH]
{"ops":[]}
[/THEATER_PATCH]
''';

      final missing = ReplyProtocolValidator.validate(
        content: withoutPatch,
        mode: ReplyProtocolMode.standard,
        choicesEnabled: false,
        gameplayPatchRequired: true,
      );
      final invalid = ReplyProtocolValidator.validate(
        content: malformedPatch,
        mode: ReplyProtocolMode.standard,
        choicesEnabled: false,
        gameplayPatchRequired: true,
      );
      final valid = ReplyProtocolValidator.validate(
        content: validPatch,
        mode: ReplyProtocolMode.standard,
        choicesEnabled: false,
        gameplayPatchRequired: true,
      );

      expect(missing.issues.join('\n'), contains('[THEATER_PATCH]'));
      expect(invalid.issues.join('\n'), contains('合法 JSON'));
      expect(valid.issues, isEmpty);
    });

    test('rejects a tagged game state without displayable state fields', () {
      const content = '''
剧情继续推进。
```html
<div>状态卡</div>
```
[GAME_STATE]
备注：模型只写了说明，没有状态字段
[/GAME_STATE]
''';

      final result = ReplyProtocolValidator.validate(
        content: content,
        mode: ReplyProtocolMode.standard,
        choicesEnabled: false,
      );

      expect(result.issues.join('\n'), contains('没有可解析的状态字段'));
    });

    test('reconciles game state and gameplay patch from separate replies', () {
      const stateOnly = '''
剧情继续推进。
```html
<div>旧楼的灯亮了。</div>
```
[GAME_STATE]
时间：深夜
地点：旧楼
状态：警觉
当前任务：检查走廊
[/GAME_STATE]
[CHOICES]
A|检查门口
B|查看窗外
C|询问同伴
D|退回楼梯
E|关掉手电
F|原地等待
[/CHOICES]
''';
      const patchOnly = '''
[THEATER_PATCH]
{"ops":[{"op":"inc","path":"局势.警戒","value":3,"reason":"灯光暴露位置"}]}
[/THEATER_PATCH]
''';

      final merged = ReplyProtocolReconciler.mergeStateBlocks(
        primary: stateOnly,
        fallback: patchOnly,
        gameplayPatchRequired: true,
      );
      final validation = ReplyProtocolValidator.validate(
        content: merged,
        mode: ReplyProtocolMode.standard,
        gameplayPatchRequired: true,
      );

      expect(validation.issues, isEmpty);
      expect(merged, contains('[GAME_STATE]'));
      expect(merged, contains('[THEATER_PATCH]'));
      expect(merged.indexOf('[GAME_STATE]'),
          lessThan(merged.indexOf('[THEATER_PATCH]')));
      expect(merged.indexOf('[THEATER_PATCH]'),
          lessThan(merged.indexOf('[CHOICES]')));
    });

    test('can make adjudicated state authoritative without replacing story',
        () {
      const primary = '''
原始剧情正文。
[GAME_STATE]
时间：白天
地点：旧楼
状态：平静
当前任务：等待
[/GAME_STATE]
''';
      const adjudicated = '''
[GAME_STATE]
时间：深夜
地点：车站
状态：警觉
当前任务：回家
[/GAME_STATE]
''';

      final merged = ReplyProtocolReconciler.mergeStateBlocks(
        primary: primary,
        fallback: adjudicated,
        gameplayPatchRequired: false,
        preferFallback: true,
      );

      expect(merged, contains('原始剧情正文'));
      expect(merged, contains('地点：车站'));
      expect(merged, isNot(contains('地点：旧楼')));
    });

    test('requires gameplay patch to follow game state', () {
      const content = '''
剧情继续推进。
```html
<div>状态卡</div>
```
[THEATER_PATCH]
{"ops":[]}
[/THEATER_PATCH]
[GAME_STATE]
时间：深夜
地点：旧楼
状态：警觉
当前任务：检查走廊
[/GAME_STATE]
''';

      final result = ReplyProtocolValidator.validate(
        content: content,
        mode: ReplyProtocolMode.standard,
        choicesEnabled: false,
        gameplayPatchRequired: true,
      );

      expect(result.issues.join('\n'), contains('必须位于 [GAME_STATE] 之后'));
    });
  });
}
