# 未完剧场 🎭

**故事还没写完，先别急着散场。**

一个用 Flutter 做的 AI 角色扮演与文字游戏应用，支持网页和安卓。你来定人设、选行动，AI 接着往下演。聊得投缘的 NPC 可以私聊，还能带去新世界继续折腾。

本项目使用 AI 辅助开发。欢迎看代码、提问题，也欢迎把它改成你喜欢的样子。AI 写代码时很有自信，出问题时还请以实际表现为准。

## 先把剧场开起来

| 你想怎么入场 | 从这里走 |
| --- | --- |
| 打开网页就玩 | [直接进入剧场](https://4433shijue.github.io/unfinished-theater/) |
| 安卓安装 | [前往 Releases 下载 `.apk`](https://github.com/4433shijue/unfinished-theater/releases/latest) |
| 下载源码自己运行 | 看下方的本地启动 |
| 自己修改、打包或部署 | 看下方构建说明和 [发布指南](docs/PUBLISHING.md) |

**开始 AI 对话前，需要填写自己的 API 地址、API Key 和模型名称。** 支持兼容 OpenAI Chat Completions 的接口，项目不附送共享 Key。模型服务可能收费，账单由你选择的服务商决定，剧场里的「啥币」不能拿去抵扣。

首次打开先加载基础字体，主题字体随后按需补齐，等待时仍可操作。网络异常时可按提示重试，不必清除存档。

第一次打开后进入设置，完成 API 配置，再创建角色或跟着「第一次开幕」体验流程开始。详细操作见 [游玩说明](USER_GUIDE.md)。

## 这里能玩什么

- **开自己的剧本**。创建角色、人设和世界书，也能让 AI 帮忙写。想怎么开场，你说了算，AI 的发挥另说。
- **剧情有后续**。长期记忆、故事状态和角色专属玩法变量会跟着对话保存。记忆也能自己看、自己改。
- **NPC 有自己的戏**。私聊、羁绊路线、整理角色卡，还能把喜欢的 NPC 带去新世界。换个世界，关系继续培养。
- **走岔了可以另开一条线**。剧情分支、存档快照、重新回复都在。关键操作前还有自动保护快照。
- **看剧情也要挑装修**。主题、气泡皮肤、自定义 CSS 子集样式，以及 HTML 剧情面板。今天想看什么风格，就给剧场换一套。
- **把喜欢的片段带走**。消息书签、全局搜索、剧情分享卡、HTML 导出和 JSON 存档迁移，方便回看和备份。

完整版本变化放在 [更新记录](CHANGELOG.md)，这里先给新来的朋友留条进门的路。

## 下载源码，本地开演

需要先安装 [Git](https://git-scm.com/downloads) 和 [Flutter SDK](https://docs.flutter.dev/install)，并把 Flutter 加入 PATH。项目自动构建固定使用 Flutter **3.41.7**，建议先用同一版本。Git 负责搬代码，Flutter 负责让代码上班。

复制下面几行，就能把剧场搬回自己电脑。

```bash
git clone https://github.com/4433shijue/unfinished-theater.git
cd unfinished-theater
flutter doctor
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5173
```

等终端提示服务启动后，用日常使用的 Chrome 或 Edge 打开 [本地剧场](http://127.0.0.1:5173)。终端保持开着，关闭它就会停服。

Windows 也可以直接运行启动脚本。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_web.ps1
```

macOS 和 Linux 使用下面这条。

```bash
sh ./run_web.sh
```

脚本会安装项目依赖并启动固定端口的网页服务。首次下载 Flutter 和依赖需要联网。

## 自己打包

先在项目根目录检查代码。

```bash
flutter pub get
flutter analyze
flutter test --no-pub
```

**打包网页**

```bash
flutter build web --release
```

成品在 `build/web/`，可以放到静态网站托管服务。不能直接双击 `index.html`，浏览器会当场罢工。如果电脑上有 Python，可以本地预览构建结果。

```bash
python -m http.server 5173 --bind 127.0.0.1 --directory build/web
```

然后打开 [本地剧场](http://127.0.0.1:5173)。部署到 GitHub Pages 的仓库子路径时需要设置 `--base-href`，项目的 Pages 工作流已经处理了默认 GitHub 地址的情况。

**打包安卓**

安装 Android SDK 与 JDK 17，并通过 `flutter doctor` 检查 Android 工具链，按提示接受 SDK 许可。

```bash
flutter doctor --android-licenses
flutter build apk --release
```

成品在 `build/app/outputs/flutter-apk/app-release.apk`。没有配置自己的签名时，个人构建会使用调试签名；正式分发请按 [发布指南](docs/PUBLISHING.md) 配置长期使用的发布密钥。

Windows 上的 `build.ps1` 可以依次完成检查、Web 打包和 APK 打包，需要同时具备两端的构建环境。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

## 存档住在哪里

角色、聊天、API 设置和存档保存在当前设备本地。AI 请求会把所需的对话与设定发送给你配置的模型服务商；本地保存不等于离线生成。

网页存档跟着浏览器和网站地址走。换域名、协议、端口、浏览器或设备，都可能看到一个全新的剧场。清理浏览器数据或卸载应用也可能清掉存档。搬家前先去设置里导出 JSON，再到新地方导入，别让主角连人带剧情一起走丢。

API Key 属于敏感信息，不要把设置截图或含密钥的导出内容发到公开 Issue。程序会在设备上保存你的配置，共用电脑时请留意这一点。

## 卡住了先看看

- **找不到 flutter 命令**。检查 SDK 是否安装、PATH 是否包含 Flutter 的 `bin`，重新打开终端再试。
- **网页能打开，AI 不回复**。检查 API 地址、Key、模型名称及服务商额度。网页端还需要服务商允许跨域请求。
- **换地址后像重开了游戏**。先回旧地址导出存档，再到新地址导入。剧情通常还在旧家。
- **安卓无法覆盖安装**。新旧包的签名可能不同。先在旧版导出存档，再处理重装，别先卸载。

提 Issue 时请附版本、设备、复现步骤和脱敏后的错误信息。角色的爱恨情仇可以省略，报错原文尽量留下。

## 转发和二改

允许非商业转载、修改和再发布，欢迎通过 [GitHub Issues](https://github.com/4433shijue/unfinished-theater/issues) 与作者友好交流。请保留项目来源和许可说明。**原版和二改版都禁止商用，改过也不能拿去卖钱或用于商业服务。** 具体条件见 [非商业使用许可](LICENSE.md)。

这是采用非商业许可的公开源码项目。第三方字体、图片和音乐另按各自授权处理，见 [素材说明](THIRD_PARTY_NOTICES.md)。
