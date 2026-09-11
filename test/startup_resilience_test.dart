import 'dart:async';

import 'package:ai_roleplay_chat/bootstrap_app.dart';
import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/services/llm_api_client.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:ai_roleplay_chat/services/memory_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a visible shell while platform bootstrap is pending',
      (tester) async {
    final pending = Completer<void>();

    await tester.pumpWidget(
      AppBootstrap(
        initializePlatform: () => pending.future,
        readyBuilder: (_) => const MaterialApp(
          home: Text('应用已就绪'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('未完剧场'), findsOneWidget);
    expect(find.text('正在连接本地存档'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();

    expect(find.text('应用已就绪'), findsOneWidget);
  });

  testWidgets('platform bootstrap failure can retry without restarting',
      (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      AppBootstrap(
        initializePlatform: () async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('storage unavailable');
          }
        },
        readyBuilder: (_) => const MaterialApp(
          home: Text('重试成功'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('剧场布景没有完成'), findsOneWidget);
    expect(find.text('重新布景'), findsOneWidget);
    expect(find.text('复制诊断'), findsOneWidget);

    await tester.tap(find.text('重新布景'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('重试成功'), findsOneWidget);
  });

  test('data initialization exposes failure and recovers on retry', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = _FlakyLocalStore();
    final controller = AppStateController(
      store: store,
      apiClient: LlmApiClient(client: http.Client()),
      memoryService: MemoryService(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.isInitializing, isFalse);
    expect(controller.hasInitializationError, isTrue);
    expect(controller.initializationPhase, '读取应用设置');
    expect(controller.initializationDiagnostics, contains('StateError'));

    await controller.retryInitialization();

    expect(store.attempts, 2);
    expect(controller.isInitializing, isFalse);
    expect(controller.hasInitializationError, isFalse);
    expect(controller.characters, isNotEmpty);
    expect(controller.initializationPhase, '完成剧场布景');
  });
}

class _FlakyLocalStore extends LocalStore {
  int attempts = 0;

  @override
  Future<String> loadOrCreateInstallId() async {
    attempts += 1;
    if (attempts == 1) {
      throw StateError('test initialization failure');
    }
    return super.loadOrCreateInstallId();
  }
}
