import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/theme.dart';

/// Animated app icon that plays an MP4 in a loop with rounded corners.
/// Falls back to the static PNG if the video fails to load.
class AnimatedAppIcon extends StatefulWidget {
  final double size;

  const AnimatedAppIcon({super.key, required this.size});

  @override
  State<AnimatedAppIcon> createState() => _AnimatedAppIconState();
}

class _AnimatedAppIconState extends State<AnimatedAppIcon> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/icon/app_icon_animated.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.logo),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _initialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            : Image.asset(
                'assets/icon/app_icon_inside.png',
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}
