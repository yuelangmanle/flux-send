# Flux 发布检查表

## 发布前

- [ ] `app/pubspec.yaml` 版本和 build number 已递增。
- [ ] 使用既有 Android `applicationId` 与私有发布密钥。
- [ ] 未将 `.jks`、`key.properties`、Token、密码或本机构建目录加入暂存区。
- [ ] `dart format --set-exit-if-changed lib test`、`flutter analyze`、`flutter test` 均通过。
- [ ] 更新 `app/assets/CHANGELOG.md` 与 `docs/PROGRESS.md`。

## 构建与验证

- [ ] 运行 `scripts/compile_android_apk.sh` 生成 APK。
- [ ] 运行 `scripts/compile_mac_dmg.sh` 生成 DMG。
- [ ] 使用 `apksigner verify --print-certs` 核验 APK 的包名、版本与签名证书。
- [ ] 使用 `hdiutil verify` 和 `codesign --verify --deep --strict` 核验 DMG。
- [ ] 计算并核验 `SHA256SUMS.txt`。
- [ ] 在至少一台 Android 真机和一台 macOS 设备上进行与本次改动相关的冒烟测试。

## 归档与 GitHub Release

```text
releases/history/v<版本>/Flux-v<版本>-android.apk
releases/history/v<版本>/Flux-v<版本>-macOS.dmg
releases/history/v<版本>/SHA256SUMS.txt
```

本地归档不进入 Git。创建 `v<版本>` 的 GitHub Release 后，上传上述三项，发布说明必须包含已验证的平台、未验证项和 SHA-256 文件。不要覆盖或删除已发布的安装包。
