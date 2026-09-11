part of '../settings_screen.dart';

class _ImportDataDialogResult {
  const _ImportDataDialogResult({
    required this.content,
    required this.replaceExisting,
  });

  final String content;
  final bool replaceExisting;
}

class _ImportDataDialog extends StatefulWidget {
  const _ImportDataDialog();

  @override
  State<_ImportDataDialog> createState() => _ImportDataDialogState();
}

class _ImportDataDialogState extends State<_ImportDataDialog> {
  static const int _inlineTextLimit = 512 * 1024;
  static const int _livePreviewLimit = 768 * 1024;

  late final TextEditingController _controller;
  Timer? _previewDebounce;
  bool _replaceExisting = false;
  bool _isPickingFile = false;
  bool _suppressPreviewRefresh = false;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _selectedFileContent;
  String? _fileMessage;
  DataArchivePreview? _preview;
  String? _previewError;
  int _previewRequestId = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: AppTheme.panel,
      title: Text(AppTheme.glitchText('导入数据')),
      content: SizedBox(
        width: min(MediaQuery.sizeOf(context).width * 0.9, 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTheme.glitchText(
                  '可以选择导出的 JSON 存档文件，也可以把存档内容粘贴到下面。默认是合并导入，不会清空当前设备数据。'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.translucentPanelFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.activeLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: _isPickingFile ? null : _pickArchiveFile,
                        icon: _isPickingFile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: Text(AppTheme.glitchText(
                          _isPickingFile ? '读取中...' : '选择存档文件',
                        )),
                      ),
                      OutlinedButton.icon(
                        onPressed: _effectiveImportContent.isEmpty
                            ? null
                            : _clearInput,
                        icon: const Icon(Icons.clear_rounded),
                        label: Text(AppTheme.glitchText('清空内容')),
                      ),
                    ],
                  ),
                  if (_selectedFileName != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      AppTheme.glitchText(
                        '已读取：$_selectedFileName${_selectedFileSize == null ? '' : ' 路 ${_formatBytes(_selectedFileSize!)}'}',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.selectedTintIcon,
                      ),
                    ),
                  ],
                  if (_fileMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      AppTheme.glitchText(_fileMessage!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 7,
              maxLines: 12,
              enabled: _selectedFileContent == null,
              decoration: InputDecoration(
                hintText: AppTheme.glitchText(
                  _selectedFileContent == null
                      ? '{ "schemaVersion": 1, ... }'
                      : '已读取较大的存档文件，为避免卡顿不在这里展开。',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_outlined),
                  label: Text(AppTheme.glitchText('从剪贴板粘贴')),
                ),
                FilterChip(
                  label: Text(AppTheme.glitchText('覆盖当前数据')),
                  selected: _replaceExisting,
                  onSelected: (value) =>
                      setState(() => _replaceExisting = value),
                ),
              ],
            ),
            if (_preview != null || _previewError != null) ...<Widget>[
              const SizedBox(height: 12),
              _ImportPreviewCard(
                preview: _preview,
                error: _previewError,
              ),
            ],
            if (_replaceExisting) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText('覆盖会把当前角色列表、NPC、世界书、背包等替换成导入存档。建议先导出备份。'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.activeSoft,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton.icon(
          onPressed: _isPickingFile ||
                  _previewError != null ||
                  (_preview != null && !_preview!.canImport)
              ? null
              : _submit,
          icon: const Icon(Icons.file_upload_outlined),
          label: Text(AppTheme.glitchText('开始导入')),
        ),
      ],
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      setState(() => _fileMessage = '剪贴板里没有可用文本。');
      return;
    }
    if (text.length > maxArchiveImportBytes ~/ 3) {
      setState(() => _fileMessage = '剪贴板内容过大，请改用 64MB 以内的存档文件。');
      return;
    }
    setState(() {
      _selectedFileContent = null;
      _suppressPreviewRefresh = true;
      _controller.text = text;
      _suppressPreviewRefresh = false;
      _selectedFileName = null;
      _selectedFileSize = null;
      _fileMessage = '已从剪贴板填入存档内容。';
    });
    _refreshPreviewForContent(text);
  }

  Future<void> _pickArchiveFile() async {
    setState(() {
      _isPickingFile = true;
      _fileMessage = null;
    });
    try {
      final file = await pickArchiveFileData(maxBytes: maxArchiveImportBytes);
      if (file == null) {
        setState(() => _fileMessage = '没有选择文件。');
        return;
      }
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        setState(() => _fileMessage = '这个文件没有读到内容。');
        return;
      }
      final content = utf8.decode(bytes, allowMalformed: true).trim();
      if (content.length > _inlineTextLimit) {
        setState(() {
          _selectedFileContent = content;
          _suppressPreviewRefresh = true;
          _controller.clear();
          _suppressPreviewRefresh = false;
          _selectedFileName = file.name;
          _selectedFileSize = file.size;
          _fileMessage =
              '已读取大文件（${_formatBytes(content.length)}），不会展开到输入框；点开始导入会直接使用该文件。';
        });
        _refreshPreviewForContent(content, fromLargeFile: true);
        return;
      }
      if (content.isEmpty) {
        setState(() => _fileMessage = '这个文件是空的。');
        return;
      }
      setState(() {
        _selectedFileContent = null;
        _suppressPreviewRefresh = true;
        _controller.text = content;
        _suppressPreviewRefresh = false;
        _selectedFileName = file.name;
        _selectedFileSize = file.size;
        _fileMessage = '文件内容已填入下方，确认无误后点开始导入。';
      });
      _refreshPreviewForContent(content);
    } catch (error) {
      setState(() => _fileMessage = '读取文件失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
      }
    }
  }

  void _clearInput() {
    setState(() {
      _controller.clear();
      _selectedFileName = null;
      _selectedFileSize = null;
      _selectedFileContent = null;
      _fileMessage = '已清空导入内容。';
      _preview = null;
      _previewError = null;
    });
  }

  void _submit() {
    final text = _effectiveImportContent;
    if (text.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _ImportDataDialogResult(
        content: text,
        replaceExisting: _replaceExisting,
      ),
    );
  }

  void _refreshPreview() {
    if (_suppressPreviewRefresh) {
      return;
    }
    _previewDebounce?.cancel();
    _selectedFileContent = null;
    _selectedFileName = null;
    _selectedFileSize = null;
    final text = _controller.text.trim();
    if (!mounted) {
      return;
    }
    if (text.isEmpty) {
      setState(() {
        _preview = null;
        _previewError = null;
      });
      return;
    }
    if (text.length > _livePreviewLimit) {
      setState(() {
        _preview = null;
        _previewError = '内容比较大，已暂停实时预览，点击开始导入会直接处理。';
      });
      return;
    }
    _previewDebounce = Timer(const Duration(milliseconds: 260), () {
      if (mounted) {
        _refreshPreviewForContent(text);
      }
    });
  }

  Future<void> _refreshPreviewForContent(
    String text, {
    bool fromLargeFile = false,
  }) async {
    if (!mounted) {
      return;
    }
    final requestId = ++_previewRequestId;
    if (!fromLargeFile && text.length > _livePreviewLimit) {
      setState(() {
        _preview = null;
        _previewError = '大文件已读取，已跳过实时预览以保持页面流畅。开始导入时会直接解析完整文件。';
      });
      return;
    }
    try {
      setState(() {
        _preview = null;
        _previewError = fromLargeFile ? '正在后台预览大文件概要...' : null;
      });
      final preview =
          await context.read<AppStateController>().previewDataArchive(text);
      if (!mounted || requestId != _previewRequestId) {
        return;
      }
      setState(() {
        _preview = preview;
        _previewError = null;
      });
    } on FormatException catch (error) {
      if (!mounted || requestId != _previewRequestId) {
        return;
      }
      setState(() {
        _preview = null;
        _previewError = error.message;
      });
    } catch (error) {
      if (!mounted || requestId != _previewRequestId) {
        return;
      }
      setState(() {
        _preview = null;
        _previewError = '预览失败：$error';
      });
    }
  }

  String get _effectiveImportContent =>
      (_selectedFileContent ?? _controller.text).trim();
}

