import 'package:ai_roleplay_chat/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults mobile power save mode on for existing saves', () {
    final settings = AppSettings.fromJson(const <String, dynamic>{
      'apiUrl': 'https://example.test',
      'apiKey': 'key',
      'modelName': 'model',
    });

    expect(settings.mobilePowerSaveMode, isTrue);
    expect(settings.includeStreamUsage, isTrue);
    expect(settings.promptTokenBudget, 0);
    expect(settings.cacheIsolationId, isEmpty);
    expect(settings.toJson()['mobilePowerSaveMode'], isTrue);
    expect(settings.toJson()['includeStreamUsage'], isTrue);
  });

  test('prompt budget and cache isolation id survive serialization', () {
    final settings = AppSettings.initial().copyWith(
      promptTokenBudget: 64000,
      cacheIsolationId: 'install-cache_123',
    );

    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.promptTokenBudget, 64000);
    expect(restored.cacheIsolationId, 'install-cache_123');
  });

  test('can disable mobile power save mode explicitly', () {
    final settings = AppSettings.initial().copyWith(
      mobilePowerSaveMode: false,
    );

    expect(settings.mobilePowerSaveMode, isFalse);
    expect(
      AppSettings.fromJson(settings.toJson()).mobilePowerSaveMode,
      isFalse,
    );
    expect(
      AppSettings.fromJson(const <String, dynamic>{
        'mobilePowerSaveMode': 'false',
      }).mobilePowerSaveMode,
      isFalse,
    );
  });

  test('stream usage defaults on and can be disabled explicitly', () {
    final settings = AppSettings.initial().copyWith(
      includeStreamUsage: false,
    );

    expect(settings.includeStreamUsage, isFalse);
    expect(
      AppSettings.fromJson(settings.toJson()).includeStreamUsage,
      isFalse,
    );
    expect(
      AppSettings.fromJson(const <String, dynamic>{
        'includeStreamUsage': 'false',
      }).includeStreamUsage,
      isFalse,
    );
  });

  test('insecure HTTP consent is explicit and follows memory fallback', () {
    final defaults = AppSettings.fromJson(const <String, dynamic>{});
    expect(defaults.allowInsecureMainApi, isFalse);
    expect(defaults.allowInsecureMemoryApi, isFalse);

    final settings = AppSettings.initial().copyWith(
      memoryApiUrl: 'http://memory.example.test',
      memoryApiKey: 'memory-key',
      memoryModelName: 'memory-model',
      allowInsecureMainApi: false,
      allowInsecureMemoryApi: true,
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.allowInsecureMemoryApi, isTrue);
    expect(restored.memorySettingsOrFallback().allowInsecureMainApi, isTrue);
  });
}
