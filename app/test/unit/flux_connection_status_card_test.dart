import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('send and receive tabs show the shared Flux connection status card', () {
    final sendTab = File('lib/pages/tabs/send_tab.dart').readAsStringSync();
    final receiveTab = File('lib/pages/tabs/receive_tab.dart').readAsStringSync();
    final widget = File('lib/widget/flux_connection_status_card.dart');

    expect(widget.existsSync(), isTrue);
    expect(sendTab, contains('FluxConnectionStatusCard'));
    expect(receiveTab, contains('FluxConnectionStatusCard'));
  });

  test('settings and status card share real connection-mode switching side effects', () {
    final settingsTab = File('lib/pages/tabs/settings_tab.dart').readAsStringSync();
    final statusCard = File('lib/widget/flux_connection_status_card.dart').readAsStringSync();

    expect(settingsTab, contains('switchFluxConnectionMode('));
    expect(statusCard, contains('switchFluxConnectionMode('));
    expect(settingsTab, isNot(contains('ref.notifier(connectionModeProvider).setMode(selectedMode)')));
  });
}
