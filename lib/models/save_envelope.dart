import 'dart:convert';

const int currentSaveSchemaVersion = 2;
const String currentSaveAppVersion = '2.11.0+2110';

class SaveEnvelope {
  const SaveEnvelope({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.payload,
    required this.checksum,
    required this.migrationHistory,
  });

  factory SaveEnvelope.wrap({
    required Map<String, dynamic> payload,
    String appVersion = currentSaveAppVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Iterable<String> migrationHistory = const <String>[],
  }) {
    final now = DateTime.now();
    final safePayload = _deepStringKeyedMap(payload);
    return SaveEnvelope(
      schemaVersion: currentSaveSchemaVersion,
      appVersion: appVersion,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      payload: safePayload,
      checksum: SaveEnvelopeChecksum.forPayload(safePayload),
      migrationHistory: migrationHistory.toList(growable: false),
    );
  }

  factory SaveEnvelope.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? _deepStringKeyedMap(Map<String, dynamic>.from(rawPayload))
        : <String, dynamic>{};
    final rawHistory = json['migrationHistory'];
    return SaveEnvelope(
      schemaVersion: _readInt(json['schemaVersion']),
      appVersion: json['appVersion']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      payload: payload,
      checksum: json['checksum']?.toString() ?? '',
      migrationHistory: rawHistory is List
          ? rawHistory.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }

  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> payload;
  final String checksum;
  final List<String> migrationHistory;

  bool get hasValidChecksum =>
      checksum.isNotEmpty &&
      checksum == SaveEnvelopeChecksum.forPayload(payload);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'payload': payload,
      'checksum': checksum,
      'migrationHistory': migrationHistory,
    };
  }
}

class SaveEnvelopeParseResult {
  const SaveEnvelopeParseResult({
    required this.payload,
    required this.schemaVersion,
    required this.appVersion,
    required this.checksumValid,
    required this.migrationHistory,
    required this.repairNotes,
    required this.isEnvelope,
  });

  final Map<String, dynamic> payload;
  final int schemaVersion;
  final String appVersion;
  final bool checksumValid;
  final List<String> migrationHistory;
  final List<String> repairNotes;
  final bool isEnvelope;
}

class SaveEnvelopeException implements Exception {
  const SaveEnvelopeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SaveEnvelopeCodec {
  const SaveEnvelopeCodec._();

  static Map<String, dynamic> wrapArchive({
    required Map<String, dynamic> legacyRoot,
    String appVersion = currentSaveAppVersion,
  }) {
    final root = Map<String, dynamic>.from(legacyRoot);
    final exportedAt =
        DateTime.tryParse(root['exportedAt']?.toString() ?? '') ??
            DateTime.now();
    final envelope = SaveEnvelope.wrap(
      payload: root,
      appVersion: appVersion,
      createdAt: exportedAt,
      updatedAt: DateTime.now(),
      migrationHistory: <String>[
        'v2 envelope created from legacy archive root',
      ],
    );
    return <String, dynamic>{
      'archiveType': 'ai_roleplay_chat.save_envelope',
      ...envelope.toJson(),
    };
  }

  static SaveEnvelopeParseResult unwrapArchive(
    Map<String, dynamic> root, {
    bool allowInvalidChecksum = false,
    bool allowFutureSchema = false,
  }) {
    if (root['payload'] is Map &&
        (root['archiveType'] == 'ai_roleplay_chat.save_envelope' ||
            root.containsKey('checksum'))) {
      final envelope = SaveEnvelope.fromJson(root);
      final notes = <String>[];
      if (!envelope.hasValidChecksum) {
        if (!allowInvalidChecksum) {
          throw const SaveEnvelopeException(
            '存档完整性校验失败，内容可能损坏或被修改。为保护现有数据，本次导入已停止。',
          );
        }
        notes.add('checksum mismatch; import must remain blocked');
      }
      if (envelope.schemaVersion > currentSaveSchemaVersion) {
        if (!allowFutureSchema) {
          throw SaveEnvelopeException(
            '存档版本 ${envelope.schemaVersion} 高于当前支持的 '
            '$currentSaveSchemaVersion，请先升级应用。',
          );
        }
        notes.add('future schema; import must remain blocked');
      }
      if (envelope.schemaVersion < currentSaveSchemaVersion) {
        notes.add(
          'schema migrated from ${envelope.schemaVersion} to '
          '$currentSaveSchemaVersion',
        );
      }
      return SaveEnvelopeParseResult(
        payload: envelope.payload,
        schemaVersion: envelope.schemaVersion,
        appVersion: envelope.appVersion,
        checksumValid: envelope.hasValidChecksum,
        migrationHistory: envelope.migrationHistory,
        repairNotes: notes,
        isEnvelope: true,
      );
    }

    final legacySchemaVersion = _readInt(root['schemaVersion']);
    if (legacySchemaVersion > currentSaveSchemaVersion && !allowFutureSchema) {
      throw SaveEnvelopeException(
        '存档版本 $legacySchemaVersion 高于当前支持的 '
        '$currentSaveSchemaVersion，请先升级应用。',
      );
    }

    return SaveEnvelopeParseResult(
      payload: Map<String, dynamic>.from(root),
      schemaVersion: legacySchemaVersion,
      appVersion: root['appVersion']?.toString() ?? '',
      checksumValid: true,
      migrationHistory: const <String>['legacy archive without envelope'],
      repairNotes: const <String>['legacy archive upgraded on import'],
      isEnvelope: false,
    );
  }
}

class SaveEnvelopeChecksum {
  const SaveEnvelopeChecksum._();

  static String forPayload(Map<String, dynamic> payload) {
    final canonical = jsonEncode(_canonicalize(payload));
    var hash = 0x811c9dc5;
    for (final code in canonical.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}

Map<String, dynamic> _deepStringKeyedMap(Map<String, dynamic> source) {
  return <String, dynamic>{
    for (final entry in source.entries)
      entry.key.toString(): _normalizeValue(entry.value),
  };
}

dynamic _normalizeValue(dynamic value) {
  if (value is Map) {
    return _deepStringKeyedMap(Map<String, dynamic>.from(value));
  }
  if (value is List) {
    return value.map(_normalizeValue).toList(growable: false);
  }
  return value;
}

int _readInt(Object? value) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
