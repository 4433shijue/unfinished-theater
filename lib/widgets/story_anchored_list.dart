import 'dart:async';
import 'package:flutter/material.dart';

/// Marks a rendered paragraph without introducing a layout or storage key.
class StoryReadingParagraph extends StatelessWidget {
  const StoryReadingParagraph(
      {super.key, required this.text, required this.child});
  final String text;
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// Lazy chat list with measured message anchors, shared by main and NPC chats.
class StoryAnchoredList extends StatefulWidget {
  const StoryAnchoredList(
      {super.key,
      required this.controller,
      required this.ids,
      required this.itemBuilder,
      required this.separatorBuilder,
      required this.onPosition,
      this.savedPosition = const {},
      this.padding = EdgeInsets.zero,
      this.scopeKey = '',
      this.readingActive,
      this.generating = false});
  final bool? readingActive;
  final ScrollController controller;
  final List<String> ids;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder separatorBuilder;
  final void Function(String id, double fraction, bool leaving) onPosition;
  final Map<String, dynamic> savedPosition;
  final EdgeInsets padding;
  final bool generating;
  final String scopeKey;
  @override
  State<StoryAnchoredList> createState() => StoryAnchoredListState();
}

class StoryAnchoredListState extends State<StoryAnchoredList>
    with WidgetsBindingObserver {
  final _keys = <String, GlobalKey>{};
  Timer? _saveTimer;
  Timer? _cueTimer;
  ({String id, String text, double y})? _returnPoint;
  Rect? _cue;
  int _visit = 0;
  bool _following = true;
  bool _jumping = false;
  bool _newContent = false;
  bool _restored = false;
  String? _anchorId;
  double _anchorFraction = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onScroll);
    _anchorId = widget.savedPosition['messageId']?.toString();
    _anchorFraction =
        (widget.savedPosition['fraction'] as num?)?.toDouble() ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_anchorId != null) {
        _following = false;
        await jumpToMessage(_anchorId!, fraction: _anchorFraction);
      } else {
        await goToLatest();
      }
      _restored = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _save(true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored && !_following && _anchorId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) jumpToMessage(_anchorId!, fraction: _anchorFraction);
      });
    }
  }

  @override
  void didUpdateWidget(StoryAnchoredList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey) {
      _visit++;
      _returnPoint = null;
      _cue = null;
      _cueTimer?.cancel();
    } else if (oldWidget.readingActive != widget.readingActive) {
      final visit = ++_visit;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || visit != _visit) return;
        if (widget.readingActive == false) {
          _rememberParagraph();
        } else if (widget.readingActive == true) {
          _restoreParagraph(visit);
        }
      });
    }
    if (oldWidget.scopeKey != widget.scopeKey) {
      _saveTimer?.cancel();
      if (_anchorId != null) {
        oldWidget.onPosition(_anchorId!, _anchorFraction, true);
      }
      _anchorId = widget.savedPosition['messageId']?.toString();
      _anchorFraction =
          (widget.savedPosition['fraction'] as num?)?.toDouble() ?? 0;
      _restored = false;
      _newContent = false;
      _following = _anchorId == null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (_anchorId != null) {
          await jumpToMessage(_anchorId!, fraction: _anchorFraction);
        } else {
          await goToLatest();
        }
        _restored = true;
      });
      return;
    }
    if (_anchorId != null &&
        !widget.ids.contains(_anchorId) &&
        widget.ids.isNotEmpty) {
      final oldIndex = oldWidget.ids.indexOf(_anchorId!);
      final nearest = widget.ids[oldIndex.clamp(0, widget.ids.length - 1)];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) jumpToMessage(nearest);
      });
    }
    if (widget.readingActive != false &&
        (oldWidget.ids.length != widget.ids.length || widget.generating)) {
      if (_following) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_jumping) goToLatest();
        });
      } else if (widget.ids.length > oldWidget.ids.length ||
          widget.generating) {
        _newContent = true;
      }
    }
  }

  @override
  void dispose() {
    _cueTimer?.cancel();
    _saveTimer?.cancel();
    _save(true);
    widget.controller.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<({String id, int index, double top, double height})> _visible() {
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return [];
    final origin = viewport.localToGlobal(Offset.zero).dy;
    final result = <({String id, int index, double top, double height})>[];
    for (final entry in _keys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy - origin;
      if (top + box.size.height > 0 && top < viewport.size.height) {
        result.add((
          id: entry.key,
          index: widget.ids.indexOf(entry.key),
          top: top,
          height: box.size.height
        ));
      }
    }
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  void _onScroll() {
    if (_cue != null) _clearCue();
    if (_jumping || !_restored || !widget.controller.hasClients) return;
    final atEnd = widget.controller.position.extentAfter < 80;
    if (atEnd != _following || (_newContent && atEnd)) {
      setState(() {
        _following = atEnd;
        if (atEnd) _newContent = false;
      });
    }
    // Scroll notifications precede lazy-list layout. Sample after that frame,
    // otherwise a large jump may persist a recycled item from the old viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_jumping && _restored) _capturePosition();
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _jumping) return;
      _capturePosition();
      _save(false);
    });
  }

  List<({String id, String text, Rect rect})> _paragraphs({String? only}) {
    final viewport = context.findRenderObject() as RenderBox;
    final result = <({String id, String text, Rect rect})>[];
    for (final entry in _keys.entries) {
      if (only != null && entry.key != only) continue;
      final item = entry.value.currentContext;
      if (item == null) continue;
      void visit(Element e) {
        final w = e.widget;
        if (w is StoryReadingParagraph) {
          final box = e.findRenderObject();
          if (box is RenderBox && box.attached && box.hasSize) {
            final xy = box.localToGlobal(Offset.zero, ancestor: viewport);
            result.add((id: entry.key, text: w.text, rect: xy & box.size));
          }
        } else {
          e.visitChildren(visit);
        }
      }

      item.visitChildElements(visit);
    }
    return result;
  }

  void _rememberParagraph() {
    _returnPoint = null;
    final all = _paragraphs();
    final height = (context.findRenderObject() as RenderBox).size.height;
    final p =
        all.where((p) => p.rect.bottom > 0 && p.rect.top < height).firstOrNull;
    if (p != null &&
        all.where((x) => x.id == p.id && x.text == p.text).length == 1) {
      _returnPoint = (id: p.id, text: p.text, y: p.rect.top);
    }
  }

  Future<void> _restoreParagraph(int visit) async {
    final point = _returnPoint;
    _returnPoint = null;
    if (point == null ||
        !widget.ids.contains(point.id) ||
        !widget.controller.hasClients) {
      return;
    }
    if (_keys[point.id]?.currentContext == null) await jumpToMessage(point.id);
    if (!mounted || _visit != visit) return;
    final matches =
        _paragraphs(only: point.id).where((p) => p.text == point.text).toList();
    if (matches.length != 1) return;
    final r = matches.single.rect, pos = widget.controller.position;
    final offset = (pos.pixels + r.top - point.y)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    final dy = offset - pos.pixels;
    if (dy.abs() > 1) widget.controller.jumpTo(offset);
    final y = (r.top - dy)
        .clamp(0.0, (context.findRenderObject() as RenderBox).size.height);
    if (r.bottom - dy <= y) return;
    setState(() => _cue = Rect.fromLTWH(
        (r.left - 5).clamp(0.0, double.infinity),
        y,
        2,
        (r.bottom - dy - y).clamp(0.0, 36.0)));
    _cueTimer?.cancel();
    _cueTimer = Timer(const Duration(milliseconds: 1600), _clearCue);
  }

  void _clearCue() {
    if (mounted && _cue != null) setState(() => _cue = null);
  }

  void _capturePosition() {
    final visible = _visible();
    if (visible.isNotEmpty) {
      _anchorId = visible.first.id;
      _anchorFraction =
          (-visible.first.top / visible.first.height).clamp(0.0, 1.0);
    }
  }

  void _save(bool leaving) {
    if (_anchorId != null) {
      widget.onPosition(_anchorId!, _anchorFraction, leaving);
    }
  }

  Future<void> goToLatest() async {
    if (!mounted || !widget.controller.hasClients) return;
    if (_jumping) return;
    _saveTimer?.cancel();
    _jumping = true;
    try {
      for (var i = 0; i < 16 && mounted && widget.controller.hasClients; i++) {
        widget.controller.jumpTo(widget.controller.position.maxScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || !widget.controller.hasClients) return;
        if (widget.controller.position.extentAfter < 1) break;
      }
    } finally {
      _jumping = false;
    }
    _following = true;
    _newContent = false;
    if (widget.ids.isNotEmpty) {
      _anchorId = widget.ids.last;
      _anchorFraction = 0;
    }
    if (mounted) setState(() {});
  }

  Future<void> jumpToMessage(String id, {double fraction = 0}) async {
    if (_jumping || widget.ids.isEmpty || !widget.controller.hasClients) return;
    var index = widget.ids.indexOf(id);
    if (index < 0) {
      final neighbors = [
        widget.savedPosition['nextId'],
        widget.savedPosition['previousId']
      ];
      index = neighbors
              .map((n) => widget.ids.indexOf(n?.toString() ?? ''))
              .where((i) => i >= 0)
              .firstOrNull ??
          ((widget.savedPosition['index'] as num?)?.toInt() ??
                  widget.ids.length - 1)
              .clamp(0, widget.ids.length - 1);
      id = widget.ids[index];
      fraction = 0;
    }
    _saveTimer?.cancel();
    _jumping = true;
    _following = false;
    try {
      double low = 0, high = widget.controller.position.maxScrollExtent;
      for (var attempt = 0; attempt < 60 && mounted; attempt++) {
        final itemContext = _keys[id]?.currentContext;
        if (itemContext != null && itemContext.mounted) {
          await Scrollable.ensureVisible(itemContext,
              alignment: 0, duration: Duration.zero);
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || !widget.controller.hasClients) {
            break;
          }
          final box = _keys[id]?.currentContext?.findRenderObject();
          if (box is RenderBox && box.hasSize) {
            final viewport = context.findRenderObject() as RenderBox;
            final top = box.localToGlobal(Offset.zero).dy -
                viewport.localToGlobal(Offset.zero).dy;
            final offset =
                widget.controller.offset + top + fraction * box.size.height;
            widget.controller.jumpTo(
                offset.clamp(0.0, widget.controller.position.maxScrollExtent));
          }
          _anchorId = id;
          _anchorFraction = fraction;
          _save(false);
          break;
        }
        final visible = _visible();
        if (visible.isNotEmpty) {
          if (index < visible.first.index) {
            high = widget.controller.offset;
          } else if (index > visible.last.index) {
            low = widget.controller.offset;
          }
        }
        high = high.clamp(low, widget.controller.position.maxScrollExtent);
        var offset = (low + high) / 2;
        if ((offset - widget.controller.offset).abs() < 1) {
          offset = (widget.controller.offset +
                  (visible.isNotEmpty && index < visible.first.index ? -1 : 1) *
                      widget.controller.position.viewportDimension)
              .clamp(0.0, widget.controller.position.maxScrollExtent);
          high = widget.controller.position.maxScrollExtent;
        }
        widget.controller.jumpTo(offset);
        await WidgetsBinding.instance.endOfFrame;
      }
    } finally {
      _jumping = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        ListView.separated(
            controller: widget.controller,
            padding: widget.padding,
            itemCount: widget.ids.length,
            separatorBuilder: widget.separatorBuilder,
            itemBuilder: (context, index) => KeyedSubtree(
                key: _keys.putIfAbsent(widget.ids[index], GlobalKey.new),
                child: widget.itemBuilder(context, index))),
        if (_cue case final rect?)
          Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                  child: ColoredBox(
                      key: const ValueKey('story-return-cue'),
                      color: Theme.of(context).colorScheme.primary))),
        if (_newContent)
          Positioned(
              bottom: 12,
              right: 12,
              child: FilledButton.tonalIcon(
                  onPressed: goToLatest,
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('有新内容'))),
      ]);
}
