// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../services/runnable_html_sandbox.dart';

class RunnableCodePreview extends StatefulWidget {
  const RunnableCodePreview({
    super.key,
    required this.document,
    required this.height,
    this.onAction,
  });

  final String document;
  final double height;
  final ValueChanged<String>? onAction;

  @override
  State<RunnableCodePreview> createState() => _RunnableCodePreviewState();
}

class RunnableCodePreviewInteractionGuard {
  const RunnableCodePreviewInteractionGuard._();

  static final ValueNotifier<int> _blockDepth = ValueNotifier<int>(0);

  static bool get isBlocked => _blockDepth.value > 0;

  static void pushBlock() {
    _blockDepth.value += 1;
  }

  static void popBlock() {
    _blockDepth.value = (_blockDepth.value - 1).clamp(0, 1 << 30);
  }

  static void addListener(VoidCallback listener) {
    _blockDepth.addListener(listener);
  }

  static void removeListener(VoidCallback listener) {
    _blockDepth.removeListener(listener);
  }
}

class _RunnableCodePreviewState extends State<RunnableCodePreview> {
  static int _counter = 0;

  late String _viewType;
  late String _bridgeId;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  html.IFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    RunnableCodePreviewInteractionGuard.addListener(_applyPointerInterception);
    _registerFactory();
    _listenToMessages();
  }

  @override
  void didUpdateWidget(covariant RunnableCodePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _registerFactory();
    }
  }

  @override
  void dispose() {
    RunnableCodePreviewInteractionGuard.removeListener(
        _applyPointerInterception);
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: HtmlElementView(
          key: ValueKey<String>(_viewType),
          viewType: _viewType,
        ),
      ),
    );
  }

  void _registerFactory() {
    _viewType = 'runnable-preview-${_counter++}';
    _bridgeId = 'bridge-$_viewType';
    final document = RunnableHtmlSandbox.build(
      document: widget.document,
      trustedBridgeScript: _interactionBridge(_bridgeId),
    );
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final iframe = html.IFrameElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..style.backgroundColor = '#ffffff'
        ..style.overflow = 'auto'
        ..srcdoc = document;

      _iframe = iframe;
      _applyPointerInterception();
      iframe.setAttribute('scrolling', 'yes');
      iframe.setAttribute(
        'sandbox',
        'allow-scripts',
      );
      return iframe;
    });
  }

  void _applyPointerInterception() {
    _iframe?.style.pointerEvents =
        RunnableCodePreviewInteractionGuard.isBlocked ? 'none' : 'auto';
  }

  void _listenToMessages() {
    if (widget.onAction == null || _messageSubscription != null) {
      return;
    }

    _messageSubscription = html.window.onMessage.listen((event) {
      if (event.source != _iframe?.contentWindow || event.origin != 'null') {
        return;
      }
      final data = event.data;
      if (data is! Map) {
        return;
      }
      if (data['type'] != 'ai-roleplay-action' || data['id'] != _bridgeId) {
        return;
      }
      final value = data['value']?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        widget.onAction?.call(value);
      }
    });
  }

  String _interactionBridge(String bridgeId) {
    if (widget.onAction == null) {
      return '';
    }

    final escapedBridgeId = bridgeId.replaceAll("'", r"\'");
    return '''
(function () {
  var bridgeId = '$escapedBridgeId';
  function findActionElement(target) {
    if (!target || !target.closest) return null;
    return target.closest('[data-prompt], [data-action], [data-ai-action], .rp-action, .rp-choice');
  }
  function actionText(element) {
    return (element.getAttribute('data-prompt') ||
      element.getAttribute('data-action') ||
      element.getAttribute('data-ai-action') ||
      element.textContent || '').trim();
  }
  document.addEventListener('click', function (event) {
    var element = findActionElement(event.target);
    if (!element) return;
    var text = actionText(element);
    if (!text) return;
    event.preventDefault();
    window.parent.postMessage({
      type: 'ai-roleplay-action',
      id: bridgeId,
      value: text
    }, '*');
  }, true);
})();
''';
  }
}
