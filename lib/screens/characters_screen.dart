import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/character_profile.dart';
import '../models/npc_migration.dart';
import '../theme/app_theme.dart';
import '../widgets/character_editor_dialog.dart';
import '../widgets/character_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/gameplay_system_dialog.dart';
import '../widgets/memory_manager_dialog.dart';
import '../widgets/tutorial_guide.dart';
import 'npc_migration_archive_screen.dart';
import 'world_books_screen.dart';

class CharactersScreen extends StatelessWidget {
  const CharactersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final selected = controller.currentCharacter;

    if (controller.characters.isEmpty) {
      return EmptyState(
        icon: Icons.theater_comedy_outlined,
        title: '还没有角色',
        description: '先创建一个角色档案，设置它的语气、边界和记忆方式，再开始对话。',
        actionLabel: '新建角色',
        actionKey: TutorialTargetRegistry.keyOf(
          TutorialTargetId.newCharacterButton,
        ),
        onAction: () {
          TutorialTargetRegistry.report(TutorialTargetId.newCharacterButton);
          _openEditor(context);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final listSection = _CharacterListSection(
          onCreate: () {
            TutorialTargetRegistry.report(
              TutorialTargetId.newCharacterButton,
            );
            _openEditor(context);
          },
          onOpenWorldBooks: () => _openWorldBooks(context),
          onOpenMigrationArchive: () => _openMigrationArchive(context),
        );
        final detailSection = selected == null
            ? const SizedBox.shrink()
            : _CharacterDetailSection(character: selected);

        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: SingleChildScrollView(child: listSection),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 10,
                  child: SingleChildScrollView(child: detailSection),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            listSection,
            const SizedBox(height: 18),
            detailSection,
          ],
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    CharacterProfile? initialCharacter,
  }) async {
    final draft = await showDialog<CharacterDraft>(
      context: context,
      builder: (context) => CharacterEditorDialog(
        initialCharacter: initialCharacter,
        onGenerateSimulatorPrompt:
            context.read<AppStateController>().generateSimulatorPrompt,
      ),
    );

    if (!context.mounted || draft == null) {
      return;
    }

    final controller = context.read<AppStateController>();
    if (initialCharacter == null) {
      await controller.createCharacter(draft);
      if (context.mounted) {
        final createdCharacter = controller.currentCharacter;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTheme.glitchText('角色已创建')),
            action: createdCharacter == null
                ? null
                : SnackBarAction(
                    label: AppTheme.glitchText('生成玩法'),
                    onPressed: () => _openGameplaySystem(
                      context,
                      createdCharacter.id,
                    ),
                  ),
          ),
        );
      }
      return;
    }

    await controller.updateCharacter(initialCharacter.id, draft);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('角色已更新'))),
      );
    }
  }

  void _openWorldBooks(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WorldBooksScreen(),
      ),
    );
  }

  void _openMigrationArchive(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NpcMigrationArchiveScreen(),
      ),
    );
  }

  void _openGameplaySystem(BuildContext context, String characterId) {
    showDialog<void>(
      context: context,
      builder: (context) => GameplaySystemDialog(characterId: characterId),
    );
  }
}

class _CharacterListSection extends StatelessWidget {
  const _CharacterListSection({
    required this.onCreate,
    required this.onOpenWorldBooks,
    required this.onOpenMigrationArchive,
  });

  final VoidCallback onCreate;
  final VoidCallback onOpenWorldBooks;
  final VoidCallback onOpenMigrationArchive;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();

