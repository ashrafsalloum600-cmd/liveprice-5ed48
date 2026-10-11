import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liveprice/services/pricing.dart';
import 'package:liveprice/theme/app_colors.dart';

class RateBanner extends StatefulWidget {
  final bool flat;

  const RateBanner({super.key, this.flat = false});

  @override
  State<RateBanner> createState() => _RateBannerState();
}

class _RateBannerState extends State<RateBanner> with SingleTickerProviderStateMixin {
  static const _label = TextStyle(fontSize: 13, color: AppColors.textDim, fontWeight: FontWeight.w600);
  static const _red = Color(0xFFFF3B30);
  static const _green = Color(0xFF34C759);

  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  late final Animation<double> _curve = CurvedAnimation(parent: _pulse, curve: Curves.easeOut);
  Timer? _timer;
  int _tick = 0;

  bool get _showRate => _tick % 7 < 4;

  @override
  void initState() {
    super.initState();
    Pricing.instance.addListener(_onPricingChanged);
    _syncTimer();
  }

  void _onPricingChanged() => _syncTimer();

  void _syncTimer() {
    if (Pricing.instance.lastUpdatedAt == null) {
      _timer?.cancel();
      _timer = null;
      _tick = 0;
      return;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final wasRate = _showRate;
      _tick++;
      if (wasRate != _showRate && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    Pricing.instance.removeListener(_onPricingChanged);
    _timer?.cancel();
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

  String _relativeUpdateTime(DateTime updatedAt) {
    final elapsed = DateTime.now().difference(updatedAt);
    if (elapsed.inMinutes < 1) return 'الآن';
    if (elapsed.inMinutes < 60) return _relativeUnit(elapsed.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق', 'دقيقة');
    if (elapsed.inHours < 24) return _relativeUnit(elapsed.inHours, 'ساعة', 'ساعتين', 'ساعات', 'ساعة');
    return _relativeUnit(elapsed.inDays, 'يوم', 'يومين', 'أيام', 'يوماً');
  }

  String _relativeUnit(int value, String one, String two, String plural, String many) {
    if (value == 1) return 'منذ $one';
    if (value == 2) return 'منذ $two';
    if (value <= 10) return 'منذ $value $plural';
    return 'منذ $value $many';
  }

  Widget _rateContent(double rate, bool up, bool down) {
    return Row(
      key: const ValueKey('rate'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _liveDot(),
        const SizedBox(width: 6),
        const Text('سعر الصرف :', style: _label),
        const SizedBox(width: 6),
        Text(
          _fmt(rate),
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
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
    );
  }

  Widget _updateContent(DateTime updatedAt) {
    return Row(
      key: const ValueKey('update'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 16, color: _green),
        const SizedBox(width: 6),
        const Text('آخر تحديث للأسعار :', style: _label),
        const SizedBox(width: 6),
        Text(
          _relativeUpdateTime(updatedAt),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Pricing.instance,
      builder: (context, _) {
        final rate = Pricing.instance.usdToSyp;
        if (rate == null) return const SizedBox.shrink();
        final lastUpdatedAt = Pricing.instance.lastUpdatedAt;
        final prev = Pricing.instance.previousUsdToSyp;
        final up = prev != null && rate > prev;
        final down = prev != null && rate < prev;

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: widget.flat
              ? null
              : BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
                ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: lastUpdatedAt == null
                  ? _rateContent(rate, up, down)
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _showRate ? _rateContent(rate, up, down) : _updateContent(lastUpdatedAt),
                    ),
            ),
          ),
        );
      },
    );
  }
}
