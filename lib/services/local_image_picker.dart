import 'local_image_file_data.dart';
import 'local_image_picker_stub.dart'
    if (dart.library.html) 'local_image_picker_web.dart'
    if (dart.library.io) 'local_image_picker_io.dart';

Future<LocalImageFileData?> pickLocalImageFileData() {
  return pickLocalImageFileDataImpl();
}
