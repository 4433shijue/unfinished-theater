import 'package:flutter/material.dart';

import '../models/inline_theater_settings.dart';
import '../services/html_interaction_bridge.dart';
import 'runnable_code_preview.dart';

class InlineTheaterSettingsEditor extends StatefulWidget {
  const InlineTheaterSettingsEditor(
      {super.key,
      required this.value,
      required this.onChanged,
      this.available = true});
  final InlineTheaterSettings value;
  final ValueChanged<InlineTheaterSettings> onChanged;
  final bool available;

  @override
  State<InlineTheaterSettingsEditor> createState() =>
      _InlineTheaterSettingsEditorState();
}

class _InlineTheaterSettingsEditorState
    extends State<InlineTheaterSettingsEditor> {
  late final TextEditingController _prompt =
      TextEditingController(text: widget.value.customPrompt);

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  void _update({bool? enabled, InlineTheaterMode? mode, List<String>? themes}) {
    widget.onChanged(InlineTheaterSettings(
        enabled: enabled ?? widget.value.enabled,
        mode: mode ?? widget.value.mode,
        themeIds: themes ?? widget.value.themeIds,
        customPrompt: _prompt.text));
  }

  Future<void> _fillExample() async {
    if (_prompt.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('提示词示例'),
                  content: const SingleChildScrollView(
                      child: Text(InlineTheaterSettings.promptExample)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('保留我的内容')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('用示例替换'))
                  ]));
      if (replace != true || !mounted) return;
    }
    _prompt.text = InlineTheaterSettings.promptExample;
    _update();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('每回合番外'),
          subtitle: Text(
              widget.available ? '正文后附赠一个可点击的小剧场，不影响主线。' : '教程和大型群聊模式不生成番外窗口。'),
          value: widget.available && value.enabled,
          onChanged: widget.available ? (v) => _update(enabled: v) : null),
      if (widget.available && value.enabled) ...[
        Wrap(spacing: 8, children: [
          for (final mode in InlineTheaterMode.values)
            ChoiceChip(
                label: Text(switch (mode) {
                  InlineTheaterMode.single => '固定一个',
                  InlineTheaterMode.multiple => '多个轮换',
                  InlineTheaterMode.custom => '自定义'
                }),
                selected: value.mode == mode,
                onSelected: (_) => _update(
                    mode: mode,
                    themes: mode == InlineTheaterMode.single &&
                            value.themeIds.length > 1
                        ? [value.themeIds.first]
                        : null)),
        ]),
        const SizedBox(height: 8),
        if (value.mode != InlineTheaterMode.custom) ...[
          Text(value.mode == InlineTheaterMode.multiple
              ? '按勾选顺序轮换，每回合一个。'
              : '每回合使用这个主题。'),
          Wrap(spacing: 8, children: [
            for (final theme in InlineTheaterTheme.values)
              FilterChip(
                  label: Text(theme.label),
                  selected: value.themeIds.contains(theme.name),
                  onSelected: (selected) {
                    final next = [...value.themeIds];
                    if (value.mode == InlineTheaterMode.single) {
                      next.clear();
                    }
                    if (selected) {
                      next.add(theme.name);
                    } else {
                      next.remove(theme.name);
                    }
                    _update(themes: next);
                  }),
          ]),
          if (value.mode == InlineTheaterMode.multiple &&
              value.themeIds.isNotEmpty)
            Text(
                '轮换顺序：${value.themeIds.map((id) => InlineTheaterTheme.values.firstWhere((t) => t.name == id).label).join(' → ')}',
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
        TextFormField(
            controller: _prompt,
            minLines: 3,
            maxLines: 7,
            maxLength: 1200,
            decoration: InputDecoration(
                labelText: value.mode == InlineTheaterMode.custom
                    ? '想看什么番外'
                    : '补充你的口味（可选）',
                hintText: '写下人物、氛围、题材，以及希望点击后看到什么。'),
            onChanged: (_) => _update(),
            validator: (_) => widget.available && !widget.value.isValid
                ? '请选择主题，或填写番外提示词。'
                : null),
        Wrap(spacing: 8, children: [
          TextButton.icon(
              onPressed: _fillExample,
              icon: const Icon(Icons.edit_note),
              label: const Text('填入示例')),
          PopupMenuButton<InlineTheaterTheme>(
              tooltip: '查看可点击示例',
              itemBuilder: (_) => InlineTheaterTheme.values
                  .map((t) => PopupMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onSelected: (theme) => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                          title: Text('${theme.label} · 示例'),
                          content: SizedBox(
                              width: 460,
                              height: 440,
                              child: RunnableCodePreview(
                                  document: theme.exampleHtml,
                                  height: 440,
                                  interactionPolicy:
                                      HtmlInteractionPolicy.localOnly)),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('关闭'))
                          ])),
              child: const Padding(
                  padding: EdgeInsets.all(12), child: Text('查看可点击示例'))),
        ]),
      ],
    ]);
  }
}
