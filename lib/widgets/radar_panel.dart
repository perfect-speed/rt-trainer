import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
      child: CustomPaint(painter: _RadarPainter(progress: progress ?? .25, phaseLabel: phaseLabel, runway: runway), child: const SizedBox.expand()),
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
    final grid = Paint()..color = const Color(0xFF1B303D)..strokeWidth = 1;
    final bright = Paint()..color = AppTheme.accent..strokeWidth = 2..style = PaintingStyle.stroke;
    final muted = Paint()..color = const Color(0xFF526879)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final step = math.max(28.0, size.shortestSide / 8);
    for (double x=0;x<size.width;x+=step) canvas.drawLine(Offset(x,0),Offset(x,size.height),grid);
    for (double y=0;y<size.height;y+=step) canvas.drawLine(Offset(0,y),Offset(size.width,y),grid);

    final rTop = Offset(size.width*.55,size.height*.16);
    final rBot = Offset(size.width*.39,size.height*.78);
    canvas.drawLine(rTop,rBot,Paint()..color=const Color(0xFF3A4A55)..strokeWidth=26);
    canvas.drawLine(rTop,rBot,Paint()..color=const Color(0xFFBAC6CE)..strokeWidth=1.5);
    _text(canvas, Offset(rBot.dx-35,rBot.dy+12),'BANA $runway',11,AppTheme.textMuted);

    final route=<Offset>[
      Offset(size.width*.15,size.height*.82), Offset(size.width*.28,size.height*.78),
      Offset(size.width*.38,size.height*.72), rBot, Offset(size.width*.47,size.height*.60),
      Offset(size.width*.48,size.height*.48), Offset(size.width*.49,size.height*.34),
      Offset(size.width*.54,size.height*.18), Offset(size.width*.68,size.height*.08),
    ];
    final path=Path()..moveTo(route.first.dx,route.first.dy);
    for(final p in route.skip(1)) path.lineTo(p.dx,p.dy);
    canvas.drawPath(path,muted);
    final t=progress.clamp(0.0,1.0)*(route.length-1);
    final i=t.floor().clamp(0,route.length-2); final f=t-i;
    final a=route[i], b=route[i+1];
    final aircraft=Offset(a.dx+(b.dx-a.dx)*f,a.dy+(b.dy-a.dy)*f);
    canvas.drawCircle(aircraft,5,Paint()..color=AppTheme.accent); canvas.drawCircle(aircraft,12,bright);
    _text(canvas,Offset(aircraft.dx+14,aircraft.dy-5),'SE-KQX',12,Colors.white);
    _text(canvas,const Offset(14,14),'KALMAR · AVGÅNG',11,AppTheme.textMuted);
    if(phaseLabel!=null) _text(canvas,Offset(14,size.height-26),phaseLabel!,11,AppTheme.accent);
  }
  void _text(Canvas c,Offset o,String t,double s,Color color){final p=TextPainter(text:TextSpan(text:t,style:TextStyle(color:color,fontSize:s,fontWeight:FontWeight.w600)),textDirection:TextDirection.ltr)..layout(maxWidth:260);p.paint(c,o);}
  @override bool shouldRepaint(covariant _RadarPainter old)=>old.progress!=progress||old.phaseLabel!=phaseLabel||old.runway!=runway;
}
