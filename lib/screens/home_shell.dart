import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../data/release_notes.dart';
import '../theme/app_theme.dart';
import '../theme/theme_skin_assets.dart';
import '../widgets/release_notes_dialog.dart';
import '../widgets/startup_status_screen.dart';
import '../widgets/tutorial_guide.dart';
import 'characters_screen.dart';
import 'chat_screen.dart';
import 'npc_chats_screen.dart';
import 'settings_screen.dart';
import 'user_profiles_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  TutorialGuideSequence? _activeTutorial;
  bool _releaseNoticeVisible = false;
  Timer? _cthulhuTimer;
  String? _cthulhuTimerThemeId;
  final math.Random _cthulhuRandom = math.Random();
  int _cthulhuGazeCount = 0;

  static const List<String> _cthulhuMessages = <String>[
    '祂在凝视你...',
    '你听到了吗....',
    '我的子民...',
    '祂在呼唤你...',
  ];

  bool get _tutorialVisible => _activeTutorial != null;

  @override
  void initState() {
    super.initState();
    TutorialGuideCoordinator.requests.addListener(_handleTutorialRequest);
  }

  @override
  void dispose() {
    TutorialGuideCoordinator.requests.removeListener(_handleTutorialRequest);
    _cthulhuTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final uiScale = AppTheme.uiScaleOf(context);
    final themeId = controller.settings.themeId;

    if (controller.hasInitializationError) {
      return StartupStatusScreen.failure(
        phase: controller.initializationPhase,
        errorSummary: controller.initializationErrorSummary,
        diagnostics: controller.initializationDiagnostics,
        onRetry: controller.retryInitialization,
        retryLabel: controller.hasQuarantinedData ? '使用安全数据继续' : '重新布景',
        failureMessage: controller.hasQuarantinedData
            ? '检测到无法解析的本地数据，原始内容已经完整移入隔离区。继续后会使用安全默认值，隔离原文可在设置的数据保险箱中复制。'
            : null,
      );
    }

    if (controller.isInitializing) {
      return StartupStatusScreen.loading(
        phase: controller.initializationPhase,
      );
    }

    _scheduleTutorialIfNeeded(controller);
    _scheduleReleaseNoticeIfNeeded(controller);
    _syncCthulhuWatcher(themeId, controller);
    final pages = const <Widget>[
      ChatScreen(),
      CharactersScreen(),
      NpcChatsScreen(),
      UserProfilesScreen(),
      SettingsScreen(),
    ];
    final labels = <String>['对话', '角色', 'NPC', '用户', '设置']
        .map(AppTheme.glitchText)
        .toList(growable: false);
    final mobileNavIndexes = const <int>[0, 1, 2, 4];
    final subtitles = <String>[
      '故事控制台',
      '角色档案',
      'NPC 私聊',
      '用户人设',
      '应用设置',
    ].map(AppTheme.glitchText).toList(growable: false);
    const icons = <IconData>[
      Icons.chat_bubble_outline_rounded,
      Icons.theater_comedy_outlined,
      Icons.badge_outlined,
      Icons.person_outline_rounded,
      Icons.tune_rounded,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useMobileShell = _useMobileStyleShell(constraints.maxWidth);
        final selectedIndex = controller.currentTabIndex;
        _noteCthulhuMenuVisitIfNeeded(controller, selectedIndex);
        final mediaQuery = MediaQuery.of(context);
        final safeTopInset = math.max(
          mediaQuery.padding.top,
          mediaQuery.viewPadding.top,
        );
        final safeBottomInset = math.max(
          mediaQuery.padding.bottom,
          mediaQuery.viewPadding.bottom,
        );
        final keyboardVisible = mediaQuery.viewInsets.bottom > 0;
        final mobileDockHeight = (78 * uiScale) + safeBottomInset;
        final content = IndexedStack(
          index: selectedIndex,
          children: pages,
        );

        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              SafeArea(
                top: !useMobileShell,
                bottom: !useMobileShell,
                child: useMobileShell
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                          10 * uiScale,
                          safeTopInset + 8 * uiScale,
                          10 * uiScale,
                          0,
                        ),
                        child: Column(
                          children: [
                            if (selectedIndex != 0) ...[
                              _ShellHeader(
                                title: labels[selectedIndex],
                                subtitle: subtitles[selectedIndex],
                                compact: true,
                                onSearch: _openGlobalSearch,
                              ),
                              SizedBox(height: 8 * uiScale),
                            ],
                            Expanded(child: content),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: keyboardVisible
                                  ? SizedBox(height: 6 * uiScale)
                                  : SizedBox(
                                      key: const ValueKey<String>(
                                        'mobile-dock',
                                      ),
                                      height: mobileDockHeight,
                                      child: SizedBox(
                                        height: mobileDockHeight,
                                        child: OverflowBox(
                                          minWidth: constraints.maxWidth,
                                          maxWidth: constraints.maxWidth,
                                          minHeight: mobileDockHeight,
                                          maxHeight: mobileDockHeight,
                                          alignment: Alignment.bottomCenter,
                                          child: SizedBox(
                                            width: constraints.maxWidth,
                                            height: mobileDockHeight,
                                            child: _MobileDock(
                                              labels: labels,
                                              icons: icons,
                                              selectedIndex: selectedIndex,
                                              visibleIndexes: mobileNavIndexes,
                                              onSelect: (index) =>
                                                  _selectTab(controller, index),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          22 * uiScale,
                          22 * uiScale,
                          22 * uiScale,
                          18 * uiScale,
                        ),
                        child: Row(
                          children: [
                            _NeonSidebar(
                              labels: labels,
                              icons: icons,
                              selectedIndex: selectedIndex,
                              onSelect: (index) =>
                                  _selectTab(controller, index),
                            ),
                            SizedBox(width: 18 * uiScale),
                            Expanded(
                              child: Column(
                                children: [
                                  _ShellHeader(
                                    title: labels[selectedIndex],
                                    subtitle: subtitles[selectedIndex],
                                    onSearch: _openGlobalSearch,
                                  ),
                                  SizedBox(height: 18 * uiScale),
                                  Expanded(child: content),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (_activeTutorial case final tutorial?)
                TutorialGuideOverlay(
                  sequence: tutorial,
                  onCompleted: () => _finishTutorial(skipped: false),
                  onSkipped: () => _finishTutorial(skipped: true),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _useMobileStyleShell(double width) {
    return width < 980;
  }

  Future<void> _openGlobalSearch() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _GlobalSearchDialog(),
    );
  }

  void _scheduleTutorialIfNeeded(AppStateController controller) {
    if (controller.isInitializing ||
        !controller.shouldShowTutorial ||
        _tutorialVisible) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tutorialVisible || !controller.shouldShowTutorial) {
        return;
      }
      _showTutorial();
    });
  }

  void _scheduleReleaseNoticeIfNeeded(AppStateController controller) {
    if (controller.isInitializing ||
        controller.shouldShowTutorial ||
        !controller.shouldShowReleaseNotice ||
        _tutorialVisible ||
        _releaseNoticeVisible) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          controller.shouldShowTutorial ||
          !controller.shouldShowReleaseNotice ||
          _tutorialVisible ||
          _releaseNoticeVisible) {
        return;
      }
      unawaited(_showReleaseNotice());
    });
  }

  void _showTutorial() {
    if (!mounted || _tutorialVisible) {
      return;
    }
    setState(() => _activeTutorial = quickStartTutorial);
  }

  Future<void> _finishTutorial({required bool skipped}) async {
    final tutorial = _activeTutorial;
    if (tutorial == null) {
      return;
    }
    setState(() => _activeTutorial = null);
    if (tutorial.completesOnboarding && mounted) {
      await context.read<AppStateController>().completeTutorial(
            skipped: skipped,
          );
    }
  }

  void _handleTutorialRequest() {
    final request = TutorialGuideCoordinator.requests.value;
    if (request == null || !mounted) {
      return;
    }
    TutorialGuideCoordinator.requests.value = null;
    setState(() => _activeTutorial = request);
  }

  void _selectTab(AppStateController controller, int index) {
    final target = switch (index) {
      0 => TutorialTargetId.navChat,
      1 => TutorialTargetId.navCharacters,
      2 => TutorialTargetId.navNpc,
      4 => TutorialTargetId.navSettings,
      _ => null,
    };
    if (target != null) {
      TutorialTargetRegistry.report(target);
    }
    controller.setCurrentTabIndex(index);
  }

  Future<void> _showReleaseNotice() async {
    _releaseNoticeVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ReleaseNotesDialog(
        release: currentReleaseNotes,
      ),
    );
    _releaseNoticeVisible = false;
    if (!mounted) {
      return;
    }
    await context.read<AppStateController>().completeReleaseNotice();
  }

  void _syncCthulhuWatcher(
    String themeId,
    AppStateController controller,
  ) {
    if (themeId != AppThemeVariant.cthulhu.id) {
      _cthulhuTimer?.cancel();
      _cthulhuTimer = null;
      _cthulhuTimerThemeId = null;
      _cthulhuGazeCount = 0;
      return;
    }
    if (_cthulhuTimerThemeId == themeId && _cthulhuTimer != null) {
      return;
    }
    _cthulhuTimer?.cancel();
    _cthulhuTimerThemeId = themeId;
    _cthulhuTimer = Timer(
      const Duration(minutes: 3),
      () => _showCthulhuGaze(controller),
    );
  }

  void _scheduleNextCthulhuGaze(AppStateController controller) {
    _cthulhuTimer?.cancel();
    if (!mounted || controller.settings.themeId != AppThemeVariant.cthulhu.id) {
      _cthulhuTimer = null;
      return;
    }
    final seconds = 300 + _cthulhuRandom.nextInt(301);
    _cthulhuTimer = Timer(
      Duration(seconds: seconds),
      () => _showCthulhuGaze(controller),
    );
  }

  void _showCthulhuGaze(AppStateController controller) {
    if (!mounted || controller.settings.themeId != AppThemeVariant.cthulhu.id) {
      _cthulhuTimer?.cancel();
      _cthulhuTimer = null;
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final firstTime = _cthulhuGazeCount == 0;
    final messageIndex =
        firstTime ? 0 : _cthulhuRandom.nextInt(_cthulhuMessages.length);
    final message = _cthulhuMessages[messageIndex];
    _cthulhuGazeCount++;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _CthulhuGazeOverlay(
        message: message,
        onDismissed: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );
    overlay.insert(entry);
    unawaited(controller.noteCthulhuGaze());
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
    _scheduleNextCthulhuGaze(controller);
  }

  void _noteCthulhuMenuVisitIfNeeded(
    AppStateController controller,
    int selectedIndex,
  ) {
    if (controller.settings.themeId != AppThemeVariant.cthulhu.id) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          controller.settings.themeId != AppThemeVariant.cthulhu.id) {
        return;
      }
      unawaited(controller.noteCthulhuMenuVisit(selectedIndex));
    });
  }
}

class _CthulhuGazeOverlay extends StatefulWidget {
  const _CthulhuGazeOverlay({
    required this.message,
    required this.onDismissed,
  });

  final String message;
  final VoidCallback onDismissed;

  @override
  State<_CthulhuGazeOverlay> createState() => _CthulhuGazeOverlayState();
}

class _CthulhuGazeOverlayState extends State<_CthulhuGazeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _textProgressController;
  String _visibleText = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _textProgressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.message.length * 80),
    )..forward();

    _textProgressController.addListener(_onTextProgress);
  }

  void _onTextProgress() {
    final count =
        (widget.message.length * _textProgressController.value).round();
    if (_visibleText.length != count) {
      setState(() {
        _visibleText =
            widget.message.substring(0, count.clamp(0, widget.message.length));
      });
    }
  }

  @override
  void dispose() {
    _textProgressController.removeListener(_onTextProgress);
    _fadeController.dispose();
    _textProgressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeVariant.cthulhu.palette;
    return FadeTransition(
      opacity: _fadeController,
      child: Material(
        color: Colors.black.withValues(alpha: 0.88),
        child: GestureDetector(
          onTap: widget.onDismissed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Eye icon
                  Icon(
                    Icons.visibility_outlined,
                    size: 42,
                    color: palette.primary.withValues(alpha: 0.72),
                  ),
                  const SizedBox(height: 20),
                  // Streaming text
                  Text(
                    _visibleText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      color: palette.soft,
                      fontFamily: 'AbyssSerif',
                      shadows: const <Shadow>[
                        Shadow(
                          color: Color(0xFF7A211B),
                          offset: Offset(0, 0),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Cursor blink
                  if (_textProgressController.value < 1)
                    Container(
                      width: 3,
                      height: 32,
                      color: palette.soft.withValues(alpha: 0.8),
                    ),
                  if (_textProgressController.value >= 1)
                    Text(
                      '点击任意位置关闭',
                      style: TextStyle(
                        color: palette.soft.withValues(alpha: 0.3),
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    required this.themeId,
    required this.reduceMotion,
  });

  final String themeId;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final descriptor = AppTheme.describeTheme(themeId);
    final palette = descriptor.palette;
    final effect = _backgroundEffectFor(descriptor);
    final skinSpec = descriptor.isRuntimeTheme
        ? null
        : ThemeSkinAssets.specFor(descriptor.id);
    final hasArtwork = skinSpec != null;
    final motionPolicy = skinSpec?.motionPolicy ?? ThemeSkinEffectPolicy.full;
    final motionOpacity = skinSpec?.motionOpacity ?? 1;
    final staticEffectPolicy =
        skinSpec?.staticEffectPolicy ?? ThemeSkinEffectPolicy.full;
    final staticEffectOpacity = skinSpec?.staticEffectOpacity ?? 1;
    final showStaticEffect = staticEffectPolicy != ThemeSkinEffectPolicy.none &&
        staticEffectOpacity > 0;
    final showMotion = !reduceMotion &&
        effect != _BackdropEffect.none &&
        effect != _BackdropEffect.corrupt &&
        motionPolicy != ThemeSkinEffectPolicy.none &&
        motionOpacity > 0;
    final corrupt = effect == _BackdropEffect.corrupt;
    final eldritch = effect == _BackdropEffect.eldritch;
    final terminal = effect == _BackdropEffect.terminal;
    final vinyl = effect == _BackdropEffect.vinyl;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.background,
              stops: const <double>[0, 0.38, 0.72, 1],
            ),
          ),
        ),
        if (hasArtwork)
          Positioned.fill(
            child: IgnorePointer(
              child: ThemeSkinBackdropArtwork(themeId: descriptor.id),
            ),
          ),
        if (!hasArtwork &&
            !corrupt &&
            !eldritch &&
            !terminal &&
            !vinyl) ...<Widget>[
          Positioned(
            top: -120,
            left: -60,
            child: _GlowOrb(
              size: 360,
              color: palette.primary,
              opacity: 0.075,
            ),
          ),
          Positioned(
            top: 80,
            right: -70,
            child: _GlowOrb(
              size: 340,
              color: palette.accent,
              opacity: 0.065,
            ),
          ),
          Positioned(
            bottom: -80,
            left: 140,
            child: _GlowOrb(
              size: 420,
              color: palette.secondary,
              opacity: 0.065,
            ),
          ),
        ],
        if (showStaticEffect && (corrupt || eldritch))
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                key: ValueKey<String>(
                  'backdrop-static-${effect.name}-${staticEffectPolicy.name}',
                ),
                opacity: staticEffectOpacity,
                child: _BackdropStaticEffectLayer(
                  effect: effect,
                  palette: palette,
                  policy: staticEffectPolicy,
                ),
              ),
            ),
          ),
        if (showMotion)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                key: ValueKey<String>(
                  'backdrop-motion-${effect.name}-${motionPolicy.name}',
                ),
                opacity: motionOpacity,
                child: _PremiumBackdropMotionLayer(
                  key: ValueKey<String>('motion-$themeId-${effect.name}'),
                  effect: effect,
                  palette: palette,
                  policy: motionPolicy,
                ),
              ),
            ),
          ),
        if (skinSpec case final spec?)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                key: ValueKey<String>('backdrop-scrim-${descriptor.id}'),
                color: spec.scrimColor.withValues(alpha: spec.scrimOpacity),
              ),
            ),
          )
        else
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey<String>('backdrop-generic-overlay'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.025),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.14),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  _BackdropEffect _backgroundEffectFor(AppThemeDescriptor descriptor) {
    final token = descriptor.backgroundEffect?.trim().toLowerCase();
    if (descriptor.isRuntimeTheme) {
      return switch (token) {
        'flower' || 'petal' || 'petals' || 'ink' => _BackdropEffect.flower,
        'mechanical' || 'gear' || 'gears' => _BackdropEffect.mechanical,
        'rain' || 'rain_radio' || 'rain-radio' => _BackdropEffect.rainRadio,
        'pasture' || 'cloud' || 'clouds' => _BackdropEffect.pasture,
        'vinyl' || 'record' => _BackdropEffect.vinyl,
        'eldritch' || 'cthulhu' => _BackdropEffect.eldritch,
        'terminal' ||
        'rift' ||
        'rift_relay' ||
        'rift-relay' =>
          _BackdropEffect.terminal,
        'corrupt' ||
        'glitch' ||
        'april_fools' ||
        'april-fools' =>
          _BackdropEffect.corrupt,
        _ => _BackdropEffect.none,
      };
    }
    final variant = descriptor.baseVariant;
    if (variant.isCorrupt) {
      return _BackdropEffect.corrupt;
    }
    if (variant.isEldritch) {
      return _BackdropEffect.eldritch;
    }
    if (variant.isTerminal) {
      return _BackdropEffect.terminal;
    }
    if (variant.isFlower) {
      return _BackdropEffect.flower;
    }
    if (variant.isMechanical) {
      return _BackdropEffect.mechanical;
    }
    if (variant.isRainRadio) {
      return _BackdropEffect.rainRadio;
    }
    if (variant.isPasture) {
      return _BackdropEffect.pasture;
    }
    if (variant.isVinyl) {
      return _BackdropEffect.vinyl;
    }
    return _BackdropEffect.none;
  }
}

