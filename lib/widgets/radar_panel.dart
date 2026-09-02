import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RadarPanel extends StatelessWidget {
  const RadarPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: const Color(0xFF0C161E),
        child: CustomPaint(
          painter: _RadarPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF1B303D)
      ..strokeWidth = 1;
    final bright = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final muted = Paint()
      ..color = const Color(0xFF526879)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final step = math.max(28.0, size.shortestSide / 8);
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final boundary = Path()
      ..moveTo(size.width * .73, 0)
      ..quadraticBezierTo(size.width * .62, size.height * .5, size.width * .78, size.height);
    canvas.drawPath(boundary, muted);

    final runwayCenter = Offset(size.width * .30, size.height * .43);
    canvas.save();
    canvas.translate(runwayCenter.dx, runwayCenter.dy);
    canvas.rotate(-0.42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: size.width * .08, height: size.height * .34),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF3A4A55),
    );
    canvas.drawLine(Offset(0, -size.height * .15), Offset(0, size.height * .15), Paint()..color = const Color(0xFFBAC6CE)..strokeWidth = 1.5);
    canvas.restore();

    final aircraft = Offset(size.width * .48, size.height * .68);
    canvas.drawCircle(aircraft, 5, Paint()..color = AppTheme.accent);
    canvas.drawCircle(aircraft, 12, bright);
    canvas.drawLine(aircraft, Offset(aircraft.dx - 20, aircraft.dy + 28), bright);

    _text(canvas, const Offset(14, 14), 'TRAINING SECTOR', 11, AppTheme.textMuted);
    _text(canvas, Offset(size.width * .76, 20), 'TMA', 11, AppTheme.warning);
    _text(canvas, Offset(aircraft.dx + 14, aircraft.dy - 5), 'SE-KQX', 12, Colors.white);
    _text(canvas, Offset(runwayCenter.dx - 22, runwayCenter.dy + 52), 'BANA 01', 11, AppTheme.textMuted);
  }

  void _text(Canvas canvas, Offset offset, String text, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
