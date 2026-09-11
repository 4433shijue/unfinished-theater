part of '../chat_screen.dart';

Future<void> _runAction(
  BuildContext context,
  Future<String?> Function() action, {
  String? successMessage,
}) async {
  String? error;
  try {
    error = await action();
  } catch (exception) {
    error = '操作失败：$exception';
  }
  if (!context.mounted) {
    return;
  }
  _showTopNotice(
    context,
    error ?? successMessage ?? '操作完成。',
    isError: error != null,
  );
}

Future<T> _withTopLoading<T>(
  BuildContext context,
  String message,
  Future<T> Function() action,
) async {
  if (!context.mounted) {
    return action();
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (overlayContext) => _TopFloatingNotice(
      message: message,
      loading: true,
      isError: false,
    ),
  );
  overlay.insert(entry);
  try {
    return await action();
  } finally {
    entry.remove();
  }
}

void _showTopNotice(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) {
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => _TopFloatingNotice(
      message: AppTheme.glitchText(message),
      loading: false,
      isError: isError,
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2400), () {
    if (entry.mounted) {
      entry.remove();
    }
  });
}

class _TopFloatingNotice extends StatelessWidget {
  const _TopFloatingNotice({
    required this.message,
    required this.loading,
    required this.isError,
  });

  final String message;
  final bool loading;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top + 14;
    final color =
        isError ? Theme.of(context).colorScheme.error : AppTheme.activeAccent;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppTheme.activePalette.panelHighlightStart,
                      AppTheme.activePalette.panelHighlightEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: color.withValues(alpha: 0.75)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (loading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      else
                        Icon(
                          isError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: color,
                          size: 20,
                        ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          message,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.activeSoft,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryItemNoteDialog extends StatefulWidget {
  const _StoryItemNoteDialog({
    required this.itemName,
    required this.initialNote,
  });

  final String itemName;
  final String initialNote;

  @override
  State<_StoryItemNoteDialog> createState() => _StoryItemNoteDialogState();
}

class _TheaterRequestDialog extends StatefulWidget {
  const _TheaterRequestDialog({
    required this.item,
    required this.npcs,
  });

  final ShopItemDefinition item;
  final List<NpcProfile> npcs;

  @override
  State<_TheaterRequestDialog> createState() => _TheaterRequestDialogState();
}

class _TheaterRequestDialogState extends State<_TheaterRequestDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _targetController;
  late final TextEditingController _detailController;
  late final TextEditingController _extraController;
  String? _selectedNpcId;

  @override
  void initState() {
    super.initState();
    _selectedNpcId = widget.npcs.isEmpty ? null : widget.npcs.first.id;
    _targetController = TextEditingController();
    _detailController = TextEditingController();
    _extraController = TextEditingController();
  }

  @override
  void dispose() {
    _targetController.dispose();
    _detailController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(widget.item.effectId);
    return AlertDialog(
      title: Text(AppTheme.glitchText(widget.item.name)),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText(copy.description),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (widget.npcs.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedNpcId,
                    decoration: InputDecoration(
                      labelText: AppTheme.glitchText('选择 NPC'),
                    ),
                    items: widget.npcs
                        .map(
                          (npc) => DropdownMenuItem<String>(
                            value: npc.id,
                            child: Text(npc.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() {
                      _selectedNpcId = value;
                    }),
                  )
                else
                  TextFormField(
                    controller: _targetController,
                    decoration: InputDecoration(
                      labelText: AppTheme.glitchText('指定 NPC'),
                      hintText: AppTheme.glitchText('例如：同桌 / 班长 / 让 AI 选择'),
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _detailController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText(copy.detailLabel),
                    hintText: AppTheme.glitchText(copy.detailHint),
                  ),
                  validator: copy.detailRequired
                      ? (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppTheme.glitchText('这里需要写一点要求。');
                          }
                          return null;
                        }
                      : null,
                ),
                if (copy.extraLabel != null) ...<Widget>[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _extraController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppTheme.glitchText(copy.extraLabel!),
                      hintText: AppTheme.glitchText(copy.extraHint ?? ''),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(AppTheme.glitchText('开始生成')),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final target = _selectedNpcId == null
        ? _targetController.text.trim()
        : widget.npcs.firstWhere((npc) => npc.id == _selectedNpcId).name.trim();
    final resolvedTarget = target.isEmpty ? '请根据当前剧情选择合适 NPC' : target;
    final request = StringBuffer()
      ..writeln('指定 NPC：$resolvedTarget')
      ..writeln(
          '${_copyFor(widget.item.effectId).detailLabel}：${_detailController.text.trim().isEmpty ? '让 AI 根据 NPC 性格自由发挥' : _detailController.text.trim()}');
    if (_extraController.text.trim().isNotEmpty) {
      request.writeln('补充台词或氛围：${_extraController.text.trim()}');
    }
    Navigator.of(context).pop(request.toString().trim());
  }

  _TheaterRequestCopy _copyFor(String effectId) {
    return switch (effectId) {
      'child_spray' => const _TheaterRequestCopy(
          description: '指定一个 NPC，再写写你想让 TA 变成什么样的小孩。',
          detailLabel: '小孩设定',
          detailHint: '例如：五六岁、嘴硬但黏人、穿着小雨衣',
          detailRequired: false,
        ),
      'beast_ear_potion' => const _TheaterRequestCopy(
          description: '指定一个 NPC，再写耳朵类型；留空就让 AI 按人设自由发挥。',
          detailLabel: '耳朵类型',
          detailHint: '例如：猫耳 / 狐狸耳 / 兔耳 / 让 AI 发挥',
          detailRequired: false,
        ),
      'touch' => const _TheaterRequestCopy(
          description: '指定一个 NPC 和触碰部位，可以额外写一句你想说的话。',
          detailLabel: '触碰部位',
          detailHint: '例如：摸头 / 牵手 / 轻轻碰肩膀',
          detailRequired: true,
          extraLabel: '可选一句话',
          extraHint: '例如：别怕，我在。',
        ),
      'truth_lollipop' => const _TheaterRequestCopy(
          description: '指定一个 NPC，可以写你希望 TA 真心话围绕什么主题。',
          detailLabel: '真心话主题',
          detailHint: '例如：对我的第一印象 / 最近藏着没说的话 / 让 AI 发挥',
          detailRequired: false,
        ),
      _ => const _TheaterRequestCopy(
          description: '补充这次小剧场的要求。',
          detailLabel: '补充要求',
          detailHint: '想看什么就写什么。',
          detailRequired: false,
        ),
    };
  }
}

class _TheaterRequestCopy {
  const _TheaterRequestCopy({
    required this.description,
    required this.detailLabel,
    required this.detailHint,
    required this.detailRequired,
    this.extraLabel,
    this.extraHint,
  });

  final String description;
  final String detailLabel;
  final String detailHint;
  final bool detailRequired;
  final String? extraLabel;
  final String? extraHint;
}

class _StoryItemNoteDialogState extends State<_StoryItemNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('备注：${widget.itemName}'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '写点你想记住的用途、来历或吐槽。',
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _AiToolTile extends StatelessWidget {
  const _AiToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(icon, color: AppTheme.selectedTintIcon),
      title: Text(
        AppTheme.glitchText(title),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.contrastText,
              fontWeight: FontWeight.w800,
            ),
      ),
      subtitle: Text(
        AppTheme.glitchText(subtitle),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
      ),
      onTap: onTap,
    );
  }
}

class _ChatScrollButtons extends StatelessWidget {
  const _ChatScrollButtons({
    required this.onTop,
    required this.onBottom,
  });

  final VoidCallback onTop;
  final VoidCallback onBottom;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _jumpButton(
            context,
            tooltip: '回到顶部',
            icon: Icons.vertical_align_top_rounded,
            onPressed: onTop,
          ),
          const SizedBox(height: 12),
          _jumpButton(
            context,
            tooltip: '回到底部',
            icon: Icons.vertical_align_bottom_rounded,
            onPressed: onBottom,
          ),
        ],
      ),
    );
  }

  Widget _jumpButton(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final fill = AppTheme.isLightPaletteMode
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.24);
    return IconButton(
      tooltip: AppTheme.glitchText(tooltip),
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStatePropertyAll(fill),
        foregroundColor: WidgetStatePropertyAll(
          AppTheme.contrastText.withValues(alpha: 0.86),
        ),
        overlayColor: WidgetStatePropertyAll(
          AppTheme.activePrimary.withValues(alpha: 0.12),
        ),
        shape: const WidgetStatePropertyAll(CircleBorder()),
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
      ),
    );
  }
}

