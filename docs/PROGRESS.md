# Flux 进度与交接记录

> 这份文档用于接手：记录本轮目标、已修复内容、验证证据、打包产物和后续重点。更新日期：2026-09-29。

## 当前发布

| 项目 | 状态 |
|------|------|
| 应用名 | Flux |
| 当前版本 | 2.0.0+200 |
| Android applicationId | `org.localsend.localsend_app`（必须保持不变，保证覆盖安装） |
| Android 签名 | 既有私有 JKS；文件、别名和密码仅存于密码管理器与离线备份，绝不进入公开仓库 |
| macOS 应用名 | `Flux.app` |
| 目标产物 | `/Users/yueliangmanle/flux-send/releases/history/v2.0.0/Flux-v2.0.0-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v2.0.0/Flux-v2.0.0-macOS.dmg` |

## 本轮目标

- 修复“扫描/连接/剪切板/断连/蓝牙/UI 反馈”相关问题，至少保证当前代码可静态检查、可测试、可发布安装包。
- 补上经典蓝牙入口与真实链路反馈：系统配对设备列表、刷新、连接、监听、已连接/断开/错误状态。
- 每次发包更新版本号，并保留签名密钥信息，避免 Android 后续无法覆盖安装。
- 所有关键操作留痕，方便后续开发者接手。
- 以后所有正式安装包统一归档到 `/Users/yueliangmanle/flux-send/releases/history/v版本号/`，并更新 `releases/README.md`；桌面只允许临时中转，发包后要清空。

### 2026-09-30 v2.0.0 大版本：安全/稳定性/传输性能整体升级

- 依据：docs/ROADMAP-2.0.md（四维深读审查汇总）。本批实施其中阶段一全部 + 阶段二/三的高价值快赢项；断点续传、蓝牙协议 v2、前台服务、二维码配对、剪贴板时间线等留在 2.0.x/2.1。
- 安全：剪贴板同步出站校验对端 TLS 证书指纹（TOFU）；`/api/clipboard` 加 1 MiB 上限 + 每 IP 30 次/分钟限流 + 可选 PIN（X-Pin 头）；PIN 限流改 5 分钟滑动窗口（成功清零），PIN 优先走请求头。
- 稳定性：UDP 公告重试不再中途关闭 socket；监听排空积压数据报；Android SAF 扫描移后台线程 + 5000 条上限（消 ANR）；picker 按 requestCode 存 Result（消挂死）；未知扩展名兜底 octet-stream（消崩溃）；onDestroy 回收全部挂起 Result。
- 性能：蓝牙接收改流式写临时 .part 文件 + 大小校验（消大文件 OOM）；进度文案 100ms 节流。
- macOS：pending 文件安全作用域在 Flutter 消费后统一释放（修泄漏）；目标目录书签过期自动重建；Debug entitlements 补 app-scope bookmarks。
- 重构：删除 WebRTC 信令/接收链、in_app_purchase 捐赠、TV 输入包装等上游遗留；TextFieldTv → FluxTextField。
- UI：扫描空态给原因提示 + “去排查/手动输入 IP”入口（新 i18n key 经 slang 生成）；失败重试按钮加本地化 tooltip。
- 验证：`dart format` 无变更；`flutter analyze` 无 issues；`flutter test` 全量 242 项通过；`:app:compileReleaseKotlin` 通过（原生改动编译验证）。
- 构建环境记录（本机，2026-09-30，Xcode 27 / Rust stable 1.94 环境）：
  1. macOS DMG 多次构建失败的根因链：stable 工具链自动升级 1.93.1→1.94.0 + `~/.cargo/registry` 经本地代理下载损坏 + Xcode 27 新链接器在 `MACOSX_DEPLOYMENT_TARGET>=12` 时对部分 proc-macro dylib 间歇性产出 "mis-aligned LINKEDIT string pool"（rustc 报 E0463，每次失败的不是同一个 crate；与 cargokit 固定用 stable 解析工具链叠加，长路径 target 目录更容易触发）。
  2. 已落地的环境规避（机器级，均在仓库外）：`rustup default 1.93.1` 并将 `stable` 符号链接至 1.93.1（`rustup toolchain link stable ~/.rustup/toolchains/1.93.1-aarch64-apple-darwin`）；`~/.cargo/config.toml` 注释失效代理（备份同目录）并新增 `[env] MACOSX_DEPLOYMENT_TARGET = { value = "10.14", force = true }`（仅影响 macOS rust 编译，dylib 在 12+ 照常运行）；曾损坏的 `~/.cargo/registry/{cache,src}` 已清空重下。
  3. 仓库内规避：`app/rust/rust-toolchain.toml` 钉扎 1.93.1；macOS 构建改为 **arm64 单架构**（Podfile 与 Runner 工程强制 `ARCHS = arm64`），Intel Mac 暂用 1.1.55；链接器修复后按 ROADMAP 恢复双架构并移除上述规避。
- 产物与校验（`releases/history/v2.0.0/`）：
  - `Flux-v2.0.0-android.apk`（133M）SHA-256 `dca3326148a7ccd566849c4b27c4bd6332379ef768cfb2740ab5117d3f239e2f`；aapt 校验 `org.localsend.localsend_app`、`versionName=2.0.0`、`versionCode=200`；apksigner 证书 SHA-256 保持 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
  - `Flux-v2.0.0-macOS.dmg`（arm64）SHA-256 `5c224e7e716cfaef03ed4f57f8fab994ffa49bc18ca70bcac4d30b574a9c6f18`；`hdiutil verify` 通过；挂载后 `Flux.app` 为 `2.0.0 (200)`，`codesign --verify --deep --strict` 通过，蓝牙 entitlement 为 true。
  - 同目录 `SHA256SUMS.txt` 已生成。
- 发布状态：用户确认后直接发布 GitHub Release v2.0.0（未经双端真机验收，验收转为发布后事项）。
- 已知未做（记入 ROADMAP）：断点续传、蓝牙协议 v2 能力协商、Android 前台服务（息屏保活）、二维码配对、剪贴板时间线、设置页拆分、i18n 全量收口。`send_provider.dart` 的 rhttp publicKey 接线（发送链 pinning）尚未完成，剪切板链已先落地。

### 2026-09-29 v1.1.55 追加修复（四维审查汇总：产品 / UI / 体验 / 全栈）

- 背景：以 4 个并行审查（产品、UI、使用体验、全栈工程师）扫描待发布代码，汇总后统一修复。v1.1.54 已于 2026-07-27 本地归档但未发布 GitHub Release，本轮修复独立升版为 `1.1.55+114`，不动 v1.1.54 归档产物。
- 根因 1（数据级）：剪切板发送端对部分失败的重试每 5 秒重发旧文本；接收端 `shouldWriteIncomingClipboard` 的第二条件 `lastLocalText != lastRemoteText` 在用户复制过新内容后恒为真，旧文本重试会覆盖接收端刚复制的内容。
- 修复 1：接收端判据改为 `incomingText != lastRemoteText && incomingText != lastLocalText`——已接收过的远端文本（含失败重试）与本机现有内容一律不再写入；发送端待同步文本超过 2 分钟未成功即放弃自动重试并提示，`_pendingSince` 记录首次入队时间。
- 根因 2（信任级）：剪切板“暂停”只存内存，`init.dart` 启动无条件 `enable()`，重启后静默恢复同步。
- 修复 2：`PersistenceService` 新增 `ls_clipboard_sync_enabled`（默认开启），`enable()/disable()` 写入持久层，启动按存储值恢复，暂停过的设备重启显示“剪切板同步已暂停”。
- 根因 3（并发）：Android `writeFrame` 被 accept/client 线程（hello）与读循环线程（ack）及平台主线程并发调用，RFCOMM 输出流可能交错写坏帧。
- 修复 3：`writeFrame` 加 `@Synchronized`；读循环在 emit `clipboard`/`message` 前再次校验 `socket === activeSocket`，旧 socket 晚到数据不再冒充新连接。
- 根因 4：macOS `rejectUnverifiedMessage` 固定关闭 `self.channel`，依赖调用方守卫才能保证不误关新连接。
- 修复 4：`handleLine(_ line:, from:)` 显式传入触发消息的通道，`rejectUnverifiedMessage(_:on:)` 只关闭该通道。
- 根因 5（体验）：对非 Flux 配对设备按 2/5/10/15 秒无限循环重连，且提示不含原因。
- 修复 5：新增 `isClassicBluetoothHandshakeFailureMessage` / `shouldStopClassicBluetoothAutoReconnect`（上限 3 次连续握手失败），达到后停止自动重连并提示“对方可能不是 Flux 或版本过旧”；手动重连、连接成功、手动停止都会重置计数。
- 根因 6（品牌/流程）：`.github/workflows/winget.yml` 每次 release 会把 Flux 资产推到上游 `LocalSend.LocalSend` winget 包（引用不存在的 WINGET_TOKEN）；pubspec 元数据、关于页、Windows Inno 脚本仍是 LocalSend 身份；git `origin` 仍指向上游 `localsend/localsend`。
- 修复 6：删除 `winget.yml`；pubspec description/homepage 改为 Flux 与本仓库；关于页加“Flux 基于 LocalSend（Apache-2.0）修改”致谢并新增 Flux 源码入口，上游链接改标注“上游项目”；Inno 脚本改用 Flux 名称/新 AppId（避免与上游安装器互相覆盖），输出名改 `flux`；删除指向上游的 `origin` remote（仅保留 `flux`）。
- 根因 7（CI）：`compile_apk.yml`/`release.yml` 的 secrets 未配置时会解码出空文件，错误延迟到 Gradle 签名阶段才暴露（当前仓库未配置任何 Actions secrets）。
- 修复 7：两个工作流的解码步骤加空值守卫，缺失时立即 `exit 1` 并输出配置指引；`docs/DEVELOPMENT.md` 补充蓝牙握手威胁模型（hello/ack 是活性校验不是认证，明文 RFCOMM，传输安全边界仍是 HTTPS + PIN）。
- 其他：`theme.dart` 删除悬空死代码行；`releases/README.md` 归档表补 v1.1.53；`destination_display_label.dart` 对 `pathSegments` 懒解码抛出的 `FormatException`（截断 UTF-8，如 `%E4%B8`）与 `decodeComponent` 的 `ArgumentError` 都做回退。
- TDD 留痕：先翻转“重试可写入”的旧断言并新增 pending TTL、握手失败停止重连、原生写锁/通道定向关闭等测试，再实现转绿。
- 验证：`dart format` 无变更；`flutter analyze` 无 issues；`flutter test` 全量 238 项通过。
- 已识别、本轮不做（后续优化清单）：约 230 处新功能文案硬编码中文未接入 i18n（`flux_connection_status_card`/`classic_bluetooth_provider`/`clipboard_sync_provider`/`connection_mode_provider`/`settings_tab`）；业务逻辑依赖中文文案匹配（`classic_bluetooth_provider.dart` 的 `contains('经典蓝牙未连接')`、`RegExp(r'发送失败[:：]\s*\d+')`）应改为枚举状态；`settings_tab.dart`（1182 行）、`receive_controller.dart`（879 行）、`classic_bluetooth_provider.dart`（727 行）待拆分；`classic_bluetooth_bridge_test.dart` 的源码字符串断言应升级为行为测试；手动 IP 连接失败直接显示英文异常栈（`address_input_dialog.dart`）应映射中文；扫描空列表缺就地排查指引（`send_tab.dart`）；13+ 处 `Colors.grey` 硬编码应走 `colorScheme`；`ci.yml`（Flutter 3.38.10）与发布线（3.35.6）版本漂移；`msix/`、`fastlane/`、`readme_i18n/`、`scripts/appimage` 等上游残留目录待清理。
- 构建环境修复（本机，2026-09-29，Xcode 27 / Flutter 3.44 环境变化导致旧命令失败）：
  1. Android：Maven Central 与 Gradle Plugin Portal 在当前网络不可达，写入 `~/.gradle/init.d/aliyun-mirror.gradle` 注入阿里云镜像；`~/.gradle/gradle.properties` 中已失效的 127.0.0.1:7890 代理已注释（备份 `gradle.properties.bak-20260929`），Gradle 走直连 + 镜像。
  2. macOS：Xcode 27 SDK 最低部署目标为 12.0，`app/macos/Podfile` 的 platform 升至 12.0 并在 post_install 强制所有 Pod ≥ 12.0（原有一行强制 11.0 的旧代码一并移除），`Runner.xcodeproj` 全部配置升至 12.0。
  3. macOS：Xcode 27 的 `lipo` 不再接受多架构 `-verify_arch`，Flutter 3.44 工具的架构校验因此误报“does not contain architectures”；已对本机 `/opt/homebrew/share/flutter`（brew Flutter 3.44.0）的 `packages/flutter_tools/lib/src/build_system/targets/darwin.dart` 打补丁改为逐架构校验（语义等价），并删除 `flutter_tools.snapshot` 触发重建。brew 升级 Flutter 后补丁会丢失，届时若上游未修复需重打；`~/.local/bin/flux-lipo-shim/lipo` 为备用 PATH 垫片。
- 产物与校验（`releases/history/v1.1.55/`）：
  - `Flux-v1.1.55-android.apk`（134M）SHA-256 `242e1926a04ebfa6e901619737198fd8e90c103a19b44283a25d69e3608dc6d5`；aapt 校验 `org.localsend.localsend_app`、`versionName=1.1.55`、`versionCode=114`；apksigner 证书 SHA-256 保持 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
  - `Flux-v1.1.55-macOS.dmg`（62M）SHA-256 `18138187f494c83166d579bdbdf9e29161a0164b45d790f20a5f0022591277bd`；`hdiutil verify` 通过；挂载后 `Flux.app` 为 `1.1.55 (114)`，`codesign --verify --deep --strict` 通过，蓝牙 entitlement 为 true。
  - 同目录 `SHA256SUMS.txt` 已生成。
