import 'dart:async';

extension StreamExt<T> on Stream<T> {
  (StreamController<T>, StreamSubscription<T>) digested() {
    late StreamSubscription<T> subscription;
    final streamController = StreamController<T>(
      onListen: () => subscription.resume(),
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () async => await subscription.cancel(),
    );

    subscription = listen(
      (data) => streamController.add(data),
      onError: (e, st) => streamController.addError(e, st),
      onDone: () async => await streamController.close(),
    );

    return (streamController, subscription);
  }
}

/// 按字节跳过流的前 [count] 字节（Stream.skip 按事件数跳过，不适用于文件块流）。
Stream<List<int>> skipBytes(Stream<List<int>> source, int count) {
  late StreamSubscription<List<int>> subscription;
  late StreamController<List<int>> controller;
  var remaining = count;

  void onData(List<int> chunk) {
    if (remaining > 0) {
      if (chunk.length <= remaining) {
        remaining -= chunk.length;
        return;
      }
      final rest = chunk.sublist(remaining);
      remaining = 0;
      controller.add(rest);
      return;
    }
    controller.add(chunk);
  }

  controller = StreamController<List<int>>(
    onListen: () {
      subscription = source.listen(
        onData,
        onError: controller.addError,
        onDone: controller.close,
        cancelOnError: true,
      );
    },
    onPause: () => subscription.pause(),
    onResume: () => subscription.resume(),
    onCancel: () => subscription.cancel(),
  );

  return controller.stream;
}
