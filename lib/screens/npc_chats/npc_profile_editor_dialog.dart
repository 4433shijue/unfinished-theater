part of '../npc_chats_screen.dart';

class _NpcProfileEditorDialog extends StatefulWidget {
  const _NpcProfileEditorDialog({
    this.profile,
    required this.characters,
    this.onGenerateRoleCard,
  });

  final NpcProfile? profile;
  final List<CharacterProfile> characters;
  final Future<NpcRoleCardDraftResult> Function(
    String extraInstruction, {
    void Function(String partial)? onChunk,
  })? onGenerateRoleCard;

  @override
  State<_NpcProfileEditorDialog> createState() =>
      _NpcProfileEditorDialogState();
}

class _NpcProfileEditorDialogState extends State<_NpcProfileEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _impressionController;
  late final TextEditingController _roleCardController;
  late final TextEditingController _roleCardInstructionController;
  late final Set<String> _boundCharacterIds;
  late String _avatarDataUri;
  late double _affinity;
  late NpcLifecycle _lifecycle;
  late bool _companionEnabled;
  late bool _globalBinding;
  bool _generatingRoleCard = false;
  String? _roleCardError;
  NpcProfileDraft? _pendingGeneratedDraft;
  final ValueNotifier<String> _generatingDraftNotifier =
      ValueNotifier<String>('');

  bool get _isCreating => widget.profile == null;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _descriptionController =
        TextEditingController(text: profile?.description ?? '');
    _impressionController =
        TextEditingController(text: profile?.impression ?? '');
    _roleCardController = TextEditingController(text: profile?.roleCard ?? '');
    _roleCardInstructionController = TextEditingController();
    _avatarDataUri = profile?.avatarDataUri ?? '';
    _affinity = (profile?.affinity ?? 0).toDouble();
    _lifecycle = profile?.lifecycle ?? NpcLifecycle.active;
    _companionEnabled = profile?.companionEnabled ?? false;
    _globalBinding = profile?.globalBinding ?? false;
    _boundCharacterIds = <String>{
      if (profile == null)
        ...widget.characters.take(1).map((character) => character.id)
      else if (profile.boundCharacterIds.isEmpty)
        profile.characterId
      else
        ...profile.boundCharacterIds,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _impressionController.dispose();
    _roleCardController.dispose();
    _roleCardInstructionController.dispose();
    _generatingDraftNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 620;
    return AlertDialog(
      title: Text(
          AppTheme.glitchText(widget.profile == null ? '新建 NPC' : '编辑 NPC')),
      content: SizedBox(
        width: compact ? size.width * 0.92 : 620,
        height: compact ? size.height * 0.68 : null,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: compact ? 12 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _NpcAvatarPicker(
                  name: _nameController.text,
                  avatarDataUri: _avatarDataUri,
                  onPick: _pickAvatar,
                  onClear: _avatarDataUri.trim().isEmpty
                      ? null
                      : () => setState(() => _avatarDataUri = ''),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('NPC 名字'),
                    hintText: AppTheme.glitchText('例如：同桌 / 沈知夏 / 食堂阿姨'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppTheme.glitchText('请输入 NPC 名字');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('NPC 简介'),
                    hintText:
                        AppTheme.glitchText('写身份、性格、和用户角色的关系。可以先简单写，后续再补。'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _impressionController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('初始印象，可选'),
                    hintText: AppTheme.glitchText('例如：觉得用户角色有点安静，但做事认真。'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        AppTheme.glitchText('好感度'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      _affinity.round().toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.activeSoft,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                Slider(
                  value: _affinity,
                  min: -100,
                  max: 100,
                  divisions: 200,
                  label: _affinity.round().toString(),
                  onChanged: (value) => setState(() => _affinity = value),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppTheme.glitchText('好感度是数值，印象是文字判断；两者会分别影响后续主线。'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<NpcLifecycle>(
                  initialValue: _lifecycle,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('生命周期'),
                    helperText: AppTheme.glitchText(
                      '失踪、已故或归档后，私聊与好感会冻结。',
                    ),
                  ),
                  items: NpcLifecycle.values
                      .map(
                        (value) => DropdownMenuItem<NpcLifecycle>(
                          value: value,
                          child: Text(AppTheme.glitchText(value.label)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _lifecycle = value);
                    }
                  },
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  value: _companionEnabled,
                  onChanged: (value) =>
                      setState(() => _companionEnabled = value),
                  title: Text(AppTheme.glitchText('作为同行 NPC / 重要配角注入世界')),
                  subtitle: Text(
                      AppTheme.glitchText('开启后，主线会让这个 NPC 自主行动；玩家仍只操控自己的角色。')),
                ),
                SwitchListTile(
                  value: _globalBinding,
                  onChanged: !_companionEnabled
                      ? null
                      : (value) => setState(() => _globalBinding = value),
                  title: Text(AppTheme.glitchText('全局绑定')),
                  subtitle: Text(AppTheme.glitchText('开启后，这个 NPC 会跟随进入所有模拟器。')),
                ),
                const SizedBox(height: 10),
                _BindingSelector(
                  characters: widget.characters,
                  disabled: !_companionEnabled || _globalBinding,
                  selectedIds: _boundCharacterIds,
                  onToggle: (characterId, selected) {
                    setState(() {
                      if (selected) {
                        _boundCharacterIds.add(characterId);
                      } else {
                        _boundCharacterIds.remove(characterId);
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _roleCardController,
                  minLines: 6,
                  maxLines: 12,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('NPC 角色卡，可选'),
                    hintText: AppTheme.glitchText(
                      '写 TA 的身份、性格、目标、说话风格、行动倾向和跨世界同行规则。',
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                if (widget.onGenerateRoleCard != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppTheme.glitchText(
                        _isCreating
                            ? '可以只写角色卡或零散灵感，AI 会补成简介、初始印象和完整角色卡；生成后先预览，再决定怎么应用。'
                            : 'AI 会参考现有档案补全角色卡，生成后先预览，不会直接覆盖。',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            height: 1.45,
                          ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _roleCardInstructionController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: AppTheme.glitchText(
                        _isCreating ? 'AI 帮你写灵感' : '补全要求，可选',
                      ),
                      hintText: AppTheme.glitchText(
                        _isCreating
                            ? '例如：阴郁但护短的旧友，嘴硬，怕被抛下。'
                            : '例如：保留暧昧感，但不要直接确认恋人。',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _generatingRoleCard ? null : _generateRoleCard,
                      icon: _generatingRoleCard
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high_outlined),
                      label: Text(AppTheme.glitchText(
                        _generatingRoleCard
                            ? (_isCreating ? '生成中' : '补全中')
                            : (_isCreating ? 'AI 帮你写' : 'AI 补全角色卡'),
                      )),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<String>(
                    valueListenable: _generatingDraftNotifier,
                    builder: (context, liveText, _) {
                      if (liveText.trim().isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        constraints: const BoxConstraints(maxHeight: 190),
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.translucentPanelFillStrong,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.activeLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppTheme.glitchText(
                                      '正在生成…（已输出 ${liveText.length} 字）',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textWeak,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  AppTheme.glitchText(liveText),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textMuted,
                                        height: 1.5,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (_pendingGeneratedDraft != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _NpcRoleCardDraftPreview(
                    draft: _pendingGeneratedDraft!,
                    onApplyEmpty: _applyGeneratedDraftToEmptyFields,
                    onApplyAll: _applyGeneratedDraftToAllFields,
                    onDismiss: () =>
                        setState(() => _pendingGeneratedDraft = null),
                  ),
                ],
                if (_roleCardError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppTheme.glitchText(_roleCardError!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
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
          child: Text(AppTheme.glitchText('保存')),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_companionEnabled && _roleCardController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('绑定前请先补全 NPC 角色卡。'))),
      );
      return;
    }
    if (_companionEnabled && !_globalBinding && _boundCharacterIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('请至少选择一个绑定世界。'))),
      );
      return;
    }

    Navigator.of(context).pop(
      NpcProfileDraft(
        name: _nameController.text.trim(),
        avatarDataUri: _avatarDataUri.trim(),
        description: _descriptionController.text.trim(),
        impression: _impressionController.text.trim(),
        affinity: _affinity.round(),
        lifecycle: _lifecycle,
        sourceType: widget.profile?.sourceType ?? NpcProfileSource.manual,
        roleCard: _roleCardController.text.trim(),
        roleCardFinalized: _roleCardController.text.trim().isNotEmpty,
        companionEnabled: _companionEnabled,
        globalBinding: _globalBinding,
        boundCharacterIds: _globalBinding
            ? const <String>[]
            : _boundCharacterIds.toList(growable: false),
      ),
    );
  }

  Future<void> _generateRoleCard() async {
    final generator = widget.onGenerateRoleCard;
    if (generator == null) {
      return;
    }
    setState(() {
      _generatingRoleCard = true;
      _roleCardError = null;
    });
    _generatingDraftNotifier.value = '';
    try {
      final result = await generator(
        _roleCardRequestText(),
        onChunk: (partial) => _generatingDraftNotifier.value = partial,
      );
      if (!mounted) {
        return;
      }
      if (result.error != null || result.draft == null) {
        setState(() => _roleCardError = result.error ?? '角色卡补全失败。');
        return;
      }
      final draft = result.draft!;
      setState(() {
        _pendingGeneratedDraft = draft;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roleCardError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _generatingDraftNotifier.value = '';
      if (mounted) {
        setState(() => _generatingRoleCard = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await pickLocalImageFileData();
      if (file == null) {
        return;
      }
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        setState(() => _roleCardError = '没有读到头像图片内容。');
        return;
      }
      const maxBytes = 2 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        setState(() => _roleCardError = '头像图片不能超过 2MB。');
        return;
      }
      setState(() {
        _avatarDataUri =
            'data:${_avatarMimeType(file.mimeType, file.extension)};base64,${base64Encode(bytes)}';
        _roleCardError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roleCardError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _avatarMimeType(String? mimeType, String? extension) {
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }
    return switch (extension?.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/png',
    };
  }

  String _roleCardRequestText() {
    final parts = <String>[
      if (_nameController.text.trim().isNotEmpty)
        '期望姓名/称呼：${_nameController.text.trim()}',
      if (_descriptionController.text.trim().isNotEmpty)
        '用户已写简介：${_descriptionController.text.trim()}',
      if (_impressionController.text.trim().isNotEmpty)
        '初始印象：${_impressionController.text.trim()}',
      if (_roleCardController.text.trim().isNotEmpty)
        '用户已写角色卡：${_roleCardController.text.trim()}',
      _roleCardInstructionController.text.trim(),
    ];
    return parts.where((part) => part.trim().isNotEmpty).join('\n');
  }

  void _applyGeneratedDraftToEmptyFields() {
    final draft = _pendingGeneratedDraft;
    if (draft == null) {
      return;
    }
    setState(() {
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = draft.name;
      }
      if (_descriptionController.text.trim().isEmpty) {
        _descriptionController.text = draft.description;
      }
      if (_impressionController.text.trim().isEmpty) {
        _impressionController.text = draft.impression;
      }
      if (_roleCardController.text.trim().isEmpty) {
        _roleCardController.text = draft.roleCard;
      }
      if (_affinity.round() == 0) {
        _affinity = draft.affinity.toDouble();
      }
      if (_avatarDataUri.trim().isEmpty) {
        _avatarDataUri = draft.avatarDataUri;
      }
      _pendingGeneratedDraft = null;
    });
  }

  void _applyGeneratedDraftToAllFields() {
    final draft = _pendingGeneratedDraft;
    if (draft == null) {
      return;
    }
    setState(() {
      _nameController.text = draft.name;
      _descriptionController.text = draft.description;
      _impressionController.text = draft.impression;
      _roleCardController.text = draft.roleCard;
      _affinity = draft.affinity.toDouble();
      if (draft.avatarDataUri.trim().isNotEmpty) {
        _avatarDataUri = draft.avatarDataUri;
      }
      _pendingGeneratedDraft = null;
    });
  }
}

class _NpcAvatarPicker extends StatelessWidget {
  const _NpcAvatarPicker({
    required this.name,
    required this.avatarDataUri,
    required this.onPick,
    required this.onClear,
  });

  final String name;
  final String avatarDataUri;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        children: <Widget>[
          CharacterAvatar(
            name: name.trim().isEmpty ? 'NPC' : name,
            avatarDataUri: avatarDataUri,
            selected: true,
            size: 62,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('NPC 头像'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTheme.glitchText('可从本地选择图片，保存后会显示在 NPC 列表和私聊里。'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: onPick,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(AppTheme.glitchText('上传头像')),
                    ),
                    if (onClear != null)
                      TextButton(
                        onPressed: onClear,
                        child: Text(AppTheme.glitchText('清除')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NpcRoleCardDraftPreview extends StatelessWidget {
  const _NpcRoleCardDraftPreview({
    required this.draft,
    required this.onApplyEmpty,
    required this.onApplyAll,
    required this.onDismiss,
  });

  final NpcProfileDraft draft;
  final VoidCallback onApplyEmpty;
  final VoidCallback onApplyAll;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_fix_high_outlined, color: AppTheme.activeSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppTheme.glitchText('AI 补全预览'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: AppTheme.glitchText('关闭预览'),
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _previewLine(context, '姓名', draft.name),
            _previewLine(context, '简介', draft.description),
            _previewLine(context, '初始印象', draft.impression),
            _previewLine(context, '好感度', draft.affinity.toString()),
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText('角色卡'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              AppTheme.glitchText(draft.roleCard.trim().isEmpty
                  ? '暂无角色卡内容。'
                  : draft.roleCard.trim()),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: onApplyEmpty,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text(AppTheme.glitchText('应用到空字段')),
                ),
                FilledButton.icon(
                  onPressed: onApplyAll,
                  icon: const Icon(Icons.done_all_rounded),
                  label: Text(AppTheme.glitchText('全部应用')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewLine(BuildContext context, String label, String value) {
    final normalized = value.trim().isEmpty ? '暂无' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label：',
              style: TextStyle(
                color: AppTheme.activeSoft,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(text: AppTheme.glitchText(normalized)),
          ],
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
      ),
    );
  }
}

class _BindingSelector extends StatelessWidget {
  const _BindingSelector({
    required this.characters,
    required this.disabled,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<CharacterProfile> characters;
  final bool disabled;
  final Set<String> selectedIds;
  final void Function(String characterId, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppTheme.glitchText('绑定到指定模拟器'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          AppTheme.glitchText(disabled
              ? '当前已关闭或使用全局绑定。'
              : '勾选后，这个 NPC 会作为同行 NPC / 重要配角注入对应世界。'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 8),
        for (final character in characters)
          CheckboxListTile(
            value: disabled ? false : selectedIds.contains(character.id),
            onChanged: disabled
                ? null
                : (value) => onToggle(character.id, value == true),
            title: Text(AppTheme.glitchText(character.name)),
            subtitle: Text(
              AppTheme.glitchText(character.visibleBlurb),
              maxLines: compact ? 3 : 2,
            ),
          ),
      ],
    );
  }
}
