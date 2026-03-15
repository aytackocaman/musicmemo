import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Draws a depleting teal border directly on the card's edges.
/// At the burn point, a polished glowing head with smooth trailing
/// sparkle arcs creates a premium "comet" effect.
class FuseTimerBorder extends StatefulWidget {
  final Widget child;
  final double progress; // 1.0 = full, 0.0 = empty
  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final bool showFuse;

  const FuseTimerBorder({
    super.key,
    required this.child,
    required this.progress,
    required this.color,
    this.borderRadius = 16.0,
    this.strokeWidth = 5.0,
    this.showFuse = true,
  });

  @override
  State<FuseTimerBorder> createState() => _FuseTimerBorderState();
}

class _FuseTimerBorderState extends State<FuseTimerBorder>
    with SingleTickerProviderStateMixin {
  AnimationController? _particleController;

  void _ensureController() {
    _particleController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _particleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showFuse || widget.progress <= 0.0) {
      return widget.child;
    }

    _ensureController();

    return AnimatedBuilder(
      animation: _particleController!,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _FuseLoaderPainter(
            progress: widget.progress,
            color: widget.color,
            borderRadius: widget.borderRadius,
            strokeWidth: widget.strokeWidth,
            phase: _particleController!.value,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _FuseLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double phase;

  static const _fuseColor = Color(0xFF14B8A6); // teal

  _FuseLoaderPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
    required this.phase,
  });

  /// Build a rounded rect path that starts from the top-center point
  /// and traces clockwise around the card.
  Path _buildPathFromTopCenter(Size size) {
    final r = borderRadius;
    final w = size.width;
    final h = size.height;
    final midX = w / 2;

    return Path()
      // Start at top-center
      ..moveTo(midX, 0)
      // Top edge right half → top-right corner
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      // Right edge → bottom-right corner
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      // Bottom edge → bottom-left corner
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      // Left edge → top-left corner
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      // Top edge left half back to start
      ..lineTo(midX, 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final fullPath = _buildPathFromTopCenter(size);
    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final totalLength = metric.length;
    final fuseLength = totalLength * progress.clamp(0.0, 1.0);
    final burnOffset = totalLength - fuseLength;

    // ── 1. Remaining (unconsumed) teal border ──
    final remainingPath = metric.extractPath(burnOffset, totalLength);

    canvas.drawPath(
      remainingPath,
      Paint()
        ..color = _fuseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // ── 2. Comet head at the burn point ──
    if (progress < 1.0 && progress > 0.0) {
      _drawCometHead(canvas, metric, burnOffset, totalLength);
    }
  }

  void _drawCometHead(
    Canvas canvas,
    PathMetric metric,
    double burnOffset,
    double totalLength,
  ) {
    final tangent = metric.getTangentForOffset(burnOffset);
    if (tangent == null) return;
    final pos = tangent.position;

    // ── Shimmer pulse (cycles with phase) ──
    final shimmer = 0.6 + 0.4 * sin(phase * 2 * pi);

    // ── Outer glow — large soft teal halo ──
    canvas.drawCircle(
      pos,
      12 * shimmer,
      Paint()
        ..color = _fuseColor.withValues(alpha: 0.2 * shimmer)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── Middle glow — warm white ──
    canvas.drawCircle(
      pos,
      7 * shimmer,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * shimmer)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Bright core — solid white dot ──
    canvas.drawCircle(
      pos,
      strokeWidth * 0.6,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // ── Trailing comet tail — a gradient stroke behind the head ──
    // Draw a short segment of the already-consumed path as a fading tail
    final tailLength = totalLength * 0.06; // 6% of perimeter
    final tailStart = (burnOffset - tailLength).clamp(0.0, totalLength);
    if (burnOffset > tailStart) {
      final tailPath = metric.extractPath(tailStart, burnOffset);

      // Bright inner tail
      canvas.drawPath(
        tailPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 * shimmer)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Outer glow tail
      canvas.drawPath(
        tailPath,
        Paint()
          ..color = _fuseColor.withValues(alpha: 0.3 * shimmer)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 1.8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // ── Starburst rays — 4 small lines radiating from the head ──
    final rayLength = 4.0 + 3.0 * shimmer;
    const rayCount = 4;
    for (int i = 0; i < rayCount; i++) {
      final rayAngle = tangent.angle + (i * pi / 2) + phase * pi * 2;
      final rayEnd = Offset(
        pos.dx + cos(rayAngle) * rayLength,
        pos.dy + sin(rayAngle) * rayLength,
      );
      canvas.drawLine(
        pos,
        rayEnd,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6 * shimmer)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Orbiting sparkles — 3 tiny dots that orbit the head ──
    const sparkleCount = 3;
    for (int i = 0; i < sparkleCount; i++) {
      final orbitAngle = phase * 2 * pi + (i * 2 * pi / sparkleCount);
      final orbitRadius = 6.0 + 2.0 * sin(phase * 4 * pi + i);
      final sparklePos = Offset(
        pos.dx + cos(orbitAngle) * orbitRadius,
        pos.dy + sin(orbitAngle) * orbitRadius,
      );
      final sparkleSize = 1.5 + 0.8 * sin(phase * 3 * pi + i * 1.5);

      canvas.drawCircle(
        sparklePos,
        sparkleSize,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * shimmer),
      );
    }
  }

  @override
  bool shouldRepaint(_FuseLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.color != color;
}
