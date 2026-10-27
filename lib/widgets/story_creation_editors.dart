import 'gameplay_draft_editors.dart';
import 'package:flutter/material.dart';
import '../models/story_advanced_settings.dart';
import '../models/story_opening_draft.dart';

class StoryAdvancedSettingsEditor extends StatelessWidget {
  const StoryAdvancedSettingsEditor(
      {super.key, required this.value, required this.onChanged});
  final StoryAdvancedSettings value;
  final ValueChanged<StoryAdvancedSettings> onChanged;
  @override
  Widget build(BuildContext context) => ExpansionTile(
          title: const Text('高级设置'),
          subtitle: const Text('长期生效的叙事偏好与指令约束'),
          childrenPadding: const EdgeInsets.all(12),
          children: [
            _choice(
                '叙事视角',
                value.perspective,
                {'first': '第一人称', 'second': '第二人称', 'third': '第三人称'},
                (v) => onChanged(value.copyWith(perspective: v))),
            _choice(
                '正文篇幅',
                value.length,
                {
                  'short': '短篇 · 600—1000 字',
                  'medium': '中篇 · 1200—1800 字',
                  'long': '长篇 · 2200—3200 字'
                },
                (v) => onChanged(value.copyWith(length: v))),
            _choice(
                '剧情节奏',
                value.pace,
                {'slow': '慢慢展开', 'natural': '自然推进', 'fast': '紧凑推进'},
                (v) => onChanged(value.copyWith(pace: v))),
            _choice(
                '初始人物数量',
                '${value.npcCount}',
                {
                  '0': 'AI 决定 · 3—6 人',
                  '3': '3 人',
                  '4': '4 人',
                  '5': '5 人',
                  '6': '6 人'
                },
                (v) => onChanged(value.copyWith(npcCount: int.parse(v)))),
            _text('互动偏好', value.interaction,
                (v) => onChanged(value.copyWith(interaction: v))),
            _text('世界约束', value.worldConstraints,
                (v) => onChanged(value.copyWith(worldConstraints: v))),
            _text('额外指令（原样保存）', value.instructions,
                (v) => onChanged(value.copyWith(instructions: v))),
          ]);
  Widget _choice(String label, String current, Map<String, String> choices,
          ValueChanged<String> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
              initialValue: current,
              decoration: InputDecoration(labelText: label),
              isExpanded: true,
              items: choices.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) change(v);
              }));
  Widget _text(String label, String current, ValueChanged<String> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              initialValue: current,
              minLines: 2,
              maxLines: 5,
              decoration:
                  InputDecoration(labelText: label, alignLabelWithHint: true),
              onChanged: change));
}

class StoryOpeningEditor extends StatefulWidget {
  const StoryOpeningEditor(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.onRegenerate,
      required this.locked,
      this.busy = false,
      this.supplementOnly = false});
  final StoryOpeningDraft value;
  final ValueChanged<StoryOpeningDraft> onChanged;
  final Future<void> Function(String section) onRegenerate;
  final bool busy, supplementOnly;
  final Set<String> locked;
  @override
  State<StoryOpeningEditor> createState() => _StoryOpeningEditorState();
}

