import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_state_controller.dart';
import '../models/story_continuity.dart';
import '../services/message_content_parser.dart';

Future<void> _storyNotice(
    BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

Future<String?> storyTextDialog(BuildContext context, String title,
    {String initial = '', String hint = ''}) async {
  final editor = TextEditingController(text: initial);
  final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 1),
              title: Text(title),
              content: TextField(
                  controller: editor,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(hintText: hint)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, editor.text.trim()),
                    child: const Text('保存'))
              ]));
  editor.dispose();
  return result;
}

Future<void> showRememberStoryFact(
    BuildContext context, String messageId, String content,
    {String? npcId}) async {
  final controller = context.read<AppStateController>();
  final text = await storyTextDialog(context, '记为重要事实',
      initial: MessageContentParser.contextTextForModel(content),
      hint: '写一条需要保持一致的事实');
  if (text == null || text.isEmpty || !context.mounted) return;
  await _storyNotice(
      context,
      () => controller.rememberStoryFact(
          text: text, sourceIds: [messageId], npcId: npcId));
}

Future<void> showStoryRewriteDialog(BuildContext context, String messageId,
        {String? npcId, String? selection}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _StoryRewriteDialog(
            messageId: messageId, npcId: npcId, selection: selection));

class _StoryRewriteDialog extends StatefulWidget {
  const _StoryRewriteDialog(
      {required this.messageId, this.npcId, this.selection});
  final String messageId;
  final String? npcId;
  final String? selection;
  @override
  State<_StoryRewriteDialog> createState() => _StoryRewriteDialogState();
}

class _StoryRewriteDialogState extends State<_StoryRewriteDialog> {
  final direction = TextEditingController();
  final branchName = TextEditingController();
  final affinity = <String, TextEditingController>{};
  late List<StoryRewriteTarget> targets;
  StoryRewriteTarget? target;
  StoryRewritePreview? preview;
  StoryRewriteMode mode = StoryRewriteMode.polish;
  bool busy = false;
  bool ambiguousSelection = false;
  String? error;
  @override
  void initState() {
    super.initState();
    targets = context
        .read<AppStateController>()
        .storyRewriteTargets(widget.messageId, npcId: widget.npcId);
    target = targets.firstOrNull;
    final selected = widget.selection?.trim() ?? '';
    if (selected.isNotEmpty) {
      final matches = <StoryRewriteTarget>[];
      for (final paragraph in targets) {
        var offset = paragraph.selectedText.indexOf(selected);
        while (offset >= 0) {
          final start = paragraph.start + offset;
          matches.add(StoryRewriteTarget(
              messageId: paragraph.messageId,
              content: paragraph.content,
              start: start,
              end: start + selected.length,
              npcId: paragraph.npcId,
              groupIndex: paragraph.groupIndex));
          offset = paragraph.selectedText
              .indexOf(selected, offset + selected.length);
        }
      }
      if (matches.isNotEmpty) {
        targets = matches;
        ambiguousSelection = matches.length > 1;
        target = ambiguousSelection ? null : matches.single;
      }
    }
  }

