import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/classic_bluetooth_provider.dart';
import 'package:localsend_app/provider/clipboard_sync_provider.dart';
import 'package:localsend_app/provider/connection_mode_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:system_settings_2/system_settings_2.dart';

class FluxConnectionStatusCard extends StatelessWidget {
  final bool compact;

  const FluxConnectionStatusCard({
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final theme = Theme.of(context);
    final mode = ref.watch(connectionModeProvider);
    final bluetooth = mode == FluxConnectionMode.classicBluetooth ? ref.watch(classicBluetoothProvider) : null;
    final clipboard = ref.watch(clipboardSyncProvider);
    final nearby = ref.watch(nearbyDevicesProvider);
    final localIpState = ref.watch(localIpProvider);
    final server = ref.watch(serverProvider);
    final selectedFiles = ref.watch(selectedSendingFilesProvider);
    final ownFingerprint = ref.watch(securityProvider).certificateHash;
    final discoveryLogs = ref.watch(discoveryLoggerProvider);
    final targetCount = selectClipboardSyncTargets(
      nearby,
      ownFingerprint: ownFingerprint,
      localIps: localIpState.localIps,
    ).length;
    final details = describeFluxConnectionMode(
      mode,
      onlineDeviceCount: targetCount,
      clipboardEnabled: clipboard.enabled,
    );
    final scanning = nearby.runningFavoriteScan || nearby.runningIps.isNotEmpty;
    final lastDiscoveryLog = discoveryLogs.isEmpty ? '还没有发现日志，点「刷新扫描」会立刻触发 UDP + TCP 扫描。' : discoveryLogs.last.log;

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: theme.brightness == Brightness.light ? 0.46 : 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.92),
                        theme.colorScheme.secondary.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.hub_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.connectionStatusCard.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  icon: server == null ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                  label: server == null ? t.connectionStatusCard.serverOffline : t.connectionStatusCard.serverOnline,
                  color: server == null ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<FluxConnectionMode>(
              showSelectedIcon: false,
              selected: {mode},
              onSelectionChanged: (selection) => _setMode(context, ref, selection.first),
              segments: [
                ButtonSegment(
                  value: FluxConnectionMode.localNetwork,
                  icon: Icon(Icons.router_rounded),
                  label: Text(t.connectionStatusCard.modeLan),
                ),
                ButtonSegment(
                  value: FluxConnectionMode.hotspot,
                  icon: Icon(Icons.wifi_tethering_rounded),
                  label: Text(t.connectionStatusCard.modeHotspot),
                ),
                ButtonSegment(
                  value: FluxConnectionMode.classicBluetooth,
                  icon: Icon(Icons.bluetooth_connected_rounded),
                  label: Text(t.connectionStatusCard.modeBluetooth),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  icon: mode == FluxConnectionMode.classicBluetooth
                      ? (bluetooth?.connected == true ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded)
                      : (scanning ? Icons.sync_rounded : Icons.radar_rounded),
                  label: mode == FluxConnectionMode.classicBluetooth
                      ? (bluetooth?.connected == true
                            ? t.connectionStatusCard.btConnected
                            : bluetooth?.listening == true
                            ? '蓝牙监听中'
                            : t.connectionStatusCard.btNotListening)
                      : (scanning ? t.connectionStatusCard.tcpScanning(count: nearby.runningIps.length) : t.connectionStatusCard.udpStandby),
                  color: mode == FluxConnectionMode.classicBluetooth
                      ? (bluetooth?.connected == true ? theme.colorScheme.primary : theme.colorScheme.secondary)
                      : (scanning ? theme.colorScheme.tertiary : theme.colorScheme.primary),
                ),
                _StatusPill(
                  icon: mode == FluxConnectionMode.classicBluetooth
                      ? Icons.bluetooth_rounded
                      : (targetCount > 0 ? Icons.devices_rounded : Icons.devices_other_rounded),
                  label: mode == FluxConnectionMode.classicBluetooth
                      ? t.connectionStatusCard.btPairedCount(count: bluetooth?.pairedDevices.length ?? 0)
                      : t.connectionStatusCard.syncTargetsCount(count: targetCount),
                  color: mode == FluxConnectionMode.classicBluetooth
                      ? ((bluetooth?.pairedDevices.isNotEmpty ?? false) ? theme.colorScheme.primary : theme.colorScheme.outline)
                      : (targetCount > 0 ? theme.colorScheme.primary : theme.colorScheme.outline),
                ),
                _StatusPill(
                  icon: clipboard.enabled ? Icons.content_paste_go_rounded : Icons.content_paste_off_rounded,
                  label: clipboard.enabled ? t.connectionStatusCard.clipboardAutoSync : t.connectionStatusCard.clipboardOff,
                  color: clipboard.enabled ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                _StatusPill(
                  icon: localIpState.localIps.isEmpty ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                  label: localIpState.localIps.isEmpty ? t.connectionStatusCard.noIp : localIpState.localIps.take(2).join(' / '),
                  color: localIpState.localIps.isEmpty ? theme.colorScheme.error : theme.colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatusLine(
              icon: details.bluetoothPairingRequired ? Icons.bluetooth_searching_rounded : Icons.lan_rounded,
              text: details.status,
            ),
            const SizedBox(height: 8),
            _StatusLine(
              icon: Icons.dns_rounded,
              text: server == null
                  ? t.connectionStatusCard.serverDown
                  : t.connectionStatusCard.serverInfo(port: server.port, protocol: server.https ? 'HTTPS' : 'HTTP', alias: server.alias),
            ),
            const SizedBox(height: 8),
            _StatusLine(
              icon: clipboard.lastError == null ? Icons.history_rounded : Icons.warning_amber_rounded,
              text: clipboard.lastError == null
                  ? clipboard.statusMessage + (clipboard.lastSyncTime == null ? '' : '；最近同步 ${_formatTime(clipboard.lastSyncTime!)}')
                  : t.connectionStatusCard.clipboardError(error: clipboard.lastError ?? ''),
            ),
            const SizedBox(height: 8),
            _StatusLine(
              icon: Icons.receipt_long_rounded,
              text: mode == FluxConnectionMode.classicBluetooth ? (bluetooth?.statusMessage ?? t.connectionStatusCard.btPreparing) : lastDiscoveryLog,
            ),
            if (mode == FluxConnectionMode.classicBluetooth) ...[
              const SizedBox(height: 10),
              _BluetoothDevicesPanel(bluetooth: bluetooth),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _refreshScan(context, ref),
                  icon: Icon(mode == FluxConnectionMode.classicBluetooth ? Icons.bluetooth_searching_rounded : Icons.sync_rounded),
                  label: Text(
                    mode == FluxConnectionMode.classicBluetooth ? t.connectionStatusCard.refreshBtDevices : t.connectionStatusCard.refreshScan,
                  ),
                ),
                if (mode == FluxConnectionMode.classicBluetooth)
                  OutlinedButton.icon(
                    onPressed: () => _openBluetoothSettings(context),
                    icon: const Icon(Icons.settings_bluetooth_rounded),
                    label: Text(t.connectionStatusCard.openBtSettings),
                  ),
                if (mode == FluxConnectionMode.classicBluetooth && selectedFiles.isNotEmpty)
                  FilledButton.icon(
                    onPressed: bluetooth?.connected == true ? () => unawaited(ref.notifier(classicBluetoothProvider).sendFiles(selectedFiles)) : null,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(t.connectionStatusCard.btSendFiles(count: selectedFiles.length)),
                  ),
                FilledButton.tonalIcon(
                  onPressed: ref.notifier(clipboardSyncProvider).toggle,
                  icon: Icon(clipboard.enabled ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(clipboard.enabled ? t.connectionStatusCard.pauseClipboard : t.connectionStatusCard.enableClipboard),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setMode(BuildContext context, Ref ref, FluxConnectionMode mode) {
    final messenger = ScaffoldMessenger.of(context);
    unawaited(
      switchFluxConnectionMode(
        ref,
        mode,
        onlineDeviceCount: ref.read(clipboardSyncProvider).onlineDeviceCount,
        clipboardEnabled: ref.read(clipboardSyncProvider).enabled,
      ).then((details) {
        if (!details.activationSucceeded) {
          _showSnackBar(messenger, details.failureMessage ?? t.connectionStatusCard.modeSwitchFailed);
          return;
        }
        if (mode == FluxConnectionMode.classicBluetooth) {
          _showSnackBar(messenger, t.connectionStatusCard.switchedBluetooth);
          return;
        }
        _showSnackBar(messenger, t.connectionStatusCard.switchedNetwork(mode: details.title));
      }),
    );
  }

  void _refreshScan(BuildContext context, Ref ref) {
    final messenger = ScaffoldMessenger.of(context);
    final mode = ref.read(connectionModeProvider);

    if (mode == FluxConnectionMode.classicBluetooth) {
      unawaited(ref.notifier(classicBluetoothProvider).startListening());
      unawaited(ref.notifier(classicBluetoothProvider).refreshPairedDevices());
      _showSnackBar(messenger, t.connectionStatusCard.refreshedBtDevices);
      return;
    }

    ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
    unawaited(ref.global.dispatchAsync(StartSmartScan(forceLegacy: true)));
    _showSnackBar(messenger, t.connectionStatusCard.refreshedScan);
  }

  void _openBluetoothSettings(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    if (checkPlatform([TargetPlatform.android, TargetPlatform.iOS])) {
      unawaited(SystemSettings.bluetooth());
      return;
    }

    if (checkPlatform([TargetPlatform.macOS])) {
      unawaited(Process.run('open', ['x-apple.systempreferences:com.apple.BluetoothSettings']));
      _showSnackBar(messenger, t.connectionStatusCard.btSettingsOpened);
      return;
    }

    _showSnackBar(messenger, t.connectionStatusCard.btSettingsUnsupported);
  }

  void _showSnackBar(ScaffoldMessengerState messenger, String text) {
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

class _BluetoothDevicesPanel extends StatelessWidget {
  final ClassicBluetoothState? bluetooth;

  const _BluetoothDevicesPanel({
    required this.bluetooth,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final theme = Theme.of(context);
    final state = bluetooth;

    if (state == null) {
      return const SizedBox.shrink();
    }

    if (state.pairedDevices.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            state.refreshing ? t.connectionStatusCard.readingPairedDevices : t.connectionStatusCard.noPairedDevices,
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (final device in state.pairedDevices)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(
                  state.connectedAddress == device.address && state.connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                  color: state.connectedAddress == device.address && state.connected ? theme.colorScheme.primary : theme.colorScheme.secondary,
                ),
                title: Text(device.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(device.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: FilledButton.tonal(
                  onPressed: state.connecting ? null : () => ref.notifier(classicBluetoothProvider).connect(device),
                  child: Text(
                    state.connectedAddress == device.address && state.connected
                        ? t.connectionStatusCard.statusConnected
                        : state.connectedAddress == device.address && state.connecting
                        ? t.connectionStatusCard.statusConnecting
                        : t.connectionStatusCard.statusConnect,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: theme.brightness == Brightness.light ? 0.12 : 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatusLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}
