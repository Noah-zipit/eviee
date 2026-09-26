import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ambient eviee orb: chrome spark core + breathing halo + three expanding
/// ripple rings. Seamless loop, monochrome white/silver on near-black.
/// Mirrors ~/workspace/eviee-theme/orb-anim.html.
class OrbWidget extends StatefulWidget {
  final double size;
  const OrbWidget({super.key, this.size = 132});

  @override
  State<OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<OrbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _OrbPainter(_ctrl.value),
          size: Size(widget.size, widget.size),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t; // 0..1 loop position
  _OrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 132.0;

    // Ripple rings: 3 staggered, scale .55 -> 2.1, fade out.
    for (var i = 0; i < 3; i++) {
      final phase = ((t + i / 3.0) % 1.0);
      final eased = _easeOutCubic(phase);
      final radius = 29 * unit * (0.55 + eased * 1.55);
      final opacity = (1 - phase) * 0.45;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Color.fromRGBO(235, 240, 245, opacity),
      );
    }

    // Breathing halo.
    final breathe = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final haloR = 48 * unit * (1 + 0.14 * breathe);
    canvas.drawCircle(
      c,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 255, 255, 0.20 + 0.08 * breathe),
            const Color.fromRGBO(255, 255, 255, 0.05),
            const Color.fromRGBO(255, 255, 255, 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: haloR)),
    );

    // Spark: 4-point star, slow rotation (16s period).
    final spin = (t * 2800 / 16000) * math.pi * 2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    final sparkR = 26 * unit;
    final sparkPaint = Paint()
      ..color = const Color(0xFFF4F7FA)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(_starPath(sparkR), sparkPaint);
    canvas.drawPath(
        _starPath(sparkR * 0.55),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.restore();

    // Core: pulsing white-hot dot.
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final coreR = 13 * unit * (1 + 0.22 * pulse);
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFE6EBF1),
            Color(0x00E6EBF1),
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
  }

  Path _starPath(double r) {
    final path = Path();
    const spikes = 4;
    for (var i = 0; i < spikes; i++) {
      final a = (i / spikes) * math.pi * 2 - math.pi / 2;
      final tip = Offset(math.cos(a) * r, math.sin(a) * r);
      final a1 = a + math.pi / spikes;
      final inner = Offset(math.cos(a1) * r * 0.16, math.sin(a1) * r * 0.16);
      final a2 = a - math.pi / spikes;
      final inner2 = Offset(math.cos(a2) * r * 0.16, math.sin(a2) * r * 0.16);
      if (i == 0) {
        path.moveTo(inner2.dx, inner2.dy);
      }
      path.lineTo(tip.dx, tip.dy);
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    return path;
  }

  double _easeOutCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}