    return Container(
      decoration: AppTheme.glassPanel(highlighted: true),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTheme.glitchText('角色档案'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppTheme.glitchText('整理每个角色的设定、开场白和记忆方式。'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        key: TutorialTargetRegistry.keyOf(
                          TutorialTargetId.newCharacterButton,
                        ),
                        onPressed: onCreate,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(AppTheme.glitchText('新建角色')),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onOpenWorldBooks,
                        icon: const Icon(Icons.menu_book_rounded),
                        label: Text(AppTheme.glitchText('世界书')),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onOpenMigrationArchive,
                        icon: const Icon(Icons.history_edu_outlined),
                        label: Text(AppTheme.glitchText('前尘档案馆')),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTheme.glitchText('角色档案'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppTheme.glitchText('整理每个角色的设定、开场白和记忆方式。'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      key: TutorialTargetRegistry.keyOf(
                        TutorialTargetId.newCharacterButton,
                      ),
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(AppTheme.glitchText('新建角色')),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onOpenWorldBooks,
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text(AppTheme.glitchText('世界书')),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onOpenMigrationArchive,
                      icon: const Icon(Icons.history_edu_outlined),
                      label: Text(AppTheme.glitchText('前尘档案馆')),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _CharacterGroupedList(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.character,
    required this.isSelected,
  });

  final CharacterProfile character;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final avatar = _AvatarBadge(
          name: character.name,
          avatarDataUri: character.avatarDataUri,
          selected: isSelected,
        );
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: () => context.read<AppStateController>().selectCharacter(
                  character.id,
                ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.activePrimary.withValues(alpha: 0.22),
                          AppTheme.activeSecondary.withValues(alpha: 0.14),
                          AppTheme.activeAccent.withValues(alpha: 0.1),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.activePalette.panelStart
                              .withValues(alpha: 0.56),
                          AppTheme.activePalette.panelEnd
                              .withValues(alpha: 0.42),
                        ],
                      ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.activeSoft.withValues(alpha: 0.38)
                      : AppTheme.activeLine,
                ),
                boxShadow: isSelected ? AppTheme.neonGlow(alpha: 0.06) : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 14 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatar,
                        SizedBox(width: compact ? 12 : 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      character.name,
                                      maxLines: compact ? 2 : 1,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (!compact && character.isPresetRole) ...[
                                    _StatusPill(
                                      label: '系统预设',
                                      color: AppTheme.activeAccent,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (!compact && character.isNpcMigration) ...[
                                    _StatusPill(
                                      label: 'NPC 迁徙',
                                      color: AppTheme.activeSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (!compact &&
                                      character.largeGroupChatModeEnabled) ...[
                                    _StatusPill(
                                      label: '大型群聊',
                                      color: AppTheme.activeAccent,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (!compact && character.mapModeEnabled) ...[
                                    _StatusPill(
                                      label: '地图主线',
                                      color: AppTheme.activeSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (!compact && isSelected)
                                    _StatusPill(
                                      label: '当前',
                                      color: AppTheme.activePrimary,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                character.visibleBlurb,
                                maxLines: compact ? 4 : 3,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TileAction(
                          tooltip: AppTheme.glitchText('编辑角色'),
                          icon: Icons.edit_outlined,
                          onTap: () async {
                            final draft = await showDialog<CharacterDraft>(
                              context: context,
                              builder: (context) => CharacterEditorDialog(
                                initialCharacter: character,
                                onGenerateSimulatorPrompt: context
                                    .read<AppStateController>()
                                    .generateSimulatorPrompt,
                              ),
                            );
                            if (!context.mounted || draft == null) {
                              return;
                            }

                            await context
                                .read<AppStateController>()
                                .updateCharacter(character.id, draft);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppTheme.glitchText('角色已更新')),
                                ),
                              );
                            }
                          },
                        ),
                        _TileAction(
                          tooltip: AppTheme.glitchText('删除角色'),
                          icon: Icons.delete_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                          onTap: () => _confirmDelete(context),
                        ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TinyTag(
                            label:
                                'Temp ${character.modelParams.temperature.toStringAsFixed(2)}',
                          ),
                          _TinyTag(
                            label:
                                'Top P ${character.modelParams.topP.toStringAsFixed(2)}',
                          ),
                          _TinyTag(
                            label: character.modelParams.contextLength <= 0
                                ? '上下文不限'
                                : '上下文 ${character.modelParams.contextLength} 条',
                          ),
                          if (character.isNpcMigration)
                            const _TinyTag(label: '由带走 NPC 生成'),
                          if (character.largeGroupChatModeEnabled)
                            const _TinyTag(label: '大型群聊模式'),
                          if (character.mapModeEnabled)
                            const _TinyTag(label: '地图主线模式'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('删除角色')),
        content: Text(AppTheme.glitchText(
          '确定要删除「${character.name}」吗？这个角色的对话和记忆也会一起移除。',
        )),
        actions: [
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

    if (!context.mounted || confirmed != true) {
      return;
    }

    final error =
        await context.read<AppStateController>().deleteCharacter(character.id);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTheme.glitchText(error ?? '角色已删除'))),
    );
  }
}

class _CharacterGroupedList extends StatelessWidget {
  const _CharacterGroupedList({required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    final main = controller.characters
        .where((character) =>
            !character.isNpcMigration && !character.isStoryBranch)
        .toList(growable: false);
    final migrations = controller.characters
        .where((character) => character.isNpcMigration)
        .toList(growable: false);
    final branches = controller.characters
        .where((character) => character.isStoryBranch)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CharacterGroup(
          title: '我的角色',
          icon: Icons.theater_comedy_outlined,
          characters: main,
          selectedCharacterId: controller.selectedCharacterId,
        ),
        if (migrations.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          _CharacterGroup(
            title: '前尘新世界',
            icon: Icons.history_edu_outlined,
            characters: migrations,
            selectedCharacterId: controller.selectedCharacterId,
          ),
        ],
        if (branches.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          _CharacterGroup(
            title: '剧情分支',
            icon: Icons.fork_right_outlined,
            characters: branches,
            selectedCharacterId: controller.selectedCharacterId,
          ),
        ],
      ],
    );
  }
}

class _CharacterGroup extends StatelessWidget {
  const _CharacterGroup({
    required this.title,
    required this.icon,
    required this.characters,
    required this.selectedCharacterId,
  });

  final String title;
  final IconData icon;
  final List<CharacterProfile> characters;
  final String? selectedCharacterId;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppTheme.activePrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppTheme.glitchText('$title · ${characters.length}'),
                maxLines: 2,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: characters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final character = characters[index];
            return _CharacterTile(
              character: character,
              isSelected: character.id == selectedCharacterId,
            );
          },
        ),
      ],
    );
  }
}

class _CharacterDetailSection extends StatelessWidget {
  const _CharacterDetailSection({required this.character});

