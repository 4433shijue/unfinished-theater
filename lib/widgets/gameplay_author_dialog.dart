import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/gameplay_system.dart';
import '../services/gameplay_system_draft.dart';
import '../services/gameplay_system_parser.dart';
import 'gameplay_draft_editors.dart';
import 'gameplay_rehearsal_dialog.dart';

class GameplayAuthorDialog extends StatefulWidget {
  const GameplayAuthorDialog({
    super.key,
    required this.current,
    required this.generated,
    required this.state,
    this.onRegenerate,
  });
  final GameplaySystem? current;
  final GameplaySystem generated;
  final GameStateSnapshot state;
  final Future<GameplaySystem> Function()? onRegenerate;

  @override
  State<GameplayAuthorDialog> createState() => _GameplayAuthorDialogState();
}

class _GameplayAuthorDialogState extends State<GameplayAuthorDialog> {
  late GameplaySystem _working = widget.generated;
  late GameplaySystemDraft _review = GameplaySystemDraft.preview(
    current: widget.current ?? widget.generated,
    generated: widget.generated,
  );
  final Set<String> _lockedGroups = {};
  bool _busy = false;
  bool _invalidMerge = false;
  String? _error;

  void _refreshReview() {
    try {
      _review = GameplaySystemDraft.merge(
        current: widget.current ?? _working,
        generated: _working,
        lockedGroups: _lockedGroups,
      );
      _error = null;
      _invalidMerge = false;
    } catch (error) {
      _error = error.toString();
      _invalidMerge = true;
    }
  }

