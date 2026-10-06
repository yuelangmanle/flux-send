/// 传输速度采样器：按固定间隔记录累计字节数，计算瞬时速度序列（bytes/s）。
/// 纯逻辑、无 Flutter 依赖，便于单元测试。
class TransferSpeedSampler {
  TransferSpeedSampler({this.window = 60, this.minInterval = const Duration(milliseconds: 250)});

  /// 保留的采样点数量。
  final int window;

  /// 两次采样的最小间隔；过短的间隔会造成速度值抖动，直接忽略。
  final Duration minInterval;

  final List<double> _samples = [];
  int? _lastBytes;
  DateTime? _lastTime;

  /// 记录当前累计字节数；距上次采样不足 [minInterval] 时返回 null（不产生新样本）。
  double? addSample(int totalBytes, DateTime now) {
    final lastBytes = _lastBytes;
    final lastTime = _lastTime;
    if (lastBytes != null && lastTime != null) {
      final elapsed = now.difference(lastTime);
      if (elapsed < minInterval) {
        return null;
      }
      final seconds = elapsed.inMicroseconds / 1e6;
      final speed = (totalBytes - lastBytes) / seconds;
      _samples.add(speed.clamp(0, double.maxFinite));
      if (_samples.length > window) {
        _samples.removeAt(0);
      }
    }
    _lastBytes = totalBytes;
    _lastTime = now;
    return _samples.isEmpty ? null : _samples.last;
  }

  /// 当前速度序列（旧 → 新，bytes/s）。
  List<double> get samples => List.unmodifiable(_samples);

  /// 最近的平滑速度：最后 N 个样本的平均值（N 最多 5），无样本时返回 null。
  double? get smoothedLatest {
    if (_samples.isEmpty) {
      return null;
    }
    final tail = _samples.length <= 5 ? _samples : _samples.sublist(_samples.length - 5);
    return tail.reduce((a, b) => a + b) / tail.length;
  }

  void reset() {
    _samples.clear();
    _lastBytes = null;
    _lastTime = null;
  }
}