enum _BackdropEffect {
  none,
  corrupt,
  eldritch,
  terminal,
  flower,
  mechanical,
  rainRadio,
  pasture,
  vinyl,
}

class _BackdropStaticEffectLayer extends StatelessWidget {
  const _BackdropStaticEffectLayer({
    required this.effect,
    required this.palette,
    required this.policy,
  });

  final _BackdropEffect effect;
  final AppThemePalette palette;
  final ThemeSkinEffectPolicy policy;

  @override
  Widget build(BuildContext context) {
    if (effect == _BackdropEffect.corrupt) {
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.62, -0.42),
                  radius: 1.05,
                  colors: <Color>[
                    palette.secondary.withValues(alpha: 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              key: ValueKey<String>(
                'backdrop-static-paint-${effect.name}-${policy.name}',
              ),
              painter: _CorruptScanlinePainter(
                lineColor: palette.secondary.withValues(alpha: 0.07),
                errorColor: palette.primary.withValues(alpha: 0.055),
              ),
            ),
          ),
        ],
      );
    }

    if (effect == _BackdropEffect.eldritch) {
      return Stack(
        children: <Widget>[
          Positioned(
            bottom: -90,
            left: -70,
            child: _GlowOrb(
              size: 300,
              color: palette.secondary,
              opacity: 0.12,
            ),
          ),
          Positioned(
            top: -40,
            right: -80,
            child: _GlowOrb(
              size: 360,
              color: palette.primary,
              opacity: 0.1,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              key: ValueKey<String>(
                'backdrop-static-paint-${effect.name}-${policy.name}',
              ),
              painter: _EldritchBackdropPainter(
                sigilColor: palette.primary.withValues(alpha: 0.09),
                noiseColor: palette.accent.withValues(alpha: 0.035),
                policy: policy,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.expand();
  }
}

class _PremiumBackdropMotionLayer extends StatefulWidget {
  const _PremiumBackdropMotionLayer({
    super.key,
    required this.effect,
    required this.palette,
    required this.policy,
  });

  final _BackdropEffect effect;
  final AppThemePalette palette;
  final ThemeSkinEffectPolicy policy;

  @override
  State<_PremiumBackdropMotionLayer> createState() =>
      _PremiumBackdropMotionLayerState();
}

class _PremiumBackdropMotionLayerState
    extends State<_PremiumBackdropMotionLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: ValueKey<String>(
        'backdrop-motion-paint-${widget.effect.name}-${widget.policy.name}',
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PremiumBackdropPainter(
              progress: _controller.value,
              effect: widget.effect,
              palette: widget.palette,
              policy: widget.policy,
            ),
          );
        },
      ),
    );
  }
}

