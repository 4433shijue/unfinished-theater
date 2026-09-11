import 'package:ai_roleplay_chat/models/chat_message.dart';
import 'package:ai_roleplay_chat/models/npc_profile.dart';
import 'package:ai_roleplay_chat/widgets/chat_message_bubble.dart';
import 'package:ai_roleplay_chat/widgets/onboarding_tutorial_dialog.dart';
import 'package:ai_roleplay_chat/widgets/tutorial_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all built-in bubble skins render in a compact preview',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const frameIds = <String>[
      'frame_default',
      'frame_sticky_note',
      'frame_cat_paw',
      'frame_moon_ticket',
      'frame_whisper_rift',
      'frame_inbox_burst',
      'frame_cream_note',
      'frame_film_strip',
      'frame_pixel_quest',
      'frame_bad_luck_charm',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                for (final frameId in frameIds)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: BubbleFramePreview(
                      frameId: frameId,
                      label: frameId,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BubbleFramePreview), findsNWidgets(frameIds.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large group chat bubbles fit on phone and expose interactions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const content = '''
[GROUP_CHAT]
{"mode":"large_group_chat","messages":[{"id":"msg_1","type":"narration","speakerId":"narrator","speaker":"旁白","replyTo":"","content":"雨声停在窗外，会议室里忽然安静下来。"},{"id":"msg_2","type":"npc","speakerId":"npc-linxia","speaker":"林夏","replyTo":"msg_1","content":"刚才是谁关了灯？"},{"id":"msg_3","type":"npc","speakerId":"npc-zhouheng","speaker":"周珩","replyTo":"msg_2","content":"不是我，先别碰门。"}]}
[/GROUP_CHAT]
''';
    final npcProfiles = <NpcProfile>[
      NpcProfile(
        id: 'npc-linxia',
        characterId: 'character-1',
        name: '林夏',
        createdAt: DateTime(2026, 8, 8),
        updatedAt: DateTime(2026, 8, 8),
      ),
      NpcProfile(
        id: 'npc-zhouheng',
        characterId: 'character-1',
        name: '周珩',
        createdAt: DateTime(2026, 8, 8),
        updatedAt: DateTime(2026, 8, 8),
      ),
    ];
    String? mentionedSpeaker;
    String? repliedMessageId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ChatMessageBubble(
              message: ChatMessage(
                id: 'assistant-1',
                role: ChatRole.assistant,
                content: content,
                timestamp: DateTime(2026, 8, 8),
                isSummarized: false,
              ),
              assistantName: '群聊界面测试',
              npcProfiles: npcProfiles,
              onGroupChatMention: (message) {
                mentionedSpeaker = message.speaker;
              },
              onGroupChatReply: (message) {
                repliedMessageId = message.id;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('林夏'), findsWidgets);
    expect(find.text('林夏：刚才是谁关了灯？'), findsOneWidget);
    expect(find.byIcon(Icons.alternate_email_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.reply_rounded), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.alternate_email_rounded).first);
    await tester.tap(find.byIcon(Icons.reply_rounded).last);
    await tester.pump();

    expect(mentionedSpeaker, '林夏');
    expect(repliedMessageId, 'msg_3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial text streams and can reveal the full copy',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreamingTutorialText(
            text: '这段教程会逐字出现。',
            interval: Duration(milliseconds: 80),
          ),
        ),
      ),
    );
    await tester.pump();

    final initialText =
        tester.widget<RichText>(find.byType(RichText).first).text.toPlainText();
    expect(initialText, isNot(contains('这段教程会逐字出现。')));

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(StreamingTutorialText));
    await tester.pump();

    final revealedText =
        tester.widget<RichText>(find.byType(RichText).first).text.toPlainText();
    expect(revealedText, contains('这段教程会逐字出现。'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial overlay lets target clicks advance the guide',
      (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var completed = false;
    const sequence = TutorialGuideSequence(
      title: '交互测试',
      steps: <TutorialGuideStep>[
        TutorialGuideStep(
          target: TutorialTargetId.apiUrlField,
          action: TutorialTargetId.apiUrlField,
          icon: Icons.looks_one_outlined,
          title: '第一步',
          instruction: '请点击真实按钮。',
          actionLabel: '点击目标',
        ),
        TutorialGuideStep(
          target: TutorialTargetId.apiUrlField,
          action: TutorialTargetId.apiUrlField,
          icon: Icons.looks_two_outlined,
          title: '第二步',
          instruction: '再次点击真实按钮。',
          actionLabel: '再次点击目标',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(
                left: 24,
                top: 24,
                child: FilledButton(
                  key: TutorialTargetRegistry.keyOf(
                    TutorialTargetId.apiUrlField,
                  ),
                  onPressed: () => TutorialTargetRegistry.report(
                    TutorialTargetId.apiUrlField,
                  ),
                  child: const Text('真实目标'),
                ),
              ),
              TutorialGuideOverlay(
                sequence: sequence,
                onCompleted: () => completed = true,
                onSkipped: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('第一步'), findsOneWidget);
    await tester.tap(find.text('真实目标'));
    await tester.pump();
    expect(find.text('第二步'), findsOneWidget);

    await tester.tap(find.text('真实目标'));
    await tester.pump();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial card stays on-screen on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const sequence = TutorialGuideSequence(
      title: '手机引导',
      steps: <TutorialGuideStep>[
        TutorialGuideStep(
          target: TutorialTargetId.chatLaunch,
          action: TutorialTargetId.chatLaunch,
          icon: Icons.near_me_rounded,
          title: '手机端步骤',
          instruction: '卡片应当避开底部操作按钮，并完整留在屏幕范围内。',
          actionLabel: '点击底部按钮',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(
                right: 18,
                bottom: 18,
                child: IconButton.filled(
                  key: TutorialTargetRegistry.keyOf(
                    TutorialTargetId.chatLaunch,
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.near_me_rounded),
                ),
              ),
              TutorialGuideOverlay(
                sequence: sequence,
                onCompleted: () {},
                onSkipped: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final cardRect = tester.getRect(
      find.byKey(const ValueKey<String>('手机引导-0')),
    );
    expect(cardRect.left, greaterThanOrEqualTo(0));
    expect(cardRect.top, greaterThanOrEqualTo(0));
    expect(cardRect.right, lessThanOrEqualTo(390));
    expect(cardRect.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('detailed tutorial streams a topic and offers live guidance',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DetailedTutorialDialog()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('完整功能教程'), findsOneWidget);
    expect(find.text('开始游玩'), findsWidgets);
    expect(find.text('剧场与设定'), findsOneWidget);
    expect(find.byType(StreamingTutorialText), findsOneWidget);
    expect(find.text('进入界面，跟随高亮操作'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
