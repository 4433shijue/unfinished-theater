part of '../settings_screen.dart';

class _SoftSettingsLine extends StatelessWidget {
  const _SoftSettingsLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black
            .withValues(alpha: AppTheme.isBasicPaletteMode ? 0.035 : 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppTheme.activeSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppTheme.glitchText(text),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    required this.padding,
    this.highlighted = false,
    super.key,
  });

  final Widget child;
  final double padding;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassPanel(highlighted: highlighted),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: child,
      ),
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.controller,
    required this.selectedModelId,
    required this.availableModels,
    required this.label,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String? selectedModelId;
  final List<String> availableModels;
  final String label;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String>(
          width: constraints.maxWidth,
          controller: controller,
          initialSelection: selectedModelId,
          label: Text(AppTheme.glitchText(label)),
          hintText: AppTheme.glitchText(
            availableModels.isEmpty ? '可手动输入模型名称' : '搜索并选择模型',
          ),
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          dropdownMenuEntries: availableModels
              .map(
                (modelId) => DropdownMenuEntry<String>(
                  value: modelId,
                  label: modelId,
                ),
              )
              .toList(growable: false),
          onSelected: (value) {
            if (value == null) {
              return;
            }
            onSelected(value);
          },
        );
      },
    );
  }
}

class _SettingsQuickNav extends StatelessWidget {
  const _SettingsQuickNav({
    required this.onJump,
    required this.activeId,
  });

  final ValueChanged<String> onJump;
  final String activeId;

  @override
  Widget build(BuildContext context) {
    final items = const <({String id, IconData icon, String label})>[
      (id: 'api', icon: Icons.key_outlined, label: 'API'),
      (id: 'memory', icon: Icons.psychology_alt_outlined, label: '记忆'),
      (id: 'display', icon: Icons.palette_outlined, label: '显示'),
      (id: 'preset', icon: Icons.bookmark_border_rounded, label: '预设'),
      (id: 'data', icon: Icons.import_export_rounded, label: '存档'),
      (id: 'info', icon: Icons.help_outline_rounded, label: '说明'),
    ];
    return Container(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppTheme.glitchText('设置目录'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final selected = item.id == activeId;
                return ActionChip(
                  avatar: Icon(
                    item.icon,
                    size: 18,
                    color: selected ? AppTheme.contrastText : null,
                  ),
                  label: Text(
                    AppTheme.glitchText(item.label),
                    maxLines: 2,
                  ),
                  backgroundColor: selected
                      ? AppTheme.activePrimary.withValues(alpha: 0.22)
                      : null,
                  side: BorderSide(
                    color: selected ? AppTheme.activeSoft : AppTheme.activeLine,
                  ),
                  onPressed: () => onJump(item.id),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
