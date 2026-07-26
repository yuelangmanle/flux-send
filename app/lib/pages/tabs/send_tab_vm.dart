import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/pages/progress_page.dart';
import 'package:localsend_app/pages/send_page.dart';
import 'package:localsend_app/pages/web_send_page.dart';
import 'package:localsend_app/provider/connection_mode_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/dialogs/address_input_dialog.dart';
import 'package:localsend_app/widget/dialogs/favorite_delete_dialog.dart';
import 'package:localsend_app/widget/dialogs/favorite_dialog.dart';
import 'package:localsend_app/widget/dialogs/favorite_edit_dialog.dart';
import 'package:localsend_app/widget/dialogs/no_files_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SendTabVm {
  final SendMode sendMode;
  final List<CrossFile> selectedFiles;
  final List<String> localIps;
  final Iterable<Device> nearbyDevices;
  final List<FavoriteDevice> favoriteDevices;
  final Future<void> Function(BuildContext context) onTapAddress;
  final Future<void> Function(BuildContext context) onTapFavorite;
  final Future<void> Function(BuildContext context, SendMode mode) onTapSendMode;
  final Future<void> Function(BuildContext context, Device device) onToggleFavorite;
  final Future<void> Function(BuildContext context, Device device) onTapDevice;
  final Future<void> Function(BuildContext context, Device device) onTapDeviceMultiSend;

  const SendTabVm({
    required this.sendMode,
    required this.selectedFiles,
    required this.localIps,
    required this.nearbyDevices,
    required this.favoriteDevices,
    required this.onTapAddress,
    required this.onTapFavorite,
    required this.onTapSendMode,
    required this.onToggleFavorite,
    required this.onTapDevice,
    required this.onTapDeviceMultiSend,
  });
}

