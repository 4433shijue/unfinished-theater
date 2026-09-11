import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/bubble_style.dart';
import '../models/character_profile.dart';
import '../models/game_state.dart';
import '../models/npc_migration.dart';
import '../models/npc_profile.dart';
import '../models/tool_result.dart';
import '../services/local_image_picker.dart';
import '../services/story_insight_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_avatar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/html_content_view.dart';
import 'npc_migration_archive_screen.dart';

part 'npc_chats/npc_library_widgets.dart';
part 'npc_chats/npc_binding_dialog.dart';
part 'npc_chats/npc_chat_thread_screen.dart';
part 'npc_chats/npc_gift_sheet.dart';
part 'npc_chats/npc_thread_widgets.dart';
part 'npc_chats/npc_migration_dialog.dart';
part 'npc_chats/npc_profile_editor_dialog.dart';

class NpcChatsScreen extends StatelessWidget {
  const NpcChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final character = controller.currentCharacter;
    final profiles = controller.currentWorldNpcProfiles;
    final ensemble = controller.currentNpcEnsemble;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(AppTheme.glitchText('NPC')),
          bottom: character == null
              ? null
              : TabBar(
                  tabs: <Widget>[
                    Tab(
                      icon: const Icon(Icons.forum_outlined),
                      text: AppTheme.glitchText('私聊'),
                    ),
                    Tab(
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      text: AppTheme.glitchText(
                        controller.currentNpcUnreadCount > 0
                            ? '来信 · ${controller.currentNpcUnreadCount}'
                            : '来信',
                      ),
                    ),
                  ],
                ),
          actions: <Widget>[
            IconButton(
              tooltip: AppTheme.glitchText('新建 NPC'),
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.shellBackgroundGradient),
          child: SafeArea(
            top: false,
            child: character == null
                ? EmptyState(
                    icon: Icons.theater_comedy_outlined,
                    title: AppTheme.glitchText('还没有当前角色'),
                    description: AppTheme.glitchText(
                      '先回到角色页创建或选择一个角色，再管理当前世界的 NPC。',
                    ),
                  )
                : TabBarView(
                    children: <Widget>[
                      _NpcChatsTab(
                        profiles: profiles,
                        ensemble: ensemble,
                        controller: controller,
                        onCreate: () => _openEditor(context),
                        onOpen: (profile) => _openThread(context, profile),
                        onEdit: (profile) =>
                            _openEditor(context, profile: profile),
                        onDelete: (profile) => _confirmDelete(context, profile),
                        onMigrate: (profile) =>
                            _openMigration(context, profile),
                        onBind: (profile) =>
                            _openBindingEditor(context, profile),
                        onFinalize: (profile) =>
                            _finalizeRoleCard(context, profile),
                        onOpenRoleCard: (profile) =>
                            _openRoleCardViewer(context, profile),
                        onOpenArchive: (profile) =>
                            _openMigrationArchive(context, profile),
                        onDiary: (profile) =>
                            _generateNpcDiary(context, profile),
                      ),
                      _NpcLettersTab(
                        profiles: profiles,
                        controller: controller,
                        onOpen: (profile) => _openThread(context, profile),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateNpcDiary(
    BuildContext context,
    NpcProfile profile,
  ) async {
    final controller = context.read<AppStateController>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await controller.generateConversationToolReply(
      'npc_diary',
      resultTitle: 'NPC 日记 · ${profile.name}',
      userRequest: '''
只写 NPC「${profile.name}」（ID：${profile.id}）的私人日记或内心独白。
必须服从这份 NPC 档案的生命周期、好感与羁绊，不推进主聊天。
''',
    );
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText(error))),
      );
      return;
    }
    final result = controller.lastGeneratedToolResult;
    if (result != null) {
      await _showNpcToolResult(context, result);
    }
  }

  Future<void> _showNpcToolResult(
    BuildContext context,
    ToolResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        AppTheme.glitchText(result.toolTitle),
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: AppTheme.glitchText('关闭'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: HtmlContentView(content: result.content)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    NpcProfile? profile,
  }) async {
    final controller = context.read<AppStateController>();
    final draft = await showDialog<NpcProfileDraft>(
      context: context,
      builder: (context) => _NpcProfileEditorDialog(
        profile: profile,
        characters: controller.characters,
        onGenerateRoleCard: profile == null
            ? (inspiration, {onChunk}) =>
                controller.buildNpcRoleCardDraftFromInspiration(
                  inspiration: inspiration,
                  onChunk: onChunk,
                )
            : (extraInstruction, {onChunk}) => controller.buildNpcRoleCardDraft(
                  npcId: profile.id,
                  extraInstruction: extraInstruction,
                  onChunk: onChunk,
                ),
      ),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    if (profile == null) {
      await controller.createNpcProfile(draft);
    } else {
      await controller.updateNpcProfile(profile.id, draft);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    NpcProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('删除 NPC')),
        content: Text(
            AppTheme.glitchText('确定删除「${profile.name}」吗？它的私聊记录和印象历史也会一起删除。')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppTheme.glitchText('删除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await context.read<AppStateController>().deleteNpcProfile(profile.id);
  }

  Future<void> _openThread(
    BuildContext context,
    NpcProfile profile,
  ) async {
    final controller = context.read<AppStateController>();
    await controller.loadNpcThread(profile.id);
    await controller.markNpcThreadRead(profile.id);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NpcChatThreadScreen(npcId: profile.id),
      ),
    );
  }

  Future<void> _openMigration(
    BuildContext context,
    NpcProfile profile,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _NpcMigrationDialog(
        npc: profile,
        onEditRoleCard: () => _finalizeRoleCard(context, profile),
      ),
    );
  }

  Future<void> _openMigrationArchive(
    BuildContext context,
    NpcProfile profile,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NpcMigrationArchiveScreen(sourceNpcId: profile.id),
      ),
    );
  }

  Future<void> _openBindingEditor(
    BuildContext context,
    NpcProfile profile,
  ) async {
    if (!profile.hasReusableRoleCard) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTheme.glitchText('绑定到世界前，请先整理成 NPC 角色卡。')),
        ),
      );
      await _finalizeRoleCard(context, profile);
      return;
    }
    final controller = context.read<AppStateController>();
    final result = await showDialog<_NpcBindingDraft>(
      context: context,
      builder: (context) => _NpcBindingDialog(
        profile: profile,
        characters: controller.characters,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final error = await controller.updateNpcBindings(
      npcId: profile.id,
      companionEnabled: result.companionEnabled,
      globalBinding: result.globalBinding,
      boundCharacterIds: result.boundCharacterIds,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText(error ?? 'NPC 绑定已更新'))),
    );
  }

  Future<void> _finalizeRoleCard(
    BuildContext context,
    NpcProfile profile,
  ) async {
    final instructionController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('整理成 NPC 角色卡')),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppTheme.glitchText(
                  'AI 只会补全干净人设，不生成新世界、不推进剧情、不写告别；原世界强绑定内容会被去掉或泛化。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: AppTheme.glitchText('补全要求，可选'),
                  hintText: AppTheme.glitchText('例如：保留克制感，不绑定原学校背景。'),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: Text(AppTheme.glitchText('开始整理')),
          ),
        ],
      ),
    );
    final extraInstruction = instructionController.text.trim();
    instructionController.dispose();
    if (confirmed != true || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText('正在补全 NPC 角色卡...'))),
    );
    final result = await context.read<AppStateController>().finalizeNpcRoleCard(
          npcId: profile.id,
          extraInstruction: extraInstruction,
        );
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          AppTheme.glitchText(
            result.error ?? '已整理成 NPC 角色卡，可在角色库里查看和绑定。',
          ),
        ),
      ),
    );
  }

  Future<void> _openRoleCardViewer(
    BuildContext context,
    NpcProfile profile,
  ) async {
    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (context) => _NpcRoleCardViewerDialog(profile: profile),
    );
    if (shouldEdit == true && context.mounted) {
      await _openEditor(context, profile: profile);
    }
  }
}

