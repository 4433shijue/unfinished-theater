import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/character_profile.dart';
import '../models/world_book.dart';
import '../services/story_insight_service.dart';
import '../theme/app_theme.dart';
import '../widgets/world_book_editor_dialog.dart';

class WorldBooksScreen extends StatefulWidget {
  const WorldBooksScreen({super.key});

  static const int _collapsedContentLength = 260;

  @override
  State<WorldBooksScreen> createState() => _WorldBooksScreenState();
}

class _WorldBooksScreenState extends State<WorldBooksScreen> {
  bool _batchMode = false;
  String _selectedTag = '';
  final Set<String> _selectedEntryIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final entries = controller.worldBooks;
    final tags = _allTags(entries);
    if (_selectedTag.isNotEmpty && !tags.contains(_selectedTag)) {
      _selectedTag = '';
    }
    final filtered = _selectedTag.isEmpty
        ? entries
        : entries
            .where((entry) => entry.tags.contains(_selectedTag))
            .toList(growable: false);
    final groups = _groupEntries(filtered, selectedTag: _selectedTag);
    final previewItems = controller.currentWorldBookPreview;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.shellBackgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(AppTheme.glitchText('世界书')),
          actions: <Widget>[
            IconButton(
              tooltip: AppTheme.glitchText(_batchMode ? '退出批量' : '批量管理'),
              icon: Icon(_batchMode
                  ? Icons.close_rounded
                  : Icons.checklist_rtl_rounded),
              onPressed: entries.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _batchMode = !_batchMode;
                        if (!_batchMode) {
                          _selectedEntryIds.clear();
                        }
                      });
                    },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: AppTheme.glitchText('新建条目'),
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _openEditor(context),
              ),
            ),
          ],
        ),
        body: entries.isEmpty
            ? _WorldBookEmpty(onCreate: () => _openEditor(context))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                children: <Widget>[
                  _WorldBookTriggerPreviewPanel(items: previewItems),
                  const SizedBox(height: 14),
                  _WorldBookToolbar(
                    tags: tags,
                    selectedTag: _selectedTag,
                    batchMode: _batchMode,
                    selectedCount: _selectedEntryIds.length,
                    onTagSelected: (tag) => setState(() => _selectedTag = tag),
                    onSelectVisible: () {
                      setState(() {
                        _selectedEntryIds
                          ..clear()
                          ..addAll(filtered
                              .where((entry) =>
                                  entry.id != WorldBookEntry.defaultEntry().id)
                              .map((entry) => entry.id));
                      });
                    },
                    onClearSelection: () =>
                        setState(() => _selectedEntryIds.clear()),
                    onDelete: _selectedEntryIds.isEmpty
                        ? null
                        : () => _deleteSelected(context),
                    onBind: _selectedEntryIds.isEmpty
                        ? null
                        : () => _bindSelected(context),
                    onGlobal: _selectedEntryIds.isEmpty
                        ? null
                        : () => _setSelectedGlobal(context, true),
                    onUnglobal: _selectedEntryIds.isEmpty
                        ? null
                        : () => _setSelectedGlobal(context, false),
                  ),
                  const SizedBox(height: 14),
                  for (final group in groups) ...<Widget>[
                    _WorldBookGroupHeader(
                      title: group.key,
                      count: group.entries.length,
                    ),
                    const SizedBox(height: 10),
                    for (final entry in group.entries)
                      _WorldBookCard(
                        entry: entry,
                        collapseThreshold:
                            WorldBooksScreen._collapsedContentLength,
                        selected: _selectedEntryIds.contains(entry.id),
                        batchMode: _batchMode,
                        onSelectedChanged: (value) {
                          if (entry.id == WorldBookEntry.defaultEntry().id) {
                            return;
                          }
                          setState(() {
                            if (value) {
                              _selectedEntryIds.add(entry.id);
                            } else {
                              _selectedEntryIds.remove(entry.id);
                            }
                          });
                        },
                        onOpenFull: () => _openEditor(context, entry: entry),
                        onEdit: () => _openEditor(context, entry: entry),
                        onDelete: () => _confirmDelete(context, entry),
                      ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
      ),
    );
  }

  List<String> _allTags(List<WorldBookEntry> entries) {
    return entries
        .expand((entry) => entry.tags)
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
  }

  List<_WorldBookGroup> _groupEntries(
    List<WorldBookEntry> entries, {
    required String selectedTag,
  }) {
    final map = <String, List<WorldBookEntry>>{};
    for (final entry in entries) {
      final groupKey = selectedTag.trim().isNotEmpty
          ? selectedTag.trim()
          : _primaryTag(entry);
      final list = map.putIfAbsent(groupKey, () => <WorldBookEntry>[]);
      if (!list.any((item) => item.id == entry.id)) {
        list.add(entry);
      }
    }
    return map.entries
        .map((entry) => _WorldBookGroup(entry.key, entry.value))
        .toList(growable: false)
      ..sort((a, b) {
        if (a.key == '未分组') {
          return 1;
        }
        if (b.key == '未分组') {
          return -1;
        }
        return a.key.compareTo(b.key);
      });
  }

  String _primaryTag(WorldBookEntry entry) {
    for (final tag in entry.tags) {
      final clean = tag.trim();
      if (clean.isNotEmpty) {
        return clean;
      }
    }
    return '未分组';
  }

  Future<void> _openEditor(
    BuildContext context, {
    WorldBookEntry? entry,
  }) async {
    final draft = await showDialog<WorldBookDraft>(
      context: context,
      builder: (context) => WorldBookEditorDialog(
        initialEntry: entry,
      ),
    );

    if (!context.mounted || draft == null) {
      return;
    }

    final controller = context.read<AppStateController>();
    if (entry == null) {
      await controller.createWorldBook(draft);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTheme.glitchText('世界书条目已创建'))),
        );
      }
      return;
    }

    await controller.updateWorldBook(entry.id, draft);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('世界书条目已更新'))),
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WorldBookEntry entry) async {
    final controller = context.read<AppStateController>();

    final isDefault = entry.id == WorldBookEntry.defaultEntry().id;
    if (isDefault) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTheme.glitchText('默认创作规则不能删除'))),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('删除世界书')),
        content: Text(AppTheme.glitchText('确定要删除「${entry.title}」吗？')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTheme.glitchText('删除')),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    await controller.deleteWorldBook(entry.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('世界书条目已删除'))),
      );
    }
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final count = _selectedEntryIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('批量删除世界书')),
        content: Text(AppTheme.glitchText('确定删除选中的 $count 条世界书吗？默认创作规则会被保留。')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTheme.glitchText('删除')),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) {
      return;
    }
    final controller = context.read<AppStateController>();
    final messenger = ScaffoldMessenger.of(context);
    await controller.deleteWorldBooks(_selectedEntryIds);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedEntryIds.clear();
      _batchMode = false;
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('世界书已批量删除。')),
    );
  }

  Future<void> _bindSelected(BuildContext context) async {
    final controller = context.read<AppStateController>();
    final messenger = ScaffoldMessenger.of(context);
    final characters = controller.characters;
    final selectedCharacters = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _CharacterPickerDialog(characters: characters),
    );
    if (!context.mounted ||
        selectedCharacters == null ||
        selectedCharacters.isEmpty) {
      return;
    }
    await controller.bulkBindWorldBooks(
      entryIds: _selectedEntryIds,
      characterIds: selectedCharacters,
    );
    if (!mounted) {
      return;
    }
    setState(() => _selectedEntryIds.clear());
    messenger.showSnackBar(
      const SnackBar(content: Text('世界书已批量绑定角色。')),
    );
  }

  Future<void> _setSelectedGlobal(BuildContext context, bool global) async {
    final controller = context.read<AppStateController>();
    final messenger = ScaffoldMessenger.of(context);
    await controller.bulkSetWorldBookGlobal(
      entryIds: _selectedEntryIds,
      global: global,
    );
    if (!mounted) {
      return;
    }
    setState(() => _selectedEntryIds.clear());
    messenger.showSnackBar(
      SnackBar(content: Text(global ? '世界书已批量设为全局。' : '世界书已取消全局。')),
    );
  }
}

