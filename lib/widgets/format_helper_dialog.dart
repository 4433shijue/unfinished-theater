import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class FormatHelperDialog extends StatefulWidget {
  const FormatHelperDialog({
    super.key,
    this.initialText = '',
    this.saveMode = false,
  });

  final String initialText;
  final bool saveMode;

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const FormatHelperDialog(),
    );
  }

  static Future<String?> edit(
    BuildContext context, {
    required String initialText,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => FormatHelperDialog(
        initialText: initialText,
        saveMode: true,
      ),
    );
  }

  @override
  State<FormatHelperDialog> createState() => _FormatHelperDialogState();
}

class _FormatHelperDialogState extends State<FormatHelperDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _insertAtCursor(String text) {
    final selection = _controller.selection;
    final current = _controller.text;
    if (selection.isValid && selection.textInside(current).isNotEmpty) {
      // Replace selection
      final start = selection.start;
      final end = selection.end;
      _controller.text =
          current.substring(0, start) + text + current.substring(end);
      _controller.selection =
          TextSelection.collapsed(offset: start + text.length);
    } else {
      final rawOffset =
          selection.isValid ? selection.extentOffset : current.length;
      final offset = rawOffset.clamp(0, current.length).toInt();
      _controller.text =
          current.substring(0, offset) + text + current.substring(offset);
      _controller.selection =
          TextSelection.collapsed(offset: offset + text.length);
    }
    _focusNode.requestFocus();
  }

  void _copyToClipboard() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTheme.glitchText('已复制到剪贴板')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.code_rounded, color: AppTheme.activeSoft),
          const SizedBox(width: 10),
          Text(AppTheme.glitchText('格式编辑工具')),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Editable text area
              TextFormField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 6,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: AppTheme.glitchText('在这里编辑内容，或点下方按钮插入格式模板...'),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.activeLine),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: AppTheme.glassPanel(radius: 14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    AppTheme.glitchText(
                      '[GAME_STATE] 是给游戏面板解析的状态存档；[CHOICES] 是底部可点击选项；[BUBBLE] 可以把一段回复拆成多个气泡；```html 代码块``` 会被渲染成可预览面板。',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  IconButton(
                    tooltip: AppTheme.glitchText('清空'),
                    onPressed: () => _controller.clear(),
                    icon: const Icon(Icons.clear_all_rounded, size: 20),
                  ),
                  FilledButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(AppTheme.glitchText('复制到剪贴板')),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Quick insert buttons
              Text(
                AppTheme.glitchText('快速插入格式模板'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _InsertCard(
                label: '[GAME_STATE] ... [/GAME_STATE]',
                template:
                    '[GAME_STATE]\n时间：\n地点：\n状态：\n当前任务：\n人物数据：\n关系网：\nNPC变化：\n[/GAME_STATE]',
                onInsert: () => _insertAtCursor(
                    '[GAME_STATE]\n时间：\n地点：\n状态：\n当前任务：\n人物数据：\n关系网：\nNPC变化：\n[/GAME_STATE]'),
              ),
              const SizedBox(height: 8),
              _InsertCard(
                label: '[CHOICES] ... [/CHOICES]',
                template: '[CHOICES]\nA|\nB|\nC|\nD|\nE|\nF|\n[/CHOICES]',
                onInsert: () => _insertAtCursor(
                    '[CHOICES]\nA|\nB|\nC|\nD|\nE|\nF|\n[/CHOICES]'),
              ),
              const SizedBox(height: 8),
              _InsertCard(
                label: '[BUBBLE] ... [/BUBBLE]',
                template: '[BUBBLE]\n内容\n[/BUBBLE]',
                onInsert: () => _insertAtCursor('[BUBBLE]\n内容\n[/BUBBLE]'),
              ),
              const SizedBox(height: 8),
              _InsertCard(
                label: '```html ... ```',
                template: '```html\n\n```',
                onInsert: () => _insertAtCursor('```html\n\n```'),
              ),
              const SizedBox(height: 8),
              _InsertCard(
                label: 'data-prompt 按钮',
                template:
                    '<button class="rp-action" data-prompt="行动文本">按钮文字</button>',
                onInsert: () => _insertAtCursor(
                    '<button class="rp-action" data-prompt="行动文本">按钮文字</button>'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: widget.saveMode
              ? () => Navigator.of(context).pop(_controller.text)
              : () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText(widget.saveMode ? '保存' : '关闭')),
        ),
      ],
    );
  }
}

class _InsertCard extends StatelessWidget {
  const _InsertCard({
    required this.label,
    required this.template,
    required this.onInsert,
  });

  final String label;
  final String template;
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPanel(radius: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.activePrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontFamily: 'monospace',
                            color: AppTheme.activeSoft,
                            fontSize: 12,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.split('\n').take(2).join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppTheme.textWeak,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: FilledButton(
                onPressed: onInsert,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(AppTheme.glitchText('插入'),
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
