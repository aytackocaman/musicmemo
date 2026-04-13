import 'package:flutter/widgets.dart';

class Responsive {
  /// Scale factor: 1.0 on iPhone, 1.2 on iPad.
  static double scale(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    if (shortestSide >= 600) return 1.2;
    return 1.0;
  }

  /// Whether the current device is an iPad-class screen.
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }
}

/// Constrains content width on tablets so text/forms don't stretch wall-to-wall.
/// On phone, returns child unchanged.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 600});

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isTablet(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
