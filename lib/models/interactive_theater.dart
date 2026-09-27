enum InteractiveTheaterSelectionMode {
  single,
  multi,
}

enum InteractiveTheaterKind {
  chatEasterEgg,
  branchingDrama,
  objectExploration,
  lightGame,
}

extension InteractiveTheaterSelectionModeCopy
    on InteractiveTheaterSelectionMode {
  String get code => name;

  String get label => switch (this) {
        InteractiveTheaterSelectionMode.single => '单选小剧场',
        InteractiveTheaterSelectionMode.multi => '多选小剧场',
      };

  String get instruction => switch (this) {
        InteractiveTheaterSelectionMode.single =>
          '同一组互动选项只能选择一个，点击继续后根据这个选择推进一小段番外。',
        InteractiveTheaterSelectionMode.multi =>
          '互动选项可以选择多个，点击继续后把这些选择组合成一小段番外。',
      };
}

extension InteractiveTheaterKindCopy on InteractiveTheaterKind {
  String get code => switch (this) {
        InteractiveTheaterKind.chatEasterEgg => 'chat_easter_egg',
        InteractiveTheaterKind.branchingDrama => 'branching_drama',
        InteractiveTheaterKind.objectExploration => 'object_exploration',
        InteractiveTheaterKind.lightGame => 'light_game',
      };

  String get label => switch (this) {
        InteractiveTheaterKind.chatEasterEgg => '群聊彩蛋',
        InteractiveTheaterKind.branchingDrama => '分支短剧',
        InteractiveTheaterKind.objectExploration => '物件探索',
        InteractiveTheaterKind.lightGame => '轻量小游戏',
      };

  String get description => switch (this) {
        InteractiveTheaterKind.chatEasterEgg => '切换不同人的聊天视角，挖出同一件小事的错位理解。',
        InteractiveTheaterKind.branchingDrama => '选一句话或一个动作，看人物按自己的性格接住它。',
        InteractiveTheaterKind.objectExploration => '点开纸条、抽屉、礼物或现场细节，拼出一段小故事。',
        InteractiveTheaterKind.lightGame => '做一个三到五步的小操作，让结果变成对白、笑点或彩蛋。',
      };

  String get promptInstruction => switch (this) {
        InteractiveTheaterKind.chatEasterEgg =>
          '把一个当前剧情中的小事做成幕后聊天或群聊彩蛋。让不同人物只说自己知道的部分，可以有撤回、错发、旁观者插话或不合时宜的认真。',
        InteractiveTheaterKind.branchingDrama =>
          '把一个具体场面做成短分支剧。给出三到五个行动按钮，每个按钮都改变人物回应或下一小步，但不要改变主线事实。',
        InteractiveTheaterKind.objectExploration =>
          '把场景做成可点击的物件探索。安排三到六个有意义的物件，每次点开都给出一小段世界内信息、动作或人物反应，不要把普通装饰都写成线索。',
        InteractiveTheaterKind.lightGame =>
          '做一个三到五步就能完成的轻量小游戏，例如调饮料、安排座位、整理物品、猜留言主人或照顾一只小动物。结果要反馈人物性格和小笑点。',
      };
}

class InteractiveTheaterRequest {
  const InteractiveTheaterRequest({
    required this.selectionMode,
    required this.kinds,
    this.title = '',
    this.customPrompt = '',
  });

  final InteractiveTheaterSelectionMode selectionMode;
  final List<InteractiveTheaterKind> kinds;
  final String title;
  final String customPrompt;

  bool get isValid => kinds.isNotEmpty || customPrompt.trim().isNotEmpty;

  String get displayTitle {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }
    if (kinds.isEmpty) {
      return '自定义互动小剧场';
    }
    return '互动小剧场 · ${kinds.map((kind) => kind.label).join(' · ')}';
  }

  String get kindCodes => kinds.map((kind) => kind.code).join(', ');

  String toPrompt() {
    final buffer = StringBuffer()
      ..writeln('互动选项模式：${selectionMode.label}')
      ..writeln(selectionMode.instruction);
    if (kinds.isNotEmpty) {
      buffer
        ..writeln('已选择的玩法方向：${kinds.map((kind) => kind.label).join('、')}')
        ..writeln('玩法要求：');
      for (final kind in kinds) {
        buffer.writeln('- ${kind.label}：${kind.promptInstruction}');
      }
    }
    if (customPrompt.trim().isNotEmpty) {
      buffer
        ..writeln('用户自定义提示词：')
        ..writeln(customPrompt.trim());
    }
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'selectionMode': selectionMode.code,
      'kinds': kinds.map((kind) => kind.code).toList(growable: false),
      'title': title,
      'customPrompt': customPrompt,
    };
  }
}
