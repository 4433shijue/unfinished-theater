import 'dart:convert';
import 'package:ai_roleplay_chat/models/story_continuity.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/models/world_book.dart';
import 'package:ai_roleplay_chat/models/user_profile.dart';
import 'package:ai_roleplay_chat/services/story_continuity_engine.dart';
import 'package:ai_roleplay_chat/services/story_rewrite_service.dart';
import 'package:ai_roleplay_chat/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  StoryContinuityState turn(StoryContinuityState state, String id,
          {String? npc,
          String text = '我告诉甲：钥匙在楼下。',
          String value = '钥匙在楼下',
          String level = 'told'}) =>
      StoryContinuityEngine.apply(
          state: state,
          eventId: id,
          sourceIds: [id],
          narrative: text,
          npcIds: {'a', 'b'},
          privateNpcId: npc,
          patch: {
            'facts': [
              {'key': 'key', 'text': value, 'evidence': text}
            ],
            'knowledge': [
              {'npcId': 'a', 'factKey': 'key', 'level': level, 'evidence': text}
            ],
            'scene': {
              'title': '门口',
              'summary': text,
              'evidence': text,
              'participants': ['甲']
            },
          });

  test(
      'private knowledge is scoped, suspicion remains uncertain and turns are idempotent',
      () {
    final state = turn(StoryContinuityState(characterId: 'w'), 'm1',
        npc: 'a', level: 'suspected');
    expect(
        StoryContinuityEngine.factsPrompt(state, npcId: 'a'), contains('只是怀疑'));
    expect(StoryContinuityEngine.factsPrompt(state, npcId: 'b'), isEmpty);
    expect(state.scene, isEmpty);
    expect(turn(state, 'm1').sequence, 1);
    expect(turn(state, 'm1').facts, hasLength(1));
  });
  test('unsupported evidence and HTML extras never create canonical facts', () {
    final state = StoryContinuityEngine.apply(
        state: StoryContinuityState(characterId: 'w'),
        eventId: 'm',
        sourceIds: ['m'],
        narrative: '门还关着。\n```html\n<html>钥匙在楼下</html>\n```',
        npcIds: {'a'},
        patch: {
          'facts': [
            {'key': 'key', 'text': '钥匙在楼下', 'evidence': '钥匙在楼下'}
          ]
        });
    expect(state.facts, isEmpty);
  });
  test('pinned conflicts retain the original and do not repeat', () {
    var state = turn(StoryContinuityState(characterId: 'w'), 'one');
    state.data['facts'] =
        state.facts.map((f) => {...f, 'pinned': true}).toList();
    state = turn(state, 'two', value: '钥匙在楼上', text: '甲说钥匙在楼上。');
    state = turn(state, 'three', value: '钥匙在楼上', text: '甲说钥匙在楼上。');
    expect(state.activeFacts.single['text'], '钥匙在楼下');
    expect(state.conflicts, hasLength(1));
  });
  test('branch snapshots exclude future facts and knowledge', () {
    var state = turn(StoryContinuityState(characterId: 'w'), 'one');
    state = turn(state, 'two', value: '钥匙在楼上', text: '甲把钥匙拿到了楼上。');
    final branch = state.atCheckpoint('two', 'branch');
    expect(branch.characterId, 'branch');
    expect(branch.sequence, 1);
    expect(branch.activeFacts.single['text'], '钥匙在楼下');
    expect(branch.checkpoints.containsKey('two'), isFalse);
  });
  test(
      'director overrides merge per field and private chats use story preferences',
      () {
    final state = StoryContinuityState(characterId: 'w', data: {
      'directors': {
        'story': {'篇幅': '简短', '剧情节奏': '慢慢相处'},
        'scene': {'篇幅': '详细'},
        'turn': {'剧情节奏': '推进主线', '篇幅': ''}
      }
    });
    expect(StoryContinuityEngine.director(state), {'篇幅': '详细', '剧情节奏': '推进主线'});
    expect(StoryContinuityEngine.director(state, privateChat: true),
        {'篇幅': '简短', '剧情节奏': '慢慢相处'});
  });
  test('rewriting a duplicate paragraph replaces the selected occurrence only',
      () {
    const raw =
        '他点点头。\n\n他点点头。\n[GAME_STATE]\n时间：夜晚\n[/GAME_STATE]\n```html\n<html>他点点头。</html>\n```';
    final targets = StoryRewriteService.targets('m', raw);
    expect(targets, hasLength(2));
    final rewritten = StoryRewriteService.replace(raw, targets[1], '他摇摇头。');
    expect(rewritten, startsWith('他点点头。\n\n他摇摇头。'));
    expect(rewritten, contains('[GAME_STATE]\n时间：夜晚'));
    expect(rewritten, contains('<html>他点点头。</html>'));
    expect(() => StoryRewriteService.replace('changed', targets[1], '改写'),
        throwsStateError);
    expect(() => StoryRewriteService.replace(raw, targets[1], '[GAME_STATE]'),
        throwsStateError);
  });
  test('raw HTML fragments and bubble delimiters are excluded from selection',
      () {
    const raw =
        '[BUBBLE]第一段。[/BUBBLE]\n<div>番外秘密<button>点我</button></div>\n[BUBBLE]第二段。[/BUBBLE]';
    final targets = StoryRewriteService.targets('m', raw);
    expect(targets.map((t) => t.selectedText), ['第一段。', '第二段。']);
    expect(StoryRewriteService.replace(raw, targets.last, '第二段改写。'),
        contains('<div>番外秘密<button>点我</button></div>'));
  });
  test('group rewrite preserves speaker, reply target and other messages', () {
    final raw = '[GROUP_CHAT]\n${jsonEncode({
          'messages': [
            {'speakerId': 'a', 'content': '重复', 'replyTo': 'x'},
            {'speakerId': 'b', 'content': '重复'}
          ]
        })}\n[/GROUP_CHAT]';
    final target = StoryRewriteService.targets('m', raw)[1];
    final result = StoryRewriteService.replace(raw, target, '新台词');
    expect(result, contains('"speakerId":"a","content":"重复","replyTo":"x"'));
    expect(result, contains('"speakerId":"b","content":"新台词"'));
  });
  test('legacy authored material is backstage until explicitly marked public',
      () {
    expect(WorldBookEntry.fromJson({'title': '秘密'}).visibility.allows('a'),
        isFalse);
    expect(
        UserProfile.fromJson({'name': '真实身份'}).visibility.allows('a'), isFalse);
    expect(
        const StoryVisibility(mode: 'npcs', npcIds: ['a']).allows('a'), isTrue);
    expect(const StoryVisibility(mode: 'npcs', npcIds: ['a']).allows('b'),
        isFalse);
  });
  test(
      'NPC state projection keeps shared identity while isolating relationships',
      () {
    final npc = NpcProfile.fromJson({
      'id': 'a',
      'characterId': 'w',
      'name': '甲',
      'roleCard': '独立人设',
      'affinity': 90
    });
    final world = NpcWorldState(
        profile: {'affinity': 12, 'impression': '刚认识'}, messages: []);
    expect(world.project(npc).affinity, 12);
    expect(world.project(npc).roleCard, '独立人设');
    expect(npc.affinity, 90);
  });
  test(
      'continuity transaction round trips checkpoints, revisions and visibility',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final state = turn(StoryContinuityState(characterId: 'w'), 'one');
    state.data['revisions'] = {
      'main/one': [
        {'id': 'v1', 'content': '原文'}
      ]
    };
    await store.commitStoryWorkspace(state: state);
    final restored = await store.loadStoryContinuity('w');
    expect(restored.toJson(), state.toJson());
    expect(restored.atCheckpoint('one', 'b').facts, isEmpty);
  });
}