- 发布状态：代码与产物已推送；GitHub Release v1.1.55 已于 2026-09-30 由用户决定直接发布（未按 RELEASE.md 先做双端真机验收，验收作为后续事项补做）。`releases/latest` API 已返回 v1.1.55 与三个正确命名产物，应用内“检查更新”即刻可见。
- 遗留待办：补做 Android ↔ macOS 经典蓝牙双端真机互传验收（配对 → 双方切经典蓝牙 → 连接 → 握手完成 → 双向剪切板/小文件），以及“暂停剪切板重启保持”与“非 Flux 设备 3 次失败停止重连”回归；如验收发现问题，按惯例以 1.1.56 修复发布。
- 勘误：本轮排查中一段“账号被 GitHub 风控隐藏”的结论是错误的，原因是从用户消息照抄了带多余字母 i 的账号名（yueliangmanle ≠ yuelangmanle）且未与登录账号核对；所有 404 均为查询了不存在的账号名所致，账号与仓库从未异常。
- 真机边界：本轮没有把未执行的 Android ↔ macOS 经典蓝牙双端互传写成通过。安装两个 `1.1.55` 包后，仍需按“系统配对 → 双方切经典蓝牙 → 一端连接 → 双方显示握手完成 → 双向剪切板/小文件”完成最终实机验收；同时回归“暂停剪切板重启保持暂停”与“对非 Flux 设备 3 次握手失败后停止重连”。

### 2026-07-27 v1.1.54 蓝牙真实连通性修复

- 用户反馈与证据：Android 可单端显示“已连接”，macOS 仍处于“监听中”，双方无法传输；macOS 崩溃报告定位到 `ClassicBluetoothBridge.jsonString → NSJSONSerialization.dataWithJSONObject → SIGABRT`；Android 设置页异常为 `Illegal percent encoding in URI`。
- 根因 1：Android/macOS 在 RFCOMM socket 打开后立即上报 `connected`，没有确认对端是否为 Flux，也没有确认对端已收到可用协议，导致假连接。
- 修复 1：两端加入 `flux.bluetooth.hello.v1` / `flux.bluetooth.hello.ack.v1` 握手；只在 `confirmHandshake` 后上报连接并允许剪切板或文件帧。未验证数据会断开并给出中文反馈。
- 根因 2：Android 旧读循环在服务端仍运行时会持续处理已替换 socket 的数据，可能把旧链路数据写入新状态。
- 修复 2：读循环改为只在 `socket === activeSocket` 时处理，重连、替换、停止后旧 socket 的晚到数据被隔离。
- 根因 3：macOS 使用仅允许顶层数组/字典的 `JSONSerialization.data(withJSONObject:)` 编码字符串，Objective-C 异常会绕过 Swift `try?` 并终止进程。
- 修复 3：改为 `JSONEncoder().encode(value)`；设置路径解析对非法 SAF 百分号编码安全回退，避免设置页崩溃。
- TDD 留痕：先新增握手门禁、旧 socket 隔离、macOS 字符串编码、非法 SAF URI 的红灯测试；定向 22 项测试与 Dart 静态分析已转绿。尚未把未做的 Android/macOS 双端真机互传写成通过。
- 发布约束：版本升为 `1.1.54+113`，继续使用既有 `org.localsend.localsend_app` 与本机私有 JKS；构建完成后再写入 SHA-256、签名和 DMG 校验结果。
- 发布验证：`flutter analyze` 无 issues，`flutter test` 全量通过；Android APK 实际为 `versionName=1.1.54`、`versionCode=113`、包名 `org.localsend.localsend_app`，签名证书 SHA-256 保持为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 验证：DMG 通过 `hdiutil verify`；真实挂载后的 `Flux.app` 为 `1.1.54+113` 且 `codesign --verify --deep --strict`、蓝牙 entitlement 均通过；经典蓝牙模式启动烟测 12 秒持续运行、有 5 个可见窗口，崩溃报告计数保持 `1 -> 1`。
- 构建留痕：构建工具并行运行时会让旧 bundle 被提前打进 DMG；本次已从通过签名和版本校验的 `Flux.app` 重建最终 DMG，并再次从实际挂载点校验版本，不能仅依据 DMG 文件名判断版本。
- 归档产物：`releases/history/v1.1.54/Flux-v1.1.54-android.apk` SHA-256 为 `b5a7ff8b50031b3ce10cecd0804c8dec63b56d9baa283ef8a680c782b87e47f9`；`releases/history/v1.1.54/Flux-v1.1.54-macOS.dmg` SHA-256 为 `68438223fd8e1782ce8a5243e87bc3fcb4efa46b0a589e3fc5bfebd16d8b8d0e`；校验清单为同目录 `SHA256SUMS.txt`。
- 真机边界：本轮没有把未执行的 Android ↔ macOS 经典蓝牙双端互传写成通过。安装两个 `1.1.54` 包后，仍需按“系统配对 → 双方切经典蓝牙 → 一端连接 → 双方显示握手完成 → 双向剪切板/小文件”完成最终实机验收。

### 2026-07-27 开源仓库与更新通道初始化

- 创建公开仓库 `yuelangmanle/flux-send`，将 Flux 作为独立、可维护的 Apache-2.0 派生项目发布，并在 `NOTICE` 中保留 LocalSend 上游致谢。
- 安全处理：根目录新增对 Android JKS、`key.properties`、本机配置与 `releases/history/` 的忽略规则；重写开发手册，移除历史签名密码明文，私钥与密码仅保留在本机安全存储中。
- 工程化：新增安全策略、发布检查表、贡献指南、行为准则、GitHub Issue 联系入口和开源项目 README；Release 二进制仅上传 GitHub Releases，不进入源码历史。
- 更新能力：新增可测试的 GitHub stable-release 客户端；设置页“检查更新”仅在用户点击后访问 GitHub，Android 打开 APK、macOS 打开 DMG，不提供静默下载或安装。
- 版本：升至 `1.1.53+112`，并同步 Windows 安装器显示版本，避免 CI 的跨配置版本一致性检查失败。
- 验证：`flutter analyze` 无 issues，`flutter test` 全量 228 项通过；Android APK 的 package name 为 `org.localsend.localsend_app`、versionCode 为 `112`、签名证书 SHA-256 保持为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS：DMG 通过 `hdiutil verify`，包内 `Flux.app` 为 `1.1.53+112`，`codesign --verify --deep --strict` 与蓝牙 entitlement 均通过。
- 产物：Android SHA-256 为 `bffe07b8f307a0331223ef3840b885569fd87b63acd71bc750fba95437a3e1a9`；macOS SHA-256 为 `6c15757758f55dc5ffba35075af4e2c11fcd1ff2d9fdde836aecbe3b3101e7f6`；两者及 `SHA256SUMS.txt` 已归档至 `releases/history/v1.1.53/`，并已发布到 GitHub Release `v1.1.53`。

## 已完成修复

### 2026-07-26 v1.1.52 Android 设置页空白兜底与可见错误反馈

- 用户现象：Android 进入“设置”页后显示灰色空页面，没有可见内容或错误反馈。
- 根因：设置页主构建过程直接订阅 `clipboardSyncProvider`；该 Provider 初始化依赖发现、网络和蓝牙状态，若订阅期抛出异常，原有 `ViewModelBuilder.errorBuilder` 无法捕获主 builder 的异常，Release 下会显示整页灰色 ErrorWidget。
- 修复：将剪切板同步设置提取为独立 `_ClipboardSyncSettingsSection`，把 Provider 失败范围限制到该小节；主设置页其余内容不会被剪切板服务失败连带清空。
- 防线：新增 `lib/config/runtime_error_widget.dart`，应用入口在 `preInit` 前注册全局中文 `ErrorWidget.builder`。未来任何未隔离的构建异常都会显示“页面加载异常”和可复制错误摘要，而不是无说明空白。
- TDD 留痕：先新增“runtime widget failures use a visible Chinese fallback”回归测试，确认旧入口缺少注册时红灯，再实现并确认转绿。
- 验证：定向设置/剪切板/连接模式测试 32 项通过；`flutter test` 全量 224 项通过；`flutter analyze` 无 issues。
- 发布约束：本轮版本为 `1.1.52+111`，Android 包名仍为 `org.localsend.localsend_app`，继续使用 `app/android/app/flux-release-key.jks` 与既有签名，保证覆盖安装一致；Android 真机当前未通过 ADB 连接，待新 APK 安装后复测“设置”页。
- 新产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.52/Flux-v1.1.52-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.52/Flux-v1.1.52-macOS.dmg`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.52/SHA256SUMS.txt`。
- 产物校验：Android APK `versionName=1.1.52`、`versionCode=111`、签名 SHA-256 为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS DMG 通过 `hdiutil verify`，包内 `Flux.app` 为 `1.1.52+111`，`codesign --verify --deep --strict` 和蓝牙 entitlement 均通过。
- macOS 烟测：新构建 App 的局域网模式下启动 12 秒持续运行，主窗口可见，TCP LISTEN 存在，崩溃日志计数为 `0 -> 0`。
- 哈希：APK `b0db94df3b90aad53a3c0b7cedd8b201ac4294444af12a5c9c6772a5aef18ed9`；DMG `1055a4129b9abe0f3b24ff4e2e86aa68d63aeb0e17e941c16768d922e5722cdd`。

### 2026-06-09 v1.1.51 Android 设置页白屏与 macOS 安装版本修复

- 当前状态：响应“手机端设置点进去还是白屏、电脑端设置版本仍是上一版”的反馈；本轮继续升正式版本，不复用旧包。
- macOS 安装核验：先确认 `/Applications/Flux.app` 曾停留在 `1.1.49+108`，再用 `releases/history/v1.1.50/Flux-v1.1.50-macOS.dmg` 覆盖安装到 `1.1.50+109` 并通过 `codesign --verify --deep --strict` 与启动存活检查；本轮会继续安装新版 `1.1.51+110`。
- Android 白屏根因防线：设置页顶部伪 appbar 不再让 Android 渲染 `MoveWindow`，该桌面拖拽组件只在 `checkPlatformIsDesktop()` 为真时启用。
- Android 初始化防线：`_SettingsTabInitAction` 不再直接读取桌面自启动/右键菜单状态，移动端通过 `loadDesktopSettingsTabState()` 返回空桌面状态，避免 Android 设置页初始化触碰桌面专用 helper。
- UI 兜底：设置页新增中文加载态、中文错误态和“重试”按钮；即使设置初始化出现异常，也显示可反馈错误而不是纯白屏。
- TDD 留痕：新增/更新 `test/unit/settings_resilience_test.dart`，先复现设置页缺少移动端隔离和错误兜底的红灯，再实现转绿。
- 当前验证：`flutter analyze` 无 issues；定向 `flutter test test/unit/settings_resilience_test.dart test/unit/flux_connection_status_card_test.dart test/unit/provider/connection_mode_provider_test.dart` 通过；当前没有 Android ADB 设备在线，真机设置页点击需安装新 APK 后复测。

### 2026-06-09 v1.1.50 蓝牙真链路与剪切板自动同步修复

- 当前状态：响应“蓝牙传输被 Wi‑Fi 迷惑、剪切板要自动同步、不要毛坯房”的反馈；本轮把蓝牙文件、剪切板载荷、模式隔离、接收历史和设置页兜底一起收敛后发正式包。
- 根因修复：经典蓝牙模式下清空 LAN 发现设备，并拦截手动 IP、收藏设备、发送页局域网扫描入口；用户在蓝牙模式看到的文件发送只能走经典蓝牙 RFCOMM，不会再偷偷走局域网/热点。
- 蓝牙文件链路：新增 begin/chunk/end JSON 行帧，经 Android/macOS 原生 RFCOMM bridge 发送；接收端按块组装保存，并写入接收历史。
- 剪切板自动同步：应用启动后仍默认启用剪切板同步，每 500ms 轮询系统剪切板；局域网/热点走 HTTP `text/plain`，经典蓝牙走常驻 RFCOMM；“发送当前剪切板”只应作为测试入口，不是正常使用入口。
- Android 剪切板修复：发送端不再 POST JSON，接收端仍兼容旧版 JSON，避免 Android 把 `{"text":"..."}` 原样写入系统剪切板。
- TDD 留痕：新增/更新 `clipboard_sync_provider_test.dart`、`classic_bluetooth_provider_test.dart`、`classic_bluetooth_bridge_test.dart`、`receive_history_provider_test.dart`、`settings_resilience_test.dart`，先复现红灯再转绿。
- 验证通过：`flutter analyze` 无 issues；`flutter test` 全量 219 项通过。
- Android 真机验证：设备 `5c9a55dc` 已从 `1.1.49+108` 覆盖安装到 `1.1.50+109`，`firstInstallTime` 保持 `2026-06-04 18:51:47`；启动 8 秒后进程仍在，未发现 `FATAL EXCEPTION` / `AndroidRuntime` 崩溃日志。
- macOS 烟测：release `Flux.app` 为 `1.1.50+109`，启动 10 秒后进程仍在，崩溃日志计数保持 `5 -> 5`；DMG 通过 `hdiutil verify`，签名和蓝牙 entitlement 校验通过。
- 新产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.50/Flux-v1.1.50-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.50/Flux-v1.1.50-macOS.dmg`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.50/SHA256SUMS.txt`。
- 发布完整性：Android APK SHA-256 为 `81e53ca5565c28bcd1cacc14f3b6f9fe0d6afe670e0d16d23d7fad7f15585b4f`，macOS DMG SHA-256 为 `2f8e485e989d33989f6cd04052826d12fa9004eb21a9f1b4ccfbc2e11cad3eec`；Android 签名 SHA-256 仍为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- 归档调整：历史安装包已统一移动到 `/Users/yueliangmanle/flux-send/releases/history/`，打包脚本后续也默认写入 `releases/history/v版本号/`。

### 2026-06-08 v1.1.49 三模式烟测与蓝牙切换安全回退

