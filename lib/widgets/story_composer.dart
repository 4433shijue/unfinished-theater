import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_state_controller.dart';
import '../models/story_composer.dart';
import '../services/story_rewrite_service.dart';
import 'chat_input_bar.dart';
import 'story_workbench.dart';

class StoryComposer extends StatefulWidget {
  const StoryComposer(
      {super.key,
      required this.worldId,
      this.npcId,
      required this.isSending,
      required this.canPause,
      required this.hasPendingMessages,
      required this.onSend,
      required this.onLaunch,
      this.leading,
      this.enabled = true,
      this.disabledHint,
      this.edgeToEdge = false,
      this.tutorialTargetsEnabled = true,
      this.sendLabel = '发送',
      this.launchLabel = '提交并生成回复',
      this.draftText,
      this.draftVersion = 0,
      this.quickActions = const [],
      this.onQuickActionSelected});
  final String sendLabel, launchLabel;
  final String worldId;
  final String? npcId;
  final bool isSending,
      canPause,
      hasPendingMessages,
      enabled,
      edgeToEdge,
      tutorialTargetsEnabled;
  final String? disabledHint, draftText;
  final int draftVersion;
  final Widget? leading;
  final List<ChatQuickAction> quickActions;
  final ValueChanged<String>? onQuickActionSelected;
  final Future<String?> Function(String, StoryQuote?) onSend;
  final Future<void> Function() onLaunch;
  @override
  State<StoryComposer> createState() => StoryComposerState();
}

class StoryComposerState extends State<StoryComposer> {
  late AppStateController _app;
  String _text = '';
  StoryQuote? _quote;
  String? _original;
  String? _error;
  int _version = 0, _editRevision = 0, _session = 0;
  bool _loaded = false, _helping = false;
  Timer? _saveTimer;
  @override
  void initState() {
    super.initState();
    _app = context.read<AppStateController>();
    _load();
  }

