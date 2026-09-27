import 'package:flutter/foundation.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  static void pushBlock() {}

  static void popBlock() {}
}

class _RunnableCodePreviewState extends State<RunnableCodePreview> {
  late final WebViewController _controller;
  final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers =
      <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // The model document is stripped of scripts before this trusted bridge
      // runs, and its CSP blocks network access and inline event handlers.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'AiRoleplayBridge',
        onMessageReceived: (message) {
          final value = message.message.trim();
          if (value.isNotEmpty) {
            widget.onAction?.call(value);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('ai-roleplay-action:')) {
              final encoded = url.substring('ai-roleplay-action:'.length);
              final value = Uri.decodeComponent(encoded).trim();
              if (value.isNotEmpty) {
                widget.onAction?.call(value);
              }
              return NavigationDecision.prevent;
            }
            if (url.isEmpty ||
                url.startsWith('about:blank') ||
                url.startsWith('data:text/html')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _loadDocument();
  }

  @override
  void didUpdateWidget(covariant RunnableCodePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _loadDocument();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final resolvedHeight = min(widget.height, viewportHeight * 0.68)
        .clamp(260.0, 760.0)
        .toDouble();

    return SizedBox(
      width: double.infinity,
      height: resolvedHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: WebViewWidget(
          controller: _controller,
          gestureRecognizers: _gestureRecognizers,
        ),
      ),
    );
  }

  Future<void> _loadDocument() async {
    final document = widget.document.trim();
    if (document.isEmpty) {
      return;
    }
    await _controller.loadHtmlString(
      RunnableHtmlSandbox.build(
        document: document,
        trustedBridgeScript: _interactionBridge(),
      ),
    );
  }

  String _interactionBridge() {
    if (widget.onAction == null) {
      return '';
    }

    return '''
(function () {
  function send(payload) {
    var value = JSON.stringify(payload);
    if (window.AiRoleplayBridge && window.AiRoleplayBridge.postMessage) {
      window.AiRoleplayBridge.postMessage(value);
    } else {
      window.location.href = 'ai-roleplay-action:' + encodeURIComponent(value);
    }
  }
  function selectedItems() {
    var elements = document.querySelectorAll('[data-theater-choice][data-theater-selected="true"]');
    var values = [];
    for (var i = 0; i < elements.length; i++) {
      var element = elements[i];
      values.push((element.getAttribute('data-theater-label') || element.textContent || '').trim());
    }
    return values;
  }
  function findTheaterChoice(target) {
    if (!target || !target.closest) return null;
    return target.closest('[data-theater-choice]');
  }
  function findTheaterSubmit(target) {
    if (!target || !target.closest) return null;
    return target.closest('[data-theater-submit]');
  }
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
    var choice = findTheaterChoice(event.target);
    if (choice) {
      var group = choice.closest('[data-theater-group]') || document.body;
      var mode = group.getAttribute('data-choice-mode') || 'single';
      if (mode === 'single') {
        var selected = group.querySelectorAll('[data-theater-choice][data-theater-selected="true"]');
        for (var i = 0; i < selected.length; i++) {
          selected[i].setAttribute('data-theater-selected', 'false');
          selected[i].setAttribute('aria-pressed', 'false');
          selected[i].classList.remove('is-selected');
        }
      }
      var next = choice.getAttribute('data-theater-selected') !== 'true';
      choice.setAttribute('data-theater-selected', next ? 'true' : 'false');
      choice.setAttribute('aria-pressed', next ? 'true' : 'false');
      choice.classList.toggle('is-selected', next);
      event.preventDefault();
      event.stopPropagation();
      send({type: 'theater-selection', mode: mode, values: selectedItems()});
      return;
    }
    var submit = findTheaterSubmit(event.target);
    if (submit) {
      event.preventDefault();
      event.stopPropagation();
      send({type: 'theater-submit', values: selectedItems()});
      return;
    }
    var element = findActionElement(event.target);
    if (!element) return;
    var text = actionText(element);
    if (!text) return;
    event.preventDefault();
    send({type: 'action', value: text});
  }, true);
})();
''';
  }
}
