import 'local_audio_file_data.dart';
import 'local_audio_picker_stub.dart'
    if (dart.library.html) 'local_audio_picker_web.dart'
    if (dart.library.io) 'local_audio_picker_io.dart';

Future<LocalAudioFileData?> pickLocalAudioFileData() {
  return pickLocalAudioFileDataImpl();
}