  @override
  void dispose() {
    direction.dispose();
    branchName.dispose();
    for (final field in affinity.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final versions = storyMaps(controller.currentContinuity
        .revisions['${widget.npcId ?? 'main'}/${widget.messageId}']);
    final needsBaseline = preview?.requiresBranch == true &&
        controller
            .rewriteCheckpoint(widget.messageId, npcId: widget.npcId)
            .isEmpty;
    final baselineNpcs = controller.currentWorldNpcProfiles
        .where((n) => widget.npcId == null || n.id == widget.npcId);
    return PopScope(
        canPop: !busy,
        child: AlertDialog(
            backgroundColor:
                Theme.of(context).colorScheme.surface.withValues(alpha: 1),
            title: const Text('局部重写与版本'),
            content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      if (targets.isEmpty)
                        const Text('没有可改写的正文段落。状态面板和 HTML 番外不参与改写。'),
                      if (ambiguousSelection)
                        const Text('这段文字出现多次，请按顺序与上下文选择要改的位置。'),
                      if (targets.isNotEmpty)
                        DropdownButtonFormField<int>(
                            initialValue: target == null
                                ? null
                                : targets.indexOf(target!),
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: '选择段落'),
                            items: [
                              for (var i = 0; i < targets.length; i++)
                                DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                        '${i + 1}. ${ambiguousSelection ? targets[i].content.substring((targets[i].start - 20).clamp(0, targets[i].content.length), (targets[i].end + 20).clamp(0, targets[i].content.length)) : targets[i].selectedText}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis))
                            ],
                            onChanged: busy
                                ? null
                                : (i) => setState(() {
                                      target = targets[i!];
                                      preview = null;
                                    })),
                      const SizedBox(height: 12),
                      SegmentedButton<StoryRewriteMode>(
                          segments: const [
                            ButtonSegment(
                                value: StoryRewriteMode.polish,
                                label: Text('润色文字')),
                            ButtonSegment(
                                value: StoryRewriteMode.plot,
                                label: Text('改写剧情'))
                          ],
                          selected: {
                            mode
                          },
                          onSelectionChanged: busy
                              ? null
                              : (s) => setState(() {
                                    mode = s.single;
                                    preview = null;
                                  })),
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final label in ['更符合人设', '别替我行动', '换个表达'])
                          ActionChip(
                              label: Text(label),
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                        direction.text = label;
                                        preview = null;
                                      }))
                      ]),
                      TextField(
                          controller: direction,
                          enabled: !busy,
                          maxLines: 3,
                          minLines: 1,
                          decoration:
                              const InputDecoration(labelText: '这段想怎么改'),
                          onChanged: (_) => setState(() => preview = null)),
                      if (target != null) ...[
                        const SizedBox(height: 12),
                        const Text('选中原文'),
                        SelectableText(target!.selectedText)
                      ],
                      if (preview != null) ...[
                        const Divider(),
                        const Text('候选文字'),
                        SelectableText(preview!.replacement),
                        const SizedBox(height: 10),
                        Text(preview!.reason),
                        if (preview!.requiresBranch)
                          TextField(
                              controller: branchName,
                              decoration: const InputDecoration(
                                  labelText: '新分支名称（可留空）')),
                        if (needsBaseline) ...[
                          const Text('旧记录缺少可靠快照。会保留可证实的历史，未知印象与关系不从现在带回。'),
                          for (final npc in baselineNpcs)
                            TextField(
                                controller: affinity.putIfAbsent(
                                    npc.id, TextEditingController.new),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        signed: true),
                                decoration: InputDecoration(
                                    labelText: '${npc.name} 的起始好感（-100 至 100）'))
                        ]
                      ],
                      if (versions.isNotEmpty)
                        ExpansionTile(
                            title: Text('已保存版本 · ${versions.length}'),
                            children: [
                              for (var i = 0; i < versions.length; i++)
                                ListTile(
                                    title: Text('版本 ${i + 1}'),
                                    subtitle: Text(
                                        MessageContentParser
                                            .contextTextForModel(versions[i]
                                                        ['content']
                                                    ?.toString() ??
                                                ''),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis),
                                    trailing: TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => run(() async {
                                                  await controller
                                                      .switchStoryRevision(
                                                          widget.messageId,
                                                          versions[i]['id']
                                                              .toString(),
                                                          npcId: widget.npcId);
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                }),
                                        child: const Text('采用')))
                            ]),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      if (busy)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator()),
                    ]))),
            actions: [
              TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('取消')),
              if (preview == null)
                FilledButton(
                    onPressed: busy || target == null
                        ? null
                        : () => run(() async {
                              final result =
                                  await controller.previewStoryRewrite(
                                      target!, mode, direction.text);
                              if (mounted) setState(() => preview = result);
                            }),
                    child: const Text('生成预览')),
              if (preview != null)
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                              final baselines = <String, int>{};
                              if (needsBaseline) {
                                for (final npc in baselineNpcs) {
                                  final value = int.tryParse(
                                      affinity[npc.id]?.text.trim() ?? '');
                                  if (value == null ||
                                      value < -100 ||
                                      value > 100) {
                                    throw StateError(
                                        '请填写 ${npc.name} 的有效起始好感。');
                                  }
                                  baselines[npc.id] = value;
                                }
                              }
                              await controller.applyStoryRewrite(preview!,
                                  branchName: branchName.text,
                                  legacyAffinities: baselines);
                              if (context.mounted) Navigator.pop(context);
                            }),
                    child: Text(preview!.requiresBranch ? '创建分支并采用' : '采用这段'))
            ]));
  }
}