class _PremiumBackdropPainter extends CustomPainter {
  const _PremiumBackdropPainter({
    required this.progress,
    required this.effect,
    required this.palette,
    required this.policy,
  });

  final double progress;
  final _BackdropEffect effect;
  final AppThemePalette palette;
  final ThemeSkinEffectPolicy policy;

  @override
  void paint(Canvas canvas, Size size) {
    if (effect == _BackdropEffect.eldritch) {
      final pulse = 0.5 + math.sin(progress * math.pi * 2) * 0.5;
      final breathePaint = Paint()
        ..color = palette.primary.withValues(alpha: 0.055 + pulse * 0.055)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.50, size.height * 0.55),
          width: size.width * 1.10,
          height: size.height * 0.78,
        ),
        breathePaint,
      );

      if (policy == ThemeSkinEffectPolicy.ambientOnly) {
        final dustPaint = Paint();
        for (var i = 0; i < 32; i++) {
          final random = math.Random(8200 + i * 37);
          final x = (random.nextDouble() * size.width +
                  math.sin(progress * math.pi * 2 + i) * 9) %
              size.width;
          final y =
              ((random.nextDouble() + progress * 0.035) % 1) * size.height;
          dustPaint.color = (i.isEven ? palette.accent : palette.primary)
              .withValues(alpha: 0.025 + random.nextDouble() * 0.035);
          canvas.drawCircle(
            Offset(x, y),
            0.6 + random.nextDouble() * 1.2,
            dustPaint,
          );
        }
        return;
      }

      final eyePaint = Paint()
        ..color = palette.accent.withValues(alpha: 0.05 + pulse * 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      final eyeCenter = Offset(size.width * 0.78, size.height * 0.18);
      final eyeRect = Rect.fromCenter(
        center: eyeCenter,
        width: size.shortestSide * 0.34,
        height: size.shortestSide * 0.14,
      );
      canvas.drawOval(eyeRect, eyePaint);
      canvas.drawCircle(
        eyeCenter,
        size.shortestSide * (0.022 + pulse * 0.01),
        Paint()..color = palette.primary.withValues(alpha: 0.18),
      );

      final threadPaint = Paint()
        ..color = palette.secondary.withValues(alpha: 0.065)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      for (var i = 0; i < 4; i++) {
        final drift = progress * math.pi * 2 + i * 0.72;
        final y = size.height * (0.62 + i * 0.08);
        final path = Path()
          ..moveTo(-70, y + math.sin(drift) * 18)
          ..cubicTo(
            size.width * 0.18,
            y - 90,
            size.width * 0.40,
            y + 80,
            size.width + 70,
            y + math.cos(drift) * 24,
          );
        canvas.drawPath(path, threadPaint);
      }
      return;
    }

    if (effect == _BackdropEffect.terminal) {
      final scanPaint = Paint()
        ..color = palette.accent.withValues(alpha: 0.045)
        ..strokeWidth = 1;
      for (var y = 0.0; y < size.height; y += 8) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
      }

      final columnPaint = Paint();
      const glyphs = '01/[]{}<>RIFTVOIDERROR裂隙中转站';
      for (var i = 0; i < 54; i++) {
        final random = math.Random(4300 + i * 19);
        final x = random.nextDouble() * size.width;
        final speed = 0.16 + random.nextDouble() * 0.46;
        final y = ((random.nextDouble() + progress * speed) % 1) *
                (size.height + 180) -
            90;
        final glyph =
            glyphs[(random.nextInt(glyphs.length) + i) % glyphs.length];
        final painter = TextPainter(
          text: TextSpan(
            text: glyph,
            style: TextStyle(
              color: (i.isEven ? palette.accent : palette.primary).withValues(
                alpha: 0.05 + random.nextDouble() * 0.09,
              ),
              fontSize: 10 + random.nextDouble() * 8,
              fontFamily: 'RiftCombat',
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x, y));
      }

      if (policy == ThemeSkinEffectPolicy.ambientOnly) {
        return;
      }

      columnPaint.color = const Color(0xFFFF4DB8).withValues(alpha: 0.07);
      final glitchY = (progress * (size.height + 120)) % (size.height + 120);
      canvas.drawRect(
        Rect.fromLTWH(0, glitchY - 44, size.width, 2),
        Paint()..color = palette.accent.withValues(alpha: 0.20),
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.18, glitchY, size.width * 0.34, 3),
        columnPaint,
      );
      return;
    }

    if (effect == _BackdropEffect.pasture) {
      final cloudPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      for (var i = 0; i < 8; i++) {
        final random = math.Random(9400 + i * 29);
        final x = ((random.nextDouble() + progress * (0.018 + i * 0.002)) % 1) *
                (size.width + 220) -
            110;
        final y = size.height * (0.08 + random.nextDouble() * 0.42);
        final w = 120 + random.nextDouble() * 150;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.34),
          cloudPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + w * 0.22, y - w * 0.04),
            width: w * 0.64,
            height: w * 0.30,
          ),
          cloudPaint,
        );
      }

      for (var i = 0; i < 3; i++) {
        final path = Path();
        final base = size.height * (0.72 + i * 0.08);
        path.moveTo(-40, size.height + 40);
        for (var x = -40.0; x <= size.width + 40; x += 80) {
          final y = base + math.sin(x * 0.012 + progress * math.pi + i) * 18;
          path.lineTo(x, y);
        }
        path
          ..lineTo(size.width + 40, size.height + 40)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = (i.isEven ? palette.secondary : palette.accent)
                .withValues(alpha: 0.055 + i * 0.025),
        );
      }
      return;
    }

    if (effect == _BackdropEffect.vinyl) {
      final center = Offset(size.width * 0.12, size.height * 0.15);
      final radius = math.max(size.shortestSide * 0.18, 96.0);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(progress * math.pi * 2 * 0.35);
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );
      final groovePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.accent.withValues(alpha: 0.10);
      for (var r = radius * 0.30; r < radius; r += 10) {
        canvas.drawCircle(Offset.zero, r, groovePaint);
      }
      canvas.drawCircle(
        Offset.zero,
        radius * 0.24,
        Paint()..color = palette.primary.withValues(alpha: 0.22),
      );
      canvas.restore();

      final armPaint = Paint()
        ..color = palette.accent.withValues(alpha: 0.16)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      final wobble = math.sin(progress * math.pi * 8) * 5;
      canvas.drawLine(
        Offset(size.width * 0.33, size.height * 0.03),
        Offset(size.width * 0.21 + wobble, size.height * 0.18),
        armPaint,
      );
      final dust = Paint()..color = palette.accent.withValues(alpha: 0.08);
      for (var i = 0; i < 70; i++) {
        final random = math.Random(10700 + i * 17);
        final x = random.nextDouble() * size.width;
        final y = ((random.nextDouble() + progress * 0.08) % 1) * size.height;
        canvas.drawCircle(Offset(x, y), 0.7 + random.nextDouble() * 1.2, dust);
      }
      return;
    }

    if (effect == _BackdropEffect.mechanical) {
      _paintGear(canvas, size, Offset(size.width * 0.10, size.height * 0.18),
          96, progress * math.pi * 2, palette.primary.withValues(alpha: 0.10));
      _paintGear(
          canvas,
          size,
          Offset(size.width * 0.92, size.height * 0.80),
          142,
          -progress * math.pi * 1.4,
          palette.accent.withValues(alpha: 0.08));
      final rivetPaint = Paint()..color = palette.line.withValues(alpha: 0.16);
      for (var x = 28.0; x < size.width; x += 72) {
        for (var y = 32.0; y < size.height; y += 72) {
          canvas.drawCircle(Offset(x, y), 1.8, rivetPaint);
        }
      }
      return;
    }

    if (effect == _BackdropEffect.rainRadio) {
      final rainPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1;
      final lineCount = policy == ThemeSkinEffectPolicy.ambientOnly ? 54 : 150;
      for (var i = 0; i < lineCount; i++) {
        final random = math.Random(7000 + i * 31);
        final speed = 0.5 + random.nextDouble() * 2.2;
        final y = (random.nextDouble() * (size.height + 180) +
                    progress * speed * (size.height + 240)) %
                (size.height + 180) -
            90;
        final x = random.nextDouble() * size.width +
            math.sin(progress * math.pi * 2 + i) * 12;
        final length = 10 + random.nextDouble() * 32;
        rainPaint.color = palette.accent.withValues(
          alpha: 0.045 + random.nextDouble() * 0.10,
        );
        canvas.drawLine(Offset(x, y), Offset(x + 5, y + length), rainPaint);
      }
      return;
    }

    if (effect != _BackdropEffect.flower) {
      return;
    }

    if (policy == ThemeSkinEffectPolicy.ambientOnly) {
      final dustPaint = Paint();
      for (var i = 0; i < 12; i++) {
        final random = math.Random(6100 + i * 41);
        final x = ((random.nextDouble() + progress * 0.012) % 1) * size.width;
        final y = ((random.nextDouble() + progress * 0.018) % 1) * size.height;
        dustPaint.color = palette.primary.withValues(
          alpha: 0.018 + random.nextDouble() * 0.022,
        );
        canvas.drawCircle(
          Offset(x, y),
          0.7 + random.nextDouble() * 1.1,
          dustPaint,
        );
      }

      final petalPaint = Paint()
        ..color = palette.accent.withValues(alpha: 0.045);
      for (var i = 0; i < 6; i++) {
        final random = math.Random(6600 + i * 53);
        final x = ((random.nextDouble() + progress * (0.010 + i * 0.001)) % 1) *
            size.width;
        final y = ((random.nextDouble() + progress * (0.018 + i * 0.002)) % 1) *
            size.height;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * 0.18 + random.nextDouble() * math.pi);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: 7 + random.nextDouble() * 4,
            height: 3 + random.nextDouble() * 2,
          ),
          petalPaint,
        );
        canvas.restore();
      }
      return;
    }

    final ink = Paint()
      ..color = palette.primary.withValues(alpha: 0.055)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 + progress * 0.12;
      final center = Offset(size.width * 0.82, size.height * 0.18);
      canvas.save();
      canvas.translate(
        center.dx + math.cos(angle) * 52,
        center.dy + math.sin(angle) * 36,
      );
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 130, height: 42),
        ink,
      );
      canvas.restore();
    }
  }

  void _paintGear(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    double angle,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.drawCircle(Offset.zero, radius * 0.42, paint);
    for (var i = 0; i < 18; i++) {
      final a = i * math.pi * 2 / 18;
      canvas.drawLine(
        Offset(math.cos(a) * radius * 0.9, math.sin(a) * radius * 0.9),
        Offset(math.cos(a) * radius * 1.12, math.sin(a) * radius * 1.12),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PremiumBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.effect != effect ||
        oldDelegate.palette != palette ||
        oldDelegate.policy != policy;
  }
}

class _EldritchBackdropPainter extends CustomPainter {
  const _EldritchBackdropPainter({
    required this.sigilColor,
    required this.noiseColor,
    required this.policy,
  });

  final Color sigilColor;
  final Color noiseColor;
  final ThemeSkinEffectPolicy policy;

  @override
  void paint(Canvas canvas, Size size) {
    final noisePaint = Paint()..color = noiseColor;
    for (var y = 0.0; y < size.height; y += 18) {
      for (var x = (y % 36 == 0 ? 0.0 : 9.0); x < size.width; x += 28) {
        canvas.drawCircle(Offset(x, y), 0.8, noisePaint);
      }
    }

    if (policy == ThemeSkinEffectPolicy.ambientOnly) {
      return;
    }

    final sigilPaint = Paint()
      ..color = sigilColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final center = Offset(size.width * 0.72, size.height * 0.22);
    final radius = size.shortestSide * 0.22;
    canvas.drawCircle(center, radius, sigilPaint);
    canvas.drawCircle(center, radius * 0.62, sigilPaint);
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7;
      final start = Offset(
        center.dx + math.cos(angle) * radius * 0.25,
        center.dy + math.sin(angle) * radius * 0.25,
      );
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(start, end, sigilPaint);
    }

    final tentaclePaint = Paint()
      ..color = sigilColor.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(-40, size.height * 0.82)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.74,
        size.width * 0.05,
        size.height * 0.58,
        size.width * 0.27,
        size.height * 0.52,
      );
    canvas.drawPath(path, tentaclePaint);
  }

  @override
  bool shouldRepaint(covariant _EldritchBackdropPainter oldDelegate) {
    return oldDelegate.sigilColor != sigilColor ||
        oldDelegate.noiseColor != noiseColor ||
        oldDelegate.policy != policy;
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _CorruptScanlinePainter extends CustomPainter {
  const _CorruptScanlinePainter({
    required this.lineColor,
    required this.errorColor,
  });

  final Color lineColor;
  final Color errorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = lineColor;
    final errorPaint = Paint()..color = errorColor;
    for (var y = 0.0; y < size.height; y += 8) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), linePaint);
    }
    for (var x = 18.0; x < size.width; x += 96) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1.2, size.height), errorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CorruptScanlinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.errorColor != errorColor;
  }
}

