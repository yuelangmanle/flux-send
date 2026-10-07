# Flux

[![CI](https://github.com/yuelangmanle/flux-send/actions/workflows/ci.yml/badge.svg)](https://github.com/yuelangmanle/flux-send/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/yuelangmanle/flux-send?display_name=tag)](https://github.com/yuelangmanle/flux-send/releases/latest)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

**Flux** 是一个无服务器的本地传输工具，用于在 Android 与 macOS 设备之间传输文件、文本和剪切板内容。它基于局域网、热点直连或已配对的经典蓝牙工作；不需要账号，不需要云端中转服务器。

> Flux 是 [LocalSend](https://github.com/localsend/localsend) 的派生项目，保留 Apache License 2.0 与上游致谢，详见 [NOTICE](NOTICE)。

## 下载

请从 [GitHub Releases](https://github.com/yuelangmanle/flux-send/releases/latest) 获取最新稳定安装包：

| 平台 | 安装包 |
| --- | --- |
| Android | `Flux-v<版本>-android.apk` |
| macOS | `Flux-v<版本>-macOS.dmg` |

每个 Release 均附带 `SHA256SUMS.txt`。仅从本仓库的 Release 下载，并在安装前按需核验哈希。

## 核心能力

- 局域网发现与手动 IP 连接；支持一个设备开热点、另一个设备接入的直连场景。
- 已配对经典蓝牙（RFCOMM）作为无 Wi‑Fi 场景的传输通道，配合前台服务息屏保活。
- 文件、文件夹、文本与剪切板同步；**传输中断后重试可从断点续传**。
- 接收历史支持搜索与多选批量管理；进度页有实时速度曲线与“重试全部失败项”。
- 手动连接弹窗内置本机连接二维码与中文分类错误提示。
- 用户主动点击“设置 → 检查更新”后，从 GitHub Releases 获取最新稳定版；应用不会静默下载或安装。

## 使用提示

1. 局域网与热点模式需要双方允许本地网络通信，并处于同一网络。
2. 经典蓝牙模式需要先在系统蓝牙设置中完成配对；它不依赖 Wi‑Fi。
3. Android 文件接收建议在应用内选择保存目录。不要为了 Flux 额外授予“所有文件访问权限”。
4. 若发现不到设备，请确认路由器未启用 AP 隔离，并检查系统防火墙是否放行 Flux。

## 开发

```bash
git clone https://github.com/yuelangmanle/flux-send.git
cd flux-send/app
flutter pub get
flutter analyze
flutter test
```

完整环境、签名安全和发版规范见 [开发与交接手册](docs/DEVELOPMENT.md) 与 [发布检查表](docs/RELEASE.md)。

## 参与贡献

欢迎提交 Bug、功能建议和 Pull Request。请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)；安全问题请按 [SECURITY.md](SECURITY.md) 的私密流程报告。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
