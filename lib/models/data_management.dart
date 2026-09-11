import '../utils/id_generator.dart';

class DataArchivePreview {
  const DataArchivePreview({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.scope,
    required this.includeApiSecrets,
    required this.characterCount,
    required this.historyMessageCount,
    required this.npcCount,
    required this.npcMessageCount,
    required this.npcMigrationCount,
    required this.worldBookCount,
    required this.toolResultCount,
    required this.fanficResultCount,
    required this.userProfileCount,
    required this.hasSettings,
    required this.hasGamification,
    required this.hasIntegrityChecksum,
    required this.checksumValid,
    required this.schemaSupported,
  });

  final int schemaVersion;
  final String appVersion;
  final DateTime? exportedAt;
  final String scope;
  final bool includeApiSecrets;
  final int characterCount;
  final int historyMessageCount;
  final int npcCount;
  final int npcMessageCount;
  final int npcMigrationCount;
  final int worldBookCount;
  final int toolResultCount;
  final int fanficResultCount;
  final int userProfileCount;
  final bool hasSettings;
  final bool hasGamification;
  final bool hasIntegrityChecksum;
  final bool checksumValid;
  final bool schemaSupported;

  bool get canImport =>
      (!hasIntegrityChecksum || checksumValid) && schemaSupported;

  String get scopeLabel => switch (scope) {
        'all' => '全部数据',
        'character' => '单角色数据',
        _ => scope.trim().isEmpty ? '未知范围' : scope,
      };
}

class DataStorageReport {
  const DataStorageReport({
    required this.totalBytes,
    required this.items,
  });

  final int totalBytes;
  final List<DataStorageReportItem> items;
}

class DataStorageReportItem {
  const DataStorageReportItem({
    required this.label,
    required this.bytes,
    required this.description,
  });

  final String label;
  final int bytes;
  final String description;
}

class QuarantinedDataRecord {
  QuarantinedDataRecord({
    String? id,
    required this.storageKey,
    required this.rawValue,
    required this.error,
    DateTime? detectedAt,
  })  : id = id ?? IdGenerator.generic('quarantine'),
        detectedAt = detectedAt ?? DateTime.now();

  factory QuarantinedDataRecord.fromJson(Map<String, dynamic> json) {
    return QuarantinedDataRecord(
      id: json['id']?.toString(),
      storageKey: json['storageKey']?.toString() ?? '',
      rawValue: json['rawValue']?.toString() ?? '',
      error: json['error']?.toString() ?? 'unknown parse error',
      detectedAt: DateTime.tryParse(json['detectedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String storageKey;
  final String rawValue;
  final String error;
  final DateTime detectedAt;

  int get sizeBytes => rawValue.length * 2;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'storageKey': storageKey,
      'rawValue': rawValue,
      'error': error,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }
}

class SaveSnapshot {
  SaveSnapshot({
    String? id,
    required this.characterId,
    required this.characterName,
    required this.title,
    required this.archiveJson,
    DateTime? createdAt,
  })  : id = id ?? IdGenerator.generic('snapshot'),
        createdAt = createdAt ?? DateTime.now();

  factory SaveSnapshot.fromJson(Map<String, dynamic> json) {
    return SaveSnapshot(
      id: json['id']?.toString(),
      characterId: json['characterId']?.toString() ?? '',
      characterName: json['characterName']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名存档',
      archiveJson: json['archiveJson']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String characterId;
  final String characterName;
  final String title;
  final String archiveJson;
  final DateTime createdAt;

  int get sizeBytes => archiveJson.length * 2;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'characterId': characterId,
      'characterName': characterName,
      'title': title,
      'archiveJson': archiveJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
