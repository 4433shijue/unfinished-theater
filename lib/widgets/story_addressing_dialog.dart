import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_state_controller.dart';

Future<void> showNpcAddressingDialog(BuildContext context, String npcId) =>
    showDialog<void>(
        context: context, builder: (_) => _AddressingDialog(npcId: npcId));

class _AddressingDialog extends StatefulWidget {
  const _AddressingDialog({required this.npcId});
  final String npcId;
  @override
  State<_AddressingDialog> createState() => _AddressingDialogState();
}

class _AddressingDialogState extends State<_AddressingDialog> {
  final _toNpc = TextEditingController(),
      _toPlayer = TextEditingController(),
      _condition = TextEditingController();
  late String _worldId;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final app = context.read<AppStateController>();
    _worldId = app.currentCharacter!.id;
    final values = app.npcAddressing(widget.npcId);
    _toNpc.text = values['toNpc'] ?? '';
    _toPlayer.text = values['toPlayer'] ?? '';
    _condition.text = values['condition'] ?? '';
  }

  @override
  void dispose() {
    _toNpc.dispose();
    _toPlayer.dispose();
    _condition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: 1),
          title: const Text('专属称呼'),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('只用于当前世界。可以留空；称呼不会自动改变你们的关系。'),
                TextField(
                    controller: _toNpc,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: '我称呼 TA')),
                TextField(
                    controller: _toPlayer,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'TA 称呼我')),
                TextField(
                    controller: _condition,
                    maxLength: 400,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: '使用条件（可选）', hintText: '例如独处时才使用，生气时恢复全名')),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          final app = context.read<AppStateController>();
                          if (app.currentCharacter?.id != _worldId) {
                            throw StateError('剧本已切换，请重新打开设置。');
                          }
                          await app.saveNpcAddressing(widget.npcId, {
                            'toNpc': _toNpc.text.trim(),
                            'toPlayer': _toPlayer.text.trim(),
                            'condition': _condition.text.trim()
                          });
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _error = '$e';
                              _saving = false;
                            });
                          }
                        }
                      },
                child: Text(_saving ? '保存中…' : '保存')),
          ]);
}
