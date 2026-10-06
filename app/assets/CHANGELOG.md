## Flux 2.0.1 (2026-10-07)

v2.0.0 发布当夜按既定 ROADMAP 完成的第一批循环优化（安全/体验/可测性）。详细记录见 `docs/PROGRESS.md`。

- feat(security): 发送流程先 `/api/register` 获取对端公钥并对 prepare-upload 做 TLS 证书 pinning（防中间人）；对端不支持或失败时优雅退化为不 pinning。
- feat(security): `/api/clipboard` 增加 1 MiB 请求体上限与每 IP 每分钟 30 次限流；接收端设置 PIN 后剪切板写入也需提供 PIN（`X-Pin` 头，兼容 query）。
- fix(security): PIN 错误尝试改 5 分钟滑动窗口（成功清零），PIN 优先从 `X-Pin` 头读取。
- fix(discovery): UDP 设备公告重试不再中途关闭 socket（第 2、3 轮重试曾被静默丢弃）；监听端循环排空积压数据报。
- fix(bluetooth): 接收文件流式写入临时文件并校验大小（消大文件 OOM）；进度文案 100ms 节流；断开事件新增结构化代码（`PEER_NOT_FLUX`/`HANDSHAKE_*`），Dart 优先按代码判断并保留文案 fallback；对非 Flux 设备连续 3 次握手失败后停止自动重连。
- fix(android): SAF 扫描移后台线程（消 ANR）；picker 结果按请求码隔离（消挂死）；未知扩展名兜底 octet-stream。
- fix(macos): pending 文件安全作用域统一释放（修泄漏）；目标目录书签过期自动重建。
- feat(ui): 进度页实时传输速度曲线；接收历史搜索 + 长按多选批量删除；扫描空态指引；状态卡呼吸动效；传输完成/失败/蓝牙发送触觉反馈；首次启动引导 + 设置页"使用说明"；手动连接失败中文分类提示。
- feat(i18n): 状态卡、设置页、接收历史等约 60 条展示文案迁入 slang（en + zh-CN）。
- refactor: 移除 WebRTC 信令链、in_app_purchase 捐赠、TV 遗留；settings_tab 拆分（1182 → 697+513 行）；主题色收敛（22 处 `Colors.grey` 清零）。
- ci: `flutter test` 启用随机顺序；Android 签名 secrets 缺失时立即失败并给配置指引。
- chore(release): 版本升至 `2.0.1+211`，保持 Android applicationId 与既有签名密钥不变。macOS 仍为 Apple Silicon 单架构（见 2.0.0 说明）。

## Flux 2.0.0 (2026-09-30)

大版本更新：安全、稳定性与传输性能的整体升级，配套架构清理。完整 2.0 路线图见 `docs/ROADMAP-2.0.md`。

> **macOS 安装包说明**：2.0.0 的 DMG 为 Apple Silicon (arm64) 单架构。Xcode 27 新链接器在双架构构建中对 Rust proc-macro dylib 会间歇性产出无法加载的产物（详见 `docs/PROGRESS.md` 的构建环境记录），Intel Mac 用户请暂用 1.1.55，恢复双架构后另行发版。

- feat(security): 剪切板同步通道现在校验对端 TLS 证书指纹（与设备指纹一致），阻断中间人截获；手动输入且未注册的对端仍可连接（TOFU）。
- feat(security): `/api/clipboard` 增加 1 MiB 请求体上限、每 IP 每分钟 30 次限流；接收端设置 PIN 后，剪切板写入也必须提供 PIN（`X-Pin` 头，兼容 query 方式）。
- feat(security): PIN 错误尝试改为 5 分钟滑动窗口（成功即清零、过期自动失效），不再永久锁死同 NAT 用户；PIN 优先从请求头读取，避免进入 URL 日志。
- fix(discovery): UDP 设备公告的重试不再中途关闭 socket（此前第 2、3 轮重试被静默丢弃，弱网下极难发现设备）；监听端改为循环排空积压数据报，减少突发丢包。
- fix(bluetooth): 接收文件改为流式写入临时 `.part` 文件并在完成后校验大小——大文件不再全量驻留内存（消除 OOM）；进度文案 100ms 节流，不再每 24KB 触发整页重建。
- fix(android): SAF 递归扫描移至后台线程并加 5000 条上限，选大目录不再 ANR；目录选择器按请求码独立保存结果，连续调用不再互相覆盖挂死；未知扩展名按通用二进制打开，不再崩溃。
- fix(macos): 拖放/打开文件的 security-scoped 访问在 Flutter 消费后统一释放（此前无限累积）；目标目录书签过期时自动重建。
- refactor: 移除上游遗留死代码——WebRTC 信令与接收链、in_app_purchase 捐赠流程、Android TV 输入包装，减少依赖与构建时间。
- ui: 扫描不到设备时给出原因提示并提供“去排查 / 手动输入 IP”一键入口；失败重试按钮补充本地化文字。
- docs: 新增 `docs/ROADMAP-2.0.md`（四维深读审查：架构 / 网络协议安全 / 原生层 / UI·UX）。
- chore(release): 版本升至 `2.0.0+200`，保持 Android applicationId 与既有签名密钥不变。

## Flux 1.1.55 (2026-09-29)

- fix(clipboard): 接收端不再接受远端对旧文本的失败重试，避免发送端重试覆盖本机刚复制的新内容；待同步文本超过 2 分钟未成功即放弃自动重试并明确提示。
- fix(clipboard): “暂停剪切板”现在会持久化（默认开启不受影响），重启后保持暂停状态，不再静默恢复同步。
- fix(bluetooth): Android `writeFrame` 加锁串行化，握手帧与数据帧并发写不再可能交错损坏；读循环在写出前再次校验 socket 身份，旧 socket 晚到数据不会冒充新连接。
- fix(bluetooth): 对非 Flux 配对设备连续 3 次握手失败后停止自动重连，提示“对方可能不是 Flux 或版本过旧”；手动重连或连接成功会重置计数。
- fix(macos): 非 Flux 数据只关闭携带该数据的通道，不再可能误关新连接。
- fix(settings): Android SAF 保存目录包含截断或非法 `%` 编码时安全回退显示原路径，设置页不再崩溃或空白（同时覆盖 `FormatException` 场景）。
- chore(brand): 应用元数据与关于页标明 Flux 身份并保留 LocalSend（Apache-2.0）上游致谢；删除会把发布资产误推到上游 LocalSend winget 包的 CI 工作流；Windows 安装器改用独立 AppId 与 Flux 命名。
- ci: Android 签名 secrets 缺失时构建立即失败并给出配置指引，不再延迟到 Gradle 签名阶段报错。
- docs: 开发手册补充经典蓝牙握手威胁模型（`hello/ack` 是对端活性校验而非认证，传输安全边界仍是 HTTPS + PIN）。
- test(clipboard/bluetooth): 覆盖重试不覆盖、pending 超时、暂停持久化、握手失败停止重连、写锁与通道定向关闭等回归场景。
- chore(release): 版本升至 `1.1.55+114`，保持 Android applicationId 与既有签名密钥不变。

## Flux 1.1.54 (2026-07-27)