- 当前状态：继续响应“热点和局域网模式也不要忽略，还没做实测”；本轮把局域网、热点、经典蓝牙都纳入 macOS 烟测，不再只测蓝牙持久启动。
- 根因风险：经典蓝牙切换旧实现先保存模式，再异步启动原生 RFCOMM；如果蓝牙启动失败或未来包漏权限，用户可能被保存的蓝牙模式拖入“再次打开仍失败”的体验。
- 修复：经典蓝牙切换先 `setModeVolatile()`，等待 `startListening()` 返回成功后才 `persistMode()`；失败时自动 `setMode(previousMode)` 回退，并在 UI snackbar 中显示失败原因。
- TDD 留痕：新增 `classic bluetooth switch is only persisted after native listener starts` 红灯测试，确认旧顺序不安全后修复转绿。
- 烟测脚本：扩展 `/Users/yueliangmanle/flux-send/scripts/smoke_macos_flux.sh`，支持 `FLUX_SMOKE_MODE=localNetwork|hotspot|classicBluetooth`，并检查进程、可见窗口、持久模式、TCP LISTEN、崩溃日志。
- Android 真机验证：设备 `25019PNF3C`（Android 16 / SDK 36）已从旧版 `1.1.38+97` 覆盖安装到 `1.1.49+108`，`firstInstallTime` 保持不变；启动 12 秒后进程仍在，未发现 `FATAL EXCEPTION` / `AndroidRuntime` 崩溃日志。
- macOS 三模式实测：`/Applications/Flux.app` 已覆盖安装为 `1.1.49+108`；`FLUX_SMOKE_MODE=localNetwork`、`FLUX_SMOKE_MODE=hotspot`、`FLUX_SMOKE_MODE=classicBluetooth` 均通过，三次都确认 `Flux` 进程 12 秒后仍运行、`lsof -iTCP -sTCP:LISTEN` 有监听端口、崩溃日志计数保持 `5 -> 5`。
- 新产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.49/Flux-v1.1.49-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.49/Flux-v1.1.49-macOS.dmg`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.49/SHA256SUMS.txt`。
- 发布完整性：Android APK SHA-256 为 `784c2b5f8d96989ac7c6a08d647b920c06041475e1b504ead11af1f09d486db4`，macOS DMG SHA-256 为 `3490880e6755988936ab4e15b4eedbef1d2d656e195aa137c3e0199992917796`；Android 签名 SHA-256 仍为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。

### 2026-06-08 v1.1.48 无权限弹窗小屏可读性

- 当前状态：继续审计 v1.1.47 权限提示纠偏后的 UI 风险；长文案进入 `NoPermissionDialog` 后，旧弹窗没有滚动能力，手机小屏可能看不完整。
- 修复：`NoPermissionDialog` 的 `AlertDialog` 增加 `scrollable: true`，长恢复指引可滚动阅读。
- TDD 留痕：新增 `no-permission dialog is scrollable for long Android recovery guidance` 红灯测试，确认旧实现失败后修复转绿。
- 验证通过：定向 `flutter test test/unit/no_permission_dialog_guidance_test.dart` 通过；`flutter analyze` 无 issues；`flutter test` 全量 211 项通过。
- 已正式发布并覆盖安装 macOS `1.1.48+107`；启动 8 秒烟测通过，没有新增 `Flux-*.ips` 崩溃日志。
- 新产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.48/Flux-v1.1.48-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.48/Flux-v1.1.48-macOS.dmg`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.48/SHA256SUMS.txt`。
- Android 包名仍为 `org.localsend.localsend_app`，`versionCode=107`，`versionName=1.1.48`，签名 SHA-256 仍为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 校验：DMG 通过 `hdiutil verify`；包内 `Flux.app` 为 `1.1.48+107`，包含 `NSBluetoothAlwaysUsageDescription` 与 `com.apple.security.device.bluetooth=true`，`codesign --verify --deep --strict` 通过。
- 追加复核：新增 `/Users/yueliangmanle/flux-send/scripts/smoke_macos_flux.sh`，并实际跑通普通启动与 `FLUX_SMOKE_MODE=classicBluetooth` 持久蓝牙模式启动；两次均确认 `Flux` 进程 12 秒后仍运行、CoreGraphics 可见窗口数为 `5`、崩溃日志计数保持 `5 -> 5`。
- 发布完整性：Android APK SHA-256 为 `0a1349b99417d85be491a7012c3d3730f34b7c31236272a34ab3eb732ade4d2e`，macOS DMG SHA-256 为 `f2a37705333911a52073bf01c269f6838c2b358eddaeb313f9f1e0ebebe91acd`；桌面无安装包残留。

### 2026-06-08 v1.1.47 Android 权限提示纠偏

- 当前状态：继续全量审计用户此前反馈“手机端发电脑说没有权限，系统设置里给了还是没用”的路径；发现 `NoPermissionDialog` 仍是泛文案，会把 Android SAF/文件选择器问题误导成系统设置授权问题。
- 根因风险：Android 发送文件、发送文件夹和接收保存目录都依赖系统文件选择器/SAF 持久授权；失败后用户通常应该回到 Flux 重新选择文件、文件夹或 Download/下载目录，而不是寻找“全部文件访问权限”。
- 修复：中文/英文无权限弹窗改为可操作说明，明确发送失败、接收保存失败分别怎么处理，并说明 Android 本流程不需要“全部文件访问权限”。
- TDD 留痕：新增 `test/unit/no_permission_dialog_guidance_test.dart`，先跑出红灯，再修复源 i18n 和生成文件后转绿。
- 验证通过：`flutter analyze` 无 issues，`flutter test` 全量 210 项通过；旧泛文案已从中英文源文件和生成文件主路径清除。
- 已正式发布并覆盖安装 macOS `1.1.47+106`；启动 8 秒烟测通过，没有新增 `Flux-*.ips` 崩溃日志。
- 新产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.47/Flux-v1.1.47-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.47/Flux-v1.1.47-macOS.dmg`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.47/SHA256SUMS.txt`。
- Android 包名仍为 `org.localsend.localsend_app`，`versionCode=106`，`versionName=1.1.47`，签名 SHA-256 仍为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 校验：DMG 通过 `hdiutil verify`；包内 `Flux.app` 为 `1.1.47+106`，包含 `NSBluetoothAlwaysUsageDescription` 与 `com.apple.security.device.bluetooth=true`，`codesign --verify --deep --strict` 通过。
- 发布完整性：Android APK SHA-256 为 `a2b58e7ffd13ebe92545486f2aed3c9ca2952dea9eff27f6fe2d8a796b5fec1d`，macOS DMG SHA-256 为 `82839feb8068497de6777f7df045a80975cb39b58708941c22706dc67c85339e`；桌面无安装包残留。

### 2026-06-08 v1.1.46 macOS 蓝牙闪退防线

- 当前状态：已复核最新用户崩溃日志，18:15 的 `Flux-*.ips` 来自旧包 `1.1.38+97`，崩溃原因为 macOS TCC 发现缺少 `NSBluetoothAlwaysUsageDescription` 后强杀进程。
- 现场核对：修复前现装 `/Applications/Flux.app` 为 `1.1.45+104`，已包含蓝牙用途说明和蓝牙沙盒 entitlement，直接启动 8 秒仍存活且没有新增崩溃日志。
- 根因风险：`classicBluetoothProvider` 初始化时会自动调用原生 `startListening()` 与 `refreshPairedDevices()`；如果用户保存蓝牙模式或 UI 读取状态，应用启动阶段就会触碰蓝牙硬件，风险过高。
- 修复：Classic Bluetooth Provider 初始化改为“待命 + 只订阅事件”，不再自动启动原生蓝牙；切换到蓝牙、刷新蓝牙设备或连接设备时才显式访问硬件。
- 防线：macOS 原生 `ClassicBluetoothBridge` 在所有 IOBluetooth 入口前自检 `NSBluetoothAlwaysUsageDescription`，未来若包漏配会返回 `BLUETOOTH_USAGE_DESCRIPTION_MISSING` 中文错误，不再裸奔到 TCC 强杀。
- TDD 留痕：先新增两个失败测试并确认红灯，再修复转绿；定向验证 `flutter test test/unit/provider/classic_bluetooth_provider_test.dart test/unit/macos_visibility_test.dart` 通过，共 25 项通过。
- 验证通过：`flutter analyze` 无 issues，`flutter test` 全量 208 项通过；Android/macOS release 包均已构建。
- 已正式发布并覆盖安装 macOS `1.1.46+105`；启动 8 秒烟测通过，没有新增 `Flux-*.ips` 崩溃日志。
- 新产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.46/Flux-v1.1.46-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.46/Flux-v1.1.46-macOS.dmg`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.46/SHA256SUMS.txt`。
- Android 包名仍为 `org.localsend.localsend_app`，`versionCode=105`，`versionName=1.1.46`，签名 SHA-256 仍为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 校验：DMG 通过 `hdiutil verify`；包内 `Flux.app` 为 `1.1.46+105`，包含 `NSBluetoothAlwaysUsageDescription` 与 `com.apple.security.device.bluetooth=true`，`codesign --verify --deep --strict` 通过。
- 发布完整性：Android APK SHA-256 为 `43d0ac629ce99a633e8264e47156e5e91a00418d2b834fc2f10cfaee9709f4ce`，macOS DMG SHA-256 为 `df03ef1b91ede91f3c7d2f112112ca81a36c6bea58fce82bb9034791fd50d908`；桌面无安装包残留。

### 2026-06-08 v1.1.45 文件上传错误提示

- 修复文件上传失败时发送端可能显示空白错误（例如 `[500] `）的问题；现在接收端没有返回错误详情时，会提示检查接收端 Flux 的保存目录、权限和剩余空间。
- 新增空 HTTP 上传失败响应回归测试；最终 `flutter analyze` 无 issues，`flutter test` 全量 206 项通过。
- 已正式发布并覆盖安装 macOS `1.1.45+104`；启动 8 秒烟测通过，没有新增 `Flux-*.ips` 崩溃日志。
- 新产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.45/Flux-v1.1.45-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.45/Flux-v1.1.45-macOS.dmg`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.45/SHA256SUMS.txt`。
- Android 包名仍为 `org.localsend.localsend_app`，`versionCode=104`，`versionName=1.1.45`，签名 SHA-256 仍为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。

### 2026-06-08 v1.1.44 模式门控与发包

- 修复经典蓝牙模式下剪切板服务仍会触发 UDP 多播和 TCP 网段扫描的问题；现在蓝牙模式只维护 RFCOMM 常驻链路状态，局域网/热点模式才跑网络发现。
- 修复 Android/macOS 打包脚本默认无法从 `pubspec.yaml` 解析版本号的问题；以后不传 `VERSION=...` 也能自动归档到 `releases/history/v当前版本/`。
- 新增剪切板模式门控测试和打包脚本默认版本解析测试；最终 `flutter analyze` 无 issues，`flutter test` 全量 205 项通过。
- 已正式发布并覆盖安装 macOS `1.1.44+103`；启动 8 秒烟测通过，没有新增 `Flux-*.ips` 崩溃日志。
- 新产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.44/Flux-v1.1.44-android.apk`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.44/Flux-v1.1.44-macOS.dmg`、`/Users/yueliangmanle/flux-send/releases/history/v1.1.44/SHA256SUMS.txt`。
- Android 包名仍为 `org.localsend.localsend_app`，`versionCode=103`，`versionName=1.1.44`，签名 SHA-256 仍为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。

### 2026-06-08 安装纠偏与质量闸门

- 复核用户侧“macOS 选择蓝牙模式闪退且再也打不开”时，发现 `/Applications/Flux.app` 实际仍是旧版 `1.1.38+97`，缺少 `NSBluetoothAlwaysUsageDescription` 与 `com.apple.security.device.bluetooth`，与崩溃日志中的 TCC 强杀原因一致。
- 已从项目归档 `/Users/yueliangmanle/flux-send/releases/history/v1.1.43/Flux-v1.1.43-macOS.dmg` 覆盖安装到 `/Applications/Flux.app`，当前已安装版本为 `1.1.43+102`。
- 覆盖安装后确认本机偏好仍保存 `flutter.flux_connection_mode=classicBluetooth`，在“启动即进入蓝牙模式”的状态下启动 8 秒仍存活，且没有新增 `Flux-*.ips` 崩溃日志。
- 本轮没有修改运行时代码，因此当时没有重新发 `v1.1.44`；后续已在模式门控修复后正式发布 `1.1.44+103`。

### 连接与剪切板

- 新增/接入 `ClassicBluetoothService`，启动后监听原生蓝牙事件、读取已配对设备、启动经典蓝牙服务端。
- 剪切板同步在经典蓝牙模式下改走 `sendClassicBluetoothClipboard(text)`，不再只依赖局域网 HTTP 目标。
- 蓝牙事件 `clipboard` 会进入 `clipboardSyncProvider.handleIncomingClipboard(...)`，避免只显示连接而不同步内容。
- 异步事件订阅、启动监听、刷新设备、dispose 清理均显式 `unawaited`，`flutter analyze` 已无警告。

### Android 原生

- `ClassicBluetoothBridge.kt` 使用标准 SPP UUID `00001101-0000-1000-8000-00805F9B34FB`。
- Android EventChannel 回调切回主线程发送，降低断连/重连时原生事件触发 Flutter 崩溃风险。
- 保留局域网/热点/蓝牙权限声明与运行时请求路径；经典蓝牙仍要求用户先在系统设置完成配对。

### macOS 原生

- `ClassicBluetoothBridge.swift` 发布 SPP SDP 服务，而不是假设固定 RFCOMM channel 1。
- 连接远端时先通过 SDP 查询解析 RFCOMM channel，失败才 fallback 到 channel 1。
- 适配当前 macOS SDK 的 IOBluetooth Swift API：`register(forChannelOpenNotifications:...)`、`getServiceRecord(for:)` 和 UUID 类型转换。
- `flutter build macos --release` 已通过，产物为 `build/macos/Build/Products/Release/Flux.app`。

### UI 与反馈

- `FluxConnectionStatusCard` 展示局域网、热点直连、经典蓝牙三种模式的状态。
- 蓝牙区域展示已配对设备、刷新按钮、连接按钮、监听/连接/错误状态。
- 模式说明改为中文，并明确经典蓝牙需要先在系统蓝牙设置中配对。

## 已验证命令

```bash
cd /Users/yueliangmanle/flux-send/app
flutter test test/unit/provider/connection_mode_provider_test.dart test/unit/provider/clipboard_sync_provider_test.dart test/unit/provider/classic_bluetooth_provider_test.dart test/unit/classic_bluetooth_bridge_test.dart
flutter analyze
flutter test
flutter build macos --release
flutter build apk --release
```

验证结果：

