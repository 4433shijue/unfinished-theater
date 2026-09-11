class NpcMessageClassifier {
  const NpcMessageClassifier._();

  static bool isDeliverableChatBubble(String value) {
    final text = value.trim();
    if (text.isEmpty || text == '无') {
      return false;
    }
    if (_looksLikeExplicitNoneWithStatus(text) || _looksLikeStateNote(text)) {
      return false;
    }
    if (_looksLikeThirdPersonStatus(text)) {
      return false;
    }
    return true;
  }

  static bool _looksLikeExplicitNoneWithStatus(String text) {
    return RegExp(r'^无\s*[\(（].+[\)）]$').hasMatch(text);
  }

  static bool _looksLikeStateNote(String text) {
    const markers = <String>[
      '等待回复',
      '等待回信',
      '已传递',
      '已送达',
      '准备向',
      '原本准备',
      '私聊触发',
      '来信触发',
      '消息触发',
      '待触发',
      '未触发',
    ];
    if (markers.any(text.contains)) {
      return true;
    }
    if (RegExp(r'^(?:状态|当前状态|计划|日程|后续|触发|备注)\s*[:：]').hasMatch(text)) {
      return true;
    }
    if (RegExp(r'(?:今日|明日|今晚|今夜|明天|次日).*(?:将|会|准备|原本准备)').hasMatch(text)) {
      return true;
    }
    if (RegExp(r'(?:将|会)(?:收到|主动找|主动联系)').hasMatch(text)) {
      return true;
    }
    return false;
  }

  static bool _looksLikeThirdPersonStatus(String text) {
    if (RegExp(r'^[^：:]{1,12}[：:]').hasMatch(text)) {
      return false;
    }
    final hasDialoguePunctuation = RegExp(r'[？?！!。…]$').hasMatch(text);
    if (hasDialoguePunctuation && text.length <= 36) {
      return false;
    }
    return RegExp(r'^(?:今日|明日|今晚|今夜|明天|次日|当前|随后|之后|稍后)').hasMatch(text);
  }
}