class _PremiumChatFrame extends StatelessWidget {
  const _PremiumChatFrame({
    required this.child,
    required this.themeDescriptor,
  });

  final Widget child;
  final AppThemeDescriptor themeDescriptor;

  @override
  Widget build(BuildContext context) {
    final variant = themeDescriptor.baseVariant;
    final motionMode = _motionModeFor(themeDescriptor);
    final premium = motionMode != null ||
        variant.isFlower ||
        variant.isMechanical ||
        variant.isRainRadio ||
        variant.isEldritch ||
        variant.isTerminal ||
        variant.isPasture ||
        variant.isVinyl;
    if (!premium) {
      return child;
    }

    final radius = variant.isTerminal
        ? 6.0
        : variant.isMechanical
            ? 12.0
            : variant.isEldritch
                ? 10.0
                : variant.isVinyl
                    ? 8.0
                    : 24.0;
    final fill = variant.isFlower
        ? Colors.white.withValues(alpha: 0.18)
        : variant.isTerminal
            ? Colors.black.withValues(alpha: 0.10)
            : variant.isEldritch
                ? Colors.black.withValues(alpha: 0.12)
                : variant.isPasture
                    ? Colors.white.withValues(alpha: 0.14)
                    : variant.isVinyl
                        ? Colors.black.withValues(alpha: 0.10)
                        : Colors.transparent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: fill,
        child: Stack(
          children: <Widget>[
            if (motionMode != null)
              Positioned.fill(
                child: _PremiumChatMotionLayer(
                  key: ValueKey<String>(
                    'chat-motion-${themeDescriptor.id}-${motionMode.name}',
                  ),
                  mode: motionMode,
                  palette: themeDescriptor.palette,
                ),
              ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }

  _PremiumMotionMode? _motionModeFor(AppThemeDescriptor descriptor) {
    if (descriptor.isRuntimeTheme) {
      return switch (descriptor.backgroundEffect?.trim().toLowerCase()) {
        'flower' || 'petal' || 'petals' || 'ink' => _PremiumMotionMode.flower,
        'mechanical' || 'gear' || 'gears' => _PremiumMotionMode.mechanical,
        'rain' || 'rain_radio' || 'rain-radio' => _PremiumMotionMode.rain,
        'eldritch' || 'cthulhu' || 'abyss' => _PremiumMotionMode.abyss,
        'terminal' ||
        'rift' ||
        'rift_relay' ||
        'rift-relay' =>
          _PremiumMotionMode.rift,
        'pasture' || 'cloud' || 'clouds' => _PremiumMotionMode.pasture,
        'vinyl' || 'record' => _PremiumMotionMode.vinyl,
        _ => null,
      };
    }

    final variant = descriptor.baseVariant;
    if (variant.isMechanical) {
      return _PremiumMotionMode.mechanical;
    }
    if (variant.isRainRadio) {
      return _PremiumMotionMode.rain;
    }
    if (variant.isEldritch) {
      return _PremiumMotionMode.abyss;
    }
    if (variant.isTerminal) {
      return _PremiumMotionMode.rift;
    }
    if (variant.isPasture) {
      return _PremiumMotionMode.pasture;
    }
    if (variant.isVinyl) {
      return _PremiumMotionMode.vinyl;
    }
    if (variant.isFlower) {
      return _PremiumMotionMode.flower;
    }
    return null;
  }
}

class _PremiumChatMotionLayer extends StatefulWidget {
  const _PremiumChatMotionLayer({
    super.key,
    required this.mode,
    required this.palette,
  });

  final _PremiumMotionMode mode;
  final AppThemePalette palette;

  @override
  State<_PremiumChatMotionLayer> createState() =>
      _PremiumChatMotionLayerState();
}

class _PremiumChatMotionLayerState extends State<_PremiumChatMotionLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PremiumChatMotionPainter(
              progress: _controller.value,
              mode: widget.mode,
              palette: widget.palette,
            ),
          );
        },
      ),
    );
  }
}