- 关键单元测试：通过。
- `flutter analyze`：通过，无 issues。
- `flutter test`：通过，全量 206 项通过。
- macOS release build：通过，`Flux.app` 版本为 `1.1.45`，构建号为 `104`。
- Android release build：通过，已生成 release APK。
- Android 校验：`/Users/yueliangmanle/flux-send/releases/history/v1.1.45/Flux-v1.1.45-android.apk` 包名为 `org.localsend.localsend_app`，`versionCode=104`，`versionName=1.1.45`，签名 SHA-256 仍为 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 校验：`/Users/yueliangmanle/flux-send/releases/history/v1.1.45/Flux-v1.1.45-macOS.dmg` 已通过 `codesign --verify --deep --strict` 和 `hdiutil verify`，挂载后确认包内 `Flux.app` 同样包含 `NSBluetoothAlwaysUsageDescription` 与 `com.apple.security.device.bluetooth`。
- macOS 启动烟测：release `Flux.app` 直接启动 8 秒后仍存活，且 `~/Library/Logs/DiagnosticReports` 未产生新的 `Flux-*.ips` 崩溃日志。
- 发布完整性：`/Users/yueliangmanle/flux-send/releases/history/v1.1.45/SHA256SUMS.txt` 已生成并校验通过。

## 后续接手重点

1. 真机蓝牙互通必须先在 macOS/Android 系统蓝牙设置完成配对；应用内只列出并连接“已配对设备”。
2. 经典蓝牙的稳定性要重点观察断连重连、App 前后台切换、macOS 蓝牙权限弹窗后的状态恢复。
3. 局域网/热点模式仍依赖设备在同一网段、系统防火墙允许入站、Android Wi-Fi/附近设备权限可用。
4. 如果用户反馈“能发现但不能传”，优先检查接收端日志和 `/api/clipboard`/文件上传响应，不要只看发送端成功提示。
5. Android 发版必须继续使用同一个 `applicationId` 与 `flux-release-key.jks`；不要重建 keystore。

## 打包后校验建议

```bash
cd /Users/yueliangmanle/flux-send/app
$ANDROID_HOME/build-tools/*/apksigner verify --print-certs /Users/yueliangmanle/flux-send/releases/history/v1.1.43/Flux-v1.1.43-android.apk
hdiutil verify /Users/yueliangmanle/flux-send/releases/history/v1.1.43/Flux-v1.1.43-macOS.dmg
```

## 2026-06-08 追加维护记录（打包脚本加固，未发包）

- 接手时间：2026-06-08。在 v1.1.43 发包后继续审计项目内打包脚本，发现 `scripts/compile_mac_dmg.sh` 仍使用 `LocalSend.app`、`LocalSend.dmg`、旧 Developer ID 和 notarization 占位；`scripts/compile_android_apk.sh` 仍复制旧 `localsend` 目录到 `/tmp/build`，不符合当前 Flux 归档规则。
- 根因风险：后续接手者如果使用旧脚本，会生成错误名称/错误路径的安装包，或者在 macOS 重签时遗漏 `Release.entitlements`，再次丢失经典蓝牙沙盒权限。
- 修复：重写 `scripts/compile_android_apk.sh` 与 `scripts/compile_mac_dmg.sh`；两个脚本默认从 `app/pubspec.yaml` 读取版本号，并输出到 `/Users/yueliangmanle/flux-send/releases/history/v版本/`。
- macOS 脚本加固：默认 ad-hoc 签名，支持 `SIGN_ID=...` 覆盖；重签 `Flux.app` 时强制带 `macos/Runner/Release.entitlements`，并检查 `com.apple.security.device.bluetooth=true` 后再生成 DMG。
- TDD 留痕：新增 `test/unit/release_packaging_scripts_test.dart`，先确认旧脚本因 LocalSend 名称/旧归档路径失败，再重写脚本使测试转绿。
- 验证：`flutter test test/unit/release_packaging_scripts_test.dart` 通过，共 2 项通过；`bash -n scripts/compile_mac_dmg.sh scripts/compile_android_apk.sh` 通过。
- 发包状态：本次只加固打包脚本和文档，未生成新安装包；当前正式安装包仍为 v1.1.43+102。

## 2026-06-08 追加修复记录（v1.1.43+102）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 审计 macOS 经典蓝牙启动授权链路；未改动 Android keystore，未改动 `applicationId`。
- 根因风险：macOS `Info.plist` 已声明 `NSBluetoothAlwaysUsageDescription`，但 Runner 仍启用 App Sandbox；如果 entitlements 缺少 `com.apple.security.device.bluetooth`，release/debug 沙盒包可能仍无法访问蓝牙设备，导致蓝牙模式启动失败或链路不可用。
- 修复：在 `macos/Runner/Release.entitlements` 与 `macos/Runner/DebugProfile.entitlements` 增加 `com.apple.security.device.bluetooth=true`。
- TDD 留痕：新增 `macOS sandbox entitlements allow Bluetooth device access` 红灯测试，确认旧 entitlements 失败后再补齐。
- 定向验证：`flutter test test/unit/macos_visibility_test.dart` 通过，共 3 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 200 项通过。
- Android 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.43/Flux-v1.1.43-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=102`，`versionName=1.1.43`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.43/Flux-v1.1.43-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.43`，`CFBundleVersion=102`，`NSBluetoothAlwaysUsageDescription` 存在，`com.apple.security.device.bluetooth=true` 存在，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- macOS 安装包复核：挂载 DMG 后确认包内 `Flux.app` 同样为 `1.1.43+102`，包含蓝牙用途说明与蓝牙沙盒 entitlement，并通过 `codesign --verify --deep --strict`。
- macOS 启动烟测：直接启动 release `Flux.app`，8 秒后进程仍存活，`~/Library/Logs/DiagnosticReports` 未产生新的 `Flux-*.ips` 崩溃日志。
- 发布完整性：新增 `/Users/yueliangmanle/flux-send/releases/history/v1.1.43/SHA256SUMS.txt`；Android APK SHA-256 为 `b3ac53e70d69edd9c48ef559b93068391b139b2ad9559c49cb68c74974b64d29`，macOS DMG SHA-256 为 `0566387109af1e1d053014248abdbeb2243ec6dd1950b3e82bda4fe8d70b8377`。

## 2026-06-08 追加修复记录（v1.1.42+101）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 审计 Android 经典蓝牙停止/切换/快速重连路径；未改动 Android keystore，未改动 `applicationId`。
- 根因风险：Android `connect()` 在线程中阻塞等待 `BluetoothSocket.connect()`；如果用户切换模式或停止蓝牙，旧 socket 成功后仍可能 `attachSocket(...)` 并覆盖当前连接状态，或在过期失败时发出误导性连接失败事件。
- 修复：新增 `AtomicInteger connectionGeneration`；server/client attach 都带 generation；stop/start/connect 递增 generation；过期 attach 关闭 socket 并退出，过期 connect 失败不再 emit error，旧 server 线程不会关闭新 server socket。
- TDD 留痕：新增 `Android rejects stale RFCOMM socket attach after stop or replacement connect` 红灯测试，确认旧实现失败后再修复。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart` 通过，共 15 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 199 项通过。
- Android 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.42/Flux-v1.1.42-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=101`，`versionName=1.1.42`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.42/Flux-v1.1.42-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.42`，`CFBundleVersion=101`，`NSBluetoothAlwaysUsageDescription` 存在，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- macOS 安装包复核：挂载 DMG 后确认包内 `Flux.app` 同样为 `1.1.42+101`，包含 `NSBluetoothAlwaysUsageDescription`，并通过 `codesign --verify --deep --strict`。
- macOS 启动烟测：直接启动 release `Flux.app`，8 秒后进程仍存活，`~/Library/Logs/DiagnosticReports` 未产生新的 `Flux-*.ips` 崩溃日志。
- 发布完整性：新增 `/Users/yueliangmanle/flux-send/releases/history/v1.1.42/SHA256SUMS.txt`；Android APK SHA-256 为 `96268c5a4a9bd93aeb16c31bed00f6d0597081d036a368b7c0f33c7c7fed64b8`，macOS DMG SHA-256 为 `526b810a71f580adf6672538e96c41b46b42b43bb12c41e87533716e2d05b6df`。

## 2026-06-08 追加修复记录（v1.1.41+100）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 审计 macOS 经典蓝牙停止/切换/快速重连路径；未改动 Android keystore，未改动 `applicationId`。
- 根因风险：`openRFCOMMChannelSync` 在后台等待期间，如果用户切换模式或停止蓝牙，旧连接成功后仍可能异步回主线程 `attach(...)`，造成停止后幽灵连接或替换掉较新的连接。
- 修复：新增 `connectionGeneration` 代际保护；每次出站连接和 `stop()` 都递增 generation；后台连接只允许用捕获的 generation 接管通道；过期 attach 会关闭新返回的 RFCOMM channel 并退出。
- TDD 留痕：新增 `macOS rejects stale RFCOMM attach callbacks after stop or replacement connect` 红灯测试，确认旧实现失败后再修复。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart` 通过，共 14 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 198 项通过。
- Android 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.41/Flux-v1.1.41-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=100`，`versionName=1.1.41`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.41/Flux-v1.1.41-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.41`，`CFBundleVersion=100`，`NSBluetoothAlwaysUsageDescription` 存在，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- macOS 安装包复核：挂载 DMG 后确认包内 `Flux.app` 同样为 `1.1.41+100`，包含 `NSBluetoothAlwaysUsageDescription`，并通过 `codesign --verify --deep --strict`。
- macOS 启动烟测：直接启动 release `Flux.app`，8 秒后进程仍存活，`~/Library/Logs/DiagnosticReports` 未产生新的 `Flux-*.ips` 崩溃日志。
- 发布完整性：新增 `/Users/yueliangmanle/flux-send/releases/history/v1.1.41/SHA256SUMS.txt`；Android APK SHA-256 为 `14876c4b15235e431ab02d77d51c7c264ea1319e244d5e9b34ab406ce15e9023`，macOS DMG SHA-256 为 `0cc329a906be20f921f0dced52bab72a10717ec4511dbcaa9dce98ddaf5e001f`。
- 桌面清理：`/Users/yueliangmanle/Desktop` 未发现 `Flux-v*-android.apk` 或 `Flux-v*-macOS.dmg` 残留。

