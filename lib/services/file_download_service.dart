import 'file_download_service_stub.dart'
    if (dart.library.io) 'file_download_service_native.dart'
    if (dart.library.html) 'file_download_service_web.dart';

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) {
  return downloadTextFileImpl(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}