class _NeonSidebar extends StatelessWidget {
  const _NeonSidebar({
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    final premiumRail = AppTheme.isFlowerMode ||
        AppTheme.isMechanicalMode ||
        AppTheme.isRainRadioMode ||
        AppTheme.isEldritchMode ||
        AppTheme.isTerminalMode ||
        AppTheme.isPastureMode ||
        AppTheme.isVinylMode;
    return Container(
      width: (premiumRail ? 164 : 122) * uiScale,
      decoration: AppTheme.glassPanel(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          (premiumRail ? 10 : 12) * uiScale,
          16 * uiScale,
          (premiumRail ? 10 : 12) * uiScale,
          16 * uiScale,
        ),
        child: Column(
          children: [
            const _BrandBlock(),
            SizedBox(height: 20 * uiScale),
            Expanded(
              child: Column(
                children: List.generate(
                  labels.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: 10 * uiScale),
                    child: _NavTile(
                      key: _tutorialNavKey(index),
                      label: labels[index],
                      icon: icons[index],
                      selected: index == selectedIndex,
                      onTap: () => onSelect(index),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12 * uiScale),
              decoration: BoxDecoration(
                color: AppTheme.translucentPanelFillStrong,
                borderRadius: BorderRadius.circular(AppTheme.isTerminalMode
                    ? 6
                    : AppTheme.isMechanicalMode
                        ? 10
                        : AppTheme.isEldritchMode
                            ? 12
                            : AppTheme.isVinylMode
                                ? 8
                                : 22),
                border: Border.all(color: AppTheme.activeLine),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.activeSoft.withValues(alpha: 0.92),
                    size: 20 * uiScale,
                  ),
                  SizedBox(height: 6 * uiScale),
                  Text(
                    AppTheme.glitchText('本地保存'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDock extends StatelessWidget {
  const _MobileDock({
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.visibleIndexes,
    required this.onSelect,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final List<int> visibleIndexes;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    final light = AppTheme.isLightPaletteMode;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withValues(alpha: 0.66)
                : Colors.black.withValues(alpha: 0.28),
            border: Border(
              top: BorderSide(
                color:
                    AppTheme.activeLine.withValues(alpha: light ? 0.42 : 0.5),
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: light ? 0.08 : 0.18),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            minimum: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                4 * uiScale,
                4 * uiScale,
                4 * uiScale,
                5 * uiScale,
              ),
              child: Row(
                children: List.generate(
                  visibleIndexes.length,
                  (visibleIndex) {
                    final pageIndex = visibleIndexes[visibleIndex];
                    return Expanded(
                      child: _NavTile(
                        key: _tutorialNavKey(pageIndex),
                        label: labels[pageIndex],
                        icon: icons[pageIndex],
                        selected: pageIndex == selectedIndex,
                        onTap: () => onSelect(pageIndex),
                        compact: true,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    if (compact) {
      final selectedColor = AppTheme.isLightPaletteMode
          ? AppTheme.activePrimary
          : AppTheme.activeSoft;
      final unselectedColor = AppTheme.textWeak;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14 * uiScale),
          overlayColor: WidgetStatePropertyAll(
            AppTheme.activePrimary.withValues(alpha: 0.10),
          ),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 2 * uiScale,
              vertical: 5 * uiScale,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: 48 * uiScale,
                  height: 28 * uiScale,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.activePrimary.withValues(
                            alpha: AppTheme.isLightPaletteMode ? 0.10 : 0.16,
                          )
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    icon,
                    size: 22 * uiScale,
                    color: selected ? selectedColor : unselectedColor,
                  ),
                ),
                SizedBox(height: 2 * uiScale),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? selectedColor : unselectedColor,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w700,
                        height: 1.15,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final premiumTile = !compact &&
        (AppTheme.isFlowerMode ||
            AppTheme.isMechanicalMode ||
            AppTheme.isRainRadioMode ||
            AppTheme.isEldritchMode ||
            AppTheme.isTerminalMode ||
            AppTheme.isPastureMode ||
            AppTheme.isVinylMode);
    final selectedTextColor = AppTheme.selectedTintText;
    final selectedIconColor = AppTheme.selectedTintIcon;
    final radius = _navRadius(premiumTile);
    final decoration = _navDecoration(selected, premiumTile, radius);
    final overlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return AppTheme.activePrimary.withValues(alpha: 0.20);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return AppTheme.activePrimary.withValues(alpha: 0.12);
      }
      return null;
    });

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        overlayColor: overlayColor,
        onTap: onTap,
        child: Ink(
          decoration: decoration,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (compact ? 8 : 8) * uiScale,
              vertical: (compact ? 8 : 12) * uiScale,
            ),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 20 * uiScale,
                        color: selected ? selectedIconColor : AppTheme.textWeak,
                      ),
                      SizedBox(height: 4 * uiScale),
                      Text(
                        label,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: selected
                                      ? selectedTextColor
                                      : AppTheme.textWeak,
                                ),
                      ),
                    ],
                  )
                : premiumTile
                    ? Row(
                        children: [
                          Container(
                            width: 34 * uiScale,
                            height: 34 * uiScale,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.activePrimary.withValues(
                                      alpha:
                                          AppTheme.isFlowerMode ? 0.18 : 0.24,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppTheme.isTerminalMode
                                    ? 4
                                    : AppTheme.isMechanicalMode
                                        ? 8
                                        : AppTheme.isEldritchMode
                                            ? 10
                                            : AppTheme.isVinylMode
                                                ? 8
                                                : 16,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 20 * uiScale,
                              color: selected
                                  ? selectedIconColor
                                  : AppTheme.textWeak,
                            ),
                          ),
                          SizedBox(width: 10 * uiScale),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: selected
                                        ? selectedTextColor
                                        : AppTheme.textWeak,
                                  ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Icon(
                            icon,
                            color: selected
                                ? selectedIconColor
                                : AppTheme.textWeak,
                          ),
                          SizedBox(height: 10 * uiScale),
                          Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: selected
                                      ? selectedTextColor
                                      : AppTheme.textWeak,
                                ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  double _navRadius(bool premiumTile) {
    if (!premiumTile) {
      return 18.0;
    }
    if (AppTheme.isTerminalMode) {
      return 6.0;
    }
    if (AppTheme.isMechanicalMode) {
      return 10.0;
    }
    if (AppTheme.isEldritchMode) {
      return 12.0;
    }
    if (AppTheme.isVinylMode) {
      return 8.0;
    }
    return 18.0;
  }

  BoxDecoration _navDecoration(
    bool selected,
    bool premiumTile,
    double radius,
  ) {
    if (!premiumTile) {
      return selected
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.activePrimary.withValues(
                    alpha: AppTheme.isLightPaletteMode ? 0.16 : 0.30,
                  ),
                  AppTheme.activeSecondary.withValues(
                    alpha: AppTheme.isLightPaletteMode ? 0.10 : 0.18,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: AppTheme.neonGlow(alpha: 0.045),
            )
          : BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
            );
    }

    if (AppTheme.isMechanicalMode) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? <Color>[
                  AppTheme.activePrimary.withValues(alpha: 0.28),
                  AppTheme.activeSecondary.withValues(alpha: 0.20),
                ]
              : <Color>[Colors.transparent, Colors.transparent],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: selected ? AppTheme.neonGlow(alpha: 0.07) : null,
      );
    }

    if (AppTheme.isEldritchMode) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? <Color>[
                  AppTheme.activePrimary.withValues(alpha: 0.30),
                  AppTheme.activeSecondary.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.22),
                ]
              : <Color>[Colors.transparent, Colors.transparent],
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(4),
          topRight: Radius.circular(radius + 8),
          bottomLeft: Radius.circular(radius + 8),
          bottomRight: const Radius.circular(4),
        ),
        boxShadow: selected ? AppTheme.neonGlow(alpha: 0.10) : null,
      );
    }

    if (AppTheme.isTerminalMode) {
      return BoxDecoration(
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppTheme.activePrimary.withValues(alpha: 0.22),
                  AppTheme.activeAccent.withValues(alpha: 0.12),
                  const Color(0xFFFF4DB8).withValues(alpha: 0.08),
                ],
              )
            : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: selected
            ? <BoxShadow>[
                ...AppTheme.neonGlow(alpha: 0.08),
                BoxShadow(
                  color: const Color(0xFFFF4DB8).withValues(alpha: 0.12),
                  blurRadius: 0,
                  offset: const Offset(3, 3),
                ),
              ]
            : null,
      );
    }

    if (AppTheme.isRainRadioMode) {
      return BoxDecoration(
        color: selected
            ? AppTheme.activePrimary.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: selected ? AppTheme.neonGlow(alpha: 0.06) : null,
      );
    }

    if (AppTheme.isPastureMode) {
      return BoxDecoration(
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppTheme.activePrimary.withValues(alpha: 0.20),
                  AppTheme.activeAccent.withValues(alpha: 0.16),
                ],
              )
            : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: selected ? AppTheme.neonGlow(alpha: 0.05) : null,
      );
    }

