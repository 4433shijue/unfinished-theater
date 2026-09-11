import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_roleplay_chat/services/theme_font_service.dart';

void main() {
  test('concurrent requests and subsequent visits share one download',
      () async {
    final gate = Completer<void>();
    var calls = 0;
    final fonts = ThemeFontService(load: (_, __) {
      calls++;
      return gate.future;
    });
    final first = fonts.ensure('AbyssSerif');
    final second = fonts.ensure('AbyssSerif');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    gate.complete();
    await Future.wait([first, second]);
    await fonts.ensure('AbyssSerif');
    expect(calls, 1);
  });
  test('failed font can be retried without invalidating successful fonts',
      () async {
    var attempts = 0;
    final fonts = ThemeFontService(load: (family, _) async {
      if (family == 'AbyssSerif' && attempts++ == 0) {
        throw StateError('offline');
      }
    });
    await fonts.ensure('FlowerWenDingKai');
    await expectLater(fonts.ensure('AbyssSerif'), throwsStateError);
    await fonts.ensure('AbyssSerif');
    expect(attempts, 2);
  });
}
