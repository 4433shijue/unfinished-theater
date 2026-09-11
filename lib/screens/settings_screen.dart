import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/app_state_controller.dart';
import '../data/release_notes.dart';
import '../models/app_settings.dart';
import '../models/data_management.dart';
import '../models/gamification.dart';
import '../models/theme_style.dart';
import '../services/archive_file_picker.dart';
import '../services/data_health_service.dart';
import '../services/llm_api_client.dart';
import '../services/file_download_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_skin_assets.dart';
import '../utils/api_endpoint_resolver.dart';
import '../widgets/onboarding_tutorial_dialog.dart';
import '../widgets/release_notes_dialog.dart';
import '../widgets/tutorial_guide.dart';
import '../widgets/html_content_view.dart';

part 'settings/import_data_dialog.dart';
part 'settings/save_snapshots_dialog.dart';
part 'settings/data_cleaner_dialog.dart';
part 'settings/settings_common_widgets.dart';
part 'settings/theme_settings_widgets.dart';
part 'settings/theme_editor_dialog.dart';
part 'settings/settings_form_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LlmApiClient _apiClient = LlmApiClient();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _apiSectionKey = GlobalKey();
  final GlobalKey _memorySectionKey = GlobalKey();
  final GlobalKey _displaySectionKey = GlobalKey();
  final GlobalKey _presetSectionKey = GlobalKey();
  final GlobalKey _dataSectionKey = GlobalKey();
  final GlobalKey _infoSectionKey = GlobalKey();

  late final TextEditingController _apiUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelNameController;
  late final TextEditingController _memoryApiUrlController;
  late final TextEditingController _memoryApiKeyController;
  late final TextEditingController _memoryModelNameController;
  late final TextEditingController _presetNameController;

  bool _didLoadInitialValues = false;
  bool _obscureApiKey = true;
  bool _obscureMemoryApiKey = true;
  bool _isFetchingModels = false;
  bool _isTestingConnection = false;
  bool _isFetchingMemoryModels = false;
  bool _isTestingMemoryConnection = false;
  bool? _lastConnectionSucceeded;
  bool? _lastMemoryConnectionSucceeded;
  bool _basicThemePackExpanded = false;
  String _activeSettingsSectionId = 'api';
  String? _connectionMessage;
  String? _memoryConnectionMessage;
  List<String> _availableModels = const <String>[];
  List<String> _availableMemoryModels = const <String>[];
  String? _selectedModelId;
  String? _selectedMemoryModelId;
  double _timeoutSeconds = 180;
  double _summaryThreshold = 6;
  int _memoryContextIndex = 3;
  double _uiScale = 1;
  String _themeId = AppThemeVariant.sakura.id;
  bool _mobilePowerSaveMode = true;
  bool _includeStreamUsage = true;
  bool _allowInsecureMainApi = false;
  bool _allowInsecureMemoryApi = false;
  int _promptTokenBudget = 0;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController()..addListener(_refresh);
    _apiKeyController = TextEditingController();
    _modelNameController = TextEditingController()..addListener(_refresh);
    _memoryApiUrlController = TextEditingController()..addListener(_refresh);
    _memoryApiKeyController = TextEditingController();
    _memoryModelNameController = TextEditingController()..addListener(_refresh);
    _presetNameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitialValues) {
      return;
    }

    _applySettings(context.read<AppStateController>().settings);
    _didLoadInitialValues = true;
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _memoryApiUrlController.dispose();
    _memoryApiKeyController.dispose();
    _memoryModelNameController.dispose();
    _presetNameController.dispose();
    _scrollController.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final installId = controller.installId;
    final uiScale = AppTheme.uiScaleOf(context);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final sectionPadding = (compact ? 16.0 : 22.0) * uiScale;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all((compact ? 12 : 20) * uiScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SettingsQuickNav(
            onJump: _jumpToSection,
            activeId: _activeSettingsSectionId,
          ),
          const SizedBox(height: 18),
          _SectionCard(
            key: _apiSectionKey,
            highlighted: true,
            padding: sectionPadding,
            child: _buildApiSection(context),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            key: _memorySectionKey,
            padding: sectionPadding,
            child: _buildMemorySection(context),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            key: _displaySectionKey,
            padding: sectionPadding,
            child: _buildDisplaySection(context),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            key: _presetSectionKey,
            padding: sectionPadding,
            child: _buildPresetSection(context, controller.settingsPresets),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            key: _dataSectionKey,
            padding: sectionPadding,
            child: _buildDataPortabilitySection(context),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            key: _infoSectionKey,
            padding: sectionPadding,
            child: _buildTutorialAndInfoSection(context, installId),
          ),
        ],
      ),
    );
  }

  void _jumpToSection(String id) {
    setState(() => _activeSettingsSectionId = id);
    final key = switch (id) {
      'api' => _apiSectionKey,
      'memory' => _memorySectionKey,
      'display' => _displaySectionKey,
      'preset' => _presetSectionKey,
      'data' => _dataSectionKey,
      'info' => _infoSectionKey,
      _ => _apiSectionKey,
    };
    final label = switch (id) {
      'api' => 'API 设置',
      'memory' => '记忆设置',
      'display' => '显示设置',
      'preset' => '预设设置',
      'data' => '存档/数据管理',
      'info' => '说明/帮助',
      _ => '设置区块',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = key.currentContext;
      if (targetContext == null || !_scrollController.hasClients) {
        _showMessage('正在打开对应设置区块。');
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
      _showMessage('已跳转到$label。');
    });
  }

  Widget _buildApiSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppTheme.glitchText('API 设置'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          AppTheme.glitchText(
            '这里填写兼容 OpenAI Chat Completions 的主聊天接口。URL 可以只填站点根地址，例如 https://api.openai.com。',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 18),
        TextFormField(
          key: TutorialTargetRegistry.keyOf(TutorialTargetId.apiUrlField),
          controller: _apiUrlController,
          onTap: () =>
              TutorialTargetRegistry.report(TutorialTargetId.apiUrlField),
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('API 地址'),
            hintText: AppTheme.glitchText('https://api.example.com'),
          ),
        ),
        if (_isNonLoopbackHttp(_apiUrlController.text)) ...<Widget>[
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(AppTheme.glitchText('允许当前主 API 使用明文 HTTP')),
            subtitle: Text(
              AppTheme.glitchText('API Key 和剧情内容可能被网络中间节点读取，仅用于你信任的自建服务。'),
            ),
            value: _allowInsecureMainApi,
            onChanged: (value) => setState(() => _allowInsecureMainApi = value),
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          controller: _apiKeyController,
          obscureText: _obscureApiKey,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('API Key'),
            hintText: AppTheme.glitchText('sk-...'),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
              icon: Icon(
                _obscureApiKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ModelDropdown(
          controller: _modelNameController,
          selectedModelId: _selectedModelId,
          availableModels: _availableModels,
          label: '模型名称',
          onSelected: (value) {
            setState(() {
              _selectedModelId = value;
              _modelNameController.text = value;
            });
          },
        ),
        const SizedBox(height: 10),
        Text(
          _effectiveModelName.isEmpty
              ? AppTheme.glitchText('当前还没有选定模型。')
              : AppTheme.glitchText('当前模型：$_effectiveModelName'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textWeak,
              ),
        ),
        const SizedBox(height: 14),
        _StreamUsageSwitchTile(
          value: _includeStreamUsage,
          onChanged: (value) => setState(() => _includeStreamUsage = value),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          key: ValueKey<int>(_promptTokenBudget),
          initialValue: _promptTokenBudget,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('Prompt Token 预算'),
          ),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 0, child: Text('自动')),
            DropdownMenuItem<int>(value: 8000, child: Text('8K')),
            DropdownMenuItem<int>(value: 16000, child: Text('16K')),
            DropdownMenuItem<int>(value: 32000, child: Text('32K')),
            DropdownMenuItem<int>(value: 64000, child: Text('64K')),
            DropdownMenuItem<int>(value: 128000, child: Text('128K')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _promptTokenBudget = value);
            }
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.tonalIcon(
              style: AppTheme.skinTonalButtonStyle(),
              onPressed: _isFetchingModels ? null : _pullModels,
              icon: _isFetchingModels
                  ? const _TinySpinner()
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(AppTheme.glitchText('拉取模型')),
            ),
            OutlinedButton.icon(
              onPressed: _isTestingConnection ? null : _testConnection,
              icon: _isTestingConnection
                  ? const _TinySpinner()
                  : const Icon(Icons.network_check_outlined),
              label: Text(AppTheme.glitchText('测试连接')),
            ),
            FilledButton.icon(
              key: TutorialTargetRegistry.keyOf(
                TutorialTargetId.saveApiButton,
              ),
              onPressed: () {
                TutorialTargetRegistry.report(
                  TutorialTargetId.saveApiButton,
                );
                _saveApiSettings();
              },
              icon: const Icon(Icons.save_outlined),
              label: Text(AppTheme.glitchText('保存 API 设置')),
            ),
          ],
        ),
        if (_availableModels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            AppTheme.glitchText(
                '已拉取 ${_availableModels.length} 个模型，可在上方下拉框里搜索选择。'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
        if (_connectionMessage != null) ...<Widget>[
          const SizedBox(height: 14),
          _StatusCard(
            success: _lastConnectionSucceeded == true,
            message: _connectionMessage!,
          ),
        ],
        const SizedBox(height: 16),
        _PromptDiagnosticsSettingsPanel(
          controller: context.watch<AppStateController>(),
        ),
      ],
    );
  }

  Widget _buildMemorySection(BuildContext context) {
    final usingDedicatedMemoryApi =
        _memoryApiUrlController.text.trim().isNotEmpty ||
            _memoryApiKeyController.text.trim().isNotEmpty ||
            _effectiveMemoryModelName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppTheme.glitchText('记忆保存策略'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          AppTheme.glitchText(
            '长期记忆会在聊天回复完成后的空闲阶段后台总结。专用 API 留空时，会自动使用主聊天 API。',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 16),
        _IntSliderField(
          label: '请求超时',
          value: _timeoutSeconds.round(),
          min: 60,
          max: 300,
          divisions: 24,
          suffix: '秒',
          onChanged: (value) =>
              setState(() => _timeoutSeconds = value.toDouble()),
        ),
        const SizedBox(height: 14),
        _IntSliderField(
          label: '自动总结触发阈值',
          value: _summaryThreshold.round(),
          min: 5,
          max: 30,
          divisions: 25,
          suffix: '条消息',
          onChanged: (value) =>
              setState(() => _summaryThreshold = value.toDouble()),
        ),
        const SizedBox(height: 14),
        _UnlimitedIntSliderField(
          label: '注入模型的长期记忆条数',
          sliderValue: _memoryContextIndex.toDouble(),
          max: 20,
          valueLabel: _selectedMemoryContextItems == null
              ? '不限'
              : '${_selectedMemoryContextItems!} 条',
          onChanged: (value) {
            setState(() => _memoryContextIndex = value.round());
          },
        ),
        const SizedBox(height: 20),
        Text(AppTheme.glitchText('记忆总结专用 API'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          usingDedicatedMemoryApi
              ? AppTheme.glitchText('当前会优先使用这组 API 总结长期记忆。')
              : AppTheme.glitchText('留空时使用主 API，总结任务不会阻塞正在生成的聊天回复。'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textWeak,
              ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _memoryApiUrlController,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('记忆 API 地址（可选）'),
            hintText: AppTheme.glitchText('https://api.example.com'),
          ),
        ),
        if (_isNonLoopbackHttp(_memoryApiUrlController.text)) ...<Widget>[
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(AppTheme.glitchText('允许当前记忆 API 使用明文 HTTP')),
            subtitle: Text(
              AppTheme.glitchText('长期记忆和 API Key 会以明文传输，仅用于你信任的自建服务。'),
            ),
            value: _allowInsecureMemoryApi,
            onChanged: (value) =>
                setState(() => _allowInsecureMemoryApi = value),
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          controller: _memoryApiKeyController,
          obscureText: _obscureMemoryApiKey,
          decoration: InputDecoration(
            labelText: AppTheme.glitchText('记忆 API Key（可选）'),
            hintText: AppTheme.glitchText('留空则使用主 API Key'),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _obscureMemoryApiKey = !_obscureMemoryApiKey);
              },
              icon: Icon(
                _obscureMemoryApiKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ModelDropdown(
          controller: _memoryModelNameController,
          selectedModelId: _selectedMemoryModelId,
          availableModels: _availableMemoryModels,
          label: '记忆模型名称（可选）',
          onSelected: (value) {
            setState(() {
              _selectedMemoryModelId = value;
              _memoryModelNameController.text = value;
            });
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.tonalIcon(
              style: AppTheme.skinTonalButtonStyle(),
              onPressed: _isFetchingMemoryModels ? null : _pullMemoryModels,
              icon: _isFetchingMemoryModels
                  ? const _TinySpinner()
                  : const Icon(Icons.cloud_sync_outlined),
              label: Text(AppTheme.glitchText('拉取记忆模型')),
            ),
            OutlinedButton.icon(
              onPressed:
                  _isTestingMemoryConnection ? null : _testMemoryConnection,
              icon: _isTestingMemoryConnection
                  ? const _TinySpinner()
                  : const Icon(Icons.network_ping_outlined),
              label: Text(AppTheme.glitchText('测试记忆 API')),
            ),
            FilledButton.icon(
              onPressed: _saveMemorySettings,
              icon: const Icon(Icons.save_outlined),
              label: Text(AppTheme.glitchText('保存记忆策略')),
            ),
          ],
        ),
        if (_memoryConnectionMessage != null) ...<Widget>[
          const SizedBox(height: 14),
          _StatusCard(
            success: _lastMemoryConnectionSucceeded == true,
            message: _memoryConnectionMessage!,
          ),
        ],
      ],
    );
  }

  Widget _buildDisplaySection(BuildContext context) {
    final controller = context.watch<AppStateController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppTheme.glitchText('显示与交互'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          AppTheme.glitchText('这里控制界面缩放和整体配色。新增主题都做了低饱和处理，避免手机上过亮。'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 16),
        _ScaleSliderField(
          label: '界面缩放',
          value: _uiScale,
          onChanged: (value) => setState(() => _uiScale = value),
        ),
        const SizedBox(height: 14),
        _PowerSaveSwitchTile(
          value: _mobilePowerSaveMode,
          onChanged: (value) => setState(() => _mobilePowerSaveMode = value),
        ),
        const SizedBox(height: 20),
        Text(AppTheme.glitchText('UI 主题'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final basicThemes = AppThemeVariant.values
                .where((variant) => variant.isBasicPalette)
                .toList(growable: false);
            final personalityThemes = AppThemeVariant.values
                .where((variant) => !variant.isBasicPalette)
                .toList(growable: false);
            final customThemes = controller.gamification.customThemeStyles;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: personalityThemes
                      .map(
                        (variant) => SizedBox(
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2,
                          child: _ThemeOptionCard(
                            variant: variant,
                            selected: _themeId == variant.id,
                            locked: !controller.canUseTheme(variant.id),
                            unlockCost: controller.themeUnlockCost(variant.id),
                            coinBalance: controller.gamification.coins,
                            onTap: () {
                              if (!controller.canUseTheme(variant.id)) {
                                _unlockTheme(variant);
                                return;
                              }
                              setState(() => _themeId = variant.id);
                            },
                            onUnlock: () => _unlockTheme(variant),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                _CustomThemeSection(
                  controller: controller,
                  selectedThemeId: _themeId,
                  styles: customThemes,
                  onSelect: (id) => setState(() => _themeId = id),
                ),
                const SizedBox(height: 12),
                _BasicThemePackCard(
                  variants: basicThemes,
                  selectedThemeId: _themeId,
                  expanded: _basicThemePackExpanded,
                  onToggle: () {
                    setState(() {
                      _basicThemePackExpanded = !_basicThemePackExpanded;
                    });
                  },
                  onSelect: (variant) {
                    setState(() => _themeId = variant.id);
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saveDisplaySettings,
          icon: const Icon(Icons.save_outlined),
          label: Text(AppTheme.glitchText('保存显示与交互')),
        ),
      ],
    );
  }

  Widget _buildPresetSection(
    BuildContext context,
    List<SettingsPreset> presets,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppTheme.glitchText('预设'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          AppTheme.glitchText('可以把当前 API、记忆策略、显示交互保存成一个命名预设，之后一键恢复。'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _presetNameController,
                decoration: InputDecoration(
                  labelText: AppTheme.glitchText('预设名称'),
                  hintText: AppTheme.glitchText('例如：手机常用 / 本地代理 / 高速站点'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _saveCurrentAsPreset,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(AppTheme.glitchText('保存预设')),
            ),
          ],
        ),
        if (presets.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          for (final preset in presets) ...<Widget>[
            _PresetTile(
              preset: preset,
              onApply: () => _applyPreset(preset),
              onDelete: () => _deletePreset(preset),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildDataPortabilitySection(BuildContext context) {
    final controller = context.watch<AppStateController>();
    final currentCharacter = controller.currentRootCharacter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppTheme.glitchText('存档迁移'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          AppTheme.glitchText(
            '导出数据后可以在另一台设备导入，角色、聊天记录、NPC、世界书、背包和成就都会跟着走。默认导出不会包含 API Key，更适合发给朋友测试。',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.tonalIcon(
              style: AppTheme.skinTonalButtonStyle(),
              onPressed: () => _exportAllData(includeApiSecrets: false),
              icon: const Icon(Icons.ios_share_outlined),
              label: Text(AppTheme.glitchText('导出全部数据')),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportAllData(includeApiSecrets: true),
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text(AppTheme.glitchText('导出完整数据')),
            ),
            OutlinedButton.icon(
              onPressed: currentCharacter == null
                  ? null
                  : () => _exportSingleCharacter(currentCharacter.id),
              icon: const Icon(Icons.badge_outlined),
              label: Text(AppTheme.glitchText('导出当前角色')),
            ),
            FilledButton.icon(
              onPressed: _showImportDataDialog,
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(AppTheme.glitchText('导入数据')),
            ),
            FilledButton.tonalIcon(
              style: AppTheme.skinTonalButtonStyle(),
              onPressed: _showSaveSnapshots,
              icon: const Icon(Icons.restore_page_outlined),
              label: Text(AppTheme.glitchText('恢复中心')),
            ),
            OutlinedButton.icon(
              onPressed: _showDataCleaner,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(AppTheme.glitchText('数据保险箱')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          AppTheme.glitchText(
            '恢复中心会保留手动存档、自动保护和已删除剧场的快照；数据保险箱保存被隔离的损坏原文并检查容量与断链。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textWeak,
              ),
        ),
      ],
    );
  }

  Widget _buildTutorialAndInfoSection(BuildContext context, String? installId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(AppTheme.glitchText('教程与帮助'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Text(
          AppTheme.glitchText(
            '首次启动只带你实际完成 API 配置与第一回合。角色、玩法变量、长期记忆、NPC、分支、地图、存档和装扮等内容，可以在完整教程里逐字听讲并进入界面实操。',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
                height: 1.55,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.tonalIcon(
              style: AppTheme.skinTonalButtonStyle(),
              onPressed: () {
                context.read<AppStateController>().replayTutorial();
                _showMessage('快速上手已重新打开。');
              },
              icon: const Icon(Icons.rocket_launch_outlined),
              label: Text(AppTheme.glitchText('重新查看快速上手')),
            ),
            OutlinedButton.icon(
              onPressed: _showDetailedTutorial,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(AppTheme.glitchText('完整功能教程')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _showReleaseHistory,
          icon: const Icon(Icons.campaign_outlined),
          label: Text(AppTheme.glitchText('查看历史公告')),
        ),
        if (installId != null) ...<Widget>[
          const SizedBox(height: 14),
          SelectableText(
            AppTheme.glitchText('当前设备安装 ID：$installId'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textWeak,
                ),
          ),
        ],
      ],
    );
  }

  Future<void> _showReleaseHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.panel,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText('历史公告'),
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        color: AppTheme.contrastText,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                for (final release in releaseNotesHistory)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    leading: Icon(
                      Icons.campaign_outlined,
                      color: AppTheme.activeSoft,
                    ),
                    title: Text(release.title),
                    subtitle: Text(
                      release.subtitle,
                      maxLines: 4,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      showDialog<void>(
                        context: sheetContext,
                        builder: (_) => ReleaseNotesDialog(release: release),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetailedTutorial() async {
    final sequence = await showDialog<TutorialGuideSequence>(
      context: context,
      builder: (_) => const DetailedTutorialDialog(),
    );
    if (!mounted || sequence == null) {
      return;
    }
    TutorialGuideCoordinator.start(sequence);
  }

  String get _effectiveModelName {
    final direct = _modelNameController.text.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    return _selectedModelId?.trim() ?? '';
  }

  String get _effectiveMemoryModelName {
    final direct = _memoryModelNameController.text.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    return _selectedMemoryModelId?.trim() ?? '';
  }

  Future<void> _saveApiSettings() async {
    final error = _validateMainApi(requireModelName: true);
    if (error != null) {
      _showMessage(error);
      return;
    }

    final controller = context.read<AppStateController>();
    final next = controller.settings.copyWith(
      apiUrl: _apiUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      modelName: _effectiveModelName,
      experienceMode: false,
      includeStreamUsage: _includeStreamUsage,
      promptTokenBudget: _promptTokenBudget,
      allowInsecureMainApi: _allowInsecureMainApi,
    );

    await controller.saveSettings(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _lastConnectionSucceeded = true;
      _connectionMessage = 'API 设置已保存。';
    });
    _showMessage('API 设置已保存。');
  }

  Future<void> _saveMemorySettings() async {
    final error = _validateMemoryApiDraft();
    if (error != null) {
      _showMessage(error);
      return;
    }

    final controller = context.read<AppStateController>();
    final next = controller.settings.copyWith(
      requestTimeoutSeconds: _timeoutSeconds.round(),
      autoSummaryMinMessages: _summaryThreshold.round(),
      memoryContextItems: _selectedMemoryContextItems ?? 0,
      memoryApiUrl: _memoryApiUrlController.text.trim(),
      memoryApiKey: _memoryApiKeyController.text.trim(),
      memoryModelName: _effectiveMemoryModelName,
      allowInsecureMemoryApi: _allowInsecureMemoryApi,
    );

    await controller.saveSettings(next);
    if (!mounted) {
      return;
    }
    _showMessage('记忆策略已保存。');
  }

  Future<void> _saveDisplaySettings() async {
    final controller = context.read<AppStateController>();
    final next = controller.settings.copyWith(
      uiScale: _uiScale,
      themeId: _themeId,
      mobilePowerSaveMode: _mobilePowerSaveMode,
    );

    await controller.saveSettings(next);
    if (!mounted) {
      return;
    }
    _showMessage('显示与交互已保存。');
  }

  Future<void> _unlockTheme(AppThemeVariant variant) async {
    final cost = variant.unlockCost;
    if (cost <= 0) {
      setState(() => _themeId = variant.id);
      return;
    }
    final controller = context.read<AppStateController>();
    final error = await controller.unlockTheme(variant.id);
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showMessage(error);
      return;
    }
    setState(() => _themeId = variant.id);
    _showMessage('已解锁「${variant.label}」，保存显示与交互后生效。');
  }

  Future<void> _saveCurrentAsPreset() async {
    final name = _presetNameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请先给预设起一个名字。');
      return;
    }

    final memoryError = _validateMemoryApiDraft();
    if (memoryError != null) {
      _showMessage(memoryError);
      return;
    }

    final controller = context.read<AppStateController>();
    final draftSettings = _buildDraftSettings(controller.settings);
    await controller.saveSettings(draftSettings);
    await controller.saveSettingsPreset(name);
    if (!mounted) {
      return;
    }
    _presetNameController.clear();
    _showMessage('预设已保存。');
  }

  Future<void> _applyPreset(SettingsPreset preset) async {
    await context.read<AppStateController>().applySettingsPreset(preset.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _applySettings(context.read<AppStateController>().settings);
      _connectionMessage = null;
      _memoryConnectionMessage = null;
    });
    _showMessage('已加载预设：${preset.name}');
  }

  Future<void> _deletePreset(SettingsPreset preset) async {
    await context.read<AppStateController>().deleteSettingsPreset(preset.id);
    if (!mounted) {
      return;
    }
    _showMessage('预设已删除。');
  }

  Future<void> _exportAllData({required bool includeApiSecrets}) async {
    final controller = context.read<AppStateController>();
    final content = await controller.exportAllDataArchive(
      includeApiSecrets: includeApiSecrets,
    );
    final saved = await downloadTextFile(
      filename: includeApiSecrets
          ? 'ai_roleplay_full_save_v1_9_8.json'
          : 'ai_roleplay_safe_save_v1_9_8.json',
      content: content,
      mimeType: 'application/json;charset=utf-8',
    );
    if (!mounted) {
      return;
    }
    _showMessage(saved ? '存档已导出。' : '导出失败，请稍后再试。');
  }

  Future<void> _exportSingleCharacter(String characterId) async {
    final controller = context.read<AppStateController>();
    final content = await controller.exportCharacterDataArchive(
      characterId: characterId,
    );
    if (content == null) {
      _showMessage('当前没有可导出的角色。');
      return;
    }
    final saved = await downloadTextFile(
      filename: 'ai_roleplay_character_v1_9_8.json',
      content: content,
      mimeType: 'application/json;charset=utf-8',
    );
    if (!mounted) {
      return;
    }
    _showMessage(saved ? '当前角色数据已导出。' : '导出失败，请稍后再试。');
  }

  Future<void> _showImportDataDialog() async {
    final result = await showDialog<_ImportDataDialogResult>(
      context: context,
      builder: (_) => const _ImportDataDialog(),
    );
    if (result == null || !mounted) {
      return;
    }
    final error = await context.read<AppStateController>().importDataArchive(
          result.content,
          replaceExisting: result.replaceExisting,
        );
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showMessage(error);
      return;
    }
    setState(() {
      _applySettings(context.read<AppStateController>().settings);
      _connectionMessage = null;
      _memoryConnectionMessage = null;
    });
    _showMessage('导入完成，存档已经接上了。');
  }

  Future<void> _showSaveSnapshots() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _SaveSnapshotsDialog(),
    );
  }

  Future<void> _showDataCleaner() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _DataCleanerDialog(),
    );
  }

  Future<void> _pullModels() async {
    final error = _validateMainApi(requireModelName: false);
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _isFetchingModels = true);
    try {
      final models = await _apiClient.fetchModels(
        settings: _buildMainDraftSettings(requireModelName: false),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _availableModels = models;
        if (_effectiveModelName.isEmpty && models.isNotEmpty) {
          _selectedModelId = models.first;
          _modelNameController.text = models.first;
        }
      });
      _showMessage('已拉取 ${models.length} 个模型。');
    } on LlmApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('拉取模型失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isFetchingModels = false);
      }
    }
  }

  Future<void> _testConnection() async {
    final error = _validateMainApi(requireModelName: true);
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionMessage = null;
      _lastConnectionSucceeded = null;
    });

    try {
      await _apiClient.testConnection(
        settings: _buildMainDraftSettings(requireModelName: true),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _lastConnectionSucceeded = true;
        _connectionMessage = '连接成功，当前模型可以正常访问聊天接口。';
      });
    } on LlmApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastConnectionSucceeded = false;
        _connectionMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastConnectionSucceeded = false;
        _connectionMessage = '连接测试失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() => _isTestingConnection = false);
      }
    }
  }

  Future<void> _pullMemoryModels() async {
    final memorySettings = _buildMemoryDraftSettings();
    if (memorySettings == null) {
      _showMessage('记忆 API 留空时会使用主 API，无需单独拉取。');
      return;
    }

    setState(() => _isFetchingMemoryModels = true);
    try {
      final models = await _apiClient.fetchModels(settings: memorySettings);
      if (!mounted) {
        return;
      }
      setState(() {
        _availableMemoryModels = models;
        if (_effectiveMemoryModelName.isEmpty && models.isNotEmpty) {
          _selectedMemoryModelId = models.first;
          _memoryModelNameController.text = models.first;
        }
      });
      _showMessage('已拉取 ${models.length} 个记忆模型。');
    } on LlmApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('拉取记忆模型失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isFetchingMemoryModels = false);
      }
    }
  }

  Future<void> _testMemoryConnection() async {
    final memorySettings = _buildMemoryDraftSettings();
    if (memorySettings == null) {
      _showMessage('记忆 API 留空时会使用主 API。');
      return;
    }

    setState(() {
      _isTestingMemoryConnection = true;
      _memoryConnectionMessage = null;
      _lastMemoryConnectionSucceeded = null;
    });

    try {
      await _apiClient.testConnection(settings: memorySettings);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMemoryConnectionSucceeded = true;
        _memoryConnectionMessage = '记忆 API 连接成功。';
      });
    } on LlmApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMemoryConnectionSucceeded = false;
        _memoryConnectionMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMemoryConnectionSucceeded = false;
        _memoryConnectionMessage = '记忆 API 测试失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() => _isTestingMemoryConnection = false);
      }
    }
  }

  String? _validateMainApi({required bool requireModelName}) {
    final apiUrl = _apiUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final modelName = _effectiveModelName;

    if (apiUrl.isEmpty) {
      return '请先填写 API 地址。';
    }
    try {
      ApiEndpointResolver.chatCompletions(
        apiUrl,
        allowInsecureHttp: _allowInsecureMainApi,
      );
    } on FormatException catch (error) {
      return error.message;
    }
    if (apiKey.isEmpty) {
      return '请先填写 API Key。';
    }
    if (requireModelName && modelName.isEmpty) {
      return '请先填写或选择模型名称。';
    }
    return null;
  }

  String? _validateMemoryApiDraft() {
    final url = _memoryApiUrlController.text.trim();
    final key = _memoryApiKeyController.text.trim();
    final model = _effectiveMemoryModelName;
    final filled =
        <String>[url, key, model].where((value) => value.isNotEmpty).length;

    if (filled == 0) {
      return null;
    }
    if (filled < 3) {
      return '记忆专用 API 如果要启用，需要同时填写地址、Key 和模型名称；全部留空则使用主 API。';
    }

    try {
      ApiEndpointResolver.chatCompletions(
        url,
        allowInsecureHttp: _allowInsecureMemoryApi,
      );
    } on FormatException catch (error) {
      return '记忆 API：${error.message}';
    }
    return null;
  }

  AppSettings _buildDraftSettings(AppSettings base) {
    return base.copyWith(
      apiUrl: _apiUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      modelName: _effectiveModelName,
      experienceMode: false,
      requestTimeoutSeconds: _timeoutSeconds.round(),
      autoSummaryMinMessages: _summaryThreshold.round(),
      memoryContextItems: _selectedMemoryContextItems ?? 0,
      uiScale: _uiScale,
      themeId: _themeId,
      mobilePowerSaveMode: _mobilePowerSaveMode,
      includeStreamUsage: _includeStreamUsage,
      promptTokenBudget: _promptTokenBudget,
      memoryApiUrl: _memoryApiUrlController.text.trim(),
      memoryApiKey: _memoryApiKeyController.text.trim(),
      memoryModelName: _effectiveMemoryModelName,
      allowInsecureMainApi: _allowInsecureMainApi,
      allowInsecureMemoryApi: _allowInsecureMemoryApi,
    );
  }

  AppSettings _buildMainDraftSettings({required bool requireModelName}) {
    final modelName = requireModelName
        ? _effectiveModelName
        : (_effectiveModelName.isEmpty
            ? 'placeholder-model'
            : _effectiveModelName);

    return AppSettings.initial().copyWith(
      apiUrl: _apiUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      modelName: modelName,
      requestTimeoutSeconds: _timeoutSeconds.round(),
      allowInsecureMainApi: _allowInsecureMainApi,
    );
  }

  AppSettings? _buildMemoryDraftSettings() {
    final error = _validateMemoryApiDraft();
    if (error != null) {
      _showMessage(error);
      return null;
    }

    final url = _memoryApiUrlController.text.trim();
    final key = _memoryApiKeyController.text.trim();
    final model = _effectiveMemoryModelName;
    if (url.isEmpty && key.isEmpty && model.isEmpty) {
      return null;
    }

    return AppSettings.initial().copyWith(
      apiUrl: url,
      apiKey: key,
      modelName: model,
      requestTimeoutSeconds: _timeoutSeconds.round(),
      allowInsecureMainApi: _allowInsecureMemoryApi,
    );
  }

  void _applySettings(AppSettings settings) {
    _apiUrlController.text = settings.apiUrl;
    _apiKeyController.text = settings.apiKey;
    _modelNameController.text = settings.modelName;
    _selectedModelId =
        settings.modelName.trim().isEmpty ? null : settings.modelName.trim();
    _memoryApiUrlController.text = settings.memoryApiUrl;
    _memoryApiKeyController.text = settings.memoryApiKey;
    _memoryModelNameController.text = settings.memoryModelName;
    _selectedMemoryModelId = settings.memoryModelName.trim().isEmpty
        ? null
        : settings.memoryModelName.trim();
    _timeoutSeconds = settings.requestTimeoutSeconds.clamp(60, 300).toDouble();
    _summaryThreshold = settings.autoSummaryMinMessages.toDouble();
    _memoryContextIndex =
        _resolveMemoryContextIndex(settings.memoryContextItems);
    _uiScale = settings.uiScale.clamp(0.82, 1.25);
    _themeId = AppTheme.hasRuntimeTheme(settings.themeId)
        ? settings.themeId
        : AppThemeVariant.byId(settings.themeId).id;
    _mobilePowerSaveMode = settings.mobilePowerSaveMode;
    _includeStreamUsage = settings.includeStreamUsage;
    _allowInsecureMainApi = settings.allowInsecureMainApi;
    _allowInsecureMemoryApi = settings.allowInsecureMemoryApi;
    _promptTokenBudget = <int>{0, 8000, 16000, 32000, 64000, 128000}
            .contains(settings.promptTokenBudget)
        ? settings.promptTokenBudget
        : 0;
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isNonLoopbackHttp(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'http') {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host != 'localhost' && host != '::1' && !host.startsWith('127.');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int? get _selectedMemoryContextItems {
    if (_memoryContextIndex >= 20) {
      return null;
    }
    return _memoryContextIndex + 1;
  }

  int _resolveMemoryContextIndex(int value) {
    if (value <= 0) {
      return 20;
    }
    return value.clamp(1, 20) - 1;
  }
}

class _PromptDiagnosticsSettingsPanel extends StatelessWidget {
  const _PromptDiagnosticsSettingsPanel({required this.controller});

  final AppStateController controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.latestPromptDiagnostics;
    final exceedsPromptBudget = data != null &&
        data.promptTokenBudget > 0 &&
        data.estimatedTokens > data.promptTokenBudget;
    final warmMetrics = controller.currentPromptCacheMetrics
        .where(
          (metric) =>
              metric.rolloverReason == 'warm_append' &&
              metric.cacheHitRate != null,
        )
        .take(12)
        .toList(growable: false);
    final rollingHitRate = warmMetrics.isEmpty
        ? null
        : (warmMetrics
                    .map((metric) => metric.cacheHitRate!)
                    .reduce((left, right) => left + right) /
                warmMetrics.length)
            .round();
    return DecoratedBox(
      decoration: AppTheme.glassPanel(radius: 18),
      child: ExpansionTile(
        leading: const Icon(Icons.query_stats_outlined),
        title: Text(AppTheme.glitchText('Prompt 调用诊断')),
        subtitle: Text(
          AppTheme.glitchText(
            data == null
                ? '尚无调用记录'
                : '${data.model} · ${data.estimatedTokens} tokens',
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          if (data == null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppTheme.glitchText('完成一次 AI 回复后会显示输入、输出、耗时和缓存数据。'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            )
          else ...<Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _PromptMetricChip(
                  label: '估算输入',
                  value: '${data.estimatedTokens}',
                ),
                _PromptMetricChip(
                  label: '真实输入',
                  value: data.inputTokens?.toString() ?? '未返回',
                ),
                _PromptMetricChip(
                  label: '真实输出',
                  value: data.outputTokens?.toString() ?? '未返回',
                ),
                _PromptMetricChip(
                  label: '缓存命中',
                  value: '${data.cacheHitRate ?? 0}%',
                ),
                _PromptMetricChip(
                  label: '暖请求均值',
                  value: rollingHitRate == null ? '暂无' : '$rollingHitRate%',
                ),
                _PromptMetricChip(
                  label: '耗时',
                  value: data.elapsed == null
                      ? '未完成'
                      : '${data.elapsed!.inMilliseconds} ms',
                ),
              ],
            ),
            if (exceedsPromptBudget) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppTheme.glitchText(
                        '本次估算输入已超过 Prompt 预算。请精简世界书或长期记忆，或提高预算。',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            if (data.error.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppTheme.glitchText(data.error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppTheme.glitchText(
                  '缓存阶段：${_promptCacheStageLabel(data.cacheRolloverReason)} · 记忆 ${data.memoryCount} · 世界书 ${data.staticWorldBookCount + data.triggeredWorldBookCount}',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromptMetricChip extends StatelessWidget {
  const _PromptMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(AppTheme.glitchText('$label $value')),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _promptCacheStageLabel(String value) {
  return switch (value) {
    'warm_append' => '连续追加',
    'initial' => '首次建立',
    'message_limit' => '消息换代',
    'token_budget' => 'Token 换代',
    'stable_prefix_changed' => '固定设定变更',
    'missing_epoch_anchor' => '历史锚点变更',
    'regenerate' => '重新生成',
    _ => value.isEmpty ? '未记录' : value,
  };
}
