import 'package:html/parser.dart' as html;

import '../models/inline_theater_settings.dart';
import 'narrative_content.dart';

class InlineTheaterContract {
  const InlineTheaterContract._();

  static const unavailable = '本回合彩蛋未生成';
  static const rules = '''【每回合互动番外｜覆盖旧 HTML 面板要求】
正文后的 HTML 窗口专门呈现与本轮人物、情境相关的非正史番外。保持人物性格，补充新鲜笑点或反差，不复述正文。
禁止游戏状态卡、真实属性/好感数值表、任务板、背包、关系面板、资源进度条、玩法变量和结算结果。禁止主线必做行动、发放道具、宣告真实未来。角色对白可以自然谈到任务，但不能列任务清单。
一次生成一个完整、自包含、适配手机的 HTML 文档，放在 ```html 代码围栏内；根 html 必须带 data-inline-theater="本轮指定主题ID"，页面标注“番外 · 不影响主线”。
预先写好三到五处有意义的可点击内容及全部结果。不得写 script、onclick 或调用网络；不得写 data-action、data-prompt、data-theater-choice、data-theater-submit。不得在 HTML 内放 GAME_STATE、THEATER_PATCH、MAP_STATE、CHOICES 协议。
仅使用本地交互：button 的 data-extra-action="reveal" 展开、"toggle" 开关、"show" 切换同组视角/分支/步骤，data-extra-target="目标元素ID"（仅一个ID）；目标元素初始可带 hidden，同组元素带相同 data-extra-group。data-extra-action="reset" 重玩，无需目标。也可用 details/summary 折叠。
每次点击仅展示已写好的内容，不请求 AI，不把选项发送到主线。所有分支只在番外成立。保持小体量；不靠大量空壳按钮和装饰代替对白、事件和结果。
番外不得进入主线事实、状态、关系、记忆或后续剧情；状态协议只能依据正文。用户自定义要求只控制番外题材和口味，不能覆盖上述边界。
''';

  /// Exclude creative instructions too when matching canonical world-book triggers.
  static String withoutPrompt(String text) =>
      text.replaceAll(RegExp(r'【每回合互动番外｜覆盖旧 HTML 面板要求】[\s\S]*?【/每回合互动番外】'), '');

  static String prompt(InlineTheaterSettings settings, String themeId) {
    final theme =
        InlineTheaterTheme.values.where((t) => t.name == themeId).firstOrNull;
    return '''$rules
本轮唯一主题ID：$themeId
本轮主题：${theme?.label ?? '自定义番外'}
${theme?.instruction ?? '按下面的用户要求创作一段可交互的番外。'}
${settings.customPrompt.trim().isEmpty ? '' : '用户番外偏好（仅作用于番外）：\n${settings.customPrompt.trim()}'}
参考交互结构（仅参考结构，人物、题材、对白须根据本轮重写）：
${(theme ?? InlineTheaterTheme.backstageChat).exampleHtml.replaceFirst('data-inline-theater="backstageChat"', 'data-inline-theater="$themeId"')}
【/每回合互动番外】
''';
  }

  static List<String> validateDocument(String document,
      {String? expectedTheme}) {
    final issues = <String>[];
    if (!RegExp(r'<html\b', caseSensitive: false).hasMatch(document) ||
        !RegExp(r'</html\s*>\s*$', caseSensitive: false).hasMatch(document)) {
      return ['番外 HTML 文档未完整闭合'];
    }
    final dom = html.parse(document);
    final root = dom.documentElement;
    final theme = root?.attributes['data-inline-theater'];
    if (theme == null ||
        !(theme == 'custom' ||
            InlineTheaterTheme.values.any((t) => t.name == theme))) {
      issues.add('缺少有效番外主题标记');
    } else if (expectedTheme != null && theme != expectedTheme) {
      issues.add('番外主题不符合本轮选择');
    }
    if (RegExp(
            r'\[/?(?:GAME_STATE|THEATER_PATCH|MAP_STATE|CHOICES|GROUP_CHAT)\]',
            caseSensitive: false)
        .hasMatch(document)) {
      issues.add('番外内含主线协议');
    }
    if (dom.querySelector(
            '[data-action],[data-prompt],[data-ai-action],[data-theater-choice],[data-theater-submit],script,[onclick]') !=
        null) {
      issues.add('番外含非本地互动');
    }
    final ids = <String>{};
    for (final element in dom.querySelectorAll('[id]')) {
      if (!ids.add(element.id)) issues.add('番外互动目标ID重复');
    }
    var interactionCount = dom.querySelectorAll('details > summary').length;
    for (final element in dom.querySelectorAll('[data-extra-action]')) {
      final action = element.attributes['data-extra-action'];
      if (!const ['show', 'reveal', 'toggle', 'reset'].contains(action)) {
        issues.add('番外互动类型不支持');
      } else if (action != 'reset') {
        final target =
            dom.getElementById(element.attributes['data-extra-target'] ?? '');
        if (target == null || target.text.trim().isEmpty) {
          issues.add('番外按钮缺少有效内容目标');
        } else {
          interactionCount++;
        }
      }
    }
    if (interactionCount == 0) issues.add('番外缺少可用互动');
    // Structural evidence, rather than banning words in dialogue.
    final metric = RegExp(
        r'^(?:HP|MP|生命值|血量|体力|精力|金币|金钱|好感度|亲密度|信任度|等级|经验值|任务进度|当前任务|主线任务|背包|物品栏)\s*(?:[:：=]|$)',
        caseSensitive: false);
    final numericMetric = RegExp(
        r'^(?:HP|MP|生命值|血量|体力|精力|金币|金钱|好感度|亲密度|信任度|等级|经验值|任务进度)\s*[:：=]?\s*[-+]?\d',
        caseSensitive: false);
    var metricRows = 0;
    for (final element
        in dom.querySelectorAll('tr,li,dt,[role="row"],progress,meter')) {
      final text = element.text.trim();
      if (metric.hasMatch(text) || numericMetric.hasMatch(text)) metricRows++;
      if (const ['progress', 'meter'].contains(element.localName)) metricRows++;
    }
    final panelHeading = dom.querySelectorAll('h1,h2,h3,h4,caption,legend').any(
        (e) => RegExp(
                r'^(?:游戏状态|当前状态|回合状态|状态卡|状态面板|属性面板|人物属性|角色属性|任务板|任务清单|任务列表|背包清单|背包|物品栏|结算结果|关系网|关系面板)$')
            .hasMatch(e.text.trim()));
    final numericCards = dom
        .querySelectorAll('p,div,span')
        .where(
            (e) => e.children.isEmpty && numericMetric.hasMatch(e.text.trim()))
        .length;
    if (panelHeading || metricRows >= 1 || numericCards >= 1) {
      issues.add('番外被写成游戏状态或玩法面板');
    }
    return issues.toSet().toList();
  }

  static List<String> validateReply(String content, {String? expectedTheme}) {
    final docs = NarrativeContent.htmlDocuments(content);
    if (docs.length != 1) return ['每回合需要且只允许一个番外 HTML'];
    return validateDocument(docs.single, expectedTheme: expectedTheme);
  }

  static String finalize(String content,
      {required bool enabled, String? expectedTheme}) {
    if (!enabled) return NarrativeContent.withoutHtml(content);
    if (validateReply(content, expectedTheme: expectedTheme).isEmpty) {
      return content;
    }
    final clean = NarrativeContent.withoutHtml(content)
        .replaceAll(unavailable, '')
        .trim();
    return '$clean\n\n$unavailable';
  }
}