- fix(bluetooth): Classic Bluetooth 仅在 Android 与 macOS 双方完成 Flux `hello/ack` 协议握手后才报告“已连接”；非 Flux 对端和未验证帧会明确断开，避免 socket 打开就形成假连接。
- fix(bluetooth): 将 Android 读循环绑定到当前 RFCOMM socket，替换或重连后的旧 socket 无法再写入剪切板、文件帧或连接状态。
- fix(macos): 使用 `JSONEncoder` 编码剪切板字符串，避免 `NSJSONSerialization` 对顶层字符串触发 Objective-C 异常导致闪退。
- fix(settings): Android SAF 保存目录包含非法 `%` 编码时安全回退显示原路径，设置页不再崩溃或空白。
- test(bluetooth): 覆盖握手门禁、旧 socket 隔离、macOS JSON 编码与非法 SAF URI 回归场景。
- chore(release): 版本升至 `1.1.54+113`，保持 Android applicationId 与既有签名密钥不变。

## Flux 1.1.53 (2026-07-27)

- feat(update): 在设置页新增“检查更新”，主动读取 Flux GitHub Releases 的稳定版信息，并按当前平台打开 APK、DMG 或发布页。
- test(update): 覆盖 GitHub Release 解析、稳定版校验、语义化版本比较和安装包平台匹配。
- docs(oss): 建立公开仓库主页、发布检查表、安全策略、贡献规范和 Issue 流程；发布凭据从文档中脱敏。

## Flux 1.1.52 (2026-07-26)

- fix(settings): isolate clipboard-sync provider reads to their own settings section, so a provider initialization failure no longer replaces the entire Android settings page with a blank error surface.
- fix(ui): register a global Chinese runtime error fallback before application initialization, replacing opaque Flutter error boxes with a visible recovery message and error summary.
- test(settings): add a regression test requiring the global runtime error fallback; verified red before implementation and green after implementation.
- chore(release): bump Android/macOS package version to 1.1.52+111 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts under `releases/history/v1.1.52/` with SHA-256 checksums.
- test(macos): verify the new release app starts visibly, persists local-network mode, opens a TCP listener, and produces no crash report during a 12-second smoke test.

## Flux 1.1.51 (2026-06-09)

- fix(android): keep the settings tab away from desktop-only window chrome and desktop startup checks, reducing Android settings white-screen risk.
- fix(ui): add a Chinese settings-page loading and error fallback with a real retry path instead of leaving a blank page when initialization fails.
- test(settings): add regression coverage for stale dropdown values, Android-safe settings app bar, error fallback, and inert Android desktop-state loading.
- chore(release): bump Android/macOS package version to 1.1.51+110 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.50 (2026-06-09)

- fix(bluetooth): add real Classic Bluetooth file transfer frames for begin/chunk/end over the RFCOMM resident link, so Bluetooth file sending no longer falls back to LAN/hotspot devices.
- fix(send): block manual IP, favorite-device, and LAN scan entry points while Classic Bluetooth mode is selected, preventing false “Bluetooth worked” results when Wi‑Fi is actually carrying the transfer.
- fix(clipboard): send clipboard HTTP payloads as `text/plain` and keep legacy JSON receive compatibility, avoiding Android writing `{"text":"..."}` into the system clipboard.
- fix(ui): make settings dropdowns resilient to stale persisted values and extend receive-history grouping by date/type for handoff visibility.
- test(bluetooth): add regression coverage for RFCOMM file frames, Bluetooth-only send behavior, clipboard payload format, receive history grouping, and settings resilience.
- chore(release): bump Android/macOS package version to 1.1.50+109 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts under `releases/history/v1.1.50/`.
- docs(release): record v1.1.50 signing, Android real-device install smoke, macOS launch smoke, SHA-256 checksums, and the new `releases/history/` archive policy.

## Flux 1.1.49 (2026-06-08)

- fix(connection): only persist Classic Bluetooth mode after the native RFCOMM listener confirms startup; if Bluetooth startup fails, Flux rolls back to the previous mode instead of leaving macOS trapped in a saved Bluetooth mode.
- fix(ui): show a failure snackbar when Classic Bluetooth activation fails, rather than saying the mode switched successfully.
- test(release): extend macOS smoke coverage to local network, hotspot, and Classic Bluetooth modes with visible-window, TCP listener, persisted-mode, and crash-log checks.
- chore(release): bump Android/macOS package version to 1.1.49+108 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.49.
- docs(release): record Android real-device install smoke, macOS three-mode smoke, signing, DMG, APK, and SHA-256 verification results.

## Flux 1.1.48 (2026-06-08)

- fix(ui): make the no-permission dialog scrollable so the longer Android file-picker and receive-folder recovery guidance remains readable on small phone screens.
- test(ui): extend no-permission dialog coverage to require scrollable long guidance.
- chore(release): bump Android/macOS package version to 1.1.48+107 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.48.
- docs(release): record v1.1.48 permission-dialog, signing, entitlement, launch-smoke, DMG, APK, and SHA-256 verification results.

## Flux 1.1.47 (2026-06-08)

- fix(android): replace the generic no-permission dialog with actionable guidance for Android file sending and receive-folder recovery, telling users to reselect via the system picker or choose the Download folder instead of hunting for unnecessary “All files access”.
- test(i18n): add regression coverage for Chinese and English no-permission guidance across source and generated localization files.
- chore(release): bump Android/macOS package version to 1.1.47+106 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.47.
- docs(release): record v1.1.47 permission-guidance, signing, launch-smoke, DMG, APK, and SHA-256 verification results.

## Flux 1.1.46 (2026-06-08)

- fix(macos): prevent Classic Bluetooth status initialization from auto-touching native Bluetooth hardware on app startup, so a saved Bluetooth mode cannot trap Flux in a crash-on-launch loop.
- fix(macos): guard every native IOBluetooth entry point with a runtime `NSBluetoothAlwaysUsageDescription` self-check and return an actionable Flux error instead of letting macOS TCC kill the process if a future package is misbuilt.
- test(bluetooth): add regression coverage for lazy Classic Bluetooth provider startup and macOS privacy-guard checks.
- chore(release): bump Android/macOS package version to 1.1.46+105 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.46.
- docs(release): record v1.1.46 TCC crash evidence, signing, entitlement, launch-smoke, DMG, APK, and SHA-256 verification results.

## Flux 1.1.45 (2026-06-08)

- fix(send): show an actionable Chinese message when a file upload fails with an empty HTTP error body, instead of displaying a blank status like `[500] `.
- test(send): add regression coverage for empty upload failure responses.
- chore(release): bump Android/macOS package version to 1.1.45+104 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.44 (2026-06-08)

- fix(clipboard): stop UDP multicast and TCP subnet clipboard discovery while Classic Bluetooth mode is selected, so Bluetooth mode uses the RFCOMM resident link instead of silently mixing in LAN/hotspot scanning.
- fix(build): repair release script version parsing so Android/macOS package scripts can derive `1.1.44` from `pubspec.yaml` without requiring manual `VERSION=...`.
- fix(build): replace obsolete LocalSend packaging scripts with Flux release archive scripts that preserve macOS Bluetooth entitlements.
- test(clipboard): add regression coverage for the clipboard discovery mode gate.
- test(build): add regression coverage for Android/macOS release packaging scripts, archive naming, and default pubspec version parsing.
- docs(build): document the entitlement-preserving macOS signing workflow for future handoff.
- chore(release): bump Android/macOS package version to 1.1.44+103 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.44.

## Flux 1.1.43 (2026-06-08)

- fix(macos): add the App Sandbox Bluetooth device entitlement to release and debug macOS bundles so Classic Bluetooth can access the Bluetooth stack after the privacy prompt is declared.
- fix(build): preserve macOS entitlements when re-signing the release app before DMG packaging.
- test(macos): add regression coverage that both macOS entitlements files include `com.apple.security.device.bluetooth`.
- chore(release): bump Android/macOS package version to 1.1.43+102 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.43.
- docs(release): record v1.1.43 signing, entitlement, launch-smoke, DMG-mount, and SHA-256 verification evidence.

