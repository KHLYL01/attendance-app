import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Fades and lifts content into place. Use it for screens and loaded sections.
class AppEntrance extends StatelessWidget {
  const AppEntrance({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.medium + (AppMotion.staggerStep * index),
      curve: AppMotion.enter,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
        );
      },
      child: child,
    );
  }
}