final sendTabVmProvider = ViewProvider((ref) {
  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
  final selectedFiles = ref.watch(selectedSendingFilesProvider);
  final localIps = ref.watch(localIpProvider).localIps;
  final connectionMode = ref.watch(connectionModeProvider);
  final usingClassicBluetooth = connectionMode == FluxConnectionMode.classicBluetooth;
  final nearbyDevices = usingClassicBluetooth ? const <Device>[] : ref.watch(nearbyDevicesProvider).allDevices.values;
  final favoriteDevices = usingClassicBluetooth ? const <FavoriteDevice>[] : ref.watch(favoritesProvider);

  return SendTabVm(
    sendMode: sendMode,
    selectedFiles: selectedFiles,
    localIps: localIps,
    nearbyDevices: nearbyDevices,
    favoriteDevices: favoriteDevices,
    onTapAddress: (context) async {
      if (ref.read(connectionModeProvider) == FluxConnectionMode.classicBluetooth) {
        context.showSnackBar('经典蓝牙模式不会使用手动 IP。请在上方蓝牙设备列表连接后，使用「通过蓝牙发送」。');
        return;
      }
      final device = await showDialog<Device?>(
        context: context,
        builder: (_) => const AddressInputDialog(),
      );
      final files = ref.read(selectedSendingFilesProvider);
      if (device != null && files.isNotEmpty && context.mounted) {
        await ref
            .notifier(sendProvider)
            .startSession(
              target: device,
              files: files,
              background: false,
            );
      } else if (device != null && context.mounted) {
        context.showSnackBar('已加入设备，可用于剪切板自动同步；选择文件后也可以直接发送。');
      }
    },
    onTapFavorite: (context) async {
      if (ref.read(connectionModeProvider) == FluxConnectionMode.classicBluetooth) {
        context.showSnackBar('经典蓝牙模式不会使用收藏的局域网设备。请连接已配对蓝牙设备后再发送。');
        return;
      }
      final device = await showDialog<Device?>(
        context: context,
        builder: (_) => const FavoritesDialog(),
      );
      if (device != null && context.mounted) {
        final files = ref.read(selectedSendingFilesProvider);
        if (files.isEmpty) {
          context.showSnackBar('已加入收藏设备，可用于剪切板自动同步；选择文件后也可以直接发送。');
          return;
        }

        await ref
            .notifier(sendProvider)
            .startSession(
              target: device,
              files: files,
              background: false,
            );
      }
    },
    onTapSendMode: (context, mode) async {
      if (mode == SendMode.link) {
        final files = ref.read(selectedSendingFilesProvider);
        if (files.isEmpty) {
          await context.pushBottomSheet(() => const NoFilesDialog());
          return;
        }
        await context.push(() => WebSendPage(files));
        return;
      }

      await ref.notifier(settingsProvider).setSendMode(mode);
      if (mode != SendMode.multiple) {
        ref.notifier(sendProvider).clearAllSessions();
      }
    },
    onToggleFavorite: (context, device) async {
      final favoriteDevice = favoriteDevices.findDevice(device);
      if (favoriteDevice != null) {
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => FavoriteDeleteDialog(favoriteDevice),
        );
        if (result == true) {
          await ref.redux(favoritesProvider).dispatchAsync(RemoveFavoriteAction(deviceFingerprint: device.fingerprint));
        }
      } else {
        await showDialog(
          context: context,
          builder: (_) => FavoriteEditDialog(prefilledDevice: device),
        );
      }
    },
    onTapDevice: (context, device) async {
      if (ref.read(connectionModeProvider) == FluxConnectionMode.classicBluetooth) {
        context.showSnackBar('经典蓝牙模式不会通过局域网设备发送。请使用上方「通过蓝牙发送」。');
        return;
      }
      if (selectedFiles.isEmpty) {
        context.showSnackBar('设备在线，可用于剪切板自动同步；选择文件后也可以直接发送。');
        return;
      }

      await ref
          .notifier(sendProvider)
          .startSession(
            target: device,
            files: selectedFiles,
            background: false,
          );
    },
    onTapDeviceMultiSend: (context, device) async {
      if (ref.read(connectionModeProvider) == FluxConnectionMode.classicBluetooth) {
        context.showSnackBar('经典蓝牙模式不会通过局域网设备发送。请使用上方「通过蓝牙发送」。');
        return;
      }
      final session = ref.read(sendProvider).values.firstWhereOrNull((s) => s.target.ip == device.ip);
      if (session != null) {
        if (session.status == SessionStatus.waiting) {
          ref.notifier(sendProvider).setBackground(session.sessionId, false);
          await context.push(
            () => SendPage(showAppBar: true, closeSessionOnClose: false, sessionId: session.sessionId),
            transition: RouterinoTransition.fade(),
          );
          ref.notifier(sendProvider).setBackground(session.sessionId, true);
          return;
        } else if (session.status == SessionStatus.sending || session.status == SessionStatus.finishedWithErrors) {
          ref.notifier(sendProvider).setBackground(session.sessionId, false);
          await context.push(() => ProgressPage(showAppBar: true, closeSessionOnClose: false, sessionId: session.sessionId));
          ref.notifier(sendProvider).setBackground(session.sessionId, true);
          return;
        }
      }

      final files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty) {
        context.showSnackBar('设备在线，可用于剪切板自动同步；选择文件后也可以直接发送。');
        return;
      }

      if (session != null) {
        // close old session
        ref.notifier(sendProvider).closeSession(session.sessionId);
      }

      await ref
          .notifier(sendProvider)
          .startSession(
            target: device,
            files: files,
            background: true,
          );
    },
  );
});

class SendTabInitAction extends AsyncGlobalAction {
  final BuildContext context;

  SendTabInitAction(this.context);

  @override
  Future<void> reduce() async {
    if (ref.read(connectionModeProvider) == FluxConnectionMode.classicBluetooth) {
      return;
    }
    final devices = ref.read(nearbyDevicesProvider).devices;
    if (devices.isEmpty) {
      await dispatchAsync(StartSmartScan(forceLegacy: false));
    }
  }
}
