import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/app_state_controller.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';
import 'utils/app_text_scaler.dart';
import 'widgets/opening_curtain_gate.dart';
import 'widgets/theme_font_loader.dart';

class AiRoleplayApp extends StatelessWidget {
  const AiRoleplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final uiScale = context.select<AppStateController, double>(
      (controller) => controller.settings.uiScale,
    );
    final themeId = context.select<AppStateController, String>(
      (controller) => controller.settings.themeId,
    );
    final mobilePowerSaveMode = context.select<AppStateController, bool>(
      (controller) => controller.settings.mobilePowerSaveMode,
    );
    final isInitializing = context.select<AppStateController, bool>(
      (controller) => controller.isInitializing,
    );
    final hasInitializationError = context.select<AppStateController, bool>(
      (controller) => controller.hasInitializationError,
    );
    final initializationPhase = context.select<AppStateController, String>(
      (controller) => controller.initializationPhase,
    );

    return MaterialApp(
      title: '未完剧场',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(themeId),
      highContrastTheme: AppTheme.highContrastThemeFor(themeId),
      scrollBehavior: const _DesktopFriendlyScrollBehavior(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final controller = context.read<AppStateController>();
        final appChild = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            controller.resumeMusicAfterUserGesture();
          },
          child: child ?? const SizedBox.shrink(),
        );
        final layeredChild = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AppBackdrop(
              key: ValueKey<String>('app-backdrop-$themeId'),
              themeId: themeId,
              reduceMotion: mediaQuery.disableAnimations ||
                  mediaQuery.size.width < 980 && mobilePowerSaveMode,
            ),
            appChild,
          ],
        );
        return ThemeFontLoader(
          themeId: themeId,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: AppTextScaler(
                systemScaler: mediaQuery.textScaler,
                uiScale: uiScale,
              ),
            ),
            child: hasInitializationError
                ? layeredChild
                : OpeningCurtainGate(
                    ready: !isInitializing,
                    loadingLabel: initializationPhase,
                    onOpened: controller.openCurtainAndStartMusic,
                    child: layeredChild,
                  ),
          ),
        );
      },
      home: const HomeShell(),
    );
  }
}

class _DesktopFriendlyScrollBehavior extends MaterialScrollBehavior {
  const _DesktopFriendlyScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
