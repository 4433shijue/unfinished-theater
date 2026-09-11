import '../theme/app_theme.dart';
import '../utils/id_generator.dart';

class AppSettings {
  const AppSettings({
    required this.apiUrl,
    required this.apiKey,
    required this.modelName,
    required this.requestTimeoutSeconds,
    required this.autoSummaryMinMessages,
    required this.memoryContextItems,
    required this.uiScale,
    required this.themeId,
    this.memoryApiUrl = '',
    this.memoryApiKey = '',
    this.memoryModelName = '',
    this.experienceMode = false,
    this.mobilePowerSaveMode = true,
    this.includeStreamUsage = true,
    this.promptTokenBudget = 0,
    this.cacheIsolationId = '',
    this.allowInsecureMainApi = false,
    this.allowInsecureMemoryApi = false,
  });

  factory AppSettings.initial() {
    return const AppSettings(
      apiUrl: '',
      apiKey: '',
      modelName: 'gpt-4o-mini',
      requestTimeoutSeconds: 180,
      autoSummaryMinMessages: 6,
      memoryContextItems: 4,
      uiScale: 1,
      themeId: 'sakura',
      experienceMode: false,
      mobilePowerSaveMode: true,
      includeStreamUsage: true,
      promptTokenBudget: 0,
      cacheIsolationId: '',
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      apiUrl: json['apiUrl']?.toString() ?? '',
      apiKey: json['apiKey']?.toString() ?? '',
      modelName: json['modelName']?.toString() ?? 'gpt-4o-mini',
      requestTimeoutSeconds:
          _readInt(json['requestTimeoutSeconds'], fallback: 180),
      autoSummaryMinMessages:
          _readInt(json['autoSummaryMinMessages'], fallback: 6),
      memoryContextItems: _readInt(json['memoryContextItems'], fallback: 4),
      uiScale: _readDouble(json['uiScale'], fallback: 1),
      themeId: _normalizeThemeId(json['themeId']?.toString()),
      memoryApiUrl: json['memoryApiUrl']?.toString() ?? '',
      memoryApiKey: json['memoryApiKey']?.toString() ?? '',
      memoryModelName: json['memoryModelName']?.toString() ?? '',
      experienceMode: json['experienceMode'] == true,
      mobilePowerSaveMode:
          _readBool(json['mobilePowerSaveMode'], fallback: true),
      includeStreamUsage: _readBool(json['includeStreamUsage'], fallback: true),
      promptTokenBudget: _readInt(json['promptTokenBudget'], fallback: 0),
      cacheIsolationId: json['cacheIsolationId']?.toString() ?? '',
      allowInsecureMainApi:
          _readBool(json['allowInsecureMainApi'], fallback: false),
      allowInsecureMemoryApi:
          _readBool(json['allowInsecureMemoryApi'], fallback: false),
    );
  }

  final String apiUrl;
  final String apiKey;
  final String modelName;
  final int requestTimeoutSeconds;
  final int autoSummaryMinMessages;
  final int memoryContextItems;
  final double uiScale;
  final String themeId;
  final String memoryApiUrl;
  final String memoryApiKey;
  final String memoryModelName;
  final bool experienceMode;
  final bool mobilePowerSaveMode;
  final bool includeStreamUsage;
  final int promptTokenBudget;
  final String cacheIsolationId;
  final bool allowInsecureMainApi;
  final bool allowInsecureMemoryApi;

  String get effectiveApiUrl => apiUrl;

  String get effectiveApiKey => apiKey;

  String get effectiveModelName => modelName;

  bool get canChat {
    return effectiveApiUrl.trim().isNotEmpty &&
        effectiveApiKey.trim().isNotEmpty &&
        effectiveModelName.trim().isNotEmpty;
  }

  bool get hasCompleteMemoryApi {
    return memoryApiUrl.trim().isNotEmpty &&
        memoryApiKey.trim().isNotEmpty &&
        memoryModelName.trim().isNotEmpty;
  }

  bool get hasPartialMemoryApi {
    final fields = <String>[
      memoryApiUrl.trim(),
      memoryApiKey.trim(),
      memoryModelName.trim(),
    ];
    final filled = fields.where((value) => value.isNotEmpty).length;
    return filled > 0 && filled < fields.length;
  }

