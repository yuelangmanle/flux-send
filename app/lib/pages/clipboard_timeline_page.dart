import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/clipboard_timeline_provider.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// 剪贴板时间线：按时间倒序展示最近同步的剪贴板内容，点击回填系统剪贴板。
class ClipboardTimelinePage extends StatefulWidget {
  const ClipboardTimelinePage();

  @override
  State<ClipboardTimelinePage> createState() => _ClipboardTimelinePageState();
}

class _ClipboardTimelinePageState extends State<ClipboardTimelinePage> with Refena {
  @override
  Widget build(BuildContext context) {
    final entries = context.watch(clipboardTimelineProvider);
    return Scaffold(
      appBar: basicLocalSendAppbar(t.clipboardTimelinePage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Text(t.clipboardTimelinePage.empty, style: Theme.of(context).textTheme.headlineSmall),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(t.clipboardTimelinePage.clear),
                          content: Text(t.clipboardTimelinePage.clearConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(t.general.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(t.clipboardTimelinePage.clear),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        unawaited(ref.notifier(clipboardTimelineProvider).clear());
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: Text(t.clipboardTimelinePage.clear),
                  ),
                ],
              ),
            ),
            ...entries.map((entry) {
              final time = TimeOfDay.fromDateTime(entry.timestamp).format(context);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      entry.sent ? Icons.upload_rounded : Icons.download_rounded,
                      color: entry.sent ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      entry.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${entry.sent ? t.clipboardTimelinePage.sent : t.clipboardTimelinePage.received}'
                      ' · ${entry.peerAlias} · $time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.content_copy_rounded),
                      tooltip: t.clipboardTimelinePage.copyBack,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: entry.text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.clipboardTimelinePage.copiedBack)),
                          );
                        }
                      },
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}
