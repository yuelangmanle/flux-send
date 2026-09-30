# Flux 2.0 路线图（规划稿）

> 生成于 2026-09-30，基于 4 路并行深读审查（架构 / 网络协议安全 / 原生层 / UI·UX·创新）。
> 证据均标注 文件:行号，实施时以当时代码为准。当前基线：v1.1.55+114。

## 一、总主题

2.0 的主线不是堆功能，而是三件事：**把安全做实**（当前 HTTPS 不验证对端，等于裸奔）、**把传输做稳**（断点续传缺失、蓝牙大文件驻内存）、**把架构还清**（中文文案当协议、巨石文件、死代码拖累构建）。功能与动效在此之上叠加。

---

## 二、P0：必须进 2.0 的问题（安全 / 崩溃 / 数据）

### 安全
1. **出站 TLS 不验证对端证书**——`util/rhttp.dart:74` `verifyCertificates: false`；`clipboard_sync_provider.dart:658` `badCertificateCallback=()=>true`；证书 pinning 在 rust 侧已有（`core/src/http/client/mod.rs:169`）但 Dart 未接线（`send_provider.dart:156` `publicKey: null // TODO`；`security_helper.dart:67` 无人调用）。当前 HTTPS 只有加密无认证，可被 MITM。→ register 响应已带 peer public_key，2.0 全链路 pinning。
2. **`/api/clipboard` 完全无鉴权**——`server_provider.dart:146-166`，无 PIN/指纹/限流，body 无大小上限。→ 收藏指纹或 PIN + 1MB 上限 + 429 限流。
3. **PIN 限流缺陷**——`server/controller/common.dart:11-36`：按 IP 永不过期、成功不重置、pin 走 query 参数易进日志。→ TTL 窗口 + 成功重置 + Header 传递。

### 崩溃 / 数据
4. **SAF 递归扫描在主线程**——`MainActivity.kt:171-195,263-281`，选大目录直接 ANR。→ 移 IO 线程 + 条目上限。
5. **FileOpener 未知类型兜底成目录 MIME**——`FileOpener.kt:91`，会以 directory MIME 拉起 VIEW 导致崩溃。→ 兜底 `application/octet-stream`。
6. **选择器 pendingResult 单槽覆盖**——`MainActivity.kt:27`，连续调用挂死 Future。→ 按 requestCode 建 map。
7. **UDP 公告重试失效**——`common/.../multicast_discovery.dart:122-135`，第一轮 send 后即 close socket，弱网下发现成功率骤降。→ close 移出循环。
8. **蓝牙收文件全量驻内存**——`classic_bluetooth_provider.dart:186-203,616-627`，大文件 OOM；且每 24KB chunk 两次 `state.copyWith` 触发整页 rebuild。→ begin 即流式落盘 `.part` + 进度 100ms 节流。

### 协议正确性
9. **中文文案是跨进程协议**——`send_provider.dart:661,672`、`classic_bluetooth_provider.dart:114-116` 等以 `contains('中文')` 驱动状态机，文案一改即断，且堵死 i18n。→ 定义错误码枚举随协议下发，文案仅展示层。
10. **协议常量三处双写**——Kotlin/Swift/Dart 各一份（`ClassicBluetoothBridge.kt:30-32`、`.swift:7-9`、`classic_bluetooth_bridge.dart:23-25`），漂移即静默坏包。→ 单源 + 握手协商版本。

---

## 三、2.0 功能路线图（按阶段）

### 阶段一：还债基线（先于一切新功能）
1. 删死代码：webrtc 接收链（`webrtc_receiver.dart` 零引用、`signaling_provider` 仅 init 启动无消费、`rust/api/webrtc.dart` + 1160 行 freezed）——可省三架构 rust 编译的大头时间；`purchase_provider`（上游付费遗留）；`tv_provider`；Windows/Linux 目录与依赖（win32_registry、yaru、bitsdojo_window、msix）。
2. 错误码协议：`core/errors/` 定义枚举，Dart/Kotlin/Swift 三端对齐，中文文案兼容读过渡（新码优先、旧文案 fallback，双端同版后移除）。
3. P0 安全三连：证书 pinning 全链路（TOFU + 收藏指纹）、clipboard 鉴权、PIN 限流重写。
4. P0 原生三连：SAF 线程化、FileOpener 兜底、pendingResult map。
5. `receive_controller.dart`（879 行，反向 import UI `receive_controller.dart:21`）拆为 `receive_session_controller`（纯状态机，先补测试）+ `receive_file_writer` + `receive_notification`。
6. 测试升级：字符串断言改行为断言；补 send_provider / server 路由覆盖。
7. i18n 收口：229 处硬编码中文迁入 slang，CI 加 `[一-龥]` 扫描拦截。

