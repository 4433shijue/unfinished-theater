# v2.16.0 本地验收

基于 v2.15.0 的 `46ab75b`，在独立分支 `codex/story-small-features-v216` 实现。原工作目录已有的改动没有混入本次提交。

## 已落地

- 主线与 NPC 引用接话、来源查看、过期引用拦截，引用随存档与导出保存。
- 两种表达候选、采用前预览、编辑与恢复原稿，不自动发送或结算。
- 按世界保存私人便签；显式带入输入框或导演台；分支复制便签且不复制待发送草稿。
- 全局常用导演短语，继续使用本回合、本场景、本剧本的原有范围。
- 按世界和 NPC 保存双方称呼与使用条件，随剧情快照保持分支隔离。
- 默认简短结算，重要公开变化突出显示，完整明细与失败处理仍可用。
- A–F 六路线共用生成、修复和灵感规则，逐步提高意外程度；F 在世界规则内尝试荒诞行动，后果正常生效。保留多选，在同一次生成请求内自检；最新回复可按需只换选项。

## 自动验证

- `flutter analyze --no-pub` 无问题。
- 全量 `flutter test --no-pub --reporter expanded`：461 项通过、1 项跳过。另跑相关 UI 测试，21 项通过。
- `flutter build web --release --no-pub --no-wasm-dry-run` 完成。构建仍有原有 Cupertino 字体族提示，没有编译错误。
- 浏览器用隔离的合成存档与模拟接口验证 1280×1000、390×1000 两种尺寸：表达候选和撤回、私人便签、常用短语、换选项、主线/NPC 引用、持久化恢复、专属称呼及私聊请求。每种尺寸 3 次模拟请求，页面异常为 0。
- 单元测试覆盖选项数量/字母/明显重复、请求隔离、替换只改选项、过期结果、引用原文变化、分支来源映射、并行保存、导出导入和失败后保留草稿。引用指纹的乘法拆分成 16 位运算，避免 JavaScript 精度导致跨端存档误判；原生测试和浏览器测试均与 FNV 参考值比较。

运行浏览器验收前执行 `flutter test tools/story_composer_browser_fixture.dart`，然后提供 `build/web` 静态服务并运行 `node tools/story_composer_browser_qa.cjs`。可通过 `THEATER_QA_URL`、`THEATER_PLAYWRIGHT_MODULE`、`THEATER_CHROMIUM_EXECUTABLE` 指定本地环境；结果在 `build/story-composer-qa/`。

## 验证边界

浏览器使用模拟接口，没有调用付费模型。六项的真实创意与语义差异仍需所连接模型遵守策略，程序不能保证模型每轮都达到创意要求。没有进行实体 Android 设备或真实账号验收。

Android APK **未产出**。默认 Gradle 缓存先报损坏的 `transforms/.../metadata.bin`；隔离缓存后在线解析依赖长时间停在下载。补齐并验证 Kotlin 1.8.22 编译器校验值，再离线构建，仍报 `flutter_plugin_android_lifecycle` 所需的 `com.android.tools.build:gradle:8.13.1` 未缓存。未为了通过本地构建而修改项目的插件或 AGP 版本。日志为 `build/v216-apk-build.log` 和 `build/v216-apk-offline.log`。

网页包为 `build/releases/unfinished-theater-v2.16.0-web.zip`。未推送远端、部署 Pages 或发布正式版本。
