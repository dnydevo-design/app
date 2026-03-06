import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarUI extends StatefulWidget {
  final double size;
  final Color color;
  final bool isCalling;

  const RadarUI({
    super.key,
    this.size = 300,
    this.color = Colors.blue,
    this.isCalling = false,
  });

  @override
  State<RadarUI> createState() => _RadarUIState();
}

class _RadarUIState extends State<RadarUI> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: Duration(seconds: widget.isCalling ? 1 : 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(RadarUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCalling != oldWidget.isCalling) {
      _controller.duration = Duration(seconds: widget.isCalling ? 1 : 4);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(
              animationValue: _controller.value,
              color: widget.isCalling ? Colors.green : widget.color,
              isCalling: widget.isCalling,
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isCalling;

  _RadarPainter({required this.animationValue, required this.color, required this.isCalling});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final paintCircle = Paint()
      ..color = color.withOpacity(isCalling ? 0.3 * (1 - animationValue) + 0.1 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCalling ? 2.0 : 1.0;

    // Draw background circles
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), paintCircle);
    }

    // Draw lines
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paintCircle);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paintCircle);

    // Draw scanning arc
    final sweepAngle = math.pi / 2;
    final startAngle = (animationValue * 2 * math.pi) - (math.pi / 2);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: sweepAngle,
        colors: [color.withOpacity(0.0), color.withOpacity(0.5)],
        stops: const [0.0, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      true,
      sweepPaint,
    );
    
    // Draw scanning line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
      
    final endX = center.dx + radius * math.cos(startAngle + sweepAngle);
    final endY = center.dy + radius * math.sin(startAngle + sweepAngle);
    
    canvas.drawLine(center, Offset(endX, endY), linePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.color != color ||
           oldDelegate.isCalling != isCalling;
  }
}
