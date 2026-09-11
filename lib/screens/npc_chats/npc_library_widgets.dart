part of '../npc_chats_screen.dart';

class _NpcEnsemblePanel extends StatelessWidget {
  const _NpcEnsemblePanel({required this.items});

  final List<NpcEnsembleInsight> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(6).toList(growable: false);
    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.hub_outlined, color: AppTheme.activeSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTheme.glitchText('NPC 群像视图'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Chip(
                  label: Text(AppTheme.glitchText('${items.length} 人')),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppTheme.glitchText('按当前地点、目标、关系和事件记忆整理本世界 NPC 状态。'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              Text(
                AppTheme.glitchText('暂无可展示的 NPC 状态。'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textWeak,
                    ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      for (final item in visible)
                        SizedBox(
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 10) / 2,
                          child: _NpcEnsembleTile(item: item),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NpcEnsembleTile extends StatelessWidget {
  const _NpcEnsembleTile({required this.item});

  final NpcEnsembleInsight item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.activeSoft.withValues(alpha: 0.18),
                child: Text(
                  item.name.characters.take(1).toString(),
                  style: TextStyle(
                    color: AppTheme.activeSoft,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.glitchText(item.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _NpcInsightLine(icon: Icons.place_outlined, text: item.location),
          _NpcInsightLine(icon: Icons.psychology_outlined, text: item.mood),
          _NpcInsightLine(icon: Icons.flag_outlined, text: item.goal),
          _NpcInsightLine(icon: Icons.favorite_border, text: item.bond),
          const SizedBox(height: 6),
          Text(
            AppTheme.glitchText(item.recentEvent),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _NpcInsightLine extends StatelessWidget {
  const _NpcInsightLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: AppTheme.textWeak),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppTheme.glitchText(text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NpcLibrarySectionHeader extends StatelessWidget {
  const _NpcLibrarySectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.auto_stories_outlined, color: AppTheme.activeSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppTheme.glitchText('$title · $count'),
                    maxLines: 2,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppTheme.glitchText(subtitle),
                    maxLines: 3,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NpcRoleCardViewerDialog extends StatelessWidget {
  const _NpcRoleCardViewerDialog({required this.profile});

  final NpcProfile profile;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final roleCard = profile.roleCard.trim();
    return AlertDialog(
      title: Text(AppTheme.glitchText('NPC 角色卡 · ${profile.name}')),
      content: SizedBox(
        width: size.width < 620 ? size.width * 0.92 : 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _NpcInfoPill(
                    icon: Icons.article_outlined,
                    text: profile.hasReusableRoleCard ? '已整理' : '未整理',
                  ),
                  _NpcInfoPill(
                    icon: Icons.hub_outlined,
                    text: profile.companionEnabled
                        ? profile.globalBinding
                            ? '已全局绑定'
                            : '绑定 ${profile.boundCharacterIds.length} 个世界'
                        : '未绑定',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SelectableText(
                AppTheme.glitchText(
                    roleCard.isEmpty ? '还没有角色卡。请先使用“整理成 NPC 角色卡”。' : roleCard),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.edit_outlined),
          label: Text(AppTheme.glitchText('编辑角色卡')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppTheme.glitchText('关闭')),
        ),
      ],
    );
  }
}
