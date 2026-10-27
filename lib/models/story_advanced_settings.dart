class StoryAdvancedSettings {
  const StoryAdvancedSettings(
      {this.perspective = 'second',
      this.length = 'long',
      this.pace = 'natural',
      this.interaction = '',
      this.worldConstraints = '',
      this.instructions = '',
      this.npcCount = 0});
  factory StoryAdvancedSettings.fromJson(Map<String, dynamic> j) =>
      StoryAdvancedSettings(
          perspective:
              const ['first', 'second', 'third'].contains(j['perspective'])
                  ? j['perspective'] as String
                  : 'second',
          length: const ['short', 'medium', 'long'].contains(j['length'])
              ? j['length'] as String
              : 'long',
          pace: const ['slow', 'natural', 'fast'].contains(j['pace'])
              ? j['pace'] as String
              : 'natural',
          interaction: j['interaction']?.toString() ?? '',
          worldConstraints: j['worldConstraints']?.toString() ?? '',
          instructions: j['instructions']?.toString() ?? '',
          npcCount: const [3, 4, 5, 6].contains(j['npcCount'])
              ? j['npcCount'] as int
              : 0);
  final String perspective,
      length,
      pace,
      interaction,
      worldConstraints,
      instructions;
  final int npcCount;
  int get minimumCharacters =>
      switch (length) { 'short' => 600, 'medium' => 1200, _ => 2000 };
  String get lengthTarget => switch (length) {
        'short' => '600-1000',
        'medium' => '1200-1800',
        _ => '2200-3200'
      };
  String get lengthInstruction =>
      '纯文字剧情正文目标 $lengthTarget 个中文字符，下限 $minimumCharacters 字；HTML、状态块和选项不计入正文长度，资料卡与代码同样不计入。';
  Map<String, dynamic> toJson() => {
        'perspective': perspective,
        'length': length,
        'pace': pace,
        'interaction': interaction,
        'worldConstraints': worldConstraints,
        'instructions': instructions,
        'npcCount': npcCount
      };
  StoryAdvancedSettings copyWith(
          {String? perspective,
          String? length,
          String? pace,
          String? interaction,
          String? worldConstraints,
          String? instructions,
          int? npcCount}) =>
      StoryAdvancedSettings(
          perspective: perspective ?? this.perspective,
          length: length ?? this.length,
          pace: pace ?? this.pace,
          interaction: interaction ?? this.interaction,
          worldConstraints: worldConstraints ?? this.worldConstraints,
          instructions: instructions ?? this.instructions,
          npcCount: npcCount ?? this.npcCount);
  String toPrompt({bool groupChat = false}) => '''【用户长期高级设置】
叙事视角：${switch (perspective) {
        'first' => '第一人称',
        'third' => '第三人称',
        _ => '第二人称'
      }}。
${groupChat ? '使用群聊气泡，篇幅服从对话节奏。' : lengthInstruction}
推进节奏：${switch (pace) {
        'slow' => '慢慢展开，不跳过关键互动',
        'fast' => '紧凑推进，保留玩家选择机会',
        _ => '自然推进'
      }}。
互动偏好原文：$interaction
世界约束原文：$worldConstraints
额外指令原文：$instructions
以上用户明确约束优先于生成设定中的叙事偏好；临时导演指令不得静默覆盖。固定事实冲突应保留原事实并提出冲突。运行结构协议仍须满足。不要替玩家决定行动或台词。
''';
}