Future<void> showDirectorPreferencesDialog(BuildContext context) =>
    showDialog<void>(
        context: context, builder: (_) => const _DirectorPreferencesDialog());

class _DirectorPreferencesDialog extends StatefulWidget {
  const _DirectorPreferencesDialog();
  @override
  State<_DirectorPreferencesDialog> createState() =>
      _DirectorPreferencesDialogState();
}

class _DirectorPreferencesDialogState
    extends State<_DirectorPreferencesDialog> {
  String scope = 'turn';
  Map<String, String> values = {};
  final note = TextEditingController();
  static const choices = {
    '剧情节奏': ['沿用剧本', '慢慢相处', '自然推进', '推进主线'],
    '对话比重': ['沿用剧本', '多写对话', '对话与叙述均衡', '多写行动'],
    '心理描写': ['沿用剧本', '少写心理', '适量心理', '多写 NPC 心理'],
    '篇幅': ['沿用剧本', '简短', '适中', '详细']
  };
  void load() {
    values = storyMap(context
            .read<AppStateController>()
            .currentContinuity
            .directors[scope])
        .map((k, v) => MapEntry(k, v.toString()));
    note.text = values['导演补充'] ?? '';
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: 1),
          title: const Text('剧情导演台'),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                    initialValue: scope,
                    decoration: const InputDecoration(labelText: '作用范围'),
                    items: const [
                      DropdownMenuItem(value: 'turn', child: Text('本回合')),
                      DropdownMenuItem(value: 'scene', child: Text('本场景')),
                      DropdownMenuItem(value: 'story', child: Text('本剧本'))
                    ],
                    onChanged: (v) => setState(() {
                          scope = v!;
                          load();
                        })),
                const SizedBox(height: 8),
                const Text('本回合优先，其次本场景和本剧本。留空的项目沿用下一级偏好。'),
                for (final entry in choices.entries)
                  DropdownButtonFormField<String>(
                      key: ValueKey('$scope/${entry.key}'),
                      initialValue: entry.value.contains(values[entry.key])
                          ? values[entry.key]
                          : '沿用剧本',
                      decoration: InputDecoration(labelText: entry.key),
                      items: entry.value
                          .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) =>
                          values[entry.key] = v == '沿用剧本' ? '' : v!),
                TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '导演补充')),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            TextButton(
                onPressed: () => _storyNotice(context, () async {
                      await context
                          .read<AppStateController>()
                          .saveDirectorPreferences(scope, {});
                      if (context.mounted) Navigator.pop(context);
                    }),
                child: const Text('清空此范围')),
            FilledButton(
                onPressed: () => _storyNotice(context, () async {
                      await context
                          .read<AppStateController>()
                          .saveDirectorPreferences(
                              scope, {...values, '导演补充': note.text});
                      if (context.mounted) Navigator.pop(context);
                    }),
                child: const Text('保存'))
          ]);
}

Future<void> showStoryContinuityDialog(BuildContext context,
        {String? npcId, ValueChanged<String>? onJump}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _StoryContinuityDialog(npcId: npcId, onJump: onJump));

