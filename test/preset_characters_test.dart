import 'package:ai_roleplay_chat/data/preset_characters.dart';
import 'package:ai_roleplay_chat/models/character_profile.dart';
import 'package:ai_roleplay_chat/models/model_params.dart';
import 'package:ai_roleplay_chat/services/message_content_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds tutorial demo as the locked default preset', () {
    final character = buildTutorialDemoCharacter();

    expect(character.presetId, tutorialDemoPresetId);
    expect(character.name, tutorialDemoName);
    expect(character.isPromptLocked, isTrue);
    expect(character.name, '第一次开幕');
    expect(character.prompt, contains('产品事实库'));
    expect(character.prompt, contains('幕灯'));
    expect(character.openingMessage, contains('幕灯'));
    expect(character.openingMessage, isNot(contains('NPC1')));
    expect(character.openingMessage, isNot(contains('NPC2')));
    expect(character.openingMessage, isNot(contains('NPC3')));
    expect(character.openingMessage, isNot(contains('HTML')));
    expect(character.isTutorialDemo, isTrue);
    expect(character.preferredChoiceCount, 3);
    expect(character.requiresHtmlPanel, isFalse);
    expect(character.runtimeProtocolPrompt, contains('300-600'));
    expect(character.runtimeProtocolPrompt, isNot(contains('2200-3200')));
    final parsed = MessageContentParser.parseStructured(
      character.openingMessage,
      cache: false,
    );
    expect(parsed.choices, hasLength(3));
    expect(
        parsed.choices.map((choice) => choice.index), <String>['A', 'B', 'C']);
  });

  test('normalizes legacy high school preset into tutorial demo', () {
    final legacy = CharacterProfile(
      id: 'char_legacy',
      name: '高中生活模拟器',
      createdAt: DateTime(2026),
      prompt: 'legacy prompt',
      modelParams: ModelParams.defaults(),
      description: 'legacy description',
      openingMessage: 'legacy opening',
      presetId: legacyHighSchoolSimulatorPresetId,
      isPromptLocked: true,
    );

    final normalized = normalizeTutorialDemoCharacter(legacy);

    expect(shouldNormalizeToTutorialDemo(legacy), isTrue);
    expect(normalized.id, legacy.id);
    expect(normalized.presetId, tutorialDemoPresetId);
    expect(normalized.name, tutorialDemoName);
    expect(normalized.description, tutorialDemoDescription);
    expect(normalized.prompt, contains('幕灯'));
    expect(normalized.hiddenPrompt, contains('第一次开幕专用节奏'));
  });

  test('refreshes the previous tutorial preset copy for existing users', () {
    final previous = CharacterProfile(
      id: 'tutorial-existing',
      name: legacyTutorialDemoName,
      createdAt: DateTime(2026),
      prompt: '旧版教程提示词',
      modelParams: ModelParams.defaults(),
      description: legacyTutorialDemoDescription,
      openingMessage: '旧版开场',
      hiddenPrompt: '旧版隐藏协议',
      presetId: tutorialDemoPresetId,
      isPromptLocked: true,
    );

    final normalized = normalizeTutorialDemoCharacter(previous);

    expect(normalized.name, tutorialDemoName);
    expect(normalized.description, tutorialDemoDescription);
    expect(normalized.openingMessage, tutorialDemoOpeningMessage);
    expect(normalized.prompt, tutorialDemoPrompt);
  });

  test('detects only empty or legacy generated runtime prompts', () {
    expect(shouldRefreshSimulatorRuntimePrompt(''), isTrue);
    expect(
      shouldRefreshSimulatorRuntimePrompt(
        '【隐藏运行协议】\n正文目标 2200-3200。\n每回合固定生成六个选项',
      ),
      isTrue,
    );
    expect(
      shouldRefreshSimulatorRuntimePrompt('用户自己编写的隐藏规则'),
      isFalse,
    );
  });
}
