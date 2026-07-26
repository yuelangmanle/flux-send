import 'dart:io';

import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:test/test.dart';

void main() {
  test('clipboard route reports incoming write failures instead of returning false success', () {
    final provider = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();
    final server = File('lib/provider/network/server/server_provider.dart').readAsStringSync();

    expect(provider, contains('Future<bool> handleIncomingClipboard'));
    expect(provider, contains('return true;'));
    expect(provider, contains('return false;'));
    expect(server, contains('final updated = await ref.notifier(clipboardSyncProvider).handleIncomingClipboard(text);'));
    expect(server, contains("message: clipboardError ?? 'clipboard write failed'"));
  });

  test('clipboard route reports receiver paused state instead of returning false success', () {
    final provider = File('lib/provider/clipboard_sync_provider.dart').readAsStringSync();
    final server = File('lib/provider/network/server/server_provider.dart').readAsStringSync();

    expect(provider, contains('远端剪切板已拒收：本机剪切板同步已暂停'));
    expect(provider, contains('return false;'));
    expect(server, contains('ref.read(clipboardSyncProvider).lastError'));
    expect(server, contains("message: clipboardError ?? 'clipboard write failed'"));
  });

  test('file upload failure response includes receiver save error details', () {
    final source = File('lib/provider/network/server/controller/receive_controller.dart').readAsStringSync();

    expect(source, contains('describeReceiveUploadFailure'));
    expect(source, contains('finalFileState?.errorMessage'));
    expect(source, isNot(contains('Could not save file. Check receiving device for more information.')));
  });

  test('file upload failure drains request body before responding with the save error', () {
    final source = File('lib/provider/network/server/controller/receive_controller.dart').readAsStringSync();
    final catchIndex = source.indexOf('Failed to save file');
    final drainIndex = source.indexOf('await request.drain', catchIndex);
    final responseIndex = source.indexOf('describeReceiveUploadFailure(finalFileState?.errorMessage)', catchIndex);

    expect(catchIndex, isNonNegative);
    expect(drainIndex, isNonNegative);
    expect(responseIndex, isNonNegative);
    expect(drainIndex, lessThan(responseIndex));
  });

  test('incoming register wakes clipboard sync after recording the peer', () {
    final source = File('lib/provider/network/server/controller/receive_controller.dart').readAsStringSync();
    final registerIndex = source.indexOf('dispatchAsync(RegisterDeviceAction');
    final wakeIndex = source.indexOf('notifyDeviceRegistered', registerIndex);

    expect(registerIndex, isNonNegative);
    expect(wakeIndex, isNonNegative);
    expect(wakeIndex, greaterThan(registerIndex));
  });

  test('sender translates receiver save permission failures into actionable Chinese text', () {
    expect(
      describeSendFailure('Permission denied', statusCode: 500),
      '接收端保存失败：没有保存权限。请在接收端 Flux 的「设置 > 接收 > 保存到文件夹」重新选择一个可写目录；Android 建议选择 Download/下载目录，并在系统弹窗中允许写入。',
    );
    expect(
      describeSendFailure('Disk full', statusCode: 500),
      '[500] Disk full',
    );
  });

  test('sender describes empty HTTP upload failures with actionable text', () {
    expect(
      describeSendFailure('', statusCode: 500),
      '[500] 对方没有返回错误详情；请检查接收端 Flux 的保存目录、权限和剩余空间。',
    );
    expect(
      describeSendFailure('   ', statusCode: 409),
      '[409] 对方没有返回错误详情；请检查接收端 Flux 的保存目录、权限和剩余空间。',
    );
  });

  test('sender shows missing Android receive folder guidance without HTTP noise', () {
    expect(
      describeSendFailure(
        '请先在接收端 Flux 的「设置 > 接收 > 保存目录」选择 Download/下载目录；未设置时 Android 可能只能写入应用私有目录，文件会很难找到。',
        statusCode: 409,
      ),
      '请先在接收端 Flux 的「设置 > 接收 > 保存目录」选择 Download/下载目录；未设置时 Android 可能只能写入应用私有目录，文件会很难找到。',
    );
  });
}