### 阶段二：传输体验（2.0 的主打卖点）
1. **断点续传 + 完整性**：upload 增加 offset/Range + 分块 SHA-256，接收端 `.part` + 会话 token；HTTP 与蓝牙共用同一分块校验协议。（当前失败即整文件重发）
2. **蓝牙文件通道下沉原生**：长度前缀二进制帧替代 base64+JSON（省 33% 空间）、逐块 ACK 背压、64KB 分块、进度事件；两端常量经握手协商。
3. **Android 前台服务**：蓝牙监听与传输移入 foreground service（`FOREGROUND_SERVICE_CONNECTED_DEVICE` + 通知进度），解决息屏断连；multicast lock 一并迁移。
4. **传输速度可视化**：进度页加速度曲线（`CustomPaint` + 环形缓冲 60 采样点 + `RepaintBoundary`），完成动效 `easeOutBack` + `HapticFeedback.mediumImpact`；失败重试图标加文字。
5. **Android targetSdk 34→35**（2026 上架要求）+ 边到边验证。
6. macOS：tray 菜单"最近目标速传"（statusItem 基建已有）；修 `AppDelegate.swift:120-142` bookmark 泄漏（startAccessing 无 stop）。

### 阶段三：体验与创新
1. **一键速传收藏设备**（S，性价比最高）：send 页收藏设备条，点即发。
2. **二维码配对**（M）：本机指纹二维码 + 对端扫码，替代手动输 IP；顺带完成配对信任模型。
3. **接收记录管理**（M）：搜索（`SearchAnchor`）+ 长按多选批量操作 + `Hero` 大图预览。
4. **剪贴板时间线**（M）：本地历史表 + 时间线 UI，跨端粘贴不丢。
5. **发现体验**：设备卡排序/收藏置顶/昵称编辑；骨架屏；`FluxEmptyView` 统一空态/错误态组件。
6. **首启引导**（S）：3 步 PageView（昵称→权限→信任说明）。
7. **动效规范**：状态卡呼吸灯（在线常亮/扫描呼吸/离线静止）、页面 M3 fade-through、进度页 `Hero` 飞入、触觉仅三处（选中/完成/错误）、动态取色收口到 `colorScheme`（清掉 22 处 `Colors.grey`）。
8. **传输队列编排**（M）：会话完成自动发下一个。

### 2.1+ 候选（本轮不做）
iOS 端（需 BLE 重写传输面，中等偏大）；Windows 最小恢复（Flutter Windows runner + rhttp Windows 构建 + 防火墙引导）；macOS Services 菜单；统计面板；多设备组网/中继。

---

## 四、架构目标形态

```
app/lib/
  core/            # 错误码、常量、结果类型（无 Flutter 依赖）
  bridge/          # 全部 MethodChannel/EventChannel 收拢，统一 org.localsend.flux/<domain> 命名与错误码表
  provider/
    network/{server,discovery,send}
    bluetooth/
    clipboard/
    settings/
  pages/ widget/   # 只 import provider facade；禁止 controller import pages（修 receive_controller.dart:21）
```

规则：UI → Provider(facade) → Service → Bridge；协议层只传错误码；轮询改事件流（clipboard 500ms `Timer.periodic` → 平台剪贴板变更回调）；扫描指数退避、发现成功即停（现状：0 设备在线时每 5 秒最坏约 3072 个 HTTP 请求）。

---

## 五、兼容性基线（必须保持）

- 与上游 LocalSend 1.15–1.17 **互传可用**（v2 API 双注册、端口 53317、组播 224.0.0.167 已验证完整）——2.0 任何协议改动不得破坏，新能力走版本协商（hello.v2 能力位 / HTTP header）。
- Android applicationId 与签名密钥不变（覆盖安装）；macOS 部署目标 ≥ 12.0。
- 上游 2.x 的 token 签名机制（`core/src/crypto/token.rs`）已在依赖里但 Dart 未启用——启用它而不是自造轮子。

---

## 六、验收口径

- 阶段一结束：`flutter analyze` 0 issues、测试数 ≥ 260（含 receive_session 行为测试）、`grep -rP '[一-龥]' app/lib --include=*.dart` 在白名单外为 0、frb_generated.web.dart 与 webrtc 代码消失。
- 阶段二结束：1GB 文件经蓝牙传输内存峰值 < 100MB；传输中断重连后续传成功率 ≥ 95%；息屏 10 分钟 Android 蓝牙不断连。
- 阶段三结束：设置页最大文件 < 400 行；全 app 无 `Colors.grey` 硬编码；新用户从安装到首次传输 ≤ 60 秒（含引导）。
