import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('macOS packaging script preserves Flux naming and Bluetooth entitlements', () {
    final script = File('../scripts/compile_mac_dmg.sh').readAsStringSync();

    expect(script, contains('Flux.app'));
    expect(script, contains(r'Flux-v$VERSION-macOS.dmg'));
    expect(script, contains('macos/Runner/Release.entitlements'));
    expect(script, contains('com.apple.security.device.bluetooth'));
    expect(script, contains(r'codesign --force --deep --sign "$SIGN_ID" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"'));
    expect(script, contains('hdiutil create'));
    expect(script, contains(r'hdiutil verify "$DMG_OUT"'));
    expect(script, isNot(contains('LocalSend.app')));
    expect(script, isNot(contains('LocalSend.dmg')));
    expect(script, isNot(contains('Developer ID Application: Tien Do Nam')));
    expect(script, isNot(contains('notarytool submit')));
  });

  test('Android packaging script archives Flux APK under project releases', () {
    final script = File('../scripts/compile_android_apk.sh').readAsStringSync();

    expect(script, contains(r'Flux-v$VERSION-android.apk'));
    expect(script, contains(r'releases/history/v$VERSION'));
    expect(script, contains('build/app/outputs/flutter-apk/app-release.apk'));
    expect(script, isNot(contains('localsend')));
    expect(script, isNot(contains('/tmp/build')));
  });

  test('release packaging scripts support dry-run path verification', () {
    final macos = Process.runSync(
      'bash',
      ['../scripts/compile_mac_dmg.sh'],
      environment: {
        'DRY_RUN': '1',
        'VERSION': '9.9.9',
      },
    );
    final android = Process.runSync(
      'bash',
      ['../scripts/compile_android_apk.sh'],
      environment: {
        'DRY_RUN': '1',
        'VERSION': '9.9.9',
      },
    );

    expect(macos.exitCode, 0);
    expect(android.exitCode, 0);
    expect(macos.stdout, contains('DRY_RUN=1'));
    expect(android.stdout, contains('DRY_RUN=1'));
    expect(macos.stdout, contains('/releases/history/v9.9.9/Flux-v9.9.9-macOS.dmg'));
    expect(android.stdout, contains('/releases/history/v9.9.9/Flux-v9.9.9-android.apk'));
    expect(macos.stdout, contains('Release.entitlements'));
  });

  test('release packaging scripts parse version from pubspec by default', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$', multiLine: true).firstMatch(pubspec)!.group(1)!;

    final macos = Process.runSync(
      'bash',
      ['../scripts/compile_mac_dmg.sh'],
      environment: {
        'DRY_RUN': '1',
      },
    );
    final android = Process.runSync(
      'bash',
      ['../scripts/compile_android_apk.sh'],
      environment: {
        'DRY_RUN': '1',
      },
    );

    expect(macos.exitCode, 0);
    expect(android.exitCode, 0);
    expect(macos.stdout, contains('VERSION=$version'));
    expect(android.stdout, contains('VERSION=$version'));
    expect(macos.stdout, contains('/releases/history/v$version/Flux-v$version-macOS.dmg'));
    expect(android.stdout, contains('/releases/history/v$version/Flux-v$version-android.apk'));
  });

  test('macOS smoke script verifies visible window, crash logs, and persisted Bluetooth mode', () {
    final script = File('../scripts/smoke_macos_flux.sh').readAsStringSync();

    expect(script, contains('/Applications/Flux.app'));
    expect(script, contains('CGWindowListCopyWindowInfo'));
    expect(script, contains('Flux-*.ips'));
    expect(script, contains('flutter.flux_connection_mode'));
    expect(script, contains('localNetwork'));
    expect(script, contains('hotspot'));
    expect(script, contains('classicBluetooth'));
    expect(script, contains('lsof'));
    expect(script, contains('-iTCP'));
    expect(script, contains('-sTCP:LISTEN'));
    expect(script, contains('DRY_RUN=1'));
  });
}
