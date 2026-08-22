import 'dart:ui';
import 'package:flutter/material.dart';

class GradientCircularProgressIndicator extends StatefulWidget {
  final double size;
  final List<Color> colors;
  final double strokeWidth;

  const GradientCircularProgressIndicator({
    super.key,
    required this.size,
    required this.colors,
    this.strokeWidth = 6.0,
  });

  @override
  State<GradientCircularProgressIndicator> createState() =>
      _GradientCircularProgressIndicatorState();
}

class _GradientCircularProgressIndicatorState
    extends State<GradientCircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter:
            _GradientCircularProgressPainter(colors: widget.colors, strokeWidth: widget.strokeWidth),
      ),
    );
  }
}

class _GradientCircularProgressPainter extends CustomPainter {
  final List<Color> colors;
  final double strokeWidth;

  _GradientCircularProgressPainter({
    required this.colors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: colors,
        stops: const [0.0, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      0,
      3.141592653589793 * 1.9,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
