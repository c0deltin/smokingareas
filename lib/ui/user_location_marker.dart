import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/heading_service.dart';

/// Blue location dot with a translucent cone pointing where the user is
/// facing (compass) or walking (GPS course) – like in map apps.
///
/// Used as a flutter_map marker *without* counter-rotation, so the cone keeps
/// its geographic direction when the map is rotated.
class UserLocationMarker extends StatelessWidget {
  const UserLocationMarker({super.key, required this.heading});

  final HeadingService? heading;

  static const double size = 96;

  @override
  Widget build(BuildContext context) {
    final service = heading;
    if (service == null) return const _Dot();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => Stack(alignment: Alignment.center, children: [
        if (service.heading != null)
          CustomPaint(
            size: const Size.square(size),
            painter: HeadingConePainter(
              headingDegrees: service.heading!,
              spreadDegrees: service.spread,
              color: Colors.blue,
            ),
          ),
        const _Dot(),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
    );
  }
}

/// Paints a cone (circular sector) from the centre towards [headingDegrees]
/// (clockwise from north = up), [spreadDegrees] to each side, fading out.
class HeadingConePainter extends CustomPainter {
  HeadingConePainter({
    required this.headingDegrees,
    required this.spreadDegrees,
    required this.color,
  });

  final double headingDegrees;
  final double spreadDegrees;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    // Canvas angles start at 3 o'clock and grow clockwise; north is −90°.
    final mid = (headingDegrees - 90) * math.pi / 180;
    final half = spreadDegrees * math.pi / 180;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, mid - half, half * 2, false)
      ..close();
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.0)],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HeadingConePainter old) =>
      old.headingDegrees != headingDegrees ||
      old.spreadDegrees != spreadDegrees ||
      old.color != color;
}
