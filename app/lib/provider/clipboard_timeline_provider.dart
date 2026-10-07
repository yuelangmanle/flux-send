import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// 剪贴板时间线条目。
class ClipboardTimelineEntry {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool sent; // true=本机发出, false=从对端接收
  final String peerAlias;

  const ClipboardTimelineEntry({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.sent,
    required this.peerAlias,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'ts': timestamp.millisecondsSinceEpoch,
    'sent': sent,
    'peer': peerAlias,
  };

  static ClipboardTimelineEntry fromMap(Map<String, dynamic> map) => ClipboardTimelineEntry(
    id: map['id'] as String,
    text: map['text'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
    sent: map['sent'] as bool? ?? false,
    peerAlias: map['peer'] as String? ?? '',
  );
}

final clipboardTimelineProvider = NotifierProvider<ClipboardTimelineService, List<ClipboardTimelineEntry>>((ref) {
  return ClipboardTimelineService(ref.read(persistenceProvider));
});

class ClipboardTimelineService extends Notifier<List<ClipboardTimelineEntry>> {
  final PersistenceService _persistence;

  ClipboardTimelineService(this._persistence);

  @override
  List<ClipboardTimelineEntry> init() {
    final raw = _persistence.getClipboardTimeline();
    return raw.map(ClipboardTimelineEntry.fromMap).toList();
  }

  /// 记录一条剪贴板同步；与上一条内容相同则去重；超过 50 条裁剪。
  Future<void> add({
    required String text,
    required bool sent,
    required String peerAlias,
  }) async {
    if (text.isEmpty) {
      return;
    }
    if (state.isNotEmpty && state.first.text == text) {
      return;
    }
    final entry = ClipboardTimelineEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      sent: sent,
      peerAlias: peerAlias,
    );
    final updated = [entry, ...state].take(50).toList();
    await _persistence.setClipboardTimeline(updated.map((e) => e.toMap()).toList());
    state = updated;
  }

  Future<void> clear() async {
    await _persistence.setClipboardTimeline(const []);
    state = const [];
  }
}
