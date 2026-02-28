import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';

class GameCardWidget extends StatefulWidget {
  final CardState state;
  final VoidCallback? onTap;
  final double size;
  final int cardNumber;

  /// If > 0, shows a depleting circular countdown ring on the flipped card.
  final int countdownMs;

  /// Color of the player who matched this card. Used for matched card gradient
  /// and particle burst. Falls back to teal if null.
  final Color? matchedColor;

  const GameCardWidget({
    super.key,
    required this.state,
    required this.cardNumber,
    this.onTap,
    this.size = 64,
    this.countdownMs = 0,
    this.matchedColor,
  });

  @override
  State<GameCardWidget> createState() => _GameCardWidgetState();
}

class _GameCardWidgetState extends State<GameCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  AnimationController? _scaleController;
  Animation<double>? _scaleAnimation;
  bool _showFront = true;

  AnimationController? _countdownController;
  AnimationController? _particleController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _flipAnimation.addListener(() {
      if (_flipAnimation.value >= 0.5 && _showFront) {
        setState(() => _showFront = false);
      } else if (_flipAnimation.value < 0.5 && !_showFront) {
        setState(() => _showFront = true);
      }
    });

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _scaleController!, curve: Curves.easeInOut),
    );

    _updateFlipAnimation();
    _updateCountdown();
  }

  @override
  void didUpdateWidget(GameCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateFlipAnimation();
      if (widget.state == CardState.matched) {
        _triggerParticles();
      }
    }
    if (oldWidget.countdownMs != widget.countdownMs) {
      _updateCountdown();
    }
  }

  void _updateFlipAnimation() {
    if (widget.state == CardState.faceDown) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  void _updateCountdown() {
    if (widget.countdownMs > 0) {
      _countdownController?.dispose();
      _countdownController = AnimationController(
        duration: Duration(milliseconds: widget.countdownMs),
        vsync: this,
      );
      _countdownController!.forward();
    } else {
      _countdownController?.dispose();
      _countdownController = null;
    }
  }

  void _triggerParticles() {
    _particleController?.dispose();
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _particleController!.forward().then((_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.state == CardState.faceDown && widget.onTap != null) {
      _scaleController?.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _scaleController?.reverse();
    if (widget.state == CardState.faceDown) {
      widget.onTap?.call();
    }
  }

  void _handleTapCancel() {
    _scaleController?.reverse();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _scaleController?.dispose();
    _countdownController?.dispose();
    _particleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showParticles = _particleController != null &&
        _particleController!.isAnimating;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: ScaleTransition(
            scale: _scaleAnimation ?? const AlwaysStoppedAnimation(1.0),
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final angle = _flipAnimation.value * pi;
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle);

                return Transform(
                  alignment: Alignment.center,
                  transform: transform,
                  child: _showFront ? _buildFaceDown() : _buildFaceUp(),
                );
              },
            ),
          ),
        ),
        if (showParticles)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _particleController!,
                builder: (context, _) => CustomPaint(
                  painter: _ParticlePainter(
                    progress: _particleController!.value,
                    cardWidth: widget.size,
                    cardHeight: widget.size * 1.25,
                    matchedColor: widget.matchedColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFaceDown() {
    final radius = BorderRadius.circular(12);
    return Container(
      width: widget.size,
      height: widget.size * 1.25,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9B6FF7), // lighter purple
            Color(0xFF7C3AED), // deeper purple
          ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner highlight glow
            Positioned(
              top: -widget.size * 0.2,
              left: -widget.size * 0.1,
              child: Container(
                width: widget.size * 0.8,
                height: widget.size * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Card number
            Text(
              '${widget.cardNumber}',
              style: TextStyle(
                fontSize: widget.size * 0.32,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceUp() {
    // Mirror the content since we're showing the back of a flipped card
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: widget.state == CardState.matched
          ? _buildMatchedCard()
          : _buildFlippedCard(),
    );
  }

  Widget _buildFlippedCard() {
    final radius = BorderRadius.circular(12);
    return Container(
      width: widget.size,
      height: widget.size * 1.25,
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.purple,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner highlight
            Positioned(
              top: -widget.size * 0.15,
              right: -widget.size * 0.1,
              child: Container(
                width: widget.size * 0.7,
                height: widget.size * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.06),
                      AppColors.purple.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Icon(
              Icons.volume_up,
              size: widget.size * 0.4,
              color: AppColors.purple,
            ),
            // Countdown ring overlay
            if (_countdownController != null)
              AnimatedBuilder(
                animation: _countdownController!,
                builder: (context, child) {
                  // Deplete from 1.0 → 0.0
                  final progress = 1.0 - _countdownController!.value;
                  if (progress <= 0) return const SizedBox();
                  return SizedBox(
                    width: widget.size * 0.55,
                    height: widget.size * 0.55,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: AppColors.purple.withValues(alpha: 0.6),
                      backgroundColor: AppColors.purple.withValues(alpha: 0.1),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedCard() {
    final radius = BorderRadius.circular(12);
    final baseColor = widget.matchedColor ?? AppColors.teal;
    // Derive lighter and deeper shades from the base color for the gradient
    final hsl = HSLColor.fromColor(baseColor);
    final lighterColor = hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
    final deeperColor = hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor();
    return Container(
      width: widget.size,
      height: widget.size * 1.25,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lighterColor, deeperColor],
        ),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner highlight glow
            Positioned(
              top: -widget.size * 0.2,
              left: -widget.size * 0.1,
              child: Container(
                width: widget.size * 0.8,
                height: widget.size * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Icon(
              Icons.check,
              size: widget.size * 0.4,
              color: AppColors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final double cardWidth;
  final double cardHeight;
  final Color? matchedColor;

  static const int _particleCount = 20;
  static List<Offset>? _cachedDirections;
  static List<Offset> get _directions {
    if (_cachedDirections == null || _cachedDirections!.length != _particleCount) {
      _cachedDirections = List.generate(_particleCount, (i) {
        final angle = (i / _particleCount) * 2 * pi + 0.3 * i;
        return Offset(cos(angle), sin(angle));
      });
    }
    return _cachedDirections!;
  }
  static const List<Color> _defaultColors = [
    Color(0xFF14B8A6), // teal
    Color(0xFF8B5CF6), // purple
    Color(0xFFF472B6), // pink
    Color(0xFFFBBF24), // gold
    Color(0xFF10B981), // green
  ];

  _ParticlePainter({
    required this.progress,
    required this.cardWidth,
    required this.cardHeight,
    this.matchedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxDist = cardWidth * 1.4;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    // When a matched color is provided, use it as the dominant particle color
    // with white and a lighter variant for variety.
    final colors = matchedColor != null
        ? [
            matchedColor!,
            matchedColor!,
            Colors.white,
            HSLColor.fromColor(matchedColor!).withLightness(0.75).toColor(),
            Color(0xFFFBBF24), // gold accent
          ]
        : _defaultColors;

    for (int i = 0; i < _particleCount; i++) {
      final dir = _directions[i];
      final dist = maxDist * progress;
      final x = cx + dir.dx * dist;
      final y = cy + dir.dy * dist;
      final radius = 3.5 * (1.0 - progress * 0.4);
      final color = colors[i % colors.length].withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
