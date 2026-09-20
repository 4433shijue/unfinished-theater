# 提示词固定样本评测

评测工具位于 `tools/prompt_eval/`。16 个虚构场景使用真实生产请求构建、JSON/协议解析器和必要的 Controller 流程，不另抄一套生成提示词。结果分别记录机器协议检查与待人工评分的内容质量。

普通 CI 只跑传输层单元测试，评测 runner 默认跳过。显式 `run` 默认使用模拟回复，不联网调用模型，也不读取应用存档或寻找 API 密钥。

## 运行方法

在项目根目录执行，先按项目常规流程完成 `flutter pub get`。

```powershell
# 16 个场景各跑两次，捕获实际生产请求，回复全部为模拟数据。
python tools/prompt_eval/prompt_eval.py run --output .tmp/prompt-eval/current.json

# 固定旧版源码。git archive 在临时目录运行，不切当前分支。
# 依赖只从本地缓存解析，缺少缓存时明确失败。
python tools/prompt_eval/prompt_eval.py run --ref v2.11.0 --output .tmp/prompt-eval/v2.11.0.json
python tools/prompt_eval/prompt_eval.py run --ref v2.11.1 --output .tmp/prompt-eval/v2.11.1.json

python tools/prompt_eval/prompt_eval.py report .tmp/prompt-eval/v2.11.0.json .tmp/prompt-eval/v2.11.1.json --output .tmp/prompt-eval/blind-review.html
```

`--repeats 1` 适合首次检查；`--scenarios daily_dialogue,group_chat` 可以只跑指定场景。输出文件已存在时默认拒绝覆盖，要重跑请换路径或显式加 `--overwrite`。不要同时在同一工作目录运行多个 Flutter 测试进程，它们共享编译缓存；不同的临时基线目录不共享该缓存。

真实模型只在 `--mode live` 下启用，且必须由操作者在当前进程明确提供以下环境变量。

默认沿用应用的流式用量统计开关。如果服务商不接受 `stream_options.include_usage`，可额外设置 `PROMPT_EVAL_INCLUDE_STREAM_USAGE=0`；报告会保留最终请求中的差异。这是连接兼容性设置，不能把关闭用量统计后的结果与开启状态混称为同一请求。

默认通过生产 `streamChat` 评测。若服务商对完整长上下文的流式请求返回 400，而同一请求的非流式接口可用，可设置 `PROMPT_EVAL_STREAM=0` 改用生产 `sendChat`；报告会记录传输方式，非流式结果不能与流式结果直接混比。

| 环境变量 | 内容 |
| --- | --- |
| `PROMPT_EVAL_API_URL` | HTTPS Chat Completions 服务地址，不含查询参数或内嵌凭证 |
| `PROMPT_EVAL_API_KEY` | 当前评测专用的运行时密钥 |
| `PROMPT_EVAL_MODEL` | 完整模型 ID |

不要把密钥写在命令、文档或提交文件中。配置好环境后先运行一个小样本。

```powershell
python tools/prompt_eval/prompt_eval.py run --mode live --scenarios daily_dialogue --repeats 1 --max-requests 1 --max-output-tokens 8192 --output .tmp/prompt-eval/live-smoke.json

# 每个版本 16 场景 x 2 次。分别指定旧版/新版，以相同预算和模型运行。
python tools/prompt_eval/prompt_eval.py run --mode live --ref v2.11.0 --repeats 2 --max-requests 48 --max-output-tokens 393216 --output .tmp/prompt-eval/live-old.json
python tools/prompt_eval/prompt_eval.py run --mode live --ref v2.11.1 --repeats 2 --max-requests 48 --max-output-tokens 393216 --output .tmp/prompt-eval/live-new.json
python tools/prompt_eval/prompt_eval.py report .tmp/prompt-eval/live-old.json .tmp/prompt-eval/live-new.json --output .tmp/prompt-eval/live-review.html
```

两个版本分别受各自预算控制；上述完整对比最多 96 次生产调用、786432 个预留输出 tokens。真正联网次数会低于生产调用次数，因为固定故障首轮不发网络。这个上限也包含所有额外修复和续写，不能用“32 个场景任务”替代费用计算。

## 预算与记录

- `--max-requests` 限制整个运行中的生产 HTTP 调用次数，故障注入也保守占一个名额；每次网络发送前检查，不会越额继续修复。
- `--max-output-tokens` 是**请求输出上限的累计预留预算**。每次以该功能的生产 `max_tokens` 预留，避免接口不返回 usage 时失去总量限制。生产调用未指定上限时，评测添加 8192 并记录 `outputCapAdded=true`，已有上限不改变。
- 输出 tokens 由服务端遵守 `max_tokens`；客户端另有 4 MiB 响应字节上限及超时。无法把服务商忽略参数或失败请求是否收费伪装成客户端可保证的账单上限。
- 不自动重试 HTTP 错误、限流、超时和断流，出现这些错误即结束本次运行，已完成的请求和部分报告保留。超预算也保留结果，并以退出码 2 结束。
- 每次调用记录实际 messages、温度、top_p、输出上限、原始生成内容、状态、耗时、首字节到达时间、finish_reason 及接口实际返回的 usage。首字节时间不声称等于首个可见字符时间。
- `summary` 区分普通首轮通过率、最终通过率、额外调用、真实网络请求、故障注入和已知 tokens。usage 缺失不会伪造为完整零消耗；没有价格配置，费用为未知。
- 不保存请求 headers、密钥或服务端错误正文；运行时密钥若意外出现在请求正文/响应正文中会替换为 `[REDACTED]`。结果只含本工具的固定虚构故事，不读取用户的浏览器/桌面真实记录。

