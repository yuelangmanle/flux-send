import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('no-permission dialog is scrollable for long Android recovery guidance', () {
    final source = File('lib/widget/dialogs/no_permission_dialog.dart').readAsStringSync();

    expect(source, contains('AlertDialog('));
    expect(source, contains('scrollable: true'));
  });

  test('Chinese no-permission dialog explains Android picker and receive-folder recovery', () {
    final zhCn = File('assets/i18n/zh-CN.json').readAsStringSync();
    final generated = File('lib/gen/strings_zh_CN.g.dart').readAsStringSync();

    for (final source in [zhCn, generated]) {
      expect(source, contains('如果是发送文件失败'));
      expect(source, contains('系统文件选择器'));
      expect(source, contains('如果是接收保存失败'));
      expect(source, contains('Download/下载目录'));
      expect(source, contains('Android 不需要“全部文件访问权限”'));
    }
  });

  test('English no-permission dialog distinguishes picker access from all-files permission', () {
    final en = File('assets/i18n/en.json').readAsStringSync();
    final generated = File('lib/gen/strings_en.g.dart').readAsStringSync();

    for (final source in [en, generated]) {
      expect(source, contains('system file picker'));
      expect(source, contains('receive save fails'));
      expect(source, contains('Download folder'));
      expect(source, contains('All files access'));
    }
  });
}