## 2026-06-08 追加修复记录（v1.1.40+99）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 审计 macOS 经典蓝牙连接/断连/重连路径；未改动 Android keystore，未改动 `applicationId`。
- 根因风险：macOS 出站 RFCOMM 打开已经在后台线程执行，但成功后直接在后台线程调用 `attach(...)` 修改 `channel` 与 `receiveBuffer`；同时 RFCOMM data/close delegate 回调也可能跨线程进入，和主线程发送/停止/替换通道操作交错时存在状态竞争。
- 修复：新增 `attachOnMain(...)`，服务端入站和客户端出站连接都回主线程接管通道；`rfcommChannelData` 与 `rfcommChannelClosed` 复制必要数据后回主线程处理；数据处理新增 stale channel guard，旧通道数据不再写入当前接收缓冲。
- TDD 留痕：新增 `macOS serializes RFCOMM attach, data, and close callbacks onto the main thread` 红灯测试，确认旧实现失败后再修复。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart` 通过，共 13 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 197 项通过。
- Android 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.40/Flux-v1.1.40-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=99`，`versionName=1.1.40`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.40/Flux-v1.1.40-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.40`，`CFBundleVersion=99`，`NSBluetoothAlwaysUsageDescription` 存在，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- macOS 安装包复核：挂载 DMG 后确认包内 `Flux.app` 同样为 `1.1.40+99`，包含 `NSBluetoothAlwaysUsageDescription`，并通过 `codesign --verify --deep --strict`。
- macOS 启动烟测：直接启动 release `Flux.app`，8 秒后进程仍存活，`~/Library/Logs/DiagnosticReports` 未产生新的 `Flux-*.ips` 崩溃日志。
- 发布完整性：新增 `/Users/yueliangmanle/flux-send/releases/history/v1.1.40/SHA256SUMS.txt`；Android APK SHA-256 为 `99f256f1c98444732f5242c9c144c24c38897136ad7858a6bbcd10eb1b96a3e5`，macOS DMG SHA-256 为 `7f06b13d3e24fc96680392250c853c44752c7a0f52d4a77211d22ada248bfcf1`。
- 桌面清理：`/Users/yueliangmanle/Desktop` 未发现 `Flux-v*-android.apk` 或 `Flux-v*-macOS.dmg` 残留。

## 2026-06-08 追加修复记录（v1.1.39+98）

- 接手时间：2026-06-08。针对用户真机反馈“电脑端选择蓝牙模式会闪退，然后再也打不开”继续在 `/Users/yueliangmanle/flux-send/app` 修复；未改动 Android keystore，未改动 `applicationId`。
- 根因证据：读取 `~/Library/Logs/DiagnosticReports/Flux-*.ips`，崩溃类型为 `EXC_CRASH SIGABRT`，`termination.namespace = TCC`，系统提示缺少 `NSBluetoothAlwaysUsageDescription`。
- 根因分析：macOS 经典蓝牙 RFCOMM 初始化会访问蓝牙隐私能力；旧包 `Info.plist` 未声明蓝牙用途，macOS TCC 直接强杀。若用户已经把连接模式持久化为蓝牙，旧包启动后会再次触发同一崩溃。
- 修复：在 `macos/Runner/Info.plist` 增加 `NSBluetoothAlwaysUsageDescription`，文案为 `Flux 使用经典蓝牙连接已配对设备，用于无 Wi‑Fi 场景下的剪切板同步。`。
- TDD 留痕：新增 `macOS app declares Bluetooth privacy usage before RFCOMM access` 红灯测试；确认旧实现失败后再补齐 `Info.plist`，随后定向测试转绿。
- 定向验证：`flutter test test/unit/macos_visibility_test.dart` 通过，共 2 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 196 项通过。
- Android 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.39/Flux-v1.1.39-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=98`，`versionName=1.1.39`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/flux-send/releases/history/v1.1.39/Flux-v1.1.39-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.39`，`CFBundleVersion=98`，`NSBluetoothAlwaysUsageDescription` 存在，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- macOS 安装包复核：挂载 DMG 后确认包内 `Flux.app` 同样包含 `NSBluetoothAlwaysUsageDescription`，并通过 `codesign --verify --deep --strict`。
- macOS 启动烟测：直接启动 release `Flux.app`，8 秒后进程仍存活，`~/Library/Logs/DiagnosticReports` 未产生新的 `Flux-*.ips` 崩溃日志。
- 发布完整性：新增 `/Users/yueliangmanle/flux-send/releases/history/v1.1.39/SHA256SUMS.txt`；Android APK SHA-256 为 `2fcf8cdc6d8cf0c10677e693947d915e0c74f8c71ca9fb19f385439e5b143289`，macOS DMG SHA-256 为 `906b25b2586815a466630fa9adc2e50ed3e5e86b488a3f4f8c7c07de3f29f013`。
- 桌面清理：`/Users/yueliangmanle/Desktop` 未发现 `Flux-v*-android.apk` 或 `Flux-v*-macOS.dmg` 残留。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.38+97）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：证书主题、Windows 自启动和 Windows SendTo 右键菜单的旧品牌残留。
- 根因：新生成设备证书的 CN 仍为 `LocalSend User`；Windows 自启动注册表值和 SendTo 快捷方式文件名仍为 `LocalSend`。
- 修复：新生成证书 CN 改为 `Flux User`；Windows 自启动注册表值和 SendTo 快捷方式文件名改为 `Flux`。未改动 Windows 旧设置路径，避免已有设置丢失。
- TDD 留痕：新增 `flux_integration_branding_test.dart` 红灯测试，确认旧品牌常量失败后再修复。
- 定向验证：`flutter test test/unit/util/security_helper_test.dart test/unit/flux_integration_branding_test.dart` 已通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 195 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.38-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=97`，`versionName=1.1.38`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.38-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.38`，`CFBundleVersion=97`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.37+96）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：用户可见英文残留、Flux 品牌残留、语言页标题/加载占位和 Windows 故障排查命令。
- 根因：部分 fork 后 UI 文案仍保留英文或 LocalSend：复制提示为 `Copied ... to clipboard!`，启动错误页为 `LocalSend: Error`，语言页标题误用发送选择页标题，语言名加载占位为 `Loading`，防火墙命令规则名为 `LocalSend`。
- 修复：复制提示改为中文；启动错误页改为 Flux 品牌和中文错误标签；语言页标题改为“语言”并使用 `加载中` 占位；防火墙规则名改为 `Flux`。
- TDD 留痕：新增复制提示汉化、启动错误页品牌、故障排查命令名、语言页标题/加载占位三组红灯测试，确认旧实现失败后再修。
- 定向验证：`flutter test test/unit/language_page_localization_test.dart test/unit/flux_branding_localization_test.dart test/unit/copyable_text_localization_test.dart` 已通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 192 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.37-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=96`，`versionName=1.1.37`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.37-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.37`，`CFBundleVersion=96`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.36+95）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：手动地址输入对 IPv6 / 括号 IPv6 / 默认识别码模式的兼容性。
- 根因：默认“识别码”模式下 `looksLikeFullAddressInput(...)` 漏识别 IPv6；输入 `[fe80::1]:25565` 或 `fe80::1` 会被当作识别码尾号拼接。
- 修复：新增 `_looksLikeIpv6AddressInput(...)`，支持 `[IPv6]:port` 和裸 IPv6 字面量识别；完整 IPv6 地址直接进入 `parseAddressInput(...)`。
- TDD 留痕：新增 IPv6 手动地址解析与默认模式完整地址识别红灯测试，覆盖 `[fe80::1]:25565` 和 `fe80::1`。
- 定向验证：`flutter test test/unit/util/address_input_parser_test.dart` 已通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 188 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.36-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=95`，`versionName=1.1.36`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.36-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.36`，`CFBundleVersion=95`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.35+94）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：手动地址、发现地址和剪切板 HTTP 发送 URI 构造，重点看 IPv6 / 主机名 / 端口组合是否会被字符串拼坏。
- 根因：`_sendToDevice(...)` 用 `'$scheme://$ip:$port/api/clipboard'` 手写拼接 URL；IPv6 地址需要 `[]` 包裹，手写拼接会生成非法 URI。
- 修复：新增 `buildClipboardSyncUri(...)`，统一使用 `Uri(scheme, host, port, path)` 构造剪切板接收接口地址；`_sendToDevice(...)` 改为直接 `client.postUrl(url)`。
- TDD 留痕：新增 `clipboard sender builds valid URIs for IPv4 hostnames and IPv6 addresses` 红灯测试，覆盖 IPv4、`.local` 主机名和 IPv6。
- 定向验证：`flutter test test/unit/provider/clipboard_sync_provider_test.dart` 已通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 187 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.35-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=94`，`versionName=1.1.35`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.35-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.35`，`CFBundleVersion=94`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.34+93）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：剪切板接收侧去重逻辑，重点检查远端重复文本和本地剪切板已分叉后的覆盖行为。
- 根因：接收远端剪切板时只判断 `text == _lastRemoteText`；如果本机已经复制了不同内容，远端再次发送旧文本仍会被当作重复包忽略。
- 修复：新增 `shouldWriteIncomingClipboard(...)` 并接入 `handleIncomingClipboard(...)`；只有“远端文本相同且本地最后文本也仍相同”才跳过，否则重新写入系统剪切板。
- TDD 留痕：新增 `accepts repeated remote clipboard text after the local clipboard diverged` 红灯测试；确认旧实现失败后实现转绿，并把暂停状态下重复文本测试改为验证新 helper 执行顺序。
- 定向验证：`flutter test test/unit/provider/clipboard_sync_provider_test.dart` 已通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 186 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.34-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=93`，`versionName=1.1.34`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.34-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.34`，`CFBundleVersion=93`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.33+92）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：剪切板自动同步状态机、远端回声抑制、经典蓝牙 negative-send 后是否会形成假连接或漏重连。
- 根因 1：远端剪切板写入后 `_suppressNext` 只在“下一次轮询文本等于远端文本”时清理；如果用户先复制不同文本，抑制标记不清理，之后再次复制回远端文本会被误吞。
- 修复 1：新增 `shouldClearRemoteClipboardEchoSuppression(...)` 并接入 `_checkClipboard()`，本地复制不同文本时立即解除远端回声抑制，再正常同步。
- 根因 2：经典蓝牙原生发送返回 `false` 时，Dart 层只记录“经典蓝牙发送未确认”；如果原生错误事件延迟或丢失，可能短暂保留 stale connected state，自动重连不会立即排队。
- 修复 2：将“经典蓝牙发送未确认 / 经典蓝牙未连接 / 无法发送剪切板”归类为断链错误，`applyClassicBluetoothSendFailure(...)` 会立即清空连接地址和 connected 状态，并触发已有自动重连队列。
- TDD 留痕：新增剪切板回声抑制清理红灯测试和经典蓝牙 negative-send 假连接红灯测试，均先确认旧实现失败，再实现转绿。
- 定向验证：`flutter test test/unit/provider/classic_bluetooth_provider_test.dart test/unit/provider/clipboard_sync_provider_test.dart` 已通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 185 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.33-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=92`，`versionName=1.1.33`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.33-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.33`，`CFBundleVersion=92`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.32+91）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：状态卡和发现日志里是否仍有英文、技术化文本，避免用户看到“半汉化”或误以为扫描逻辑没做完。
- 根因：UDP 发现路径仍写 `[DISCOVER/UDP] ...`，收到 `/register` 请求时仍写 `Received "/register" HTTP request...`，和 v1.1.31 新增的 TCP 扫描完成/失败中文日志不一致。
- 修复：新增 `describeMulticastDeviceDiscovered(...)` 和 `describeRegisterRequestReceived(...)`，并替换 `StartMulticastListener` 与 `ReceiveController` 的日志源头。
- TDD 留痕：新增 `UDP discovery and incoming register logs are Chinese` 红灯测试，先确认旧实现缺中文日志函数，再实现转绿。
- 定向验证：`flutter test test/unit/provider/nearby_scan_failure_test.dart test/unit/provider/nearby_devices_provider_test.dart` 已通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 183 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.32-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=91`，`versionName=1.1.32`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.32-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.32`，`CFBundleVersion=91`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.31+90）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：经典蓝牙常驻连接体验、断线后是否自动恢复、LAN/热点刷新扫描后是否有完整反馈。
- 根因 1：经典蓝牙断开后 Dart 层只重启监听，没有记住上次设备并主动重连；连接超时或 MethodChannel 连接失败后也不会排队重连，导致“常驻连接”仍像一次性连接。
- 修复 1：`ClassicBluetoothService` 记住上次已连接/手动连接设备，非手动停止且非 dispose 时进入有界自动重连；退避节奏为 2s/5s/10s/15s，连接成功后清零，手动停止时取消。
- 根因 2：TCP 扫描日志只有开始和发现设备，扫空或失败时没有最终状态，用户看到状态卡容易误判为“扫描按钮没反应”。
- 修复 2：`StartLegacyScan` 增加中文扫描开始、发现设备、扫描完成/未发现/失败日志；失败路径仍清理 running subnet，避免 UI 一直显示扫描中。
- TDD 留痕：新增经典蓝牙自动重连 gating/backoff/超时队列测试；新增 TCP 扫描完成与失败中文日志测试。
- 定向验证：`flutter test test/unit/provider/classic_bluetooth_provider_test.dart` 已通过；`flutter test test/unit/provider/nearby_scan_failure_test.dart test/unit/provider/nearby_devices_provider_test.dart test/unit/provider/scan_facade_test.dart` 已通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 182 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.31-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=90`，`versionName=1.1.31`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.31-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.31`，`CFBundleVersion=90`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.30+89）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：经典蓝牙连接/重连路径，重点看失败后资源清理，避免“连接失败后再次连接更不稳定”。
- 根因：Android 出站连接中 `device.createRfcommSocketToServiceRecord(...)` 创建的 `nextSocket` 如果在 `connect()` 抛异常，会直接进入 catch 发出“经典蓝牙连接失败”，但未关闭这个新建 socket；这会留下半开 RFCOMM socket，增加后续重连失败、断连假状态和蓝牙栈异常概率。
- 修复：`connect(...)` 中把 `nextSocket` 提前声明为 `BluetoothSocket?`，成功 `attachSocket(nextSocket, "client")` 后置空；catch 中调用 `closeQuietly(nextSocket)`，只释放尚未 attach 的失败 socket，不误关已接管的活动 socket。
- TDD 留痕：先新增 `Android closes a newly created outbound RFCOMM socket when connect fails` 红灯测试，确认旧实现没有失败关闭路径；修复后调整为验证 `nextSocket` 声明、创建、attach、成功置空、catch 关闭的顺序。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart` 通过，共 12 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 178 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.30-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=89`，`versionName=1.1.30`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.30-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.30`，`CFBundleVersion=89`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.29+88）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：经典蓝牙剪切板链路，重点看 Android 与 macOS 的 RFCOMM 发送行为是否一致，避免一个方向长文本稳定、另一个方向仍然整包写。
- 根因：v1.1.28 只修了 macOS 分块写；Android `ClassicBluetoothBridge.sendClipboard(...)` 仍用 `activeSocket.outputStream.write(payload.toByteArray(Charsets.UTF_8))` 一次性写完整 JSON payload，长剪切板在经典蓝牙 socket 上仍可能阻塞或断链。
- 修复：Android 原生发送新增 `maxWriteChunkSize = 8192`，先生成 `bytes`，再通过 `while (offset < bytes.size)` 循环 `write(bytes, offset, chunkSize)`；发送完成后统一 `flush()`，换行帧协议保持不变。
- TDD 留痕：先新增 `Android sends classic Bluetooth clipboard payloads in bounded RFCOMM chunks` 红灯测试，确认旧实现缺少 `maxWriteChunkSize` 且存在整包 `payload.toByteArray(...)` 写入；实现后定向测试转绿。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart` 通过，共 11 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 177 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.29-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=88`，`versionName=1.1.29`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.29-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.29`，`CFBundleVersion=88`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.28+87）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：经典蓝牙剪切板链路，重点检查 macOS ↔ Android 中较长剪切板文本、大 JSON payload 和 RFCOMM 写入边界。
- 根因：macOS `ClassicBluetoothBridge.sendClipboard(...)` 将完整 payload 一次性写入 `IOBluetoothRFCOMMChannel.writeSync(...)`，并用 `UInt16(buffer.count)` 作为长度；超过 64KB 会直接失败，较长文本单次写也不利于 RFCOMM 稳定性。
- 修复：macOS 原生发送改为 `maxWriteChunkSize = 8192` 循环分块写，任一分块失败立刻返回错误；接收端仍按换行聚合完整 JSON，协议不变。
- 编译修复留痕：macOS release 构建先暴露 Swift 独占访问错误；改为缓存 `totalBytes` 后又暴露 `writeSync` 参数必须是可变 raw pointer。最终使用 `withUnsafeMutableBufferPointer` 提供可变指针，同时闭包内只读 `totalBytes`，避免再次触发独占访问。
- TDD 留痕：新增 macOS bounded RFCOMM chunk 红灯测试；确认旧实现缺少分块写并存在 `UInt16(buffer.count)` 后实现转绿；随后加上“分块循环不得继续读取 `bytes.count`”回归约束。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart` 通过，共 10 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 176 项通过。
- Android 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.28-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=87`，`versionName=1.1.28`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.28-macOS.dmg`，大小约 61 MB。
- macOS 校验：`CFBundleShortVersionString=1.1.28`，`CFBundleVersion=87`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。

