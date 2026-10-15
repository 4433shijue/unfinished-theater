import 'chat_message.dart';

enum InlineTheaterMode { single, multiple, custom }

enum InlineTheaterTheme {
  backstageChat,
  interview,
  innerVoice,
  whatIf,
  branchingScene,
  objects,
  miniGame;

  String get label => switch (this) {
        backstageChat => '幕后群聊',
        interview => '角色采访',
        innerVoice => '内心吐槽',
        whatIf => '假如剧场',
        branchingScene => '分支短剧',
        objects => '物件彩蛋',
        miniGame => '轻量小游戏',
      };

  String get instruction => switch (this) {
        backstageChat => '围绕本轮小事写三到五条幕后聊天，点击展开撤回消息或没发出去的心声，利用不同人物的误解制造笑点。',
        interview => '把本轮人物请到场外采访，点击不同问题揭晓嘴硬回答和另一人的拆台，保持角色性格。',
        innerVoice => '展示人物嘴上说的话，点击揭晓与之形成反差的内心吐槽；这是番外猜想，不是主线的秘密事实。',
        whatIf => '把本轮场面变成明确的非正史假设，例如全员变猫或身份互换，点击切换人物视角，不能泄露真实未来。',
        branchingScene => '从本轮一个小动作写三种不同的非正史回应，所有分支和结尾一次写好，选择后在窗口内切换。',
        objects => '让用户点开三个有意思的小物件，逐渐拼出一个与角色有关的轻巧笑点，不发放真实道具或主线线索。',
        miniGame => '做三步以内的调饮料、猜留言或安排座位小游戏，用预写场景切换呈现每一步和结尾，结果只反馈角色对白和笑点。',
      };

  /// Small executable documents also serve as protocol examples and QA fixtures.
  String get exampleHtml {
    final (lead, captions, answers) = switch (this) {
      backstageChat => (
          '散场后的匿名群',
          ['主持人发了什么', '谁撤回了消息', '点开最后一条'],
          ['主持人：今天谁又把伞落下了？', '某人撤回：其实我是故意等她的。', '旁观者：两位，群里还坐着我。']
        ),
      interview => (
          '雨后五分钟采访',
          ['为什么没走', '伞是谁的', '还有补充吗'],
          ['“我只是顺路。”他把通往反方向的车票藏进袖口。', '“她的。”两个人同时指向对方。', '场外传来一句：“这一段麻烦剪掉。”']
        ),
      innerVoice => (
          '嘴上与心里',
          ['只是顺路', '一点不冷', '你先回去'],
          ['心里：这条路今天绕得很值得。', '心里：她要是再靠近半步就好了。', '心里：走慢一点，我还没想好告别的话。']
        ),
      whatIf => (
          '假如雨棚下都是猫',
          ['看橘猫', '看黑猫', '看路过的猫'],
          ['橘猫把唯一的干纸箱推过去，又假装在洗脸。', '黑猫坐进纸箱，给旁边留了半个位置。', '路过的猫：借过，你俩挡住鱼店门了。']
        ),
      branchingScene => (
          '如果当时换一句话',
          ['把伞递过去', '说一句好巧', '一起等雨停'],
          ['“下次记得还。”伞柄上还留着手心的温度。', '“嗯，好巧。”他把已经等了很久的咖啡藏到身后。', '雨很快停了。两个人谁也没先提。']
        ),
      objects => (
          '桌上留下的三样东西',
          ['折起来的纸条', '杯底的小画', '没拆的糖'],
          [
            '纸条上写着“别再忘带伞”，最后一笔划得很重。',
            '杯底画了两只挤在伞下的小动物。',
            '包装纸背面写着“多买了一颗”，字迹和纸条一模一样。'
          ]
        ),
      miniGame => (
          '给嘴硬的人调一杯饮料',
          ['先放茶叶', '再加一片柠檬', '最后递过去'],
          [
            '第一步：茶香冒出来，他终于肯从书后抬头。',
            '第二步：他说不要酸，视线却一直跟着杯子走。',
            '“也就一般。”他连杯底那片柠檬都没留下。'
          ]
        ),
    };
    final cards = List.generate(
            3,
            (i) => '''
<section id="answer$i" data-extra-group="answers" hidden><p>${answers[i]}</p>
${this == miniGame && i < 2 ? '<button data-extra-action="show" data-extra-target="answer${i + 1}">${captions[i + 1]}</button>' : ''}</section>''')
        .join();
    final buttons = List.generate(
            this == miniGame ? 1 : 3,
            (i) =>
                '<button data-extra-action="show" data-extra-target="answer$i">${captions[i]}</button>')
        .join();
    return '''<!doctype html><html lang="zh-CN" data-inline-theater="$name"><head><meta charset="utf-8"><style>
body{margin:0;padding:20px;background:#fff7ef;color:#493c49;font:16px/1.8 sans-serif;box-sizing:border-box}h2{font-size:21px}button{font:inherit;background:#f4dce8;border:0;border-radius:12px;padding:10px 14px;margin:5px;cursor:pointer}section{padding:12px;border-radius:12px;background:#fff} [hidden]{display:none!important}
</style></head><body><small>番外 · 不影响主线</small><h2>$lead</h2><p>雨停以后，还有一点没说完的小事。</p>$buttons$cards<button data-extra-action="reset">重新看看</button></body></html>''';
  }
}

