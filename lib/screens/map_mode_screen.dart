import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/map_state.dart';
import '../theme/app_theme.dart';
import '../widgets/runnable_code_preview.dart';

class MapModeScreen extends StatefulWidget {
  const MapModeScreen({super.key});

  @override
  State<MapModeScreen> createState() => _MapModeScreenState();
}

class _MapModeScreenState extends State<MapModeScreen> {
  final TextEditingController _actionController = TextEditingController();
  final Set<String> _selectedLocationIds = <String>{};
  final Set<String> _selectedOpeningChoiceIds = <String>{};
  final List<String> _queuedActions = <String>[];
  bool _showHtmlPanel = false;
  bool _phoneOrientationLocked = false;
  bool _orientationRequestScheduled = false;
  MapRouteMode _selectedRouteMode = MapRouteMode.leastActionPoints;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestPhoneLandscape();
  }

  void _requestPhoneLandscape() {
    if (_orientationRequestScheduled ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ||
        MediaQuery.sizeOf(context).shortestSide >= 600) {
      return;
    }
    _orientationRequestScheduled = true;
    _phoneOrientationLocked = true;
    unawaited(
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  @override
  void dispose() {
    if (_phoneOrientationLocked) {
      unawaited(
        SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
          DeviceOrientation.portraitUp,
        ]),
      );
    }
    _actionController.dispose();
    super.dispose();
  }

  int get _planCount => _selectedLocationIds.length + _queuedActions.length;

  void _queueHtmlAction(
    BuildContext context,
    MapWorldState state,
    String action,
  ) {
    final trimmed = action.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final locationId = _locationIdFromAction(state, trimmed);
    if (locationId != null) {
      _openLocation(context, locationId);
      return;
    }

    final timeStep = _timeStepFromAction(trimmed);
    if (timeStep != null) {
      _submitRound(context, timeStep);
      return;
    }

    _queueAction(trimmed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText('行动已加入下一回合计划。'))),
    );
  }

  String? _locationIdFromAction(MapWorldState state, String action) {
    final locationMatch = RegExp(
      r'^(?:map:location:|location:|地点[:：])\s*([^|｜]+)(?:[|｜](.+))?$',
      caseSensitive: false,
    ).firstMatch(action);
    if (locationMatch == null) {
      return null;
    }
    final rawId = locationMatch.group(1)?.trim() ?? '';
    if (rawId.isEmpty) {
      return null;
    }
    for (final location in state.locations) {
      if (location.id == rawId || location.name == rawId) {
        return location.id;
      }
    }
    return rawId;
  }

  String? _timeStepFromAction(String action) {
    final timeMatch = RegExp(
      r'^(?:map:time:|time:|时间[:：])\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(action);
    return timeMatch?.group(1)?.trim();
  }

  void _toggleLocation(String locationId, {bool forceSelected = false}) {
    final normalized = locationId.trim();
    if (normalized.isEmpty) {
      return;
    }
    setState(() {
      if (forceSelected) {
        _selectedLocationIds.add(normalized);
      } else if (_selectedLocationIds.contains(normalized)) {
        _selectedLocationIds.remove(normalized);
      } else {
        _selectedLocationIds.add(normalized);
      }
    });
  }

  void _planLocation(MapWorldState state, String locationId) {
    if (!state.isRulesDriven) {
      _toggleLocation(locationId);
      return;
    }
    final normalized = locationId.trim();
    if (normalized.isEmpty || normalized == state.currentLocationId) {
      return;
    }
    setState(() {
      if (_selectedLocationIds.contains(normalized)) {
        _selectedLocationIds.clear();
      } else {
        _selectedLocationIds
          ..clear()
          ..add(normalized);
      }
    });
  }

  void _queueAction(String action) {
    final trimmed = action.trim();
    if (trimmed.isEmpty) {
      return;
    }
    setState(() {
      if (!_queuedActions.contains(trimmed)) {
        _queuedActions.add(trimmed);
      }
    });
  }

  void _removeQueuedAction(String action) {
    setState(() => _queuedActions.remove(action));
  }

  Future<void> _openLocation(BuildContext context, String locationId) async {
    final controller = context.read<AppStateController>();
    final state = controller.currentMapState;
    if (state.isRulesDriven) {
      final location =
          state.locations.where((item) => item.id == locationId).firstOrNull;
      if (location == null || location.id == state.currentLocationId) {
        return;
      }
      final selectedMode = await showModalBottomSheet<MapRouteMode>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => _RoutePreviewSheet(
          location: location,
          currentActionPoints: state.currentActionPoints,
          cheapest: controller.mapRouteTo(
            locationId,
            mode: MapRouteMode.leastActionPoints,
          ),
          safest: controller.mapRouteTo(
            locationId,
            mode: MapRouteMode.safest,
          ),
          fastest: controller.mapRouteTo(
            locationId,
            mode: MapRouteMode.fastest,
          ),
        ),
      );
      if (!mounted || selectedMode == null) {
        return;
      }
      setState(() {
        _selectedRouteMode = selectedMode;
        _selectedLocationIds
          ..clear()
          ..add(locationId);
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final error = await controller.openMapLocation(locationId);
    if (!mounted) {
      return;
    }
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText(error))),
      );
    }
  }

  void _runChoice(BuildContext context, MapStoryChoice choice) {
    if (choice.kind == MapStoryChoiceKind.location) {
      final locationId = choice.locationId.trim();
      if (locationId.isNotEmpty) {
        _openLocation(context, locationId);
        return;
      }
    }
    final action = choice.action.trim().isEmpty
        ? choice.label.trim()
        : choice.action.trim();
    if (action.isNotEmpty) {
      _queueAction(action);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('行动已加入下一回合计划。'))),
      );
    }
  }

  void _clearPlan() {
    setState(() {
      _selectedLocationIds.clear();
      _queuedActions.clear();
    });
  }

  Future<void> _submitRound(BuildContext context, String step) async {
    final actions = List<String>.from(_queuedActions);
    final locationIds = _selectedLocationIds.toList(growable: false);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<AppStateController>().runMapPlannedRound(
      actions: actions,
      locationIds: locationIds,
      timeStep: step,
      structuredActions: <Map<String, dynamic>>[
        if (locationIds.isNotEmpty)
          <String, dynamic>{
            'kind': 'location',
            'locationId': locationIds.first,
            'routeMode': _selectedRouteMode.name,
          },
      ],
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText(error))),
      );
      return;
    }
    _clearPlan();
  }

  Future<void> _enterChat(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error =
        await context.read<AppStateController>().enterMapMomentInChat();
    if (!mounted) {
      return;
    }
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText(error))),
      );
      return;
    }
    navigator.pop();
  }

  Widget _buildLandscapeMap(
    BuildContext context,
    AppStateController controller,
    MapWorldState state,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideWidth = (constraints.maxWidth * 0.37).clamp(270.0, 380.0);
        return Row(
          key: const ValueKey<String>('map-landscape-layout'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _MapGraphBoard(
                state: state,
                selectedLocationIds: _selectedLocationIds,
                expanded: true,
                onLocationTap: (locationId) =>
                    _openLocation(context, locationId),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: sideWidth,
              child: _LandscapeMapSideRail(
                actionController: _actionController,
                isBusy: controller.isMapGenerating,
                onSubmitAction: () {
                  final value = _actionController.text.trim();
                  if (value.isEmpty) {
                    return;
                  }
                  _actionController.clear();
                  _queueAction(value);
                },
                compassChildren: <Widget>[
                  _MapCompassPanel(
                    state: state,
                    isBusy: controller.isMapGenerating,
                    onChoice: (choice) => _runChoice(context, choice),
                    onFreeAction: _queueAction,
                  ),
                  _CurrentScenePanel(
                    state: state,
                    isBusy: controller.isMapGenerating,
                    onChoice: (choice) => _runChoice(context, choice),
                    onFreeAction: _queueAction,
                    onEnterChat: () => _enterChat(context),
                  ),
                ],
                planChildren: <Widget>[
                  _ActionBasketPanel(
                    state: state,
                    selectedLocationIds: _selectedLocationIds,
                    queuedActions: _queuedActions,
                    routeMode: _selectedRouteMode,
                    onRemoveLocation: _toggleLocation,
                    onRemoveAction: _removeQueuedAction,
                    onClear: _clearPlan,
                  ),
                  _TimeAdvancePanel(
                    planCount: _planCount,
                    isBusy: controller.isMapGenerating,
                    rulesDriven: state.isRulesDriven,
                    onAdvance: (step) => _submitRound(context, step),
                    onReset: _planCount == 0 ? null : _clearPlan,
                  ),
                  _MapTurnPanel(
                    state: state,
                    isBusy: controller.isMapGenerating,
                    onUseItem: (itemId) async {
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await controller.useMapItem(itemId);
                      if (!mounted || error == null) {
                        return;
                      }
                      messenger.showSnackBar(
                        SnackBar(content: Text(AppTheme.glitchText(error))),
                      );
                    },
                  ),
                ],
                detailChildren: <Widget>[
                  _CurrentLocationStatusPanel(state: state),
                  _NpcPositionPanel(state: state),
                  _LocationBoard(
                    state: state,
                    selectedLocationIds: _selectedLocationIds,
                    onToggle: (locationId) => _planLocation(state, locationId),
                    onOpen: (locationId) => _openLocation(context, locationId),
                  ),
                  _MapIntelPanel(state: state),
                  _EventLogPanel(state: state),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final character = controller.currentCharacter;
    final state = controller.currentMapState;
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.shortestSide < 600;
    final useLandscapeMap = state.isRulesDriven &&
        viewport.width >= 640 &&
        viewport.width > viewport.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.shellBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton.filledTonal(
                      style: AppTheme.skinIconButtonStyle(),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppTheme.glitchText('地图主线'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            character == null
                                ? AppTheme.glitchText('暂无角色')
                                : AppTheme.glitchText(
                                    '${character.name} · ${state.timeLabel.trim().isEmpty ? '时间未定' : state.timeLabel}',
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textMuted,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (!state.isEmpty && !state.isRulesDriven) ...<Widget>[
                      IconButton.filledTonal(
                        style: AppTheme.skinIconButtonStyle(),
                        tooltip: AppTheme.glitchText('升级为本地回合地图'),
                        onPressed: controller.isMapGenerating
                            ? null
                            : () => _run(
                                  context,
                                  controller.upgradeCurrentMapToRules,
                                ),
                        icon: const Icon(Icons.upgrade_rounded),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton.filledTonal(
                      style: AppTheme.skinIconButtonStyle(),
                      tooltip: AppTheme.glitchText(
                        state.isRulesDriven ? '固定地图不可重生成' : '重生成当前位置',
                      ),
                      onPressed: controller.isMapGenerating ||
                              state.isRulesDriven ||
                              state.isEmpty
                          ? null
                          : () => _run(
                                context,
                                controller.regenerateCurrentMapLocation,
                              ),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 8),
                    if (compact)
                      IconButton.filledTonal(
                        style: AppTheme.skinIconButtonStyle(),
                        tooltip: AppTheme.glitchText('进聊天'),
                        onPressed:
                            state.isEmpty ? null : () => _enterChat(context),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                      )
                    else
                      FilledButton.tonalIcon(
                        onPressed:
                            state.isEmpty ? null : () => _enterChat(context),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: Text(AppTheme.glitchText('进聊天')),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (state.needsOpeningSetup)
                  Expanded(
                    child: _OpeningSetupPanel(
                      state: state,
                      selectedChoiceIds: _selectedOpeningChoiceIds,
                      isGenerating: controller.isMapGenerating,
                      onToggle: (choiceId) {
                        setState(() {
                          if (_selectedOpeningChoiceIds.contains(choiceId)) {
                            _selectedOpeningChoiceIds.remove(choiceId);
                          } else {
                            _selectedOpeningChoiceIds.add(choiceId);
                          }
                        });
                      },
                      onGenerate: () =>
                          _run(context, controller.generateMapOpeningChoices),
                      onApply: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final error = await controller.applyMapOpeningChoices(
                          _selectedOpeningChoiceIds,
                        );
                        if (!mounted) {
                          return;
                        }
                        if (error != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(AppTheme.glitchText(error))),
                          );
                          return;
                        }
                        setState(() => _selectedOpeningChoiceIds.clear());
                      },
                    ),
                  )
                else if (state.isEmpty)
                  Expanded(
                    child: _EmptyMapPanel(
                      isGenerating: controller.isMapGenerating,
                      onGenerate: () =>
                          _run(context, controller.generateInitialMap),
                    ),
                  )
                else if (state.needsBirthSelection)
                  Expanded(
                    child: _BirthSelectionPanel(
                      state: state,
                      isBusy: controller.isMapGenerating,
                      onSelect: (locationId) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final error =
                            await controller.selectMapBirthLocation(locationId);
                        if (!mounted || error == null) {
                          return;
                        }
                        messenger.showSnackBar(
                          SnackBar(content: Text(AppTheme.glitchText(error))),
                        );
                      },
                    ),
                  )
                else
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        if (useLandscapeMap)
                          _buildLandscapeMap(
                            context,
                            controller,
                            state,
                          )
                        else
                          ListView(
                            children: <Widget>[
                              if (state.isRulesDriven) ...<Widget>[
                                _MapTurnPanel(
                                  state: state,
                                  isBusy: controller.isMapGenerating,
                                  onUseItem: (itemId) async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final error =
                                        await controller.useMapItem(itemId);
                                    if (!mounted || error == null) {
                                      return;
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content:
                                            Text(AppTheme.glitchText(error)),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _MapGraphBoard(
                                  state: state,
                                  selectedLocationIds: _selectedLocationIds,
                                  onLocationTap: (locationId) =>
                                      _openLocation(context, locationId),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _MapCompassPanel(
                                state: state,
                                isBusy: controller.isMapGenerating,
                                onChoice: (choice) =>
                                    _runChoice(context, choice),
                                onFreeAction: (action) => _queueAction(action),
                              ),
                              const SizedBox(height: 12),
                              _CurrentLocationStatusPanel(state: state),
                              const SizedBox(height: 12),
                              _NpcPositionPanel(state: state),
                              const SizedBox(height: 12),
                              _CurrentScenePanel(
                                state: state,
                                isBusy: controller.isMapGenerating,
                                onChoice: (choice) =>
                                    _runChoice(context, choice),
                                onFreeAction: (action) => _queueAction(action),
                                onEnterChat: () => _enterChat(context),
                              ),
                              const SizedBox(height: 12),
                              _LocationBoard(
                                state: state,
                                selectedLocationIds: _selectedLocationIds,
                                onToggle: (locationId) =>
                                    _planLocation(state, locationId),
                                onOpen: (locationId) =>
                                    _openLocation(context, locationId),
                              ),
                              const SizedBox(height: 12),
                              _ActionBasketPanel(
                                state: state,
                                selectedLocationIds: _selectedLocationIds,
                                queuedActions: _queuedActions,
                                routeMode: _selectedRouteMode,
                                onRemoveLocation: _toggleLocation,
                                onRemoveAction: _removeQueuedAction,
                                onClear: _clearPlan,
                              ),
                              const SizedBox(height: 12),
                              _TimeAdvancePanel(
                                planCount: _planCount,
                                isBusy: controller.isMapGenerating,
                                rulesDriven: state.isRulesDriven,
                                onAdvance: (step) =>
                                    _submitRound(context, step),
                                onReset: _planCount == 0 ? null : _clearPlan,
                              ),
                              const SizedBox(height: 12),
                              _MapIntelPanel(state: state),
                              if (!state.isRulesDriven) ...<Widget>[
                                const SizedBox(height: 12),
                                _MapHtmlToggleCard(
                                  expanded: _showHtmlPanel,
                                  onToggle: () => setState(
                                    () => _showHtmlPanel = !_showHtmlPanel,
                                  ),
                                  child: _showHtmlPanel
                                      ? _MapPreviewCard(
                                          state: state,
                                          onAction: (action) =>
                                              _queueHtmlAction(
                                            context,
                                            state,
                                            action,
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _EventLogPanel(state: state),
                              const SizedBox(height: 92),
                            ],
                          ),
                        if (controller.isMapGenerating)
                          const _MapLoadingOverlay(),
                      ],
                    ),
                  ),
                if (!state.isEmpty &&
                    !state.needsBirthSelection &&
                    !useLandscapeMap)
                  _MapActionBar(
                    controller: _actionController,
                    isBusy: controller.isMapGenerating,
                    onSubmit: () async {
                      final value = _actionController.text.trim();
                      if (value.isEmpty) {
                        return;
                      }
                      _actionController.clear();
                      _queueAction(value);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() task,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await task();
    if (!mounted || error == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(AppTheme.glitchText(error))));
  }
}

class _LandscapeMapSideRail extends StatelessWidget {
  const _LandscapeMapSideRail({
    required this.actionController,
    required this.isBusy,
    required this.onSubmitAction,
    required this.compassChildren,
    required this.planChildren,
    required this.detailChildren,
  });

  final TextEditingController actionController;
  final bool isBusy;
  final VoidCallback onSubmitAction;
  final List<Widget> compassChildren;
  final List<Widget> planChildren;
  final List<Widget> detailChildren;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            dividerColor: AppTheme.activeLine,
            tabs: const <Widget>[
              _LandscapeMapTab(
                icon: Icons.explore_outlined,
                label: '罗盘',
              ),
              _LandscapeMapTab(
                icon: Icons.playlist_add_check_rounded,
                label: '计划',
              ),
              _LandscapeMapTab(
                icon: Icons.info_outline_rounded,
                label: '详情',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _LandscapeMapRailList(children: compassChildren),
                _LandscapeMapRailList(children: planChildren),
                _LandscapeMapRailList(children: detailChildren),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _MapActionBar(
            controller: actionController,
            isBusy: isBusy,
            onSubmit: onSubmitAction,
          ),
        ],
      ),
    );
  }
}

class _LandscapeMapTab extends StatelessWidget {
  const _LandscapeMapTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 17),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              AppTheme.glitchText(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeMapRailList extends StatelessWidget {
  const _LandscapeMapRailList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: PageStorageKey<String>('map-rail-${children.length}'),
      padding: EdgeInsets.zero,
      itemCount: children.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => children[index],
    );
  }
}

class _EmptyMapPanel extends StatelessWidget {
  const _EmptyMapPanel({
    required this.isGenerating,
    required this.onGenerate,
  });

  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.map_outlined,
              size: 54,
              color: AppTheme.activeSoft,
            ),
            const SizedBox(height: 16),
            Text(
              AppTheme.glitchText('还没有交互地图'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppTheme.glitchText(
                '开局设置完成后由 AI 生成固定地图蓝图。之后每回合先由本地规则结算移动、NPC 与事件，再由 AI 继续叙事。',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isGenerating ? null : onGenerate,
              icon: isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(AppTheme.glitchText(
                isGenerating ? '地图生成中...' : '生成交互地图',
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningSetupPanel extends StatelessWidget {
  const _OpeningSetupPanel({
    required this.state,
    required this.selectedChoiceIds,
    required this.isGenerating,
    required this.onToggle,
    required this.onGenerate,
    required this.onApply,
  });

  final MapWorldState state;
  final Set<String> selectedChoiceIds;
  final bool isGenerating;
  final ValueChanged<String> onToggle;
  final VoidCallback onGenerate;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final choices = state.openingChoices;
    final grouped = <String, List<MapOpeningChoice>>{};
    for (final choice in choices) {
      grouped
          .putIfAbsent(choice.category, () => <MapOpeningChoice>[])
          .add(choice);
    }
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 680),
        padding: const EdgeInsets.all(22),
        decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
        child: choices.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.auto_fix_high_rounded,
                      size: 54, color: AppTheme.activeSoft),
                  const SizedBox(height: 16),
                  Text(
                    AppTheme.glitchText('先载入开局选择'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppTheme.glitchText(
                      '开局选项由本地规则提供，不消耗 AI 调用。选好之后，再一次性生成固定地图。',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: isGenerating ? null : onGenerate,
                    icon: isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.casino_outlined),
                    label: Text(AppTheme.glitchText(
                      isGenerating ? '正在载入...' : '载入开局选择',
                    )),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppTheme.glitchText('选择你的开局设定'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTheme.glitchText('可多选。选好后会写入地图主线，不会改角色原始提示词。'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: grouped.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  AppTheme.glitchText(entry.key),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: AppTheme.activeSoft),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: entry.value.map((choice) {
                                    final selected =
                                        selectedChoiceIds.contains(choice.id);
                                    return FilterChip(
                                      selected: selected,
                                      onSelected: (_) => onToggle(choice.id),
                                      label: Text(AppTheme.glitchText(
                                        choice.description.trim().isEmpty
                                            ? choice.label
                                            : '${choice.label}｜${choice.description}',
                                      )),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: isGenerating ? null : onGenerate,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(AppTheme.glitchText('恢复默认选项')),
                      ),
                      FilledButton.icon(
                        onPressed: selectedChoiceIds.isEmpty ? null : onApply,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(AppTheme.glitchText('确认开局')),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _BirthSelectionPanel extends StatelessWidget {
  const _BirthSelectionPanel({
    required this.state,
    required this.isBusy,
    required this.onSelect,
  });

  final MapWorldState state;
  final bool isBusy;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 760),
          padding: const EdgeInsets.all(22),
          decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.flag_circle_outlined, color: AppTheme.activeSoft),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      AppTheme.glitchText('选择出生地点'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText(
                  '地图拓扑已经固定。选定出生地点后，本地确定开局位置，再由 AI 写出开场剧情。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;
                  final width = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 20) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: state.spawnCandidates.map((candidate) {
                      final location = state.locations
                          .where((item) => item.id == candidate.locationId)
                          .firstOrNull;
                      return SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.activeLine),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                _spawnIcon(candidate.style),
                                color: AppTheme.activeSoft,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppTheme.glitchText(candidate.label),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                AppTheme.glitchText(candidate.description),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textMuted,
                                      height: 1.4,
                                    ),
                              ),
                              if (location != null) ...<Widget>[
                                const SizedBox(height: 8),
                                _MiniTag(
                                  icon: Icons.warning_amber_rounded,
                                  label: '风险：${location.riskLevel}',
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : () => onSelect(candidate.locationId),
                                  icon: const Icon(Icons.flag_rounded),
                                  label: Text(AppTheme.glitchText('从这里开始')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _spawnIcon(String style) {
    switch (style) {
      case 'danger':
        return Icons.local_fire_department_outlined;
      case 'social':
        return Icons.groups_outlined;
      default:
        return Icons.shield_outlined;
    }
  }
}

class _MapTurnPanel extends StatelessWidget {
  const _MapTurnPanel({
    required this.state,
    required this.isBusy,
    required this.onUseItem,
  });

  final MapWorldState state;
  final bool isBusy;
  final ValueChanged<String> onUseItem;

  @override
  Widget build(BuildContext context) {
    final availableItems = state.mapInventory
        .where((item) => item.quantity > 0)
        .toList(growable: false);
    final threatProgress = state.threatLimit <= 0
        ? 0.0
        : (state.threatClock / state.threatLimit).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(highlighted: true, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppTheme.glitchText('第 ${state.turnNumber + 1} 回合'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusChip(
                icon: Icons.bolt_rounded,
                text:
                    '${state.currentActionPoints}/${state.maxActionPoints} AP',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List<Widget>.generate(state.maxActionPoints, (index) {
              final active = index < state.currentActionPoints;
              final beyondTemporaryLimit =
                  index >= state.temporaryActionPointLimit;
              return Expanded(
                child: Container(
                  height: 10,
                  margin: EdgeInsets.only(
                    right: index == state.maxActionPoints - 1 ? 0 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? beyondTemporaryLimit
                            ? AppTheme.activeAccent
                            : AppTheme.activePrimary
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: beyondTemporaryLimit
                          ? AppTheme.activeAccent.withValues(alpha: 0.58)
                          : AppTheme.activeLine,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              Text(
                AppTheme.glitchText(
                  '临时上限 ${state.temporaryActionPointLimit} AP',
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              Text(
                AppTheme.glitchText('总上限 ${state.maxActionPoints} AP'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.activeAccent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.timer_outlined, size: 16, color: AppTheme.textWeak),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: threatProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: threatProgress >= 0.75
                        ? Theme.of(context).colorScheme.error
                        : AppTheme.activeAccent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppTheme.glitchText(
                  '危机 ${state.threatClock}/${state.threatLimit}',
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ),
          if (availableItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableItems.map((item) {
                return Tooltip(
                  message: AppTheme.glitchText(
                    item.description.trim().isEmpty
                        ? item.name
                        : item.description,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : () => onUseItem(item.id),
                    icon: Icon(_itemIcon(item.kind), size: 17),
                    label: Text(
                      AppTheme.glitchText('${item.name} ×${item.quantity}'),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ],
          if (state.statusEffects.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: state.statusEffects
                  .map(
                    (effect) => _MiniTag(
                      icon: Icons.auto_awesome_outlined,
                      label: '${effect.name} · ${effect.remainingTurns} 回合',
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  IconData _itemIcon(MapItemKind kind) {
    switch (kind) {
      case MapItemKind.restoreActionPoints:
        return Icons.bolt_rounded;
      case MapItemKind.moveDiscount:
        return Icons.confirmation_number_outlined;
      case MapItemKind.camp:
        return Icons.night_shelter_outlined;
      case MapItemKind.key:
        return Icons.key_outlined;
      case MapItemKind.intel:
        return Icons.map_outlined;
    }
  }
}

class _MapGraphBoard extends StatelessWidget {
  const _MapGraphBoard({
    required this.state,
    required this.selectedLocationIds,
    required this.onLocationTap,
    this.expanded = false,
  });

  final MapWorldState state;
  final Set<String> selectedLocationIds;
  final ValueChanged<String> onLocationTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final visible = state.locations
        .where((item) => item.status != MapLocationStatus.hidden)
        .toList(growable: false);
    final visibleIds = visible.map((item) => item.id).toSet();
    final visibleEdges = state.edges
        .where(
          (edge) =>
              edge.discovered &&
              visibleIds.contains(edge.fromId) &&
              visibleIds.contains(edge.toId),
        )
        .toList(growable: false);
    final reachableLocationIds = _reachableMapLocationIds(state, visibleIds);
    final cycleCount = _mapGraphCycleCount(visibleIds, visibleEdges);
    final graph = LayoutBuilder(
      builder: (context, constraints) {
        final nodeWidth = constraints.maxWidth < 460 ? 90.0 : 104.0;
        const nodeHeight = 60.0;
        final graphSize = Size(constraints.maxWidth, constraints.maxHeight);
        Offset point(MapLocationNode location) => _mapGraphPoint(
              location,
              graphSize,
              nodeWidth: nodeWidth,
              nodeHeight: nodeHeight,
            );
        return ClipRect(
          child: InteractiveViewer(
            minScale: 0.85,
            maxScale: 2.4,
            boundaryMargin: const EdgeInsets.all(36),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MapGraphPainter(
                        locations: visible,
                        edges: visibleEdges,
                        currentLocationId: state.currentLocationId,
                        reachableLocationIds: reachableLocationIds,
                        selectedLocationIds:
                            Set<String>.from(selectedLocationIds),
                        nodeWidth: nodeWidth,
                        nodeHeight: nodeHeight,
                      ),
                    ),
                  ),
                  for (final location in visible)
                    Positioned(
                      left: point(location).dx - nodeWidth / 2,
                      top: point(location).dy - nodeHeight / 2,
                      width: nodeWidth,
                      height: nodeHeight,
                      child: _MapGraphNode(
                        location: location,
                        current: location.id == state.currentLocationId,
                        reachable: reachableLocationIds.contains(location.id),
                        selected: selectedLocationIds.contains(location.id),
                        onTap: location.status == MapLocationStatus.locked
                            ? null
                            : () => onLocationTap(location.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return Container(
      key: const ValueKey<String>('map-graph-board'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassPanel(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.hub_outlined, color: AppTheme.activeSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText('无向有环图'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: Text(
                  AppTheme.glitchText(
                    '${visibleEdges.length} 条双向道路 · $cycleCount 个独立环路',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 10,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                AppTheme.glitchText('道路可双向通行'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              _MapGraphLegendItem(
                color: AppTheme.activePrimary,
                label: '当前位置',
              ),
              _MapGraphLegendItem(
                color: Theme.of(context).colorScheme.tertiary,
                label: '本回合可达',
              ),
              _MapGraphLegendItem(
                color: AppTheme.activeAccent,
                label: '已规划',
              ),
              _MapGraphLegendItem(
                color: AppTheme.textWeak,
                label: '锁定',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (expanded)
            Expanded(child: graph)
          else
            AspectRatio(
              aspectRatio: MediaQuery.sizeOf(context).width < 600 ? 1.05 : 1.8,
              child: graph,
            ),
        ],
      ),
    );
  }
}

class _MapGraphLegendItem extends StatelessWidget {
  const _MapGraphLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          AppTheme.glitchText(label),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
      ],
    );
  }
}

class _MapGraphNode extends StatelessWidget {
  const _MapGraphNode({
    required this.location,
    required this.current,
    required this.reachable,
    required this.selected,
    required this.onTap,
  });

  final MapLocationNode location;
  final bool current;
  final bool reachable;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emphasized = current || selected;
    return Material(
      color: current
          ? AppTheme.activePrimary
          : selected
              ? AppTheme.activeAccent
              : reachable
                  ? colors.tertiaryContainer
                  : AppTheme.panel,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: emphasized
                  ? AppTheme.activeSoft
                  : reachable
                      ? colors.tertiary
                      : AppTheme.activeLine,
              width: emphasized || reachable ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                current
                    ? Icons.my_location_rounded
                    : location.status == MapLocationStatus.locked
                        ? Icons.lock_outline_rounded
                        : reachable
                            ? Icons.route_rounded
                            : Icons.place_outlined,
                size: 16,
                color: emphasized
                    ? Colors.white
                    : reachable
                        ? colors.onTertiaryContainer
                        : AppTheme.textWeak,
              ),
              const SizedBox(height: 2),
              Text(
                AppTheme.glitchText(location.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: emphasized
                          ? Colors.white
                          : reachable
                              ? colors.onTertiaryContainer
                              : AppTheme.textMain,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapGraphPainter extends CustomPainter {
  _MapGraphPainter({
    required this.locations,
    required this.edges,
    required this.currentLocationId,
    required this.reachableLocationIds,
    required this.selectedLocationIds,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  final List<MapLocationNode> locations;
  final List<MapEdge> edges;
  final String currentLocationId;
  final Set<String> reachableLocationIds;
  final Set<String> selectedLocationIds;
  final double nodeWidth;
  final double nodeHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = <String, MapLocationNode>{
      for (final location in locations) location.id: location,
    };
    for (final edge in edges.where((item) => item.discovered)) {
      final from = byId[edge.fromId];
      final to = byId[edge.toId];
      if (from == null || to == null) {
        continue;
      }
      final highlighted = (from.id == currentLocationId &&
              selectedLocationIds.contains(to.id)) ||
          (to.id == currentLocationId && selectedLocationIds.contains(from.id));
      final reachable = (from.id == currentLocationId &&
              reachableLocationIds.contains(to.id)) ||
          (to.id == currentLocationId &&
              reachableLocationIds.contains(from.id));
      final paint = Paint()
        ..color = edge.blocked
            ? Colors.redAccent.withValues(alpha: 0.45)
            : highlighted
                ? AppTheme.activeSoft.withValues(alpha: 0.95)
                : reachable
                    ? AppTheme.activeAccent.withValues(alpha: 0.62)
                    : AppTheme.textWeak.withValues(alpha: 0.38)
        ..strokeWidth = highlighted
            ? 3
            : reachable
                ? 2.2
                : edge.actionPointCost == 2
                    ? 2.2
                    : 1.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final start = _mapGraphPoint(
        from,
        size,
        nodeWidth: nodeWidth,
        nodeHeight: nodeHeight,
      );
      final end = _mapGraphPoint(
        to,
        size,
        nodeWidth: nodeWidth,
        nodeHeight: nodeHeight,
      );
      canvas.drawLine(start, end, paint);
      final middle = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final label = TextPainter(
        text: TextSpan(
          text: '${edge.actionPointCost} AP',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 9,
            backgroundColor: AppTheme.panel.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, middle - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _MapGraphPainter oldDelegate) =>
      oldDelegate.currentLocationId != currentLocationId ||
      oldDelegate.reachableLocationIds != reachableLocationIds ||
      oldDelegate.selectedLocationIds != selectedLocationIds ||
      oldDelegate.edges != edges ||
      oldDelegate.locations != locations ||
      oldDelegate.nodeWidth != nodeWidth ||
      oldDelegate.nodeHeight != nodeHeight;
}

Offset _mapGraphPoint(
  MapLocationNode location,
  Size size, {
  required double nodeWidth,
  required double nodeHeight,
}) {
  final horizontalInset = min(nodeWidth / 2 + 8, size.width / 2);
  final verticalInset = min(nodeHeight / 2 + 8, size.height / 2);
  final normalizedX = ((location.x - 0.05) / 0.9).clamp(0.0, 1.0);
  final normalizedY = ((location.y - 0.05) / 0.9).clamp(0.0, 1.0);
  return Offset(
    horizontalInset + normalizedX * max(0, size.width - horizontalInset * 2),
    verticalInset + normalizedY * max(0, size.height - verticalInset * 2),
  );
}

Set<String> _reachableMapLocationIds(
  MapWorldState state,
  Set<String> visibleLocationIds,
) {
  final start = state.currentLocationId.trim();
  if (start.isEmpty || !visibleLocationIds.contains(start)) {
    return <String>{};
  }
  final lockedIds = state.locations
      .where((location) => location.status == MapLocationStatus.locked)
      .map((location) => location.id)
      .toSet();
  final availableItemIds = state.mapInventory
      .where((item) => item.quantity > 0)
      .map((item) => item.id)
      .toSet();
  final distances = <String, int>{start: 0};
  final visited = <String>{};
  while (true) {
    String? closest;
    var closestDistance = state.currentActionPoints + 1;
    for (final entry in distances.entries) {
      if (!visited.contains(entry.key) && entry.value < closestDistance) {
        closest = entry.key;
        closestDistance = entry.value;
      }
    }
    if (closest == null || closestDistance > state.currentActionPoints) {
      break;
    }
    visited.add(closest);
    for (final edge in state.edges) {
      if (!edge.discovered ||
          edge.blocked ||
          (edge.requiredItemId.trim().isNotEmpty &&
              !availableItemIds.contains(edge.requiredItemId.trim()))) {
        continue;
      }
      final other = edge.other(closest);
      if (other == null ||
          !visibleLocationIds.contains(other) ||
          lockedIds.contains(other)) {
        continue;
      }
      final nextDistance = closestDistance + edge.actionPointCost;
      if (nextDistance <= state.currentActionPoints &&
          nextDistance < (distances[other] ?? 1 << 20)) {
        distances[other] = nextDistance;
      }
    }
  }
  return distances.keys.where((id) => id != start).toSet();
}

int _mapGraphCycleCount(Set<String> locationIds, List<MapEdge> edges) {
  if (locationIds.isEmpty) {
    return 0;
  }
  final neighbors = <String, Set<String>>{
    for (final id in locationIds) id: <String>{},
  };
  for (final edge in edges) {
    neighbors[edge.fromId]?.add(edge.toId);
    neighbors[edge.toId]?.add(edge.fromId);
  }
  var components = 0;
  final visited = <String>{};
  for (final id in locationIds) {
    if (!visited.add(id)) {
      continue;
    }
    components++;
    final pending = <String>[id];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final neighbor in neighbors[current] ?? const <String>{}) {
        if (visited.add(neighbor)) {
          pending.add(neighbor);
        }
      }
    }
  }
  return max(0, edges.length - locationIds.length + components);
}

class _RoutePreviewSheet extends StatelessWidget {
  const _RoutePreviewSheet({
    required this.location,
    required this.currentActionPoints,
    required this.cheapest,
    required this.safest,
    required this.fastest,
  });

  final MapLocationNode location;
  final int currentActionPoints;
  final MapRouteResult cheapest;
  final MapRouteResult safest;
  final MapRouteResult fastest;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTheme.glitchText('前往 ${location.name}'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              AppTheme.glitchText('当前行动力：$currentActionPoints AP'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(height: 14),
            _RouteOptionTile(
              icon: Icons.bolt_outlined,
              title: '最省行动力',
              route: cheapest,
              currentActionPoints: currentActionPoints,
              onTap: () => Navigator.of(context).pop(
                MapRouteMode.leastActionPoints,
              ),
            ),
            const SizedBox(height: 8),
            _RouteOptionTile(
              icon: Icons.shield_outlined,
              title: '最低风险',
              route: safest,
              currentActionPoints: currentActionPoints,
              onTap: () => Navigator.of(context).pop(MapRouteMode.safest),
            ),
            const SizedBox(height: 8),
            _RouteOptionTile(
              icon: Icons.schedule_outlined,
              title: '最少时间',
              route: fastest,
              currentActionPoints: currentActionPoints,
              onTap: () => Navigator.of(context).pop(MapRouteMode.fastest),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteOptionTile extends StatelessWidget {
  const _RouteOptionTile({
    required this.icon,
    required this.title,
    required this.route,
    required this.currentActionPoints,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final MapRouteResult route;
  final int currentActionPoints;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reachable = route.isReachable;
    final enough = route.totalActionPointCost <= currentActionPoints;
    final highestRisk = route.edges.fold<int>(
      0,
      (value, edge) => max(value, _routeRisk(edge.riskLevel)),
    );
    final riskText = switch (highestRisk) { 3 => '高', 2 => '中', _ => '低' };
    return ListTile(
      enabled: reachable,
      onTap: reachable ? onTap : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.activeLine),
      ),
      leading: Icon(icon),
      title: Text(AppTheme.glitchText(title)),
      subtitle: Text(
        AppTheme.glitchText(
          reachable
              ? '${route.edges.length} 段道路 · ${route.totalActionPointCost} AP · $riskText风险${enough ? '' : ' · 本回合只能部分抵达'}'
              : route.blockedReason,
        ),
      ),
      trailing: reachable ? const Icon(Icons.add_road_rounded) : null,
    );
  }

  int _routeRisk(String value) {
    if (value.contains('高')) {
      return 3;
    }
    if (value.contains('中')) {
      return 2;
    }
    return 1;
  }
}

class _MapCompassPanel extends StatelessWidget {
  const _MapCompassPanel({
    required this.state,
    required this.isBusy,
    required this.onChoice,
    required this.onFreeAction,
  });

  final MapWorldState state;
  final bool isBusy;
  final ValueChanged<MapStoryChoice> onChoice;
  final ValueChanged<String> onFreeAction;

  @override
  Widget build(BuildContext context) {
    final recommended =
        state.activeChoices.isEmpty ? null : state.activeChoices.first;
    final optionalChoices = state.activeChoices
        .skip(recommended == null ? 0 : 1)
        .take(3)
        .toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.explore_outlined, color: AppTheme.activeSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText('主线罗盘'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (state.title.trim().isNotEmpty)
                _StatusChip(
                  icon: Icons.public_rounded,
                  text: state.title.trim(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final width = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  SizedBox(
                    width: width,
                    child: _CompassItem(
                      icon: Icons.flag_outlined,
                      label: '当前阶段',
                      value: state.stage.trim().isEmpty
                          ? '阶段未定'
                          : state.stage.trim(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _CompassItem(
                      icon: Icons.track_changes_rounded,
                      label: '当前目标',
                      value: state.mainGoal.trim().isEmpty
                          ? '等待主线目标'
                          : state.mainGoal.trim(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _CompassItem(
                      icon: Icons.schedule_rounded,
                      label: '当前时间',
                      value: state.timeLabel.trim().isEmpty
                          ? '时间未定'
                          : state.timeLabel.trim(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _CompassItem(
                      icon: Icons.place_outlined,
                      label: '当前位置',
                      value: state.currentLocationName.trim().isEmpty
                          ? '尚未进入地点'
                          : state.currentLocationName.trim(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (recommended != null) ...<Widget>[
            Text(
              AppTheme.glitchText('推荐下一步'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.activeSoft,
                  ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: isBusy ? null : () => onChoice(recommended),
              icon: Icon(_choiceIcon(recommended.kind), size: 18),
              label: Text(AppTheme.glitchText(recommended.label)),
            ),
            if (recommended.riskLevel.trim().isNotEmpty ||
                recommended.timeCost.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (recommended.riskLevel.trim().isNotEmpty)
                    _MiniTag(
                      icon: Icons.warning_amber_rounded,
                      label: '风险：${recommended.riskLevel.trim()}',
                    ),
                  if (recommended.timeCost.trim().isNotEmpty)
                    _MiniTag(
                      icon: Icons.hourglass_bottom_rounded,
                      label: '耗时：${recommended.timeCost.trim()}',
                    ),
                ],
              ),
            ],
            if (optionalChoices.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: optionalChoices
                    .map(
                      (choice) => OutlinedButton.icon(
                        onPressed: isBusy ? null : () => onChoice(choice),
                        icon: Icon(_choiceIcon(choice.kind), size: 17),
                        label: Text(AppTheme.glitchText(choice.label)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ] else ...<Widget>[
            Text(
              AppTheme.glitchText('还没有推荐行动，可以先从地点或自由行动开始。'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onFreeAction('调查当前地点'),
                  icon: const Icon(Icons.search_rounded),
                  label: Text(AppTheme.glitchText('调查当前地点')),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onFreeAction('寻找附近的NPC'),
                  icon: const Icon(Icons.people_outline_rounded),
                  label: Text(AppTheme.glitchText('寻找 NPC')),
                ),
              ],
            ),
          ],
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

class _CompassItem extends StatelessWidget {
  const _CompassItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppTheme.activeSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText(label),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textWeak,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTheme.glitchText(value),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMain,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
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

class _CurrentLocationStatusPanel extends StatelessWidget {
  const _CurrentLocationStatusPanel({required this.state});

  final MapWorldState state;

  @override
  Widget build(BuildContext context) {
    final location = state.currentLocation;
    final locationName = (location?.name.trim().isNotEmpty == true
            ? location!.name
            : state.currentLocationName)
        .trim();
    if (locationName.isEmpty && location == null) {
      return const SizedBox.shrink();
    }
    final description = location?.description.trim() ?? '';
    final scene = location?.scene.trim() ?? '';
    final npcs = <String>{
      if (location != null) ...location.npcs,
      ...state.npcPositions
          .where((npc) => _sameLocation(npc, location, locationName))
          .map((npc) => npc.name),
    }.where((item) => item.trim().isNotEmpty).toList(growable: false);
    final clues = location?.clues ?? const <String>[];
    final nextActions = location?.nextActions ?? const <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _locationStatusIcon(location?.status),
                color: AppTheme.activeSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText(
                      locationName.isEmpty ? '当前地点' : locationName),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusChip(
                icon: _locationStatusIcon(location?.status),
                text: _locationStatusLabel(location?.status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (description.isNotEmpty || scene.isNotEmpty)
            Text(
              AppTheme.glitchText(
                scene.isNotEmpty ? scene : description,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if ((location?.riskLevel.trim().isNotEmpty ?? false))
                _MiniTag(
                  icon: Icons.warning_amber_rounded,
                  label: '风险：${location!.riskLevel.trim()}',
                ),
              if ((location?.timeCost.trim().isNotEmpty ?? false))
                _MiniTag(
                  icon: Icons.hourglass_bottom_rounded,
                  label: '耗时：${location!.timeCost.trim()}',
                ),
              if (npcs.isNotEmpty)
                _MiniTag(
                  icon: Icons.people_alt_outlined,
                  label: 'NPC：${npcs.take(3).join('、')}',
                ),
              if (clues.isNotEmpty)
                _MiniTag(
                  icon: Icons.manage_search_rounded,
                  label: '线索：${clues.length} 条',
                ),
            ],
          ),
          if (nextActions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              AppTheme.glitchText('地点可做'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.activeSoft,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: nextActions
                  .take(5)
                  .map(
                    (action) => _MiniTag(
                      icon: Icons.bolt_outlined,
                      label: action,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  static bool _sameLocation(
    MapNpcPosition npc,
    MapLocationNode? location,
    String locationName,
  ) {
    if (location != null && npc.locationId.trim() == location.id) {
      return true;
    }
    final npcLocation = npc.locationName.trim();
    return npcLocation.isNotEmpty &&
        locationName.isNotEmpty &&
        npcLocation == locationName;
  }
}

IconData _locationStatusIcon(MapLocationStatus? status) {
  switch (status) {
    case MapLocationStatus.locked:
      return Icons.lock_outline_rounded;
    case MapLocationStatus.available:
      return Icons.place_outlined;
    case MapLocationStatus.current:
      return Icons.my_location_rounded;
    case MapLocationStatus.explored:
      return Icons.check_circle_outline_rounded;
    case MapLocationStatus.hidden:
      return Icons.help_outline_rounded;
    case null:
      return Icons.place_outlined;
  }
}

String _locationStatusLabel(MapLocationStatus? status) {
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
    case null:
      return '地点状态';
  }
}

class _NpcPositionPanel extends StatelessWidget {
  const _NpcPositionPanel({required this.state});

  final MapWorldState state;

  @override
  Widget build(BuildContext context) {
    final positions = state.npcPositions.take(12).toList(growable: false);
    if (positions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.people_alt_outlined, color: AppTheme.activeSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText('NPC 位置'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                AppTheme.glitchText('${positions.length} 人有动向'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textWeak,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final width = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: positions
                    .map(
                      (npc) => SizedBox(
                        width: width,
                        child: _NpcPositionTile(
                          npc: npc,
                          currentLocationId: state.currentLocationId,
                          currentLocationName: state.currentLocationName,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NpcPositionTile extends StatelessWidget {
  const _NpcPositionTile({
    required this.npc,
    required this.currentLocationId,
    required this.currentLocationName,
  });

  final MapNpcPosition npc;
  final String currentLocationId;
  final String currentLocationName;

  @override
  Widget build(BuildContext context) {
    final location = npc.locationName.trim().isNotEmpty
        ? npc.locationName.trim()
        : npc.locationId.trim();
    final samePlace = (npc.locationId.trim().isNotEmpty &&
            npc.locationId.trim() == currentLocationId.trim()) ||
        (npc.locationName.trim().isNotEmpty &&
            npc.locationName.trim() == currentLocationName.trim());
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: samePlace
            ? AppTheme.activePrimary.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: samePlace
              ? AppTheme.activeSoft.withValues(alpha: 0.45)
              : AppTheme.activeLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                samePlace ? Icons.person_pin_circle_outlined : Icons.person_pin,
                size: 18,
                color: AppTheme.activeSoft,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  AppTheme.glitchText(npc.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _MiniTag(
                icon: Icons.place_outlined,
                label: location.isEmpty ? '位置未知' : location,
              ),
              if (samePlace)
                const _MiniTag(
                  icon: Icons.my_location_rounded,
                  label: '同处一地',
                ),
              if (npc.status.trim().isNotEmpty)
                _MiniTag(
                  icon: Icons.info_outline_rounded,
                  label: npc.status.trim(),
                ),
              if (npc.lastSeen.trim().isNotEmpty)
                _MiniTag(
                  icon: Icons.schedule_rounded,
                  label: npc.lastSeen.trim(),
                ),
            ],
          ),
          if (npc.intent.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText(npc.intent.trim()),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppTheme.activeSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppTheme.glitchText(text),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentScenePanel extends StatelessWidget {
  const _CurrentScenePanel({
    required this.state,
    required this.isBusy,
    required this.onChoice,
    required this.onFreeAction,
    required this.onEnterChat,
  });

  final MapWorldState state;
  final bool isBusy;
  final ValueChanged<MapStoryChoice> onChoice;
  final ValueChanged<String> onFreeAction;
  final VoidCallback onEnterChat;

  @override
  Widget build(BuildContext context) {
    final scene = state.activeScene.trim();
    final choices = state.activeChoices;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassPanel(highlighted: true, radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.auto_stories_outlined, color: AppTheme.activeSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText('当前主线'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onEnterChat,
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: Text(AppTheme.glitchText('带入聊天')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.stage.trim().isNotEmpty || state.mainGoal.trim().isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (state.stage.trim().isNotEmpty)
                  _InfoPill(
                    icon: Icons.flag_outlined,
                    text: state.stage.trim(),
                  ),
                if (state.mainGoal.trim().isNotEmpty)
                  _InfoPill(
                    icon: Icons.track_changes_rounded,
                    text: state.mainGoal.trim(),
                  ),
              ],
            ),
          if (state.stage.trim().isNotEmpty || state.mainGoal.trim().isNotEmpty)
            const SizedBox(height: 12),
          Text(
            AppTheme.glitchText(
              scene.isEmpty ? '主线已经准备好。点一个地点或在下方输入行动，让地图开始动起来。' : scene,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                  color: AppTheme.textMain,
                ),
          ),
          const SizedBox(height: 14),
          if (choices.isNotEmpty) ...<Widget>[
            Text(
              AppTheme.glitchText('下一步'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.activeSoft,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: choices
                  .map(
                    (choice) => FilledButton.tonalIcon(
                      onPressed: isBusy ? null : () => onChoice(choice),
                      icon: Icon(_choiceIcon(choice.kind), size: 18),
                      label: Text(AppTheme.glitchText(choice.label)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ] else ...<Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onFreeAction('调查当前地点'),
                  icon: const Icon(Icons.search_rounded),
                  label: Text(AppTheme.glitchText('调查当前地点')),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onFreeAction('寻找附近的NPC'),
                  icon: const Icon(Icons.people_outline_rounded),
                  label: Text(AppTheme.glitchText('寻找 NPC')),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onFreeAction('梳理当前线索'),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: Text(AppTheme.glitchText('梳理线索')),
                ),
              ],
            ),
          ],
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppTheme.activeSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppTheme.glitchText(text),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard({
    required this.state,
    required this.onAction,
  });

  final MapWorldState state;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final html = state.activeHtml.trim();
    if (html.isEmpty) {
      return const SizedBox.shrink();
    }
    final height = MediaQuery.sizeOf(context).height * 0.58;
    final resolvedHeight = height.clamp(360.0, 720.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassPanel(radius: 26),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppTheme.glitchText('交互地图'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showFullscreen(context, html),
                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                label: Text(AppTheme.glitchText('全屏阅读')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: resolvedHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: RunnableCodePreview(
                    document: _ensureHtmlDocument(html),
                    height: resolvedHeight,
                    onAction: onAction,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.activeLine),
                  ),
                  child: Icon(
                    Icons.swipe_vertical_rounded,
                    size: 16,
                    color: AppTheme.textWeak,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullscreen(BuildContext context, String html) async {
    final document = _ensureHtmlDocument(html);
    await showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AppTheme.panel,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        AppTheme.glitchText('地图全屏阅读'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: AppTheme.glitchText('关闭'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: RunnableCodePreview(
                    document: document,
                    height: MediaQuery.sizeOf(context).height * 0.88,
                    onAction: onAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ensureHtmlDocument(String html) {
    if (RegExp(r'<!doctype|<html\b', caseSensitive: false).hasMatch(html)) {
      return html;
    }
    return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body { margin: 0; padding: 0; min-height: 100%; background: transparent; }
    body { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; }
  </style>
</head>
<body>
$html
</body>
</html>
''';
  }
}

class _LocationBoard extends StatelessWidget {
  const _LocationBoard({
    required this.state,
    required this.selectedLocationIds,
    required this.onToggle,
    required this.onOpen,
  });

  final MapWorldState state;
  final Set<String> selectedLocationIds;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (state.locations.isEmpty) {
      return const SizedBox.shrink();
    }
    final currentId = state.currentLocationId.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTheme.glitchText('地点棋盘'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: state.locations.map((location) {
                  final selected = selectedLocationIds.contains(location.id);
                  final current = location.id == currentId ||
                      location.status == MapLocationStatus.current;
                  final locked = location.status == MapLocationStatus.locked;
                  final hidden = location.status == MapLocationStatus.hidden;
                  final width = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 10) / 2;
                  final route = state.isRulesDriven && !current
                      ? context
                          .read<AppStateController>()
                          .mapRouteTo(location.id)
                      : null;
                  return SizedBox(
                    width: width,
                    child: _LocationTile(
                      location: location,
                      selected: selected,
                      current: current,
                      locked: locked,
                      hidden: hidden,
                      travelCost: route?.isReachable == true
                          ? route!.totalActionPointCost
                          : null,
                      currentActionPoints: state.currentActionPoints,
                      onOpen:
                          hidden || locked ? null : () => onOpen(location.id),
                      onPlan:
                          hidden || locked ? null : () => onToggle(location.id),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.selected,
    required this.current,
    required this.locked,
    required this.hidden,
    required this.travelCost,
    required this.currentActionPoints,
    required this.onOpen,
    required this.onPlan,
  });

  final MapLocationNode location;
  final bool selected;
  final bool current;
  final bool locked;
  final bool hidden;
  final int? travelCost;
  final int currentActionPoints;
  final VoidCallback? onOpen;
  final VoidCallback? onPlan;

  @override
  Widget build(BuildContext context) {
    final description = location.description.trim();
    final chips = <Widget>[
      _MiniTag(
        icon: _statusIcon,
        label: _statusLabel,
      ),
      if (location.npcs.isNotEmpty)
        _MiniTag(
          icon: Icons.people_alt_outlined,
          label: location.npcs.take(2).join('、'),
        ),
      if (location.clues.isNotEmpty)
        _MiniTag(
          icon: Icons.search_rounded,
          label: '${location.clues.length} 条线索',
        ),
      if (!current && travelCost != null)
        _MiniTag(
          icon: Icons.bolt_outlined,
          label:
              '$travelCost AP${travelCost! > currentActionPoints ? ' · 跨回合' : ''}',
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: current
            ? AppTheme.activePrimary.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: selected ? 0.09 : 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: current
              ? AppTheme.activeSoft.withValues(alpha: 0.5)
              : selected
                  ? AppTheme.activePrimary.withValues(alpha: 0.45)
                  : AppTheme.activeLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_statusIcon, size: 20, color: AppTheme.activeSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText(hidden ? '未知地点' : location.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty && !hidden) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText(description),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.near_me_outlined, size: 17),
                  label: Text(
                    AppTheme.glitchText(current ? '当前' : '查看路线'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                style: AppTheme.skinIconButtonStyle(),
                tooltip: AppTheme.glitchText(
                  selected ? '移出计划' : '加入下一回合计划',
                ),
                onPressed: onPlan,
                icon: Icon(
                  selected
                      ? Icons.playlist_remove_rounded
                      : Icons.playlist_add_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    if (hidden) {
      return Icons.help_outline_rounded;
    }
    if (current) {
      return Icons.my_location_rounded;
    }
    switch (location.status) {
      case MapLocationStatus.locked:
        return Icons.lock_outline_rounded;
      case MapLocationStatus.available:
        return Icons.place_outlined;
      case MapLocationStatus.current:
        return Icons.my_location_rounded;
      case MapLocationStatus.explored:
        return Icons.check_circle_outline_rounded;
      case MapLocationStatus.hidden:
        return Icons.help_outline_rounded;
    }
  }

  String get _statusLabel {
    if (hidden) {
      return '隐藏';
    }
    if (current) {
      return '当前位置';
    }
    switch (location.status) {
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

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
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
              AppTheme.glitchText(label),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBasketPanel extends StatelessWidget {
  const _ActionBasketPanel({
    required this.state,
    required this.selectedLocationIds,
    required this.queuedActions,
    required this.routeMode,
    required this.onRemoveLocation,
    required this.onRemoveAction,
    required this.onClear,
  });

  final MapWorldState state;
  final Set<String> selectedLocationIds;
  final List<String> queuedActions;
  final MapRouteMode routeMode;
  final ValueChanged<String> onRemoveLocation;
  final ValueChanged<String> onRemoveAction;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final selectedLocations = state.locations
        .where((location) => selectedLocationIds.contains(location.id))
        .toList(growable: false);
    final hasPlan = selectedLocations.isNotEmpty || queuedActions.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppTheme.glitchText('下一回合计划'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (hasPlan)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(AppTheme.glitchText('重置')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasPlan)
            Text(
              AppTheme.glitchText(
                '点击地图里的按钮、勾选地点，或者在底部输入行动，都会先放进这里。最后点“下一回合”统一结算。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final location in selectedLocations)
                  InputChip(
                    avatar: const Icon(Icons.place_outlined, size: 16),
                    label: Text(
                      AppTheme.glitchText(
                        state.isRulesDriven
                            ? '${location.name} · ${context.read<AppStateController>().mapRouteTo(location.id, mode: routeMode).totalActionPointCost} AP · ${_routeModeLabel(routeMode)}'
                            : location.name,
                      ),
                    ),
                    onDeleted: () => onRemoveLocation(location.id),
                  ),
                for (final action in queuedActions)
                  InputChip(
                    avatar: const Icon(Icons.bolt_outlined, size: 16),
                    label: Text(AppTheme.glitchText(action)),
                    onDeleted: () => onRemoveAction(action),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _routeModeLabel(MapRouteMode mode) => switch (mode) {
        MapRouteMode.leastActionPoints => '省 AP',
        MapRouteMode.safest => '低风险',
        MapRouteMode.fastest => '少时间',
      };
}

class _TimeAdvancePanel extends StatelessWidget {
  const _TimeAdvancePanel({
    required this.planCount,
    required this.isBusy,
    required this.rulesDriven,
    required this.onAdvance,
    required this.onReset,
  });

  final int planCount;
  final bool isBusy;
  final bool rulesDriven;
  final ValueChanged<String> onAdvance;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    const steps = <String>['下一回合', '下一小时', '下一阶段', '下一天', '下个关键事件'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppTheme.glitchText('时间推进'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (planCount > 0)
                Text(
                  AppTheme.glitchText('已规划 $planCount 项'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppTheme.glitchText(
              rulesDriven
                  ? '本地引擎先执行路线与行动；行动力不足时会停在最后一个可达地点。NPC、事件和危机时钟推进后，再由 AI 续写本回合叙事。'
                  : '只点“下一回合”时，AI 会自己决定过去多久；点“下一天”等明确按钮时，会尽量在该时间范围内完成你放进计划里的事项。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps
                .map(
                  (step) => step == '下一回合'
                      ? FilledButton.icon(
                          onPressed: isBusy ? null : () => onAdvance(step),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(AppTheme.glitchText(step)),
                        )
                      : OutlinedButton(
                          onPressed: isBusy ? null : () => onAdvance(step),
                          child: Text(AppTheme.glitchText(step)),
                        ),
                )
                .toList(growable: false),
          ),
          if (onReset != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.clear_all_rounded),
              label: Text(AppTheme.glitchText('清空当前计划')),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapIntelPanel extends StatelessWidget {
  const _MapIntelPanel({required this.state});

  final MapWorldState state;

  @override
  Widget build(BuildContext context) {
    final clues = state.discoveredClues.take(8).toList(growable: false);
    final movements = state.npcMovements.take(8).toList(growable: false);
    if (clues.isEmpty && movements.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(radius: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final children = <Widget>[
            if (clues.isNotEmpty)
              _IntelColumn(
                icon: Icons.manage_search_rounded,
                title: '已发现线索',
                items: clues,
              ),
            if (movements.isNotEmpty)
              _IntelColumn(
                icon: Icons.people_alt_outlined,
                title: 'NPC 动向',
                items: movements,
              ),
          ];
          if (compact || children.length == 1) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children
                  .expand(
                      (child) => <Widget>[child, const SizedBox(height: 12)])
                  .toList()
                ..removeLast(),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: children[0]),
              const SizedBox(width: 14),
              Expanded(child: children[1]),
            ],
          );
        },
      ),
    );
  }
}

class _IntelColumn extends StatelessWidget {
  const _IntelColumn({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, color: AppTheme.activeSoft, size: 18),
            const SizedBox(width: 6),
            Text(
              AppTheme.glitchText(title),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
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
                          height: 1.35,
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

class _MapHtmlToggleCard extends StatelessWidget {
  const _MapHtmlToggleCard({
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassPanel(radius: 24),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.web_asset_outlined, color: AppTheme.activeSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText('交互地图视图'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                label: Text(AppTheme.glitchText(expanded ? '收起' : '展开')),
              ),
            ],
          ),
          if (!expanded)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppTheme.glitchText('这里保留 AI 生成的 HTML 地图。主线阅读和推进已经放到上面的剧情面板里。'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ),
          if (expanded && child != null) ...<Widget>[
            const SizedBox(height: 10),
            child!,
          ],
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LegacyTimeAdvancePanel extends StatelessWidget {
  const _LegacyTimeAdvancePanel({required this.onAdvance});

  final ValueChanged<String> onAdvance;

  @override
  Widget build(BuildContext context) {
    const steps = <String>['下一小时', '下一阶段', '下一天', '下个关键事件'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTheme.glitchText('时间推进'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: steps
                .map(
                  (step) => OutlinedButton(
                    onPressed: () => onAdvance(step),
                    child: Text(AppTheme.glitchText(step)),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _EventLogPanel extends StatelessWidget {
  const _EventLogPanel({required this.state});

  final MapWorldState state;

  @override
  Widget build(BuildContext context) {
    final logs = state.eventLog.take(6).toList(growable: false);
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassPanel(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTheme.glitchText('近期地图事件'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...logs.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppTheme.glitchText(log),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapActionBar extends StatelessWidget {
  const _MapActionBar({
    required this.controller,
    required this.isBusy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassPanel(highlighted: true, radius: 28),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppTheme.glitchText('在当前位置做点什么...'),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isBusy ? null : onSubmit,
            style: AppTheme.skinFilledIconButtonStyle(),
            child: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _MapLoadingOverlay extends StatelessWidget {
  const _MapLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: AppTheme.glassPanel(highlighted: true, radius: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(AppTheme.glitchText('地图引擎生成中...')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