## 2026-06-08 追加修复记录（v1.1.27+86）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 继续审计范围：手动 IP、经典蓝牙剪切板、接收端保存失败/上传卡住三条用户高频痛点链路。
- 根因 1：地址输入弹窗默认识别码模式下，完整 `IP:port` 会走识别码拼接路径，容易把 `10.113.15.240:25565` 当成尾号拼到本机网段后再注册，造成无法解析或连接失败。
- 修复 1：`looksLikeFullAddressInput(...)` 自动识别 IPv4 / URL / 域名直连地址；即使用户没切到 IP 模式，完整地址也直接按 host/port 解析。
- 根因 2：经典蓝牙发送失败时未把 socket 类失败统一收敛成断开，UI 和剪切板服务可能继续认为链路已连接，形成假连接。
- 修复 2：`applyClassicBluetoothSendFailure(...)` 复用断链错误分类，遇到 broken pipe / socket closed / connection reset / macOS 数字错误码后清空连接状态和地址。
- 根因 3：接收端保存失败后未消费完上传请求体，发送端可能收到空错误或接收端长时间看起来卡在“正在接收”。
- 修复 3：上传保存异常后先 `request.drain<void>().timeout(const Duration(seconds: 2))`，再返回 `describeReceiveUploadFailure(...)` 的明确中文错误。
- TDD 留痕：先新增手动地址、经典蓝牙发送失败状态、上传失败 drain 三组红灯测试；确认失败后实现并转绿。
- 定向验证：`flutter test test/unit/util/address_input_parser_test.dart test/unit/provider/classic_bluetooth_provider_test.dart test/unit/provider/clipboard_incoming_failure_test.dart` 通过，共 28 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 175 项通过；Android release APK 与 macOS release DMG 均已构建并校验。
- 发布产物：`~/Desktop/Flux-v1.1.27-android.apk`（127M）、`~/Desktop/Flux-v1.1.27-macOS.dmg`（61M）。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=86`，`versionName=1.1.27`，签名 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 校验：`CFBundleShortVersionString=1.1.27`，`CFBundleVersion=86`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.26+85）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环修复；未改动 Android keystore，未改动 `applicationId`。
- 卡点留痕：上一轮被一次从 `/Users/yueliangmanle/trance` 发起的广域 `find .. -name AGENTS.md` 卡住，已停止该扫描；后续只在 Flux 工程范围内检查，避免再扫用户主目录。
- 根因 1：Android 12+ 经典蓝牙服务端启动需要 `BLUETOOTH_ADVERTISE`，旧逻辑只请求/检查了连接等权限；真机上可能 UI 进入蓝牙模式，但 RFCOMM server socket 实际无法创建。
- 修复 1：`requestAndroidNetworkPermissions()` 新增 `Permission.bluetoothAdvertise.request()`；Android `ClassicBluetoothBridge.startServer()` 在 `listenUsingRfcommWithServiceRecord(...)` 前检查 `BLUETOOTH_ADVERTISE`，缺失时返回失败并发出中文错误。
- 根因 2：经典蓝牙链路断开后，Android/macOS 发送侧常见错误是 `broken pipe`、`socket closed`、`connection reset`、`connection refused`、`not connected` 或 macOS IOBluetooth 数字错误码；旧状态层未统一识别，可能保留假连接，随后重连/发送进入异常状态。
- 修复 2：`shouldTreatClassicBluetoothErrorAsDisconnect(...)` 增加错误消息分类，连接中失败和已连接后的 socket 类发送失败都收敛为真实断连。
- TDD 留痕：新增 Android manifest/启动权限/原生监听权限源码测试，以及经典蓝牙 socket 错误断连分类测试；已先确认红灯再实现转绿。
- 定向验证：`flutter test test/unit/android_multicast_discovery_test.dart test/unit/provider/classic_bluetooth_provider_test.dart` 通过，共 19 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 172 项通过；Android release APK 与 macOS release DMG 均已构建并校验。
- 发布产物：`~/Desktop/Flux-v1.1.26-android.apk`（127M）、`~/Desktop/Flux-v1.1.26-macOS.dmg`（61M）。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=85`，`versionName=1.1.26`，签名 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 校验：`CFBundleShortVersionString=1.1.26`，`CFBundleVersion=85`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。
- 构建备注：Android 构建仍有 Gradle/AGP/Kotlin 未来版本兼容性警告，macOS 构建仍有 `photo_manager` 的 `PrivacyInfo.xcprivacy` 资源处理警告；本轮未扩散升级依赖，避免引入额外变量。

## 2026-06-08 追加修复记录（v1.1.25+84）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 循环排查；未改动 Android keystore，未改动 `applicationId`。
- 根因 1：后台 TCP fallback 扫描完成后只刷新在线设备数量，没有通知剪切板同步服务；如果用户已经复制了内容，扫描刚发现设备时不会立刻补发，常要等下一轮 5 秒定时器，真机体验像“发现了但不同步”。
- 修复 1：`ClipboardSyncService` 订阅 `nearbyDevicesProvider` 状态变化，发现新的可达设备端点后调用 `notifyDeviceRegistered()`，pending 剪切板会立即进入补发队列。
- 根因 2：只用设备数量判断发现变化会漏掉端口 fallback / 协议 / IP 更新；设备仍是同一台但有效 HTTP 端点变了，旧逻辑不会立即重试。
- 修复 2：新增 `shouldWakeClipboardAfterNearbyDevicesChange(...)`，以 `fingerprint|ip|port|https` 可达端点集合判断变化；同一设备端口变更也会唤醒 pending。
- 根因 3：手动刷新扫描会先清空旧设备列表；如果把“端点集合变化”简单等同于唤醒，会在清空阶段过早触发一次无意义重试。
- 修复 3：当新的可达端点集合为空时不唤醒；等真实发现到非空端点后再触发补发。
- TDD 留痕：先新增“后台 TCP 发现后唤醒 pending”“设备注册路径唤醒”“端点变化也唤醒”“刷新清空不误触发”等红灯测试；确认失败后实现并转绿。
- 定向验证：`flutter test test/unit/provider/nearby_devices_provider_test.dart test/unit/provider/clipboard_background_discovery_test.dart` 通过，共 13 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 全量 170 项通过；Android release APK 与 macOS release DMG 均已构建并校验。
- 发布产物：`~/Desktop/Flux-v1.1.25-android.apk`（127M）、`~/Desktop/Flux-v1.1.25-macOS.dmg`（61M）。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=84`，`versionName=1.1.25`，签名 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 校验：`CFBundleShortVersionString=1.1.25`，`CFBundleVersion=84`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。

## 2026-06-08 追加修复记录（v1.1.24+83）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 处理；未改动 Android keystore，未改动 `applicationId`。
- 继续循环排查：不把 v1.1.23 当终点，继续审计常驻剪切板补发、局域网/热点多目标同步、经典蓝牙连接后 pending 唤醒。
- 根因 1：局域网 / 热点剪切板同步多个目标时，只要有一台设备成功，旧逻辑就调用 `resolvePendingClipboardAfterSuccessfulSend(...)` 清空 pending；失败设备后续即使恢复在线，也不会收到这次复制内容。
- 修复 1：新增 `resolvePendingClipboardAfterSendAttempt(...)`；只有 `successCount == attemptedCount` 时才清空 pending，部分成功会保留当前剪切板并显示 `已同步到 x/y 台设备，失败设备稍后自动重试`。
- 根因 2：保留 pending 后，旧 finally 逻辑会因为 pending 仍等于当前文本而立刻递归重试；失败设备离线时可能形成无间隔重试风暴。
- 修复 2：`shouldRetryPendingClipboardAfterSend(...)` 增加 `retryQueuedDuringSend` 参数；同一文本失败不立即递归，等待正常 5 秒发现/重试定时器，只有新剪切板或设备注册唤醒才立即重试。
- 根因 3：经典蓝牙 RFCOMM `connected` 事件只更新蓝牙状态，没有通知剪切板同步服务；如果用户先复制、再连接蓝牙，需要等下一轮定时器才可能补发，体验像“连上了但剪切板不动”。
- 修复 3：经典蓝牙 `connected` 分支调用 `clipboardSyncProvider.notifyDeviceRegistered()`，连接成为真实链路后立即补发 pending 剪切板。
- TDD 留痕：先新增“部分成功保留 pending”“同文本失败不立即递归，队列唤醒才立即重试”“蓝牙 connected 唤醒 pending”红灯测试；确认失败后实现并转绿。
- 定向验证：`flutter test test/unit/provider/classic_bluetooth_provider_test.dart test/unit/provider/clipboard_sync_provider_test.dart` 通过，共 29 项通过。
- 全量验证：`flutter analyze` 通过；`flutter test` 全量 166 项通过；Android release APK 与 macOS release DMG 均已构建并校验。
- 发布产物：`~/Desktop/Flux-v1.1.24-android.apk`（127M）、`~/Desktop/Flux-v1.1.24-macOS.dmg`（61M）。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=83`，`versionName=1.1.24`，签名 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 校验：`CFBundleShortVersionString=1.1.24`，`CFBundleVersion=83`，`codesign --verify --deep --strict` 通过，`hdiutil verify` 通过。

## 2026-06-08 追加修复记录（v1.1.23+82）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 处理；未改动 Android keystore，未改动 `applicationId`。
- 继续循环排查：不把 v1.1.22 当终点，重点审计常驻剪切板、局域网/热点发现、连接模式切换和经典蓝牙状态清理。
- 根因 1：局域网 / 热点剪切板同步到已发现设备失败时，发送循环吞掉每台设备的异常，只在 UI 显示“未能同步到任何设备”，用户无法判断是接收端暂停、保存失败、IP 不通还是端口错误。
- 修复 1：新增 `describeClipboardPeerSendFailure(...)` 和 `describeClipboardSyncFailureSummary(...)`；同步失败时保留目标别名、IP 和接收端具体错误，状态卡会显示可排障原因。
- 根因 2：状态卡切换连接模式会启动扫描/蓝牙监听，但设置页的“连接模式”只写入持久化配置，不触发真实 UDP/TCP 扫描、蓝牙监听或蓝牙停止。
- 修复 2：抽出 `switchFluxConnectionMode(...)`，状态卡和设置页共用同一条真实切换链路；切到局域网/热点会清空旧发现并触发 `StartSmartScan(forceLegacy: true)`，切到经典蓝牙会启动 RFCOMM 监听并刷新已配对设备。
- 根因 3：从经典蓝牙切回局域网/热点时没有停止原生 RFCOMM 监听，可能保留后台 socket、旧断连事件和混乱状态。
- 修复 3：`switchFluxConnectionMode(...)` 在确认上一模式是经典蓝牙且 provider 已初始化时调用 `classicBluetoothProvider.stop()`，避免普通局域网/热点切换时无谓初始化蓝牙 provider。
- TDD 留痕：先新增逐设备剪切板失败摘要、设置页/状态卡共享真实切换副作用、切出蓝牙停止 RFCOMM 监听等红灯测试；确认失败后实现并转绿。
- 定向验证：`flutter test test/unit/flux_connection_status_card_test.dart test/unit/provider/classic_bluetooth_provider_test.dart test/unit/provider/connection_mode_provider_test.dart test/unit/provider/clipboard_sync_provider_test.dart` 通过，共 32 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 通过，共 164 项通过。
- Android 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build apk --release` 通过，生成 `build/app/outputs/flutter-apk/app-release.apk`。
- Android 产物：已复制到 `/Users/yueliangmanle/Desktop/Flux-v1.1.23-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=82`，`versionName=1.1.23`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build macos --release` 通过，生成 `build/macos/Build/Products/Release/Flux.app`。
- macOS 产物：已 ad-hoc 重新签名并打包到 `/Users/yueliangmanle/Desktop/Flux-v1.1.23-macOS.dmg`，大小约 61 MB。
- macOS 校验：`codesign --verify --deep --strict` 通过，`hdiutil verify /Users/yueliangmanle/Desktop/Flux-v1.1.23-macOS.dmg` 通过；`CFBundleShortVersionString=1.1.23`，`CFBundleVersion=82`。

## 2026-06-08 追加修复记录（v1.1.22+81）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 处理；未改动 Android keystore，未改动 `applicationId`。
- 继续循环排查：v1.1.21 已让接收端拒绝未选保存目录的普通文件请求，但发送端仍会把该错误显示成 `[409] 请先在接收端 Flux...`。
- 根因：发送端 `describeSendFailure(...)` 只对权限/SAF/保存失败类错误做中文翻译；接收目录缺失的 409 虽然已经是中文指导，但仍被统一加上 HTTP 状态码前缀。
- 修复：发送端识别“请先在接收端 Flux”且包含“保存目录”的接收端指导，直接原样展示，不再添加 `[409]`。
- TDD 留痕：先新增 `sender shows missing Android receive folder guidance without HTTP noise` 红灯测试；确认旧输出包含 `[409]` 后实现修复并转绿。
- 定向验证：`flutter test test/unit/provider/clipboard_incoming_failure_test.dart test/unit/util/receive_destination_policy_test.dart test/unit/util/receive_error_message_test.dart` 通过，共 12 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 通过，共 161 项通过。
- Android 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build apk --release` 通过，生成 `build/app/outputs/flutter-apk/app-release.apk`。
- Android 产物：已复制到 `/Users/yueliangmanle/Desktop/Flux-v1.1.22-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=81`，`versionName=1.1.22`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build macos --release` 通过，生成 `build/macos/Build/Products/Release/Flux.app`。
- macOS 产物：已 ad-hoc 重新签名并打包到 `/Users/yueliangmanle/Desktop/Flux-v1.1.22-macOS.dmg`，大小约 61 MB。
- macOS 校验：`codesign --verify --deep --strict` 通过，`hdiutil verify /Users/yueliangmanle/Desktop/Flux-v1.1.22-macOS.dmg` 通过；`CFBundleShortVersionString=1.1.22`，`CFBundleVersion=81`。

## 2026-06-08 追加修复记录（v1.1.21+80）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 处理；未改动 Android keystore，未改动 `applicationId`。
- 继续循环排查：v1.1.20 已修正 Android 保存目录显示，但实际 prepare-upload 仍会在 `settings.destination == null` 时调用 `getDefaultDestinationDirectory()`。
- 根因：Android `getDefaultDestinationDirectory()` 使用 `path_provider.getExternalStorageDirectory()`，该目录可能是应用私有外部目录；普通文件 quick-save 或手动接收成功后，用户可能在 Download/下载里找不到文件，误以为权限无效或传输失败。
- 修复：新增 `shouldRequireExplicitReceiveDirectory(...)`；Android 未显式选择目录时，普通文件、文件夹、非图片/视频或关闭相册保存的接收请求会在 prepare-upload 阶段返回 409，并提示先选择 Download/下载目录。
- 保留例外：Android 图片/视频且启用“保存到相册”时可继续不选目录，因为保存链路走相册，不依赖公共 Download。
- TDD 留痕：先新增 `receive_destination_policy_test.dart` 红灯测试，确认缺少策略；实现后定向测试转绿。
- 定向验证：`flutter test test/unit/util/receive_destination_policy_test.dart test/unit/util/destination_display_label_test.dart test/unit/android_saf_directory_permission_test.dart test/unit/util/receive_error_message_test.dart test/unit/provider/clipboard_incoming_failure_test.dart` 通过，共 15 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 通过，共 160 项通过。
- Android 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build apk --release` 通过，生成 `build/app/outputs/flutter-apk/app-release.apk`。
- Android 产物：已复制到 `/Users/yueliangmanle/Desktop/Flux-v1.1.21-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=80`，`versionName=1.1.21`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build macos --release` 通过，生成 `build/macos/Build/Products/Release/Flux.app`。
- macOS 产物：已 ad-hoc 重新签名并打包到 `/Users/yueliangmanle/Desktop/Flux-v1.1.21-macOS.dmg`，大小约 61 MB。
- macOS 校验：`codesign --verify --deep --strict` 通过，`hdiutil verify /Users/yueliangmanle/Desktop/Flux-v1.1.21-macOS.dmg` 通过；`CFBundleShortVersionString=1.1.21`，`CFBundleVersion=80`。

