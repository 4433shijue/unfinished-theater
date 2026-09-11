import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../models/world_book.dart';
import '../theme/app_theme.dart';

class WorldBookEditorDialog extends StatefulWidget {
  const WorldBookEditorDialog({
    super.key,
    this.initialEntry,
  });

  final WorldBookEntry? initialEntry;

  @override
  State<WorldBookEditorDialog> createState() => _WorldBookEditorDialogState();
}

class _WorldBookEditorDialogState extends State<WorldBookEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  late bool _isGlobal;
  late Set<String> _selectedCharacterIds;
  late WorldBookInjectionPosition _injectionPosition;
  late double _priority;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _contentController = TextEditingController(text: entry?.content ?? '');
    _tagsController = TextEditingController(text: entry?.tags.join('、') ?? '');
    _isGlobal = entry?.global ?? false;
    _selectedCharacterIds =
        Set<String>.from(entry?.boundCharacterIds ?? <String>[]);
    _injectionPosition =
        entry?.injectionPosition ?? WorldBookInjectionPosition.middle;
    _priority = (entry?.priority ?? 50).toDouble();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  bool get isEditing => widget.initialEntry != null;

  void _submit() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      WorldBookDraft(
        title: title,
        content: content,
        global: _isGlobal,
        tags: _parseTags(_tagsController.text),
        boundCharacterIds: _isGlobal
            ? const <String>[]
            : _selectedCharacterIds.toList(growable: false),
        triggerMode: WorldBookTriggerMode.always,
        keywords: const <String>[],
        regexPattern: '',
        injectionPosition: _injectionPosition,
        priority: _priority.round(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppStateController>();
    final characters = controller.characters;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 620;
    final longContent = _contentController.text.trim().length > 260;
    final dialogWidth = math.max(
      300.0,
      math.min(
          longContent ? 760.0 : 520.0, size.width - (compact ? 28.0 : 72.0)),
    );

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: AppTheme.glassPanel(highlighted: true, radius: 24),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
        child: Text(
          AppTheme.glitchText(isEditing ? '编辑世界书' : '新建世界书'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      content: SingleChildScrollView(
        child: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTheme.glitchText('标题'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '输入标题',
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 20),
              Text(
                AppTheme.glitchText('内容'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: '输入世界书内容...',
                ),
                maxLines: longContent ? 18 : 8,
                minLines: longContent ? 10 : 4,
              ),
              const SizedBox(height: 20),
              Text(
                AppTheme.glitchText('标签'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  hintText: '例如：学院、NPC关系、城市规则',
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 20),
              Text(
                AppTheme.glitchText('注入位置'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WorldBookInjectionPosition.values.map((position) {
                  return ChoiceChip(
                    label: Text(AppTheme.glitchText(position.label)),
                    selected: _injectionPosition == position,
                    onSelected: (_) {
                      setState(() => _injectionPosition = position);
                    },
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText(_positionHint(_injectionPosition)),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Text(
                    AppTheme.glitchText('优先级 ${_priority.round()}'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: _priority,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: _priority.round().toString(),
                      onChanged: (value) => setState(() => _priority = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: Checkbox(
                      value: _isGlobal,
                      onChanged: (value) {
                        setState(() {
                          _isGlobal = value ?? false;
                          if (_isGlobal) {
                            _selectedCharacterIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isGlobal = !_isGlobal;
                        if (_isGlobal) {
                          _selectedCharacterIds.clear();
                        }
                      });
                    },
                    child: Text(
                      AppTheme.glitchText('全局生效'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (!_isGlobal) ...[
                const SizedBox(height: 16),
                Text(
                  AppTheme.glitchText('绑定角色'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                const SizedBox(height: 8),
                if (characters.isEmpty)
                  Text(
                    AppTheme.glitchText('还没有角色，请先创建角色。'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.translucentPanelFill,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.activeLine),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: characters.map((character) {
                        final isBound =
                            _selectedCharacterIds.contains(character.id);
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              if (isBound) {
                                _selectedCharacterIds.remove(character.id);
                              } else {
                                _selectedCharacterIds.add(character.id);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: Checkbox(
                                    value: isBound,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedCharacterIds
                                              .add(character.id);
                                        } else {
                                          _selectedCharacterIds
                                              .remove(character.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    character.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: isBound
                                              ? AppTheme.selectedTintText
                                              : AppTheme.textMuted,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actions: [
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

  List<String> _parseTags(String raw) {
    return raw
        .split(RegExp(r'[,，、\s]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _positionHint(WorldBookInjectionPosition position) {
    switch (position) {
      case WorldBookInjectionPosition.front:
        return '适合文风、全局禁令、世界边界，靠近角色设定前部。';
      case WorldBookInjectionPosition.middle:
        return '适合世界观、玩法规则、长期背景，跟角色设定一起生效。';
      case WorldBookInjectionPosition.rear:
        return '适合当前地点、NPC、道具、关键事实，靠近本轮状态。';
    }
  }
}
