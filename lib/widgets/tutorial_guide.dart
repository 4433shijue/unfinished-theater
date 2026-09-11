import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum TutorialTargetId {
  navChat,
  navCharacters,
  navNpc,
  navSettings,
  apiUrlField,
  saveApiButton,
  newCharacterButton,
  chatInput,
  chatSend,
  chatLaunch,
}

class TutorialTargetRegistry {
  TutorialTargetRegistry._();

  static final Map<TutorialTargetId, GlobalKey> _keys =
      <TutorialTargetId, GlobalKey>{
    for (final target in TutorialTargetId.values)
      target: GlobalKey(debugLabel: 'tutorial-${target.name}'),
  };

  static final ValueNotifier<TutorialTargetId?> actions =
      ValueNotifier<TutorialTargetId?>(null);

  static GlobalKey keyOf(TutorialTargetId target) => _keys[target]!;

  static void report(TutorialTargetId target) {
    actions.value = null;
    actions.value = target;
  }
}

class TutorialGuideStep {
  const TutorialGuideStep({
    required this.target,
    required this.action,
    required this.icon,
    required this.title,
    required this.instruction,
    required this.actionLabel,
  });

  final TutorialTargetId target;
  final TutorialTargetId action;
  final IconData icon;
  final String title;
  final String instruction;
  final String actionLabel;
}

class TutorialGuideSequence {
  const TutorialGuideSequence({
    required this.title,
    required this.steps,
    this.completesOnboarding = false,
  });

  final String title;
  final List<TutorialGuideStep> steps;
  final bool completesOnboarding;
}

class TutorialGuideCoordinator {
  TutorialGuideCoordinator._();

  static final ValueNotifier<TutorialGuideSequence?> requests =
      ValueNotifier<TutorialGuideSequence?>(null);

  static void start(TutorialGuideSequence sequence) {
    requests.value = null;
    requests.value = sequence;
  }
}

const TutorialGuideSequence quickStartTutorial = TutorialGuideSequence(
  title: '快速上手',
  completesOnboarding: true,
  steps: <TutorialGuideStep>[
    TutorialGuideStep(
      target: TutorialTargetId.navSettings,
      action: TutorialTargetId.navSettings,
      icon: Icons.settings_outlined,
      title: '先连接 AI 服务',
      instruction: '点击高亮的“设置”。连接信息只保存在当前设备，之后创建的故事会使用你选择的 AI 模型。',
      actionLabel: '请点击“设置”',
    ),
    TutorialGuideStep(
      target: TutorialTargetId.apiUrlField,
      action: TutorialTargetId.apiUrlField,
      icon: Icons.key_rounded,
      title: '填写连接信息',
      instruction: '点击服务地址输入框开始填写，再补全密钥和模型名称。不确定填什么时，可以查看服务提供方给出的接入说明。',
      actionLabel: '请点击服务地址输入框',
    ),
    TutorialGuideStep(
      target: TutorialTargetId.saveApiButton,
      action: TutorialTargetId.saveApiButton,
      icon: Icons.save_outlined,
      title: '保存并测试连接',
      instruction: '三项都填好后，可以先测试连接，再点击“保存 API 设置”。看到连接成功后就能开始故事。',
      actionLabel: '填好后点击“保存 API 设置”',
    ),
    TutorialGuideStep(
      target: TutorialTargetId.navCharacters,
      action: TutorialTargetId.navCharacters,
      icon: Icons.theater_comedy_outlined,
      title: '挑选一个故事',
      instruction: '现在点击“角色”。每张角色卡都是一个独立故事，拥有自己的聊天、记忆、NPC 和进度。',
      actionLabel: '请点击“角色”',
    ),
    TutorialGuideStep(
      target: TutorialTargetId.navChat,
      action: TutorialTargetId.navChat,
      icon: Icons.chat_bubble_outline_rounded,
      title: '回到主舞台',
      instruction: '选好现有故事，或者之后再创建新的故事。先点击“对话”，我们开始第一回合。',
      actionLabel: '请点击“对话”',
    ),
    TutorialGuideStep(
      target: TutorialTargetId.chatInput,
      action: TutorialTargetId.chatInput,
      icon: Icons.edit_outlined,
      title: '写下行动或台词',
      instruction: '点击底部输入框，写一句行动、台词或补充设定。这里可以像文游一样自由描述，不必拘泥于固定选项。',
      actionLabel: '请点击输入框并输入内容',
    ),
    TutorialGuideStep(
      target: TutorialTargetId.chatSend,
      action: TutorialTargetId.chatSend,
      icon: Icons.send_rounded,
      title: '把内容放入本回合',
      instruction: '输入完成后点击“发送”。这句话会加入当前回合；需要时还可以继续补充更多行动或台词。',
      actionLabel: '请输入内容，然后点击“发送”',
    ),
    TutorialGuideStep(
      target: TutorialTargetId.chatLaunch,
      action: TutorialTargetId.chatLaunch,
      icon: Icons.near_me_rounded,
      title: '正式推进剧情',
      instruction: '最后点击小飞机，AI 会读取本回合的全部内容并继续故事。看到回复后，快速教程就完成了。',
      actionLabel: '请点击小飞机开始剧情',
    ),
  ],
);

