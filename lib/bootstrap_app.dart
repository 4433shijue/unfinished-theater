import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'controllers/app_state_controller.dart';
import 'models/save_envelope.dart';
import 'services/durable_web_preferences.dart';
import 'services/llm_api_client.dart';
import 'services/local_store.dart';
import 'services/memory_service.dart';
import 'services/web_audio_plugin_registrar.dart';
import 'widgets/startup_status_screen.dart';

typedef BootstrapInitializer = Future<void> Function();

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    this.initializePlatform,
    this.readyBuilder,
  });

  final BootstrapInitializer? initializePlatform;
  final WidgetBuilder? readyBuilder;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _isReady = false;
  bool _isLoading = true;
  Object? _error;
  StackTrace? _stackTrace;
  String _phase = '正在连接本地存档';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      final readyBuilder = widget.readyBuilder;
      if (readyBuilder != null) {
        return Builder(builder: readyBuilder);
      }
      return ChangeNotifierProvider<AppStateController>(
        create: (_) => AppStateController(
          store: LocalStore(),
          apiClient: LlmApiClient(),
          memoryService: MemoryService(),
        )..initialize(),
        child: const AiRoleplayApp(),
      );
    }

    return MaterialApp(
      title: '未完剧场',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF715B7A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: _isLoading
          ? StartupStatusScreen.loading(phase: _phase)
          : StartupStatusScreen.failure(
              phase: _phase,
              errorSummary: '本地运行环境初始化失败（${_error.runtimeType}）。',
              diagnostics: _diagnostics(),
              onRetry: _initialize,
            ),
    );
  }

  Future<void> _initialize() async {
    if (_isLoading && _error != null) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _stackTrace = null;
      _phase = '正在连接本地存档';
    });

    try {
      final initializer = widget.initializePlatform ?? _initializePlatform;
      await initializer();
      if (!mounted) {
        return;
      }
      setState(() {
        _isReady = true;
        _isLoading = false;
        _phase = '本地运行环境已就绪';
      });
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  String _diagnostics() {
    return <String>[
      '未完剧场启动诊断',
      '版本：$currentSaveAppVersion',
      '阶段：$_phase',
      '错误类型：${_error.runtimeType}',
      '错误：$_error',
      if (_stackTrace != null) '堆栈：$_stackTrace',
    ].join('\n');
  }
}

Future<void> _initializePlatform() async {
  await initializeDurableWebPreferences();
  ensureWebAudioPluginRegistered();
}