class _WorldBookGroup {
  const _WorldBookGroup(this.key, this.entries);

  final String key;
  final List<WorldBookEntry> entries;
}

class _WorldBookEmpty extends StatelessWidget {
  const _WorldBookEmpty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.menu_book_rounded,
            size: 64,
            color: AppTheme.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            AppTheme.glitchText('还没有世界书条目'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppTheme.glitchText('创建一条世界书设定来丰富角色的世界观。'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(AppTheme.glitchText('新建条目')),
          ),
        ],
      ),
    );
  }
}

class _WorldBookTriggerPreviewPanel extends StatelessWidget {
  const _WorldBookTriggerPreviewPanel({required this.items});

  final List<WorldBookPreviewItem> items;

  @override
  Widget build(BuildContext context) {
    final activeItems = items.where((item) => item.active).take(6).toList();
    final inactiveCount = items.where((item) => !item.active).length;
    return Container(
      decoration: AppTheme.glassPanel(highlighted: activeItems.isNotEmpty),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.rule_folder_outlined, color: AppTheme.activeSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText('本轮世界书触发预览'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Chip(
                label: Text(AppTheme.glitchText('命中 ${activeItems.length}')),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppTheme.glitchText(
              activeItems.isEmpty
                  ? '当前上下文暂未命中关键词/正则世界书，常驻条目会继续按规则注入。'
                  : '根据最近对话、状态面板和地图上下文预估本轮注入条目。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              AppTheme.glitchText('还没有可预览的世界书条目。'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textWeak,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final item in items.take(10))
                  _WorldBookPreviewChip(item: item),
                if (inactiveCount > 0)
                  Chip(
                    avatar: const Icon(Icons.visibility_off_outlined, size: 16),
                    label: Text(AppTheme.glitchText('未命中 $inactiveCount')),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WorldBookPreviewChip extends StatelessWidget {
  const _WorldBookPreviewChip({required this.item});

  final WorldBookPreviewItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.active
        ? AppTheme.activeSoft
        : AppTheme.textMuted.withValues(alpha: 0.72);
    return Tooltip(
      message:
          '${item.reason}\n${item.position} · ${item.trigger} · 优先级 ${item.priority}',
      child: Chip(
        avatar: Icon(
          item.active ? Icons.bolt_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        label: Text(
          AppTheme.glitchText(item.title),
          overflow: TextOverflow.ellipsis,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _WorldBookToolbar extends StatelessWidget {
  const _WorldBookToolbar({
    required this.tags,
    required this.selectedTag,
    required this.batchMode,
    required this.selectedCount,
    required this.onTagSelected,
    required this.onSelectVisible,
    required this.onClearSelection,
    required this.onDelete,
    required this.onBind,
    required this.onGlobal,
    required this.onUnglobal,
  });

  final List<String> tags;
  final String selectedTag;
  final bool batchMode;
  final int selectedCount;
  final ValueChanged<String> onTagSelected;
  final VoidCallback onSelectVisible;
  final VoidCallback onClearSelection;
  final VoidCallback? onDelete;
  final VoidCallback? onBind;
  final VoidCallback? onGlobal;
  final VoidCallback? onUnglobal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassPanel(radius: 20),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilterChip(
                label: Text(AppTheme.glitchText('全部标签')),
                selected: selectedTag.isEmpty,
                onSelected: (_) => onTagSelected(''),
              ),
              for (final tag in tags)
                FilterChip(
                  label: Text(AppTheme.glitchText(tag)),
                  selected: selectedTag == tag,
                  onSelected: (_) => onTagSelected(tag),
                ),
            ],
          ),
          if (batchMode) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('已选 $selectedCount 条'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                OutlinedButton.icon(
                  onPressed: onSelectVisible,
                  icon: const Icon(Icons.select_all_rounded),
                  label: Text(AppTheme.glitchText('全选当前列表')),
                ),
                TextButton.icon(
                  onPressed: onClearSelection,
                  icon: const Icon(Icons.clear_rounded),
                  label: Text(AppTheme.glitchText('清空')),
                ),
                FilledButton.tonalIcon(
                  onPressed: onBind,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(AppTheme.glitchText('批量绑定')),
                ),
                OutlinedButton.icon(
                  onPressed: onGlobal,
                  icon: const Icon(Icons.public_rounded),
                  label: Text(AppTheme.glitchText('设为全局')),
                ),
                OutlinedButton.icon(
                  onPressed: onUnglobal,
                  icon: const Icon(Icons.public_off_rounded),
                  label: Text(AppTheme.glitchText('取消全局')),
                ),
                FilledButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(AppTheme.glitchText('删除所选')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorldBookGroupHeader extends StatelessWidget {
  const _WorldBookGroupHeader({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(Icons.sell_outlined, size: 18, color: AppTheme.activeSoft),
        const SizedBox(width: 8),
        Text(
          AppTheme.glitchText('$title · $count'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _WorldBookCard extends StatelessWidget {
  const _WorldBookCard({
    required this.entry,
    required this.collapseThreshold,
    required this.selected,
    required this.batchMode,
    required this.onSelectedChanged,
    required this.onOpenFull,
    required this.onEdit,
    required this.onDelete,
  });

  final WorldBookEntry entry;
  final int collapseThreshold;
  final bool selected;
  final bool batchMode;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onOpenFull;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppStateController>();
    final isDefault = entry.id == WorldBookEntry.defaultEntry().id;
    final trimmedContent = entry.content.trim();
    final shouldCollapse = trimmedContent.length > collapseThreshold;
    final previewContent = shouldCollapse
        ? '${trimmedContent.substring(0, collapseThreshold).trimRight()}...'
        : trimmedContent;

    String boundLabel;
    if (entry.global) {
      boundLabel = AppTheme.glitchText('全局');
    } else if (entry.boundCharacterIds.isEmpty) {
      boundLabel = AppTheme.glitchText('未绑定角色');
    } else {
      final names = entry.boundCharacterIds.map((id) {
        final character = controller.characters
            .where((c) => c.id == id)
            .map((c) => c.name)
            .firstOrNull;
        return character ?? id;
      }).join('、');
      boundLabel = names;
    }

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: AppTheme.glassPanel(highlighted: isDefault || selected),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (batchMode) ...<Widget>[
                    Checkbox(
                      value: selected,
                      onChanged: isDefault
                          ? null
                          : (value) => onSelectedChanged(value ?? false),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                entry.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                maxLines: MediaQuery.sizeOf(context).width < 620
                                    ? 2
                                    : 1,
                              ),
                            ),
                            if (isDefault) ...<Widget>[
                              const SizedBox(width: 8),
                              _WorldBookPill(
                                text: '系统',
                                color: AppTheme.activeAccent,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          boundLabel,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: entry.global
                                        ? AppTheme.activePrimary
                                        : AppTheme.textMuted,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            _WorldBookPill(
                              text: '注入：${entry.injectionPosition.label}',
                              color: AppTheme.activePrimary,
                            ),
                            _WorldBookPill(
                              text: '优先级 ${entry.priority}',
                              color: AppTheme.activeAccent,
                            ),
                          ],
                        ),
                        if (entry.tags.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: entry.tags
                                .map(
                                  (tag) => _WorldBookPill(
                                    text: tag,
                                    color: AppTheme.activePrimary,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isDefault && !batchMode) ...<Widget>[
                    IconButton(
                      tooltip: AppTheme.glitchText('编辑'),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      tooltip: AppTheme.glitchText('删除'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                      alpha: AppTheme.isBasicPaletteMode ? 0.035 : 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.activeLine.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  previewContent,
                  maxLines: shouldCollapse ? 7 : null,
                  overflow: shouldCollapse
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                        height: 1.6,
                      ),
                ),
              ),
              if (shouldCollapse) ...<Widget>[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: onOpenFull,
                    icon: const Icon(Icons.open_in_full_rounded),
                    label: Text(AppTheme.glitchText('展开完整世界书')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!batchMode || isDefault) {
      return card;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => onSelectedChanged(!selected),
      child: card,
    );
  }
}

class _WorldBookPill extends StatelessWidget {
  const _WorldBookPill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        AppTheme.glitchText(text),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _CharacterPickerDialog extends StatefulWidget {
  const _CharacterPickerDialog({required this.characters});

  final List<CharacterProfile> characters;

  @override
  State<_CharacterPickerDialog> createState() => _CharacterPickerDialogState();
}

class _CharacterPickerDialogState extends State<_CharacterPickerDialog> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(AppTheme.glitchText('批量绑定角色')),
      content: SizedBox(
        width: 420,
        child: widget.characters.isEmpty
            ? Text(
                AppTheme.glitchText('还没有可绑定的角色。'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.characters
                    .map(
                      (character) => CheckboxListTile(
                        value: _selected.contains(character.id),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(character.id);
                            } else {
                              _selected.remove(character.id);
                            }
                          });
                        },
                        title: Text(character.name),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(AppTheme.glitchText('绑定')),
        ),
      ],
    );
  }
}