    if (AppTheme.isVinylMode) {
      return BoxDecoration(
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppTheme.activePrimary.withValues(alpha: 0.28),
                  AppTheme.activeSecondary.withValues(alpha: 0.20),
                ],
              )
            : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: selected ? AppTheme.neonGlow(alpha: 0.08) : null,
      );
    }

    return BoxDecoration(
      color: selected
          ? AppTheme.activePrimary.withValues(alpha: 0.17)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: selected ? AppTheme.neonGlow(alpha: 0.045) : null,
    );
  }
}

Key? _tutorialNavKey(int index) {
  final target = switch (index) {
    0 => TutorialTargetId.navChat,
    1 => TutorialTargetId.navCharacters,
    2 => TutorialTargetId.navNpc,
    4 => TutorialTargetId.navSettings,
    _ => null,
  };
  return target == null ? null : TutorialTargetRegistry.keyOf(target);
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.onSearch,
  });

  final String title;
  final String subtitle;
  final bool compact;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    return Container(
      width: double.infinity,
      decoration:
          AppTheme.glassPanel(highlighted: true, radius: compact ? 20 : 24),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          (compact ? 14 : 24) * uiScale,
          (compact ? 10 : 18) * uiScale,
          (compact ? 14 : 24) * uiScale,
          (compact ? 10 : 18) * uiScale,
        ),
        child: _HeaderText(
          title: title,
          subtitle: subtitle,
          compact: compact,
          onSearch: onSearch,
        ),
      ),
    );
  }
}