## Flux 1.1.42 (2026-06-08)

- fix(android): reject stale Classic Bluetooth RFCOMM socket attach callbacks after stop, mode switch, or replacement connect so old client/server threads cannot re-own the active socket.
- fix(android): suppress stale Bluetooth connect errors after a newer generation starts, avoiding misleading failure messages after the user has already stopped or switched modes.
- test(bluetooth): add regression coverage for Android Classic Bluetooth generation guards around stop and replacement connects.
- chore(release): bump Android/macOS package version to 1.1.42+101 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.42.
- docs(release): record v1.1.42 signing, launch-smoke, DMG-mount, and SHA-256 verification evidence.

## Flux 1.1.41 (2026-06-08)

- fix(macos): reject stale Classic Bluetooth RFCOMM attach callbacks after stop, mode switch, or replacement connect so old background connections cannot re-own the active channel.
- fix(macos): close stale RFCOMM channels that complete after a newer generation has started, preventing ghost connected state after Bluetooth is stopped.
- test(bluetooth): add regression coverage for macOS Classic Bluetooth generation guards around stop and replacement connects.
- chore(release): bump Android/macOS package version to 1.1.41+100 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.41.

## Flux 1.1.40 (2026-06-08)

- fix(macos): serialize Classic Bluetooth RFCOMM attach, data, and close callbacks onto the main thread, reducing race risk when reconnecting or replacing channels.
- fix(macos): ignore stale RFCOMM data from a replaced channel so old callbacks cannot mutate the active receive buffer.
- test(bluetooth): add regression coverage for macOS RFCOMM callback main-thread serialization and stale channel guards.
- chore(release): bump Android/macOS package version to 1.1.40+99 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.40.

## Flux 1.1.39 (2026-06-08)

- fix(macos): add `NSBluetoothAlwaysUsageDescription` to the macOS app bundle so selecting Classic Bluetooth no longer triggers a TCC privacy crash.
- test(macos): add regression coverage that the macOS `Info.plist` declares the Bluetooth privacy usage text before any RFCOMM access.
- chore(release): bump Android/macOS package version to 1.1.39+98 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.39.

## Flux 1.1.38 (2026-06-08)

- fix(branding): generate new self-signed device certificates with `Flux User` as the subject CN instead of `LocalSend User`.
- fix(windows): rename the Windows autostart registry value and SendTo shortcut filename from `LocalSend` to `Flux`.
- test(flux): add regression coverage for certificate subject branding, Windows autostart branding, and Windows SendTo context-menu branding.
- chore(release): bump Android/macOS package version to 1.1.38+97 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.38.

## Flux 1.1.37 (2026-06-08)

- fix(ui): localize the copyable-text snackbar from English to Chinese so copied IPs / paths no longer show `Copied ... to clipboard!`.
- fix(branding): replace remaining user-facing `LocalSend: Error` startup-error branding with Flux and Chinese error labels.
- fix(ui): correct the language page title from the send-selection title to the actual language setting, and replace the locale-loading fallback with Chinese text.
- fix(windows): rename troubleshoot firewall-rule commands from `LocalSend` to `Flux`.
- test(flux): add regression coverage for copy feedback localization, Flux startup-error branding, troubleshoot firewall command naming, and language page localization.
- chore(release): bump Android/macOS package version to 1.1.37+96 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.37.

## Flux 1.1.36 (2026-06-08)

- fix(manual-connect): detect IPv6 manual addresses in the default hashtag mode so `[IPv6]:port` and bare IPv6 inputs are not mis-expanded as local shortcode suffixes.
- test(flux): add regression coverage for IPv6 manual address parsing and full-address detection.
- chore(release): bump Android/macOS package version to 1.1.36+95 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.36.

## Flux 1.1.35 (2026-06-08)

- fix(clipboard): build `/api/clipboard` send URLs with Dart `Uri` instead of string concatenation, keeping IPv4, hostnames, and IPv6 addresses valid.
- test(flux): add regression coverage for clipboard sync URI construction across IPv4, `.local` hostnames, and IPv6.
- chore(release): bump Android/macOS package version to 1.1.35+94 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.35.

## Flux 1.1.34 (2026-06-08)

- fix(clipboard): accept repeated incoming remote clipboard text when the local clipboard has diverged since the previous remote write, preventing valid remote resends from being silently ignored.
- test(flux): add regression coverage for incoming clipboard de-duplication that considers both the last remote text and the current local-side clipboard state.
- chore(release): bump Android/macOS package version to 1.1.34+93 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.34.

## Flux 1.1.33 (2026-06-08)

- fix(clipboard): clear stale remote-clipboard echo suppression as soon as the next local clipboard value differs from the last remote text, preventing later same-text local copies from being swallowed.
- fix(bluetooth): treat native Classic Bluetooth negative send results such as `经典蓝牙发送未确认` as real disconnects so stale connected state is cleared and bounded auto-reconnect starts immediately.
- test(flux): add regression coverage for clipboard echo-suppression cleanup and Classic Bluetooth negative-send disconnect handling.
- chore(release): bump Android/macOS package version to 1.1.33+92 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.33.

## Flux 1.1.32 (2026-06-08)

- fix(discovery): localize the remaining UDP discovery and incoming `/register` discovery logs to Chinese, removing English status-card fragments such as `[DISCOVER/UDP]` and `Received "/register" HTTP request`.
- test(flux): add regression coverage that UDP-discovered devices and incoming register requests produce Chinese user-facing discovery log lines.
- chore(release): bump Android/macOS package version to 1.1.32+91 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.32.

## Flux 1.1.31 (2026-06-08)

- fix(bluetooth): remember the last Classic Bluetooth peer and automatically reconnect after unexpected disconnects, socket-send disconnects, connection timeouts, or method-channel connection failures with bounded 2s/5s/10s/15s retry backoff.
- fix(discovery): make TCP discovery logs fully actionable in Chinese, including scan start, found-device, scan-complete, no-device, and scan-failed states so the status card no longer appears stuck after manual refreshes.
- test(flux): add regression coverage for Classic Bluetooth auto-reconnect gating/backoff/timeout queueing and TCP discovery completion/failure messages.
- chore(release): bump Android/macOS package version to 1.1.31+90 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.31.

## Flux 1.1.30 (2026-06-08)

- fix(android): close newly created Classic Bluetooth RFCOMM client sockets when outbound `connect()` fails, reducing half-open socket leaks and flaky reconnects after failed pairing/link attempts.
- test(flux): add regression coverage that Android outbound Bluetooth connection failures call `closeQuietly(nextSocket)` while successful attaches clear the temporary socket reference first.
- chore(release): bump Android/macOS package version to 1.1.30+89 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.30.

## Flux 1.1.29 (2026-06-08)

- fix(android): send Android Classic Bluetooth clipboard payloads in bounded 8KB RFCOMM chunks instead of one large socket write, matching the macOS stability fix for longer clipboard text.
- test(flux): add regression coverage that Android RFCOMM clipboard writes loop through bounded chunks and never fall back to one-shot `payload.toByteArray(...)` writes.
- chore(release): bump Android/macOS package version to 1.1.29+88 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.29.

## Flux 1.1.28 (2026-06-08)

- fix(bluetooth): send macOS Classic Bluetooth clipboard payloads in bounded RFCOMM chunks instead of one large `writeSync`, improving long clipboard reliability and removing the 64KB single-write ceiling.
- test(flux): add regression coverage that macOS RFCOMM writes loop through bounded chunks and no longer reject payloads solely because they exceed a single `UInt16` write length.
- chore(release): bump Android/macOS package version to 1.1.28+87 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.28.