class _StoryContinuityDialog extends StatelessWidget {
  const _StoryContinuityDialog({this.npcId, this.onJump});
  final String? npcId;
  final ValueChanged<String>? onJump;
  Future<void> correct(BuildContext context, Map<String, dynamic> fact,
      {Map<String, dynamic>? conflict}) async {
    final controller = context.read<AppStateController>();
    final text = await storyTextDialog(context, '修正事实',
        initial: conflict == null
            ? fact['text'].toString()
            : storyMap(conflict['incoming'])['text'].toString());
    if (text == null || !context.mounted) return;
    final historical = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                backgroundColor:
                    Theme.of(context).colorScheme.surface.withValues(alpha: 1),
                title: const Text('确认影响'),
                content: SingleChildScrollView(
                    child: Text(
                        '${controller.factCorrectionImpact(fact['id'].toString()).join('\n')}\n\n这是纠正旧记录，还是剧情现在发生了变化？')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('剧情现在变化')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('以前记错了'))
                ]));
    if (historical == null || !context.mounted) return;
    await _storyNotice(
        context,
        () => controller.correctStoryFact(fact['id'].toString(), text,
            historical: historical, conflictId: conflict?['id']?.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final state = controller.currentContinuity;
    final npcs = controller.currentWorldNpcProfiles;
    return AlertDialog(
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 1),
        title: Text(npcId == null ? '连续记忆与章节' : '人物知情范围'),
        content: SizedBox(
            width: 700,
            height: MediaQuery.sizeOf(context).height * .65,
            child: DefaultTabController(
                length: 3,
                initialIndex: npcId == null ? 0 : 1,
                child: Column(children: [
                  const TabBar(tabs: [
                    Tab(text: '事实'),
                    Tab(text: '知情'),
                    Tab(text: '章节')
                  ]),
                  Expanded(
                      child: TabBarView(children: [
                    ListView(children: [
                      TextButton.icon(
                          onPressed: () async {
                            final text =
                                await storyTextDialog(context, '新增重要事实');
                            if (text != null && context.mounted) {
                              await _storyNotice(
                                  context,
                                  () => controller.rememberStoryFact(
                                      text: text, sourceIds: [], npcId: npcId));
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('新增重要事实')),
                      for (final conflict in state.conflicts
                          .where((c) => c['resolved'] != true))
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('待确认的事实变化'),
                                      Text(
                                          storyMap(conflict['incoming'])['text']
                                                  ?.toString() ??
                                              ''),
                                      Wrap(spacing: 8, children: [
                                        TextButton(
                                            onPressed: () {
                                              final fact = state.facts
                                                  .where((f) =>
                                                      f['id'] ==
                                                      conflict['factId'])
                                                  .firstOrNull;
                                              if (fact != null) {
                                                correct(context, fact,
                                                    conflict: conflict);
                                              }
                                            },
                                            child: const Text('查看并处理')),
                                        TextButton(
                                            onPressed: () => _storyNotice(
                                                context,
                                                () => controller
                                                    .dismissFactConflict(
                                                        conflict['id']
                                                            .toString())),
                                            child: const Text('保留原事实'))
                                      ])
                                    ]))),
                      if (state.activeFacts.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('还没有已确认事实。可以从消息菜单记录，也会随剧情自动整理。')),
                      for (final fact
                          in state.facts.where((f) => f['retired'] != true))
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(fact['text']?.toString() ?? ''),
                                      if (fact['needsReview'] == true)
                                        const Text('来源待核对'),
                                      Wrap(spacing: 8, children: [
                                        TextButton.icon(
                                            onPressed: () => _storyNotice(
                                                context,
                                                () => controller.setFactPinned(
                                                    fact['id'].toString(),
                                                    fact['pinned'] != true)),
                                            icon: Icon(fact['pinned'] == true
                                                ? Icons.push_pin
                                                : Icons.push_pin_outlined),
                                            label: Text(fact['pinned'] == true
                                                ? '已固定'
                                                : '固定')),
                                        TextButton(
                                            onPressed: () =>
                                                correct(context, fact),
                                            child: const Text('纠正')),
                                        if (storyStrings(fact['sourceIds'])
                                            .isNotEmpty)
                                          TextButton(
                                              onPressed: () {
                                                final id = storyStrings(
                                                        fact['sourceIds'])
                                                    .first;
                                                final mainSource = controller
                                                    .currentHistory.messages
                                                    .where((m) => m.id == id)
                                                    .firstOrNull;
                                                final privateSources =
                                                    <String, String>{};
                                                String? sourceNpc;
                                                for (final entry in state
                                                    .npcWorlds.entries) {
                                                  for (final message
                                                      in NpcWorldState.fromJson(
                                                              storyMap(
                                                                  entry.value))
                                                          .messages) {
                                                    if (message.id == id) {
                                                      privateSources[id] =
                                                          message.content;
                                                      sourceNpc = entry.key;
                                                    }
                                                  }
                                                }
                                                final sameSurface =
                                                    npcId == null
                                                        ? mainSource != null
                                                        : sourceNpc == npcId;
                                                if (onJump != null &&
                                                    sameSurface) {
                                                  Navigator.pop(context);
                                                  onJump!(id);
                                                } else {
                                                  final content =
                                                      mainSource?.content ??
                                                          privateSources[id];
                                                  showDialog<void>(
                                                      context: context,
                                                      builder: (_) => AlertDialog(
                                                              backgroundColor: Theme
                                                                      .of(context)
                                                                  .colorScheme
                                                                  .surface
                                                                  .withValues(
                                                                      alpha: 1),
                                                              title: Text(
                                                                  sourceNpc ==
                                                                          null
                                                                      ? '来源原文'
                                                                      : '${controller.npcProfileById(sourceNpc)?.name ?? 'NPC'} · 私聊来源'),
                                                              content: SingleChildScrollView(child: SelectableText(content == null ? '来源已不在当前记录中。' : MessageContentParser.contextTextForModel(content))),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context),
                                                                    child:
                                                                        const Text(
                                                                            '关闭'))
                                                              ]));
                                                }
                                              },
                                              child: const Text('查看来源'))
                                      ])
                                    ]))),
                    ]),
                    ListView(children: [
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('记录人物知道什么，以及如何获知。怀疑不会自动变成事实。')),
                      for (final npc
                          in npcs.where((n) => npcId == null || n.id == npcId))
                        ExpansionTile(
                            initiallyExpanded: npcId != null,
                            title: Text(npc.name),
                            children: [
                              if (storyMap(state.data['legacyNpcBaselines'])
                                  .containsKey(npc.id))
                                ListTile(
                                    title: const Text('旧档升级基线'),
                                    subtitle: Text(
                                        '升级时好感 ${storyMap(storyMap(state.data['legacyNpcBaselines'])[npc.id])['affinity']}。旧共享关系仅作为起点，不代表该世界已发生的经历。')),
                              for (final fact in state.activeFacts)
                                ListTile(
                                    title: Text(
                                        '${fact['needsReview'] == true ? '待核对 · ' : ''}${fact['text']}'),
                                    subtitle: DropdownButton<String>(
                                        isExpanded: true,
                                        value: state.knowledge
                                                .where((k) =>
                                                    k['npcId'] == npc.id &&
                                                    k['factId'] == fact['id'])
                                                .firstOrNull?['level']
                                                ?.toString() ??
                                            'unknown',
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'unknown',
                                              child: Text('尚不知道')),
                                          DropdownMenuItem(
                                              value: 'witnessed',
                                              child: Text('亲眼见过')),
                                          DropdownMenuItem(
                                              value: 'told',
                                              child: Text('被告知')),
                                          DropdownMenuItem(
                                              value: 'suspected',
                                              child: Text('只是怀疑'))
                                        ],
                                        onChanged: (v) => _storyNotice(
                                            context,
                                            () => controller.setNpcKnowledge(
                                                npc.id,
                                                fact['id'].toString(),
                                                v!))))
                            ])
                    ]),
                    ListView(children: [
                      Wrap(spacing: 8, children: [
                        FilledButton.tonal(
                            onPressed: controller.isSending
                                ? null
                                : () => _storyNotice(context, () async {
                                      final error =
                                          await controller.closeStoryScene();
                                      if (error != null) {
                                        throw StateError(error);
                                      }
                                    }),
                            child: const Text('在这里收尾')),
                        TextButton(
                            onPressed: () => showNextStorySceneDialog(context),
                            child: const Text('进入下一场')),
                        if (state.scene['closed'] == true)
                          TextButton(
                              onPressed: () => _storyNotice(
                                  context, controller.reopenStoryScene),
                              child: const Text('重新打开当前场景'))
                      ]),
                      if (state.chapters.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('收尾后，这里会保存章节和未完成事项。')),
                      for (final chapter in state.chapters)
                        ListTile(
                            title:
                                Text(chapter['title']?.toString() ?? '未命名章节'),
                            subtitle: Text(
                                '${chapter['summary'] ?? ''}\n${storyStrings(chapter['openThreads']).join('；')}'),
                            onTap: onJump == null
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    onJump!(
                                        chapter['startMessageId'].toString());
                                  },
                            trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final title = await storyTextDialog(
                                      context, '章节名称',
                                      initial:
                                          chapter['title']?.toString() ?? '');
                                  if (title != null && context.mounted) {
                                    await _storyNotice(
                                        context,
                                        () => controller.renameStoryChapter(
                                            chapter['id'].toString(), title));
                                  }
                                }))
                    ]),
                  ]))
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('关闭'))
        ]);
  }
}

