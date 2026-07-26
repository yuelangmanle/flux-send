import 'package:localsend_app/util/receive_error_message.dart';
import 'package:test/test.dart';

void main() {
  test('describes receive save failures with actionable fallback text', () {
    expect(
      describeReceiveUploadFailure(null),
      '接收端保存失败。请在接收端检查保存目录、相册或文件权限后重试。',
    );
    expect(
      describeReceiveUploadFailure('Permission denied'),
      '接收端保存失败：没有保存权限。请在接收端 Flux 的「设置 > 接收 > 保存到文件夹」重新选择一个可写目录；Android 建议选择 Download/下载目录，并在系统弹窗中允许写入。',
    );
    expect(
      describeReceiveUploadFailure('open failed: EACCES (Permission denied)'),
      '接收端保存失败：没有保存权限。请在接收端 Flux 的「设置 > 接收 > 保存到文件夹」重新选择一个可写目录；Android 建议选择 Download/下载目录，并在系统弹窗中允许写入。',
    );
    expect(
      describeReceiveUploadFailure('No permission to access tree uri'),
      '接收端保存失败：保存目录授权已失效。请在接收端 Flux 的「设置 > 接收 > 保存到文件夹」重新选择目录并允许访问。',
    );
    expect(
      describeReceiveUploadFailure('Disk full'),
      '接收端保存失败：Disk full',
    );
  });
}
