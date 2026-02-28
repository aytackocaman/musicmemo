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

  const GameCardWidget({
    super.key,
    required this.state,
    required this.cardNumber,
    this.onTap,
    this.size = 64,
    this.countdownMs = 0,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    return Container(
      width: widget.size,
      height: widget.size * 1.25,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2DD4BF), // lighter teal
            Color(0xFF0D9488), // deeper teal
          ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.3),
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
