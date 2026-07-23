import 'dart:math';
import 'package:flutter/material.dart';

/// A lightweight falling-rain animation drawn with a [CustomPainter] — no
/// external package or asset. Meant to be layered (e.g. inside a Stack) over a
/// banner image. Purely decorative and non-interactive.
class RainOverlay extends StatefulWidget {
  final int dropCount;
  final Color color;

  const RainOverlay({
    super.key,
    this.dropCount = 90,
    this.color = const Color(0x99FFFFFF),
  });

  @override
  State<RainOverlay> createState() => _RainOverlayState();
}

class _RainOverlayState extends State<RainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Drop> _drops;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _drops = List.generate(widget.dropCount, (_) {
      return _Drop(
        x: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        speed: 0.6 + rnd.nextDouble() * 0.9,
        length: 0.04 + rnd.nextDouble() * 0.06,
        thickness: 0.8 + rnd.nextDouble() * 1.2,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RainPainter(
              drops: _drops,
              progress: _controller.value,
              color: widget.color,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Drop {
  final double x; // horizontal position, 0..1 of width
  final double phase; // vertical offset seed, 0..1
  final double speed; // fall speed multiplier
  final double length; // streak length, fraction of height
  final double thickness;

  const _Drop({
    required this.x,
    required this.phase,
    required this.speed,
    required this.length,
    required this.thickness,
  });
}

class _RainPainter extends CustomPainter {
  final List<_Drop> drops;
  final double progress;
  final Color color;

  _RainPainter({
    required this.drops,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    for (final d in drops) {
      final y = ((progress * d.speed) + d.phase) % 1.0;
      final dx = d.x * size.width;
      // Start slightly above the top so streaks enter smoothly.
      final startY = y * (size.height + size.height * d.length) -
          size.height * d.length;
      paint.strokeWidth = d.thickness;
      canvas.drawLine(
        Offset(dx, startY),
        Offset(dx, startY + d.length * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