  void _update(Map<String, dynamic> json) {
    try {
      final next = GameplaySystemParser.parse(jsonEncode(json));
      setState(() {
        _working = next;
        _refreshReview();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final effective = _review.system;
    final groups = effective.variables.map((item) => item.group).toSet();
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        title: const Text('玩法草稿 · 作者工作台'),
        content: SizedBox(
          width: math.min(800, math.max(260, size.width - 76)),
          height: math.min(760, math.max(240, size.height - 200)),
          child: ListView(
            children: [
              const Text('检查行动、代价与后果。这里的修改和预演都留在草稿，应用后才更新这座剧场。'),
              const SizedBox(height: 14),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(effective.title),
                subtitle: Text(effective.coreLoop),
                trailing: IconButton(
                    tooltip: '编辑玩法概述',
                    onPressed: _busy ? null : _editOverview,
                    icon: const Icon(Icons.edit_outlined)),
              ),
              if (widget.current != null)
                ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  title: const Text('保留哪些原有玩法'),
                  subtitle: const Text('勾选后保留该组原有变量和关联规则，其余采用当前草稿。'),
                  children: [
                    for (final group in widget.current!.variables
                        .map((item) => item.group)
                        .toSet())
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(group),
                        value: _lockedGroups.contains(group),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                  if (value == true) {
                                    _lockedGroups.add(group);
                                  } else {
                                    _lockedGroups.remove(group);
                                  }
                                  _refreshReview();
                                }),
                      ),
                  ],
                ),
              for (final group in groups)
                ExpansionTile(
                  key: ValueKey('draft-group-$group'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(group),
                  subtitle: _lockedGroups.contains(group)
                      ? const Text('已锁定原有玩法；取消勾选后可编辑新草稿')
                      : null,
                  children: [
                    for (final variable in effective.variables
                        .where((item) => item.group == group))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(variable.label),
                        subtitle: Text(variable.playerHint.isNotEmpty
                            ? variable.playerHint
                            : variable.description),
                        trailing: IconButton(
                          tooltip: '编辑${variable.label}',
                          onPressed: _busy || _lockedGroups.contains(group)
                              ? null
                              : () async {
                                  final edited = await editGameplayVariable(
                                      context, variable);
                                  if (edited == null || !mounted) return;
                                  _update({
                                    ..._working.toJson(),
                                    'variables': [
                                      for (final item in _working.variables)
                                        item.key == variable.key
                                            ? edited
                                            : item.toJson(),
                                    ]
                                  });
                                },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                  ],
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('规则与后续剧情'),
                children: [
                  for (final rule in effective.rules)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(rule.title),
                      subtitle: Text('${rule.when}\n${rule.effect}'),
                      trailing: IconButton(
                        tooltip: '编辑${rule.title}',
                        onPressed: _busy || _lockedGroups.isNotEmpty
                            ? null
                            : () async {
                                final edited =
                                    await editGameplayRule(context, rule);
                                if (edited == null || !mounted) return;
                                _update({
                                  ..._working.toJson(),
                                  'rules': [
                                    for (final item in _working.rules)
                                      item.id == rule.id
                                          ? edited
                                          : item.toJson(),
                                  ]
                                });
                              },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  if (_lockedGroups.isNotEmpty)
                    const Text('为保留锁定组的联动，规则编辑暂时关闭。需要改规则时先取消锁定。'),
                ],
              ),
              const SizedBox(height: 12),
              const Text('应用后会发生什么',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (widget.current == null)
                Text(
                    '启用 ${effective.variables.length} 个变量和 ${effective.rules.length} 条规则。'),
              if (widget.current != null)
                for (final change in _review.changes) _Note(change),
              for (final note in _review.migrationNotes) _Note(note),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy || _invalidMerge ? null : _rehearse,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('本地预演'),
                  ),
                  if (widget.onRegenerate != null)
                    TextButton.icon(
                      onPressed: _busy ? null : _regenerate,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      label: const Text('再生成一份草稿'),
                    ),
                  TextButton(
                      onPressed:
                          _busy || _lockedGroups.isNotEmpty ? null : _editJson,
                      child: const Text('高级编辑')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('放弃草稿')),
          FilledButton(
              onPressed: _busy || _invalidMerge ? null : _confirmApply,
              child: const Text('检查并应用')),
        ],
      ),
    );
  }

  Future<void> _regenerate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final generated = await widget.onRegenerate!();
      if (mounted) {
        setState(() {
          _working = generated;
          _refreshReview();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rehearse() => showDialog<void>(
        context: context,
        builder: (_) => GameplayRehearsalDialog(
          system: _review.system,
          state: widget.state.copyWith(
              customVariables:
                  _review.migrateValues(widget.state.customVariables),
              gameplayRuntime:
                  _review.migrateRuntime(widget.state.gameplayRuntime)),
        ),
      );

  Future<void> _confirmApply() async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('应用这份玩法草稿？'),
              content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_review.system.title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      if (widget.current == null)
                        Text(
                            '首次启用 ${_review.system.variables.length} 个变量和 ${_review.system.rules.length} 条规则。'),
                      if (widget.current != null)
                        for (final change in _review.changes) _Note(change),
                      for (final note in _review.migrationNotes) _Note(note),
                      const SizedBox(height: 8),
                      const Text('预演进度不会写入正式剧情。'),
                    ],
                  ))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('继续调整')),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('应用到剧场')),
              ],
            ));
    if (accepted == true && mounted) Navigator.of(context).pop(_review.system);
  }

  Future<void> _editOverview() async {
    final title = TextEditingController(text: _working.title);
    final summary = TextEditingController(text: _working.summary);
    final loop = TextEditingController(text: _working.coreLoop);
    final route = DialogRoute<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('玩法概述'),
              content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: title,
                        decoration: const InputDecoration(labelText: '玩法名称')),
                    TextField(
                        controller: summary,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: '简短介绍')),
                    TextField(
                        controller: loop,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                            labelText: '玩家做什么、付出什么、得到什么')),
                  ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('保存到草稿')),
              ],
            ));
    final result = await Navigator.of(context).push(route);
    if (result == true && mounted) {
      _update({
        ..._working.toJson(),
        'title': title.text,
        'summary': summary.text,
        'coreLoop': loop.text
      });
    }
    await route.completed;
    title.dispose();
    summary.dispose();
    loop.dispose();
  }

  Future<void> _editJson() async {
    final json = TextEditingController(
        text: const JsonEncoder.withIndent('  ').convert(_working.toJson()));
    String? error;
    final route = DialogRoute<GameplaySystem>(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, setLocalState) => AlertDialog(
                title: const Text('高级编辑玩法'),
                content: SizedBox(
                    width: 700,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('可以调整变量、揭示条件和规则的完整定义。先保存为草稿，再预演与检查差异。'),
                      TextField(
                          controller: json,
                          minLines: 10,
                          maxLines: 20,
                          decoration:
                              const InputDecoration(labelText: '玩法 JSON')),
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        try {
                          Navigator.of(context)
                              .pop(GameplaySystemParser.parse(json.text));
                        } catch (caught) {
                          setLocalState(() => error = caught.toString());
                        }
                      },
                      child: const Text('保存到草稿')),
                ],
              ),
            ));
    final result = await Navigator.of(context).push(route);
    if (result != null && mounted) {
      setState(() {
        _working = result;
        _refreshReview();
      });
    }
    await route.completed;
    json.dispose();
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text));
}
