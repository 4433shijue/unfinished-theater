import 'dart:io' as io;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'local_audio_storage_data.dart';

Future<StoredAudioFile> saveAudioImpl({
  required String trackId,
  required String originalName,
  required Uint8List bytes,
}) async {
  final directory = await _audioDirectory();
  await directory.create(recursive: true);
  final extension = _extensionOf(originalName);
  final fileName = extension.isEmpty ? '$trackId.audio' : '$trackId.$extension';
  final file =
      io.File('${directory.path}${io.Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return StoredAudioFile(
    storageKey: file.path,
    playbackUri: file.path,
    sizeBytes: bytes.length,
  );
}

Future<void> deleteAudioImpl(String storageKey) async {
  final clean = storageKey.trim();
  if (clean.isEmpty) {
    return;
  }
  final file = io.File(clean);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<String?> playbackUriForImpl(String storageKey) async {
  final clean = storageKey.trim();
  if (clean.isEmpty) {
    return null;
  }
  final file = io.File(clean);
  if (!await file.exists()) {
    return null;
  }
  return file.path;
}

void releasePlaybackUriImpl(String uri) {}

Future<io.Directory> _audioDirectory() async {
  final root = await getApplicationSupportDirectory();
  return io.Directory('${root.path}${io.Platform.pathSeparator}user_audio');
}

String _extensionOf(String name) {
  final clean = name.trim();
  final dotIndex = clean.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex >= clean.length - 1) {
    return '';
  }
  return clean.substring(dotIndex + 1).toLowerCase();
}