enum _PremiumMotionMode {
  mechanical,
  flower,
  rain,
  abyss,
  rift,
  pasture,
  vinyl
}

class _PremiumChatMotionPainter extends CustomPainter {
  const _PremiumChatMotionPainter({
    required this.progress,
    required this.mode,
    required this.palette,
  });

  final double progress;
  final _PremiumMotionMode mode;
  final AppThemePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case _PremiumMotionMode.mechanical:
        _paintMechanical(canvas, size);
        break;
      case _PremiumMotionMode.flower:
        _paintFlower(canvas, size);
        break;
      case _PremiumMotionMode.rain:
        _paintRain(canvas, size);
        break;
      case _PremiumMotionMode.abyss:
        _paintAbyss(canvas, size);
        break;
      case _PremiumMotionMode.rift:
        _paintRift(canvas, size);
        break;
      case _PremiumMotionMode.pasture:
        _paintPasture(canvas, size);
        break;
      case _PremiumMotionMode.vinyl:
        _paintVinyl(canvas, size);
        break;
    }
  }

  void _paintMechanical(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = palette.line.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _drawGear(
      canvas,
      Offset(size.width * 0.18, size.height * 0.22),
      size.shortestSide * 0.16,
      progress * math.pi * 2,
      14,
      palette.primary.withValues(alpha: 0.16),
    );
    _drawGear(
      canvas,
      Offset(size.width * 0.86, size.height * 0.74),
      size.shortestSide * 0.22,
      -progress * math.pi * 1.6,
      18,
      palette.accent.withValues(alpha: 0.12),
    );

    final steamPaint = Paint()
      ..color = palette.soft.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final t = (progress + i * 0.18) % 1;
      final baseX = size.width * (0.25 + i * 0.14);
      final baseY = size.height * (0.92 - t * 0.62);
      final path = Path()
        ..moveTo(baseX, baseY)
        ..cubicTo(
          baseX + 32,
          baseY - 38,
          baseX - 26,
          baseY - 76,
          baseX + 18,
          baseY - 116,
        );
      canvas.drawPath(path, steamPaint);
    }
  }

  void _drawGear(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    int teeth,
    Color color,
  ) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final toothPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, radius, fill);
    canvas.drawCircle(Offset.zero, radius * 0.42, fill);
    for (var i = 0; i < teeth; i++) {
      final a = i * math.pi * 2 / teeth;
      canvas.drawLine(
        Offset(math.cos(a) * radius * 0.94, math.sin(a) * radius * 0.94),
        Offset(math.cos(a) * radius * 1.18, math.sin(a) * radius * 1.18),
        toothPaint,
      );
    }
    canvas.restore();
  }

  void _paintFlower(Canvas canvas, Size size) {
    final washPaint = Paint()
      ..color = palette.primary.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final center = Offset(size.width * 0.76, size.height * 0.30);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 + progress * 0.18;
      final petalCenter =
          center + Offset(math.cos(angle) * 38, math.sin(angle) * 26);
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.shortestSide * 0.13,
          height: size.shortestSide * 0.05,
        ),
        washPaint,
      );
      canvas.restore();
    }

    final inkPaint = Paint()
      ..color = palette.accent.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final path = Path()
      ..moveTo(size.width * 0.02, size.height * 0.82)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.58,
        size.width * 0.35,
        size.height * 0.95,
        size.width * 0.58,
        size.height * 0.72,
      );
    canvas.drawPath(path, inkPaint);

    final petalPaint = Paint()..color = palette.primary.withValues(alpha: 0.14);
    for (var i = 0; i < 26; i++) {
      final random = math.Random(900 + i);
      final t = (progress * (0.18 + random.nextDouble() * 0.18) +
              random.nextDouble()) %
          1;
      final x = random.nextDouble() * size.width +
          math.sin(progress * math.pi * 2 + i) * 18;
      final y = t * (size.height + 80) - 40;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2 + i);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 16),
        petalPaint,
      );
      canvas.restore();
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final glassPaint = Paint()
      ..color = palette.accent.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var x = -size.height; x < size.width; x += 90) {
      canvas.drawLine(
        Offset(x + progress * 22, 0),
        Offset(x + size.height * 0.45 + progress * 22, size.height),
        glassPaint,
      );
    }

    final rainPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    for (var i = 0; i < 90; i++) {
      final random = math.Random(1200 + i * 17);
      final speed = 0.7 + random.nextDouble() * 1.8;
      final baseX = random.nextDouble() * size.width;
      final offsetY = random.nextDouble() * (size.height + 120);
      final y = (offsetY + progress * speed * (size.height + 260)) %
              (size.height + 140) -
          70;
      final x = (baseX + math.sin(progress * math.pi * 2 + i) * 8) %
          (size.width + 40);
      final length = 16 + random.nextDouble() * 36;
      rainPaint.color = palette.accent.withValues(
        alpha: 0.08 + random.nextDouble() * 0.16,
      );
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 5 + random.nextDouble() * 8, y + length),
        rainPaint,
      );
    }

    final ripplePaint = Paint()
      ..color = palette.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 10; i++) {
      final random = math.Random(3000 + i);
      final t = (progress + random.nextDouble()) % 1;
      final center = Offset(
        random.nextDouble() * size.width,
        size.height * (0.76 + random.nextDouble() * 0.2),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: 24 + t * 48,
          height: 5 + t * 12,
        ),
        ripplePaint..color = palette.primary.withValues(alpha: 0.09 * (1 - t)),
      );
    }
  }

  void _paintAbyss(Canvas canvas, Size size) {
    final pulse = 0.5 + math.sin(progress * math.pi * 2) * 0.5;
    final washPaint = Paint()
      ..color = palette.primary.withValues(alpha: 0.045 + pulse * 0.035)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.54),
        width: size.width * 1.04,
        height: size.height * 0.70,
      ),
      washPaint,
    );

    final rulePaint = Paint()
      ..color = palette.line.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var y = 18.0; y < size.height; y += 78) {
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), rulePaint);
    }

    final markPaint = Paint()
      ..color = palette.secondary.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < 3; i++) {
      final drift = progress * math.pi * 2 + i;
      final path = Path()
        ..moveTo(-40, size.height * (0.40 + i * 0.18))
        ..cubicTo(
          size.width * 0.25,
          size.height * (0.25 + i * 0.10) + math.sin(drift) * 20,
          size.width * 0.44,
          size.height * (0.66 - i * 0.05),
          size.width + 40,
          size.height * (0.46 + i * 0.13) + math.cos(drift) * 22,
        );
      canvas.drawPath(path, markPaint);
    }
  }

  void _paintRift(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = palette.line.withValues(alpha: 0.11)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final scanY = (progress * (size.height + 120)) % (size.height + 120);
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 60, size.width, 2),
      Paint()..color = palette.accent.withValues(alpha: 0.20),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.16, scanY - 18, size.width * 0.42, 4),
      Paint()..color = const Color(0xFFFF4DB8).withValues(alpha: 0.08),
    );

    const glyphs = '01RIFT裂隙';
    for (var i = 0; i < 38; i++) {
      final random = math.Random(6100 + i * 23);
      final x = random.nextDouble() * size.width;
      final y = ((random.nextDouble() +
                      progress * (0.22 + random.nextDouble() * 0.42)) %
                  1) *
              (size.height + 90) -
          45;
      final glyph = glyphs[(i + random.nextInt(glyphs.length)) % glyphs.length];
      final painter = TextPainter(
        text: TextSpan(
          text: glyph,
          style: TextStyle(
            color: (i.isEven ? palette.accent : palette.primary).withValues(
              alpha: 0.045 + random.nextDouble() * 0.07,
            ),
            fontSize: 9 + random.nextDouble() * 7,
            fontFamily: 'RiftCombat',
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x, y));
    }
  }

  void _paintPasture(Canvas canvas, Size size) {
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    for (var i = 0; i < 6; i++) {
      final random = math.Random(5100 + i * 37);
      final x = ((random.nextDouble() + progress * (0.020 + i * 0.003)) % 1) *
              (size.width + 180) -
          90;
      final y = size.height * (0.10 + random.nextDouble() * 0.36);
      final w = 90 + random.nextDouble() * 120;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.34),
        cloudPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + w * 0.18, y - w * 0.06),
          width: w * 0.62,
          height: w * 0.30,
        ),
        cloudPaint,
      );
    }

    final grassPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    for (var i = 0; i < 48; i++) {
      final random = math.Random(6200 + i * 13);
      final x = random.nextDouble() * size.width;
      final baseY = size.height * (0.78 + random.nextDouble() * 0.18);
      final h = 14 + random.nextDouble() * 28;
      final sway = math.sin(progress * math.pi * 2 + i) * 4;
      grassPaint.color = palette.secondary.withValues(
        alpha: 0.055 + random.nextDouble() * 0.06,
      );
      canvas.drawLine(
          Offset(x, baseY), Offset(x + sway, baseY - h), grassPaint);
    }
  }

  void _paintVinyl(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.18, size.height * 0.18);
    final radius = math.max(size.shortestSide * 0.20, 76.0);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * math.pi * 2 * 0.42);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.accent.withValues(alpha: 0.12);
    for (var r = radius * 0.30; r < radius; r += 8) {
      canvas.drawCircle(Offset.zero, r, groovePaint);
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.22,
      Paint()..color = palette.primary.withValues(alpha: 0.22),
    );
    canvas.restore();

    final scanPaint = Paint()..color = palette.accent.withValues(alpha: 0.035);
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scanPaint);
    }
    final staticPaint = Paint()..color = palette.accent.withValues(alpha: 0.06);
    for (var i = 0; i < 80; i++) {
      final random = math.Random(7300 + i * 19);
      final x = random.nextDouble() * size.width;
      final y = ((random.nextDouble() + progress * 0.10) % 1) * size.height;
      canvas.drawCircle(
          Offset(x, y), 0.6 + random.nextDouble() * 1.2, staticPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumChatMotionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mode != mode ||
        oldDelegate.palette != palette;
  }
}

