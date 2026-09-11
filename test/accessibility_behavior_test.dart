import 'package:ai_roleplay_chat/theme/app_theme.dart';
import 'package:ai_roleplay_chat/utils/app_text_scaler.dart';
import 'package:ai_roleplay_chat/widgets/chat_input_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final systemScale in <double>[1, 1.5, 2, 3]) {
    test('system text scale $systemScale is never reduced by compact UI', () {
      final scaler = AppTextScaler(
        systemScaler: TextScaler.linear(systemScale),
        uiScale: 0.82,
      );

      expect(scaler.scale(16), closeTo(16 * systemScale, 0.001));
    });
  }

  test('high contrast theme uses explicit surface contrast', () {
    final theme = AppTheme.highContrastThemeFor(AppThemeVariant.sakura.id);

    expect(theme.colorScheme.surface, Colors.white);
    expect(theme.colorScheme.onSurface, Colors.black);
    expect(theme.colorScheme.outline, Colors.black);
  });

  testWidgets('chat composer stays usable and labelled at 3x text scale',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor(AppThemeVariant.sakura.id),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            textScaler: TextScaler.linear(3),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputBar(
                isSending: false,
                canPause: true,
                hasPendingMessages: true,
                tutorialTargetsEnabled: false,
                onSend: (_) async {},
                onLaunch: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('发送消息'), findsOneWidget);
    expect(find.bySemanticsLabel('暂停当前回复'), findsOneWidget);
  });
}
