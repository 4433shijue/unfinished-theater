import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:just_audio_web/just_audio_web.dart';

bool _registered = false;

void ensureWebAudioPluginRegistered() {
  if (_registered) {
    return;
  }
  JustAudioPlugin.registerWith(webPluginRegistrar);
  _registered = true;
}
