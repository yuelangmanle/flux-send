import 'dart:io';

import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/pages/receive_page.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/file_info_dialog.dart';
import 'package:localsend_app/widget/dialogs/history_clear_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _EntryOption {
  open,
  showInFolder,
  info,
  delete;

  String get label {
    return switch (this) {
      _EntryOption.open => t.receiveHistoryPage.entryActions.open,
      _EntryOption.showInFolder => t.receiveHistoryPage.entryActions.showInFolder,
      _EntryOption.info => t.receiveHistoryPage.entryActions.info,
      _EntryOption.delete => t.receiveHistoryPage.entryActions.deleteFromHistory,
    };
  }
}

const _optionsAll = _EntryOption.values;
final _optionsWithoutOpen = [_EntryOption.info, _EntryOption.delete];

enum _HistoryGrouping {
  day,
  type,
}

class ReceiveHistoryPage extends StatefulWidget {
  const ReceiveHistoryPage({super.key});

  @override
  State<ReceiveHistoryPage> createState() => _ReceiveHistoryPageState();
}

class _ReceiveHistoryPageState extends State<ReceiveHistoryPage> {
  _HistoryGrouping _grouping = _HistoryGrouping.day;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedEntryIds = {};
  bool _selectionMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFile(
    BuildContext context,
    ReceiveHistoryEntry entry,
    Dispatcher<ReceiveHistoryService, List<ReceiveHistoryEntry>> dispatcher,
  ) async {
    if (entry.path != null) {
      await openFile(
        context,
        entry.fileType,
        entry.path!,
        onDeleteTap: () => dispatcher.dispatchAsync(RemoveHistoryEntryAction(entry.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(receiveHistoryProvider);
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? entries
        : entries.where((e) => e.fileName.toLowerCase().contains(query) || e.senderAlias.toLowerCase().contains(query)).toList();
    final groups = _grouping == _HistoryGrouping.day ? groupReceiveHistoryByDay(filtered) : groupReceiveHistoryByType(filtered);
    return Scaffold(
      appBar: basicLocalSendAppbar(t.receiveHistoryPage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainerIfDark,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainerIfDark,
                  ),
                  onPressed: checkPlatform([TargetPlatform.iOS])
                      ? null
                      : () async {
                          // ignore: use_build_context_synchronously
                          final destination = context.read(settingsProvider).destination ?? await getDefaultDestinationDirectory();
                          await openFolder(folderPath: destination);
                        },
                  icon: const Icon(Icons.folder),
                  label: Text(t.receiveHistoryPage.openFolder),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainerIfDark,
                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainerIfDark,
                  ),
                  onPressed: entries.isEmpty
                      ? null
                      : () async {
                          final result = await showDialog(
                            context: context,
                            builder: (_) => const HistoryClearDialog(),
                          );

                          if (context.mounted && result == true) {
                            await context.redux(receiveHistoryProvider).dispatchAsync(RemoveAllHistoryEntriesAction());
                          }
                        },
                  icon: const Icon(Icons.delete),
                  label: Text(t.receiveHistoryPage.deleteHistory),
                ),
              ],
            ),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: SegmentedButton<_HistoryGrouping>(
                showSelectedIcon: false,
                selected: {_grouping},
                onSelectionChanged: (selection) {
                  setState(() {
                    _grouping = selection.first;
                  });
                },
                segments: [
                  ButtonSegment(
                    value: _HistoryGrouping.day,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(t.receiveHistoryPage.groupByDay),
                  ),
                  ButtonSegment(
                    value: _HistoryGrouping.type,
                    icon: const Icon(Icons.category_rounded),
                    label: Text(t.receiveHistoryPage.groupByType),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_selectionMode && _selectedEntryIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.receiveHistoryPage.selectedCount(count: _selectedEntryIds.length),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedEntryIds.clear();
                        _selectionMode = false;
                      });
                    },
                    child: Text(t.general.cancel),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(t.receiveHistoryPage.deleteSelected),
                          content: Text(t.receiveHistoryPage.selectedCount(count: _selectedEntryIds.length)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(t.general.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(t.receiveHistoryPage.deleteSelected),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) {
                        return;
                      }
                      final ids = Set<String>.from(_selectedEntryIds);
                      await context.redux(receiveHistoryProvider).dispatchAsync(RemoveHistoryEntriesAction(ids));
                      if (!context.mounted) {
                        return;
                      }
                      setState(() {
                        _selectedEntryIds.clear();
                        _selectionMode = false;
                      });
                    },
                    icon: const Icon(Icons.delete_rounded),
                    label: Text(t.receiveHistoryPage.deleteSelected),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: t.receiveHistoryPage.searchHint,
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text(t.receiveHistoryPage.empty, style: Theme.of(context).textTheme.headlineMedium)),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text(t.receiveHistoryPage.noResults, style: Theme.of(context).textTheme.headlineSmall)),
            )
          else
            ...groups.expand((group) {
              return [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 4),
                  child: Row(
                    children: [
                      Text(group.label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text(
                        t.receiveHistoryPage.entriesCount(count: group.entries.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                ...group.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      onLongPress: () {
                        if (!_selectionMode) {
                          setState(() {
                            _selectionMode = true;
                            _selectedEntryIds.add(entry.id);
                          });
                          HapticFeedback.selectionClick(); // ignore: discarded_futures
                        }
                      },
                      onTap: _selectionMode
                          ? () {
                              setState(() {
                                if (!_selectedEntryIds.remove(entry.id)) {
                                  _selectedEntryIds.add(entry.id);
                                }
                                if (_selectedEntryIds.isEmpty) {
                                  _selectionMode = false;
                                }
                              });
                            }
                          : entry.path != null || entry.isMessage
                          ? () async {
                              if (entry.isMessage) {
                                final vm = ViewProvider((ref) {
                                  return ReceivePageVm(
                                    status: SessionStatus.waiting,
                                    sender: Device(
                                      signalingId: null,
                                      ip: '0.0.0.0',
                                      version: '1.0.0',
                                      port: 8080,
                                      https: false,
                                      fingerprint: 'fingerprint',
                                      alias: entry.senderAlias,
                                      deviceModel: 'deviceModel',
                                      deviceType: DeviceType.web,
                                      download: true,
                                      discoveryMethods: const {},
                                    ),
                                    showSenderInfo: false,
                                    files: [],
                                    message: entry.fileName,
                                    onAccept: () {},
                                    onDecline: () {},
                                    onClose: () {},
                                  );
                                });

                                // ignore: unawaited_futures
                                context.push(() => ReceivePage(vm));
                                return;
                              }

                              await _openFile(context, entry, context.redux(receiveHistoryProvider));
                            }
                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilePathThumbnail(
                            path: entry.path,
                            fileType: entry.fileType,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 3),
                                Text(
                                  entry.fileName,
                                  style: const TextStyle(fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                                Text(
                                  '${entry.timestampString} - ${entry.fileSize.asReadableFileSize} - ${entry.senderAlias}',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          PopupMenuButton<_EntryOption>(
                            onSelected: (_EntryOption item) async {
                              switch (item) {
                                case _EntryOption.open:
                                  await _openFile(context, entry, context.redux(receiveHistoryProvider));
                                  break;
                                case _EntryOption.showInFolder:
                                  if (entry.path != null) {
                                    await openFolder(
                                      folderPath: File(entry.path!).parent.path,
                                      fileName: path.basename(entry.path!),
                                    );
                                  }
                                  break;
                                case _EntryOption.info:
                                  // ignore: use_build_context_synchronously
                                  await showDialog(
                                    context: context,
                                    builder: (_) => FileInfoDialog(entry: entry),
                                  );
                                  break;
                                case _EntryOption.delete:
                                  // ignore: use_build_context_synchronously
                                  await context.redux(receiveHistoryProvider).dispatchAsync(RemoveHistoryEntryAction(entry.id));
                                  break;
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return (entry.path != null ? _optionsAll : _optionsWithoutOpen).map((e) {
                                return PopupMenuItem<_EntryOption>(
                                  value: e,
                                  child: Text(e.label),
                                );
                              }).toList();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ];
            }),
        ],
      ),
    );
  }
}
