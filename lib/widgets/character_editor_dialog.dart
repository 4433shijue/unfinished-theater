import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/preset_characters.dart';
import '../models/character_profile.dart';
import '../models/model_params.dart';
import '../models/simulator_prompt_request.dart';
import '../services/archive_file_picker.dart';
import '../services/local_image_picker.dart';
import '../services/text_document_parser.dart';
import '../theme/app_theme.dart';
import 'character_avatar.dart';

enum _CharacterCreationMode {
  manual,
  generatedSimulator,
}

class CharacterEditorDialog extends StatefulWidget {
  const CharacterEditorDialog({
    super.key,
    this.initialCharacter,
    this.onGenerateSimulatorPrompt,
  });

  final CharacterProfile? initialCharacter;
  final Future<SimulatorPromptGenerationResult> Function(
    SimulatorPromptGenerationRequest request, {
    void Function(String partial)? onChunk,
  })? onGenerateSimulatorPrompt;

  @override
  State<CharacterEditorDialog> createState() => _CharacterEditorDialogState();
}

class _CharacterEditorDialogState extends State<CharacterEditorDialog> {
  static final List<int?> _contextLengthOptions = <int?>[
    ...List<int>.generate(36, (index) => index + 5),
    null,
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _openingMessageController;
  late final TextEditingController _promptController;
  late final TextEditingController _simulatorIdeaController;
  late final TextEditingController _styleHintController;
  late final TextEditingController _extraConstraintsController;

  late double _temperature;
  late double _topP;
  late int _contextLengthIndex;
  late bool _streamingOutputEnabled;
  late bool _segmentedOutputEnabled;
  late bool _nextStepOptionsEnabled;
  late bool _mapModeEnabled;
  late bool _largeGroupChatModeEnabled;
  late String _avatarDataUri;

  _CharacterCreationMode _creationMode = _CharacterCreationMode.manual;
  SimulatorPromptGenerationMode _generationMode =
      SimulatorPromptGenerationMode.fullSimulator;
  bool _isGeneratingPrompt = false;
  String? _generatorError;
  String _uploadedDocumentName = '';
  String _uploadedDocumentText = '';
  final ValueNotifier<String> _generatingPromptNotifier =
      ValueNotifier<String>('');

  bool get _isPromptLocked => widget.initialCharacter?.isPromptLocked == true;
  bool get _isEditing => widget.initialCharacter != null;
  bool get _isGeneratorMode =>
      !_isEditing && _creationMode == _CharacterCreationMode.generatedSimulator;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCharacter;
    final params = initial?.modelParams ?? ModelParams.defaults();
    _nameController = TextEditingController(text: initial?.name ?? '');
    _nameController.addListener(_refreshAvatarPreview);
    _descriptionController =
        TextEditingController(text: initial?.description ?? '');
    _openingMessageController =
        TextEditingController(text: initial?.openingMessage ?? '');
    _promptController = TextEditingController(text: initial?.prompt ?? '');
    _simulatorIdeaController = TextEditingController();
    _styleHintController = TextEditingController();
    _extraConstraintsController = TextEditingController();
    _temperature = params.temperature;
    _topP = params.topP;
    _contextLengthIndex = _resolveContextLengthIndex(params.contextLength);
    _streamingOutputEnabled = initial?.streamingOutputEnabled ?? true;
    _segmentedOutputEnabled = initial?.segmentedOutputEnabled ?? false;
    _nextStepOptionsEnabled = initial?.nextStepOptionsEnabled ?? true;
    _mapModeEnabled = initial?.mapModeEnabled ?? false;
    _largeGroupChatModeEnabled = initial?.largeGroupChatModeEnabled ?? false;
    _avatarDataUri = initial?.avatarDataUri ?? '';
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshAvatarPreview);
    _nameController.dispose();
    _descriptionController.dispose();
    _openingMessageController.dispose();
    _promptController.dispose();
    _simulatorIdeaController.dispose();
    _styleHintController.dispose();
    _extraConstraintsController.dispose();
    _generatingPromptNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 560;
    final dialogWidth = math.max(
      300.0,
      math.min(680.0, size.width - (compact ? 36.0 : 72.0)),
    );

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 28,
        vertical: compact ? 18 : 24,
      ),
      titlePadding: EdgeInsets.fromLTRB(
        compact ? 18 : 26,
        compact ? 20 : 24,
        compact ? 18 : 26,
        0,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        compact ? 18 : 26,
        compact ? 14 : 18,
        compact ? 18 : 26,
        10,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        compact ? 14 : 20,
        0,
        compact ? 14 : 20,
        compact ? 14 : 20,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTheme.glitchText(_dialogTitle),
            style: compact ? theme.textTheme.headlineSmall : null,
          ),
          const SizedBox(height: 6),
          Text(
            AppTheme.glitchText(_dialogSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditing) ...[
                  const _SectionLabel(title: '创建方式'),
                  const SizedBox(height: 12),
                  SegmentedButton<_CharacterCreationMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment<_CharacterCreationMode>(
                        value: _CharacterCreationMode.manual,
                        icon: const Icon(Icons.edit_note_rounded),
                        label: Text(AppTheme.glitchText('自己编写')),
                      ),
                      ButtonSegment<_CharacterCreationMode>(
                        value: _CharacterCreationMode.generatedSimulator,
                        icon: const Icon(Icons.edit_note_rounded),
                        label: Text(AppTheme.glitchText('帮你写')),
                      ),
                    ],
                    selected: <_CharacterCreationMode>{_creationMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _creationMode = selection.first;
                        _generatorError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                const _SectionLabel(title: '角色基础信息'),
                const SizedBox(height: 14),
                _AvatarPicker(
                  name: _nameController.text,
                  avatarDataUri: _avatarDataUri,
                  onPick: _pickAvatar,
                  onClear: _avatarDataUri.trim().isEmpty
                      ? null
                      : () => setState(() => _avatarDataUri = ''),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText('角色名称'),
                    hintText: _isGeneratorMode
                        ? AppTheme.glitchText('可以留空，AI 会根据灵感自动起名')
                        : AppTheme.glitchText('例如：深夜店长 / 恋爱助理 / 古怪学长'),
                  ),
                  validator: (value) {
                    if (!_isGeneratorMode &&
                        (value == null || value.trim().isEmpty)) {
                      return '请输入角色名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                if (!_isPromptLocked)
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: AppTheme.glitchText('一句话简介（可选）'),
                      hintText: AppTheme.glitchText(
                        '例如：她永远在深夜便利店等你。或：你要在深宫中活到最后。',
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                if (!_isPromptLocked) const SizedBox(height: 14),
                TextFormField(
                  controller: _openingMessageController,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: AppTheme.glitchText(
                      _isPromptLocked ? '预设开场白' : '开场白（可选）',
                    ),
                    hintText: AppTheme.glitchText(
                      '留空则不会自动发送开场白。可使用 {user}，绑定用户角色后会自动替换成用户角色名称。',
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                if (_isPromptLocked)
                  _LockedPromptNotice(character: widget.initialCharacter!)
                else if (_isGeneratorMode)
                  _buildGeneratorSection(context)
                else
                  _buildManualPromptSection(context),
                const SizedBox(height: 26),
                const _SectionLabel(title: '模型参数'),
                const SizedBox(height: 14),
                _SliderField(
                  label: 'Temperature',
                  value: _temperature,
                  min: 0,
                  max: 2,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() => _temperature = value);
                  },
                ),
                const SizedBox(height: 10),
                _SliderField(
                  label: 'Top P',
                  value: _topP,
                  min: 0.1,
                  max: 1,
                  divisions: 18,
                  onChanged: (value) {
                    setState(() => _topP = value);
                  },
                ),
                const SizedBox(height: 14),
                _ContextLengthSliderField(
                  valueLabel: _selectedContextLength == null
                      ? '不限消息条数'
                      : '${_selectedContextLength!} 条',
                  sliderValue: _contextLengthIndex.toDouble(),
                  max: (_contextLengthOptions.length - 1).toDouble(),
                  divisions: _contextLengthOptions.length - 1,
                  onChanged: (value) {
                    setState(() => _contextLengthIndex = value.round());
                  },
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  value: _streamingOutputEnabled,
                  onChanged: (value) {
                    setState(() => _streamingOutputEnabled = value);
                  },
                  title: Text(AppTheme.glitchText('流式输出')),
                  subtitle: Text(
                    AppTheme.glitchText(
                      '开启后，角色回复时先显示纯文字；HTML/CSS/JS 等代码部分会等生成完成后再渲染。',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _segmentedOutputEnabled,
                  onChanged: _largeGroupChatModeEnabled
                      ? null
                      : (value) {
                          setState(() => _segmentedOutputEnabled = value);
                        },
                  title: Text(AppTheme.glitchText('分段输出')),
                  subtitle: Text(
                    AppTheme.glitchText(
                      _largeGroupChatModeEnabled
                          ? '大型群聊模式会接管气泡拆分，这个开关会自动关闭。'
                          : '开启后，角色的一次回复可以拆成多个气泡显示，选项仍会固定在最底部。',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _nextStepOptionsEnabled,
                  onChanged: _largeGroupChatModeEnabled
                      ? null
                      : (value) {
                          setState(() => _nextStepOptionsEnabled = value);
                        },
                  title: Text(AppTheme.glitchText('下一步选项')),
                  subtitle: Text(
                    AppTheme.glitchText(
                      _largeGroupChatModeEnabled
                          ? '大型群聊模式不会生成六个行动选项。'
                          : '关闭后，角色不再生成选项，更适合只阅读小说式正文。',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _mapModeEnabled,
                  onChanged:
                      _largeGroupChatModeEnabled ? null : _handleMapModeToggle,
                  title: Text(AppTheme.glitchText('固定地图主线模式')),
                  subtitle: Text(
                    AppTheme.glitchText(
                      _largeGroupChatModeEnabled
                          ? '大型群聊模式已接管主线，不能同时开启地图模式。'
                          : 'AI 开局生成固定地图；之后每回合先结算路线与行动，再由 AI 续写主线剧情。开启后不能退回普通文游。',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _largeGroupChatModeEnabled,
                  onChanged:
                      _mapModeEnabled ? null : _handleLargeGroupChatModeToggle,
                  title: Text(AppTheme.glitchText('大型群聊模式')),
                  subtitle: Text(
                    AppTheme.glitchText(
                      _mapModeEnabled
                          ? '地图主线模式已接管主线，不能同时开启大型群聊。'
                          : '开启后 AI 回复会变成旁白和当前场景 NPC 的群聊气泡流，只保留状态面板和随机 NPC 私聊；开启后不能退回普通文游。',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isGeneratingPrompt ? null : () => Navigator.of(context).pop(),
          child: Text(AppTheme.glitchText('取消')),
        ),
        FilledButton(
          onPressed: _isGeneratingPrompt ? null : _submit,
          child: Text(AppTheme.glitchText(_isEditing ? '保存修改' : '创建角色')),
        ),
      ],
    );
  }

  Widget _buildGeneratorSection(BuildContext context) {
    final canGenerate = widget.onGenerateSimulatorPrompt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.translucentPanelFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.activeLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTheme.glitchText('自定义一个文游模拟器'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.contrastText,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppTheme.glitchText(
                  '给程序一句灵感，比如“你是一个宫斗模拟器”，它会帮你生成一整套适配本程序玩法的系统提示词。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppTheme.glitchText('生成模式'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<SimulatorPromptGenerationMode>(
          showSelectedIcon: false,
          segments: <ButtonSegment<SimulatorPromptGenerationMode>>[
            ButtonSegment<SimulatorPromptGenerationMode>(
              value: SimulatorPromptGenerationMode.fullSimulator,
              icon: const Icon(Icons.sports_esports_outlined),
              label: Text(AppTheme.glitchText('完整模拟器')),
            ),
            ButtonSegment<SimulatorPromptGenerationMode>(
              value: SimulatorPromptGenerationMode.worldStage,
              icon: const Icon(Icons.public_outlined),
              label: Text(AppTheme.glitchText('只生成世界观')),
            ),
          ],
          selected: <SimulatorPromptGenerationMode>{_generationMode},
          onSelectionChanged: _isGeneratingPrompt
              ? null
              : (selection) {
                  setState(() => _generationMode = selection.first);
                },
        ),
        const SizedBox(height: 8),
        Text(
          AppTheme.glitchText(
            _generationMode == SimulatorPromptGenerationMode.worldStage
                ? '适合带着自己和绑定 NPC 进入新世界游玩，AI 主要搭舞台、规则和开局。'
                : '适合直接生成一整套可玩的模拟器，含世界、玩法、NPC 和长期主线。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _simulatorIdeaController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('文游灵感'),
            hintText: AppTheme.glitchText(
              '例如：你是一个宫斗模拟器。或：你是一个宗门经营模拟器。',
            ),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (_isGeneratorMode && (value == null || value.trim().isEmpty)) {
              return '请输入文游灵感';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _DocumentUploadRow(
          fileName: _uploadedDocumentName,
          textLength: _uploadedDocumentText.length,
          onUpload: _uploadGeneratorDocument,
          onClear: _uploadedDocumentText.isEmpty
              ? null
              : () {
                  setState(() {
                    _uploadedDocumentName = '';
                    _uploadedDocumentText = '';
                  });
                },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _styleHintController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('风格补充（可选）'),
            hintText: AppTheme.glitchText(
              '例如：偏细腻权谋，少一点系统感，多一点情绪流动。',
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _extraConstraintsController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('额外限制（可选）'),
            hintText: AppTheme.glitchText(
              '例如：不要仙侠，不要超自然，不要复杂名词堆砌。',
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTheme.glitchText(
                canGenerate
                    ? '会调用当前配置好的模型，先帮你写出一版完整提示词。'
                    : '当前没有可用的提示词生成器回调，请稍后重试。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textWeak,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: (!canGenerate || _isGeneratingPrompt)
                  ? null
                  : _generateSimulatorPrompt,
              icon: _isGeneratingPrompt
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                  AppTheme.glitchText(_isGeneratingPrompt ? '生成中' : '生成提示词')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: (!canGenerate || _isGeneratingPrompt)
                  ? null
                  : _generateBlindBoxSimulatorPrompt,
              icon: const Icon(Icons.casino_outlined),
              label: Text(AppTheme.glitchText('开盲盒')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: (!canGenerate || _isGeneratingPrompt)
                  ? null
                  : _generateClassicBlindBoxSimulatorPrompt,
              icon: const Icon(Icons.history_edu_outlined),
              label: Text(AppTheme.glitchText('开盲盒（怀旧版）')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<String>(
          valueListenable: _generatingPromptNotifier,
          builder: (context, liveText, _) {
            if (liveText.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              constraints: const BoxConstraints(maxHeight: 220),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.translucentPanelFillStrong,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.activeLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppTheme.glitchText(
                            '正在生成…（已输出 ${liveText.length} 字）',
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textWeak,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        AppTheme.glitchText(_formatGenerationPreview(liveText)),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              height: 1.5,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_generatorError != null) ...[
          const SizedBox(height: 10),
          Text(
            AppTheme.glitchText(_generatorError!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          controller: _promptController,
          minLines: 10,
          maxLines: null,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('生成的系统提示词（可修改）'),
            hintText: AppTheme.glitchText(
              '点击上方“生成提示词”后，这里会出现完整结果。你也可以继续手动修改。',
            ),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (_isGeneratorMode && (value == null || value.trim().isEmpty)) {
              return '请先生成一版提示词，或直接在这里手动补全';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildManualPromptSection(BuildContext context) {
    final canPolish = widget.onGenerateSimulatorPrompt != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextFormField(
          controller: _promptController,
          minLines: 8,
          maxLines: null,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('角色提示词'),
            hintText: AppTheme.glitchText(
              '描述角色身份、说话方式、边界、互动习惯、剧情偏好等，支持长文本直接粘贴。',
            ),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (!_isGeneratorMode && (value == null || value.trim().isEmpty)) {
              return '请输入角色提示词';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed:
                  (!canPolish || _isGeneratingPrompt) ? null : _polishCharacter,
              icon: _isGeneratingPrompt
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high_rounded),
              label: Text(
                  AppTheme.glitchText(_isGeneratingPrompt ? '润色中' : '润色你的人物')),
            ),
            OutlinedButton.icon(
              onPressed: _isGeneratingPrompt ? null : _uploadManualDocument,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(AppTheme.glitchText('上传文件')),
            ),
            Text(
              AppTheme.glitchText('把你写的人物扩展成可游玩的文游模拟器，结果仍可手动修改。'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textWeak,
                  ),
            ),
          ],
        ),
        if (_generatorError != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            AppTheme.glitchText(_generatorError!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ],
    );
  }

  Future<void> _generateSimulatorPrompt() async {
    final name = _nameController.text.trim();
    final idea = _simulatorIdeaController.text.trim();

    if (idea.isEmpty) {
      setState(() => _generatorError = '请先填写文游灵感。');
      return;
    }

    setState(() {
      _isGeneratingPrompt = true;
      _generatorError = null;
    });

    try {
      final result = await widget.onGenerateSimulatorPrompt!(
        SimulatorPromptGenerationRequest(
          roleName: name,
          simulatorIdea: idea,
          shortDescription: _descriptionController.text.trim(),
          styleHint: _styleHintController.text.trim(),
          extraConstraints: _extraConstraintsController.text.trim(),
          uploadedDocumentText: _uploadedDocumentText,
          mode: _generationMode,
        ),
        onChunk: _applyGeneratedChunk,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _promptController.text = result.prompt;
        _openingMessageController.text = result.openingMessage;
        final generatedName = result.name.trim().isNotEmpty
            ? result.name
            : (_extractGeneratedSimulatorName(result.prompt) ?? '');
        if (generatedName.isNotEmpty) {
          _nameController.text = generatedName;
        }
        if (_descriptionController.text.trim().isEmpty) {
          _descriptionController.text = result.description;
        }
        if (_generationMode == SimulatorPromptGenerationMode.worldStage &&
            !_nameController.text.contains('世界')) {
          _nameController.text = '${_nameController.text.trim()}世界';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generatorError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        _generatingPromptNotifier.value = '';
        setState(() => _isGeneratingPrompt = false);
      }
    }
  }

  /// 流式生成期间把原始输出（JSON）送进实时预览区。
  /// 生成完成后由结果拆包填进各个输入框。
  void _applyGeneratedChunk(String partial) {
    if (mounted) {
      _generatingPromptNotifier.value = partial;
    }
  }

  /// 预览区展示：能解析成 JSON 时显示成易读的分段格式，
  /// JSON 不完整（流式中）时直接显示原始文本。
  String _formatGenerationPreview(String raw) {
    final trimmed = raw.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final name = decoded['name']?.toString().trim() ?? '';
        final description = decoded['description']?.toString().trim() ?? '';
        final opening = decoded['opening']?.toString().trim() ?? '';
        final systemPrompt = decoded['systemPrompt']?.toString().trim() ?? '';
        final buffer = StringBuffer();
        if (name.isNotEmpty) {
          buffer.writeln('【名称】$name');
        }
        if (description.isNotEmpty) {
          buffer.writeln('【简介】$description');
        }
        if (opening.isNotEmpty) {
          buffer.writeln('【开场白】\n$opening');
        }
        if (systemPrompt.isNotEmpty) {
          buffer.writeln('【系统提示词】\n$systemPrompt');
        }
        if (buffer.isNotEmpty) {
          return buffer.toString().trim();
        }
      }
    } catch (_) {
      // 流式中间态 JSON 不完整，走原始文本展示。
    }
    return trimmed;
  }

  Future<void> _generateBlindBoxSimulatorPrompt() async {
    if (widget.onGenerateSimulatorPrompt == null) {
      return;
    }

    const fallbackName = '原创文游模拟器';
    const blindBoxInstruction = '''
开盲盒模式：请你自主决定一个“实打实可长期游玩”的文字游戏模拟器题材、正式名称、核心循环、成长系统、人物关系网和长期事件机制。

这不是生成“盲盒模拟器”，也不是生成“随机模拟器”。“开盲盒”只是按钮名字，最终结果必须是一个具体题材的模拟器。
不要把模拟器命名为“盲盒文游模拟器”“开盲盒模拟器”“随机模拟器”。请给出一个符合题材的正式名称。

题材可以从以下方向中选择或组合：恋爱养成、都市职业、冒险探索、轻恐悬疑、解密推理、生活经营、旅行公路、娱乐圈、校园社交、乡镇成长、店铺经营、家族经营、怪谈日常、非传统修行、奇妙职业、社群经营、旧城故事、荒岛求生、博物馆修复、邮局来信、梦境旅馆等。

可以有想象力，但必须具体、耐玩、有生活细节、有长期成长线。

请尽量生成新颖、小众、让用户眼前一亮的玩法模拟器。
请在生成的提示词开头写出：模拟器名称：XXX
''';

    setState(() {
      _isGeneratingPrompt = true;
      _generatorError = null;
    });

    try {
      final result = await widget.onGenerateSimulatorPrompt!(
        SimulatorPromptGenerationRequest(
          roleName: fallbackName,
          simulatorIdea: blindBoxInstruction,
          shortDescription: '',
          styleHint: _styleHintController.text.trim(),
          extraConstraints:
              '${_extraConstraintsController.text.trim()}\n\n$blindBoxInstruction',
          uploadedDocumentText: _uploadedDocumentText,
          mode: _generationMode,
        ),
        onChunk: _applyGeneratedChunk,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _promptController.text = result.prompt;
        _openingMessageController.text = result.openingMessage;
        final generatedName = result.name.trim().isNotEmpty
            ? result.name
            : (_extractGeneratedSimulatorName(result.prompt) ?? '');
        if (generatedName.isNotEmpty) {
          _nameController.text = generatedName;
        }
        if (_descriptionController.text.trim().isEmpty) {
          _descriptionController.text = result.description;
        }
        _simulatorIdeaController.text = '开盲盒：随机生成模拟器题材。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generatorError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        _generatingPromptNotifier.value = '';
        setState(() => _isGeneratingPrompt = false);
      }
    }
  }

  Future<void> _generateClassicBlindBoxSimulatorPrompt() async {
    if (widget.onGenerateSimulatorPrompt == null) {
      return;
    }

    const fallbackName = '原创文游模拟器';
    const blindBoxInstruction = '''
怀旧版开盲盒模式：请你自主决定一个“实打实可长期游玩”的传统文字游戏模拟器题材、正式名称、核心循环、成长系统、人物关系网和长期事件机制。

这不是生成“盲盒模拟器”，也不是生成“随机模拟器”。“开盲盒（怀旧版）”只是按钮名字，最终结果必须是一个具体题材的模拟器。
不要把模拟器命名为“盲盒文游模拟器”“开盲盒模拟器”“随机模拟器”。请给出一个符合题材的正式名称。

怀旧版重点不是猎奇创新，而是传统、上头、耐玩、容易理解。题材可以从以下方向中选择：校园恋爱、宫廷宅院、江湖门派、修仙宗门、娱乐圈成长、民国旧梦、古风探案、种田经营、学院成长、家族养成、商铺经营、闺阁成长、门派经营、旅馆经营、王府日常、县城生活等。

可以有宫廷、家族、门派、学院、恋爱、经营、探案、成长等多种传统文游味道。
玩法要有清晰主线、阶段目标、属性成长、NPC 羁绊、资源管理、突发事件和长期结局。
请在生成的提示词开头写出：模拟器名称：XXX
''';

    setState(() {
      _isGeneratingPrompt = true;
      _generatorError = null;
    });

    try {
      final result = await widget.onGenerateSimulatorPrompt!(
        SimulatorPromptGenerationRequest(
          roleName: fallbackName,
          simulatorIdea: blindBoxInstruction,
          shortDescription: '',
          styleHint: _styleHintController.text.trim(),
          extraConstraints:
              '${_extraConstraintsController.text.trim()}\n\n$blindBoxInstruction',
          uploadedDocumentText: _uploadedDocumentText,
          mode: _generationMode,
        ),
        onChunk: _applyGeneratedChunk,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _promptController.text = result.prompt;
        _openingMessageController.text = result.openingMessage;
        final generatedName = result.name.trim().isNotEmpty
            ? result.name
            : (_extractGeneratedSimulatorName(result.prompt) ?? '');
        if (generatedName.isNotEmpty) {
          _nameController.text = generatedName;
        }
        if (_descriptionController.text.trim().isEmpty) {
          _descriptionController.text = result.description;
        }
        _simulatorIdeaController.text = '开盲盒（怀旧版）：生成传统耐玩的模拟器题材。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generatorError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        _generatingPromptNotifier.value = '';
        setState(() => _isGeneratingPrompt = false);
      }
    }
  }

  Future<void> _polishCharacter() async {
    if (widget.onGenerateSimulatorPrompt == null) {
      return;
    }

    final rawPrompt = _promptController.text.trim();
    if (rawPrompt.isEmpty) {
      setState(() => _generatorError = '请先写一点角色提示词，再让我帮你润色。');
      return;
    }

    final name = _nameController.text.trim().isEmpty
        ? '润色后的人物'
        : _nameController.text.trim();
    final polishIdea = '''
润色人物模式：用户已经上传了一段 AI 角色设定。请保留原始角色的核心身份、语气、关系偏好和互动边界，不要抹掉用户的创意。
你的任务是把它扩写成一个“可长期游玩的文游模拟器型角色提示词”，让这个角色不仅能聊天，也能驱动剧情、任务、状态、NPC、背包和事件卡。

【用户原始角色设定】
$rawPrompt
''';

    setState(() {
      _isGeneratingPrompt = true;
      _generatorError = null;
    });

    try {
      final result = await widget.onGenerateSimulatorPrompt!(
        SimulatorPromptGenerationRequest(
          roleName: name,
          simulatorIdea: polishIdea,
          shortDescription: _descriptionController.text.trim(),
          styleHint: '保留用户原设定的味道，增强可玩性、长期推进能力和状态面板适配。',
          extraConstraints: _extraConstraintsController.text.trim(),
          uploadedDocumentText: _uploadedDocumentText,
          mode: SimulatorPromptGenerationMode.fullSimulator,
        ),
        onChunk: _applyGeneratedChunk,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _promptController.text = result.prompt;
        _openingMessageController.text = result.openingMessage;
        final generatedName = result.name.trim().isNotEmpty
            ? result.name
            : (_extractGeneratedSimulatorName(result.prompt) ?? '');
        if (generatedName.isNotEmpty) {
          _nameController.text = generatedName;
        }
        if (_descriptionController.text.trim().isEmpty) {
          _descriptionController.text = result.description;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generatorError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        _generatingPromptNotifier.value = '';
        setState(() => _isGeneratingPrompt = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await pickLocalImageFileData();
      if (file == null) {
        return;
      }
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        setState(() => _generatorError = '没有读到头像图片内容。');
        return;
      }
      const maxBytes = 2 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        setState(() => _generatorError = '头像图片不能超过 2MB。');
        return;
      }
      setState(() {
        _avatarDataUri =
            'data:${_avatarMimeType(file.mimeType, file.extension)};base64,${base64Encode(bytes)}';
        _generatorError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generatorError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _uploadGeneratorDocument() async {
    await _pickTextDocument(
      onParsed: (fileName, text) {
        setState(() {
          _uploadedDocumentName = fileName;
          _uploadedDocumentText = text;
          _generatorError = null;
        });
      },
    );
  }

  Future<void> _uploadManualDocument() async {
    await _pickTextDocument(
      onParsed: (fileName, text) {
        final current = _promptController.text.trim();
        final nextText =
            current.isEmpty ? text : '$current\n\n【上传文件：$fileName】\n$text';
        setState(() {
          _uploadedDocumentName = fileName;
          _uploadedDocumentText = text;
          _promptController.text = nextText;
          _generatorError = null;
        });
      },
    );
  }

  Future<void> _pickTextDocument({
    required void Function(String fileName, String text) onParsed,
  }) async {
    try {
      final file = await pickArchiveFileData(
        allowedExtensions: const <String>['md', 'json', 'doc', 'docx', 'txt'],
        webAccept:
            '.md,.json,.doc,.docx,.txt,text/markdown,application/json,text/plain,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      if (file == null) {
        return;
      }
      final parsed = TextDocumentParser.parse(
        fileName: file.name,
        bytes: file.bytes,
      ).trim();
      if (parsed.isEmpty) {
        setState(() => _generatorError = '文件里没有解析到可用文本。');
        return;
      }
      onParsed(file.name, parsed);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generatorError =
            '文件解析失败：${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  void _refreshAvatarPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleMapModeToggle(bool value) async {
    if (!value && widget.initialCharacter?.mapModeEnabled == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('地图主线已开启，不能退回普通文游模式。'))),
      );
      return;
    }
    if (!value) {
      setState(() => _mapModeEnabled = false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTheme.glitchText('开启固定地图主线')),
        content: Text(
          AppTheme.glitchText(
            '开启后，AI 会先生成一次固定地图蓝图。选定出生点后，移动、行动、NPC 和事件先由本地规则结算，再调用 AI 根据结算结果续写主线剧情。你可以通过横屏地图、路线和行动篮子推进；开启后不能退回普通文游模式。',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppTheme.glitchText('确认开启')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _mapModeEnabled = true);
  }

  Future<void> _handleLargeGroupChatModeToggle(bool value) async {
    if (!value && widget.initialCharacter?.largeGroupChatModeEnabled == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('大型群聊模式已开启，不能退回普通文游模式。'))),
      );
      return;
    }
    if (value && widget.initialCharacter?.mapModeEnabled == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTheme.glitchText('地图主线已开启，不能切换为大型群聊模式。'))),
      );
      return;
    }
    if (!value) {
      setState(() => _largeGroupChatModeEnabled = false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTheme.glitchText('开启大型群聊模式')),
        content: Text(
          AppTheme.glitchText(
            '开启后，这个模拟器的 AI 回复会由旁白和当前场景 NPC 的群聊气泡组成，不再生成六个选项和 HTML 美化框，只保留状态面板与随机 NPC 私聊。开启后不能退回普通文游模式。',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppTheme.glitchText('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppTheme.glitchText('确认开启')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() {
      _largeGroupChatModeEnabled = true;
      _mapModeEnabled = false;
      _segmentedOutputEnabled = false;
      _nextStepOptionsEnabled = false;
    });
  }

  String? _extractGeneratedSimulatorName(String prompt) {
    final match = RegExp(r'模拟器名称[：:]\s*([^\n\r]+)').firstMatch(prompt);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.replaceAll(RegExp(r'[《》「」"“”]'), '').trim();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    var submittedName = _nameController.text.trim();
    if (submittedName.isEmpty && _isGeneratorMode) {
      submittedName = _extractGeneratedSimulatorName(_promptController.text) ??
          (_generationMode == SimulatorPromptGenerationMode.worldStage
              ? '未命名世界'
              : '未命名模拟器');
    }

    Navigator.of(context).pop(
      CharacterDraft(
        name: submittedName,
        description: _isPromptLocked
            ? widget.initialCharacter!.description
            : _descriptionController.text.trim(),
        openingMessage: _openingMessageController.text.trim(),
        prompt: _isPromptLocked
            ? widget.initialCharacter!.prompt
            : _promptController.text.trim(),
        hiddenPrompt: _isPromptLocked
            ? widget.initialCharacter!.hiddenPrompt
            : simulatorRuntimeProtocolPrompt,
        streamingOutputEnabled: _streamingOutputEnabled,
        segmentedOutputEnabled: _segmentedOutputEnabled,
        nextStepOptionsEnabled: _nextStepOptionsEnabled,
        mapModeEnabled: _mapModeEnabled,
        largeGroupChatModeEnabled: _largeGroupChatModeEnabled,
        avatarDataUri: _avatarDataUri,
        modelParams: ModelParams(
          temperature: double.parse(_temperature.toStringAsFixed(2)),
          topP: double.parse(_topP.toStringAsFixed(2)),
          contextLength: _selectedContextLength ?? 0,
        ),
      ),
    );
  }

  String get _dialogTitle {
    if (_isEditing) {
      return '编辑角色';
    }
    if (_isGeneratorMode) {
      return '创建文游模拟器';
    }
    return '新建角色';
  }

  String get _dialogSubtitle {
    if (_isPromptLocked) {
      return '这是系统预设角色。你可以改名字和模型参数，但底层提示词不会对外显示。';
    }
    if (_isGeneratorMode) {
      return '输入一个灵感，让程序帮你生成一份完整的模拟器型系统提示词。';
    }
    return '让这个角色拥有自己的语气、边界和记忆风格。';
  }

  int? get _selectedContextLength => _contextLengthOptions[_contextLengthIndex];

  int _resolveContextLengthIndex(int contextLength) {
    if (contextLength <= 0) {
      return _contextLengthOptions.length - 1;
    }

    final index = _contextLengthOptions.indexOf(contextLength);
    if (index != -1) {
      return index;
    }

    if (contextLength < 5) {
      return 0;
    }

    return _contextLengthOptions.length - 2;
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

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.name,
    required this.avatarDataUri,
    required this.onPick,
    required this.onClear,
  });

  final String name;
  final String avatarDataUri;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        children: <Widget>[
          CharacterAvatar(
            name: name,
            avatarDataUri: avatarDataUri,
            selected: true,
            size: 66,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('头像'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.contrastText,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTheme.glitchText('支持从手机或电脑本地选择图片。'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
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

class _LockedPromptNotice extends StatelessWidget {
  const _LockedPromptNotice({required this.character});

  final CharacterProfile character;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.activeAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                AppTheme.glitchText('系统预设提示词已锁定'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.contrastText,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            character.visibleBlurb,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(
            AppTheme.glitchText(
              '这个角色的底层提示词不会对用户显示，也不能在这里修改。你仍然可以自由调整 Temperature、Top P 和上下文长度。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _DocumentUploadRow extends StatelessWidget {
  const _DocumentUploadRow({
    required this.fileName,
    required this.textLength,
    required this.onUpload,
    required this.onClear,
  });

  final String fileName;
  final int textLength;
  final VoidCallback onUpload;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName.trim().isNotEmpty && textLength > 0;
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
          Icon(
            hasFile ? Icons.description_rounded : Icons.upload_file_rounded,
            color: AppTheme.activeSoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasFile
                  ? '$fileName · 已读取 $textLength 字'
                  : '上传 md/json/doc/docx/txt 作为生成基础',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: hasFile ? AppTheme.contrastText : AppTheme.textMuted,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_rounded),
            label: Text(AppTheme.glitchText(hasFile ? '换文件' : '上传')),
          ),
          if (onClear != null) ...<Widget>[
            const SizedBox(width: 6),
            IconButton(
              tooltip: AppTheme.glitchText('清除文件'),
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppTheme.glitchText(title),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.activeSoft,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppTheme.glitchText(label),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ContextLengthSliderField extends StatelessWidget {
  const _ContextLengthSliderField({
    required this.valueLabel,
    required this.sliderValue,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String valueLabel;
  final double sliderValue;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppTheme.glitchText('上下文消息数'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            Text(
              AppTheme.glitchText(valueLabel),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
        Slider(
          value: sliderValue.clamp(0, max).toDouble(),
          min: 0,
          max: max,
          divisions: divisions,
          label: AppTheme.glitchText(valueLabel),
          onChanged: onChanged,
        ),
        Text(
          AppTheme.glitchText('最少 5 条，拖到最右侧表示不限消息条数。'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textWeak,
              ),
        ),
      ],
    );
  }
}