  final CharacterProfile character;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final memory = controller.currentMemory;
    final migrationRecord = character.isNpcMigration
        ? controller.npcMigrationForCharacter(character.id)
        : null;

    return Container(
      decoration: AppTheme.glassPanel(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarBadge(
                  name: character.name,
                  avatarDataUri: character.avatarDataUri,
                  selected: true,
                  large: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.name,
                        maxLines: 2,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (character.isPresetRole)
                            _StatusPill(
                              label: '系统预设',
                              color: AppTheme.activeAccent,
                            ),
                          if (character.isNpcMigration)
                            _StatusPill(
                              label: 'NPC 迁徙角色',
                              color: AppTheme.activePrimary,
                            ),
                          _StatusPill(
                            label: '记忆 ${memory.summaries.length} 条',
                            color: AppTheme.activeSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (migrationRecord != null) ...[
              _MigrationCharacterPanel(record: migrationRecord),
              const SizedBox(height: 18),
            ],
            Text(
              AppTheme.glitchText(
                character.isPromptLocked ? '角色简介' : '角色提示词',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.translucentPanelFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.activeLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.visibleBlurb,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (character.isPromptLocked) ...[
                    const SizedBox(height: 12),
                    Text(
                      AppTheme.glitchText(
                        '这是系统预设角色，底层提示词已锁定且不会对外显示。你仍然可以调整温度、Top P 和上下文参数。',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TinyTag(
                  label:
                      'Temperature ${character.modelParams.temperature.toStringAsFixed(2)}',
                ),
                _TinyTag(
                  label:
                      'Top P ${character.modelParams.topP.toStringAsFixed(2)}',
                ),
                _TinyTag(
                  label: character.modelParams.contextLength <= 0
                      ? '上下文不限'
                      : '上下文 ${character.modelParams.contextLength} 条',
                ),
                _TinyTag(label: '记忆 ${memory.summaries.length} 条'),
              ],
            ),
            const SizedBox(height: 24),
            _GameplaySystemEntry(character: character),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.panel.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.activeLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTheme.glitchText('长期记忆库'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    memory.summaries.isEmpty
                        ? AppTheme.glitchText('还没有可用记忆。多聊几轮后，系统会把关键片段整理成长时记忆卡。')
                        : AppTheme.glitchText(
                            '当前已有 ${memory.summaries.length} 条长期记忆，点开后可以逐条编辑或删除。'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.55,
                        ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: () => showMemoryManagerDialog(context),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text(AppTheme.glitchText('查看长期记忆')),
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

class _GameplaySystemEntry extends StatelessWidget {
  const _GameplaySystemEntry({required this.character});

  final CharacterProfile character;

  @override
  Widget build(BuildContext context) {
    final system = character.gameplaySystem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppTheme.activePrimary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                AppTheme.glitchText('玩法系统'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (system != null)
              _StatusPill(
                label: '${system.variables.length} 个变量',
                color: AppTheme.activePrimary,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          system == null ? AppTheme.glitchText('尚未生成专属玩法参数。') : system.coreLoop,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => GameplaySystemDialog(
              characterId: character.id,
            ),
          ),
          icon: Icon(
            system == null ? Icons.auto_awesome_rounded : Icons.tune_rounded,
          ),
          label: Text(
            AppTheme.glitchText(system == null ? '生成玩法系统' : '打开玩法系统'),
          ),
        ),
      ],
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.name,
    required this.avatarDataUri,
    required this.selected,
    this.large = false,
  });

  final String name;
  final String avatarDataUri;
  final bool selected;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return CharacterAvatar(
      name: name,
      avatarDataUri: avatarDataUri,
      selected: selected,
      large: large,
    );
  }
}

class _MigrationCharacterPanel extends StatelessWidget {
  const _MigrationCharacterPanel({required this.record});

  final NpcMigrationRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTheme.glitchText('前尘新世界'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppTheme.glitchText(
              '来源：从「${record.sourceCharacterName}」带走的「${record.sourceNpcName}」',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NpcMigrationArchiveScreen(
                      initialRecordId: record.id,
                      createdCharacterId: record.createdCharacterId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.history_edu_outlined),
                label: Text(AppTheme.glitchText('打开前尘档案')),
              ),
              OutlinedButton.icon(
                onPressed: record.allowEcho
                    ? () async {
                        final error = await context
                            .read<AppStateController>()
                            .triggerNpcMigrationEcho(
                              recordId: record.id,
                              echoType: '随机回声',
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  AppTheme.glitchText(error ?? '前尘回声已触发。')),
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.spatial_audio_outlined),
                label: Text(AppTheme.glitchText('触发前尘回声')),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NpcMigrationArchiveScreen(
                      initialRecordId: record.id,
                      createdCharacterId: record.createdCharacterId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.construction_outlined),
                label: Text(AppTheme.glitchText('迁徙重修台')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppTheme.glitchText(tooltip),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color ?? AppTheme.textMuted),
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 240 : 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.translucentPanelFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.activeLine),
        ),
        child: Text(
          AppTheme.glitchText(label),
          maxLines: compact ? 2 : 1,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        AppTheme.glitchText(label),
        maxLines: MediaQuery.sizeOf(context).width < 620 ? 2 : 1,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.contrastText,
            ),
      ),
    );
  }
}
