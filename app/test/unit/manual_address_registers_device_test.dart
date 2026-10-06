import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('manual IP discovery registers the found device for clipboard sync', () {
    final source = File('lib/widget/dialogs/address_input_dialog.dart').readAsStringSync();

    expect(source, contains('nearbyDevicesProvider'));
    expect(source, contains('RegisterDeviceAction(foundDevice!)'));
  });

  test('manual IP discovery wakes clipboard sync after registering a device', () {
    final source = File('lib/widget/dialogs/address_input_dialog.dart').readAsStringSync();
    final registerIndex = source.indexOf('RegisterDeviceAction(foundDevice!)');
    final wakeIndex = source.indexOf('notifyDeviceRegistered');

    expect(registerIndex, isNonNegative);
    expect(wakeIndex, isNonNegative);
    expect(wakeIndex, greaterThan(registerIndex));
  });

  test('send tab can open manual IP dialog even when no files are selected', () {
    final source = File('lib/pages/tabs/send_tab_vm.dart').readAsStringSync();
    final onTapAddressStart = source.indexOf('onTapAddress: (context) async {');
    final onTapFavoriteStart = source.indexOf('onTapFavorite: (context) async {');
    final onTapAddressBody = source.substring(onTapAddressStart, onTapFavoriteStart);

    expect(onTapAddressBody, contains('AddressInputDialog'));
    expect(onTapAddressBody, isNot(contains('NoFilesDialog')));
    expect(onTapAddressBody, contains('if (device != null && files.isNotEmpty && context.mounted)'));
  });

  test('tapping discovered device without files gives clipboard-ready feedback instead of blocking connection', () {
    final source = File('lib/pages/tabs/send_tab_vm.dart').readAsStringSync();
    final onTapDeviceStart = source.indexOf('onTapDevice: (context, device) async {');
    final onTapDeviceMultiStart = source.indexOf('onTapDeviceMultiSend: (context, device) async {');
    final onTapDeviceBody = source.substring(onTapDeviceStart, onTapDeviceMultiStart);

    expect(onTapDeviceBody, isNot(contains('NoFilesDialog')));
    expect(onTapDeviceBody, contains('设备在线，可用于剪切板自动同步'));
  });

  test('favorite device connection registers the device for clipboard sync', () {
    final source = File('lib/widget/dialogs/favorite_dialog.dart').readAsStringSync();

    expect(source, contains('nearbyDevicesProvider'));
    expect(source, contains('RegisterDeviceAction(device)'));
  });

  test('favorite device connection wakes clipboard sync after registering a device', () {
    final source = File('lib/widget/dialogs/favorite_dialog.dart').readAsStringSync();
    final registerIndex = source.indexOf('RegisterDeviceAction(device)');
    final wakeIndex = source.indexOf('notifyDeviceRegistered');

    expect(registerIndex, isNonNegative);
    expect(wakeIndex, isNonNegative);
    expect(wakeIndex, greaterThan(registerIndex));
  });

  test('manual address dialog rejects empty input before sending network requests', () {
    final source = File('lib/widget/dialogs/address_input_dialog.dart').readAsStringSync();

    expect(source, contains('input.isEmpty'));
    expect(source, contains('t.display.enterIpHint'));
  });

  test('manual address dialog guards duplicate discovery completions', () {
    final source = File('lib/widget/dialogs/address_input_dialog.dart').readAsStringSync();

    expect(source, contains('!deviceCompleter.isCompleted'));
  });

  test('multi-send device tap without files gives clipboard-ready feedback too', () {
    final source = File('lib/pages/tabs/send_tab_vm.dart').readAsStringSync();
    final onTapDeviceMultiStart = source.indexOf('onTapDeviceMultiSend: (context, device) async {');
    final vmEnd = source.indexOf('  );\n});', onTapDeviceMultiStart);
    final onTapDeviceMultiBody = source.substring(onTapDeviceMultiStart, vmEnd);

    expect(onTapDeviceMultiBody, isNot(contains('NoFilesDialog')));
    expect(onTapDeviceMultiBody, contains('设备在线，可用于剪切板自动同步'));
  });
}
