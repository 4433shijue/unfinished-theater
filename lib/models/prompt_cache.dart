class PromptCacheEpoch {
  const PromptCacheEpoch({
    required this.id,
    required this.startMessageId,
    required this.createdAt,
    this.checkpoint = '',
    this.rolloverCount = 0,
    this.rolloverReason = 'initial',
    this.stablePrefixDigest = '',
    this.previousPromptTokens,
    this.injectedMemorySummaryIds = const <String>[],
    this.injectedWorldBookKeys = const <String>[],
  });

  factory PromptCacheEpoch.fromJson(Map<String, dynamic> json) {
    return PromptCacheEpoch(
      id: json['id']?.toString() ?? '',
      startMessageId: json['startMessageId']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      checkpoint: json['checkpoint']?.toString() ?? '',
      rolloverCount: _readInt(json['rolloverCount']) ?? 0,
      rolloverReason: json['rolloverReason']?.toString() ?? 'initial',
      stablePrefixDigest: json['stablePrefixDigest']?.toString() ?? '',
      previousPromptTokens: _readInt(json['previousPromptTokens']),
      injectedMemorySummaryIds:
          _readStringList(json['injectedMemorySummaryIds']),
      injectedWorldBookKeys: _readStringList(json['injectedWorldBookKeys']),
    );
  }

  final String id;
  final String startMessageId;
  final DateTime createdAt;
  final String checkpoint;
  final int rolloverCount;
  final String rolloverReason;
  final String stablePrefixDigest;
  final int? previousPromptTokens;
  final List<String> injectedMemorySummaryIds;
  final List<String> injectedWorldBookKeys;

  PromptCacheEpoch copyWith({
    String? id,
    String? startMessageId,
    DateTime? createdAt,
    String? checkpoint,
    int? rolloverCount,
    String? rolloverReason,
    String? stablePrefixDigest,
    int? previousPromptTokens,
    bool clearPreviousPromptTokens = false,
    List<String>? injectedMemorySummaryIds,
    List<String>? injectedWorldBookKeys,
  }) {
    return PromptCacheEpoch(
      id: id ?? this.id,
      startMessageId: startMessageId ?? this.startMessageId,
      createdAt: createdAt ?? this.createdAt,
      checkpoint: checkpoint ?? this.checkpoint,
      rolloverCount: rolloverCount ?? this.rolloverCount,
      rolloverReason: rolloverReason ?? this.rolloverReason,
      stablePrefixDigest: stablePrefixDigest ?? this.stablePrefixDigest,
      previousPromptTokens: clearPreviousPromptTokens
          ? null
          : previousPromptTokens ?? this.previousPromptTokens,
      injectedMemorySummaryIds:
          injectedMemorySummaryIds ?? this.injectedMemorySummaryIds,
      injectedWorldBookKeys:
          injectedWorldBookKeys ?? this.injectedWorldBookKeys,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'startMessageId': startMessageId,
      'createdAt': createdAt.toIso8601String(),
      'checkpoint': checkpoint,
      'rolloverCount': rolloverCount,
      'rolloverReason': rolloverReason,
      'stablePrefixDigest': stablePrefixDigest,
      if (previousPromptTokens != null)
        'previousPromptTokens': previousPromptTokens,
      'injectedMemorySummaryIds': injectedMemorySummaryIds,
      'injectedWorldBookKeys': injectedWorldBookKeys,
    };
  }
}

class PromptCacheMetric {
  const PromptCacheMetric({
    required this.id,
    required this.characterId,
    required this.recordedAt,
    required this.model,
    required this.endpointHost,
    required this.cacheEpochId,
    required this.rolloverReason,
    required this.stablePrefixDigest,
    required this.estimatedPromptTokens,
    required this.messageCount,
    required this.usedExactAssistantReplay,
    this.previousPromptTokens,
    this.inputTokens,
    this.outputTokens,
    this.cacheHitTokens,
    this.cacheMissTokens,
    this.elapsedMilliseconds,
    this.error = '',
  });

  factory PromptCacheMetric.fromJson(Map<String, dynamic> json) {
    return PromptCacheMetric(
      id: json['id']?.toString() ?? '',
      characterId: json['characterId']?.toString() ?? '',
      recordedAt: DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
          DateTime.now(),
      model: json['model']?.toString() ?? '',
      endpointHost: json['endpointHost']?.toString() ?? '',
      cacheEpochId: json['cacheEpochId']?.toString() ?? '',
      rolloverReason: json['rolloverReason']?.toString() ?? '',
      stablePrefixDigest: json['stablePrefixDigest']?.toString() ?? '',
      estimatedPromptTokens: _readInt(json['estimatedPromptTokens']) ?? 0,
      messageCount: _readInt(json['messageCount']) ?? 0,
      usedExactAssistantReplay: json['usedExactAssistantReplay'] == true,
      previousPromptTokens: _readInt(json['previousPromptTokens']),
      inputTokens: _readInt(json['inputTokens']),
      outputTokens: _readInt(json['outputTokens']),
      cacheHitTokens: _readInt(json['cacheHitTokens']),
      cacheMissTokens: _readInt(json['cacheMissTokens']),
      elapsedMilliseconds: _readInt(json['elapsedMilliseconds']),
      error: json['error']?.toString() ?? '',
    );
  }

  final String id;
  final String characterId;
  final DateTime recordedAt;
  final String model;
  final String endpointHost;
  final String cacheEpochId;
  final String rolloverReason;
  final String stablePrefixDigest;
  final int estimatedPromptTokens;
  final int messageCount;
  final bool usedExactAssistantReplay;
  final int? previousPromptTokens;
  final int? inputTokens;
  final int? outputTokens;
  final int? cacheHitTokens;
  final int? cacheMissTokens;
  final int? elapsedMilliseconds;
  final String error;

  int? get cacheHitRate {
    final hit = cacheHitTokens;
    final miss = cacheMissTokens;
    if (hit == null && miss == null) {
      return null;
    }
    final total = (hit ?? 0) + (miss ?? 0);
    if (total == 0) {
      return null;
    }
    return ((hit ?? 0) * 100 / total).round();
  }

  int? get previousPromptCoverage {
    final previous = previousPromptTokens;
    final hit = cacheHitTokens;
    if (previous == null || previous <= 0 || hit == null) {
      return null;
    }
    return (hit * 100 / previous).clamp(0, 100).round();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'recordedAt': recordedAt.toIso8601String(),
      'model': model,
      'endpointHost': endpointHost,
      'cacheEpochId': cacheEpochId,
      'rolloverReason': rolloverReason,
      'stablePrefixDigest': stablePrefixDigest,
      'estimatedPromptTokens': estimatedPromptTokens,
      'messageCount': messageCount,
      'usedExactAssistantReplay': usedExactAssistantReplay,
      if (previousPromptTokens != null)
        'previousPromptTokens': previousPromptTokens,
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
      if (cacheHitTokens != null) 'cacheHitTokens': cacheHitTokens,
      if (cacheMissTokens != null) 'cacheMissTokens': cacheMissTokens,
      if (elapsedMilliseconds != null)
        'elapsedMilliseconds': elapsedMilliseconds,
      if (error.trim().isNotEmpty) 'error': error,
    };
  }
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '');
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
