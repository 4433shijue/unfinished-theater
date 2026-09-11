import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> downloadTextFileImpl({
  required String filename,
  required String content,
  required String mimeType,
}) async {
  final directory = await getTemporaryDirectory();
  final safeFilename = _sanitizeFilename(
    filename.trim().isEmpty ? 'chat_export.html' : filename,
  );
  final path = '${directory.path}${Platform.pathSeparator}$safeFilename';
  final file = File(path);

  await file.writeAsString(content, flush: true);

  final result = await SharePlus.instance.share(
    ShareParams(
      title: safeFilename,
      subject: safeFilename,
      files: <XFile>[
        XFile(
          file.path,
          mimeType: mimeType,
          name: safeFilename,
        ),
      ],
      fileNameOverrides: <String>[safeFilename],
    ),
  );

  return result.status != ShareResultStatus.dismissed;
}

String _sanitizeFilename(String value) {
  return value.replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_');
}