class _StoryOpeningEditorState extends State<StoryOpeningEditor> {
  Set<String> get _locked => widget.locked;
  void _replace(String key, List<Map<String, dynamic>> values) => widget
      .onChanged(StoryOpeningDraft({...widget.value.toJson(), key: values}));
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        const Text('开局预览',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Text('人物、物品和玩法将随世界一起保存。锁定的部分不会重新生成。'),
        if (widget.supplementOnly) ...[
          const Text('勾选需要补充的内容；已有的同名人物、物品和玩法会保留。'),
          Wrap(spacing: 8, children: [
            for (final n in widget.value.npcs)
              FilterChip(
                  label: Text('补充 ${n['name']}'),
                  selected: _selected('npcs', '${n['id']}'),
                  onSelected: (v) => _select('npcs', '${n['id']}', v))
          ]),
          Wrap(spacing: 8, children: [
            for (final i in widget.value.items)
              FilterChip(
                  label: Text('补充 ${i['name']}'),
                  selected: _selected('items', '${i['id']}'),
                  onSelected: (v) => _select('items', '${i['id']}', v))
          ]),
          FilterChip(
              label: const Text('补充玩法'),
              selected: widget.value.data['includeGameplay'] != false,
              onSelected: (v) => widget.onChanged(StoryOpeningDraft(
                  {...widget.value.toJson(), 'includeGameplay': v}))),
        ],
        for (final n in widget.value.npcs)
          Card(
              child: ExpansionTile(
                  title: Text('${n['name']}'),
                  subtitle:
                      Text('${n['publicIdentity']} · 初始好感 ${n['affinity']}'),
                  childrenPadding: const EdgeInsets.all(12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    '性格：${n['personality'] ?? ''}\n初始关系：${n['affinityReason'] ?? ''}\n当前目标：${n['goal'] ?? ''}\n开场${n['appeared'] == true ? '登场' : '尚未登场'}'),
                ExpansionTile(title: const Text('作者查看 · 含剧透'), children: [
                  Text(
                      '真实身份：${n['trueIdentity'] ?? ''}\n秘密：${n['secret'] ?? ''}'),
                  const Text('查看不会让玩家角色提前知情。')
                ]),
                Wrap(spacing: 8, children: [
                  FilterChip(
                      label: Text(
                          _locked.contains('npc:${n['id']}') ? '已锁定' : '锁定人物'),
                      selected: _locked.contains('npc:${n['id']}'),
                      onSelected: (v) => setState(() => v
                          ? _locked.add('npc:${n['id']}')
                          : _locked.remove('npc:${n['id']}'))),
                  TextButton(
                      onPressed: widget.busy
                          ? null
                          : () async {
                              final result = await _edit(context, n, npc: true);
                              if (result != null) {
                                _replace(
                                    'npcs',
                                    widget.value.npcs
                                        .map((v) =>
                                            v['id'] == n['id'] ? result : v)
                                        .toList());
                              }
                            },
                      child: const Text('编辑人物')),
                  TextButton(
                      onPressed:
                          widget.busy || _locked.contains('npc:${n['id']}')
                              ? null
                              : () => widget.onRegenerate('npc:${n['id']}'),
                      child: const Text('重新生成此人')),
                ])
              ])),
        ExpansionTile(
            title: Text('人物关系 · ${widget.value.relationships.length} 条'),
            children: [
              for (final r in widget.value.relationships)
                ListTile(
                    title: Text('${_name(r['from'])} → ${_name(r['to'])}'),
                    subtitle: Text(r['public'] == true
                        ? '${r['label']}'
                        : '未公开关系 · 作者展开查看'),
                    trailing: IconButton(
                        tooltip: '编辑关系',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final next = await _editRelation(context, r);
                          if (next != null) {
                            _replace(
                                'relationships',
                                widget.value.relationships
                                    .map((e) => e['from'] == r['from'] &&
                                            e['to'] == r['to']
                                        ? next
                                        : e)
                                    .toList());
                          }
                        })),
              _sectionActions('relationships', '关系')
            ]),
        ExpansionTile(
            title: Text('初始物品 · ${widget.value.items.length} 件'),
            children: [
              for (final item in widget.value.items)
                ListTile(
                    title: Text('${item['name']} ×${item['quantity']}'),
                    subtitle: Text('${item['description'] ?? ''}'),
                    trailing: IconButton(
                        tooltip: '编辑物品',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final next = await _edit(context, item, npc: false);
                          if (next != null) {
                            _replace(
                                'items',
                                widget.value.items
                                    .map(
                                        (e) => e['id'] == item['id'] ? next : e)
                                    .toList());
                          }
                        })),
              _sectionActions('items', '物品')
            ]),
        ExpansionTile(
            title: Text('初始玩法 · ${widget.value.gameplay?.title ?? '等待生成'}'),
            children: [
              Text(widget.value.gameplay?.summary ?? ''),
              for (final v in widget.value.gameplay?.variables ?? [])
                ListTile(
                    title: Text(v.label),
                    subtitle: Text('${v.initialValue} · ${v.playerHint}'),
                    trailing: IconButton(
                        tooltip: '编辑变量',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: widget.busy
                            ? null
                            : () async {
                                final changed =
                                    await editGameplayVariable(context, v);
                                if (changed == null) return;
                                final system = widget.value.gameplay!.toJson();
                                system['variables'] = [
                                  for (final variable
                                      in widget.value.gameplay!.variables)
                                    variable.key == v.key
                                        ? changed
                                        : variable.toJson()
                                ];
                                widget.onChanged(StoryOpeningDraft({
                                  ...widget.value.toJson(),
                                  'gameplaySystem': system
                                }));
                              })),
              _sectionActions('gameplaySystem', '玩法')
            ]),
        for (final error in widget.value.validate())
          Text(error,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ]);
  bool _selected(String section, String id) =>
      !(widget.value.data['excluded_$section'] as List? ?? []).contains(id);
  void _select(String section, String id, bool selected) {
    final excluded = [...widget.value.data['excluded_$section'] as List? ?? []]
      ..remove(id);
    if (!selected) excluded.add(id);
    widget.onChanged(StoryOpeningDraft(
        {...widget.value.toJson(), 'excluded_$section': excluded}));
  }

  String _name(dynamic id) =>
      '${widget.value.npcs.where((n) => n['id'] == id).firstOrNull?['name'] ?? id}';
  Widget _sectionActions(String key, String label) =>
      Wrap(spacing: 8, children: [
        FilterChip(
            label: Text(_locked.contains(key) ? '已锁定' : '锁定$label'),
            selected: _locked.contains(key),
            onSelected: (v) =>
                setState(() => v ? _locked.add(key) : _locked.remove(key))),
        TextButton(
            onPressed: widget.busy || _locked.contains(key)
                ? null
                : () => widget.onRegenerate(key),
            child: Text('重新生成$label'))
      ]);
  Future<Map<String, dynamic>?> _editRelation(
      BuildContext context, Map<String, dynamic> source) async {
    final label = TextEditingController(text: '${source['label'] ?? ''}');
    var public = source['public'] == true;
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, set) => AlertDialog(
                    title: const Text('编辑关系 · 作者设定'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: label,
                          decoration: const InputDecoration(labelText: '关系')),
                      SwitchListTile(
                          title: const Text('玩家开局已知'),
                          value: public,
                          onChanged: (v) => set(() => public = v))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, {
                                ...source,
                                'label': label.text,
                                'public': public
                              }),
                          child: const Text('保存'))
                    ])));
    label.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _edit(
      BuildContext context, Map<String, dynamic> source,
      {required bool npc}) async {
    final fields = npc
        ? {
            'name': '公开姓名',
            'publicIdentity': '公开身份',
            'personality': '性格',
            'affinity': '初始好感',
            'affinityReason': '初始关系原因',
            'goal': '当前目标',
            'stance': '立场',
            'trueIdentity': '真实身份（剧透）',
            'secret': '秘密（剧透）'
          }
        : {
            'name': '物品名称',
            'quantity': '数量',
            'description': '说明',
            'source': '来源'
          };
    final controllers = {
      for (final k in fields.keys)
        k: TextEditingController(text: '${source[k] ?? ''}')
    };
    var appeared = source['appeared'] == true;
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, set) => AlertDialog(
                    title: Text(npc ? '编辑人物 · 作者设定' : '编辑初始物品'),
                    content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              for (final e in fields.entries)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextField(
                                        controller: controllers[e.key],
                                        decoration:
                                            InputDecoration(labelText: e.value),
                                        maxLines: e.key == 'secret' ? 3 : 1)),
                              if (npc)
                                SwitchListTile(
                                    title: const Text('开场登场'),
                                    value: appeared,
                                    onChanged: (v) => set(() => appeared = v))
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, {
                                ...source,
                                for (final e in controllers.entries)
                                  e.key:
                                      e.key == 'affinity' || e.key == 'quantity'
                                          ? int.tryParse(e.value.text) ?? 0
                                          : e.value.text,
                                if (npc) 'appeared': appeared
                              }),
                          child: const Text('保存'))
                    ])));
    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
  }
}