class _ImportPreviewCard extends StatelessWidget {
  const _ImportPreviewCard({
    required this.preview,
    required this.error,
  });

  final DataArchivePreview? preview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (error != null) {
      final errorColor = theme.colorScheme.error;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: errorColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: errorColor.withValues(alpha: 0.34)),
        ),
        child: Text(
          AppTheme.glitchText(error!),
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      );
    }

    final data = preview;
    if (data == null) {
      return const SizedBox.shrink();
    }
    final exportedAt = data.exportedAt == null
        ? '时间未知'
        : data.exportedAt!.toLocal().toString().split('.').first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.activePrimary.withValues(alpha: 0.26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTheme.glitchText('导入前预览'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _PreviewChip(label: '范围', value: data.scopeLabel),
              _PreviewChip(
                  label: '版本',
                  value: data.appVersion.isEmpty ? '未知' : data.appVersion),
              _PreviewChip(label: '导出时间', value: exportedAt),
              _PreviewChip(
                label: '完整性',
                value: data.hasIntegrityChecksum
                    ? (data.checksumValid ? '校验通过' : '校验失败，禁止导入')
                    : '旧版存档，无校验码',
              ),
              if (!data.schemaSupported)
                const _PreviewChip(label: '兼容性', value: '版本过新，禁止导入'),
              _PreviewChip(label: '角色', value: '${data.characterCount}'),
              _PreviewChip(label: '聊天消息', value: '${data.historyMessageCount}'),
              _PreviewChip(label: 'NPC', value: '${data.npcCount}'),
              _PreviewChip(label: 'NPC 消息', value: '${data.npcMessageCount}'),
              _PreviewChip(label: '带走记录', value: '${data.npcMigrationCount}'),
              _PreviewChip(label: '世界书', value: '${data.worldBookCount}'),
              _PreviewChip(label: '剧情工具', value: '${data.toolResultCount}'),
              _PreviewChip(label: '同人文', value: '${data.fanficResultCount}'),
              _PreviewChip(label: '用户人设', value: '${data.userProfileCount}'),
              if (data.includeApiSecrets)
                const _PreviewChip(label: 'API Key', value: '包含'),
              if (data.hasGamification)
                const _PreviewChip(label: '背包成就', value: '包含'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFillStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width < 520 ? 220 : 360,
        ),
        child: Text(
          AppTheme.glitchText('$label：$value'),
          maxLines: MediaQuery.sizeOf(context).width < 520 ? 3 : 2,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
      ),
    );
  }
}
