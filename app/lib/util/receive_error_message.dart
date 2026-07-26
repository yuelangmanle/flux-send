String describeReceiveUploadFailure(String? errorMessage) {
  final normalized = errorMessage?.trim();
  if (normalized == null || normalized.isEmpty) {
    return '接收端保存失败。请在接收端检查保存目录、相册或文件权限后重试。';
  }
  final lower = normalized.toLowerCase();
  if (lower.contains('permission denied') || lower.contains('eacces') || lower.contains('operation not permitted')) {
    return '接收端保存失败：没有保存权限。请在接收端 Flux 的「设置 > 接收 > 保存到文件夹」重新选择一个可写目录；Android 建议选择 Download/下载目录，并在系统弹窗中允许写入。';
  }
  if (lower.contains('tree uri') || lower.contains('content://') || lower.contains('saf')) {
    return '接收端保存失败：保存目录授权已失效。请在接收端 Flux 的「设置 > 接收 > 保存到文件夹」重新选择目录并允许访问。';
  }
  return '接收端保存失败：$normalized';
}
