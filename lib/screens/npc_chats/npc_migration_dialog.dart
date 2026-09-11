part of '../npc_chats_screen.dart';

class _NpcMigrationDialog extends StatefulWidget {
  const _NpcMigrationDialog({
    required this.npc,
    required this.onEditRoleCard,
  });

  final NpcProfile npc;
  final Future<void> Function() onEditRoleCard;

  @override
  State<_NpcMigrationDialog> createState() => _NpcMigrationDialogState();
}

class _NpcMigrationDialogState extends State<_NpcMigrationDialog> {
  static const String _outputPlayableWorld = NpcMigrationOutputKind.newWorld;
  static const String _outputWorldBookOnly =
      NpcMigrationOutputKind.worldBookOnly;
  static const List<String> _worldTypes = <String>[
    '现代重逢',
    '原作后日谈',
    '转生平行世界',
    '同居日常',
    '私奔小屋',
    '校园再遇',
    '古风新篇',
    '自定义世界',
  ];
  static const List<({String value, String label, String description})>
      _narrativeVoices = <({
    String value,
    String label,
    String description,
  })>[
    (
      value: 'second',
      label: '第二人称',
      description: '默认沉浸式文游：你站在 TA 面前，故事直接对你发生。'
    ),
    (value: 'first', label: '第一人称', description: '以“我”的视角展开，像亲自写下你们的新生活。'),
    (value: 'third', label: '第三人称', description: '偏小说旁白，适合旁观你和 TA 的长期故事。'),
  ];

