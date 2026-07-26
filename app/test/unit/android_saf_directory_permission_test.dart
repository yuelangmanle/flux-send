import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Android directory picker persists write permission for receive destinations', () {
    final source = File('android/app/src/main/kotlin/org/localsend/localsend_app/MainActivity.kt').readAsStringSync();

    expect(source, contains('Intent.FLAG_GRANT_WRITE_URI_PERMISSION'));
    expect(source, contains('takePersistableDirectoryPermission'));
    expect(source, contains('Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION'));
  });
}
