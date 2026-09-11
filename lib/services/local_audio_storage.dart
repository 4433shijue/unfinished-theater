import 'dart:typed_data';

import 'local_audio_storage_data.dart';
import 'local_audio_storage_stub.dart'
    if (dart.library.html) 'local_audio_storage_web.dart'
    if (dart.library.io) 'local_audio_storage_io.dart';

class LocalAudioStorage {
  const LocalAudioStorage._();

  static Future<StoredAudioFile> saveAudio({
    required String trackId,
    required String originalName,
    required Uint8List bytes,
  }) {
    return saveAudioImpl(
      trackId: trackId,
      originalName: originalName,
      bytes: bytes,
    );
  }

  static Future<void> deleteAudio(String storageKey) {
    return deleteAudioImpl(storageKey);
  }

  static Future<String?> playbackUriFor(String storageKey) {
    return playbackUriForImpl(storageKey);
  }

  static void releasePlaybackUri(String uri) {
    releasePlaybackUriImpl(uri);
  }
}
