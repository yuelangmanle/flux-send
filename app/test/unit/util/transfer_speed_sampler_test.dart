import 'package:test/test.dart';
import 'package:localsend_app/util/transfer_speed_sampler.dart';

void main() {
  final t0 = DateTime(2026, 10, 7, 8);

  group('TransferSpeedSampler', () {
    test('first sample produces no speed value', () {
      final sampler = TransferSpeedSampler();
      expect(sampler.addSample(0, t0), isNull);
    });

    test('computes bytes per second between samples', () {
      final sampler = TransferSpeedSampler(minInterval: const Duration(milliseconds: 250));
      sampler.addSample(0, t0);
      final speed = sampler.addSample(1000, t0.add(const Duration(seconds: 1)));
      expect(speed, closeTo(1000, 0.001));
    });

    test('ignores samples that arrive too soon', () {
      final sampler = TransferSpeedSampler(minInterval: const Duration(milliseconds: 250));
      sampler.addSample(0, t0);
      expect(sampler.addSample(5000, t0.add(const Duration(milliseconds: 100))), isNull);
      final speed = sampler.addSample(5000, t0.add(const Duration(seconds: 1)));
      expect(speed, closeTo(5000, 0.001));
    });

    test('window keeps only the newest N samples', () {
      final sampler = TransferSpeedSampler(window: 3, minInterval: Duration.zero);
      for (var i = 1; i <= 5; i++) {
        sampler.addSample(i * 1000, t0.add(Duration(seconds: i)));
      }
      expect(sampler.samples, hasLength(3));
      // 每秒新增 1000 字节 → 每个样本速度都是 1000
      expect(sampler.smoothedLatest, closeTo(1000, 0.001));
    });

    test('reset clears samples and baselines', () {
      final sampler = TransferSpeedSampler(minInterval: Duration.zero);
      sampler.addSample(1000, t0);
      sampler.reset();
      expect(sampler.samples, isEmpty);
      expect(sampler.addSample(2000, t0.add(const Duration(seconds: 1))), isNull);
    });
  });
}