class _NpcChatsTab extends StatelessWidget {
  const _NpcChatsTab({
    required this.profiles,
    required this.ensemble,
    required this.controller,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onMigrate,
    required this.onBind,
    required this.onFinalize,
    required this.onOpenRoleCard,
    required this.onOpenArchive,
    required this.onDiary,
  });

  final List<NpcProfile> profiles;
  final List<NpcEnsembleInsight> ensemble;
  final AppStateController controller;
  final VoidCallback onCreate;
  final Future<void> Function(NpcProfile profile) onOpen;
  final Future<void> Function(NpcProfile profile) onEdit;
  final Future<void> Function(NpcProfile profile) onDelete;
  final Future<void> Function(NpcProfile profile) onMigrate;
  final Future<void> Function(NpcProfile profile) onBind;
  final Future<void> Function(NpcProfile profile) onFinalize;
  final Future<void> Function(NpcProfile profile) onOpenRoleCard;
  final Future<void> Function(NpcProfile profile) onOpenArchive;
  final Future<void> Function(NpcProfile profile) onDiary;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: AppTheme.glitchText('还没有 NPC'),
        description: AppTheme.glitchText(
          '可以自己创建 NPC，也可以推进主线让系统识别当前世界里出现过的人。',
        ),
        actionLabel: AppTheme.glitchText('新建 NPC'),
        onAction: onCreate,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: <Widget>[
        _NpcEnsemblePanel(items: ensemble),
        const SizedBox(height: 12),
        _NpcLibrarySectionHeader(
          title: '当前世界 NPC',
          subtitle: '私聊、写日记、带 TA 走，或整理成可复用角色卡。',
          count: profiles.length,
        ),
        const SizedBox(height: 10),
        for (final profile in profiles) ...<Widget>[
          _NpcProfileCard(
            profile: profile,
            sourceCharacterName:
                controller.characterNameFor(profile.characterId),
            migrations: controller.npcMigrationsFor(profile.id),
            unreadCount: controller.npcUnreadCountFor(profile.id),
            onOpen: () => onOpen(profile),
            onDiary: () => onDiary(profile),
            onEdit: () => onEdit(profile),
            onDelete: () => onDelete(profile),
            onMigrate: () => onMigrate(profile),
            onBind: () => onBind(profile),
            onFinalize: () => onFinalize(profile),
            onOpenRoleCard: () => onOpenRoleCard(profile),
            onOpenArchive: () => onOpenArchive(profile),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _NpcLettersTab extends StatelessWidget {
  const _NpcLettersTab({
    required this.profiles,
    required this.controller,
    required this.onOpen,
  });

  final List<NpcProfile> profiles;
  final AppStateController controller;
  final Future<void> Function(NpcProfile profile) onOpen;

  @override
  Widget build(BuildContext context) {
    final sortedProfiles = List<NpcProfile>.from(profiles)
      ..sort((left, right) {
        final leftMessages = controller.npcMessagesFor(left.id);
        final rightMessages = controller.npcMessagesFor(right.id);
        final leftTime = leftMessages.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : leftMessages.last.timestamp;
        final rightTime = rightMessages.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : rightMessages.last.timestamp;
        return rightTime.compareTo(leftTime);
      });
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: controller.isSending || profiles.isEmpty
                  ? null
                  : () => _sendDailyLetter(context),
              icon: controller.isSending
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_unread_outlined),
              label: Text(AppTheme.glitchText('今日随机来信')),
            ),
            OutlinedButton.icon(
              onPressed: controller.currentNpcUnreadCount == 0
                  ? null
                  : () => _markAllRead(context),
              icon: const Icon(Icons.done_all_rounded),
              label: Text(AppTheme.glitchText('全部标记已读')),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (profiles.isEmpty)
          const _NpcLettersEmpty()
        else
          for (final profile in sortedProfiles) ...<Widget>[
            _NpcLetterTile(
              profile: profile,
              messages: controller.npcMessagesFor(profile.id),
              unreadCount: controller.npcUnreadCountFor(profile.id),
              onOpen: () => onOpen(profile),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Future<void> _sendDailyLetter(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await controller.sendDailyNpcLetter();
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          AppTheme.glitchText(error ?? '新的 NPC 来信已经送达。'),
        ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context) async {
    await controller.markNpcInboxRead();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText('NPC 来信已全部标记为已读。'))),
    );
  }
}

class _NpcLettersEmpty extends StatelessWidget {
  const _NpcLettersEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: <Widget>[
          Icon(Icons.mark_email_unread_outlined,
              size: 48, color: AppTheme.textWeak),
          const SizedBox(height: 12),
          Text(
            AppTheme.glitchText('还没有 NPC 可以寄信。'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _NpcLetterTile extends StatelessWidget {
  const _NpcLetterTile({
    required this.profile,
    required this.messages,
    required this.unreadCount,
    required this.onOpen,
  });

  final NpcProfile profile;
  final List<NpcChatMessage> messages;
  final int unreadCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final npcMessages = messages
        .where((message) => message.role == NpcMessageRole.npc)
        .toList(growable: false);
    final latest = npcMessages.isEmpty ? null : npcMessages.last;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: AppTheme.glassPanel(radius: 18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                CharacterAvatar(
                  name: profile.name,
                  avatarDataUri: profile.avatarDataUri,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppTheme.glitchText(profile.name),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTheme.glitchText(
                          latest?.content ?? '还没有收到来信。',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (unreadCount > 0)
                  Badge(
                    label: Text('$unreadCount'),
                    child: const Icon(Icons.mark_email_unread_outlined),
                  )
                else
                  Text(
                    AppTheme.glitchText('${npcMessages.length} 封'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textWeak,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