## Flux 1.1.27 (2026-06-08)

- fix(manual-connect): treat pasted full IP / URL inputs as direct addresses even when the dialog is still in hashtag mode, preventing `10.x.x.x:port` from being mis-expanded as a local shortcode.
- fix(bluetooth): clear stale Classic Bluetooth connected state immediately when clipboard send failures indicate a broken socket, so the UI no longer keeps a fake “connected” link after send errors.
- fix(receive): drain failed upload request bodies before responding with the receiver save error, reducing stuck “receiving” states and blank sender-side errors after Android/macOS save failures.
- test(flux): add regressions for direct manual-address detection, Bluetooth send-failure state collapse, and receiver upload-failure draining.
- chore(release): bump Android/macOS package version to 1.1.27+86 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.27.

## Flux 1.1.26 (2026-06-08)

- fix(android): request `BLUETOOTH_ADVERTISE` at startup and verify it before starting the Android 12+ Classic Bluetooth RFCOMM server, so Bluetooth listening no longer silently fails on newer Android devices.
- fix(bluetooth): classify socket-closed, broken-pipe, connection-reset, connection-refused, not-connected, and macOS numeric send failures as real disconnects, preventing stale “connected” states after the link is already broken.
- test(flux): add regression coverage for runtime Bluetooth advertise permission requests, Android native listener permission checks, and Bluetooth socket-error disconnect classification.
- chore(release): bump Android/macOS package version to 1.1.26+85 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.26.

## Flux 1.1.25 (2026-06-08)

- fix(clipboard): wake pending clipboard delivery immediately when LAN / hotspot discovery registers or updates a reachable peer endpoint, instead of waiting for the next 5-second retry tick.
- fix(discovery): treat peer endpoint changes such as fallback-port updates as clipboard-relevant, while avoiding retry wakeups when a manual refresh merely clears the old device list.
- test(flux): add regression coverage for discovery-driven clipboard wakeups, endpoint updates, and refresh clearing behavior.
- chore(release): bump Android/macOS package version to 1.1.25+84 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.25.

## Flux 1.1.24 (2026-06-08)

- fix(clipboard): keep pending clipboard text when only some LAN / hotspot targets receive it, so temporarily unreachable devices retry on the next discovery tick instead of missing the copied content forever.
- fix(clipboard): avoid immediate tight retry loops for the same failed clipboard payload; same-text retries now wait for the normal discovery timer unless a newer clipboard value or device-registration wakeup arrives.
- fix(bluetooth): wake the clipboard sync service immediately when Classic Bluetooth reports a connected RFCOMM link, so pending clipboard text sends as soon as the link becomes real.
- test(flux): add regression coverage for partial clipboard delivery, retry gating, and Bluetooth connected-event wakeups.
- chore(release): bump Android/macOS package version to 1.1.24+83 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.24.

## Flux 1.1.23 (2026-06-08)

- fix(clipboard): keep per-device receiver error details when LAN / hotspot clipboard sync fails, so the UI shows which peer failed and why instead of only saying no device synced.
- fix(connection): route both the status card and settings page through the same real connection-mode switcher, ensuring LAN / hotspot switches trigger UDP + TCP discovery and Bluetooth switches start RFCOMM setup.
- fix(bluetooth): stop the native Classic Bluetooth RFCOMM listener when switching away from Bluetooth mode, reducing stale background sockets and confusing disconnected states.
- test(flux): add regression coverage for detailed clipboard failure summaries and shared connection-mode side effects.
- chore(release): bump Android/macOS package version to 1.1.23+82 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.23.

## Flux 1.1.22 (2026-06-08)

- fix(send): show the Android receive-folder guidance from prepare-upload failures directly, without prefixing it with noisy HTTP status text such as `[409]`.
- test(flux): add sender-side regression coverage for missing Android receive folder guidance.
- chore(release): bump Android/macOS package version to 1.1.22+81 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.
- build(release): publish verified Android APK and macOS DMG artifacts for v1.1.22.

## Flux 1.1.21 (2026-06-08)

- fix(android): reject non-gallery receive requests when no explicit SAF receive folder is selected, preventing files from being silently saved into an app-private directory that users cannot find.
- fix(receive): return an actionable Chinese error telling the receiver to choose Download/下载目录 before retrying.
- test(flux): add receive-destination policy coverage and verify the receive controller checks the policy before falling back to the default directory.
- chore(release): bump Android/macOS package version to 1.1.21+80 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.20 (2026-06-08)

- fix(android): make the receive-folder setting honest on Android; the unset state now asks the user to choose a Download folder instead of implying Flux already has public Downloads access.
- fix(android): show readable SAF folder names such as `Download/Flux` instead of raw `content://...` URIs after picking a receive directory.
- test(flux): add regression coverage for Android receive-destination display labels and keep SAF permission/error guidance tests green.
- chore(release): bump Android/macOS package version to 1.1.20+79 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.19 (2026-06-08)

- fix(clipboard): queue an immediate retry when a new device is registered while a clipboard send is already in progress, preventing the wakeup from being swallowed by the `_syncing` guard.
- fix(clipboard): show explicit feedback that the newly discovered device will be retried after the current sync finishes.
- test(flux): add regression coverage for device-registration wakeups that arrive during an active clipboard sync.
- chore(release): bump Android/macOS package version to 1.1.19+78 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.18 (2026-06-08)

- fix(clipboard): wake the always-on clipboard sync service immediately after a manual IP connection registers a reachable device, so pending clipboard text retries without waiting for the next timer tick.
- fix(clipboard): wake clipboard sync after favorite-device connection and after receiving a peer `/register` request, improving the bidirectional “phone connects desktop / desktop sees phone” path.
- test(flux): add regression coverage for manual IP, favorite-device, and incoming-register clipboard wakeups.
- chore(release): bump Android/macOS package version to 1.1.18+77 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.17 (2026-06-08)

- fix(discovery): filter self devices by local IP as well as fingerprint, preventing desktop scans and clipboard target lists from showing/syncing to the current device after certificate changes or loopback discovery.
- fix(discovery): add visible TCP/favorite scan-start logs so refresh actions leave immediate feedback even before any peer is found.
- fix(receive): translate common Android/SAF save permission failures into actionable Chinese guidance for both receiver and sender error screens.
- test(flux): add regression coverage for local-IP self filtering, scan feedback logs, and receiver permission error translation.
- chore(release): bump Android/macOS package version to 1.1.17+76 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.16 (2026-06-08)

- fix(clipboard): reject duplicate incoming clipboard payloads while local sync is paused, instead of letting the duplicate shortcut return a false success.
- test(flux): add regression coverage for paused duplicate incoming clipboard writes so sender retry state is not cleared incorrectly.
- chore(release): bump Android/macOS package version to 1.1.16+75 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.15 (2026-06-08)

- fix(clipboard): reject incoming clipboard writes when local clipboard sync is paused instead of returning false success to the sender.
- fix(clipboard): include the receiver-side clipboard error message in non-success HTTP responses, so senders can show and retry paused/failed receiver states.
- fix(bluetooth): wait for the clipboard write result before showing Classic Bluetooth incoming clipboard success; paused or failed writes now show a rejected state.
- test(flux): add regression coverage for paused incoming clipboard rejection, receiver error propagation, and Bluetooth incoming clipboard status accuracy.
- chore(release): bump Android/macOS package version to 1.1.15+74 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.14 (2026-06-08)

