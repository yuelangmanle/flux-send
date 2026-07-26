import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
import 'package:test/test.dart';

void main() {
  test('custom dropdown tolerates stale persisted values instead of blanking the settings tab', () {
    expect(
      resolveDropdownValue<ColorMode>(
        value: ColorMode.system,
        items: const [ColorMode.localsend, ColorMode.oled, ColorMode.yaru],
      ),
      isNull,
    );
    expect(
      resolveDropdownValue<ThemeMode>(
        value: ThemeMode.dark,
        items: ThemeMode.values,
      ),
      ThemeMode.dark,
    );
  });

  test('settings tab uses safe dropdown values and keeps current color mode in available choices', () {
    final tab = File('lib/pages/tabs/settings_tab.dart').readAsStringSync();
    final controller = File('lib/pages/tabs/settings_tab_controller.dart').readAsStringSync();

    expect(tab, contains('resolveDropdownValue'));
    expect(controller, contains('resolveAvailableColorModes'));
  });

  test('settings tab keeps Android away from desktop-only window chrome and has an error fallback', () {
    final tab = File('lib/pages/tabs/settings_tab.dart').readAsStringSync();
    final appbarStart = tab.indexOf('class _SettingsAppBar');
    final fallbackStart = tab.indexOf('class _SettingsFallback');

    expect(tab, contains('errorBuilder: _buildSettingsError'));
    expect(tab, contains('checkPlatformIsDesktop()'));
    expect(appbarStart, isNonNegative);
    expect(fallbackStart, isNonNegative);
    expect(tab.substring(appbarStart), contains('MoveWindow'));
    expect(tab.substring(appbarStart), contains('checkPlatformIsDesktop()'));
    expect(tab.substring(fallbackStart), contains('设置页加载失败'));
    expect(tab.substring(fallbackStart), contains('重试'));
  });

  test('clipboard provider failures stay inside the clipboard settings section', () {
    final tab = File('lib/pages/tabs/settings_tab.dart').readAsStringSync();
    final builderStart = tab.indexOf('builder: (context, vm) {');
    final builderEnd = tab.indexOf('Widget _buildSettingsLoading');
    final clipboardSectionStart = tab.indexOf('class _ClipboardSyncSettingsSection');

    expect(builderStart, isNonNegative);
    expect(builderEnd, isNonNegative);
    expect(clipboardSectionStart, isNonNegative);
    expect(tab.substring(builderStart, builderEnd), contains('const _ClipboardSyncSettingsSection()'));
    expect(tab.substring(builderStart, builderEnd), isNot(contains('clipboardSyncProvider')));
    expect(tab.substring(clipboardSectionStart), contains('final clipboard = context.ref.watch(clipboardSyncProvider);'));
  });

  test('runtime widget failures use a visible Chinese fallback instead of an opaque error widget', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(main, contains('ErrorWidget.builder = buildFluxRuntimeErrorWidget'));
  });

  test('runtime error fallback supplies its own text direction outside MaterialApp', () {
    final fallback = File('lib/config/runtime_error_widget.dart').readAsStringSync();

    expect(fallback, contains('Directionality('));
  });

  test('settings tab init does not touch desktop startup helpers on Android', () {
    final controller = File('lib/pages/tabs/settings_tab_controller.dart').readAsStringSync();
    final initStart = controller.indexOf('class _SettingsTabInitAction');
    final helperStart = controller.indexOf('Future<({bool autoStart, bool autoStartHidden, bool showInContextMenu})> loadDesktopSettingsTabState()');
    final initBody = controller.substring(initStart, helperStart);

    expect(controller, contains('Future<({bool autoStart, bool autoStartHidden, bool showInContextMenu})> loadDesktopSettingsTabState()'));
    expect(initBody, contains('loadDesktopSettingsTabState()'));
    expect(initBody, isNot(contains('await isAutoStartEnabled()')));
    expect(initBody, isNot(contains('await isAutoStartHidden()')));
    expect(initBody, isNot(contains('await isContextMenuEnabled()')));
  });

  test('settings tab desktop state loader returns inert values on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final state = await loadDesktopSettingsTabState();

    expect(state.autoStart, isFalse);
    expect(state.autoStartHidden, isFalse);
    expect(state.showInContextMenu, isFalse);
  });
}
