part of '../settings_screen.dart';

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.onApply,
    required this.onDelete,
  });

  final SettingsPreset preset;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.describeTheme(preset.settings.themeId);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: ListTile(
        leading:
            Icon(Icons.bookmark_outline_rounded, color: theme.palette.soft),
        title: Text(preset.name),
        subtitle: Text(
          '${preset.settings.modelName} 路 ${theme.label}',
          maxLines: MediaQuery.sizeOf(context).width < 620 ? 3 : 1,
        ),
        trailing: Wrap(
          spacing: 6,
          children: <Widget>[
            IconButton(
              tooltip: '加载预设',
              onPressed: onApply,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
            IconButton(
              tooltip: '删除预设',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleSliderField extends StatelessWidget {
  const _ScaleSliderField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    final mode = switch (percent) {
      <= 88 => '小屏紧凑',
      <= 94 => '紧凑',
      >= 118 => '大字',
      >= 108 => '舒适',
      _ => '标准',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              '$percent% 路 $mode',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _ScalePresetChip(
              label: '小屏紧凑',
              selected: (value - 0.86).abs() < 0.01,
              onTap: () => onChanged(0.86),
            ),
            _ScalePresetChip(
              label: '标准',
              selected: (value - 1).abs() < 0.01,
              onTap: () => onChanged(1),
            ),
            _ScalePresetChip(
              label: '舒适',
              selected: (value - 1.12).abs() < 0.01,
              onTap: () => onChanged(1.12),
            ),
            _ScalePresetChip(
              label: '大字',
              selected: (value - 1.22).abs() < 0.01,
              onTap: () => onChanged(1.22),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0.82, 1.25),
          min: 0.82,
          max: 1.25,
          divisions: 43,
          label: '$percent%',
          onChanged: onChanged,
        ),
        Text(
          '小屏手机建议用“小屏紧凑”，大屏手机或平板可以用“舒适”。保存后整套界面会一起适配。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textWeak,
              ),
        ),
      ],
    );
  }
}

class _PowerSaveSwitchTile extends StatelessWidget {
  const _PowerSaveSwitchTile({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        secondary: const Icon(Icons.battery_saver_outlined),
        title: Text(AppTheme.glitchText('手机省电模式')),
        subtitle: Text(
          AppTheme.glitchText(
            '手机端默认暂停高级主题的动态背景，并降低流式回复刷新频率，减少发热和耗电。',
          ),
        ),
      ),
    );
  }
}

class _StreamUsageSwitchTile extends StatelessWidget {
  const _StreamUsageSwitchTile({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        secondary: const Icon(Icons.query_stats_outlined),
        title: Text(AppTheme.glitchText('增强流式用量统计')),
        subtitle: Text(
          AppTheme.glitchText(
            '默认开启，用于显示真实回复 Token 和缓存命中信息。若自定义中转接口因此报错，可在这里关闭。',
          ),
        ),
      ),
    );
  }
}

class _ScalePresetChip extends StatelessWidget {
  const _ScalePresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _IntSliderField extends StatelessWidget {
  const _IntSliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              '$value $suffix',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions,
          label: '$value $suffix',
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }
}

class _UnlimitedIntSliderField extends StatelessWidget {
  const _UnlimitedIntSliderField({
    required this.label,
    required this.sliderValue,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double sliderValue;
  final int max;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
        Slider(
          value: sliderValue.clamp(0, max).toDouble(),
          min: 0,
          max: max.toDouble(),
          divisions: max,
          label: valueLabel,
          onChanged: onChanged,
        ),
        Text(
          '拖到最右侧表示不限。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textWeak,
              ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        success ? AppTheme.activeAccent : Theme.of(context).colorScheme.error;
    final tone = success
        ? AppTheme.activeAccent.withValues(alpha: 0.12)
        : Theme.of(context).colorScheme.error.withValues(alpha: 0.14);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _TinySpinner extends StatelessWidget {
  const _TinySpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