  AppSettings memorySettingsOrFallback() {
    if (!hasCompleteMemoryApi) {
      return this;
    }

    return copyWith(
      apiUrl: memoryApiUrl.trim(),
      apiKey: memoryApiKey.trim(),
      modelName: memoryModelName.trim(),
      experienceMode: false,
      allowInsecureMainApi: allowInsecureMemoryApi,
    );
  }

  AppSettings copyWith({
    String? apiUrl,
    String? apiKey,
    String? modelName,
    int? requestTimeoutSeconds,
    int? autoSummaryMinMessages,
    int? memoryContextItems,
    double? uiScale,
    String? themeId,
    String? memoryApiUrl,
    String? memoryApiKey,
    String? memoryModelName,
    bool? experienceMode,
    bool? mobilePowerSaveMode,
    bool? includeStreamUsage,
    int? promptTokenBudget,
    String? cacheIsolationId,
    bool? allowInsecureMainApi,
    bool? allowInsecureMemoryApi,
  }) {
    return AppSettings(
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      autoSummaryMinMessages:
          autoSummaryMinMessages ?? this.autoSummaryMinMessages,
      memoryContextItems: memoryContextItems ?? this.memoryContextItems,
      uiScale: uiScale ?? this.uiScale,
      themeId: _normalizeThemeId(themeId ?? this.themeId),
      memoryApiUrl: memoryApiUrl ?? this.memoryApiUrl,
      memoryApiKey: memoryApiKey ?? this.memoryApiKey,
      memoryModelName: memoryModelName ?? this.memoryModelName,
      experienceMode: experienceMode ?? this.experienceMode,
      mobilePowerSaveMode: mobilePowerSaveMode ?? this.mobilePowerSaveMode,
      includeStreamUsage: includeStreamUsage ?? this.includeStreamUsage,
      promptTokenBudget: promptTokenBudget ?? this.promptTokenBudget,
      cacheIsolationId: cacheIsolationId ?? this.cacheIsolationId,
      allowInsecureMainApi: allowInsecureMainApi ?? this.allowInsecureMainApi,
      allowInsecureMemoryApi:
          allowInsecureMemoryApi ?? this.allowInsecureMemoryApi,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'apiUrl': apiUrl,
      'apiKey': apiKey,
      'modelName': modelName,
      'requestTimeoutSeconds': requestTimeoutSeconds,
      'autoSummaryMinMessages': autoSummaryMinMessages,
      'memoryContextItems': memoryContextItems,
      'uiScale': uiScale,
      'themeId': themeId,
      'memoryApiUrl': memoryApiUrl,
      'memoryApiKey': memoryApiKey,
      'memoryModelName': memoryModelName,
      'experienceMode': experienceMode,
      'mobilePowerSaveMode': mobilePowerSaveMode,
      'includeStreamUsage': includeStreamUsage,
      'promptTokenBudget': promptTokenBudget,
      'cacheIsolationId': cacheIsolationId,
      'allowInsecureMainApi': allowInsecureMainApi,
      'allowInsecureMemoryApi': allowInsecureMemoryApi,
    };
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(dynamic value, {required double fallback}) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'true' || '1' || 'yes' || 'on' => true,
      'false' || '0' || 'no' || 'off' => false,
      _ => fallback,
    };
  }

  static String _normalizeThemeId(String? value) {
    final id = value?.trim() ?? '';
    if (id.startsWith('custom_theme_')) {
      return id;
    }
    return AppThemeVariant.byId(id).id;
  }
}

class SettingsPreset {
  SettingsPreset({
    String? id,
    required this.name,
    required this.settings,
    DateTime? createdAt,
  })  : id = id ?? IdGenerator.generic('preset'),
        createdAt = createdAt ?? DateTime.now();

  factory SettingsPreset.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settings'];
    return SettingsPreset(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '未命名预设',
      settings: AppSettings.fromJson(
        rawSettings is Map
            ? Map<String, dynamic>.from(rawSettings)
            : const <String, dynamic>{},
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String name;
  final AppSettings settings;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'settings': settings.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
