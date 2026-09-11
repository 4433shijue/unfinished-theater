import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'archive_file_data.dart';

Future<ArchiveFileData?> pickArchiveFileDataImpl({
  List<String> allowedExtensions = const <String>['json', 'txt'],
  String webAccept = '.json,.txt,application/json,text/plain',
  int maxBytes = maxArchiveImportBytes,
}) async {
  final completer = Completer<ArchiveFileData?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = webAccept
    ..style.display = 'none';

  void complete(ArchiveFileData? value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
    input.remove();
  }

  input.onChange.listen((_) {
    final file = input.files?.item(0);
    if (file == null) {
      complete(null);
      return;
    }
    try {
      validateArchiveFileMetadata(
        name: file.name,
        size: file.size,
        allowedExtensions: allowedExtensions,
        maxBytes: maxBytes,
      );
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      input.remove();
      return;
    }

    final reader = web.FileReader();
    reader.addEventListener(
      'error',
      ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('读取文件失败。'));
        }
        input.remove();
      }).toJS,
    );
    reader.addEventListener(
      'abort',
      ((web.Event _) {
        complete(null);
      }).toJS,
    );
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) {
        final byteBuffer = (reader.result as JSArrayBuffer?)?.toDart;
        final bytes = byteBuffer?.asUint8List();
        complete(
          ArchiveFileData(
            name: file.name,
            size: file.size,
            bytes: bytes ?? Uint8List(0),
          ),
        );
      }
    });
    reader.readAsArrayBuffer(file);
  });

  web.document.body?.children.add(input);
  input.click();

  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      input.remove();
      return null;
    },
  );
}
