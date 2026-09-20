import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/prompt_eval/scenario_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configPath = Platform.environment['PROMPT_EVAL_CONFIG'];
  test('explicit prompt evaluation run', () async {
    final config = jsonDecode(File(configPath!).readAsStringSync()) as Map<String, dynamic>;
    final result = await PromptEvalRunner(config).run();
    expect(result['cases'], isNotEmpty);
  }, skip: configPath == null ? 'Use tools/prompt_eval/prompt_eval.py run; never calls models during normal CI' : false,
     timeout: const Timeout(Duration(hours: 2)));
}
