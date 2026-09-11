part of '../settings_screen.dart';

class _CustomThemeEditorDialog extends StatefulWidget {
  const _CustomThemeEditorDialog({
    required this.controller,
    this.style,
  });

  final AppStateController controller;
  final CustomThemeStyle? style;

  @override
  State<_CustomThemeEditorDialog> createState() =>
      _CustomThemeEditorDialogState();
}

class _CustomThemeEditorDialogState extends State<_CustomThemeEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cssController;
  late String _baseThemeId;
  bool _saving = false;
  bool _pickingCss = false;

  @override
  void initState() {
    super.initState();
    _baseThemeId = AppThemeVariant.byId(widget.style?.baseThemeId).id;
    _nameController = TextEditingController(
      text: widget.style?.name ?? '我的自定义主题',
    );
    _descriptionController = TextEditingController(
      text: widget.style?.description ?? '从现有主题改出来的新装修。',
    );
    _cssController = TextEditingController(
      text: widget.style?.css ?? customThemeCssExample,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cssController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseVariant = AppThemeVariant.byId(_baseThemeId);
    final spec = ThemeStyleSpec.fromCss(
      _cssController.text,
      baseThemeId: baseVariant.id,
    );
    final palette = (spec ?? ThemeStyleSpec(baseThemeId: baseVariant.id))
        .applyTo(baseVariant.palette);
    return AlertDialog(
      title: Text(
        AppTheme.glitchText(widget.style == null ? '购买自定义主题格子' : '编辑自定义主题'),
      ),
      content: SizedBox(
        width: min(MediaQuery.sizeOf(context).width * 0.92, 820),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                AppTheme.glitchText(
                  '先选一个已有主题当底稿，样式代码只覆盖颜色、圆角、阴影和背景动效。没写到的部分继续继承底稿主题。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '主题名字'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '主题介绍'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _baseThemeId,
                decoration: const InputDecoration(labelText: '底稿主题'),
                items: AppThemeVariant.values
                    .where(
                        (variant) => widget.controller.canUseTheme(variant.id))
                    .map(
                      (variant) => DropdownMenuItem<String>(
                        value: variant.id,
                        child: Text(variant.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _baseThemeId = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _cssController,
                minLines: 9,
                maxLines: 16,
                style: const TextStyle(fontFamily: 'monospace'),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '主题样式 CSS 变量'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: customThemeCssExample),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('示例主题样式已复制。')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(AppTheme.glitchText('复制示例')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickingCss ? null : _pickCssFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                        AppTheme.glitchText(_pickingCss ? '读取中' : '导入CSS')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _cssController.text = customThemeCssExample,
                    ),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(AppTheme.glitchText('填入示例')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                AppTheme.glitchText('实时预览'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _CustomThemePreview(
                palette: palette,
                baseVariant: baseVariant,
                name: _nameController.text,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            AppTheme.glitchText(widget.style == null ? '支付200啥币并保存' : '保存修改'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = widget.style == null
        ? await widget.controller.buyCustomThemeSlot(
            name: _nameController.text,
            description: _descriptionController.text,
            baseThemeId: _baseThemeId,
            css: _cssController.text,
          )
        : await widget.controller.updateCustomThemeStyle(
            id: widget.style!.id,
            name: _nameController.text,
            description: _descriptionController.text,
            baseThemeId: _baseThemeId,
            css: _cssController.text,
          );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final message = widget.style == null ? '自定义主题已入库。' : '自定义主题已保存。';
    Navigator.of(context).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickCssFile() async {
    setState(() => _pickingCss = true);
    try {
      final file = await pickArchiveFileData(
        allowedExtensions: const <String>['css', 'txt'],
        webAccept: '.css,.txt,text/css,text/plain',
      );
      if (!mounted) {
        return;
      }
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有选择 CSS 文件。')),
        );
        return;
      }
      final content = utf8.decode(file.bytes, allowMalformed: true).trim();
      if (content.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('这个 CSS 文件是空的。')),
        );
        return;
      }
      setState(() => _cssController.text = content);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取 CSS 失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pickingCss = false);
      }
    }
  }
}

class _CustomThemePreview extends StatelessWidget {
  const _CustomThemePreview({
    required this.palette,
    required this.baseVariant,
    required this.name,
  });

  final AppThemePalette palette;
  final AppThemeVariant baseVariant;
  final String name;

  @override
  Widget build(BuildContext context) {
    final title = name.trim().isEmpty ? '自定义主题' : name.trim();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.background,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: palette.brand),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _textOnPalette(baseVariant),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '底稿：${baseVariant.label}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _textOnPalette(baseVariant)
                                .withValues(alpha: 0.68),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.panelEnd,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.line),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.glow.withValues(alpha: 0.12),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                _PreviewRow(
                  color: palette.primary,
                  label: '主按钮',
                  textColor: _buttonText(palette.primary),
                ),
                const SizedBox(height: 10),
                _PreviewBubble(
                  palette: palette,
                  text: 'AI 气泡：这套装修看起来能不能长住？',
                  alignRight: false,
                ),
                const SizedBox(height: 8),
                _PreviewBubble(
                  palette: palette,
                  text: '用户气泡：能，先给它起个响亮的名字。',
                  alignRight: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _textOnPalette(AppThemeVariant baseVariant) {
    return baseVariant.isBasicPalette ||
            baseVariant.isPasture ||
            baseVariant.isFlower
        ? const Color(0xFF2F2C33)
        : Colors.white;
  }

  Color _buttonText(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF28242B);
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.color,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({
    required this.palette,
    required this.text,
    required this.alignRight,
  });

  final AppThemePalette palette;
  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: alignRight
              ? palette.primary.withValues(alpha: 0.22)
              : palette.panelStart,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: alignRight ? palette.primary : palette.line,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: _readableTextColor(
                  alignRight ? palette.primary : palette.panelStart)),
        ),
      ),
    );
  }

  Color _readableTextColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF28242B);
  }
}

