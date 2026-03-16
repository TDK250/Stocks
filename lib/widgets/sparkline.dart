import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final bool fill;

  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SparklinePainter(data: data, color: color, fill: fill),
      child: Container(),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool fill;

  SparklinePainter({
    required this.data,
    required this.color,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minPrice = data.reduce((a, b) => a < b ? a : b);
    final maxPrice = data.reduce((a, b) => a > b ? a : b);
    final range = maxPrice - minPrice == 0 ? 1.0 : maxPrice - minPrice;

    final path = Path();
    final xStep = size.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height - ((data[i] - minPrice) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fill) {
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