  Future<void> _load() async {
    final session = ++_session;
    try {
      final draft =
          await _app.loadComposerDraft(widget.worldId, npcId: widget.npcId);
      if (!mounted || session != _session) return;
      setState(() {
        _text = draft.text;
        _quote = draft.quote;
        _version++;
        _loaded = true;
      });
    } catch (e) {
      if (mounted && session == _session) {
        setState(() {
          _loaded = true;
          _error = '草稿读取失败：$e';
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant StoryComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldId != widget.worldId ||
        oldWidget.npcId != widget.npcId) {
      _saveTimer?.cancel();
      unawaited(_save(oldWidget.worldId, oldWidget.npcId,
          ComposerDraft(text: _text, quote: _quote)));
      _text = '';
      _quote = null;
      _original = null;
      _error = null;
      _loaded = false;
      _helping = false;
      _editRevision++;
      _version++;
      _load();
    } else if (oldWidget.draftVersion != widget.draftVersion &&
        widget.draftText != null) {
      _replace(widget.draftText!);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_loaded) {
      unawaited(_save(widget.worldId, widget.npcId,
          ComposerDraft(text: _text, quote: _quote)));
    }
    super.dispose();
  }

  Future<void> _save(String world, String? npc, ComposerDraft draft) async {
    try {
      await _app.saveComposerDraft(world, draft, npcId: npc);
      if (mounted &&
          widget.worldId == world &&
          widget.npcId == npc &&
          _text == draft.text) {
        setState(() => _error = null);
      }
    } catch (e) {
      if (mounted && widget.worldId == world && widget.npcId == npc) {
        setState(() => _error = '草稿尚未保存，可重试。$e');
      }
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    final world = widget.worldId, npc = widget.npcId;
    final draft = ComposerDraft(text: _text, quote: _quote);
    _app.rememberComposerDraft(world, draft, npcId: npc);
    _saveTimer = Timer(const Duration(milliseconds: 350),
        () => unawaited(_save(world, npc, draft)));
  }

  void _replace(String text) {
    _text = text;
    _version++;
    _editRevision++;
    _scheduleSave();
  }

  void setQuote(StoryQuote quote) {
    if (quote.worldId != widget.worldId || quote.npcId != widget.npcId) return;
    setState(() {
      _quote = quote;
      _editRevision++;
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final stale = _quote != null && !_app.quoteIsCurrent(_quote!);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_error != null)
        ListTile(
            dense: true,
            title: Text(_error!),
            trailing: TextButton(
                onPressed: () => _save(widget.worldId, widget.npcId,
                    ComposerDraft(text: _text, quote: _quote)),
                child: const Text('重试'))),
      if (_quote != null)
        ListTile(
            dense: true,
            leading: const Icon(Icons.format_quote),
            title: Text(_quote!.text,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle:
                stale ? const Text('原文已变化，请重新引用或取消') : const Text('正在回应这段话'),
            onTap: () => showQuoteSource(context, _quote!),
            trailing: IconButton(
                tooltip: '取消引用',
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _quote = null;
                    _editRevision++;
                  });
                  _scheduleSave();
                })),
      if (_original != null)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                icon: const Icon(Icons.undo),
                label: const Text('恢复原稿'),
                onPressed: () {
                  setState(() {
                    _replace(_original!);
                    _original = null;
                  });
                })),
      ChatInputBar(
        key: ValueKey('${widget.worldId}/${widget.npcId}'),
        sendLabel: widget.sendLabel,
        launchLabel: widget.launchLabel,
        draftText: _text,
        draftVersion: _version,
        onDraftChanged: (value) {
          _text = value;
          _editRevision++;
          _scheduleSave();
        },
        isSending: widget.isSending,
        canPause: widget.canPause,
        hasPendingMessages: widget.hasPendingMessages,
        enabled: widget.enabled && _loaded,
        disabledHint: widget.disabledHint,
        edgeToEdge: widget.edgeToEdge,
        tutorialTargetsEnabled: widget.tutorialTargetsEnabled,
        quickActions: widget.quickActions,
        onQuickActionSelected:
            widget.onQuickActionSelected ?? (s) => setState(() => _replace(s)),
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.leading != null) widget.leading!,
          PopupMenuButton<String>(
              tooltip: '写作小工具',
              icon: _helping
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.edit_note),
              onSelected: (value) {
                if (value == 'express') {
                  unawaited(_express());
                } else {
                  unawaited(_note());
                }
              },
              itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'express',
                        enabled: !_helping &&
                            !widget.isSending &&
                            widget.enabled &&
                            _loaded,
                        child: const Text('帮我说出来')),
                    PopupMenuItem(
                        value: 'note',
                        enabled: _loaded,
                        child: const Text('私人便签')),
                  ]),
        ]),
        onSend: (value) async {
          final session = _session;
          if (_quote != null && !_app.quoteIsCurrent(_quote!)) {
            throw StateError('引用原文已变化，请重新选择或取消。');
          }
          final error = await widget.onSend(value, _quote);
          if (error != null) throw StateError(error);
          if (!mounted || session != _session) return;
          setState(() {
            _quote = null;
            _original = null;
          });
        },
        onLaunch: widget.onLaunch,
      ),
    ]);
  }

  Future<void> _express() async {
    final session = _session, revision = _editRevision;
    final draft = ComposerDraft(text: _text, quote: _quote);
    if (draft.text.trim().isEmpty) {
      _notice('先在输入框写下你想表达的意思。');
      return;
    }
    setState(() => _helping = true);
    try {
      final results =
          await _app.helpExpress(widget.worldId, draft, npcId: widget.npcId);
      if (!mounted || session != _session) return;
      if (revision != _editRevision) {
        _notice('草稿已改变，本次候选未覆盖新内容。');
        return;
      }
      final chosen = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('帮我说出来'),
                  content: SizedBox(
                      width: 520,
                      child: SingleChildScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final text in results)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context, text),
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(text))))
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('保留原稿'))
                  ]));
      if (!mounted || session != _session || chosen == null) return;
      if (revision != _editRevision) {
        _notice('草稿已改变，请重新生成。');
        return;
      }
      setState(() {
        _original = draft.text;
        _replace(chosen);
      });
    } catch (e) {
      if (mounted && session == _session) _notice('$e');
    } finally {
      if (mounted && session == _session) setState(() => _helping = false);
    }
  }

  Future<void> _note() async {
    final session = _session, world = widget.worldId;
    try {
      final text = await _app.loadPrivateNote(world);
      if (!mounted || session != _session) return;
      final result = await showDialog<({String text, bool director})>(
          context: context,
          builder: (_) =>
              _PrivateNoteDialog(worldId: world, initial: text, app: _app));
      if (!mounted || session != _session || result == null) return;
      if (result.director) {
        await showDirectorPreferencesDialog(context, appendNote: result.text);
      } else {
        setState(() => _replace(
            _text.trim().isEmpty ? result.text : '$_text\n${result.text}'));
      }
    } catch (e) {
      if (mounted) _notice('$e');
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _PrivateNoteDialog extends StatefulWidget {
  const _PrivateNoteDialog(
      {required this.worldId, required this.initial, required this.app});
  final String worldId, initial;
  final AppStateController app;
  @override
  State<_PrivateNoteDialog> createState() => _PrivateNoteDialogState();
}

class _PrivateNoteDialogState extends State<_PrivateNoteDialog> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initial);
  Timer? _timer;
  String? _error;
  bool _saving = false;
  int _revision = 0;
  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    _timer?.cancel();
    final revision = _revision, value = _text.text;
    if (mounted) setState(() => _saving = true);
    try {
      await widget.app.savePrivateNote(widget.worldId, value);
      if (mounted && revision == _revision) setState(() => _error = null);
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = '尚未保存，请重试：$e');
      return false;
    } finally {
      if (mounted && revision == _revision) setState(() => _saving = false);
    }
  }

  Future<void> _finish({bool? director}) async {
    final selection = _text.selection;
    final value = selection.isValid && !selection.isCollapsed
        ? selection.textInside(_text.text)
        : _text.text;
    if (!await _save() || !mounted) return;
    Navigator.pop(
        context, director == null ? null : (text: value, director: director));
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: AlertDialog(
          title: const Text('私人便签'),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('仅你可见。选中文字后可带入输入框或导演台；未选中时使用整张便签。'),
                TextField(
                    controller: _text,
                    minLines: 5,
                    maxLines: 12,
                    maxLength: 12000,
                    onChanged: (_) {
                      _revision++;
                      widget.app
                          .rememberPrivateNote(widget.worldId, _text.text);
                      _timer?.cancel();
                      _timer = Timer(const Duration(milliseconds: 450),
                          () => unawaited(_save()));
                    }),
                if (_error != null)
                  Text(_error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error))
                else
                  Text(_saving ? '保存中…' : '更改后自动保存'),
              ]))),
          actions: [
            TextButton(
                onPressed: () => _finish(),
                child: Text(_error == null ? '关闭' : '重试保存并关闭')),
            TextButton(
                onPressed: () => _finish(director: true),
                child: const Text('带入导演台')),
            FilledButton(
                onPressed: () => _finish(director: false),
                child: const Text('带入输入框')),
          ]));
}

