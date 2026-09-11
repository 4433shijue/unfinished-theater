import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/character_profile.dart';
import '../models/user_profile.dart';
import '../services/local_image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/character_avatar.dart';
import '../widgets/empty_state.dart';

class UserProfilesScreen extends StatelessWidget {
  const UserProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final profiles = controller.userProfiles;
    final uiScale = AppTheme.uiScaleOf(context);

    return Padding(
      padding: EdgeInsets.all(16 * uiScale),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppTheme.glitchText('用户角色'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(AppTheme.glitchText('新建用户')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: profiles.isEmpty
                ? EmptyState(
                    icon: Icons.person_outline_rounded,
                    title: '还没有用户角色',
                    description: '可以在这里创建你的主角人设，并绑定到指定角色。没有绑定时，角色会按原逻辑正常回复。',
                    actionLabel: '新建用户',
                    onAction: () => _openEditor(context),
                  )
                : ListView.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      return _UserProfileCard(
                        profile: profile,
                        characters: controller.characters,
                        onEdit: () => _openEditor(context, profile: profile),
                        onDelete: () => _confirmDelete(context, profile),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    UserProfile? profile,
  }) async {
    final controller = context.read<AppStateController>();
    final draft = await showDialog<UserProfileDraft>(
      context: context,
      builder: (context) => _UserProfileEditorDialog(
        initialProfile: profile,
        characters: controller.characters,
      ),
    );

    if (draft == null || !context.mounted) {
      return;
    }

    if (profile == null) {
      await context.read<AppStateController>().createUserProfile(draft);
    } else {
      await context.read<AppStateController>().updateUserProfile(
            profile.id,
            draft,
          );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    UserProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTheme.glitchText('删除用户角色')),
        content:
            Text(AppTheme.glitchText('确定删除“${profile.name}”吗？绑定关系也会一起移除。')),
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

    await context.read<AppStateController>().deleteUserProfile(profile.id);
  }
}

class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({
    required this.profile,
    required this.characters,
    required this.onEdit,
    required this.onDelete,
  });

  final UserProfile profile;
  final List<CharacterProfile> characters;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final boundNames = characters
        .where((character) => profile.boundCharacterIds.contains(character.id))
        .map((character) => character.name)
        .toList(growable: false);

    return Container(
      decoration: AppTheme.glassPanel(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CharacterAvatar(
                  name: profile.name,
                  avatarDataUri: profile.avatarDataUri,
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profile.name,
                    style: Theme.of(context).textTheme.titleMedium,
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
            if (profile.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                profile.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
            if (profile.gender.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _BindingChip(label: '性别：${profile.gender.trim()}'),
            ],
            const SizedBox(height: 12),
            Text(
              profile.persona,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: boundNames.isEmpty
                  ? <Widget>[
                      const _BindingChip(label: '未绑定角色'),
                    ]
                  : boundNames
                      .map((name) => _BindingChip(label: '绑定：$name'))
                      .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _BindingChip extends StatelessWidget {
  const _BindingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.activePrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Text(
        AppTheme.glitchText(label),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
      ),
    );
  }
}

class _UserProfileEditorDialog extends StatefulWidget {
  const _UserProfileEditorDialog({
    required this.characters,
    this.initialProfile,
  });

  final UserProfile? initialProfile;
  final List<CharacterProfile> characters;

  @override
  State<_UserProfileEditorDialog> createState() =>
      _UserProfileEditorDialogState();
}

class _UserProfileEditorDialogState extends State<_UserProfileEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _genderController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _personaController;
  late final Set<String> _boundCharacterIds;
  late String _avatarDataUri;
  String? _avatarError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProfile;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _genderController = TextEditingController(text: initial?.gender ?? '');
    _descriptionController =
        TextEditingController(text: initial?.description ?? '');
    _personaController = TextEditingController(text: initial?.persona ?? '');
    _boundCharacterIds = <String>{...?initial?.boundCharacterIds};
    _avatarDataUri = initial?.avatarDataUri ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _descriptionController.dispose();
    _personaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppTheme.glitchText(
        widget.initialProfile == null ? '新建用户角色' : '编辑用户角色',
      )),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _UserAvatarPicker(
                  name: _nameController.text,
                  avatarDataUri: _avatarDataUri,
                  errorText: _avatarError,
                  onPick: _pickAvatar,
                  onClear: _avatarDataUri.trim().isEmpty
                      ? null
                      : () => setState(() {
                            _avatarDataUri = '';
                            _avatarError = null;
                          }),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('用户角色名称'),
                    hintText: AppTheme.glitchText('例如：顾北辰 / 我 / 玩家主角'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入用户角色名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _genderController,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('性别（可选）'),
                    hintText: AppTheme.glitchText('例如：女 / 男 / 非二元 / 按剧情生成'),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('一句话简介（可选）'),
                    hintText: AppTheme.glitchText('例如：一个刚转学到新学校的高一新生。'),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _personaController,
                  minLines: 8,
                  maxLines: null,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('用户人设'),
                    hintText: AppTheme.glitchText('写清楚你的身份、性格、背景、说话方式、目标和边界。'),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入用户人设';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  AppTheme.glitchText('绑定角色'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  AppTheme.glitchText('不绑定也可以，角色会按原逻辑正常回复。'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textWeak,
                      ),
                ),
                const SizedBox(height: 8),
                for (final character in widget.characters)
                  CheckboxListTile(
                    value: _boundCharacterIds.contains(character.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _boundCharacterIds.add(character.id);
                        } else {
                          _boundCharacterIds.remove(character.id);
                        }
                      });
                    },
                    title: Text(character.name),
                    subtitle: character.description.trim().isEmpty
                        ? null
                        : Text(character.description),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(AppTheme.glitchText('保存')),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      UserProfileDraft(
        name: _nameController.text.trim(),
        avatarDataUri: _avatarDataUri.trim(),
        gender: _genderController.text.trim(),
        description: _descriptionController.text.trim(),
        persona: _personaController.text.trim(),
        boundCharacterIds: _boundCharacterIds.toList(growable: false),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await pickLocalImageFileData();
      if (file == null) {
        return;
      }
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        setState(() => _avatarError = '没有读到头像图片内容。');
        return;
      }
      const maxBytes = 2 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        setState(() => _avatarError = '头像图片不能超过 2MB。');
        return;
      }
      setState(() {
        _avatarDataUri =
            'data:${_avatarMimeType(file.mimeType, file.extension)};base64,${base64Encode(bytes)}';
        _avatarError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _avatarMimeType(String? mimeType, String? extension) {
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }
    return switch (extension?.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/png',
    };
  }
}

class _UserAvatarPicker extends StatelessWidget {
  const _UserAvatarPicker({
    required this.name,
    required this.avatarDataUri,
    required this.errorText,
    required this.onPick,
    required this.onClear,
  });

  final String name;
  final String avatarDataUri;
  final String? errorText;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        children: <Widget>[
          CharacterAvatar(
            name: name.trim().isEmpty ? '用户' : name,
            avatarDataUri: avatarDataUri,
            selected: true,
            size: 64,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('用户头像'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTheme.glitchText('绑定到文游后，可作为你的主角头像显示。'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                ),
                if (errorText != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    AppTheme.glitchText(errorText!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: onPick,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(AppTheme.glitchText('上传头像')),
                    ),
                    if (onClear != null)
                      TextButton(
                        onPressed: onClear,
                        child: Text(AppTheme.glitchText('清除')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