enum DetailedTutorialRoute {
  api,
  theater,
  chat,
  npc,
  settings,
}

TutorialGuideSequence detailedTutorialSequence(
  DetailedTutorialRoute route,
  String title,
) {
  return switch (route) {
    DetailedTutorialRoute.api => TutorialGuideSequence(
        title: title,
        steps: quickStartTutorial.steps.sublist(0, 3),
      ),
    DetailedTutorialRoute.theater => TutorialGuideSequence(
        title: title,
        steps: const <TutorialGuideStep>[
          TutorialGuideStep(
            target: TutorialTargetId.navCharacters,
            action: TutorialTargetId.navCharacters,
            icon: Icons.theater_comedy_outlined,
            title: '进入角色档案',
            instruction: '点击“角色”，这里管理每一个独立故事，也能查看故事状态、世界书和角色编辑。',
            actionLabel: '请点击“角色”',
          ),
          TutorialGuideStep(
            target: TutorialTargetId.newCharacterButton,
            action: TutorialTargetId.newCharacterButton,
            icon: Icons.add_rounded,
            title: '创建新剧场',
            instruction: '点击“新建角色”打开创建页。名称和开场白负责第一印象，剧场设定决定世界规则、文风与角色行为。',
            actionLabel: '请点击“新建角色”',
          ),
        ],
      ),
    DetailedTutorialRoute.chat => TutorialGuideSequence(
        title: title,
        steps: quickStartTutorial.steps.sublist(4),
      ),
    DetailedTutorialRoute.npc => const TutorialGuideSequence(
        title: 'NPC 与故事',
        steps: <TutorialGuideStep>[
          TutorialGuideStep(
            target: TutorialTargetId.navNpc,
            action: TutorialTargetId.navNpc,
            icon: Icons.badge_outlined,
            title: '打开 NPC 私聊',
            instruction: '点击“NPC”。主线里识别到的 NPC 会进入这里，可以查看档案、关系变化、独立私聊和来信。',
            actionLabel: '请点击“NPC”',
          ),
        ],
      ),
    DetailedTutorialRoute.settings => const TutorialGuideSequence(
        title: '设置与数据',
        steps: <TutorialGuideStep>[
          TutorialGuideStep(
            target: TutorialTargetId.navSettings,
            action: TutorialTargetId.navSettings,
            icon: Icons.settings_outlined,
            title: '打开设置',
            instruction: '点击“设置”。记忆、显示、预设、存档、导入导出和完整教程都集中在这个页面。',
            actionLabel: '请点击“设置”',
          ),
        ],
      ),
  };
}

class StreamingTutorialText extends StatefulWidget {
  const StreamingTutorialText({
    super.key,
    required this.text,
    this.style,
    this.interval = const Duration(milliseconds: 22),
    this.onCompleted,
  });

  final String text;
  final TextStyle? style;
  final Duration interval;
  final VoidCallback? onCompleted;

