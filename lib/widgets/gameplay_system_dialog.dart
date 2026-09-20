import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/character_profile.dart';
import '../models/gameplay_system.dart';
import 'gameplay_author_dialog.dart';
import 'gameplay_system_readout.dart';
import 'gameplay_history_dialog.dart';

class GameplaySystemDialog extends StatefulWidget {
  const GameplaySystemDialog({super.key, required this.characterId});
  final String characterId;

  @override
  State<GameplaySystemDialog> createState() => _GameplaySystemDialogState();
}

class _GameplaySystemDialogState extends State<GameplaySystemDialog> {
  bool _backstage = false;
  bool _spoilersAccepted = false;
  bool _busy = false;
  bool _loadingState = true;
  bool _startedLoading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startedLoading) {
      _startedLoading = true;
      _loadState();
    }
  }

  Future<void> _loadState() async {
    try {
      await context
          .read<AppStateController>()
          .gameplayHistoryContextFor(widget.characterId);
    } catch (error) {
      if (mounted) _error = '读取玩法状态失败：$error';
    } finally {
      if (mounted) setState(() => _loadingState = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    CharacterProfile? character;
    for (final item in controller.characters) {
      if (item.id == widget.characterId) character = item;
    }
    final system = character?.gameplaySystem;
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        title: const Text('玩法系统'),
        content: SizedBox(
          width: math.min(760, math.max(260, size.width - 76)),
          height: math.min(720, math.max(240, size.height - 220)),
          child: character == null
              ? const Center(child: Text('剧场已经不存在。'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ),
                    if (system == null)
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                const Icon(Icons.account_tree_outlined,
                                    size: 48),
                                const SizedBox(height: 16),
                                Text(character.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                const Text(
                                    '让行动留下代价、机会和后续剧情。先生成一份玩法草稿，检查或预演后再应用。',
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Text(system.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (system.summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(system.summary,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                                value: false,
                                label: Text('玩家面板'),
                                icon: Icon(Icons.visibility_outlined)),
                            ButtonSegment(
                                value: true,
                                label: Text('作者幕后'),
                                icon: Icon(Icons.theater_comedy_outlined)),
                          ],
                          selected: {_backstage},
                          showSelectedIcon: false,
                          onSelectionChanged: _busy
                              ? null
                              : (selection) => _selectView(selection.first),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _loadingState
                            ? const Center(child: CircularProgressIndicator())
                            : SingleChildScrollView(
                                child: GameplaySystemReadout(
                                  system: system,
                                  state: controller
                                      .gameplayStateFor(widget.characterId),
                                  backstage: _backstage,
                                  onVariableTap: _busy
                                      ? null
                                      : (variable) =>
                                          _openHistory(system, variable),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('关闭')),
          if (system != null && _backstage)
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => _openDraft(system, regenerate: false),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑与预演'),
            ),
          FilledButton.icon(
            onPressed: _busy || character == null
                ? null
                : () => _openDraft(system, regenerate: true),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(_busy
                ? '正在准备草稿'
                : system == null
                    ? '生成玩法草稿'
                    : '重新设计'),
          ),
        ],
      ),
    );
  }

  Future<void> _openHistory(
      GameplaySystem system, GameplayVariableDefinition variable) async {
    final controller = context.read<AppStateController>();
    setState(() => _busy = true);
    try {
      final data =
          await controller.gameplayHistoryContextFor(widget.characterId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => GameplayHistoryDialog(
          system: system,
          state: data.state,
          messages: data.history.messages,
          path: variable.key,
          storyName: controller.characterNameFor(widget.characterId),
          backstage: _backstage,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '读取变化记录失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _acceptSpoilers() async {
    if (_spoilersAccepted) return true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('进入作者视角'),
        content: const Text('这里会展示隐藏变量、尚未揭晓的条件和剧情后果。编辑与预演也会用到这些内容，可能提前揭晓悬念。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('留在玩家视角')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('查看幕后')),
        ],
      ),
    );
    if (!mounted) return false;
    if (accepted == true) _spoilersAccepted = true;
    return accepted == true;
  }

  Future<void> _selectView(bool backstage) async {
    if (backstage && !await _acceptSpoilers()) return;
    if (mounted) setState(() => _backstage = backstage);
  }

  Future<void> _openDraft(GameplaySystem? current,
      {required bool regenerate}) async {
    if (!await _acceptSpoilers() || !mounted) return;
    final controller = context.read<AppStateController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final generated = regenerate
          ? await controller.previewGameplaySystem(widget.characterId)
          : current!;
      if (!mounted) return;
      setState(() => _busy = false);
      final draft = await showDialog<GameplaySystem>(
        context: context,
        barrierDismissible: false,
        builder: (context) => GameplayAuthorDialog(
          current: current,
          generated: generated,
          state: controller.gameplayStateFor(widget.characterId),
          onRegenerate: () =>
              controller.previewGameplaySystem(widget.characterId),
        ),
      );
      if (draft == null || !mounted) return;
      setState(() => _busy = true);
      await controller.applyGameplaySystem(widget.characterId, draft);
      if (mounted) setState(() => _backstage = false);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
