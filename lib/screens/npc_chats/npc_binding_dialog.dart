part of '../npc_chats_screen.dart';

class _NpcBindingDraft {
  const _NpcBindingDraft({
    required this.companionEnabled,
    required this.globalBinding,
    required this.boundCharacterIds,
  });

  final bool companionEnabled;
  final bool globalBinding;
  final List<String> boundCharacterIds;
}

class _NpcBindingDialog extends StatefulWidget {
  const _NpcBindingDialog({
    required this.profile,
    required this.characters,
  });

  final NpcProfile profile;
  final List<CharacterProfile> characters;

  @override
  State<_NpcBindingDialog> createState() => _NpcBindingDialogState();
}

class _NpcBindingDialogState extends State<_NpcBindingDialog> {
  late bool _companionEnabled;
  late bool _globalBinding;
  late final Set<String> _boundCharacterIds;

  @override
  void initState() {
    super.initState();
    _companionEnabled = widget.profile.companionEnabled;
    _globalBinding = widget.profile.globalBinding;
    _boundCharacterIds = <String>{
      if (widget.profile.boundCharacterIds.isEmpty)
        widget.profile.characterId
      else
        ...widget.profile.boundCharacterIds,
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 620;
    return AlertDialog(
      title: Text(AppTheme.glitchText('绑定 NPC')),
      content: SizedBox(
        width: compact ? size.width * 0.92 : 620,
        height: compact ? size.height * 0.62 : null,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: compact ? 12 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SwitchListTile(
                value: _companionEnabled,
                onChanged: (value) => setState(() => _companionEnabled = value),
                title: Text(AppTheme.glitchText('作为同行 NPC / 重要配角注入世界')),
                subtitle: Text(AppTheme.glitchText(
                    '开启后，主线会把这个 NPC 当作自主行动的同行者；玩家仍只操控自己的角色。')),
              ),
              SwitchListTile(
                value: _globalBinding,
                onChanged: !_companionEnabled
                    ? null
                    : (value) => setState(() => _globalBinding = value),
                title: Text(AppTheme.glitchText('全局绑定')),
                subtitle: Text(AppTheme.glitchText('开启后，这个 NPC 会默认跟随进入所有模拟器。')),
              ),
              const SizedBox(height: 10),
              Text(
                AppTheme.glitchText('指定绑定世界'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText('关闭全局绑定时，至少选择一个模拟器。'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 10),
              for (final character in widget.characters)
                CheckboxListTile(
                  value: _globalBinding
                      ? true
                      : _boundCharacterIds.contains(character.id),
                  onChanged: !_companionEnabled || _globalBinding
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              _boundCharacterIds.add(character.id);
                            } else {
                              _boundCharacterIds.remove(character.id);
                            }
                          });
                        },
                  title: Text(AppTheme.glitchText(character.name)),
                  subtitle: Text(
                    AppTheme.glitchText(character.description.trim().isEmpty
                        ? character.visibleBlurb
                        : character.description),
                    maxLines: compact ? 3 : 2,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: compact
          ? <Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(AppTheme.glitchText('保存绑定')),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppTheme.glitchText('取消')),
              ),
            ]
          : <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppTheme.glitchText('取消')),
              ),
              FilledButton(
                onPressed: _submit,
                child: Text(AppTheme.glitchText('保存绑定')),
              ),
            ],
    );
  }

  void _submit() {
    if (_companionEnabled && !_globalBinding && _boundCharacterIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('请至少选择一个绑定世界。'))),
      );
      return;
    }
    Navigator.of(context).pop(
      _NpcBindingDraft(
        companionEnabled: _companionEnabled,
        globalBinding: _globalBinding,
        boundCharacterIds: _globalBinding
            ? const <String>[]
            : _boundCharacterIds.toList(growable: false),
      ),
    );
  }
}

// ─── Thread Screen ───────────────────────────────────────────────────────────
