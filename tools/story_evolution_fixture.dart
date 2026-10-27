import 'package:ai_roleplay_chat/theme/app_theme.dart';
// Isolated mock data; no provider calls or user saves.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/story_workflow_test.dart' as base;
import '../test/story_evolution_test.dart' as evolution;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('write v215 browser fixture', () async {
    final c = await base.fixture(evolution.EvolutionClient());
    await c.createCharacter(evolution.characterDraft());
    final npc = c.currentWorldNpcProfiles.firstWhere((n) => n.name == '人物1');
    final narrative = <String>[
      '人物1替你包好伤口，把旧城路线画在纸上。你用去一份止血药。他向你道谢，答应带你去渡口。',
      ...List.filled(26, '渡口的灯影映在水面，木船随着潮水轻晃。他把灯提得更高，等待你选择接下来的道路。')
    ].join();
    final judgment = {
      'gameState': {
        '时间': '第一日午后',
        '地点': '渡口',
        '状态': '已包扎',
        '当前任务': '调查旧城',
        '人物数据': [],
        '剧情物品栏': [
          {
            'id': 'herb',
            'name': '止血药',
            'quantity': 2,
            'description': '用于包扎',
            'source': '开局携带'
          }
        ],
        'NPC更新': [
          {
            'npcId': npc.id,
            'name': npc.name,
            'affinityDelta': 5,
            'impression': '你帮忙整理了路线',
            'storyPatch': {
              'evidence': '他向你道谢，答应带你去渡口。',
              'stance': '愿意合作',
              'trustDelta': 2
            }
          }
        ],
        '事件': {'title': '渡口之约', 'description': '约好一起调查旧城。'}
      },
      'gameplayPatch': {
        'ops': [
          {'op': 'inc', 'path': 'energy', 'value': -2, 'reason': '包扎与探路'},
          {'op': 'inc', 'path': 'progress', 'value': 5, 'reason': '得到旧城路线'}
        ]
      }
    };
    final prefs = await SharedPreferences.getInstance();
    final data = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    final dir = Directory('build/story-evolution-qa')
      ..createSync(recursive: true);
    File('${dir.path}/seed.json').writeAsStringSync(jsonEncode(data));
    File('${dir.path}/mock.json').writeAsStringSync(jsonEncode({
      'uiLabels': {
        for (final variant in AppThemeVariant.values)
          variant.id: (() {
            AppTheme.themeFor(variant.id);
            return {
              for (final label in [
                '打开未完剧场',
                '输入你的消息，开始和角色对话...',
                '输入消息...',
                '发送',
                '发送消息',
                '提交并生成回复',
                '继续阅读',
                '关闭结算',
                '角色',
                '新建角色',
                '帮你写',
                '文游灵感',
                '高级设置 长期生效的叙事偏好与指令约束',
                '额外指令（原样保存）',
                '生成提示词',
                '作者查看 · 含剧透',
                '重新生成此人',
                '编辑人物',
                '取消',
                '创建角色',
                'NPC'
              ])
                label: AppTheme.glitchText(label)
            };
          })()
      },
      'judgment': judgment,
      'narrative': narrative,
      'worldId': c.currentCharacter!.id,
      'generated': {
        'name': '渡口灯影',
        'description': '在旧城寻找失落的线索。',
        'opening': '渡口灯下，两位旅人朝你挥手。',
        'systemPrompt': '调查旧城，等待玩家决定。',
        'openingDraft': evolution.openingDraft().toJson()
      }
    }));
  });
}
