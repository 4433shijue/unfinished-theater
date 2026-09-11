part of '../chat_screen.dart';

enum _MapBasketItemKind {
  location,
  action,
  clue,
  social,
  danger,
  rest,
}

class _MapBasketItem {
  const _MapBasketItem({
    required this.kind,
    required this.label,
    required this.actionText,
    this.locationId = '',
    this.riskLevel = '',
    this.timeCost = '',
  });

  factory _MapBasketItem.location(MapLocationNode location) {
    return _MapBasketItem(
      kind: _MapBasketItemKind.location,
      label: '前往 ${location.name}',
      actionText: '前往地点：${location.name}',
      locationId: location.id,
      riskLevel: location.riskLevel,
      timeCost: location.timeCost,
    );
  }

  factory _MapBasketItem.choice(MapStoryChoice choice) {
    return _MapBasketItem(
      kind: _kindFromChoice(choice.kind),
      label: choice.label,
      actionText:
          choice.action.trim().isEmpty ? choice.label : choice.action.trim(),
      locationId: choice.locationId,
      riskLevel: choice.riskLevel,
      timeCost: choice.timeCost,
    );
  }

  factory _MapBasketItem.freeAction(String action) {
    return _MapBasketItem(
      kind: _MapBasketItemKind.action,
      label: action,
      actionText: action,
    );
  }

  final _MapBasketItemKind kind;
  final String label;
  final String actionText;
  final String locationId;
  final String riskLevel;
  final String timeCost;

  String get normalizedKey {
    final source = locationId.trim().isNotEmpty ? locationId : actionText;
    return '${kind.name}:${source.trim()}';
  }

  Map<String, dynamic> toPlanJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'label': label,
      'action': actionText,
      if (locationId.trim().isNotEmpty) 'locationId': locationId.trim(),
      if (riskLevel.trim().isNotEmpty) 'riskLevel': riskLevel.trim(),
      if (timeCost.trim().isNotEmpty) 'timeCost': timeCost.trim(),
    };
  }

  IconData get icon {
    switch (kind) {
      case _MapBasketItemKind.location:
        return Icons.place_outlined;
      case _MapBasketItemKind.clue:
        return Icons.manage_search_rounded;
      case _MapBasketItemKind.social:
        return Icons.people_alt_outlined;
      case _MapBasketItemKind.danger:
        return Icons.warning_amber_rounded;
      case _MapBasketItemKind.rest:
        return Icons.schedule_rounded;
      case _MapBasketItemKind.action:
        return Icons.bolt_outlined;
    }
  }

  static _MapBasketItemKind _kindFromChoice(MapStoryChoiceKind kind) {
    switch (kind) {
      case MapStoryChoiceKind.location:
        return _MapBasketItemKind.location;
      case MapStoryChoiceKind.clue:
        return _MapBasketItemKind.clue;
      case MapStoryChoiceKind.social:
        return _MapBasketItemKind.social;
      case MapStoryChoiceKind.danger:
        return _MapBasketItemKind.danger;
      case MapStoryChoiceKind.rest:
        return _MapBasketItemKind.rest;
      case MapStoryChoiceKind.action:
        return _MapBasketItemKind.action;
    }
  }
}

class _FloatingMapOrb extends StatefulWidget {
  const _FloatingMapOrb({
    required this.state,
    required this.basketCount,
    required this.isBusy,
    required this.initialOffset,
    required this.onOffsetChanged,
    required this.onTap,
  });

  final MapWorldState state;
  final int basketCount;
  final bool isBusy;
  final Offset? initialOffset;
  final ValueChanged<Offset> onOffsetChanged;
  final VoidCallback onTap;

  @override
  State<_FloatingMapOrb> createState() => _FloatingMapOrbState();
}

class _FloatingMapOrbState extends State<_FloatingMapOrb> {
  Offset? _offset;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 700;
    final orbSize = compact ? 62.0 : 70.0;
    final defaultOffset = Offset(
      size.width - orbSize - (compact ? 20 : 38),
      size.height - orbSize - (compact ? 190 : 220),
    );
    final resolved = _clampOffset(
      _offset ?? widget.initialOffset ?? defaultOffset,
      size,
      orbSize,
    );
    final location = widget.state.currentLocationName.trim().isEmpty
        ? '地图'
        : widget.state.currentLocationName.trim();

