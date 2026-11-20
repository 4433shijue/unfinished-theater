/// Player editing aids. These records never represent a new story event.
class StoryQuote {
  const StoryQuote(
      {required this.worldId,
      required this.messageId,
      required this.text,
      required this.sourceDigest,
      this.npcId});
  final String worldId, messageId, text, sourceDigest;
  final String? npcId;
  factory StoryQuote.fromJson(Map<String, dynamic> json) => StoryQuote(
      worldId: '${json['worldId'] ?? ''}',
      messageId: '${json['messageId'] ?? ''}',
      text: '${json['text'] ?? ''}',
      sourceDigest: '${json['sourceDigest'] ?? ''}',
      npcId: json['npcId']?.toString());
  Map<String, dynamic> toJson() => {
        'worldId': worldId,
        'messageId': messageId,
        'text': text,
        'sourceDigest': sourceDigest,
        if (npcId != null) 'npcId': npcId
      };
  String get promptContext => '【引用旧对话，仅指明回应对象，不是新的行动或重复发生的事件】\n$text\n【引用结束】';
  static String digest(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      final mixed = hash ^ unit;
      final low = mixed & 0xffff;
      final high = mixed >>> 16;
      // Split FNV multiplication so every intermediate is exactly representable
      // in JavaScript as well as on the Dart VM (archives move between both).
      hash =
          (low * 0x0193 + ((high * 0x0193 + low * 0x0100) & 0xffff) * 0x10000) &
              0xffffffff;
    }
    return '${value.length}:${hash.toRadixString(16)}';
  }
}

class ComposerDraft {
  const ComposerDraft({this.text = '', this.quote});
  final String text;
  final StoryQuote? quote;
  factory ComposerDraft.fromJson(Map<String, dynamic> json) => ComposerDraft(
      text: '${json['text'] ?? ''}',
      quote: json['quote'] is Map
          ? StoryQuote.fromJson(Map<String, dynamic>.from(json['quote'] as Map))
          : null);
  Map<String, dynamic> toJson() =>
      {'text': text, if (quote != null) 'quote': quote!.toJson()};
}