- fix(clipboard): stop retrying pending clipboard text after clipboard sync is paused, including sends finishing after the pause action.
- fix(android): close any active Classic Bluetooth RFCOMM socket before starting a new outbound connection to reduce stale-link reconnect failures.
- fix(macos): run outbound Classic Bluetooth RFCOMM connection attempts off the Flutter method channel thread so the desktop UI does not wait on synchronous Bluetooth calls.
- fix(macos): ignore stale RFCOMM close callbacks and replace the active channel before closing the previous one, preventing old disconnect events from clearing a fresh connection.
- test(flux): add regression coverage for paused clipboard retries and Classic Bluetooth reconnect race conditions.
- chore(release): bump Android/macOS package version to 1.1.14+73 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.13 (2026-06-08)

- fix(bluetooth): prevent late native disconnect events from restarting the Classic Bluetooth listener after the user stops Bluetooth or the provider is disposed.
- fix(manual-connect): accept Chinese colon and accidental spaces in manually entered `IP:port` addresses, avoiding malformed hostnames during direct connection.
- fix(receive): return receiver-side save failure details to the sender instead of a generic empty/unclear upload error.
- security(webrtc): remove debug logging of generated WebRTC private keys.
- test(flux): add regression coverage for Bluetooth manual stop, private-key log prevention, manual-address normalization, and receive-save failure messages.
- chore(release): bump Android/macOS package version to 1.1.13+72 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.12 (2026-06-08)

- fix(macos): treat RFCOMM notification registration failure as a real Classic Bluetooth listener startup failure, removing the temporary SPP service and returning false instead of showing a false listening state.
- docs(flux): clean the remaining historical Bluetooth wording that still suggested the RFCOMM data path was only in development, while preserving the release-history context.
- test(flux): extend Classic Bluetooth bridge regression coverage to require macOS notification startup acknowledgement before reporting listener success.
- chore(release): bump Android/macOS package version to 1.1.12+71 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.11 (2026-06-08)

- fix(bluetooth): make Classic Bluetooth server startup return a real native `bool`, so the UI no longer says it is listening when Android permissions, adapter state, or RFCOMM socket creation failed.
- fix(macos): stop reporting RFCOMM listening when SPP service publication fails, keeping Bluetooth mode feedback honest instead of looking ready while no service exists.
- fix(android): mark the RFCOMM server as running immediately after socket creation to avoid duplicate listener startup during rapid refreshes.
- fix(server): return HTTP 405 for unsupported methods instead of letting unknown method probes throw through the request handler.
- docs(flux): remove stale handoff text that still claimed the RFCOMM data channel was unfinished, and record this repair loop in the progress log.
- test(flux): add regression coverage for Bluetooth listener startup truthfulness, listener-error state cleanup, and unsupported HTTP method handling.
- chore(release): bump Android/macOS package version to 1.1.11+70 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.10 (2026-06-08)

- fix(bluetooth): keep Classic Bluetooth connection attempts in a real pending state until the native `connected`, `error`, `disconnected`, or timeout result arrives.
- fix(bluetooth): add an 18-second connection timeout that stays active even while native RFCOMM connect calls are still waiting, so the UI no longer looks stuck.
- fix(bluetooth): preserve existing link state when a send ACK fails; send errors now report retryable clipboard failure instead of pretending the Bluetooth link disconnected.
- fix(bluetooth): include remote device address/name/role in Android and macOS `connected` events so the receiving side can mark the actual paired device as connected.
- test(flux): add regression coverage for connection timeout state, native terminal-event races, send-error link preservation, and connected-device identity feedback.
- docs(flux): record this handoff in the development/progress docs and bump release metadata to 1.1.10+69 without changing `applicationId` or the existing `flux-release-key.jks` signing key.

## Flux 1.1.9 (2026-06-08)

- fix(bluetooth): make Android and macOS Classic Bluetooth clipboard sends return a real native ACK, so Flux no longer marks clipboard sync successful when the RFCOMM write failed.
- fix(bluetooth): make the Dart clipboard sync provider respect the native ACK and keep pending clipboard text for automatic retry when Bluetooth send is not confirmed.
- fix(macos): buffer RFCOMM chunks by newline and parse complete JSON frames, preventing partial or coalesced Bluetooth packets from breaking incoming clipboard sync.
- fix(macos): reject oversized single-frame Bluetooth clipboard payloads with a clear error instead of silently failing the `UInt16` RFCOMM write length.
- fix(android): report clean Bluetooth disconnects once and clear the active socket consistently after the read loop ends.
- test(flux): expand Bluetooth regression coverage and rerun full `flutter test` plus `flutter analyze`.
- chore(release): bump Android/macOS package version to 1.1.9+68 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.8 (2026-06-07)

- feat(bluetooth): wire Classic Bluetooth into a real RFCOMM always-on clipboard path on Android and macOS, with paired-device listing, connect actions, server listening state, and Chinese status feedback.
- fix(macos): update the IOBluetooth bridge for the current macOS SDK by publishing an SPP service, resolving the RFCOMM channel via SDP, and using the renamed Swift APIs so release builds compile cleanly.
- fix(flux): mark async Bluetooth lifecycle cleanup explicitly, preventing analyzer warnings and making event-stream shutdown/restart behavior easier to audit.
- docs(flux): record the release handoff, verification commands, known Bluetooth pairing requirement, and Android signing key details for future maintainers.
- test(flux): verify connection mode, clipboard routing, classic Bluetooth bridge coverage, `flutter analyze`, Android release build, and macOS release build.
- chore(release): bump Android/macOS package version to 1.1.8+67 while keeping `applicationId` and the existing `flux-release-key.jks` signing key unchanged.

## Flux 1.1.7 (2026-06-07)

- fix(flux): keep the newest reachable IP/port when the same device fingerprint is rediscovered, preventing clipboard sync and file sends from targeting stale addresses after Wi‑Fi/hotspot changes.
- fix(macos): probe the bounded fallback port range when a second Flux instance starts, so an existing app that moved away from the default port is shown instead of launching a competing instance.
- fix(flux): store the receiver's remote session id separately from the local send-session key, preventing v2 file uploads from losing the real remote session after prepare-upload.
- test(flux): add regression coverage for stale-device merge behavior, desktop single-instance fallback probing, and send-session remote id handling.
- chore(release): bump Android/macOS package version to 1.1.7+66 while keeping the existing release signing key.

## Flux 1.1.6 (2026-06-07)

- fix(flux): restart the UDP multicast listener when the server has to move to a fallback port, so discovery no longer advertises/listens on a stale port after `Address already in use`.
- fix(flux): filter loopback and VPN-like local addresses from automatic discovery candidates while preserving hotspot gateway addresses such as `172.20.10.1`.
- fix(android): declare and request LAN/hotspot discovery permissions, nearby Wi‑Fi permission, and classic Bluetooth runtime permissions before discovery starts.
- test(flux): add regression coverage for multicast listener restart, Android LAN/Bluetooth permissions, and network-interface candidate filtering.
- chore(release): bump Android/macOS package version to 1.1.6+65 while keeping the existing release signing key.

## Flux 1.1.5 (2026-06-07)

- fix(flux): auto-recover when the preferred HTTP port is already in use by trying bounded fallback ports instead of leaving the server offline.
- fix(flux): install receive/register routes with the actual bound port, so discovery, file receive, and clipboard sync advertise the reachable endpoint.
- fix(flux): scan the default port plus nearby fallback ports, improving discovery when either side had to move away from the default port.
- fix(flux): return a real `/api/clipboard` failure when the receiver cannot write the system clipboard, and keep retry eligibility for failed incoming clipboard writes.
- test(flux): add regression coverage for port fallback, multi-port discovery, clipboard false-success prevention, and incoming clipboard retry ordering.
- chore(release): bump Android/macOS package version to 1.1.5+64 while keeping the existing release signing key.

