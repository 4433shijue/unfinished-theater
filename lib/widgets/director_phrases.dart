import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_state_controller.dart';

class DirectorPhrases extends StatelessWidget {
  const DirectorPhrases({super.key, required this.note});
  final TextEditingController note;
  static const builtins = {
    '停留在这一刻': '这轮停留在当前场景，展开眼前的互动，不急着跳时间或切场景。',
    '留出接话空间': '在适合我回应的位置停下，别替我回答或一口气完成整场对话。',
    '让 TA 主动一点': '让当前互动对象按自己的性格主动提出想法或行动，把我的回应留给我。',
  };
  void _append(String value) {
    note.text = note.text.trim().isEmpty ? value : '${note.text}\n$value';
    note.selection = TextSelection.collapsed(offset: note.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final phrases =
        context.watch<AppStateController>().settings.directorPhrases;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('常用导演短语'),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final entry in builtins.entries)
          ActionChip(
              label: Text(entry.key), onPressed: () => _append(entry.value)),
        for (final entry in phrases.entries)
          InputChip(
              label: Text(entry.key),
              onPressed: () => _append(entry.value),
              deleteIcon: const Icon(Icons.edit, size: 16),
              deleteButtonTooltipMessage: '编辑或删除',
              onDeleted: () =>
                  _edit(context, name: entry.key, text: entry.value)),
        ActionChip(
            label: const Text('保存当前补充'),
            avatar: const Icon(Icons.add, size: 16),
            onPressed: () => _edit(context, text: note.text)),
      ]),
    ]);
  }

  Future<void> _edit(BuildContext context,
      {String? name, String text = ''}) async {
    await showDialog<void>(
        context: context,
        builder: (_) => _PhraseEditor(name: name, text: text));
  }
}

class _PhraseEditor extends StatefulWidget {
  const _PhraseEditor({this.name, required this.text});
  final String? name;
  final String text;
  @override
  State<_PhraseEditor> createState() => _PhraseEditorState();
}

class _PhraseEditorState extends State<_PhraseEditor> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _text = TextEditingController(text: widget.text);
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    final app = context.read<AppStateController>();
    final name = _name.text.trim();
    if (!delete && (name.isEmpty || _text.text.trim().isEmpty)) {
      setState(() => _error = '请填写名称和短语内容。');
      return;
    }
    if (!delete &&
        name != widget.name &&
        app.settings.directorPhrases.containsKey(name)) {
      setState(() => _error = '这个名称已存在，请换一个。');
      return;
    }
    setState(() => _busy = true);
    try {
      await app.saveDirectorPhrase(delete ? '' : name, delete ? '' : _text.text,
          previousName: widget.name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: 1),
          title: Text(widget.name == null ? '保存常用短语' : '编辑常用短语'),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: _name,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: '名称')),
                TextField(
                    controller: _text,
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: '导演补充')),
                if (_error != null) Text(_error!),
              ]))),
          actions: [
            if (widget.name != null)
              TextButton(
                  onPressed: _busy ? null : () => _save(delete: true),
                  child: const Text('删除')),
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
                onPressed: _busy ? null : _save, child: const Text('保存')),
          ]);
}