Future<StoryQuote?> selectStoryQuote(
    BuildContext context, String messageId, String raw,
    {String? selection, String? npcId}) async {
  final app = context.read<AppStateController>();
  final worldId = app.currentCharacter?.id;
  String? text = selection?.trim();
  if (text == null || text.isEmpty) {
    final targets = StoryRewriteService.targets(messageId, raw, npcId: npcId);
    text = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('选择要接的话'),
                content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final t in targets)
                        ListTile(
                            title: Text(t.selectedText),
                            onTap: () => Navigator.pop(context, t.selectedText))
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'))
                ]));
  }
  if (text == null || text.isEmpty) return null;
  if (worldId != app.currentCharacter?.id) return null;
  return app.makeStoryQuote(messageId, raw, text, npcId: npcId);
}

Future<void> showQuoteSource(BuildContext context, StoryQuote quote) {
  final app = context.read<AppStateController>();
  final raw = app.quoteSource(quote);
  final current = app.quoteIsCurrent(quote);
  final paragraphs = raw == null
      ? <String>[]
      : StoryRewriteService.targets(quote.messageId, raw, npcId: quote.npcId)
          .map((t) => t.selectedText)
          .toList();
  final matched = paragraphs.where((p) => p.contains(quote.text)).firstOrNull;
  return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(current ? '引用来源' : '引用来源已变化或删除'),
              content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                      child: SelectableText(
                          current ? matched ?? quote.text : quote.text))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'))
              ]));
}