## Flux 1.1.4 (2026-06-07)

- fix(flux): wait for incoming clipboard writes before returning `/api/clipboard`, so senders no longer get false success while the receiver failed to update the system clipboard.
- fix(flux): clear TCP/favorite scanning indicators even when the discovery isolate errors, preventing the UI from getting stuck in a permanent scanning state.
- test(flux): add regression coverage for discovery-scan failure cleanup and keep the clipboard/manual-connect/device-discovery checks green.
- chore(release): bump Android/macOS package version to 1.1.4+63 while keeping the existing release signing key.

## Flux 1.1.3 (2026-06-07)

- feat(flux): add a shared connection status card on Send and Receive tabs with LAN, hotspot, Bluetooth, server, IP, scan, and clipboard status.
- fix(android): acquire a multicast lock on startup so UDP discovery is not silently blocked on Wi-Fi.
- fix(flux): register manually entered IP devices into the nearby-device pool so clipboard sync has a real target after manual connect.
- fix(android): persist SAF directory write permission for receive destinations.
- chore(release): bump Android/macOS package version to 1.1.3+62 while keeping the existing release signing key.

## Flux 1.1.2 (2026-06-06)

- feat(flux): add a visible connection mode section with Local Network, Hotspot Direct, and Classic Bluetooth choices.
- feat(flux): show honest end-to-end status for each mode, including UDP multicast / HTTP-TCP behavior for LAN and hotspot direct.
- feat(flux): add Classic Bluetooth UI with pairing guidance and explicit RFCOMM in-progress status instead of hiding Bluetooth or pretending it is already connected.
- test(flux): add connection mode status coverage so Bluetooth UI and pairing guidance cannot disappear again.

## Flux 1.1.1 (2026-06-06)

- fix(macos): launch Flux as a normal foreground app so double-clicking the app visibly opens the main window instead of behaving like a menu-bar-only background app.
- chore(release): bump Android/macOS package version to 1.1.1+60 for the rebuilt installers.

## Flux 1.1.0 (2026-06-06)

- feat(flux): add always-on clipboard sync with background discovery, retry, Chinese status feedback, and self-device filtering.
- fix(flux): disable the default public LocalSend WebRTC signaling/STUN servers to stop unrelated reconnect loops.
- fix(flux): support manual addresses with `host:port` or pasted URLs instead of treating `10.x.x.x:25565` as a hostname.
- fix(flux): trust local self-signed HTTPS certificates for clipboard sync requests and report non-2xx responses as failures.
- chore(flux): rename visible app labels, tray/app titles, Android label, and macOS menus to Flux while keeping the Android `applicationId` unchanged for update compatibility.

