import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'local_audio_file_data.dart';

Future<LocalAudioFileData?> pickLocalAudioFileDataImpl() async {
  final completer = Completer<LocalAudioFileData?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'audio/*'
    ..style.display = 'none';

  void complete(LocalAudioFileData? value) {
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

    final reader = web.FileReader();
    reader.addEventListener(
      'error',
      ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('读取音频文件失败。'));
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
      if (completer.isCompleted) {
        return;
      }
      final byteBuffer = (reader.result as JSArrayBuffer?)?.toDart;
      final bytes = byteBuffer?.asUint8List();
      complete(
        LocalAudioFileData(
          name: file.name,
          size: file.size,
          bytes: bytes ?? Uint8List(0),
          mimeType: file.type.isEmpty ? null : file.type,
          extension: _extensionOf(file.name),
        ),
      );
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

String? _extensionOf(String name) {
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex >= name.length - 1) {
    return null;
  }
  return name.substring(dotIndex + 1);
}
