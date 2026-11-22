// Execute this same harness against the 2.16 and 3.0 package configs.
// All data and model replies are synthetic; no network request leaves the test.
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_roleplay_chat/controllers/app_state_controller.dart';
import 'package:ai_roleplay_chat/models/save_envelope.dart';
import '../test/story_workflow_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real package archive round trip', () async {
    final mode = Platform.environment['EXPRESSION_COMPAT_MODE'] ?? 'seed';
    final dir = Directory(Platform.environment['EXPRESSION_COMPAT_DIR']!);
    dir.createSync(recursive: true);
    final c = await fixtures.fixture(fixtures.ScriptedClient());
    if (mode == 'seed') {
      expect(currentSaveAppVersion, '2.16.0+2160');
      await c.queueUserMessage('旧版保存的原话');
      await c.requestAssistantReply();
      await c.queueNpcUserMessage('a', '只告诉阿澈的旧版私聊');
      await c.requestNpcReply('a');
      await c.savePrivateNote('world', '私人便签仍未带入模型');
      File('${dir.path}/v216.json')
          .writeAsStringSync(await c.exportAllDataArchive());
    } else if (mode == 'upgrade') {
      expect(currentSaveAppVersion, '3.0.0+3002');
      expect(
          await c.importDataArchive(
              File('${dir.path}/v216.json').readAsStringSync(),
              replaceExisting: true),
          isNull);
      await c.selectCharacter('world');
      expect(
          c.currentHistory.messages.any((m) => m.content == '旧版保存的原话'), isTrue);
      await c.queueUserMessage('把信交给他，但先不答应上楼');
      await c.requestAssistantReply();
      await c.queueNpcUserMessage('a', '只有阿澈知道的独立私聊');
      await c.requestNpcReply('a');
      await c.updateMessageContent(
          c.currentHistory.messages.last.id, '他接过信。\n\n“**要上楼谈吗**？”他等着你的回答。');
      await c.updateNpcMessageContent(
          'a', c.npcMessagesFor('a').last.id, '“*我知道了*。”');
      expect(
          await c.createStoryBranchFromMessage(
              messageId: c.currentHistory.messages.last.id,
              branchName: '正文表现力版本创建的分支'),
          isNull);
      File('${dir.path}/v300.json')
          .writeAsStringSync(await c.exportAllDataArchive());
      File('${dir.path}/expected.json').writeAsStringSync(jsonEncode({
        'branchId': c.currentCharacter!.id,
        'history': c.currentHistory.toJson(),
        'npcs': c.npcMessagesFor('a').map((m) => m.toJson()).toList(),
        'state': c.currentGameState.toJson(),
        'note': await c.loadPrivateNote(c.currentCharacter!.id),
      }));
    } else {
      expect(currentSaveAppVersion, '2.16.0+2160');
      expect(
          await c.importDataArchive(
              File('${dir.path}/v300.json').readAsStringSync(),
              replaceExisting: true),
          isNull);
      final expected =
          jsonDecode(File('${dir.path}/expected.json').readAsStringSync());
      await c.selectCharacter(expected['branchId']);
      expect(c.currentHistory.toJson(), expected['history']);
      expect(c.npcMessagesFor('a').map((m) => m.toJson()).toList(),
          expected['npcs']);
      expect(c.currentGameState.toJson(), expected['state']);
      expect(await c.loadPrivateNote(c.currentCharacter!.id), expected['note']);
      expect(c.currentCharacter!.isStoryBranch, isTrue);
      await c.queueUserMessage('退回旧版后依然能继续');
      expect(await c.requestAssistantReply(), isNull);
      File('${dir.path}/rollback-result.json').writeAsStringSync(jsonEncode({
        'readerVersion': currentSaveAppVersion,
        'schema': currentSaveSchemaVersion,
        'historyAndNpcAndStateEqual': true,
        'continuedAfterRollback': true,
      }));
    }
  });
}