## 2026-06-08 追加修复记录（v1.1.20+79）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 处理；未改动 Android keystore，未改动 `applicationId`。
- 继续循环排查：没有把 v1.1.19 当终点，转向用户此前反复提到的 Android 文件接收“权限给了还是没用 / 目录不知道在哪里”的真机体验。
- 根因：Android 设置页未设置接收目录时显示 i18n 文案“(下载)”，但代码里的 `getDefaultDestinationDirectory()` 在 Android 使用 `path_provider.getExternalStorageDirectory()`，它可能指向应用私有外部目录，不等同于公共 Download；这会误导用户以为已经选择/授权了 Download。
- 根因：用户通过 SAF 选择目录后，设置页直接显示原始 `content://com.android.externalstorage.documents/tree/...`，不利于判断当前到底授权了哪个目录。
- 修复：新增 `describeDestinationDisplayLabel(...)`；Android 未设置目录时显示“未设置保存目录（点此选择 Download/下载目录）”，已选择 SAF 目录时显示可读目录名，如 `Download` 或 `Download/Flux`；桌面平台保持原先默认下载目录显示。
- TDD 留痕：先新增 `destination_display_label_test.dart` 红灯测试，确认缺少显示逻辑；实现后定向测试转绿。
- 定向验证：`flutter test test/unit/util/destination_display_label_test.dart test/unit/android_saf_directory_permission_test.dart test/unit/util/receive_error_message_test.dart` 通过，共 5 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 通过，共 155 项通过。
- Android 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build apk --release` 通过，生成 `build/app/outputs/flutter-apk/app-release.apk`。
- Android 产物：已复制到 `/Users/yueliangmanle/Desktop/Flux-v1.1.20-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=79`，`versionName=1.1.20`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build macos --release` 通过，生成 `build/macos/Build/Products/Release/Flux.app`。
- macOS 产物：已 ad-hoc 重新签名并打包到 `/Users/yueliangmanle/Desktop/Flux-v1.1.20-macOS.dmg`，大小约 61 MB。
- macOS 校验：`codesign --verify --deep --strict` 通过，`hdiutil verify /Users/yueliangmanle/Desktop/Flux-v1.1.20-macOS.dmg` 通过；`CFBundleShortVersionString=1.1.20`，`CFBundleVersion=79`。

## 2026-06-08 追加修复记录（v1.1.19+78）

- 接手时间：2026-06-08。继续在 `/Users/yueliangmanle/flux-send/app` 处理；未改动 Android keystore，未改动 `applicationId`。
- 根因：v1.1.18 新增 `notifyDeviceRegistered()` 后，如果设备注册唤醒发生在 `_sendToAllPeers(...)` 正在执行期间，后续重试调用会被 `_syncing` 防重入保护直接 return，导致“发现/注册成功后立即重试 pending 剪切板”的唤醒被吞掉。
- 修复：`ClipboardSyncService` 新增 `_retryAfterCurrentSync`；当注册唤醒或发送中重复同步请求发生在 `_syncing=true` 时，先排队，当前同步 `finally` 结束后立即用最新 `_pendingText` 再跑一次。
- 状态反馈：注册唤醒被排队时显示“已发现新设备，当前同步结束后会立即重试剪切板”，便于后续真机日志判断链路是否进入队列。
- TDD 留痕：先新增 `device registration wakeup queues retry while a clipboard send is already running` 红灯测试，确认旧实现缺少排队重试语义；实现后定向测试转绿。
- 定向验证：`flutter test test/unit/provider/clipboard_sync_provider_test.dart test/unit/manual_address_registers_device_test.dart test/unit/provider/clipboard_incoming_failure_test.dart` 通过，共 27 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 通过，共 152 项通过。
- Android 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build apk --release` 通过，生成 `build/app/outputs/flutter-apk/app-release.apk`。
- Android 产物：已复制到 `/Users/yueliangmanle/Desktop/Flux-v1.1.19-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=78`，`versionName=1.1.19`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build macos --release` 通过，生成 `build/macos/Build/Products/Release/Flux.app`。
- macOS 产物：已 ad-hoc 重新签名并打包到 `/Users/yueliangmanle/Desktop/Flux-v1.1.19-macOS.dmg`，大小约 61 MB。
- macOS 校验：`codesign --verify --deep --strict` 通过，`hdiutil verify /Users/yueliangmanle/Desktop/Flux-v1.1.19-macOS.dmg` 通过；`CFBundleShortVersionString=1.1.19`，`CFBundleVersion=78`。

## 2026-06-08 追加修复记录（v1.1.18+77）

- 接手时间：2026-06-08 03:16 CST。继续在 `/Users/yueliangmanle/flux-send/app` 处理，未改动 Android keystore，未改动 `applicationId`。
- 继续循环排查：没有把 v1.1.17 打包结果当终点，重新核对手动 IP、收藏设备、服务端 `/register`、剪切板 pending 重试、发现/端口 fallback 和蓝牙状态路径。
- 根因：手动输入 IP 或最近设备连接成功后，虽然设备被注册进 `nearbyDevicesProvider`，但剪切板同步服务只靠 5 秒定时器刷新在线设备数/重试 `_pendingText`；用户会看到“连接成功/已加入设备”，但复制内容不一定立刻同步。
- 修复：`ClipboardSyncService` 新增 `notifyDeviceRegistered()`；手动 IP 注册成功后立即刷新在线设备数，并在有 pending 剪切板时主动重试发送。
- 根因：收藏设备连接成功也只注册设备，不会唤醒剪切板同步服务，表现与手动 IP 一样。
- 修复：`FavoritesDialog` 在 `RegisterDeviceAction(device)` 后调用 `notifyDeviceRegistered()`。
- 根因：远端主动通过 `/register` 登记到本机时，本机虽然记录了对方设备，但也不会唤醒本机剪切板同步；这会让“手机扫描到电脑并发起登记后，电脑端没有立即显示可同步/剪切板不动”的体验变差。
- 修复：`ReceiveController._registerHandler(...)` 在记录对方设备后调用 `clipboardSyncProvider.notifyDeviceRegistered()`。
- TDD 留痕：先新增手动 IP、收藏设备、入站 `/register` 唤醒剪切板同步的红灯测试；确认失败后实现修复，再跑定向测试转绿。
- 定向验证：`flutter test test/unit/provider/clipboard_incoming_failure_test.dart test/unit/manual_address_registers_device_test.dart test/unit/provider/clipboard_sync_provider_test.dart` 通过，共 26 项通过。
- 静态检查：`flutter analyze` 通过，输出 `No issues found!`。
- 全量验证：`flutter test` 通过，共 151 项通过。
- Android 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build apk --release` 通过，生成 `build/app/outputs/flutter-apk/app-release.apk`。
- Android 产物：已复制到 `/Users/yueliangmanle/Desktop/Flux-v1.1.18-android.apk`，大小约 127 MB。
- Android 校验：包名 `org.localsend.localsend_app`，`versionCode=77`，`versionName=1.1.18`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`。
- macOS 构建：`RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup flutter build macos --release` 通过，生成 `build/macos/Build/Products/Release/Flux.app`。
- macOS 产物：已 ad-hoc 重新签名并打包到 `/Users/yueliangmanle/Desktop/Flux-v1.1.18-macOS.dmg`，大小约 61 MB。
- macOS 校验：`codesign --verify --deep --strict` 通过，`hdiutil verify /Users/yueliangmanle/Desktop/Flux-v1.1.18-macOS.dmg` 通过；`CFBundleShortVersionString=1.1.18`，`CFBundleVersion=77`。

## 2026-06-08 追加修复记录（v1.1.9+68）

- 发现问题：Classic Bluetooth 原生发送方法原先只要方法调用完成就返回成功，真实 RFCOMM 写入失败时上层仍可能显示“已同步”。
- 修复：Dart/Android/macOS 蓝牙桥统一返回 `bool` ACK；`ClassicBluetoothService.sendClipboard` 只在 ACK 为 true 时标记成功，否则保留待同步文本等待重试。
- 发现问题：macOS `rfcommChannelData` 原先直接把每次回调当完整消息，遇到半包/粘包时可能 JSON 解析失败或剪切板内容异常。
- 修复：macOS 增加 `receiveBuffer`，按 `\n` 分帧后解析完整 JSON 行；非 Flux 消息走普通 message 事件。
- 发现问题：macOS RFCOMM `writeSync` 长度参数是 `UInt16`，超大剪切板可能超长失败但 UI 不清楚。
- 修复：写入前检查 `bytes.count <= UInt16.max`，超限时返回失败并显示“经典蓝牙剪切板过大”。
- 发现问题：Android 读循环异常和 finally 都可能发断线事件，日志/状态容易重复跳动。
- 修复：读循环统一收敛断开消息，清理 active socket 后只发一次 `disconnected`。
- 验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart` 通过；`flutter test` 全量 121 项通过；`flutter analyze` 无 issues。
## 2026-06-08 追加修复记录（v1.1.10+69）

- 接手确认：实际发布源为 `/Users/yueliangmanle/flux-send/app`；`/Users/yueliangmanle/trance` 只是当前 Codex 工作目录外壳，不是本轮发包源。
- 根因：`connectClassicBluetoothDevice` 原生方法只是提交连接请求，Dart 端旧逻辑会立即把 `connecting=false` 并显示类似“连接已发起”的文案，用户容易误解为链路已成。
- 修复：`ClassicBluetoothService.connect()` 改为保持 `connecting=true`，只在原生 `connected`/`error`/`disconnected` 或 18 秒超时后结束连接中状态。
- 根因：macOS 原生 RFCOMM connect 可能同步等待；如果超时器放在 `await connectClassicBluetoothDevice(...)` 后面，UI 会一直干等。
- 修复：连接超时器提前到原生调用前启动，超时文案明确提示检查系统配对、蓝牙开启和另一端 Flux 是否保持打开。
- 根因：蓝牙发送失败会发 `error` 事件，旧 Dart 事件处理把所有 `error` 都当连接失败，导致剪切板发送失败也可能被显示成断连。
- 修复：新增 `shouldTreatClassicBluetoothErrorAsDisconnect(...)`，仅连接阶段错误清理连接；已连接状态下的发送错误保留链路并让剪切板同步自动重试。
- 根因：服务端收到入站 RFCOMM 连接时，`connected` 事件没有远端地址，电脑端无法把具体配对设备标记为已连接。
- 修复：Android/macOS 原生 `connected` 事件加入远端 `address`/`name`/`role`；Dart 收到后更新 `connectedAddress`。
- TDD 留痕：先新增失败测试验证“不能把发起连接当成功”“发送错误不等于断连”“连接事件必须带远端身份”，再实现并跑定向测试转绿。
- 验证：`flutter test` 全量 126 项通过；`flutter analyze` 无 issues；`flutter build macos --release` 通过；`flutter build apk --release` 通过。
- 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.10-android.apk`、`/Users/yueliangmanle/Desktop/Flux-v1.1.10-macOS.dmg`。
- 产物校验：APK 包名 `org.localsend.localsend_app`，`versionCode=69`，`versionName=1.1.10`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS `Flux.app` 重新 ad-hoc 签名后 `codesign --verify --deep --strict` 通过；DMG `hdiutil verify` 通过。
## 2026-06-08 追加修复记录（v1.1.11+70）

- 继续循环排查：重新读取当前工作树、版本、产物、TODO/旧文案、发现/服务/蓝牙相关代码，未依赖上一轮记忆直接判定完成。
- 根因：Android `startClassicBluetoothServer` 旧实现立即 `result.success(null)`，Dart 会设置 `listening=true`；如果权限不足、没有蓝牙适配器或 RFCOMM socket 创建失败，UI 仍可能显示监听成功。
- 修复：Android 原生 `startServer()` 改为返回 `Boolean`，只有 RFCOMM server socket 成功创建才返回 true；Dart `startClassicBluetoothServer()`/`ClassicBluetoothService.startListening()` 只在原生 ACK 为 true 时显示监听中。
- 根因：macOS `publishSerialPortService()` 失败时仍继续注册 RFCOMM notification 并发 `listening`，会出现“看起来监听中但实际没有 SPP 服务”的假状态。
- 修复：macOS `startServer() -> Bool`，SPP 服务发布失败直接返回 false 并保留错误消息。
- 根因：Android server socket 创建成功到 server thread 设置 `running=true` 之间存在短暂竞态，快速重复刷新可能重复启动监听。
- 修复：server socket 创建成功后立即设置 `running=true`，线程 finally 中统一复位。
- 根因：蓝牙服务/监听运行期错误只写 `lastError`，旧状态可能仍保留 `listening=true`。
- 修复：Provider 收到包含“服务/监听”的蓝牙 error 事件时同步置 `listening=false`。
- 根因：`SimpleServer` 只支持 GET/POST，但未知 HTTP 方法通过 `firstWhere` 查找会抛 `Bad state: No element`，某些系统/代理探测请求可能制造噪音或异常日志。
- 修复：新增 `HttpMethod.fromMethodName`，不支持的方法直接返回 HTTP 405。
- 文档：清理 `docs/DEVELOPMENT.md` 中关于蓝牙 RFCOMM 链路仍未完工的过期描述，避免后续接手误判当前蓝牙实现状态。
- TDD 留痕：先新增蓝牙监听真实 ACK、监听错误状态清理和 HTTP 405 的失败测试，再实现并跑定向测试转绿。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart test/unit/util/simple_server_test.dart test/unit/provider/classic_bluetooth_provider_test.dart` 通过。
- 验证：`flutter test` 全量 129 项通过；`flutter analyze` 无 issues；`flutter build macos --release` 通过；`flutter build apk --release` 通过。
- 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.11-android.apk`、`/Users/yueliangmanle/Desktop/Flux-v1.1.11-macOS.dmg`。
- 产物校验：APK 包名 `org.localsend.localsend_app`，`versionCode=70`，`versionName=1.1.11`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS `Flux.app` 重新 ad-hoc 签名后 `codesign --verify --deep --strict` 通过；DMG `hdiutil verify` 通过。
## 2026-06-08 追加修复记录（v1.1.12+71）

