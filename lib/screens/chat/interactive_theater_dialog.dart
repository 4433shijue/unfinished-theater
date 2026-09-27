part of '../chat_screen.dart';

const String _interactiveTheaterExamplePrompt =
    '让刚才在雨里吵架的两位角色被迫一起照看一只迷路的小猫。做成手机友好的互动小剧场：先显示一段便利店门口的幕后群聊，再让我选择“先找主人”“先给猫喂水”或“假装没看见”，每个选项都要让两人的性格产生不同反应。结尾停在一个小笑点，不写入主线。';

Future<InteractiveTheaterRequest?> showInteractiveTheaterBuilderDialog(
  BuildContext context,
) {
  return showDialog<InteractiveTheaterRequest>(
    context: context,
    builder: (_) => const _InteractiveTheaterBuilderDialog(),
  );
}

Future<void> showInteractiveTheaterResultDialog(
  BuildContext context, {
  required ToolResult result,
  required InteractiveTheaterContinueCallback onContinue,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _InteractiveTheaterResultDialog(
      result: result,
      onContinue: onContinue,
    ),
  );
}

class _InteractiveTheaterBuilderDialog extends StatefulWidget {
  const _InteractiveTheaterBuilderDialog();

  @override
  State<_InteractiveTheaterBuilderDialog> createState() =>
      _InteractiveTheaterBuilderDialogState();
}

