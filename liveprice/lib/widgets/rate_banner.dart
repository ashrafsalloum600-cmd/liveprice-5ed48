import 'package:flutter/material.dart';
import 'package:liveprice/services/pricing.dart';

class RateBanner extends StatefulWidget {
  const RateBanner({super.key});

  @override
  State<RateBanner> createState() => _RateBannerState();
}

class _RateBannerState extends State<RateBanner> with SingleTickerProviderStateMixin {
  static const _label = TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600);
  static const _red = Color(0xFFFF3B30);
  static const _green = Color(0xFF34C759);

  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  late final Animation<double> _curve = CurvedAnimation(parent: _pulse, curve: Curves.easeOut);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    var s = v.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return parts.length > 1 ? '$whole.${parts[1]}' : whole;
  }

  Widget _dot() => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
  );

  Widget _liveDot() {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.45, end: 0).animate(_curve),
            child: ScaleTransition(scale: Tween<double>(begin: 1, end: 2.2).animate(_curve), child: _dot()),
          ),
          _dot(),
        ],
      ),
    );
  }

  Widget _arrow(bool up, bool down) {
    if (!up && !down) return const SizedBox.shrink(key: ValueKey('none'));
    final color = up ? _green : _red;
    return Container(
      key: ValueKey(up),
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color.withAlpha(38), shape: BoxShape.circle),
      child: Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Pricing.instance,
      builder: (context, _) {
        final rate = Pricing.instance.usdToSyp;
        if (rate == null) return const SizedBox.shrink();
        final prev = Pricing.instance.previousUsdToSyp;
        final up = prev != null && rate > prev;
        final down = prev != null && rate < prev;

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _liveDot(),
                  const SizedBox(width: 6),
                  const Text('سعر الصرف :', style: _label),
                  const SizedBox(width: 6),
                  Text(
                    _fmt(rate),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                  const SizedBox(width: 6),
                  const Text('ل.س', style: _label),
                  if (up || down) const SizedBox(width: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: _arrow(up, down),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