class _TinySpinner extends StatelessWidget {
  const _TinySpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.activeSoft),
      ),
    );
  }
}

class _FanficDraft {
  const _FanficDraft({
    required this.pairingMode,
    required this.firstNpcId,
    required this.secondNpcId,
    required this.inspiration,
    required this.blindBox,
  });

  final String pairingMode;
  final String firstNpcId;
  final String? secondNpcId;
  final String inspiration;
  final bool blindBox;
}

class _FanficGeneratingDialog extends StatelessWidget {
  const _FanficGeneratingDialog({required this.liveText});

  final ValueListenable<String> liveText;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 28,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: size.height * (compact ? 0.72 : 0.62),
        ),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppTheme.glitchText('同人文生成中…'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ValueListenableBuilder<String>(
                  valueListenable: liveText,
                  builder: (context, text, _) {
                    if (text.trim().isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          AppTheme.glitchText('模型正在构思中，稍等一下…'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textWeak,
                              ),
                        ),
                      );
                    }
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 360),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.translucentPanelFillStrong,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.activeLine),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          AppTheme.glitchText(text),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.textMuted,
                                height: 1.5,
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppTheme.glitchText('生成完成后会自动弹出全文；如果失败，10 啥币会退回。'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textWeak,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FanficDialog extends StatefulWidget {
  const _FanficDialog({
    required this.onGenerate,
    required this.onOpenResult,
  });

  final ValueChanged<_FanficDraft> onGenerate;
  final ValueChanged<FanficResult> onOpenResult;

  @override
  State<_FanficDialog> createState() => _FanficDialogState();
}

class _FanficDialogState extends State<_FanficDialog> {
  final TextEditingController _inspirationController = TextEditingController();
  String _pairingMode = 'user_npc';
  String? _firstNpcId;
  String? _secondNpcId;
  bool _blindBox = false;

  @override
  void dispose() {
    _inspirationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    final npcs = controller.currentCharacterNpcProfiles;
    if (_firstNpcId == null && npcs.isNotEmpty) {
      _firstNpcId = npcs.first.id;
    }
    if (_secondNpcId == null && npcs.length > 1) {
      _secondNpcId = npcs.firstWhere((npc) => npc.id != _firstNpcId).id;
    }
    final fanficHistory = controller.currentCharacterFanficResults;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 28,
        vertical: compact ? 18 : 32,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? size.width - 24 : 780,
          maxHeight: size.height * (compact ? 0.86 : 0.8),
        ),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppTheme.glitchText('同人文工坊'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textMain,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppTheme.glitchText('关闭'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppTheme.glitchText('消耗 10 啥币生成独立同人文，结果会保存在这里，不进入剧情工具历史。'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SegmentedButton<String>(
                        segments: <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: 'user_npc',
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: Text(AppTheme.glitchText('我和 NPC')),
                          ),
                          ButtonSegment<String>(
                            value: 'npc_npc',
                            icon: const Icon(Icons.people_alt_outlined),
                            label: Text(AppTheme.glitchText('NPC 和 NPC')),
                          ),
                        ],
                        selected: <String>{_pairingMode},
                        onSelectionChanged: (value) {
                          setState(() => _pairingMode = value.first);
                        },
                      ),
                      const SizedBox(height: 14),
                      if (npcs.isEmpty)
                        Text(
                          AppTheme.glitchText('当前角色还没有 NPC，先在剧情里生成或手动创建 NPC。'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppTheme.textMuted),
                        )
                      else ...<Widget>[
                        _NpcDropdown(
                          label: _pairingMode == 'user_npc'
                              ? '选择 NPC'
                              : '选择第一个 NPC',
                          value: _firstNpcId,
                          npcs: npcs,
                          onChanged: (value) {
                            setState(() {
                              _firstNpcId = value;
                              if (_secondNpcId == value) {
                                String? nextSecondId;
                                for (final npc in npcs) {
                                  if (npc.id != value) {
                                    nextSecondId = npc.id;
                                    break;
                                  }
                                }
                                _secondNpcId = nextSecondId;
                              }
                            });
                          },
                        ),
                        if (_pairingMode == 'npc_npc') ...<Widget>[
                          const SizedBox(height: 12),
                          _NpcDropdown(
                            label: '选择第二个 NPC',
                            value: _secondNpcId,
                            npcs: npcs
                                .where((npc) => npc.id != _firstNpcId)
                                .toList(growable: false),
                            onChanged: (value) {
                              setState(() => _secondNpcId = value);
                            },
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: _inspirationController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: AppTheme.glitchText('同人文灵感'),
                          hintText: AppTheme.glitchText('写想看的梗，或者点击开盲盒随机一个'),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => setState(() => _blindBox = false),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _rollBlindBox,
                            icon: const Icon(Icons.casino_outlined),
                            label: Text(AppTheme.glitchText('开盲盒')),
                          ),
                          FilledButton.icon(
                            onPressed: controller.isSending || npcs.isEmpty
                                ? null
                                : _submit,
                            icon: controller.isSending
                                ? const _TinySpinner()
                                : const Icon(Icons.auto_stories_outlined),
                            label: Text(AppTheme.glitchText('生成同人文 · 10啥币')),
                          ),
                          _MetricChip(
                            label: AppTheme.glitchText(
                              '余额 ${controller.gamification.coins} 啥币',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppTheme.glitchText('历史同人文'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.selectedTintIcon,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 8),
                      if (fanficHistory.isEmpty)
                        Text(
                          AppTheme.glitchText('这里还没有同人文。第一篇通常最像把火点起来。'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textWeak),
                        )
                      else
                        for (final result in fanficHistory.take(20))
                          _FanficHistoryTile(
                            result: result,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onOpenResult(result);
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _rollBlindBox() {
    final inspiration = rollFanficBlindBoxInspiration();
    setState(() {
      _blindBox = true;
      _inspirationController.text = inspiration.label;
    });
    widget.onGenerate(
      _FanficDraft(
        pairingMode: _pairingMode,
        firstNpcId: _firstNpcId ?? '',
        secondNpcId: _secondNpcId,
        inspiration: inspiration.label,
        blindBox: true,
      ),
    );
  }

  void _submit() {
    widget.onGenerate(
      _FanficDraft(
        pairingMode: _pairingMode,
        firstNpcId: _firstNpcId ?? '',
        secondNpcId: _secondNpcId,
        inspiration: _inspirationController.text.trim(),
        blindBox: _blindBox,
      ),
    );
  }
}

class _NpcDropdown extends StatelessWidget {
  const _NpcDropdown({
    required this.label,
    required this.value,
    required this.npcs,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<NpcProfile> npcs;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final validValue = npcs.any((npc) => npc.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: validValue,
      decoration: InputDecoration(labelText: AppTheme.glitchText(label)),
      items: npcs
          .map(
            (npc) => DropdownMenuItem<String>(
              value: npc.id,
              child: Text(npc.name),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _FanficHistoryTile extends StatelessWidget {
  const _FanficHistoryTile({
    required this.result,
    required this.onTap,
  });

  final FanficResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = result.createdAt.toLocal();
    final time =
        '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(Icons.menu_book_outlined, color: AppTheme.activeSoft),
      title: Text(
        AppTheme.glitchText(result.title),
        maxLines: MediaQuery.sizeOf(context).width < 620 ? 2 : 1,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w800,
            ),
      ),
      subtitle: Text(
        AppTheme.glitchText('${result.pairingLabel} · $time'),
        maxLines: MediaQuery.sizeOf(context).width < 620 ? 2 : 1,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textWeak,
            ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _ToolHistoryTile extends StatelessWidget {
  const _ToolHistoryTile({
    required this.result,
    required this.onTap,
  });

  final ToolResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = result.createdAt.toLocal();
    final time =
        '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(Icons.article_outlined, color: AppTheme.activeSoft),
      title: Text(
        AppTheme.glitchText(result.toolTitle),
        maxLines: MediaQuery.sizeOf(context).width < 620 ? 2 : 1,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.contrastText,
              fontWeight: FontWeight.w800,
            ),
      ),
      subtitle: Text(
        time,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textWeak,
            ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
