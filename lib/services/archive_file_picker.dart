import 'archive_file_data.dart';
export 'archive_file_data.dart' show maxArchiveImportBytes;
import 'archive_file_picker_stub.dart'
    if (dart.library.html) 'archive_file_picker_web.dart'
    if (dart.library.io) 'archive_file_picker_io.dart';

Future<ArchiveFileData?> pickArchiveFileData({
  List<String> allowedExtensions = const <String>['json', 'txt'],
  String webAccept = '.json,.txt,application/json,text/plain',
  int maxBytes = maxArchiveImportBytes,
}) {
  return pickArchiveFileDataImpl(
    allowedExtensions: allowedExtensions,
    webAccept: webAccept,
    maxBytes: maxBytes,
  );
}