class _InteractiveTheaterBuilderDialogState
    extends State<_InteractiveTheaterBuilderDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final Set<InteractiveTheaterKind> _selectedKinds = <InteractiveTheaterKind>{};
  InteractiveTheaterSelectionMode _selectionMode =
      InteractiveTheaterSelectionMode.single;
  String _error = '';

  @override
  void dispose() {
    _titleController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 28,
        vertical: compact ? 16 : 30,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? size.width - 20 : 720,
          maxHeight: size.height * (compact ? 0.9 : 0.84),
        ),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
          padding: EdgeInsets.all(compact ? 14 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.touch_app_outlined, color: AppTheme.activeSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppTheme.glitchText('搭建互动小剧场'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
              Text(
                AppTheme.glitchText('它会读取当前故事的语境，生成一张可以直接点击的独立番外卡。玩完不会改变主线。'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    Text(
                      AppTheme.glitchText('互动选项模式'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final mode
                            in InteractiveTheaterSelectionMode.values)
                          ChoiceChip(
                            avatar: Icon(
                              mode == InteractiveTheaterSelectionMode.single
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.checklist_rounded,
                              size: 18,
                            ),
                            label: Text(AppTheme.glitchText(mode.label)),
                            selected: _selectionMode == mode,
                            onSelected: (_) => setState(() {
                              _selectionMode = mode;
                              if (mode ==
                                      InteractiveTheaterSelectionMode.single &&
                                  _selectedKinds.length > 1) {
                                final firstSelected = _selectedKinds.first;
                                _selectedKinds
                                  ..clear()
                                  ..add(firstSelected);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppTheme.glitchText(_selectionMode.instruction),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textWeak,
                          ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      AppTheme.glitchText('玩法方向（可不选，直接写自定义提示词）'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    for (final kind
                        in InteractiveTheaterKind.values) ...<Widget>[
                      _TheaterKindTile(
                        kind: kind,
                        selected: _selectedKinds.contains(kind),
                        onTap: () => _toggleKind(kind),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      maxLength: 40,
                      decoration: InputDecoration(
                        labelText: AppTheme.glitchText('小剧场名称（可选）'),
                        hintText: AppTheme.glitchText('留空就自动按玩法命名'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppTheme.glitchText('自己填写小剧场提示词'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _fillExample,
                          icon:
                              const Icon(Icons.auto_awesome_outlined, size: 18),
                          label: Text(AppTheme.glitchText('填入示例')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _promptController,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1200,
                      decoration: InputDecoration(
                        hintText: AppTheme.glitchText(
                          '例如：让两个嘴硬的人一起照顾一只猫，做成三步互动，每一步都要有具体反应。',
                        ),
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_error.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        AppTheme.glitchText(_error),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppTheme.glitchText('取消')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(AppTheme.glitchText('开始搭台')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleKind(InteractiveTheaterKind kind) {
    setState(() {
      if (_selectionMode == InteractiveTheaterSelectionMode.single) {
        _selectedKinds
          ..clear()
          ..add(kind);
      } else if (!_selectedKinds.remove(kind)) {
        _selectedKinds.add(kind);
      }
      _error = '';
    });
  }

  void _fillExample() {
    setState(() {
      _promptController.text = _interactiveTheaterExamplePrompt;
      _promptController.selection = TextSelection.collapsed(
        offset: _promptController.text.length,
      );
      _error = '';
    });
  }

  void _submit() {
    final prompt = _promptController.text.trim();
    if (_selectedKinds.isEmpty && prompt.isEmpty) {
      setState(() => _error = '请选择至少一种玩法，或填写自己的小剧场提示词。');
      return;
    }
    final kinds = InteractiveTheaterKind.values
        .where(_selectedKinds.contains)
        .toList(growable: false);
    Navigator.of(context).pop(
      InteractiveTheaterRequest(
        selectionMode: _selectionMode,
        kinds: kinds,
        title: _titleController.text.trim(),
        customPrompt: prompt,
      ),
    );
  }
}

class _TheaterKindTile extends StatelessWidget {
  const _TheaterKindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final InteractiveTheaterKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.13)
                : colors.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.72)
                  : colors.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? colors.primary : AppTheme.textWeak,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppTheme.glitchText(kind.label),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppTheme.glitchText(kind.description),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InteractiveTheaterContinuation {
  const InteractiveTheaterContinuation({this.result, this.error});

  final ToolResult? result;
  final String? error;
}

typedef InteractiveTheaterContinueCallback
    = Future<InteractiveTheaterContinuation> Function(
  ToolResult current,
  List<String> selections,
);

class _InteractiveTheaterResultDialog extends StatefulWidget {
  const _InteractiveTheaterResultDialog({
    required this.result,
    required this.onContinue,
  });

  final ToolResult result;
  final InteractiveTheaterContinueCallback onContinue;

  @override
  State<_InteractiveTheaterResultDialog> createState() =>
      _InteractiveTheaterResultDialogState();
}

class _InteractiveTheaterResultDialogState
    extends State<_InteractiveTheaterResultDialog> {
  late ToolResult _result = widget.result;
  bool _isContinuing = false;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 28,
        vertical: compact ? 12 : 28,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? size.width - 16 : 860,
          maxHeight: size.height * (compact ? 0.9 : 0.84),
        ),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
          padding: EdgeInsets.all(compact ? 10 : 16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.auto_awesome_outlined, color: AppTheme.activeSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppTheme.glitchText(_result.toolTitle),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppTheme.glitchText(
                            '独立番外 · ${_result.theaterSelectionMode == 'multi' ? '多选' : '单选'} · 第 ${_result.theaterStep + 1} 幕',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textWeak),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: AppTheme.glitchText('复制'),
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: _result.content),
                    ),
                    icon: const Icon(Icons.content_copy_outlined),
                  ),
                  IconButton(
                    tooltip: AppTheme.glitchText('关闭'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (_error.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      AppTheme.glitchText(_error),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    DecoratedBox(
                      decoration: AppTheme.glassPanel(radius: 22),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: HtmlContentView(
                          content: _result.content,
                          onAction: _handleHtmlAction,
                        ),
                      ),
                    ),
                    if (_isContinuing)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(AppTheme.glitchText('小剧场正在接住你的选择…')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppTheme.glitchText('点击选项后，再点“继续小剧场”。这里的选择只影响番外。'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textWeak,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleHtmlAction(String rawValue) async {
    if (_isContinuing) {
      return;
    }
    final payload = _decodeTheaterEvent(rawValue);
    if (payload == null || payload['type']?.toString() != 'theater-submit') {
      return;
    }
    final rawValues = payload['values'];
    final selections = rawValues is List
        ? rawValues.map((value) => value.toString().trim()).where((value) {
            return value.isNotEmpty;
          }).toList(growable: false)
        : const <String>[];
    setState(() => _error = '');
    setState(() => _isContinuing = true);
    try {
      final continuation = await widget.onContinue(_result, selections);
      if (!mounted) {
        return;
      }
      if (continuation.error != null && continuation.error!.isNotEmpty) {
        setState(() => _error = continuation.error!);
      } else if (continuation.result != null) {
        setState(() => _result = continuation.result!);
      }
    } finally {
      if (mounted) {
        setState(() => _isContinuing = false);
      }
    }
  }

  Map<String, dynamic>? _decodeTheaterEvent(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Older previews can still send plain data-action text.
    }
    return null;
  }
}
