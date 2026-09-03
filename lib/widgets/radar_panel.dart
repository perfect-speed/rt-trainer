import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Simplified Kalmar (ESMQ) ground picture for training, based on the AIP
/// aerodrome geometry: RWY 16/34 is the main 2050 m runway, RWY 05/23 crosses
/// its southern part, and Apron 1/2 with TWY A lie west of the main runway.
/// This is deliberately NOT a chart for navigation.
class RadarPanel extends StatelessWidget {
  const RadarPanel({super.key, this.progress, this.phaseLabel, this.runway = '01'});
  final double? progress;
  final String? phaseLabel;
  final String runway;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: ColoredBox(
      color: const Color(0xFF0C161E),
      child: CustomPaint(
        painter: _RadarPainter(progress: progress ?? .25, phaseLabel: phaseLabel, runway: runway),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress, required this.phaseLabel, required this.runway});
  final double progress;
  final String? phaseLabel;
  final String runway;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFF172A35)..strokeWidth = 1;
    final step = math.max(30.0, size.shortestSide / 8);
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);

    final runway = Paint()..color = const Color(0xFF3B4B55)..strokeWidth = 27..strokeCap = StrokeCap.butt;
    final centre = Paint()..color = const Color(0xFFB9C5CD)..strokeWidth = 1.3;
    final taxi = Paint()..color = const Color(0xFF536875)..strokeWidth = 8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final taxiLine = Paint()..color = const Color(0xFFD0A74B)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final apron = Paint()..color = const Color(0xFF263944)..style = PaintingStyle.fill;
    final accent = Paint()..color = AppTheme.accent..strokeWidth = 2..style = PaintingStyle.stroke;

    // AIP orientation: RWY 16/34 ~147/327 MAG. Draw north up, with RWY 16
    // threshold at the upper-left and RWY 34 threshold at the lower-right.
    final r16 = Offset(size.width * .55, size.height * .10);
    final r34 = Offset(size.width * .72, size.height * .88);
    canvas.drawLine(r16, r34, runway);
    canvas.drawLine(r16, r34, centre);
    _text(canvas, Offset(r16.dx - 27, r16.dy - 6), '16', 12, Colors.white);
    _text(canvas, Offset(r34.dx + 10, r34.dy - 5), '34', 12, Colors.white);

    // RWY 05/23 crosses the southern part of RWY 16/34.
    final crossC = Offset(size.width * .67, size.height * .68);
    final crossA = Offset(crossC.dx - size.width * .18, crossC.dy + size.height * .08);
    final crossB = Offset(crossC.dx + size.width * .18, crossC.dy - size.height * .08);
    canvas.drawLine(crossA, crossB, Paint()..color = const Color(0xFF35454F)..strokeWidth = 15);
    canvas.drawLine(crossA, crossB, Paint()..color = const Color(0xFF9EABB4)..strokeWidth = 1);
    _text(canvas, Offset(crossA.dx - 18, crossA.dy - 2), '05', 10, AppTheme.textMuted);
    _text(canvas, Offset(crossB.dx + 5, crossB.dy - 2), '23', 10, AppTheme.textMuted);

    // Aprons lie west of the main runway. TWY A runs north/south beside it;
    // for a RWY 16 departure the training route goes north from Apron 2 to
    // the RWY 16 holding position before entering the runway.
    final apronRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .13, size.height * .60, size.width * .25, size.height * .20),
      const Radius.circular(8),
    );
    canvas.drawRRect(apronRect, apron);
    _text(canvas, Offset(size.width * .15, size.height * .63), 'APRON 1 / 2', 10, AppTheme.textMuted);

    final apronExit = Offset(size.width * .37, size.height * .68);
    final twySouth = Offset(size.width * .43, size.height * .66);
    final twyNorth = Offset(size.width * .39, size.height * .20);
    final hold16 = Offset(size.width * .49, size.height * .16);
    final runwayEntry = Offset(size.width * .54, size.height * .145);

    final twyPath = Path()
      ..moveTo(apronExit.dx, apronExit.dy)
      ..lineTo(twySouth.dx, twySouth.dy)
      ..lineTo(twyNorth.dx, twyNorth.dy)
      ..lineTo(hold16.dx, hold16.dy)
      ..lineTo(runwayEntry.dx, runwayEntry.dy);
    canvas.drawPath(twyPath, taxi);
    canvas.drawPath(twyPath, taxiLine);
    _text(canvas, Offset(size.width * .31, size.height * .37), 'TWY A', 10, AppTheme.textMuted);

    // Holding point is explicitly BEFORE the runway.
    final hpVec = runwayEntry - hold16;
    final hpLen = math.max(1.0, hpVec.distance);
    final normal = Offset(-hpVec.dy / hpLen, hpVec.dx / hpLen) * 9;
    canvas.drawLine(hold16 - normal, hold16 + normal, Paint()..color = const Color(0xFFE0B64F)..strokeWidth = 3);
    _text(canvas, Offset(hold16.dx - 74, hold16.dy - 24), 'VÄNTPLATS RWY 16', 9, const Color(0xFFE0B64F));

    // Route points are chosen so the phase progress used by the state machine
    // maps to meaningful physical locations instead of cutting across RWY.
    final route = <Offset>[
      Offset(size.width * .22, size.height * .72), // apron/contact
      apronExit,
      twySouth,
      Offset(size.width * .41, size.height * .46),
      twyNorth,
      hold16,                                    // holding point
      runwayEntry,                               // cleared to line up
      Offset(size.width * .55, size.height * .18),
      Offset(size.width * .59, size.height * .34),
      Offset(size.width * .64, size.height * .57),
      Offset(size.width * .72, size.height * .90), // accelerating RWY 16 direction
      Offset(size.width * .78, size.height * .98),
    ];
    final path = Path()..moveTo(route.first.dx, route.first.dy);
    for (final p in route.skip(1)) path.lineTo(p.dx, p.dy);
    canvas.drawPath(path, Paint()..color = const Color(0xFF708795)..strokeWidth = 1.3..style = PaintingStyle.stroke);

    final t = progress.clamp(0.0, 1.0) * (route.length - 1);
    final i = t.floor().clamp(0, route.length - 2);
    final f = t - i;
    final a = route[i], b = route[i + 1];
    final aircraft = Offset(a.dx + (b.dx - a.dx) * f, a.dy + (b.dy - a.dy) * f);
    canvas.drawCircle(aircraft, 5, Paint()..color = AppTheme.accent);
    canvas.drawCircle(aircraft, 12, accent);
    _text(canvas, Offset(aircraft.dx + 14, aircraft.dy - 6), 'SE-KQX', 11, Colors.white);

    _text(canvas, const Offset(14, 14), 'KALMAR ESMQ · FÖRENKLAD AIP-GEOMETRI', 10, AppTheme.textMuted);
    if (phaseLabel != null) _text(canvas, Offset(14, size.height - 26), phaseLabel!, 11, AppTheme.accent);
  }

  void _text(Canvas c, Offset o, String t, double s, Color color) {
    final p = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: s, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 280);
    p.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.progress != progress || old.phaseLabel != phaseLabel || old.runway != runway;
}