- 继续循环排查：在 v1.1.11 基础上继续扫描旧文案和蓝牙监听假状态风险。
- 根因：macOS `IOBluetoothRFCOMMChannel.register(...)` 可能返回 nil；旧实现只要 SPP service 发布成功就发 `listening`，notification 注册失败时仍会出现假监听状态。
- 修复：macOS `startServer()` 增加 `guard notification != nil else`，失败时移除临时 SPP service、清空 `serviceRecord`、发出“经典蓝牙 RFCOMM 监听注册失败”并返回 false。
- 文档：清理开发书旧版本日志里仍暗示蓝牙数据通道只在开发中的表述，避免接手者误判当前实现状态。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart` 通过。
- 构建留痕：首次 `flutter build macos --release` 卡在 Rust 工具链自更新，报 `tls handshake eof`；实际本机 `1.93.1-aarch64-apple-darwin` 已安装，执行 `rustup set auto-self-update disable` 并带 `RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup` 后重跑通过。
- 验证：`flutter test` 全量 129 项通过；`flutter analyze` 无 issues；`flutter build macos --release` 通过；`flutter build apk --release` 通过。
- 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.12-android.apk`、`/Users/yueliangmanle/Desktop/Flux-v1.1.12-macOS.dmg`。
- 产物校验：APK 包名 `org.localsend.localsend_app`，`versionCode=71`，`versionName=1.1.12`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS `Flux.app` 重新 ad-hoc 签名后 `codesign --verify --deep --strict` 通过；DMG `hdiutil verify` 通过。
## 2026-06-08 追加修复记录（v1.1.13+72）

- 继续循环排查：没有把 v1.1.12 绿色结果当终点，重新扫描蓝牙、剪切板、手动连接、接收保存和日志敏感信息路径。
- 根因：Dart 蓝牙 Provider 在收到 `disconnected` 时无条件 `startListening()`；如果用户刚手动停止或 Provider 正在 dispose，晚到的原生断开事件会把监听重新拉起，表现为“刚关又自己重连/状态乱跳”。
- 修复：新增手动停止/销毁状态门闩，`shouldRestartClassicBluetoothListenerOnDisconnect(...)` 只有非手动停止且未销毁时才允许断线后自动恢复监听。
- 根因：手动地址解析只处理英文冒号；中文输入法常见的 `10.113.15.240：25565` 或冒号两侧空格会被 URI 解析成错误 hostname。
- 修复：`normalizeAddressInput(...)` 会统一中文冒号和冒号两侧空格，再解析 host/port。
- 根因：接收端保存文件失败后，发送端只能拿到泛泛英文 500，用户容易看到空白或不知所措的错误。
- 修复：新增 `describeReceiveUploadFailure(...)`，接收端保存失败时把具体保存错误带回发送端，并给无具体错误时的中文操作提示。
- 安全修复：移除 WebRTC signaling 初始化时 debug 打印生成私钥的代码，避免密钥进入日志。
- 定向验证：`flutter test test/unit/provider/classic_bluetooth_provider_test.dart test/unit/provider/signaling_provider_test.dart test/unit/util/address_input_parser_test.dart test/unit/provider/clipboard_incoming_failure_test.dart test/unit/util/receive_error_message_test.dart` 通过。
- 验证：`flutter test` 全量 134 项通过；`flutter analyze` 无 issues；`flutter build macos --release` 通过；`flutter build apk --release` 通过。
- 构建留痕：macOS 构建前继续执行 `rustup set auto-self-update disable` 并设置 `RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup`，避免 Rust 工具链自更新 TLS 问题复发。
- 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.13-android.apk`、`/Users/yueliangmanle/Desktop/Flux-v1.1.13-macOS.dmg`。
- 产物校验：APK 包名 `org.localsend.localsend_app`，`versionCode=72`，`versionName=1.1.13`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS `Flux.app` 重新 ad-hoc 签名后 `codesign --verify --deep --strict` 通过；DMG `hdiutil verify` 通过。

## 2026-06-08 追加修复记录（v1.1.14+73）

- 继续循环排查：没有把 v1.1.13 的绿色结果当终点，继续检查经典蓝牙重连、macOS UI 卡顿、剪切板暂停后的 pending 重试路径。
- 根因：点击“暂停剪切板”后，如果旧发送 finally 中仍有 pending 文本，旧逻辑可能继续触发下一轮同步。
- 修复：暂停剪切板时清空 pending 文本，`_sendToAllPeers()` 和 finally 重试都检查 `state.enabled`，关闭后不再继续发送。
- 根因：Android 主动发起新的经典蓝牙连接前未先释放旧 active socket，旧连接残留可能导致重连失败、状态错乱或读循环晚到断开。
- 修复：Android `connect(address)` 在线程内创建新 RFCOMM socket 前先 `closeSocket(emitDisconnected=false)`，让主动重连先清理旧链路。
- 根因：macOS `openRFCOMMChannelSync` 原先在 Flutter MethodChannel 主线程同步执行，连接失败或系统等待时 UI 可能干等。
- 修复：macOS 主动连接改为 `DispatchQueue.global(qos: .userInitiated)` 后台执行，结果通过事件通道回主线程上报。
- 根因：macOS 替换 RFCOMM channel 时，旧通道 close 回调可能晚到并误报 `disconnected`，把新连接状态清掉，表现为“刚连上又断/重连后崩”。
- 修复：`rfcommChannelClosed` 只处理当前 active channel；`attach` 先挂新 channel，再关闭 previous channel，避免旧 close 事件污染新链路。
- TDD 留痕：新增红灯测试覆盖剪切板关闭后不重试、Android 新连接前先关旧 socket、macOS stale close 忽略、macOS 后台连接、macOS attach 替换顺序；修复后定向测试转绿。
- 定向验证：`flutter test test/unit/classic_bluetooth_bridge_test.dart test/unit/provider/classic_bluetooth_provider_test.dart test/unit/provider/clipboard_sync_provider_test.dart test/unit/provider/connection_mode_provider_test.dart test/unit/flux_connection_status_card_test.dart` 通过。
- 验证：`flutter test` 全量 139 项通过；`flutter analyze` 无 issues；`flutter build macos --release` 通过；`flutter build apk --release` 通过。
- 构建留痕：macOS 构建前继续执行 `rustup set auto-self-update disable` 并设置 `RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup`；Android 构建出现 Gradle/AGP/Kotlin 未来弃用警告但 release 构建成功。
- 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.14-android.apk`、`/Users/yueliangmanle/Desktop/Flux-v1.1.14-macOS.dmg`。
- 产物校验：APK 包名 `org.localsend.localsend_app`，`versionCode=73`，`versionName=1.1.14`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS `Flux.app` 重新 ad-hoc 签名后 `codesign --verify --deep --strict` 通过；DMG `hdiutil verify` 通过。

## 2026-06-08 追加修复记录（v1.1.15+74）

- 继续循环排查：没有把 v1.1.14 的打包结果当终点，继续检查剪切板暂停语义、HTTP 错误反馈和蓝牙入站状态反馈。
- 根因：本机点击“暂停剪切板”后，远端通过 HTTP 或蓝牙推来的剪切板仍可能进入 `handleIncomingClipboard(...)` 并写入本机，暂停只阻止了本机向外发送。
- 修复：`handleIncomingClipboard(...)` 在 `state.enabled=false` 时明确拒收并返回 false，状态/错误文案为“远端剪切板已拒收：本机剪切板同步已暂停”。
- 根因：接收端拒收或写入失败后，`/api/clipboard` 只返回泛化 `clipboard write failed`，发送端无法知道是对方暂停、权限失败还是其他写入失败。
- 修复：服务端读取 `clipboardSyncProvider.lastError` 并随 HTTP 500 返回；发送端非 2xx 时解析 JSON `message`，错误显示为“剪切板同步失败：<接收端具体原因>”，待同步文本保留以便重试。
- 根因：经典蓝牙收到 `clipboard` 事件后立即显示“已接收剪切板”，但实际写入可能因暂停或系统剪切板权限失败而被拒收。
- 修复：蓝牙 Provider 新增 `_handleIncomingClipboardEvent(...)`，等待 `handleIncomingClipboard(...)` 真实结果后再显示“已接收”或“经典蓝牙剪切板已拒收”。
- TDD 留痕：先新增暂停接收拒收、接收端错误透传、蓝牙入站状态准确性红灯测试，再实现并跑定向测试转绿。
- 定向验证：`flutter test test/unit/provider/clipboard_sync_provider_test.dart test/unit/provider/clipboard_incoming_failure_test.dart test/unit/provider/clipboard_incoming_order_test.dart test/unit/provider/classic_bluetooth_provider_test.dart` 通过。
- 验证：`flutter test` 全量 143 项通过；`flutter analyze` 无 issues；`flutter build macos --release` 通过；`flutter build apk --release` 通过。
- 构建留痕：macOS 构建前继续执行 `rustup set auto-self-update disable` 并设置 `RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup`；Android 构建出现 Gradle/AGP/Kotlin 未来弃用警告但 release 构建成功。
- 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.15-android.apk`、`/Users/yueliangmanle/Desktop/Flux-v1.1.15-macOS.dmg`。
- 产物校验：APK 包名 `org.localsend.localsend_app`，`versionCode=74`，`versionName=1.1.15`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS `Flux.app` 重新 ad-hoc 签名后 `codesign --verify --deep --strict` 通过；DMG `hdiutil verify` 通过。

## 2026-06-08 追加修复记录（v1.1.16+75）

- 继续循环排查：没有把 v1.1.15 的打包结果当终点，继续审计剪切板暂停后的边界条件。
- 根因：`handleIncomingClipboard(...)` 原先把“空文本或重复远端文本”合并为第一行成功返回；在本机暂停后，如果远端再次推送与上次相同的剪切板，重复判断会绕过暂停拒收并返回成功，发送端可能误清待重试文本。
- 修复：接收入口改为先处理空文本，再检查 `state.enabled` 并拒收暂停状态，最后才做 `_lastRemoteText` 重复去重。
- TDD 留痕：先新增“暂停状态下重复入站剪切板仍拒收”的红灯测试，再调整判断顺序并跑剪切板/蓝牙相关定向测试转绿。
- 定向验证：`flutter test test/unit/provider/clipboard_sync_provider_test.dart test/unit/provider/clipboard_incoming_failure_test.dart test/unit/provider/clipboard_incoming_order_test.dart test/unit/provider/classic_bluetooth_provider_test.dart` 通过。
- 验证：`flutter test` 全量 144 项通过；`flutter analyze` 无 issues；`flutter build macos --release` 通过；`flutter build apk --release` 通过。
- 构建留痕：Android 构建继续使用 `RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup`，Gradle release 构建成功生成 `build/app/outputs/flutter-apk/app-release.apk`。
- 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.16-android.apk`、`/Users/yueliangmanle/Desktop/Flux-v1.1.16-macOS.dmg`。
- 产物校验：APK 包名 `org.localsend.localsend_app`，`versionCode=75`，`versionName=1.1.16`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS `Flux.app` 的 `codesign --verify --deep --strict` 通过，DMG `hdiutil verify` 通过。

## 2026-06-08 追加修复记录（v1.1.17+76）

- 继续循环排查：没有把 v1.1.16 的打包结果当终点，继续审计“电脑扫描到自己”“点扫描没反馈”“文件传输权限失败提示不可用”等体验坑。
- 根因：设备注册和剪切板目标选择主要依赖证书指纹过滤自己；当证书变化、手动输入/收藏本机 IP、或局域网回环发现时，仍可能把本机 IP 当成可同步设备。
- 修复：`NearbyDevicesService` 接入 `localIpProvider`，`shouldRegisterNearbyDevice(...)` 同时按本机 IP 过滤；`selectClipboardSyncTargets(...)` 也新增 `localIps` 过滤，状态卡的可同步设备数量同步使用该过滤结果。
- 根因：TCP/收藏扫描只在发现设备时写日志；如果没有发现设备或扫描还在进行，用户只看到“手动刷新扫描触发”，容易误判按钮无效。
- 修复：新增 `describeLegacyScanStart(...)` / `describeFavoriteScanStart(...)` 并在扫描启动时写入发现日志，刷新按钮现在会立即留下“正在扫描哪个网段/端口”的可见反馈。
- 根因：Android/SAF 保存目录权限失效或普通文件权限失败时，接收端/发送端可能只显示英文异常、空错误或泛化失败，用户不知道要重新选保存目录。
- 修复：`describeReceiveUploadFailure(...)` 识别 `Permission denied`、`EACCES`、`tree uri`、`content://`、`SAF` 等常见错误并输出中文操作指引；发送端 `describeSendFailure(...)` 也复用该翻译。
- TDD 留痕：先新增本机 IP 自过滤、扫描启动日志、发送端权限错误翻译等红灯测试，再实现修复并跑定向测试转绿。
- 定向验证：`flutter test test/unit/provider/nearby_devices_provider_test.dart test/unit/provider/nearby_scan_failure_test.dart test/unit/provider/scan_facade_test.dart test/unit/provider/clipboard_sync_provider_test.dart test/unit/provider/clipboard_background_discovery_test.dart test/unit/provider/clipboard_incoming_failure_test.dart test/unit/util/receive_error_message_test.dart test/unit/android_saf_directory_permission_test.dart` 通过，共 33 项通过；`flutter analyze` 无 issues。
- 验证：`flutter test` 全量 148 项通过；`flutter analyze` 无 issues；`flutter build macos --release` 通过；`flutter build apk --release` 通过。
- 构建留痕：macOS 构建前继续执行 `rustup set auto-self-update disable` 并设置 `RUSTUP_DIST_SERVER=https://rsproxy.cn RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup`；Android 构建同样使用 rsproxy 环境变量，Gradle release 构建成功生成 `build/app/outputs/flutter-apk/app-release.apk`。
- 产物：`/Users/yueliangmanle/Desktop/Flux-v1.1.17-android.apk`、`/Users/yueliangmanle/Desktop/Flux-v1.1.17-macOS.dmg`。
- 产物校验：APK 包名 `org.localsend.localsend_app`，`versionCode=76`，`versionName=1.1.17`，签名证书 SHA-256 `b20954002f018b6628dcddf20e6c37ffb97e7c32bb5695e1d0e60fbc61bb6c66`；macOS `Flux.app` 的 `codesign --verify --deep --strict` 通过，DMG `hdiutil verify` 通过。
