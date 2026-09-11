import 'package:ai_roleplay_chat/models/save_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wraps and unwraps archive payload with checksum', () {
    final legacyRoot = <String, dynamic>{
      'schemaVersion': 1,
      'appVersion': '2.5.5+255',
      'exportedAt': '2026-05-21T00:00:00.000',
      'data': <String, dynamic>{
        'characters': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'char-1'},
        ],
      },
    };

    final wrapped = SaveEnvelopeCodec.wrapArchive(legacyRoot: legacyRoot);
    final parsed = SaveEnvelopeCodec.unwrapArchive(wrapped);

    expect(parsed.payload['data'], legacyRoot['data']);
    expect(parsed.checksumValid, isTrue);
    expect(parsed.appVersion, currentSaveAppVersion);
    expect(parsed.schemaVersion, currentSaveSchemaVersion);
  });

  test('keeps legacy root importable', () {
    final legacyRoot = <String, dynamic>{
      'schemaVersion': 1,
      'appVersion': '2.5.5+255',
      'data': <String, dynamic>{'characters': <Object>[]},
    };

    final parsed = SaveEnvelopeCodec.unwrapArchive(legacyRoot);

    expect(parsed.payload, legacyRoot);
    expect(parsed.checksumValid, isTrue);
    expect(parsed.migrationHistory.single, contains('legacy archive'));
  });

  test('blocks a tampered envelope by default', () {
    final wrapped = SaveEnvelopeCodec.wrapArchive(
      legacyRoot: <String, dynamic>{
        'data': <String, dynamic>{'characters': <Object>[]},
      },
    );
    final payload = Map<String, dynamic>.from(wrapped['payload'] as Map);
    payload['tampered'] = true;
    wrapped['payload'] = payload;

    expect(
      () => SaveEnvelopeCodec.unwrapArchive(wrapped),
      throwsA(isA<SaveEnvelopeException>()),
    );

    final preview = SaveEnvelopeCodec.unwrapArchive(
      wrapped,
      allowInvalidChecksum: true,
    );
    expect(preview.checksumValid, isFalse);
  });

  test('blocks future schema envelopes by default', () {
    final wrapped = SaveEnvelopeCodec.wrapArchive(
      legacyRoot: <String, dynamic>{'data': <String, dynamic>{}},
    );
    wrapped['schemaVersion'] = currentSaveSchemaVersion + 1;
    wrapped['checksum'] = SaveEnvelopeChecksum.forPayload(
      Map<String, dynamic>.from(wrapped['payload'] as Map),
    );

    expect(
      () => SaveEnvelopeCodec.unwrapArchive(wrapped),
      throwsA(isA<SaveEnvelopeException>()),
    );
  });

  test('blocks future legacy archives by default', () {
    final legacy = <String, dynamic>{
      'schemaVersion': currentSaveSchemaVersion + 1,
      'data': <String, dynamic>{},
    };

    expect(
      () => SaveEnvelopeCodec.unwrapArchive(legacy),
      throwsA(isA<SaveEnvelopeException>()),
    );
  });
}