Future<void> showNextStorySceneDialog(BuildContext context) async {
  final time = TextEditingController();
  final location = TextEditingController();
  final controller = context.read<AppStateController>();
  final mapMode = controller.currentCharacter?.mapModeEnabled == true;
  await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 1),
              title: const Text('进入下一场'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: time,
                    decoration: const InputDecoration(
                        labelText: '时间', hintText: '留空延续当前时间，例如第二天清晨')),
                if (mapMode)
                  DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: '',
                      decoration: const InputDecoration(labelText: '地点'),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('继续当前位置')),
                        for (final place
                            in controller.currentMapState.locations)
                          DropdownMenuItem(
                              value: place.id, child: Text(place.name))
                      ],
                      onChanged: (id) => location.text = id ?? '')
                else
                  TextField(
                      controller: location,
                      decoration: const InputDecoration(
                          labelText: '地点', hintText: '留空继续当前位置'))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('暂时留在这里')),
                FilledButton(
                    onPressed: () => _storyNotice(context, () async {
                          final error = await context
                              .read<AppStateController>()
                              .enterNextStoryScene(
                                  time: time.text.trim(),
                                  location: location.text.trim());
                          if (error != null) throw StateError(error);
                          if (context.mounted) Navigator.pop(context);
                        }),
                    child: const Text('确认进入'))
              ]));
  time.dispose();
  location.dispose();
}

