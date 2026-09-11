import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('archive import commits through one recoverable storage batch',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = AppStateController(
      store: LocalStore(),
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final archive = await controller.exportAllDataArchive(
      includeApiSecrets: false,
    );

    final error = await controller.importDataArchive(
      archive,
      replaceExisting: true,
    );

    expect(error, isNull);
    expect(controller.characters, isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('storage_batch_archive_import'), isFalse);
    expect(prefs.getString('characters'), isNotEmpty);
  });
}
