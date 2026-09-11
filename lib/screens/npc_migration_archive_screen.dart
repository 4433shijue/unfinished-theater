import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/npc_migration.dart';
import '../theme/app_theme.dart';

class NpcMigrationArchiveScreen extends StatefulWidget {
  const NpcMigrationArchiveScreen({
    super.key,
    this.initialRecordId,
    this.sourceNpcId,
    this.createdCharacterId,
  });

  final String? initialRecordId;
  final String? sourceNpcId;
  final String? createdCharacterId;

  @override
  State<NpcMigrationArchiveScreen> createState() =>
      _NpcMigrationArchiveScreenState();
}

class _NpcMigrationArchiveScreenState extends State<NpcMigrationArchiveScreen> {
  String _query = '';
  String _groupMode = '全部前尘';
  String? _selectedRecordId;

  @override
  void initState() {
    super.initState();
    _selectedRecordId = widget.initialRecordId;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final allRecords = controller.npcMigrations;
    final records = _filteredRecords(allRecords);
    final selected = _selectedRecordId == null
        ? (records.isEmpty ? null : records.first)
        : records.cast<NpcMigrationRecord?>().firstWhere(
              (record) => record?.id == _selectedRecordId,
              orElse: () => records.isEmpty ? null : records.first,
            );
    final createdCharacterAvailable = selected != null &&
        selected.createsCharacter &&
        controller.characters
            .any((character) => character.id == selected.createdCharacterId);
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(AppTheme.glitchText('前尘档案馆')),
        actions: <Widget>[
          if (createdCharacterAvailable)
            IconButton(
              tooltip: AppTheme.glitchText('打开新角色'),
              onPressed: () async {
                await context
                    .read<AppStateController>()
                    .selectCharacter(selected.createdCharacterId);
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                }
              },
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.shellBackgroundGradient),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: allRecords.isEmpty
                ? _ArchiveEmptyState()
                : wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 420,
                            child: SingleChildScrollView(
                              child: _ArchiveListPane(
                                query: _query,
                                groupMode: _groupMode,
                                records: records,
                                selectedRecordId: selected?.id,
                                onQueryChanged: (value) =>
                                    setState(() => _query = value),
                                onGroupChanged: (value) =>
                                    setState(() => _groupMode = value),
                                onSelect: (record) => setState(
                                    () => _selectedRecordId = record.id),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: selected == null
                                ? const SizedBox.shrink()
                                : SingleChildScrollView(
                                    child: _ArchiveDetailPane(
                                      record: selected,
                                      createdCharacterAvailable:
                                          createdCharacterAvailable,
                                    ),
                                  ),
                          ),
                        ],
                      )
                    : ListView(
                        children: <Widget>[
                          _ArchiveListPane(
                            query: _query,
                            groupMode: _groupMode,
                            records: records,
                            selectedRecordId: selected?.id,
                            onQueryChanged: (value) =>
                                setState(() => _query = value),
                            onGroupChanged: (value) =>
                                setState(() => _groupMode = value),
                            onSelect: (record) =>
                                setState(() => _selectedRecordId = record.id),
                          ),
                          if (selected != null) ...<Widget>[
                            const SizedBox(height: 14),
                            _ArchiveDetailPane(
                              record: selected,
                              createdCharacterAvailable:
                                  createdCharacterAvailable,
                            ),
                          ],
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  List<NpcMigrationRecord> _filteredRecords(List<NpcMigrationRecord> source) {
    final query = _query.trim().toLowerCase();
    return source.where((record) {
      if (_groupMode == '只看已迁徙角色' && !record.createsCharacter) {
        return false;
      }
      if (widget.sourceNpcId != null &&
          record.sourceNpcId != widget.sourceNpcId) {
        return false;
      }
      if (widget.createdCharacterId != null &&
          record.createdCharacterId != widget.createdCharacterId) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        record.sourceNpcName,
        record.sourceCharacterName,
        record.createdCharacterName,
        record.worldType,
        record.archiveText,
        record.keepsake.name,
        NpcMigrationRelationshipLock.label(record.relationshipLock),
      ].join('\n').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }
}

class _ArchiveListPane extends StatelessWidget {
  const _ArchiveListPane({
    required this.query,
    required this.groupMode,
    required this.records,
    required this.selectedRecordId,
    required this.onQueryChanged,
    required this.onGroupChanged,
    required this.onSelect,
  });

  final String query;
  final String groupMode;
  final List<NpcMigrationRecord> records;
  final String? selectedRecordId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<NpcMigrationRecord> onSelect;

  static const List<String> _groups = <String>[
    '全部前尘',
    '按旧世界',
    '按 NPC',
    '按新世界',
    '只看已迁徙角色',
  ];

  @override
  Widget build(BuildContext context) {
    final grouped = _group(records);
    return Container(
      decoration: AppTheme.glassPanel(highlighted: true),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTheme.glitchText('前尘档案馆'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              AppTheme.glitchText('旧世界告别、迁徙档案、新世界角色和长期回声都会保存在这里。'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                labelText: AppTheme.glitchText('搜索前尘'),
                hintText: AppTheme.glitchText('NPC、新角色、旧世界、关键词...'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final mode in _groups)
                  ChoiceChip(
                    selected: groupMode == mode,
                    label: Text(AppTheme.glitchText(mode)),
                    onSelected: (_) => onGroupChanged(mode),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  AppTheme.glitchText('没有符合条件的前尘档案。'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              )
            else
              for (final entry in grouped.entries) ...<Widget>[
                if (entry.key.isNotEmpty) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      AppTheme.glitchText(entry.key),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
                for (final record in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ArchiveRecordCard(
                      record: record,
                      selected: record.id == selectedRecordId,
                      onTap: () => onSelect(record),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  Map<String, List<NpcMigrationRecord>> _group(
      List<NpcMigrationRecord> records) {
    final result = <String, List<NpcMigrationRecord>>{};
    for (final record in records) {
      final key = switch (groupMode) {
        '按旧世界' => record.sourceCharacterName,
        '按 NPC' => record.sourceNpcName,
        '按新世界' => record.createsCharacter
            ? record.worldType
            : NpcMigrationOutputKind.label(record.outputKind),
        '只看已迁徙角色' => 'NPC 新世界',
        _ => '',
      };
      result.putIfAbsent(key, () => <NpcMigrationRecord>[]).add(record);
    }
    return result;
  }
}

class _ArchiveRecordCard extends StatelessWidget {
  const _ArchiveRecordCard({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final NpcMigrationRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.activePrimary.withValues(alpha: 0.14)
                : AppTheme.translucentPanelFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.activeSoft : AppTheme.activeLine,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.history_edu_outlined,
                      size: 18, color: AppTheme.activePrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppTheme.glitchText(record.sourceNpcName),
                      maxLines: MediaQuery.sizeOf(context).width < 620 ? 2 : 1,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText(record.branchTitle),
                maxLines: MediaQuery.sizeOf(context).width < 620 ? 4 : 2,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _ArchiveChip(
                    icon: record.createsCharacter
                        ? Icons.person_pin
                        : Icons.menu_book_outlined,
                    text: record.createsCharacter
                        ? record.createdCharacterName
                        : NpcMigrationOutputKind.label(record.outputKind),
                  ),
                  _ArchiveChip(
                    icon: Icons.favorite_border_rounded,
                    text: NpcMigrationRelationshipLock.shortLabel(
                      record.relationshipLock,
                    ),
                  ),
                  if (record.farewellOutcome.hasFarewell)
                    const _ArchiveChip(icon: Icons.waving_hand, text: '有告别'),
                  if (!record.keepsake.isEmpty)
                    _ArchiveChip(
                        icon: Icons.card_giftcard, text: record.keepsake.name),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveDetailPane extends StatelessWidget {
  const _ArchiveDetailPane({
    required this.record,
    required this.createdCharacterAvailable,
  });

  final NpcMigrationRecord record;
  final bool createdCharacterAvailable;

  @override
  Widget build(BuildContext context) {
    final local = record.createdAt.toLocal().toString().split('.').first;
    return Container(
      decoration: AppTheme.glassPanel(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      AppTheme.activePrimary.withValues(alpha: 0.22),
                  child: const Icon(Icons.auto_stories_outlined),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppTheme.glitchText(record.branchTitle),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppTheme.glitchText(
                          record.createsCharacter
                              ? '从「${record.sourceCharacterName}」带走「${record.sourceNpcName}」 · $local'
                              : '从「${record.sourceCharacterName}」保存「${record.sourceNpcName}」的前尘 · $local',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _ArchiveChip(icon: Icons.public, text: record.worldType),
                _ArchiveChip(
                  icon: record.createsCharacter
                      ? Icons.travel_explore_outlined
                      : Icons.menu_book_outlined,
                  text: NpcMigrationOutputKind.label(record.outputKind),
                ),
                _ArchiveChip(
                  icon: Icons.memory,
                  text: NpcMigrationMemoryMode.shortLabel(record.memoryMode),
                ),
                _ArchiveChip(
                  icon: Icons.route,
                  text: NpcMigrationRelationshipLock.shortLabel(
                    record.relationshipLock,
                  ),
                ),
                _ArchiveChip(
                  icon: Icons.spatial_audio_off_outlined,
                  text: record.allowEcho ? '允许回声' : '关闭回声',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ArchiveActionPanel(
              record: record,
              createdCharacterAvailable: createdCharacterAvailable,
            ),
            const SizedBox(height: 12),
            _ArchiveSection(
              title: '来源',
              icon: Icons.history_edu_outlined,
              content: record.sourceDigest,
              expanded: true,
            ),
            _ArchiveSection(
              title: '旧世界告别',
              icon: Icons.waving_hand_outlined,
              content: _farewellText(record.farewellOutcome),
            ),
            _ArchiveSection(
              title: '迁徙档案',
              icon: Icons.folder_shared_outlined,
              content: record.archiveText,
            ),
            _ArchiveSection(
              title: '前尘世界书',
              icon: Icons.menu_book_outlined,
              content: '【${record.worldBookTitle}】\n${record.worldBookContent}',
            ),
            if (record.createsCharacter)
              _ArchiveSection(
                title: '新角色卡',
                icon: Icons.person_pin_circle_outlined,
                content:
                    '名称：${record.createdCharacterName}\n简介：${record.characterDescription}\n\n${record.characterPrompt}',
              ),
            if (record.createsCharacter)
              _ArchiveSection(
                title: '开场白',
                icon: Icons.forum_outlined,
                content: record.openingMessage,
              ),
            if (record.manifest.qualityWarnings.isNotEmpty)
              _ArchiveSection(
                title: '生成检查',
                icon: Icons.fact_check_outlined,
                content: record.manifest.qualityWarnings
                    .map((item) => '- $item')
                    .join('\n'),
              ),
            _ArchiveSection(
              title: '前尘信物',
              icon: Icons.card_giftcard_outlined,
              content: record.keepsake.isEmpty
                  ? '未记录。'
                  : '名称：${record.keepsake.name}\n外观与来历：${record.keepsake.description}\n来源：${record.keepsake.origin}\n关系意义：${record.keepsake.emotionalMeaning}\n触发方向：${record.keepsake.useEffectPrompt}',
            ),
            _ArchiveSection(
              title: '关系任务',
              icon: Icons.task_alt_outlined,
              content: record.relationshipTasks.isEmpty
                  ? '未记录。'
                  : record.relationshipTasks
                      .map((task) =>
                          '${task.completed ? '已完成' : '未完成'}｜${task.stage}｜${task.title}\n${task.description}')
                      .join('\n\n'),
            ),
            _ArchiveSection(
              title: '前尘回声记录',
              icon: Icons.spatial_audio_outlined,
              content: record.echoEvents.isEmpty
                  ? '尚未触发前尘回声。'
                  : record.echoEvents
                      .map((event) =>
                          '${event.echoType}｜${NpcMigrationEchoStatus.label(event.status)}\n${event.summary}${event.errorMessage.trim().isEmpty ? '' : '\n${event.errorMessage}'}')
                      .join('\n\n'),
            ),
            _ArchiveSection(
              title: '纪念册',
              icon: Icons.collections_bookmark_outlined,
              content: record.albumEntries.isEmpty
                  ? '纪念册还没有条目。'
                  : record.albumEntries
                      .map((entry) =>
                          '${entry.title}\n${entry.content}${entry.note.trim().isEmpty ? '' : '\n备注：${entry.note}'}')
                      .join('\n\n'),
            ),
            _ArchiveSection(
              title: '重修历史',
              icon: Icons.construction_outlined,
              content: record.revisionHistory.isEmpty
                  ? '还没有重修记录。'
                  : record.revisionHistory
                      .map((entry) => '${entry.section}｜${entry.instruction}')
                      .join('\n\n'),
            ),
          ],
        ),
      ),
    );
  }

  static String _farewellText(NpcFarewellOutcome outcome) {
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

class _ArchiveActionPanel extends StatelessWidget {
  const _ArchiveActionPanel({
    required this.record,
    required this.createdCharacterAvailable,
  });

  final NpcMigrationRecord record;
  final bool createdCharacterAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          if (record.createsCharacter)
            FilledButton.tonalIcon(
              onPressed: createdCharacterAvailable
                  ? () async {
                      await context
                          .read<AppStateController>()
                          .selectCharacter(record.createdCharacterId);
                      if (context.mounted) {
                        Navigator.of(context).maybePop();
                      }
                    }
                  : null,
              icon: Icon(createdCharacterAvailable
                  ? Icons.open_in_new_rounded
                  : Icons.link_off_rounded),
              label: Text(AppTheme.glitchText(
                  createdCharacterAvailable ? '打开新角色' : '新角色已失联')),
            ),
          OutlinedButton.icon(
            onPressed: record.allowEcho && createdCharacterAvailable
                ? () => _showEchoDialog(context, record)
                : null,
            icon: const Icon(Icons.spatial_audio_outlined),
            label: Text(AppTheme.glitchText('前尘回声')),
          ),
          OutlinedButton.icon(
            onPressed: () => _showRevisionDialog(context, record),
            icon: const Icon(Icons.construction_outlined),
            label: Text(AppTheme.glitchText('迁徙重修台')),
          ),
          OutlinedButton.icon(
            onPressed: () => _showAlbumDialog(context, record),
            icon: const Icon(Icons.collections_bookmark_outlined),
            label: Text(AppTheme.glitchText('加入纪念册')),
          ),
          IconButton.outlined(
            tooltip: AppTheme.glitchText('删除这份档案'),
            onPressed: () => _deleteRecord(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text(AppTheme.glitchText('删除前尘档案？')),
        content: Text(
          AppTheme.glitchText('只删除这份档案，不会删除已经生成的角色或世界书。'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTheme.glitchText('删除档案')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context
        .read<AppStateController>()
        .deleteNpcMigrationRecord(record.id);
  }

  Future<void> _showEchoDialog(
    BuildContext context,
    NpcMigrationRecord record,
  ) async {
    const types = <String>[
      '梦见旧世界',
      '触发信物',
      'TA 说出没说完的话',
      '新世界出现旧世界相似场景',
      '随机回声',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppTheme.panel,
        title: Text(AppTheme.glitchText('前尘回声')),
        children: <Widget>[
          for (final type in types)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(type),
              child: Text(AppTheme.glitchText(type)),
            ),
        ],
      ),
    );
    if (selected == null || !context.mounted) {
      return;
    }
    final error = await context
        .read<AppStateController>()
        .triggerNpcMigrationEcho(recordId: record.id, echoType: selected);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText(error ?? '前尘回声已触发。'))),
    );
  }

  Future<void> _showRevisionDialog(
    BuildContext context,
    NpcMigrationRecord record,
  ) async {
    final result = await showDialog<_RevisionRequest>(
      context: context,
      builder: (context) => _RevisionDialog(record: record),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final error =
        await context.read<AppStateController>().reviseNpcMigrationRecord(
              recordId: record.id,
              section: result.section,
              instruction: result.instruction,
            );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText(error ?? '前尘档案已重修。'))),
    );
  }

  Future<void> _showAlbumDialog(
    BuildContext context,
    NpcMigrationRecord record,
  ) async {
    final result = await showDialog<_AlbumRequest>(
      context: context,
      builder: (context) => const _AlbumDialog(),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final error =
        await context.read<AppStateController>().addNpcMigrationAlbumEntry(
              recordId: record.id,
              title: result.title,
              content: result.content,
              note: result.note,
            );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText(error ?? '已加入前尘纪念册。'))),
    );
  }
}

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({
    required this.title,
    required this.icon,
    required this.content,
    this.expanded = false,
  });

  final String title;
  final IconData icon;
  final String content;
  final bool expanded;

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
          initiallyExpanded: expanded,
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

class _ArchiveChip extends StatelessWidget {
  const _ArchiveChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.activePrimary),
          const SizedBox(width: 5),
          Text(
            AppTheme.glitchText(text),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassPanel(highlighted: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.history_edu_outlined,
                size: 54, color: AppTheme.activePrimary),
            const SizedBox(height: 14),
            Text(
              AppTheme.glitchText('还没有前尘档案'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText('去 NPC 私聊页点“带 TA 走”，完成告别和再续前缘后，这里会保存完整链路。'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.55,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevisionRequest {
  const _RevisionRequest(this.section, this.instruction);

  final String section;
  final String instruction;
}

class _RevisionDialog extends StatefulWidget {
  const _RevisionDialog({required this.record});

  final NpcMigrationRecord record;

  @override
  State<_RevisionDialog> createState() => _RevisionDialogState();
}

class _RevisionDialogState extends State<_RevisionDialog> {
  late final List<String> _sections;
  late String _section;
  late String _selectedRuleValue;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sections = <String>[
      '旧世界档案',
      '前尘世界书',
      if (widget.record.createsCharacter) '新角色卡',
      if (widget.record.createsCharacter) '开场白',
      '关系任务',
      '前尘信物',
      '记忆强度',
      '关系路线',
    ];
    _section = _sections.first;
    _selectedRuleValue = widget.record.memoryMode;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(AppTheme.glitchText('迁徙重修台')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _section,
              decoration:
                  InputDecoration(labelText: AppTheme.glitchText('重修部分')),
              items: _sections
                  .map((section) => DropdownMenuItem<String>(
                        value: section,
                        child: Text(AppTheme.glitchText(section)),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                _section = value ?? _section;
                _selectedRuleValue = _section == '关系路线'
                    ? widget.record.relationshipLock
                    : widget.record.memoryMode;
              }),
            ),
            const SizedBox(height: 12),
            if (_section == '记忆强度')
              DropdownButtonFormField<String>(
                key: ValueKey<String>(_section),
                initialValue: _selectedRuleValue,
                decoration:
                    InputDecoration(labelText: AppTheme.glitchText('记忆强度')),
                items: const <String>[
                  NpcMigrationMemoryMode.full,
                  NpcMigrationMemoryMode.fragments,
                  NpcMigrationMemoryMode.echo,
                ]
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(AppTheme.glitchText(
                            NpcMigrationMemoryMode.shortLabel(value))),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(
                  () => _selectedRuleValue = value ?? _selectedRuleValue,
                ),
              )
            else if (_section == '关系路线')
              DropdownButtonFormField<String>(
                key: ValueKey<String>(_section),
                initialValue: _selectedRuleValue,
                decoration:
                    InputDecoration(labelText: AppTheme.glitchText('关系路线')),
                items: NpcMigrationRelationshipLock.values
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(AppTheme.glitchText(
                            NpcMigrationRelationshipLock.label(value))),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(
                  () => _selectedRuleValue = value ?? _selectedRuleValue,
                ),
              )
            else
              TextField(
                controller: _controller,
                minLines: 4,
                maxLines: 7,
                decoration: InputDecoration(
                  labelText: AppTheme.glitchText('修改要求'),
                  hintText: AppTheme.glitchText('例如：保留事实，只把文风改得更克制。'),
                  alignLabelWithHint: true,
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _RevisionRequest(
              _section,
              _section == '记忆强度' || _section == '关系路线'
                  ? _selectedRuleValue
                  : _controller.text.trim(),
            ),
          ),
          child: Text(AppTheme.glitchText('开始重修')),
        ),
      ],
    );
  }
}

class _AlbumRequest {
  const _AlbumRequest(this.title, this.content, this.note);

  final String title;
  final String content;
  final String note;
}

class _AlbumDialog extends StatefulWidget {
  const _AlbumDialog();

  @override
  State<_AlbumDialog> createState() => _AlbumDialogState();
}

class _AlbumDialogState extends State<_AlbumDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(AppTheme.glitchText('加入前尘纪念册')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: AppTheme.glitchText('标题')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _content,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: AppTheme.glitchText('内容'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration:
                  InputDecoration(labelText: AppTheme.glitchText('备注，可选')),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _AlbumRequest(
              _title.text.trim(),
              _content.text.trim(),
              _note.text.trim(),
            ),
          ),
          child: Text(AppTheme.glitchText('收录')),
        ),
      ],
    );
  }
}