    return Positioned(
      left: resolved.dx,
      top: resolved.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) {
          final next = _clampOffset(resolved + details.delta, size, orbSize);
          setState(() => _offset = next);
          widget.onOffsetChanged(next);
        },
        child: Semantics(
          button: true,
          label: '地图主线',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: orbSize,
            constraints: BoxConstraints(minHeight: orbSize),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  AppTheme.activePrimary.withValues(alpha: 0.95),
                  AppTheme.activeAccent.withValues(alpha: 0.82),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.activeSoft.withValues(alpha: 0.85),
                width: 1.4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppTheme.activeAccent.withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    widget.isBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.map_outlined, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      AppTheme.glitchText(location),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.fade,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                if (widget.basketCount > 0)
                  Positioned(
                    right: -8,
                    top: -10,
                    child: _MapOrbBadge(label: '${widget.basketCount}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Offset _clampOffset(Offset value, Size size, double orbSize) {
    final maxX = (size.width - orbSize - 8).clamp(8.0, size.width);
    final maxY = (size.height - orbSize - 132).clamp(72.0, size.height);
    return Offset(
      value.dx.clamp(8.0, maxX).toDouble(),
      value.dy.clamp(72.0, maxY).toDouble(),
    );
  }
}

class _MapOrbBadge extends StatelessWidget {
  const _MapOrbBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.panel, width: 1.5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _MapModeQuickActionBar extends StatefulWidget {
  const _MapModeQuickActionBar({
    required this.basketCount,
    required this.isBusy,
    required this.onAdd,
    required this.onOpenMap,
  });

  final int basketCount;
  final bool isBusy;
  final ValueChanged<_MapBasketItem> onAdd;
  final VoidCallback onOpenMap;

  @override
  State<_MapModeQuickActionBar> createState() => _MapModeQuickActionBarState();
}

class _MapModeQuickActionBarState extends State<_MapModeQuickActionBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassPanel(highlighted: true, radius: 26),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppTheme.glitchText('写一个地图行动，先放进行动篮子...'),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            style: AppTheme.skinIconButtonStyle(),
            tooltip: AppTheme.glitchText('加入行动篮子'),
            onPressed: widget.isBusy ? null : _submit,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: widget.onOpenMap,
            icon: const Icon(Icons.map_outlined),
            label: Text(
              AppTheme.glitchText(
                widget.basketCount > 0 ? '地图 ${widget.basketCount}' : '地图',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    widget.onAdd(_MapBasketItem.freeAction(value));
    _controller.clear();
  }
}

class _ChatMapPanel extends StatefulWidget {
  const _ChatMapPanel({
    required this.basket,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
    required this.onMove,
    required this.onSubmit,
    required this.onGenerate,
    required this.onRegenerate,
  });

  final List<_MapBasketItem> basket;
  final ValueChanged<_MapBasketItem> onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;
  final void Function(int oldIndex, int newIndex) onMove;
  final ValueChanged<String> onSubmit;
  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;

  @override
  State<_ChatMapPanel> createState() => _ChatMapPanelState();
}

class _ChatMapPanelState extends State<_ChatMapPanel> {
  final TextEditingController _freeActionController = TextEditingController();
  String _timeStep = '下一回合';

  @override
  void dispose() {
    _freeActionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final state = controller.currentMapState;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.all(compact ? 0 : 16),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(compact ? 26 : 30),
          border: Border.all(color: AppTheme.activeLine),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 34,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              _MapPanelHeader(
                state: state,
                isBusy: controller.isMapGenerating,
                onGenerate: widget.onGenerate,
                onRegenerate: state.locations.isEmpty || state.isRulesDriven
                    ? null
                    : widget.onRegenerate,
              ),
              Expanded(
                child: state.isEmpty
                    ? _EmptyChatMapPanel(
                        isBusy: controller.isMapGenerating,
                        onGenerate: widget.onGenerate,
                      )
                    : state.needsBirthSelection
                        ? _ChatBirthSelection(
                            state: state,
                            isBusy: controller.isMapGenerating,
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                            children: <Widget>[
                              _MapOverviewBlock(state: state),
                              const SizedBox(height: 12),
                              _MapSuggestionBlock(
                                choices: state.activeChoices,
                                onAdd: _addChoice,
                              ),
                              const SizedBox(height: 12),
                              _MapLocationBlock(
                                state: state,
                                onAddLocation: _addLocation,
                                onAddAction: _addLocationAction,
                              ),
                              const SizedBox(height: 12),
                              _MapIntelBlock(state: state),
                              const SizedBox(height: 12),
                              _MapFreeActionBlock(
                                controller: _freeActionController,
                                onSubmit: _addFreeAction,
                              ),
                              const SizedBox(height: 12),
                              _MapBasketBlock(
                                basket: widget.basket,
                                timeStep: _timeStep,
                                isBusy: controller.isMapGenerating,
                                onTimeStepChanged: (value) {
                                  setState(() => _timeStep = value);
                                },
                                onRemove: (index) {
                                  widget.onRemove(index);
                                  setState(() {});
                                },
                                onClear: () {
                                  widget.onClear();
                                  setState(() {});
                                },
                                onMove: (oldIndex, newIndex) {
                                  widget.onMove(oldIndex, newIndex);
                                  setState(() {});
                                },
                                onSubmit: () => widget.onSubmit(_timeStep),
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

  void _addChoice(MapStoryChoice choice) {
    widget.onAdd(_MapBasketItem.choice(choice));
    setState(() {});
  }

  void _addLocation(MapLocationNode location) {
    widget.onAdd(_MapBasketItem.location(location));
    setState(() {});
  }

  void _addLocationAction(MapLocationNode location, String action) {
    widget.onAdd(
      _MapBasketItem(
        kind: _MapBasketItemKind.action,
        label: action,
        actionText: '${location.name}：$action',
        locationId: location.id,
        riskLevel: location.riskLevel,
        timeCost: location.timeCost,
      ),
    );
    setState(() {});
  }

  void _addFreeAction() {
    final value = _freeActionController.text.trim();
    if (value.isEmpty) {
      return;
    }
    widget.onAdd(_MapBasketItem.freeAction(value));
    _freeActionController.clear();
    setState(() {});
  }
}

class _MapPanelHeader extends StatelessWidget {
  const _MapPanelHeader({
    required this.state,
    required this.isBusy,
    required this.onGenerate,
    required this.onRegenerate,
  });

  final MapWorldState state;
  final bool isBusy;
  final VoidCallback onGenerate;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.explore_outlined, color: AppTheme.activeSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText(
                    state.title.trim().isEmpty ? '地图主线' : state.title.trim(),
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.contrastText,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTheme.glitchText(
                    state.currentLocationName.trim().isEmpty
                        ? '聊天阅读 + 悬浮地图 + 行动篮子'
                        : '当前位置：${state.currentLocationName.trim()}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
            ),
          ),
          if (state.isEmpty)
            IconButton.filledTonal(
              style: AppTheme.skinIconButtonStyle(),
              tooltip: AppTheme.glitchText('生成地图'),
              onPressed: isBusy ? null : onGenerate,
              icon: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
            )
          else if (!state.isRulesDriven)
            IconButton.filledTonal(
              style: AppTheme.skinIconButtonStyle(),
              tooltip: AppTheme.glitchText('重新生成地图'),
              onPressed: isBusy ? null : onRegenerate,
              icon: const Icon(Icons.refresh_rounded),
            ),
          IconButton(
            tooltip: AppTheme.glitchText('关闭'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatMapPanel extends StatelessWidget {
  const _EmptyChatMapPanel({
    required this.isBusy,
    required this.onGenerate,
  });

  final bool isBusy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.map_outlined, size: 54, color: AppTheme.activeSoft),
            const SizedBox(height: 14),
            Text(
              AppTheme.glitchText('还没有稳定大地图'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              AppTheme.glitchText(
                'AI 会先生成 8-10 个固定地点、双向环路、NPC、任务和事件；地图蓝图保持固定，每回合先由本地规则结算，再由 AI 续写叙事。',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.55,
                  ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: isBusy ? null : onGenerate,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(AppTheme.glitchText(isBusy ? '生成中...' : '生成地图开局')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBirthSelection extends StatelessWidget {
  const _ChatBirthSelection({required this.state, required this.isBusy});

  final MapWorldState state;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        _MapPanelCard(
          highlighted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _MapSectionTitle(
                icon: Icons.flag_circle_outlined,
                title: '选择出生地点',
              ),
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText(
                  '地图已经固定。选定出生地点后，本地确定开局位置，再由 AI 写出开场剧情。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 12),
              ...state.spawnCandidates.map(
                (candidate) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppTheme.activeLine),
                    ),
                    leading: Icon(
                      candidate.style == 'danger'
                          ? Icons.local_fire_department_outlined
                          : candidate.style == 'social'
                              ? Icons.groups_outlined
                              : Icons.shield_outlined,
                    ),
                    title: Text(AppTheme.glitchText(candidate.label)),
                    subtitle: Text(AppTheme.glitchText(candidate.description)),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    enabled: !isBusy,
                    onTap: isBusy
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final error = await context
                                .read<AppStateController>()
                                .selectMapBirthLocation(candidate.locationId);
                            if (error != null) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(AppTheme.glitchText(error)),
                                ),
                              );
                            }
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapOverviewBlock extends StatelessWidget {
  const _MapOverviewBlock({required this.state});

  final MapWorldState state;

  @override
  Widget build(BuildContext context) {
    return _MapPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MapSectionTitle(icon: Icons.track_changes_rounded, title: '主线提示'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (state.timeLabel.trim().isNotEmpty)
                _MapInfoTag(
                    icon: Icons.schedule_rounded, text: state.timeLabel),
              if (state.stage.trim().isNotEmpty)
                _MapInfoTag(icon: Icons.flag_outlined, text: state.stage),
              if (state.currentLocationName.trim().isNotEmpty)
                _MapInfoTag(
                  icon: Icons.place_outlined,
                  text: state.currentLocationName,
                ),
              if (state.isRulesDriven)
                _MapInfoTag(
                  icon: Icons.bolt_rounded,
                  text: '${state.currentActionPoints}/${state.maxActionPoints} '
                      'AP · 临时 ${state.temporaryActionPointLimit}',
                ),
              if (state.isRulesDriven)
                _MapInfoTag(
                  icon: Icons.timer_outlined,
                  text: '危机 ${state.threatClock}/${state.threatLimit}',
                ),
            ],
          ),
          if (state.mainGoal.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              AppTheme.glitchText('目标：${state.mainGoal.trim()}'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMain,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (state.activeScene.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText(state.activeScene.trim()),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.55,
                  ),
            ),
          ],
          if (state.isRulesDriven &&
              state.mapInventory.any((item) => item.quantity > 0)) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: state.mapInventory
                  .where((item) => item.quantity > 0)
                  .map(
                    (item) => OutlinedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final error = await context
                            .read<AppStateController>()
                            .useMapItem(item.id);
                        if (error != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(AppTheme.glitchText(error)),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: Text(
                        AppTheme.glitchText('${item.name} ×${item.quantity}'),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapSuggestionBlock extends StatelessWidget {
  const _MapSuggestionBlock({
    required this.choices,
    required this.onAdd,
  });

  final List<MapStoryChoice> choices;
  final ValueChanged<MapStoryChoice> onAdd;

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) {
      return const SizedBox.shrink();
    }
    return _MapPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MapSectionTitle(icon: Icons.playlist_add_rounded, title: '行动建议'),
          const SizedBox(height: 10),
          ...choices.map(
            (choice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MapActionTile(
                icon: _choiceIcon(choice.kind),
                title: choice.label,
                subtitle: choice.action,
                riskLevel: choice.riskLevel,
                timeCost: choice.timeCost,
                onTap: () => onAdd(choice),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _choiceIcon(MapStoryChoiceKind kind) {
    switch (kind) {
      case MapStoryChoiceKind.location:
        return Icons.place_outlined;
      case MapStoryChoiceKind.clue:
        return Icons.search_rounded;
      case MapStoryChoiceKind.social:
        return Icons.people_alt_outlined;
      case MapStoryChoiceKind.danger:
        return Icons.warning_amber_rounded;
      case MapStoryChoiceKind.rest:
        return Icons.schedule_rounded;
      case MapStoryChoiceKind.action:
        return Icons.bolt_outlined;
    }
  }
}

class _MapLocationBlock extends StatelessWidget {
  const _MapLocationBlock({
    required this.state,
    required this.onAddLocation,
    required this.onAddAction,
  });

  final MapWorldState state;
  final ValueChanged<MapLocationNode> onAddLocation;
  final void Function(MapLocationNode location, String action) onAddAction;

  @override
  Widget build(BuildContext context) {
    if (state.locations.isEmpty) {
      return const SizedBox.shrink();
    }
    return _MapPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MapSectionTitle(icon: Icons.public_rounded, title: '稳定大地点'),
          const SizedBox(height: 10),
          ...state.locations.map(
            (location) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MapLocationCard(
                location: location,
                current: location.id == state.currentLocationId,
                travelCost: state.isRulesDriven &&
                        location.id != state.currentLocationId
                    ? context
                        .read<AppStateController>()
                        .mapTravelCost(location.id)
                    : 0,
                onAddLocation: () => onAddLocation(location),
                onAddAction: (action) => onAddAction(location, action),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLocationCard extends StatelessWidget {
  const _MapLocationCard({
    required this.location,
    required this.current,
    required this.travelCost,
    required this.onAddLocation,
    required this.onAddAction,
  });

  final MapLocationNode location;
  final bool current;
  final int? travelCost;
  final VoidCallback onAddLocation;
  final ValueChanged<String> onAddAction;

  @override
  Widget build(BuildContext context) {
    final hidden = location.status == MapLocationStatus.hidden;
    final locked = location.status == MapLocationStatus.locked;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: current
            ? AppTheme.activePrimary.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current
              ? AppTheme.activeSoft.withValues(alpha: 0.55)
              : AppTheme.activeLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                current ? Icons.my_location_rounded : Icons.place_outlined,
                color: AppTheme.activeSoft,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText(hidden ? '未知地点' : location.name),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _MapStatusBadge(text: _statusText(location.status, current)),
            ],
          ),
          if (!hidden && location.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText(location.description.trim()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if (location.riskLevel.trim().isNotEmpty)
                _MapInfoTag(
                  icon: Icons.warning_amber_rounded,
                  text: location.riskLevel,
                ),
              if (location.timeCost.trim().isNotEmpty)
                _MapInfoTag(
                    icon: Icons.timer_outlined, text: location.timeCost),
              if (location.npcs.isNotEmpty)
                _MapInfoTag(
                  icon: Icons.people_alt_outlined,
                  text: location.npcs.join('、'),
                ),
              if (location.clues.isNotEmpty)
                _MapInfoTag(
                  icon: Icons.search_rounded,
                  text: '${location.clues.length} 条线索',
                ),
              if (!current && travelCost != null)
                _MapInfoTag(
                  icon: Icons.bolt_outlined,
                  text: '$travelCost AP',
                ),
            ],
          ),
          if (!hidden && location.clues.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _MapBulletList(title: '线索', items: location.clues),
          ],
          if (!hidden && location.nextActions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _MapBulletList(title: '推荐行动', items: location.nextActions),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: hidden || locked ? null : onAddLocation,
                icon: const Icon(Icons.near_me_outlined, size: 17),
                label: Text(AppTheme.glitchText(current ? '留在此处行动' : '加入前往')),
              ),
              for (final action in location.nextActions.take(3))
                OutlinedButton.icon(
                  onPressed:
                      hidden || locked ? null : () => onAddAction(action),
                  icon: const Icon(Icons.playlist_add_rounded, size: 17),
                  label: Text(AppTheme.glitchText(action)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusText(MapLocationStatus status, bool current) {
    if (current) {
      return '当前位置';
    }
    switch (status) {
      case MapLocationStatus.locked:
        return '未解锁';
      case MapLocationStatus.available:
        return '可前往';
      case MapLocationStatus.current:
        return '当前位置';
      case MapLocationStatus.explored:
        return '已探索';
      case MapLocationStatus.hidden:
        return '隐藏';
    }
  }
}

class _MapIntelBlock extends StatelessWidget {
  const _MapIntelBlock({required this.state});

  final MapWorldState state;

  @override
  Widget build(BuildContext context) {
    if (state.discoveredClues.isEmpty &&
        state.npcMovements.isEmpty &&
        state.eventLog.isEmpty) {
      return const SizedBox.shrink();
    }
    return _MapPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MapSectionTitle(icon: Icons.hub_outlined, title: '线索与动向'),
          if (state.discoveredClues.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _MapBulletList(
              title: '关键线索',
              items: state.discoveredClues.take(12).toList(growable: false),
            ),
          ],
          if (state.npcMovements.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _MapBulletList(
              title: '最新动向',
              items: state.npcMovements.take(8).toList(growable: false),
            ),
          ],
          if (state.eventLog.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _MapBulletList(
              title: '最近事件',
              items: state.eventLog.take(4).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapFreeActionBlock extends StatelessWidget {
  const _MapFreeActionBlock({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _MapPanelCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: AppTheme.glitchText('补充一个自由行动，先放篮子里...'),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            style: AppTheme.skinIconButtonStyle(),
            tooltip: AppTheme.glitchText('加入行动篮子'),
            onPressed: onSubmit,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
        ],
      ),
    );
  }
}

class _MapBasketBlock extends StatelessWidget {
  const _MapBasketBlock({
    required this.basket,
    required this.timeStep,
    required this.isBusy,
    required this.onTimeStepChanged,
    required this.onRemove,
    required this.onClear,
    required this.onMove,
    required this.onSubmit,
  });

  final List<_MapBasketItem> basket;
  final String timeStep;
  final bool isBusy;
  final ValueChanged<String> onTimeStepChanged;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;
  final void Function(int oldIndex, int newIndex) onMove;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    const steps = <String>['下一回合', '下一小时', '下一阶段', '下一天', '下个关键事件'];
    return _MapPanelCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MapSectionTitle(
                  icon: Icons.shopping_basket_outlined,
                  title: '行动篮子',
                ),
              ),
              if (basket.isNotEmpty)
                TextButton.icon(
                  onPressed: isBusy ? null : onClear,
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: Text(AppTheme.glitchText('清空')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (basket.isEmpty)
            Text(
              AppTheme.glitchText(
                '点地点、行动建议或输入自由行动，都会先留在这里；确认后先完成本地规则结算，再由 AI 续写本回合叙事。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
            )
          else
            ...basket.asMap().entries.map(
                  (entry) => _MapBasketTile(
                    index: entry.key,
                    item: entry.value,
                    canMoveUp: entry.key > 0,
                    canMoveDown: entry.key < basket.length - 1,
                    onMoveUp: () => onMove(entry.key, entry.key - 1),
                    onMoveDown: () => onMove(entry.key, entry.key + 1),
                    onRemove: () => onRemove(entry.key),
                  ),
                ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps
                .map(
                  (step) => ChoiceChip(
                    selected: timeStep == step,
                    onSelected: (_) => onTimeStepChanged(step),
                    label: Text(AppTheme.glitchText(step)),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isBusy || basket.isEmpty ? null : onSubmit,
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(AppTheme.glitchText(isBusy ? '推进中...' : '确认并推进')),
          ),
        ],
      ),
    );
  }
}

class _MapBasketTile extends StatelessWidget {
  const _MapBasketTile({
    required this.index,
    required this.item,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final _MapBasketItem item;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(item.icon, size: 18, color: AppTheme.activeSoft),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('${index + 1}. ${item.label}'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMain,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                ),
                if (item.actionText.trim() != item.label.trim()) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    AppTheme.glitchText(item.actionText),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                  ),
                ],
                if (item.riskLevel.trim().isNotEmpty ||
                    item.timeCost.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      if (item.riskLevel.trim().isNotEmpty)
                        _MapInfoTag(
                          icon: Icons.warning_amber_rounded,
                          text: item.riskLevel,
                        ),
                      if (item.timeCost.trim().isNotEmpty)
                        _MapInfoTag(
                          icon: Icons.timer_outlined,
                          text: item.timeCost,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: AppTheme.glitchText('上移'),
                visualDensity: VisualDensity.compact,
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: AppTheme.glitchText('下移'),
                visualDensity: VisualDensity.compact,
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                tooltip: AppTheme.glitchText('删除'),
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapActionTile extends StatelessWidget {
  const _MapActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.riskLevel,
    required this.timeCost,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String riskLevel;
  final String timeCost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.activeLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: AppTheme.activeSoft, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppTheme.glitchText(title),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMain,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (subtitle.trim().isNotEmpty &&
                      subtitle.trim() != title.trim()) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      AppTheme.glitchText(subtitle),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            height: 1.4,
                          ),
                    ),
                  ],
                  if (riskLevel.trim().isNotEmpty ||
                      timeCost.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (riskLevel.trim().isNotEmpty)
                          _MapInfoTag(
                            icon: Icons.warning_amber_rounded,
                            text: riskLevel,
                          ),
                        if (timeCost.trim().isNotEmpty)
                          _MapInfoTag(
                            icon: Icons.timer_outlined,
                            text: timeCost,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.add_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MapPanelCard extends StatelessWidget {
  const _MapPanelCard({
    required this.child,
    this.highlighted = false,
  });

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassPanel(highlighted: highlighted, radius: 18),
      child: child,
    );
  }
}

class _MapSectionTitle extends StatelessWidget {
  const _MapSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: AppTheme.activeSoft),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            AppTheme.glitchText(title),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.contrastText,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _MapInfoTag extends StatelessWidget {
  const _MapInfoTag({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: AppTheme.textWeak),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              AppTheme.glitchText(text),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapStatusBadge extends StatelessWidget {
  const _MapStatusBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppTheme.glitchText(text),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _MapBulletList extends StatelessWidget {
  const _MapBulletList({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final visible = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppTheme.glitchText(title),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.activeSoft,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        ...visible.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.activeSoft,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppTheme.glitchText(item),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.42,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