- feat(windows): add LocalSend to Windows Share Sheet (@chenxdust, https://github.com/localsend/localsend/pull/2555)
- feat: enable starting text share via command line using `--text` or `-t` flags (@guilhermetiscoski, https://github.com/localsend/localsend/pull/2661)
- feat(android): add quick settings tile for instant app launch (@Voltra, https://github.com/localsend/localsend/pull/2676)
- feat(android, ios, macos): respect system-wide animation preferences on first app startup (@nitheesh-daram, https://github.com/localsend/localsend/pull/2338)
- feat: improve remaining time formatting for long transfers (@ShlomoCode, https://github.com/localsend/localsend/pull/2765)
- feat: change duplicate file naming from "file-1.txt" to "file (1).txt" format (@kartoshka95, https://github.com/localsend/localsend/pull/2455)
- feat(macos): implement button to quickly open firewall settings from troubleshoot page (@ShlomoCode, https://github.com/localsend/localsend/pull/2775)
- feat(macos): add Command+Comma shortcut to open settings (@ShlomoCode, https://github.com/localsend/localsend/pull/2715)
- feat(macos): use user-friendly ComputerName instead of the technical hostname (@ShlomoCode, https://github.com/localsend/localsend/pull/2729)
- feat(linux): use native window decorations instead of large GTK3 headerbar (@nixigaj, https://github.com/localsend/localsend/pull/2360)
- fix(macos): prevent Dock icon from briefly appearing during autostart when "Start hidden" is enabled (@ShlomoCode, https://github.com/localsend/localsend/pull/2449)
- feat(macos): enable Dock icon text-drop even when the app is not running (@ShlomoCode, https://github.com/localsend/localsend/pull/2712)
- feat(macos): borderless window design (@ReallLucky, https://github.com/localsend/localsend/pull/2416)
- feat(macos): enable Hardened Runtime for the Mac App Store version as well to improve security (@ShlomoCode, https://github.com/localsend/localsend/pull/2716)
- fix(macos): Dock icon drag-and-drop and Share Extension working again (@ShlomoCode, https://github.com/localsend/localsend/pull/2711)
- fix(android): files not downloading when using "Share via link" (@ShlomoCode, https://github.com/localsend/localsend/pull/2756)
- fix(ios, android): prevent transfer error by saving unsupported media formats to folder instead of gallery (@ShlomoCode, https://github.com/localsend/localsend/pull/2766)
- fix: release wake lock after file transfer completes to allow device sleep (@kartoshka95, https://github.com/localsend/localsend/pull/2457)
- fix(android): preserve location metadata when sharing media (@ShlomoCode, https://github.com/localsend/localsend/pull/2742)
- fix: text message content displayed three times in history dialog (@ew-sirenko, https://github.com/localsend/localsend/pull/2296)
- fix: text message content size calculation (@ew-sirenko, https://github.com/localsend/localsend/pull/2297)
- fix(linux): add CJK font support for Chinese, Japanese, and Korean text (@Mr-Ebonycat, https://github.com/localsend/localsend/pull/2719)
- fix: save DNG files to image gallery (@ShlomoCode, https://github.com/localsend/localsend/pull/2728)

## 1.17.0 (2025-02-19)

- feat: add advanced setting to filter network interfaces (@Tienisto)
- feat(mobile): swipe gesture to select multiple media files (@Tienisto)
- feat(windows): when pasting an image, automatically convert it to PNG (@BrianMwit)
- feat(android): add option to open gallery when image/video was automatically saved (@Tienisto)
- fix: path traversal vulnerability when saving files (@Tienisto)
- fix: black screen when tapping on "Back" twice in "Share via link" (@Tienisto)
- fix(macos): window disappears on command key when minimize to tray is enabled (@Tienisto)
- fix(windows): do not poll local IP resulting in unwanted location permissions (@Tienisto)

## 1.16.2 (2024-11-06)

- fix(ios): share from other apps to LocalSend doesn't work in iOS 18 (@Tienisto)

## 1.16.1 (2024-11-05)

- feat: show exact error message when using IP address dialog or favorite dialog (@Tienisto)
- feat(desktop): highlight file when tapping "Show in folder" (@Tienisto)
- fix(android): properly close app on back gesture (@Tienisto)

## 1.16.0 (2024-11-03)

- feat: improve transfer speed if the sending device is the bottleneck by using Rust as HTTP client and multithreading (@Tienisto)
- feat: add option to automatically receive files only from favorites (@Davte)
- feat: only automatically finish when files are either successfully received or skipped (@Tienisto)
- feat: improve various padding and spacing issues in RTL languages (@ShlomoCode)
- feat: persist "advanced settings" toggle (@Nolle10)
- feat: add alias-regeneration button and alias update dialog (@Nolle10)
- feat(macos): drag-and-drop files and text into menu bar icon (@ShlomoCode)
- feat(macos): drag-and-drop text into the app icon (@ShlomoCode)
- feat(macos): include LocalSend as a share target in the share menu (@ShlomoCode)
- feat(macos): starts hidden in menu bar instead of being minimized when autostart is enabled (@ShlomoCode)
- feat(macos): show error and success state in the app icon (@ShlomoCode, @Tienisto)
- feat(macos): also have autostart option in sandboxed version (App Store) (@ShlomoCode)
- feat(macos): LocalSend installed via dmg installer is sandboxed (@Tienisto)
- feat(android): enable clipboard button (@Seidko)
- feat(ios): enable clipboard button (@AnessZurba)
- fix(macos): reopen app from launchpad after minimizing to menu bar should make window visible (@ShlomoCode)
- fix(macos): persist write access to download location after app restart (@ShlomoCode)
- i18n: add Malaysian (@Gloridust), Slovak (@dodog)

## 1.15.4 (2024-08-20)

- feat: add button to retry a failed file transfer (@Tienisto)
- feat: show tooltip on the "Scan" button (@Tienisto)
- feat: treat any URI as link, so it becomes clickable on receiver (e.g. file://, obsidian://) (@Tienisto)
- feat(mobile): adjust button width in send tab to indicate that it's scrollable (@Tienisto)
- feat(windows): title bar color should match the system theme (@FutoTan)
- fix: memory leak when sending files (regression in 1.15.0, 1.15.2 only fixed receiving files) (@Tienisto)
- fix(windows): LocalSend window is invisible at app start (@Tienisto)
- i18n: distinguish between "Exit" and "Quit" depending on the platform (@sergd88)
- i18n: add Hindi (@rishi-singh26)

## 1.15.3 (2024-07-29)

- feat: reduce receive history length to 30 items to increase performance (@Tienisto)
- feat: show error message when initialization fails for better debugging (@Tienisto)
- fix(android): properly close app on back gesture (@Tienisto)

## 1.15.2 (2024-07-25)

- feat: extract network scanning to separate threads, scanning should not cause UI lags anymore (@Tienisto)
- feat(windows): use bigger icon for the installer (@Tienisto)
- fix: memory leak when receiving files, properly receive files that exceed available RAM (@Tienisto)
- fix(android): save files outside of Download folder (@Tienisto)
- fix(windows): use correct portable settings file when started via autostart (@Tienisto)
- fix(windows): make installer work on arm64 (@Tienisto)

## 1.15.1 (2024-07-18)

- feat: support Internet Explorer 8 (IE8) in web share (@Tienisto)
- feat: save auto accept state when switching encryption mode in web share (@Tienisto)
- feat: switch to "Send" tab when pasting via keyboard shortcut (@Tienisto)
- fix: count PIN tries correctly in web share (@Tienisto)
- fix(android): crash when picking files or folders on Android TV (@Tienisto)
- fix(windows): crash when sum of file sizes is greater than 2 GB (@Tienisto)
- fix(windows): bundle required DLL files to avoid crash on app start (@Tienisto)
- fix(macos): hide autostart option when installed via App Store because this switch is not working (@Tienisto)

## 1.15.0 (2024-07-15)

- feat: add clear button in the send tab (@Caesarovich)
- feat: save text messages to history (@Tienisto)
- feat: keep timestamps of transferred files (@Tienisto)
- feat: add option to require PIN when sharing via link (@Tienisto)
- feat: add option to require PIN when receiving files (@Tienisto)
- feat: add option to open parent folder of received files in history (@Tienisto)
- feat: confirm before adding or removing favorites in the nearby devices list (@Tienisto)
- feat: add URL view when sharing via link that shows the URL in bigger font (@harriseldon)
- feat: add discovery timeout setting for advanced users (@o2e)
- feat(android): do not require MANAGE_EXTERNAL_STORAGE, implement Android SAF (@Tienisto)
- feat(android): do not copy files to cache when select via file picker (@Tienisto)
- feat(windows): add context menu integration ("Send to") (@Tienisto)
- feat(windows): toggle "start hidden" in-app instead of referring to the system settings (@Tienisto)
- feat(desktop): make auto start + start hidden more stable, now listens to `--hidden` parameter instead of `autostart` (@Tienisto)
- feat(desktop): load initial files from command line arguments (@Tienisto)
- feat(desktop): show progress in the taskbar (@NightFeather0615)
- feat(macos): handle files that were dropped into the app icon (@Tienisto)
- fix: sanitize file names with invalid characters (@Caesarovich)
- fix: UI overflow when window height is too small (@CHUNG-HAO)
- fix(ios): make documents files visible to the Finder / AppleDevices app (@twinkles-twinstar)
- fix(windows): correctly remove tray icon when closing the app (@zpp0196)
- fix(windows): don't keep file open (@NightFeather0615)
- fix(linux): compatibility with newer libayatana versions (@ix5)
- i18n: add Serbian (@nebojsatomic), Finnish (@jooapa), Romanian (@UnifeGi)

## 1.14.0 (2024-02-26)

- feat: add option to automatically accept requests when sharing via link (@MisterChangRay, @Tienisto)
- feat: use fix button width for all buttons in the selection row (only noticeable in Russian) (@Tienisto)
- fix: picking many files should not freeze the UI (@Tienisto)
- fix: do not create a new session for the same IP when sharing via link (@MisterChangRay)
- fix(android): save files to SD card on Android 10 or older (@Tienisto)
- i18n: add Danish (@Limfjorden)

## 1.13.1 (2023-12-08)

- feat: add a short delay when "Auto Finish" is enabled (@Tienisto)
- feat: automatically update the device name of favorite devices when they were unchanged by the user (@Tienisto)
- feat: expand file picker buttons if the button text is too long (@Tienisto)
- fix: various crash issues by downgrading Flutter from 3.16 to 3.13 (@Tienisto)

## 1.13.0 (2023-12-04)

- feat: add option to automatically finish after successful transfer (@Tienisto)
- feat: show favorite name in the device list if marked as favorite (@Tienisto)
- feat: ignore duplicate files when selected from file picker (@programmermager)
- feat: add donation options (@Tienisto)
- feat: add Yaru theme (@Tienisto)
- feat(desktop): uses `settings.json` located next to the executable if available for portable mode (@Tienisto)
- feat(windows): make windows icon sharper (@Tienisto, @sergd88)
- feat(macos): add Command+W shortcut to close the window (@Q1CHENL)
- fix: also show an OLED color mode option when dynamic colors are not supported by OS (@dhruvanbhalara)
- fix: sync button should spin right away when clicked (@Tienisto)
- fix(android): request permission when saving files outside of downloads folder (@Tienisto)
- fix(ios): fix permission error when picking directory (@Tienisto)
- fix(ios): clear cache when file is shared from another app (@Tienisto)
- i18n: add Greek (@multipetros), Khmer (@nidexingg)

## 1.12.0 (2023-10-25)

- feat: add favorites (@Tienisto)
- feat: add OLED color mode (@Tienisto)
- feat: show dialog before clearing history (@pantshaswat, @Tienisto)
- feat: show clear button in apk picker search bar (@Tienisto)
- feat: use better colors for the toggle switches in the settings (@gitstart)
- feat: drastically improve GPU usage by optimizing the spin animation (@Tienisto)
- feat(desktop): support pasting from clipboard (@gitstart, @Tienisto)
- feat(linux): allow disabling client side decorations on Wayland (@I-Want-ToBelieve)
- feat(android): use high framerate on devices that lock at 60 Hz like on some OnePlus phones (@Tienisto)
- fix(desktop): fallback to "$HOME/Downloads" when default downloads folder is unavailable (@Sqbika)
- i18n: add Vietnamese (@faea726), Thai (@watchakorn-18k), Basque (@xezpeleta)

## 1.11.1 (2023-09-04)

- feat: hide color setting when dynamic colors are not supported (@Tienisto)
- feat(linux): use white icon for the linux tray (@GaryElshaw, @Tienisto)
- fix: possible race condition leading to zero total files (@Tienisto)
- fix(android): navigation bar color on Android 9 and earlier (@Tienisto)
- fix(android): add `requestLegacyExternalStorage` again (that was removed in 1.11.0) (@Tienisto)
- fix(linux): do not use zenity dependency anymore for file picker (@Tienisto)

## 1.11.0 (2023-08-28)

- feat: optionally enable HTTPS (encryption) when share via link (@Tienisto)
- feat: use switches instead of dropdowns for settings (@forecaster-cyber)
- feat: tapping on scan button clears found devices (@Tienisto)
- feat: text message dialog is multiline only (@Tienisto)
- feat: add option to disable animations (@Tienisto)
- feat: add option to not save to history (@Tienisto)
- feat: add option to customize device model (@Tienisto)
- feat(desktop): bind "ESC" key to go to the previous page (@RiverTwilight, @Tienisto)
- feat(android, ios): open link in new browser tab (@Tienisto)
- feat(linux): enable autostart feature (@TheGB0077)
- fix(android, ios): Save GIFs and image metadata (@natsuk4ze)
- fix(android, ios): handle decline permission when picking files (@Tienisto)
- fix(desktop): GPU usage when hidden to tray (@Tienisto)

## 1.10.0 (2023-06-02)

- feat: dynamic colors (Material You) (@Tienisto)
- feat(android): sharing APKs includes version in file name (@Tienisto)
- feat(windows): restore Windows 7 support (@Tienisto)
- feat(windows): use specialized fonts for Chinese, Japanese and Korean (@graphemecluster, @Tienisto)
- fix: cancellation fixes during active file transfer (@SelaseKay)
- fix(windows): possible settings corruption (@TheGB0077, @Tienisto)
- fix(android): get downloads directory correctly (@Tienisto)
- fix(ios): could not save HEIC files (@Tienisto)

## 1.9.1 (2023-05-05)

- feat: add folder should include the folder itself
- fix: handle file names with special characters in link share mode
- fix(android): fix status bar icon color after picking a media file
- fix(linux): add libayatana-appindicator3-1 to AppImage dependencies (by @TheGB0077)

## 1.9.0 (2023-04-23)

- feat: directory share
- feat: share via browser link (for non-LocalSend users)
- feat: add "delete from history" button when file could not be opened (by @TheGB0077)
- feat: close message request when copied / opened link
- feat: slightly improve transfer speed
- feat: implement LocalSend protocol v2 with v1 fallback
- feat: scan (sync) button automatically scans all network interfaces when count < 3
- feat(android, ios): add "Save to gallery" setting button in file receive options
- feat(desktop): move troubleshoot out of navigation into send page
- feat(desktop): save last window position (by @TheGB0077)
- feat(android): enable edge-to-edge mode
- feat(android): add monochrome app icons for Android 13 (by @h9419)
- feat(android): set custom download path
- feat(linux): enable system tray (by @TheGB0077)
- fix: in multi-recipient mode, retrying causes a "canceled by sender" on the recipient device
- fix: clear selection after finished message transfer
- fix(ios): could not scan local network on iOS 14+ (by @TheGB0077)
- fix(android, ios): fallback asset picker strings to English translation (by @TheGB0077)
- fix(linux): header bar glitches
- i18n: add fa

## 1.8.0 (2023-03-05)

- feat: add send modes (single recipient, multiple recipients)
- feat: selection gets cleared after finish by default (part of send modes feature)
- feat: share to multiple recipients in parallel
- feat: add troubleshoot page
- feat: add 2 buttons to receive history: open folder + delete history
- feat: cleanup scan UI by hiding multiple network interfaces inside the scan button
- feat: edit text message in selected files
- feat: improve device discovery by answering with TCP instead of UDP
- feat(ex. iOS): pressing destination directory in progress page will open the directory
- feat(android): share apk and install apk
- feat(android): Android TV support
- feat(android): show loading indicator when picking (large) files
- feat(windows): left click on tray icon opens app
- feat(linux): add Control+Q shortcut to exit app
- fix: handshake error in unencrypted mode
- fix: also scan multicast when pressing on a subnet sync button
- fix(android): missing app icon on Android 7
- fix(android,ios): show error message when saving to gallery failed
- i18n: add bn, nl, uk

## 1.7.0 (2023-02-11)

- feat: improve device discovery by enabling multicast
- feat: received files history
- feat: show recent IP addresses in manual IP input
- feat: separate language settings page
- feat: message input is horizontally scrollable when multiline is unselected
- feat: open message normally in QuickSave mode (instead of saving it into a file)
- feat: improve error handling and add possibility to show exact error message for debugging
- feat: add unencrypted HTTP mode (for debugging)
- feat(android): keep file name when saving to photos
- feat(desktop): use bigger default window size if display is big enough
- feat(windows): use "Microsoft YaHei UI" font in Windows which works better with Chinese characters
- fix: cache cleanup on iOS
- i18n: add ar, es-ES, fr-FR, hu, in, it, iw, ja, ko, ne, pl, pt-BR, ru, sv, tr, zh-Hant-HK, zh-Hant-TW (Thanks to all the contributors!)

## 1.6.2 (2023-01-28)

- fix(desktop): close current instance when another is already open
- fix: cannot receive files when Chinese language is active
- fix(android, ios): share files with non-English names

## 1.6.1 (2023-01-27)

- fix(windows): app crashes when minimized to tray
- fix(android, ios): share intent sometimes not working
- fix(android, ios): scan not triggered when coming from share intent
- fix(android, ios): share intent produced duplicates after finishing a transfer

## 1.6.0 (2023-01-27)

- feat: show thumbnail in progress page
- feat: improve cache clearing mechanism
- feat: hashtag input now tries all combinations when multiple subnets are given
- feat(desktop): show dialog instead of bottom sheet when adding files
- feat(windows, mac): minimize to tray
- feat(windows): launch on login
- feat: add multiline toggle to message input
- fix: show correct file count in progress page
- fix: add self-discovering prevention
- i18n: add Simplified Chinese

## 1.5.2 (2023-01-14)

- F-Droid Release

## 1.5.1 (2023-01-10)

- fix(windows): app sometimes crash on start

## 1.5.0 (2023-01-09)

- feat: quick save mode
- feat: accept requests partially
- feat: set destination directory during accept phase
- feat: rename incoming files
- feat: keep screen on during file transfer
- feat: tap to open selected file before sending

## 1.4.0 (2023-01-06)

- feat: support multiple local IP addresses
- feat: detect if message is a link and add a button to open the link

## 1.3.1 (2023-01-03)

- fix: local IP sometimes not found

## 1.3.0 (2023-01-03)

- feat: enter custom target address
- feat: tap to open received file
- feat: responsive UI
- feat(ios): receive share intent
- feat(windows): set destination folder
- fix: update nearby device attributes when scan again

## 1.2.0 (2022-12-31)

- feat: drag and drop files
- feat: share plain messages
- feat(android): receive share intent

## 1.1.0 (2022-12-30)

- feat(android): add media picker
- feat(ios): merge image and video to common media picker
- fix(android): missing internet permission

## 1.0.0 (2022-12-29)

- Initial Release
