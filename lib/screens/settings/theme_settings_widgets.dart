part of '../settings_screen.dart';

class _BasicThemePackCard extends StatelessWidget {
  const _BasicThemePackCard({
    required this.variants,
    required this.selectedThemeId,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final List<AppThemeVariant> variants;
  final String selectedThemeId;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<AppThemeVariant> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = AppThemeVariant.byId(selectedThemeId);
    final selectedIsBasic =
        AppThemeVariant.hasId(selectedThemeId) && selected.isBasicPalette;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: selectedIsBasic ? 0.065 : 0.035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selectedIsBasic
              ? AppTheme.activeSoft.withValues(alpha: 0.7)
              : AppTheme.activeLine,
          width: selectedIsBasic ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: selectedIsBasic
                            ? selected.palette.brand
                            : AppThemeVariant.sakura.palette.brand,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(Icons.palette_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppTheme.glitchText('基础配色包'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppTheme.glitchText(
                            selectedIsBasic
                                ? '当前基础配色：${selected.label}'
                                : '收纳六套只换色的轻量主题，个性主题就不被挤乱啦。',
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppTheme.activeSoft,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: variants
                    .map(
                      (variant) => _BasicThemeChip(
                        variant: variant,
                        selected: selectedThemeId == variant.id,
                        onTap: () => onSelect(variant),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomThemeSection extends StatelessWidget {
  const _CustomThemeSection({
    required this.controller,
    required this.selectedThemeId,
    required this.styles,
    required this.onSelect,
  });

  final AppStateController controller;
  final String selectedThemeId;
  final List<CustomThemeStyle> styles;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppTheme.glitchText('自定义主题工坊'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTheme.glitchText(
                          '200 啥币开一个主题格子，先选已有主题当底稿，再用样式变量覆盖成新装修。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.gamification.coins >= 200
                      ? () => _openCustomThemeEditor(context, controller)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(AppTheme.glitchText('200啥币开格')),
                ),
              ],
            ),
            if (styles.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: styles
                    .map(
                      (style) => _CustomThemeChip(
                        style: style,
                        selected: selectedThemeId == style.id,
                        onSelect: () => onSelect(style.id),
                        onEdit: () => _openCustomThemeEditor(
                          context,
                          controller,
                          style: style,
                        ),
                        onDelete: () async {
                          final error =
                              await controller.deleteCustomThemeStyle(style.id);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error ?? '自定义主题「${style.name}」已删除。',
                              ),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomThemeChip extends StatelessWidget {
  const _CustomThemeChip({
    required this.style,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomThemeStyle style;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final base = AppThemeVariant.byId(style.baseThemeId);
    final spec = ThemeStyleSpec.fromCustom(style);
    final palette =
        (spec ?? ThemeStyleSpec(baseThemeId: base.id)).applyTo(base.palette);
    return Container(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: selected ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? palette.soft.withValues(alpha: 0.82)
              : AppTheme.activeLine,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: palette.brand),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppTheme.glitchText('自定义 · ${style.name}'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTheme.glitchText('底稿：${base.label}'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppTheme.glitchText('编辑'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: AppTheme.glitchText('删除'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
