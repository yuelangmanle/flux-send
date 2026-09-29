# Flux 开发与交接手册

Flux 是基于 [LocalSend](https://github.com/localsend/localsend) 的 Apache-2.0 派生项目，面向 Android、macOS 与 Windows 的本地文件传输和剪切板同步。

## 当前基线

| 项目 | 值 |
| --- | --- |
| 当前正式版本 | `1.1.54+113` |
| Android applicationId | `org.localsend.localsend_app` |
| Android 发布密钥 | 现有私有 JKS，**不在仓库中** |
| 上游基线 | LocalSend 1.17.0 |
| Flutter 版本 | `3.38.10`（见 `.fvmrc`） |

`applicationId`、发布密钥和签名证书必须保持不变，才能让 Android 用户覆盖安装后续版本。

## 1.1.54 蓝牙握手约定

经典蓝牙 RFCOMM socket 打开不等于 Flux 已连接。Android 与 macOS 都必须先发送 `flux.bluetooth.hello.v1`，收到 `flux.bluetooth.hello.ack.v1` 后才发出 `connected` 事件并允许文件或剪切板帧。

- 未完成握手时，发送文件或剪切板必须失败并显示“尚未完成 Flux 协议握手”；
- 收到非 Flux 数据时必须断开，不得显示为已连接；
- 连接替换、停止或断开时必须重置握手状态；
- Android 读循环只处理当前 socket，旧 socket 的晚到数据必须丢弃。

### 威胁模型说明

`hello/ack` 握手是**对端活性校验，不是身份认证**。RFCOMM 链路本身是明文，且握手帧不含凭据：任何已配对设备发送一条 `{"type":"flux.bluetooth.hello.v1"}` 即可通过验证。它的价值在于防止把普通蓝牙串口对端误报为“Flux 已连接”，而不是防止恶意对端。真正的传输安全边界仍是局域网通道的 HTTPS + PIN（或接收端的人工确认）；经典蓝牙通道仅建议在已配对的可信设备之间使用，不要将其视为加密通道。

## 本地准备

```bash
cd app
flutter pub get
flutter analyze
flutter test
```

需要 Flutter、Android SDK、Xcode（macOS 构建）和 Rust 工具链。网络依赖受限时，可按本机网络环境设置代理；不要把代理地址、Token 或密码写入 Git。

## Android 签名

发布机器必须安全保存以下两个本地文件，它们已被 `.gitignore` 排除：

```text
app/android/app/flux-release-key.jks
app/android/key.properties
```

密钥文件、别名和密码应保存在团队密码管理器及离线备份中；公开仓库、Issue、日志和 CI 输出中不得出现凭据。验证密钥时使用交互式命令，避免把密码写入 shell 历史：

```bash
keytool -list -v -keystore app/android/app/flux-release-key.jks
```

## 质量门禁

提交前至少执行：

```bash
cd app
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

新增逻辑先补单元测试；修复线上问题时，在 `docs/PROGRESS.md` 记录复现条件、修复范围、验证结果和未覆盖风险。

## 版本与发布

1. 任何包含用户可见改动的正式包都递增 `app/pubspec.yaml` 的版本号与 build number。
2. 更新 `app/assets/CHANGELOG.md`、`docs/PROGRESS.md` 和 `releases/README.md`。
3. 构建 Android APK 与 macOS DMG，并验证签名、启动与 SHA-256。
4. 本地归档保存到 `releases/history/v<版本>/`；该目录不进入 Git。
5. 在 GitHub 创建同名稳定版 Release，上传 APK、DMG 和 `SHA256SUMS.txt`。
6. 由安装包实际验证后再标记为正式发布；未做真机验证不得写成“已验证”。

完整发布检查表见 [RELEASE.md](RELEASE.md)。

## 应用内更新

设置页的“检查更新”只在用户主动点击时读取 GitHub Releases 的 latest API：

- 仅接受已发布的稳定版，不接受草稿或预发布版；
- Android 优先打开 `.apk`，macOS 优先打开 `.dmg`；
- 下载由系统浏览器处理，应用不会静默安装或申请额外权限；
- GitHub 不可达、发布格式不正确或无当前平台安装包时，会给出明确提示或打开发布页。

发布资产必须保持 `Flux-v<版本>-android.apk` 和 `Flux-v<版本>-macOS.dmg` 命名，确保更新入口能准确匹配。
