import 'dart:typed_data';

import 'local_audio_storage_data.dart';

Future<StoredAudioFile> saveAudioImpl({
  required String trackId,
  required String originalName,
  required Uint8List bytes,
}) async {
  return StoredAudioFile(
    storageKey: '',
    playbackUri: '',
    sizeBytes: bytes.length,
  );
}

Future<void> deleteAudioImpl(String storageKey) async {}

Future<String?> playbackUriForImpl(String storageKey) async {
  return null;
}

void releasePlaybackUriImpl(String uri) {}
