import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'archive_file_data.dart';

Future<ArchiveFileData?> pickArchiveFileDataImpl({
  List<String> allowedExtensions = const <String>['json', 'txt'],
  String webAccept = '.json,.txt,application/json,text/plain',
  int maxBytes = maxArchiveImportBytes,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    allowMultiple: false,
    withData: false,
    withReadStream: true,
  );
  final file = result?.files.isEmpty == true ? null : result?.files.single;
  if (file == null) {
    return null;
  }

  validateArchiveFileMetadata(
    name: file.name,
    size: file.size,
    allowedExtensions: allowedExtensions,
    maxBytes: maxBytes,
  );

  var bytes = file.bytes;
  bytes ??= await _readBoundedStream(file.readStream, maxBytes);
  final path = file.path?.trim();
  if (bytes == null && path != null && path.isNotEmpty) {
    bytes = await _readBoundedStream(io.File(path).openRead(), maxBytes);
  }
  if (bytes == null) {
    return ArchiveFileData(
      name: file.name,
      size: file.size,
      bytes: Uint8List(0),
    );
  }
  if (bytes.length > maxBytes) {
    throw ArchiveFileSelectionException(
      '文件读取内容超过 ${(maxBytes / (1024 * 1024)).toStringAsFixed(0)}MB 上限。',
    );
  }
  return ArchiveFileData(
    name: file.name,
    size: file.size > 0 ? file.size : bytes.length,
    bytes: bytes,
  );
}

Future<Uint8List?> _readBoundedStream(
  Stream<List<int>>? stream,
  int maxBytes,
) async {
  if (stream == null) {
    return null;
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (builder.length + chunk.length > maxBytes) {
      throw ArchiveFileSelectionException(
        '文件读取内容超过 ${(maxBytes / (1024 * 1024)).toStringAsFixed(0)}MB 上限。',
      );
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}
