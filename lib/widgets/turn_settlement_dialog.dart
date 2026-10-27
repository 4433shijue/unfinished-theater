import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_state_controller.dart';
import '../models/turn_settlement.dart';

Future<void> showTurnSettlement(
    BuildContext context, TurnSettlement settlement) async {
  final controller = context.read<AppStateController>();
  final child = ChangeNotifierProvider.value(
      value: controller, child: TurnSettlementPanel(settlement: settlement));
  if (MediaQuery.sizeOf(context).width < 600) {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 1),
        useSafeArea: true,
        builder: (c) =>
            SizedBox(height: MediaQuery.sizeOf(c).height * .78, child: child));
  } else {
    await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
            backgroundColor:
                Theme.of(c).colorScheme.surface.withValues(alpha: 1),
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 620, maxHeight: 720),
                child: child)));
  }
}

class TurnSettlementPanel extends StatefulWidget {
  const TurnSettlementPanel({super.key, required this.settlement});
  final TurnSettlement settlement;
  @override
  State<TurnSettlementPanel> createState() => _TurnSettlementPanelState();
}

class _TurnSettlementPanelState extends State<TurnSettlementPanel> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final s = widget.settlement;
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(s.complete ? '本回合结算' : '结算未完成',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    tooltip: '关闭结算',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
              const SizedBox(height: 8),
              Flexible(
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    if (!s.complete) Text(s.error),
                    if (s.complete && s.entries.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('本回合没有可公开的状态变化。')),
                    for (final category in s.entries
                        .map((e) => '${e['category']}')
                        .toSet()) ...[
                      Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 6),
                          child: Text(category,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      for (final e
                          in s.entries.where((e) => e['category'] == category))
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${e['label']}${e.containsKey('after') ? '：${e['before'] ?? ''}${e['before'] != null && '${e['before']}'.isNotEmpty ? ' → ' : ''}${e['after']}' : ''}${e['delta'] is num ? '（${(e['delta'] as num) > 0 ? '+' : ''}${e['delta']}）' : ''}'),
                                  if ('${e['reason'] ?? ''}'.isNotEmpty)
                                    Text('${e['reason']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                ]))
                    ],
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ]))),
              const SizedBox(height: 16),
              if (!s.complete)
                Wrap(spacing: 12, children: [
                  FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => context
                              .read<AppStateController>()
                              .retryTurnSettlement(s.turnId)),
                      child: Text(_busy ? '正在结算…' : '重试结算')),
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await context
                                    .read<AppStateController>()
                                    .deleteMessage(s.turnId);
                                return null;
                              }),
                      child: const Text('回到上一回合')),
                ])
              else
                Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('继续阅读'))),
            ]));
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final error = await action();
      if (!mounted) return;
      if (error == null) {
        Navigator.pop(context);
      } else {
        setState(() => _error = error);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
