/// 将手动连接的底层异常翻译为可操作的中文提示。
/// 无法识别的异常保留原文（附带排查建议），避免用户看到英文异常栈。
String describeAddressConnectError(Object error) {
  final message = error.toString().toLowerCase();

  if (message.contains('failed host lookup') || message.contains('unknownhost')) {
    return '地址无法解析：请检查输入的 IP 或主机名是否正确。';
  }
  if (message.contains('socketexception') ||
      message.contains('connection refused') ||
      message.contains('connection timed out') ||
      message.contains('timed out') ||
      message.contains('connection reset') ||
      message.contains('software caused connection abort')) {
    return '连不上对方：请确认接收端 Flux 已打开、两台设备在同一 Wi-Fi/热点，且防火墙未拦截。';
  }
  if (message.contains('no route to host') || message.contains('network is unreachable')) {
    return '找不到网络路径：请检查两台设备是否在同一网段，路由器是否开启了 AP 隔离。';
  }
  if (message.contains('handshake error') || message.contains('certificate') || message.contains('tls') || message.contains('ssl')) {
    return '安全连接失败：请确认对方运行的是 Flux/LocalSend，且系统时间正确。';
  }
  return '连接失败：$error\n请确认对方已打开 Flux 并在同一网络。';
}
