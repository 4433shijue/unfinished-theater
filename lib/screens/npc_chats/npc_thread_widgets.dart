part of '../npc_chats_screen.dart';

class _NpcMessageBubble extends StatelessWidget {
  const _NpcMessageBubble({
    required this.message,
    required this.npcName,
    required this.frameId,
    this.customStyle,
    this.selected = false,
    this.selecting = false,
    this.onTap,
    this.onLongPress,
  });

  final NpcChatMessage message;
  final String npcName;
  final String frameId;
  final BubbleStyleSpec? customStyle;
  final bool selected;
  final bool selecting;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == NpcMessageRole.user;
    final local = message.timestamp.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final bubbleDecoration = _npcBubbleDecoration(
      isUser: isUser,
      selected: selected,
      frameId: frameId,
      customStyle: customStyle,
    );
    final textColor = customStyle?.textFor(isUser) ?? AppTheme.textMain;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: DecoratedBox(
            decoration: bubbleDecoration,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Stack(
                children: <Widget>[
                  if (customStyle?.decorationText?.isNotEmpty == true)
                    Positioned(
                      right: 2,
                      top: 0,
                      child: IgnorePointer(
                        child: Text(
                          customStyle!.decorationText!,
                          style: TextStyle(
                            color: (customStyle!.accentColor ??
                                    AppTheme.activeSoft)
                                .withValues(
                              alpha: customStyle!.decorationOpacity ?? 0.22,
                            ),
                            fontSize: customStyle!.decorationSize ?? 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        isUser ? AppTheme.glitchText('你') : npcName,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: customStyle?.accentColor ??
                                      AppTheme.activeSoft,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.content,
                        softWrap: true,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: textColor, height: 1.5),
                      ),
                      if (!isUser && message.innerVoice.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _NpcInnerVoiceDisclosure(
                          innerVoice: message.innerVoice.trim(),
                          textColor: textColor,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        time,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppTheme.textWeak,
                                ),
                      ),
                      if (selecting && selected)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 22,
                            color: AppTheme.activeSoft,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NpcInnerVoiceDisclosure extends StatelessWidget {
  const _NpcInnerVoiceDisclosure({
    required this.innerVoice,
    required this.textColor,
  });

  final String innerVoice;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.activeAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.activeLine.withValues(alpha: 0.7),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          initiallyExpanded: false,
          dense: true,
          leading: Icon(
            Icons.hearing_rounded,
            size: 17,
            color: AppTheme.activeSoft,
          ),
          title: Text(
            AppTheme.glitchText('已生成这句心声'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: textColor.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w800,
                ),
          ),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                innerVoice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.86),
                      height: 1.45,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _npcBubbleDecoration({
  required bool isUser,
  required bool selected,
  required String frameId,
  required BubbleStyleSpec? customStyle,
}) {
  if (customStyle != null) {
    final background = customStyle.backgroundFor(isUser) ??
        (isUser
            ? AppTheme.activePrimary.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.72));
    final border = customStyle.borderFor(isUser) ?? AppTheme.activeLine;
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(customStyle.borderRadius ?? 22),
      border: Border.all(
        color: selected ? AppTheme.activeSoft : border,
        width: selected ? 2.4 : (customStyle.borderWidth ?? 2),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: (customStyle.shadowColor ?? border).withValues(alpha: 0.16),
          blurRadius: customStyle.shadowBlur ?? 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
  final accent = switch (frameId) {
    'frame_sticky_note' => AppTheme.activeAccent,
    'frame_cat_paw' => AppTheme.activeSoft,
    'frame_moon_ticket' => AppTheme.activeSecondary,
    'frame_whisper_rift' => AppTheme.activePrimary,
    'frame_inbox_burst' => AppTheme.activeAccent,
    'frame_cream_note' => const Color(0xFFD6A967),
    'frame_film_strip' => const Color(0xFFD8C08E),
    'frame_pixel_quest' => AppTheme.activeSoft,
    'frame_bad_luck_charm' => const Color(0xFFFF6B6B),
    _ => AppTheme.activeLine,
  };
  final radius = switch (frameId) {
    'frame_pixel_quest' => BorderRadius.circular(8),
    'frame_film_strip' => BorderRadius.circular(12),
    'frame_bad_luck_charm' => const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(26),
        bottomLeft: Radius.circular(26),
        bottomRight: Radius.circular(6),
      ),
    'frame_whisper_rift' => const BorderRadius.only(
        topLeft: Radius.circular(34),
        topRight: Radius.circular(8),
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(34),
      ),
    'frame_moon_ticket' => const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(28),
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(12),
      ),
    _ => BorderRadius.only(
        topLeft: const Radius.circular(22),
        topRight: const Radius.circular(22),
        bottomLeft: Radius.circular(isUser ? 22 : 6),
        bottomRight: Radius.circular(isUser ? 6 : 22),
      ),
  };
  return BoxDecoration(
    color: isUser
        ? AppTheme.activePrimary.withValues(alpha: 0.26)
        : Colors.white.withValues(alpha: 0.10),
    borderRadius: radius,
    border: Border.all(
      color: selected
          ? AppTheme.activeSoft
          : frameId == 'frame_default'
              ? AppTheme.activeLine
              : accent.withValues(alpha: 0.82),
      width: selected
          ? 2.4
          : frameId == 'frame_default'
              ? 1
              : frameId == 'frame_pixel_quest'
                  ? 3.2
                  : 2.4,
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color:
            accent.withValues(alpha: frameId == 'frame_default' ? 0.08 : 0.18),
        blurRadius: frameId == 'frame_pixel_quest' ? 0 : 18,
        offset: frameId == 'frame_pixel_quest'
            ? const Offset(4, 4)
            : const Offset(0, 8),
      ),
    ],
  );
}

// ─── Card ────────────────────────────────────────────────────────────────────

String _formatNpcBondLabel(
  NpcBondRoute bond, {
  bool includeScore = false,
}) {
  final stage = bond.stage.trim().isEmpty ? '初见' : bond.stage.trim();
  final route = bond.route.trim();
  final routeText = route.isEmpty || route == '未知线' ? '' : ' · $route';
  final scoreText = includeScore ? ' · ${bond.score}/100' : '';
  return '$stage$routeText$scoreText';
}

class _NpcProfileCard extends StatelessWidget {
  const _NpcProfileCard({
    required this.profile,
    required this.sourceCharacterName,
    required this.migrations,
    required this.unreadCount,
    required this.onOpen,
    required this.onDiary,
    required this.onEdit,
    required this.onDelete,
    required this.onMigrate,
    required this.onBind,
    required this.onFinalize,
    required this.onOpenRoleCard,
    required this.onOpenArchive,
  });

  final NpcProfile profile;
  final String sourceCharacterName;
  final List<NpcMigrationRecord> migrations;
  final int unreadCount;
  final VoidCallback onOpen;
  final VoidCallback onDiary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMigrate;
  final VoidCallback onBind;
  final VoidCallback onFinalize;
  final VoidCallback onOpenRoleCard;
  final VoidCallback onOpenArchive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onOpen,
            child: Ink(
              decoration: AppTheme.glassPanel(radius: 26),
              child: Padding(
                padding: EdgeInsets.all(compact ? 16 : 18),
                child: compact
                    ? _buildCompactContent(context, constraints.maxWidth)
                    : _buildWideContent(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactContent(BuildContext context, double cardWidth) {
    final pillMaxWidth = cardWidth - 32;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _avatar(),
            const SizedBox(width: 12),
            Expanded(child: _profileHeader(context, compact: true)),
          ],
        ),
        const SizedBox(height: 10),
        _actionButtons(context, compact: true),
        if (unreadCount > 0) ...<Widget>[
          const SizedBox(height: 10),
          _unreadBadge(context),
        ],
        const SizedBox(height: 10),
        _statusPills(maxWidth: pillMaxWidth),
        const SizedBox(height: 8),
        _sourceLine(context),
        if (migrations.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _migrationPreview(context),
        ],
        const SizedBox(height: 10),
        _impressionPreview(context),
      ],
    );
  }

  Widget _buildWideContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _avatar(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _profileHeader(context, compact: false),
              if (unreadCount > 0) ...<Widget>[
                const SizedBox(height: 6),
                _unreadBadge(context),
              ],
              const SizedBox(height: 8),
              _statusPills(maxWidth: 260),
              const SizedBox(height: 8),
              _sourceLine(context),
              if (migrations.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _migrationPreview(context),
              ],
              const SizedBox(height: 8),
              _impressionPreview(context),
            ],
          ),
        ),
        if (unreadCount > 0) _unreadDot(context),
        _actionButtons(context, compact: false),
      ],
    );
  }

  Widget _avatar() {
    return CharacterAvatar(
      name: profile.name.trim().isEmpty ? 'NPC' : profile.name,
      avatarDataUri: profile.avatarDataUri,
      size: 46,
    );
  }

  Widget _profileHeader(BuildContext context, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppTheme.glitchText(profile.name),
          maxLines: compact ? 2 : 1,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (profile.description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            AppTheme.glitchText(profile.description),
            maxLines: compact ? 4 : 3,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textMuted, height: 1.45),
          ),
        ],
      ],
    );
  }

  Widget _statusPills({required double maxWidth}) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        _NpcInfoPill(
          icon: Icons.favorite_border_rounded,
          text: '好感度 ${profile.affinity}',
          maxWidth: maxWidth,
        ),
        if (profile.lifecycle != NpcLifecycle.active)
          _NpcInfoPill(
            icon: profile.lifecycle == NpcLifecycle.dead
                ? Icons.person_off_outlined
                : Icons.schedule_outlined,
            text: profile.lifecycle.label,
            maxWidth: maxWidth,
          ),
        _NpcInfoPill(
          icon: Icons.route_outlined,
          text: _formatNpcBondLabel(profile.bondRoute),
          maxWidth: maxWidth,
        ),
        _NpcInfoPill(
          icon: Icons.psychology_alt_outlined,
          text: profile.hasReusableRoleCard ? '角色卡已整理' : '待整理角色卡',
          maxWidth: maxWidth,
        ),
        _NpcInfoPill(
          icon: profile.companionEnabled
              ? Icons.group_add_outlined
              : Icons.badge_outlined,
          text: _bindingLabel(),
          maxWidth: maxWidth,
        ),
      ],
    );
  }

  String _bindingLabel() {
    if (profile.companionEnabled && profile.globalBinding) {
      return '全局同行';
    }
    if (profile.companionEnabled && profile.boundCharacterIds.length > 1) {
      return '绑定 ${profile.boundCharacterIds.length} 个世界';
    }
    if (profile.companionEnabled) {
      return '当前世界同行';
    }
    return NpcProfileSource.label(profile.sourceType);
  }

  Widget _sourceLine(BuildContext context) {
    final boundLabel = profile.companionEnabled
        ? profile.globalBinding
            ? '已绑定：全部世界'
            : '已绑定：${profile.boundCharacterIds.length} 个世界'
        : '未绑定其他世界';
    return Text(
      AppTheme.glitchText('来源世界：$sourceCharacterName · $boundLabel'),
      maxLines: 2,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textWeak,
            height: 1.4,
          ),
    );
  }

  Widget _impressionPreview(BuildContext context) {
    return Text(
      profile.impression.trim().isEmpty
          ? AppTheme.glitchText('暂无印象。')
          : AppTheme.glitchText(profile.impression),
      maxLines: 5,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.55),
    );
  }

  Widget _migrationPreview(BuildContext context) {
    final latest = migrations.first;
    final extra = migrations.length > 1 ? ' 等 ${migrations.length} 个新世界' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.activeSoft.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.travel_explore_outlined,
            size: 16,
            color: AppTheme.activePrimary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppTheme.glitchText('已带去：${latest.createdCharacterName}$extra'),
              maxLines: 2,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unreadBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        AppTheme.glitchText('有未读消息'),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _unreadDot(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.only(top: 14, right: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.45),
            blurRadius: 12,
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(BuildContext context, {required bool compact}) {
    final size = compact ? 38.0 : 42.0;
    final iconSize = compact ? 21.0 : 24.0;
    Widget button({
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return SizedBox.square(
        dimension: size,
        child: IconButton(
          tooltip: AppTheme.glitchText(tooltip),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: size, height: size),
          visualDensity: VisualDensity.compact,
          iconSize: iconSize,
          icon: Icon(icon),
        ),
      );
    }

    return Wrap(
      spacing: compact ? 4 : 2,
      runSpacing: compact ? 4 : 0,
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      children: <Widget>[
        button(
          tooltip: '写 NPC 日记',
          icon: Icons.edit_note_rounded,
          onPressed: onDiary,
        ),
        button(
          tooltip: '带 TA 走',
          icon: Icons.travel_explore_outlined,
          onPressed: onMigrate,
        ),
        button(
          tooltip: profile.hasReusableRoleCard ? '绑定到世界' : '先整理角色卡',
          icon: Icons.hub_outlined,
          onPressed: onBind,
        ),
        button(
          tooltip: profile.hasReusableRoleCard ? '重新补全' : '整理成 NPC 角色卡',
          icon: Icons.auto_fix_high_outlined,
          onPressed: onFinalize,
        ),
        button(
          tooltip: '查看角色卡',
          icon: Icons.article_outlined,
          onPressed: onOpenRoleCard,
        ),
        button(
          tooltip: '前尘档案',
          icon: Icons.history_edu_outlined,
          onPressed: onOpenArchive,
        ),
        button(
          tooltip: '编辑',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        button(
          tooltip: '删除',
          icon: Icons.delete_outline_rounded,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _NpcInfoPill extends StatelessWidget {
  const _NpcInfoPill({
    required this.icon,
    required this.text,
    this.maxWidth,
  });

  final IconData icon;
  final String text;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cap = maxWidth ?? (screenWidth < 420 ? screenWidth - 72 : 280.0);
    final effectiveMaxWidth = cap < 96 ? 96.0 : cap;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.activePrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.activeLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: AppTheme.activeSoft),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                AppTheme.glitchText(text),
                maxLines: screenWidth < 520 ? 2 : 1,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NpcBondPanel extends StatelessWidget {
  const _NpcBondPanel({required this.npc});

  final NpcProfile npc;

  @override
  Widget build(BuildContext context) {
    final bond = npc.bondRoute;
    final progress = (bond.score / 100).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: AppTheme.glassPanel(highlighted: true, radius: 22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.route_outlined, color: AppTheme.activeSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppTheme.glitchText('羁绊路线'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  '${bond.score}/100',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.activeSoft,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppTheme.activePrimary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.activeSoft),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _NpcInfoPill(
                  icon: Icons.flag_outlined,
                  text: '阶段：${bond.stage}',
                ),
                _NpcInfoPill(
                  icon: Icons.alt_route_outlined,
                  text: '倾向：${bond.route}',
                ),
                if (bond.keywords.isNotEmpty)
                  _NpcInfoPill(
                    icon: Icons.sell_outlined,
                    text: bond.keywords.take(3).join(' / '),
                  ),
              ],
            ),
            if (bond.latestEvent.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                AppTheme.glitchText('最近节点：${bond.latestEvent}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
              ),
            ],
            if (bond.events.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              for (final event in bond.events.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.radio_button_checked_rounded,
                        size: 14,
                        color: AppTheme.activeSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${event.stage} · ${event.route}：${event.summary}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    height: 1.45,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
