part of 'settings_tab.dart';

extension _SettingsTabSections on _SettingsTabState {
  List<Widget> _buildGeneralSection(SettingsTabVm vm, Ref ref) {
    return [
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
    ];
  }

  List<Widget> _buildReceiveSection(SettingsTabVm vm, Ref ref) {
    return [
      _SettingsSection(
        title: t.settingsTab.receive.title,
        children: [
          _BooleanEntry(
            label: t.settingsTab.receive.quickSave,
            value: vm.settings.quickSave,
            onChanged: (b) async {
              final old = vm.settings.quickSave;
              await ref.notifier(settingsProvider).setQuickSave(b);
              if (!old && b && mounted) {
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
              if (!old && b && mounted) {
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
    ];
  }

  List<Widget> _buildSendSection(SettingsTabVm vm, Ref ref) {
    return [
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
    ];
  }

  List<Widget> _buildNetworkSection(SettingsTabVm vm, Ref ref) {
    return [
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
                if (old && !b && mounted) {
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
    ];
  }

  List<Widget> _buildOtherSection(SettingsTabVm vm, Ref ref) {
    return [
      _SettingsSection(
        title: t.settingsTab.other.title,
        padding: const EdgeInsets.only(bottom: 0),
        children: [
          _ButtonEntry(
            label: t.settingsTab.other.usageGuide,
            buttonLabel: t.onboarding.confirm,
            onTap: () async {
              await showOnboardingDialog(context);
            },
          ),
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
    ];
  }
}
