import 'package:ai_roleplay_chat/services/archive_file_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts supported archive metadata within the size limit', () {
    expect(
      () => validateArchiveFileMetadata(
        name: 'theater.JSON',
        size: 1024,
        allowedExtensions: const <String>['json', 'txt'],
      ),
      returnsNormally,
    );
  });

  test('rejects a disguised archive extension', () {
    expect(
      () => validateArchiveFileMetadata(
        name: 'theater.json.exe',
        size: 1024,
        allowedExtensions: const <String>['json', 'txt'],
      ),
      throwsA(isA<ArchiveFileSelectionException>()),
    );
  });

  test('rejects archive metadata above the configured limit', () {
    expect(
      () => validateArchiveFileMetadata(
        name: 'theater.json',
        size: maxArchiveImportBytes + 1,
        allowedExtensions: const <String>['json'],
      ),
      throwsA(
        isA<ArchiveFileSelectionException>().having(
          (error) => error.message,
          'message',
          contains('64MB'),
        ),
      ),
    );
  });
}
