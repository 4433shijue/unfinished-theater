import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const String _curtainFontFamily = 'FlowerWenDingKai';

class OpeningCurtainGate extends StatefulWidget {
  const OpeningCurtainGate({
    super.key,
    required this.child,
    required this.ready,
    required this.loadingLabel,
    required this.onOpened,
  });

  final Widget child;
  final bool ready;
  final String loadingLabel;
  final Future<void> Function() onOpened;

  @override
  State<OpeningCurtainGate> createState() => _OpeningCurtainGateState();
}

class _OpeningCurtainGateState extends State<OpeningCurtainGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _openController;
  bool _opening = false;
  bool _dismissed = false;
  double _dragStartX = 0;
  double _dragStartValue = 0;

  bool get _canOpen => widget.ready && !_opening && !_dismissed;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _openController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_canOpen) {
      return;
    }
    _openController.stop();
    _dragStartX = details.globalPosition.dx;
    _dragStartValue = _openController.value;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_canOpen) {
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    final targetDistance = math.min(width * 0.48, 380.0).clamp(180.0, 380.0);
    final distance = (details.globalPosition.dx - _dragStartX).abs();
    _openController.value =
        (_dragStartValue + distance / targetDistance).clamp(0.0, 1.0);
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_canOpen) {
      return;
    }
    if (_openController.value >= 0.58) {
      unawaited(_finishOpening());
    } else {
      unawaited(_openController.animateBack(
        0,
        curve: Curves.easeOutCubic,
      ));
    }
  }

  Future<void> _finishOpening() async {
    if (!_canOpen) {
      return;
    }
    if (MediaQuery.of(context).disableAnimations) {
      unawaited(widget.onOpened());
      setState(() {
        _opening = true;
        _dismissed = true;
      });
      return;
    }
    setState(() {
      _opening = true;
    });
    unawaited(widget.onOpened());
    await _openController.animateTo(
      1,
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
    );
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) {
      return;
    }
    setState(() {
      _dismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return widget.child;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _openController,
            builder: (context, _) {
              return _CurtainGateLayer(
                progress: _openController.value,
                ready: widget.ready,
                loadingLabel: widget.loadingLabel,
                onPanStart: _handlePanStart,
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                onOpen: () => unawaited(_finishOpening()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CurtainGateLayer extends StatelessWidget {
  const _CurtainGateLayer({
    required this.progress,
    required this.ready,
    required this.loadingLabel,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onOpen,
  });

  final double progress;
  final bool ready;
  final String loadingLabel;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final open = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final copyOpacity = (1 - open * 1.45).clamp(0.0, 1.0);
    final veilOpacity = (0.92 - open * 0.72).clamp(0.0, 0.92);
    final uiScale = AppTheme.uiScaleOf(context);
    final palette = AppTheme.activePalette;
    final curtainColors = _curtainColors(palette);
    final curtainBorder = _darken(palette.primary, 0.42);
    final copyColors = _readableCurtainCopyColors(curtainColors);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ready ? onOpen : null,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final compact = size.width < 700;
          final curtainWidth = size.width * (compact ? 0.64 : 0.58);
          final travel = curtainWidth * (compact ? 0.86 : 0.8);
          final topHeight = (compact ? 104.0 : 132.0) * uiScale;
          final handleWidth = math.min(size.width * 0.78, 430.0 * uiScale);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: Colors.black.withValues(alpha: veilOpacity)),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _StageDustPainter(
                      color: palette.accent.withValues(alpha: 0.16),
                      progress: open,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -18,
                left: (size.width - math.min(size.width * 0.96, 960.0)) / 2,
                width: math.min(size.width * 0.96, 960.0),
                height: topHeight,
                child: Opacity(
                  opacity: (1 - open * 0.95).clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: _ValancePainter(
                      colors: curtainColors,
                      borderColor: curtainBorder,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topHeight * 0.66,
                left: size.width * 0.08,
                right: size.width * 0.08,
                height: 26 * uiScale,
                child: Opacity(
                  opacity: (1 - open * 1.1).clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: _GoldRopePainter(color: palette.accent),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: -48 * uiScale,
                left: -open * travel,
                width: curtainWidth,
                child: CustomPaint(
                  painter: _CurtainPainter(
                    isLeft: true,
                    colors: curtainColors,
                    borderColor: curtainBorder,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: -48 * uiScale,
                right: -open * travel,
                width: curtainWidth,
                child: CustomPaint(
                  painter: _CurtainPainter(
                    isLeft: false,
                    colors: curtainColors,
                    borderColor: curtainBorder,
                  ),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: copyOpacity,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24 * uiScale),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            AppTheme.glitchText('未完剧场'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: copyColors.primary,
                              fontFamily: _curtainFontFamily,
                              fontSize: (compact ? 42 : 58) * uiScale,
                              fontWeight: FontWeight.w900,
                              shadows: <Shadow>[
                                Shadow(
                                  color: copyColors.shadow,
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 18 * uiScale),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 680 * uiScale,
                            ),
                            child: Text(
                              AppTheme.glitchText(
                                '故事不是被写完才开始；当你拉开帷幕，它才获得命运。',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: copyColors.secondary,
                                fontFamily: _curtainFontFamily,
                                fontSize: (compact ? 17 : 20) * uiScale,
                                height: 1.78,
                                fontWeight: FontWeight.w600,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: copyColors.shadow,
                                    blurRadius: 18,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (size.width - handleWidth) / 2,
                bottom: math.max(34 * uiScale, size.height * 0.075),
                width: handleWidth,
                child: Opacity(
                  opacity: copyOpacity,
                  child: _DragHandle(
                    progress: progress,
                    ready: ready,
                    loadingLabel: loadingLabel,
                    palette: palette,
                    onOpen: onOpen,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<Color> _curtainColors(AppThemePalette palette) {
    final primary = palette.primary;
    final secondary = palette.secondary;
    return <Color>[
      _darken(secondary, 0.50),
      _darken(primary, 0.20),
      primary,
      _darken(secondary, 0.34),
    ];
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * (1 - amount)).clamp(0.0, 1.0))
        .toColor();
  }

  static _CurtainCopyColors _readableCurtainCopyColors(List<Color> colors) {
    final averageLuminance = colors.isEmpty
        ? 0.5
        : colors
                .map((color) => color.computeLuminance())
                .reduce((a, b) => a + b) /
            colors.length;
    final useDarkText = averageLuminance > 0.34;
    final primary = useDarkText ? const Color(0xFF101317) : Colors.white;
    final shadow = useDarkText
        ? Colors.white.withValues(alpha: 0.46)
        : Colors.black.withValues(alpha: 0.72);
    return _CurtainCopyColors(
      primary: primary,
      secondary: primary.withValues(alpha: 0.86),
      shadow: shadow,
    );
  }
}

class _CurtainCopyColors {
  const _CurtainCopyColors({
    required this.primary,
    required this.secondary,
    required this.shadow,
  });

  final Color primary;
  final Color secondary;
  final Color shadow;
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.progress,
    required this.ready,
    required this.loadingLabel,
    required this.palette,
    required this.onOpen,
  });

  final double progress;
  final bool ready;
  final String loadingLabel;
  final AppThemePalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    final text = ready ? '拖拽开幕' : loadingLabel;
    return Semantics(
      button: true,
      enabled: ready,
      label: ready ? '打开未完剧场' : loadingLabel,
      onTap: ready ? onOpen : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ready ? onOpen : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.panel.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: palette.line.withValues(alpha: 0.72),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18 * uiScale,
              14 * uiScale,
              18 * uiScale,
              12 * uiScale,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9 * uiScale,
                    value: progress,
                    color: palette.accent,
                    backgroundColor: AppTheme.translucentPanelFillStrong,
                  ),
                ),
                SizedBox(height: 10 * uiScale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (ready)
                      Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                        color: palette.soft.withValues(alpha: 0.78),
                        size: 18 * uiScale,
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8 * uiScale),
                      child: Text(
                        AppTheme.glitchText(text),
                        style: TextStyle(
                          color: AppTheme.contrastText.withValues(alpha: 0.9),
                          fontFamily: _curtainFontFamily,
                          fontSize: 14 * uiScale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (ready)
                      Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        color: palette.soft.withValues(alpha: 0.78),
                        size: 18 * uiScale,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurtainPainter extends CustomPainter {
  const _CurtainPainter({
    required this.isLeft,
    required this.colors,
    required this.borderColor,
  });

  final bool isLeft;
  final List<Color> colors;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..cubicTo(
          size.width - 28,
          size.height * 0.28,
          size.width + 18,
          size.height * 0.66,
          size.width - 18,
          size.height,
        )
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, 0)
        ..cubicTo(
          28,
          size.height * 0.28,
          -18,
          size.height * 0.66,
          18,
          size.height,
        )
        ..lineTo(size.width, size.height)
        ..close();
    }

    final shader = LinearGradient(
      begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
      colors: colors,
      stops: const <double>[0, 0.26, 0.62, 1],
    ).createShader(Offset.zero & size);

    canvas.drawPath(path, Paint()..shader = shader);
    canvas.save();
    canvas.clipPath(path);
    for (var x = 24.0; x < size.width; x += 54) {
      final foldPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..strokeWidth = 18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, 32),
        Offset(x + (isLeft ? -18 : 18), size.height - 42),
        foldPaint,
      );
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x + 20, 92),
        Offset(x + 4, size.height - 132),
        highlightPaint,
      );
    }
    canvas.restore();

    final border = Paint()
      ..color = borderColor.withValues(alpha: 0.74)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _CurtainPainter oldDelegate) {
    return oldDelegate.isLeft != isLeft ||
        oldDelegate.colors != colors ||
        oldDelegate.borderColor != borderColor;
  }
}

class _ValancePainter extends CustomPainter {
  const _ValancePainter({
    required this.colors,
    required this.borderColor,
  });

  final List<Color> colors;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.7)
      ..quadraticBezierTo(
          size.width * 0.5, size.height * 1.18, 0, size.height * 0.7)
      ..close();
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        colors.length > 2 ? colors[2] : colors.last,
        colors.length > 1 ? colors[1] : colors.first,
        colors.first,
      ],
    ).createShader(Offset.zero & size);
    canvas.drawPath(path, Paint()..shader = shader);
    for (var x = 28.0; x < size.width; x += 72) {
      canvas.drawLine(
        Offset(x, 8),
        Offset(x - 8, size.height * 0.75),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.13)
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor.withValues(alpha: 0.7)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ValancePainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.borderColor != borderColor;
  }
}

class _GoldRopePainter extends CustomPainter {
  const _GoldRopePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 1.08,
        size.width,
        size.height * 0.42,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldRopePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _StageDustPainter extends CustomPainter {
  const _StageDustPainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * (0.5 + progress * 0.5));
    for (var i = 0; i < 72; i += 1) {
      final x = ((i * 83) % math.max(1, size.width.toInt())).toDouble();
      final y = ((i * 151) % math.max(1, size.height.toInt())).toDouble();
      final radius = 0.8 + (i % 5) * 0.32;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StageDustPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
