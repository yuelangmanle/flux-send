# 贡献指南

感谢你关注 Flux。提交 Issue 或 Pull Request 前，请先阅读以下约定。

## 提交问题

- 先搜索现有 Issue，避免重复报告。
- Bug 请给出设备型号、系统版本、Flux 版本、连接模式、复现步骤和脱敏日志。
- 不要上传私钥、Token、完整局域网地址、个人文件或含个人信息的剪切板内容。
- 安全漏洞请遵循 [SECURITY.md](SECURITY.md)，不要公开披露。

## 本地开发

```bash
cd app
flutter pub get
dart format lib test
flutter analyze
flutter test
```

修改用户可见逻辑时，请同时补充或更新测试。涉及 Android/macOS 原生桥、发现、热点或蓝牙时，需在 PR 中说明实际验证设备与未覆盖的场景。

## Pull Request

1. 一个 PR 聚焦一个问题。
2. 说明动机、实现方式、测试命令和平台影响。
3. 不要提交构建产物、签名文件、本地配置或 Release 安装包。
4. 所有公开贡献默认按 Apache License 2.0 授权。

## 上游同步

Flux 基于 LocalSend。涉及上游协议或基础设施调整时，请在 PR 描述中标注上游提交、冲突处理和兼容性风险。
