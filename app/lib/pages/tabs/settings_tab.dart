import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/about/about_page.dart';
import 'package:localsend_app/pages/changelog_page.dart';
import 'package:localsend_app/pages/language_page.dart';
import 'package:localsend_app/pages/settings/network_interfaces_page.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/pages/tabs/settings_tab_vm.dart';
import 'package:localsend_app/provider/clipboard_sync_provider.dart';
import 'package:localsend_app/provider/connection_mode_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/update_provider.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/util/alias_generator.dart';
import 'package:localsend_app/util/destination_display_label.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/pick_directory_path.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
import 'package:localsend_app/widget/dialogs/encryption_disabled_notice.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/quick_save_from_favorites_notice.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/dialogs/text_field_with_actions.dart';
import 'package:localsend_app/widget/flux_text_field.dart';
import 'package:localsend_app/widget/labeled_checkbox.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

part 'settings_tab.sections.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab();

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  int _settingsReloadKey = 0;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      key: ValueKey(_settingsReloadKey),
      provider: (ref) => settingsTabControllerProvider,
      loadingBuilder: _buildSettingsLoading,
      errorBuilder: _buildSettingsError,
      builder: (context, vm) {
        final ref = context.ref;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: MediaQuery.of(context).padding.right,
              ), // So camera or 3-button navigation doesn't interfere on the right, rest is handled
              child: ResponsiveListView(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
                children: [
                  SizedBox(height: 30 + MediaQuery.of(context).padding.top),
                  ..._buildGeneralSection(vm, ref),
                  _ConnectionModeSection(),
                  const _ClipboardSyncSettingsSection(),
                  ..._buildReceiveSection(vm, ref),
                  ..._buildSendSection(vm, ref),
                  ..._buildNetworkSection(vm, ref),
                  ..._buildOtherSection(vm, ref),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      LabeledCheckbox(
                        label: t.settingsTab.advancedSettings,
                        value: vm.advanced,
                        labelFirst: true,
                        onChanged: (b) async {
                          vm.onTapAdvanced(b == true);
                          await ref.notifier(settingsProvider).setAdvancedSettingsEnabled(b == true);
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const LocalSendLogo(withText: true),
                  const SizedBox(height: 5),
                  ref
                      .watch(versionProvider)
                      .maybeWhen(
                        data: (version) => Text(
                          'Version: $version',
                          textAlign: TextAlign.center,
                        ),
                        orElse: () => Container(),
                      ),
                  Text(
                    '© ${DateTime.now().year} Tien Do Nam',
                    textAlign: TextAlign.center,
                  ),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () async {
                        await context.push(() => const ChangelogPage());
                      },
                      icon: const Icon(Icons.history),
                      label: Text(t.changelogPage.title),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            const _SettingsAppBar(),
          ],
        );
      },
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(t.settingsTab.updateCheck.checking)),
            ],
          ),
        ),
      ),
    );

    try {
      final updateCheck = await checkFluxUpdate();
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await _showUpdateResult(context, updateCheck);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(t.settingsTab.updateCheck.failedTitle),
          content: Text(t.settingsTab.updateCheck.failedMessage(error: error.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.settingsTab.updateCheck.ok),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showUpdateResult(BuildContext context, FluxUpdateCheck updateCheck) async {
    if (!updateCheck.isUpdateAvailable) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(t.settingsTab.updateCheck.upToDateTitle),
          content: Text(t.settingsTab.updateCheck.upToDateMessage(version: updateCheck.installedVersion)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.settingsTab.updateCheck.done),
            ),
          ],
        ),
      );
      return;
    }

    final asset = updateCheck.installAsset;
    final target = asset?.downloadUri ?? updateCheck.release.releasePageUri;
    final installMessage = asset == null ? t.settingsTab.updateCheck.noMatchingAsset : t.settingsTab.updateCheck.downloading(name: asset.name);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.settingsTab.updateCheck.newVersionTitle(version: updateCheck.release.version)),
        content: Text(t.settingsTab.updateCheck.newVersionMessage(installMessage: installMessage, version: updateCheck.installedVersion)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.settingsTab.updateCheck.later),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final launched = await launchUrl(target, mode: LaunchMode.externalApplication);
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.settingsTab.updateCheck.openPageFailed)),
                );
              }
            },
            child: Text(asset == null ? t.settingsTab.updateCheck.openReleasePage : t.settingsTab.updateCheck.downloadUpdate),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsError(BuildContext context, Object error, StackTrace stackTrace) {
    return _buildSettingsErrorScaffold(
      context,
      error,
      stackTrace,
      onRetry: () {
        if (mounted) {
          setState(() => _settingsReloadKey++);
        }
      },
    );
  }
}

Widget _buildSettingsLoading(BuildContext context) {
  return const Stack(
    children: [
      Center(child: CircularProgressIndicator()),
      _SettingsAppBar(),
    ],
  );
}

Widget _buildSettingsErrorScaffold(
  BuildContext context,
  Object error,
  StackTrace stackTrace, {
  required VoidCallback onRetry,
}) {
  return Stack(
    children: [
      _SettingsFallback(
        error: error,
        onRetry: onRetry,
      ),
      const _SettingsAppBar(),
    ],
  );
}

class _SettingsAppBar extends StatelessWidget {
  const _SettingsAppBar();

