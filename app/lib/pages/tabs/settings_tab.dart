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
                  _SettingsSection(
                    title: t.settingsTab.general.title,
                    children: [
                      _SettingsEntry(
                        label: t.settingsTab.general.brightness,
                        child: CustomDropdownButton<ThemeMode>(
                          value: vm.settings.theme,
                          items: vm.themeModes.map((theme) {
                            return DropdownMenuItem(
                              value: theme,
                              alignment: Alignment.center,
                              child: Text(theme.humanName),
                            );
                          }).toList(),
                          onChanged: (theme) => vm.onChangeTheme(context, theme),
                        ),
                      ),
                      _SettingsEntry(
                        label: t.settingsTab.general.color,
                        child: CustomDropdownButton<ColorMode>(
                          value:
                              resolveDropdownValue(
                                value: vm.settings.colorMode,
                                items: vm.colorModes,
                              ) ??
                              vm.colorModes.first,
                          items: vm.colorModes.map((colorMode) {
                            return DropdownMenuItem(
                              value: colorMode,
                              alignment: Alignment.center,
                              child: Text(colorMode.humanName),
                            );
                          }).toList(),
                          onChanged: vm.onChangeColorMode,
                        ),
                      ),
                      _ButtonEntry(
                        label: t.settingsTab.general.language,
                        buttonLabel: vm.settings.locale?.humanName ?? t.settingsTab.general.languageOptions.system,
                        onTap: () => vm.onTapLanguage(context),
                      ),
                      if (checkPlatformIsDesktop()) ...[
                        /// Wayland does window position handling, so there's no need for it. See [https://github.com/localsend/localsend/issues/544]
                        if (vm.advanced && checkPlatformIsNotWaylandDesktop())
                          _BooleanEntry(
                            label: defaultTargetPlatform == TargetPlatform.windows
                                ? t.settingsTab.general.saveWindowPlacementWindows
                                : t.settingsTab.general.saveWindowPlacement,
                            value: vm.settings.saveWindowPlacement,
                            onChanged: (b) async {
                              await ref.notifier(settingsProvider).setSaveWindowPlacement(b);
                            },
                          ),
                        if (checkPlatformHasTray()) ...[
                          _BooleanEntry(
                            label: t.settingsTab.general.minimizeToTray,
                            value: vm.settings.minimizeToTray,
                            onChanged: (b) async {
                              await ref.notifier(settingsProvider).setMinimizeToTray(b);
                            },
                          ),
                        ],
                        if (checkPlatformIsDesktop()) ...[
                          _BooleanEntry(
                            label: t.settingsTab.general.launchAtStartup,
                            value: vm.autoStart,
                            onChanged: (_) => vm.onToggleAutoStart(context),
                          ),
                          Visibility(
                            visible: vm.autoStart,
                            maintainAnimation: true,
                            maintainState: true,
                            child: AnimatedOpacity(
                              opacity: vm.autoStart ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 500),
                              child: _BooleanEntry(
                                label: t.settingsTab.general.launchMinimized,
                                value: vm.autoStartLaunchHidden,
                                onChanged: (_) => vm.onToggleAutoStartLaunchHidden(context),
                              ),
                            ),
                          ),
                        ],
                        if (vm.advanced && checkPlatform([TargetPlatform.windows])) ...[
                          _BooleanEntry(
                            label: t.settingsTab.general.showInContextMenu,
                            value: vm.showInContextMenu,
                            onChanged: (_) => vm.onToggleShowInContextMenu(context),
                          ),
                        ],
                      ],
                      _BooleanEntry(
                        label: t.settingsTab.general.animations,
                        value: vm.settings.enableAnimations,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setEnableAnimations(b);
                        },
                      ),
                    ],
                  ),
                  _ConnectionModeSection(),
                  const _ClipboardSyncSettingsSection(),
                  _SettingsSection(
                    title: t.settingsTab.receive.title,
                    children: [
                      _BooleanEntry(
                        label: t.settingsTab.receive.quickSave,
                        value: vm.settings.quickSave,
                        onChanged: (b) async {
                          final old = vm.settings.quickSave;
                          await ref.notifier(settingsProvider).setQuickSave(b);
                          if (!old && b && context.mounted) {
                            await QuickSaveNotice.open(context);
                          }
                        },
                      ),
                      _BooleanEntry(
                        label: t.settingsTab.receive.quickSaveFromFavorites,
                        value: vm.settings.quickSaveFromFavorites,
                        onChanged: (b) async {
                          final old = vm.settings.quickSaveFromFavorites;
                          await ref.notifier(settingsProvider).setQuickSaveFromFavorites(b);
                          if (!old && b && context.mounted) {
                            await QuickSaveFromFavoritesNotice.open(context);
                          }
                        },
                      ),
                      _BooleanEntry(
                        label: t.settingsTab.receive.requirePin,
                        value: vm.settings.receivePin != null,
                        onChanged: (b) async {
                          final currentPIN = vm.settings.receivePin;
                          if (currentPIN != null) {
                            await ref.notifier(settingsProvider).setReceivePin(null);
                          } else {
                            final String? newPin = await showDialog<String>(
                              context: context,
                              builder: (_) => const PinDialog(
                                obscureText: false,
                                generateRandom: false,
                              ),
                            );

                            if (newPin != null && newPin.isNotEmpty) {
                              await ref.notifier(settingsProvider).setReceivePin(newPin);
                            }
                          }
                        },
                      ),
                      if (checkPlatformWithFileSystem())
                        _SettingsEntry(
                          label: t.settingsTab.receive.destination,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
                              shape: RoundedRectangleBorder(borderRadius: Theme.of(context).inputDecorationTheme.borderRadius),
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () async {
                              if (vm.settings.destination != null) {
                                await ref.notifier(settingsProvider).setDestination(null);
                                if (defaultTargetPlatform == TargetPlatform.macOS) {
                                  await removeExistingDestinationAccess();
                                }
                                return;
                              }

                              final directory = await pickDirectoryPath();
                              if (directory != null) {
                                if (defaultTargetPlatform == TargetPlatform.macOS) {
                                  await persistDestinationFolderAccess(directory);
                                }
                                await ref.notifier(settingsProvider).setDestination(directory);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Text(
                                describeDestinationDisplayLabel(
                                  destination: vm.settings.destination,
                                  defaultDownloadsLabel: t.settingsTab.receive.downloads,
                                  isAndroid: defaultTargetPlatform == TargetPlatform.android,
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ),
                      if (checkPlatformWithGallery())
                        _BooleanEntry(
                          label: t.settingsTab.receive.saveToGallery,
                          value: vm.settings.saveToGallery,
                          onChanged: (b) async {
                            await ref.notifier(settingsProvider).setSaveToGallery(b);
                          },
                        ),
                      _BooleanEntry(
                        label: t.settingsTab.receive.autoFinish,
                        value: vm.settings.autoFinish,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setAutoFinish(b);
                        },
                      ),
                      _BooleanEntry(
                        label: t.settingsTab.receive.saveToHistory,
                        value: vm.settings.saveToHistory,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setSaveToHistory(b);
                        },
                      ),
                    ],
                  ),
                  if (vm.advanced)
                    _SettingsSection(
                      title: t.settingsTab.send.title,
                      children: [
                        _BooleanEntry(
                          label: t.settingsTab.send.shareViaLinkAutoAccept,
                          value: vm.settings.shareViaLinkAutoAccept,
                          onChanged: (b) async {
                            await ref.notifier(settingsProvider).setShareViaLinkAutoAccept(b);
                          },
                        ),
                      ],
                    ),
                  _SettingsSection(
                    title: t.settingsTab.network.title,
                    children: [
                      AnimatedCrossFade(
                        crossFadeState:
                            vm.serverState != null &&
                                (vm.serverState!.alias != vm.settings.alias ||
                                    vm.serverState!.port != vm.settings.port ||
                                    vm.serverState!.https != vm.settings.https)
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topLeft,
                        firstChild: Container(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(t.settingsTab.network.needRestart, style: TextStyle(color: Theme.of(context).colorScheme.warning)),
                        ),
                      ),
                      _SettingsEntry(
                        label: '${t.settingsTab.network.server}${vm.serverState == null ? ' (${t.general.offline})' : ''}',
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).inputDecorationTheme.fillColor,
                            borderRadius: Theme.of(context).inputDecorationTheme.borderRadius,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (vm.serverState == null)
                                Tooltip(
                                  message: t.general.start,
                                  child: TextButton(
                                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                                    onPressed: () => vm.onTapStartServer(context),
                                    child: const Icon(Icons.play_arrow),
                                  ),
                                )
                              else
                                Tooltip(
                                  message: t.general.restart,
                                  child: TextButton(
                                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                                    onPressed: () => vm.onTapRestartServer(context),
                                    child: const Icon(Icons.refresh),
                                  ),
                                ),
                              Tooltip(
                                message: t.general.stop,
                                child: TextButton(
                                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                                  onPressed: vm.serverState == null ? null : vm.onTapStopServer,
                                  child: const Icon(Icons.stop),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SettingsEntry(
                        label: t.settingsTab.network.alias,
                        child: TextFieldWithActions(
                          name: t.settingsTab.network.alias,
                          controller: vm.aliasController,
                          onChanged: (s) async {
                            await ref.notifier(settingsProvider).setAlias(s);
                          },
                          actions: [
                            Tooltip(
                              message: t.settingsTab.network.generateRandomAlias,
                              child: IconButton(
                                onPressed: () async {
                                  // Generates random alias
                                  final newAlias = generateRandomAlias();

                                  // Update the TextField with the new alias
                                  vm.aliasController.text = newAlias;

                                  // Persist the new alias using the settingsProvider
                                  await ref.notifier(settingsProvider).setAlias(newAlias);
                                },
                                icon: const Icon(Icons.casino),
                              ),
                            ),
                            Tooltip(
                              message: t.settingsTab.network.useSystemName,
                              child: IconButton(
                                onPressed: () async {
                                  final String newAlias;
                                  if (Platform.isMacOS) {
                                    final result = await Process.run('scutil', ['--get', 'ComputerName']);
                                    newAlias = result.stdout.toString().trim();
                                  } else {
                                    newAlias = Platform.localHostname;
                                  }

                                  vm.aliasController.text = newAlias;
                                  await ref.notifier(settingsProvider).setAlias(newAlias);
                                },
                                icon: const Icon(Icons.desktop_windows_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.deviceType,
                          child: CustomDropdownButton<DeviceType>(
                            value: vm.deviceInfo.deviceType,
                            items: DeviceType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                alignment: Alignment.center,
                                child: Icon(type.icon),
                              );
                            }).toList(),
                            onChanged: (type) async {
                              await ref.notifier(settingsProvider).setDeviceType(type);
                            },
                          ),
                        ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.deviceModel,
                          child: FluxTextField(
                            name: t.settingsTab.network.deviceModel,
                            controller: vm.deviceModelController,
                            onChanged: (s) async {
                              await ref.notifier(settingsProvider).setDeviceModel(s);
                            },
                          ),
                        ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.port,
                          child: FluxTextField(
                            name: t.settingsTab.network.port,
                            controller: vm.portController,
                            onChanged: (s) async {
                              final port = int.tryParse(s);
                              if (port != null) {
                                await ref.notifier(settingsProvider).setPort(port);
                              }
                            },
                          ),
                        ),
                      if (vm.advanced)
                        _ButtonEntry(
                          label: t.settingsTab.network.network,
                          buttonLabel: switch (vm.settings.networkWhitelist != null || vm.settings.networkBlacklist != null) {
                            true => t.settingsTab.network.networkOptions.filtered,
                            false => t.settingsTab.network.networkOptions.all,
                          },
                          onTap: () async {
                            await context.push(() => const NetworkInterfacesPage());
                          },
                        ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.discoveryTimeout,
                          child: FluxTextField(
                            name: t.settingsTab.network.discoveryTimeout,
                            controller: vm.timeoutController,
                            onChanged: (s) async {
                              final timeout = int.tryParse(s);
                              if (timeout != null) {
                                await ref.notifier(settingsProvider).setDiscoveryTimeout(timeout);
                              }
                            },
                          ),
                        ),
                      if (vm.advanced)
                        _BooleanEntry(
                          label: t.settingsTab.network.encryption,
                          value: vm.settings.https,
                          onChanged: (b) async {
                            final old = vm.settings.https;
                            await ref.notifier(settingsProvider).setHttps(b);
                            if (old && !b && context.mounted) {
                              await EncryptionDisabledNotice.open(context);
                            }
                          },
                        ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.multicastGroup,
                          child: FluxTextField(
                            name: t.settingsTab.network.multicastGroup,
                            controller: vm.multicastController,
                            onChanged: (s) async {
                              await ref.notifier(settingsProvider).setMulticastGroup(s);
                            },
                          ),
                        ),
                      AnimatedCrossFade(
                        crossFadeState: vm.settings.port != defaultPort ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topLeft,
                        firstChild: Container(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(
                            t.settingsTab.network.portWarning(defaultPort: defaultPort),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        crossFadeState: vm.settings.multicastGroup != defaultMulticastGroup ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topLeft,
                        firstChild: Container(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(
                            t.settingsTab.network.multicastGroupWarning(defaultMulticast: defaultMulticastGroup),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: t.settingsTab.other.title,
                    padding: const EdgeInsets.only(bottom: 0),
                    children: [
                      _ButtonEntry(
                        label: '检查更新',
                        buttonLabel: '检查',
                        onTap: () => _checkForUpdates(context),
                      ),
                      _ButtonEntry(
                        label: t.aboutPage.title,
                        buttonLabel: t.general.open,
                        onTap: () async {
                          await context.push(() => const AboutPage());
                        },
                      ),
                      _ButtonEntry(
                        label: t.settingsTab.other.privacyPolicy,
                        buttonLabel: t.general.open,
                        onTap: () async {
                          await launchUrl(
                            Uri.parse('https://localsend.org/privacy'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                      if (checkPlatform([TargetPlatform.iOS, TargetPlatform.macOS]))
                        _ButtonEntry(
                          label: t.settingsTab.other.termsOfUse,
                          buttonLabel: t.general.open,
                          onTap: () async {
                            await launchUrl(
                              Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                    ],
                  ),
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
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('正在检查 GitHub 最新版本…')),
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
          title: const Text('检查更新失败'),
          content: Text('无法连接 GitHub 获取更新信息。请确认网络后重试。\n\n$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
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
          title: const Text('已是最新版本'),
          content: Text('当前版本 ${updateCheck.installedVersion} 已是 GitHub 上的最新正式版。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('完成'),
            ),
          ],
        ),
      );
      return;
    }

    final asset = updateCheck.installAsset;
    final target = asset?.downloadUri ?? updateCheck.release.releasePageUri;
    final installMessage = asset == null ? '此平台暂未提供匹配的安装包。将为你打开 GitHub 发布页。' : '将打开浏览器下载 ${asset.name}。下载后请按系统提示完成安装。';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('发现新版本 ${updateCheck.release.version}'),
        content: Text('$installMessage\n\n当前版本：${updateCheck.installedVersion}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('暂不更新'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final launched = await launchUrl(target, mode: LaunchMode.externalApplication);
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('无法打开下载页面，请稍后重试。')),
                );
              }
            },
            child: Text(asset == null ? '打开发布页' : '下载更新'),
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
                          '设置页加载失败',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Flux 已拦截本次异常，没有让页面继续白屏。请点重试重新加载设置页；如果仍失败，把下面这段错误反馈给我。',
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
                      label: const Text('重试'),
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
      title: '连接模式',
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
                      SnackBar(content: Text(selectedDetails.failureMessage ?? '连接模式切换失败，已回到上一种模式。')),
                    );
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已切换到${selectedDetails.title}：${selectedDetails.subtitle}')),
                  );
                }
              },
              segments: const [
                ButtonSegment(
                  value: FluxConnectionMode.localNetwork,
                  icon: Icon(Icons.router_rounded),
                  label: Text('局域网'),
                ),
                ButtonSegment(
                  value: FluxConnectionMode.hotspot,
                  icon: Icon(Icons.wifi_tethering_rounded),
                  label: Text('热点'),
                ),
                ButtonSegment(
                  value: FluxConnectionMode.classicBluetooth,
                  icon: Icon(Icons.bluetooth_connected_rounded),
                  label: Text('蓝牙'),
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
      title: '剪切板同步',
      children: [
        _BooleanEntry(
          label: '常驻同步剪切板',
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
            '可同步设备：${clipboard.onlineDeviceCount} 台',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (clipboard.lastSyncedText case final text?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '最近同步：${text.length > 50 ? text.substring(0, 50) : text}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (clipboard.syncCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '累计同步：${clipboard.syncCount} 次',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (clipboard.lastError case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '错误：$error',
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
