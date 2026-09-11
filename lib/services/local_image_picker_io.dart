import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'local_image_file_data.dart';

Future<LocalImageFileData?> pickLocalImageFileDataImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  final file = result?.files.isEmpty == true ? null : result?.files.single;
  if (file == null) {
    return null;
  }

  final bytes = file.bytes ??
      (file.path == null || file.path!.trim().isEmpty
          ? null
          : await io.File(file.path!).readAsBytes());
  return LocalImageFileData(
    name: file.name,
    size: file.size > 0 ? file.size : (bytes?.length ?? 0),
    bytes: bytes ?? Uint8List(0),
    extension: file.extension,
  );
}