## 场景与实际覆盖

| 场景 ID | 目的 | 使用的生产入口 |
| --- | --- | --- |
| `daily_dialogue` | 日常接话与人物口吻 | `LlmApiClient.streamChat` |
| `conflict` | 冲突中的边界和回应 | 同上 |
| `reunion` | 兑现约定与前情连续 | 同上 |
| `group_chat` | 群聊说话人及回复对象 | 同上，群聊模式 |
| `map_turn` | 计划与已抵达的区别 | 同上，地图模式 |
| `no_choices` | 关选项仍保留状态 | 同上 |
| `gameplay_turn` | AI 权限与程序结算 | 同上，变量玩法 |
| `hidden_variables` | 导演信息与 engine 私有变量 | 同上，变量玩法 |
| `memory_summary` | 承诺和未证实信息 | `summarizeConversation` |
| `simulator_creation` | 世界设定四字段 | `generateSimulatorPrompt` |
| `simulator_repair` | 缺字段后的有限补全 | 同上，固定故障注入 |
| `gameplay_creation` | v3 玩法合同 | `generateGameplaySystem` |
| `gameplay_repair` | 非法 JSON 后修复 | 同上，固定故障注入 |
| `item_identification` | 鉴定结果与扣费 | `AppStateController.identifyStoryInventoryItem` |
| `fanfic_continuation` | 原灵感和续写衔接 | `AppStateController.generateFanfic`，固定截断注入 |
| `npc_role_card` | 已有角色事实保留 | `AppStateController.buildNpcRoleCardDraft` |

主剧情场景验证真实 `streamChat` 构建、HTTP 传输和正式回复协议/变量解析，不模拟整个玩家 UI 发送链，也不自行增加一套主剧情修复策略。因此主剧情可能报告原始协议失败，不能把它解释成已验证所有生产裁判、后台任务与修复。正式服务本身有补全/修复的任务则按原流程继续运行，并记录每次调用。变量补丁会交给正式权限引擎检查；内容是否自然、语义是否泄漏、事实是否遗漏还需人工审阅。

三个故障场景在离线和 live 下都注入同一份损坏/截短首轮结果，标记为 `fault_fixture`（离线则 `synthetic_mock`），让后续真实修复面对完全一致的错误。它们不计入普通模型首轮通过率。报告保留修复前后的文本，不会将一次修复成功改写为首轮成功。离线完整回合默认共 19 次生产调用，3 次是额外修复/续写。

固定输入时间、角色 ID、NPC、历史与初始变量相同；Controller 内部使用系统时间生成的结果 ID 不参与评分或比较。两版保留各自生产参数，报告保留完整 payload 供核对。采样不能保证确定性，也不能假设某个兼容服务支持 seed。版本比较包含运行逻辑差异，不应把所有变化都归因于提示词文案。

## 人工盲评与结论

报告是独立本地 HTML，无 CDN、遥测和网络依赖。A/B 次序按场景随机打乱，先分别从人物口吻、自然度、行动与因果、上下文一致、玩家自主权五维评分，再选偏好并写一句理由。JSON 生成任务中不适用的维度留空，机器协议检查单列，避免把小说和 JSON 硬凑一个总分。

可以展开固定前情、初始输出、格式问题和调用记录；点“揭晓版本”后显示提交。评分在浏览器本地保存，“导出评分 JSON”会下载含场景、版本映射与评分的文件。HTML 源码中包含版本映射，盲评是界面隐藏而非对源代码查看者保密。

报告拒绝混比不同模型、端点、fixture、模式或场景/重复集合。mock 对 mock 用于验收工具；live 对 live 才提供真实模型结果。示例不是“提示词全面变好”的证据，少量样本只支持对应场景，最终报告需保留差异、失败和人工意见。

## 工具验证

```powershell
flutter test --no-pub test/prompt_eval_transport_test.dart
python -m unittest discover -s tools/prompt_eval -p test_prompt_eval.py
dart analyze tools/prompt_eval test/prompt_eval_runner_test.dart test/prompt_eval_transport_test.dart
```

仅测试真实服务协议检查与受控模拟传输不会产生真实模型费用。完整 50 套任务目录仍由 `docs/AI_PROMPTS.md` 管理；本工具首版 16 场景是代表性样本，不声称已完成全部 50 套真实模型验收。
