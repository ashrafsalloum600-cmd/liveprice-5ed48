import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'theme_controller.dart';

/// تأثير الدائرة: الثيم الجديد يتوسع من زر التبديل فوق لقطة الشاشة القديمة.
class ThemeReveal extends StatefulWidget {
  const ThemeReveal({super.key, required this.child});

  static final GlobalKey<ThemeRevealState> revealKey = GlobalKey<ThemeRevealState>();
  final Widget child;

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal> with SingleTickerProviderStateMixin {
  final GlobalKey _boundary = GlobalKey();
  ui.Image? _old;
  Offset _origin = Offset.zero;

  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _old?.dispose();
        setState(() => _old = null);
      }
    });

  Future<void> toggle(Offset origin) async {
    if (_old != null) return;
    final object = _boundary.currentContext?.findRenderObject();
    ui.Image? image;
    if (object is RenderRepaintBoundary && !MediaQuery.disableAnimationsOf(context)) {
      try {
        image = await object.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      } catch (_) {
        image = null;
      }
    }
    if (image == null || !mounted) {
      await ThemeController.instance.toggle();
      return;
    }
    setState(() {
      _old = image;
      _origin = origin;
    });
    // 1) نتأكد أن اللقطة ظاهرة فوق الشاشة قبل أي تغيير
    await WidgetsBinding.instance.endOfFrame;
    // 2) نبدّل الثيم تحت اللقطة
    ThemeController.instance.toggle();
    await WidgetsBinding.instance.endOfFrame;
    // 3) بعد ما يستقر الإطار الجديد نبدأ الدائرة
    if (mounted) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    _old?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (_old != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) =>
                    CustomPaint(painter: _RevealPainter(_old!, _origin, Curves.easeInOutCubic.transform(_c.value))),
              ),
            ),
          ),
      ],
    );
  }
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.image, this.origin, this.t);

  final ui.Image image;
  final Offset origin;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    if (t <= 0) {
      canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.medium);
      return;
    }
    final corners = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)];
    final far = corners.map((p) => (p - origin).distance).reduce(math.max);
    final hole = Path()..addOval(Rect.fromCircle(center: origin, radius: far * t));
    final clip = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), hole);
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RevealPainter old) => old.t != t || old.image != image;
}