  @override
  Widget build(BuildContext context) {
    final title = SafeArea(
      child: Container(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            t.settingsTab.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );

    return SizedBox(
      height: 50 + MediaQuery.of(context).padding.top,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20.0,
            sigmaY: 20.0,
          ),
          child: checkPlatformIsDesktop() ? MoveWindow(child: title) : title,
        ),
      ),
    );
  }
}

class _SettingsFallback extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _SettingsFallback({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20 + MediaQuery.of(context).padding.right,
        top: 90 + MediaQuery.of(context).padding.top,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.settingsTab.errorFallback.title,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.settingsTab.errorFallback.message(error: error.toString()),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(t.general.retry),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionModeSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final mode = ref.watch(connectionModeProvider);
    final clipboard = ref.watch(clipboardSyncProvider);
    final details = describeFluxConnectionMode(
      mode,
      onlineDeviceCount: clipboard.onlineDeviceCount,
      clipboardEnabled: clipboard.enabled,
    );
    final theme = Theme.of(context);

    return _SettingsSection(
      title: t.settingsTab.connectionModeSection.title,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SegmentedButton<FluxConnectionMode>(
              showSelectedIcon: false,
              selected: {mode},
              onSelectionChanged: (selection) async {
                final selectedMode = selection.first;
                final selectedDetails = await switchFluxConnectionMode(
                  ref,
                  selectedMode,
                  onlineDeviceCount: ref.read(clipboardSyncProvider).onlineDeviceCount,
                  clipboardEnabled: ref.read(clipboardSyncProvider).enabled,
                );
                if (context.mounted) {
                  if (!selectedDetails.activationSucceeded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(selectedDetails.failureMessage ?? t.connectionStatusCard.modeSwitchFailed)),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.connectionStatusCard.switchedNetwork(mode: selectedDetails.title) + selectedDetails.subtitle)),
                  );
                }
              },
              segments: [
                ButtonSegment(
                  value: FluxConnectionMode.localNetwork,
                  icon: const Icon(Icons.router_rounded),
                  label: Text(t.connectionStatusCard.modeLan),
                ),
                ButtonSegment(
                  value: FluxConnectionMode.hotspot,
                  icon: const Icon(Icons.wifi_tethering_rounded),
                  label: Text(t.connectionStatusCard.modeHotspot),
                ),
                ButtonSegment(
                  value: FluxConnectionMode.classicBluetooth,
                  icon: const Icon(Icons.bluetooth_connected_rounded),
                  label: Text(t.connectionStatusCard.modeBluetooth),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: details.clipboardAvailableNow ? theme.colorScheme.primary.withValues(alpha: 0.35) : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      details.bluetoothPairingRequired ? Icons.bluetooth_searching_rounded : Icons.check_circle_rounded,
                      color: details.clipboardAvailableNow ? theme.colorScheme.primary : theme.colorScheme.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${details.title} · ${details.subtitle}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(details.status, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(details.actionHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClipboardSyncSettingsSection extends StatelessWidget {
  const _ClipboardSyncSettingsSection();

  @override
  Widget build(BuildContext context) {
    final clipboard = context.ref.watch(clipboardSyncProvider);

    return _SettingsSection(
      title: t.settingsTab.clipboardSection.title,
      children: [
        _BooleanEntry(
          label: t.settingsTab.clipboardSection.alwaysSync,
          value: clipboard.enabled,
          onChanged: (_) => context.ref.notifier(clipboardSyncProvider).toggle(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            clipboard.statusMessage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            t.settingsTab.clipboardSection.targets(count: clipboard.onlineDeviceCount),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (clipboard.lastSyncedText case final text?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              t.settingsTab.clipboardSection.lastSync(text: text.length > 50 ? text.substring(0, 50) : text),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (clipboard.syncCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t.settingsTab.clipboardSection.totalSync(count: clipboard.syncCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (clipboard.lastError case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t.settingsTab.clipboardSection.error(error: error),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsEntry({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(label),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// A specialized version of [_SettingsEntry].
class _BooleanEntry extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanEntry({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsEntry(
      label: label,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor,
              borderRadius: theme.inputDecorationTheme.borderRadius,
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: theme.colorScheme.primary,
                activeThumbColor: theme.colorScheme.onPrimary,
                inactiveThumbColor: theme.colorScheme.outline,
                inactiveTrackColor: theme.colorScheme.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A specialized version of [_SettingsEntry].
class _ButtonEntry extends StatelessWidget {
  final String label;
  final String buttonLabel;
  final void Function() onTap;

  const _ButtonEntry({
    required this.label,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsEntry(
      label: label,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
          shape: RoundedRectangleBorder(borderRadius: Theme.of(context).inputDecorationTheme.borderRadius),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            buttonLabel,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsets padding;

  const _SettingsSection({
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.only(bottom: 15),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

extension on ThemeMode {
  String get humanName {
    switch (this) {
      case ThemeMode.system:
        return t.settingsTab.general.brightnessOptions.system;
      case ThemeMode.light:
        return t.settingsTab.general.brightnessOptions.light;
      case ThemeMode.dark:
        return t.settingsTab.general.brightnessOptions.dark;
    }
  }
}

extension on ColorMode {
  String get humanName {
    return switch (this) {
      ColorMode.system => t.settingsTab.general.colorOptions.system,
      ColorMode.localsend => t.appName,
      ColorMode.oled => t.settingsTab.general.colorOptions.oled,
      ColorMode.yaru => 'Yaru',
    };
  }
}