class InlineTheaterSettings {
  const InlineTheaterSettings({
    this.enabled = true,
    this.mode = InlineTheaterMode.multiple,
    this.themeIds = const ['backstageChat', 'innerVoice', 'whatIf'],
    this.customPrompt = '',
  });

  final bool enabled;
  final InlineTheaterMode mode;
  final List<String> themeIds;
  final String customPrompt;

  static const promptExample =
      '每回合正文后，生成一个“角色下班后的匿名吐槽群”。围绕本轮发生的事情写三到五条聊天，保持人物性格，有一点嘴硬和反差。点击消息能展开角色没发出去的真实想法。所有内容都是非正史彩蛋，不影响主线，不显示游戏数值和任务面板。';

  factory InlineTheaterSettings.fromJson(Object? value) {
    if (value is! Map) return const InlineTheaterSettings();
    final mode = InlineTheaterMode.values
            .where((m) => m.name == value['mode'])
            .firstOrNull ??
        InlineTheaterMode.multiple;
    final ids = (value['themeIds'] is List
            ? value['themeIds'] as List
            : const ['backstageChat', 'innerVoice', 'whatIf'])
        .whereType<String>()
        .where((id) => InlineTheaterTheme.values.any((t) => t.name == id))
        .toSet()
        .toList();
    final prompt = value['customPrompt']?.toString().trim() ?? '';
    return InlineTheaterSettings(
        enabled: value['enabled'] != false,
        mode: mode,
        themeIds:
            ids.isEmpty && mode != InlineTheaterMode.custom && prompt.isEmpty
                ? const ['backstageChat']
                : ids,
        customPrompt: prompt);
  }

  bool get isValid =>
      !enabled ||
      (mode == InlineTheaterMode.custom
          ? customPrompt.trim().isNotEmpty
          : themeIds.isNotEmpty || customPrompt.trim().isNotEmpty);

  String themeForTurn(int completedTurns) {
    if (mode == InlineTheaterMode.custom || themeIds.isEmpty) return 'custom';
    return themeIds[mode == InlineTheaterMode.single
        ? 0
        : completedTurns.clamp(0, 1 << 30) % themeIds.length];
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mode': mode.name,
        'themeIds': themeIds,
        'customPrompt': customPrompt
      };

  static int completedTurns(Iterable<ChatMessage> messages) {
    var awaitingReply = false;
    var count = 0;
    for (final message in messages) {
      if (message.role == ChatRole.user) {
        awaitingReply = true;
      } else if (awaitingReply &&
          message.content.trim().isNotEmpty &&
          !message.content.contains('（回复已暂停）') &&
          (message.inlineTheaterThemeId != null ||
              message.gameStateSnapshot != null ||
              message.content.contains('[/GAME_STATE]'))) {
        count++;
        awaitingReply = false;
      }
    }
    return count;
  }
}
