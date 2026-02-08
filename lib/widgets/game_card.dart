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

  @override
  void dispose() {
    _flipController.dispose();
    _countdownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.state == CardState.faceDown ? widget.onTap : null,
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
    );
  }

  Widget _buildFaceDown() {
    return Container(
      width: widget.size,
      height: widget.size * 1.25,
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '${widget.cardNumber}',
          style: TextStyle(
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
            color: AppColors.white.withValues(alpha: 0.5),
          ),
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
    return Container(
      width: widget.size,
      height: widget.size * 1.25,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.purple,
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
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
    );
  }

  Widget _buildMatchedCard() {
    return Container(
      width: widget.size,
      height: widget.size * 1.25,
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.check,
          size: widget.size * 0.4,
          color: AppColors.white,
        ),
      ),
    );
  }
}