  @override
  State<StreamingTutorialText> createState() => _StreamingTutorialTextState();
}

class _StreamingTutorialTextState extends State<StreamingTutorialText> {
  Timer? _timer;
  late List<int> _runes;
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant StreamingTutorialText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _runes = widget.text.runes.toList(growable: false);
    _visibleCount = 0;
    if (_runes.isEmpty) {
      return;
    }
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted) {
        return;
      }
      setState(() => _visibleCount += 1);
      if (_visibleCount >= _runes.length) {
        timer.cancel();
        widget.onCompleted?.call();
      }
    });
  }

  void _revealAll() {
    if (_visibleCount >= _runes.length) {
      return;
    }
    _timer?.cancel();
    setState(() => _visibleCount = _runes.length);
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final visible = String.fromCharCodes(_runes.take(_visibleCount));
    final typing = _visibleCount < _runes.length;
    return Semantics(
      label: widget.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _revealAll,
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: AppTheme.glitchText(visible)),
              if (typing)
                TextSpan(
                  text: '｜',
                  style: TextStyle(color: AppTheme.activePrimary),
                ),
            ],
          ),
          style: widget.style,
        ),
      ),
    );
  }
}

class TutorialGuideOverlay extends StatefulWidget {
  const TutorialGuideOverlay({
    super.key,
    required this.sequence,
    required this.onCompleted,
    required this.onSkipped,
  });

  final TutorialGuideSequence sequence;
  final VoidCallback onCompleted;
  final VoidCallback onSkipped;

  @override
  State<TutorialGuideOverlay> createState() => _TutorialGuideOverlayState();
}

class _TutorialGuideOverlayState extends State<TutorialGuideOverlay> {
  final GlobalKey _overlayKey = GlobalKey(debugLabel: 'tutorial-overlay');
  Timer? _locatorTimer;
  int _stepIndex = 0;

  TutorialGuideStep get _step => widget.sequence.steps[_stepIndex];

  @override
  void initState() {
    super.initState();
    TutorialTargetRegistry.actions.addListener(_handleAction);
    _locatorTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _revealTarget();
  }

