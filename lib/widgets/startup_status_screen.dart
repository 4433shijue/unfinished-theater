import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StartupStatusScreen extends StatelessWidget {
  const StartupStatusScreen.loading({
    super.key,
    required this.phase,
  })  : errorSummary = null,
        diagnostics = null,
        onRetry = null,
        retryLabel = '重新布景',
        failureMessage = null;

  const StartupStatusScreen.failure({
    super.key,
    required this.phase,
    required this.errorSummary,
    required this.diagnostics,
    required this.onRetry,
    this.retryLabel = '重新布景',
    this.failureMessage,
  });

  final String phase;
  final String? errorSummary;
  final String? diagnostics;
  final Future<void> Function()? onRetry;
  final String retryLabel;
  final String? failureMessage;

  bool get _hasError => errorSummary != null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _hasError
                        ? Icons.warning_amber_rounded
                        : Icons.theater_comedy_outlined,
                    size: 52,
                    color: _hasError ? colors.error : colors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _hasError ? '剧场布景没有完成' : '未完剧场',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _hasError
                        ? failureMessage ?? '存档没有被删除。可以直接重试；如果仍然失败，请复制诊断信息后再处理。'
                        : phase,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.6,
                        ),
                  ),
                  const SizedBox(height: 24),
                  if (_hasError)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.error.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '停在：$phase',
                            style: TextStyle(
                              color: colors.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorSummary!,
                            style: TextStyle(
                              color: colors.onErrorContainer,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  if (_hasError) ...<Widget>[
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () => unawaited(onRetry!()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(retryLabel),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => unawaited(
                            _copyDiagnostics(context, diagnostics!),
                          ),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('复制诊断'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyDiagnostics(
    BuildContext context,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('诊断信息已复制')),
    );
  }
}
