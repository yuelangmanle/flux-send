import 'dart:async';

/// 滑动窗口限流器：同一 key 在窗口内的请求次数超过上限即拒绝。
class RequestRateLimiter {
  final int maxRequests;
  final Duration window;
  final Map<String, List<DateTime>> _hits = {};

  RequestRateLimiter({
    this.maxRequests = 30,
    this.window = const Duration(minutes: 1),
  });

  /// 返回本次请求是否放行；放行时自动记录。
  bool allow(String key, DateTime now) {
    final hits = (_hits[key] ?? []).where((t) => now.difference(t) < window).toList();
    if (hits.length >= maxRequests) {
      _hits[key] = hits;
      return false;
    }
    hits.add(now);
    _hits[key] = hits;
    return true;
  }
}

class BytesLimitExceededException implements Exception {
  final int maxBytes;
  BytesLimitExceededException(this.maxBytes);

  @override
  String toString() => 'Request body exceeds $maxBytes bytes';
}

/// 限制请求体字节量的流转换器，超限时抛出 [BytesLimitExceededException]。
StreamTransformer<List<int>, List<int>> limitBytes(int maxBytes) {
  var received = 0;
  return StreamTransformer.fromHandlers(
    handleData: (List<int> data, EventSink<List<int>> sink) {
      received += data.length;
      if (received > maxBytes) {
        sink.addError(BytesLimitExceededException(maxBytes));
        return;
      }
      sink.add(data);
    },
  );
}