class StoryResumeCard extends StatelessWidget {
  final VoidCallback? onOpenCalendar;
  const StoryResumeCard(
      {super.key, this.onJump, this.onOpenCalendar, this.expanded = false});
  final bool expanded;
  final ValueChanged<String>? onJump;
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final state = controller.currentContinuity;
    final scene = state.scene;
    final left = DateTime.tryParse(
        storyMap(state.reading['main'])['leftAt']?.toString() ?? '');
    return ExpansionTile(
        key: PageStorageKey('resume/${state.characterId}'),
        initiallyExpanded: expanded ||
            (left != null && DateTime.now().difference(left).inHours >= 24),
        title: const Text('接着上次演'),
        subtitle: Text(scene['title']?.toString() ?? '连续记忆、章节与阅读进度'),
        children: [
          for (final field in [
            'participants',
            'summary',
            'openThreads',
            'pendingReply'
          ])
            if ((scene[field] is List
                    ? storyStrings(scene[field]).join('、')
                    : scene[field]?.toString() ?? '')
                .isNotEmpty)
              ListTile(
                  title: Text(const {
                    'participants': '在场人物',
                    'summary': '最近事件',
                    'openThreads': '未解决事项',
                    'pendingReply': '待回应'
                  }[field]!),
                  subtitle: Text(scene[field] is List
                      ? storyStrings(scene[field]).join('\n')
                      : scene[field].toString()),
                  trailing: const Icon(Icons.read_more),
                  onTap: onJump == null
                      ? null
                      : () => onJump!((storyMap(scene['sources'])[field] ??
                              scene['sourceId'])
                          .toString())),
          Wrap(spacing: 8, children: [
            TextButton(
                onPressed: () =>
                    showStoryContinuityDialog(context, onJump: onJump),
                child: const Text('事实、知情与章节')),
            TextButton(
                onPressed: () => showDirectorPreferencesDialog(context),
                child: const Text('导演偏好')),
            if (onOpenCalendar != null)
              TextButton(onPressed: onOpenCalendar, child: const Text('事件日历'))
          ])
        ]);
  }
}

