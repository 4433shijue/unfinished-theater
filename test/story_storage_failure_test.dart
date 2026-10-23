import 'dart:convert';
import 'package:ai_roleplay_chat/models/story_continuity.dart';
import 'package:ai_roleplay_chat/models/dialogue_history.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'failed second write rolls all story changes back, including after restart',
      () async {
    final old = StoryContinuityState(characterId: 'w', data: {'sequence': 3});
    final platform = PartialFailureStore(
        {'flutter.story_continuity_w': jsonEncode(old.toJson())});
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = platform;
    final store = LocalStore();
    final next = old.copy()..data['sequence'] = 4;
    await expectLater(
        store.commitStoryWorkspace(
            state: next, history: DialogueHistory.empty('w')),
        throwsStateError);
    expect((await store.loadStoryContinuity('w')).sequence, 3);
    expect((await SharedPreferences.getInstance()).containsKey('history_w'),
        false);
    SharedPreferences.resetStatic();
    expect((await LocalStore().loadStoryContinuity('w')).sequence, 3);
    expect(
        (await platform.getAll())
            .keys
            .where((key) => key.contains('storage_batch')),
        isEmpty);
    SharedPreferences.setMockInitialValues({});
  });
}

class PartialFailureStore extends InMemorySharedPreferencesStore {
  PartialFailureStore(super.data) : super.withData();
  bool failed = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.history_w' && !failed) {
      failed = true;
      return false;
    }
    return super.setValue(type, key, value);
  }
}