Future<void> _openCustomThemeEditor(
  BuildContext context,
  AppStateController controller, {
  CustomThemeStyle? style,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _CustomThemeEditorDialog(
      controller: controller,
      style: style,
    ),
  );
}

class _BasicThemeChip extends StatelessWidget {
  const _BasicThemeChip({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final AppThemeVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: variant.palette.brand),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
      ),
      label: Text(AppTheme.glitchText(variant.label)),
      labelStyle: Theme.of(context).textTheme.labelLarge,
      selectedColor: variant.palette.primary.withValues(alpha: 0.24),
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      side: BorderSide(
        color: selected
            ? variant.palette.soft.withValues(alpha: 0.76)
            : AppTheme.activeLine,
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.variant,
    required this.selected,
    required this.locked,
    required this.unlockCost,
    required this.coinBalance,
    required this.onTap,
    required this.onUnlock,
  });

  final AppThemeVariant variant;
  final bool selected;
  final bool locked;
  final int unlockCost;
  final int coinBalance;
  final VoidCallback onTap;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final palette = variant.palette;
    final sketchy = variant.isSketchy;
    final avatarAsset = ThemeSkinAssets.avatarAssetFor(variant.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(sketchy ? 18 : 24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: sketchy
                ? palette.panelStart.withValues(alpha: selected ? 0.95 : 0.74)
                : Colors.white.withValues(alpha: selected ? 0.065 : 0.035),
            borderRadius: BorderRadius.circular(sketchy ? 18 : 24),
            border: Border.all(
              color: selected
                  ? palette.soft.withValues(alpha: sketchy ? 0.95 : 0.78)
                  : AppTheme.activeLine,
              width: sketchy ? 1.8 : (selected ? 1.6 : 1),
            ),
            boxShadow: selected
                ? AppTheme.neonGlow(
                    color: palette.glow,
                    alpha: sketchy ? 0.18 : 0.16,
                  )
                : const <BoxShadow>[],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: palette.brand,
                    ),
                    image: avatarAsset == null
                        ? null
                        : DecorationImage(
                            image: AssetImage(avatarAsset),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                    borderRadius: BorderRadius.circular(sketchy ? 14 : 18),
                    border: Border.all(
                      color: sketchy
                          ? const Color(0xFF171B22).withValues(alpha: 0.62)
                          : Colors.white.withValues(alpha: 0.2),
                      width: sketchy ? 2 : 1,
                    ),
                  ),
                  child: sketchy && avatarAsset == null
                      ? Icon(
                          Icons.gesture_rounded,
                          color: const Color(0xFF1B1D22).withValues(alpha: 0.8),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppTheme.glitchText(variant.label),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (locked)
                            Icon(
                              Icons.lock_outline_rounded,
                              color: palette.soft,
                              size: 18,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTheme.glitchText(variant.description),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      if (locked && unlockCost > 0) ...<Widget>[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: onUnlock,
                              icon: const Icon(Icons.lock_open_rounded),
                              label: Text(
                                AppTheme.glitchText('$unlockCost 啥币解锁'),
                              ),
                            ),
                            Text(
                              AppTheme.glitchText('当前 $coinBalance 啥币'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textWeak),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected && !locked)
                  Icon(
                    Icons.check_circle_rounded,
                    color: palette.soft,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