class _GlobalSearchDialog extends StatefulWidget {
  const _GlobalSearchDialog();

  @override
  State<_GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<_GlobalSearchDialog> {
  late final TextEditingController _controller;
  Future<List<GlobalSearchResult>>? _future;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppTheme.glitchText('全局搜索')),
      content: SizedBox(
        width: 760,
        height: 560,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                labelText: AppTheme.glitchText('搜索角色、聊天、书签、NPC、世界书、前尘'),
                hintText: AppTheme.glitchText('输入两个字以上更准'),
              ),
              onSubmitted: (_) => _runSearch(),
              onChanged: (value) {
                if (value.trim().length >= 2) {
                  _runSearch();
                } else {
                  setState(() => _future = null);
                }
              },
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _future == null
                  ? _SearchEmptyHint()
                  : FutureBuilder<List<GlobalSearchResult>>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final results =
                            snapshot.data ?? const <GlobalSearchResult>[];
                        if (results.isEmpty) {
                          return _SearchEmptyHint(
                            text: '没有搜到匹配内容，换个关键词试试。',
                          );
                        }
                        return ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final result = results[index];
                            return _SearchResultTile(
                              result: result,
                              onTap: () => _openResult(result),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('关闭')),
        ),
      ],
    );
  }

  void _runSearch() {
    final query = _controller.text.trim();
    setState(() {
      _future = context.read<AppStateController>().searchEverything(query);
    });
  }

  Future<void> _openResult(GlobalSearchResult result) async {
    await context.read<AppStateController>().openSearchResult(result);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _SearchEmptyHint extends StatelessWidget {
  const _SearchEmptyHint({
    this.text = '可以搜角色名、旧聊天片段、书签备注、NPC 名字、世界书标签或前尘关键词。',
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppTheme.glitchText(text),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.onTap,
  });

  final GlobalSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.activeLine),
      ),
      leading: CircleAvatar(
        backgroundColor: AppTheme.activePrimary.withValues(alpha: 0.12),
        child: Icon(_iconFor(result.type), color: AppTheme.activePrimary),
      ),
      title: Text(
        AppTheme.glitchText(result.title),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 4),
          Text(
            AppTheme.glitchText('${result.typeLabel} · ${result.subtitle}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (result.preview.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              AppTheme.glitchText(result.preview),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap,
    );
  }

  IconData _iconFor(GlobalSearchResultType type) {
    return switch (type) {
      GlobalSearchResultType.character => Icons.theater_comedy_outlined,
      GlobalSearchResultType.message => Icons.chat_bubble_outline_rounded,
      GlobalSearchResultType.bookmark => Icons.bookmark_added_rounded,
      GlobalSearchResultType.npc => Icons.group_outlined,
      GlobalSearchResultType.worldBook => Icons.menu_book_rounded,
      GlobalSearchResultType.tool => Icons.auto_fix_high_outlined,
      GlobalSearchResultType.fanfic => Icons.history_edu_outlined,
      GlobalSearchResultType.migration => Icons.travel_explore_outlined,
    };
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({
    required this.title,
    required this.subtitle,
    required this.compact,
    this.onSearch,
  });

  final String title;
  final String subtitle;
  final bool compact;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    final controller = context.watch<AppStateController>();
    final currentCharacter = controller.currentCharacter;
    final memories = controller.currentMemory.summaries.length;
    final characterName = currentCharacter?.name ?? '未选择角色';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: (compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * uiScale,
                vertical: 7 * uiScale,
              ),
              decoration: BoxDecoration(
                color: AppTheme.activeSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.activeLine),
              ),
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textMuted,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6 * uiScale),
        Text(
          AppTheme.glitchText('当前角色 · $characterName    长期记忆 · $memories 条'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        SizedBox(height: 10 * uiScale),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
            label: Text(AppTheme.glitchText(compact ? '搜索' : '全局搜索')),
          ),
        ),
      ],
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 4 * uiScale),
      child: Container(
        width: 90 * uiScale,
        height: 90 * uiScale,
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppTheme.neonGlow(alpha: 0.12),
          border: Border.all(
            color: AppTheme.isLightPaletteMode
                ? AppTheme.activePrimary.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.24),
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppTheme.glitchText('未完'),
              style: TextStyle(
                color: AppTheme.selectedTintText,
                fontWeight: FontWeight.w900,
                fontSize: 24 * uiScale,
              ),
            ),
            SizedBox(height: 2 * uiScale),
            Text(
              AppTheme.glitchText('剧场'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.selectedTintText.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
