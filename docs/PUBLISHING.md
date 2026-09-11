# 发布到 GitHub

## 第一次准备

1. 在 GitHub 建立项目仓库，建议名称 `unfinished-theater`。先完成下面的内容检查，再公开源码。
2. 核对源码和历史提交的凭据扫描结果。不要上传私人存档、营销草稿、构建日志或签名密钥。`.gitignore` 只影响未跟踪文件，不能清除历史。
3. 补齐 `THIRD_PARTY_NOTICES.md` 中的素材来源与授权文件。源码使用条件见 `LICENSE.md`。
4. 在干净目录克隆待发布版本，执行 README 的启动和构建步骤，确认没有依赖作者电脑上的文件。
5. 在 GitHub 仓库的 Settings → Pages 中把 Source 设为 GitHub Actions。

## 发布网页

在 Actions 中选择 `Publish website`，点击 Run workflow，选择需要发布的分支。工作流会先分析和测试，再构建并部署网页；成功后部署记录会提供可访问地址。

工作流自动区分 `用户名.github.io` 根站点与普通项目站点。配置自定义域名时需同步调整 `pages.yml` 的基础路径。网页访问的模型接口需要允许对应站点的跨域请求。

## 安卓签名

从未公开发布过的应用可以创建一份新的发布密钥。已经安装旧版的用户，如果旧包使用不同签名，不能直接覆盖升级。先在旧版导出存档，再卸载旧包、安装新版、导入存档。请勿在未导出时直接卸载。

密钥只创建一次，并在安全位置备份。后续官方版本一直使用同一份密钥。

```bash
keytool -genkeypair -v -keystore android/release.jks -alias release -keyalg RSA -keysize 2048 -validity 10000
```

复制 `android/key.properties.example` 为 `android/key.properties`，在本地填写密码和别名。不要提交这两个文件。

GitHub 仓库 Settings → Secrets and variables → Actions 中设置以下四项 repository secrets。

| Secret 名称 | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 发布 keystore 的 Base64 编码 |
| `ANDROID_STORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_PASSWORD` | 私钥密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名，例如 release |

Windows 可将 Base64 直接复制到剪贴板，避免显示在终端日志中。

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path android/release.jks))) | Set-Clipboard
```

## 发布安装包

确认目标提交包含这次要发布的全部功能和匹配的 `pubspec.yaml` 版本。以下版本号仅为示例，应与实际源码保持一致。

```bash
git tag v2.10.5
git push origin v2.10.5
```

`Build release draft` 会检查版本、分析、测试并构建正式签名 APK 与 Web ZIP，生成 SHA256 校验文件，上传到一个草稿 Release。缺少签名 secrets 会明确失败，不会把调试签名包冒充官方包。

检查草稿中的版本、附件和说明后，点击 Publish release 对外发布。已经公开的 Release 不会被工作流覆盖。Web ZIP 需要静态 HTTP 服务，不能双击 HTML 启动。

## 日常更新

修改代码，更新版本，确认自动检查成功，再推送新标签。需要更新网页时手动运行网页发布工作流。发布到不同域名、协议或端口前提醒玩家导出存档。
