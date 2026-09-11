class FanficResult {
  const FanficResult({
    required this.id,
    required this.characterId,
    required this.title,
    required this.pairingLabel,
    required this.inspiration,
    required this.content,
    required this.createdAt,
    this.blindBox = false,
  });

  factory FanficResult.fromJson(Map<String, dynamic> json) {
    return FanficResult(
      id: json['id']?.toString() ?? '',
      characterId: json['characterId']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名同人文',
      pairingLabel: json['pairingLabel']?.toString() ?? '',
      inspiration: json['inspiration']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      blindBox: json['blindBox'] == true,
    );
  }

  final String id;
  final String characterId;
  final String title;
  final String pairingLabel;
  final String inspiration;
  final String content;
  final DateTime createdAt;
  final bool blindBox;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'title': title,
      'pairingLabel': pairingLabel,
      'inspiration': inspiration,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'blindBox': blindBox,
    };
  }
}