  @override
  void didUpdateWidget(covariant TutorialGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sequence, widget.sequence)) {
      _stepIndex = 0;
      _revealTarget();
    }
  }

  @override
  void dispose() {
    TutorialTargetRegistry.actions.removeListener(_handleAction);
    _locatorTimer?.cancel();
    super.dispose();
  }

  void _handleAction() {
    final action = TutorialTargetRegistry.actions.value;
    if (action == null || action != _step.action) {
      return;
    }
    _advance();
  }

  void _advance() {
    if (_stepIndex == widget.sequence.steps.length - 1) {
      widget.onCompleted();
      return;
    }
    setState(() => _stepIndex += 1);
    _revealTarget();
  }

  void _revealTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext =
          TutorialTargetRegistry.keyOf(_step.target).currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.42,
      );
    });
  }

  Rect? _targetRect() {
    final overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox = TutorialTargetRegistry.keyOf(_step.target)
        .currentContext
        ?.findRenderObject() as RenderBox?;
    if (overlayBox == null ||
        targetBox == null ||
        !overlayBox.hasSize ||
        !targetBox.hasSize ||
        targetBox.size.isEmpty) {
      return null;
    }
    final global = targetBox.localToGlobal(Offset.zero);
    final local = overlayBox.globalToLocal(global);
    return local & targetBox.size;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final target = _targetRect();
          final hole = target?.inflate(7).intersect(Offset.zero & size);
          final compact = size.width < 700;
          final cardWidth = math.min(compact ? size.width - 24 : 430.0,
              math.max(0.0, size.width - 24));
          final cardHeight = compact ? 238.0 : 226.0;
          final cardLeft = _cardLeft(size, hole, cardWidth, compact);
          final cardTop = _cardTop(size, hole, cardHeight, compact);
          final cardRect =
              Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight);

          return Stack(
            key: _overlayKey,
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TutorialScrimPainter(hole: hole),
                  ),
                ),
              ),
              if (hole != null) ...<Widget>[
                Positioned.fromRect(
                  rect: hole,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.activeSoft,
                          width: 2.5,
                        ),
                        boxShadow: AppTheme.neonGlow(alpha: 0.22),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TutorialConnectorPainter(
                        target: hole.center,
                        card: cardRect,
                        color: AppTheme.activeSoft,
                      ),
                    ),
                  ),
                ),
              ],
              Positioned.fromRect(
                rect: cardRect,
                child: _TutorialGuideCard(
                  key: ValueKey<String>(
                    '${widget.sequence.title}-$_stepIndex',
                  ),
                  sequenceTitle: widget.sequence.title,
                  step: _step,
                  index: _stepIndex,
                  total: widget.sequence.steps.length,
                  targetFound: hole != null,
                  onSkipStep: _advance,
                  onClose: widget.onSkipped,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _cardLeft(
    Size size,
    Rect? target,
    double cardWidth,
    bool compact,
  ) {
    if (!compact && target != null && target.right < size.width * 0.32) {
      return math.min(target.right + 22, size.width - cardWidth - 16);
    }
    return ((size.width - cardWidth) / 2).clamp(12.0, size.width);
  }

  double _cardTop(
    Size size,
    Rect? target,
    double cardHeight,
    bool compact,
  ) {
    if (target == null) {
      return ((size.height - cardHeight) / 2).clamp(12.0, size.height);
    }
    final placeAtTop = target.center.dy > size.height * (compact ? 0.48 : 0.58);
    return placeAtTop ? 16 : math.max(16, size.height - cardHeight - 18);
  }
}

class _TutorialGuideCard extends StatelessWidget {
  const _TutorialGuideCard({
    super.key,
    required this.sequenceTitle,
    required this.step,
    required this.index,
    required this.total,
    required this.targetFound,
    required this.onSkipStep,
    required this.onClose,
  });

  final String sequenceTitle;
  final TutorialGuideStep step;
  final int index;
  final int total;
  final bool targetFound;
  final VoidCallback onSkipStep;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: AppTheme.glassPanel(highlighted: true, radius: 20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppTheme.actionGradient,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(step.icon, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppTheme.glitchText(
                              '$sequenceTitle ${index + 1}/$total'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textWeak,
                          ),
                        ),
                        Text(
                          AppTheme.glitchText(step.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '退出教程',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamingTutorialText(
                  text: step.instruction,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.55,
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Icon(
                    targetFound
                        ? Icons.touch_app_rounded
                        : Icons.location_searching_rounded,
                    size: 18,
                    color: AppTheme.activePrimary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      AppTheme.glitchText(
                        targetFound ? step.actionLabel : '正在定位目标控件…',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.activePrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onSkipStep,
                    child: Text(index == total - 1 ? '结束' : '跳过此步'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (index + 1) / total,
                  minHeight: 4,
                  backgroundColor: AppTheme.activeLine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialScrimPainter extends CustomPainter {
  const _TutorialScrimPainter({required this.hole});

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (hole != null && !hole!.isEmpty) {
      path
        ..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(14)))
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialScrimPainter oldDelegate) =>
      oldDelegate.hole != hole;
}

class _TutorialConnectorPainter extends CustomPainter {
  const _TutorialConnectorPainter({
    required this.target,
    required this.card,
    required this.color,
  });

  final Offset target;
  final Rect card;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(
      target.dx.clamp(card.left + 24, card.right - 24),
      target.dy < card.top ? card.top : card.bottom,
    );
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, target, paint);
    final angle = math.atan2(target.dy - start.dy, target.dx - start.dx);
    final arrow = Path()
      ..moveTo(target.dx, target.dy)
      ..lineTo(
        target.dx - 10 * math.cos(angle - 0.48),
        target.dy - 10 * math.sin(angle - 0.48),
      )
      ..lineTo(
        target.dx - 10 * math.cos(angle + 0.48),
        target.dy - 10 * math.sin(angle + 0.48),
      )
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialConnectorPainter oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.card != card ||
      oldDelegate.color != color;
}
