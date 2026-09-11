import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'local_audio_storage_data.dart';

const String _audioStoragePrefix = 'wwjc.user_audio.';

Future<StoredAudioFile> saveAudioImpl({
  required String trackId,
  required String originalName,
  required Uint8List bytes,
}) async {
  final storageKey = '$_audioStoragePrefix$trackId';
  web.window.localStorage.setItem(storageKey, base64Encode(bytes));
  final playbackUri = _createPlaybackUri(bytes, _mimeTypeFor(originalName));
  return StoredAudioFile(
    storageKey: storageKey,
    playbackUri: playbackUri,
    sizeBytes: bytes.length,
  );
}

Future<void> deleteAudioImpl(String storageKey) async {
  final clean = storageKey.trim();
  if (clean.isEmpty) {
    return;
  }
  web.window.localStorage.removeItem(clean);
}

Future<String?> playbackUriForImpl(String storageKey) async {
  final clean = storageKey.trim();
  if (clean.isEmpty) {
    return null;
  }
  final raw = web.window.localStorage.getItem(clean);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final bytes = base64Decode(raw);
    return _createPlaybackUri(bytes, 'audio/*');
  } catch (_) {
    return null;
  }
}

void releasePlaybackUriImpl(String uri) {
  if (uri.startsWith('blob:')) {
    web.URL.revokeObjectURL(uri);
  }
}

String _createPlaybackUri(Uint8List bytes, String mimeType) {
  final parts = <web.BlobPart>[bytes.toJS].toJS;
  final blob = web.Blob(
    parts,
    web.BlobPropertyBag(type: mimeType.trim().isEmpty ? 'audio/*' : mimeType),
  );
  return web.URL.createObjectURL(blob);
}

String _mimeTypeFor(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.mp3')) {
    return 'audio/mpeg';
  }
  if (lower.endsWith('.wav')) {
    return 'audio/wav';
  }
  if (lower.endsWith('.ogg')) {
    return 'audio/ogg';
  }
  if (lower.endsWith('.m4a') || lower.endsWith('.aac')) {
    return 'audio/aac';
  }
  if (lower.endsWith('.flac')) {
    return 'audio/flac';
  }
  if (lower.endsWith('.webm')) {
    return 'audio/webm';
  }
  return 'audio/*';
}
