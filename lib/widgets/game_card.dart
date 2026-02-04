import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';

class GameCardWidget extends StatefulWidget {
  final CardState state;
  final VoidCallback? onTap;
  final double size;
  final int cardNumber;

  const GameCardWidget({
    super.key,
    required this.state,
    required this.cardNumber,
    this.onTap,
    this.size = 64,
  });

  @override
  State<GameCardWidget> createState() => _GameCardWidgetState();
}

class _GameCardWidgetState extends State<GameCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _animation.addListener(() {
      if (_animation.value >= 0.5 && _showFront) {
        setState(() => _showFront = false);
      } else if (_animation.value < 0.5 && !_showFront) {
        setState(() => _showFront = true);
      }
    });

    _updateAnimation();
  }

  @override
  void didUpdateWidget(GameCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.state == CardState.faceDown) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.state == CardState.faceDown ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
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
      child: Center(
        child: Icon(
          Icons.volume_up,
          size: widget.size * 0.4,
          color: AppColors.purple,
        ),
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
