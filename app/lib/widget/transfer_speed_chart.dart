import 'package:flutter/material.dart';
import 'package:localsend_app/util/file_size_helper.dart';

/// 传输速度曲线：绘制最近的 bytes/s 采样序列，视觉克制（单色描边 + 渐变填充）。
class TransferSpeedChart extends StatelessWidget {
  final List<double> samples;
  final Color color;

  const TransferSpeedChart({
    required this.samples,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: CustomPaint(
        painter: _SpeedCurvePainter(
          samples: samples,
          color: color,
        ),
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: Text(
              samples.last.round().asReadableFileSize,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedCurvePainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  _SpeedCurvePainter({
    required this.samples,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) {
      return;
    }
    final maxValue = samples.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) {
      return;
    }

    final stepX = size.width / (samples.length - 1);
    Offset pointAt(int i) {
      final ratio = samples[i] / maxValue;
      return Offset(i * stepX, size.height * (1 - ratio * 0.85) - 2);
    }

    final linePath = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    // 中点平滑：相邻点间用二次贝塞尔，视觉更柔和。
    for (var i = 1; i < samples.length; i++) {
      final prev = pointAt(i - 1);
      final curr = pointAt(i);
      final midX = (prev.dx + curr.dx) / 2;
      linePath.quadraticBezierTo(prev.dx, prev.dy, midX, (prev.dy + curr.dy) / 2);
    }
    linePath.lineTo(pointAt(samples.length - 1).dx, pointAt(samples.length - 1).dy);

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.02)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SpeedCurvePainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}
