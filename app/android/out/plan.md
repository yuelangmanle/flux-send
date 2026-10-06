# Foreground Service 保活设计规格

[S1] 服务启动后 10 秒内前台通知可见，通知标题含 "Flux"，IMPORTANCE_LOW 不发声
[S2] 进程存活期间（息屏 60 秒后）RFCOMM 监听线程不被冻结，蓝牙连接保持
[S3] ACTION_STOP 到达后 2 秒内前台通知移除、服务退出
[D1] 无源视频切片——本组件为标准 Android 前台服务模式实现，验证方式为编译通过 + 冒烟启动