  late String _worldType;
  String _outputMode = _outputPlayableWorld;
  String _narrativeVoice = 'second';
  String _memoryMode = NpcMigrationMemoryMode.full;
  String _farewellMode = NpcFarewellMode.skip;
  String _relationshipLock = NpcMigrationRelationshipLock.followOldBond;
  bool _includeFarewell = true;
  bool _generateKeepsake = true;
  bool _generateTasks = true;
  bool _allowEcho = true;
  NpcFarewellDraft? _farewellDraft;
  NpcFarewellChoice? _selectedFarewellChoice;
  NpcFarewellOutcome? _farewellOutcome;
  NpcMigrationPreview? _preview;
  bool _working = false;
  bool _farewellDone = false;
  final TextEditingController _inspirationController = TextEditingController();
  final TextEditingController _customWorldController = TextEditingController();
  final TextEditingController _farewellTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _worldType = _worldTypes.first;
  }

  @override
  void dispose() {
    _inspirationController.dispose();
    _customWorldController.dispose();
    _farewellTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final npc = widget.npc;
    final custom = _worldType == '自定义世界';
    final theme = Theme.of(context);
    final preview = _preview;
    final buildStage = context.select<AppStateController, String>(
      (controller) => controller.npcMigrationBuildStage,
    );
    final activeStep = preview != null ? 2 : (_farewellDone ? 1 : 0);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 24,
        vertical: compact ? 12 : 24,
      ),
      title: Text(
        AppTheme.glitchText(preview == null ? '带 TA 走' : '确认新世界'),
        maxLines: 2,
      ),
      content: SizedBox(
        width: compact ? size.width * 0.96 : 760,
        height: compact ? size.height * 0.72 : null,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: compact ? 12 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _MigrationStepHeader(
                activeStep: activeStep,
                working: _working,
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CharacterAvatar(
                        name: npc.name.trim().isEmpty ? 'NPC' : npc.name,
                        avatarDataUri: npc.avatarDataUri,
                        selected: true,
                        size: 52,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppTheme.glitchText(npc.name),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              npc.description.trim().isEmpty
                                  ? AppTheme.glitchText(
                                      '这个 NPC 还没有完整简介，AI 会根据已有印象和私聊补全。')
                                  : AppTheme.glitchText(npc.description),
                              maxLines: compact ? 5 : 3,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _NpcBondPanel(npc: npc),
              const SizedBox(height: 14),
              if (preview != null) _MigrationPreviewPanel(preview: preview),
              if (preview == null && !_farewellDone)
                _buildFarewellOptions(context),
              if (preview == null && _farewellDone)
                _buildOptions(context, custom: custom),
              if (_working) ...<Widget>[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  backgroundColor:
                      AppTheme.activePrimary.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.activeSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  AppTheme.glitchText(preview == null
                      ? (_farewellDone
                          ? (buildStage.trim().isEmpty
                              ? '正在整理前尘档案...'
                              : buildStage)
                          : '正在整理旧世界告别...')
                      : _outputMode == _outputWorldBookOnly
                          ? '正在保存前尘世界观...'
                          : buildStage.trim().isEmpty
                              ? '正在写入新角色、前尘世界书和迁徙记录...'
                              : buildStage),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _buildDialogActions(context, compact: compact),
    );
  }

  List<Widget> _buildDialogActions(
    BuildContext context, {
    required bool compact,
  }) {
    final preview = _preview;
    final worldBookOnly = _outputMode == _outputWorldBookOnly;
    final secondary = <Widget>[
      TextButton(
        onPressed: _working ? null : () => Navigator.of(context).pop(),
        child: Text(AppTheme.glitchText('取消')),
      ),
      if (preview != null)
        TextButton.icon(
          onPressed: _working ? null : () => setState(() => _preview = null),
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(AppTheme.glitchText('返回修改')),
        ),
      if (preview == null && _farewellDone)
        TextButton.icon(
          onPressed: _working
              ? null
              : () => setState(() {
                    _farewellDone = false;
                    _preview = null;
                  }),
          icon: const Icon(Icons.arrow_back_rounded),
          label: Text(AppTheme.glitchText('返回告别')),
        ),
    ];
    final primary = FilledButton.icon(
      onPressed: _working ? null : _submit,
      icon: Icon(preview != null
          ? (worldBookOnly
              ? Icons.menu_book_outlined
              : Icons.travel_explore_outlined)
          : _farewellDone
              ? Icons.auto_awesome_rounded
              : Icons.waving_hand_outlined),
      label: Text(AppTheme.glitchText(preview != null
          ? (worldBookOnly ? '保存前尘世界观' : '确认生成新世界')
          : _farewellDone
              ? (worldBookOnly ? '生成世界观预览' : '生成新世界预览')
              : '继续')),
    );
    if (!compact) {
      return <Widget>[...secondary, primary];
    }
    return <Widget>[
      SizedBox(width: double.infinity, child: primary),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: secondary,
      ),
    ];
  }

  Widget _buildOptions(BuildContext context, {required bool custom}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppTheme.glitchText('生成方式'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ChoiceChip(
              selected: _outputMode == _outputPlayableWorld,
              avatar: const Icon(Icons.travel_explore_outlined, size: 18),
              label: Text(AppTheme.glitchText('可游玩新世界')),
              onSelected: _working
                  ? null
                  : (_) => setState(() => _outputMode = _outputPlayableWorld),
            ),
            ChoiceChip(
              selected: _outputMode == _outputWorldBookOnly,
              avatar: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(AppTheme.glitchText('只生成世界观')),
              onSelected: _working
                  ? null
                  : (_) => setState(() => _outputMode = _outputWorldBookOnly),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          AppTheme.glitchText(_outputMode == _outputWorldBookOnly
              ? '只保存前尘世界书，不新建可游玩的模拟器。'
              : '生成一个可直接进入游玩的新世界，并自动绑定前尘世界书。'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppTheme.glitchText('叙事人称'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final voice in _narrativeVoices)
              ChoiceChip(
                selected: _narrativeVoice == voice.value,
                label: Text(AppTheme.glitchText(voice.label)),
                onSelected: _working
                    ? null
                    : (_) => setState(() => _narrativeVoice = voice.value),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          AppTheme.glitchText(
            _narrativeVoices
                .firstWhere((voice) => voice.value == _narrativeVoice)
                .description,
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppTheme.glitchText('新世界类型'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final type in _worldTypes)
              ChoiceChip(
                selected: _worldType == type,
                label: Text(AppTheme.glitchText(type)),
                onSelected:
                    _working ? null : (_) => setState(() => _worldType = type),
              ),
          ],
        ),
        if (custom) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _customWorldController,
            enabled: !_working,
            decoration: InputDecoration(
              labelText: AppTheme.glitchText('自定义世界'),
              hintText: AppTheme.glitchText('例如：雨夜旧城、海边小镇、末世安全屋...'),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          AppTheme.glitchText('旧世界记忆强度'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ChoiceChip(
              selected: _memoryMode == NpcMigrationMemoryMode.full,
              label: Text(AppTheme.glitchText('完整记得')),
              onSelected: _working
                  ? null
                  : (_) =>
                      setState(() => _memoryMode = NpcMigrationMemoryMode.full),
            ),
            ChoiceChip(
              selected: _memoryMode == NpcMigrationMemoryMode.fragments,
              label: Text(AppTheme.glitchText('片段记得')),
              onSelected: _working
                  ? null
                  : (_) => setState(
                      () => _memoryMode = NpcMigrationMemoryMode.fragments),
            ),
            ChoiceChip(
              selected: _memoryMode == NpcMigrationMemoryMode.echo,
              label: Text(AppTheme.glitchText('只留熟悉感')),
              onSelected: _working
                  ? null
                  : (_) =>
                      setState(() => _memoryMode = NpcMigrationMemoryMode.echo),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          AppTheme.glitchText(NpcMigrationMemoryMode.label(_memoryMode)),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppTheme.glitchText('关系路线'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final item in _relationshipOptions(widget.npc.bondRoute.route))
              ChoiceChip(
                selected: _relationshipLock == item.value,
                label: Text(AppTheme.glitchText(item.label)),
                onSelected: _working
                    ? null
                    : (_) => setState(() => _relationshipLock = item.value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilterChip(
              selected: _includeFarewell,
              label: Text(AppTheme.glitchText('写入旧世界告别')),
              onSelected: _working
                  ? null
                  : (value) => setState(() => _includeFarewell = value),
            ),
            FilterChip(
              selected: _generateKeepsake,
              label: Text(AppTheme.glitchText('生成前尘信物')),
              onSelected: _working
                  ? null
                  : (value) => setState(() => _generateKeepsake = value),
            ),
            FilterChip(
              selected: _generateTasks,
              label: Text(AppTheme.glitchText('生成关系任务')),
              onSelected: _working
                  ? null
                  : (value) => setState(() => _generateTasks = value),
            ),
            if (_outputMode == _outputPlayableWorld)
              FilterChip(
                selected: _allowEcho,
                label: Text(AppTheme.glitchText('允许旧世界回声')),
                onSelected: _working
                    ? null
                    : (value) => setState(() => _allowEcho = value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _inspirationController,
          enabled: !_working,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('你的新世界灵感，可选'),
            hintText: AppTheme.glitchText('想让你们从哪里重逢？现在是什么关系？有什么没说完的话？'),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  List<({String value, String label})> _relationshipOptions(String oldBond) {
    return <({String value, String label})>[
      (
        value: NpcMigrationRelationshipLock.followOldBond,
        label: oldBond.trim().isEmpty || oldBond == '未知线'
            ? '跟随旧羁绊'
            : '跟随旧羁绊 · $oldBond',
      ),
      (value: NpcMigrationRelationshipLock.lover, label: '恋人线'),
      (value: NpcMigrationRelationshipLock.bestFriend, label: '挚友线'),
      (value: NpcMigrationRelationshipLock.rival, label: '宿敌线'),
      (value: NpcMigrationRelationshipLock.accomplice, label: '共犯线'),
      (value: NpcMigrationRelationshipLock.guardian, label: '守护线'),
      (value: NpcMigrationRelationshipLock.mentor, label: '师徒线'),
      (value: NpcMigrationRelationshipLock.brokenMirror, label: '破镜线'),
      (value: NpcMigrationRelationshipLock.noRomance, label: '不要恋爱化'),
      (value: NpcMigrationRelationshipLock.naturalChange, label: '允许自然变化'),
    ];
  }

  Widget _buildFarewellOptions(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _farewellDraft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppTheme.glitchText('要和 TA 进行告别吗？'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppTheme.glitchText('告别是用户权利，不是系统强迫。你可以留下一句话，也可以直接去新世界。'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _working ? null : _buildReusableRoleCard,
              icon: const Icon(Icons.badge_outlined),
              label: Text(AppTheme.glitchText('只生成 NPC 角色卡')),
            ),
            _farewellChip('不告别，直接续前缘', NpcFarewellMode.skip),
            _farewellChip('写一场告别', NpcFarewellMode.aiScene),
            _farewellChip('只留一句话', NpcFarewellMode.oneLine),
            _farewellChip('我自己写告别', NpcFarewellMode.userWritten),
          ],
        ),
        if (_farewellMode == NpcFarewellMode.aiScene) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _working ? null : _generateFarewellDraft,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(AppTheme.glitchText(
              draft == null ? '生成旧世界告别回合' : '重新生成告别回合',
            )),
          ),
          if (draft != null) ...<Widget>[
            const SizedBox(height: 12),
            _MigrationSection(
              title: draft.title.trim().isEmpty ? '旧世界告别' : draft.title,
              icon: Icons.waving_hand_outlined,
              content:
                  '${draft.narrative}\n\n${draft.emotionalSummary}\n\n${draft.htmlPanel}',
              initiallyExpanded: true,
            ),
            Text(
              AppTheme.glitchText('最后行动'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final choice in draft.choices)
                  ChoiceChip(
                    selected: _selectedFarewellChoice?.id == choice.id,
                    label: Text(AppTheme.glitchText(choice.label)),
                    onSelected: _working
                        ? null
                        : (_) =>
                            setState(() => _selectedFarewellChoice = choice),
                  ),
              ],
            ),
          ],
        ],
        if (_farewellMode == NpcFarewellMode.oneLine ||
            _farewellMode == NpcFarewellMode.userWritten ||
            _farewellMode == NpcFarewellMode.aiScene) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _farewellTextController,
            enabled: !_working,
            minLines: _farewellMode == NpcFarewellMode.oneLine ? 1 : 3,
            maxLines: _farewellMode == NpcFarewellMode.oneLine ? 2 : 6,
            decoration: InputDecoration(
              labelText: AppTheme.glitchText(
                _farewellMode == NpcFarewellMode.oneLine
                    ? '留给 TA 的一句话'
                    : '你的告别文字，可选',
              ),
              hintText: AppTheme.glitchText('把旧世界最后想说的话留在这里。'),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ],
    );
  }

  ChoiceChip _farewellChip(String label, String value) {
    return ChoiceChip(
      selected: _farewellMode == value,
      label: Text(AppTheme.glitchText(label)),
      onSelected: _working
          ? null
          : (_) => setState(() {
                _farewellMode = value;
                _farewellOutcome = null;
                if (value != NpcFarewellMode.aiScene) {
                  _selectedFarewellChoice = null;
                }
              }),
    );
  }

  Future<void> _submit() async {
    final resolvedWorld =
        _worldType == '自定义世界' ? _customWorldController.text.trim() : _worldType;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = context.read<AppStateController>();
    final preview = _preview;
    if (preview == null && !_farewellDone) {
      await _finishFarewellStep(controller, messenger);
      return;
    }
    setState(() => _working = true);
    if (preview == null) {
      final result = await controller.buildNpcMigrationPreview(
        npcId: widget.npc.id,
        worldType: resolvedWorld.isEmpty ? '只属于你们的新世界' : resolvedWorld,
        inspiration: _inspirationController.text.trim(),
        narrativeVoice: _narrativeVoice,
        memoryMode: _memoryMode,
        outputKind: _outputMode,
        farewellOutcome: _farewellOutcome ?? const NpcFarewellOutcome(),
        relationshipLock: _relationshipLock,
        includeFarewell: _includeFarewell,
        generateKeepsake: _generateKeepsake,
        generateTasks: _generateTasks,
        allowEcho: _allowEcho,
      );
      if (!mounted) {
        return;
      }
      setState(() => _working = false);
      if (result.error != null || result.preview == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(result.error ?? '迁徙预览生成失败。')),
        );
        return;
      }
      setState(() => _preview = result.preview);
      return;
    }

    final worldBookOnly = _outputMode == _outputWorldBookOnly;
    final commit = worldBookOnly
        ? await controller.commitNpcMigrationWorldBookOnly(preview)
        : await controller.commitNpcMigrationPreview(preview);
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    if (commit.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(commit.error!)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppTheme.glitchText(
            worldBookOnly ? '前尘世界观已保存到世界书。' : '已经生成可游玩的前尘新世界。')),
      ),
    );
  }

  Future<void> _generateFarewellDraft() async {
    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await context
        .read<AppStateController>()
        .buildNpcFarewellDraft(npcId: widget.npc.id);
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    if (result.error != null || result.draft == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.error ?? '告别回合生成失败。')),
      );
      return;
    }
    setState(() {
      _farewellDraft = result.draft;
      _selectedFarewellChoice =
          result.draft!.choices.isEmpty ? null : result.draft!.choices.first;
    });
  }

  Future<void> _buildReusableRoleCard() async {
    Navigator.of(context).pop();
    await widget.onEditRoleCard();
  }

  Future<void> _finishFarewellStep(
    AppStateController controller,
    ScaffoldMessengerState messenger,
  ) async {
    if (_farewellMode == NpcFarewellMode.aiScene && _farewellDraft == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先生成一场告别，或选择其他告别方式。')),
      );
      return;
    }
    if ((_farewellMode == NpcFarewellMode.oneLine ||
            _farewellMode == NpcFarewellMode.userWritten) &&
        _farewellTextController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先写下告别文字。')),
      );
      return;
    }
    setState(() => _working = true);
    final result = await controller.summarizeNpcFarewellOutcome(
      npcId: widget.npc.id,
      mode: _farewellMode,
      draft: _farewellDraft,
      selectedChoice: _selectedFarewellChoice,
      userFarewellText: _farewellTextController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    if (result.error != null || result.outcome == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.error ?? '告别整理失败。')),
      );
      return;
    }
    setState(() {
      _farewellOutcome = result.outcome;
      _farewellDone = true;
    });
  }
}