class StoryVisibilityEditor extends StatelessWidget {
  const StoryVisibilityEditor(
      {super.key, required this.value, required this.onChanged});
  final StoryVisibility value;
  final ValueChanged<StoryVisibility> onChanged;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<String>(
            initialValue: value.mode,
            decoration: const InputDecoration(labelText: '人物可知范围'),
            items: const [
              DropdownMenuItem(value: 'narrator', child: Text('仅叙事后台')),
              DropdownMenuItem(value: 'public', child: Text('公开信息')),
              DropdownMenuItem(value: 'npcs', child: Text('指定 NPC'))
            ],
            onChanged: (v) =>
                onChanged(StoryVisibility(mode: v!, npcIds: value.npcIds))),
        if (value.mode == 'npcs')
          Wrap(spacing: 6, children: [
            for (final npc in context.read<AppStateController>().npcProfiles)
              FilterChip(
                  label: Text(npc.name),
                  selected: value.npcIds.contains(npc.id),
                  onSelected: (selected) {
                    final ids = value.npcIds.toSet();
                    selected ? ids.add(npc.id) : ids.remove(npc.id);
                    onChanged(
                        StoryVisibility(mode: 'npcs', npcIds: ids.toList()));
                  })
          ])
      ]);
}

class StoryResumeLauncher extends StatefulWidget {
  const StoryResumeLauncher({super.key, this.onJump, this.onOpenCalendar});
  final ValueChanged<String>? onJump;
  final VoidCallback? onOpenCalendar;
  @override
  State<StoryResumeLauncher> createState() => _StoryResumeLauncherState();
}

class _StoryResumeLauncherState extends State<StoryResumeLauncher> {
  @override
  void initState() {
    super.initState();
    final state = context.read<AppStateController>().currentContinuity;
    final left = DateTime.tryParse(
        storyMap(state.reading['main'])['leftAt']?.toString() ?? '');
    if (left != null && DateTime.now().difference(left).inHours >= 24) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open();
      });
    }
  }

  void _open() => showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
          backgroundColor:
              Theme.of(dialog).colorScheme.surface.withValues(alpha: 1),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: 620,
                  maxHeight: MediaQuery.sizeOf(dialog).height * .8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                        tooltip: '关闭接戏卡',
                        onPressed: () => Navigator.pop(dialog),
                        icon: const Icon(Icons.close))),
                Flexible(
                    child: SingleChildScrollView(
                        child: StoryResumeCard(
                            expanded: true,
                            onOpenCalendar: widget.onOpenCalendar,
                            onJump: (id) {
                              Navigator.pop(dialog);
                              widget.onJump?.call(id);
                            })))
              ]))));
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
      tooltip: '接戏卡', onPressed: _open, icon: const Icon(Icons.history_edu));
}
