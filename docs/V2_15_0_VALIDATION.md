# v2.15.0 验证与交付记录

验证日期：2026-10-27。基线 `e2e3c78`，独立分支 `codex/story-evolution-v215`，版本 `2.15.0+2150`。

## 实现范围

- 高级设置、篇幅控制、完整文游及盲盒的 3–6 人开局、作者预览、秘密折叠、锁定和局部重生成。
- 按世界隔离的 NPC 身份、好感、信任、立场、公开关系、目标与经历；有正文证据的重大变化；受游戏时间和人数限制的后台日常行动。
- 承诺和余波的明确期限、到期提醒，以及无法解析期限的原文保存。
- 正文、玩法、物品、NPC、连续性和结算批量提交；失败保留正文与重试入口；地图费用不重复执行。
- 桌面结算对话框、手机底部弹窗、消息重看、已读记录、旧档主动补全、v4 导出兼容和回退恢复。

## 自动验证

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| Flutter 静态分析 | 无问题 | `build/v215-analysis.log` |
| 完整 Flutter 回归 | 427 项通过，1 项按配置跳过 | `build/v215-regression.log` |
| 网页启动测试 | 3 项通过 | `build/v215-web-boot-tests.log` |
| 离线提示词评测 | 21/21 场景通过，普通首轮 18/18，真实网络调用 0 | `build/v215-prompt-eval.json` |
| Web release 构建 | 通过 | `build/v215-web-release.log` |
| Android release 构建 | 通过，使用独立 Gradle 缓存 | `build/v215-android-release.log` |

完整回归中唯一跳过的项目是显式启动的提示词评测 runner，已另行运行。离线评测包含 26 次模拟生产调用，其中 5 次是场景内额外调用，不表示真实模型的质量或成功率。

新增自动测试覆盖：3 人和 6 人开局、重复 ID 与错误引用、原文指令、创建失败不留下部分世界、身份揭露保持稳定 ID、共享人物新世界基线、传闻不判死、死亡后不增加关系、日常行动的时间和人数限制、后台重大事件只记线索、物品耗尽不复活、期限不擅自推断、秘密不进入结算、结算与存档一致、重复重试不二次增加好感、失败保存恢复、删回合及后续变化重放、独立剧情分支，以及新回合不再运行旧的二次 NPC 提取。

现有回归继续覆盖主线及 NPC 私聊改写、群聊、地图、取消生成、固定事实冲突、存档导入导出、私聊知识边界、存储写入中断回滚与重启恢复。保存失败、作者预览、锁定按钮和手机结算滚动另有组件测试。

## 浏览器验收

使用 Edge 无头浏览器的独立上下文，尺寸为 **1280×950** 和 **390×950**，窄屏启用触摸能力模拟。模型请求全部拦截为虚构数据，没有使用用户真实存档、API 密钥或付费模型。

两个尺寸均验证：生成一回合并自动结算；同时变化的玩法、物品、好感与信任；关闭后刷新不重弹；填写高级设置并核对 IndexedDB 中的原文；生成三个初始人物；作者查看与收起秘密；锁定人物后禁止重做；单独重做第二人；创建保存；玩家人物页只展示已登场人物。

每个尺寸 4 次模拟请求，页面异常为 0。验收脚本对 Flutter 的可访问输入框先滚动至可见区域，再输入和核对值，避免离屏输入造成虚假的空值结果。结算、创建预览和人物页截图已查看。最终结果在 `build/story-evolution-qa/browser-report.json`。

关键截图：

- `1280-settlement.png`：桌面统一结算。
- `390-settlement.png`：手机底部结算弹窗。
- `390-advanced-filled.png`：手机高级设置与原文指令。
- `390-opening-preview.png`：人物锁定与局部重生成。
- `1280-author-preview.png`：带剧透标识的作者入口。
- `1280-public-npcs.png`：玩家可见人物列表。

截图及报告复制到 `build/deliverables/v2.15.0/`。界面测试使用固定的虚构故事，英文变量标签来自测试样本。

## 构建与使用

Web 文件位于 `build/web/`；交付 ZIP 解压后使用 HTTP 服务打开，不能直接双击 `index.html`。Android APK 位于 `build/app/outputs/flutter-apk/app-release.apk`，交付目录另有命名副本。

本地 Android 构建最初遇到全局 Gradle 缓存 `metadata.bin` 损坏，改用工作树内隔离缓存和已有离线依赖后成功；未删除或改动用户的全局缓存。本 APK 使用本地调试签名完成 release 模式构建，不能冒充正式发布签名，可能无法覆盖已安装的正式签名版本。

Web 构建保留既有 CupertinoIcons 字体提示，构建成功，检查的页面没有发现图标或布局异常。

## 实际边界

- 真实模型的文风、长篇质量、语义保密与复杂剧情推理没有实测；这里验证的是受控响应下的程序协议、存储与交互行为。
- 没有连接物理 Android 设备；手机验证为浏览器视口及触摸模拟。APK 构建成功不等于真机验收。
- 未推送 GitHub、未创建线上发行版、未更新 Pages。本次交付包含本地 Git 检查点。
- 明确证据校验使用结构字段和正文引用，不声称能完整理解所有自然语言的真假与否定。无法解析的期限不自动推断，冲突保留人工确认入口。
- 存储持续拒绝写入时，无法保证正文或已读标记跨重启保存；应用保留错误与重试入口，不把失败当成提交成功。

## 复现

```powershell
flutter --no-version-check analyze --no-pub lib test tools
flutter --no-version-check test --no-pub --reporter expanded
node --test tools/web_boot_test.mjs
python tools/prompt_eval/prompt_eval.py run --repeats 1 --output build/prompt-eval-new.json
flutter --no-version-check build web --release --no-pub --no-wasm-dry-run
flutter --no-version-check build apk --release --no-pub
flutter test --no-pub tools/story_evolution_fixture.dart
python -m http.server 8925 --bind 127.0.0.1 --directory build/web
# 另开终端；Playwright 可由项目外运行环境提供。
node tools/story_evolution_browser_qa.cjs
```

若 Playwright 未安装在默认模块路径，设置 `THEATER_PLAYWRIGHT_MODULE`；若使用其他本地端口，设置 `THEATER_QA_URL`。实际构建日志、校验和及截图随本地交付目录保存。