class _MigrationStepHeader extends StatelessWidget {
  const _MigrationStepHeader({
    required this.activeStep,
    required this.working,
  });

  final int activeStep;
  final bool working;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final steps = <Widget>[
          _step(
            context,
            index: 0,
            icon: Icons.waving_hand_outlined,
            title: '旧世界告别',
            active: activeStep == 0,
            done: activeStep > 0,
            compact: compact,
          ),
          _step(
            context,
            index: 1,
            icon: Icons.tune_rounded,
            title: '再续前缘',
            active: activeStep == 1,
            done: activeStep > 1,
            compact: compact,
          ),
          _step(
            context,
            index: 2,
            icon: Icons.fact_check_outlined,
            title: '预览确认',
            active: activeStep == 2,
            done: false,
            compact: compact,
          ),
        ];
        if (compact) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps
                .map(
                  (step) => SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: step,
                  ),
                )
                .toList(growable: false),
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: steps[0]),
            const SizedBox(width: 8),
            Expanded(child: steps[1]),
            const SizedBox(width: 8),
            Expanded(child: steps[2]),
          ],
        );
      },
    );
  }

  Widget _step(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required bool active,
    required bool done,
    required bool compact,
  }) {
    final color = done || active ? AppTheme.activePrimary : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: color.withValues(alpha: active ? 0.55 : 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(done ? Icons.check_circle_rounded : icon,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppTheme.glitchText(title),
              maxLines: compact ? 2 : 1,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MigrationPreviewPanel extends StatelessWidget {
  const _MigrationPreviewPanel({required this.preview});

  final NpcMigrationPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localTime = preview.generatedAt.toLocal().toString().split('.').first;
    final createsCharacter =
        preview.outputKind == NpcMigrationOutputKind.newWorld;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.activePrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.activeLine),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _NpcInfoPill(
                icon: createsCharacter
                    ? Icons.badge_outlined
                    : Icons.menu_book_outlined,
                text: createsCharacter
                    ? preview.characterName
                    : NpcMigrationOutputKind.label(preview.outputKind),
              ),
              _NpcInfoPill(
                icon: Icons.public_outlined,
                text: preview.worldType,
              ),
              _NpcInfoPill(
                icon: Icons.memory_outlined,
                text: NpcMigrationMemoryMode.shortLabel(preview.memoryMode),
              ),
              _NpcInfoPill(
                icon: Icons.route_outlined,
                text: NpcMigrationRelationshipLock.shortLabel(
                  preview.relationshipLock,
                ),
              ),
              if (preview.farewellOutcome.hasFarewell)
                const _NpcInfoPill(
                  icon: Icons.waving_hand_outlined,
                  text: '有告别',
                ),
              _NpcInfoPill(
                icon: Icons.schedule_rounded,
                text: localTime,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppTheme.glitchText(createsCharacter
              ? '确认前可以完整检查；只有确认后才会创建新角色。'
              : '确认前可以完整检查；保存后只新增一份未绑定世界书，不会创建或修改角色。'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _MigrationSection(
          title: '旧世界来源',
          icon: Icons.history_edu_outlined,
          content: preview.sourceDigest,
          initiallyExpanded: true,
        ),
        _MigrationSection(
          title: '旧世界告别',
          icon: Icons.waving_hand_outlined,
          content: _previewFarewellText(preview.farewellOutcome),
        ),
        _MigrationSection(
          title: '迁徙档案',
          icon: Icons.folder_shared_outlined,
          content: preview.archiveText,
        ),
        _MigrationSection(
          title: '前尘世界书',
          icon: Icons.menu_book_outlined,
          content: '【${preview.worldBookTitle}】\n${preview.worldBookContent}',
        ),
        if (createsCharacter)
          _MigrationSection(
            title: '新角色卡',
            icon: Icons.person_pin_circle_outlined,
            content:
                '名称：${preview.characterName}\n简介：${preview.characterDescription}\n\n${preview.characterPrompt}',
          ),
        if (createsCharacter)
          _MigrationSection(
            title: '开场白',
            icon: Icons.waving_hand_outlined,
            content: preview.openingMessage,
          ),
        if (preview.manifest.qualityWarnings.isNotEmpty)
          _MigrationSection(
            title: '生成检查',
            icon: Icons.fact_check_outlined,
            content: preview.manifest.qualityWarnings
                .map((item) => '- $item')
                .join('\n'),
          ),
        _MigrationSection(
          title: '前尘信物',
          icon: Icons.card_giftcard_outlined,
          content: preview.keepsake.isEmpty
              ? '未生成。'
              : '名称：${preview.keepsake.name}\n外观与来历：${preview.keepsake.description}\n来源：${preview.keepsake.origin}\n关系意义：${preview.keepsake.emotionalMeaning}\n触发方向：${preview.keepsake.useEffectPrompt}',
        ),
        _MigrationSection(
          title: '关系任务',
          icon: Icons.task_alt_outlined,
          content: preview.relationshipTasks.isEmpty
              ? '未生成。'
              : preview.relationshipTasks
                  .map((task) =>
                      '${task.stage}｜${task.title}\n${task.description}')
                  .join('\n\n'),
        ),
      ],
    );
  }

  String _previewFarewellText(NpcFarewellOutcome outcome) {
    if (outcome.isEmpty) {
      return '用户选择不告别，直接续前缘。';
    }
    final buffer = StringBuffer()
      ..writeln('模式：${NpcFarewellMode.label(outcome.mode)}');
    if (outcome.userFarewellText.trim().isNotEmpty) {
      buffer.writeln('用户文字：${outcome.userFarewellText}');
    }
    if (outcome.selectedChoiceLabel.trim().isNotEmpty) {
      buffer.writeln('选择：${outcome.selectedChoiceLabel}');
    }
    if (outcome.finalSceneSummary.trim().isNotEmpty) {
      buffer.writeln('最后一幕：${outcome.finalSceneSummary}');
    }
    if (outcome.relationshipAfterFarewell.trim().isNotEmpty) {
      buffer.writeln('关系状态：${outcome.relationshipAfterFarewell}');
    }
    if (outcome.continuityFacts.isNotEmpty) {
      buffer.writeln('必须记住：${outcome.continuityFacts.join('；')}');
    }
    return buffer.toString().trim();
  }
}

class _MigrationSection extends StatelessWidget {
  const _MigrationSection({
    required this.title,
    required this.icon,
    required this.content,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final String content;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black
            .withValues(alpha: AppTheme.isBasicPaletteMode ? 0.03 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: AppTheme.activePrimary),
          title: Text(
            AppTheme.glitchText(title),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                AppTheme.glitchText(content.trim().isEmpty ? '暂无。' : content),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.55,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NpcThreadHeader extends StatefulWidget {
  const _NpcThreadHeader({required this.npc});

  final NpcProfile npc;

  @override
  State<_NpcThreadHeader> createState() => _NpcThreadHeaderState();
}

class _NpcThreadHeaderState extends State<_NpcThreadHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final npc = widget.npc;
    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 26),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, _expanded ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.sms_outlined, color: AppTheme.activeSoft),
                const SizedBox(width: 12),
                CharacterAvatar(
                  name: npc.name.trim().isEmpty ? 'NPC' : npc.name,
                  avatarDataUri: npc.avatarDataUri,
                  selected: true,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppTheme.glitchText('和 ${npc.name} 私聊'),
                        maxLines: 2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTheme.glitchText(
                          npc.canSendMessages
                              ? '只沉淀印象，不直接推进主线。'
                              : '${npc.lifecycle.label}状态下，私聊与好感已冻结。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: AppTheme.glitchText(_expanded ? '收起详情' : '展开详情'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _NpcInfoPill(
                  icon: Icons.favorite_border_rounded,
                  text: '好感度 ${npc.affinity}',
                ),
                if (npc.lifecycle != NpcLifecycle.active)
                  _NpcInfoPill(
                    icon: npc.lifecycle == NpcLifecycle.dead
                        ? Icons.person_off_outlined
                        : Icons.schedule_outlined,
                    text: npc.lifecycle.label,
                  ),
                _NpcInfoPill(
                  icon: Icons.route_outlined,
                  text: _formatNpcBondLabel(
                    npc.bondRoute,
                    includeScore: true,
                  ),
                ),
              ],
            ),
            if (_expanded) ...<Widget>[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * 0.42)
                      .clamp(240.0, 420.0),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _NpcImpressionDeltaCard(npc: npc),
                      const SizedBox(height: 12),
                      _NpcBondTimeline(npc: npc),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NpcImpressionDeltaCard extends StatelessWidget {
  const _NpcImpressionDeltaCard({required this.npc});

  final NpcProfile npc;

  @override
  Widget build(BuildContext context) {
    final latest =
        npc.impressionHistory.isNotEmpty ? npc.impressionHistory.first : null;
    final previous =
        npc.impressionHistory.length > 1 ? npc.impressionHistory[1] : null;
    final impression = npc.impression.trim();
    final changeLabel = _impressionChangeLabel(latest?.summary ?? impression);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.activeAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.psychology_alt_outlined, color: AppTheme.activeSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppTheme.glitchText('当前印象'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (changeLabel != null)
                  Text(
                    AppTheme.glitchText(changeLabel),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.activeSoft,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText(
                impression.isEmpty ? '暂无明确印象，聊几句后会自动沉淀。' : impression,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.55,
                  ),
            ),
            if (previous != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText('上一条：${previous.summary}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textWeak,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _impressionChangeLabel(String text) {
    final match = RegExp(r'好感变化[:：]\s*([+\-−]?\d+)').firstMatch(text);
    final value = match?.group(1)?.replaceAll('−', '-');
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed == 0) {
      return '好感变化 0';
    }
    return '好感变化 ${parsed > 0 ? '+$parsed' : parsed.toString()}';
  }
}

class _NpcBondTimeline extends StatelessWidget {
  const _NpcBondTimeline({required this.npc});

  final NpcProfile npc;

  @override
  Widget build(BuildContext context) {
    final bond = npc.bondRoute;
    final events = bond.events.take(5).toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.route_outlined, color: AppTheme.activeSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppTheme.glitchText('羁绊时间线'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  '${bond.score}/100',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.activeSoft,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _NpcBondProgressRail(score: bond.score),
            const SizedBox(height: 10),
            if (bond.latestEvent.trim().isNotEmpty)
              _NpcTimelineRow(
                title: '${bond.stage} · ${bond.route}',
                body: bond.latestEvent.trim(),
                active: true,
              )
            else
              _NpcTimelineRow(
                title: '${bond.stage} · ${bond.route}',
                body: '还没有明确羁绊节点。',
                active: true,
              ),
            for (final event in events)
              _NpcTimelineRow(
                title: '${event.stage} · ${event.route}',
                body: event.summary,
                active: false,
              ),
          ],
        ),
      ),
    );
  }
}

class _NpcBondProgressRail extends StatelessWidget {
  const _NpcBondProgressRail({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    const stages = <({int threshold, String label})>[
      (threshold: 0, label: '初见'),
      (threshold: 10, label: '熟悉'),
      (threshold: 25, label: '信任'),
      (threshold: 45, label: '牵绊'),
      (threshold: 65, label: '分岔'),
      (threshold: 80, label: '深羁绊'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final stage in stages)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: score >= stage.threshold
                  ? AppTheme.activeSoft.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: score >= stage.threshold
                    ? AppTheme.activeSoft
                    : AppTheme.activeLine,
              ),
            ),
            child: Text(
              AppTheme.glitchText(stage.label),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: score >= stage.threshold
                        ? AppTheme.activeSoft
                        : AppTheme.textWeak,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
      ],
    );
  }
}

class _NpcTimelineRow extends StatelessWidget {
  const _NpcTimelineRow({
    required this.title,
    required this.body,
    required this.active,
  });

  final String title;
  final String body;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              active
                  ? Icons.radio_button_checked_rounded
                  : Icons.circle_outlined,
              size: 15,
              color: active ? AppTheme.activeSoft : AppTheme.textWeak,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText(title),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppTheme.glitchText(body),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Editor ──────────────────────────────────────────────────────────────────
