part of '../settings_screen.dart';

class _SaveSnapshotsDialog extends StatefulWidget {
  const _SaveSnapshotsDialog();

  @override
  State<_SaveSnapshotsDialog> createState() => _SaveSnapshotsDialogState();
}

class _SaveSnapshotsDialogState extends State<_SaveSnapshotsDialog> {
  final TextEditingController _titleController = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final snapshots = controller.recoverableSaveSnapshots;
    final liveCharacterIds =
        controller.allCharacters.map((item) => item.id).toSet();
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(AppTheme.glitchText('恢复中心')),
      content: SizedBox(
        width: min(size.width * 0.9, 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTheme.glitchText(
                '这里统一保留手动存档、自动保护和已删除剧场的快照。恢复已删除剧场时会作为新副本重新导入。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: AppTheme.glitchText('给这个保存点起个名字'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _working ? null : _createSnapshot,
                  icon: _working
                      ? const _TinySpinner()
                      : const Icon(Icons.add_rounded),
                  label: Text(AppTheme.glitchText('保存')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _working ? null : _generateCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(AppTheme.glitchText('生成当前进度封面')),
            ),
            const SizedBox(height: 16),
            if (snapshots.isEmpty)
              _SoftSettingsLine(
                icon: Icons.save_as_outlined,
                text: '还没有快照，先点保存做一个当前状态备份。',
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: size.height * 0.42),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: snapshots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final snapshot = snapshots[index];
                    return _SnapshotTile(
                      snapshot: snapshot,
                      characterDeleted:
                          !liveCharacterIds.contains(snapshot.characterId),
                      onRestore: () => _restoreSnapshot(snapshot),
                      onDelete: () => _deleteSnapshot(snapshot),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('关闭')),
        ),
      ],
    );
  }

  Future<void> _createSnapshot() async {
    setState(() => _working = true);
    final error = await context
        .read<AppStateController>()
        .createCurrentCharacterSnapshot(_titleController.text);
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _titleController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('存档快照已保存。')),
    );
  }

  Future<void> _generateCover() async {
    setState(() => _working = true);
    final controller = context.read<AppStateController>();
    final error = await controller.generateConversationToolReply(
      'cover',
      resultTitle: '剧情存档封面',
    );
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText(error))),
      );
      return;
    }
    final result = controller.lastGeneratedToolResult;
    if (result == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        AppTheme.glitchText(result.toolTitle),
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: AppTheme.glitchText('关闭'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: HtmlContentView(content: result.content)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreSnapshot(SaveSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: Text(AppTheme.glitchText('恢复存档快照')),
        content: Text(AppTheme.glitchText('要把当前角色恢复到「${snapshot.title}」吗？')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTheme.glitchText('恢复')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final error = await context
        .read<AppStateController>()
        .restoreSaveSnapshot(snapshot.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '已经恢复到这个存档点。')),
    );
  }

  Future<void> _deleteSnapshot(SaveSnapshot snapshot) async {
    await context.read<AppStateController>().deleteSaveSnapshot(snapshot.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('存档快照已删除。')),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  const _SnapshotTile({
    required this.snapshot,
    required this.characterDeleted,
    required this.onRestore,
    required this.onDelete,
  });

  final SaveSnapshot snapshot;
  final bool characterDeleted;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final createdAt = snapshot.createdAt.toLocal().toString().split('.').first;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFillStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: ListTile(
        leading:
            Icon(Icons.bookmark_added_outlined, color: AppTheme.activeSoft),
        title: Text(snapshot.title),
        subtitle: Text(
          '${snapshot.characterName} · $createdAt · ${_formatBytes(snapshot.sizeBytes)}'
          '${characterDeleted ? ' · 已删除剧场，可恢复' : ''}',
          maxLines: MediaQuery.sizeOf(context).width < 620 ? 3 : 1,
        ),
        trailing: Wrap(
          spacing: 4,
          children: <Widget>[
            IconButton(
              tooltip: AppTheme.glitchText('鎭㈠'),
              onPressed: onRestore,
              icon: const Icon(Icons.restore_rounded),
            ),
            IconButton(
              tooltip: AppTheme.glitchText('删除'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
