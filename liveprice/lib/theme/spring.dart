import 'dart:math' as math;

import 'package:flutter/material.dart';

/// نابض: تخميد 0.8، تجاوز ~1.5% ثم يستقر.
class AppSpring extends Curve {
  const AppSpring();

  @override
  double transformInternal(double t) {
    const w = 14.0, z = 0.8;
    final a = z * w;
    final b = w * math.sqrt(1 - z * z);
    return 1 - math.exp(-a * t) * (math.cos(b * t) + (a / b) * math.sin(b * t));
  }
}

/// ردّ فعل لمس فوري: يصغر لحظة اللمس ويرجع بنابض خفيف.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.94});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: reduce ? Duration.zero : Duration(milliseconds: _down ? 60 : 220),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
