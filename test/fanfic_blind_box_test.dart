import 'dart:math' as math;

import 'package:ai_roleplay_chat/models/fanfic_blind_box.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the full 1-99 fanfic blind box inspiration pool', () {
    expect(fanficBlindBoxInspirations, hasLength(99));
    expect(
      fanficBlindBoxInspirations.map((item) => item.number),
      List<int>.generate(99, (index) => index + 1),
    );
    expect(fanficBlindBoxInspirations[15].label, '#16 不doi就出不去的房间');
    expect(fanficBlindBoxInspirations[23].label, '#24 abo');
    expect(fanficBlindBoxInspirations[98].label, '#99 楚门的世界pa');
  });

  test('rolls a local numbered inspiration label', () {
    final inspiration = rollFanficBlindBoxInspiration(random: math.Random(1));

    expect(inspiration.number, inInclusiveRange(1, 99));
    expect(inspiration.label, startsWith('#${inspiration.number} '));
    expect(inspiration.inspiration, isNotEmpty);
  });
}
